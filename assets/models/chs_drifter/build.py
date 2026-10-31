"""Drifter (Chaos hover constructor, T1; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_drifter/build.py

A scrap-built work hovercraft: the hover hull kit (skirt rail, twin
fans), an open-frame cab of girders and a canopy plate, salvage bins, and
a lattice crane (`nano`) with a hooked claw and a power emitter at its
tip (`nano1`); amber lamps, team canopy (BAR style, M-15; Chaos reads
light and open, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.5
NANO = (0.6, DECK, 0.0)


def build_base(p):
    d = hulls.hover(p, "chaos", length=7.0, width=5.0, deck=DECK, fans=2)
    for x in (-2.0, -0.6):  # open cab frame
        for z in (-2.6, -1.0):
            p.box((x, d + 0.55, z), (0.12, 1.1, 0.12), "steel")
    p.box((-1.3, d + 1.12, -1.8), (1.8, 0.08, 1.9), "team", bevel=0.01)
    p.box((-1.3, d + 0.25, -1.8), (1.2, 0.5, 1.0), "dark", bevel=0.03)  # seat block
    p.box((-1.3, d + 1.05, -2.72), (0.8, 0.12, 0.1), "light")
    for i in range(2):  # salvage bins
        p.box((-1.3, d + 0.3, 0.6 + i * 1.1), (1.5, 0.6, 0.9), "trim", bevel=0.03)
        p.box((-1.3, d + 0.61, 0.6 + i * 1.1), (1.2, 0.04, 0.6), "grille")


def details_base(p):
    bolts(p, (0.0, DECK + 0.001, -2.6), (2.0, DECK + 0.001, -2.6), 4, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y + 0.2, z), 0.7, 0.4, 10, "dark")
    p.box((x, y + 0.75, z + 0.2), (0.5, 0.8, 0.5), "trim", bevel=0.03)
    for sx in (-1, 1):  # lattice boom: two rails and cross braces
        p.prism_x([(z + 0.3, y + 1.05), (z - 3.4, y + 1.5), (z - 3.4, y + 1.6), (z + 0.3, y + 1.15)],
                  x + sx * 0.22 - 0.05, x + sx * 0.22 + 0.05, "steel")
    for i in range(5):
        zz = z - 0.3 - i * 0.7
        p.box((x, y + 1.15 + (0.3 - zz) * 0.12, zz), (0.44, 0.06, 0.06), "steel")
    p.box((x, y + 1.45, z - 3.5), (0.5, 0.3, 0.3), "dark")
    for sx in (-1, 1):  # claw
        p.ocyl((x + sx * 0.18, y + 1.3, z - 3.6), (sx * 0.3, -1, -0.4), 0.06, 0.5, 5, "steel", radius2=0.02)
    p.cylinder("z", (x, y + 1.55, z - 3.72), 0.16, 0.16, 8, "power")


def no_details(p):
    pass


unit.run(__file__, "chs_drifter", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         attachments={"nano1": {"parent": "nano", "at": [NANO[0], NANO[1] + 1.55, NANO[2] - 3.85]}})
