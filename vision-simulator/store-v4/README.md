# App Store screenshots v4 (UI v2)

1. Serve the UI v2 app (`cursor/vision-sim-ui-polish`, or the staging copy) on :8936, then run `python3 capture_store_v4.py`. It writes the raw screens to `../screens/`. These are iPhone 1260×2736 and iPad 2064×2752 captures with the iOS WebView emulated: Capacitor is present, StoreKit is mocked at $4.99, and `ctx.filter` is off.
2. Serve this folder on :8938, then run `python3 export_store_v4.py`. It renders `iphone-screenshots.html` and `ipad-screenshots.html`, which keep the same 5 concepts and captions as v2, into 1320×2868 and 2064×2752 RGB PNGs.

Shots 1 (hero) and 4 (color vision) use the tap-to-hide full-screen view with Compare on.
