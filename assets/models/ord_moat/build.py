"""Moat (Order floating turret, T1 structure, footprint 1, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_moat/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 4 above the water), from its blockout. The waterline is y = 0. Big
shapes first: an armored floating casemate with sloped walls and a raked
bow, team plates on its flanks, running strips, a hazard edge, a deck light
and bollards; the `turret` (the def's piece): a twin gun house with a sloped
front, a large team roof, a sensor head, and two barrels with collars and
muzzle rings (`muzzle` between them). Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

PIVOT = (0.0, 1.3, 0.0)
GUN_Y = 2.0
MUZZLE = (0.0, GUN_Y, -6.2)


def build_base(p):
    p.prism_y(octagon(3.7, 1.2), -0.9, 0.3, "paint", bevel=0.1)
    p.prism_y(octagon(3.7, 1.2), 0.3, 1.2, "paint", bevel=0.12, top_scale=0.8)
    for sx in (-1, 1):
        p.obox((sx * 3.3, 0.75, 0.3), (0, 0, 1), (sx * 0.9, 0.45, 0), 3.0, 0.8, 0.05, "team", bevel=0.012)
        p.box((sx * 3.72, 0.0, 0), (0.05, 0.14, 3.0), "light")
        p.cylinder("y", (sx * 2.2, 1.45, 2.2), 0.2, 0.5, 10, "steel")
    hazard(p, (0, 0.4, -3.55), (1, 0, 0), (0, 0.4, -1.0), 2.6, 0.35, stripes=6)
    p.box((2.5, 1.32, -2.0), (0.4, 0.2, 0.4), "light")
    p.cylinder("y", (0, 1.25, 0), 1.75, 0.1, 18, "dark")  # turret ring


def build_turret(p):
    p.prism_y(octagon(1.5, 0.45, 0, 0.2), 1.3, 2.7, "paint", bevel=0.08, top_scale=0.86)
    p.prism_x([(-1.3, 1.35), (-1.3, 2.65), (-1.9, 2.3), (-1.9, 1.6)], -1.2, 1.2, "paint", bevel=0.05)
    p.box((0, 2.74, 0.3), (2.0, 0.05, 2.0), "team", bevel=0.012)
    p.box((0.95, 3.0, 0.7), (0.5, 0.45, 0.6), "trim", bevel=0.03)  # sensor head
    p.box((0.95, 3.0, 0.38), (0.35, 0.22, 0.05), "light")
    for sx in (-1, 1):
        x = sx * 0.32
        p.cylinder("z", (x, GUN_Y, -1.95), 0.26, 0.5, 12, "trim")
        p.cylinder("z", (x, GUN_Y, -4.0), 0.15, 4.0, 10, "steel")
        p.cylinder("z", (x, GUN_Y, -5.9), 0.2, 0.5, 10, "dark")
        p.cylinder("z", (x, GUN_Y, -5.6), 0.19, 0.08, 10, "weapon")


def details_base(p):
    rivets(p, (-2.2, 1.201, 1.6), (2.2, 1.201, 1.6), 7, UP)


def details_turret(p):
    seam(p, (-0.9, 2.701, -0.4), (0.9, 2.701, -0.4), UP)
    ring(p, (0, 2.701, 0.3), UP, 0.4)


unit.run(__file__, "ord_moat", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 1.5, -1.0), 50),
                   ("80", (0, 26, 4), (0, 1, -1.0), 50),
                   ("close", (-7, 6, -9), (0, 2.0, -1.5), 40)])
