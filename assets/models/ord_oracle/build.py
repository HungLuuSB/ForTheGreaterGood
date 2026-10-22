"""Oracle (Order mobile radar, T1, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_oracle/build.py

An armored 6 x 6 with a cab and a shelter box at the back carrying the
`dish`: a big flat phased-array panel (a panel, never a dish, M-15 style
rule) tilted back 20° on a turning mast: an unlit face with a glowing edge
and a thin glowing cell grid.
Team plates on the panel's back, the cab roof and the flanks (BAR style,
M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam, wheel  # noqa: E402

DISH_PIVOT = (0.0, 4.4, 1.6)
TILT = math.radians(20)
N = (0.0, math.sin(TILT), -math.cos(TILT))  # array face: forward and up
U = (1.0, 0.0, 0.0)
WHEELS_Z = (-2.6, 0.2, 2.8)


def build_base(p):
    p.prism_x([(-4.5, 1.2), (-3.3, 0.8), (3.7, 0.8), (3.7, 2.2), (-2.8, 2.2), (-4.5, 1.6)], -2.0, 2.0, "paint", bevel=0.05)
    for sx in (-1, 1):
        x0, x1 = (2.0, 2.35) if sx > 0 else (-2.35, -2.0)
        p.prism_x([(-3.5, 1.25), (3.5, 1.25), (3.5, 1.9), (-3.5, 1.9)], x0, x1, "paint", bevel=0.03)
        p.box((sx * 2.37, 1.6, 0.0), (0.05, 0.32, 3.4), "team", bevel=0.01)
    p.prism_y([(-1.8, -2.8), (1.8, -2.8), (1.8, -1.4), (-1.8, -1.4)], 2.2, 3.1, "paint", bevel=0.04, top_scale=0.86)
    p.box((0, 2.7, -2.82), (3.0, 0.3, 0.05), "glass")
    p.box((0, 3.12, -2.1), (2.4, 0.05, 0.9), "team", bevel=0.012)
    p.box((0, 2.8, 1.6), (3.4, 1.2, 2.8), "trim", bevel=0.05)
    p.box((0, 2.8, 3.02), (2.4, 0.8, 0.05), "grille")
    p.cylinder("y", (0, 3.6, 1.6), 0.35, 0.8, 10, "steel")
    for sx in (-1, 1):
        p.box((sx * 1.4, 1.35, -4.48), (0.6, 0.2, 0.08), "head")
        for z in WHEELS_Z:
            wheel(p, sx * 2.2, 0.75, z, 0.75, 0.6, name=f"wheel{'L' if sx < 0 else 'R'}{WHEELS_Z.index(z) + 1}")


def build_dish(p):
    c = (0.0, 5.4, 1.6)
    p.cylinder("y", (0, 4.25, 1.6), 0.45, 0.3, 10, "trim")
    p.obox((0, 4.75, 1.75), (0, 1, 0.3), (1, 0, 0), 1.0, 0.3, 0.3, "dark")
    p.obox(c, U, N, 4.6, 2.2, 0.3, "paint", bevel=0.04)
    # the array face is unlit; only its edge and a thin cell grid glow
    # (review 2026-10-22: the all-glowing face outshone everything)
    face = tuple(c[i] + N[i] * 0.17 for i in range(3))
    p.obox(face, U, N, 4.2, 1.9, 0.03, "dark")
    v = (0.0, math.cos(TILT), math.sin(TILT))

    def at(a, b):
        return tuple(c[k] + N[k] * 0.195 + U[k] * a + v[k] * b for k in range(3))

    for b in (-0.91, 0.91):  # edge, top and bottom
        p.obox(at(0, b), U, N, 4.2, 0.08, 0.02, "light")
    for a in (-2.06, 2.06):  # edge, sides
        p.obox(at(a, 0), U, N, 0.08, 1.74, 0.02, "light")
    for i in range(1, 6):  # grid columns
        p.obox(at(-2.1 + i * 0.7, 0), U, N, 0.04, 1.74, 0.02, "light")
    for b in (-0.32, 0.32):  # grid rows
        p.obox(at(0, b), U, N, 4.04, 0.04, 0.02, "light")
    back = tuple(c[i] - N[i] * 0.17 for i in range(3))
    p.obox(back, U, N, 3.6, 1.5, 0.03, "team")


def details_base(p):
    seam(p, (-1.9, 2.201, 0.0), (1.9, 2.201, 0.0), UP)
    bolts(p, (-1.6, 3.401, 0.4), (1.6, 3.401, 0.4), 6, UP)


def details_dish(p):
    pass


unit.run(__file__, "ord_oracle", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH_PIVOT, build_dish, details_dish)])
