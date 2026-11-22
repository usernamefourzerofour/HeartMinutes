"""The watch App Store screenshot: a headline above two watches in a simple watch frame – the watch face with the
complications at the top left and the watch app at the bottom right, slightly overlapping.

Usage: python compose_watch.py SHOTS_DIR OUT_DIR, with watch-face.png (the watch face with the complications) and
watch-1.png (the watch app) from the Apple Watch Ultra 3 Simulator (422 × 514).
"""
import sys
from PIL import Image, ImageDraw, ImageFilter
from compose import ACCENT, H, W, font, gradient, wrap

SCALE = 2.0
BEZEL = round(46 * SCALE / 2.2)


def headline(bg, title, sub):
    d = ImageDraw.Draw(bg)
    title_f, sub_f = font(100, "Bold"), font(52, "Medium")
    y = 170
    for line in wrap(d, title, title_f, W - 140):
        d.text((W / 2, y), line, font=title_f, fill=ACCENT, anchor="ma")
        y += 116
    y += 18
    for line in wrap(d, sub, sub_f, W - 200):
        d.text((W / 2, y), line, font=sub_f, fill=(88, 64, 72), anchor="ma")
        y += 66
    return y


def watch_size():
    """Outer size of a framed watch (screen + bezel + orange case)."""
    return round(422 * SCALE) + 2 * (BEZEL + 14), round(514 * SCALE) + 2 * (BEZEL + 14)


def draw_watch(bg, shot, x, top):
    """Draws a watch with its screen's top left corner at (x, top)."""
    img = Image.open(shot).convert("RGB")
    img = img.resize((round(img.width * SCALE), round(img.height * SCALE)), Image.LANCZOS)
    b = BEZEL
    radius = round(220 * SCALE / 2.2)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x - b, top - b + 20, x + img.width + b, top + img.height + b + 20], radius, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    bg.paste(shadow, (0, 0), shadow)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle([x - b - 14, top - b - 14, x + img.width + b + 14, top + img.height + b + 14],
                        radius + 16, fill=(255, 122, 40))
    d.rounded_rectangle([x - b, top - b, x + img.width + b, top + img.height + b], radius, fill=(10, 10, 12))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], round(170 * SCALE / 2.2),
                                           fill=255)
    bg.paste(img, (x, top), mask)


def compose_watches(face, app, out, title, sub):
    bg = gradient((255, 241, 245), (255, 220, 231))
    y = headline(bg, title, sub)
    ww, wh = watch_size()
    edge = BEZEL + 14
    margin = 70
    overlap = 240
    total = 2 * wh - overlap
    top = y + (H - y - total) // 2
    draw_watch(bg, face, margin + edge, top + edge)
    draw_watch(bg, app, W - margin - ww + edge, top + wh - overlap + edge)
    bg.save(out)


if __name__ == "__main__":
    compose_watches(f"{sys.argv[1]}/watch-face.png", f"{sys.argv[1]}/watch-1.png", f"{sys.argv[2]}/3-watch.png",
                    "On your wrist", "Complications and the watch app")
