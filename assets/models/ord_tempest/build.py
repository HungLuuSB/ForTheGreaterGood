"""Tempest (Order heavy hovertank, T2; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_tempest/build.py

A heavy armoured hovercraft: a long, wide hover hull kit with three lift
fans, armoured side sponsons, a big faceted turret with a bustle, and a
long heavy gun (`barrel`, the def's pitch piece) with a thermal sleeve, a
fume extractor and a muzzle brake; team roof, cheeks and sponson bands
(BAR style, M-15; Order reads heavy, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.0
TURRET = (0.0, DECK, 0.4)
BARREL = (0.0, DECK + 0.9, -1.8)


def build_base(p):
    d = hulls.hover(p, "order", length=11.0, width=7.4, deck=DECK, fans=3)
    for sx in (-1, 1):  # armoured sponsons
        p.prism_x([(-4.6, d - 0.9), (4.0, d - 0.9), (4.4, d - 0.2), (-4.2, d - 0.2)], sx * 3.7 - 0.35, sx * 3.7 + 0.35,
                  "paint", bevel=0.05)
        p.box((sx * 4.06, d - 0.55, -1.0), (0.04, 0.3, 3.0), "team")
    p.box((0, d + 0.02, -4.0), (3.4, 0.05, 1.0), "grille")


def details_base(p):
    bolts(p, (-2.8, DECK + 0.001, -3.2), (2.8, DECK + 0.001, -3.2), 9, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.5
    p.prism_y([(-1.6, -2.4), (1.6, -2.4), (2.6, -1.2), (2.6, 1.8), (2.0, 2.6), (-2.0, 2.6), (-2.6, 1.8), (-2.6, -1.2)],
              y0, y1, "paint", bevel=0.07, top_scale=0.86)
    p.box((0, y1 + 0.02, 0.4), (2.6, 0.05, 2.4), "team", bevel=0.014)
    for sx in (-1, 1):
        p.obox((sx * 2.1, y0 + 0.75, -1.8), (sx * 0.77, 0, 0.64), (sx * 0.64, 0, -0.77), 1.2, 1.0, 0.06, "team")
        p.box((sx * 2.62, y0 + 0.7, 0.4), (0.04, 0.12, 2.4), "light")
    p.box((0, y0 + 0.8, 3.0), (3.2, 1.0, 0.9), "trim", bevel=0.05)  # bustle
    p.box((0, y0 + 0.8, 3.46), (2.8, 0.6, 0.04), "grille")
    p.box((1.3, y1 + 0.22, 0.9), (0.6, 0.4, 0.6), "trim", bevel=0.02)  # commander's sight
    p.box((1.3, y1 + 0.25, 0.58), (0.44, 0.16, 0.04), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z + 0.1), (1.4, 1.0, 1.0), "paint", bevel=0.05)  # mantlet
    p.cylinder("z", (x, y, z - 2.6), 0.34, 4.6, 14, "paint")  # thermal sleeve
    for i in range(3):
        p.cylinder("z", (x, y, z - 1.2 - i * 1.3), 0.38, 0.1, 14, "trim")
    p.cylinder("z", (x, y, z - 3.2), 0.46, 0.8, 14, "trim")  # fume extractor
    p.cylinder("z", (x, y, z - 5.5), 0.26, 1.4, 14, "steel")
    p.box((x, y, z - 6.4), (0.8, 0.5, 0.6), "dark", bevel=0.04)  # brake
    p.cylinder("z", (x, y, z - 6.72), 0.24, 0.06, 14, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_tempest", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 6.8]}},
         budget=5000)
