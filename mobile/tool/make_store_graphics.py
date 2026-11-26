"""Compose Google Play marketing screenshots and the feature graphic.

Input: raw 1080x2400 app renders (+ .json emoji positions) in RAW_DIR.
Output: docs/play-store/screenshots/*.png (1080x1920) and docs/play-store/feature-graphic.png.

  python tool/make_store_graphics.py <raw_dir>
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RAW = Path(sys.argv[1])
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "play-store"
SHOTS = OUT / "screenshots"
SHOTS.mkdir(parents=True, exist_ok=True)
FONTS = ROOT / "mobile" / "assets" / "fonts"
EMOJI_FONT = Path("C:/Windows/Fonts/seguiemj.ttf")
ICON = Image.open(ROOT / "mobile" / "tool" / "app_icon_master.png").convert("RGBA")

W, H = 1080, 1920
SS = 2  # supersampling for smooth shapes


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"Inter-{weight}.ttf"), size)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(w, h, stops):
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                img.putpixel((0, y), lerp(c0, c1, (t - p0) / (p1 - p0)))
                break
    return img.resize((w, h))


def glow(canvas, cx, cy, r, color, alpha):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (alpha,))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r * 0.55)))


def orbits(canvas, cx, cy, radii, alpha=40):
    layer = Image.new("RGBA", (canvas.width * SS, canvas.height * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, r in enumerate(radii):
        r *= SS
        steps = int(2 * math.pi * r / (14 * SS))
        for i in range(steps):
            if k % 2 == 0 or i % 2 == 0:
                a0 = 2 * math.pi * i / steps
                a1 = a0 + (2 * math.pi / steps) * (0.35 if k % 2 == 0 else 0.2)
                d.arc(
                    [cx * SS - r, cy * SS - r, cx * SS + r, cy * SS + r],
                    math.degrees(a0), math.degrees(a1),
                    fill=(255, 255, 255, alpha), width=2 * SS,
                )
    dots = [(0.18, (127, 246, 191)), (0.42, (255, 221, 181)), (0.71, (221, 225, 255)), (0.9, (255, 255, 255))]
    for t, c in dots:
        r = radii[int(t * len(radii)) % len(radii)] * SS
        a = t * 2 * math.pi
        x, y = cx * SS + r * math.cos(a), cy * SS + r * math.sin(a)
        d.ellipse([x - 7 * SS, y - 7 * SS, x + 7 * SS, y + 7 * SS], fill=c + (170,))
    canvas.alpha_composite(layer.resize(canvas.size, Image.LANCZOS))


def rounded_mask(size, radius):
    w, h = size
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=radius * SS, fill=255)
    return m.resize(size, Image.LANCZOS)


def fix_emoji(img, json_path):
    """Replace tofu boxes from the headless renderer with real emoji glyphs."""
    if not json_path.exists() or not EMOJI_FONT.exists():
        return img
    items = json.loads(json_path.read_text(encoding="utf-8"))
    d = ImageDraw.Draw(img)
    for it in items:
        x, y, w, h = (it[k] * 3 for k in ("x", "y", "w", "h"))
        if y < 72 or y + h > img.height - 10:
            continue
        bg = img.getpixel((max(0, int(x) - 3), int(y + h / 2)))
        d.rectangle([x - 1, y, x + w + 1, y + h], fill=bg)
        size = int(h * 0.78)
        f = ImageFont.truetype(str(EMOJI_FONT), size)
        d.text((x + 2, y + h * 0.1), it["char"], font=f, embedded_color=True)
    return img


def status_bar(img, dark_text=True):
    d = ImageDraw.Draw(img)
    c = (19, 28, 43) if dark_text else (255, 255, 255)
    d.text((54, 18), "9:41", font=font("SemiBold", 38), fill=c)
    # signal
    x0 = img.width - 250
    for i in range(4):
        hgt = 12 + i * 7
        d.rounded_rectangle([x0 + i * 13, 52 - hgt, x0 + i * 13 + 8, 52], radius=2, fill=c)
    # wifi
    wx, wy = img.width - 175, 52
    for i, r in enumerate((30, 21, 12)):
        d.arc([wx - r, wy - r - 4, wx + r, wy + r - 4], 225, 315, fill=c, width=6)
    d.ellipse([wx - 4, wy - 10, wx + 4, wy - 2], fill=c)
    # battery
    bx = img.width - 120
    d.rounded_rectangle([bx, 24, bx + 64, 52], radius=8, outline=c, width=4)
    d.rounded_rectangle([bx + 7, 31, bx + 50, 45], radius=3, fill=c)
    d.rounded_rectangle([bx + 66, 33, bx + 71, 43], radius=2, fill=c)
    return img


def phone(screen, width):
    """Device frame around a 1080x2400 screen, scaled to `width` (outer)."""
    bezel = 26
    inner_w = width - 2 * bezel
    inner_h = round(inner_w * screen.height / screen.width)
    scr = screen.resize((inner_w, inner_h), Image.LANCZOS).convert("RGBA")
    scr.putalpha(rounded_mask(scr.size, 46))
    outer = (width, inner_h + 2 * bezel)
    body = Image.new("RGBA", outer, (0, 0, 0, 0))
    frame = Image.new("RGBA", outer, (16, 22, 40, 255))
    body.paste(frame, (0, 0), rounded_mask(outer, 72))
    # subtle edge highlight
    hl = Image.new("RGBA", outer, (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle([3, 3, outer[0] - 4, outer[1] - 4], radius=70, outline=(90, 104, 150, 160), width=3)
    body.alpha_composite(hl)
    body.alpha_composite(scr, (bezel, bezel))
    # camera punch-hole
    d = ImageDraw.Draw(body)
    cx = outer[0] // 2
    d.ellipse([cx - 11, bezel + 16, cx + 11, bezel + 38], fill=(10, 14, 26, 255))
    return body


def shadow_for(img, offset=(0, 40), blur=50, alpha=120):
    sh = Image.new("RGBA", (img.width + 300, img.height + 300), (0, 0, 0, 0))
    a = img.getchannel("A").point(lambda v: alpha if v > 0 else 0)
    sh.paste((0, 12, 60, 255), (150 + offset[0], 150 + offset[1]), a)
    return sh.filter(ImageFilter.GaussianBlur(blur))


def wrap(draw, text, fnt, max_w):
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        test = (cur + " " + w_).strip()
        if draw.textlength(test, font=fnt) <= max_w:
            cur = test
        else:
            lines.append(cur)
            cur = w_
    lines.append(cur)
    return lines


THEMES = {
    "blue": dict(stops=[(0, (27, 59, 184)), (0.55, (34, 72, 209)), (1, (18, 36, 107))], glow=(127, 246, 191), text=(255, 255, 255), sub=(221, 225, 255), chip=(255, 255, 255, 38)),
    "light": dict(stops=[(0, (241, 243, 255)), (1, (221, 229, 251))], glow=(66, 99, 235), text=(19, 28, 43), sub=(68, 70, 84), chip=(34, 72, 209, 26)),
}


def compose(name, raw, eyebrow, title, subtitle, theme="blue", glow_side=1):
    t = THEMES[theme]
    canvas = vertical_gradient(W, H, t["stops"]).convert("RGBA")
    glow(canvas, W // 2 + glow_side * 340, 980, 360, t["glow"], 70 if theme == "blue" else 55)
    glow(canvas, W // 2 - glow_side * 380, 300, 300, (66, 99, 235) if theme == "blue" else (127, 246, 191), 90)
    if theme == "blue":
        orbits(canvas, W // 2, 1180, [430, 560, 690], alpha=34)
    d = ImageDraw.Draw(canvas)

    # Eyebrow chip
    ef = font("Bold", 30)
    ew = d.textlength(eyebrow.upper(), font=ef) + 56
    chip = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(chip).rounded_rectangle([(W - ew) / 2, 84, (W + ew) / 2, 138], radius=27, fill=t["chip"])
    canvas.alpha_composite(chip)
    d = ImageDraw.Draw(canvas)
    d.text((W / 2, 111), eyebrow.upper(), font=ef, fill=t["sub"] if theme == "blue" else (34, 72, 209), anchor="mm")

    tf = font("Bold", 76)
    y = 172
    for line in wrap(d, title, tf, W - 140):
        d.text((W / 2, y), line, font=tf, fill=t["text"], anchor="ma")
        y += 88
    sf = font("Regular", 36)
    y += 8
    for line in wrap(d, subtitle, sf, W - 200):
        d.text((W / 2, y), line, font=sf, fill=t["sub"], anchor="ma")
        y += 48

    screen = Image.open(RAW / f"{raw}.png").convert("RGB")
    screen = fix_emoji(screen, RAW / f"{raw}.json")
    screen = status_bar(screen)
    device = phone(screen, 640)
    top = max(y + 46, 470)
    x = (W - device.width) // 2
    sh = shadow_for(device)
    canvas.alpha_composite(sh, (x - 150, top - 150))
    canvas.alpha_composite(device, (x, top))
    canvas.convert("RGB").save(SHOTS / f"{name}.png", optimize=True)
    return SHOTS / f"{name}.png"


SHOT_LIST = [
    ("01_dashboard", "home", "Household hub", "Your home at a glance", "Tasks, stock and shopping in one live dashboard.", "blue", 1),
    ("02_inventory", "inventory_list", "Shared inventory", "Know what you have", "Groceries, supplies and appliances, with low-stock alerts.", "light", -1),
    ("03_stock", "inventory_detail", "Smart stock", "Never run out again", "Stock gauges and one-tap tally updates for every item.", "blue", -1),
    ("04_tasks", "tasks_list", "Tasks & requests", "Share the chores fairly", "Assign tasks, set priorities and track progress together.", "light", 1),
    ("05_repairs", "task_detail", "Repairs", "Fix things faster", "Report issues with location, due date and live updates.", "blue", 1),
    ("06_shopping", "shopping_list", "Shopping list", "One list for everyone", "Add, assign and check off items as you shop.", "light", -1),
    ("07_chat", "chat", "Family chat", "Talk it through together", "Turn any message into a task or a shopping item.", "blue", -1),
]


def feature_graphic():
    fw, fh = 1024, 500
    c = vertical_gradient(fw, fh, THEMES["blue"]["stops"]).convert("RGBA")
    glow(c, 820, 260, 260, (127, 246, 191), 60)
    glow(c, 140, 60, 220, (66, 99, 235), 110)
    orbits(c, 220, 250, [150, 205, 260], alpha=40)
    icon = ICON.resize((200, 200), Image.LANCZOS)
    sh = shadow_for(icon, offset=(0, 18), blur=28, alpha=110)
    c.alpha_composite(sh, (120 - 150, 150 - 150))
    c.alpha_composite(icon, (120, 150))
    d = ImageDraw.Draw(c)
    d.text((380, 150), "HomeCircle", font=font("Bold", 78), fill=(255, 255, 255))
    d.text((384, 250), "One home. Every detail connected.", font=font("Regular", 32), fill=(221, 225, 255))
    px = 384
    for label, color in (("Inventory", (127, 246, 191)), ("Chores", (255, 185, 86)), ("Shopping", (221, 225, 255)), ("Chat", (255, 255, 255))):
        f = font("SemiBold", 24)
        w = d.textlength(label, font=f) + 48
        pill = Image.new("RGBA", c.size, (0, 0, 0, 0))
        pd = ImageDraw.Draw(pill)
        pd.rounded_rectangle([px, 318, px + w, 362], radius=22, fill=(255, 255, 255, 34))
        pd.ellipse([px + 16, 335, px + 26, 345], fill=color + (255,))
        c.alpha_composite(pill)
        d = ImageDraw.Draw(c)
        d.text((px + 34, 340), label, font=f, fill=(255, 255, 255), anchor="lm")
        px += w + 12
    c.convert("RGB").save(OUT / "feature-graphic.png", optimize=True)


if __name__ == "__main__":
    for row in SHOT_LIST:
        print(compose(*row))
    feature_graphic()
    ICON.resize((512, 512), Image.LANCZOS).save(OUT / "app-icon-512.png", optimize=True)
    print("feature graphic + icon done")
