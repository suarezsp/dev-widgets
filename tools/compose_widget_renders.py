#!/usr/bin/env python3
"""Puts each transparent widget render on a plain rounded platter,
on a transparent canvas: only the widget shows, no wallpaper or
desktop. The platter is neutral (dark for the clear and dark
presentations, light for the light one) with a thin rim; macOS
draws the real Liquid Glass, which these images do not imitate.

Usage: compose_widget_renders.py RENDERS OUTPUT
"""
import pathlib
import sys

from PIL import Image, ImageChops, ImageDraw

SCALE = 2
CORNER_RADIUS = 22 * SCALE
RIM_WIDTH = 2
PLATTERS = {
    "clear": (28, 28, 33),
    "dark": (34, 34, 40),
    "light": (244, 244, 247),
}
RIMS = {
    "clear": (255, 255, 255, 46),
    "dark": (255, 255, 255, 46),
    "light": (0, 0, 0, 26),
}


def make_mask(size, inset=0):
    mask = Image.new("L", size, 0)
    box = (inset, inset, size[0] - 1 - inset,
           size[1] - 1 - inset)
    ImageDraw.Draw(mask).rounded_rectangle(
        box, CORNER_RADIUS, fill=255)
    return mask


def make_widget(render, mode):
    """The render on its platter, transparent outside the corners."""
    widget = Image.new("RGBA", render.size, (0, 0, 0, 0))
    platter = Image.new("RGBA", render.size, PLATTERS[mode])
    widget.paste(platter, (0, 0), make_mask(render.size))
    widget.alpha_composite(render)
    *rim_color, rim_alpha = RIMS[mode]
    ring = ImageChops.subtract(
        make_mask(render.size), make_mask(render.size, RIM_WIDTH))
    ring = ring.point(lambda value: value * rim_alpha // 255)
    rim = Image.new("RGBA", render.size, tuple(rim_color))
    rim.putalpha(ring)
    widget.alpha_composite(rim)
    return widget


def main():
    renders, output = map(pathlib.Path, sys.argv[1:3])
    output.mkdir(parents=True, exist_ok=True)
    for path in sorted(renders.glob("real-*.png")):
        mode = path.stem.rsplit("-", 1)[1]
        render = Image.open(path).convert("RGBA")
        make_widget(render, mode).save(output / path.name)


if __name__ == "__main__":
    main()
