# Generează iconița aplicației (1024x1024, fără transparență): o casă cu fulger, pe gradient albastru.
import sys
from PIL import Image, ImageDraw, ImageFilter
S = 1024
img = Image.new("RGB", (S, S))
top, bot = (20, 132, 255), (0, 72, 170)
for y in range(S):
    t = y / (S - 1)
    ImageDraw.Draw(img).line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)))
d = ImageDraw.Draw(img)
# umbră
sh = Image.new("L", (S, S), 0); sd = ImageDraw.Draw(sh)
house = [(512, 205), (812, 455), (812, 815), (212, 815), (212, 455)]
sd.polygon([(x, y + 22) for x, y in house], fill=110)
sh = sh.filter(ImageFilter.GaussianBlur(28))
img.paste((0, 40, 110), (0, 0), sh)
d = ImageDraw.Draw(img)
d.polygon(house, fill=(255, 255, 255))
d.rounded_rectangle([212, 455, 812, 815], radius=46, fill=(255, 255, 255))
# fulger
bolt = [(560, 360), (395, 610), (500, 610), (455, 760), (635, 520), (527, 520)]
d.polygon(bolt, fill=(255, 176, 0))
img.save(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
