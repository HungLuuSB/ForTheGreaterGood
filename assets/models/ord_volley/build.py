"""Volley (Order hover rocket artillery, T1; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_volley/build.py

A rocket barge: the hover hull kit with a low cab forward, and on a
turntable (`turret`; the def has no pitch piece) a raked launcher rack of
3 x 4 tubes with glowing caps (weapon channel), team side plates and a
blast deflector behind it; BAR style, M-15; Order, M-14. Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import math  # noqa: E402

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.6
TURRET = (0.0, DECK, 0.6)
RAKE = math.radians(30)
FWD = (0.0, math.sin(RAKE), -math.cos(RAKE))  # the tubes' axis, raked up
RACK = (0.0, DECK + 1.35, 0.4)


def build_base(p):
    d = hulls.hover(p, "order", length=7.0, width=4.8, deck=DECK, fans=2)
    p.prism_y([(-1.4, -2.6), (1.4, -2.6), (1.4, -1.6), (-1.4, -1.6)], d, d + 0.6, "paint", bevel=0.04,
              top_scale=0.85)  # cab
    p.box((0, d + 0.4, -2.62), (2.2, 0.25, 0.05), "glass")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -1.2), (1.6, DECK + 0.001, -1.2), 5, UP)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.15, z), 1.1, 0.3, 14, "trim", cap_kinds=("dark", "paint"))
    for sx in (-1, 1):  # launcher arms
        p.box((sx * 1.15, y + 0.75, z), (0.2, 1.0, 0.8), "paint", bevel=0.03)
    rx, ry, rz = RACK
    up = (0.0, math.cos(RAKE), math.sin(RAKE))
    p.obox((rx, ry, rz), (1, 0, 0), up, 2.1, 2.2, 1.3, "paint", bevel=0.05)  # rack box: 2.2 along the tubes
    for sx in (-1, 1):
        p.obox((rx + sx * 1.06, ry, rz), (0, 0, 1), (sx, 0, 0), 1.6, 0.9, 0.04, "team")
    for r in range(3):
        for c in range(4):
            off_x = -0.72 + c * 0.48
            off_u = -0.4 + r * 0.4
            cx = rx + off_x
            cy = ry + up[1] * off_u + FWD[1] * 1.1
            cz = rz + up[2] * off_u + FWD[2] * 1.1
            p.ocyl((cx, cy, cz), FWD, 0.17, 0.04, 8, "dark")
            p.ocyl((cx + FWD[0] * 0.03, cy + FWD[1] * 0.03, cz + FWD[2] * 0.03), FWD, 0.12, 0.03, 8, "weapon")
    p.obox((rx, ry - 0.55, rz + 1.5), (1, 0, 0), (0, 0.4, 1), 1.8, 0.6, 0.06, "steel")  # blast deflector


def no_details(p):
    pass


unit.run(__file__, "ord_volley", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret",
                                 "at": [0, RACK[1] + FWD[1] * 1.25, RACK[2] + FWD[2] * 1.25]}})
