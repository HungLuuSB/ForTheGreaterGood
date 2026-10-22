"""Verdict (Order self-propelled howitzer, T1): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_verdict/build.py

Writes assets/models/ord_verdict/export/: ord_verdict.fbx (base_bar,
turret_bar, barrel_bar and the emissive_probe quad), the textures, rig.json
and preview_*.png. Roblox model space throughout (docs/contracts/rig.md).
Look: docs/art/style-guide.md (M-15, M-18): the Lancer chassis (Order reads
heavy, M-14) with a big armored casemate set to the rear and a very long gun
with a bore evacuator and a two-baffle muzzle brake reaching well past the
nose. Team plates on the hull top, the side skirts and the casemate roof.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

import bpy  # noqa: E402
import lib  # noqa: E402

UNIT = "ord_verdict"
OUT = os.path.join(HERE, "export")
TEX = 1024
BUDGET = 4000  # triangles, whole unit (M-12)
FOOTPRINT = 1  # cells of 8 studs (unit def)
SAMPLES = 32

KINDS = ["paint", "trim", "team", "seam", "track", "steel", "rubber", "glass", "light", "grille", "dark"]

# Order sand-grey (style guide, M-16 blockout hull (178, 174, 160)), a touch
# warmer so the rendered mesh matches the rendered blockout (review
# 2026-10-22: it read near-white with a blue tint). Measured side by side in
# Studio (M-18): (174, 168, 150) with ao 0.58 drew 16% darker than the
# blockout with the same hue, so the paint is a little lighter again.
PAINT = (184, 178, 160)
ACCENT = (90, 210, 255)  # Order emissive accent
VARIANTS = {
    "bar": {"type": "paint", "base": PAINT, "chip": (214, 210, 196), "grime": PAINT},
}

SPECS = {
    # painted metal: low metalness keeps the paint light (0.25 read mid-grey)
    "paint": {"base": None, "roughness": 0.62, "metallic": 0.1, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.64},
    "trim": {"base": (112, 110, 102), "roughness": 0.5, "metallic": 0.35, "edge_mode": "highlight", "edge_wear": 0.35, "ao": 0.55},
    # team plates: the team color at full strength, a dark outline on the bevel
    "team": {"base": (40, 40, 38), "roughness": 0.45, "metallic": 0.2, "mask": "team", "wash": 0.0,
             "chip_reveal": 0.85, "crease": 0.3, "edge_mode": "highlight", "edge_wear": 0.0},
    "seam": {"base": None, "darken": 0.32, "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.45},
    "track": {"base": (66, 66, 64), "roughness": 0.5, "metallic": 0.6, "edge_mode": "highlight", "edge_wear": 0.4, "bump": "tread"},
    "steel": {"base": (150, 150, 146), "roughness": 0.35, "metallic": 0.85, "edge_mode": "highlight", "edge_wear": 0.3},
    "rubber": {"base": (34, 34, 33), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0},
    "glass": {"base": (18, 26, 32), "roughness": 0.1, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.85},
    "light": {"base": (215, 240, 250), "roughness": 0.2, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0},
    "grille": {"base": None, "darken": 0.55, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
    "dark": {"base": (50, 50, 48), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.3},
}

# Joint pivots (rig.md 2) and the muzzle, Roblox model space
TURRET_PIVOT = (0.0, 1.85, 1.0)
BARREL_PIVOT = (0.0, 2.65, -1.35)
MUZZLE = (0.0, 2.65, -10.75)

UP = (0, 1, 0)
GLACIS_N = (0, 1.85, -0.4)  # upper glacis normal (up and forward)

SKIRTS = [(-3.75, -1.9), (-1.86, 0.0), (0.04, 1.9), (1.94, 3.7)]
WHEELS = (-2.75, -1.65, -0.55, 0.55, 1.65, 2.75)
SKIRT_IN, SKIRT_OUT = 2.86, 3.1  # thick skirts (Order reads heavy)
# the casemate: set to the rear, taller than the Lancer turret
TURRET_BODY = [(-1.6, -1.25), (1.6, -1.25), (2.1, -0.55), (2.1, 3.55), (-2.1, 3.55), (-2.1, -0.55)]
TURRET_Y0, ROOF_Y = 1.85, 3.4
TOP_SCALE = 0.93


def turret_side_x(y):
    """x of the turret's sloped side at height y."""
    return 2.1 - 2.1 * (1 - TOP_SCALE) * (y - TURRET_Y0) / (ROOF_Y - TURRET_Y0)


def glacis_point(z, lift=0.0):
    """(y, z) on the upper glacis at z, lifted along its normal."""
    y = 1.85 + (z + 2.3) * (0.4 / 1.85)
    n = lib.vec(GLACIS_N).normalized()
    return (y + n.y * lift, z + n.z * lift)


# ---------------------------------------------------------------------------
# Low-poly pieces (exported)
# ---------------------------------------------------------------------------


def build_base(p):
    # lower hull between the tracks, front plate sloped
    p.prism_x([(-3.45, 0.45), (3.55, 0.45), (3.9, 0.85), (3.9, 1.3), (-4.15, 1.3)], -1.95, 1.95, "trim", bevel=0.03)
    # upper hull over the tracks, long shallow glacis
    p.prism_x([(-4.15, 1.3), (3.9, 1.3), (3.9, 1.72), (3.65, 1.85), (-2.3, 1.85), (-4.15, 1.45)], -2.85, 2.85, "paint", bevel=0.05)
    # add-on armor slab on the glacis, thick enough to read at its front edge
    a, b = glacis_point(-3.95), glacis_point(-2.45)
    a2, b2 = glacis_point(-3.95, 0.2), glacis_point(-2.45, 0.2)
    p.prism_x([(a[1], a[0]), (b[1], b[0]), (b2[1], b2[0]), (a2[1], a2[0])], -2.4, 2.4, "paint", bevel=0.05)
    # engine deck grille, rear exhaust grille
    p.box((0, 1.875, 2.7), (2.9, 0.05, 1.4), "grille")
    p.box((0, 1.05, 3.915), (2.6, 0.4, 0.04), "grille")
    # team color: plates on the hull top either side of the turret
    for sx in (-1, 1):
        p.box((sx * 2.47, 1.88, 0.75), (0.62, 0.06, 5.2), "team", bevel=0.015)
    # driver's hatch, sensor strip, head and tail lights (emissive)
    p.cylinder("y", (0.75, 1.88, -2.05), 0.28, 0.06, 10, "trim")
    p.box((0, 1.33, -4.17), (3.2, 0.07, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 2.3, 1.52, -3.96), (0.36, 0.12, 0.1), "light")
        p.box((sx * 2.45, 1.52, 3.925), (0.3, 0.12, 0.04), "light")
    # thick side skirts in four panels down over the wheels; the front one cut back
    for sx in (-1, 1):
        x0, x1 = (SKIRT_IN, SKIRT_OUT) if sx > 0 else (-SKIRT_OUT, -SKIRT_IN)
        for i, (z0, z1) in enumerate(SKIRTS):
            if i == 0:
                prof = [(z0 + 0.5, 0.55), (z1, 0.55), (z1, 1.8), (z0, 1.8), (z0, 1.1)]
            else:
                prof = [(z0, 0.55), (z1, 0.55), (z1, 1.8), (z0, 1.8)]
            p.prism_x(prof, x0, x1, "paint", bevel=0.04)
        # team side plate along the middle panels
        p.box((sx * (SKIRT_OUT + 0.025), 1.5, 0.0), (0.05, 0.36, 3.6), "team", bevel=0.012)
    # tracks: a band round the sprocket (rear) and the idler (front)
    outline = [(-3.15, 0.0), (3.45, 0.0)]
    outline += lib.outline_circle(3.45, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-3.5, 1.0)]
    outline += lib.outline_circle(-3.5, 0.6, 0.4, 90, 210, 5)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.1, 2.84) if sx > 0 else (-2.84, -2.1)
        p.band_x(outline, inner, x0, x1, "track")
        for z in WHEELS:
            p.cylinder("x", (sx * 2.47, 0.46, z), 0.4, 0.34, 12, "rubber", cap_kinds=("trim", "trim"))
            p.cylinder("x", (sx * 2.47, 0.46, z), 0.14, 0.42, 8, "steel")
        p.cylinder("x", (sx * 2.47, 0.5, 3.45), 0.42, 0.46, 12, "steel")
        p.cylinder("x", (sx * 2.47, 0.6, -3.5), 0.32, 0.46, 12, "steel")


def build_turret(p):
    p.prism_y(TURRET_BODY, TURRET_Y0, ROOF_Y, "paint", bevel=0.06, top_scale=TOP_SCALE)
    # sloped armor brow over the gun
    p.prism_x([(-1.25, 1.95), (-0.55, 1.95), (-0.45, 3.35), (-1.0, 3.35)], -1.45, 1.45, "paint", bevel=0.05)
    # team color: a big roof plate and a plate on each side
    p.box((0, ROOF_Y + 0.03, 1.4), (3.0, 0.06, 3.4), "team", bevel=0.02)
    for sx in (-1, 1):
        n = (sx, 0.12, 0)
        p.obox((sx * (turret_side_x(2.65) + 0.03), 2.65, 1.6), (0, 0, 1), n, 2.6, 0.4, 0.05, "team", bevel=0.01)
    # ammunition lockers on the rear corners, a rear door
    for sx in (-1, 1):
        p.box((sx * 1.45, 2.5, 3.75), (0.9, 1.1, 0.4), "trim", bevel=0.03)
    p.box((0, 2.55, 3.585), (1.3, 1.1, 0.05), "dark")
    # commander hatch, gunner sight, sensor strips (emissive)
    p.cylinder("y", (-1.1, ROOF_Y + 0.05, 2.4), 0.32, 0.1, 10, "trim")
    p.box((1.15, ROOF_Y + 0.2, 0.0), (0.6, 0.38, 0.6), "trim", bevel=0.03)
    p.box((1.15, ROOF_Y + 0.21, -0.315), (0.44, 0.16, 0.03), "light")
    for sx in (-1, 1):
        p.box((sx * (turret_side_x(2.95) + 0.012), 2.95, 0.4), (0.03, 0.1, 1.4), "light")
    p.box((0, 2.0, 3.6), (1.2, 0.12, 0.03), "light")
    # antennas
    for sx in (-1, 1):
        p.cylinder("y", (sx * 1.5, ROOF_Y + 0.5, 3.1), 0.03, 1.0, 4, "dark")


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.box((0, y, -1.65), (1.3, 1.0, 0.7), "paint", bevel=0.06)  # mantlet
    p.cylinder("z", (0, y, -3.3), 0.26, 2.6, 16, "paint")  # thermal sleeve
    for z in (-2.1, -3.3, -4.5):
        p.cylinder("z", (0, y, z), 0.28, 0.08, 16, "steel")
    p.cylinder("z", (0, y, -5.2), 0.36, 0.9, 16, "paint")  # bore evacuator
    p.cylinder("z", (0, y, -5.2), 0.37, 0.08, 16, "steel")
    p.cylinder("z", (0, y, -7.75), 0.22, 4.2, 16, "paint")  # chase
    # two-baffle muzzle brake
    p.cylinder("z", (0, y, -10.15), 0.34, 0.95, 12, "steel")
    for z in (-9.9, -10.35):
        p.box((0, y, z), (0.9, 0.22, 0.14), "dark")
    p.cylinder("z", (0, y, -10.68), 0.14, 0.04, 10, "dark")
    p.box((0, y + 0.24, -6.5), (0.06, 0.035, 2.4), "light")  # rail strip (emissive)


# ---------------------------------------------------------------------------
# Details, baked into the textures only (never exported)
# ---------------------------------------------------------------------------


def bolt(p, at, n, r=0.04, h=0.03):
    p.ocyl(at, n, r, h, 6, "steel")


def bolts(p, a, b, count, n):
    a, b = lib.vec(a), lib.vec(b)
    for i in range(count):
        t = (i + 0.5) / count
        bolt(p, tuple(a + (b - a) * t), n)


def seam(p, a, b, n, width=0.035, height=0.012):
    a, b = lib.vec(a), lib.vec(b)
    c = (a + b) / 2
    p.obox(tuple(c), tuple(b - a), n, (b - a).length, width, height * 2, "seam")


def ring(p, center, n, r, width=0.04):
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


def details_base(p):
    # glacis add-on slab: bolts along its top face
    for z in (-3.75, -2.65):
        y, zz = glacis_point(z, 0.2)
        bolts(p, (-2.1, y, zz), (2.1, y, zz), 8, GLACIS_N)
    # driver's hatch seam, hinge and periscopes
    ring(p, (0.75, 1.851, -2.05), UP, 0.33)
    p.obox((0.75, 1.92, -1.77), (1, 0, 0), UP, 0.3, 0.08, 0.05, "steel")
    for dx in (-0.22, 0, 0.22):
        p.obox((0.75 + dx, 1.9, -2.43), (1, 0, 0), UP, 0.14, 0.06, 0.08, "glass")
    # panel lines across the deck and around the grille
    for z in (1.85, 3.5):
        seam(p, (-1.6, 1.851, z), (1.6, 1.851, z), UP)
    for sx in (-1, 1):
        seam(p, (sx * 1.6, 1.851, 1.85), (sx * 1.6, 1.851, 3.5), UP)
        p.ocyl((sx * 1.6, 0.8, 3.9), (0, 0, 1), 0.09, 0.12, 8, "steel")
    # skirts: bolts along the top, a stiffening rib along each panel
    for sx in (-1, 1):
        x = sx * SKIRT_OUT
        for z0, z1 in SKIRTS:
            bolts(p, (x, 1.7, z0), (x, 1.7, z1), 4, (sx, 0, 0))
            seam(p, (x, 0.85, z0 + 0.15), (x, 0.85, z1 - 0.15), (sx, 0, 0), width=0.05, height=0.015)


def details_turret(p):
    y = ROOF_Y + 0.001
    for a, b in (((-1.8, y, -0.4), (1.8, y, -0.4)), ((-1.8, y, 3.2), (1.8, y, 3.2))):
        seam(p, a, b, UP, width=0.03)
    ring(p, (-1.1, y, 2.4), UP, 0.37)
    for sx in (-1, 1):
        for z in (0.2, 1.6, 3.0):
            bolt(p, (sx * turret_side_x(3.2), 3.2, z), (sx, 0, 0))
    bolts(p, (-1.3, 2.1, 3.81), (1.3, 2.1, 3.81), 5, (0, 0, 1))


def details_barrel(p):
    y = BARREL_PIVOT[1]
    for dx in (-0.4, 0.4):
        for dy in (-0.3, 0.3):
            bolt(p, (dx, y + dy, -2.01), (0, 0, -1))


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

    lib.preview_lighting()
    for key in keys:
        lib.assign_single_material(low, lib.textured_material(f"preview_{key}", sets[key], (58, 120, 230), ACCENT))
        for name, cam, look, lens in [
            ("35", (-14, 11, 17), (0, 1.5, -0.5), 50),
            ("side", (19, 3, -2.0), (0, 1.6, -2.0), 50),
            ("80", (0, 27, 4.8), (0, 1.5, 0), 50),
            ("close", (-6.5, 5.0, -7.5), (0, 2.4, -2.5), 35),
        ]:
            lib.render_preview(os.path.join(OUT, f"preview_{key}_{name}.png"), cam, look, lens=lens)

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
    exported.append(lib.image_probe("emissive_probe", sets[keys[0]]["EMI"], col))
    lib.export_fbx(exported, os.path.join(OUT, f"{UNIT}.fbx"))

    lib.write_json(os.path.join(OUT, "rig.json"), {
        "id": UNIT,
        "footprintStuds": FOOTPRINT * 8,
        "variants": {"bar": "BAR-style painted sand-grey (M-15)"},
        "pieces": {
            "base": {"parent": None, **lib.bounds(low[0])},
            "turret": {"parent": "base", "pivot": list(TURRET_PIVOT), **lib.bounds(low[1])},
            "barrel": {"parent": "turret", "pivot": list(BARREL_PIVOT), **lib.bounds(low[2])},
        },
        "attachments": {"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
        "teamColorPieces": ["base", "turret"],
        "emissive": {"probe": "emissive_probe", "tint": list(ACCENT), "strength": 2.0},
        "triangles": {**counts, "total": total},
        "textures": {"size": TEX, "perVariant": ["ALB", "RGH"], "shared": ["NOR", "MTL", "EMI"]},
    })
    print(f"[{UNIT}] done: {OUT}")


main()
