const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUT_DIR = '/Users/ryanevans/rjlcevans-ipad-screens/vision-simulator/app-store-screenshots';

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:8936/ipad-screenshots.html');

  const files = await page.evaluate(() => window.__screens.map(s => s.file));

  // Wait for every canvas to finish drawing.
  await page.waitForFunction((files) => {
    return files.every(f => {
      const c = document.getElementById('canvas-' + f);
      return c && c.dataset.ready === '1';
    });
  }, files, { timeout: 15000 });

  for (const file of files) {
    const dataUrl = await page.evaluate((file) => {
      return document.getElementById('canvas-' + file).toDataURL('image/png');
    }, file);
    const base64 = dataUrl.replace(/^data:image\/png;base64,/, '');
    fs.writeFileSync(path.join(OUT_DIR, file), Buffer.from(base64, 'base64'));
    console.log('saved', file);
  }

  await browser.close();
})();
