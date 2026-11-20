"""Generate HomeCircle launcher, adaptive, monochrome, splash and store icons.

Run from the repo root with Pillow installed (the backend venv has it):
  backend/.venv/Scripts/python.exe mobile/tool/generate_launcher_icons.py \
    mobile/android/app/src/main/res docs/images/homecircle-play-icon-512.png .tmp/icon_preview.png
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

RES = Path(sys.argv[1])  # mobile/android/app/src/main/res
STORE = Path(sys.argv[2])  # 512px Play Store icon output path
PREVIEW = Path(sys.argv[3])  # preview sheet

BLUE_TOP = (0x42, 0x63, 0xEB)
BLUE_BOTTOM = (0x22, 0x48, 0xD1)
WHITE = (255, 255, 255, 255)
GREEN = (0x7F, 0xF6, 0xBF, 255)
SS = 16  # supersampling: pixels per adaptive-icon unit (108 units wide)
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def mark(door_color, size_units=108):
    """House inside a ring, drawn in a 108-unit adaptive canvas (safe zone r=33)."""
    n = size_units * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def u(v):
        return round(v * SS)

    c = 54
    # Ring
    d.ellipse([u(c - 31), u(c - 31), u(c + 31), u(c + 31)], outline=WHITE, width=u(4.5))
    # Roof: a rounded chevron
    d.line(
        [(u(36), u(51)), (u(54), u(35)), (u(72), u(51))],
        fill=WHITE,
        width=u(5),
        joint="curve",
    )
    for x, y in ((36, 51), (54, 35), (72, 51)):
        d.ellipse([u(x - 2.5), u(y - 2.5), u(x + 2.5), u(y + 2.5)], fill=WHITE)
    # Body
    d.rounded_rectangle([u(41), u(48), u(67), u(72)], radius=u(3), fill=WHITE)
    # Door (green, or cut out for monochrome)
    door = [u(50), u(58), u(58), u(72)]
    if door_color is None:
        d.rounded_rectangle(door, radius=u(3.5), fill=(0, 0, 0, 0))
    else:
        d.rounded_rectangle(door, radius=u(3.5), fill=door_color)
    return img


def gradient(n):
    column = Image.new("RGBA", (1, 256))
    for y in range(256):
        t = y / 255
        column.putpixel(
            (0, y),
            tuple(round(a + (b - a) * t) for a, b in zip(BLUE_TOP, BLUE_BOTTOM))
            + (255,),
        )
    return column.resize((n, n), Image.BILINEAR)


def legacy(size, round_mask):
    n = 108 * SS
    base = gradient(n)
    # Crop the central 80 units so the ring fills more of a legacy icon.
    fg = (
        mark(GREEN)
        .crop((14 * SS, 14 * SS, 94 * SS, 94 * SS))
        .resize((n, n), Image.LANCZOS)
    )
    base.alpha_composite(fg)
    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    if round_mask:
        md.ellipse([0, 0, n - 1, n - 1], fill=255)
    else:
        md.rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=255)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def save(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)


foreground = mark(GREEN)
monochrome = mark(None)
for name, scale in DENSITIES.items():
    folder = RES / f"mipmap-{name}"
    folder.mkdir(parents=True, exist_ok=True)
    legacy(round(48 * scale), False).save(folder / "ic_launcher.png", optimize=True)
    legacy(round(48 * scale), True).save(
        folder / "ic_launcher_round.png", optimize=True
    )
    save(foreground, folder / "ic_launcher_foreground.png", round(108 * scale))
    save(monochrome, folder / "ic_launcher_monochrome.png", round(108 * scale))
    # Splash logo: the mark alone at 160dp (classic splash, pre-Android 12).
    save(
        foreground.crop((14 * SS, 14 * SS, 94 * SS, 94 * SS)),
        RES / f"drawable-{name}" / "launch_logo.png",
        round(120 * scale),
    )

STORE.parent.mkdir(parents=True, exist_ok=True)
store = gradient(108 * SS)
store.alpha_composite(
    mark(GREEN)
    .crop((14 * SS, 14 * SS, 94 * SS, 94 * SS))
    .resize((108 * SS, 108 * SS), Image.LANCZOS)
)
store.convert("RGB").resize((512, 512), Image.LANCZOS).save(STORE, optimize=True)

# Preview: legacy square, round, adaptive circle crop, monochrome on dark.
sheet = Image.new("RGBA", (4 * 220 + 20, 240), (240, 242, 250, 255))
sheet.alpha_composite(legacy(192, False), (20, 24))
sheet.alpha_composite(legacy(192, True), (240, 24))
adaptive = gradient(432)
adaptive.alpha_composite(foreground.resize((432, 432), Image.LANCZOS))
m = Image.new("L", (432, 432), 0)
ImageDraw.Draw(m).ellipse([36, 36, 396, 396], fill=255)
a = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
a.paste(adaptive, (0, 0), m)
sheet.alpha_composite(
    a.crop((36, 36, 396, 396)).resize((192, 192), Image.LANCZOS), (460, 24)
)
dark = Image.new("RGBA", (192, 192), (40, 48, 65, 255))
dark.alpha_composite(
    monochrome.crop((14 * SS, 14 * SS, 94 * SS, 94 * SS)).resize(
        (192, 192), Image.LANCZOS
    )
)
sheet.alpha_composite(dark, (680, 24))
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
sheet.save(PREVIEW)
print("icons written")
