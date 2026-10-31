"""Glaive (Chaos assault hovertank, T2; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_glaive/build.py

The Skim Yard's line breaker: a thick, long hover hull kit (three fans,
skirt rail) with a bladed ram prow and armour slabs, a hunched angular
turret with reactive bricks and a spiked crest, and a heavy laser
(`barrel`, the def's pitch piece): a finned emitter housing, a focusing
tube with glowing coil bands and a lens (weapon channel); amber slits,
team crest and flanks (BAR style, M-15; Chaos, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.8
TURRET = (0.0, DECK, 0.6)
BARREL = (0.0, DECK + 0.75, -0.8)
X = (1, 0, 0)


def build_base(p):
    d = hulls.hover(p, "chaos", length=9.0, width=5.8, deck=DECK, fans=3)
    # bladed ram prow
    p.prism_x([(-4.9, 0.5), (-5.8, 0.9), (-5.2, 1.6), (-4.5, 1.6)], -1.8, 1.8, "steel", bevel=0.04)
    for sx in (-1, 1):
        p.prism_x([(-3.0, d - 0.9), (2.6, d - 0.9), (2.4, d - 0.1), (-2.6, d - 0.1)], sx * 2.95 - 0.25,
                  sx * 2.95 + 0.25, "trim", bevel=0.04)  # armour slabs
        p.box((sx * 3.21, d - 0.5, -0.3), (0.04, 0.3, 2.6), "team")


def details_base(p):
    bolts(p, (-2.2, DECK + 0.001, -3.0), (2.2, DECK + 0.001, -3.0), 7, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.2
    p.prism_y([(-0.9, -1.8), (0.9, -1.8), (1.9, -0.6), (1.9, 1.6), (1.2, 2.2), (-1.2, 2.2), (-1.9, 1.6), (-1.9, -0.6)],
              y0, y1, "paint", bevel=0.06, top_scale=0.74)
    p.prism_x([(-0.8, y1), (-0.2, y1 + 0.55), (1.4, y1 + 0.35), (1.8, y1)], -0.25, 0.25, "team", bevel=0.02)
    for sx in (-1, 1):
        for j in range(2):
            p.box((sx * 1.55, y0 + 0.35 + j * 0.45, -0.6 + j * 0.1), (0.5, 0.4, 0.7), "era", bevel=0.02)
        p.obox((sx * 0.5, y1 - 0.25, -1.4), X, (0, 0.5, -1), 0.5, 0.08, 0.04, "light")
        p.ocyl((sx * 1.2, y1 - 0.1, 1.6), (sx * 0.4, 1, 0.3), 0.14, 0.7, 5, "steel", radius2=0.01)


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.1), (1.1, 0.8, 1.2), "dark", bevel=0.04)  # emitter housing
    for sx in (-1, 1):
        for i in range(3):  # cooling fins
            p.box((x + sx * 0.6, y, z - 0.4 + i * 0.3), (0.12, 0.7, 0.08), "steel")
    p.cylinder("z", (x, y, z - 2.3), 0.28, 3.2, 12, "trim")
    for i in range(3):
        p.cylinder("z", (x, y, z - 1.3 - i * 0.8), 0.34, 0.12, 12, "weapon")
    p.cylinder("z", (x, y, z - 4.0), 0.34, 0.3, 12, "dark", radius2=0.42)
    p.cylinder("z", (x, y, z - 4.17), 0.3, 0.04, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_glaive", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 4.25]}})
