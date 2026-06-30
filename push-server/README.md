# TapBTC Push Backend

A tiny Cloudflare Worker that makes Bitcoin price alerts fire **even when the
app is closed or force-quit**. It polls the BTC price once a minute and sends a
real APNs push notification whenever one of your alert thresholds is crossed.

There is no on-device background work involved — iOS can't reliably do this — so
all the monitoring lives here.

---

## One-time setup

You'll do this once. Total time ~15 minutes. Everything is free at this scale
(Cloudflare's free tier covers cron + KV easily).

### 1. Create an APNs Auth Key (Apple)

1. Go to <https://developer.apple.com/account/resources/authkeys/list>
2. Click **+**, name it `TapBTC Push`, check **Apple Push Notifications service (APNs)**, Continue → Register.
3. **Download** the `.p8` file (you can only download it once). Keep it safe.
4. Note the **Key ID** (10 chars, shown on that page).
5. Note your **Team ID** — top-right of the developer portal, or under Membership (10 chars).

### 2. Install Wrangler and log in

```bash
cd push-server
npm install
npx wrangler login
```

### 3. Create the KV namespace

```bash
npx wrangler kv namespace create ALERTS
```

Copy the printed `id` into `wrangler.toml`, replacing `REPLACE_WITH_KV_NAMESPACE_ID`.

### 4. Set the three secrets

```bash
# Key ID from step 1.4
npx wrangler secret put APNS_KEY_ID

# Team ID from step 1.5
npx wrangler secret put APNS_TEAM_ID

# Paste the FULL contents of the .p8 file, including the
# -----BEGIN PRIVATE KEY----- / -----END PRIVATE KEY----- lines.
npx wrangler secret put APNS_KEY_P8
```

(The bundle id `com.rjlcevans.rjlbtcwatch` is already set in `wrangler.toml`
under `[vars]` — change it there if your bundle id differs.)

### 5. Deploy

```bash
npx wrangler deploy
```

Wrangler prints the live URL, e.g.

```
https://tapbtc-push.<your-subdomain>.workers.dev
```

### 6. Point the app at it

Open `bitcoin-watch/BitcoinWatch/Services/PushService.swift` and set
`serverURL` to that URL. Rebuild and upload to TestFlight.

---

## Verifying it works

- `curl https://tapbtc-push.<your-subdomain>.workers.dev/health` → `ok`
- Watch live logs while testing: `npx wrangler tail`
- In the app, add an alert just above or below the current price, then close the
  app completely. Within ~1 minute of the price crossing, you should get a push.

## How it fits together

```
 iPhone (app closed)            Cloudflare Worker                 Apple APNs
 ───────────────────            ─────────────────                 ──────────
 add/edit an alert  ──POST /register──▶  store token + alerts
                                         (KV)
                                cron 1/min:
                                  fetch BTC price (Coinbase)
                                  threshold crossed? ──push──▶  deliver to phone
```

- **Token environment** is handled automatically: the Worker tries the
  production APNs host first and falls back to sandbox, so it works for both
  TestFlight builds (production) and Xcode-run builds (sandbox).
- **Cooldown / one-shot** logic mirrors the in-app rules (1-hour cooldown for
  repeating alerts; non-repeating alerts fire once). The `/register` response
  echoes fired-state back to the app so it won't double-fire in the foreground.
- **Dead tokens** (uninstalled app) are deleted automatically when APNs reports
  them unregistered.
