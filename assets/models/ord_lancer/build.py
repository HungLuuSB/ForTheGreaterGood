"""Lancer (Order light tank, T1): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_lancer/build.py

Writes assets/models/ord_lancer/export/: ord_lancer.fbx (the pieces of every
camouflage variant: base_a, turret_a, barrel_a, base_b, ...), the textures
(ord_lancer_<variant>_ALB / _RGH, shared ord_lancer_NOR / _MTL), rig.json and
preview_*.png. Roblox model space throughout (docs/contracts/rig.md): +X right,
+Y up, forward = -Z, studs. Look: docs/art/style-guide.md (Order: Leopard 2
lines, sand, sensor strips and active protection, team color on top).
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
SAMPLES = 32

KINDS = ["paint", "team", "seam", "track", "steel", "rubber", "glass", "grille", "dark"]

SAND = (186, 170, 132)
# Camouflage candidates (review, 2026-10-21): a = plain sand, weathered; b = crisp
# three-tone disruptive pattern in sand, light brown and dark brown.
VARIANTS = {
    "a": {"type": "plain", "base": SAND, "mottle": 0.06,
          "chip": (210, 198, 166), "grime": (112, 98, 74)},
    "b": {"type": "disruptive", "base": SAND,
          "tones": [((150, 124, 86), 0.34, 0.55, 1.0), ((96, 80, 58), 0.3, 0.6, 2.0)],
          "chip": (212, 200, 168), "grime": (112, 98, 74)},
}

SPECS = {
    "paint": {"base": None, "roughness": 0.78, "metallic": 0.0, "edge_wear": 0.55, "grime": 0.95},
    # Roblox draws Overlay darker than Blender: a light wash keeps the team
    # color readable at 220 studs (review 2026-10-21: 0.3 read as navy)
    "team": {"base": (120, 118, 110), "roughness": 0.65, "metallic": 0.0, "mask": "team", "wash": 0.1,
             "chip_reveal": 0.5, "crease": 0.25, "edge_wear": 0.6, "grime": 0.4},
    "seam": {"base": None, "darken": 0.55, "roughness": 0.85, "metallic": 0.0, "edge_wear": 0.2, "grime": 0.75, "ao": 0.45},
    "track": {"base": (72, 68, 62), "roughness": 0.6, "metallic": 0.55, "edge_wear": 0.6, "bump": "tread", "grime": 0.9},
    "steel": {"base": (90, 86, 78), "roughness": 0.55, "metallic": 0.65, "edge_wear": 0.6, "grime": 0.6},
    "rubber": {"base": (36, 35, 33), "roughness": 0.92, "metallic": 0.0, "edge_wear": 0.1, "grime": 0.8},
    "glass": {"base": (26, 38, 46), "roughness": 0.12, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.85},
    "grille": {"base": None, "darken": 0.7, "roughness": 0.8, "metallic": 0.0, "edge_wear": 0.3, "bump": "grille", "ao": 0.35, "grime": 0.6},
    "dark": {"base": (44, 44, 42), "roughness": 0.65, "metallic": 0.2, "edge_wear": 0.3},
}

# Joint pivots (rig.md 2) and the muzzle, Roblox model space
TURRET_PIVOT = (0.0, 1.85, 0.4)
BARREL_PIVOT = (0.0, 2.3, -1.45)
MUZZLE = (0.0, 2.3, -7.52)

UP = (0, 1, 0)
GLACIS_N = (0, 1.85, -0.4)  # upper glacis normal (up and forward)


# ---------------------------------------------------------------------------
# Low-poly pieces (exported)
# ---------------------------------------------------------------------------


def build_base(p):
    # lower hull between the tracks, front plate sloped
    p.prism_x([(-3.45, 0.45), (3.55, 0.45), (3.9, 0.85), (3.9, 1.3), (-4.15, 1.3)], -1.95, 1.95, "paint", bevel=0.03)
    # upper hull over the tracks, long shallow glacis
    p.prism_x([(-4.15, 1.3), (3.9, 1.3), (3.9, 1.72), (3.65, 1.85), (-2.3, 1.85), (-4.15, 1.45)], -2.85, 2.85, "paint", bevel=0.04)
    # engine deck grille, rear exhaust grille
    p.box((0, 1.875, 2.6), (3.2, 0.05, 1.5), "grille")
    p.box((0, 1.05, 3.915), (2.6, 0.4, 0.04), "grille")
    # driver's hatch, lights, front sensor strip (near-future accent)
    p.cylinder("y", (0.75, 1.88, -2.0), 0.28, 0.06, 10, "paint")
    p.box((0, 1.38, -4.165), (3.2, 0.07, 0.04), "glass")
    for sx in (-1, 1):
        p.box((sx * 2.3, 1.52, -3.95), (0.36, 0.12, 0.1), "glass")
        p.box((sx * 2.45, 1.52, 3.925), (0.3, 0.12, 0.04), "glass")
    # side skirts in four panels, the front one cut back at the bottom
    for sx in (-1, 1):
        x0, x1 = (2.86, 2.98) if sx > 0 else (-2.98, -2.86)
        for i, (z0, z1) in enumerate(SKIRTS):
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
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.1, 3.0) if sx > 0 else (-3.0, -2.1)
        p.band_x(outline, inner, x0, x1, "track")
        for z in WHEELS:
            p.cylinder("x", (sx * 2.55, 0.46, z), 0.4, 0.36, 14, "rubber", cap_kinds=("paint", "paint"))
            p.cylinder("x", (sx * 2.55, 0.46, z), 0.14, 0.44, 8, "steel")
        p.cylinder("x", (sx * 2.55, 0.5, 3.45), 0.42, 0.5, 12, "steel")
        p.cylinder("x", (sx * 2.55, 0.6, -3.5), 0.32, 0.5, 12, "steel")


SKIRTS = [(-3.75, -1.9), (-1.86, 0.0), (0.04, 1.9), (1.94, 3.7)]
WHEELS = (-2.75, -1.65, -0.55, 0.55, 1.65, 2.75)
TURRET_BODY = [(-1.6, -1.6), (1.6, -1.6), (1.8, -1.2), (1.8, 1.75), (-1.8, 1.75), (-1.8, -1.2)]
ROOF_Y = 2.72


def turret_side_x(y):
    """x of the turret's sloped side at height y (top scaled 0.96)."""
    return 1.8 - 0.072 * (y - 1.85) / 0.87


def build_turret(p):
    p.prism_y(TURRET_BODY, 1.85, ROOF_Y, "paint", bevel=0.04, top_scale=0.96)
    # bustle and its stowage rack
    p.prism_y([(-1.55, 1.75), (1.55, 1.75), (1.45, 2.75), (-1.45, 2.75)], 1.95, 2.66, "paint", bevel=0.03, top_scale=0.96)
    p.box((0, 2.25, 2.95), (2.6, 0.5, 0.4), "grille", bevel=0.02)
    # arrowhead wedge armor either side of the gun (Leopard 2A6 lines)
    for sx in (-1, 1):
        v = [(sx * 1.65, 1.92, -1.6), (sx * 0.42, 1.92, -1.6), (sx * 0.42, 1.92, -2.3),
             (sx * 1.65, 2.62, -1.6), (sx * 0.42, 2.62, -1.6), (sx * 0.42, 2.32, -2.3)]
        f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        p._shell(v, f, "paint", bevel=0.03)
    # team color: a painted roof panel and a stripe along each side
    p.box((0, ROOF_Y + 0.012, 0.1), (2.2, 0.025, 1.8), "team", bevel=0.008)
    for sx in (-1, 1):
        p.box((sx * (turret_side_x(2.52) + 0.012), 2.52, 0.2), (0.025, 0.16, 2.6), "team", bevel=0.006)
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
    # commander's hatch
    p.cylinder("y", (-0.9, ROOF_Y + 0.03, 1.45), 0.28, 0.06, 10, "paint")
    # sensor strips and active protection (near-future accents)
    for sx in (-1, 1):
        p.box((sx * 1.805, 2.25, -0.6), (0.03, 0.1, 1.0), "glass")
        p.box((sx * 1.92, 2.35, 1.3), (0.25, 0.4, 0.5), "paint", bevel=0.02)
        p.box((sx * 1.92, 2.42, 0.4), (0.2, 0.25, 0.45), "dark")
        p.cylinder("y", (sx * 1.3, 3.05, 2.45), 0.025, 0.7, 4, "dark")
    p.box((0, 2.35, 2.765), (1.0, 0.12, 0.03), "glass")


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.box((0, y, -1.75), (0.8, 0.62, 0.5), "paint", bevel=0.05)  # mantlet
    # thermal sleeve in two sections with clamp bands
    p.cylinder("z", (0, y, -2.85), 0.19, 1.7, 16, "paint")
    p.cylinder("z", (0, y, -5.75), 0.18, 2.3, 16, "paint")
    for z in (-2.15, -2.85, -3.55, -5.0, -5.75, -6.5):
        p.cylinder("z", (0, y, z), 0.205 if z > -3.7 else 0.195, 0.07, 16, "steel")
    # bore evacuator: tapered ends, a band round its middle
    p.cylinder("z", (0, y, -3.78), 0.27, 0.16, 16, "paint", radius2=0.19)
    p.cylinder("z", (0, y, -4.15), 0.27, 0.58, 16, "paint")
    p.cylinder("z", (0, y, -4.15), 0.282, 0.08, 16, "steel")
    p.cylinder("z", (0, y, -4.52), 0.18, 0.16, 16, "paint", radius2=0.27)
    # muzzle: a short thicker section, a chamfered lip and the dark bore
    p.cylinder("z", (0, y, -6.96), 0.2, 0.12, 16, "paint", radius2=0.18)
    p.cylinder("z", (0, y, -7.2), 0.205, 0.36, 16, "paint")
    p.cylinder("z", (0, y, -7.43), 0.17, 0.1, 16, "steel", cap_kinds=("dark", "steel"), radius2=0.205)
    p.cylinder("z", (0, y, -7.465), 0.1, 0.04, 12, "dark")
    p.box((0, y + 0.24, -7.05), (0.12, 0.08, 0.22), "dark")  # muzzle reference sensor
    p.box((0, y + 0.19, -5.75), (0.06, 0.035, 2.1), "steel")  # rail accent


# ---------------------------------------------------------------------------
# Details, baked into the textures only (never exported)
# ---------------------------------------------------------------------------


def bolt(p, at, n, r=0.035, h=0.025):
    p.ocyl(at, n, r, h, 6, "steel")


def bolts(p, a, b, count, n, inset=0.0):
    a, b = lib.vec(a), lib.vec(b)
    for i in range(count):
        t = (i + 0.5) / count if inset == 0 else inset + (1 - 2 * inset) * i / max(count - 1, 1)
        bolt(p, tuple(a + (b - a) * t), n)


def seam(p, a, b, n, width=0.035, height=0.012):
    a, b = lib.vec(a), lib.vec(b)
    c = (a + b) / 2
    p.obox(tuple(c), tuple(b - a), n, (b - a).length, width, height * 2, "seam")


def ring(p, center, n, r, width=0.04):
    """A hatch seam: short segments round a circle."""
    c, n_ = lib.vec(center), lib.vec(n).normalized()
    a = lib.Vector((1, 0, 0)) if abs(n_.x) < 0.9 else lib.Vector((0, 1, 0))
    u = (a - n_ * a.dot(n_)).normalized()
    v = n_.cross(u)
    k = 12
    for i in range(k):
        t0, t1 = 2 * math.pi * i / k, 2 * math.pi * (i + 1) / k
        pa = c + u * math.cos(t0) * r + v * math.sin(t0) * r
        pb = c + u * math.cos(t1) * r + v * math.sin(t1) * r
        seam(p, tuple(pa), tuple(pb), n, width)


def glacis_y(z):
    return 1.85 + (z + 2.3) * (0.4 / 1.85)


def details_base(p):
    # upper glacis: a seam across, bolts along the nose and the deck edge
    gz = -3.2
    seam(p, (-2.75, glacis_y(gz), gz), (2.75, glacis_y(gz), gz), GLACIS_N)
    bolts(p, (-2.4, glacis_y(-3.95), -3.95), (2.4, glacis_y(-3.95), -3.95), 12, GLACIS_N)
    bolts(p, (-2.6, glacis_y(-2.45), -2.45), (2.6, glacis_y(-2.45), -2.45), 10, GLACIS_N)
    # driver's hatch seam, hinge and periscopes
    ring(p, (0.75, 1.851, -2.0), UP, 0.33)
    p.obox((0.75, 1.92, -1.72), (1, 0, 0), UP, 0.3, 0.08, 0.05, "steel")
    for dx in (-0.22, 0, 0.22):
        p.obox((0.75 + dx, 1.9, -2.38), (1, 0, 0), UP, 0.14, 0.06, 0.08, "glass")
    # sponson tops: panel seams across, bolts at their ends
    for sx in (-1, 1):
        for z in (-1.0, 0.6, 2.2):
            seam(p, (sx * 1.85, 1.851, z), (sx * 2.82, 1.851, z), UP)
            bolts(p, (sx * 1.95, 1.851, z + 0.09), (sx * 2.72, 1.851, z + 0.09), 2, UP, inset=0.0)
        seam(p, (sx * 2.8, 1.851, -2.25), (sx * 2.8, 1.851, 3.6), UP, width=0.03)
    # rear deck: access panel seams round the grille, tow eyes on the rear plate
    for z in (1.82, 3.38):
        seam(p, (-1.65, 1.851, z), (1.65, 1.851, z), UP)
    for sx in (-1, 1):
        seam(p, (sx * 1.65, 1.851, 1.82), (sx * 1.65, 1.851, 3.38), UP)
        p.ocyl((sx * 1.6, 0.8, 3.9), (0, 0, 1), 0.09, 0.12, 8, "steel")
    # skirts: a row of bolts along the top, a stiffening rib along each panel
    for sx in (-1, 1):
        x = sx * 2.98
        for z0, z1 in SKIRTS:
            bolts(p, (x, 1.68, z0), (x, 1.68, z1), 5, (sx, 0, 0))
            seam(p, (x, 1.22, z0 + 0.12), (x, 1.22, z1 - 0.12), (sx, 0, 0), width=0.05, height=0.015)


def details_turret(p):
    # roof weld line round the edge and a module seam across the front
    rx, rz0, rz1 = 1.58, -1.38, 1.55
    y = ROOF_Y + 0.001
    for a, b in (((-rx, y, rz0), (rx, y, rz0)), ((rx, y, rz0), (rx, y, rz1)),
                 ((rx, y, rz1), (-rx, y, rz1)), ((-rx, y, rz1), (-rx, y, rz0))):
        seam(p, a, b, UP, width=0.03)
    for corner in ((-rx, y, rz0), (rx, y, rz0), (rx, y, rz1), (-rx, y, rz1)):
        bolt(p, corner, UP)
    # hatch rings
    ring(p, (-0.9, ROOF_Y + 0.001, 1.45), UP, 0.33)
    # side armor modules: vertical seams with bolts at their ends
    for sx in (-1, 1):
        for z in (-0.9, 0.05, 1.05):
            a = (sx * turret_side_x(1.97), 1.97, z)
            b = (sx * turret_side_x(2.62), 2.62, z)
            seam(p, a, b, (sx, 0, 0))
            bolt(p, (sx * turret_side_x(2.0), 2.0, z + 0.1), (sx, 0, 0))
            bolt(p, (sx * turret_side_x(2.6), 2.6, z + 0.1), (sx, 0, 0))
    # wedge armor: bolts along the back edge of each top face
    for sx in (-1, 1):
        a = lib.vec((sx * 1.65, 2.62, -1.6))
        b = lib.vec((sx * 0.42, 2.62, -1.6))
        c = lib.vec((sx * 0.42, 2.32, -2.3))
        n = (b - a).cross(c - a)
        if n.y < 0:
            n = -n
        off = (c - b).normalized() * 0.12
        for t in (0.2, 0.5, 0.8):
            bolt(p, tuple(a + (b - a) * t + off), tuple(n))
    # bustle top: bolts across
    bolts(p, (-1.2, 2.661, 2.35), (1.2, 2.661, 2.35), 5, UP)


def details_barrel(p):
    y = BARREL_PIVOT[1]
    # mantlet bolts
    for dx in (-0.28, 0.28):
        for dy in (-0.2, 0.2):
            bolt(p, (dx, y + dy, -2.0), (0, 0, -1))


# ---------------------------------------------------------------------------


def main():
    lib.reset_scene()
    scene = bpy.context.scene
    col = scene.collection

    keys = list(VARIANTS.keys())
    target = lib.new_image("bake_target", TEX, "sRGB")
    materials = {k: lib.make_material(k, SPECS[k], [VARIANTS[v] for v in keys], target) for k in KINDS}

    pieces = [
        ("base", (0.0, 0.0, 0.0), build_base, details_base),
        ("turret", TURRET_PIVOT, build_turret, details_turret),
        ("barrel", BARREL_PIVOT, build_barrel, details_barrel),
    ]
    low, high = [], []
    for name, pivot, build, details in pieces:
        p = lib.Piece(name, KINDS, pivot)
        build(p)
        low.append(p.to_object(materials, col))
        h = lib.Piece(name + "_hi", KINDS, pivot)
        build(h)
        details(h)
        high.append(h.to_object(materials, col))

    counts = {o.name: lib.tris(o) for o in low}
    total = sum(counts.values())
    print(f"[{UNIT}] triangles {counts} total {total}")
    if total > BUDGET:
        raise SystemExit(f"[{UNIT}] over budget: {total} > {BUDGET}")

    lib.unwrap(low)
    sets = lib.bake_all(low, high, list(materials.values()), TEX, SAMPLES, OUT, UNIT, keys)
    for h in high:
        bpy.data.objects.remove(h, do_unlink=True)

    # preview renders per variant, team color under the mask (Overlay)
    lib.preview_lighting()
    for key in keys:
        lib.assign_single_material(low, lib.textured_material(f"preview_{key}", sets[key], (58, 120, 230)))
        for name, cam, look, lens in [
            ("35", (-14, 11, 17), (0, 1.5, -0.5), 50),
            ("side", (18, 3, -1.5), (0, 1.5, -1.5), 50),
            ("80", (0, 26, 4.6), (0, 1.5, 0), 50),
            ("close", (-5.5, 4.2, -6.5), (0, 2.0, -1.5), 35),
        ]:
            lib.render_preview(os.path.join(OUT, f"preview_{key}_{name}.png"), cam, look, lens=lens)

    # export every variant's pieces, each with its own material
    exported = []
    for key in keys:
        mat = lib.textured_material(f"{UNIT}_{key}", sets[key])
        for o in low:
            c = o.copy()
            c.data = o.data.copy()
            c.name = f"{o.name}_{key}"
            col.objects.link(c)
            lib.assign_single_material([c], mat)
            exported.append(c)
    lib.export_fbx(exported, os.path.join(OUT, f"{UNIT}.fbx"))

    lib.write_json(os.path.join(OUT, "rig.json"), {
        "id": UNIT,
        "footprintStuds": FOOTPRINT * 8,
        "variants": {"a": "plain sand, weathered", "b": "three-tone disruptive"},
        "pieces": {
            "base": {"parent": None, **lib.bounds(low[0])},
            "turret": {"parent": "base", "pivot": list(TURRET_PIVOT), **lib.bounds(low[1])},
            "barrel": {"parent": "turret", "pivot": list(BARREL_PIVOT), **lib.bounds(low[2])},
        },
        "attachments": {"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
        "teamColorPieces": ["turret"],
        "triangles": {**counts, "total": total},
        "textures": {"size": TEX, "perVariant": ["ALB", "RGH"], "shared": ["NOR", "MTL"]},
    })
    print(f"[{UNIT}] done: {OUT}")


main()
