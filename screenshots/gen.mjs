import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const frames = [
  { selector: '.frame-main',     file: '1-main.png' },
  { selector: '.frame-dca',      file: '2-dca.png' },
  { selector: '.frame-goal',     file: '3-goal.png' },
  { selector: '.frame-alert',    file: '4-alert.png' },
  { selector: '.frame-sats',     file: '5-sats.png' },
  { selector: '.frame-settings', file: '6-settings.png' },
];

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'
});
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
