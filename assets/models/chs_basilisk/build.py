"""Basilisk (Chaos point defence, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_basilisk/build.py

New mesh for the sim's S-149 (shoots down missiles and rockets with small
vertical-launch interceptors, never units; a larger stock than the
Sanctum), at the T2 defense size (S-104: footprint 3, 24 x 24 studs, about
11 tall at the dish). Big shapes first: a patched pad with large team
plates and hazard striping, reactive blocks with amber lights along the
rack, ammo crates and a fuel drum cabled in, and a lattice post at the back
right with a spinning dish and an amber feed (client-turned `radar`, M-27).
The `launcher` (static: the def doesn't turn it): a wide, low welded rack of
24 short upright tubes in four rows, their mouths ringed amber when ready
(`weapon`), a slab blast shield behind with a team plate, `muzzle` at the
front left tube, launching straight up. Reads apart from the Wyvern (tall
tubes on a turning post) by its low wide rack. Chaos reads rugged and
improvised (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec
RACK = (-2.0, 0.0)  # centre of the rack
DECK = 1.6  # rack deck height
TUBE_H = 3.0
XS = [(-2.5 + i) * 1.15 for i in range(6)]
ZS = [(-1.5 + j) * 1.2 for j in range(4)]
POST = (7.4, 6.6)
MUZZLE = (RACK[0] + XS[0], DECK + TUBE_H + 0.05, RACK[1] + ZS[0])


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.cylinder("y", (0, 0.4, 0), 11.4, 0.8, 32, "dark", bevel=0.1)
    for x, z, w, d in ((7.0, -6.6, 4.4, 3.0), (-8.0, 6.0, 3.0, 4.0), (0.0, 9.0, 4.0, 1.6)):
        p.box((x, 0.82, z), (w, 0.04, d), "trim", bevel=0.01)  # patches
    p.box((-8.4, 0.85, -2.0), (2.6, 0.05, 6.0), "team", bevel=0.015)
    p.box((5.0, 0.85, -2.0), (3.4, 0.05, 3.4), "team", bevel=0.015)
    hazard(p, (0, 0.85, -10.2), (1, 0, 0), UP, 7.0, 0.6, stripes=12)
    # reactive blocks along the rack's sides with amber lights
    x0, z0 = RACK
    for sz in (-1, 1):
        for k in range(4):
            x = x0 - 3.3 + k * 2.2
            p.box((x, 1.3, z0 + sz * 3.4), (2.0, 1.0, 0.6), "era", bevel=0.05)
            p.box((x, 1.6, z0 + sz * 3.72), (1.4, 0.16, 0.04), "light")
    # ammo crates, a fuel drum, cables
    for x, z in ((4.0, 4.6), (5.4, 4.8), (4.7, 6.0)):
        p.box((x, 1.3, z), (1.2, 1.0, 2.4), "trim", bevel=0.05)
        p.box((x, 1.82, z), (1.0, 0.04, 2.0), "team", bevel=0.01)
    drum(p, (-7.6, 1.6, -7.2), 0.8, 1.6, "paint", "trim", sides=14, axis="y")
    p.box((-7.6, 1.6, -8.02), (0.36, 0.7, 0.05), "power")
    cable(p, [(-6.8, 0.9, -6.4), (-5.6, 0.9, -3.8), (-4.8, 1.2, -2.6)], r=0.13, kind="dark")
    cable(p, [(POST[0] - 1.0, 0.9, POST[1] - 1.0), (3.2, 0.9, 2.6), (1.2, 1.4, 1.4)], r=0.13, kind="dark")
    # lattice post with the dish, back right
    px, pz = POST
    for dx in (-0.6, 0.6):
        for dz in (-0.6, 0.6):
            beam(p, (px + dx * 1.7, 0.8, pz + dz * 1.7), (px + dx, 7.6, pz + dz), 0.2, "paint")
    for y in (2.8, 5.2):
        p.box((px, y, pz), (1.7, 0.12, 1.7), "steel")
    p.box((px, 7.8, pz), (1.6, 0.4, 1.6), "trim", bevel=0.04)
    p.box((px + 0.9, 8.4, pz + 0.9), (0.2, 0.2, 0.2), "light")  # beacon
    for x, z in ((10.4, 3.0), (-10.4, 3.0), (3.0, -10.6), (-3.0, 10.6)):
        p.box((x, 0.86, z), (0.45, 0.14, 0.45), "light")

    t = math.radians(30)
    n = (0, math.sin(t), -math.cos(t))
    c = (px, 9.4, pz - 0.6)
    with p.sub("radar", (px, 8.0, pz), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (px, 8.3, pz), 0.4, 0.6, 12, "dark")
        p.box((px, 8.8, pz), (0.5, 0.8, 0.5), "trim")
        p.ocyl(c, tuple(-k for k in n), 1.9, 0.5, 20, "paint", radius2=0.6)  # the dish, open toward n
        p.ocyl(tuple(c[k] + n[k] * 0.05 for k in range(3)), n, 1.7, 0.03, 20, "grille")
        for sx in (-1, 1):
            beam(p, (px + sx * 1.2, c[1] + n[1] * 0.1, c[2] + n[2] * 0.1), (px, c[1] + n[1] * 1.2, c[2] + n[2] * 1.2), 0.08, "trim")
        p.box((px, c[1] + n[1] * 1.25, c[2] + n[2] * 1.25), (0.35, 0.35, 0.35), "head")  # the amber feed
        p.ocyl(tuple(c[k] - n[k] * 0.5 for k in range(3)), tuple(-k for k in n), 0.9, 0.05, 16, "team")


def details_base(p):
    rivets(p, (-3.0, 0.841, -9.4), (3.0, 0.841, -9.4), 8, UP)


def build_launcher(p):
    x0, z0 = RACK
    p.box((x0, DECK - 0.4, z0), (7.6, 0.5, 5.6), "steel")  # the welded deck
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((x0 + sx * 3.5, (DECK - 0.4) / 2 + 0.4, z0 + sz * 2.5), (0.4, DECK - 0.4, 0.4), "dark")  # legs
    p.box((x0, DECK + 2.2, z0 + 3.0), (7.8, 0.3, 0.3), "trim")  # top strap
    for dx in (-3.6, 3.6):
        p.box((x0 + dx, DECK + 1.2, z0), (0.3, 2.4, 5.8), "trim")  # end frames
    # slab blast shield behind the rack, a team plate on it
    p.box((x0, DECK + 1.6, z0 + 3.3), (7.8, 3.2, 0.4), "era", bevel=0.05)
    p.box((x0, DECK + 1.9, z0 + 3.52), (3.0, 1.2, 0.05), "team", bevel=0.01)
    # 24 short upright tubes, amber ready rings
    for x in XS:
        for z in ZS:
            p.cylinder("y", (x0 + x, DECK + TUBE_H / 2, z0 + z), 0.44, TUBE_H, 12, "paint")
            p.cylinder("y", (x0 + x, DECK + TUBE_H + 0.02, z0 + z), 0.46, 0.06, 12, "weapon")
            p.cylinder("y", (x0 + x, DECK + 0.7, z0 + z), 0.46, 0.4, 12, "team")
    hazard(p, (x0, DECK - 0.14, z0 - 2.82), (1, 0, 0), (0, 0, -1), 7.0, 0.35, stripes=14)


def no_details(p):
    pass


unit.run(__file__, "chs_basilisk", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", (RACK[0], DECK, RACK[1]), build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [round(v, 3) for v in MUZZLE]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.0, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 4.0, -1.0), 40)])
