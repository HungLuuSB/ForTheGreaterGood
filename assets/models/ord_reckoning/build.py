"""Reckoning (Order nuclear silo, T3 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_reckoning/build.py

A stepped square armored bunker with sloped blast walls on every side; its
roof is one unmistakable silo top (it must never read as a Citadel from
above): two huge split blast doors, `hatch` (the def's piece, left, hinged
at its outer edge) and `hatch2` (client-only, right), ringed by a yellow
and black hazard edge and a red-white warning ring of lights (power
channel: the silo's charge state). Team plates on the lower ring, cyan
running lights round the steps (BAR style, M-15; Order reads heavy, M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams  # noqa: E402

HATCH = (-6.05, 3.1, 0.0)
HATCH2 = (6.05, 3.1, 0.0)


def octagon(r, c):
    return [(-r + c, -r), (r - c, -r), (r, -r + c), (r, r - c), (r - c, r), (-r + c, r), (-r, r - c), (-r, -r + c)]


def build_base(p):
    p.prism_y(octagon(11.8, 2.4), 0.0, 1.2, "paint", bevel=0.08, top_scale=0.94)
    p.prism_y(octagon(10.4, 1.6), 1.2, 2.6, "paint", bevel=0.08, top_scale=0.9)
    for sx, sz in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        if sx:
            p.box((sx * 10.7, 1.23, 0), (1.2, 0.05, 6.0), "team", bevel=0.015)
        else:
            p.box((0, 1.23, sz * 10.7), (6.0, 0.05, 1.2), "team", bevel=0.015)
    # the silo well and the hazard edge round it
    p.box((0, 2.62, 0), (12.6, 0.06, 12.6), "dark")
    for i in range(8):
        for side in range(4):
            t = -6.6 + i * 1.65 + 0.82
            kind = "hazard" if (i + side) % 2 == 0 else "dark"
            if side == 0:
                p.box((t, 2.7, -6.8), (1.65, 0.14, 0.8), kind)
            elif side == 1:
                p.box((t, 2.7, 6.8), (1.65, 0.14, 0.8), kind)
            elif side == 2:
                p.box((-6.8, 2.7, t), (0.8, 0.14, 1.65), kind)
            else:
                p.box((6.8, 2.7, t), (0.8, 0.14, 1.65), kind)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 6.8, 2.75, sz * 6.8), (0.8, 0.2, 0.8), "hazard")
            p.box((sx * 7.6, 2.75, sz * 7.6), (0.5, 0.18, 0.5), "power")  # warning lights at the corners
    for sx in (-1, 1):  # running lights round the steps
        p.box((sx * 11.6, 0.7, 0), (0.06, 0.2, 14.0), "light")
        p.box((0, 0.7, sx * 11.6), (14.0, 0.2, 0.06), "light")
        p.box((sx * 9.7, 2.0, 0), (0.06, 0.2, 10.0), "light")
        p.box((0, 2.0, sx * 9.7), (10.0, 0.2, 0.06), "light")
    for sz in (-1, 1):  # warning bars along the well's front and back
        p.box((0, 2.66, sz * 6.25), (11.6, 0.04, 0.16), "power")


def details_base(p):
    box_seams(p, (0, 0, 0), (17.0, 0, 17.0), 2.601)
    bolts(p, (-11.0, 1.201, -11.0), (11.0, 1.201, -11.0), 16, UP)


def build_door(sx):
    def build(p):
        x = sx * 3.05
        p.box((x, 2.85, 0), (6.0, 0.5, 12.0), "steel", bevel=0.05)
        for z in (-4.0, 0.0, 4.0):
            p.box((x, 3.12, z), (5.4, 0.06, 0.3), "trim")  # ribs
        p.box((sx * 0.1, 3.12, 0), (0.2, 0.06, 11.6), "hazard")  # seam stripe
    return build


def no_details(p):
    pass


unit.run(__file__, "ord_reckoning", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("hatch", "base", HATCH, build_door(-1), no_details),
                 unit.PieceSpec("hatch2", "base", HATCH2, build_door(1), no_details)],
         attachments={"muzzle": {"parent": "base", "at": [0, 2.8, 0]}},
         team_pieces=["base"], budget=6000, tex=2048, preview_size=26)
