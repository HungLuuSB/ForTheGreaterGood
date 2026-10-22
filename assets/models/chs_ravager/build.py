"""Ravager (Chaos light tank, T1): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_ravager/build.py

Writes assets/models/chs_ravager/export/: chs_ravager.fbx (base_bar, turret_bar,
barrel_bar and the emissive_probe quad), the textures (chs_ravager_bar_ALB /
_RGH, chs_ravager_NOR / _MTL / _EMI), rig.json and preview_*.png. Roblox model
space throughout (docs/contracts/rig.md): +X right, +Y up, forward = -Z, studs.
Look: docs/art/style-guide.md (M-15: BAR model style on T-14 / T-90M lines;
Chaos reads light, M-14): gunmetal paint, panel lines and edge highlights, a
domed turret with reactive-armor blocks, slat cages, exposed running gear,
bold team plates on the turret roof and sides and the hull top, orange
emissive sensors; turret and gun oversized for the RTS camera.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

import bpy  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402

UNIT = "chs_ravager"
OUT = os.path.join(HERE, "export")
TEX = 1024
BUDGET = 4000  # triangles, whole unit (M-12)
FOOTPRINT = 1
SAMPLES = 32
# Review 2026-10-22: Chaos reads lighter, so the whole unit is about 10% lower
# and narrower than the Lancer (M-14); applied after building, pivots included.
SCALE = (0.985, 0.9, 0.93)
lib.UPLOAD_REV = 2

KINDS = ["paint", "trim", "team", "seam", "era", "track", "steel", "rubber", "glass", "light", "grille", "dark"]

# Chaos gunmetal, lifted from (76, 80, 84) so it reads at 35° (review
# 2026-10-22); a second lift after the side-by-side measurement (M-18)
PAINT = (96, 100, 106)
ACCENT = (255, 140, 50)  # Chaos emissive accent
VARIANTS = {
    "bar": {"type": "paint", "base": PAINT, "chip": (172, 178, 184), "grime": PAINT},
}

SPECS = {
    "paint": {"base": None, "roughness": 0.45, "metallic": 0.12, "edge_mode": "highlight", "edge_wear": 0.7, "ao": 0.78},  # low metalness keeps gunmetal from reading black
    "trim": {"base": (46, 48, 52), "roughness": 0.5, "metallic": 0.35, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.6},
    "team": {"base": (24, 24, 26), "roughness": 0.45, "metallic": 0.2, "mask": "team", "wash": 0.0,
             "chip_reveal": 0.85, "crease": 0.3, "edge_mode": "highlight", "edge_wear": 0.0},
    "seam": {"base": None, "darken": 0.5, "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.45},
    # reactive-armor bricks: a lighter grey than the hull so they read as add-ons
    "era": {"base": (104, 108, 112), "roughness": 0.5, "metallic": 0.25, "edge_mode": "highlight", "edge_wear": 0.55, "ao": 0.55},
    "track": {"base": (58, 58, 58), "roughness": 0.5, "metallic": 0.6, "edge_mode": "highlight", "edge_wear": 0.45, "bump": "tread"},
    "steel": {"base": (140, 142, 144), "roughness": 0.35, "metallic": 0.85, "edge_mode": "highlight", "edge_wear": 0.3},
    "rubber": {"base": (30, 30, 30), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0},
    "glass": {"base": (22, 18, 16), "roughness": 0.1, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.85},
    "light": {"base": (255, 214, 170), "roughness": 0.2, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0},
    "grille": {"base": None, "darken": 0.5, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
    "dark": {"base": (34, 35, 38), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.35},
}

TURRET_PIVOT = (0.0, 1.9, 0.15)
BARREL_PIVOT = (0.0, 2.4, -1.5)
MUZZLE = (0.0, 2.4, -7.99)

UP = (0, 1, 0)
HULL_X = 2.65  # narrower than the Lancer's (light, M-14)
GLACIS_A, GLACIS_B = (-3.7, 1.45), (-2.0, 1.9)  # (z, y) ends of the upper glacis
WHEELS = (-2.6, -1.56, -0.52, 0.52, 1.56, 2.6)
TURRET_BODY = [(-1.0, -1.9), (1.0, -1.9), (1.7, -1.1), (1.7, 1.4), (1.2, 2.0), (-1.2, 2.0), (-1.7, 1.4), (-1.7, -1.1)]
TURRET_Y0, ROOF_Y, TOP_SCALE = 1.9, 2.92, 0.8  # tapered sides read as a dome


def glacis_normal():
    dz, dy = GLACIS_B[0] - GLACIS_A[0], GLACIS_B[1] - GLACIS_A[1]
    return (0.0, dz, -dy)  # perpendicular to the slope, up and forward


def glacis_point(t, lift=0.0):
    """Roblox (y, z) at fraction t from the glacis' low end, lifted along its normal."""
    z = GLACIS_A[0] + (GLACIS_B[0] - GLACIS_A[0]) * t
    y = GLACIS_A[1] + (GLACIS_B[1] - GLACIS_A[1]) * t
    n = lib.vec(glacis_normal()).normalized()
    return (y + n.y * lift, z + n.z * lift)


def turret_side_x(y):
    return 1.7 - 1.7 * (1 - TOP_SCALE) * (y - TURRET_Y0) / (ROOF_Y - TURRET_Y0)


# ---------------------------------------------------------------------------
# Low-poly pieces (exported)
# ---------------------------------------------------------------------------


def build_base(p):
    # lower hull, high off the ground (light, M-14)
    p.prism_x([(-3.2, 0.7), (3.2, 0.7), (3.5, 1.0), (3.5, 1.15), (-3.7, 1.15)], -1.75, 1.75, "trim", bevel=0.03)
    # upper hull over the tracks, short glacis
    p.prism_x([(-3.7, 1.15), (3.5, 1.15), (3.5, 1.75), (3.3, 1.9), (GLACIS_B[0], GLACIS_B[1]), (GLACIS_A[0], GLACIS_A[1])],
              -HULL_X, HULL_X, "paint", bevel=0.035)
    # reactive-armor bricks on the glacis, two rows with gaps
    n = glacis_normal()
    for t in (0.28, 0.72):
        y, z = glacis_point(t, 0.07)
        for i in range(6):
            x = -2.05 + i * 0.82
            p.obox((x, y, z), (1, 0, 0), n, 0.72, 0.62, 0.14, "era")
    # engine deck grille, driver's hatch, front lights and sensor (emissive)
    p.box((0, 1.92, 2.3), (2.4, 0.05, 1.6), "grille")
    for z in (1.85, 2.3, 2.75):  # engine-deck exhaust slots
        p.box((0, 1.95, z), (2.2, 0.04, 0.2), "light")
    for sx in (-1, 1):  # running strips along the flaps
        p.box((sx * (HULL_X + 0.12), 1.75, 0.0), (0.04, 0.1, 6.2), "light")
    p.cylinder("y", (0, 1.93, -1.6), 0.26, 0.06, 10, "trim")
    for sx in (-1, 1):
        p.box((sx * 2.1, 1.6, -3.71), (0.5, 0.2, 0.07), "head")
        p.box((sx * 2.2, 1.55, 3.51), (0.42, 0.16, 0.06), "light")
    # team color on the hull top: plates either side of the engine deck
    for sx in (-1, 1):
        p.box((sx * 1.95, 1.93, 2.0), (0.8, 0.05, 2.4), "team", bevel=0.012)
    # thin partial skirts (flaps) over the top of the track run, reactive bricks up front
    for sx in (-1, 1):
        x0, x1 = (HULL_X + 0.02, HULL_X + 0.1) if sx > 0 else (-HULL_X - 0.1, -HULL_X - 0.02)
        for z0, z1 in ((-3.3, -1.7), (-1.65, 0.0), (0.05, 1.7), (1.75, 3.2)):
            p.prism_x([(z0, 1.22), (z1, 1.22), (z1, 1.72), (z0, 1.72)], x0, x1, "paint", bevel=0.01)
        for z in (-2.95, -2.35, -1.75):
            p.box((sx * (HULL_X + 0.17), 1.47, z), (0.12, 0.42, 0.52), "era")
    # rear slat cage over the hull's back plate (open frame: reads light)
    for y in (0.95, 1.72):
        p.box((0, y, 3.75), (4.6, 0.05, 0.05), "dark")
    for i in range(9):
        p.box((-2.2 + i * 0.55, 1.33, 3.75), (0.04, 0.82, 0.04), "dark")
    for sx in (-1, 1):
        p.box((sx * 2.3, 1.33, 3.62), (0.05, 0.05, 0.3), "dark")
    # tracks and exposed road wheels
    outline = [(-2.9, 0.0), (3.1, 0.0)]
    outline += lib.outline_circle(3.15, 0.55, 0.55, -85, 90, 8)[1:]
    outline += [(-3.25, 1.1)]
    outline += lib.outline_circle(-3.25, 0.65, 0.45, 90, 215, 5)[1:]
    inner = lib.offset_polygon(outline, 0.09)
    for sx in (-1, 1):
        x0, x1 = (1.9, 2.64) if sx > 0 else (-2.64, -1.9)
        with p.sub("trackL" if sx < 0 else "trackR", (sx * 2.27, 0.5, 0.0), "scroll", (1, 0, 0)):  # M-27 track set
            p.band_x(outline, inner, x0, x1, "track")
            for z in WHEELS:
                p.cylinder("x", (sx * 2.27, 0.5, z), 0.42, 0.32, 10, "rubber", cap_kinds=("paint", "paint"))
                p.cylinder("x", (sx * 2.27, 0.5, z), 0.15, 0.4, 6, "steel")
            p.cylinder("x", (sx * 2.27, 0.55, 3.15), 0.44, 0.44, 12, "steel")
            p.cylinder("x", (sx * 2.27, 0.65, -3.25), 0.34, 0.44, 12, "steel")


def build_turret(p):
    p.prism_y(TURRET_BODY, TURRET_Y0, ROOF_Y, "paint", bevel=0.05, top_scale=TOP_SCALE)
    # bustle and the slat cage round it
    p.prism_y([(-1.15, 2.0), (1.15, 2.0), (1.0, 2.55), (-1.0, 2.55)], 1.98, 2.7, "paint", bevel=0.04)
    for y in (1.98, 2.78):
        p.box((0, y, 3.0), (3.0, 0.05, 0.05), "dark")
        for sx in (-1, 1):
            p.box((sx * 1.5, y, 2.45), (0.05, 0.05, 1.1), "dark")
    for i in range(8):
        p.box((-1.4 + i * 0.4, 2.38, 3.0), (0.04, 0.8, 0.04), "dark")
    for sx in (-1, 1):
        for z in (2.1, 2.55):
            p.box((sx * 1.5, 2.38, z), (0.04, 0.8, 0.04), "dark")
    # reactive-armor brow on the front faces
    for sx in (-1, 1):
        u = (-0.7 * sx, 0, -0.8)
        n = (0.8 * sx, 0.35, -0.7)
        p.obox((sx * 1.38, 2.35, -1.52), u, n, 1.0, 0.72, 0.16, "era")
        p.obox((sx * 0.62, 2.62, -1.95), (1, 0, 0), (0, 0.35, -1), 0.52, 0.42, 0.14, "era")
    # team color: roof plate and a plate on each side
    p.box((0, ROOF_Y + 0.025, 0.15), (2.1, 0.05, 2.4), "team", bevel=0.015)
    for sx in (-1, 1):
        n = (1.0 * sx, 0.31, 0.0)
        p.obox((sx * (turret_side_x(2.4) + 0.025), 2.4, 0.25), (0, 0, 1), n, 2.0, 0.42, 0.05, "team", bevel=0.01)
    # sensor heads on the front corners (emissive), commander's sight
    for sx in (-1, 1):
        p.box((sx * 1.0, ROOF_Y + 0.14, -1.25), (0.42, 0.28, 0.42), "trim", bevel=0.025)
        p.box((sx * 1.0, ROOF_Y + 0.15, -1.47), (0.36, 0.18, 0.04), "light")
    p.cylinder("y", (-0.55, ROOF_Y + 0.12, 0.95), 0.12, 0.24, 8, "dark")
    p.box((-0.55, ROOF_Y + 0.33, 0.95), (0.4, 0.24, 0.36), "trim", bevel=0.02)
    p.box((-0.55, ROOF_Y + 0.34, 0.765), (0.34, 0.14, 0.04), "light")
    # remote weapon station with a heavy MG (more weapons per vehicle)
    p.box((0.75, ROOF_Y + 0.17, 1.3), (0.5, 0.32, 0.55), "trim", bevel=0.025)
    p.cylinder("z", (0.75, ROOF_Y + 0.24, 0.65), 0.07, 0.8, 6, "dark")
    # twin ATGM launcher box on the left side
    p.box((-1.95, 2.55, 0.5), (0.42, 0.4, 1.3), "trim", bevel=0.03)
    for dy in (-0.09, 0.09):
        p.cylinder("z", (-1.95, 2.55 + dy, -0.16), 0.11, 0.05, 8, "weapon")
    # antenna
    p.cylinder("y", (1.2, ROOF_Y + 0.4, 1.7), 0.025, 0.8, 4, "dark")
    for sx in (-1, 1):  # turret side sensor strips
        p.box((sx * (turret_side_x(2.3) + 0.03), 2.3, 0.6), (0.04, 0.12, 1.8), "light")


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.box((0, y, -1.75), (0.85, 0.62, 0.5), "paint", bevel=0.05)  # mantlet
    p.cylinder("z", (0, y, -3.1), 0.205, 2.2, 14, "paint")
    # fume extractor with a glowing band (weapon glow, small)
    p.cylinder("z", (0, y, -4.3), 0.28, 0.2, 14, "paint", radius2=0.205)
    p.cylinder("z", (0, y, -4.62), 0.28, 0.44, 14, "paint")
    p.cylinder("z", (0, y, -4.62), 0.295, 0.16, 14, "weapon")
    p.cylinder("z", (0, y, -4.94), 0.195, 0.2, 14, "paint", radius2=0.28)
    p.cylinder("z", (0, y, -6.3), 0.195, 2.5, 14, "paint")
    for z in (-2.3, -3.6, -5.6, -7.0):
        p.cylinder("z", (0, y, z), 0.215, 0.07, 14, "steel")
    # muzzle and bore
    p.cylinder("z", (0, y, -7.7), 0.225, 0.36, 14, "paint")
    p.cylinder("z", (0, y, -7.93), 0.19, 0.1, 14, "steel", cap_kinds=("dark", "steel"), radius2=0.225)
    p.cylinder("z", (0, y, -7.97), 0.11, 0.04, 10, "dark")
    p.cylinder("z", (0, y, -7.55), 0.232, 0.12, 14, "weapon")  # muzzle ring


# ---------------------------------------------------------------------------
# Details, baked into the textures only
# ---------------------------------------------------------------------------


def bolt(p, at, n, r=0.04, h=0.03):
    p.ocyl(at, n, r, h, 6, "steel")


def bolts(p, a, b, count, n):
    a, b = lib.vec(a), lib.vec(b)
    for i in range(count):
        bolt(p, tuple(a + (b - a) * ((i + 0.5) / count)), n)


def seam(p, a, b, n, width=0.035, height=0.012):
    a, b = lib.vec(a), lib.vec(b)
    p.obox(tuple((a + b) / 2), tuple(b - a), n, (b - a).length, width, height * 2, "seam")


def ring(p, center, n, r, width=0.04):
    c, n_ = lib.vec(center), lib.vec(n).normalized()
    a = lib.Vector((1, 0, 0)) if abs(n_.x) < 0.9 else lib.Vector((0, 1, 0))
    u = (a - n_ * a.dot(n_)).normalized()
    v = n_.cross(u)
    for i in range(12):
        t0, t1 = 2 * math.pi * i / 12, 2 * math.pi * (i + 1) / 12
        seam(p, tuple(c + u * math.cos(t0) * r + v * math.sin(t0) * r),
             tuple(c + u * math.cos(t1) * r + v * math.sin(t1) * r), n, width)


def details_base(p):
    ring(p, (0, 1.901, -1.6), UP, 0.31)
    for z in (-1.0, 0.5, 1.4, 3.15):
        seam(p, (-2.55, 1.901, z), (2.55, 1.901, z), UP)
    for sx in (-1, 1):
        seam(p, (sx * 1.25, 1.901, 1.4), (sx * 1.25, 1.901, 3.15), UP)
        bolts(p, (sx * 2.6, 1.901, -1.9), (sx * 2.6, 1.901, 3.2), 6, UP)
        x = sx * (HULL_X + 0.1)
        bolts(p, (x, 1.62, -3.2), (x, 1.62, 3.1), 10, (sx, 0, 0))


def details_turret(p):
    y = ROOF_Y + 0.001
    ring(p, (-0.55, y, 0.95), UP, 0.3)
    for z in (-0.95, 1.3):
        seam(p, (-1.25, y, z), (1.25, y, z), UP, width=0.03)
    for sx in (-1, 1):
        bolts(p, (sx * 1.15, y, -1.05), (sx * 1.15, y, 1.4), 5, UP)


def details_barrel(p):
    y = BARREL_PIVOT[1]
    for dx in (-0.3, 0.3):
        for dy in (-0.2, 0.2):
            bolt(p, (dx, y + dy, -2.01), (0, 0, -1))


# ---------------------------------------------------------------------------


unit.run(
    __file__, UNIT, "chaos", footprint=FOOTPRINT,
        pieces=[
            unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
            unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret),
            unit.PieceSpec("barrel", "turret", BARREL_PIVOT, build_barrel, details_barrel),
        ],
        attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
        scale=SCALE,
        previews=[
            ("35", (-14, 11, 17), (0, 1.5, -0.5), 50),
            ("side", (19, 3, -2.0), (0, 1.6, -2.0), 50),
            ("80", (0, 27, 4.8), (0, 1.5, 0), 50),
            ("close", (-5.8, 4.6, -7.0), (0, 2.1, -1.6), 35),
        ],
)
