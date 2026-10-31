"""Whisper (Order cloaked tank, T2; batch 1 of the BAR roster, S-228/S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_whisper/build.py

A low stealth tank: the tracked hull under sloped faceted side plates in
dark radar-absorbent panels, a flat faceted turret with steeply raked
sides, and a gauss gun (`barrel`, the def's pitch piece): twin rails with
accelerator rings (weapon channel) instead of a tube; a thin team stripe
and a few dim cyan sensor slits, so it reads quiet next to the other
Order tanks (BAR style, M-15; Order, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.75
TURRET = (0.0, DECK, 0.5)
BARREL = (0.0, DECK + 0.5, -1.3)


def build_base(p):
    d = hulls.tracked(p, "order", length=8.0, width=5.2, deck=DECK)
    # sloped faceted side plates over the skirts
    for sx in (-1, 1):
        x0, x1 = (2.2, 2.95) if sx > 0 else (-2.95, -2.2)
        p.prism_x([(-3.6, d - 0.9), (3.7, d - 0.9), (3.4, d + 0.08), (-3.2, d + 0.08)], x0, x1, "dark", bevel=0.04)
    p.prism_x([(-4.3, d - 0.7), (-3.2, d + 0.06), (-2.2, d + 0.06), (-2.2, d - 0.7)], -2.2, 2.2, "dark", bevel=0.04)
    p.box((0, d + 0.1, 0.4), (0.18, 0.04, 6.0), "team", bevel=0.008)


def details_base(p):
    bolts(p, (-1.8, DECK + 0.001, 3.2), (1.8, DECK + 0.001, 3.2), 6, UP)


def build_turret(p):
    y0, y1 = DECK + 0.05, DECK + 0.85
    p.prism_y([(-0.8, -1.7), (0.8, -1.7), (2.0, -0.4), (2.0, 1.6), (1.2, 2.2), (-1.2, 2.2), (-2.0, 1.6), (-2.0, -0.4)],
              y0, y1, "dark", bevel=0.04, top_scale=0.62)
    p.box((0, y1 + 0.01, 0.6), (0.18, 0.04, 2.0), "team", bevel=0.008)
    for sx in (-1, 1):
        p.obox((sx * 1.3, y0 + 0.4, -0.95), (sx * 0.7, 0, -0.7), (0, 0.5, -0.4), 0.5, 0.06, 0.04, "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z + 0.1), (0.9, 0.5, 0.5), "dark", bevel=0.04)
    for sx in (-1, 1):
        p.box((x + sx * 0.2, y, z - 2.4), (0.14, 0.32, 4.6), "trim", bevel=0.02)  # rails
    for i in range(3):
        p.box((x, y, z - 1.0 - i * 1.4), (0.66, 0.5, 0.16), "dark", bevel=0.02)
        p.box((x, y, z - 1.0 - i * 1.4), (0.56, 0.4, 0.18), "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_whisper", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, BARREL[1], BARREL[2] - 4.8]}})
