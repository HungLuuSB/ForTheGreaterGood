"""Arbiter (Order mobile fire-control radar, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_arbiter/build.py

An armored 6 x 6 truck with a cab and an equipment shelter, carrying the
`dish` (the def's piece, turning on its bearing): a big flat fire-control
array tilted back 20°, unlit face with a glowing edge and a fine cell grid
(the Oracle rule), a team plate on its back (BAR style, M-15; Order reads
heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DISH = (0.0, 3.0, 2.2)
T = math.radians(20)
N = (0.0, math.sin(T), -math.cos(T))
V = (0.0, math.cos(T), math.sin(T))
C = (0.0, 4.8, 2.2)


def build_base(p):
    d = hulls.wheeled(p, "order", length=7.6, width=4.8, deck=2.2)
    p.prism_y([(-1.8, -3.7), (1.8, -3.7), (1.8, -2.1), (-1.8, -2.1)], d, d + 1.0, "paint", bevel=0.05, top_scale=0.88)
    p.box((0, d + 0.6, -3.72), (2.6, 0.3, 0.05), "glass")
    p.box((0, d + 0.3, -3.73), (2.8, 0.12, 0.04), "light")
    p.box((0, d + 0.6, -0.6), (3.6, 1.2, 2.0), "trim", bevel=0.04)  # shelter
    p.box((0, d + 1.23, -0.6), (2.8, 0.05, 1.4), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 1.81, d + 0.6, -0.6), (0.04, 0.2, 1.6), "light")
    p.cylinder("y", (0, d + 0.4, 2.2), 0.5, 0.8, 10, "steel")


def details_base(p):
    bolts(p, (-2.0, 2.201, 3.4), (2.0, 2.201, 3.4), 6, UP)


def at(a, b, n):
    return tuple(C[k] + (1, 0, 0)[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_dish(p):
    p.cylinder("y", (0, 3.15, 2.2), 0.45, 0.3, 10, "trim")
    p.obox(at(0, -0.9, -0.4), (1, 0, 0), N, 0.5, 1.4, 0.4, "steel")
    p.obox(C, (1, 0, 0), N, 4.2, 3.0, 0.4, "paint", bevel=0.04)
    p.obox(at(0, 0, 0.21), (1, 0, 0), N, 3.9, 2.7, 0.03, "dark")
    for b in (-1.3, 1.3):
        p.obox(at(0, b, 0.23), (1, 0, 0), N, 3.9, 0.08, 0.02, "light")
    for a in (-1.9, 1.9):
        p.obox(at(a, 0, 0.23), (1, 0, 0), N, 0.08, 2.5, 0.02, "light")
    for a in (-1.27, -0.63, 0.0, 0.63, 1.27):
        p.obox(at(a, 0, 0.23), (1, 0, 0), N, 0.04, 2.5, 0.02, "light")
    for b in (-0.43, 0.43):
        p.obox(at(0, b, 0.23), (1, 0, 0), N, 3.74, 0.04, 0.02, "light")
    p.obox(at(0, 0, -0.21), (1, 0, 0), N, 3.4, 2.2, 0.03, "team")


def no_details(p):
    pass


unit.run(__file__, "ord_arbiter", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH, build_dish, no_details)])
