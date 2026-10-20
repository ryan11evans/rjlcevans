"""Capture the Vision Simulator web app the way the iOS Capacitor wrapper shows it.
Wrapper facts (vision-simulator-app/capacitor.config.json): StatusBar overlaysWebView=false,
so the WebView starts BELOW the status bar (env(safe-area-inset-top)=0) but runs under the
home indicator (bottom inset 34pt). We render the WebView area, then composite a status bar
+ Dynamic Island + home indicator so the PNG matches a 6.9" iPhone (440x956 pt @3x)."""
import asyncio, sys, os
from playwright.async_api import async_playwright
from PIL import Image, ImageDraw, ImageFont

STATUS_PT = 62   # status bar height on 16 Pro Max
INIT = r"""
(({pro, ready, hint}) => {
  window.Capacitor = { isNativePlatform: () => true, Plugins: {} };
  // iOS WKWebView ignores ctx.filter; emulate that so captures match the iPhone.
  Object.defineProperty(CanvasRenderingContext2D.prototype, 'filter', { get() { return 'none'; }, set() {}, configurable: true });
  try { localStorage.setItem('vs_isPro', pro ? '1':'0'); if (!hint) localStorage.setItem('vs_ui2_hint','1'); } catch(e){}
  if (!ready) return;
  const cbs = [];
  const chain = { approved(){return chain;}, productUpdated(cb){cbs.push(cb);return chain;}, receiptUpdated(cb){cbs.push(cb);return chain;} };
  const product = { pricing: { price: '$4.99' }, getOffer: () => ({ order(){} }) };
  window.CdvPurchase = {
    store: { register(){}, when(){return chain;}, get(){return product;}, owned(){return pro;},
             initialize(){ setTimeout(()=>cbs.forEach(f=>f()), 30); }, restorePurchases(){} },
    ProductType: { NON_CONSUMABLE: 'nc' }, Platform: { APPLE_APPSTORE: 'ios' } };
})
"""

def font(sz, bold=True):
    for p in ["/usr/share/fonts/truetype/sand-box/google/Inter/Inter-VariableFont_opsz,wght.ttf"]:
        try:
            f = ImageFont.truetype(p, sz)
            try: f.set_variation_by_axes([14, 650 if bold else 400])
            except Exception: pass
            return f
        except Exception: pass
    return ImageFont.load_default()

def chrome(web_png, out, w_pt, h_pt, scale=3, status_bg=(0x15,0x18,0x20), landscape=False, ipad=False, status=True, home=True):
    web = Image.open(web_png).convert("RGB")
    W, H = w_pt*scale, h_pt*scale
    canvas = Image.new("RGB", (W, H), status_bg)
    top = 0 if (landscape or not status) else (24 if ipad else STATUS_PT)*scale
    canvas.paste(web, (0, top))
    d = ImageDraw.Draw(canvas)
    if top:
        if not ipad:  # dynamic island
            iw, ih = 126*scale, 37*scale
            d.rounded_rectangle([(W-iw)//2, 11*scale, (W+iw)//2, 11*scale+ih], radius=ih//2, fill=(0,0,0))
            cy = 11*scale + ih//2
        else:
            cy = 12*scale
        f = font(17*scale if not ipad else 12*scale)
        d.text((46*scale if not ipad else 20*scale, cy), "9:41", fill="white", font=f, anchor="lm")
        x = W - (34 if not ipad else 20)*scale
        # battery
        bw, bh = 27*scale, 13*scale
        d.rounded_rectangle([x-bw, cy-bh//2, x, cy+bh//2], radius=4*scale, outline=(255,255,255), width=max(1,scale))
        d.rounded_rectangle([x-bw+2*scale, cy-bh//2+2*scale, x-2*scale-4*scale, cy+bh//2-2*scale], radius=2*scale, fill="white")
        x -= bw + 8*scale
        for i in range(4):  # signal
            bh2 = (4+i*3)*scale
            d.rounded_rectangle([x-(4-i)*5*scale, cy+6*scale-bh2, x-(4-i)*5*scale+3*scale, cy+6*scale], radius=scale, fill="white")
    if home and not ipad:
        hw = 140*scale if not landscape else 200*scale
        d.rounded_rectangle([(W-hw)//2, H-9*scale, (W+hw)//2, H-4*scale], radius=3*scale, fill=(255,255,255))
    canvas.save(out)

async def new_page(b, url, w, h, dpr=3, pro=False, ready=True, safe_bottom=34, safe_lr=0, hint=False):
    ctx = await b.new_context(viewport={"width": w, "height": h}, device_scale_factor=dpr, has_touch=True, is_mobile=True,
        user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148")
    await ctx.add_init_script(f"({INIT})({{pro:{str(pro).lower()},ready:{str(ready).lower()},hint:{str(hint).lower()}}})")
    # Chromium has no notch: emulate the WebView's real insets by substituting env() values.
    async def route(r):
        resp = await r.fetch()
        body = await resp.text()
        body = body.replace("env(safe-area-inset-top)", "0px").replace("env(safe-area-inset-bottom)", f"{safe_bottom}px") \
                   .replace("env(safe-area-inset-left)", f"{safe_lr}px").replace("env(safe-area-inset-right)", f"{safe_lr}px")
        await r.fulfill(response=resp, body=body)
    async def any_route(r):
        if r.request.resource_type == "document": await route(r)
        else: await r.continue_()
    await ctx.route("**/*", any_route)
    p = await ctx.new_page()
    await p.goto(url)
    await p.wait_for_timeout(400)
    if ready:
        await p.evaluate("document.dispatchEvent(new Event('deviceready'))")
    await p.evaluate("document.fonts.ready")
    await p.wait_for_timeout(500)
    return ctx, p

async def sample(p, k):
    await p.evaluate(f"document.querySelector('[data-sample=\"{k}\"]').click()")
    await p.wait_for_timeout(700)
async def cond(p, c):
    await p.evaluate(f"(()=>{{const b=document.querySelector('.cond[data-cond=\"{c}\"]'); if(b.getAttribute('aria-pressed')!=='true') b.click();}})()")
    await p.wait_for_timeout(500)
async def preset(p, label):
    await p.evaluate(f"[...document.querySelectorAll('.preset')].find(b=>b.textContent.trim()==={label!r}).click()")
    await p.wait_for_timeout(400)
async def slider(p, cid, v):
    await p.evaluate(f"(()=>{{const e=document.getElementById('{cid}'); e.value={v}; e.dispatchEvent(new Event('input'));}})()")
    await p.wait_for_timeout(400)
