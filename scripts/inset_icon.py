#!/usr/bin/env python3
"""Center an RGBA icon within the 1024 px macOS Dock safe area."""

import sys

from PIL import Image


if len(sys.argv) != 3:
    raise SystemExit("Usage: inset_icon.py INPUT.png OUTPUT.png")

source = Image.open(sys.argv[1]).convert("RGBA")
canvas_size = 1024
inset = 81
content_size = canvas_size - inset * 2
source = source.resize((content_size, content_size), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
canvas.alpha_composite(source, (inset, inset))
canvas.save(sys.argv[2])
