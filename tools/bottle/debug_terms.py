"""Which shader term is painting the bottle interior? Render the terms as RGB.

Red = view edge, green = vertical bands, blue = highlight strip, all unlit and
fully opaque, so a value on the film is a value the term really produced.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/bottle/debug_terms.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy

import render_skins as rs

OUT = "/tmp/skins_review/terms.png"


def main():
    scene = rs.new_scene()
    meshes, top = rs.import_bottle(scene)
    scene.render.resolution_x = int(rs.MM_W * rs.PX_PER_MM * rs.MARGIN)
    scene.render.resolution_y = int(rs.MM_H * rs.PX_PER_MM * rs.MARGIN)
    rs.ortho_camera(scene, "sprite.cam", 0.0, 0.0, rs.MM_H / 1000.0 * rs.MARGIN, top / 2.0)
    rs.crop_to_bottle(scene)

    material = bpy.data.materials.new("terms")
    tree = rs.node_tree(material)
    edge = rs.edge_ramp(tree, rs.view_edge(tree), "glass")
    bands = rs.vertical_bands(tree, "glass")
    strip = rs.highlight_strip(tree)

    combine = tree.nodes.new("ShaderNodeCombineColor")
    combine.location = (200, 0)
    tree.links.new(edge, combine.inputs["Red"])
    tree.links.new(bands, combine.inputs["Green"])
    tree.links.new(strip, combine.inputs["Blue"])
    emission = tree.nodes.new("ShaderNodeEmission")
    emission.location = (400, 0)
    tree.links.new(combine.outputs["Color"], emission.inputs["Color"])
    rs.shader_output(tree, emission.outputs["Emission"])

    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(material)

    for node in tree.nodes:
        if node.type == "VALTORGB":
            stops = " ".join(
                f"{element.position:.2f}->{element.color[0]:.2f}"
                for element in node.color_ramp.elements
            )
            print(f"ramp at {node.location[:]}: {stops}")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT)


main()
