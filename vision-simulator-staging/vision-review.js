/*
 * App Store review prompt for the Vision Simulator iOS app.
 *
 * Calls SKStoreReviewController.requestReview through the Capacitor
 * InAppReview plugin. One request per install (localStorage vs_reviewAsked).
 * Apple may still choose not to show the dialog.
 *
 * Positive moments that can ask, whichever comes first:
 *   - the user finishes a free challenge
 *   - the user has opened 3 distinct conditions (free ones count)
 *   - a Pro purchase just succeeded
 *
 * Does nothing on the plain web, and nothing in a binary that does not
 * include the plugin. Never asks while a paywall, About sheet, or challenge
 * is covering the screen.
 */
(function () {
  'use strict';

  var AFTER_DISTINCT = 3;
  var DELAY_MS = 1800;
  var timer = null;
  var pending = false;

  function nativeApp() {
    var cap = window.Capacitor;
    if (!cap) return false;
    try {
      if (typeof cap.getPlatform === 'function' && cap.getPlatform() === 'web') return false;
      if (typeof cap.isNativePlatform === 'function' && !cap.isNativePlatform()) return false;
    } catch (e) {
      return false;
    }
    return true;
  }

  function plugin() {
    var cap = window.Capacitor;
    if (!nativeApp() || !cap || typeof cap.isPluginAvailable !== 'function') return null;
    try {
      if (!cap.isPluginAvailable('InAppReview')) return null;
    } catch (e) {
      return null;
    }
    var api = null;
    try {
      api = typeof cap.registerPlugin === 'function'
        ? cap.registerPlugin('InAppReview')
        : (cap.Plugins && cap.Plugins.InAppReview);
    } catch (e2) {
      return null;
    }
    return api && typeof api.requestReview === 'function' ? api : null;
  }

  function alreadyAsked() {
    try { return localStorage.getItem('vs_reviewAsked') === '1'; } catch (e) { return true; }
  }

  function modalOpen() {
    return !!document.querySelector('.paywall-overlay.open, .sheet-overlay.open, .challenge-overlay.open, [role="dialog"].open');
  }

  function fire(triesLeft) {
    timer = null;
    try {
      if (alreadyAsked()) { pending = false; return; }
      var api = plugin();
      if (!api) { pending = false; return; }
      if (modalOpen() || document.hidden) {
        if (triesLeft > 0) timer = setTimeout(function () { fire(triesLeft - 1); }, 1000);
        else pending = false;
        return;
      }
      try { localStorage.setItem('vs_reviewAsked', '1'); } catch (e) { pending = false; return; }
      pending = false;
      Promise.resolve(api.requestReview()).catch(function () {});
    } catch (e2) {
      pending = false;
    }
  }

  function schedule() {
    try {
      if (pending || timer || alreadyAsked() || !plugin()) return;
      pending = true;
      timer = setTimeout(function () { fire(60); }, DELAY_MS);
    } catch (e) {}
  }

  function readSeen() {
    try {
      var seen = JSON.parse(localStorage.getItem('vs_condsSeen') || '[]');
      return Array.isArray(seen) ? seen : [];
    } catch (e) {
      return [];
    }
  }

  // Records condition keys. Does not ask. The launch preview uses this so the
  // condition already on screen counts, without prompting by itself.
  function markSeen(keys) {
    try {
      var seen = readSeen();
      (keys || []).forEach(function (k) {
        if (k && k !== 'none' && seen.indexOf(k) === -1) seen.push(k);
      });
      localStorage.setItem('vs_condsSeen', JSON.stringify(seen));
      return seen.length;
    } catch (e) {
      return 0;
    }
  }

  function noteConditions(keys) {
    var count = markSeen(keys);
    if (count >= AFTER_DISTINCT) schedule();
  }

  // A finished challenge, or a Pro purchase that just went through.
  function notePositive() {
    schedule();
  }

  window.VisionReview = {
    markSeen: markSeen,
    noteConditions: noteConditions,
    notePositive: notePositive
  };
})();
