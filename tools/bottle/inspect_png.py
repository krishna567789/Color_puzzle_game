"""Proof sheet for the generated skins: alpha stats + a dark-background composite.

A transparent PNG looks fine on white whatever its alpha is, so the review copy
is flattened over a checkerboard and the numbers are printed next to it.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/bottle/inspect_png.py
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import render_skins as rs

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
SKIN_DIR = os.path.join(PROJECT, "assets", "skins")
OUT = "/tmp/skins_review"

NAMES = [
    name
    for skin_id in rs.SKINS
    for name in (skin_id, f"hero_{skin_id}")
]


def load(name):
    path = os.path.join(SKIN_DIR, f"{name}.png")
    image = bpy.data.images.load(path)
    image.colorspace_settings.name = "sRGB"
    return path, image


def stats(name, image):
    w, h = image.size
    px = list(image.pixels)
    rows = [int(h * f) for f in (0.02, 0.12, 0.30, 0.50, 0.75, 0.98)]
    cols = [int(w * f) for f in (0.02, 0.20, 0.50, 0.80, 0.98)]
    print(f"\n{name} {w}x{h}")
    for y in rows:
        line = []
        for x in cols:
            i = (y * w + x) * 4
            line.append(f"a={px[i + 3]:.2f} rgb=({px[i]:.2f},{px[i + 1]:.2f},{px[i + 2]:.2f})")
        print(f"  y={y:4d}  " + "  ".join(line))
    opaque = sum(1 for i in range(3, len(px), 4) if px[i] > 0.5)
    partial = sum(1 for i in range(3, len(px), 4) if 0.02 < px[i] <= 0.5)
    print(f"  pixels >0.5 alpha: {opaque}  ({100 * opaque / (w * h):.1f}%)")
    print(f"  pixels 0.02..0.5 alpha: {partial}  ({100 * partial / (w * h):.1f}%)")


def flatten(name, image):
    """Composite over a checker so transparency is visible in the review copy."""
    w, h = image.size
    out = bpy.data.images.new(f"review.{name}", w, h, alpha=True)
    src = list(image.pixels)
    dst = list(out.pixels)
    step = max(16, w // 14)
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            checker = 0.30 if ((x // step) + (y // step)) % 2 == 0 else 0.16
            a = src[i + 3]
            for c in range(3):
                dst[i + c] = src[i + c] * a + checker * (1.0 - a)
            dst[i + 3] = 1.0
    out.pixels = dst
    out.filepath_raw = os.path.join(OUT, f"{name}_on_dark.png")
    out.file_format = "PNG"
    out.save()


os.makedirs(OUT, exist_ok=True)
for name in NAMES:
    _, image = load(name)
    stats(name, image)
    flatten(name, image)
    bpy.data.images.remove(image)

print("\nreview copies in", OUT)
