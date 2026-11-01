"""Halcyon (Order hover anti-air, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_halcyon/build.py

An air-defence hovercraft: the hover hull kit with a tracking radar
dome on a mast at the stern, and on a turret (`turret`; the def has no
pitch piece) two upright missile pods of four cells each, raked skyward
with glowing caps (weapon channel); team pods and roof (BAR style, M-15;
Order, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import math  # noqa: E402

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.6
TURRET = (0.0, DECK, -0.4)
RAKE = math.radians(55)
AIM = (0.0, math.sin(RAKE), -math.cos(RAKE))


def build_base(p):
    d = hulls.hover(p, "order", length=6.8, width=4.6, deck=DECK, fans=2)
    p.cylinder("y", (-1.4, d + 0.9, 1.2), 0.1, 1.8, 6, "steel")  # radar mast
    p.cylinder("y", (-1.4, d + 1.95, 1.2), 0.42, 0.5, 12, "trim", radius2=0.2)
    p.box((-1.4, d + 1.95, 0.8), (0.5, 0.12, 0.04), "light")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -2.4), (1.6, DECK + 0.001, -2.4), 5, UP)


def build_turret(p):
    x, y, z = TURRET
    p.prism_y([(-1.0, -0.9), (1.0, -0.9), (1.2, -0.3), (1.2, 0.9), (-1.2, 0.9), (-1.2, -0.3)], y, y + 0.55, "paint",
              bevel=0.05, top_scale=0.85)
    p.box((0, y + 0.57, z + 0.3), (0.9, 0.05, 0.9), "team", bevel=0.01)
    up = (0.0, math.cos(RAKE), math.sin(RAKE))
    for sx in (-1, 1):
        px, py, pz = x + sx * 0.95, y + 1.05, z
        p.obox((px, py, pz), (1, 0, 0), up, 0.6, 0.9, 1.1, "team", bevel=0.04)
        for r in range(2):
            for c in range(2):
                ox = -0.14 + c * 0.28
                ou = -0.2 + r * 0.4
                cx, cy, cz = px + ox, py + up[1] * ou + AIM[1] * 0.46, pz + up[2] * ou + AIM[2] * 0.46
                p.ocyl((cx, cy, cz), AIM, 0.11, 0.03, 8, "weapon")
        p.box((px, y + 0.7, pz + 0.2), (0.2, 0.4, 0.3), "trim")


def no_details(p):
    pass


unit.run(__file__, "ord_halcyon", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret",
                                 "at": [0, TURRET[1] + 1.05 + AIM[1] * 0.6, TURRET[2] + AIM[2] * 0.6]}})
