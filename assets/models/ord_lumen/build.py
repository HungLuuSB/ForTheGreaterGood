"""Lumen (Order flak tower, T2 structure, footprint 1; S-96): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_lumen/build.py

A sloped armored emplacement and pedestal with a glowing `power` band;
on it the `turret`: an angular gun house with a cyan fire-control sensor
and a small search radar, carrying a twin flak gun either side, laid up at
35 degrees (the def turns only the turret), with jackets, flash hiders and
ready rings (`weapon`). Team plates on the roof and the rear slope. Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

TURRET_PIVOT = (0.0, 3.2, 0.0)
ELEV = math.radians(35)
GUN = (0.0, math.sin(ELEV), -math.cos(ELEV))  # barrel direction
MUZZLES = {"muzzle": (-1.8, 6.02, -3.46), "muzzle2": (1.8, 6.02, -3.46)}
HOUSE = [(-1.2, -1.4), (1.2, -1.4), (1.4, -0.9), (1.4, 1.5), (-1.4, 1.5), (-1.4, -0.9)]


def at(x, t):
    """Point t studs along a barrel starting at (x, 4.3, -1.0)."""
    return (x, 4.3 + GUN[1] * t, -1.0 + GUN[2] * t)


def build_base(p):
    sq = [(-3.3, -3.3), (3.3, -3.3), (3.3, 3.3), (-3.3, 3.3)]
    p.prism_y(sq, 0.0, 0.4, "trim", bevel=0.04)
    p.prism_y([(-2.4, -3.0), (2.4, -3.0), (3.0, -2.4), (3.0, 2.4), (2.4, 3.0), (-2.4, 3.0), (-3.0, 2.4), (-3.0, -2.4)],
              0.4, 1.6, "paint", bevel=0.05, top_scale=0.84)
    p.prism_x([(2.55, 0.75), (2.3, 1.35), (2.05, 1.35), (2.3, 0.75)], -1.3, 1.3, "team")  # rear slope plate
    p.cylinder("y", (0, 2.4, 0), 1.1, 1.6, 16, "dark")
    p.cylinder("y", (0, 2.05, 0), 1.14, 0.3, 16, "power")
    p.cylinder("y", (0, 3.15, 0), 1.35, 0.1, 16, "trim")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 3.15, 0.45, sz * 3.15), (0.3, 0.1, 0.3), "light")
    p.box((0, 1.0, -2.98), (2.4, 0.14, 0.12), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (3.6, 0, 3.6), 1.601)
    for sz in (-1, 1):
        bolts(p, (-2.8, 0.401, sz * 3.15), (2.8, 0.401, sz * 3.15), 7, UP)


def build_turret(p):
    p.prism_y(HOUSE, 3.2, 4.8, "paint", bevel=0.05, top_scale=0.9)
    p.box((0, 4.82, 0.45), (1.7, 0.06, 1.6), "team", bevel=0.015)
    p.box((0, 4.25, -1.42), (1.1, 0.5, 0.06), "light")  # fire-control sensor
    p.box((0, 4.25, -1.38), (1.3, 0.7, 0.04), "dark")
    p.box((0, 5.05, 1.0), (0.12, 0.45, 0.12), "steel")  # search radar mast and face
    p.obox((0, 5.35, 1.0), (1, 0, 0), (0, 0.3, -1), 1.2, 0.5, 0.08, "trim")
    p.obox((0, 5.36, 0.97), (1, 0, 0), (0, 0.3, -1), 1.0, 0.36, 0.06, "light")
    for sx in (-1, 1):
        p.box((sx * 1.8, 4.2, -0.2), (0.8, 1.2, 1.6), "trim", bevel=0.04)  # gun mounts
        p.box((sx * 1.8, 4.3, 0.85), (0.7, 0.7, 0.6), "dark", bevel=0.03)  # ammo feed
        p.box((sx * 2.21, 4.2, -0.2), (0.04, 0.16, 1.2), "light")
        for x in (sx * 1.6, sx * 2.0):
            p.ocyl(at(x, -0.2), GUN, 0.2, 1.2, 10, "paint")  # jacket
            p.ocyl(at(x, 0.0), GUN, 0.13, 3.0, 10, "steel")  # barrel
            p.ocyl(at(x, 2.55), GUN, 0.17, 0.12, 10, "weapon")  # ready ring
            p.ocyl(at(x, 2.7), GUN, 0.18, 0.3, 10, "dark")  # flash hider


def details_turret(p):
    ring(p, (0, 4.801, 0.45), UP, 0.4)
    seam(p, (-1.2, 4.6, -1.36), (1.2, 4.6, -1.36), (0, 0, -1))
    for sx in (-1, 1):
        bolts(p, (sx * 2.21, 4.65, -0.8), (sx * 2.21, 4.65, 0.4), 3, (sx, 0, 0))


unit.run(__file__, "ord_lumen", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={k: {"parent": "turret", "at": list(v)} for k, v in MUZZLES.items()})
