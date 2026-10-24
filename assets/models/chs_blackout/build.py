"""Blackout (Chaos jammer tower, T2 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_blackout/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16
studs, about 24 tall), from its scaled blockout, and bigger and more
elaborate than the T1 Smog, not a rescale. Big shapes first: a patched
skid with two large team plates (the blockout's team band) and hazard
striping, a generator box with a hot vent and a fuel drum, an open lattice
mast on four splayed legs with braced rings, X bracing, amber beacons and
guy cables, a grated platform with rail posts and a bearing on top. The
client-spun `spine` (spin Y, rig.md 9; the blockout's rods ride on it): a
tall post through the platform carrying three rings of four glowing
emitter rods on struts (`power`), turned 30 degrees ring to ring, with
collars and a cap lamp. Chaos reads rugged, light and open (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from towers import clamped_cable, louver  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

SPINE = (0.0, 11.6, 0.0)  # the spine's pivot, on its bearing
Y0, Y1 = 1.0, 11.2  # mast legs from the skid to the platform
FOOT, TOP = 3.1, 1.25  # leg spread at the skid and at the top
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
RINGS = (13.4, 17.0, 20.6)  # the blockout's three rings of rods


def leg_at(sx, sz, y):
    t = (y - Y0) / (Y1 - Y0)
    r = FOOT + (TOP - FOOT) * t
    return (sx * r, y, sz * r)


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def build_base(p):
    p.prism_y(octagon(7.8, 0.9), 0.0, Y0, "dark", bevel=0.08, top_scale=0.985)
    for sz in (-1, 1):  # two large team plates (the blockout's band at the back, one at the front)
        p.box((0, Y0 + 0.03, sz * 5.9), (8.8, 0.06, 2.4), "team", bevel=0.015)
    hazard(p, (-6.0, Y0 + 0.03, 0), (0, 0, 1), UP, 6.0, 0.6, stripes=12)
    p.box((5.6, Y0 + 0.02, 1.8), (2.0, 0.04, 2.6), "steel", bevel=0.01)  # welded patch
    for sx in (-1, 1):
        p.box((sx * 7.82, 0.5, 0), (0.05, 0.16, 5.0), "light")
    # generator box (front right) with a hot vent, a fuel drum, a feed cable
    p.prism_y(rect(4.9, -2.6, 1.3, 1.1), Y0, 3.2, "paint", bevel=0.08)
    p.box((4.9, 3.24, -2.6), (2.2, 0.05, 1.8), "team", bevel=0.012)
    p.box((4.9, 2.0, -3.73), (1.8, 0.5, 0.05), "power")
    louver(p, (6.22, 2.1, -2.6), (0, 0, 1), (1, 0, 0), 1.6, 1.2, slats=3)
    p.cylinder("y", (4.9, 3.9, -1.9), 0.25, 1.3, 10, "steel")
    p.cylinder("y", (4.9, 4.57, -1.9), 0.22, 0.06, 10, "power")
    p.cylinder("y", (6.4, Y0 + 0.8, -5.2), 0.6, 1.6, 12, "paint")
    p.box((6.4, Y0 + 1.61, -5.2), (0.8, 0.03, 0.22), "hazard")
    cable(p, [(3.6, 2.2, -2.2), (2.4, 2.8, -1.6), (1.5, 3.6, -1.3)], r=0.1, kind="dark")
    # the lattice mast: splayed legs on foot pads, braced rings, X bracing, beacons
    for sx, sz in CORNERS:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.48, "paint", bevel=0.04)
        p.box((sx * FOOT, Y0 + 0.25, sz * FOOT), (1.1, 0.5, 1.1), "trim", bevel=0.04)
    ys = (3.6, 6.4, 9.0)
    for y in ys:
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.22, "steel")
    for i, (sx, sz) in enumerate(CORNERS):
        nx, nz = CORNERS[(i + 1) % 4]
        for ya, yb in ((Y0 + 0.4, ys[0]), (ys[0], ys[1]), (ys[1], ys[2])):
            beam(p, leg_at(sx, sz, ya), leg_at(nx, nz, yb), 0.13, "steel")
            beam(p, leg_at(nx, nz, ya), leg_at(sx, sz, yb), 0.13, "steel")
    for sx, sz in CORNERS:
        x, y, z = leg_at(sx, sz, 6.4)
        p.box((x, y + 0.3, z), (0.55, 0.36, 0.55), "light")
    # guy cables to anchor blocks
    for sx, sz in ((1, 1), (-1, -1)):
        p.box((sx * 6.6, Y0 + 0.2, sz * 6.6), (0.7, 0.5, 0.7), "trim")
        cable(p, [leg_at(sx, sz, 9.0), (sx * 6.6, Y0 + 0.4, sz * 6.6)], r=0.05, kind="steel")
    # grated platform, rail posts, the bearing
    p.box((0, Y1 + 0.15, 0), (3.6, 0.3, 3.6), "trim", bevel=0.04)
    p.box((0, Y1 + 0.31, 0), (3.2, 0.03, 3.2), "grille")
    for sx, sz in CORNERS:
        p.box((sx * 1.7, Y1 + 0.6, sz * 1.7), (0.1, 0.6, 0.1), "steel")
        p.box((sx * 1.7, Y1 + 0.94, sz * 1.7), (0.24, 0.14, 0.24), "light")
    p.cylinder("y", (0, Y1 + 0.42, 0), 0.9, 0.24, 14, "steel")
    clamped_cable(p, [(1.0, 3.8, -1.2), (1.3, 7.0, -1.1), (1.0, Y1, -0.9)], r=0.08)

    with p.sub("spine", SPINE, "spin", (0, 1, 0)):
        p.cylinder("y", (0, 11.6, 0), 0.75, 0.4, 14, "trim")
        p.cylinder("y", (0, 17.2, 0), 0.45, 11.2, 12, "paint")
        for k, y in enumerate(RINGS):
            p.cylinder("y", (0, y, 0), 0.7, 0.5, 12, "trim")
            for j in range(4):
                a = math.radians(j * 90 + k * 30)
                s, c = math.sin(a), math.cos(a)
                p.obox((s * 1.45, y, c * 1.45), (s, 0, c), UP, 1.9, 0.16, 0.16, "steel")
                p.cylinder("y", (s * 2.5, y, c * 2.5), 0.2, 0.5, 8, "dark")
                p.cylinder("y", (s * 2.5, y, c * 2.5), 0.12, 1.8, 8, "power")
        p.cylinder("y", (0, 22.95, 0), 0.6, 0.18, 12, "trim")
        p.box((0, 23.2, 0), (0.36, 0.32, 0.36), "light")


def details_base(p):
    rivets(p, (-6.4, Y0 + 0.01, -7.2), (6.4, Y0 + 0.01, -7.2), 10, UP)
    rivets(p, (4.7, Y0 + 0.05, 0.6), (6.5, Y0 + 0.05, 0.6), 4, UP)
    with p.sub("spine", SPINE, "spin", (0, 1, 0)):
        for y in RINGS:
            ring(p, (0, y + 0.251, 0), UP, 0.5)


unit.run(__file__, "chs_blackout", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-30, 26, -36), (0, 11.0, 0), 50),
                   ("80", (0, 60, 9), (0, 8, 0), 50),
                   ("close", (-14, 16, -17), (0, 13.0, 0), 45)])
