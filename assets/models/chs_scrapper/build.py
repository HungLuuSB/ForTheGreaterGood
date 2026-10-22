"""Scrapper (Chaos builder, T1): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_scrapper/build.py

Writes assets/models/chs_scrapper/export/: chs_scrapper.fbx (base_bar,
nano_bar and the emissive_probe quad), the textures, rig.json and
preview_*.png. Roblox model space throughout (docs/contracts/rig.md).
Look: docs/art/style-guide.md (M-15, M-18): the Ravager's chassis (Chaos reads
light, M-14: exposed wheels, slat cage, the same 10% smaller scale) with a
plow, a small armored cab on the left, a hopper heaped with scrap and a
stack; on the `nano` turntable a hydraulic arm with a claw and the orange
build emitter. Team plates on the hull top and the turntable.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

import bpy  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402

UNIT = "chs_scrapper"
OUT = os.path.join(HERE, "export")
TEX = 1024
BUDGET = 4000  # triangles, whole unit (M-12)
FOOTPRINT = 1
SAMPLES = 32
# Review 2026-10-22: Chaos reads lighter, so the whole unit is about 10% lower
# and narrower than the Lancer (M-14); applied after building, pivots included.
SCALE = (0.985, 0.9, 0.93)

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

NANO_PIVOT = (1.2, 1.9, 0.3)  # the nano turntable on the right of the deck

UP = (0, 1, 0)
HULL_X = 2.65  # narrower than the Lancer's (light, M-14)
GLACIS_A, GLACIS_B = (-3.7, 1.45), (-2.0, 1.9)  # (z, y) ends of the upper glacis
WHEELS = (-2.6, -1.56, -0.52, 0.52, 1.56, 2.6)


# ---------------------------------------------------------------------------
# Low-poly pieces (exported)
# ---------------------------------------------------------------------------


def build_base(p):
    # lower hull, high off the ground (light, M-14)
    p.prism_x([(-3.2, 0.7), (3.2, 0.7), (3.5, 1.0), (3.5, 1.15), (-3.7, 1.15)], -1.75, 1.75, "trim", bevel=0.03)
    # upper hull over the tracks, short glacis
    p.prism_x([(-3.7, 1.15), (3.5, 1.15), (3.5, 1.75), (3.3, 1.9), (GLACIS_B[0], GLACIS_B[1]), (GLACIS_A[0], GLACIS_A[1])],
              -HULL_X, HULL_X, "paint", bevel=0.035)
    # plow: an angled scraper blade on two arms, a toothed bottom edge
    p.prism_x([(-4.35, 0.2), (-4.05, 0.2), (-3.9, 0.9), (-4.15, 1.5), (-4.45, 1.45)], -3.0, 3.0, "era", bevel=0.03)
    for i in range(7):
        p.box((-2.55 + i * 0.85, 0.12, -4.3), (0.3, 0.2, 0.25), "steel")
    for sx in (-1, 1):
        p.obox((sx * 1.6, 0.85, -3.8), (0, 0.3, 1), (1, 0, 0), 1.0, 0.24, 0.26, "dark", bevel=0.02)
    # small armored cab on the left front, a slit window
    p.prism_y([(-2.4, -3.0), (-0.6, -3.0), (-0.6, -1.3), (-2.4, -1.3)], 1.85, 2.85, "paint", bevel=0.04, top_scale=0.85)
    p.box((-1.5, 2.45, -2.97), (1.3, 0.16, 0.05), "light")
    p.box((-1.5, 2.86, -2.15), (1.0, 0.05, 1.0), "team", bevel=0.012)
    # hopper heaped with scrap, and the stack
    p.prism_y([(-2.3, 0.8), (0.2, 0.8), (0.2, 3.0), (-2.3, 3.0)], 1.9, 2.75, "dark", bevel=0.03, top_scale=1.08)
    for at, size, rot in (((-1.5, 2.85, 1.5), (0.9, 0.35, 0.7), (0.3, 0, 1)), ((-0.6, 2.9, 2.2), (0.7, 0.3, 0.6), (1, 0, 0.4)),
                          ((-1.2, 2.95, 2.5), (0.5, 0.4, 0.5), (0.6, 0, -1))):
        p.obox(at, rot, (0.2, 1, 0.1), size[0], size[2], size[1], "steel", bevel=0.02)
    p.cylinder("y", (-2.0, 3.0, 3.25), 0.2, 2.0, 8, "steel")
    p.cylinder("y", (-2.0, 4.02, 3.25), 0.26, 0.12, 8, "light")  # stack glow
    # engine deck grille, front lights (emissive)
    p.box((1.0, 1.92, 2.6), (1.4, 0.05, 1.2), "grille")
    for z in (2.25, 2.6, 2.95):  # engine-deck exhaust slots
        p.box((1.0, 1.95, z), (1.3, 0.04, 0.18), "light")
    for sx in (-1, 1):  # running strips along the flaps
        p.box((sx * (HULL_X + 0.12), 1.75, 0.0), (0.04, 0.1, 6.2), "light")
    for sx in (-1, 1):
        p.box((sx * 2.1, 1.6, -3.71), (0.5, 0.2, 0.07), "head")
        p.box((sx * 2.2, 1.55, 3.51), (0.42, 0.16, 0.06), "light")
    # team color on the hull top: a plate on the right rear
    p.box((1.95, 1.93, 2.5), (0.8, 0.05, 1.6), "team", bevel=0.012)
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


def build_nano(p):
    px, py, pz = NANO_PIVOT
    p.cylinder("y", (px, py + 0.15, pz), 0.85, 0.3, 12, "paint")
    p.cylinder("y", (px, py + 0.32, pz), 0.7, 0.05, 12, "team")
    p.cylinder("y", (px, py + 0.02, pz), 0.88, 0.08, 12, "power")  # turntable power ring
    # arm: a lattice-like boom of two rails rising forward, a piston under it
    base = lib.vec((px, py + 0.55, pz + 0.2))
    tip = lib.vec((px, py + 2.6, pz - 2.2))
    d = tip - base
    for dx in (-0.22, 0.22):
        p.obox(tuple((base + tip) / 2 + lib.Vector((dx, 0, 0))), tuple(d), (1, 0, 0), d.length, 0.22, 0.12, "dark", bevel=0.015)
    for t in (0.25, 0.5, 0.75):
        p.box(tuple(base + d * t), (0.5, 0.08, 0.08), "dark")
    a = lib.vec((px, py + 0.4, pz - 0.4))
    b = base + d * 0.5
    p.obox(tuple((a + b) / 2), tuple(b - a), (1, 0, 0), (b - a).length, 0.16, 0.16, "steel")
    # claw: a block with two jaws, the orange emitter between them
    p.box(tuple(tip), (0.7, 0.5, 0.6), "paint", bevel=0.03)
    for dx in (-0.25, 0.25):
        p.obox(tuple(tip + lib.Vector((dx, -0.45, -0.15))), (0, 1, 0.3), (1, 0, 0), 0.6, 0.18, 0.12, "steel")
    p.cylinder("y", tuple(tip + lib.Vector((0, -0.35, -0.05))), 0.24, 0.24, 10, "power")
    # hydraulic tank on the turntable's back
    p.cylinder("x", (px, py + 0.55, pz + 0.75), 0.25, 0.9, 8, "trim")


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
    bolts(p, (-2.6, 1.0, -4.3), (2.6, 1.0, -4.3), 7, (0, 0.2, -1))
    for z in (-1.0, 0.5, 1.4, 3.15):
        seam(p, (-2.55, 1.901, z), (2.55, 1.901, z), UP)
    for sx in (-1, 1):
        seam(p, (sx * 1.25, 1.901, 1.4), (sx * 1.25, 1.901, 3.15), UP)
        bolts(p, (sx * 2.6, 1.901, -1.9), (sx * 2.6, 1.901, 3.2), 6, UP)
        x = sx * (HULL_X + 0.1)
        bolts(p, (x, 1.62, -3.2), (x, 1.62, 3.1), 10, (sx, 0, 0))


def details_nano(p):
    px, py, pz = NANO_PIVOT
    ring(p, (px, py + 0.301, pz), UP, 0.78)


# ---------------------------------------------------------------------------


unit.run(
    __file__, UNIT, "chaos", footprint=FOOTPRINT,
        pieces=[
            unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
            unit.PieceSpec("nano", "base", NANO_PIVOT, build_nano, details_nano),
        ],
        scale=SCALE,
        previews=[
            ("35", (-14, 11, 17), (0, 1.5, -0.5), 50),
            ("side", (19, 3, -2.0), (0, 1.6, -2.0), 50),
            ("80", (0, 27, 4.8), (0, 1.5, 0), 50),
            ("close", (-5.8, 4.6, -7.0), (0, 2.1, -1.6), 35),
        ],
)
