"""Extractor (Order supply extractor, T1 structure, footprint 1): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_extractor/build.py

An armored housing with sloped sides on a square pad, a big team plate on
its top, the drill head rising through it with a glowing cyan ring, side
pipes and vents (BAR style, M-15; Order reads heavy, M-14).
Writes export/ (FBX, maps, rig.json, previews) through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

HOUSING = [(-2.5, -2.5), (2.5, -2.5), (2.5, 2.5), (-2.5, 2.5)]


def build_base(p):
    # pad with a chamfered edge
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.45, "trim", bevel=0.05, top_scale=0.97)
    # armored housing: a sloped skirt, then the upright block
    p.prism_y([(-3.35, -3.35), (3.35, -3.35), (3.35, 3.35), (-3.35, 3.35)], 0.45, 1.3, "paint", bevel=0.05, top_scale=0.78)
    p.prism_y(HOUSING, 1.3, 2.9, "paint", bevel=0.06, top_scale=0.94)
    p.box((0, 2.93, 0), (3.9, 0.06, 3.9), "team", bevel=0.02)
    # drill head: collar, glowing ring, the head and its cap
    p.cylinder("y", (0, 3.15, 0), 1.25, 0.5, 16, "trim")
    p.cylinder("y", (0, 3.47, 0), 1.2, 0.2, 16, "power")
    p.cylinder("y", (0, 4.05, 0), 1.0, 1.0, 16, "steel")
    p.cylinder("y", (0, 4.05, 0), 1.02, 0.16, 16, "power")  # drill-head band
    p.cylinder("y", (0, 4.7, 0), 0.75, 0.3, 12, "dark")
    p.cylinder("y", (0, 5.0, 0), 0.32, 0.3, 8, "power")
    # pipes down the sides into the pad, vents and edge lights
    for sx in (-1, 1):
        p.cylinder("z", (sx * 2.75, 1.0, 0.0), 0.18, 4.6, 8, "steel")
        p.box((sx * 2.54, 2.2, 0.0), (0.07, 0.42, 2.6), "power")  # glowing vents
        p.box((sx * 3.55, 0.5, -3.55), (0.3, 0.12, 0.3), "light")
        p.box((sx * 3.55, 0.5, 3.55), (0.3, 0.12, 0.3), "light")
    p.box((0, 2.2, -2.53), (2.0, 0.12, 0.04), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (4.7, 0, 4.7), 2.901)
    ring(p, (0, 3.401, 0), UP, 1.1)
    for sx in (-1, 1):
        bolts(p, (sx * 2.51, 2.7, -2.2), (sx * 2.51, 2.7, 2.2), 6, (sx, 0, 0))
        seam(p, (sx * 2.51, 1.45, -2.3), (sx * 2.51, 1.45, 2.3), (sx, 0, 0))
    bolts(p, (-2.2, 2.7, -2.51), (2.2, 2.7, -2.51), 6, (0, 0, -1))


unit.run(__file__, "ord_extractor", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
