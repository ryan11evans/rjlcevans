# Bitcoin Watch — Setup Guide

## What this app does

- **iPhone**: Fetches BTC price every **15 seconds** while open, every ~10-15 min in background
- **Watch complication**: Updates via iPhone push (`transferCurrentComplicationUserInfo`) — this is the **fastest legal path** for Watch complications, using the dedicated 50/day complication budget; when the Watch app is open it fetches directly every **10 seconds**
- **iPhone widgets**: Refreshes every ~10 minutes (WidgetKit minimum)
- **Lock Screen widgets**: Same complication-style widgets on iPhone lock screen
- **API**: Coinbase public API — free, no key needed

## Why this is faster than other apps

The trick is the **iPhone as a relay**. Watch complications have a ~50 refresh/day system budget on their own. But `transferCurrentComplicationUserInfo()` is a separate budget that wakes the watch app and reloads the complication with **complication priority** — iOS/watchOS lets this happen whenever the phone has internet, independent of the normal background task scheduler. Result: as long as your iPhone is active (which it usually is), the Watch complication updates with each iPhone refresh.

## First-time Xcode Setup

### Option A — XcodeGen (recommended, 2 minutes)

```bash
brew install xcodegen
cd bitcoin-watch
xcodegen generate
open BitcoinWatch.xcodeproj
```

### Option B — Manual

1. Open Xcode → File → New → Project → iOS App (SwiftUI, Swift)
   - Product Name: `BitcoinWatch`
   - Bundle ID: `com.rjlcevans.bitcoinwatch`
2. Add Watch App target: File → New → Target → watchOS → Watch App
   - Include Complications: ✓
3. Add Widget Extension target: File → New → Target → iOS → Widget Extension
4. Replace the generated source files with the ones in this repo
5. Add `Shared/BitcoinPrice.swift` to all three targets

### Required Xcode configuration

1. **App Groups** — add `group.com.rjlcevans.bitcoinwatch` to all three targets in Signing & Capabilities
2. **Background Modes** (iPhone target) — enable:
   - Background fetch
   - Background processing
3. **WatchConnectivity** — linked automatically; no extra steps
4. **Complication Principal Class** — already in `WatchApp/App/Info.plist`

### Bundle IDs

| Target | Bundle ID |
|--------|-----------|
| iPhone app | `com.rjlcevans.bitcoinwatch` |
| Widget | `com.rjlcevans.bitcoinwatch.widget` |
| Watch app | `com.rjlcevans.bitcoinwatch.watchkitapp` |

Replace `rjlcevans` with your own reverse-domain if you prefer.

## File structure

```
bitcoin-watch/
├── Shared/
│   └── BitcoinPrice.swift          ← shared model + UserDefaults helpers
├── BitcoinWatch/                   ← iPhone app
│   ├── App/
│   │   ├── BitcoinWatchApp.swift
│   │   └── Info.plist
│   ├── Services/
│   │   ├── PriceService.swift      ← fetches price, drives Watch push
│   │   ├── ConnectivityManager.swift ← WCSession sender
│   │   └── BackgroundRefresh.swift ← BGAppRefreshTask
│   └── Views/
│       ├── ContentView.swift
│       └── PriceChartView.swift
├── BitcoinWatchWidget/             ← WidgetKit extension
│   └── BitcoinWatchWidget.swift
└── WatchApp/                       ← watchOS app
    ├── App/
    │   ├── BitcoinWatchWatchApp.swift
    │   ├── WatchPriceService.swift
    │   ├── WatchConnectivityReceiver.swift
    │   └── Info.plist
    ├── Views/
    │   └── WatchContentView.swift
    └── Complications/
        └── ComplicationController.swift  ← all complication families
```
