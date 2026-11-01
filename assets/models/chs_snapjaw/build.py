"""Snapjaw (Chaos hover tank, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_snapjaw/build.py

A biting hover tank: the hover hull kit with a toothed bow guard, a
wedge turret with a spiked crest and reactive bricks, and a stubby plasma
gun (`barrel`, the def's pitch piece) in a jaw-shaped shroud whose glowing
throat is the weapon channel; amber slits, team crest (BAR style, M-15;
Chaos, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.5
TURRET = (0.0, DECK, 0.0)
BARREL = (0.0, DECK + 0.45, -1.0)
X = (1, 0, 0)


def build_base(p):
    d = hulls.hover(p, "chaos", length=6.8, width=4.6, deck=DECK, fans=2)
    for i in range(5):  # toothed bow guard
        x = -1.6 + i * 0.8
        p.ocyl((x, 0.75, -3.75), (0, 0.2, -1), 0.14, 0.45, 5, "steel", radius2=0.02)
    p.box((0, 0.75, -3.6), (3.6, 0.2, 0.15), "steel")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, 2.0), (1.6, DECK + 0.001, 2.0), 5, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 0.8
    p.prism_y([(-0.5, -1.4), (0.5, -1.4), (1.4, -0.2), (1.3, 1.3), (-1.3, 1.3), (-1.4, -0.2)], y0, y1, "paint",
              bevel=0.05, top_scale=0.75)
    p.prism_x([(-0.6, y1), (0.0, y1 + 0.5), (1.1, y1 + 0.3), (1.2, y1)], -0.2, 0.2, "team", bevel=0.02)  # crest
    for sx in (-1, 1):
        p.box((sx * 1.2, y0 + 0.4, 0.4), (0.2, 0.4, 0.5), "era", bevel=0.02)
        p.obox((sx * 0.5, y1 - 0.2, -1.05), X, (0, 0.5, -1), 0.4, 0.08, 0.04, "light")


def build_barrel(p):
    x, y, z = BARREL
    for sy in (-1, 1):  # the jaws
        p.prism_x([(z + 0.3, y + sy * 0.1), (z - 1.4, y + sy * 0.14), (z - 1.6, y + sy * 0.4), (z + 0.3, y + sy * 0.38)],
                  x - 0.4, x + 0.4, "trim", bevel=0.03)
    for i in range(3):  # teeth
        p.box((x - 0.26 + i * 0.26, y + 0.12, z - 1.42), (0.08, 0.12, 0.08), "steel")
        p.box((x - 0.26 + i * 0.26, y - 0.12, z - 1.42), (0.08, 0.12, 0.08), "steel")
    p.cylinder("z", (x, y, z - 0.6), 0.16, 1.4, 10, "weapon")  # glowing throat


def no_details(p):
    pass


unit.run(__file__, "chs_snapjaw", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 1.6]}})
