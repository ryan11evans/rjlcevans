/*
 * Free challenges: a color-vision dot plate and a blind-spot finder.
 *
 * The plates are drawn here from original paths and colors. They are not
 * scans of Ishihara plates or any other published test. Nothing in this
 * file is a diagnosis. The plain website can run the challenges; the App
 * Store review request lives in vision-review.js and no-ops without the
 * native plugin.
 */
(function () {
  'use strict';

  var STORE = 'https://apps.apple.com/app/id6772865195';

  // Figure/ground pairs sit on a deutan confusion line (Machado 2009) with
  // nearly the same luminance, so typical color vision reads the digit and
  // red-green deficiency tends to lose it. Brightness is a shared spatial
  // field, not a per-class random, so luminance edges don't redraw the digit.
  var PLATES = [
    { digit: '7', figure: [156, 126, 54], ground: [90, 150, 48], seed: 11 },
    { digit: '2', figure: [180, 132, 64], ground: [68, 164, 56], seed: 29 }
  ];

  var DEUTAN = [
    [0.367322, 0.860646, -0.227968],
    [0.280085, 0.672501, 0.047413],
    [-0.011820, 0.042940, 0.968881]
  ];

  var state = null;
  var spotTimer = null;
  var overlay, bodyEl;

  function host() {
    try {
      if (typeof window.__vsChallengeHost === 'function') return window.__vsChallengeHost() || { inApp: false, locked: false };
    } catch (e) {}
    return { inApp: false, locked: false };
  }

  function holdWebRedirect() {
    try { sessionStorage.setItem('vs_storeRedirected', '1'); } catch (e) {}
    try {
      if (typeof window.__vsCancelStoreRedirect === 'function') window.__vsCancelStoreRedirect();
    } catch (e2) {}
  }

  function haptic() {
    try {
      var h = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Haptics;
      if (h && h.impact) h.impact({ style: 'Light' });
    } catch (e) {}
  }

  function el(html) {
    bodyEl.innerHTML = html;
  }

  function $(sel) { return bodyEl.querySelector(sel); }

  function legal() {
    return '<p class="cx-legal">This is not a medical test.</p>';
  }

  function srgbToLin(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }
  function linToSrgb(c) {
    c = Math.min(1, Math.max(0, c));
    return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
  }
  function applyDeutan(rgb) {
    var l = rgb.map(function (v) { return srgbToLin(v / 255); });
    var o = [0, 0, 0];
    for (var i = 0; i < 3; i++) o[i] = DEUTAN[i][0] * l[0] + DEUTAN[i][1] * l[1] + DEUTAN[i][2] * l[2];
    return o.map(function (v) { return Math.round(Math.min(1, Math.max(0, linToSrgb(v))) * 255); });
  }
  function dist(a, b) {
    var d0 = a[0] - b[0], d1 = a[1] - b[1], d2 = a[2] - b[2];
    return Math.sqrt(d0 * d0 + d1 * d1 + d2 * d2);
  }

  function rng(seed) {
    var n = seed % 2147483647;
    if (n <= 0) n += 2147483646;
    return function () {
      n = (n * 48271) % 2147483647;
      return n / 2147483647;
    };
  }

  function drawDigit(ctx, digit, x, y, s) {
    ctx.save();
    ctx.fillStyle = '#fff';
    ctx.strokeStyle = '#fff';
    ctx.lineJoin = 'round';
    ctx.lineWidth = Math.max(2, s * 0.045);
    ctx.font = '900 ' + Math.round(s * 0.9) + 'px Arial, Helvetica, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.translate(x + s / 2, y + s / 2);
    ctx.strokeText(digit, 0, s * 0.02);
    ctx.fillText(digit, 0, s * 0.02);
    ctx.restore();
  }

  function fieldAt(x, y, seed) {
    var a = Math.sin(x * 0.017 + seed) * Math.cos(y * 0.014 + seed * 0.3);
    var b = Math.sin((x + y) * 0.006 + seed * 0.2);
    return 0.8 + 0.32 * (0.5 + 0.5 * (0.7 * a + 0.3 * b));
  }

  function rgbAt(base, k) {
    return 'rgb(' + base.map(function (v) {
      return Math.max(0, Math.min(255, Math.round(v * k)));
    }).join(',') + ')';
  }

  // Draws a plate into canvas. Returns mean figure/ground colors so a test
  // can confirm the digit is obvious in normal color and collapses under a
  // deutan simulation. `canvas` may be an offscreen canvas.
  function drawPlate(canvas, plate) {
    var css = canvas.clientWidth || canvas.width || 320;
    if (css < 40) css = 320;
    var dpr = Math.min((window.devicePixelRatio || 1), 2);
    var size = Math.round(css * dpr);
    canvas.width = size;
    canvas.height = size;
    var ctx = canvas.getContext('2d');
    var mask = document.createElement('canvas');
    mask.width = size;
    mask.height = size;
    var mctx = mask.getContext('2d');
    var glyph = size * 0.72;
    if (plate.digit) drawDigit(mctx, plate.digit, (size - glyph) / 2, (size - glyph) / 2 + size * 0.02, glyph);
    var maskData = mctx.getImageData(0, 0, size, size).data;

    var cx = size / 2, cy = size / 2, R = size / 2 - dpr;
    ctx.clearRect(0, 0, size, size);
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.clip();
    ctx.fillStyle = rgbAt(plate.ground, 0.86);
    ctx.fillRect(0, 0, size, size);

    var rand = rng(plate.seed);
    var gap = Math.max(8 * dpr, size / 15);
    var figSum = [0, 0, 0], gndSum = [0, 0, 0], figN = 0, gndN = 0;

    function paintDot(x, y, scale) {
      var dx = x - cx, dy = y - cy;
      var rad = gap * scale;
      if (dx * dx + dy * dy > (R - rad * 0.15) * (R - rad * 0.15)) return;
      var px = Math.max(0, Math.min(size - 1, x | 0));
      var py = Math.max(0, Math.min(size - 1, y | 0));
      var ink = maskData[(py * size + px) * 4 + 3] > 40;
      var k = fieldAt(x, y, plate.seed);
      var base = ink ? plate.figure : plate.ground;
      var col = base.map(function (v) { return Math.max(0, Math.min(255, v * k)); });
      if (ink) { figSum[0] += col[0]; figSum[1] += col[1]; figSum[2] += col[2]; figN++; }
      else { gndSum[0] += col[0]; gndSum[1] += col[1]; gndSum[2] += col[2]; gndN++; }
      ctx.beginPath();
      ctx.fillStyle = rgbAt(base, k);
      ctx.arc(x, y, rad, 0, Math.PI * 2);
      ctx.fill();
      ctx.lineWidth = Math.max(1, rad * 0.08);
      ctx.strokeStyle = 'rgba(30, 22, 8, 0.22)';
      ctx.stroke();
    }

    var y, x;
    for (y = gap * 0.35; y < size; y += gap) {
      for (x = gap * 0.35; x < size; x += gap) {
        paintDot(x + (rand() - 0.5) * gap * 0.55, y + (rand() - 0.5) * gap * 0.55, 0.42 + rand() * 0.28);
      }
    }
    for (y = gap * 0.85; y < size; y += gap) {
      for (x = gap * 0.85; x < size; x += gap) {
        paintDot(x + (rand() - 0.5) * gap * 0.35, y + (rand() - 0.5) * gap * 0.35, 0.22 + rand() * 0.16);
      }
    }
    for (var ang = 0; ang < Math.PI * 2; ang += 0.22) {
      var rr = R - gap * (0.28 + rand() * 0.22);
      paintDot(cx + Math.cos(ang) * rr, cy + Math.sin(ang) * rr, 0.36 + rand() * 0.2);
    }
    ctx.restore();
    ctx.beginPath();
    ctx.arc(cx, cy, R - dpr, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(90, 62, 28, 0.35)';
    ctx.lineWidth = Math.max(1, dpr);
    ctx.stroke();

    function mean(sum, n) {
      if (!n) return [0, 0, 0];
      return [sum[0] / n, sum[1] / n, sum[2] / n];
    }
    var fig = mean(figSum, figN);
    var gnd = mean(gndSum, gndN);
    return {
      normal: dist(fig, gnd),
      deutan: dist(applyDeutan(fig), applyDeutan(gnd)),
      figureDots: figN
    };
  }

  function measure(digit) {
    var plate = null;
    for (var i = 0; i < PLATES.length; i++) if (PLATES[i].digit === String(digit)) plate = PLATES[i];
    if (!plate) return null;
    var c = document.createElement('canvas');
    c.width = 280;
    c.height = 280;
    return drawPlate(c, plate);
  }

  function noteDone() {
    if (!state || !state.finished) return;
    state.finished = false;
    try { if (window.VisionReview) window.VisionReview.notePositive(); } catch (e) {}
  }

  function closeOverlay() {
    stopSpot();
    if (overlay) overlay.classList.remove('open');
    document.documentElement.classList.remove('challenge-open');
    noteDone();
    state = null;
  }

  function open(which) {
    if (which !== 'color' && which !== 'spot') return;
    holdWebRedirect();
    if (!overlay) boot();
    stopSpot();
    state = {
      which: which,
      phase: 'intro',
      plate: 0,
      correct: 0,
      answered: null,
      finished: false,
      eye: 'right',
      t: 0.12,
      auto: true
    };
    overlay.classList.add('open');
    overlay.setAttribute('data-challenge', which);
    overlay.setAttribute('data-phase', 'intro');
    document.documentElement.classList.add('challenge-open');
    render();
    var closeBtn = overlay.querySelector('.cx-close');
    if (closeBtn) closeBtn.focus();
  }

  function setPhase(phase) {
    state.phase = phase;
    overlay.setAttribute('data-phase', phase);
    render();
  }

  function ctaLabel() {
    var h = host();
    if (!h.inApp) return 'Get the app';
    if (h.locked) return 'See it with Pro';
    return 'Open the simulation';
  }

  function finishAnd(action) {
    var which = state.which;
    var condition = which === 'color' ? 'colorblind' : 'glaucoma';
    state.finished = true;
    closeOverlay();
    if (action === 'see') {
      var h = host();
      if (!h.inApp) {
        window.location.assign(STORE);
        return;
      }
      document.dispatchEvent(new CustomEvent('vs-challenge', {
        detail: { action: 'see', condition: condition }
      }));
    }
  }

  function otherChallenge() {
    var next = state && state.which === 'color' ? 'spot' : 'color';
    // Finishing the first challenge is already a good moment to ask. The
    // prompt waits until this overlay closes, so it won't cover the next one.
    if (state && state.finished) {
      state.finished = false;
      try { if (window.VisionReview) window.VisionReview.notePositive(); } catch (e) {}
    }
    open(next);
  }

  function renderColorIntro() {
    el(
      '<p class="cx-eyebrow">Free challenge</p>' +
      '<h2 class="cx-title" id="cxTitle">Can you see the number?</h2>' +
      '<p class="cx-copy">About 1 in 12 men can\u2019t pick a number out of a plate like this. The dots are original artwork drawn for this demo.</p>' +
      '<div class="cx-plate-wrap cx-plate-small" aria-hidden="true"><canvas id="cxDecor"></canvas></div>' +
      '<button type="button" class="cx-primary" id="cxNext">Show the plate</button>' +
      legal()
    );
    var decor = $('canvas');
    if (decor) {
      decor.width = 200;
      decor.height = 200;
      drawPlate(decor, { digit: '', figure: PLATES[0].figure, ground: PLATES[0].ground, seed: 3 });
    }
    $('button').addEventListener('click', function () { haptic(); setPhase('plate'); });
  }

  function renderPlate() {
    var plate = PLATES[state.plate];
    var n = state.plate + 1;
    el(
      '<p class="cx-eyebrow">Plate ' + n + ' of 2</p>' +
      '<h2 class="cx-title" id="cxTitle">What number do you see?</h2>' +
      '<div class="cx-plate-wrap"><canvas id="cxPlate" role="img" aria-label="Dot plate. The number is drawn in the colors of the dots."></canvas></div>' +
      '<div class="cx-keys" id="cxKeys" role="group" aria-label="Your answer"></div>' +
      legal()
    );
    var canvas = $('#cxPlate');
    drawPlate(canvas, plate);
    var keys = $('#cxKeys');
    var digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    digits.forEach(function (d) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'cx-key';
      b.textContent = d;
      b.setAttribute('data-answer', d);
      b.addEventListener('click', function () { choose(d); });
      keys.appendChild(b);
    });
    var none = document.createElement('button');
    none.type = 'button';
    none.className = 'cx-key cx-key-wide';
    none.textContent = 'No number';
    none.setAttribute('data-answer', 'none');
    none.addEventListener('click', function () { choose('none'); });
    keys.appendChild(none);
  }

  function choose(answer) {
    if (!state || state.phase !== 'plate') return;
    haptic();
    var plate = PLATES[state.plate];
    if (answer === plate.digit) state.correct += 1;
    state.answered = answer;
    if (state.plate >= PLATES.length - 1) setPhase('result');
    else {
      state.plate += 1;
      setPhase('plate');
    }
  }

  function renderColorResult() {
    state.finished = true;
    var both = state.correct === 2;
    var none = state.correct === 0;
    var lead = both
      ? 'You read both numbers. Most people with typical color vision do.'
      : none
        ? 'Those digits stayed hidden. About 1 in 12 men mix red and green in a similar way. The screen and the light can hide a plate too.'
        : 'You read one of the two. The digits are drawn in colors that red\u2013green vision can blend together.';
    el(
      '<p class="cx-eyebrow">Color vision</p>' +
      '<h2 class="cx-title" id="cxTitle">' + (both ? 'You saw both' : 'Here\u2019s the idea') + '</h2>' +
      '<p class="cx-copy">' + lead + ' The plates were a 7 and a 2.</p>' +
      '<p class="cx-copy">The Color Blindness simulation shifts a whole photo \u2014 a garden, a night street, a face \u2014 the way those cones mix color. That\u2019s one of the Pro simulations.</p>' +
      '<button type="button" class="cx-primary" id="cxSee">' + ctaLabel() + '</button>' +
      '<button type="button" class="cx-quiet" id="cxLater">Not now</button>' +
      '<button type="button" class="cx-link" id="cxOther">Try the blind spot</button>' +
      legal()
    );
    $('#cxSee').addEventListener('click', function () { haptic(); finishAnd('see'); });
    $('#cxLater').addEventListener('click', function () { closeOverlay(); });
    $('#cxOther').addEventListener('click', function () { haptic(); otherChallenge(); });
  }

  function renderSpotIntro() {
    el(
      '<p class="cx-eyebrow">Free challenge</p>' +
      '<h2 class="cx-title" id="cxTitle">Find your blind spot</h2>' +
      '<p class="cx-copy">Every eye has a small gap where the optic nerve leaves. Cover one eye, stare at the cross, and the dot can vanish.</p>' +
      '<div class="cx-spot-demo" aria-hidden="true"><span class="cx-cross">+</span><span class="cx-dot"></span></div>' +
      '<button type="button" class="cx-primary" id="cxNext">Start with my right eye</button>' +
      legal()
    );
    $('#cxNext').addEventListener('click', function () {
      haptic();
      state.eye = 'right';
      state.t = 0.12;
      state.auto = !prefersReduced();
      setPhase('test');
    });
  }

  function prefersReduced() {
    return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  }

  function renderSpotTest() {
    var right = state.eye === 'right';
    el(
      '<p class="cx-eyebrow">' + (right ? 'Right eye' : 'Left eye') + '</p>' +
      '<h2 class="cx-title" id="cxTitle">' + (right ? 'Cover your left eye' : 'Cover your right eye') + '</h2>' +
      '<p class="cx-copy cx-tight">Hold the phone a little closer than arm\u2019s length. Look only at the +.</p>' +
      '<div class="cx-stage" id="cxStage">' +
        '<span class="cx-cross" id="cxCross">+</span>' +
        '<span class="cx-dot" id="cxDot"></span>' +
      '</div>' +
      '<label class="cx-slider-label" for="cxSpotRange">Move the dot</label>' +
      '<input type="range" id="cxSpotRange" min="0" max="100" value="' + Math.round(state.t * 100) + '" aria-valuetext="Dot position">' +
      '<p class="cx-hint" id="cxHint" aria-live="polite"></p>' +
      '<button type="button" class="cx-primary" id="cxVanished">The dot vanished</button>' +
      '<button type="button" class="cx-link" id="cxFlip">' + (right ? 'Switch to my left eye' : 'Switch to my right eye') + '</button>' +
      legal()
    );
    placeSpot();
    var range = $('#cxSpotRange');
    range.addEventListener('input', function () {
      state.auto = false;
      state.t = Number(range.value) / 100;
      placeSpot();
    });
    $('#cxVanished').addEventListener('click', function () {
      haptic();
      if (state.t < 0.42) {
        $('#cxHint').textContent = 'Keep looking at the + and let the dot travel a little farther.';
        return;
      }
      stopSpot();
      setPhase('reveal');
    });
    $('#cxFlip').addEventListener('click', function () {
      haptic();
      state.eye = state.eye === 'right' ? 'left' : 'right';
      state.t = 0.12;
      state.auto = !prefersReduced();
      setPhase('test');
    });
    var stage = $('#cxStage');
    stage.addEventListener('pointerdown', function (e) {
      if (e.target.closest && e.target.closest('button')) return;
      state.auto = false;
      scrub(e.clientX);
      stage.setPointerCapture(e.pointerId);
    });
    stage.addEventListener('pointermove', function (e) {
      if (!stage.hasPointerCapture(e.pointerId)) return;
      scrub(e.clientX);
    });
    if (state.auto) startSpot();
    var rangeEl = $('#cxSpotRange');
    if (rangeEl) {
      var pct = (rangeEl.value - rangeEl.min) / ((rangeEl.max - rangeEl.min) || 1) * 100;
      rangeEl.style.setProperty('--pct', pct + '%');
    }
  }

  function scrub(clientX) {
    var stage = $('#cxStage');
    if (!stage) return;
    var rect = stage.getBoundingClientRect();
    var p = (clientX - rect.left) / rect.width;
    // Map the touch into the dot's travel, ignoring which eye.
    var t = state.eye === 'right' ? (p - 0.18) / 0.7 : (0.82 - p) / 0.7;
    state.t = Math.max(0, Math.min(1, t));
    var range = $('#cxSpotRange');
    if (range) range.value = String(Math.round(state.t * 100));
    placeSpot();
  }

  function placeSpot() {
    var cross = $('#cxCross');
    var dot = $('#cxDot');
    if (!cross || !dot || !state) return;
    var right = state.eye === 'right';
    var anchor = right ? 18 : 82;
    var travel = state.t * 70;
    cross.style.left = anchor + '%';
    cross.style.top = '46%';
    dot.style.left = (right ? anchor + travel : anchor - travel) + '%';
    dot.style.top = '58%';
  }

  function startSpot() {
    stopSpot();
    var last = performance.now();
    function tick(now) {
      if (!state || state.phase !== 'test' || !state.auto) return;
      var dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      state.t = Math.min(1, state.t + dt / 11);
      var range = $('#cxSpotRange');
      if (range) range.value = String(Math.round(state.t * 100));
      placeSpot();
      if (state.t < 1) spotTimer = requestAnimationFrame(tick);
    }
    spotTimer = requestAnimationFrame(tick);
  }

  function stopSpot() {
    if (spotTimer) cancelAnimationFrame(spotTimer);
    spotTimer = null;
  }

  function renderReveal() {
    el(
      '<p class="cx-eyebrow">Still there</p>' +
      '<h2 class="cx-title" id="cxTitle">Now look at the dot</h2>' +
      '<p class="cx-copy">It never left the screen. Your brain was filling in the gap.</p>' +
      '<div class="cx-stage cx-stage-still" id="cxStage">' +
        '<span class="cx-cross" id="cxCross">+</span>' +
        '<span class="cx-dot cx-dot-look" id="cxDot"></span>' +
      '</div>' +
      '<button type="button" class="cx-primary" id="cxSeeDot">I see the dot</button>' +
      legal()
    );
    placeSpot();
    $('#cxSeeDot').addEventListener('click', function () { haptic(); setPhase('result'); });
  }

  function renderSpotResult() {
    state.finished = true;
    el(
      '<p class="cx-eyebrow">Field of vision</p>' +
      '<h2 class="cx-title" id="cxTitle">That\u2019s your blind spot</h2>' +
      '<p class="cx-copy">The optic nerve leaves the eye there, so that patch has no light-sensing cells. The brain paints over it with the surrounding scene.</p>' +
      '<p class="cx-copy">Glaucoma can take a much wider share of side vision, and people often don\u2019t notice, because the brain fills that in too. The simulator shows that loss.</p>' +
      '<button type="button" class="cx-primary" id="cxSee">' + ctaLabel() + '</button>' +
      '<button type="button" class="cx-quiet" id="cxLater">Not now</button>' +
      '<button type="button" class="cx-link" id="cxOther">Try the number plate</button>' +
      legal()
    );
    $('#cxSee').addEventListener('click', function () { haptic(); finishAnd('see'); });
    $('#cxLater').addEventListener('click', function () { closeOverlay(); });
    $('#cxOther').addEventListener('click', function () { haptic(); otherChallenge(); });
  }

  function render() {
    if (!state) return;
    if (state.which === 'color') {
      if (state.phase === 'intro') renderColorIntro();
      else if (state.phase === 'plate') renderPlate();
      else renderColorResult();
    } else if (state.phase === 'intro') renderSpotIntro();
    else if (state.phase === 'test') renderSpotTest();
    else if (state.phase === 'reveal') renderReveal();
    else renderSpotResult();
  }

  function injectStyle() {
    if (document.getElementById('cx-style')) return;
    var css = [
      '.challenge-overlay{display:none;position:fixed;inset:0;z-index:190;background:#0f1620;color:#eef2f7;',
      'font-family:"VS Inter Tight","Inter Tight",-apple-system,BlinkMacSystemFont,sans-serif;}',
      '.challenge-overlay.open{display:block;}',
      '.cx-sheet{position:relative;height:100%;overflow-y:auto;-webkit-overflow-scrolling:touch;overscroll-behavior:contain;',
      'padding:calc(56px + env(safe-area-inset-top)) 20px calc(18px + env(safe-area-inset-bottom));',
      'max-width:520px;margin:0 auto;box-sizing:border-box;}',
      '.cx-close{position:absolute;top:calc(8px + env(safe-area-inset-top));right:8px;z-index:2;',
      'width:44px;height:44px;border:none;border-radius:50%;background:rgba(255,255,255,0.08);color:#eef2f7;',
      'font-size:22px;line-height:1;cursor:pointer;}',
      '.cx-eyebrow{margin:18px 0 6px;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#d4a574;font-weight:600;}',
      '.cx-title{font-family:"VS Fraunces","Fraunces",Georgia,serif;font-weight:500;font-size:28px;line-height:1.15;',
      'letter-spacing:-0.02em;margin:0 0 10px;color:#eef2f7;}',
      '.cx-copy{margin:0 0 12px;font-size:15px;line-height:1.5;color:#c5d0dc;}',
      '.cx-copy.cx-tight{margin-bottom:8px;}',
      '.cx-legal{margin:14px 0 0;font-size:12px;line-height:1.4;color:#8b97a6;text-align:center;}',
      '.cx-primary{appearance:none;width:100%;min-height:52px;margin-top:8px;border:none;border-radius:14px;',
      'background:#d4a574;color:#1a1208;font:700 17px/1 inherit;cursor:pointer;}',
      '.cx-primary:active{background:#e0b483;}',
      '.cx-quiet{appearance:none;width:100%;min-height:44px;margin-top:4px;border:none;background:none;',
      'color:#9aa7b8;font:600 15px/1 inherit;cursor:pointer;}',
      '.cx-link{appearance:none;display:block;width:100%;min-height:44px;margin-top:2px;border:none;background:none;',
      'color:#d4a574;font:600 15px/1 inherit;cursor:pointer;}',
      '.cx-plate-wrap{display:flex;justify-content:center;margin:6px 0 12px;}',
      '.cx-plate-wrap canvas{width:min(78vw,340px);height:auto;aspect-ratio:1;border-radius:50%;',
      'box-shadow:0 16px 40px rgba(0,0,0,0.35);}',
      '.cx-plate-small canvas{width:min(42vw,168px);}',
      '.cx-keys{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;}',
      '.cx-key{appearance:none;min-height:48px;border-radius:12px;border:1px solid rgba(255,255,255,0.08);',
      'background:rgba(255,255,255,0.06);color:#eef2f7;font:600 20px/1 inherit;cursor:pointer;}',
      '.cx-key:active{background:rgba(255,255,255,0.16);}',
      '.cx-key-wide{grid-column:1 / -1;font-size:16px;}',
      '.cx-stage{position:relative;height:min(42vw,220px);min-height:150px;margin:8px 0 12px;border-radius:16px;',
      'background:#07090d;box-shadow:inset 0 0 0 1px rgba(255,255,255,0.06);touch-action:none;}',
      '.cx-cross,.cx-dot{position:absolute;transform:translate(-50%,-50%);pointer-events:none;}',
      '.cx-cross{font:600 34px/1 Georgia,serif;color:#f4f1ea;}',
      '.cx-dot{width:22px;height:22px;border-radius:50%;background:#d4a574;box-shadow:0 0 0 6px rgba(212,165,116,0.15);}',
      '.cx-dot-look{animation:cxPulse 1.4s ease-in-out infinite;}',
      '@keyframes cxPulse{50%{transform:translate(-50%,-50%) scale(1.18);}}',
      '.cx-spot-demo{position:relative;height:88px;margin:8px 0 16px;border-radius:16px;background:#07090d;}',
      '.cx-spot-demo .cx-cross{left:28%;top:50%;}',
      '.cx-spot-demo .cx-dot{left:68%;top:58%;}',
      '.cx-slider-label{display:block;font-size:13px;color:#9aa7b8;margin:0 0 2px;}',
      '.challenge-overlay input[type=range]{width:100%;height:44px;margin:0 0 4px;padding:18px 0;box-sizing:border-box;',
      'appearance:none;-webkit-appearance:none;background:linear-gradient(to right,#d4a574 var(--pct,20%),rgba(255,255,255,0.16) var(--pct,20%));',
      'background-clip:content-box;border-radius:0;}',
      '.challenge-overlay input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:28px;height:28px;border-radius:50%;',
      'background:#fff;box-shadow:0 2px 6px rgba(0,0,0,0.35);}',
      '.cx-hint{min-height:1.3em;margin:0 0 6px;font-size:13px;color:#d4a574;}',
      '@media (prefers-reduced-motion: reduce){.cx-dot-look{animation:none;}}',
      'html.challenge-open,html.challenge-open body{overflow:hidden;}'
    ].join('');
    var style = document.createElement('style');
    style.id = 'cx-style';
    style.textContent = css;
    document.head.appendChild(style);
  }

  function paintRange(input) {
    var pct = (input.value - input.min) / ((input.max - input.min) || 1) * 100;
    input.style.setProperty('--pct', pct + '%');
  }

  function buildOverlay() {
    overlay = document.createElement('div');
    overlay.className = 'challenge-overlay';
    overlay.id = 'challengeOverlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-labelledby', 'cxTitle');
    overlay.innerHTML = '<button type="button" class="cx-close" id="cxClose" aria-label="Close">\u00d7</button><div class="cx-sheet"><div id="cxBody"></div></div>';
    document.body.appendChild(overlay);
    bodyEl = overlay.querySelector('#cxBody');
    overlay.querySelector('#cxClose').addEventListener('click', closeOverlay);
    overlay.addEventListener('input', function (e) {
      if (e.target && e.target.type === 'range') paintRange(e.target);
    });
  }

  function bindLaunchers() {
    var nodes = document.querySelectorAll('[data-challenge]');
    for (var i = 0; i < nodes.length; i++) {
      (function (btn) {
        btn.addEventListener('pointerdown', holdWebRedirect);
        btn.addEventListener('click', function () {
          open(btn.getAttribute('data-challenge'));
        });
      })(nodes[i]);
    }
  }

  function onKey(e) {
    if (e.key === 'Escape' && overlay && overlay.classList.contains('open')) closeOverlay();
  }

  function boot() {
    if (overlay) return;
    injectStyle();
    buildOverlay();
    bindLaunchers();
    document.addEventListener('keydown', onKey);
    var which = null;
    try { which = new URLSearchParams(window.location.search).get('challenge'); } catch (e) {}
    if (which === 'color' || which === 'spot') open(which);
  }

  window.VisionChallenges = {
    open: function (which) { if (!overlay) boot(); open(which); },
    close: closeOverlay,
    measure: measure
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
