"""Typhon (Chaos heavy laser hovertank, T2; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_typhon/build.py

A monster of the shallows: a very wide hover hull kit (three fans, skirt
rail) with outrigger floats on girder arms, a heavy hunched turret with
a horned crest and a power trunk behind, and twin heavy lasers side by
side on one pitching yoke (`barrel`, the def's pitch piece): finned
housings, coil-banded tubes and lenses (weapon channel); amber slits,
team crest and floats (BAR style, M-15; Chaos, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.0
TURRET = (0.0, DECK, 0.6)
BARREL = (0.0, DECK + 1.0, -1.2)
GUN_X = 0.75
X = (1, 0, 0)


def build_base(p):
    d = hulls.hover(p, "chaos", length=11.0, width=7.0, deck=DECK, fans=3)
    for sx in (-1, 1):  # outrigger floats on girder arms
        for z in (-2.4, 1.6):
            p.box((sx * 4.0, d - 0.6, z), (1.2, 0.14, 0.2), "steel")
        p.cylinder("z", (sx * 4.75, d - 0.9, -0.4), 0.5, 7.0, 10, "dark", cap_kinds=("trim", "trim"))
        p.ocyl((sx * 4.75, d - 0.9, -3.9), (0, 0, -1), 0.5, 0.6, 10, "trim", radius2=0.12)
        p.cylinder("z", (sx * 4.75, d - 0.9, -0.4), 0.52, 1.6, 10, "team")
    p.prism_x([(-5.6, 0.5), (-6.4, 0.9), (-5.9, 1.7), (-5.3, 1.7)], -2.2, 2.2, "steel", bevel=0.04)  # ram


def details_base(p):
    bolts(p, (-2.8, DECK + 0.001, -3.6), (2.8, DECK + 0.001, -3.6), 9, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.6
    p.prism_y([(-1.3, -2.2), (1.3, -2.2), (2.6, -0.8), (2.6, 1.8), (1.8, 2.8), (-1.8, 2.8), (-2.6, 1.8), (-2.6, -0.8)],
              y0, y1, "paint", bevel=0.07, top_scale=0.76)
    p.prism_x([(-0.9, y1), (-0.2, y1 + 0.7), (1.6, y1 + 0.5), (2.2, y1)], -0.3, 0.3, "team", bevel=0.02)
    for sx in (-1, 1):
        p.ocyl((sx * 1.4, y1 - 0.15, -0.9), (sx * 0.6, 1.0, -0.4), 0.2, 1.1, 6, "steel", radius2=0.02)  # horns
        for j in range(2):
            p.box((sx * 2.15, y0 + 0.45 + j * 0.5, -0.4), (0.5, 0.42, 0.9), "era", bevel=0.02)
        p.obox((sx * 0.7, y1 - 0.3, -1.85), X, (0, 0.5, -1), 0.6, 0.1, 0.04, "light")
    p.box((0, y0 + 0.8, 3.3), (2.6, 1.2, 1.0), "trim", bevel=0.05)  # power trunk
    p.box((0, y0 + 0.8, 3.81), (2.2, 0.8, 0.04), "grille")
    for sx in (-1, 1):
        p.cylinder("z", (sx * 1.0, y0 + 1.55, 2.4), 0.16, 1.8, 8, "weapon")  # power conduits


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z + 0.2), (2.8, 0.6, 0.9), "dark", bevel=0.04)  # yoke
    for sx in (-1, 1):
        gx = x + sx * GUN_X
        p.box((gx, y, z - 0.4), (0.9, 0.85, 1.2), "dark", bevel=0.04)
        for i in range(3):
            p.box((gx + sx * 0.5, y, z - 0.7 + i * 0.3), (0.12, 0.75, 0.08), "steel")
        p.cylinder("z", (gx, y, z - 2.8), 0.26, 3.6, 12, "trim")
        for i in range(3):
            p.cylinder("z", (gx, y, z - 1.6 - i * 0.9), 0.32, 0.12, 12, "weapon")
        p.cylinder("z", (gx, y, z - 4.7), 0.32, 0.3, 12, "dark", radius2=0.4)
        p.cylinder("z", (gx, y, z - 4.87), 0.28, 0.04, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_typhon", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [-GUN_X, BARREL[1], BARREL[2] - 4.95]}},
         budget=6000)
