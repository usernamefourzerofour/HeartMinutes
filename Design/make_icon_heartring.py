# Variant af app-ikonet: hjerte-ring som komplikationen (spor, stigende farveintensitet, prik).
# Brug: python3 make_icon_heartring.py ud.png [rød|mørk]
import math, sys
from PIL import Image, ImageDraw
N, SS = 1024, 4
W = N * SS
k = W / 220.0
def bez(p0, p1, p2, p3, n=400):
    return [((1-t)**3*p0[0]+3*(1-t)**2*t*p1[0]+3*(1-t)*t*t*p2[0]+t**3*p3[0],
             (1-t)**3*p0[1]+3*(1-t)**2*t*p1[1]+3*(1-t)*t*t*p2[1]+t**3*p3[1]) for t in [i/n for i in range(n+1)]]
# Omrids fra kløften og med uret (samme som HeartOutlineShape), skaleret lidt ind så stregen er plads.
pts = (bez((110,74),(116,58),(136,46),(158,62)) + bez((158,62),(186,82),(180,128),(110,178))
       + bez((110,178),(40,128),(34,82),(62,62)) + bez((62,62),(84,46),(104,58),(110,74)))
s, cx, cy = 1.06, 110, 113
pts = [((x-110)*s+cx, (y-112)*s+cy) for x, y in pts]
pts = [(x*k, y*k) for x, y in pts]
L = [0.0]
for i in range(1, len(pts)): L.append(L[-1] + math.dist(pts[i], pts[i-1]))
total = L[-1]
style = sys.argv[2] if len(sys.argv) > 2 else "rød"
lw = 19 * k
frac = 2 / 3
img = Image.new("RGB", (W, W))
d = ImageDraw.Draw(img)
if style == "rød":
    top, bottom = (0xff, 0x5a, 0x6e), (0xd8, 0x1b, 0x3c)
    for y in range(W):
        t = y / (W - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    bgc = lambda y: tuple(round(a + (b - a) * y / (W - 1)) for a, b in zip(top, bottom))
    def col(t, y):   # hvid med stigende dækning over baggrunden
        a = 0.35 + 0.65 * t; b = bgc(y)
        return tuple(round(b[i] * (1 - a) + 255 * a) for i in range(3))
    track = lambda y: tuple(round(c * 0.75 + 255 * 0.25) for c in bgc(y))
    dot = (0xd8, 0x1b, 0x3c)
else:
    d.rectangle((0, 0, W, W), fill=(12, 6, 10))
    def col(t, y):   # lys pink → dyb rødpink (som komplikationen)
        return (round(255 * (1 - 0.18 * t)), round(255 * (0.70 - 0.70 * t)), round(255 * (0.82 - 0.58 * t)))
    track = lambda y: (70, 8, 28)
    dot = (255, 255, 255)
def stamp(p, c, r):
    d.ellipse((p[0]-r, p[1]-r, p[0]+r, p[1]+r), fill=c)
for p in pts: stamp(p, track(p[1]), lw / 2)
end = frac * total
for i, p in enumerate(pts):
    if L[i] > end: break
    stamp(p, col(L[i] / end, p[1]), lw / 2)
# Prik ved enden
j = max(i for i in range(len(pts)) if L[i] <= end)
stamp(pts[j], dot, lw * 0.2)
img.resize((N, N), Image.LANCZOS).save(sys.argv[1])
