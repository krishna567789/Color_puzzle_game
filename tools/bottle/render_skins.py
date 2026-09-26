"""Render the pre-baked tube skins and the hero bottle from artifact.glb.

The GLB is the geometry; the *look* is authored here, because a game sprite
needs a transparent middle (the liquid is painted in Flutter underneath it) and
that is a shading problem, not a modelling one.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/bottle/render_skins.py
"""

import math
import os

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
GLB = os.path.join(HERE, "artifact.glb")
OUT_DIR = os.path.join(PROJECT, "assets", "skins")

# The bottle is 55 x 150 mm, which is exactly the box BottlePainter draws in
# lib/widgets/tube_widget.dart, so the sprite maps 1 mm -> 1 logical pixel.
MM_W, MM_H = 55.0, 150.0
PX_PER_MM = 4
MARGIN = 1.25

# Grey-alpha ramps over the sprite's own coordinate terms: `edge_stops` runs over
# 1 - |normal.y| (0 facing the camera, 1 at the silhouette) and `band_stops` over
# the normalised height. Every skin must fall to a low value across the middle of
# its range, because the liquid is painted in Flutter underneath this PNG.
EDGE = {
    "glass": [(0.0, 0.0), (0.55, 0.04), (0.78, 0.34), (0.92, 0.90), (1.0, 1.0)],
    "neon": [(0.0, 0.03), (0.28, 0.14), (0.58, 0.50), (0.84, 1.0), (1.0, 1.0)],
    "crystal": [(0.0, 0.0), (0.46, 0.08), (0.70, 0.44), (0.88, 1.0), (1.0, 1.0)],
    "wood": [(0.0, 0.0), (0.42, 0.0), (0.60, 0.92), (1.0, 1.0)],
}

BANDS = {
    "glass": [(0.0, 0.16), (0.06, 0.03), (0.16, 0.0), (1.0, 0.0)],
    "neon": [(0.0, 0.22), (0.08, 0.05), (0.18, 0.0), (1.0, 0.0)],
    "crystal": [(0.0, 0.16), (0.06, 0.03), (0.16, 0.0), (1.0, 0.0)],
    # A wooden foot and collar, but only half-silvered: an opaque one would eat
    # the bottom layer of liquid and the player could not read its colour.
    "wood": [(0.0, 0.5), (0.10, 0.5), (0.14, 0.0), (0.86, 0.0), (0.90, 0.45), (1.0, 0.45)],
}

# Skin id -> look. The ids are the ones the shop already sells. `edge` scales the
# whole alpha budget, `strip` is how much of the specular band shows through.
SKINS = {
    "default_tube": {
        "tint": (0.86, 0.95, 1.0, 1.0),
        "edge": 1.05,
        "strip": 0.55,
        "kind": "glass",
    },
    "neon_tube": {
        "tint": (0.80, 0.30, 1.0, 1.0),
        "edge": 1.15,
        "strip": 0.30,
        "kind": "neon",
    },
    "crystal_bottle": {
        "tint": (0.62, 0.92, 1.0, 1.0),
        "edge": 1.15,
        "strip": 0.80,
        "kind": "crystal",
    },
    "wooden_tube": {
        "tint": (0.62, 0.40, 0.22, 1.0),
        "edge": 1.0,
        "strip": 0.0,
        "kind": "wood",
    },
}

LIQUID = [
    (1.0, 0.13, 0.13, 1.0),
    (1.0, 0.72, 0.16, 1.0),
    (0.11, 0.76, 0.36, 1.0),
    (0.13, 0.42, 1.0, 1.0),
]


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # AgX/Filmic would mute the liquid colours that the game paints with.
    scene.view_settings.view_transform = "Standard"
    return scene


def import_bottle(scene):
    bpy.ops.import_scene.gltf(filepath=GLB)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    top = max(
        (obj.matrix_world @ mathutils.Vector(c)).z
        for obj in meshes
        for c in obj.bound_box
    )
    return meshes, top


def node_tree(material):
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    return tree


def shader_output(tree, surface):
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    tree.links.new(surface, out.inputs["Surface"])
    return out


def view_edge(tree):
    """0 where the surface faces the sprite camera, 1 exactly at the silhouette.

    The sprite camera is orthographic and looks down -Y, so 1 - |N.y| is a
    screen-space edge distance. A physical Fresnel has a floor of ~0.03 and
    washes the whole shoulder; this term is flat-zero across the front face,
    which is what lets the ramp be tight enough to read as an outline.
    """
    geometry = tree.nodes.new("ShaderNodeNewGeometry")
    geometry.location = (-1100, 0)
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    separate.location = (-920, 0)
    tree.links.new(geometry.outputs["Normal"], separate.inputs["Vector"])
    flat = new_math(tree, (-740, 0), "ABSOLUTE")
    tree.links.new(separate.outputs["Y"], flat.inputs[0])
    edge = new_math(tree, (-560, 0), "SUBTRACT")
    edge.inputs[0].default_value = 1.0
    tree.links.new(flat.outputs["Value"], edge.inputs[1])
    return edge.outputs["Value"]


def ramp(tree, source, stops, location):
    """A grey-alpha ramp with exactly the stops asked for.

    Blender seeds a ColorRamp with two elements, and the one at position 1.0 is
    white: leaving stray seeds in place makes the ramp fade to fully opaque at
    its top stop, which washes the whole bottle interior.
    """
    ramp_node = tree.nodes.new("ShaderNodeValToRGB")
    ramp_node.location = location
    ramp_node.color_ramp.interpolation = "LINEAR"
    elements = ramp_node.color_ramp.elements
    while len(elements) > 2:
        elements.remove(elements[-1])
    for index, stop in enumerate((stops[0], stops[-1])):
        position, value = stop
        element = elements[index]
        element.position = position
        element.color = (value, value, value, 1)
    for position, value in stops[1:-1]:
        element = elements.new(position)
        element.color = (value, value, value, 1)
    tree.links.new(source, ramp_node.inputs["Fac"])
    return ramp_node.outputs["Color"]


def edge_ramp(tree, source, kind):
    return ramp(tree, source, EDGE[kind], (-400, 0))


def highlight_strip(tree):
    """Two vertical specular bands on the flat front face, like the old painter's
    gradient, but only where the glass actually faces the camera."""
    geometry = tree.nodes.new("ShaderNodeNewGeometry")
    geometry.location = (-1100, -620)
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    separate.location = (-920, -620)
    tree.links.new(geometry.outputs["Position"], separate.inputs["Vector"])
    to_unit = tree.nodes.new("ShaderNodeMapRange")
    to_unit.location = (-740, -620)
    to_unit.inputs["From Min"].default_value = -MM_W / 2000.0
    to_unit.inputs["From Max"].default_value = MM_W / 2000.0
    tree.links.new(separate.outputs["X"], to_unit.inputs["Value"])
    stops = [
        (0.0, 0.0),
        (0.14, 0.0),
        (0.19, 0.42),
        (0.27, 0.0),
        (0.72, 0.0),
        (0.76, 0.20),
        (0.82, 0.0),
        (1.0, 0.0),
    ]
    strip = ramp(tree, to_unit.outputs["Result"], stops, (-560, -620))
    flat = new_math(tree, (-740, -420), "ABSOLUTE")
    tree.links.new(separate.outputs["Y"], flat.inputs[0])
    face_on = new_math(tree, (-560, -420), "SUBTRACT")
    face_on.inputs[0].default_value = 1.0
    tree.links.new(flat.outputs["Value"], face_on.inputs[1])
    gated = new_math(tree, (-380, -520), "MULTIPLY_ADD")
    tree.links.new(strip, gated.inputs[0])
    tree.links.new(face_on.outputs["Value"], gated.inputs[1])
    gated.inputs[2].default_value = 0.0
    return gated.outputs["Value"]


def vertical_bands(tree, kind):
    """Foot, collar and body bands over the bottle's normalised height.

    World position, not object coords: the rim is a second object whose local Z
    is centred on itself, so an object-space ramp would make it invisible.
    """
    geometry = tree.nodes.new("ShaderNodeNewGeometry")
    geometry.location = (-1100, -320)
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    separate.location = (-920, -320)
    tree.links.new(geometry.outputs["Position"], separate.inputs["Vector"])
    map_range = tree.nodes.new("ShaderNodeMapRange")
    map_range.location = (-740, -320)
    map_range.inputs["From Min"].default_value = 0.0
    map_range.inputs["From Max"].default_value = MM_H / 1000.0
    tree.links.new(separate.outputs["Z"], map_range.inputs["Value"])
    return ramp(tree, map_range.outputs["Result"], BANDS[kind], (-560, -320))


def new_math(tree, location, operation):
    node = tree.nodes.new("ShaderNodeMath")
    node.location = location
    node.operation = operation
    return node


def set_principled(material, name, value):
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    socket = bsdf.inputs.get(name)
    if socket is not None:
        socket.default_value = value


def build_skin_material(name, spec):
    material = bpy.data.materials.new(name)
    tree = node_tree(material)
    material.blend_method = "BLEND"
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "BLENDED"
    material.show_transparent_back = False
    material.use_backface_culling = False

    core = new_math(tree, (-260, 0), "MAXIMUM")
    tree.links.new(edge_ramp(tree, view_edge(tree), spec["kind"]), core.inputs[0])
    tree.links.new(vertical_bands(tree, spec["kind"]), core.inputs[1])

    lit = new_math(tree, (-120, 60), "MULTIPLY_ADD")
    tree.links.new(highlight_strip(tree), lit.inputs[0])
    lit.inputs[1].default_value = spec["strip"]
    tree.links.new(core.outputs["Value"], lit.inputs[2])

    scaled = new_math(tree, (40, 60), "MULTIPLY")
    scaled.inputs[1].default_value = spec["edge"]
    tree.links.new(lit.outputs["Value"], scaled.inputs[0])

    alpha = tree.nodes.new("ShaderNodeClamp")
    alpha.location = (200, 60)
    tree.links.new(scaled.outputs["Value"], alpha.inputs["Value"])

    emission = tree.nodes.new("ShaderNodeEmission")
    emission.location = (100, -80)
    emission.inputs["Color"].default_value = spec["tint"]
    emission.inputs["Strength"].default_value = 1.0

    mix = tree.nodes.new("ShaderNodeMixShader")
    mix.location = (330, 0)
    transparent = tree.nodes.new("ShaderNodeBsdfTransparent")
    transparent.location = (120, 220)
    tree.links.new(alpha.outputs["Result"], mix.inputs["Fac"])
    tree.links.new(transparent.outputs["BSDF"], mix.inputs[1])
    tree.links.new(emission.outputs["Emission"], mix.inputs[2])
    shader_output(tree, mix.outputs["Shader"])
    return material


def ortho_camera(scene, name, azimuth_deg, elevation_deg, scale_m, target_z):
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = scale_m
    camera = bpy.data.objects.new(name, data)
    scene.collection.objects.link(camera)
    aim = bpy.data.objects.new(name + "_aim", None)
    scene.collection.objects.link(aim)
    aim.location = (0, 0, target_z)
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    distance = 1.0
    camera.location = (
        distance * math.cos(elevation) * math.sin(azimuth),
        -distance * math.cos(elevation) * math.cos(azimuth),
        distance * math.sin(elevation),
    )
    track = camera.constraints.new("TRACK_TO")
    track.target = aim
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    scene.camera = camera
    return camera


def crop_to_bottle(scene):
    """Render wide, then crop the exact 55 x 150 mm window out of the middle."""
    scene.render.use_border = True
    scene.render.use_crop_to_border = True
    inset = (1.0 - 1.0 / MARGIN) / 2.0
    scene.render.border_min_x = inset
    scene.render.border_max_x = 1.0 - inset
    scene.render.border_min_y = inset
    scene.render.border_max_y = 1.0 - inset


def liquid_column(scene, index, bottom_mm, height_mm, radius_mm):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius_mm / 1000.0,
        depth=height_mm / 1000.0,
        location=(0, 0, (bottom_mm + height_mm / 2.0) / 1000.0),
        vertices=64,
    )
    obj = bpy.context.view_layer.objects.active
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    colour = LIQUID[index % len(LIQUID)]
    material = bpy.data.materials.new(f"liquid.{index}")
    material.use_nodes = True
    set_principled(material, "Base Color", colour)
    set_principled(material, "Roughness", 0.45)
    # A little of its own light: the game's liquids are flat-saturated, and a
    # purely diffuse column reads as pastel plastic under one sun.
    set_principled(material, "Emission Color", colour)
    set_principled(material, "Emission Strength", 0.16)
    obj.data.materials.append(material)
    return obj


def ambient(scene, colour, strength):
    world = bpy.data.worlds.new("hero.world")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = colour
    background.inputs["Strength"].default_value = strength


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # ---- sprite pass: one flat front render per skin ----------------------
    scene = new_scene()
    meshes, top = import_bottle(scene)
    scene.render.resolution_x = int(MM_W * PX_PER_MM * MARGIN)
    scene.render.resolution_y = int(MM_H * PX_PER_MM * MARGIN)
    ortho_camera(scene, "sprite.cam", 0.0, 0.0, MM_H / 1000.0 * MARGIN, top / 2.0)
    crop_to_bottle(scene)

    for skin_id, spec in SKINS.items():
        material = build_skin_material(f"skin.{skin_id}", spec)
        for obj in meshes:
            obj.data.materials.clear()
            obj.data.materials.append(material)
        scene.render.filepath = os.path.join(OUT_DIR, f"{skin_id}.png")
        bpy.ops.render.render(write_still=True)
        print("sprite", scene.render.filepath, flush=True)

    # ---- hero pass: one filled three-quarter render per skin --------------
    scene = new_scene()
    meshes, top = import_bottle(scene)
    scene.render.resolution_x = 560
    scene.render.resolution_y = 1000
    scene.render.use_border = False

    # The straight body runs 15..102.5 mm at 27.5 mm radius; below that the base
    # corner narrows, so a column that starts earlier would push through the
    # glass. Starting at 16 mm also leaves the thick glass foot visible.
    band = 22.0
    for index in range(4):
        liquid_column(scene, index, 16.0 + band * index, band, 25.0)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.0115, depth=0.016, location=(0, 0, top + 0.006), vertices=32
    )
    cork_obj = bpy.context.view_layer.objects.active
    for polygon in cork_obj.data.polygons:
        polygon.use_smooth = True
    cork_material = bpy.data.materials.new("hero.cork")
    cork_material.use_nodes = True
    set_principled(cork_material, "Base Color", (0.42, 0.26, 0.13, 1.0))
    set_principled(cork_material, "Roughness", 0.85)
    cork_obj.data.materials.append(cork_material)

    ambient(scene, (0.62, 0.68, 0.78, 1.0), 1.0)

    sun = bpy.data.lights.new("hero.sun", type="SUN")
    sun.energy = 3.0
    sun.angle = math.radians(12.0)
    sun_obj = bpy.data.objects.new("hero.sun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(35), math.radians(-12), math.radians(20))

    # Frame the cork too: aiming at the bottle's own centre would clip it.
    ortho_camera(scene, "hero.cam", 26.0, 14.0, 0.19, (top + 0.018) / 2.0)

    for skin_id, spec in SKINS.items():
        material = build_skin_material(f"hero.{skin_id}", spec)
        for obj in meshes:
            obj.data.materials.clear()
            obj.data.materials.append(material)
        scene.render.filepath = os.path.join(OUT_DIR, f"hero_{skin_id}.png")
        bpy.ops.render.render(write_still=True)
        print("hero", scene.render.filepath, flush=True)


if __name__ == "__main__":
    main()
