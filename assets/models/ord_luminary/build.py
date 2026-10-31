"""Luminary (Order mobile tachyon-beam tank, heavy T2; batch 1 of the BAR
roster, S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_luminary/build.py

A heavy beam platform: a broad heavy tracked hull with thick skirts and
radiator banks, a tall faceted turret with a capacitor bank across its back
(running channel), and a thick beam projector (`barrel`, the def's pitch
piece): a heavy housing, a focusing tube with three lens rings and a wide
lens at the mouth (weapon channel); team roof and turret cheeks (BAR style,
M-15; Order reads heavy, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.3
TURRET = (0.0, DECK, 0.8)
BARREL = (0.0, DECK + 1.1, -1.1)


def build_base(p):
    d = hulls.tracked(p, "order", length=9.6, width=6.4, deck=DECK, wheels=7)
    for sx in (-1, 1):
        p.box((sx * 2.3, d + 0.15, 3.6), (1.2, 0.3, 1.6), "grille")  # radiator banks
        p.box((sx * 2.3, d + 0.32, 3.6), (1.2, 0.04, 0.12), "light")


def details_base(p):
    bolts(p, (-2.6, DECK + 0.001, -2.6), (2.6, DECK + 0.001, -2.6), 8, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 2.0
    p.prism_y([(-1.6, -1.9), (1.6, -1.9), (2.4, -0.8), (2.4, 2.4), (1.8, 3.0), (-1.8, 3.0), (-2.4, 2.4), (-2.4, -0.8)],
              y0, y1, "paint", bevel=0.07, top_scale=0.86)
    p.box((0, y1 + 0.02, 0.6), (2.6, 0.05, 2.4), "team", bevel=0.015)
    for sx in (-1, 1):
        # flush on the front facet (its outward normal and run, at mid-height of the sloped side)
        p.obox((sx * 1.9, y0 + 1.0, -1.25), (sx * 0.59, 0, 0.81), (sx * 0.81, 0, -0.59), 0.9, 1.0, 0.06, "team")
    # capacitor bank across the back
    for i in range(4):
        x = -1.5 + i * 1.0
        p.cylinder("y", (x, y0 + 1.0, 3.2), 0.36, 1.6, 10, "trim")
        p.cylinder("y", (x, y0 + 1.6, 3.2), 0.38, 0.12, 10, "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.4), (1.8, 1.4, 1.4), "paint", bevel=0.06)  # projector housing
    p.cylinder("z", (x, y, z - 3.4), 0.5, 4.8, 16, "trim")
    for i in range(3):
        p.cylinder("z", (x, y, z - 2.0 - i * 1.4), 0.68, 0.22, 16, "dark")
        p.cylinder("z", (x, y, z - 2.0 - i * 1.4), 0.6, 0.26, 16, "weapon")
    p.cylinder("z", (x, y, z - 5.95), 0.72, 0.4, 16, "dark", radius2=0.8)  # mouth
    p.cylinder("z", (x, y, z - 6.17), 0.58, 0.05, 16, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_luminary", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 6.3]}},
         budget=5000)
