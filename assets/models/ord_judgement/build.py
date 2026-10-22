"""Judgement (Order MLRS, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_judgement/build.py

A tracked launcher: a skirted hull with a forward cab, a turntable
`turret` and on it the `launcher` (pitches about its rear trunnion, the
weapon's piece), a closed armored box of 3 x 2 rocket cells, each cell's
cap with a ready light (weapon channel), team plates on the box sides and
the cab roof (BAR style, M-15; Order reads heavy, M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

TURRET = (0.0, 2.45, 1.4)
LAUNCHER = (0.0, 2.9, 3.2)
T = math.radians(25)
N = (0.0, math.sin(T), -math.cos(T))  # the box's forward axis, pitched up
V = (0.0, math.cos(T), math.sin(T))


def build_base(p):
    d = hulls.tracked(p, "order", length=8.0, width=5.6, deck=2.0)
    p.prism_y([(-1.8, -3.9), (1.8, -3.9), (1.8, -2.2), (-1.8, -2.2)], d, d + 1.0, "paint", bevel=0.05, top_scale=0.86)
    p.box((0, d + 0.6, -3.92), (2.4, 0.3, 0.05), "glass")
    p.box((0, d + 1.03, -3.0), (2.4, 0.05, 1.2), "team", bevel=0.012)


def details_base(p):
    bolts(p, (-2.4, 2.001, 3.3), (2.4, 2.001, 3.3), 8, UP)


def build_turret(p):
    p.cylinder("y", (0, 2.45, 1.4), 1.8, 0.5, 16, "trim")
    for sx in (-1, 1):
        p.box((sx * 1.2, 2.95, 2.9), (0.4, 0.7, 0.8), "steel")  # trunnion cheeks
    p.cylinder("y", (0, 2.72, 1.4), 1.82, 0.12, 16, "light", cap_kinds=("trim", "trim"))


def at(a, b, n):
    c = (0.0, 3.95, 1.0)
    return tuple(c[k] + (1, 0, 0)[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_launcher(p):
    p.obox(at(0, 0, 0), (1, 0, 0), N, 4.2, 1.8, 4.6, "paint", bevel=0.06)
    for sx in (-1, 1):
        p.obox(at(sx * 2.12, 0, 0), (1, 0, 0), N, 0.04, 1.2, 3.4, "team")
        p.obox(at(sx * 2.12, 0.72, 0), (1, 0, 0), N, 0.04, 0.24, 3.8, "light")
        p.obox(at(sx * 1.6, 0.91, 0), (1, 0, 0), N, 0.36, 0.03, 3.8, "light")  # box top edge strips
    p.obox(at(0, 0, 2.31), (1, 0, 0), N, 3.9, 1.5, 0.03, "dark")  # front face
    for a in (-1.3, 0.0, 1.3):
        for b in (-0.38, 0.38):
            p.obox(at(a, b, 2.33), (1, 0, 0), N, 1.1, 0.6, 0.03, "steel")
            p.obox(at(a, b, 2.35), (1, 0, 0), N, 0.3, 0.2, 0.02, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_judgement", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("launcher", "turret", LAUNCHER, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [0, 4.0, -1.4]}})
