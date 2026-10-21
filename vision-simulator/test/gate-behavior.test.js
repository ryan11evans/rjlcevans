'use strict';

const assert = require('assert');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..');
const STORE = 'https://apps.apple.com/us/app/vision-simulator-by-dr-evans/id6772865195';

function startServer() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const url = new URL(req.url, 'http://127.0.0.1');
      let filePath = decodeURIComponent(url.pathname);
      if (filePath === '/') filePath = '/index.html';
      const abs = path.normalize(path.join(ROOT, filePath));
      if (!abs.startsWith(ROOT)) {
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
        const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml' };
        res.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
        res.end(data);
      });
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

async function main() {
  const server = await startServer();
  const origin = 'http://127.0.0.1:' + server.address().port;
  const browser = await chromium.launch({ headless: true });
  const storeHits = [];

  async function track(page) {
    page.on('request', (req) => {
      if (req.url().startsWith('https://apps.apple.com/')) storeHits.push(req.url());
    });
    await page.route('https://apps.apple.com/**', (route) => route.abort());
  }

  try {
    // Plain browser: gate visible, simulator not started, then redirect.
    {
      storeHits.length = 0;
      const context = await browser.newContext();
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (err) => errors.push(String(err)));
      await track(page);
      await page.goto(origin + '/index.html', { waitUntil: 'domcontentloaded' });
      assert.strictEqual(await page.evaluate(() => document.documentElement.classList.contains('is-browser')), true);
      assert.strictEqual(await page.evaluate(() => window.__vsSimulatorBooted === true), false);
      assert.strictEqual(await page.locator('#storeGate').isVisible(), true);
      assert.strictEqual(await page.locator('.wrap').isVisible(), false);
      assert.strictEqual(await page.locator('#storeGateBtn').getAttribute('href'), STORE);
      await page.screenshot({ path: '/tmp/vs-gate-browser.png', fullPage: true });
      await page.waitForRequest((req) => req.url().startsWith(STORE), { timeout: 6000 });
      assert.deepStrictEqual(errors, []);
      await context.close();
    }

    // ?stay=1 keeps the gate on screen so the button can be read.
    {
      storeHits.length = 0;
      const context = await browser.newContext();
      const page = await context.newPage();
      await track(page);
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(4000);
      assert.strictEqual(storeHits.length, 0, 'stay=1 must not redirect');
      await page.locator('#storeGateBtn').click();
      await page.waitForTimeout(300);
      assert.ok(storeHits.some((url) => url.startsWith(STORE)), 'button opens the listing');
      await context.close();
    }

    // Crawlers see the gate and are not redirected.
    {
      storeHits.length = 0;
      const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
      });
      const page = await context.newPage();
      await track(page);
      await page.goto(origin + '/index.html', { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(4000);
      assert.strictEqual(await page.locator('#storeGate h1').innerText(), 'Vision Simulator');
      assert.strictEqual(storeHits.length, 0, 'crawler must not be redirected');
      const og = await page.locator('meta[property="og:title"]').getAttribute('content');
      assert.strictEqual(og, 'Vision Simulator by Dr. Evans');
      await context.close();
    }

    // Capacitor at document start: simulator, no gate, no redirect.
    {
      storeHits.length = 0;
      const context = await browser.newContext();
      await context.addInitScript(() => {
        window.Capacitor = {
          getPlatform: () => 'ios',
          isNativePlatform: () => true,
          isPluginAvailable: () => false,
        };
      });
      const page = await context.newPage();
      await track(page);
      const errors = [];
      page.on('pageerror', (err) => errors.push(String(err)));
      await page.goto(origin + '/index.html', { waitUntil: 'domcontentloaded' });
      assert.strictEqual(await page.evaluate(() => window.__vsSimulatorBooted), true);
      assert.strictEqual(await page.locator('#storeGate').isVisible(), false);
      assert.strictEqual(await page.locator('#compareToggle').isVisible(), true);
      await page.locator('[data-sample="reading"]').click();
      await page.waitForFunction(() => {
        const canvas = document.getElementById('stageCanvas');
        if (!canvas.width || !canvas.height) return false;
        const pixels = canvas.getContext('2d').getImageData(0, 0, Math.min(canvas.width, 40), Math.min(canvas.height, 40)).data;
        return Array.prototype.some.call(pixels, (v) => v !== 0);
      }, null, { timeout: 3000 });
      await page.screenshot({ path: '/tmp/vs-gate-native.png', fullPage: true });
      await page.waitForTimeout(3500);
      assert.strictEqual(storeHits.length, 0, 'native app must not be sent to the App Store');
      assert.deepStrictEqual(errors, []);
      await context.close();
    }

    // Bridge handler only (older shell, no Capacitor object): still the simulator.
    {
      const context = await browser.newContext();
      await context.addInitScript(() => {
        window.webkit = { messageHandlers: { bridge: { postMessage: () => {} } } };
      });
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      assert.strictEqual(await page.evaluate(() => window.__vsSimulatorBooted), true);
      assert.strictEqual(await page.locator('#storeGate').isVisible(), false);
      await context.close();
    }

    // Detection script missing: fail open to the simulator.
    {
      const context = await browser.newContext();
      const page = await context.newPage();
      await page.route('**/shell-detect.js*', (route) => route.abort());
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      assert.strictEqual(await page.evaluate(() => window.__vsSimulatorBooted), true);
      assert.strictEqual(await page.locator('#compareToggle').isVisible(), true);
      await context.close();
    }

    // Capacitor appears late: leave the gate and boot the simulator, do not redirect.
    {
      storeHits.length = 0;
      const context = await browser.newContext();
      await context.addInitScript(() => {
        setTimeout(() => {
          window.Capacitor = { getPlatform: () => 'ios', isNativePlatform: () => true };
        }, 400);
      });
      const page = await context.newPage();
      await track(page);
      await page.goto(origin + '/index.html', { waitUntil: 'domcontentloaded' });
      assert.strictEqual(await page.evaluate(() => document.documentElement.classList.contains('is-browser')), true);
      await page.waitForFunction(() => window.__vsSimulatorBooted === true, null, { timeout: 3000 });
      await page.waitForTimeout(4000);
      assert.strictEqual(storeHits.length, 0, 'late native signal must cancel the redirect');
      await context.close();
    }

    // deviceready alone is a native shell, even with no Capacitor object yet.
    {
      const context = await browser.newContext();
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      assert.strictEqual(await page.evaluate(() => window.__vsSimulatorBooted === true), false);
      await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
      await page.waitForFunction(() => window.__vsSimulatorBooted === true);
      await context.close();
    }

    // Current binary with the purchase plugin: Pro stays locked, Compare does not count.
    {
      const context = await browser.newContext();
      await context.addInitScript(() => {
        const chain = () => proxy;
        const proxy = new Proxy({}, { get: () => chain });
        window.CdvPurchase = {
          store: {
            register: () => {},
            when: () => proxy,
            get: () => null,
            owned: () => false,
            initialize: () => {},
          },
          ProductType: { NON_CONSUMABLE: 'non_consumable' },
          Platform: { APPLE_APPSTORE: 'ios' },
        };
        window.Capacitor = {
          getPlatform: () => 'ios',
          isNativePlatform: () => true,
          isPluginAvailable: () => false,
        };
      });
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
      await page.waitForTimeout(100);
      await page.locator('[data-cond="glaucoma"]').click();
      assert.strictEqual(await page.locator('#paywallOverlay').evaluate((el) => el.classList.contains('open')), true);
      await page.locator('#paywallClose').click();
      await page.locator('#compareToggle').click();
      assert.strictEqual(await page.locator('#compareToggle').getAttribute('aria-pressed'), 'false');
      assert.strictEqual(await page.evaluate(() => localStorage.getItem('vs_compareUses')), null);
      await context.close();
    }

    // Older binary: Capacitor, no purchase plugin. Pro features stay unlocked.
    {
      const context = await browser.newContext();
      await context.addInitScript(() => {
        window.Capacitor = {
          getPlatform: () => 'ios',
          isNativePlatform: () => true,
          isPluginAvailable: (name) => name === 'InAppReview',
          registerPlugin: () => ({ requestReview: () => Promise.resolve() }),
        };
        window.__reviewCalls = 0;
        const real = window.Capacitor.registerPlugin;
        window.Capacitor.registerPlugin = (name) => {
          const plugin = real(name);
          return {
            requestReview: () => {
              window.__reviewCalls += 1;
              return plugin.requestReview();
            },
          };
        };
      });
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      await page.evaluate(() => document.dispatchEvent(new Event('deviceready')));
      await page.locator('[data-cond="glaucoma"]').click();
      assert.strictEqual(await page.locator('[data-cond="glaucoma"]').getAttribute('aria-pressed'), 'true');
      assert.strictEqual(await page.locator('#paywallOverlay').evaluate((el) => el.classList.contains('open')), false);
      for (let i = 0; i < 5; i += 1) await page.locator('#compareToggle').click();
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 1, 'review asked on the 3rd Compare on');
      assert.strictEqual(await page.evaluate(() => localStorage.getItem('vs_compareUses')), '3');
      await page.locator('#compareToggle').click();
      await page.locator('#compareToggle').click();
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 1, 'does not ask again');
      await context.close();
    }

    // Plugin absent: Compare still works and never calls review.
    {
      const context = await browser.newContext();
      await context.addInitScript(() => {
        window.__reviewCalls = 0;
        window.Capacitor = {
          getPlatform: () => 'ios',
          isNativePlatform: () => true,
          isPluginAvailable: () => false,
          registerPlugin: () => {
            window.__reviewCalls += 1;
            return { requestReview: () => Promise.resolve() };
          },
        };
      });
      const page = await context.newPage();
      await page.goto(origin + '/index.html?stay=1', { waitUntil: 'domcontentloaded' });
      for (let i = 0; i < 5; i += 1) await page.locator('#compareToggle').click();
      assert.strictEqual(await page.evaluate(() => window.__reviewCalls), 0);
      assert.strictEqual(await page.locator('#compareToggle').getAttribute('aria-pressed'), 'true');
      await context.close();
    }

    console.log('gate-behavior: ok');
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
