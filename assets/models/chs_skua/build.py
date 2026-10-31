"""Skua (Chaos hover anti-air, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_skua/build.py

A flak hovercraft: the hover hull kit with a spiked radar mast, and on a
turret (`turret`; the def has no pitch piece) a single open missile cradle
of six bare missiles raked skyward between two side braces, warheads
glowing (weapon channel); amber lamps, team cradle plate (BAR style,
M-15; Chaos reads light and open, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import math  # noqa: E402

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.5
TURRET = (0.0, DECK, -0.3)
RAKE = math.radians(55)
AIM = (0.0, math.sin(RAKE), -math.cos(RAKE))
UPV = (0.0, math.cos(RAKE), math.sin(RAKE))
CRADLE = (0.0, DECK + 1.2, -0.3)


def build_base(p):
    d = hulls.hover(p, "chaos", length=6.8, width=4.6, deck=DECK, fans=2)
    p.cylinder("y", (1.5, d + 0.9, 1.4), 0.08, 1.8, 6, "steel")  # radar mast
    p.box((1.5, d + 1.8, 1.4), (0.9, 0.25, 0.12), "dark")
    p.box((1.5, d + 1.8, 1.33), (0.6, 0.08, 0.04), "light")
    p.ocyl((1.5, d + 1.95, 1.4), (0, 1, 0), 0.06, 0.5, 5, "steel", radius2=0.01)


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -2.4), (1.6, DECK + 0.001, -2.4), 5, UP)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.2, z), 0.9, 0.4, 10, "dark")
    cx, cy, cz = CRADLE
    for sx in (-1, 1):  # side braces
        p.obox((cx + sx * 0.85, cy - 0.2, cz), (1, 0, 0), UPV, 0.1, 1.6, 0.9, "steel")
    p.obox((cx, cy - 0.55, cz + 0.25), (1, 0, 0), UPV, 1.6, 1.0, 0.08, "team")  # cradle plate
    for r in range(2):
        for c in range(3):
            ox = -0.45 + c * 0.45
            ou = -0.05 + r * 0.38
            mx, my, mz = cx + ox, cy + UPV[1] * ou, cz + UPV[2] * ou
            p.ocyl((mx - AIM[0] * 0.7, my - AIM[1] * 0.7, mz - AIM[2] * 0.7), AIM, 0.1, 1.2, 6, "trim")
            p.ocyl((mx + AIM[0] * 0.5, my + AIM[1] * 0.5, mz + AIM[2] * 0.5), AIM, 0.1, 0.3, 6, "weapon",
                   radius2=0.02)


def no_details(p):
    pass


unit.run(__file__, "chs_skua", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret",
                                 "at": [0, CRADLE[1] + AIM[1] * 0.9, CRADLE[2] + AIM[2] * 0.9]}})
