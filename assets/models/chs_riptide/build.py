"""Riptide (Chaos floating turret, T1 structure, footprint 1, on water):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_riptide/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 3 above the water), from its blockout. The waterline is y = 0. Big
shapes first: a round float with a strapped buoyancy ring, a deck ringed
with reactive blocks and amber lights, team plates and hazard striping, an
ammo crate; the `turret` (the def's piece): an open single-gun mount with
a slab gun shield, a team plate on the shield, an ammo box with a belt, a
lamp mast and one barrel with a muzzle ring (`muzzle`). Chaos reads rugged
and improvised (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

PIVOT = (0.0, 0.9, 0.0)
GUN_Y = 1.75
MUZZLE = (0.0, GUN_Y, -5.6)


def build_base(p):
    p.cylinder("y", (0, -0.3, 0), 3.7, 1.2, 20, "paint", bevel=0.06)
    p.cylinder("y", (0, -0.1, 0), 3.78, 0.5, 20, "rubber")  # buoyancy ring
    p.cylinder("y", (0, 0.5, 0), 3.3, 0.4, 20, "trim", bevel=0.04)
    for i in range(8):
        a = math.radians(22.5 + i * 45)
        c, s = math.cos(a), math.sin(a)
        if i == 2:
            continue  # the ammo crate's gap
        p.obox((c * 2.85, 0.95, s * 2.85), (-s, 0, c), (c, 0, s), 1.6, 0.6, 0.45, "era", bevel=0.04)
        p.obox((c * 3.09, 1.05, s * 3.09), (-s, 0, c), (c, 0, s), 1.0, 0.12, 0.03, "light")
    p.box((0, 0.72, 1.6), (2.4, 0.05, 1.0), "team", bevel=0.01)
    hazard(p, (0, 0.72, -1.8), (1, 0, 0), UP, 2.0, 0.35, stripes=5)
    p.box((1.1, 1.1, 2.7), (0.9, 0.7, 0.7), "trim", bevel=0.04)  # ammo crate
    p.cylinder("y", (0, 0.78, 0), 1.3, 0.16, 14, "steel")


def build_turret(p):
    p.cylinder("y", (0, 1.05, 0), 1.1, 0.3, 14, "trim")
    p.box((0, 1.6, 0.2), (1.2, 0.8, 1.6), "paint", bevel=0.05)  # breech house
    p.obox((0, 1.85, -0.9), (1, 0, 0), (0, 0.25, -1), 2.6, 1.4, 0.25, "era", bevel=0.05)  # gun shield
    p.obox((0, 1.95, -1.05), (1, 0, 0), (0, 0.25, -1), 1.4, 0.6, 0.05, "team", bevel=0.01)
    p.box((0.95, 1.5, 0.6), (0.6, 0.6, 0.8), "trim", bevel=0.04)  # ammo box
    cable(p, [(0.75, 1.7, 0.2), (0.45, 1.8, -0.3)], r=0.07)
    p.cylinder("y", (-0.8, 2.4, 0.6), 0.05, 1.2, 6, "steel")
    p.box((-0.8, 3.05, 0.6), (0.24, 0.16, 0.24), "light")
    p.cylinder("z", (0, GUN_Y, -1.2), 0.24, 0.6, 12, "trim")
    p.cylinder("z", (0, GUN_Y, -3.3), 0.15, 4.2, 10, "steel")
    p.cylinder("z", (0, GUN_Y, -5.3), 0.2, 0.5, 10, "dark")
    p.cylinder("z", (0, GUN_Y, -5.0), 0.19, 0.08, 10, "weapon")


def details_base(p):
    ring(p, (0, 0.701, 0), UP, 2.6)
    rivets(p, (-1.0, 0.741, 1.15), (1.0, 0.741, 1.15), 5, UP)


unit.run(__file__, "chs_riptide", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", PIVOT, build_turret, lambda p: None)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 1.5, -1.0), 50),
                   ("80", (0, 26, 4), (0, 1, -1.0), 50),
                   ("close", (-7, 6, -9), (0, 2.0, -1.5), 40)])
