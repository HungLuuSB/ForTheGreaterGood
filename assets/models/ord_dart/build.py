"""Dart (Order fast hover raider, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_dart/build.py

The quickest hull: a narrow, long hover hull kit with one big lift fan, a
swept windscreen, a tail fin, and a small ball mount (`turret`; the def
has no pitch piece) with a twin machine gun; team nose stripe and fin
(BAR style, M-15; Order, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.4
TURRET = (0.0, DECK, -0.9)


def build_base(p):
    d = hulls.hover(p, "order", length=6.6, width=3.8, deck=DECK, fans=1)
    p.prism_y([(-1.0, -1.9), (1.0, -1.9), (1.2, 0.6), (-1.2, 0.6)], d, d + 0.35, "paint", bevel=0.04,
              top_scale=0.8)  # cockpit tub
    p.obox((0, d + 0.55, -0.3), (1, 0, 0), (0, 0.8, -0.6), 1.6, 0.9, 0.04, "glass")  # swept windscreen
    p.box((0, d + 0.02, -2.6), (0.4, 0.05, 1.2), "team", bevel=0.01)
    p.prism_x([(1.4, d + 0.6), (2.9, d + 0.6), (3.2, d + 1.9), (2.6, d + 1.9)], -0.06, 0.06, "team",
              bevel=0.01)  # tail fin


def details_base(p):
    bolts(p, (-1.2, DECK + 0.001, 1.0), (1.2, DECK + 0.001, 1.0), 4, UP)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.1, z), 0.5, 0.2, 12, "trim")
    p.cylinder("y", (x, y + 0.42, z), 0.42, 0.45, 12, "paint", radius2=0.3)
    for sx in (-1, 1):
        p.cylinder("z", (x + sx * 0.14, y + 0.45, z - 0.9), 0.06, 1.1, 6, "steel")
        p.cylinder("z", (x + sx * 0.14, y + 0.45, z - 1.47), 0.08, 0.06, 6, "weapon")
    p.box((x, y + 0.45, z - 0.35), (0.5, 0.26, 0.3), "dark")


def no_details(p):
    pass


unit.run(__file__, "ord_dart", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, TURRET[1] + 0.45, TURRET[2] - 1.55]}})
