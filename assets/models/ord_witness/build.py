"""Witness (Order pinpointer radar, T2 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_witness/build.py

New mesh at the size scale (S-104, M-26: footprint 2, 16 x 16 studs, about
10 tall), from its blockout. Pieces: `base` and the def's `dish` (turn Y,
tools/animate.py; a flat phased array, never a dish). Big shapes first: a
chamfered slab, a wedge-shaped armored block with sloped glacis plates front
and back, a large team roof plate and team plates on the glacis, cooling fin
banks with lit grilles on the flanks, a lit sensor slit and hazard striping
at the front, a grilled vent block and two sensor cupolas with lit lenses on
the roof, a turret ring and an armored mast, aerials and corner lights. The
`dish`: a precision array tilted back 20 degrees on a yoke, its face unlit
with a glowing edge and a fine grid (style guide, "Sensor faces"), two
flanking targeting pods with lit lenses, a framed back with a large team
plate and a finned equipment box. Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

DISH_PIVOT = (0.0, 5.0, -1.0)
TILT = math.radians(20)
N = (0.0, math.sin(TILT), -math.cos(TILT))  # array face: forward and up
VV = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 7.0, -1.0)
PW, PH = 7.4, 3.8
BX = 5.4  # block half width
ROOF = 2.9


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.6, "trim", bevel=0.1, top_scale=0.985)
    # the wedge-shaped block: upright sides, sloped glacis front and back
    prof = [(-7.0, 0.6), (7.0, 0.6), (7.0, 1.2), (5.0, ROOF), (-5.0, ROOF), (-7.0, 1.2)]
    p.prism_x(prof, -BX, BX, "paint", bevel=0.16)
    p.box((0, ROOF + 0.03, 1.9), (8.6, 0.06, 5.4), "team", bevel=0.02)
    k = math.atan2(ROOF - 1.2, 2.0)
    for sz in (-1, 1):  # team plates on the glacis
        n = (0.0, math.cos(k), sz * math.sin(k))
        c = (0.0, (ROOF + 1.2) / 2 + n[1] * 0.03, sz * 6.0 + n[2] * 0.03)
        p.obox(c, (1, 0, 0), n, 7.6, 1.9, 0.05, "team", bevel=0.015)
    # lit sensor slit and hazard striping at the front
    p.box((0, 1.0, -7.03), (6.0, 0.14, 0.05), "light")
    hazard(p, (0, 0.62, -7.45), (1, 0, 0), UP, 6.4, 0.5, stripes=12)
    # cooling fin banks with lit grilles on the flanks
    for sx in (-1, 1):
        x = sx * (BX + 0.55)
        p.box((x, 1.65, 0), (1.1, 2.1, 6.4), "trim", bevel=0.08)
        for i in range(7):
            p.box((x + sx * 0.57, 1.65, -2.7 + i * 0.9), (0.12, 1.8, 0.22), "grille")
        p.box((x, 2.74, 0), (0.22, 0.06, 5.0), "light")
    # turret ring and the armored mast
    p.cylinder("y", (0, ROOF + 0.25, -1.0), 2.0, 0.5, 20, "trim", bevel=0.05)
    p.cylinder("y", (0, ROOF + 0.52, -1.0), 1.75, 0.06, 20, "dark")
    p.ocyl((0, ROOF + 0.55, -1.0), UP, 1.1, 1.5, 12, "paint", radius2=0.85)
    p.cylinder("y", (0, 4.45, -1.0), 1.15, 0.12, 12, "light")
    p.cylinder("y", (0, 4.75, -1.0), 0.95, 0.5, 14, "steel")
    # a grilled vent block and two sensor cupolas with lit lenses on the roof front
    p.box((0, ROOF + 0.18, -4.1), (3.4, 0.36, 1.1), "trim", bevel=0.05)
    p.box((0, ROOF + 0.37, -4.1), (3.0, 0.04, 0.8), "grille")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 3.7, ROOF + 0.35, -3.6), 0.75, 0.7, 8, "paint", bevel=0.04)
        p.ocyl((sx * 3.7, ROOF + 0.7, -3.6), UP, 0.75, 0.3, 8, "trim", radius2=0.45)
        p.box((sx * 3.7, ROOF + 0.4, -4.33), (0.6, 0.18, 0.05), "light")
    # aerials at the back corners, corner lights
    for sx in (-1, 1):
        p.box((sx * 4.7, ROOF + 0.25, 4.4), (0.6, 0.5, 0.6), "trim")
        p.cylinder("y", (sx * 4.7, ROOF + 1.6, 4.4), 0.06, 2.2, 6, "steel")
        p.box((sx * 4.7, ROOF + 2.75, 4.4), (0.2, 0.14, 0.2), "light")
        for sz in (-1, 1):
            p.box((sx * 6.6, 0.66, sz * 6.6), (0.4, 0.1, 0.4), "light")
    cable(p, [(-3.6, ROOF + 0.1, 3.4), (-1.6, ROOF + 0.4, 1.0), (-0.9, ROOF + 0.9, -0.2)], r=0.1, kind="steel")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * BX, 1.0, -4.6), (sx * BX, 1.0, 4.6), 9, (sx, 0, 0))
        seam(p, (sx * BX, 2.2, -4.0), (sx * BX, 2.2, 4.0), (sx, 0, 0))
    ring(p, (0, ROOF + 0.501, -1.0), UP, 1.5)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + VV[k] * b + N[k] * n for k in range(3))


def build_dish(p):
    p.cylinder("y", (0, 5.3, -1.0), 0.75, 0.6, 14, "trim", bevel=0.03)
    p.obox((0, 5.7, -0.8), U, (0, 0, 1), 3.4, 0.4, 1.0, "paint", bevel=0.04)
    for sx in (-1, 1):  # yoke arms up to the array's back
        p.obox(at(sx * 1.5, -0.9, -0.55), U, N, 0.42, 1.9, 0.42, "steel")
    p.obox(PANEL, U, N, PW, PH, 0.45, "paint", bevel=0.05)
    p.obox(at(0, 0, 0.23), U, N, PW - 0.5, PH - 0.45, 0.03, "dark")
    hw, hh = (PW - 0.5) / 2, (PH - 0.45) / 2
    for b in (-hh + 0.05, hh - 0.05):  # glowing edge
        p.obox(at(0, b, 0.25), U, N, PW - 0.5, 0.09, 0.02, "light")
    for a in (-hw + 0.05, hw - 0.05):
        p.obox(at(a, 0, 0.25), U, N, 0.09, PH - 0.55, 0.02, "light")
    for i in range(1, 10):  # fine grid
        p.obox(at(-hw + i * (2 * hw / 10), 0, 0.25), U, N, 0.035, PH - 0.55, 0.02, "light")
    for b in (-hh / 2, 0.0, hh / 2):
        p.obox(at(0, b, 0.25), U, N, PW - 0.6, 0.035, 0.02, "light")
    # flanking targeting pods with lit lenses
    for sx in (-1, 1):
        a = sx * (PW / 2 + 0.55)
        p.obox(at(sx * (PW / 2 + 0.15), 0, 0), U, N, 0.4, 1.0, 0.4, "trim")
        p.ocyl(at(a, 0, -0.6), N, 0.5, 1.2, 12, "paint")
        p.ocyl(at(a, 0, 0.6), N, 0.38, 0.06, 12, "light")
    # framed back: a large team plate, ribs, a finned equipment box
    p.obox(at(0, 0.3, -0.24), U, N, PW - 1.2, PH - 1.4, 0.03, "team")
    for a in (-3.3, 3.3):
        p.obox(at(a, 0, -0.33), U, N, 0.3, PH - 0.2, 0.22, "trim")
    p.obox(at(0, -1.1, -0.65), U, N, 2.4, 1.0, 0.6, "trim", bevel=0.05)
    for i in range(5):
        p.obox(at(-0.8 + i * 0.4, -1.1, -1.0), U, N, 0.06, 0.9, 0.14, "steel")


def details_dish(p):
    for b in (-PH / 2 + 0.1, PH / 2 - 0.1):
        bolts(p, at(-PW / 2 + 0.2, b, 0.23), at(PW / 2 - 0.2, b, 0.23), 12, N)


unit.run(__file__, "ord_witness", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH_PIVOT, build_dish, details_dish)],
         budget=6000,
         previews=[("35", (-24, 19, -28), (0, 3.5, 0), 50),
                   ("80", (0, 40, 7), (0, 3, 0), 50),
                   ("close", (-12, 10, -14), (0, 5.0, 0), 40)])
