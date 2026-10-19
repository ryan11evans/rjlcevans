// Captures still frames of the live app (iOS-emulated: ctx.filter disabled)
// for the promo videos. Usage: node capture.js [OUT_DIR]
// Requires playwright (PW env var can point at its path).
const { chromium } = require(process.env.PW || 'playwright');
const path = require('path'), fs = require('fs');
const APP = process.env.APP_URL || 'https://rjlcevans.com/vision-simulator/index.html';
const OUT = process.argv[2] || path.join(__dirname, 'frames');
fs.mkdirSync(OUT, { recursive: true });

const JOBS = {
  v1: { src: { sample: 'street' }, cond: 'cataract',
        steps: [['normal', null], ...[0.15, 0.3, 0.45, 0.6, 0.75, 0.9].map(v => [`cat${v}`, { slider: ['cataractSev', v] }])] },
  v2: { src: { sample: 'street' }, cond: 'glaucoma',
        steps: [['normal', null], ['mild', { preset: ['glaucomaStages', 'Mild'] }], ['moderate', { preset: ['glaucomaStages', 'Moderate'] }],
                ['severe', { preset: ['glaucomaStages', 'Severe'] }], ['end', { preset: ['glaucomaStages', 'End Stage'] }]] },
  v3: { src: { upload: path.join(__dirname, 'menu.png') }, cond: 'amd',
        steps: [['normal', null], ['mild', { preset: ['amdStages', 'Mild'] }], ['moderate', { preset: ['amdStages', 'Moderate'] }],
                ['advanced', { preset: ['amdStages', 'Advanced'] }]] },
  v3grid: { src: { sample: 'grid' }, cond: 'amd',
        steps: [['normal', null], ['mild', { preset: ['amdStages', 'Mild'] }], ['moderate', { preset: ['amdStages', 'Moderate'] }],
                ['advanced', { preset: ['amdStages', 'Advanced'] }]] },
};

(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [name, j] of Object.entries(JOBS)) {
    const ctx = await b.newContext({ viewport: { width: 560, height: 1000 }, deviceScaleFactor: 2 });
    await ctx.addInitScript(() => {
      window.Capacitor = { isNativePlatform: () => true };
      Object.defineProperty(CanvasRenderingContext2D.prototype, 'filter', { get() { return 'none'; }, set() {}, configurable: true });
    });
    const p = await ctx.newPage();
    p.on('pageerror', e => errs.push(name + ': ' + e.message));
    p.on('console', m => { if (m.type() === 'error') errs.push(name + ': ' + m.text()); });
    await p.goto(APP + '?cb=' + Date.now(), { waitUntil: 'networkidle' }); await p.waitForTimeout(400);
    if (j.src.upload) await p.setInputFiles('#upload', j.src.upload); else await p.click(`#sampleRow [data-sample="${j.src.sample}"]`);
    await p.waitForTimeout(600);
    for (const [lbl, act] of j.steps) {
      if (act) {
        if (!(await p.locator('#ctrl_' + (act.slider ? act.slider[0] : 'x') + ', #' + (act.preset ? act.preset[0] : 'x')).count())) {
          await p.click(`.cond[data-cond="${j.cond}"]`); await p.waitForTimeout(250);
        }
        if (act.slider) await p.evaluate(([id, v]) => { const el = document.getElementById('ctrl_' + id); el.value = v; el.dispatchEvent(new Event('input')); }, act.slider);
        if (act.preset) await p.click(`#${act.preset[0]} .preset:text-is("${act.preset[1]}")`);
        await p.waitForTimeout(300);
      }
      await p.evaluate(() => window.scrollTo(0, 0));
      await p.locator('#stageCanvas').screenshot({ path: path.join(OUT, `${name}_${lbl}.png`) });
    }
    await ctx.close();
  }
  console.log('errors:', JSON.stringify(errs));
  await b.close();
})();
