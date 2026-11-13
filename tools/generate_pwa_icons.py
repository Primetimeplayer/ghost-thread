"""Generates the GhostThread PWA icons, favicon and splash mark.

Motif: a quiet ghost with a dashed, unfinished thread running through it,
drawn in the app's Material 3 seed colours. Run with:

    python3 tools/generate_pwa_icons.py
"""

from __future__ import annotations

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


def _dashed_curve(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    width: int,
    dash: int,
    gap: int,
) -> None:
    """Draws dashes along a polyline, like a thread that is still going."""
    on, run = True, 0.0
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        seg = max(abs(x1 - x0), abs(y1 - y0))
        steps = max(1, int(seg))
        for step in range(steps):
            t0, t1 = step / steps, (step + 1) / steps
            ax, ay = x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0
            bx, by = x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1
            run += seg / steps
            if on and run >= dash:
                on, run = False, 0.0
            elif not on and run >= gap:
                on, run = True, 0.0
            if on:
                draw.line([(ax, ay), (bx, by)], fill=fill, width=width)


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

    # A loose, unfinished thread behind the ghost, open on the right.
    width = SUPERSAMPLE * (0.030 if maskable else 0.034)
    y_center = SUPERSAMPLE * 0.60
    points = [
        (SUPERSAMPLE * x, y_center + SUPERSAMPLE * dy)
        for x, dy in [
            (-0.02, 0.10),
            (0.14, -0.02),
            (0.30, 0.10),
            (0.46, 0.02),
            (0.62, 0.12),
            (0.78, 0.02),
            (0.92, 0.10),
            (1.02, 0.03),
        ]
    ]
    _dashed_curve(draw, points, (243, 237, 247, 115), int(width), int(SUPERSAMPLE * 0.055), int(SUPERSAMPLE * 0.038))
    draw.ellipse(
        [
            SUPERSAMPLE * 0.475 - width * 0.9,
            y_center - width * 0.9,
            SUPERSAMPLE * 0.475 + width * 0.9,
            y_center + width * 0.9,
        ],
        fill=(243, 237, 247, 150),
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
