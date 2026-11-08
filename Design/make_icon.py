# Tegner app-ikonet (hjerte, 2/3 fejet) som 1024x1024 PNG uden gennemsigtighed.
import math, sys
from PIL import Image, ImageDraw
N, SS = 1024, 4
W = N * SS
k = W / 220.0
def bez(p0, p1, p2, p3, n=200):
    return [((1-t)**3*p0[0]+3*(1-t)**2*t*p1[0]+3*(1-t)*t*t*p2[0]+t**3*p3[0],
             (1-t)**3*p0[1]+3*(1-t)**2*t*p1[1]+3*(1-t)*t*t*p2[1]+t**3*p3[1]) for t in [i/n for i in range(n+1)]]
heart = (bez((110,178),(40,128),(34,82),(62,62)) + bez((62,62),(84,46),(104,58),(110,74))
         + bez((110,74),(116,58),(136,46),(158,62)) + bez((158,62),(186,82),(180,128),(110,178)))
heart = [(x*k, y*k) for x, y in heart]
top, bottom = (0xff, 0x5a, 0x6e), (0xd8, 0x1b, 0x3c)
img = Image.new("RGB", (W, W))
d = ImageDraw.Draw(img)
for y in range(W):
    t = y / (W - 1)
    d.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
mask = Image.new("L", (W, W), 0); ImageDraw.Draw(mask).polygon(heart, fill=255)
img.paste(Image.new("RGB", (W, W), "white"), (0, 0), mask.point(lambda v: v * 0.38))
frac = 2 / 3
cx, cy, r = 110 * k, 110 * k, 140 * k
sector = [(cx, cy)] + [(cx + r * math.sin(a), cy - r * math.cos(a))
                       for a in [frac * 2 * math.pi * i / 200 for i in range(201)]]
smask = Image.new("L", (W, W), 0); ImageDraw.Draw(smask).polygon(sector, fill=255)
both = Image.composite(mask, Image.new("L", (W, W), 0), smask)
img.paste(Image.new("RGB", (W, W), "white"), (0, 0), both)
img.resize((N, N), Image.LANCZOS).save(sys.argv[1])
