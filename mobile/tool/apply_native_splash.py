"""Native (pre-Flutter) splash assets that mirror UI/splash screen.

Run from mobile/ with Pillow installed:
  python tool/apply_native_splash.py

Writes, per density:
  drawable-<d>/launch_logo.png   icon + glass frame + title + tagline (pre-Android 12 / window background)
  drawable-<d>/splash_icon.png   framed icon on a 288dp canvas (Android 12+ system splash)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RES = Path("android/app/src/main/res")
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
MASTER = Image.open("tool/app_icon_master.png").convert("RGBA")
BOLD = "assets/fonts/Inter-Bold.ttf"
REGULAR = "assets/fonts/Inter-Regular.ttf"
SS = 4  # supersample on top of the density scale


def framed_icon(unit, shadow_on=True):
    """112dp icon inside a 6dp glass frame (radius 34) with the mockup shadow. Returns (img, pad)."""
    icon, ring = 112 * unit, 6 * unit
    frame = icon + 2 * ring
    pad = 60 * unit  # room for the blurred drop shadow
    canvas = Image.new("RGBA", (frame + 2 * pad,) * 2, (0, 0, 0, 0))
    mask = Image.new("L", (frame, frame), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, frame - 1, frame - 1], radius=34 * unit, fill=255)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((0, 0x12, 0x56, 115), (pad, pad + 20 * unit), mask)
    if shadow_on:
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(25 * unit)))
    # Glass frame: white 35% -> 10% -> 0 top to bottom.
    glass = Image.new("RGBA", (frame, frame))
    gp = glass.load()
    for y in range(frame):
        t = y / (frame - 1)
        a = 0.35 + (0.10 - 0.35) * t / 0.5 if t < 0.5 else 0.10 * (1 - (t - 0.5) / 0.5)
        for x in range(frame):
            gp[x, y] = (255, 255, 255, round(a * 255))
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(glass, (pad, pad), mask)
    canvas.alpha_composite(layer)
    # Icon surface (primary blue + artwork), rounded 28.
    surface = Image.new("RGBA", (icon, icon), (0x22, 0x48, 0xD1, 255))
    surface.alpha_composite(MASTER.resize((icon, icon), Image.LANCZOS))
    imask = Image.new("L", (icon, icon), 0)
    ImageDraw.Draw(imask).rounded_rectangle([0, 0, icon - 1, icon - 1], radius=28 * unit, fill=255)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(surface, (pad + ring, pad + ring), imask)
    canvas.alpha_composite(layer)
    return canvas, pad


def center_paste(canvas, img, top):
    canvas.alpha_composite(img, ((canvas.width - img.width) // 2, top))


def text_img(text, font_path, px, fill, spacing=0.0):
    font = ImageFont.truetype(font_path, px)
    w = round(font.getlength(text) + abs(spacing) * len(text)) + 8
    img = Image.new("RGBA", (w, round(px * 1.5)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 4.0
    for ch in text:
        d.text((x, 0), ch, font=font, fill=fill)
        x += font.getlength(ch) + spacing
    return img.crop(img.getbbox())


for name, d in DENSITIES.items():
    unit = round(d * SS)
    out = RES / f"drawable-{name}"
    out.mkdir(exist_ok=True)

    # Android 12+ icon: 288dp canvas, circle-masked to 192dp, so keep the frame inside ~150dp.
    frame, pad = framed_icon(unit, shadow_on=False)
    inner = 112 + 12
    crop = frame.crop((pad, pad, pad + inner * unit, pad + inner * unit))
    icon_canvas = Image.new("RGBA", (288 * unit,) * 2, (0, 0, 0, 0))
    scale = 0.78  # fit the framed icon inside the circular mask
    small = crop.resize((round(inner * unit * scale),) * 2, Image.LANCZOS)
    icon_canvas.alpha_composite(
        small, ((icon_canvas.width - small.width) // 2, (icon_canvas.height - small.height) // 2)
    )
    icon_canvas.resize((round(288 * d),) * 2, Image.LANCZOS).save(out / "splash_icon.png", optimize=True)

    # Window-background logo: framed icon + title + tagline, laid out like the Flutter splash.
    width, height = 300 * unit, 250 * unit
    logo = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    shadowed, pad = framed_icon(unit)
    center_paste(logo, shadowed, 0 - pad + 10 * unit)
    title = text_img("HomeCircle", BOLD, 32 * unit, (255, 255, 255, 255), -0.64 * unit)
    center_paste(logo, title, (10 + 124 + 32) * unit)
    tag = text_img("One home. Every detail connected.", REGULAR, 14 * unit, (0xDD, 0xE1, 0xFF, 242))
    center_paste(logo, tag, (10 + 124 + 32 + 40 + 6) * unit)
    logo.resize((round(300 * d), round(250 * d)), Image.LANCZOS).save(out / "launch_logo.png", optimize=True)

print("native splash assets updated")
