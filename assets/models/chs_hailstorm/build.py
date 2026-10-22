"""Hailstorm (Chaos flak tower, T2 structure, footprint 1; S-96): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_hailstorm/build.py

A squat octagonal plated base with reactive blocks and ammo crates, a
pedestal with a glowing `power` collar; on it the round `turret`: a slab
shield leaning forward, three lighter flak guns in a row laid up at 40
degrees behind it (ready rings on `weapon`), a side ammo drum and an amber
spotter eye. Team plates on the base and the turret roof. Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

TURRET_PIVOT = (0.0, 2.6, 0.0)
ELEV = math.radians(40)
GUN = (0.0, math.sin(ELEV), -math.cos(ELEV))
MUZZLES = {"muzzle": (-0.9, 5.57, -3.19), "muzzle2": (0.0, 5.57, -3.19), "muzzle3": (0.9, 5.57, -3.19)}
SLAB_N = (0.0, math.sin(math.radians(20)), math.cos(math.radians(20)))  # leaning forward 20 degrees


def at(x, t):
    """Point t studs along a barrel starting at (x, 3.9, -1.2)."""
    return (x, 3.9 + GUN[1] * t, -1.2 + GUN[2] * t)


def octagon(h, c):
    return [(-h + c, -h), (h - c, -h), (h, -h + c), (h, h - c), (h - c, h), (-h + c, h), (-h, h - c), (-h, -h + c)]


def build_base(p):
    p.prism_y(octagon(3.3, 1.0), 0.0, 0.4, "trim", bevel=0.04)
    p.prism_y(octagon(3.05, 0.9), 0.4, 1.4, "paint", bevel=0.05, top_scale=0.92)
    for sx in (-1, 1):  # reactive blocks
        for z in (-1.0, 1.0):
            p.box((sx * 3.02, 0.95, z), (0.26, 0.7, 1.4), "era", bevel=0.02)
        p.box((sx * 3.16, 0.95, 0), (0.05, 0.14, 0.5), "light")
    p.box((-2.0, 1.9, 1.5), (1.4, 1.0, 1.2), "trim", bevel=0.04)  # ammo crates
    p.box((2.1, 1.8, 1.3), (1.2, 0.8, 1.4), "trim", bevel=0.04)
    p.box((2.1, 2.21, 1.3), (1.0, 0.04, 0.3), "hazard")
    p.box((0, 1.42, 2.3), (2.2, 0.06, 0.8), "team", bevel=0.015)
    p.cylinder("y", (0, 2.0, 0), 1.2, 1.2, 14, "dark")
    p.cylinder("y", (0, 1.65, 0), 1.24, 0.3, 14, "power")
    p.box((0, 0.9, -2.85), (1.8, 0.14, 0.1), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (3.4, 0, 3.4), 1.401)
    for sx in (-1, 1):
        bolts(p, (sx * 3.15, 0.401, -1.8), (sx * 3.15, 0.401, 1.8), 5, UP)


def build_turret(p):
    p.cylinder("y", (0, 3.2, 0.2), 1.7, 1.2, 14, "paint")
    p.cylinder("y", (0, 3.82, 0.2), 1.5, 0.06, 14, "trim")
    p.box((0, 3.86, 0.9), (1.4, 0.06, 1.0), "team", bevel=0.015)
    p.obox((0, 3.9, -1.3), (1, 0, 0), SLAB_N, 3.4, 1.4, 0.4, "paint", bevel=0.04)  # slab shield
    p.obox((0, 3.42, -1.45), (1, 0, 0), SLAB_N, 3.2, 0.12, 0.42, "light")
    p.cylinder("x", (-1.85, 3.3, 0.4), 0.55, 0.5, 12, "trim")  # ammo drum
    p.cylinder("x", (-2.12, 3.3, 0.4), 0.3, 0.06, 12, "hazard")
    p.cylinder("y", (1.2, 3.95, 1.0), 0.3, 0.3, 10, "dark")  # spotter eye
    p.ocyl((1.2, 4.0, 1.0), (0, 0.5, -1), 0.24, 0.22, 10, "light")
    for x in (-0.9, 0.0, 0.9):
        p.ocyl(at(x, -0.1), GUN, 0.2, 0.9, 10, "dark")  # breech jacket
        p.ocyl(at(x, 0.0), GUN, 0.13, 2.6, 10, "steel")
        p.ocyl(at(x, 2.1), GUN, 0.17, 0.12, 10, "weapon")  # ready ring
        p.ocyl(at(x, 2.3), GUN, 0.17, 0.3, 10, "dark")


def details_turret(p):
    ring(p, (0, 3.891, 0.9), UP, 0.35)
    seam(p, (-1.5, 3.81, -0.3), (1.5, 3.81, -0.3), UP)
    bolts(p, (-1.5, 4.4, -1.47), (1.5, 4.4, -1.47), 6, (0, 0.34, -0.94))


unit.run(__file__, "chs_hailstorm", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={k: {"parent": "turret", "at": list(v)} for k, v in MUZZLES.items()})
