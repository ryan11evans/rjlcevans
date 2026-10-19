"""Vision Simulator promo videos (9:16, 1080x1920, 30 fps, burned-in captions).

Stills come from the live app (capture.js, iOS-emulated). Compare wipes are
composited here exactly like the app's Compare mode: left of the divider is
the unmodified image and right is the simulated one.

  node capture.js frames            # stills from the live app
  python3 make_videos.py frames out # writes out/v1-cataract-night.mp4 etc.

Text stays inside the short-video safe zone: centered, x 140-940, above y 1500.
"""
import json, math, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FR_DIR = sys.argv[1] if len(sys.argv) > 1 else 'frames'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'out'
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1080, 1920, 30
NOTO = '/usr/share/fonts/truetype/sand-box/google/Noto Sans/NotoSans-VariableFont_wdth,wght.ttf'
FRA = '/usr/share/fonts/truetype/sand-box/google/Fraunces/Fraunces-VariableFont_SOFT,WONK,opsz,wght.ttf'
ICON = os.path.join(HERE, '..', 'visionsim-icon-1024.PNG')
ACCENT = (242, 196, 141)
TEXT_MAX_W, TEXT_X0, TEXT_X1, TEXT_YMAX = 800, 140, 940, 1500

def noto(sz, w):
    f = ImageFont.truetype(NOTO, sz); f.set_variation_by_axes([w, 100]); return f
def fra(sz, w):
    f = ImageFont.truetype(FRA, sz); f.set_variation_by_axes([min(144, sz), w, 0, 0]); return f

F_HOOK, F_STEP, F_PILL, F_EYEBROW = noto(64, 800), noto(50, 650), noto(26, 650), noto(30, 600)
F_END_T, F_END_S, F_END_C, F_END_D = fra(96, 600), noto(54, 700), noto(44, 600), noto(38, 500)

def load(name):
    return Image.open(os.path.join(FR_DIR, name + '.png')).convert('RGB')

def wrap(d, text, font, maxw):
    words, lines, cur = text.split(), [], ''
    for wd in words:
        t = (cur + ' ' + wd).strip()
        if d.textlength(t, font=font) <= maxw: cur = t
        else: lines.append(cur); cur = wd
    if cur: lines.append(cur)
    return lines

BBOX = []
def text_block(d, text, font, y, fill, lh, tag, t):
    lines = wrap(d, text, font, TEXT_MAX_W)
    for i, ln in enumerate(lines):
        yy = y + i * lh
        d.text((W // 2, yy), ln, font=font, fill=fill, anchor='ma')
        x0, y0, x1, y1 = d.textbbox((W // 2, yy), ln, font=font, anchor='ma')
        BBOX.append(dict(t=t, tag=tag, x0=x0, y0=y0, x1=x1, y1=y1))
    return y + len(lines) * lh

def background():
    bg = Image.new('RGB', (W, H))
    top, bot = (13, 19, 28), (26, 36, 51)
    d = ImageDraw.Draw(bg)
    for y in range(H):
        k = y / H; d.line((0, y, W, y), fill=tuple(int(top[i] + (bot[i] - top[i]) * k) for i in range(3)))
    return bg
BG = background()

def pill(img, xy, text, anchor_right=False):
    d = ImageDraw.Draw(img, 'RGBA')
    tw = d.textlength(text, font=F_PILL) + 2 * len(text)
    w, h = int(tw + 36), 46
    x, y = xy
    if anchor_right: x -= w
    d.rounded_rectangle((x, y, x + w, y + h), radius=23, fill=(0, 0, 0, 130))
    cx = x + 18
    for ch in text:   # letter-spaced, like the app's labels
        d.text((cx, y + h // 2), ch, font=F_PILL, fill=(255, 255, 255), anchor='lm'); cx += d.textlength(ch, font=F_PILL) + 2

def zoom(img, z):
    if z <= 1.0001: return img
    w, h = img.size; cw, ch = w / z, h / z
    return img.crop(((w - cw) / 2, (h - ch) / 2, (w + cw) / 2, (h + ch) / 2)).resize((w, h), Image.LANCZOS)

def wipe(normal, cond, split, cond_label):
    w, h = normal.size; sx = int(round(w * split))
    out = cond.copy(); out.paste(normal.crop((0, 0, sx, h)), (0, 0))
    d = ImageDraw.Draw(out, 'RGBA')
    d.rectangle((sx - 2, 0, sx + 2, h), fill=(255, 255, 255, 235))
    r = 40; cy = h // 2
    d.ellipse((sx - r, cy - r, sx + r, cy + r), fill=(255, 255, 255, 245))
    for s in (-1, 1):   # the app's ↔ handle
        d.polygon([(sx + s * 22, cy), (sx + s * 8, cy - 10), (sx + s * 8, cy + 10)], fill=(20, 26, 36))
    d.rectangle((sx - 9, cy - 2, sx + 9, cy + 2), fill=(20, 26, 36))
    pill(out, (24, 22), 'NORMAL'); pill(out, (w - 24, 22), cond_label, anchor_right=True)
    return out

def blend(a, b, k):
    k = max(0.0, min(1.0, k)); k = k * k * (3 - 2 * k)
    return Image.blend(a, b, k)

def ease(k):
    k = max(0.0, min(1.0, k)); return k * k * (3 - 2 * k)

STAGE_W = W; STAGE_Y = 640
def compose(stage, hook, step, t, label=None):
    img = BG.copy(); d = ImageDraw.Draw(img)
    # eyebrow + hook
    d.text((W // 2, 168), 'V I S I O N   S I M U L A T O R', font=F_EYEBROW, fill=(212, 165, 116), anchor='ma')
    BBOX.append(dict(t=t, tag='eyebrow', **dict(zip(('x0', 'y0', 'x1', 'y1'), d.textbbox((W // 2, 168), 'V I S I O N   S I M U L A T O R', font=F_EYEBROW, anchor='ma')))))
    text_block(d, hook, F_HOOK, 240, (255, 255, 255), 82, 'hook', t)
    st = stage.resize((STAGE_W, int(stage.height * STAGE_W / stage.width)), Image.LANCZOS)
    if label: pill(st, (24, 22), label)
    img.paste(st, (0, STAGE_Y))
    if step:
        text_block(d, step, F_STEP, STAGE_Y + st.height + 44, ACCENT, 62, 'step', t)
    return img

def endcard(cta, t, k):
    img = BG.copy(); d = ImageDraw.Draw(img, 'RGBA')
    icon = Image.open(ICON).convert('RGB').resize((300, 300), Image.LANCZOS)
    m = Image.new('L', icon.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, 299, 299), radius=66, fill=255)
    a = ease(k * 2.5)
    y0 = int(330 + (1 - a) * 40)
    img.paste(icon, ((W - 300) // 2, y0), m)
    y = text_block(d, 'Vision Simulator', F_END_T, y0 + 350, (255, 255, 255), 110, 'end_title', t)
    y = text_block(d, 'Free on the App Store', F_END_S, y + 20, ACCENT, 70, 'end_free', t)
    y = text_block(d, cta, F_END_C, y + 40, (235, 240, 246), 58, 'end_cta', t)
    d.line((W // 2 - 300, y + 50, W // 2 + 300, y + 50), fill=(255, 255, 255, 60), width=2)
    text_block(d, 'Education only, not a diagnosis. See your eye doctor.', F_END_D, y + 90, (200, 208, 218), 52, 'end_disc', t)
    return img

# ---- timelines: list of (seconds, fn(k) -> (stage, step, label)) ----
def V1():
    N = load('v1_normal'); C = {v: load(f'v1_cat{v}') for v in (0.15, 0.3, 0.45, 0.6, 0.75, 0.9)}
    def sev(k):  # 0.3 -> 0.9 through the captured levels
        vs = [0.3, 0.45, 0.6, 0.75, 0.9]; x = k * (len(vs) - 1); i = min(len(vs) - 2, int(x))
        return blend(C[vs[i]], C[vs[i + 1]], x - i)
    return dict(slug='v1-cataract-night', hook="Your mom says she's \u201cfine to drive at night.\u201d This is what cataracts actually do.",
        cta='Search \u201cVision Simulator Eye Disease\u201d', segs=[
        (2.5, lambda k: (N, 'Normal vision', 'NORMAL')),
        (3.5, lambda k: (wipe(N, C[0.3], 1 - ease(k), 'CATARACT'), 'Cataract: halos around every headlight', None)),
        (4.5, lambda k: (sev(k), 'As it worsens: haze, glare, faded color', 'CATARACT \u00b7 MILD \u2192 SEVERE')),
        (3.0, lambda k: (wipe(N, C[0.9], 0.5 * ease(k), 'CATARACT'), 'Left: normal  \u00b7  Right: cataract', None)),
    ])

def V2():
    N = load('v2_normal'); S = [load(f'v2_{s}') for s in ('mild', 'moderate', 'severe', 'end')]
    return dict(slug='v2-glaucoma', hook="Glaucoma steals your side vision so slowly you don't notice. Watch.",
        cta='Get your eye pressure checked.', segs=[
        (2.5, lambda k: (N, 'Normal vision', 'NORMAL')),
        (2.5, lambda k: (blend(N, S[0], k), 'Early: a faint patch you won\u2019t notice', 'GLAUCOMA \u00b7 MILD')),
        (2.5, lambda k: (blend(S[0], S[1], k), 'It spreads, often starting up top', 'GLAUCOMA \u00b7 MODERATE')),
        (2.5, lambda k: (blend(S[1], S[2], k), 'Then half the view fades away', 'GLAUCOMA \u00b7 SEVERE')),
        (2.5, lambda k: (blend(S[2], S[3], k), 'Late: a small island of sight', 'GLAUCOMA \u00b7 END STAGE')),
        (3.0, lambda k: (wipe(N, S[3], ease(k) * 0.55, 'GLAUCOMA'), 'Lost vision doesn\u2019t come back. Early treatment protects it.', None)),
    ])

def V3():
    N = load('v3_normal'); S = [load(f'v3_{s}') for s in ('mild', 'moderate', 'advanced')]
    G = [load(f'v3grid_{s}') for s in ('normal', 'mild', 'moderate', 'advanced')]
    def grid(k):
        x = k * 3; i = min(2, int(x)); return blend(G[i], G[i + 1], x - i)
    return dict(slug='v3-amd-menu', hook='This is what reading a menu looks like with macular degeneration.',
        cta='Try it free on iPhone and iPad.', segs=[
        (2.5, lambda k: (N, 'Normal vision', 'NORMAL')),
        (2.5, lambda k: (blend(N, S[0], k), 'Early AMD: words bend and blur in the center', 'AMD \u00b7 MILD')),
        (2.5, lambda k: (blend(S[0], S[1], k), 'A gray smudge sits where you look', 'AMD \u00b7 MODERATE')),
        (2.5, lambda k: (blend(S[1], S[2], k), 'Side vision stays. The center is lost.', 'AMD \u00b7 ADVANCED')),
        (0.6, lambda k: (blend(S[2], G[0], k), 'Amsler grid: straight lines bow' if k >= 0.5 else 'Side vision stays. The center is lost.', 'AMSLER GRID' if k >= 0.5 else 'AMD \u00b7 ADVANCED')),
        (3.4, lambda k: (grid(k), 'Amsler grid: straight lines bow', 'AMSLER GRID \u00b7 AMD')),
    ])

END_S = 3.5
def render(spec, preview=None):
    global BBOX
    BBOX = []
    total = sum(s for s, _ in spec['segs']) + END_S
    nfr = int(round(total * FPS))
    path = os.path.join(OUT, spec['slug'] + '.mp4')
    if preview is None:
        ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                               '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-shortest',
                               '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
                               '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', path], stdin=subprocess.PIPE)
    frames = range(nfr) if preview is None else [int(p * FPS) for p in preview]
    for fi in frames:
        t = fi / FPS; acc = 0; img = None
        for dur, fn in spec['segs']:
            if t < acc + dur:
                stage, step, label = fn((t - acc) / dur)
                stage = zoom(stage, 1.0 + 0.05 * (t / (total - END_S)))
                img = compose(stage, spec['hook'], step, round(t, 2), label)
                break
            acc += dur
        if img is None:
            img = endcard(spec['cta'], round(t, 2), (t - acc) / END_S)
        if preview is None: ff.stdin.write(img.tobytes())
        else: img.save(f'/tmp/promo/prev_{spec["slug"]}_{t:05.2f}.png')
    if preview is None:
        ff.stdin.close(); ff.wait()
    bad = [b for b in BBOX if b['y1'] > TEXT_YMAX or b['x0'] < TEXT_X0 - 1 or b['x1'] > TEXT_X1 + 1 or abs((b['x0'] + b['x1']) / 2 - 540) > 6]
    uniq = {(b['tag'], b['x0'], b['x1'], b['y1']) for b in bad}
    print(spec['slug'], f'{total:.1f}s', 'safe-zone violations:', len(uniq), sorted(uniq)[:5])
    return path

if __name__ == '__main__':
    which = os.environ.get('ONLY', 'v1,v2,v3').split(',')
    prev = os.environ.get('PREVIEW')
    for name in which:
        spec = {'v1': V1, 'v2': V2, 'v3': V3}[name]()
        render(spec, [float(x) for x in prev.split(',')] if prev else None)
