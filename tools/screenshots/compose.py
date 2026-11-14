"""Composes App Store screenshots: a headline and a subline on a soft background above a framed app screenshot.

Usage: python compose.py SHOTS_DIR OUT_DIR (needs Pillow and the SF Pro Rounded font from macOS).
SHOTS_DIR holds raw Simulator screenshots (iPhone 17 Pro Max, 1320 × 2868) of the app launched with `-DemoData YES`:
raw-1.png Overview, raw-2c.png a workout in the heart rate chart, raw-3.png Settings, raw-4.png Overview in dark mode.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
ACCENT = (224, 5, 69)
FONT = "/System/Library/Fonts/SFNSRounded.ttf"


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient(top, bottom):
    img = Image.new("RGB", (W, H), top)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def wrap(draw, text, f, width):
    words, lines, line = text.split(), [], ""
    for w in words:
        test = (line + " " + w).strip()
        if draw.textlength(test, font=f) <= width or not line:
            line = test
        else:
            lines.append(line)
            line = w
    lines.append(line)
    return lines


def compose(shot, out, title, sub, dark=False, shot_width=1040, top=170):
    bg = gradient((44, 8, 22), (12, 2, 8)) if dark else gradient((255, 241, 245), (255, 220, 231))
    d = ImageDraw.Draw(bg)
    title_f, sub_f = font(100, "Bold"), font(52, "Medium")
    y = top
    for line in wrap(d, title, title_f, W - 140):
        d.text((W / 2, y), line, font=title_f, fill=(255, 92, 140) if dark else ACCENT, anchor="ma")
        y += 116
    y += 18
    for line in wrap(d, sub, sub_f, W - 200):
        d.text((W / 2, y), line, font=sub_f, fill=(225, 205, 212) if dark else (88, 64, 72), anchor="ma")
        y += 66
    y += 56

    img = Image.open(shot).convert("RGB")
    h = round(img.height * shot_width / img.width)
    img = img.resize((shot_width, h), Image.LANCZOS)
    radius = 96
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    x = (W - shot_width) // 2
    # Soft shadow and a thin frame.
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x - 6, y + 14, x + shot_width + 6, y + h + 26], radius + 6,
                                             fill=(0, 0, 0, 110 if dark else 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    bg.paste(shadow, (0, 0), shadow)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle([x - 10, y - 10, x + shot_width + 10, y + h + 10], radius + 10,
                        fill=(70, 70, 76) if dark else (255, 255, 255))
    bg.paste(img, (x, y), mask)
    bg.save(out)


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    compose(f"{src}/raw-1.png", f"{dst}/1-week.png", "Your week, one number",
            "Workouts and everyday activity both count")
    compose(f"{src}/raw-2c.png", f"{dst}/2-workouts.png", "Every workout in detail",
            "Heart rate and zones for each workout")
    compose(f"{src}/raw-3.png", f"{dst}/3-zones.png", "Your zones, your rules",
            "2 or 5 zones, from your age or max heart rate")
    compose(f"{src}/raw-4.png", f"{dst}/5-private.png", "Private by design",
            "No servers, no accounts, no tracking", dark=True)
