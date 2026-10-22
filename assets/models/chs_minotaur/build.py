"""Minotaur (Chaos siege ram, T2 ground, footprint 2): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_minotaur/build.py

The biggest Chaos tank: low, wide and front-heavy, a slab hull on wide
tracks, the `ram` (the def's piece, the charge's muzzle) a demolition plate
wider than the tracks with its top leaning forward, three crusher blocks and
pointed tips; a flat low `turret` pushed forward with amber eye slits and a
team roof, and a short fat `barrel` (Chaos: rugged slab armor, a short
heavy gun). Pieces and pivots follow the blockout (rig.md 4; BAR style,
M-15; Chaos reads light, M-14: here the exception, a brute). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

RAM_PIVOT = (0.0, 1.5, -6.4)
TURRET_PIVOT = (0.0, 2.8, -0.6)
BARREL_PIVOT = (0.0, 2.8, -3.4)
T = math.radians(25)
RAM_N = (0.0, math.sin(T), math.cos(T))  # the plate's thickness axis, its top leaning forward
X = (1.0, 0.0, 0.0)
WHEELS = (-4.6, -2.8, -1.0, 0.8, 2.6, 4.4)


def build_base(p):
    p.prism_x([(-5.2, 0.5), (5.6, 0.5), (5.9, 1.0), (5.9, 1.6), (-6.0, 1.6)], -3.8, 3.8, "trim", bevel=0.04)
    p.prism_x([(-6.2, 1.3), (5.4, 1.3), (5.4, 2.3), (-2.6, 2.3), (-6.2, 1.6)], -3.8, 3.8, "paint", bevel=0.06)
    for sx in (-1, 1):
        p.box((sx * 2.7, 2.35, 2.2), (1.6, 0.06, 3.4), "team", bevel=0.012)
        p.box((sx * 3.83, 1.8, 1.4), (0.05, 0.22, 6.6), "light")
        p.box((sx * 2.9, 1.5, -6.05), (1.0, 0.3, 0.12), "head")
    for z in (3.9, 4.4, 4.9):  # exhaust slots at the back
        p.box((0, 2.33, z), (3.6, 0.04, 0.32), "light")
    p.box((0, 1.6, 5.45), (3.0, 0.4, 0.05), "light")  # rear exhaust
    # rear cage
    p.box((0, 2.1, 5.7), (7.4, 0.15, 0.15), "dark")
    for x in (-2.4, 0.0, 2.4):
        p.box((x, 1.5, 5.7), (0.12, 1.2, 0.12), "dark")
    # wide tracks with slab guards
    outline = [(-5.6, 0.0), (5.6, 0.0)]
    outline += lib.outline_circle(5.6, 0.6, 0.6, -90, 90, 8)[1:]
    outline += [(-5.8, 1.4)]
    outline += lib.outline_circle(-5.8, 0.75, 0.6, 90, 230, 5)[1:]
    inner = lib.offset_polygon(outline, 0.12)
    for sx in (-1, 1):
        x0, x1 = (3.8, 5.4) if sx > 0 else (-5.4, -3.8)
        p.band_x(outline, inner, x0, x1, "track")
        for z in WHEELS:
            p.cylinder("x", (sx * 4.6, 0.55, z), 0.5, 0.5, 12, "rubber", cap_kinds=("trim", "trim"))
        p.box((sx * 4.6, 1.85, 0.5), (1.9, 0.25, 9.0), "paint", bevel=0.04)
        p.box((sx * 5.57, 1.85, 0.5), (0.05, 0.16, 8.0), "light")  # guard edge lights


def details_base(p):
    bolts(p, (-3.5, 2.301, -1.0), (3.5, 2.301, -1.0), 10, UP)


def ram_at(x, up, out=0.0):
    c = (0.0, 1.5, -6.9)
    v = (0.0, math.cos(T), -math.sin(T))
    return tuple(c[k] + X[k] * x + v[k] * up + RAM_N[k] * out for k in range(3))


def build_ram(p):
    p.obox(ram_at(0, 0), X, RAM_N, 11.8, 2.4, 0.8, "steel", bevel=0.06)
    for x in (-3.6, 0.0, 3.6):  # crusher blocks on its face
        p.obox(ram_at(x, 0.1, -0.55), X, RAM_N, 2.2, 1.0, 0.5, "dark", bevel=0.04)
    for sx in (-1, 1):  # pointed tips
        p.obox(ram_at(sx * 5.6, 0, -0.3), X, RAM_N, 0.8, 2.4, 1.2, "dark", bevel=0.04)
        p.box((sx * 2.0, 1.4, -5.6), (0.5, 0.5, 1.6), "trim")  # arms back to the hull
    p.obox(ram_at(0, 1.05, -0.42), X, RAM_N, 9.0, 0.16, 0.04, "light")  # top edge strip


def build_turret(p):
    p.prism_y([(-2.5, -2.0), (2.5, -2.0), (2.5, 1.4), (-2.5, 1.4)], 2.3, 3.3, "paint", bevel=0.05, top_scale=0.94)
    p.prism_x([(-3.8, 2.3), (-2.0, 2.3), (-2.0, 3.3), (-2.6, 3.3)], -2.5, 2.5, "paint", bevel=0.04)
    p.box((0, 3.33, -0.4), (3.4, 0.06, 2.8), "team", bevel=0.015)
    for sx in (-1, 1):
        p.obox((sx * 1.4, 3.0, -3.42), X, (0, 0.55, -0.83), 1.2, 0.3, 0.04, "light")  # eye slits
    p.box((1.6, 3.5, 0.6), (0.6, 0.4, 0.6), "trim")
    for sx in (-1, 1):
        p.box((sx * 2.52, 2.85, -0.3), (0.05, 0.26, 3.2), "light")


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.cylinder("z", (0, y, -4.4), 0.75, 2.6, 14, "paint")
    p.cylinder("z", (0, y, -5.7), 0.95, 0.4, 14, "dark", cap_kinds=("dark", "dark"))
    p.cylinder("z", (0, y, -5.92), 0.55, 0.04, 12, "dark")
    p.cylinder("z", (0, y, -5.1), 0.78, 0.14, 14, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_minotaur", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("ram", "base", RAM_PIVOT, build_ram, no_details),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL_PIVOT, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, 2.8, -5.95]}},
         team_pieces=["base", "turret"])
