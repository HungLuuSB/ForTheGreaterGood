"""Skimwright (Order hover constructor, T1; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_skimwright/build.py

A broad work hovercraft: the hover hull kit (rubber skirt, twin lift fans
at the stern, rudders), a glazed cab front left, a stowed float panel, and
a slewing crane (`nano`) with a team-striped boom folded forward and a
power emitter at its tip (`nano1`); BAR style, M-15; Order, M-14. Our own
design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.6
NANO = (1.0, DECK, 0.2)


def build_base(p):
    d = hulls.hover(p, "order", length=7.0, width=5.0, deck=DECK, fans=2)
    p.prism_y([(-2.1, -2.5), (-0.3, -2.5), (-0.3, -0.7), (-2.1, -0.7)], d, d + 1.1, "paint", bevel=0.05,
              top_scale=0.9)  # cab
    p.box((-1.2, d + 0.7, -2.52), (1.5, 0.42, 0.05), "glass")
    p.box((-1.2, d + 1.12, -1.6), (1.3, 0.05, 1.3), "team", bevel=0.012)
    p.box((-1.2, d + 1.2, -2.15), (1.0, 0.1, 0.1), "head")
    p.box((-1.2, d + 0.2, 1.0), (1.6, 0.4, 1.6), "trim", bevel=0.04)  # stowed float panel
    p.box((-1.2, d + 0.41, 1.0), (1.3, 0.04, 1.3), "grille")


def details_base(p):
    bolts(p, (0.3, DECK + 0.001, -2.4), (2.0, DECK + 0.001, -2.4), 4, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y + 0.2, z), 0.75, 0.4, 14, "trim", cap_kinds=("dark", "paint"))
    p.box((x, y + 0.7, z + 0.1), (0.55, 0.7, 0.7), "paint", bevel=0.04)
    p.prism_x([(z + 0.4, y + 0.9), (z - 2.9, y + 1.4), (z - 2.9, y + 1.72), (z + 0.4, y + 1.4)], x - 0.24, x + 0.24,
              "paint", bevel=0.03)
    p.box((x, y + 1.6, z - 1.3), (0.3, 0.04, 1.8), "team")
    p.cylinder("z", (x, y + 1.55, z - 3.05), 0.26, 0.3, 10, "trim")
    p.cylinder("z", (x, y + 1.55, z - 3.28), 0.19, 0.18, 10, "power")
    p.box((x + 0.25, y + 1.2, z - 1.2), (0.04, 0.1, 1.6), "light")


def no_details(p):
    pass


unit.run(__file__, "ord_skimwright", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         attachments={"nano1": {"parent": "nano", "at": [NANO[0], NANO[1] + 1.55, NANO[2] - 3.4]}})
