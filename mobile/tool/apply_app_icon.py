"""Regenerate every HomeCircle icon from one 1024px master (rounded square, transparent corners).

Run from mobile/ with Pillow installed (master: tool/app_icon_master.png):
  python tool/apply_app_icon.py tool/app_icon_master.png ../docs/images/homecircle-play-icon-512.png
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SRC = Path(sys.argv[1])
STORE = Path(sys.argv[2])
RES = Path("android/app/src/main/res")
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

master = Image.open(SRC).convert("RGBA")
N = master.width


def fill_background(img):
    """Smooth gradient background derived from the artwork (no transparent corners)."""
    import numpy as np

    arr = np.asarray(img).astype("float64")
    alpha = arr[..., 3:4] / 255.0
    # Ignore the near-white house and its glow: keep only saturated blue pixels.
    blue = ((arr[..., 2] - arr[..., 0]) > 60)[..., None] * alpha
    num = Image.fromarray((arr[..., :3] * blue).astype("uint8"))
    den = Image.fromarray((blue[..., 0] * 255).astype("uint8"))
    num = np.asarray(num.filter(ImageFilter.GaussianBlur(120))).astype("float64")
    den = np.asarray(den.filter(ImageFilter.GaussianBlur(120))).astype("float64")[..., None] / 255.0
    out = num / np.maximum(den, 1e-3)
    return Image.fromarray(np.clip(out, 0, 255).astype("uint8"))


background = fill_background(master)
square = background.copy().convert("RGBA")
square.alpha_composite(master)
square = square.convert("RGB")  # opaque full-bleed (iOS, store)


adaptive_square = square.convert("RGBA")


def white_silhouette():
    """Near-white house pixels -> white on transparent, for the themed icon."""
    px = master.load()
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    po = out.load()
    for y in range(N):
        for x in range(N):
            r, g, b, a = px[x, y]
            if a > 200 and r > 225 and g > 230 and b > 235:
                po[x, y] = (255, 255, 255, 255)
    return out


def circle(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.width - 1, img.height - 1], fill=255)
    out = img.convert("RGBA")
    out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    return out


def rounded(img):
    return master.resize(img.size, Image.LANCZOS)


def adaptive_layer(art, scale):
    """108-unit canvas with the artwork scaled into the safe zone."""
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    size = round(N * scale)
    small = art.resize((size, size), Image.LANCZOS)
    canvas.alpha_composite(small, ((N - size) // 2, (N - size) // 2))
    return canvas


foreground = Image.new("RGBA", (N, N), (0, 0, 0, 0))
mono = adaptive_layer(white_silhouette(), 0.86)

for name, d in DENSITIES.items():
    folder = RES / f"mipmap-{name}"
    legacy_px = round(48 * d)
    square.resize((legacy_px,) * 2, Image.LANCZOS).convert("RGBA").save(
        folder / "ic_launcher.png", optimize=True
    )
    circle(square.resize((legacy_px,) * 2, Image.LANCZOS)).save(
        folder / "ic_launcher_round.png", optimize=True
    )
    adaptive_px = round(108 * d)
    foreground.resize((adaptive_px,) * 2, Image.LANCZOS).save(
        folder / "ic_launcher_foreground.png", optimize=True
    )
    mono.resize((adaptive_px,) * 2, Image.LANCZOS).save(
        folder / "ic_launcher_monochrome.png", optimize=True
    )
    # Splash logo: 120dp rounded icon.
    (RES / f"drawable-{name}").mkdir(exist_ok=True)
    master.resize((round(120 * d),) * 2, Image.LANCZOS).save(
        RES / f"drawable-{name}" / "launch_logo.png", optimize=True
    )

# Adaptive background as a bitmap so the gradient matches the artwork.
for name, d in DENSITIES.items():
    px = round(108 * d)
    adaptive_square.resize((px, px), Image.LANCZOS).save(
        RES / f"mipmap-{name}" / "ic_launcher_background.png", optimize=True
    )

# In-app brand mark, store and iOS icons.
master.resize((128, 128), Image.LANCZOS).save("assets/images/logo_mark.png", optimize=True)
STORE.parent.mkdir(parents=True, exist_ok=True)
square.resize((512, 512), Image.LANCZOS).save(STORE, optimize=True)

ios = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
for f in ios.glob("Icon-App-*.png"):
    w = Image.open(f).size[0]
    square.resize((w, w), Image.LANCZOS).save(f, optimize=True)
print("icons updated")
