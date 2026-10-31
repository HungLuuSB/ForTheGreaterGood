"""Skimmer (Order hover tank, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_skimmer/build.py

A light hover tank: the hover hull kit with twin fans, a low rounded
turret with team roof and cheek panels, and a plasma gun (`barrel`, the
def's pitch piece): a ribbed sleeve, a slim tube and a glowing collar
(weapon channel); BAR style, M-15; Order, M-14. Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.6
TURRET = (0.0, DECK, -0.2)
BARREL = (0.0, DECK + 0.5, -1.2)


def build_base(p):
    hulls.hover(p, "order", length=6.8, width=4.6, deck=DECK, fans=2)


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -2.3), (1.6, DECK + 0.001, -2.3), 5, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 0.85
    p.prism_y([(-0.8, -1.2), (0.8, -1.2), (1.4, -0.5), (1.4, 0.9), (0.9, 1.4), (-0.9, 1.4), (-1.4, 0.9), (-1.4, -0.5)],
              y0, y1, "paint", bevel=0.06, top_scale=0.8)
    p.box((0, y1 + 0.02, 0.2), (1.2, 0.05, 1.2), "team", bevel=0.012)
    for sx in (-1, 1):
        p.obox((sx * 1.1, y0 + 0.42, -0.85), (sx * 0.76, 0, 0.65), (sx * 0.65, 0, -0.76), 0.6, 0.5, 0.05, "team")
        p.box((sx * 1.41, y0 + 0.4, 0.3), (0.04, 0.1, 0.9), "light")
    p.cylinder("y", (0.6, y1 + 0.12, 0.6), 0.22, 0.24, 8, "trim")  # sight


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z + 0.1), (0.6, 0.5, 0.5), "trim", bevel=0.03)
    p.cylinder("z", (x, y, z - 0.6), 0.22, 0.8, 10, "paint")
    for i in range(3):
        p.cylinder("z", (x, y, z - 0.35 - i * 0.22), 0.26, 0.08, 10, "trim")
    p.cylinder("z", (x, y, z - 1.7), 0.12, 1.6, 10, "steel")
    p.cylinder("z", (x, y, z - 2.45), 0.17, 0.2, 10, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_skimmer", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 2.6]}})
