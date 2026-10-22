"""Gorgon (Chaos mobile radar SAM, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_gorgon/build.py

A light 6 x 6 truck: up front a thin lattice mast, the `turret` (the def's
piece), with a small panel radar on top (unlit face, amber edge) and a beacon; behind
the cab the `launcher` (turned by the weapon), an open rail frame with four
bare radar SAMs, white radomes and amber ready lights (weapon channel), a
team plate on the frame (BAR style, M-15; Chaos reads light and open,
M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

TURRET = (-1.4, 2.2, -1.2)
LAUNCHER = (0.3, 2.2, 2.2)


def build_base(p):
    d = hulls.wheeled(p, "chaos", length=7.4, width=4.4, deck=2.0)
    p.box((0, d + 0.45, -2.6), (2.6, 0.9, 1.6), "paint", bevel=0.04)  # cab
    p.box((0, d + 0.6, -3.41), (1.8, 0.2, 0.04), "light")


def details_base(p):
    bolts(p, (-1.7, 2.001, 3.3), (1.7, 2.001, 3.3), 6, UP)


def build_turret(p):
    x, y, z = TURRET
    p.box((x, 3.8, z), (0.3, 3.2, 0.3), "trim")
    for k in range(3):
        p.box((x, 2.8 + k * 0.9, z), (0.6, 0.06, 0.06), "steel")
    t = math.radians(15)
    n = (0, math.sin(t), -math.cos(t))
    c = (x, 5.8, z)
    p.obox(c, (1, 0, 0), n, 1.6, 1.0, 0.2, "paint", bevel=0.02)
    p.obox(tuple(c[k] + n[k] * 0.11 for k in range(3)), (1, 0, 0), n, 1.44, 0.84, 0.02, "dark")
    v = (0, math.cos(t), math.sin(t))
    for b in (-0.42, 0.42):  # glowing edge only (style guide, "Sensor faces")
        p.obox(tuple(c[k] + n[k] * 0.12 + v[k] * b for k in range(3)), (1, 0, 0), n, 1.44, 0.07, 0.02, "light")
    for a in (-0.69, 0.69):
        p.obox((c[0] + a, c[1] + n[1] * 0.12, c[2] + n[2] * 0.12), (1, 0, 0), n, 0.07, 0.84, 0.02, "light")
    p.box((x, 6.5, z), (0.24, 0.2, 0.24), "light")


def build_launcher(p):
    x, y, z = LAUNCHER
    p.box((x, 2.35, z), (2.8, 0.3, 2.6), "trim")
    t = math.radians(45)
    n = (0, math.sin(t), -math.cos(t))
    p.obox((x, 3.4, z - 0.6), (1, 0, 0), n, 2.8, 0.15, 2.6, "steel")  # rail frame
    for i, dx in enumerate((-0.95, -0.32, 0.32, 0.95)):
        c = (x + dx, 3.8, z - 0.9)
        p.ocyl(tuple(c[k] - n[k] * 1.4 for k in range(3)), n, 0.2, 2.6, 8, "paint")
        tip = tuple(c[k] + n[k] * 1.2 for k in range(3))
        p.ocyl(tip, n, 0.2, 0.35, 8, "radome", radius2=0.04)
        p.ocyl(tuple(c[k] - n[k] * 1.45 for k in range(3)), tuple(-v for v in n), 0.15, 0.03, 8, "weapon")
    p.box((x, 2.52, z + 0.8), (2.0, 0.05, 0.8), "team")
    p.box((x - 1.42, 2.35, z), (0.04, 0.16, 2.2), "light")


def no_details(p):
    pass


unit.run(__file__, "chs_gorgon", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("launcher", "base", LAUNCHER, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [0.3, 5.4, -0.3]}})
