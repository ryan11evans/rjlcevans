import { chromium } from 'playwright-core';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const frames = [
  { selector: '.frame-main',      file: '1-main.png' },
  { selector: '.frame-portfolio', file: '2-portfolio.png' },
  { selector: '.frame-alert',     file: '3-alert.png' },
  { selector: '.frame-widgets',   file: '4-widgets.png' },
  { selector: '.frame-briefing',  file: '5-briefing.png' },
  { selector: '.frame-privacy',   file: '6-privacy.png' },
];

// Use the sandbox's prebuilt Chromium if present; otherwise fall back to
// Playwright's own managed browser (works on a normal Mac after
// `npx playwright install chromium`).
import fs from 'fs';
const sandboxChromium = '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell';
const browser = await chromium.launch(
  fs.existsSync(sandboxChromium) ? { executablePath: sandboxChromium } : {}
);
const context = await browser.newContext({ deviceScaleFactor: 2 });
const page = await context.newPage();
await page.setViewportSize({ width: 3000, height: 4000 });
await page.goto('file://' + path.join(__dirname, 'index.html'));
await page.waitForTimeout(800);

for (const f of frames) {
  const el = page.locator(f.selector).first();
  await el.screenshot({ path: path.join(__dirname, f.file), type: 'png' });
  console.log('Saved', f.file);
}

await browser.close();
