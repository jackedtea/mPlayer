# This file is part of mPlayer.
# Copyright (C) 2026 Nam <namicedtea@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# See the LICENSE file at the app root for the full notice.
"""Draws the Android TV launcher banner (android:banner).

The icon's gradient run full-bleed, its play glyph and cast waves on the left
and the name beside them. The launcher rounds the corners and scales the
image itself, so the PNG is a plain rectangle.

    python tool/make_tv_banner.py

Needs Pillow. Writes drawable-xhdpi (320x180, the size Android TV asks for)
and drawable-xxhdpi (480x270) from the same drawing.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
FONT = ROOT / "assets/fonts/Roboto-Variable.ttf"

# From icon.svg.
LIGHT = (0x5B, 0x9E, 0xE8)
DARK = (0x1D, 0x6F, 0xC2)
WAVE = (0xEA, 0xF4, 0xFF)

# Drawn this many times larger, then reduced, for smooth edges.
SUPER = 8


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def draw(width, height):
    w, h = width * SUPER, height * SUPER
    unit = w / 320  # Everything below is laid out on the 320x180 grid.

    # Diagonal gradient, top-left light to bottom-right dark, as on the icon.
    ground = Image.new("RGB", (w, h))
    px = ground.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = lerp(LIGHT, DARK, (x / w + y / h) / 2)

    glyph = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g = ImageDraw.Draw(glyph)

    font = ImageFont.truetype(str(FONT), round(42 * unit))
    font.set_variation_by_axes([600])
    text = "mPlayer"
    left, top, right, bottom = font.getbbox(text)

    # The icon's glyph spans x 200..476, y 82..394 of its 512 grid. It is
    # drawn 84 tall, the name 14 to its right, and the pair centred.
    s = 84 / 312 * unit
    gap = 14 * unit
    group = 276 * s + gap + (right - left)
    ox = (w - group) / 2 - 200 * s
    oy = (h - 312 * s) / 2 - 82 * s

    def p(x, y):
        return (ox + x * s, oy + y * s)

    def arc(start, end, r, alpha):
        # The centre of the clockwise minor arc of radius r from start to end,
        # as the SVG's "A r r 0 0 1" draws it.
        (x1, y1), (x2, y2) = start, end
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        dx, dy = x2 - x1, y2 - y1
        chord = math.hypot(dx, dy)
        off = math.sqrt(max(r * r - (chord / 2) ** 2, 0))
        cx, cy = mx - dy / chord * off, my + dx / chord * off
        a0 = math.degrees(math.atan2(y1 - cy, x1 - cx))
        a1 = math.degrees(math.atan2(y2 - cy, x2 - cx))
        if a1 < a0:
            a1 += 360

        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        stroke = round(15 * s)
        # Pillow grows a wide arc inward from its box; the SVG strokes either
        # side of the path.
        grow = stroke / 2
        (bx0, by0), (bx1, by1) = p(cx - r, cy - r), p(cx + r, cy + r)
        box = [bx0 - grow, by0 - grow, bx1 + grow, by1 + grow]
        ImageDraw.Draw(layer).arc(
            box, a0, a1, fill=WAVE + (255,), width=stroke
        )
        # Round caps, as stroke-linecap="round".
        for ex, ey in (start, end):
            ex, ey = p(ex, ey)
            half = stroke / 2
            ImageDraw.Draw(layer).ellipse(
                [ex - half, ey - half, ex + half, ey + half], fill=WAVE + (255,)
            )
        a = layer.getchannel("A").point(lambda v: round(v * alpha))
        layer.putalpha(a)
        glyph.alpha_composite(layer)

    arc((353, 118), (440, 205), 87, 0.85)
    arc((317, 82), (476, 241), 138, 0.5)
    cx, cy = p(440, 205)
    r = 13 * s
    g.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WAVE + (255,))
    g.polygon([p(200, 159), p(374, 277), p(200, 394)], fill=(255, 255, 255, 255))

    # The name, to the right of the glyph.
    tx = ox + 476 * s + gap - left
    ty = (h - (bottom - top)) / 2 - top
    g.text((tx, ty), text, font=font, fill=(255, 255, 255, 255))

    ground = ground.convert("RGBA")
    ground.alpha_composite(glyph)
    return ground.convert("RGB").resize((width, height), Image.LANCZOS)


def main():
    for folder, (width, height) in {
        "drawable-xhdpi": (320, 180),
        "drawable-xxhdpi": (480, 270),
    }.items():
        out = RES / folder / "tv_banner.png"
        draw(width, height).save(out, optimize=True)
        print(out)


if __name__ == "__main__":
    main()
