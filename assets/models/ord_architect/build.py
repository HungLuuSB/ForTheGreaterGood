"""Architect (Order advanced ground worker, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_architect/build.py

A heavier Mason: a tracked hull with thick skirts and a dozer blade, a
raised armored cab with a dark windshield, team plates; on the `nano`
turntable twin booms carrying two glowing emitters (power channel:
brighten while building) and a team-painted counterweight (BAR style,
M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

NANO = (0.0, 2.3, 1.9)


def build_base(p):
    d = hulls.tracked(p, "order", length=8.4, width=6.0, deck=1.9)
    p.prism_x([(-4.9, 0.4), (-4.6, 0.4), (-4.45, 1.5), (-4.75, 1.5)], -3.3, 3.3, "steel", bevel=0.03)  # dozer blade
    for sx in (-1, 1):
        p.box((sx * 2.4, 0.9, -4.2), (0.3, 0.3, 0.9), "dark")  # blade arms
    p.prism_y([(-1.7, -3.6), (1.7, -3.6), (1.7, -1.4), (-1.7, -1.4)], d, d + 1.4, "paint", bevel=0.05, top_scale=0.9)  # cab
    p.box((0, d + 0.9, -3.62), (2.6, 0.5, 0.05), "glass")
    p.box((0, d + 1.42, -2.5), (2.4, 0.05, 1.6), "team", bevel=0.012)
    p.box((0, d + 1.47, -2.5), (2.0, 0.08, 0.12), "light")  # roof beacon bar
    for sx in (-1, 1):  # cab side strips
        p.box((sx * 1.66, d + 0.8, -2.5), (0.04, 0.2, 2.0), "light")
    p.cylinder("y", (0, d + 0.1, 1.9), 1.5, 0.2, 16, "trim")  # turntable ring


def details_base(p):
    bolts(p, (-2.6, 1.901, 3.4), (2.6, 1.901, 3.4), 8, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (0, y + 0.25, z), 1.5, 0.5, 16, "paint")
    p.box((0, y + 0.52, z), (2.0, 0.05, 2.0), "team")
    t = math.radians(35)
    n = (0, math.sin(t), -math.cos(t))
    for sx in (-1, 1):
        p.obox((sx * 0.8, 4.1, 0.6), (1, 0, 0), n, 0.7, 0.7, 4.4, "paint", bevel=0.04)
        p.cylinder("y", (sx * 0.8, 5.4, -1.4), 0.45, 0.8, 12, "power")  # emitters
        p.cylinder("y", (sx * 0.8, 5.85, -1.4), 0.5, 0.1, 12, "dark")
    p.box((0, y + 1.0, z + 1.2), (2.4, 1.0, 1.0), "trim", bevel=0.04)  # counterweight
    p.box((0, y + 1.0, z + 1.71), (2.0, 0.6, 0.04), "team")


def no_details(p):
    pass


unit.run(__file__, "ord_architect", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)])
