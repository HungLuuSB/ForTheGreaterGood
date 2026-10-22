"""Seraph (Order mobile radar SAM, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_seraph/build.py

A 6 x 6 armored truck: up front on a short mast the `turret` (the def's
piece) carrying a tilted search array (unlit face, glowing edge, as the
Oracle), behind it the `launcher` (turned by the weapon) with three closed
radar SAM canisters, white radome caps and ready lights (weapon channel),
team plates on the flanks and the launcher (BAR style, M-15; Order reads
heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

TURRET = (0.0, 2.4, -0.8)
LAUNCHER = (0.0, 2.4, 2.3)
T = math.radians(15)
N = (0.0, math.sin(T), -math.cos(T))
V = (0.0, math.cos(T), math.sin(T))


def build_base(p):
    d = hulls.wheeled(p, "order", length=7.6, width=4.8, deck=2.2)
    p.prism_y([(-1.6, -3.6), (1.6, -3.6), (1.6, -2.0), (-1.6, -2.0)], d, d + 0.9, "paint", bevel=0.05, top_scale=0.88)
    p.box((0, d + 0.55, -3.62), (2.4, 0.3, 0.05), "glass")
    p.box((0, d + 0.25, -3.63), (2.6, 0.12, 0.04), "light")  # cab light bar
    for sx in (-1, 1):
        p.box((sx * 1.62, d + 0.5, -2.8), (0.04, 0.2, 1.4), "light")


def details_base(p):
    bolts(p, (-1.9, 2.201, 3.5), (1.9, 2.201, 3.5), 6, UP)


def at(c, a, b, n=0.0):
    return tuple(c[k] + (1, 0, 0)[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_turret(p):
    p.cylinder("y", (0, 3.1, -0.8), 0.25, 1.6, 8, "steel")
    c = (0.0, 4.8, -0.8)
    p.obox(c, (1, 0, 0), N, 3.0, 1.8, 0.3, "paint", bevel=0.03)
    p.obox(at(c, 0, 0, 0.16), (1, 0, 0), N, 2.7, 1.5, 0.03, "dark")
    for b in (-0.75, 0.75):
        p.obox(at(c, 0, b, 0.18), (1, 0, 0), N, 2.7, 0.08, 0.02, "light")
    for a in (-1.35, 1.35):
        p.obox(at(c, a, 0, 0.18), (1, 0, 0), N, 0.08, 1.5, 0.02, "light")
    for a in (-0.45, 0.45):
        p.obox(at(c, a, 0, 0.18), (1, 0, 0), N, 0.04, 1.5, 0.02, "light")
    p.obox(at(c, 0, 0, -0.17), (1, 0, 0), N, 2.4, 1.2, 0.03, "team")


def build_launcher(p):
    p.box((0, 2.65, 2.3), (3.4, 0.5, 3.0), "trim", bevel=0.04)
    t = math.radians(40)
    n = (0, math.sin(t), -math.cos(t))
    for x in (-1.05, 0.0, 1.05):
        c = (x, 4.0, 1.3)
        p.obox(c, (1, 0, 0), n, 0.9, 0.9, 3.2, "paint", bevel=0.04)
        tip = tuple(c[k] + n[k] * 1.62 for k in range(3))
        p.ocyl(tip, n, 0.38, 0.06, 10, "radome")
        p.ocyl(tuple(tip[k] + n[k] * 0.07 for k in range(3)), n, 0.14, 0.02, 8, "weapon")
    p.box((0, 2.92, 3.4), (2.6, 0.05, 0.8), "team")
    for sx in (-1, 1):
        p.box((sx * 1.71, 2.65, 2.3), (0.04, 0.16, 2.4), "light")


def no_details(p):
    pass


unit.run(__file__, "ord_seraph", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("launcher", "base", LAUNCHER, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [0, 5.2, 0.3]}})
