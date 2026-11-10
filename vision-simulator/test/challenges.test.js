'use strict';

const assert = require('assert');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const PROD = path.join(__dirname, '..');
const STAGING = path.join(__dirname, '..', '..', 'vision-simulator-staging');
const ARTIFACTS = process.env.VS_ARTIFACTS || '';

function startServer(root) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const url = new URL(req.url, 'http://127.0.0.1');
      let filePath = decodeURIComponent(url.pathname);
      if (filePath === '/') filePath = '/index.html';
      const abs = path.normalize(path.join(root, filePath));
      if (!abs.startsWith(root)) {
        res.writeHead(403);
        res.end();
        return;
      }
      fs.readFile(abs, (err, data) => {
        if (err) {
          res.writeHead(404);
          res.end('missing');
          return;
        }
        const ext = path.extname(abs);
        const types = {
          '.html': 'text/html',
          '.js': 'text/javascript',
          '.png': 'image/png',
          '.jpg': 'image/jpeg',
          '.svg': 'image/svg+xml',
          '.woff2': 'font/woff2'
        };
        res.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
        res.end(data);
      });
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

function reviewMock() {
  window.__reviewCalls = 0;
  window.Capacitor = Object.assign(window.Capacitor || {}, {
    getPlatform: () => 'ios',
    isNativePlatform: () => true,
    isPluginAvailable: (name) => name === 'InAppReview',
    registerPlugin: () => ({ requestReview: () => { window.__reviewCalls += 1; return Promise.resolve(); } })
  });
}

function purchaseMock() {
  const handlers = { productUpdated: [] };
  let owned = false;
  window.CdvPurchase = {
    store: {
      register() {},
      when() {
        return {
          approved() { return this; },
          productUpdated(fn) { handlers.productUpdated.push(fn); return this; },
          receiptUpdated() { return this; }
        };
      },
      get() {
        return {
          pricing: null,
          getOffer() {
            return {
              order() {
                owned = true;
                handlers.productUpdated.forEach((fn) => fn());
              }
            };
          }
        };
      },
      owned() { return owned; },
      initialize() { handlers.productUpdated.forEach((fn) => fn()); },
      restorePurchases() {}
    },
    ProductType: { NON_CONSUMABLE: 'non_consumable' },
    Platform: { APPLE_APPSTORE: 'ios' }
  };
}

async function shot(page, name) {
  if (!ARTIFACTS) return;
  await page.screenshot({ path: path.join(ARTIFACTS, name) });
}

async function main() {
  const server = await startServer(PROD);
  const stagingServer = await startServer(STAGING);
  const origin = 'http://127.0.0.1:' + server.address().port;
  const stagingOrigin = 'http://127.0.0.1:' + stagingServer.address().port;
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_PATH || undefined
  });
  const phone = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };

  try {
    // Plates are original dot art: readable in normal color, collapsed for deutan.
    {
      const context = await browser.newContext(phone);
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      const stats = await page.evaluate(() => window.VisionChallenges.measure('7'));
      assert.ok(stats.figureDots > 15, 'plate draws a digit out of dots');
      assert.ok(stats.normal > 40, 'normal vision can separate the colors, got ' + stats.normal);
      assert.ok(stats.deutan < stats.normal * 0.35, 'deutan simulation collapses the digit, got ' + stats.deutan + ' vs ' + stats.normal);
      const stats2 = await page.evaluate(() => window.VisionChallenges.measure('2'));
      assert.ok(stats2.normal > 40 && stats2.deutan < stats2.normal * 0.35);
      await context.close();
    }

    // Mobile web: challenges live on the store gate, never ask for a review,
    // and starting one cancels the App Store redirect.
    {
      const context = await browser.newContext(phone);
      const page = await context.newPage();
      const storeHits = [];
      page.on('request', (req) => {
        if (req.url().startsWith('https://apps.apple.com/')) storeHits.push(req.url());
      });
      await page.route('https://apps.apple.com/**', (route) => route.abort());
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.waitForSelector('#gateChallenges [data-challenge="color"]');
      assert.strictEqual(await page.locator('#storeGate').isVisible(), true);
      assert.ok((await page.locator('#storeGate').innerText()).includes('This is not a medical test.'));
      await shot(page, 'challenge-gate-mobile.png');

      await page.locator('#gateChallenges [data-challenge="color"]').click();
      await page.waitForSelector('#cxTitle');
      assert.strictEqual(await page.locator('#cxTitle').innerText(), 'Can you see the number?');
      assert.ok((await page.locator('.cx-legal').innerText()).includes('This is not a medical test.'));
      await shot(page, 'challenge-color-intro.png');
      await page.locator('#cxNext').click();
      await page.waitForSelector('#cxPlate');
      const pixels = await page.evaluate(() => {
        const c = document.getElementById('cxPlate');
        const data = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
        let color = 0;
        for (let i = 0; i < data.length; i += 16) {
          if (Math.abs(data[i] - data[i + 1]) > 25) color++;
        }
        return color;
      });
      assert.ok(pixels > 20, 'the plate is drawn, not a blank canvas');
      await shot(page, 'challenge-color-plate.png');
      await page.locator('[data-answer="7"]').click();
      await page.locator('[data-answer="2"]').click();
      await page.waitForSelector('#cxSee');
      assert.strictEqual(await page.locator('#cxSee').innerText(), 'Get the app');
      assert.ok((await page.locator('#challengeOverlay').innerText()).includes('This is not a medical test.'));
      assert.ok((await page.locator('#challengeOverlay').innerText()).includes('Color Blindness'));
      assert.strictEqual(await page.locator('#paywallOverlay').evaluate((el) => el.classList.contains('open')), false);
      await shot(page, 'challenge-color-result.png');
      await page.locator('#cxLater').click();
      await page.waitForTimeout(2200);
      assert.strictEqual(await page.evaluate(() => localStorage.getItem('vs_reviewAsked')), null);
      assert.strictEqual(await page.evaluate(() => window.__vsSimulatorBooted === true), false);

      await page.locator('#gateChallenges [data-challenge="spot"]').click();
      await shot(page, 'challenge-spot-intro.png');
      await page.locator('#cxNext').click();
      await page.waitForSelector('#cxDot');
      await shot(page, 'challenge-spot-test.png');
      await page.locator('#cxVanished').click();
      assert.ok((await page.locator('#cxHint').innerText()).length > 0, 'too-early tap explains to keep going');
      await page.locator('#cxSpotRange').evaluate((el) => {
        el.value = '80';
        el.dispatchEvent(new Event('input', { bubbles: true }));
      });
      await page.locator('#cxVanished').click();
      await page.waitForSelector('#cxSeeDot');
      await shot(page, 'challenge-spot-reveal.png');
      await page.locator('#cxSeeDot').click();
      await page.waitForSelector('#cxSee');
      assert.ok((await page.locator('#challengeOverlay').innerText()).includes('Glaucoma'));
      assert.ok((await page.locator('#challengeOverlay').innerText()).includes('This is not a medical test.'));
      await shot(page, 'challenge-spot-result.png');
      await page.locator('#cxLater').click();
      assert.strictEqual(await page.evaluate(() => localStorage.getItem('vs_reviewAsked')), null);
      await context.close();

      // A fresh visit that opens a challenge is not sent to the App Store.
      const context2 = await browser.newContext(phone);
      const page2 = await context2.newPage();
      const hits = [];
      page2.on('request', (req) => {
        if (req.url().startsWith('https://apps.apple.com/')) hits.push(req.url());
      });
      await page2.route('https://apps.apple.com/**', (route) => route.abort());
      await page2.goto(origin + '/index.html', { waitUntil: 'domcontentloaded' });
      await page2.locator('#gateChallenges [data-challenge="color"]').click();
      await page2.waitForTimeout(4500);
      assert.strictEqual(hits.length, 0, 'opening a challenge cancels the store redirect');
      assert.strictEqual(await page2.locator('#challengeOverlay').evaluate((el) => el.classList.contains('open')), true);
      await context2.close();
      assert.ok(storeHits.length === 0);
    }

    // In the app: soft Pro prompt, no paywall until they ask, review once they leave.
    {
      const context = await browser.newContext(phone);
      await context.addInitScript(purchaseMock);
      await context.addInitScript(reviewMock);
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
      await page.waitForTimeout(100);
      await shot(page, 'challenge-app-dock.png');
      await page.locator('#challengeBlock [data-challenge="color"]').dispatchEvent('click');
      await page.locator('#cxNext').click();
      await page.locator('[data-answer="none"]').click();
      await page.locator('[data-answer="none"]').click();
      await page.waitForSelector('#cxSee');
      assert.strictEqual(await page.locator('#cxSee').innerText(), 'See it with Pro');
      assert.strictEqual(await page.locator('#paywallOverlay').evaluate((el) => el.classList.contains('open')), false);
      await page.locator('#cxSee').click();
      assert.strictEqual(await page.locator('#paywallOverlay').evaluate((el) => el.classList.contains('open')), true);
      await page.waitForTimeout(2500);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 0, 'no review over the paywall');
      await page.locator('#paywallLater').dispatchEvent('click');
      await page.waitForTimeout(1500);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 1, 'review after the challenge, once the paywall closes');

      await page.locator('#challengeBlock [data-challenge="spot"]').dispatchEvent('click');
      await page.locator('#cxNext').click();
      await page.locator('#cxSpotRange').evaluate((el) => {
        el.value = '70';
        el.dispatchEvent(new Event('input', { bubbles: true }));
      });
      await page.locator('#cxVanished').click();
      await page.locator('#cxSeeDot').click();
      await page.locator('#cxLater').click();
      await page.waitForTimeout(2500);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 1, 'does not ask again');
      await context.close();
    }

    // A successful Pro purchase is also a positive moment, still once.
    {
      const context = await browser.newContext(phone);
      await context.addInitScript(purchaseMock);
      await context.addInitScript(reviewMock);
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
      await page.waitForTimeout(80);
      await page.locator('#unlockProBtn').dispatchEvent('click');
      await page.locator('#paywallBuy').click();
      await page.waitForTimeout(2200);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 0, 'purchase review waits for the paywall to close');
      await page.locator('#paywallLater').dispatchEvent('click');
      await page.waitForTimeout(1500);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 1);
      assert.strictEqual(await page.evaluate(() => document.documentElement.classList.contains('is-pro')), true);
      await context.close();
    }

    // Staging copy: same challenges, review still inert in a browser.
    {
      const context = await browser.newContext(phone);
      const page = await context.newPage();
      await page.goto(stagingOrigin + '/index.html?ui2=1', { waitUntil: 'domcontentloaded' });
      await page.locator('#challengeBlock [data-challenge="spot"]').dispatchEvent('click');
      await page.locator('#cxNext').click();
      await page.locator('#cxSpotRange').evaluate((el) => {
        el.value = '75';
        el.dispatchEvent(new Event('input', { bubbles: true }));
      });
      await page.locator('#cxVanished').click();
      await page.locator('#cxSeeDot').click();
      assert.ok((await page.locator('.cx-legal').innerText()).includes('This is not a medical test.'));
      assert.strictEqual(await page.locator('#cxSee').innerText(), 'Open the simulation');
      await page.locator('#cxLater').click();
      await page.waitForTimeout(2000);
      assert.strictEqual(await page.evaluate(() => localStorage.getItem('vs_reviewAsked')), null);
      await context.close();
    }

    function denyCamera() {
      const md = navigator.mediaDevices || {};
      navigator.mediaDevices = md;
      md.getUserMedia = () => Promise.reject(new DOMException('denied', 'NotAllowedError'));
    }
    async function frameStats(page) {
      return page.evaluate(() => {
        const c = document.getElementById('stageCanvas');
        const ctx = c.getContext('2d');
        const lum = (x, y) => {
          const d = ctx.getImageData(Math.max(0, x), Math.max(0, y), 1, 1).data;
          return 0.2126 * d[0] + 0.7152 * d[1] + 0.0722 * d[2];
        };
        const corners = [lum(3, 3), lum(c.width - 4, 3), lum(3, c.height - 4), lum(c.width - 4, c.height - 4)];
        let center = 0;
        for (let dy = -12; dy <= 12; dy += 4) {
          for (let dx = -12; dx <= 12; dx += 4) {
            center = Math.max(center, lum((c.width >> 1) + dx, (c.height >> 1) + dy));
          }
        }
        return { corner: Math.max.apply(null, corners), center: center };
      });
    }

    // Photo fallback: denied camera still runs moderate AMD on the garden,
    // counts down, freezes, then opens the unlock sheet. No price. One look only.
    {
      const context = await browser.newContext(phone);
      await context.addInitScript(denyCamera);
      await context.addInitScript(() => { window.__vsPreviewMs = 1400; });
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      const gateText = (await page.locator('#storeGate').innerText()).toLowerCase();
      const previewAt = gateText.indexOf('see macular degeneration');
      const extrasAt = gateText.indexOf('fun extras');
      const plateAt = gateText.indexOf('see the number');
      assert.ok(previewAt !== -1 && previewAt < extrasAt && extrasAt < plateAt, 'preview is ahead of the fun extras');
      await page.locator('#gatePreview [data-preview="amd"]').click();
      await page.waitForSelector('#previewHud', { state: 'visible' });
      const count = await page.locator('#previewHudCount').innerText();
      assert.ok(Number(count) >= 1 && Number(count) <= 10);
      await page.waitForFunction(() => {
        const c = document.getElementById('stageCanvas');
        return c && c.width > 20;
      });
      const during = await frameStats(page);
      assert.ok(during.center < during.corner * 0.45, 'the center is a dark scotoma, not a light blur, ' + during.center + ' vs ' + during.corner);
      assert.ok(during.corner > 80, 'the surrounding garden stays visible, got ' + during.corner);
      assert.ok(during.center < 55, 'the central scotoma is dense, got ' + during.center);
      const span = await page.evaluate(() => {
        const c = document.getElementById('stageCanvas');
        const g = c.getContext('2d');
        const y = c.height >> 1;
        const lum = (x) => {
          const d = g.getImageData(x, y, 1, 1).data;
          return 0.2126 * d[0] + 0.7152 * d[1] + 0.0722 * d[2];
        };
        const edge = Math.max(lum(6), lum(c.width - 7));
        let dark = 0;
        for (let x = 0; x < c.width; x += 2) if (lum(x) < edge * 0.4) dark += 2;
        return dark / c.width;
      });
      assert.ok(span > 0.32 && span < 0.55, 'scotoma should cover about 35–45% of the width, got ' + span);
      await shot(page, 'amd-preview-running.png');
      await page.waitForSelector('#paywallOverlay.open', { timeout: 5000 });
      assert.strictEqual(await page.locator('#paywallTitle').innerText(), "That's what macular degeneration looks like.");
      assert.strictEqual(await page.locator('#paywallLead').innerText(), 'Unlock all 10 conditions.');
      const buy = await page.locator('#paywallBuy').innerText();
      assert.strictEqual(buy, 'Get the app');
      assert.ok(!/\$/.test(buy), 'paywall must not hardcode a price');
      assert.strictEqual(await page.locator('#paywallRestore').isVisible(), false, 'Restore Purchases stays off the website');
      const features = await page.locator('.paywall-features').innerText();
      assert.ok(features.includes('All 10 conditions'));
      assert.ok(!features.includes('7 more'));
      const frozen = await frameStats(page);
      assert.ok(frozen.corner > 35, 'the last frame stays up behind the unlock sheet');
      assert.ok(frozen.center < frozen.corner, 'the frozen frame keeps the central scotoma');
      await shot(page, 'amd-unlock.png');
      await page.waitForTimeout(2000);
      assert.strictEqual(await page.evaluate(() => localStorage.getItem('vs_reviewAsked')), null, 'watching a preview does not ask for a review');
      await page.locator('#paywallClose').click();
      await page.locator('#gatePreview [data-preview="amd"]').click();
      await page.waitForTimeout(400);
      assert.strictEqual(await page.locator('#paywallOverlay').evaluate((el) => el.classList.contains('open')), true);
      assert.strictEqual(await page.locator('#previewHud').evaluate((el) => el.hidden), true, 'a used preview goes straight to the paywall');
      await page.locator('#paywallClose').click();
      await page.locator('#gatePreview [data-preview="glaucoma"]').click();
      await page.waitForSelector('#previewHud', { state: 'visible' });
      assert.strictEqual(await page.locator('#previewHudName').evaluate((el) => el.textContent), 'Severe glaucoma');
      await context.close();
    }

    // Mid-countdown on the garden: the number has moved, the scotoma is still up.
    {
      const context = await browser.newContext(phone);
      await context.addInitScript(denyCamera);
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.locator('#gatePreview [data-preview="amd"]').click();
      await page.waitForFunction(() => {
        const n = document.getElementById('previewHudCount');
        return n && n.textContent === '5';
      }, null, { timeout: 12000 });
      await shot(page, 'amd-mid-countdown.png');
      await context.close();
    }

    // Preview that ends in a purchase can ask for a review, once, after the sheet closes.
    {
      const context = await browser.newContext(phone);
      await context.addInitScript(denyCamera);
      await context.addInitScript(() => { window.__vsPreviewMs = 1200; });
      await context.addInitScript(purchaseMock);
      await context.addInitScript(reviewMock);
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
      await page.locator('#previewBlock [data-preview="cataract"]').dispatchEvent('click');
      await page.waitForSelector('#paywallOverlay.open', { timeout: 8000 });
      assert.strictEqual(await page.locator('#paywallTitle').innerText(), "That's what a dense cataract looks like.");
      await page.locator('#paywallBuy').click();
      await page.waitForTimeout(2000);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 0, 'review waits until the unlock sheet closes');
      await page.locator('#paywallLater').dispatchEvent('click');
      await page.waitForTimeout(1500);
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 1);
      await context.close();
    }

    console.log('challenges: ok');
  } finally {
    await browser.close();
    server.close();
    stagingServer.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
