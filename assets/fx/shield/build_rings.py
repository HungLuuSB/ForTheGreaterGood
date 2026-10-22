"""Thin ring meshes for the shield's flowing rings (client request, C-94).

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/shield/build_rings.py

Writes assets/fx/shield/export/shield_rings.fbx with
  ring_thin   torus, radius 1, tube 0.002 (a fifth of `ring`), horizontal
  band        an open cylinder wall, radius 1, height 1 (y from -0.5 to 0.5),
              wall 0.002 thick, faces both ways: Size.Y sets the ribbon's
              width apart from its radius
A mesh's tube always scales with its radius, so these are the two ways to
keep a ring thin on a big dome. White, untextured (the client tints them).
Usage: docs/contracts/fx.md.
"""

import math
import os

import bmesh
import bpy

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")
SEGMENTS = 48


def obj(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    mat = bpy.data.materials.new(name + "_white")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
    mesh.materials.append(mat)
    return o


def ring_thin():
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    tube, sides = 0.002, 3
    grid = []
    for i in range(SEGMENTS):
        t = 2 * math.pi * i / SEGMENTS
        grid.append([bm.verts.new(((1 + tube * math.cos(2 * math.pi * j / sides)) * math.cos(t),
                                   (1 + tube * math.cos(2 * math.pi * j / sides)) * math.sin(t),
                                   tube * math.sin(2 * math.pi * j / sides))) for j in range(sides)])
    for i in range(SEGMENTS):
        for j in range(sides):
            f = bm.faces.new([grid[i][j], grid[(i + 1) % SEGMENTS][j], grid[(i + 1) % SEGMENTS][(j + 1) % sides], grid[i][(j + 1) % sides]])
            for loop, t in zip(f.loops, [(i / SEGMENTS, j / sides), ((i + 1) / SEGMENTS, j / sides),
                                        ((i + 1) / SEGMENTS, (j + 1) / sides), (i / SEGMENTS, (j + 1) / sides)]):
                loop[uv].uv = t
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj("ring_thin", bm)


def band():
    """Outer and inner walls (2 * SEGMENTS quads each) so it shows from both
    sides; U round the ring, V across the ribbon (0 bottom, 1 top)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for r, outward in ((1.001, True), (0.999, False)):
        lo = [bm.verts.new((r * math.cos(2 * math.pi * i / SEGMENTS), r * math.sin(2 * math.pi * i / SEGMENTS), -0.5)) for i in range(SEGMENTS)]
        hi = [bm.verts.new((r * math.cos(2 * math.pi * i / SEGMENTS), r * math.sin(2 * math.pi * i / SEGMENTS), 0.5)) for i in range(SEGMENTS)]
        for i in range(SEGMENTS):
            k = (i + 1) % SEGMENTS
            quad = [lo[i], lo[k], hi[k], hi[i]] if outward else [lo[k], lo[i], hi[i], hi[k]]
            uvs = [(i / SEGMENTS, 0), ((i + 1) / SEGMENTS, 0), ((i + 1) / SEGMENTS, 1), (i / SEGMENTS, 1)]
            if not outward:
                uvs = [uvs[1], uvs[0], uvs[3], uvs[2]]
            f = bm.faces.new(quad)
            for loop, t in zip(f.loops, uvs):
                loop[uv].uv = t
    return obj("band", bm)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    objs = [ring_thin(), band()]
    for o in objs:
        o.data.calc_loop_triangles()
        print(f"[shield_rings] {o.name} triangles {len(o.data.loop_triangles)}")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "shield_rings.fbx"), use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
        mesh_smooth_type="FACE", add_leaf_bones=False, bake_space_transform=True,
    )
    print("[shield_rings] done")


main()
