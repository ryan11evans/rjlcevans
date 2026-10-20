"""Raw App Store screens from the UI v2 app (same 5 concepts as screenshots-v2).
Writes screens/s1-hero.png, s2-amd-compare.png, s3-cataract-night.png, s5-colorblind-compare.png,
s4-conditions-freepro.png (iPhone 1260x2736) and ipad-* (2064x2752) into OUT_DIR."""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from cap import *
BASE = os.environ.get("APP_URL", "http://127.0.0.1:8936/vision-simulator/")
OUT = os.environ.get("OUT_DIR", "/workspace/vs-shots/vision-simulator/screens")
FACE = "/workspace/vs-shots/vision-simulator/screens/src/hero-face.jpg"
TMP = "/tmp/vs-store"; os.makedirs(TMP, exist_ok=True)
DEVICES = [("", 420, 912, 3, False), ("ipad-", 1032, 1376, 2, True)]

async def set_compare(p, on):
    cur = await p.evaluate("document.getElementById('compareSwitch').getAttribute('aria-checked') === 'true'")
    if cur != on: await p.evaluate("document.getElementById('compareSwitch').click()"); await p.wait_for_timeout(300)
async def compare(p, split):
    await set_compare(p, True)
    if abs(split-0.5) > 0.01:
        box = await p.locator('.stage-wrap').bounding_box(); y = box['y'] + box['height']*0.55
        await p.mouse.move(box['x']+box['width']*0.5, y); await p.mouse.down()
        await p.mouse.move(box['x']+box['width']*split, y, steps=8); await p.mouse.up()
        await p.wait_for_timeout(300)
async def immersive(p):
    box = await p.locator('.stage-wrap').bounding_box()
    await p.mouse.click(box['x']+box['width']*0.85, box['y']+box['height']*0.8)   # a quick tap = hide the UI
    await p.wait_for_timeout(900)
    assert await p.evaluate("document.documentElement.classList.contains('immersive')")

async def hero(p, ipad):
    await p.set_input_files('#upload', FACE); await p.wait_for_timeout(800)
    await cond(p, 'glaucoma'); await preset(p, 'Severe'); await compare(p, 0.4); await immersive(p)
async def amd(p, ipad):
    await sample(p, 'face'); await cond(p, 'amd'); await preset(p, 'Advanced'); await compare(p, 0.5)
async def cataract(p, ipad):
    await sample(p, 'street'); await cond(p, 'cataract'); await slider(p, 'ctrl_cataractSev', 0.48); await set_compare(p, False)
async def colorblind(p, ipad):
    await sample(p, 'garden'); await cond(p, 'colorblind'); await preset(p, 'Protan (red)'); await compare(p, 0.5); await immersive(p)
async def freepro(p, ipad):
    await p.wait_for_timeout(600)
    await p.evaluate("document.querySelector('.cond[data-cond=\"glaucoma\"]').click()")   # free user taps a Pro condition
    await p.wait_for_timeout(700)
ONLY = os.environ.get("ONLY")
SHOTS = [("s1-hero.png", hero, True), ("s2-amd-compare.png", amd, True), ("s3-cataract-night.png", cataract, True),
         ("s5-colorblind-compare.png", colorblind, True), ("s4-conditions-freepro.png", freepro, False)]

async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as pw:
        b = await pw.chromium.launch(); errors = []
        for fname, fn, pro in [x for x in SHOTS if not ONLY or x[0] in ONLY.split(',')]:
            for prefix, w, h, dpr, ipad in DEVICES:
                top = 24 if ipad else STATUS_PT
                ctx, p = await new_page(b, BASE, w, h-top, dpr=dpr, pro=pro, safe_bottom=20 if ipad else 34)
                p.on("pageerror", lambda e: errors.append(f"{fname}: {e}"))
                p.on("console", lambda m: m.type == "error" and errors.append(f"{fname}: {m.text}"))
                await p.wait_for_timeout(500)
                await fn(p, ipad)
                raw = f"{TMP}/{prefix}{fname}"; await p.screenshot(path=raw)
                chrome(raw, f"{OUT}/{prefix}{fname}", w, h, scale=dpr, ipad=ipad)
                print("saved", prefix+fname, Image.open(f"{OUT}/{prefix}{fname}").size); await ctx.close()
        print("PAGE ERRORS:", errors); await b.close()
if __name__ == "__main__": asyncio.run(main())
