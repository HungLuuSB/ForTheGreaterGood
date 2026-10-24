"""Rampart (Order coastal battery, T2 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_rampart/build.py

From its blockout, at the size scale (S-104: footprint 3, 24 x 24 studs,
about 7 tall): bigger and more elaborate than the T1 turrets, not a
rescale. Big shapes first: a chamfered slab, a heavy sea-wall bunker with
a recurved wave-return front (embrasure slots and a lit sensor line), two
corner bastions with searchlights (the blockout's lights), large team
plates on the deck either side of the ring, a magazine hatch and vents at
the back, a radio mast on the rear corner (outside the guns' sweep). The
`turret` (yaw, the def's piece; pivot as the blockout): a broad casemate
with a sloped front, cheek armor, a large team roof plate, a naval
rangefinder whose hooded ends stand out past the sides, a small fire-
control array, and twin long guns with sleeves, evacuators and muzzle
brakes (`muzzle` at the left gun's mouth, as the blockout). Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, clamped_cable, glow_strip, louver  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

TURRET_PIVOT = (0.0, 3.5, 1.0)
GY = 4.8  # gun axis height
GX = 1.6  # guns either side
MUZZLE = (-GX, GY, -14.1)
DECK = 3.2  # bunker roof height
WALL = [(-10.8, 0.5), (-9.7, 1.3), (-8.6, 2.2), (-7.6, 2.9), (-6.9, 3.4), (-6.3, 3.4), (-6.3, 0.5)]  # (z, y)


def build_base(p):
    p.prism_y(octagon(11.7, 1.2), 0.0, 0.5, "trim", bevel=0.12, top_scale=0.99)
    p.prism_y(rect(0, 2.0, 10.0, 8.3), 0.5, 2.5, "paint", bevel=0.16)
    p.prism_y(rect(0, 2.0, 10.0, 8.3), 2.5, DECK, "paint", bevel=0.16, top_scale=0.95)
    # the recurved sea wall, embrasure slots and a lit sensor line
    p.prism_x(WALL, -9.6, 9.6, "paint", bevel=0.12)
    for x in (-6.0, -2.0, 2.0, 6.0):
        p.obox((x, 2.01, -8.85), (1, 0, 0), (0, 1.1, -0.9), 2.2, 0.5, 0.06, "dark")
    p.obox((0, 2.63, -8.01), (1, 0, 0), (0, 1.0, -0.7), 14.0, 0.12, 0.05, "light")
    # corner bastions with searchlights
    for sx in (-1, 1):
        p.prism_y(octagon(1.8, 0.6, sx * 8.4, -4.4), DECK - 0.2, 3.7, "paint", bevel=0.1, top_scale=0.86)
        p.box((sx * 8.4, 3.72, -4.0), (2.2, 0.05, 1.6), "team", bevel=0.01)
        p.box((sx * 8.4, 3.92, -5.1), (0.9, 0.4, 0.7), "trim", bevel=0.04)
        p.box((sx * 8.4, 3.92, -5.46), (0.6, 0.24, 0.05), "head")
    # large team plates on the deck either side of the ring
    for sx in (-1, 1):
        p.box((sx * 7.2, DECK + 0.03, 3.6), (3.8, 0.06, 6.4), "team", bevel=0.02)
    # turret ring with a running band
    p.cylinder("y", (0, 3.35, 1.0), 5.0, 0.3, 32, "dark")
    p.cylinder("y", (0, DECK + 0.02, 1.0), 5.15, 0.04, 32, "light")
    # magazine hatch and vents at the back, a rail along the rear edge
    p.box((0, DECK + 0.06, 8.4), (3.6, 0.12, 2.0), "trim", bevel=0.04)
    hazard(p, (0, DECK + 0.13, 8.4), (1, 0, 0), UP, 3.0, 0.3, stripes=8)
    for sx in (-1, 1):
        p.cylinder("y", (sx * 3.6, DECK + 0.35, 8.6), 0.45, 0.7, 10, "trim")
        p.cylinder("y", (sx * 3.6, DECK + 0.75, 8.6), 0.6, 0.12, 10, "dark")
    for x in (-9.4, -6.0, -2.6, 2.6, 6.0, 9.4):
        p.box((x, DECK + 0.45, 10.0), (0.14, 0.9, 0.14), "steel")
    for sx in (-1, 1):
        p.box((sx * 6.0, DECK + 0.85, 10.0), (6.8, 0.1, 0.1), "steel")
    # sides: vents, running strips; the front slab edge striped
    for sx in (-1, 1):
        louver(p, (sx * 10.02, 1.6, 0.0), (0, 0, 1), (sx, 0, 0), 3.0, 1.0, slats=3)
        louver(p, (sx * 10.02, 1.6, 6.0), (0, 0, 1), (sx, 0, 0), 3.0, 1.0, slats=3)
        p.box((sx * 10.03, 1.0, 3.0), (0.05, 0.14, 2.4), "light")
    louver(p, (-5.0, 1.6, 10.32), (1, 0, 0), (0, 0, 1), 3.0, 1.0, slats=3)
    p.box((4.0, 1.6, 10.32), (2.0, 2.0, 0.05), "dark")  # magazine door
    p.box((4.0, 2.75, 10.33), (2.0, 0.12, 0.05), "light")
    hazard(p, (0, 0.52, -11.3), (1, 0, 0), UP, 9.0, 0.36, stripes=16)
    # cable box on the rear corner
    p.box((10.2, 0.9, 10.2), (1.0, 0.8, 1.0), "trim", bevel=0.04)
    for sx in (-1, 1):
        p.box((sx * 10.6, 0.56, -10.0), (0.4, 0.12, 0.4), "light")
    clamped_cable(p, [(10.2, 1.3, 9.7), (9.9, 2.2, 9.4), (9.4, DECK, 8.2)], r=0.09)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 10.02, 0.8, -5.6), (sx * 10.02, 0.8, 9.6), 12, (sx, 0, 0))
        seam(p, (sx * 10.02, 2.5, -5.6), (sx * 10.02, 2.5, 9.8), (sx, 0, 0))
    ring(p, (0, 3.51, 1.0), UP, 4.4)
    seam(p, (-9.6, 2.9, -7.64), (9.6, 2.9, -7.64), (0, 1, -0.7))
    seam(p, (-9.6, 1.3, -9.74), (9.6, 1.3, -9.74), (0, 1, -0.8))


HOUSE = [(-4.2, 3.6), (4.9, 3.6), (4.9, 5.7), (4.4, 6.2), (-2.0, 6.2), (-4.2, 4.4)]


def build_turret(p):
    p.prism_x(HOUSE, -4.6, 4.6, "paint", bevel=0.16)
    for sx in (-1, 1):
        p.obox((sx * 4.85, 4.6, 0.4), (0, 0, 1), (sx, 0.18, 0), 5.6, 1.8, 0.45, "paint", bevel=0.08)
        glow_strip(p, (sx * 5.09, 4.25, -1.6), (sx * 5.09, 4.25, 2.4), (sx, 0.18, 0), width=0.1)
    p.box((0, 6.23, 1.6), (7.0, 0.06, 4.6), "team", bevel=0.02)
    # naval rangefinder across the back, hooded ends past the sides
    for sx in (-1, 1):
        p.box((sx * 3.2, 6.45, 4.3), (0.4, 0.5, 0.4), "steel")
    p.cylinder("x", (0, 6.95, 4.3), 0.36, 11.0, 12, "trim")
    for sx in (-1, 1):
        p.box((sx * 5.6, 6.95, 4.2), (0.7, 0.9, 1.0), "paint", bevel=0.06)
        p.box((sx * 5.6, 6.95, 3.68), (0.45, 0.4, 0.05), "light")
    # fire-control array on a post (front left): unlit face, glowing edge
    p.box((-2.6, 6.6, -0.8), (0.3, 0.8, 0.3), "steel")
    p.obox((-2.6, 7.3, -0.9), (1, 0, 0), (0, 0.3, -1), 1.6, 0.9, 0.14, "trim", bevel=0.02)
    p.obox((-2.6, 7.32, -0.98), (1, 0, 0), (0, 0.3, -1), 1.4, 0.7, 0.02, "dark")
    for b in (-0.37, 0.37):
        p.obox((-2.6, 7.32 + b * 0.96, -0.98 + b * 0.29), (1, 0, 0), (0, 0.3, -1), 1.4, 0.06, 0.03, "light")
    # bustle louvres and an antenna
    louver(p, (-2.2, 4.6, 4.92), (1, 0, 0), (0, 0, 1), 3.0, 1.4)
    louver(p, (2.2, 4.6, 4.92), (1, 0, 0), (0, 0, 1), 3.0, 1.4)
    antenna(p, (3.6, 6.2, 2.8), 2.0)
    # twin long guns: mantlets, sleeves, evacuators, brakes, ready rings
    for sx in (-1, 1):
        x = sx * GX
        p.box((x, GY, -3.9), (1.6, 1.7, 1.4), "trim", bevel=0.1)
        p.ocyl((x, GY, -4.5), (0, 0, -1), 0.62, 2.0, 14, "trim")
        p.ocyl((x, GY, -4.5), (0, 0, -1), 0.42, 8.8, 14, "paint")
        p.ocyl((x, GY, -8.4), (0, 0, -1), 0.58, 1.2, 14, "paint")
        for z in (-7.0, -10.6):
            p.ocyl((x, GY, z), (0, 0, -1), 0.46, 0.12, 14, "steel")
        p.ocyl((x, GY, -12.0), (0, 0, -1), 0.48, 0.14, 14, "weapon")
        p.ocyl((x, GY, -13.25), (0, 0, -1), 0.58, 0.8, 14, "dark")
        p.ocyl((x, GY, -14.06), (0, 0, -1), 0.3, 0.03, 12, "dark")


def details_turret(p):
    for sx in (-1, 1):
        seam(p, (sx * 4.61, 3.9, -4.0), (sx * 4.61, 3.9, 4.8), (sx, 0, 0))
        rivets(p, (sx * 5.1, 5.35, -2.0), (sx * 5.1, 5.35, 2.8), 6, (sx, 0.18, 0))
    seam(p, (-4.3, 6.21, -1.5), (4.3, 6.21, -1.5), UP)
    ring(p, (0, 6.265, 1.6), UP, 0.7)


unit.run(__file__, "ord_rampart", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-34, 26, -40), (0, 3.0, -2.0), 50),
                   ("80", (0, 58, 9), (0, 2, -2.0), 50),
                   ("close", (-17, 13, -20), (0, 4.0, -3.0), 38)])
