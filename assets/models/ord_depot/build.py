"""Depot (Order storage, T1 structure, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_depot/build.py

A low armored bunker with sloped sides all round (stores supply and power):
a big team plate on the roof, two heavy loading hatches at the back, a cyan
fill gauge across the front slope and charge strips along the sides (power
channel: dims on an energy stall), corner running lights on the pad (BAR
style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, seam  # noqa: E402

BLOCK = [(-2.5, -3.2), (2.5, -3.2), (3.2, -2.5), (3.2, 2.5), (2.5, 3.2), (-2.5, 3.2), (-3.2, 2.5), (-3.2, -2.5)]


def build_base(p):
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.4, "trim", bevel=0.05, top_scale=0.97)
    p.prism_y(BLOCK, 0.4, 2.4, "paint", bevel=0.07, top_scale=0.72)
    p.box((0, 2.43, -0.6), (3.4, 0.05, 1.6), "team", bevel=0.015)
    for sx in (-1, 1):  # loading hatches at the back
        p.box((sx * 0.85, 2.55, 1.15), (1.3, 0.25, 1.1), "steel", bevel=0.04)
        p.box((sx * 0.85, 2.69, 1.15), (0.9, 0.04, 0.12), "dark")
    # fill gauge on the front slope: a dark window with lit segments
    p.obox((0, 1.45, -2.8), (1, 0, 0), (0, 0.66, -0.75), 3.0, 0.5, 0.05, "dark")
    for i in range(5):
        p.obox((-1.15 + i * 0.575, 1.47, -2.83), (1, 0, 0), (0, 0.66, -0.75), 0.48, 0.4, 0.04, "power")
    for sx in (-1, 1):  # charge strips along the side slopes
        p.obox((sx * 2.82, 1.3, 0.3), (0, 0, 1), (sx * 0.75, 0.66, 0), 3.6, 0.3, 0.04, "power")
    for sx in (-1, 1):  # pad corner lights
        for sz in (-1, 1):
            p.box((sx * 3.38, 0.42, sz * 3.38), (0.6, 0.08, 0.6), "light")
    p.box((0, 0.8, 3.5), (1.6, 0.6, 0.3), "grille")  # back vent
    for sx in (-1, 1):  # hatch status lights
        p.box((sx * 0.85, 2.69, 0.52), (0.9, 0.04, 0.12), "light")
    for sx in (-1, 1):  # roof edge running lights
        p.box((sx * 1.95, 2.42, -0.6), (0.22, 0.04, 2.4), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (4.0, 0, 4.0), 2.401)
    seam(p, (-1.7, 2.401, 0.6), (1.7, 2.401, 0.6), UP)
    bolts(p, (-3.3, 0.401, 3.3), (3.3, 0.401, 3.3), 8, UP)
    bolts(p, (-3.3, 0.401, -3.3), (3.3, 0.401, -3.3), 8, UP)


unit.run(__file__, "ord_depot", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
