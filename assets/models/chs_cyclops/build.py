"""Cyclops (Chaos siege mortar, T2, footprint 2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_cyclops/build.py

Tall, to differ from the low wide Minotaur as a black shape: a narrow
tracked hull with a recoil spade and a slat cage at the back, an open
casemate `turret` carrying one huge mortar tube fixed near-vertical (75°)
with a lit band at its mouth (weapon channel), and the big amber sensor
eye on a raised mast beside it. The weapon pitches -5° to 60° from a level
rest, so the `barrel` is the short elevating cradle at the tube's foot and
the muzzle sits at the tube's mouth on the turret (M-19). (BAR style, M-15;
Chaos reads light, M-14.) Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402

TURRET = (0.0, 2.6, 1.0)
BARREL = (0.0, 4.3, 1.0)
T = math.radians(75)
AX = (0.0, math.sin(T), -math.cos(T))  # tube axis, leaning forward


def build_base(p):
    hulls.tracked(p, "chaos", length=10.0, width=6.0, deck=2.6)
    p.prism_x([(5.0, 0.3), (5.6, 0.3), (5.2, 2.2), (4.8, 2.2)], -2.6, 2.6, "steel", bevel=0.03)  # recoil spade
    p.box((0, 2.0, 5.55), (4.6, 0.12, 0.05), "light")


def no_details(p):
    pass


def build_turret(p):
    p.prism_y([(-2.3, -1.3), (2.3, -1.3), (2.3, 3.3), (-2.3, 3.3)], 2.6, 4.0, "paint", bevel=0.05, top_scale=0.92)
    p.box((0, 4.03, 2.4), (3.2, 0.05, 1.4), "team")
    # the tube, fixed: from the cradle up to the mouth (10.45 up)
    base = (0.0, 4.4, 1.0)
    L = 6.4
    p.ocyl(base, AX, 0.95, L, 14, "trim")
    mouth = tuple(base[k] + AX[k] * L for k in range(3))
    p.ocyl(tuple(mouth[k] - AX[k] * 0.6 for k in range(3)), AX, 1.05, 0.5, 14, "dark")
    p.ocyl(tuple(mouth[k] - AX[k] * 1.1 for k in range(3)), AX, 0.98, 0.16, 14, "weapon")
    for k in (1.8, 3.6):
        p.ocyl(tuple(base[j] + AX[j] * k for j in range(3)), AX, 1.0, 0.18, 14, "steel")
    # sensor eye on a mast
    p.box((2.0, 6.2, 2.4), (0.3, 4.4, 0.3), "steel")
    p.ocyl((2.0, 8.5, 2.0), (0, 0, -1), 0.6, 0.6, 12, "dark")
    p.ocyl((2.0, 8.5, 1.4), (0, 0, -1), 0.45, 0.06, 12, "light")
    for sx in (-1, 1):
        p.box((sx * 2.31, 3.3, 1.0), (0.04, 0.3, 4.2), "light")


def build_barrel(p):
    p.box((0, 4.3, 1.0), (2.6, 1.0, 1.6), "steel", bevel=0.04)
    for sx in (-1, 1):
        p.cylinder("x", (sx * 1.4, 4.3, 1.0), 0.4, 0.3, 10, "trim")


unit.run(__file__, "chs_cyclops", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, no_details),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, 10.45, -0.85]}})
