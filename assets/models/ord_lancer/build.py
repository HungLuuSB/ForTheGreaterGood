"""Lancer (Order light tank, T1): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_lancer/build.py

Writes assets/models/ord_lancer/export/: ord_lancer.fbx, ord_lancer_{ALB,NOR,RGH,MTL}.png,
rig.json and preview_*.png. Roblox model space throughout (docs/contracts/rig.md):
+X right, +Y up, forward = -Z, studs. Look: docs/art/style-guide.md (Order: Leopard 2
lines, sand camouflage, sensor strips and active protection, team color on top).
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

import bpy  # noqa: E402
import lib  # noqa: E402

UNIT = "ord_lancer"
OUT = os.path.join(HERE, "export")
TEX = 1024
BUDGET = 4000  # triangles, whole unit (M-12)
FOOTPRINT = 1  # cells of 8 studs (unit def)

KINDS = ["paint", "team", "track", "steel", "rubber", "glass", "grille", "dark"]

CAMO = {
    "scale": 0.28,
    "seed": 1.0,
    # Order sand (186, 170, 132) with mid tan and dark earth patches
    "stops": [(0.0, (124, 108, 82)), (0.43, (186, 170, 132)), (0.57, (158, 140, 104)), (0.68, (124, 108, 82))],
}

SPECS = {
    "paint": {"base": None, "roughness": 0.62, "metallic": 0.0, "edge_wear": 0.35},
    "team": {"base": (205, 205, 200), "roughness": 0.55, "metallic": 0.0, "mask": 0.1, "edge_wear": 0.15},
    "track": {"base": (70, 68, 64), "roughness": 0.55, "metallic": 0.6, "edge_wear": 0.45, "bump": "tread"},
    "steel": {"base": (88, 86, 80), "roughness": 0.5, "metallic": 0.7, "edge_wear": 0.4},
    "rubber": {"base": (34, 34, 33), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.05},
    "glass": {"base": (28, 40, 50), "roughness": 0.1, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.8},
    "grille": {"base": None, "roughness": 0.7, "metallic": 0.0, "edge_wear": 0.2, "bump": "grille", "ao": 0.35},
    "dark": {"base": (46, 46, 44), "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.2},
}

# Joint pivots (rig.md 2) and the muzzle, Roblox model space
TURRET_PIVOT = (0.0, 1.85, 0.4)
BARREL_PIVOT = (0.0, 2.3, -1.45)
MUZZLE = (0.0, 2.3, -7.5)


def offset_polygon(points, d):
    """Offsets a closed (z, y) outline by d (positive = inward)."""
    n = len(points)
    area = sum(points[i][0] * points[(i + 1) % n][1] - points[(i + 1) % n][0] * points[i][1] for i in range(n))
    sign = 1 if area > 0 else -1  # counterclockwise: inward is to the left
    out = []
    for i in range(n):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
        nrm = []
        for a, b in ((p0, p1), (p1, p2)):
            dz, dy = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dz, dy) or 1
            nrm.append((-dy / length * sign, dz / length * sign))  # left normal
        nz, ny = nrm[0][0] + nrm[1][0], nrm[0][1] + nrm[1][1]
        length = math.hypot(nz, ny) or 1
        nz, ny = nz / length, ny / length
        cos = nz * nrm[1][0] + ny * nrm[1][1]
        k = d / max(cos, 0.5)
        out.append((p1[0] + nz * k, p1[1] + ny * k))
    return out


def build_base(p):
    # lower hull between the tracks, front plate sloped
    p.prism_x([(-3.45, 0.45), (3.55, 0.45), (3.9, 0.85), (3.9, 1.3), (-4.15, 1.3)], -1.95, 1.95, "paint", bevel=0.03)
    # upper hull over the tracks, long shallow glacis
    p.prism_x([(-4.15, 1.3), (3.9, 1.3), (3.9, 1.72), (3.65, 1.85), (-2.3, 1.85), (-4.15, 1.45)], -2.85, 2.85, "paint", bevel=0.04)
    # engine deck grille, rear exhaust grille
    p.box((0, 1.875, 2.6), (3.2, 0.05, 1.5), "grille")
    p.box((0, 1.05, 3.915), (2.6, 0.4, 0.04), "grille")
    # team color on the hull top: sponson plates beside the turret
    for sx in (-1, 1):
        p.box((sx * 2.35, 1.872, 0.6), (0.8, 0.04, 3.4), "team")
    # driver's hatch, lights, front sensor strip (near-future accent)
    p.cylinder("y", (0.75, 1.88, -2.0), 0.28, 0.06, 10, "paint")
    p.box((0, 1.38, -4.165), (3.2, 0.07, 0.04), "glass")
    for sx in (-1, 1):
        p.box((sx * 2.3, 1.52, -3.95), (0.36, 0.12, 0.1), "glass")
        p.box((sx * 2.45, 1.52, 3.925), (0.3, 0.12, 0.04), "glass")
    # side skirts in four panels, the front one cut back at the bottom
    segments = [(-3.75, -1.9), (-1.86, 0.0), (0.04, 1.9), (1.94, 3.7)]
    for sx in (-1, 1):
        x0, x1 = (2.86, 2.98) if sx > 0 else (-2.98, -2.86)
        for i, (z0, z1) in enumerate(segments):
            if i == 0:
                prof = [(z0 + 0.45, 0.85), (z1, 0.85), (z1, 1.78), (z0, 1.78), (z0, 1.2)]
            else:
                prof = [(z0, 0.85), (z1, 0.85), (z1, 1.78), (z0, 1.78)]
            p.prism_x(prof, x0, x1, "paint", bevel=0.02)
    # tracks: a band round the sprocket (rear) and the idler (front)
    outline = [(-3.15, 0.0), (3.45, 0.0)]
    outline += lib.outline_circle(3.45, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-3.5, 1.0)]
    outline += lib.outline_circle(-3.5, 0.6, 0.4, 90, 210, 5)[1:]
    inner = offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.1, 3.0) if sx > 0 else (-3.0, -2.1)
        p.band_x(outline, inner, x0, x1, "track")
        # road wheels (painted discs, rubber tires), sprocket, idler
        for z in (-2.75, -1.65, -0.55, 0.55, 1.65, 2.75):
            p.cylinder("x", (sx * 2.55, 0.46, z), 0.4, 0.36, 14, "rubber", cap_kinds=("paint", "paint"))
            p.cylinder("x", (sx * 2.55, 0.46, z), 0.14, 0.44, 8, "steel")
        p.cylinder("x", (sx * 2.55, 0.5, 3.45), 0.42, 0.5, 12, "steel")
        p.cylinder("x", (sx * 2.55, 0.6, -3.5), 0.32, 0.5, 12, "steel")


def build_turret(p):
    # body: chamfered front corners, slightly sloped sides
    p.prism_y([(-1.6, -1.6), (1.6, -1.6), (1.8, -1.2), (1.8, 1.75), (-1.8, 1.75), (-1.8, -1.2)],
              1.85, 2.72, "paint", bevel=0.04, top_scale=0.96)
    # bustle and its stowage rack
    p.prism_y([(-1.55, 1.75), (1.55, 1.75), (1.45, 2.75), (-1.45, 2.75)], 1.95, 2.66, "paint", bevel=0.03, top_scale=0.96)
    p.box((0, 2.25, 2.95), (2.6, 0.5, 0.4), "grille", bevel=0.02)
    # arrowhead wedge armor either side of the gun (Leopard 2A6 lines)
    for sx in (-1, 1):
        v = [(sx * 1.65, 1.92, -1.6), (sx * 0.42, 1.92, -1.6), (sx * 0.42, 1.92, -2.3),
             (sx * 1.65, 2.62, -1.6), (sx * 0.42, 2.62, -1.6), (sx * 0.42, 2.32, -2.3)]
        f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        p._shell(v, f, "paint", bevel=0.03)
    # team color: roof plate
    p.box((0, 2.735, 0.25), (2.4, 0.03, 2.3), "team")
    # commander's panoramic sight
    p.cylinder("y", (-0.95, 2.9, 0.9), 0.12, 0.35, 8, "dark")
    p.box((-0.95, 3.15, 0.9), (0.45, 0.3, 0.4), "paint", bevel=0.02)
    p.box((-0.95, 3.17, 0.69), (0.35, 0.15, 0.03), "glass")
    # gunner's sight
    p.box((0.95, 2.86, -0.95), (0.55, 0.3, 0.6), "paint", bevel=0.02)
    p.box((0.95, 2.88, -1.26), (0.4, 0.14, 0.03), "glass")
    # remote weapon station
    p.box((0.7, 2.86, 1.35), (0.45, 0.25, 0.45), "paint", bevel=0.02)
    p.cylinder("z", (0.7, 2.92, 0.85), 0.05, 0.6, 6, "dark")
    # sensor strips and active protection (near-future accents)
    for sx in (-1, 1):
        p.box((sx * 1.805, 2.35, -0.6), (0.03, 0.12, 1.0), "glass")
        p.box((sx * 1.92, 2.35, 1.3), (0.25, 0.4, 0.5), "paint", bevel=0.02)
        p.box((sx * 1.92, 2.42, 0.4), (0.2, 0.25, 0.45), "dark")
        p.cylinder("y", (sx * 1.3, 3.05, 2.45), 0.025, 0.7, 4, "dark")
    p.box((0, 2.35, 2.765), (1.0, 0.12, 0.03), "glass")


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.box((0, y, -1.75), (0.8, 0.62, 0.5), "paint", bevel=0.05)  # mantlet
    p.cylinder("z", (0, y, -2.85), 0.19, 1.7, 16, "paint")  # thermal sleeve
    p.cylinder("z", (0, y, -3.775), 0.27, 0.15, 16, "paint", radius2=0.19)
    p.cylinder("z", (0, y, -4.15), 0.27, 0.6, 16, "paint")  # fume extractor
    p.cylinder("z", (0, y, -4.525), 0.18, 0.15, 16, "paint", radius2=0.27)
    p.cylinder("z", (0, y, -5.8), 0.18, 2.4, 16, "paint")
    p.cylinder("z", (0, y, -7.225), 0.2, 0.45, 16, "paint", cap_kinds=("dark", "paint"))  # muzzle, bore
    p.box((0, y + 0.23, -7.1), (0.12, 0.08, 0.2), "dark")  # muzzle reference sensor
    p.box((0, y + 0.19, -5.8), (0.07, 0.04, 2.3), "steel")  # rail accent


def main():
    lib.reset_scene()
    scene = bpy.context.scene
    col = scene.collection

    target = lib.new_image("bake_target", TEX, "sRGB")
    materials = {k: lib.make_material(k, SPECS[k], CAMO, target) for k in KINDS}

    pieces = [
        ("base", (0.0, 0.0, 0.0), build_base),
        ("turret", TURRET_PIVOT, build_turret),
        ("barrel", BARREL_PIVOT, build_barrel),
    ]
    objs = []
    for name, pivot, fn in pieces:
        p = lib.Piece(name, KINDS, pivot)
        fn(p)
        objs.append(p.to_object(materials, col))

    counts = {o.name: lib.tris(o) for o in objs}
    total = sum(counts.values())
    print(f"[{UNIT}] triangles {counts} total {total}")
    if total > BUDGET:
        raise SystemExit(f"[{UNIT}] over budget: {total} > {BUDGET}")

    lib.unwrap(objs)
    paths, imgs = lib.bake_all(objs, list(materials.values()), TEX, 32, OUT, UNIT)

    # preview renders with the team color under the mask (Overlay)
    lib.preview_lighting()
    preview = lib.preview_team_material("preview", imgs, (58, 120, 230))
    lib.assign_single_material(objs, preview)
    for name, cam, look in [
        ("preview_55", (0, 22, 15.4), (0, 1.5, 0)),
        ("preview_35", (-14, 11, 17), (0, 1.5, -0.5)),
        ("preview_side", (18, 3, -1.5), (0, 1.5, -1.5)),
        ("preview_80", (0, 26, 4.6), (0, 1.5, 0)),
    ]:
        lib.render_preview(os.path.join(OUT, f"{name}.png"), cam, look)

    # export with the plain textured material
    final, _, _ = lib.textured_material(UNIT, imgs)
    lib.assign_single_material(objs, final)
    lib.export_fbx(objs, os.path.join(OUT, f"{UNIT}.fbx"))

    def bounds(o):
        import mathutils
        pts = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
        rb = [lib.to_roblox(v) for v in pts]
        lo = [min(v[i] for v in rb) for i in range(3)]
        hi = [max(v[i] for v in rb) for i in range(3)]
        return {"center": [round((lo[i] + hi[i]) / 2, 4) for i in range(3)],
                "size": [round(hi[i] - lo[i], 4) for i in range(3)]}

    lib.write_json(os.path.join(OUT, "rig.json"), {
        "id": UNIT,
        "footprintStuds": FOOTPRINT * 8,
        "pieces": {
            "base": {"parent": None, **bounds(objs[0])},
            "turret": {"parent": "base", "pivot": list(TURRET_PIVOT), **bounds(objs[1])},
            "barrel": {"parent": "turret", "pivot": list(BARREL_PIVOT), **bounds(objs[2])},
        },
        "attachments": {"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
        "teamColorPieces": ["base", "turret"],
        "triangles": {**counts, "total": total},
        "textures": {k: {"file": os.path.basename(v), "size": TEX} for k, v in paths.items()},
    })
    print(f"[{UNIT}] done: {OUT}")


main()
