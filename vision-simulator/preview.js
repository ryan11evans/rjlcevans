/*
 * One free look at a Pro simulation, on the live camera.
 * Ten seconds, then Normal Vision again with the unlock sheet.
 * The camera keeps streaming. One preview per condition per install.
 * If the camera is denied, the same preview runs on the tulip garden photo.
 * The filters are the app's own (see __vsPreviewApi). Nothing here sets a price.
 */
(function () {
  'use strict';

  var SPECS = {
    amd: {
      cond: 'amd',
      // End Stage preset: fully black central scotoma (about 12–15°),
      // soft irregular edge, metamorphopsia around it, sharp periphery.
      // Advanced is only ~15% of a phone frame wide, so it has no impact here.
      params: { amdSize: 60, amdDistortion: 0.6 },
      label: 'Macular degeneration',
      line: "That's what macular degeneration looks like.",
      usedLabel: 'Unlock macular degeneration'
    },
    glaucoma: {
      cond: 'glaucoma',
      params: { glaucomaStage: 4 },
      label: 'Severe glaucoma',
      line: "That's what severe glaucoma looks like.",
      usedLabel: 'Unlock severe glaucoma'
    },
    cataract: {
      cond: 'cataract',
      params: { cataractSev: 1 },
      label: 'Dense cataract',
      line: "That's what a dense cataract looks like.",
      usedLabel: 'Unlock dense cataract'
    }
  };

  var running = false;
  var timer = null;

  function readUsed() {
    try {
      var list = JSON.parse(localStorage.getItem('vs_previewUsed') || '[]');
      return Array.isArray(list) ? list : [];
    } catch (e) {
      return [];
    }
  }
  function isUsed(kind) { return readUsed().indexOf(kind) !== -1; }
  function markUsed(kind) {
    try {
      var list = readUsed();
      if (list.indexOf(kind) === -1) list.push(kind);
      localStorage.setItem('vs_previewUsed', JSON.stringify(list));
    } catch (e) {}
    refresh();
  }

  function duration() {
    var n = window.__vsPreviewMs;
    if (typeof n === 'number' && n >= 400 && n <= 10000) return n;
    return 10000;
  }

  function holdRedirect() {
    try { sessionStorage.setItem('vs_storeRedirected', '1'); } catch (e) {}
    try {
      if (typeof window.__vsCancelStoreRedirect === 'function') window.__vsCancelStoreRedirect();
    } catch (e2) {}
  }

  function refresh() {
    var nodes = document.querySelectorAll('[data-preview]');
    for (var i = 0; i < nodes.length; i++) {
      var btn = nodes[i];
      var kind = btn.getAttribute('data-preview');
      var spec = SPECS[kind];
      var used = isUsed(kind);
      btn.classList.toggle('is-used', used);
      var kick = btn.querySelector('.cc-kicker');
      if (kick) kick.textContent = used ? 'Preview used' : (btn.classList.contains('preview-hero') ? '10 seconds · Free' : '10 seconds');
      var name = btn.querySelector('.cc-name');
      if (used && spec && name) name.textContent = spec.usedLabel;
    }
  }

  function ensureHud() {
    var hud = document.getElementById('previewHud');
    if (hud) return hud;
    var stage = document.querySelector('.stage');
    if (!stage) return null;
    hud = document.createElement('div');
    hud.id = 'previewHud';
    hud.className = 'preview-hud';
    hud.hidden = true;
    hud.setAttribute('role', 'timer');
    hud.innerHTML = '<span class="preview-hud-name" id="previewHudName"></span><span class="preview-hud-count" id="previewHudCount" aria-live="polite"></span>';
    stage.appendChild(hud);
    return hud;
  }
  function showHud(label, seconds) {
    var hud = ensureHud();
    if (!hud) return;
    hud.hidden = false;
    var name = document.getElementById('previewHudName');
    var count = document.getElementById('previewHudCount');
    if (name) name.textContent = label;
    if (count && count.textContent !== String(seconds)) count.textContent = String(seconds);
  }
  function hideHud() {
    var hud = document.getElementById('previewHud');
    if (hud) hud.hidden = true;
  }

  function waitForFrame() {
    return new Promise(function (resolve) {
      var canvas = document.getElementById('stageCanvas');
      var t0 = Date.now();
      function tick() {
        if (canvas && canvas.width > 2) {
          try {
            // Read a 1×1 copy so the full stage bitmap is not pulled back
            // from the GPU on every frame while we wait for the first image.
            if (!waitForFrame.probe) {
              waitForFrame.probe = document.createElement('canvas');
              waitForFrame.probe.width = waitForFrame.probe.height = 1;
              waitForFrame.pctx = waitForFrame.probe.getContext('2d', { willReadFrequently: true });
            }
            var pctx = waitForFrame.pctx;
            pctx.drawImage(canvas, canvas.width >> 1, canvas.height >> 1, 1, 1, 0, 0, 1, 1);
            var c = pctx.getImageData(0, 0, 1, 1).data;
            if (c[0] + c[1] + c[2] > 12) { resolve(true); return; }
          } catch (e) { resolve(true); return; }
        }
        if (Date.now() - t0 > 5000) { resolve(true); return; }
        requestAnimationFrame(tick);
      }
      tick();
    });
  }

  function finish(spec) {
    if (timer) { clearInterval(timer); timer = null; }
    running = false;
    hideHud();
    var api = window.__vsPreviewApi;
    if (!api) return;
    // Remove the effect only. freeze() used to stop the camera track and
    // cancel the draw loop, which left the last filtered frame on screen
    // for macular degeneration, glaucoma, and cataract alike.
    if (typeof api.restoreLive === 'function') api.restoreLive();
    api.openUnlock(spec);
  }

  function specFor(kind, override) {
    var base = SPECS[kind];
    if (!base) return null;
    if (!override || !override.params) return base;
    return {
      cond: base.cond,
      params: override.params,
      label: override.label || base.label,
      line: override.line || base.line,
      usedLabel: base.usedLabel
    };
  }

  function begin(kind, override) {
    var spec = specFor(kind, override);
    var api = window.__vsPreviewApi;
    if (!spec || !api || running) return;
    if (isUsed(kind)) { api.openUnlock(SPECS[kind]); return; }
    running = true;
    api.enter();
    api.apply(spec);
    var camOk = false;
    Promise.resolve(api.startCamera()).then(function (ok) {
      camOk = !!ok;
      if (camOk) return true;
      return api.showGarden();
    }).then(function (ok) {
      if (!running) return;
      if (!ok) {
        running = false;
        api.leave();
        return;
      }
      return waitForFrame().then(function () {
        if (!running) return;
        markUsed(kind);
        var ends = Date.now() + duration();
        showHud(spec.label, Math.max(1, Math.ceil((ends - Date.now()) / 1000)));
        timer = setInterval(function () {
          var left = ends - Date.now();
          if (left <= 0) { finish(spec); return; }
          showHud(spec.label, Math.max(1, Math.ceil(left / 1000)));
        }, 200);
      });
    }).catch(function () {
      running = false;
      hideHud();
      if (window.__vsPreviewApi) window.__vsPreviewApi.leave();
    });
  }

  window.__vsConsumePreviewPending = function () {
    var pending = window.__vsPreviewPending;
    window.__vsPreviewPending = null;
    if (!pending || !SPECS[pending.kind]) return;
    if (pending.mode === 'paywall') {
      if (window.__vsPreviewApi) window.__vsPreviewApi.openUnlock(SPECS[pending.kind]);
      return;
    }
    begin(pending.kind, pending.override);
  };

  // In-app entry. override.params replaces the stored preset (the first-open
  // look is advanced macular degeneration; the gate button stays end stage).
  // A used condition opens the unlock sheet. The used list is vs_previewUsed.
  window.__vsRunPreview = function (kind, override) {
    if (!SPECS[kind]) return;
    holdRedirect();
    if (isUsed(kind)) {
      if (window.__vsPreviewApi) window.__vsPreviewApi.openUnlock(SPECS[kind]);
      else {
        window.__vsPreviewPending = { mode: 'paywall', kind: kind };
        if (typeof window.__vsBootForPreview === 'function') window.__vsBootForPreview();
      }
      return;
    }
    if (window.__vsPreviewApi) begin(kind, override);
    else {
      window.__vsPreviewPending = { mode: 'run', kind: kind, override: override || null };
      if (typeof window.__vsBootForPreview === 'function') window.__vsBootForPreview();
    }
  };
  window.__vsPreviewIsUsed = function (kind) { return isUsed(kind); };

  window.__vsPreviewOnClose = function () {
    if (!document.documentElement.classList.contains('preview-mode')) return;
    if (timer) { clearInterval(timer); timer = null; }
    running = false;
    hideHud();
    if (window.__vsPreviewApi) window.__vsPreviewApi.leave();
  };

  function launch(kind) {
    if (!SPECS[kind]) return;
    holdRedirect();
    if (isUsed(kind)) {
      if (window.__vsPreviewApi) window.__vsPreviewApi.openUnlock(SPECS[kind]);
      else {
        window.__vsPreviewPending = { mode: 'paywall', kind: kind };
        if (typeof window.__vsBootForPreview === 'function') window.__vsBootForPreview();
      }
      return;
    }
    if (window.__vsPreviewApi) begin(kind);
    else {
      window.__vsPreviewPending = { mode: 'run', kind: kind };
      if (typeof window.__vsBootForPreview === 'function') window.__vsBootForPreview();
    }
  }

  function bind() {
    var nodes = document.querySelectorAll('[data-preview]');
    for (var i = 0; i < nodes.length; i++) {
      (function (btn) {
        if (btn.dataset.previewBound) return;
        btn.dataset.previewBound = '1';
        btn.addEventListener('pointerdown', holdRedirect);
        btn.addEventListener('click', function () { launch(btn.getAttribute('data-preview')); });
      })(nodes[i]);
    }
    refresh();
  }

  function injectStyle() {
    if (document.getElementById('preview-style')) return;
    var css = [
      '.preview-hud{position:absolute;z-index:14;left:50%;top:calc(14px + env(safe-area-inset-top));transform:translateX(-50%);',
      'display:flex;flex-direction:column;align-items:center;gap:2px;min-width:148px;padding:10px 18px 12px;border-radius:18px;',
      'background:rgba(8,11,16,0.72);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);',
      'box-shadow:0 8px 28px rgba(0,0,0,0.35);pointer-events:none;}',
      '.preview-hud[hidden]{display:none !important;}',
      '.preview-hud-name{font-size:13px;font-weight:600;letter-spacing:0.04em;text-transform:uppercase;color:#d4a574;}',
      '.preview-hud{contain:layout;}',
      '.preview-hud-count{font-family:"VS Fraunces","Fraunces",Georgia,serif;font-size:44px;line-height:1;font-weight:500;color:#fff;font-variant-numeric:tabular-nums;min-width:1.4ch;text-align:center;}',
      'html.preview-mode.is-browser .stage-wrap{display:block !important;position:fixed !important;inset:0;z-index:80;',
      'width:100% !important;height:100% !important;max-height:none !important;aspect-ratio:auto !important;margin:0 !important;border-radius:0;}',
      'html.is-browser:not(.preview-mode) body > .stage-wrap{display:none !important;}',
      'html.preview-mode #backToSite{display:none !important;}',
      'html.is-browser .paywall-overlay.preview-unlock.open{display:flex !important;align-items:flex-end;padding:0;}',
      'html.preview-mode .paywall-overlay.preview-unlock .paywall-panel{width:100%;max-width:560px;border-radius:24px 24px 0 0;',
      'padding-bottom:calc(18px + env(safe-area-inset-bottom));}',
      '.paywall-overlay.preview-unlock{background:transparent;backdrop-filter:none;-webkit-backdrop-filter:none;',
      'pointer-events:none;align-items:flex-end;padding:0;}',
      '.paywall-overlay.preview-unlock .paywall-panel{pointer-events:auto;}'
    ].join('');
    var style = document.createElement('style');
    style.id = 'preview-style';
    style.textContent = css;
    document.head.appendChild(style);
  }

  function boot() {
    injectStyle();
    bind();
    if (window.__vsPreviewPending && window.__vsPreviewApi) window.__vsConsumePreviewPending();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
