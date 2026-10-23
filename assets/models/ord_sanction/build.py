"""Sanction (Order missile battery, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sanction/build.py

New mesh at the T2 defense size (S-104: footprint 3, 24 x 24 studs, about
9 tall), no blockout before it (the sim's S-106). Big shapes first: a
chamfered slab, an armored octagonal emplacement with sloped walls, team
plates and buttresses, ammo bunkers at the back with a reload rail, a
glowing turret ring; the `launcher` (the def turns it, M-3): a heavy
armored launcher house on a turntable with a sloped front, a large team
roof, two big missile cells with glowing ready lights (2-missile salvo;
`muzzle` at the left cell), a fire-control radar head and side armor.
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

PIVOT = (0.0, 3.6, 0.0)
CELL_Y = 6.0
MUZZLE = (-1.4, CELL_Y, -4.05)


def build_base(p):
    p.prism_y(octagon(11.6, 1.4), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.99)
    hazard(p, (0, 0.62, -10.8), (1, 0, 0), UP, 8.0, 0.5, stripes=14)
    p.prism_y(octagon(7.6, 2.0), 0.6, 2.4, "paint", bevel=0.18)
    p.prism_y(octagon(7.6, 2.0), 2.4, 3.5, "paint", bevel=0.18, top_scale=0.8)
    for sx in (-1, 1):
        p.obox((sx * 6.7, 2.95, 0), (0, 0, 1), (sx * 1.1, 1.0, 0), 5.0, 1.3, 0.06, "team", bevel=0.02)
        p.box((sx * 7.62, 1.5, 0), (0.05, 0.16, 6.0), "light")
        for sz in (-1, 1):  # buttresses
            p.prism_y(rect(sx * 7.6, sz * 5.2, 1.0, 1.0), 0.6, 2.6, "paint", bevel=0.1, top_scale=0.6)
    p.cylinder("y", (0, 3.55, 0), 3.7, 0.12, 28, "light")  # turret ring
    # ammo bunkers at the back with a reload rail
    for sx in (-1, 1):
        p.prism_y(rect(sx * 3.4, 9.0, 2.0, 1.4), 0.6, 2.4, "trim", bevel=0.1)
        p.box((sx * 3.4, 2.44, 9.0), (3.2, 0.05, 2.0), "team", bevel=0.015)
        p.box((sx * 3.4, 1.6, 7.58), (2.4, 0.3, 0.05), "power")
    p.box((0, 2.6, 7.4), (1.2, 0.5, 4.0), "steel", bevel=0.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 0.66, sz * 11.0), (0.5, 0.12, 0.5), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 7.62, 1.0, -4.0), (sx * 7.62, 1.0, 4.0), 9, (sx, 0, 0))
    seam(p, (-5.0, 3.501, 3.0), (5.0, 3.501, 3.0), UP)


def build_launcher(p):
    p.cylinder("y", (0, 3.8, 0), 3.4, 0.4, 28, "trim", bevel=0.05)  # turntable
    # launcher house: sloped front, team roof, side armor
    p.prism_y([(-3.0, -3.4), (3.0, -3.4), (3.6, -2.6), (3.6, 3.2), (-3.6, 3.2), (-3.6, -2.6)], 4.0, 7.9, "paint",
              bevel=0.14, top_scale=0.94)
    p.box((0, 7.94, 0.4), (5.4, 0.06, 4.8), "team", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 3.62, 5.6, 0.2), (0.06, 2.2, 5.0), "trim", bevel=0.02)
        p.box((sx * 3.66, 6.9, 0.2), (0.05, 0.14, 5.4), "light")
    # two big missile cells with ready lights
    for sx in (-1, 1):
        x = sx * 1.4
        p.box((x, CELL_Y, -3.42), (2.2, 2.2, 0.08), "dark")
        p.cylinder("z", (x, CELL_Y, -3.5), 0.85, 0.1, 18, "steel")
        p.cylinder("z", (x, CELL_Y, -3.56), 0.55, 0.04, 16, "weapon")
    hazard(p, (0, 4.6, -3.45), (1, 0, 0), (0, 0, -1), 5.4, 0.5, stripes=12)
    # fire-control radar head on the roof
    p.box((2.2, 8.4, 1.6), (1.4, 0.9, 1.2), "trim", bevel=0.05)
    p.box((2.2, 8.4, 0.98), (1.1, 0.5, 0.05), "light")
    p.box((0, 6.0, 3.22), (5.0, 2.0, 0.05), "grille")


def details_launcher(p):
    ring(p, (0, 7.941, 0.4), UP, 1.2)
    for sx in (-1, 1):
        rivets(p, (sx * 3.66, 4.6, -2.0), (sx * 3.66, 4.6, 2.6), 6, (sx, 0, 0))


unit.run(__file__, "ord_sanction", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.5, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 5.0, -1.0), 40)])
