"""Unit codex portraits (the user's request 2026-10-23): one image per unit
def, the same three-quarter camera and lighting, plain neutral background,
team blue; the approved BAR mesh where there is one, else the blockout.

    lune run _portraits   (a temporary dump script: debug_out/portraits/defs.json)
    blender -b --factory-startup --python-exit-code 1 -P assets/models/tools/portraits.py -- [first] [count]

Writes debug_out/portraits/<id>.jpg (512 x 320) and portraits_<first>.json
(footprint and height in studs per id; merged into portraits.json after).
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib  # noqa: E402
import unit  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "debug_out", "portraits")
TEAM = (58, 120, 230)  # team blue, as the previews
BG = (0.42, 0.43, 0.45)
W, H = 512, 320
LENS = 50
PALETTES = {
    "order": {"hull": (178, 174, 160), "dark": (112, 110, 102), "track": (54, 54, 52), "metal": (140, 140, 134),
              "glass": (90, 210, 255), "team": TEAM, "hazard": (228, 184, 40)},
    "chaos": {"hull": (86, 90, 95), "dark": (46, 48, 52), "track": (36, 36, 36), "metal": (104, 108, 112),
              "glass": (255, 140, 50), "team": TEAM, "hazard": (228, 184, 40)},
}


def clear_unit():
    for o in list(bpy.data.objects):
        if o.get("unit"):
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    for i in list(bpy.data.images):
        if i.users == 0:
            bpy.data.images.remove(i)


def flat_material(rgb, emit=0.0):
    key = f"flat_{rgb}_{emit}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lib.srgb(rgb)
    b.inputs["Roughness"].default_value = 0.6
    if emit:
        b.inputs["Emission Color"].default_value = lib.srgb(rgb)
        b.inputs["Emission Strength"].default_value = emit
    return m


def orientation(rot):
    """Roblox Orientation (degrees; applied Y, then X, then Z) as a 3x3 in Roblox space."""
    if not rot:
        return Matrix.Identity(3)
    rx, ry, rz = (math.radians(a) for a in rot)
    return (Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(rz, 3, "Z"))


def part_verts(p):
    """Local shape vertices and faces in Roblox space (unit size, centred)."""
    shape = p["shape"]
    if shape == "box":
        v = [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        return v, f
    if shape == "wedge":  # Roblox WedgePart: vertical face at the back (+Z), the slope down to the front
        v = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
        return v, f
    if shape == "cylinder":
        n = 20
        axis = p.get("axis", "x")
        v, f = [], []
        for e in (-0.5, 0.5):
            for i in range(n):
                a = 2 * math.pi * i / n
                c, s = 0.5 * math.cos(a), 0.5 * math.sin(a)
                v.append({"x": (e, c, s), "y": (c, e, s), "z": (c, s, e)}[axis])
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n + j, n + i))
        f.append(tuple(range(n - 1, -1, -1)))
        f.append(tuple(range(n, 2 * n)))
        return v, f
    # ball
    v, f = [], []
    rings, segs = 8, 16
    for r in range(rings + 1):
        t = math.pi * r / rings
        for s in range(segs):
            a = 2 * math.pi * s / segs
            v.append((0.5 * math.sin(t) * math.cos(a), 0.5 * math.cos(t), 0.5 * math.sin(t) * math.sin(a)))
    for r in range(rings):
        for s in range(segs):
            a, b = r * segs + s, r * segs + (s + 1) % segs
            f.append((a, b, b + segs, a + segs))
    return v, f


def build_blockout(entry, col):
    pal = PALETTES[entry["faction"]]
    objs = []
    for p in entry["parts"]:
        v, f = part_verts(p)
        size, at, rot = Vector(p["size"]), Vector(p["at"]), orientation(p.get("rot"))
        bm = bmesh.new()
        verts = []
        for x, y, z in v:
            rb = at + rot @ Vector((x * size.x, y * size.y, z * size.z))
            verts.append(bm.verts.new(lib.R(rb.x, rb.y, rb.z)))
        for face in f:
            try:
                bm.faces.new([verts[i] for i in face])
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(p["name"])
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new(p["name"], mesh)
        o["unit"] = True
        col.objects.link(o)
        key = p["color"]
        mesh.materials.append(flat_material(pal.get(key, pal["hull"]), 2.0 if key == "glass" else 0.0))
        objs.append(o)
    return objs


def build_mesh(entry, col):
    uid = entry["id"]
    exp = os.path.join(ROOT, "assets", "models", uid, "export")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(exp, f"{uid}.fbx"))
    objs = [o for o in bpy.data.objects if o not in before]
    imgs = {}
    for k, name in {"ALB": f"{uid}_bar_ALB.png", "RGH": f"{uid}_bar_RGH.png", "NOR": f"{uid}_NOR.png",
                    "MTL": f"{uid}_MTL.png", "EMI": f"{uid}_EMI.png"}.items():
        img = bpy.data.images.load(os.path.join(exp, name), check_existing=False)
        if k != "ALB":
            img.colorspace_settings.name = "Non-Color"
        imgs[k] = img
    glow = unit.FACTIONS[entry["faction"]]["glow"]
    base_mat = lib.textured_material(f"p_{uid}", imgs, TEAM, None)
    keep = []
    for o in objs:
        o["unit"] = True
        if o.type != "MESH" or o.name.startswith(("emissive_probe", "tex_")):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        if "_glow_" in o.name:
            channel = o.name.split("_glow_")[1].split(".")[0]
            lib.assign_single_material([o], lib.textured_material(f"p_{uid}_{channel}", imgs, None, glow.get(channel, (220, 220, 220))))
        else:
            lib.assign_single_material([o], base_mat)
        keep.append(o)
    return keep


def world_bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objs:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def setup():
    lib.reset_scene()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (*BG, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    sun = bpy.data.lights.new("key", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("key", sun)
    so.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))  # from front-left, above
    scene.collection.objects.link(so)
    fill = bpy.data.lights.new("fill", "SUN")
    fill.energy = 0.8
    fo = bpy.data.objects.new("fill", fill)
    fo.rotation_euler = Euler((math.radians(60), 0, math.radians(150)))
    scene.collection.objects.link(fo)
    # a ground plane in the background tone, so units sit on something
    gm = bpy.data.meshes.new("ground")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=2000)
    bm.to_mesh(gm)
    bm.free()
    g = bpy.data.objects.new("ground", gm)
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (BG[0] * 0.9, BG[1] * 0.9, BG[2] * 0.9, 1)
    b.inputs["Roughness"].default_value = 1.0
    gm.materials.append(mat)
    scene.collection.objects.link(g)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = LENS
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    s = scene.render.image_settings
    s.file_format, s.color_mode, s.quality = "JPEG", "RGB", 92
    return cam


def frame(cam, lo, hi):
    """The same three-quarter view for every unit (front-left, 30 degrees
    down), distanced so the bounding sphere fills the frame."""
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2
    # Roblox: forward is -Z, so the front-left is (-x, +y, -z)
    d_rb = Vector((-1.0, 0.75, -1.15)).normalized()
    d = lib.R(d_rb.x, d_rb.y, d_rb.z)
    sensor_h = 36 * H / W  # the sensor's vertical extent at this aspect
    fov_v = 2 * math.atan(sensor_h / 2 / LENS)
    dist = radius / math.sin(fov_v / 2) * 0.68
    cam.location = center + d * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    first = int(args[0]) if args else 0
    count = int(args[1]) if len(args) > 1 else 10_000
    entries = json.load(open(os.path.join(OUT, "defs.json"), encoding="utf-8"))[first:first + count]
    cam = setup()
    col = bpy.context.scene.collection
    meta = {}
    for e in entries:
        clear_unit()
        objs = build_mesh(e, col) if e["mesh"] else build_blockout(e, col)
        lo, hi = world_bounds(objs)
        # air units hover a little so they don't read as parked
        lift = Vector((0, 0, 1.5)) if e["domain"] == "air" and lo.z < 0.5 else Vector((0, 0, 0))
        for o in objs:
            o.location += lift
        lo, hi = lo + lift, hi + lift
        frame(cam, lo, hi)
        bpy.context.scene.render.filepath = os.path.join(OUT, f"{e['id']}.jpg")
        bpy.ops.render.render(write_still=True)
        size = hi - lo
        meta[e["id"]] = {"name": e["name"], "footprint": e["footprint"], "height": round(hi.z - lift.z, 2),
                         "size": [round(size.x, 2), round(size.y, 2), round(size.z, 2)],
                         "source": "mesh" if e["mesh"] else ("blockout" if e["handmade"] else "generic blockout")}
        print(f"[portrait] {e['id']} {meta[e['id']]['source']} h {meta[e['id']]['height']}")
    json.dump(meta, open(os.path.join(OUT, f"portraits_{first}.json"), "w", encoding="utf-8"), indent=1)


main()
