"""Bulwark (Order gun turret, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_bulwark/build.py

A stepped armored emplacement with sloped walls and a turret ring; on it the
`turret`: an angular gun house with a sloped front, a long gun with a muzzle
brake and a sight (the weapon turns the turret; the gun has no pitch piece).
Team plates on the roof and the emplacement walls (BAR style, M-15; Order
reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

TURRET_PIVOT = (0.0, 2.3, 0.0)
MUZZLE = (0.0, 3.15, -7.45)
HOUSE = [(-1.5, -1.9), (1.5, -1.9), (1.95, -1.2), (1.95, 2.0), (-1.95, 2.0), (-1.95, -1.2)]


def build_base(p):
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.4, "trim", bevel=0.04)
    p.prism_y([(-3.4, -3.4), (3.4, -3.4), (3.4, 3.4), (-3.4, 3.4)], 0.4, 2.1, "paint", bevel=0.06, top_scale=0.74)
    for sz in (-1, 1):
        p.prism_x([(sz * 3.05, 0.9), (sz * 2.85, 0.9), (sz * 2.65, 1.6), (sz * 2.85, 1.6)], -1.6, 1.6, "team")
    p.cylinder("y", (0, 2.2, 0), 2.0, 0.2, 16, "dark")
    for sx in (-1, 1):  # wall-top running strips
        p.box((sx * 2.6, 2.05, 0), (0.12, 0.08, 4.6), "light")
    for sx in (-1, 1):
        p.box((sx * 3.5, 0.45, 3.5), (0.3, 0.12, 0.3), "light")
        p.box((sx * 3.5, 0.45, -3.5), (0.3, 0.12, 0.3), "light")


def build_turret(p):
    p.prism_y(HOUSE, 2.3, 3.85, "paint", bevel=0.06, top_scale=0.92)
    p.prism_x([(-1.9, 2.35), (-1.2, 2.35), (-1.2, 3.8), (-1.75, 3.6)], -1.4, 1.4, "paint", bevel=0.04)  # brow
    p.box((0, 3.88, 0.4), (2.8, 0.06, 2.4), "team", bevel=0.015)
    p.box((1.2, 4.05, -0.6), (0.55, 0.35, 0.55), "trim", bevel=0.03)
    p.box((1.2, 4.06, -0.885), (0.44, 0.2, 0.04), "light")
    p.box((0, 3.0, 2.06), (2.4, 0.9, 0.12), "grille")
    p.box((0, 3.4, 2.07), (2.2, 0.14, 0.05), "light")  # rear sensor strip
    for sx in (-1, 1):  # side sensor strips
        p.box((sx * 1.95, 3.3, 0.4), (0.05, 0.14, 2.6), "light")
    # mantlet, gun, evacuator, brake
    p.box((0, 3.15, -2.2), (1.1, 0.85, 0.6), "trim", bevel=0.05)
    p.cylinder("z", (0, 3.15, -4.6), 0.25, 4.4, 14, "paint")
    p.cylinder("z", (0, 3.15, -4.1), 0.33, 0.7, 14, "paint")
    for z in (-3.0, -5.6):
        p.cylinder("z", (0, 3.15, z), 0.27, 0.08, 14, "steel")
    p.cylinder("z", (0, 3.15, -7.05), 0.32, 0.8, 12, "steel")
    p.box((0, 3.15, -7.0), (0.8, 0.2, 0.14), "dark")
    p.cylinder("z", (0, 3.15, -6.6), 0.34, 0.14, 12, "weapon")  # brake ring
    p.box((0, 3.44, -5.0), (0.09, 0.05, 2.4), "weapon")


def details_base(p):
    box_seams(p, (0, 0, 0), (5.0, 0, 5.0), 2.101)
    bolts(p, (-3.4, 0.401, -3.55), (3.4, 0.401, -3.55), 8, UP)
    bolts(p, (-3.4, 0.401, 3.55), (3.4, 0.401, 3.55), 8, UP)


def details_turret(p):
    ring(p, (0, 3.851, 0.4), UP, 0.5)
    seam(p, (-1.7, 3.851, -1.1), (1.7, 3.851, -1.1), UP)
    for sx in (-1, 1):
        bolts(p, (sx * 1.85, 3.5, -1.0), (sx * 1.85, 3.5, 1.8), 4, (sx, 0, 0))


unit.run(__file__, "ord_bulwark", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}})
