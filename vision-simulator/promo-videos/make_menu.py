# Builds menu.png, an original restaurant-menu image used as the AMD video source.
from PIL import Image, ImageDraw, ImageFont
FR = '/usr/share/fonts/truetype/sand-box/google/Fraunces/Fraunces-VariableFont_SOFT,WONK,opsz,wght.ttf'
def f(sz, w):
    ft = ImageFont.truetype(FR, sz); ft.set_variation_by_axes([min(144, sz), w, 0, 0]); return ft
W, H = 1600, 1000
im = Image.new('RGB', (W, H), (246, 240, 226)); d = ImageDraw.Draw(im)
d.rectangle((40, 40, W - 40, H - 40), outline=(120, 90, 60), width=3)
d.text((W // 2, 112), "The Corner Bistro", font=f(80, 600), fill=(70, 45, 30), anchor='mm')
d.text((W // 2, 182), "DINNER MENU", font=f(30, 550), fill=(140, 100, 70), anchor='mm')
d.line((W // 2 - 240, 216, W // 2 + 240, 216), fill=(160, 120, 80), width=2)
cols = [("STARTERS", [("Tomato basil soup", "7"), ("Garden salad", "8"), ("Crispy calamari", "12"), ("Garlic bread", "5")], "house-made, served warm"),
        ("MAINS", [("Grilled salmon", "24"), ("Roast chicken", "19"), ("Mushroom risotto", "17"), ("Steak frites", "28")], "seasonal vegetables")]
for ci, (title, items, sub) in enumerate(cols):
    x0 = 110 + ci * 720; y = 275
    d.text((x0, y), title, font=f(38, 700), fill=(90, 60, 40)); y += 72
    for name, price in items:
        d.text((x0, y), name, font=f(40, 520), fill=(40, 32, 26))
        d.text((x0 + 640, y), price, font=f(40, 560), fill=(40, 32, 26), anchor='ra')
        d.text((x0, y + 50), sub, font=f(25, 450), fill=(120, 100, 85))
        y += 122
d.text((W // 2, H - 108), "Desserts: ask your server", font=f(32, 480), fill=(110, 80, 60), anchor='mm')
im.save(__file__.replace('make_menu.py', 'menu.png'))
