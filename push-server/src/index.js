// TapBTC push backend — Cloudflare Worker
//
// Jobs:
//   1. POST /register  — a device uploads its APNs token + alerts + preferences
//   2. cron (1/min)    — fetch BTC price + block height, then send APNs pushes:
//        - custom price alerts (per-device thresholds)
//        - new all-time high alerts (global)
//        - halving countdown / block milestone alerts (global)
//
// This is what makes alerts fire when the app is closed or force-quit: the
// monitoring happens here, on an always-on server, not on the phone.
//
// All devices live under a single KV key (DEVICES_KEY) so the cron does one
// read per tick instead of a KV list() — list() every minute would exceed the
// free tier's 1,000-list/day limit.

const COINBASE_URL = "https://api.coinbase.com/v2/prices/BTC-USD/spot";
const BLOCK_URL = "https://blockstream.info/api/blocks/tip/height";
const GECKO_CHANGE_URL =
  "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true";
const VOLATILITY_COOLDOWN_MS = 12 * 60 * 60 * 1000; // 12h between volatility pushes

const CURRENCY_SYMBOLS = {
  usd: "$", eur: "€", gbp: "£", cad: "$", aud: "$", jpy: "¥",
};

function fmtCur(value, currency) {
  const sym = CURRENCY_SYMBOLS[currency] || "$";
  return sym + Math.round(value).toLocaleString("en-US");
}
const APNS_HOST_PROD = "https://api.push.apple.com";
const APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com";
const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour, matches the in-app cooldown
const DEVICES_KEY = "devices";
const JWT_KEY = "apns:jwt";
const ATH_KEY = "global:ath";
const MILESTONES_KEY = "global:milestones";

// Seed so a fresh deploy doesn't false-alert; client registrations bump this
// with the real ATH from CoinGecko.
const ATH_SEED = 126080;

const HALVING_INTERVAL = 210000;
// Alert when this many blocks remain until the halving (0 = the halving itself)
const HALVING_STEPS = [100000, 75000, 50000, 25000, 10000, 5000, 1000, 0];
// Round-number block heights worth celebrating
const ROUND_BLOCKS = [1000000];

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
    ctx.waitUntil(tick(env));
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

  const { token, alerts, athAlert, milestoneAlert, knownATH,
          volatility, briefing, holdings, currency, invested, investedBTC } = body;
  if (typeof token !== "string" || !/^[0-9a-fA-F]{8,}$/.test(token)) {
    return json({ error: "invalid token" }, 400);
  }

  const cleanAlerts = (Array.isArray(alerts) ? alerts : []).filter(
    (a) =>
      a &&
      typeof a.id === "string" &&
      typeof a.targetPrice === "number" &&
      (a.direction === "above" || a.direction === "below"),
  );

  const devices = (await env.ALERTS.get(DEVICES_KEY, "json")) || {};
  const prev = devices[token] || {};
  const prevFired = prev.fired || {};

  // Carry forward fired-state only for alerts that still exist.
  const fired = {};
  for (const a of cleanAlerts) {
    if (prevFired[a.id] != null) fired[a.id] = prevFired[a.id];
  }

  // Volatility (Pro): { enabled, threshold }
  let vol = null;
  if (volatility && volatility.enabled && typeof volatility.threshold === "number") {
    vol = { enabled: true, threshold: Math.max(1, Math.min(50, volatility.threshold)) };
  }
  // Daily briefing (Pro): { enabled, hour, tz(minutes) }
  let brief = null;
  if (briefing && briefing.enabled &&
      typeof briefing.hour === "number" && typeof briefing.tz === "number") {
    brief = {
      enabled: true,
      hour: Math.max(0, Math.min(23, Math.round(briefing.hour))),
      tz: Math.round(briefing.tz),
    };
  }

  const cur = typeof currency === "string" && CURRENCY_SYMBOLS[currency] ? currency : "usd";

  devices[token] = {
    alerts: cleanAlerts,
    fired,
    currency: cur,
    athAlert: athAlert !== false,
    milestoneAlert: milestoneAlert !== false,
    volatility: vol,
    volFired: prev.volFired || 0,
    briefing: brief,
    lastBriefingDay: prev.lastBriefingDay || "",
    holdings: typeof holdings === "number" && holdings > 0 ? holdings : 0,
    invested: typeof invested === "number" && invested > 0 ? invested : 0,
    investedBTC: typeof investedBTC === "number" && investedBTC > 0 ? investedBTC : 0,
    updatedAt: Date.now(),
  };
  await env.ALERTS.put(DEVICES_KEY, JSON.stringify(devices));

  // Let clients teach the server the real ATH (from CoinGecko).
  if (typeof knownATH === "number" && knownATH > 0) {
    const ath = (await env.ALERTS.get(ATH_KEY, "json")) || { value: ATH_SEED };
    if (knownATH > ath.value) {
      ath.value = knownATH;
      await env.ALERTS.put(ATH_KEY, JSON.stringify(ath));
    }
  }

  // Echo fired-state back so the client can mark those alerts fired/disabled
  // and avoid double-firing them in the foreground.
  return json({ fired });
}

// ── Cron tick ────────────────────────────────────────────────────────────────

async function tick(env) {
  const devices = await env.ALERTS.get(DEVICES_KEY, "json");
  if (!devices || Object.keys(devices).length === 0) return;

  const price = await fetchPrice(); // USD base (used for ATH)

  // Fetch a price for each currency actually in use.
  const priceByCur = { usd: price };
  const inUse = new Set();
  for (const d of Object.values(devices)) if (d && d.currency) inUse.add(d.currency);
  for (const c of inUse) {
    if (c !== "usd" && priceByCur[c] === undefined) priceByCur[c] = await fetchPriceFor(c);
  }

  const state = { env, devices, jwt: null, devicesChanged: false, priceByCur };

  // Only pay for the CoinGecko 24h-change call if some device needs it.
  const needsChange = Object.values(devices).some(
    (d) => d && ((d.volatility && d.volatility.enabled) || (d.briefing && d.briefing.enabled)),
  );
  const change = needsChange ? await fetchChange24h() : null;

  if (price != null) {
    await checkPriceAlerts(state);
    await checkATH(state, price);
    if (change != null) await checkVolatility(state, change);
    await checkBriefing(state, change);
  }
  await checkMilestones(state);

  if (state.devicesChanged) {
    await env.ALERTS.put(DEVICES_KEY, JSON.stringify(state.devices));
  }
}

// ── Custom price alerts ──────────────────────────────────────────────────────

async function checkPriceAlerts(state) {
  for (const token of Object.keys(state.devices)) {
    const record = state.devices[token];
    if (!record || !Array.isArray(record.alerts)) continue;

    // Alert thresholds are entered in the device's display currency.
    const cur = record.currency || "usd";
    const price = state.priceByCur[cur];
    if (price == null) continue;

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

      const title =
        alert.label && alert.label.length ? alert.label : "Bitcoin Price Alert";
      const dir = alert.direction === "above" ? "above" : "below";
      const body = `BTC is now ${fmtCur(price, cur)} — ${dir} your target of ${fmtCur(alert.targetPrice, cur)}`;

      const result = await deliver(state, token, title, body);
      if (result === "unregistered") break; // device deleted; skip its remaining alerts
      if (result === true) {
        record.fired[alert.id] = Date.now();
        state.devicesChanged = true;
      }
    }
  }
}

// ── All-time high alerts (global) ────────────────────────────────────────────

async function checkATH(state, price) {
  const ath = (await state.env.ALERTS.get(ATH_KEY, "json")) || {
    value: ATH_SEED,
    lastAlert: 0,
  };
  if (price <= ath.value) return;

  const fmt = "$" + Math.round(price).toLocaleString("en-US");
  const shouldAlert = Date.now() - (ath.lastAlert || 0) > COOLDOWN_MS;

  if (shouldAlert) {
    for (const token of Object.keys(state.devices)) {
      if (state.devices[token]?.athAlert === false) continue;
      await deliver(
        state,
        token,
        "New All-Time High 🚀",
        `Bitcoin just hit ${fmt} — a new all-time high!`,
      );
    }
    ath.lastAlert = Date.now();
  }

  // Track the new high even when inside the alert cooldown.
  ath.value = price;
  await state.env.ALERTS.put(ATH_KEY, JSON.stringify(ath));
}

// ── Halving countdown / block milestones (global) ────────────────────────────

async function checkMilestones(state) {
  const height = await fetchBlockHeight();
  if (height == null) return;

  const nextHalving = Math.ceil(height / HALVING_INTERVAL) * HALVING_INTERVAL;
  const remaining = nextHalving - height;

  // Build the currently-satisfied milestone keys.
  const satisfied = [];
  for (const step of HALVING_STEPS) {
    if (remaining <= step) {
      satisfied.push({
        key: `h${nextHalving}-${step}`,
        title: step === 0 ? "The Bitcoin Halving 🟠" : "Halving Countdown ⛏️",
        body:
          step === 0
            ? `The halving is here — block ${nextHalving.toLocaleString("en-US")} reached. New era begins.`
            : `${step.toLocaleString("en-US")} blocks until the next Bitcoin halving.`,
      });
    }
  }
  for (const round of ROUND_BLOCKS) {
    if (height >= round) {
      satisfied.push({
        key: `b${round}`,
        title: "Bitcoin Milestone 🎉",
        body: `Bitcoin just reached block ${round.toLocaleString("en-US")}.`,
      });
    }
  }

  let stored = await state.env.ALERTS.get(MILESTONES_KEY, "json");

  // First run: mark everything already passed as fired WITHOUT pushing, so a
  // fresh deploy doesn't spam historical milestones.
  if (!stored) {
    const fired = {};
    for (const m of satisfied) fired[m.key] = Date.now();
    await state.env.ALERTS.put(MILESTONES_KEY, JSON.stringify({ fired }));
    return;
  }

  let changed = false;
  for (const m of satisfied) {
    if (stored.fired[m.key]) continue;

    for (const token of Object.keys(state.devices)) {
      if (state.devices[token]?.milestoneAlert === false) continue;
      await deliver(state, token, m.title, m.body);
    }
    stored.fired[m.key] = Date.now();
    changed = true;
  }
  if (changed) {
    await state.env.ALERTS.put(MILESTONES_KEY, JSON.stringify(stored));
  }
}

// ── Volatility alerts (Pro, per-device) ──────────────────────────────────────

async function checkVolatility(state, change) {
  for (const token of Object.keys(state.devices)) {
    const d = state.devices[token];
    if (!d || !d.volatility || !d.volatility.enabled) continue;
    if (Math.abs(change) < d.volatility.threshold) continue;
    if (Date.now() - (d.volFired || 0) < VOLATILITY_COOLDOWN_MS) continue;

    const cur = d.currency || "usd";
    const price = state.priceByCur[cur];
    if (price == null) continue;

    const dir = change >= 0 ? "up" : "down";
    const arrow = change >= 0 ? "📈" : "📉";
    const result = await deliver(
      state,
      token,
      `Big Move ${arrow}`,
      `Bitcoin is ${dir} ${Math.abs(change).toFixed(1)}% in 24h — now ${fmtCur(price, cur)}.`,
    );
    if (result === "unregistered") continue;
    if (result === true) {
      d.volFired = Date.now();
      state.devicesChanged = true;
    }
  }
}

// ── Daily briefing (Pro, per-device, at the user's local hour) ────────────────

async function checkBriefing(state, change) {
  for (const token of Object.keys(state.devices)) {
    const d = state.devices[token];
    if (!d || !d.briefing || !d.briefing.enabled) continue;

    const cur = d.currency || "usd";
    const price = state.priceByCur[cur];
    if (price == null) continue;

    // Convert now → the device's local wall clock via its stored tz offset.
    const local = new Date(Date.now() + d.briefing.tz * 60000);
    const localHour = local.getUTCHours();
    const localDay = local.toISOString().slice(0, 10);

    if (localHour !== d.briefing.hour) continue;
    if (d.lastBriefingDay === localDay) continue; // already sent today

    let body = `Bitcoin is ${fmtCur(price, cur)}`;
    if (change != null) body += ` (${change >= 0 ? "+" : ""}${change.toFixed(1)}% 24h)`;
    if (d.holdings > 0) {
      const stack = fmtCur(d.holdings * price, cur);
      body += `. Your ${trimAmount(d.holdings)} BTC is worth ${stack}`;
      // Add P&L if we have a cost basis.
      if (d.investedBTC > 0 && d.invested > 0) {
        const pct = ((d.investedBTC * price) / d.invested - 1) * 100;
        body += ` (${pct >= 0 ? "+" : ""}${pct.toFixed(1)}%)`;
      }
      body += ".";
    } else {
      body += ".";
    }

    const result = await deliver(state, token, "Your Bitcoin Briefing ☀️", body);
    if (result === "unregistered") continue;
    if (result === true) {
      d.lastBriefingDay = localDay;
      state.devicesChanged = true;
    }
  }
}

function trimAmount(n) {
  // Up to 8 decimals, no trailing zeros.
  return parseFloat(n.toFixed(8)).toString();
}

// ── Data sources ─────────────────────────────────────────────────────────────

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

async function fetchPriceFor(currency) {
  try {
    const code = currency.toUpperCase();
    const res = await fetch(`https://api.coinbase.com/v2/prices/BTC-${code}/spot`, {
      cf: { cacheTtl: 0 },
    });
    const data = await res.json();
    const amount = parseFloat(data?.data?.amount);
    return Number.isFinite(amount) ? amount : null;
  } catch {
    return null;
  }
}

async function fetchChange24h() {
  try {
    const res = await fetch(GECKO_CHANGE_URL, { cf: { cacheTtl: 60 } });
    const data = await res.json();
    const c = data?.bitcoin?.usd_24h_change;
    return Number.isFinite(c) ? c : null;
  } catch {
    return null;
  }
}

async function fetchBlockHeight() {
  try {
    const res = await fetch(BLOCK_URL, { cf: { cacheTtl: 30 } });
    const text = await res.text();
    const h = parseInt(text.trim(), 10);
    return Number.isFinite(h) ? h : null;
  } catch {
    return null;
  }
}

// ── APNs delivery ────────────────────────────────────────────────────────────

// Sends one push. Lazily signs the JWT, and deletes dead devices in place.
async function deliver(state, token, title, body) {
  if (!state.jwt) state.jwt = await getApnsJwt(state.env);
  const result = await sendPush(state.env, state.jwt, token, title, body);
  if (result === "unregistered") {
    delete state.devices[token];
    state.devicesChanged = true;
  }
  return result;
}

async function sendPush(env, jwt, token, title, bodyText) {
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
  const cached = await env.ALERTS.get(JWT_KEY, "json");
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
  await env.ALERTS.put(JWT_KEY, JSON.stringify({ jwt, iat: Date.now() }), {
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
