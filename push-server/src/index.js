// TapBTC push backend — Cloudflare Worker
//
// Two jobs:
//   1. POST /register  — a device uploads its APNs token + current alert list
//   2. cron (1/min)    — fetch the BTC price and send an APNs push for any
//                        alert whose threshold has been crossed
//
// This is what makes alerts fire when the app is closed or force-quit: the
// monitoring happens here, on an always-on server, not on the phone.

const COINBASE_URL = "https://api.coinbase.com/v2/prices/BTC-USD/spot";
const APNS_HOST_PROD = "https://api.push.apple.com";
const APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com";
const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour, matches the in-app cooldown

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/register") {
      return handleRegister(request, env);
    }
    if (request.method === "GET" && url.pathname === "/health") {
      return new Response("ok");
    }
    return new Response("Not found", { status: 404 });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(checkAndFire(env));
  },
};

// ── Registration ────────────────────────────────────────────────────────────

async function handleRegister(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }

  const { token, alerts } = body;
  if (typeof token !== "string" || !/^[0-9a-fA-F]{8,}$/.test(token)) {
    return json({ error: "invalid token" }, 400);
  }

  const key = `device:${token}`;
  const existing = (await env.ALERTS.get(key, "json")) || { fired: {} };
  const prevFired = existing.fired || {};

  const cleanAlerts = (Array.isArray(alerts) ? alerts : []).filter(
    (a) =>
      a &&
      typeof a.id === "string" &&
      typeof a.targetPrice === "number" &&
      (a.direction === "above" || a.direction === "below"),
  );

  // Carry forward fired-state only for alerts that still exist.
  const fired = {};
  for (const a of cleanAlerts) {
    if (prevFired[a.id] != null) fired[a.id] = prevFired[a.id];
  }

  await env.ALERTS.put(
    key,
    JSON.stringify({ token, alerts: cleanAlerts, fired, updatedAt: Date.now() }),
  );

  // Echo fired-state back so the client can mark those alerts fired/disabled
  // and avoid double-firing them in the foreground.
  return json({ fired });
}

// ── Cron: price check + push ─────────────────────────────────────────────────

async function checkAndFire(env) {
  const price = await fetchPrice();
  if (price == null) return;

  const jwt = await getApnsJwt(env);
  let cursor;

  do {
    const list = await env.ALERTS.list({ prefix: "device:", cursor });
    cursor = list.list_complete ? null : list.cursor;

    for (const entry of list.keys) {
      const record = await env.ALERTS.get(entry.name, "json");
      if (!record || !Array.isArray(record.alerts)) continue;

      let changed = false;
      let dropped = false;

      for (const alert of record.alerts) {
        if (alert.enabled === false) continue;

        const crossed =
          alert.direction === "above"
            ? price >= alert.targetPrice
            : price <= alert.targetPrice;
        if (!crossed) continue;

        const last = record.fired[alert.id];
        if (last && !alert.repeating) continue; // one-shot already fired
        if (last && Date.now() - last < COOLDOWN_MS) continue; // cooldown

        const result = await sendPush(env, jwt, record.token, alert, price);
        if (result === "unregistered") {
          await env.ALERTS.delete(entry.name);
          dropped = true;
          break;
        }
        if (result === true) {
          record.fired[alert.id] = Date.now();
          changed = true;
        }
      }

      if (changed && !dropped) {
        await env.ALERTS.put(entry.name, JSON.stringify(record));
      }
    }
  } while (cursor);
}

async function fetchPrice() {
  try {
    const res = await fetch(COINBASE_URL, { cf: { cacheTtl: 0 } });
    const data = await res.json();
    const amount = parseFloat(data?.data?.amount);
    return Number.isFinite(amount) ? amount : null;
  } catch {
    return null;
  }
}

// ── APNs ─────────────────────────────────────────────────────────────────────

async function sendPush(env, jwt, token, alert, price) {
  const fmt = (n) => "$" + Math.round(n).toLocaleString("en-US");
  const dir = alert.direction === "above" ? "above" : "below";
  const title =
    alert.label && alert.label.length ? alert.label : "Bitcoin Price Alert";
  const bodyText = `BTC is now ${fmt(price)} — ${dir} your target of ${fmt(alert.targetPrice)}`;

  const payload = JSON.stringify({
    aps: { alert: { title, body: bodyText }, sound: "default" },
  });
  const headers = {
    authorization: `bearer ${jwt}`,
    "apns-topic": env.APNS_BUNDLE_ID,
    "apns-push-type": "alert",
    "apns-priority": "10",
  };

  // Production tokens come from TestFlight/App Store builds; sandbox tokens
  // come from builds run directly via Xcode. Try prod first, fall back to
  // sandbox so the same server works for both.
  for (const host of [APNS_HOST_PROD, APNS_HOST_SANDBOX]) {
    let res;
    try {
      res = await fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers,
        body: payload,
      });
    } catch {
      return false;
    }
    if (res.status === 200) return true;

    const err = await res.json().catch(() => ({}));
    const reason = err.reason;
    if (reason === "BadDeviceToken" || reason === "Unregistered") {
      // Wrong environment for this host — try the other one. If both reject
      // the token, it's dead; tell the caller to delete it.
      if (host === APNS_HOST_SANDBOX) return "unregistered";
      continue;
    }
    // ExpiredProviderToken etc. — give up on this device for now.
    return false;
  }
  return false;
}

// APNs provider tokens may be reused for up to an hour and must not be
// regenerated too often, so cache the signed JWT in KV.
async function getApnsJwt(env) {
  const cached = await env.ALERTS.get("apns:jwt", "json");
  if (cached && Date.now() - cached.iat < 30 * 60 * 1000) return cached.jwt;

  const header = { alg: "ES256", kid: env.APNS_KEY_ID };
  const payload = { iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };
  const enc = (obj) => base64url(new TextEncoder().encode(JSON.stringify(obj)));
  const signingInput = `${enc(header)}.${enc(payload)}`;

  const key = await importPrivateKey(env.APNS_KEY_P8);
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64url(new Uint8Array(sig))}`;
  await env.ALERTS.put("apns:jwt", JSON.stringify({ jwt, iat: Date.now() }), {
    expirationTtl: 3600,
  });
  return jwt;
}

async function importPrivateKey(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

// ── helpers ──────────────────────────────────────────────────────────────────

function base64url(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}
