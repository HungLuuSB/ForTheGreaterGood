"""Maw (Chaos heavy turret, T2 structure, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_maw/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 3, 24 x 24
studs, about 13 tall), from its scaled blockout (turret pivot, gun, mouth,
ammo drum and muzzle where Scale.scaled puts them), and bigger and more
elaborate than the T1 Spike, not a rescale. Big shapes first: a patched
pad, a round sloped base ringed with reactive blocks and amber strips, big
team plates on its deck, a crate stack and a lamp post, the tall ribbed
drum (the T2 signature) with a glowing collar and a ladder. The `turret`
(yaw, the def's piece): a squat wide domed drum with a team roof plate, a
leaning slab shield round the gun, reactive bricks on its flanks, the big
ammo drum with a feed chute on its right, an amber spotter eye and an
antenna, and the very fat short gun with jacket rings and a flared mouth
holding a glowing ring (`weapon`; `muzzle` at the mouth). Chaos reads
rugged and improvised (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_round, clamped_cable, louver  # noqa: E402
from mech import cable, drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

S = 2.682  # the blockout's scale (footprint 1 -> 3)
TURRET_PIVOT = (0.0, 2.8 * S, 0.0)  # 7.51
GY = 4.0 * S  # 10.73, gun axis height
MUZZLE = (0.0, GY, -5.5 * S)  # -14.75
TZ = 0.2 * S  # 0.54, the turret drum's centre
B1 = 3.75  # base deck height
D1 = TURRET_PIVOT[1]  # drum top


def on(c, n, d):
    k = d / math.sqrt(sum(v * v for v in n))
    return tuple(c[i] + n[i] * k for i in range(3))


def build_base(p):
    p.prism_y(octagon(11.7, 2.6), 0.0, 0.4, "dark", bevel=0.08, top_scale=0.99)
    p.box((-7.6, 0.42, 8.2), (3.0, 0.04, 2.0), "steel", bevel=0.01)  # welded patch
    hazard(p, (0, 0.42, -11.2), (1, 0, 0), UP, 9.0, 0.5, stripes=16)
    # round sloped base, reactive blocks round it
    p.cylinder("y", (0, (0.4 + B1) / 2, 0), 8.7, B1 - 0.4, 32, "paint", radius2=8.0, bevel=0.08)
    for i in range(9):
        a = math.radians(i * 40)
        c, s = math.cos(a), math.sin(a)
        n = (s, 0.18, -c)
        p.obox((s * 8.65, 2.0, -c * 8.65), (c, 0, s), n, 4.2, 2.2, 0.7, "era", bevel=0.06)
        if i % 3 == 0:
            p.obox(on((s * 8.65, 2.5, -c * 8.65), n, 0.36), (c, 0, s), n, 2.6, 0.16, 0.04, "light")
    # big team plates on the deck (back quarters)
    for sx in (-1, 1):
        a = math.radians(sx * 130)
        c, s = math.cos(a), math.sin(a)
        p.obox((s * 6.7, B1 + 0.03, -c * 6.7), (c, 0, s), UP, 4.4, 2.2, 0.06, "team", bevel=0.015)
    p.obox((0, B1 + 0.03, -6.7), (1, 0, 0), UP, 4.4, 2.2, 0.06, "team", bevel=0.015)
    # crate stack (front right) and a lamp post (front left)
    for dx, dy, dz in ((0, 0, 0), (0.2, 0.9, 0.1), (1.6, 0, -0.9)):
        p.obox((5.2 + dx, B1 + 0.45 + dy, -4.6 + dz), (0.8, 0, 0.6), UP, 1.6, 1.3, 0.9, "trim", bevel=0.04)
    p.cylinder("y", (-5.6, B1 + 1.2, -4.8), 0.1, 2.4, 6, "steel")
    p.box((-5.6, B1 + 2.5, -4.8), (0.6, 0.4, 0.5), "dark")
    p.box((-5.6, B1 + 2.5, -5.07), (0.42, 0.24, 0.04), "head")
    # the tall ribbed drum, glowing collar, a ladder at the back
    p.cylinder("y", (0, (B1 + D1) / 2, 0), 5.4, D1 - B1, 24, "paint", bevel=0.06)
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        c, s = math.cos(a), math.sin(a)
        p.obox((s * 5.45, (B1 + D1) / 2, c * 5.45), (c, 0, -s), (s, 0, c), 0.36, D1 - B1 - 0.4, 0.3, "trim")
    p.cylinder("y", (0, D1 - 0.25, 0), 5.5, 0.16, 24, "power")
    for x in (-0.4, 0.4):
        p.box((x, (B1 + D1) / 2, 5.75), (0.08, D1 - B1, 0.08), "steel")
    for k in range(6):
        p.box((0, B1 + 0.4 + k * 0.6, 5.75), (0.8, 0.06, 0.06), "steel")
    louver(p, (0, 5.4, -5.42), (1, 0, 0), (0, 0, -1), 2.2, 1.0, slats=3)
    clamped_cable(p, [(3.2, B1, 5.8), (3.6, 5.0, 4.0), (3.8, 6.8, 3.6)], r=0.1)
    for sx in (-1, 1):
        p.box((sx * 10.0, 0.52, -10.0), (0.5, 0.24, 0.5), "light")


def details_base(p):
    band_round(p, 1.6, 8.5, segments=24)
    band_round(p, 5.6, 5.42, segments=20)
    ring(p, (0, D1 + 0.01, 0), UP, 4.6)
    rivets(p, (-6.4, B1 + 0.01, 2.2), (6.4, B1 + 0.01, 2.2), 12, UP)


def build_turret(p):
    p.cylinder("y", (0, 9.55, TZ), 6.2, 4.1, 24, "paint", radius2=5.7, bevel=0.08)
    p.cylinder("y", (0, 12.1, TZ), 5.7, 1.0, 24, "paint", radius2=4.4, bevel=0.06)
    p.box((0, 12.63, TZ + 0.7), (5.8, 0.06, 4.8), "team", bevel=0.02)
    # leaning slab shield round the gun
    p.obox((0, 10.3, -6.0), (1, 0, 0), (0, 0.3, -1), 7.4, 4.6, 0.6, "era", bevel=0.08)
    p.obox((0, 12.11, -5.79), (1, 0, 0), (0, 0.3, -1), 5.2, 0.16, 0.04, "light")
    # reactive bricks on the flanks (left), a patch
    for z in (-1.6, 0.8, 3.2):
        p.box((-(math.sqrt(5.97 ** 2 - (z - TZ) ** 2) + 0.25), 9.4, z), (0.7, 2.2, 2.2), "era", bevel=0.05)
    p.box((-6.16, 8.3, 0.6), (0.05, 0.16, 2.4), "light")
    p.box((4.0, 9.8, 4.9), (2.2, 1.6, 0.05), "steel", bevel=0.01)
    # the big ammo drum (right) with a feed chute to the gun
    drum(p, (7.24, 10.19, 1.61), 2.4, 3.2, "trim", "dark", sides=18)
    p.cylinder("x", (8.86, 10.19, 1.61), 1.1, 0.06, 14, "hazard")
    p.obox((5.4, 11.6, -1.4), (-0.6, 0, -1), UP, 3.6, 1.2, 1.0, "steel", bevel=0.05)
    p.box((5.6, 8.3, 1.61), (1.8, 0.8, 1.4), "dark", bevel=0.04)
    # amber spotter eye (left front), antenna and vent at the back
    p.box((-3.2, 13.0, -2.0), (1.4, 1.0, 1.4), "trim", bevel=0.05)
    p.ocyl((-3.2, 13.0, -2.7), (0, 0, -1), 0.4, 0.06, 12, "light")
    antenna(p, (-2.4, 12.6, 4.0), 2.6, r=0.06)
    louver(p, (1.0, 9.8, TZ + 5.95), (1, 0, 0), (0, 0, 1), 2.6, 1.4)
    cable(p, [(-3.2, 12.5, -1.3), (-3.9, 12.2, 0.4), (-4.4, 11.6, 2.0)], r=0.1, kind="dark")
    # the very fat short gun: jacket rings, a flared mouth with a glowing ring
    p.ocyl((0, GY, -4.0), (0, 0, -1), 2.15, 8.9, 20, "steel")
    for z in (-6.4, -9.6):
        p.ocyl((0, GY, z), (0, 0, -1), 2.36, 0.7, 20, "dark")
    p.ocyl((0, GY, -12.9), (0, 0, -1), 2.4, 1.6, 20, "dark", radius2=2.82)
    p.ocyl((0, GY, -14.5), (0, 0, -1), 2.1, 0.05, 20, "dark")
    p.ocyl((0, GY, -14.55), (0, 0, -1), 1.5, 0.06, 20, "weapon")
    p.ocyl((0, GY, -14.61), (0, 0, -1), 1.05, 0.04, 16, "dark")


def details_turret(p):
    band_round(p, 9.0, 6.12, segments=24, cz=TZ)
    ring(p, (0, 12.665, TZ + 0.7), UP, 0.8)
    rivets(p, (-3.4, 12.0, -5.84), (3.4, 12.0, -5.84), 8, (0, 0.3, -1))
    for z in (-5.2, -8.0, -11.2):
        ring(p, (0, GY, z), (0, 0, -1), 2.17, width=0.06, segments=18)


unit.run(__file__, "chs_maw", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": [round(v, 3) for v in MUZZLE]}},
         budget=6000,
         previews=[("35", (-34, 30, -40), (0, 5.0, -3.0), 50),
                   ("80", (0, 60, 9), (0, 4, -3.0), 50),
                   ("close", (-17, 16, -20), (0, 8.0, -4.0), 38)])
