"""Stalker (Chaos mobile fire-control radar, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_stalker/build.py

A light 6 x 6 truck with a cab and a lattice mast, carrying the `dish`
(the def's piece, turning on the mast top): a smaller flat array tilted
back 15°, never a dish, unlit face with an amber edge and three cell lines,
a counterweight and a team stripe on its back (BAR style, M-15; Chaos reads
light and open, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DISH = (-0.4, 5.6, 2.2)
T = math.radians(15)
N = (0.0, math.sin(T), -math.cos(T))
V = (0.0, math.cos(T), math.sin(T))
C = (-0.4, 6.3, 2.2)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    d = hulls.wheeled(p, "chaos", length=7.2, width=4.2, deck=2.2)
    p.box((0, d + 0.55, -2.7), (3.6, 1.1, 1.6), "paint", bevel=0.04)
    p.box((0, d + 0.75, -3.54), (2.8, 0.22, 0.05), "light")
    p.box((0, d + 1.12, -2.7), (2.6, 0.05, 1.0), "team", bevel=0.01)
    for dx in (-0.5, 0.5):  # lattice mast
        for dz in (-0.5, 0.5):
            beam(p, (-0.4 + dx * 1.6, d, 2.2 + dz * 1.6), (-0.4 + dx * 0.5, 5.5, 2.2 + dz * 0.5), 0.16, "paint")
    for y in (3.4, 4.6):
        f = 1.6 - 1.1 * (y - d) / (5.5 - d)
        for a, b in (((-0.5, -0.5), (0.5, -0.5)), ((0.5, -0.5), (0.5, 0.5)), ((0.5, 0.5), (-0.5, 0.5)), ((-0.5, 0.5), (-0.5, -0.5))):
            beam(p, (-0.4 + a[0] * f, y, 2.2 + a[1] * f), (-0.4 + b[0] * f, y, 2.2 + b[1] * f), 0.08, "steel")
    p.box((0.9, d + 0.4, 0.2), (1.6, 0.8, 1.2), "trim")  # power unit
    p.box((0.9, d + 0.4, -0.41), (1.2, 0.24, 0.04), "light")


def details_base(p):
    bolts(p, (-1.7, 2.201, 3.3), (1.7, 2.201, 3.3), 6, UP)


def at(a, b, n):
    return tuple(C[k] + (1, 0, 0)[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_dish(p):
    p.cylinder("y", (-0.4, 5.7, 2.2), 0.35, 0.3, 8, "trim")
    p.obox(C, (1, 0, 0), N, 2.8, 1.8, 0.25, "paint", bevel=0.03)
    p.obox(at(0, 0, 0.14), (1, 0, 0), N, 2.5, 1.5, 0.03, "dark")
    for b in (-0.73, 0.73):
        p.obox(at(0, b, 0.16), (1, 0, 0), N, 2.5, 0.08, 0.02, "light")
    for a in (-1.23, -0.41, 0.41, 1.23):
        p.obox(at(a, 0, 0.16), (1, 0, 0), N, 0.06 if abs(a) > 1 else 0.04, 1.4, 0.02, "light")
    p.obox(at(0, 0.5, -0.14), (1, 0, 0), N, 2.2, 0.3, 0.03, "team")
    p.obox(at(1.6, -0.6, -0.3), (1, 0, 0), N, 0.6, 0.5, 0.4, "trim", bevel=0.03)


def no_details(p):
    pass


unit.run(__file__, "chs_stalker", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH, build_dish, no_details)])
