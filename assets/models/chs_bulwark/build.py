"""Bulwark (Chaos beam tower, T2 structure, footprint 3; S-157, Inferno's
replacement): mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_bulwark/build.py

From its approved blockout v3 (the user's reference 2026-10-24: the weapons
stacked on top of each other, each turning on its own). Big shapes first: a
heavy buttressed base with reactive blocks, a glowing vent, two power drums
at the back and a round plinth. Tier 1, the `laser` ring (yaw): a full-width
armored ring with plates and a team panel; on its front the `laser_mount`
(pitch, -60..+60 degrees) holds the `laser_drum`, three green laser barrels
in a triangle that the client turns 120 degrees per shot (`laser_muzzle1`
on top at rest). Tier 2, the `shell`: a static armored collar. Tier 3, the
beam `turret` (yaw): a heavy head with a single big eye lens, a team plate
and a heat sink; its `barrel` (pitch) the long beam emitter, `muzzle` at
its tip. Off, the head sinks onto the collar and the barrel folds down.
Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import cable, hazard, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

LY = 5.6  # the laser ring's pivot height
DY, DZ, R = LY + 1.5, -4.9, 0.7  # the laser drum's axis and its barrels' distance from it
TY = LY + 5.2  # the beam head's pivot height
BARREL = (-0.8, LY + 6.9, -2.5)
MUZZLE = (-0.8, LY + 6.9, -10.0)


def lat(k, z):
    a = math.radians(90 + (k - 1) * 120)
    return (R * math.cos(a), DY + R * math.sin(a), z)


def build_base(p):
    p.prism_y(rect(0, 0, 8.0, 8.0), 0.0, 4.0, "dark", bevel=0.12)
    for sx in (-1, 1):
        p.prism_x([(-8.0, 0.0), (-10.4, 0.0), (-8.0, 4.0)], sx * 6.4 - 1.5, sx * 6.4 + 1.5, "paint", bevel=0.08)  # buttresses
        p.box((sx * 8.3, 2.6, -1.0), (0.6, 2.4, 7.0), "era", bevel=0.06)
        p.cylinder("y", (sx * 5.2, 6.0, 5.6), 1.6, 4.0, 18, "steel", bevel=0.05)
        p.cylinder("y", (sx * 5.2, 8.05, 5.6), 1.3, 0.1, 18, "power")
    p.box((0, 2.2, -8.06), (4.0, 2.4, 0.12), "grille")
    p.box((0, 2.2, -8.02), (3.6, 2.0, 0.06), "power")
    p.box((0, 4.04, 6.4), (4.6, 0.05, 2.4), "team", bevel=0.01)
    hazard(p, (0, 4.03, -7.4), (1, 0, 0), UP, 10.0, 0.6, stripes=20)
    p.cylinder("y", (0, 4.8, 0), 4.8, 1.6, 32, "paint", bevel=0.06)
    cable(p, [(-5.2, 4.2, 4.4), (-3.6, 4.4, 2.6), (-2.0, 5.2, 1.6)], r=0.16, kind="dark")
    skirt_square(p, 8.0, h=0.4, flare=0.7, bolts=10)
    for sx in (-1, 1):
        louver(p, (sx * 4.4, 2.2, 8.02), (1, 0, 0), (0, 0, 1), 2.4, 1.6)
        glow_strip(p, (sx * 7.0, 0.6, -8.03), (sx * 7.0, 3.4, -8.03), (0, 0, -1), width=0.14)
    clamped_cable(p, [(5.2, 4.2, 4.4), (3.6, 4.4, 2.6), (2.0, 5.2, 1.6)], r=0.14)


def details_base(p):
    band_box(p, 2.0, 0, 0, 8.0, 8.0)
    band_round(p, 4.4, 4.8)
    rivets(p, (-7.0, 4.01, -6.0), (7.0, 4.01, -6.0), 12, UP)
    ring(p, (0, 5.61, 0), UP, 3.6)


def build_laser(p):
    p.cylinder("y", (0, LY + 1.5, 0), 4.4, 3.0, 32, "paint", bevel=0.08)
    for sx in (-1, 1):
        p.box((sx * 4.5, LY + 1.5, 0.6), (0.5, 2.4, 4.0), "era", bevel=0.05)
    p.box((0, LY + 1.5, 4.42), (2.8, 1.2, 0.06), "team", bevel=0.01)
    p.box((2.0, LY + 2.4, -4.3), (0.5, 0.4, 0.3), "head")
    p.cylinder("y", (0, LY + 2.95, 0), 4.2, 0.1, 32, "trim")


def details_laser(p):
    seam(p, (-3.6, LY + 1.0, -2.4), (3.6, LY + 1.0, -2.4), (0, 0, -1))


def build_laser_mount(p):
    p.box((0, DY, -4.2), (2.6, 2.6, 1.4), "dark", bevel=0.08)


def details_laser_mount(p):
    ring(p, (0, DY + 1.31, -4.2), UP, 0.5)


def build_laser_drum(p):
    p.cylinder("z", (0, DY, DZ), 1.2, 1.0, 16, "steel", bevel=0.04)
    for k in (1, 2, 3):
        p.ocyl(lat(k, DZ - 0.4), (0, 0, -1), 0.28, 3.4, 12, "steel")
        p.ocyl(lat(k, DZ - 2.4), (0, 0, -1), 0.36, 0.3, 12, "dark")
        p.ocyl(lat(k, DZ - 3.7), (0, 0, -1), 0.22, 0.1, 12, "weapon")


def details_laser_drum(p):
    ring(p, (0, DY, DZ - 0.51), (0, 0, -1), 0.4)


def build_shell(p):
    p.prism_y(rect(0, 0.2, 3.6, 3.6), LY + 3.0, LY + 5.2, "dark", bevel=0.1, top_scale=0.94)
    p.cylinder("y", (0, LY + 3.3, 0), 4.0, 0.6, 32, "steel")
    for sx in (-1, 1):
        p.box((sx * 3.62, LY + 4.1, 0.2), (0.06, 1.2, 3.0), "light" if sx < 0 else "grille")


def details_shell(p):
    rivets(p, (-3.2, LY + 4.6, -3.41), (3.2, LY + 4.6, -3.41), 9, (0, 0, -1))


def build_turret(p):
    p.prism_y(rect(0, 0.5, 3.3, 3.5), TY, TY + 3.6, "paint", bevel=0.12, top_scale=0.92)
    p.prism_x([(-3.0, TY + 3.6), (-0.4, TY + 3.6), (-0.4, TY + 4.4), (-1.6, TY + 4.4)], -3.0, 3.0, "paint", bevel=0.06)
    p.cylinder("z", (1.9, TY + 2.6, -3.05), 1.0, 0.3, 20, "trim")
    p.ocyl((1.9, TY + 2.6, -3.2), (0, 0, -1), 0.8, 0.3, 20, "power", radius2=0.5)  # the eye
    p.box((0, TY + 3.64, 2.3), (3.4, 0.05, 2.6), "team", bevel=0.01)
    p.box((0, TY + 1.9, 4.3), (5.6, 2.2, 0.6), "grille", bevel=0.04)  # heat sink
    antenna(p, (2.4, TY + 4.4, 2.4), 2.0)
    louver(p, (-3.32, TY + 2.2, 1.0), (0, 0, 1), (-1, 0, 0), 2.4, 1.2)


def details_turret(p):
    band_box(p, TY + 2.6, 0, 0.5, 3.3, 3.5)
    seam(p, (-3.0, TY + 1.0, -3.01), (3.0, TY + 1.0, -3.01), (0, 0, -1))
    rivets(p, (-3.31, TY + 0.6, -2.4), (-3.31, TY + 0.6, 3.4), 6, (-1, 0, 0))


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z - 0.2), (1.8, 1.8, 1.2), "trim", bevel=0.08)
    p.ocyl((x, y, z - 0.6), (0, 0, -1), 0.65, 6.2, 16, "steel")
    p.ocyl((x, y, z - 1.4), (0, 0, -1), 0.9, 0.6, 16, "dark")
    p.ocyl((x, y, MUZZLE[2] + 1.0), (0, 0, -1), 0.8, 0.9, 16, "dark")
    p.ocyl((x, y, MUZZLE[2] + 0.12), (0, 0, -1), 0.45, 0.1, 16, "weapon")


def details_barrel(p):
    ring(p, (BARREL[0], BARREL[1] + 0.91, BARREL[2] - 0.2), UP, 0.4)


unit.run(__file__, "chs_bulwark", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("laser", "base", (0.0, LY, 0.0), build_laser, details_laser),
                 unit.PieceSpec("laser_mount", "laser", (0.0, DY, -3.6), build_laser_mount, details_laser_mount),
                 unit.PieceSpec("laser_drum", "laser_mount", (0.0, DY, DZ), build_laser_drum, details_laser_drum),
                 unit.PieceSpec("shell", "base", (0.0, LY + 3.0, 0.0), build_shell, details_shell),
                 unit.PieceSpec("turret", "base", (0.0, TY, 0.0), build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)},
                      **{f"laser_muzzle{k}": {"parent": "laser_drum", "at": [round(v, 3) for v in lat(k, DZ - 3.8)]} for k in (1, 2, 3)}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 6.0, 0), 50),
                   ("close", (-15, 18, -18), (0, 9.0, -2.0), 40)])
