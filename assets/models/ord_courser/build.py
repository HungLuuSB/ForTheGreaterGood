"""Courser (Order fast light assault vehicle, T1; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_courser/build.py

A quick 6 x 6 raider: a low, sharply raked wheeled hull with a long nose and
thick side skirts over the wheels, a small flat wedge turret set back, and a
slim autocannon (`barrel`, the def's pitch piece) with a muzzle brake; a
team roof plate and team skirt strips, cyan sight and running strips (BAR
style, M-15; Order reads clean and heavy, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.9
TURRET = (0.0, DECK, 0.5)
BARREL = (0.0, DECK + 0.55, -0.9)


def build_base(p):
    d = hulls.wheeled(p, "order", length=6.8, width=4.4, deck=DECK, axles=3)
    p.prism_x([(-4.0, 1.35), (-3.4, 0.95), (-2.6, d - 0.1), (-3.3, d - 0.35)], -1.7, 1.7, "paint", bevel=0.04)  # nose
    p.box((0, d - 0.3, -3.75), (2.4, 0.08, 0.06), "light")
    p.box((0, d + 0.02, 2.4), (2.2, 0.05, 1.2), "grille")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -2.0), (1.6, DECK + 0.001, -2.0), 6, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 0.95
    p.prism_y([(-1.1, -0.9), (1.1, -0.9), (1.45, -0.3), (1.45, 1.5), (-1.45, 1.5), (-1.45, -0.3)], y0, y1, "paint",
              bevel=0.05, top_scale=0.86)
    p.prism_x([(-1.4, y0 + 0.05), (-0.85, y0 + 0.05), (-0.85, y1), (-1.05, y1)], -0.95, 0.95, "paint", bevel=0.04)
    p.box((0, y1 + 0.02, 0.35), (1.8, 0.05, 1.5), "team", bevel=0.012)
    p.box((0.75, y1 + 0.12, -0.3), (0.42, 0.24, 0.42), "trim", bevel=0.02)  # sight
    p.box((0.75, y1 + 0.13, -0.52), (0.34, 0.12, 0.04), "light")
    p.cylinder("y", (-0.8, y1 + 0.45, 1.1), 0.04, 0.9, 5, "steel")  # antenna
    for sx in (-1, 1):
        p.box((sx * 1.46, y0 + 0.5, 0.6), (0.04, 0.12, 1.6), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.1), (0.7, 0.55, 0.5), "paint", bevel=0.04)  # mantlet
    p.cylinder("z", (x, y, z - 1.8), 0.16, 2.8, 12, "trim")
    p.cylinder("z", (x, y, z - 0.9), 0.24, 0.6, 12, "paint")
    p.box((x, y, z - 3.3), (0.42, 0.34, 0.5), "dark", bevel=0.03)  # brake
    p.cylinder("z", (x, y, z - 3.0), 0.2, 0.08, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_courser", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 3.6]}})
