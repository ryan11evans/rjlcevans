const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const APP_URL = 'http://localhost:8935/index.html';
const OUT_DIR = '/Users/ryanevans/rjlcevans/vision-simulator/screens';

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

async function setupPage(context, { proReady = false } = {}) {
  await context.addInitScript((proReady) => {
    window.Capacitor = { isNativePlatform: () => true };
    if (proReady) {
      const chain = () => proxyChain;
      const proxyChain = new Proxy({}, { get: () => chain });
      window.CdvPurchase = {
        store: {
          register: () => {},
          when: () => proxyChain,
          get: () => null,
          owned: () => false,
          initialize: () => {},
        },
        ProductType: { NON_CONSUMABLE: 'non_consumable' },
        Platform: { APPLE_APPSTORE: 'apple_appstore' },
      };
    }
  }, proReady);
  const page = await context.newPage();
  await page.goto(APP_URL);
  await page.waitForTimeout(300);
  if (proReady) {
    await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
    await page.waitForTimeout(200);
  }
  return page;
}

async function clickSample(page, kind) {
  await page.click(`#sampleRow [data-sample="${kind}"]`);
  await page.waitForTimeout(250);
}

async function clickCondition(page, cond) {
  await page.click(`.cond[data-cond="${cond}"]`);
  await page.waitForTimeout(150);
}

async function clickPreset(page, text) {
  await page.click(`.preset:has-text("${text}")`);
  await page.waitForTimeout(150);
}

async function setSlider(page, ctrlId, value) {
  await page.evaluate(({ ctrlId, value }) => {
    const el = document.getElementById(ctrlId);
    el.value = value;
    el.dispatchEvent(new Event('input'));
  }, { ctrlId, value });
  await page.waitForTimeout(150);
}

async function enableCompare(page) {
  await page.click('#compareToggle');
  await page.waitForTimeout(200);
}

async function scrollConditionsBy(page, dx) {
  await page.evaluate((dx) => {
    document.getElementById('conditions').scrollLeft = dx;
  }, dx);
  await page.waitForTimeout(150);
}

async function shoot(page, file) {
  await page.evaluate(() => document.activeElement && document.activeElement.blur());
  await page.mouse.move(0, 0);
  await injectStatusBar(page);
  await page.waitForTimeout(100);
  await page.screenshot({ path: path.join(OUT_DIR, file) });
  console.log('saved', file);
}

(async () => {
  const browser = await chromium.launch();

  // ── Screen 1: Hero ──────────────────────────────────────────────
  {
    const ctx = await browser.newContext({ viewport: { width: 420, height: 912 }, deviceScaleFactor: 3 });
    const page = await setupPage(ctx, { proReady: false });
    await clickSample(page, 'reading');
    await shoot(page, 's1-hero.png');
    await ctx.close();
  }

  // ── Screen 2: AMD compare ───────────────────────────────────────
  {
    const ctx = await browser.newContext({ viewport: { width: 420, height: 912 }, deviceScaleFactor: 3 });
    const page = await setupPage(ctx, { proReady: false });
    await clickSample(page, 'face');
    await clickCondition(page, 'amd');
    await clickPreset(page, 'Moderate');
    await enableCompare(page);
    await page.evaluate(() => window.scrollTo(0, 0));
    await shoot(page, 's2-amd-compare.png');
    await ctx.close();
  }

  // ── Screen 3: Cataract night ─────────────────────────────────────
  {
    const ctx = await browser.newContext({ viewport: { width: 420, height: 912 }, deviceScaleFactor: 3 });
    const page = await setupPage(ctx, { proReady: false });
    await clickSample(page, 'street');
    await clickCondition(page, 'cataract');
    await setSlider(page, 'ctrl_cataractSev', 0.3);
    await page.evaluate(() => window.scrollTo(0, 0));
    await shoot(page, 's3-cataract-night.png');
    await ctx.close();
  }

  // ── Screen 4: Free/Pro conditions grid ────────────────────────────
  {
    const ctx = await browser.newContext({ viewport: { width: 420, height: 912 }, deviceScaleFactor: 3 });
    const page = await setupPage(ctx, { proReady: true });
    await clickSample(page, 'reading');
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(150);
    await shoot(page, 's4-conditions-freepro.png');
    await ctx.close();
  }

  // ── Screen 5: Color blindness compare ─────────────────────────────
  {
    const ctx = await browser.newContext({ viewport: { width: 420, height: 912 }, deviceScaleFactor: 3 });
    const page = await setupPage(ctx, { proReady: false });
    await clickSample(page, 'garden');
    await clickCondition(page, 'colorblind');
    await clickPreset(page, 'Protan');
    await enableCompare(page);
    await page.evaluate(() => window.scrollTo(0, 0));
    await shoot(page, 's5-colorblind-compare.png');
    await ctx.close();
  }

  await browser.close();
})();
