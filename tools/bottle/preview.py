"""Headless preview of the bottle GLB: silhouette first, art later.

Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python preview.py
"""

import math
import os

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
GLB = os.path.join(HERE, "artifact.glb")
OUT_DIR = "/tmp/bottle_preview"

FRONT = "front"
THREE_QUARTER = "three_quarter"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
scene = bpy.context.scene

# Report what actually came in: the profile is authored in millimetres, so the
# bounding box is the proof the model matches the game's 55 x 150 box.
mins = mathutils.Vector((1e9, 1e9, 1e9))
maxs = mathutils.Vector((-1e9, -1e9, -1e9))
vertices = 0
for obj in scene.objects:
    if obj.type != "MESH":
        continue
    vertices += len(obj.data.vertices)
    for corner in obj.bound_box:
        world = obj.matrix_world @ mathutils.Vector(corner)
        mins = mathutils.Vector(map(min, mins, world))
        maxs = mathutils.Vector(map(max, maxs, world))

print(
    "IMPORTED bounds mm: "
    f"x {mins.x * 1000:.2f}..{maxs.x * 1000:.2f}  "
    f"y {mins.y * 1000:.2f}..{maxs.y * 1000:.2f}  "
    f"z {mins.z * 1000:.2f}..{maxs.z * 1000:.2f}  "
    f"verts {vertices}",
    flush=True,
)

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.resolution_x = 220
scene.render.resolution_y = 600
scene.render.resolution_percentage = 100

target = bpy.data.objects.new("target", None)
scene.collection.objects.link(target)
target.location = (0, 0, (mins.z + maxs.z) / 2)

MARGIN = 1.2
ORTHO_SCALE = (maxs.z - mins.z) * MARGIN


def add_camera(name, azimuth_deg, elevation_deg):
    """An orthographic camera aimed at the bottle's middle.

    `ortho_scale` covers the render's larger dimension, which is the height
    here, so a 220x600 frame shows a 55x150 * MARGIN window.
    """
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = ORTHO_SCALE
    camera = bpy.data.objects.new(name, data)
    scene.collection.objects.link(camera)

    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    distance = 1.0
    camera.location = (
        distance * math.cos(elevation) * math.sin(azimuth),
        -distance * math.cos(elevation) * math.cos(azimuth),
        distance * math.sin(elevation),
    )
    track = camera.constraints.new("TRACK_TO")
    track.target = target
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    return camera


os.makedirs(OUT_DIR, exist_ok=True)
views = {FRONT: (0.0, 0.0), THREE_QUARTER: (32.0, 16.0)}
for view, (azimuth, elevation) in views.items():
    scene.camera = add_camera(f"cam_{view}", azimuth, elevation)
    scene.render.filepath = os.path.join(OUT_DIR, f"{view}.png")
    bpy.ops.render.render(write_still=True)
    print(f"rendered {scene.render.filepath}", flush=True)
