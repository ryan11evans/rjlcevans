/*
 * Decide whether this page is running inside the Vision Simulator iOS app.
 *
 * Fail open: any uncertainty returns true (run the simulator). A normal
 * browser returns false. Locking a real app user out of the simulator is
 * worse than briefly showing the simulator to a browser we can't classify.
 *
 * Installed builds load this page from https://rjlcevans.com/vision-simulator/.
 * Capacitor injects window.Capacitor at document start, including builds that
 * predate the in-app purchase plugin. Older shells are also recognized via
 * cordova, the purchase plugin, and the WKWebView message handlers Capacitor
 * registers ("bridge"). This file is plain ES5 so a syntax error here cannot
 * take the app down; if it fails to load, index.html treats that as native.
 */
function isVisionSimulatorNativeApp() {
  try {
    var root = typeof window !== 'undefined' ? window : {};
    var cap = root.Capacitor;

    if (cap) {
      var platform = null;
      if (typeof cap.getPlatform === 'function') {
        try {
          platform = cap.getPlatform();
        } catch (e) {
          return true;
        }
      }
      if (platform && platform !== 'web') return true;

      if (typeof cap.isNativePlatform === 'function') {
        try {
          if (cap.isNativePlatform()) return true;
        } catch (e2) {
          return true;
        }
      }

      if (hasVisionSimulatorNativeBridge() || root.cordova || root.CdvPurchase || root.PhoneGap || root.phonegap) {
        return true;
      }

      // Capacitor's web runtime (or a test double) explicitly says this is a browser.
      if (platform === 'web') return false;
      if (typeof cap.isNativePlatform === 'function') return false;

      // window.Capacitor exists but has no platform API. That is an older or
      // partial native shell, not desktop Safari. Keep the simulator.
      return true;
    }

    if (root.cordova || root.CdvPurchase || root.PhoneGap || root.phonegap) return true;
    if (hasVisionSimulatorNativeBridge()) return true;

    var ua = '';
    try {
      ua = (typeof navigator !== 'undefined' && navigator.userAgent) || '';
    } catch (e3) {
      return true;
    }
    if (/Capacitor|Cordova/i.test(ua)) return true;

    return false;
  } catch (e4) {
    return true;
  }
}

function hasVisionSimulatorNativeBridge() {
  try {
    var root = typeof window !== 'undefined' ? window : {};
    var webkit = root.webkit;
    if (!webkit) return false;
    var handlers = webkit.messageHandlers;
    if (!handlers) return false;
    if (handlers.bridge || handlers.capacitor || handlers.cordova || handlers.cordova_iab) return true;
    return false;
  } catch (e) {
    return true;
  }
}

/* Link-preview and search crawlers should read this page, not follow the
 * App Store redirect. Humans still get the redirect. */
function isVisionSimulatorLinkPreview() {
  try {
    var ua = (typeof navigator !== 'undefined' && navigator.userAgent) || '';
    return /bot|crawler|spider|slurp|facebookexternalhit|facebot|embedly|quora link preview|whatsapp|telegrambot|slackbot|discordbot|pinterest|vkshare|redditbot|applebot|ia_archiver|linkedinbot|twitterbot/i.test(ua);
  } catch (e) {
    return false;
  }
}
