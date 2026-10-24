"""Augur (Chaos pinpointer radar, T2 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_augur/build.py

New mesh at the size scale (S-104, M-26: footprint 2, 16 x 16 studs, about
10 tall), from its blockout. Pieces: `base` and the def's `dish` (turn Y,
tools/animate.py; a flat phased array, never a dish). Big shapes first: a
patched skid slab with a large team plate and hazard striping, an open
four-leg lattice frame on foot pads with braced rings and X bracing, guy
cables, amber beacons, a grated platform with rail posts, the amber "eye"
hung under its front in a ribbed housing; at the foot a generator shed with
a team roof, a hot vent and a stack, a strapped salvage tank with a team
cap, fuel drums and a cable run. The `dish`: a flat array tilted back 20
degrees on a strut yoke, its face unlit with an amber edge and cell lines,
welded patches, a big team plate on its back (the blockout's band), a
counterweight box and a whip aerial. Chaos reads rugged, light and open
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

DISH_PIVOT = (0.0, 6.2, 0.0)
TILT = math.radians(20)
N = (0.0, math.sin(TILT), -math.cos(TILT))
VV = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 8.0, 0.0)
PW, PH = 7.0, 3.4
FOOT, TOP = 3.0, 1.1
Y0, Y1 = 0.55, 5.8
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]


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
    p.prism_y(octagon(7.8, 0.9), 0.0, 0.55, "dark", bevel=0.08, top_scale=0.985)
    p.box((4.4, 0.58, 4.4), (5.0, 0.05, 5.0), "team", bevel=0.015)
    p.box((-4.4, 0.58, -4.6), (3.6, 0.05, 2.6), "team", bevel=0.015)
    hazard(p, (1.6, 0.58, -6.9), (1, 0, 0), UP, 7.0, 0.5, stripes=12)
    p.box((5.6, 0.58, -2.4), (1.8, 0.04, 2.4), "steel", bevel=0.01)  # welded patch
    for s in (-1, 1):
        p.box((s * 7.82, 0.3, 0), (0.05, 0.14, 4.0), "light")
    # the frame: four splayed legs on foot pads, braced rings, X bracing
    for sx, sz in CORNERS:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.42, "paint", bevel=0.04)
        p.box((sx * FOOT, 0.75, sz * FOOT), (1.0, 0.4, 1.0), "trim", bevel=0.04)
    for y in (2.4, 4.3):
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.2, "steel")
    for i, (sx, sz) in enumerate(CORNERS):
        nx, nz = CORNERS[(i + 1) % 4]
        for ya, yb in ((Y0 + 0.3, 2.4), (2.4, 4.3)):
            beam(p, leg_at(sx, sz, ya), leg_at(nx, nz, yb), 0.12, "steel")
            beam(p, leg_at(nx, nz, ya), leg_at(sx, sz, yb), 0.12, "steel")
    for sx, sz in CORNERS:  # amber beacons
        x, y, z = leg_at(sx, sz, 4.3)
        p.box((x, y + 0.24, z), (0.44, 0.28, 0.44), "light")
    # guy cables to anchor blocks
    for sx in (-1, 1):
        p.box((sx * 6.3, 0.75, -6.3), (0.7, 0.4, 0.7), "trim")
        cable(p, [leg_at(sx, -1, 4.3), (sx * 6.3, 0.9, -6.3)], r=0.05, kind="steel")
    # grated platform, rail posts, the bearing
    p.box((0, Y1 + 0.15, 0), (3.0, 0.3, 3.0), "trim", bevel=0.04)
    p.box((0, Y1 + 0.32, 0), (2.7, 0.03, 2.7), "grille")
    for sx, sz in CORNERS:
        p.box((sx * 1.38, Y1 + 0.45, sz * 1.38), (0.1, 0.3, 0.1), "steel")
    p.cylinder("y", (0, Y1 + 0.4, 0), 0.7, 0.2, 12, "steel")
    # the eye: a ribbed housing hung under the platform front, its amber lens forward
    p.box((0, 5.45, -1.2), (0.32, 0.7, 0.32), "steel")
    p.ocyl((0, 4.8, -1.0), (0, 0, -1), 0.75, 0.8, 14, "dark")
    p.ocyl((0, 4.8, -1.8), (0, 0, -1), 0.75, 0.2, 14, "trim", radius2=0.62)
    p.ocyl((0, 4.8, -2.0), (0, 0, -1), 0.55, 0.06, 14, "light")
    # generator shed at the foot (back left) with a team roof, a vent and a stack
    p.prism_y(rect(-4.6, 4.6, 1.5, 1.3), 0.55, 2.5, "paint", bevel=0.07)
    p.box((-4.6, 2.54, 4.6), (2.8, 0.05, 2.4), "team", bevel=0.012)
    p.box((-4.6, 1.5, 3.28), (1.8, 0.4, 0.05), "power")
    p.ocyl((-5.5, 2.5, 5.2), UP, 0.24, 1.3, 10, "steel")
    p.cylinder("y", (-5.5, 3.84, 5.2), 0.22, 0.07, 10, "power")
    # a salvaged tank by the shed, strapped, with a team cap
    p.cylinder("y", (-6.2, 1.85, 1.6), 0.9, 2.6, 12, "paint", bevel=0.04)
    p.ocyl((-6.2, 3.15, 1.6), UP, 0.9, 0.35, 12, "trim", radius2=0.6)
    p.cylinder("y", (-6.2, 3.52, 1.6), 0.58, 0.04, 10, "team")
    for y in (1.2, 2.4):
        p.cylinder("y", (-6.2, y, 1.6), 0.94, 0.14, 12, "dark")
    cable(p, [(-5.4, 2.6, 2.2), (-4.6, 2.6, 3.2)], r=0.1, kind="steel")
    for z in (-1.2, -0.2):  # fuel drums
        drum(p, (-6.4, 0.98, z), 0.42, 0.95, "trim", "dark", sides=10, axis="x")
    cable(p, [(-3.1, 1.6, 4.0), (-2.0, 0.8, 2.6), leg_at(-1, 1, 1.6)], r=0.08, kind="dark")


def details_base(p):
    rivets(p, (-6.4, 0.551, -6.2), (6.4, 0.551, -6.2), 10, UP)
    rivets(p, (-5.8, 2.541, 3.6), (-3.4, 2.541, 3.6), 4, UP)
    ring(p, (0, 4.8, -2.04), (0, 0, -1), 0.45)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + VV[k] * b + N[k] * n for k in range(3))


def build_dish(p):
    p.cylinder("y", (0, 6.45, 0), 0.5, 0.5, 12, "trim")
    for sx in (-1, 1):  # strut yoke to the panel's back
        beam(p, (sx * 0.35, 6.6, 0.1), at(sx * 1.8, -0.8, -0.25), 0.26, "steel")
    beam(p, (0, 6.6, 0.3), at(0, -0.2, -0.25), 0.3, "steel")
    p.obox(PANEL, U, N, PW, PH, 0.36, "paint", bevel=0.04)
    p.obox(at(0, 0, 0.19), U, N, PW - 0.45, PH - 0.4, 0.03, "dark")
    hw, hh = (PW - 0.45) / 2, (PH - 0.4) / 2
    for b in (-hh + 0.05, hh - 0.05):  # amber edge
        p.obox(at(0, b, 0.21), U, N, PW - 0.45, 0.09, 0.02, "light")
    for a in (-hw + 0.05, hw - 0.05):
        p.obox(at(a, 0, 0.21), U, N, 0.09, PH - 0.5, 0.02, "light")
    for a in (-1.6, 0.0, 1.6):  # cell lines and one row
        p.obox(at(a, 0, 0.21), U, N, 0.04, PH - 0.5, 0.02, "light")
    p.obox(at(0, 0.0, 0.21), U, N, PW - 0.55, 0.04, 0.02, "light")
    p.obox(at(-2.2, 0.7, 0.23), U, N, 1.1, 0.8, 0.03, "steel")  # welded patches
    p.obox(at(2.4, -0.9, 0.23), U, N, 0.9, 0.6, 0.03, "steel")
    # back: the big team plate, ribs, a counterweight, a whip aerial
    p.obox(at(0, 0.35, -0.2), U, N, PW - 0.8, PH - 1.2, 0.03, "team")
    for a in (-2.4, 2.4):
        p.obox(at(a, 0, -0.28), U, N, 0.2, PH - 0.2, 0.18, "dark")
    p.obox(at(2.2, -1.1, -0.6), U, N, 1.1, 0.9, 0.7, "trim", bevel=0.04)
    cable(p, [at(2.2, -0.7, -0.3), at(1.0, -1.3, -0.35), at(0.2, -1.4, -0.4)], r=0.06, kind="steel")
    p.ocyl(at(-PW / 2 + 0.3, PH / 2, -0.1), VV, 0.05, 1.8, 6, "steel")
    p.obox(at(-PW / 2 + 0.3, PH / 2 + 1.85, -0.1), U, N, 0.18, 0.14, 0.18, "light")


def details_dish(p):
    bolts(p, at(-PW / 2 + 0.3, PH / 2 - 0.1, 0.18), at(PW / 2 - 0.3, PH / 2 - 0.1, 0.18), 12, N)


unit.run(__file__, "chs_augur", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH_PIVOT, build_dish, details_dish)],
         budget=6000,
         previews=[("35", (-24, 19, -28), (0, 4.0, 0), 50),
                   ("80", (0, 40, 7), (0, 3, 0), 50),
                   ("close", (-12, 11, -14), (0, 6.0, 0), 40)])
