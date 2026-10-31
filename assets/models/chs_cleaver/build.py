"""Cleaver (Chaos riot tank, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_cleaver/build.py

A short, brutal crowd-breaker: a stubby tracked hull with slat cages and a
toothed dozer blade, a squat angular turret with reactive bricks, and a
fat short scatter gun (`barrel`, the def's pitch piece) with a flared,
slotted muzzle; amber vision slits (BAR style, M-15; Chaos reads light and
open, here blunt, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.9
TURRET = (0.0, DECK, 0.4)
BARREL = (0.0, DECK + 0.6, -0.8)
X = (1, 0, 0)


def build_base(p):
    d = hulls.tracked(p, "chaos", length=6.4, width=4.6, deck=DECK)
    # toothed dozer blade on two arms
    p.prism_x([(-3.75, 0.25), (-4.15, 0.45), (-4.05, 1.45), (-3.7, 1.35)], -2.4, 2.4, "steel", bevel=0.04)
    for i in range(6):
        x = -2.0 + i * 0.8
        p.ocyl((x, 0.32, -4.1), (0, -0.3, -1), 0.14, 0.35, 5, "steel", radius2=0.02)
    for sx in (-1, 1):
        p.box((sx * 1.6, 1.0, -3.3), (0.25, 0.3, 1.0), "dark")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, 2.4), (1.6, DECK + 0.001, 2.4), 6, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.05
    p.prism_y([(-1.0, -1.0), (1.0, -1.0), (1.5, -0.3), (1.5, 1.3), (0.9, 1.7), (-0.9, 1.7), (-1.5, 1.3), (-1.5, -0.3)],
              y0, y1, "paint", bevel=0.05, top_scale=0.8)
    p.box((0, y1 + 0.02, 0.45), (1.4, 0.05, 1.4), "team", bevel=0.012)
    for sx in (-1, 1):
        for j in range(2):
            p.box((sx * 1.05, y0 + 0.35 + j * 0.45, -0.95), (0.6, 0.4, 0.12), "era", bevel=0.02)
        p.obox((sx * 0.45, y1 - 0.25, -0.86), X, (0, 0.4, -1), 0.45, 0.1, 0.04, "light")  # slits
        p.obox((sx * 1.52, y0 + 0.5, 0.5), (0, 0, 1), (sx, 0, 0), 1.2, 0.12, 0.04, "light")
    p.cylinder("y", (-0.6, y1 + 0.18, 0.9), 0.32, 0.36, 8, "dark")  # hatch


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.1), (0.9, 0.7, 0.6), "paint", bevel=0.04)
    p.cylinder("z", (x, y, z - 1.1), 0.36, 1.5, 12, "trim")
    p.cylinder("z", (x, y, z - 2.15), 0.36, 0.6, 12, "dark", radius2=0.56)  # flared muzzle
    for i in range(4):
        p.box((x, y, z - 1.9 - i * 0.12), (0.8, 0.06, 0.04), "steel")
    p.cylinder("z", (x, y, z - 2.47), 0.42, 0.06, 12, "weapon")
    p.cylinder("z", (x, y, z - 2.5), 0.3, 0.04, 12, "dark")  # the bore


def no_details(p):
    pass


unit.run(__file__, "chs_cleaver", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 2.55]}})
