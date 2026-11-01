"""Magistrate (Order combat engineer, T2; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_magistrate/build.py

A front-line builder on a heavy chassis: the tracked hull with thick skirts,
a wide dozer blade on push arms, an armoured cab with vision blocks at the
front right, tool racks, and on a turntable at the back (`nano`, the def's
turning piece) a two-stage telescopic boom with a glowing emitter head
(power channel: brightens while building); team cab roof, boom panel and
skirt strips (BAR style, M-15; Order reads clean and heavy, M-14). No gun:
the def has no weapon. Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.1
NANO = (-0.4, DECK, 1.5)


def build_base(p):
    d = hulls.tracked(p, "order", length=8.4, width=5.6, deck=DECK)
    # dozer blade on push arms
    p.prism_x([(-4.75, 0.2), (-5.25, 0.4), (-5.15, 1.75), (-4.7, 1.6)], -3.0, 3.0, "paint", bevel=0.05)
    p.box((0, 1.0, -5.22), (5.6, 0.1, 0.06), "hazard")
    for sx in (-1, 1):
        p.box((sx * 2.0, 1.1, -4.4), (0.3, 0.35, 1.2), "trim")
    # armoured cab, front right
    p.prism_y([(0.3, -3.6), (2.5, -3.6), (2.5, -1.4), (0.3, -1.4)], d, d + 1.3, "paint", bevel=0.05, top_scale=0.9)
    p.box((1.4, d + 1.32, -2.5), (1.6, 0.05, 1.6), "team", bevel=0.012)
    for x in (0.8, 1.4, 2.0):
        p.box((x, d + 0.9, -3.52), (0.4, 0.25, 0.05), "glass")
    p.box((1.4, d + 1.36, -3.3), (1.2, 0.1, 0.1), "head")  # work lights
    # tool racks along the left deck
    p.box((-1.9, d + 0.25, -1.6), (1.2, 0.5, 2.0), "trim", bevel=0.03)
    p.box((-1.9, d + 0.52, -1.6), (1.0, 0.04, 1.8), "grille")


def details_base(p):
    bolts(p, (-2.4, DECK + 0.001, 3.6), (2.4, DECK + 0.001, 3.6), 8, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y + 0.2, z), 1.1, 0.4, 16, "trim", cap_kinds=("dark", "paint"))
    p.box((x, y + 0.85, z + 0.3), (1.0, 1.0, 1.3), "paint", bevel=0.05)  # boom housing
    # two-stage boom, raised forward
    p.prism_x([(z + 0.8, y + 1.1), (z - 2.4, y + 1.7), (z - 2.4, y + 2.25), (z + 0.8, y + 1.75)], x - 0.38, x + 0.38,
              "paint", bevel=0.04)
    p.prism_x([(z - 2.3, y + 1.78), (z - 4.2, y + 2.13), (z - 4.2, y + 2.48), (z - 2.3, y + 2.13)], x - 0.24, x + 0.24,
              "trim", bevel=0.03)
    p.box((x, y + 2.03, z - 0.8), (0.5, 0.04, 2.0), "team")
    p.box((x + 0.39, y + 1.6, z - 0.9), (0.04, 0.1, 2.4), "light")
    # emitter head
    p.box((x, y + 2.3, z - 4.35), (0.6, 0.6, 0.4), "trim", bevel=0.03)
    p.cylinder("z", (x, y + 2.3, z - 4.62), 0.22, 0.16, 10, "power")


def no_details(p):
    pass


unit.run(__file__, "ord_magistrate", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         attachments={"nano1": {"parent": "nano", "at": [NANO[0], NANO[1] + 2.3, NANO[2] - 4.75]}})
