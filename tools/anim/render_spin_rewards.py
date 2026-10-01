"""Render the lucky-spin reward flipbooks: a minted coin and a cut gem.

A coin turning through its own edge is the one celebration move a 2D rotation
cannot fake: the silhouette goes from a disc to a bar and back, and the
highlight sweeps across the metal as it does. Both are drawn here in 3D and
baked to a flipbook, for the same reasons the victory spin is (see
render_victory_spin.py).

The emblem is the coin the game already sells - a four point star inside a
minted ring - built from geometry rather than a texture, so it throws a real
highlight instead of a painted one.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/anim/render_spin_rewards.py
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
PROJECT = os.path.dirname(TOOLS)
sys.path.insert(0, os.path.join(TOOLS, "bottle"))

import render_skins as rs  # noqa: E402  (reuses the shipped look and camera)

FRAMES = 16
PIXELS = 256
# 55 mm across a square frame: the 48 mm coin fills it with room for the lean
# and the bob, so no frame clips and both sequences share one camera.
ORTHO_SCALE = 0.055
MM = 0.001

OUT = {
    "coin": os.path.join(PROJECT, "assets", "anim", "spin_coin"),
    "gem": os.path.join(PROJECT, "assets", "anim", "spin_gem"),
}

# One turn per loop, so the last frame joins back onto the first.
COIN_LEAN_DEG = 12.0
# A gem has to rock further than a coin leans: tipping toward the lens is what
# trades the side profile for the table, and that swap is its whole motion.
GEM_LEAN_DEG = 24.0
BOB_MM = 2.6


def deg(value):
    return math.radians(value)


def active():
    return bpy.context.view_layer.objects.active


def studio(scene):
    """Three suns and one broad area lamp: the sweep across the metal is the
    motion, and a flat world alone would leave gold looking like brass paint."""
    rs.ambient(scene, (0.62, 0.57, 0.52, 1.0), 1.0)
    key = bpy.data.lights.new("spin.key", type="SUN")
    key.energy = 2.4
    key.angle = deg(9.0)
    fill = bpy.data.lights.new("spin.fill", type="SUN")
    fill.energy = 2.2
    fill.color = (0.75, 0.85, 1.0)
    rim = bpy.data.lights.new("spin.rim", type="SUN")
    rim.energy = 2.6
    rim.color = (1.0, 0.86, 0.62)
    broad = bpy.data.lights.new("spin.broad", type="AREA")
    broad.energy = 8.0
    broad.shape = "SQUARE"
    broad.size = 0.35

    for name, light, location, rotation in (
        ("key", key, (0.12, -0.16, 0.20), (deg(38), 0, deg(32))),
        ("fill", fill, (-0.18, -0.14, 0.10), (deg(62), 0, deg(-58))),
        ("rim", rim, (0.05, 0.22, 0.14), (deg(-42), 0, deg(168))),
        ("broad", broad, (0.0, -0.30, 0.24), (deg(52), 0, 0)),
    ):
        obj = bpy.data.objects.new("spin." + name, light)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = rotation


def metal(name, colour, roughness):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    rs.set_principled(material, "Base Color", (*colour, 1.0))
    rs.set_principled(material, "Metallic", 1.0)
    rs.set_principled(material, "Roughness", roughness)
    return material


def gem_material(name, colour):
    """A gem is not metal. It reads as lit from inside, the way the game's
    liquids are painted, so a little of its own colour goes back out."""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    rs.set_principled(material, "Base Color", (*colour, 1.0))
    rs.set_principled(material, "Metallic", 0.15)
    rs.set_principled(material, "Roughness", 0.06)
    rs.set_principled(material, "Emission Color", (*colour, 1.0))
    rs.set_principled(material, "Emission Strength", 0.10)
    rs.set_principled(material, "Coat Weight", 1.0)
    return material


def shade(obj, smooth):
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth


def lathe(scene, name, profile_mm, segments):
    """Revolve a radius/height profile about Z, closing it with two flat discs.

    The rim is authored rather than bevelled because Blender 5.2's bevel
    modifier has no smooth-by-angle option left: an explicit profile is what
    puts the shading break exactly where the flat face stops and the edge
    begins, which is the difference between a minted coin and a pill.
    """
    vertices = []
    for radius, height in profile_mm:
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            vertices.append(
                (
                    radius * MM * math.cos(angle),
                    radius * MM * math.sin(angle),
                    height * MM,
                )
            )

    rings = len(profile_mm)
    faces = []
    for band in range(rings - 1):
        base, top = band * segments, (band + 1) * segments
        for index in range(segments):
            nxt = (index + 1) % segments
            faces.append((base + index, base + nxt, top + nxt, top + index))
    # Each cap is one convex disc, so it cannot be mis-rasterised, and it stays
    # flat shaded: the face of a coin is a plane.
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple(range((rings - 1) * segments, rings * segments)))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=True)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)

    quads = (rings - 1) * segments
    for index, polygon in enumerate(mesh.polygons):
        polygon.use_smooth = index < quads
    return obj


def coin_profile(edge=1.1, half=2.5, radius=24.0):
    """One quarter of the coin's cross section, mirrored.

    The profile runs outward along the face, around the fillet, up the rim and
    back in, so its first and last points are the two faces.
    """
    flat = radius - edge
    quarter = math.pi / 2.0
    arc = [quarter * third for third in (1, 2)]
    return (
        [(flat, -half)]
        + [(flat + edge * math.sin(t), -half + edge - edge * math.cos(t)) for t in arc]
        + [(radius, -half + edge), (radius, half - edge)]
        + [(flat + edge * math.cos(t), half - edge + edge * math.sin(t)) for t in arc]
        + [(flat, half)]
    )


def empty(scene, name):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    return obj


def star(side):
    """The game's coin emblem: four long points and four short ones, raised off
    the face it belongs to.

    An emboss is only embossed if its own normals say so - the mesh is built
    lying flat with its front cap on +Z, so the star that carries the far face
    can simply be rotated half a turn.
    """
    points = []
    for index in range(8):
        angle = math.pi * index / 4.0
        # Four long points and four short ones, the same proportions as the
        # coin icon the shop already sells.
        radius = (13.0 if index % 2 == 0 else 4.2) * MM
        points.append((radius * math.cos(angle), radius * math.sin(angle)))

    depth = 0.6 * MM
    vertices = [(x, y, 0.0) for x, y in points]
    vertices += [(x, y, depth) for x, y in points]
    near, far = list(range(8)), list(range(8, 16))
    faces = []
    # Triangles only: a concave eight sided outline is something the rasteriser
    # can get wrong as a single n-gon, and the side wall needs four vertices
    # anyway. The outline runs counter-clockwise seen from +Z, so the caps are
    # wound in opposite orders and the walls start at the near rim.
    for index in range(1, 7):
        faces.append((near[0], near[index + 1], near[index]))
        faces.append((far[0], far[index], far[index + 1]))
    for index in range(8):
        nxt = (index + 1) % 8
        faces.append((near[index], near[nxt], far[nxt], far[index]))

    mesh = bpy.data.meshes.new("spin.star")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=True)
    obj = bpy.data.objects.new("spin.star", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location.z = 2.5 * MM * side
    if side < 0:
        obj.rotation_euler = (math.pi, 0.0, 0.0)
    return obj


def coin(scene):
    """A blank with a rounded edge, a minted ring and a star on each face.

    Everything is built lying flat with its axis on Z; `stand` is what tips it
    up to face the camera, so the same rig drives the gem too.
    """
    blank = lathe(scene, "spin.blank", coin_profile(), 96)
    parts = [blank]

    for side in (1, -1):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=18.5 * MM,
            minor_radius=0.6 * MM,
            major_segments=72,
            minor_segments=10,
            location=(0, 0, side * 2.5 * MM),
        )
        parts.append(active())
        parts.append(star(side))

    polished = metal("spin.gold.device", (0.74, 0.48, 0.10), 0.14)
    matte = metal("spin.gold.field", (0.90, 0.66, 0.20), 0.42)
    for obj in parts:
        # A coin is a polished device struck on a matte field, and that is the
        # only reason an emblem the same colour as its background is readable:
        # one sharp highlight against one soft one.
        material = matte if obj is blank else polished
        obj.data.materials.clear()
        obj.data.materials.append(material)
        # The rings are round; the star is flat, because an emboss you cannot
        # see the edge of is just a drawing on the coin.
        shade(obj, not obj.name.startswith("spin.star"))
    return parts


def gem(scene):
    """An eight sided brilliant: a table, a crown, a girdle and a pavilion.

    The pavilion's facets are offset by half a step the way a real cut stone
    is, so it has to tuck inside the crown's edge-to-edge radius of 19.4 mm or
    its corners poke out through the girdle as ears.
    """
    parts = []
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=21 * MM,
        radius2=9 * MM,
        depth=11 * MM,
        location=(0, 0, 9.5 * MM),
    )
    parts.append(active())
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=0.0,
        radius2=19.0 * MM,
        depth=19 * MM,
        location=(0, 0, -5.5 * MM),
    )
    pavilion = active()
    pavilion.rotation_euler = (0.0, 0.0, deg(22.5))
    parts.append(pavilion)

    material = gem_material("spin.gem", (0.05, 0.42, 0.80))
    for obj in parts:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        # Flat facets: a gem is read by the planes it throws back at the eye,
        # and smoothing it turns the whole thing into one soft blob.
        shade(obj, False)
    return parts


def stand(scene, parts, upright):
    """turn -> body -> parts. The lean belongs to `turn`, whose XYZ order means
    it tips back first and then spins about the world's vertical; a lean on the
    body would precess with every frame.

    A coin has to lie on its edge to show its face to a camera that sits on -Y,
    but a gem tipped the same way presents its table straight down the axis,
    which flattens an eight sided brilliant into a plain octagon. Left upright it
    rocks toward and away from the lens instead, and that is what reads as cut
    glass.
    """
    turn = empty(scene, "spin.turn")
    body = empty(scene, "spin.body")
    body.parent = turn
    if not upright:
        body.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    for obj in parts:
        obj.parent = body
    return turn


def keyframe(obj, frame, yaw_deg, lean_deg, bob_mm):
    obj.rotation_euler = (deg(lean_deg), 0.0, deg(yaw_deg))
    obj.location.z = bob_mm * MM
    obj.keyframe_insert("rotation_euler", frame=frame)
    obj.keyframe_insert("location", frame=frame)


def render(scene, out_dir, turn, lean_deg):
    scene.frame_start = 1
    scene.frame_end = FRAMES
    os.makedirs(out_dir, exist_ok=True)
    for index in range(FRAMES):
        phase = 2.0 * math.pi * index / FRAMES
        keyframe(
            turn,
            index + 1,
            360.0 * index / FRAMES,
            lean_deg * math.cos(phase),
            BOB_MM * math.sin(2.0 * phase),
        )
        scene.frame_set(index + 1)
        scene.render.filepath = os.path.join(out_dir, "frame_%02d.png" % (index + 1))
        bpy.ops.render.render(write_still=True)
    print("wrote", FRAMES, "frames to", out_dir, flush=True)


def build_scene():
    scene = rs.new_scene()
    # Blender eases every new keyframe by default, which pulls a steady turn
    # into a pulse once per frame. A flipbook needs equal steps.
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    scene.render.resolution_x = PIXELS
    scene.render.resolution_y = PIXELS
    scene.render.use_border = False
    samples = getattr(getattr(scene, "eevee", None), "taa_render_samples", None)
    if samples is not None:
        scene.eevee.taa_render_samples = 24
    studio(scene)
    rs.ortho_camera(scene, "spin.cam", 0.0, 6.0, ORTHO_SCALE, 0.0)
    return scene


def total_kb(path):
    return (
        sum(
            os.path.getsize(os.path.join(root, name))
            for root, _, names in os.walk(path)
            for name in names
        )
        / 1024.0
    )


def main():
    for name, build, lean_deg, upright in (
        ("coin", coin, COIN_LEAN_DEG, False),
        ("gem", gem, GEM_LEAN_DEG, True),
    ):
        scene = build_scene()
        turn = stand(scene, build(scene), upright)
        render(scene, OUT[name], turn, lean_deg)
        print("%s: %.0f KB" % (name, total_kb(OUT[name])), flush=True)


if __name__ == "__main__":
    main()
