#!/usr/bin/env python3
"""The arrangement the user has on the desktop next to Apple's
widgets (one medium over two small), with DevWidgets only, on a
transparent canvas.

Usage: compose_comparison.py RENDERS OUTPUT
"""
import pathlib
import sys

from PIL import Image

from compose_widget_renders import make_widget

GAP = 24 * 2
SIDE = 728
LAYOUT = [
    ("real-medium-memory-clear.png", 0, 0),
    ("real-small-cpu-clear.png", 0, 340 + GAP),
    ("real-small-network-clear.png", 340 + GAP, 340 + GAP),
]


def main():
    renders, output = map(pathlib.Path, sys.argv[1:3])
    canvas = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    for name, x, y in LAYOUT:
        render = Image.open(renders / name).convert("RGBA")
        canvas.alpha_composite(make_widget(render, "clear"), (x, y))
    canvas.save(output)


if __name__ == "__main__":
    main()
