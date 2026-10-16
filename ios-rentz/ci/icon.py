# Generează iconița aplicației Renț (1024x1024, fără transparență):
# trei cărți în evantai (K♥ în față) pe postav verde.
# Rulare: python3 ci/icon.py Rentz/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import math
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024
SS = 2  # supersampling
W = S * SS

FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
         "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
         "/Library/Fonts/Arial Unicode.ttf"]


def font(size):
    for f in FONTS:
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


img = Image.new("RGB", (W, W))
# postav: gradient radial
cx, cy = W / 2, W * 0.42
inner, outer = (24, 120, 80), (5, 42, 27)
px = img.load()
for y in range(0, W, 2):
    for x in range(0, W, 2):
        t = min(1.0, math.hypot(x - cx, y - cy) / (W * 0.75))
        c = tuple(int(a + (b - a) * t) for a, b in zip(inner, outer))
        px[x, y] = c
        if x + 1 < W: px[x + 1, y] = c
        if y + 1 < W:
            px[x, y + 1] = c
            if x + 1 < W: px[x + 1, y + 1] = c

RED, BLACK, WHITE = (204, 18, 45), (26, 27, 29), (251, 250, 245)
cw, ch = int(W * 0.40), int(W * 0.40 * 1.42)


def card(rank, suit, color, pip_x=0.56):
    c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=int(cw * 0.1), fill=WHITE, outline=(200, 198, 190), width=SS * 3)
    f1, f2, f3 = font(int(cw * 0.26)), font(int(cw * 0.2)), font(int(cw * 0.62))
    d.text((cw * 0.08, cw * 0.04), rank, font=f1, fill=color)
    d.text((cw * 0.1, cw * 0.31), suit, font=f2, fill=color)
    d.text((cw * pip_x, ch * 0.58), suit, font=f3, fill=color, anchor="mm")
    return c


def paste_rot(base, c, angle, center):
    r = c.rotate(angle, resample=Image.BICUBIC, expand=True)
    # umbră
    sh = Image.new("RGBA", r.size, (0, 0, 0, 0))
    sh.putalpha(r.split()[3].point(lambda a: int(a * 0.45)))
    sh = sh.filter(ImageFilter.GaussianBlur(W * 0.012))
    x, y = int(center[0] - r.width / 2), int(center[1] - r.height / 2)
    base.paste((0, 0, 0), (x, y + int(W * 0.015)), sh)
    base.paste(r, (x, y), r)


base_y = W * 0.53
paste_rot(img, card("A", "♠", BLACK, 0.42), 22, (W * 0.36, base_y + W * 0.02))
paste_rot(img, card("Q", "♦", RED, 0.74), -22, (W * 0.64, base_y + W * 0.02))
paste_rot(img, card("K", "♥", RED), 0, (W * 0.5, base_y - W * 0.03))

img = img.resize((S, S), Image.LANCZOS)
img.save(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
