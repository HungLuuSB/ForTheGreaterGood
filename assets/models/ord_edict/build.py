"""Edict (Order artillery emplacement, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_edict/build.py

From its blockout, at the size scale (S-104: footprint 3, 24 x 24 studs,
about 7.5 tall): bigger and more elaborate than the T1 Gauntlet, not a
rescale. Big shapes first: a chamfered slab, a sloped armored emplacement
with a front glacis, diamond buttresses at the corners, team plates on the
side slopes and the glacis, hinged ready-ammo hatches, an ammo bunker with
a cable run to the turret ring and a fire-control cabin with a mast at the
back. The `turret` (yaw, the def's piece; pivot as the blockout): a big
casemate with a sloped front, stacked cheek armor, a large team roof
plate, a sight in the front slope, a rangefinder bar and a louvred bustle, carrying a very long gun with a sleeve, an evacuator and
a slotted muzzle brake (`muzzle` at its mouth). Order reads heavy and clean
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, clamped_cable, glow_strip, louver  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

TURRET_PIVOT = (0.0, 2.6, 1.0)
GY = 4.5  # gun axis height
MUZZLE = (0.0, GY, -19.4)
BODY = octagon(9.0, 2.2, 0.0, 1.0)  # x -9..9, z -8..10
TOP = 0.86  # the body's upper walls slope in to this share


def diamond(cx, cz, r):
    return [(cx, cz - r), (cx + r, cz), (cx, cz + r), (cx - r, cz)]


def build_base(p):
    p.prism_y(octagon(11.7, 1.6), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.99)
    p.prism_y(BODY, 0.6, 1.8, "paint", bevel=0.16)
    p.prism_y(BODY, 1.8, 2.7, "paint", bevel=0.16, top_scale=TOP)
    # front glacis (the blockout's wedge), its edge lit
    p.prism_x([(-10.8, 0.6), (-7.4, 0.6), (-7.4, 2.4), (-8.0, 2.4)], -6.6, 6.6, "paint", bevel=0.12)
    p.box((0, 0.75, -10.84), (11.0, 0.16, 0.06), "light")
    # team plates on the side slopes and the glacis
    for sx in (-1, 1):
        p.obox((sx * 8.42, 2.27, 1.0), (0, 0, 1), (sx * 0.9, 1.26, 0), 7.0, 1.2, 0.06, "team", bevel=0.02)
    p.obox((0, 1.53, -9.42), (1, 0, 0), (0, 2.8, -1.8), 8.0, 1.6, 0.06, "team", bevel=0.02)
    # diamond buttresses on the chamfered corners
    for sx in (-1, 1):
        for cz in (-6.5, 8.5):
            p.prism_y(diamond(sx * 8.1, cz, 1.2), 0.6, 2.5, "paint", bevel=0.1, top_scale=0.55)
    # ready-ammo hatches on the deck, hinged
    for sx in (-1, 1):
        p.box((sx * 5.5, 2.74, -4.9), (1.7, 0.1, 1.7), "trim", bevel=0.03)
        p.cylinder("x", (sx * 5.5, 2.8, -4.05), 0.1, 1.2, 8, "steel")
    # turret ring with a thin running band
    p.cylinder("y", (0, 2.82, 1.0), 5.3, 0.24, 32, "dark")
    p.cylinder("y", (0, 2.66, 1.0), 5.45, 0.06, 32, "light")
    # ammo bunker (back right) with a team roof, a lit door and a feed rail
    p.prism_y(rect(6.8, 8.0, 1.6, 1.3), 2.6, 4.4, "trim", bevel=0.1, top_scale=0.92)
    p.box((6.8, 4.42, 8.0), (2.6, 0.05, 2.0), "team", bevel=0.01)
    p.box((6.8, 3.3, 6.69), (1.4, 0.9, 0.05), "dark")
    p.box((6.8, 3.85, 6.67), (1.4, 0.1, 0.05), "power")
    clamped_cable(p, [(5.6, 2.75, 7.0), (4.6, 2.78, 6.0), (3.6, 2.8, 5.2)], r=0.12)
    # fire-control cabin (back left): window strip, mast, dish-less sensor box
    p.prism_y(rect(-6.8, 8.0, 1.5, 1.3), 2.6, 4.6, "paint", bevel=0.1, top_scale=0.9)
    p.box((-6.8, 4.62, 8.0), (2.3, 0.05, 1.9), "team", bevel=0.01)
    p.box((-6.8, 3.9, 6.69), (2.2, 0.3, 0.05), "light")
    p.cylinder("y", (-7.4, 5.8, 8.4), 0.12, 2.4, 6, "steel")
    p.box((-7.4, 7.1, 8.4), (0.9, 0.5, 0.5), "trim", bevel=0.03)
    p.box((-7.4, 7.1, 8.13), (0.6, 0.2, 0.05), "light")
    # vents, side strips, hazard edge, corner lights, a cable run
    for sx in (-1, 1):
        louver(p, (sx * 9.02, 1.2, -3.0), (0, 0, 1), (sx, 0, 0), 2.6, 0.8, slats=3)
        louver(p, (sx * 9.02, 1.2, 5.0), (0, 0, 1), (sx, 0, 0), 2.6, 0.8, slats=3)
        p.box((sx * 9.03, 1.2, 1.0), (0.05, 0.14, 2.6), "light")
    louver(p, (0, 1.2, 10.02), (1, 0, 0), (0, 0, 1), 4.0, 0.8, slats=3)
    hazard(p, (0, 0.62, -11.2), (1, 0, 0), UP, 9.0, 0.4, stripes=16)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.2, 0.68, sz * 10.2), (0.45, 0.12, 0.45), "light")
    clamped_cable(p, [(-5.4, 2.75, 7.2), (-4.6, 2.78, 6.0), (-3.6, 2.8, 5.2)], r=0.1)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 9.02, 0.85, -5.4), (sx * 9.02, 0.85, 7.4), 12, (sx, 0, 0))
        seam(p, (sx * 9.02, 1.8, -5.6), (sx * 9.02, 1.8, 7.6), (sx, 0, 0))
    seam(p, (-6.6, 1.8, -8.02), (6.6, 1.8, -8.02), (0, 0, -1))
    ring(p, (0, 2.95, 1.0), UP, 4.4)
    rivets(p, (-10.4, 0.601, 11.2), (10.4, 0.601, 11.2), 14, UP)


HOUSE = [(-4.9, 2.8), (5.6, 2.8), (5.6, 5.5), (5.0, 6.1), (-2.0, 6.1), (-4.9, 3.7)]
SLOPE_N = (0.0, 2.9, -2.4)  # the house's sloped front


def build_turret(p):
    p.prism_x(HOUSE, -3.9, 3.9, "paint", bevel=0.16)
    # stacked cheek armor
    for sx in (-1, 1):
        p.obox((sx * 4.15, 4.3, 0.6), (0, 0, 1), (sx, 0.22, 0), 6.4, 2.4, 0.5, "paint", bevel=0.1)
        p.obox((sx * 4.5, 4.1, 1.0), (0, 0, 1), (sx, 0.22, 0), 4.4, 1.4, 0.3, "trim", bevel=0.06)
        glow_strip(p, (sx * 4.66, 4.1, -0.6), (sx * 4.66, 4.1, 2.6), (sx, 0.22, 0), width=0.1)
    p.box((0, 6.17, 1.4), (6.0, 0.06, 5.6), "team", bevel=0.02)
    # sight in the front slope (the blockout's), a rangefinder bar on posts at the back
    p.obox((2.6, 5.4, -2.85), (1, 0, 0), SLOPE_N, 1.2, 0.8, 0.36, "trim", bevel=0.05)
    p.obox((2.6, 5.52, -2.95), (1, 0, 0), SLOPE_N, 0.8, 0.36, 0.06, "light")
    for sx in (-1, 1):
        p.box((sx * 2.0, 6.4, 4.7), (0.3, 0.6, 0.3), "steel")
    p.cylinder("x", (0, 6.9, 4.7), 0.32, 5.2, 10, "trim")
    for sx in (-1, 1):
        p.cylinder("x", (sx * 2.7, 6.9, 4.7), 0.42, 0.4, 10, "dark")
        p.box((sx * 2.7, 6.9, 4.28), (0.3, 0.3, 0.05), "light")
    # bustle: louvres, a grille and an antenna
    louver(p, (-1.8, 4.3, 5.62), (1, 0, 0), (0, 0, 1), 2.6, 1.4)
    p.box((1.8, 4.3, 5.62), (2.4, 1.4, 0.05), "grille")
    antenna(p, (-3.3, 6.1, 4.6), 2.2)
    # mantlet, very long gun, evacuator, slotted muzzle brake
    p.box((0, GY, -4.3), (2.8, 2.0, 1.8), "trim", bevel=0.14)
    p.ocyl((0, GY, -5.1), (0, 0, -1), 0.82, 2.6, 16, "trim")  # sleeve
    p.ocyl((0, GY, -5.1), (0, 0, -1), 0.55, 13.0, 16, "paint")
    p.ocyl((0, GY, -10.0), (0, 0, -1), 0.78, 1.8, 16, "paint")  # evacuator
    for z in (-7.9, -12.6, -15.4):
        p.ocyl((0, GY, z), (0, 0, -1), 0.6, 0.14, 16, "steel")
    p.ocyl((0, GY, -16.9), (0, 0, -1), 0.62, 0.16, 16, "weapon")
    p.box((0, GY, -18.6), (1.6, 1.3, 1.5), "dark", bevel=0.08)
    for z in (-18.2, -18.9):
        for sx in (-1, 1):
            p.box((sx * 0.81, GY, z), (0.05, 0.9, 0.3), "grille")
    p.ocyl((0, GY, -19.35), (0, 0, -1), 0.4, 0.04, 14, "dark")


def details_turret(p):
    for sx in (-1, 1):
        seam(p, (sx * 3.91, 3.2, -4.6), (sx * 3.91, 3.2, 5.5), (sx, 0, 0))
    seam(p, (-3.6, 6.11, -1.6), (3.6, 6.11, -1.6), UP)
    ring(p, (0, 6.205, 2.0), UP, 0.6)
    for sx in (-1, 1):
        rivets(p, (sx * 4.42, 5.2, -1.8), (sx * 4.42, 5.2, 3.2), 6, (sx, 0.22, 0))


unit.run(__file__, "ord_edict", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-34, 26, -40), (0, 3.0, -3.0), 50),
                   ("80", (0, 58, 9), (0, 2, -3.0), 50),
                   ("close", (-17, 13, -20), (0, 4.0, -4.0), 38)])
