"""Bulwark (Order gun turret, T1 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_bulwark/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
about 6 tall), not rescaled. Big shapes first: a chamfered slab, an armored
casemate ring with sloped walls, team plates and buttresses, ammo bunkers
with a feed rail into the turret ring; a heavy turret (`turret`, the def's
piece) with a sloped front, a large team roof, an ammo drum and feed chute,
a sensor head with a lens, and a long gun with an evacuator and a muzzle
brake (`muzzle`). Order reads heavy and clean (M-14). Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

TURRET_PIVOT = (0.0, 3.2, 0.0)
MUZZLE = (0.0, 4.5, -10.6)
HOUSE = [(-2.0, -2.8), (2.0, -2.8), (2.7, -1.6), (2.7, 2.6), (-2.7, 2.6), (-2.7, -1.6)]


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.985)
    p.prism_y(octagon(5.6, 1.6), 0.6, 1.8, "paint", bevel=0.18)
    p.prism_y(octagon(5.6, 1.6), 1.8, 3.0, "paint", bevel=0.18, top_scale=0.78)
    for sx in (-1, 1):  # team plates on the casemate's sides
        p.obox((sx * 5.0, 2.35, 0), (0, 0, 1), (sx, 0.6, 0), 3.4, 0.9, 0.06, "team", bevel=0.02)
        p.box((sx * 5.62, 1.2, 0), (0.05, 0.3, 4.2), "light")
        p.box((0, 1.2, sx * 5.62), (4.2, 0.3, 0.05), "power")
    p.cylinder("y", (0, 3.1, 0), 3.0, 0.2, 24, "dark")  # turret ring
    # buttresses
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = (sx * 4.8, sz * 4.8)
            p.prism_y(rect(c[0], c[1], 0.8, 0.8), 0.6, 2.2, "paint", bevel=0.1, top_scale=0.6)
    # ammo bunkers at the back with a feed rail to the ring
    for sx in (-1, 1):
        p.prism_y(rect(sx * 2.6, 6.2, 1.4, 1.0), 0.6, 2.0, "trim", bevel=0.08)
        p.box((sx * 2.6, 2.04, 6.2), (2.2, 0.05, 1.4), "team")
        p.box((sx * 2.6, 1.4, 5.18), (1.6, 0.3, 0.05), "power")
    p.box((0, 2.2, 4.8), (1.0, 0.5, 3.0), "steel", bevel=0.04)
    hazard(p, (0, 0.62, -6.9), (1, 0, 0), (0, 1, 0), 5.0, 0.4, stripes=10)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.2, 0.68, sz * 7.2), (0.4, 0.1, 0.4), "light")


def build_turret(p):
    p.prism_y(HOUSE, 3.2, 5.3, "paint", bevel=0.16, top_scale=0.88)
    p.prism_x([(-3.0, 3.25), (-1.8, 3.25), (-1.8, 5.25), (-2.7, 4.9)], -2.0, 2.0, "paint", bevel=0.1)  # sloped front
    p.box((0, 5.33, 0.3), (3.8, 0.06, 3.8), "team", bevel=0.02)
    # ammo drum and feed chute on the left
    drum(p, (-3.1, 4.0, 1.0), 0.8, 0.8, "trim", "dark", sides=16)
    p.obox((-2.7, 4.6, -0.2), (0, 0.3, -1), (1, 0, 0), 1.8, 0.4, 0.4, "steel")
    # sensor head on the right with a lens
    p.box((1.8, 5.75, -0.6), (1.1, 0.8, 1.2), "trim", bevel=0.06)
    p.cylinder("z", (1.8, 5.75, -1.25), 0.3, 0.1, 12, "light")
    for sx in (-1, 1):
        p.box((sx * 2.72, 4.4, 0.6), (0.05, 0.3, 3.2), "light")
    p.box((0, 4.75, -2.95), (2.6, 0.2, 0.05), "weapon")
    p.box((0, 4.2, 2.62), (3.6, 1.2, 0.05), "grille")
    # mantlet, long gun, evacuator, muzzle brake
    p.prism_x([(-3.4, 3.8), (-2.6, 3.7), (-2.6, 5.3), (-3.3, 5.1)], -0.9, 0.9, "trim", bevel=0.08)
    p.cylinder("z", (0, 4.5, -6.8), 0.36, 7.0, 16, "paint")
    p.cylinder("z", (0, 4.5, -6.0), 0.48, 1.2, 16, "paint")  # evacuator
    for z in (-4.4, -8.4):
        p.cylinder("z", (0, 4.5, z), 0.39, 0.12, 16, "steel")
    p.cylinder("z", (0, 4.5, -10.1), 0.46, 1.0, 14, "steel")
    p.box((0, 4.5, -10.0), (1.1, 0.3, 0.2), "dark")
    p.cylinder("z", (0, 4.5, -9.55), 0.48, 0.16, 14, "weapon")
    p.box((0, 4.9, -7.0), (0.12, 0.06, 3.6), "weapon")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 5.62, 0.9, -3.2), (sx * 5.62, 0.9, 3.2), 7, (sx, 0, 0))
        seam(p, (sx * 5.62, 1.8, -3.6), (sx * 5.62, 1.8, 3.6), (sx, 0, 0))


def details_turret(p):
    ring(p, (0, 5.331, 0.3), UP, 0.6)
    for sx in (-1, 1):
        rivets(p, (sx * 2.72, 3.6, -1.2), (sx * 2.72, 3.6, 2.2), 5, (sx, 0, 0))


unit.run(__file__, "ord_bulwark", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 3.0, -1.0), 50),
                   ("80", (0, 38, 6), (0, 2, -1.0), 50),
                   ("close", (-11, 9, -14), (0, 3.5, -2.0), 35)])
