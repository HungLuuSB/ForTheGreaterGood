"""Sling (Chaos hover rocket artillery, T1; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_sling/build.py

A ramshackle rocket barge: the hover hull kit with a girder frame, and on
a turntable (`turret`; the def has no pitch piece) an open rail launcher:
two rows of bare rockets on racks raked skyward, warheads glowing (weapon
channel), a scrap blast shield and a team plate; amber lamps (BAR style,
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
TURRET = (0.0, DECK, 0.5)
RAKE = math.radians(32)
FWD = (0.0, math.sin(RAKE), -math.cos(RAKE))
UPV = (0.0, math.cos(RAKE), math.sin(RAKE))
RACK = (0.0, DECK + 1.2, 0.4)


def build_base(p):
    d = hulls.hover(p, "chaos", length=7.0, width=4.8, deck=DECK, fans=2)
    for sx in (-1, 1):
        p.box((sx * 1.6, d + 0.3, -1.8), (0.12, 0.6, 1.6), "steel")
    p.box((0, d + 0.62, -1.8), (3.4, 0.08, 1.6), "dark")  # driver's roof plate
    p.box((0, d + 0.5, -2.62), (1.0, 0.1, 0.08), "light")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -0.8), (1.6, DECK + 0.001, -0.8), 5, UP)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.15, z), 1.0, 0.3, 10, "dark")
    for sx in (-1, 1):
        p.box((sx * 1.0, y + 0.7, z), (0.14, 0.9, 0.14), "steel")
    rx, ry, rz = RACK
    for sx in (-1, 1):  # rails
        p.obox((rx + sx * 0.95, ry, rz), (1, 0, 0), UPV, 0.1, 2.6, 0.1, "steel")
    for r in range(2):
        for c in range(4):
            ox = -0.6 + c * 0.4
            ou = -0.2 + r * 0.42
            cx, cy, cz = rx + ox, ry + UPV[1] * ou, rz + UPV[2] * ou
            p.ocyl((cx - FWD[0], cy - FWD[1] * 1.0, cz - FWD[2] * 1.0), FWD, 0.13, 1.7, 6, "trim")
            p.ocyl((cx + FWD[0] * 0.7, cy + FWD[1] * 0.7, cz + FWD[2] * 0.7), FWD, 0.13, 0.35, 6, "weapon",
                   radius2=0.02)
    p.obox((rx, ry - 0.1, rz + 1.3), (1, 0, 0), (0, 0.4, 1), 2.1, 0.8, 0.06, "dark")  # scrap blast shield
    p.obox((rx, ry - 0.1, rz + 1.34), (1, 0, 0), (0, 0.4, 1), 1.2, 0.4, 0.02, "team")


def no_details(p):
    pass


unit.run(__file__, "chs_sling", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret",
                                 "at": [0, RACK[1] + FWD[1] * 1.1, RACK[2] + FWD[2] * 1.1]}})
