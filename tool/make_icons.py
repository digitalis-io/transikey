#!/usr/bin/env python3
"""Generate app icons and the in-app mark from assets/branding/TransiKey_Logo.jpeg.

Requires: pip install pillow numpy
Usage:    python3 tool/make_icons.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/branding/TransiKey_Logo.jpeg"
EMBLEM_BOX = (470, 150, 935, 455)  # shield + pulse, without the wordmark
BACKGROUND = (36, 39, 43)


def emblem() -> Image.Image:
    """Cut the emblem out of the artwork with a soft alpha matte."""
    crop = Image.open(SOURCE).convert("RGB").crop(EMBLEM_BOX)
    rgb = np.asarray(crop).astype(np.float32)
    corner = rgb[:12, :12].reshape(-1, 3).mean(axis=0)
    distance = np.sqrt(((rgb - corner) ** 2).sum(axis=2))
    alpha = np.clip((distance - 18) / 40, 0, 1)
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def icon(size: int = 1024) -> Image.Image:
    """macOS style: rounded dark tile with margin, emblem centred."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    margin = round(size * 0.098)
    tile = size - 2 * margin
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (margin, margin, size - margin, size - margin),
        radius=round(tile * 0.225),
        fill=255,
    )
    canvas.paste(Image.new("RGBA", (size, size), BACKGROUND + (255,)), mask=mask)
    mark = emblem()
    width = round(tile * 0.94)
    mark = mark.resize(
        (width, round(mark.height * width / mark.width)), Image.LANCZOS
    )
    canvas.alpha_composite(
        mark, ((size - mark.width) // 2, (size - mark.height) // 2)
    )
    return canvas


def main() -> None:
    master = icon()
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        master.resize((px, px), Image.LANCZOS).save(mac / f"app_icon_{px}.png")

    master.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)],
    )

    out = ROOT / "assets/branding"
    master.resize((512, 512), Image.LANCZOS).save(out / "app_icon.png")
    mark = emblem()
    mark.resize((mark.width * 2, mark.height * 2), Image.LANCZOS).save(
        out / "transikey_mark.png"
    )
    print("icons written")


if __name__ == "__main__":
    main()
