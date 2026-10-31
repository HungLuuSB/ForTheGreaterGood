"""Grendel (Chaos very heavy amphibious tank, T2; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_grendel/build.py

A seafloor brute: the amphibious hull kit (boat bow, open-framed sponsons,
snorkel, water jets) stretched broad and long, a ballast hump and anchor
chains on the bow, a massive hunched turret with a horned crest and
reactive bricks, and a short fat cannon (`barrel`, the def's pitch piece)
with a boxy muzzle brake; amber slits, team crest and flanks (BAR style,
M-15; Chaos, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.2
TURRET = (0.0, DECK, 0.8)
BARREL = (0.0, DECK + 1.0, -1.4)
X = (1, 0, 0)


def build_base(p):
    d = hulls.amphibious(p, "chaos", length=9.4, width=6.0, deck=DECK, wheels=7)
    p.box((0, d + 0.18, 3.4), (3.2, 0.35, 1.6), "trim", bevel=0.05)  # ballast hump
    p.box((0, d + 0.37, 3.4), (2.6, 0.04, 1.2), "grille")
    for sx in (-1, 1):
        for i in range(4):  # anchor chain links down the bow
            p.box((sx * 1.6, d - 0.25 - i * 0.22, -4.9 - i * 0.12), (0.14, 0.2, 0.26), "steel")
        p.box((sx * 2.6, d + 0.02, -1.6), (0.6, 0.05, 2.4), "team", bevel=0.01)


def details_base(p):
    bolts(p, (-2.4, DECK + 0.001, 4.2), (2.4, DECK + 0.001, 4.2), 8, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.9
    p.prism_y([(-1.4, -2.0), (1.4, -2.0), (2.3, -1.0), (2.5, 1.4), (1.6, 2.9), (-1.6, 2.9), (-2.5, 1.4), (-2.3, -1.0)],
              y0, y1, "paint", bevel=0.08, top_scale=0.78)
    # horned crest along the roof
    p.prism_x([(-1.2, y1), (-0.4, y1 + 0.75), (1.4, y1 + 0.55), (2.2, y1)], -0.45, 0.45, "dark", bevel=0.03)
    p.box((0, y1 + 0.55, 0.5), (0.95, 0.05, 1.2), "team")
    for sx in (-1, 1):
        p.ocyl((sx * 1.3, y1 - 0.1, -0.6), (sx * 0.6, 1.0, -0.5), 0.2, 1.2, 6, "steel", radius2=0.02)  # horns
        for j in range(2):
            for k in range(2):
                p.box((sx * (1.75 + 0.25 * k), y0 + 0.55 + j * 0.55, -1.45 + k * 0.55), (0.55, 0.45, 0.14), "era",
                      bevel=0.02)
        p.obox((sx * 0.6, y1 - 0.35, -1.7), X, (0, 0.5, -1), 0.6, 0.1, 0.04, "light")
        p.box((sx * 2.47, y0 + 0.8, 1.2), (0.04, 0.6, 1.6), "team")
    p.box((0, y0 + 1.0, 3.2), (3.0, 1.2, 0.8), "trim", bevel=0.05)  # stowage bustle


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.2), (1.6, 1.3, 1.0), "paint", bevel=0.06)  # mantlet
    p.cylinder("z", (x, y, z - 1.7), 0.5, 2.4, 14, "trim")
    p.cylinder("z", (x, y, z - 2.0), 0.6, 0.5, 14, "dark")  # bore evacuator
    p.box((x, y, z - 3.25), (1.2, 0.9, 0.7), "dark", bevel=0.05)  # brake
    for sx in (-1, 1):
        p.box((x + sx * 0.62, y, z - 3.25), (0.06, 0.7, 0.5), "steel")
    p.cylinder("z", (x, y, z - 3.62), 0.42, 0.06, 14, "weapon")
    p.cylinder("z", (x, y, z - 3.65), 0.3, 0.04, 14, "dark")


def no_details(p):
    pass


unit.run(__file__, "chs_grendel", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 3.75]}},
         budget=5000)
