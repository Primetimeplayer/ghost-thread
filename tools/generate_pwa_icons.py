"""Generates the GhostThread PWA icons, favicon and splash mark.

Motif: a quiet ghost with a dashed, unfinished thread running through it,
drawn in the app's Material 3 seed colours. Run with:

    python3 tools/generate_pwa_icons.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

SEED_TOP = (124, 99, 190)
SEED_BOTTOM = (86, 63, 142)
INK = (243, 237, 247)
GLYPH_DARK = (72, 51, 120)
SUPERSAMPLE = 1024
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "web")


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _background() -> Image.Image:
    image = Image.new("RGB", (SUPERSAMPLE, SUPERSAMPLE))
    draw = ImageDraw.Draw(image)
    for y in range(SUPERSAMPLE):
        draw.line([(0, y), (SUPERSAMPLE, y)], fill=_mix(SEED_TOP, SEED_BOTTOM, y / SUPERSAMPLE))
    return image


def _dotted_curve(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    radius: float,
    spacing: float,
) -> None:
    """Places soft dots along a polyline: a thread still being written."""
    travelled = 0.0
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        steps = max(1, int(seg / max(1.0, spacing / 2)))
        for step in range(steps + 1):
            t = step / steps
            travelled += seg / steps
            if travelled < spacing:
                continue
            travelled = 0.0
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=fill)


def _ghost(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float, h: float) -> None:
    left, right = cx - w / 2, cx + w / 2
    top, bottom = cy - h / 2, cy + h / 2
    draw.pieslice([left, top, right, top + w], 180, 360, fill=INK)
    draw.rectangle([left, top + w / 2, right, bottom - h * 0.10], fill=INK)
    bumps = 4
    bump_w = w / bumps
    for index in range(bumps):
        x0 = left + index * bump_w
        draw.pieslice(
            [x0, bottom - h * 0.20, x0 + bump_w, bottom + h * 0.04], 0, 180, fill=INK
        )
    eye_r = w * 0.075
    eye_y = cy - h * 0.06
    for eye_x in (cx - w * 0.17, cx + w * 0.17):
        draw.ellipse(
            [eye_x - eye_r, eye_y - eye_r * 1.3, eye_x + eye_r, eye_y + eye_r * 1.3],
            fill=GLYPH_DARK,
        )


def _compose(maskable: bool) -> Image.Image:
    base = _background().convert("RGBA")
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # A loose, unfinished dotted thread drifting behind the ghost.
    y_center = SUPERSAMPLE * 0.635
    points = [
        (SUPERSAMPLE * x, y_center + SUPERSAMPLE * dy)
        for x, dy in [
            (-0.04, 0.075),
            (0.12, 0.005),
            (0.28, 0.075),
            (0.44, 0.015),
            (0.60, 0.085),
            (0.74, 0.02),
        ]
    ]
    _dotted_curve(
        draw,
        points,
        (243, 237, 247, 120),
        SUPERSAMPLE * (0.012 if maskable else 0.013),
        SUPERSAMPLE * 0.052,
    )

    # The thread simply stops: one open ring where the thought trails off.
    ring_x, ring_y = SUPERSAMPLE * 0.845, y_center + SUPERSAMPLE * 0.02
    ring_r = SUPERSAMPLE * 0.040
    draw.ellipse(
        [ring_x - ring_r, ring_y - ring_r, ring_x + ring_r, ring_y + ring_r],
        outline=(243, 237, 247, 150),
        width=int(SUPERSAMPLE * 0.012),
    )

    scale = 0.42 if maskable else 0.50
    ghost_w = SUPERSAMPLE * scale
    _ghost(draw, SUPERSAMPLE * 0.50, SUPERSAMPLE * 0.535, ghost_w, ghost_w * 1.22)

    image = Image.alpha_composite(base, layer)
    return image


def _rounded(image: Image.Image, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.size[0], image.size[1]], radius=image.size[0] * radius_ratio, fill=255
    )
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.paste(image, (0, 0), mask)
    return out


def main() -> None:
    regular = _rounded(_compose(maskable=False), 0.235)
    maskable = _compose(maskable=True)

    icons = os.path.join(OUT_DIR, "icons")
    os.makedirs(icons, exist_ok=True)

    regular.resize((192, 192), Image.LANCZOS).save(os.path.join(icons, "Icon-192.png"))
    regular.resize((512, 512), Image.LANCZOS).save(os.path.join(icons, "Icon-512.png"))
    maskable.resize((192, 192), Image.LANCZOS).save(
        os.path.join(icons, "Icon-maskable-192.png")
    )
    maskable.resize((512, 512), Image.LANCZOS).save(
        os.path.join(icons, "Icon-maskable-512.png")
    )
    regular.resize((180, 180), Image.LANCZOS).save(
        os.path.join(icons, "Icon-180.png")
    )
    regular.resize((32, 32), Image.LANCZOS).save(os.path.join(OUT_DIR, "favicon.png"))
    regular.resize((512, 512), Image.LANCZOS).save(
        os.path.join(icons, "splash-icon.png")
    )
    print("Wrote icons to", os.path.abspath(icons))


if __name__ == "__main__":
    main()
