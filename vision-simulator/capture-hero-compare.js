// Renders the hero App Store screen: the app's own Compare mode on an uploaded face photo.
// Usage: serve vision-simulator/ on a local port, then
//   APP_URL=http://localhost:8936/index.html OUT_DIR=./screens node capture-hero-compare.js
// Default: Glaucoma (Severe), divider at 40%. Override with COND=cataract SEV=0.5 SPLIT=0.5.
// Writes s1-hero.png (iPhone 1260x2736) and ipad-s1-hero.png (iPad 2064x2752).
const { chromium } = require('playwright');
const path = require('path');

const APP_URL = process.env.APP_URL || 'http://localhost:8936/index.html';
const OUT_DIR = process.env.OUT_DIR || path.join(__dirname, 'screens');
const FACE = path.join(__dirname, 'screens/src/hero-face.jpg');   // see screens/src/CREDITS.md
const COND = process.env.COND || 'glaucoma';
const SEV = parseFloat(process.env.SEV || '0.8');
const SPLIT = parseFloat(process.env.SPLIT || '0.4');

const DEVICES = [
  { file: 's1-hero.png', viewport: { width: 420, height: 912 }, scale: 3 },
  { file: 'ipad-s1-hero.png', viewport: { width: 1032, height: 1376 }, scale: 2 },
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

async function injectStatusBar(page) {
  await page.evaluate((html) => {
    const wrap = document.createElement('div');
    wrap.innerHTML = html;
    document.body.insertBefore(wrap.firstElementChild, document.body.firstChild);
  }, STATUS_BAR_HTML);
}

async function injectStatusBar(page) {
  await page.evaluate((html) => {
    const wrap = document.createElement('div');
    wrap.innerHTML = html;
    document.body.insertBefore(wrap.firstElementChild, document.body.firstChild);
  }, STATUS_BAR_HTML);
}

(async () => {
  const browser = await chromium.launch();
  for (const d of DEVICES) {
    const ctx = await browser.newContext({ viewport: d.viewport, deviceScaleFactor: d.scale });
    await ctx.addInitScript(() => { window.Capacitor = { isNativePlatform: () => true }; });
    const page = await ctx.newPage();
    await page.goto(APP_URL);
    await page.waitForTimeout(300);
    await page.setInputFiles('#upload', FACE);          // the app's Upload Image button
    await page.waitForTimeout(400);
    await page.click(`.cond[data-cond="${COND}"]`);
    await page.waitForTimeout(150);
    if (COND === 'cataract') {
      await page.evaluate((v) => { const el = document.getElementById('ctrl_cataractSev'); el.value = v; el.dispatchEvent(new Event('input')); }, SEV);
    } else if (COND === 'glaucoma') {
      await page.click('#glaucomaStages .preset:has-text("Severe")');
    }
    await page.waitForTimeout(150);
    await page.click('#compareToggle');
    await page.waitForTimeout(200);
    // Drag the divider like a user would.
    const box = await page.locator('.stage-wrap').boundingBox();
    const y = box.y + box.height / 2;
    await page.mouse.move(box.x + box.width * 0.5, y);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * SPLIT, y, { steps: 5 });
    await page.mouse.up();
    await page.evaluate(() => { window.scrollTo(0, 0); document.activeElement && document.activeElement.blur(); });
    await page.mouse.move(0, 0);
    await injectStatusBar(page);
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(OUT_DIR, d.file) });
    console.log('saved', d.file);
    await ctx.close();
  }
  await browser.close();
})();
