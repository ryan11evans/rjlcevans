// Captures the raw app screens used by iphone-screenshots.html / ipad-screenshots.html
// from the real app, with CanvasRenderingContext2D.filter disabled so the
// output matches iOS WKWebView (where ctx.filter is unsupported).
//
// Usage:
//   APP_URL=https://rjlcevans.com/vision-simulator/index.html \
//   OUT_DIR=./screens ONLY=hero,amd,cataract,colorblind node capture-store-screens.js
// Optional overrides: HERO_STAGE=Severe HERO_SPLIT=0.4 CAT_SEV=0.48 AMD_STAGE=Advanced
//   AMD_SPLIT=0.5 CVD_TYPE="Protan (red)" CVD_SPLIT=0.5
// Writes s1-hero, s2-amd-compare, s3-cataract-night, s5-colorblind-compare
// (iPhone 1260x2736) and the ipad-* versions (2064x2752).
const { chromium } = require('playwright');
const path = require('path');

const APP_URL = process.env.APP_URL || 'https://rjlcevans.com/vision-simulator/index.html';
const OUT_DIR = process.env.OUT_DIR || path.join(__dirname, 'screens');
const FACE = path.join(__dirname, 'screens/src/hero-face.jpg');   // see screens/src/CREDITS.md
const ONLY = (process.env.ONLY || 'hero,amd,cataract,colorblind').split(',');
const E = process.env;

const DEVICES = [
  { prefix: '', viewport: { width: 420, height: 912 }, scale: 3 },
  { prefix: 'ipad-', viewport: { width: 1032, height: 1376 }, scale: 2 },
];

const STATUS_BAR_HTML = `
<div id="fakeStatusBar" style="height:54px; box-sizing:border-box; display:flex; align-items:center; justify-content:space-between; padding:0 26px 0 30px; position:relative; z-index:99999; font-family:-apple-system, BlinkMacSystemFont, sans-serif;">
  <span style="color:#fff; font-size:17px; font-weight:600; letter-spacing:-0.2px;">9:41</span>
  <div style="display:flex; align-items:center; gap:7px;">
    <svg width="19" height="12" viewBox="0 0 19 12" fill="none"><rect x="0" y="7" width="3" height="5" rx="0.8" fill="#fff"/><rect x="5" y="5" width="3" height="7" rx="0.8" fill="#fff"/><rect x="10" y="3" width="3" height="9" rx="0.8" fill="#fff"/><rect x="15" y="0" width="3" height="12" rx="0.8" fill="#fff"/></svg>
    <svg width="16" height="12" viewBox="0 0 16 12" fill="none"><path d="M8 10.2C8.66 10.2 9.2 9.66 9.2 9C9.2 8.34 8.66 7.8 8 7.8C7.34 7.8 6.8 8.34 6.8 9C6.8 9.66 7.34 10.2 8 10.2Z" fill="#fff"/><path d="M4.5 6.8C5.4 5.9 6.65 5.35 8 5.35C9.35 5.35 10.6 5.9 11.5 6.8" stroke="#fff" stroke-width="1.3" stroke-linecap="round" fill="none"/><path d="M1.5 3.9C3.15 2.25 5.45 1.2 8 1.2C10.55 1.2 12.85 2.25 14.5 3.9" stroke="#fff" stroke-width="1.3" stroke-linecap="round" fill="none"/></svg>
    <svg width="26" height="13" viewBox="0 0 26 13" fill="none"><rect x="0.75" y="0.75" width="21.5" height="11.5" rx="3" stroke="#fff" stroke-opacity="0.5" stroke-width="1"/><rect x="2.25" y="2.25" width="18.5" height="8.5" rx="1.8" fill="#fff"/><rect x="23.5" y="4" width="1.8" height="5" rx="0.9" fill="#fff" fill-opacity="0.5"/></svg>
  </div>
</div>`;

const SHOTS = {
  hero: { file: 's1-hero.png', async run(p) {
    await p.setInputFiles('#upload', FACE); await p.waitForTimeout(500);
    await cond(p, 'glaucoma'); await preset(p, 'glaucomaStages', E.HERO_STAGE || 'Severe');
    await compare(p, parseFloat(E.HERO_SPLIT || '0.4'));
  } },
  amd: { file: 's2-amd-compare.png', async run(p) {
    await sample(p, 'face'); await cond(p, 'amd'); await preset(p, 'amdStages', E.AMD_STAGE || 'Advanced');
    await compare(p, parseFloat(E.AMD_SPLIT || '0.5'));
  } },
  cataract: { file: 's3-cataract-night.png', async run(p) {
    await sample(p, 'street'); await cond(p, 'cataract'); await slider(p, 'ctrl_cataractSev', E.CAT_SEV || '0.48');
  } },
  colorblind: { file: 's5-colorblind-compare.png', async run(p) {
    await sample(p, 'garden'); await cond(p, 'colorblind'); await preset(p, 'cvdTypes', E.CVD_TYPE || 'Protan (red)');
    await compare(p, parseFloat(E.CVD_SPLIT || '0.5'));
  } },
};

async function sample(p, k) { await p.click(`#sampleRow [data-sample="${k}"]`); await p.waitForTimeout(400); }
async function cond(p, c) { await p.click(`.cond[data-cond="${c}"]`); await p.waitForTimeout(200); }
async function preset(p, group, text) { await p.click(`#${group} .preset:text-is("${text}")`); await p.waitForTimeout(200); }
async function slider(p, id, v) {
  await p.evaluate(([id, v]) => { const el = document.getElementById(id); el.value = v; el.dispatchEvent(new Event('input')); }, [id, v]);
  await p.waitForTimeout(200);
}
async function compare(p, split) {
  await p.click('#compareToggle'); await p.waitForTimeout(250);
  if (Math.abs(split - 0.5) < 0.01) return;
  const box = await p.locator('.stage-wrap').boundingBox();       // drag the divider like a user
  const y = box.y + box.height / 2;
  await p.mouse.move(box.x + box.width * 0.5, y); await p.mouse.down();
  await p.mouse.move(box.x + box.width * split, y, { steps: 6 }); await p.mouse.up();
}

(async () => {
  const browser = await chromium.launch();
  const errors = [];
  for (const key of ONLY) {
    const s = SHOTS[key];
    for (const d of DEVICES) {
      const ctx = await browser.newContext({ viewport: d.viewport, deviceScaleFactor: d.scale });
      await ctx.addInitScript(() => {
        window.Capacitor = { isNativePlatform: () => true };
        // iOS WKWebView ignores ctx.filter; emulate that so captures match iPhone.
        Object.defineProperty(CanvasRenderingContext2D.prototype, 'filter', { get() { return 'none'; }, set() {}, configurable: true });
      });
      const p = await ctx.newPage();
      p.on('pageerror', e => errors.push(`${key}: ${e.message}`));
      p.on('console', m => { if (m.type() === 'error') errors.push(`${key}: ${m.text()}`); });
      await p.goto(APP_URL + (APP_URL.includes('?') ? '&' : '?') + 'cb=' + Date.now(), { waitUntil: 'networkidle' });
      await p.waitForTimeout(400);
      await s.run(p);
      await p.evaluate(() => { window.scrollTo(0, 0); document.activeElement && document.activeElement.blur(); });
      await p.mouse.move(0, 0);
      await p.evaluate((html) => { const w = document.createElement('div'); w.innerHTML = html; document.body.insertBefore(w.firstElementChild, document.body.firstChild); }, STATUS_BAR_HTML);
      await p.waitForTimeout(250);
      const out = path.join(OUT_DIR, d.prefix + s.file);
      await p.screenshot({ path: out });
      console.log('saved', out);
      await ctx.close();
    }
  }
  if (errors.length) console.log('PAGE ERRORS:', errors);
  await browser.close();
})();
