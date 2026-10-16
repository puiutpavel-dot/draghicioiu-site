# Generează iconițele Android ale jocului Renț din același desen ca iconița iOS:
# trei cărți în evantai (K♥ în față) pe postav verde.
#   - mipmap-*/ic_launcher.png, ic_launcher_round.png (iconițe clasice)
#   - mipmap-*/ic_launcher_foreground.png (stratul de față pentru iconița adaptivă)
#   - store/icon-512.png și store/feature-graphic-1024x500.png pentru Google Play
# Rulare din android-rentz/: python3 ci/icons.py
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
         "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"]
RED, BLACK, WHITE = (204, 18, 45), (26, 27, 29), (251, 250, 245)
FELT_IN, FELT_OUT = (24, 120, 80), (5, 42, 27)


def font(size):
    for f in FONTS:
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def felt(w, h, cx=0.5, cy=0.42):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - w * cx, y - h * cy) / (max(w, h) * 0.75))
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(FELT_IN, FELT_OUT))
    return img


def card(cw, rank, suit, color, pip_x=0.56):
    ch = int(cw * 1.42)
    c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=int(cw * 0.1), fill=WHITE,
                        outline=(200, 198, 190), width=max(2, cw // 120))
    d.text((cw * 0.08, cw * 0.04), rank, font=font(int(cw * 0.26)), fill=color)
    d.text((cw * 0.1, cw * 0.31), suit, font=font(int(cw * 0.2)), fill=color)
    d.text((cw * pip_x, ch * 0.58), suit, font=font(int(cw * 0.62)), fill=color, anchor="mm")
    return c


def paste_rot(base, c, angle, center, blur):
    r = c.rotate(angle, resample=Image.BICUBIC, expand=True)
    sh = Image.new("RGBA", r.size, (0, 0, 0, 0))
    sh.putalpha(r.split()[3].point(lambda a: int(a * 0.45)))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    x, y = int(center[0] - r.width / 2), int(center[1] - r.height / 2)
    shadow = Image.new("RGBA", r.size, (0, 0, 0, 255))
    shadow.putalpha(sh.split()[3])
    base.alpha_composite(shadow, (x, y + int(blur * 1.2)))
    base.alpha_composite(r, (x, y))


def fan(size, scale=1.0):
    """Evantaiul de cărți pe fundal transparent, centrat, pe o pânză size×size."""
    W = size
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cw = int(W * 0.40 * scale)
    by = W * 0.53
    off = W * 0.14 * scale
    paste_rot(layer, card(cw, "A", "♠", BLACK, 0.42), 22, (W / 2 - off, by + W * 0.02 * scale), W * 0.012)
    paste_rot(layer, card(cw, "Q", "♦", RED, 0.74), -22, (W / 2 + off, by + W * 0.02 * scale), W * 0.012)
    paste_rot(layer, card(cw, "K", "♥", RED), 0, (W / 2, by - W * 0.03 * scale), W * 0.012)
    return layer


def full_icon(px):
    big = 1024
    base = felt(big, big).convert("RGBA")
    base.alpha_composite(fan(big))
    return base.convert("RGB").resize((px, px), Image.LANCZOS)


def round_mask(img):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).ellipse([0, 0, img.size[0] - 1, img.size[1] - 1], fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


DENS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
RES = "app/src/main/res"
master = full_icon(1024)
_f = fan(1024, scale=0.62)  # zona sigură a iconiței adaptive: ~66% din mijloc
_bb = _f.getbbox()
fg_master = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
fg_master.alpha_composite(_f.crop(_bb), ((1024 - (_bb[2] - _bb[0])) // 2, (1024 - (_bb[3] - _bb[1])) // 2))
for d, px in DENS.items():
    folder = f"{RES}/mipmap-{d}"
    os.makedirs(folder, exist_ok=True)
    ic = master.resize((px, px), Image.LANCZOS)
    rounded = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    m = Image.new("L", (px, px), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, px - 1, px - 1], radius=int(px * 0.18), fill=255)
    rounded.paste(ic, (0, 0), m)
    rounded.save(f"{folder}/ic_launcher.png")
    round_mask(ic).save(f"{folder}/ic_launcher_round.png")
    fg = int(px * 108 / 48)
    fg_master.resize((fg, fg), Image.LANCZOS).save(f"{folder}/ic_launcher_foreground.png")

os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
for name in ("ic_launcher", "ic_launcher_round"):
    with open(f"{RES}/mipmap-anydpi-v26/{name}.xml", "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')

os.makedirs("store", exist_ok=True)
master.resize((512, 512), Image.LANCZOS).save("store/icon-512.png")

# Grafica de prezentare (1024×500): postav, evantaiul în dreapta, titlul în stânga.
fg = felt(1024, 500, cx=0.7, cy=0.5).convert("RGBA")
f = fan(560)
fg.alpha_composite(f, (560, -40))
d = ImageDraw.Draw(fg)
d.text((70, 120), "MASA DE", font=font(52), fill=(241, 190, 80))
d.text((64, 170), "RENȚ", font=font(132), fill=WHITE)
d.text((72, 375), "Jocul de cărți românesc", font=font(30), fill=(220, 225, 220))
fg.convert("RGB").save("store/feature-graphic-1024x500.png")
print("ok")
