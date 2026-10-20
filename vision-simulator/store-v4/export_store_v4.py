"""Render the final App Store PNGs with the existing generators (iphone-/ipad-screenshots.html)."""
import asyncio, base64, io, os
from playwright.async_api import async_playwright
from PIL import Image
OUT = "/workspace/vision-sim/screenshots-v4"
# generator order: hero, amd, cataract, colorblind, free-pro  ->  App Store order used since v2
NAMES = ["1-hero", "3-amd-compare", "2-cataract-night", "4-colorblind", "5-free-pro-499"]
async def main():
    async with async_playwright() as pw:
        b = await pw.chromium.launch()
        for dev, page_name, size in [("iphone", "iphone-screenshots.html", (1320, 2868)), ("ipad", "ipad-screenshots.html", (2064, 2752))]:
            p = await b.new_page()
            errs = []; p.on("console", lambda m: m.type == "error" and errs.append(m.text)); p.on("pageerror", lambda e: errs.append(str(e)))
            await p.goto(f"http://127.0.0.1:8938/{page_name}?cb=1", wait_until="networkidle")
            await p.wait_for_function("document.querySelectorAll('#cards canvas').length === 5")
            await p.wait_for_timeout(3000)
            urls = await p.evaluate("[...document.querySelectorAll('#cards canvas')].map(c => c.toDataURL('image/png'))")
            for name, u in zip(NAMES, urls):
                im = Image.open(io.BytesIO(base64.b64decode(u.split(',')[1])))
                assert im.size == size, (name, im.size)
                im = im.convert("RGB")   # App Store: no alpha channel
                path = f"{OUT}/{dev}-{name}.png"; im.save(path, optimize=True); print("saved", path, im.size, im.mode)
            print(dev, "errors:", errs); await p.close()
        await b.close()
asyncio.run(main())
