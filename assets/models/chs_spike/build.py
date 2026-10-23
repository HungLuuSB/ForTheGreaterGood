"""Spike (Chaos gun turret, T1 structure, footprint 2): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_spike/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
about 5 tall), not rescaled. Big shapes first: a slab, a round emplacement
ringed with reactive blocks and lit edges, team plates on the berm, an ammo
crate stack with a feed chute; a squat rotating turret (`turret`, the def's
piece) with a slab gun shield, a team roof, an ammo box and belt, a sensor
mast with a lamp, and twin barrels with muzzle rings (`muzzle` between
them). Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

TURRET_PIVOT = (0.0, 2.6, 0.0)
MUZZLE = (0.0, 3.6, -8.6)


def build_base(p):
    p.prism_y(octagon(7.8, 0.7), 0.0, 0.6, "dark", bevel=0.1, top_scale=0.985)
    p.cylinder("y", (0, 1.2, 0), 5.0, 1.2, 24, "paint", bevel=0.08)
    for i in range(10):
        a = math.radians(-90 + i * 36)
        c, s = math.cos(a), math.sin(a)
        p.obox((c * 5.05, 1.35, s * 5.05), (-s, 0, c), (c, 0, s), 2.6, 1.3, 0.5, "era", bevel=0.04)
        p.obox((c * 5.32, 1.85, s * 5.32), (-s, 0, c), (c, 0, s), 1.8, 0.26, 0.04, "light")
    for sx in (-1, 1):
        p.box((sx * 2.4, 1.83, 3.6), (2.4, 0.05, 1.2), "team", bevel=0.012)
    p.cylinder("y", (0, 2.1, 0), 2.6, 0.9, 18, "trim")
    p.cylinder("y", (0, 2.58, 0), 2.9, 0.08, 18, "steel")
    # ammo crate stack and a feed chute (back right)
    for k, (dx, dy) in enumerate(((0, 0), (0.2, 1.0), (-0.1, 2.0))):
        p.box((5.6 + dx, 1.1 + dy, 5.2), (1.8, 0.9, 1.4), "trim", bevel=0.05)
    p.box((5.6, 1.2, 4.48), (1.2, 0.3, 0.05), "power")
    p.cylinder("y", (0, 2.3, 0), 2.62, 0.16, 18, "power")
    cable(p, [(4.8, 2.6, 4.6), (3.0, 2.8, 2.4), (2.0, 2.6, 1.4)], r=0.18, kind="steel")
    hazard(p, (-2.0, 0.62, -6.9), (1, 0, 0), (0, 1, 0), 5.0, 0.4, stripes=10)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.7, sz * 7.0), (0.35, 0.2, 0.35), "light")


def build_turret(p):
    p.cylinder("y", (0, 3.4, 0.4), 2.6, 1.6, 18, "paint", radius2=2.3, bevel=0.06)
    p.box((0, 4.23, 0.6), (3.0, 0.05, 2.8), "team", bevel=0.015)
    # slab gun shield, angled
    p.obox((0, 3.7, -2.1), (1, 0, 0), (0, 0.3, -1), 4.4, 2.2, 0.35, "era", bevel=0.06)
    p.obox((0, 3.6, -2.3), (1, 0, 0), (0, 0.3, -1), 1.6, 0.8, 0.1, "dark")
    # ammo box with a belt and a ready light
    p.box((2.4, 3.3, 1.6), (1.2, 1.1, 1.4), "trim", bevel=0.05)
    p.box((3.02, 3.3, 1.6), (0.05, 0.3, 0.9), "weapon")
    cable(p, [(2.0, 3.6, 0.9), (1.2, 3.7, -0.6), (0.6, 3.6, -1.6)], r=0.12)
    # sensor mast with a lamp
    p.cylinder("y", (-1.6, 4.9, 0.8), 0.1, 1.6, 6, "steel")
    p.box((-1.6, 5.75, 0.8), (0.6, 0.4, 0.5), "dark")
    p.box((-1.6, 5.75, 0.53), (0.45, 0.25, 0.05), "light")
    # twin barrels with collars and muzzle rings
    for sx in (-1, 1):
        x = sx * 0.6
        p.cylinder("z", (x, 3.6, -5.4), 0.28, 6.0, 12, "steel")
        p.cylinder("z", (x, 3.6, -2.8), 0.42, 0.9, 12, "trim")
        p.cylinder("z", (x, 3.6, -8.2), 0.34, 0.6, 12, "dark")
        p.cylinder("z", (x, 3.6, -7.8), 0.33, 0.14, 12, "weapon")


def details_base(p):
    ring(p, (0, 2.551, 0), UP, 2.3)


def details_turret(p):
    ring(p, (0, 4.21, 0.4), UP, 1.4)
    rivets(p, (-1.8, 4.21, -0.4), (1.8, 4.21, -0.4), 5, UP)


unit.run(__file__, "chs_spike", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 3.0, -1.0), 50),
                   ("80", (0, 38, 6), (0, 2, -1.0), 50),
                   ("close", (-11, 9, -14), (0, 3.5, -2.0), 35)])
