"""Mandate (Order mobile artillery, T2; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_mandate/build.py

A self-propelled howitzer: a long tracked hull with the engine forward and
folded recoil spades at the stern, a tall boxy turret set well back with an
ammo bustle, and a long howitzer (`barrel`, the def's pitch piece) with a
recoil sleeve, a fume extractor and a slotted muzzle brake; a travel lock
on the glacis; team roof and side panels (BAR style, M-15; Order, M-14).
Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.0
TURRET = (0.0, DECK, 1.6)
BARREL = (0.0, DECK + 1.15, -0.3)


def build_base(p):
    d = hulls.tracked(p, "order", length=9.0, width=5.4, deck=DECK)
    p.box((0, d + 0.02, -2.6), (3.0, 0.05, 1.4), "grille")  # engine deck forward
    p.box((0, d + 0.55, -3.7), (0.5, 1.1, 0.3), "trim")  # travel lock
    p.box((0, d + 1.1, -3.7), (0.9, 0.2, 0.4), "trim")
    for sx in (-1, 1):
        p.box((sx * 1.6, 1.3, 4.75), (1.2, 1.4, 0.25), "trim", bevel=0.03)  # folded spades
        p.box((sx * 1.6, 0.75, 4.95), (1.2, 0.3, 0.3), "dark")


def details_base(p):
    bolts(p, (-2.2, DECK + 0.001, -1.5), (2.2, DECK + 0.001, -1.5), 7, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.8
    p.prism_y([(-1.8, -1.2), (1.8, -1.2), (2.2, -0.6), (2.2, 2.6), (-2.2, 2.6), (-2.2, -0.6)], y0, y1, "paint",
              bevel=0.06, top_scale=0.94)
    p.box((0, y1 + 0.02, 0.8), (2.6, 0.05, 2.4), "team", bevel=0.012)
    p.box((0, y0 + 1.0, 3.0), (3.4, 1.0, 0.8), "trim", bevel=0.04)  # ammo bustle
    p.box((0, y0 + 1.0, 3.41), (3.0, 0.6, 0.04), "grille")
    for sx in (-1, 1):
        p.box((sx * 2.22, y0 + 0.9, 1.2), (0.04, 0.8, 1.6), "team")
        p.box((sx * 2.22, y0 + 1.45, 1.0), (0.04, 0.12, 2.6), "light")
    p.box((-1.2, y1 + 0.2, -0.4), (0.5, 0.36, 0.5), "trim", bevel=0.02)  # sight
    p.box((-1.2, y1 + 0.22, -0.66), (0.4, 0.16, 0.04), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.5), (1.3, 1.1, 1.1), "paint", bevel=0.05)  # mantlet
    p.cylinder("z", (x, y, z - 1.8), 0.42, 1.8, 14, "paint")  # recoil sleeve
    p.cylinder("z", (x, y, z - 4.8), 0.26, 5.0, 14, "paint")
    p.cylinder("z", (x, y, z - 4.0), 0.36, 0.8, 14, "trim")  # fume extractor
    p.box((x, y, z - 7.55), (0.7, 0.55, 0.7), "dark", bevel=0.04)  # brake
    for i in range(3):
        p.box((x, y, z - 7.35 - i * 0.2), (0.74, 0.12, 0.06), "steel")
    p.cylinder("z", (x, y, z - 7.2), 0.29, 0.08, 14, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_mandate", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 7.95]}})
