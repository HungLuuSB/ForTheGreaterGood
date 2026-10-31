"""Mudskipper (Chaos light amphibious tank, T1; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_mudskipper/build.py

A low swamp skulker: the amphibious hull in Chaos dress (open-bracketed
dark floats, slat cages), a flat wide-set turret pushed forward like a
mudskipper's head with two bulging sensor eyes on top, and a long thin gun
(`barrel`, the def's pitch piece) (BAR style, M-15; Chaos reads light and
open, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.8
TURRET = (0.0, DECK, -0.2)
BARREL = (0.0, DECK + 0.45, -1.4)


def build_base(p):
    hulls.amphibious(p, "chaos", length=6.6, width=4.4, deck=DECK, wheels=5)


def details_base(p):
    bolts(p, (-1.5, DECK + 0.001, 2.3), (1.5, DECK + 0.001, 2.3), 6, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 0.8
    p.prism_y([(-1.0, -1.4), (1.0, -1.4), (1.7, -0.6), (1.7, 1.2), (-1.7, 1.2), (-1.7, -0.6)], y0, y1, "paint",
              bevel=0.05, top_scale=0.86)
    p.box((0, y1 + 0.02, 0.1), (1.6, 0.05, 1.4), "team", bevel=0.012)
    for sx in (-1, 1):
        p.cylinder("y", (sx * 0.85, y1 + 0.2, -0.6), 0.34, 0.4, 10, "dark")  # eye turrets
        p.cylinder("z", (sx * 0.85, y1 + 0.25, -0.95), 0.18, 0.06, 10, "light")
        p.box((sx * 1.72, y0 + 0.4, 0.2), (0.04, 0.12, 1.4), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.05), (0.7, 0.5, 0.45), "paint", bevel=0.04)
    p.cylinder("z", (x, y, z - 1.85), 0.14, 3.3, 12, "trim")
    p.cylinder("z", (x, y, z - 3.45), 0.2, 0.3, 12, "dark")
    p.cylinder("z", (x, y, z - 3.3), 0.18, 0.06, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_mudskipper", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 3.65]}})
