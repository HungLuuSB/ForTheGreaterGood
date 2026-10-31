"""Wader (Order light amphibious tank, T1; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_wader/build.py

A light tank that swims: the amphibious hull (boat bow, team-banded
flotation sponsons, snorkel, stern water jets) with a compact rounded
turret, a wave screen folded on the glacis and a medium gun with a
muzzle brake (`barrel`, the def's pitch piece) (BAR style, M-15; Order,
M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.9
TURRET = (0.0, DECK, 0.6)
BARREL = (0.0, DECK + 0.6, -0.8)


def build_base(p):
    d = hulls.amphibious(p, "order", length=6.8, width=4.4, deck=DECK, wheels=5)
    p.box((0, d + 0.05, -2.6), (3.2, 0.1, 0.6), "trim", bevel=0.02)  # folded wave screen


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, 2.4), (1.6, DECK + 0.001, 2.4), 6, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.0
    p.prism_y([(-1.0, -0.8), (1.0, -0.8), (1.4, -0.2), (1.4, 1.2), (1.0, 1.7), (-1.0, 1.7), (-1.4, 1.2), (-1.4, -0.2)],
              y0, y1, "paint", bevel=0.06, top_scale=0.84)
    p.box((0, y1 + 0.02, 0.5), (1.6, 0.05, 1.6), "team", bevel=0.012)
    p.cylinder("y", (-0.6, y1 + 0.15, 1.0), 0.36, 0.3, 10, "trim")  # hatch
    p.box((0.7, y1 + 0.1, -0.2), (0.4, 0.22, 0.4), "trim", bevel=0.02)  # sight
    p.box((0.7, y1 + 0.11, -0.41), (0.32, 0.1, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 1.41, y0 + 0.5, 0.5), (0.04, 0.12, 1.2), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.05), (0.8, 0.6, 0.5), "paint", bevel=0.04)
    p.cylinder("z", (x, y, z - 1.6), 0.18, 2.6, 12, "paint")
    p.box((x, y, z - 3.05), (0.48, 0.36, 0.42), "dark", bevel=0.03)
    p.cylinder("z", (x, y, z - 2.8), 0.21, 0.08, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_wader", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 3.3]}})
