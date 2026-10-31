"""Gnat (Chaos fast hover raider, T1; batch 1 of the BAR roster, S-230): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_gnat/build.py

A stripped racer: a narrow hover hull kit with one big fan and the skirt
rail, a bare roll cage over an open seat, twin tail fins, and a pintle
mount (`turret`; the def has no pitch piece) with a single long machine
gun and an ammo drum; amber lamps, team fins (BAR style, M-15; Chaos reads
light and open, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.3
TURRET = (0.0, DECK, -1.1)


def build_base(p):
    d = hulls.hover(p, "chaos", length=6.4, width=3.6, deck=DECK, fans=1)
    p.box((0, d + 0.2, -0.2), (1.0, 0.4, 1.0), "dark", bevel=0.03)  # seat
    for sx in (-1, 1):  # roll cage
        p.box((sx * 0.6, d + 0.6, -0.6), (0.08, 1.2, 0.08), "steel")
        p.box((sx * 0.6, d + 0.6, 0.4), (0.08, 1.2, 0.08), "steel")
        p.box((sx * 0.6, d + 1.2, -0.1), (0.08, 0.08, 1.1), "steel")
        p.prism_x([(1.6, d + 0.6), (2.7, d + 0.6), (3.0, d + 1.6), (2.5, d + 1.6)], sx * 0.7 - 0.05, sx * 0.7 + 0.05,
                  "team", bevel=0.01)  # tail fins
    p.box((0, d + 1.2, -0.1), (1.28, 0.08, 0.08), "steel")
    p.box((0, d + 1.2, -0.65), (0.5, 0.08, 0.06), "light")


def details_base(p):
    bolts(p, (-1.0, DECK + 0.001, 1.1), (1.0, DECK + 0.001, 1.1), 4, UP)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.25, z), 0.1, 0.5, 6, "steel")
    p.box((x, y + 0.55, z), (0.3, 0.2, 0.6), "dark")
    p.cylinder("z", (x, y + 0.6, z - 1.0), 0.07, 1.6, 6, "steel")
    p.cylinder("z", (x, y + 0.6, z - 1.82), 0.09, 0.06, 6, "weapon")
    p.cylinder("x", (x + 0.3, y + 0.5, z + 0.05), 0.22, 0.25, 10, "trim")  # ammo drum


def no_details(p):
    pass


unit.run(__file__, "chs_gnat", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, TURRET[1] + 0.6, TURRET[2] - 1.9]}})
