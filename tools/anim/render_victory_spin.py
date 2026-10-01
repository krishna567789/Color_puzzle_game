"""Render the victory-spin flipbook: a filled hero bottle that sways and bobs.

Why frames instead of a live GLB: interactive_3d/Filament costs +8.5 MB per ABI,
has no camera-rotation or animator-control API (a bottle cannot be leaned for a
pour), and its texture freezes ~1.5 s after the last touch. A short pre-rendered
sequence costs a few hundred KB, is exactly reproducible, and plays anywhere.

The motion is sampled analytically and written as keyframes on one Empty, so the
same move can be re-authored by hand in the Blender timeline. It sways +/-25 deg
in a single loop period, which is seamless: frame 1 joins back onto frame 16.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/anim/render_victory_spin.py
"""

import math
import os
import sys

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
PROJECT = os.path.dirname(TOOLS)
sys.path.insert(0, os.path.join(TOOLS, "bottle"))

import render_skins as rs  # noqa: E402  (reuses the shipped skin look)

OUT_DIR = os.path.join(PROJECT, "assets", "anim", "victory_spin")

FRAMES = 16
FRAME_W, FRAME_H = 176, 400
# The card shows the bottle about 130 logical px tall, so 400 px covers a
# 3x-density screen without wasting bytes on a fourth.
# An ortho camera's scale follows the sensor's longer side, which for this
# portrait frame is its height: 205 mm covers the 150 mm bottle plus the cork
# and leaves room for the sway.
ORTHO_SCALE = 0.205

# At 130 logical px tall a turntable alone reads as static, because the bottle
# is a body of revolution: only its highlight moves. The bob and the lean are
# what change the silhouette, so they carry the motion.
SWAY_DEG = 25.0
BOB_MM = 9.0
TILT_DEG = 11.0


def turntable(scene):
    """Parent every mesh to one Empty at the world origin.

    The bottle and its liquid are already authored in world coordinates around
    the Z axis, so a plain parent link is all that is needed. Preserving world
    matrices here would shift everything by the pivot height, because the
    dependency graph has not evaluated the new parent yet.
    """
    empty = bpy.data.objects.new("turntable", None)
    scene.collection.objects.link(empty)
    for obj in [o for o in scene.objects if o.type == "MESH"]:
        obj.parent = empty
    return empty


def keyframe(empty, frame, rot_z_deg, loc_z_m, rot_x_deg):
    empty.rotation_euler = (math.radians(rot_x_deg), 0.0, math.radians(rot_z_deg))
    empty.location.z = loc_z_m
    empty.keyframe_insert("rotation_euler", frame=frame)
    empty.keyframe_insert("location", frame=frame)


def set_view_transform(scene, name):
    items = {
        i.identifier
        for i in scene.view_settings.rna_type.properties["view_transform"].enum_items
    }
    if name in items:
        scene.view_settings.view_transform = name


def build_scene():
    scene = rs.new_scene()
    set_view_transform(scene, "Standard")
    scene.render.resolution_x = FRAME_W
    scene.render.resolution_y = FRAME_H
    scene.render.use_border = False
    meshes, top = rs.import_bottle(scene)

    material = rs.build_skin_material("spin.glass", rs.SKINS["default_tube"])
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(material)

    band = 22.0
    for index in range(4):
        rs.liquid_column(scene, index, 16.0 + band * index, band, 25.0)

    rs.ambient(scene, (0.62, 0.68, 0.78, 1.0), 1.0)
    sun = bpy.data.lights.new("spin.sun", type="SUN")
    sun.energy = 3.0
    sun.angle = math.radians(12.0)
    sun_obj = bpy.data.objects.new("spin.sun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(35), math.radians(-12), math.radians(20))

    rs.ortho_camera(scene, "spin.cam", 24.0, 12.0, ORTHO_SCALE, top / 2.0 + 0.008)
    return scene, top


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    scene, top = build_scene()
    empty = turntable(scene)
    for index in range(FRAMES):
        phase = 2.0 * math.pi * index / FRAMES
        keyframe(
            empty,
            index + 1,
            SWAY_DEG * math.sin(phase),
            BOB_MM / 1000.0 * math.sin(2.0 * phase),
            TILT_DEG * math.sin(phase + math.pi / 2.0),
        )

    scene.frame_start = 1
    scene.frame_end = FRAMES
    for index in range(FRAMES):
        frame = index + 1
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(OUT_DIR, "frame_%02d.png" % frame)
        bpy.ops.render.render(write_still=True)
        print("frame", frame, mathutils.Vector(empty.rotation_euler).z, flush=True)

    print("wrote", FRAMES, "frames to", OUT_DIR, flush=True)


if __name__ == "__main__":
    main()
