"""Pontifex (Order amphibious constructor, T1; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_pontifex/build.py

The bridge-builder: the amphibious hull with a glazed cab at the front left,
a stowed pontoon section on the rear deck, and on a turntable (`nano`, the
def's turning piece) a folded construction crane with a glowing emitter
(power channel: brightens while building); team cab roof and crane panels
(BAR style, M-15; Order, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.9
NANO = (0.9, DECK, 0.9)


def build_base(p):
    d = hulls.amphibious(p, "order", length=7.0, width=4.6, deck=DECK, wheels=5)
    # cab, front left
    p.prism_y([(-2.0, -2.6), (-0.2, -2.6), (-0.2, -0.8), (-2.0, -0.8)], d, d + 1.2, "paint", bevel=0.05, top_scale=0.92)
    p.box((-1.1, d + 0.75, -2.62), (1.5, 0.45, 0.05), "glass")
    p.box((-1.1, d + 1.23, -1.7), (1.4, 0.05, 1.4), "team", bevel=0.012)
    p.box((-1.1, d + 1.3, -2.25), (1.0, 0.1, 0.1), "head")  # work lights
    # stowed pontoon section on the rear deck
    p.box((-1.0, d + 0.3, 2.0), (1.8, 0.6, 2.2), "trim", bevel=0.04)
    p.box((-1.0, d + 0.61, 2.0), (1.4, 0.04, 1.8), "grille")


def details_base(p):
    bolts(p, (0.4, DECK + 0.001, -2.6), (2.0, DECK + 0.001, -2.6), 4, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y + 0.2, z), 0.85, 0.4, 14, "trim", cap_kinds=("dark", "paint"))
    p.box((x, y + 0.75, z + 0.1), (0.6, 0.8, 0.8), "paint", bevel=0.04)  # crane post
    # boom: folded forward over the deck, raised a little
    p.prism_x([(z + 0.4, y + 0.95), (z - 2.6, y + 1.35), (z - 2.6, y + 1.7), (z + 0.4, y + 1.45)], x - 0.25, x + 0.25,
              "paint", bevel=0.03)
    p.box((x, y + 1.62, z - 1.2), (0.3, 0.04, 1.8), "team")
    p.cylinder("z", (x, y + 1.5, z - 2.75), 0.28, 0.3, 10, "trim")
    p.cylinder("z", (x, y + 1.5, z - 3.0), 0.2, 0.2, 10, "power")  # emitter
    p.box((x + 0.31, y + 1.2, z - 1.0), (0.04, 0.1, 1.6), "light")


def no_details(p):
    pass


unit.run(__file__, "ord_pontifex", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         attachments={"nano1": {"parent": "nano", "at": [NANO[0], NANO[1] + 1.5, NANO[2] - 3.15]}})
