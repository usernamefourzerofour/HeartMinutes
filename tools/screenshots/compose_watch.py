"""The watch App Store screenshots: headline above the watch app in a simple watch frame.

Usage: python compose_watch.py SHOTS_DIR OUT_DIR, with watch-face.png (the watch face with
the complications) and watch-1.png (the watch app) from the Apple Watch Ultra 3 Simulator (422 × 514).
"""
import sys
from PIL import Image, ImageDraw, ImageFilter
from compose import ACCENT, H, W, font, gradient, wrap


def compose_watch(shot, out, title, sub):
    bg = gradient((255, 241, 245), (255, 220, 231))
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
    img = Image.open(shot).convert("RGB")
    scale = 2.2
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    bezel = 46
    x = (W - img.width) // 2
    top = y + (H - y - img.height) // 2 - 40
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x - bezel, top - bezel + 20, x + img.width + bezel, top + img.height + bezel + 20], 220, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    bg.paste(shadow, (0, 0), shadow)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle([x - bezel - 14, top - bezel - 14, x + img.width + bezel + 14, top + img.height + bezel + 14],
                        236, fill=(255, 122, 40))
    d.rounded_rectangle([x - bezel, top - bezel, x + img.width + bezel, top + img.height + bezel], 220,
                        fill=(10, 10, 12))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], 170, fill=255)
    bg.paste(img, (x, top), mask)
    bg.save(out)


if __name__ == "__main__":
    compose_watch(f"{sys.argv[1]}/watch-face.png", f"{sys.argv[2]}/3-face.png", "On your watch face",
                  "Heart and ring complications")
    compose_watch(f"{sys.argv[1]}/watch-1.png", f"{sys.argv[2]}/7-watch.png", "On your wrist",
                  "Heart ring and chart in the watch app")
