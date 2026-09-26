"""Fine pixel scans of a rendered sprite, to tell a gradient from a bug.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/bottle/scan_png.py -- assets/skins/default_tube.png
"""

import os
import sys

import bpy

argv = sys.argv
path = argv[argv.index("--") + 1] if "--" in argv else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "skins", "default_tube.png"
)
path = os.path.abspath(path)
image = bpy.data.images.load(path)
image.colorspace_settings.name = "sRGB"
w, h = image.size
px = list(image.pixels)


def cell(x, y):
    i = (y * w + x) * 4
    return f"{px[i + 3]:.2f}|{px[i]:.2f}{px[i + 1]:.2f}{px[i + 2]:.2f}"


print(f"{os.path.basename(path)} {w}x{h}   alpha|r g b")
print("\nrow scan (y from bottom):")
for y_frac in (0.20, 0.50, 0.80):
    y = int(h * y_frac)
    print(f"  y={y:4d} " + " ".join(cell(int(w * x / 36), y) for x in range(1, 35, 2)))

print("\ncolumn scans, bottom to top, every 16px:")
for label, x in (("centre", w // 2), ("strip", int(w * (0.5 - 16.0 / 55.0)))):
    print(f"  {label:6s} " + " ".join(cell(x, y) for y in range(0, h, 16)))
