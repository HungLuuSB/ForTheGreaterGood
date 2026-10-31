"""Hurler (Chaos mobile artillery, T2; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_hurler/build.py

An open-frame gun carrier: the tracked hull with an exposed girder deck,
ammo racks and folding rear spades, a short open-backed turret set far
back with a gun shield, and a long plasma howitzer (`barrel`, the def's
pitch piece): a coil-wrapped breech, a ribbed tube and a glowing vented
muzzle (weapon channel); amber slits, team shield panels (BAR style, M-15;
Chaos reads light and open, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.8
TURRET = (0.0, DECK, 2.0)
BARREL = (0.0, DECK + 0.95, 0.9)


def build_base(p):
    d = hulls.tracked(p, "chaos", length=8.8, width=5.0, deck=DECK)
    # exposed girder deck forward
    for sx in (-1, 1):
        p.box((sx * 1.4, d + 0.2, -1.8), (0.2, 0.4, 4.0), "steel")
    for i in range(4):
        p.box((0, d + 0.2, -3.4 + i * 1.0), (2.8, 0.2, 0.15), "steel")
    for i in range(3):  # ammo racks between the girders
        p.cylinder("z", (-0.6 + i * 0.6, d + 0.25, -1.8), 0.2, 2.6, 8, "trim", cap_kinds=("weapon", "dark"))
    for sx in (-1, 1):  # folding spades
        p.prism_x([(4.4, 0.4), (5.1, 0.6), (4.8, 1.7), (4.4, 1.6)], sx * 1.1 - 0.5, sx * 1.1 + 0.5, "dark",
                  bevel=0.03)
        p.box((sx * 1.1, 1.65, 4.2), (0.25, 0.25, 1.0), "steel")


def details_base(p):
    bolts(p, (-2.0, DECK + 0.001, 3.6), (2.0, DECK + 0.001, 3.6), 6, UP)


def build_turret(p):
    y0 = DECK
    p.prism_y([(-1.4, -0.6), (1.4, -0.6), (1.6, 0.4), (1.6, 2.2), (-1.6, 2.2), (-1.6, 0.4)], y0, y0 + 0.7, "paint",
              bevel=0.05, top_scale=0.92)
    # gun shield: two raked plates either side of the cradle
    for sx in (-1, 1):
        p.prism_x([(-0.7, y0 + 0.7), (-0.3, y0 + 1.9), (0.3, y0 + 1.9), (0.5, y0 + 0.7)],
                  sx * 0.45 if sx > 0 else -1.55, 1.55 if sx > 0 else -0.45, "paint", bevel=0.04)
        p.box((sx * 1.0, y0 + 1.3, -0.55), (0.8, 0.5, 0.04), "team")
        p.box((sx * 1.0, y0 + 1.75, -0.3), (0.6, 0.06, 0.04), "light")
        p.box((sx * 1.2, y0 + 0.9, 1.5), (0.5, 0.4, 1.0), "trim", bevel=0.03)  # shell lockers
    p.box((0, y0 + 0.45, 1.9), (1.6, 0.06, 0.04), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.1), (0.8, 0.8, 1.4), "dark", bevel=0.04)  # cradle
    for i in range(4):  # coil-wrapped breech
        p.cylinder("z", (x, y, z - 0.9 - i * 0.28), 0.42, 0.14, 12, "weapon" if i % 2 else "trim")
    p.cylinder("z", (x, y, z - 4.4), 0.24, 6.6, 12, "paint")
    for i in range(5):  # ribs
        p.cylinder("z", (x, y, z - 2.4 - i * 0.9), 0.3, 0.1, 12, "trim")
    p.cylinder("z", (x, y, z - 7.85), 0.3, 0.5, 12, "dark", radius2=0.38)  # vented muzzle
    for sx in (-1, 1):
        p.box((x + sx * 0.36, y, z - 7.85), (0.06, 0.3, 0.32), "weapon")
    p.cylinder("z", (x, y, z - 8.12), 0.22, 0.04, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_hurler", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 8.2]}})
