"""Seeker Spire (Chaos fire-control radar, T2 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_seekerspire/build.py

From its blockout, at the size scale (S-104: footprint 2, 16 x 16 studs,
about 16 tall): bigger and more elaborate than the T1 Eye, lighter than
the Tribunal, not a rescale. Big shapes first: a patched skid with two
large team plates and hazard striping, a generator box with a team roof, a
hot vent and a fuel drum, a tall narrow lattice spire on four splayed legs
with braced rings, X bracing, front braces (the blockout's), amber
beacons and guy cables, a grated platform with rail posts, and the amber
"eye" sensor hung under it at the front. The client-turned `radar` (turn
Y, the blockout's visual piece and pivot): a flat phased-array panel tilted
back 15 degrees, never a dish, its face unlit with an amber edge and cell
lines, welded patches, two tracker horns on its sides, a big team plate on
its back (the blockout's team strip on top) and a hung counterweight.
Chaos reads rugged, light and open (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from towers import clamped_cable, louver  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

RADAR = (0.0, 11.6, 0.0)  # the radar's pivot (blockout)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))  # panel face: forward and up
V = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 13.9, 0.0)
PW, PH = 5.6, 3.8
Y0, Y1 = 0.6, 11.0  # spire legs from the skid to the platform
FOOT, TOP = 3.0, 0.95
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


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_base(p):
    p.prism_y(octagon(7.8, 1.2), 0.0, Y0, "dark", bevel=0.07, top_scale=0.985)
    p.box((-4.4, Y0 + 0.03, 4.2), (4.6, 0.06, 4.6), "team", bevel=0.015)  # the blockout's team plate, enlarged
    p.box((4.4, Y0 + 0.03, -4.6), (4.2, 0.06, 3.4), "team", bevel=0.015)
    hazard(p, (-6.8, Y0 + 0.03, -2.4), (0, 0, 1), UP, 5.0, 0.6, stripes=10)
    p.box((-4.6, Y0 + 0.02, -4.4), (2.2, 0.04, 2.4), "steel", bevel=0.01)  # welded patch
    for sx in (-1, 1):
        p.box((sx * 7.82, 0.3, 0), (0.05, 0.14, 5.4), "light")
    # generator box (back right) with a team roof, a hot vent, a fuel drum
    p.prism_y(rect(4.6, 4.2, 1.4, 1.2), Y0, 2.8, "paint", bevel=0.07)
    p.box((4.6, 2.84, 4.2), (2.4, 0.05, 2.0), "team", bevel=0.012)
    p.box((4.6, 1.7, 2.97), (1.6, 0.4, 0.05), "power")
    louver(p, (6.02, 1.8, 4.2), (0, 0, 1), (1, 0, 0), 1.8, 1.2, slats=3)
    p.ocyl((4.0, 2.8, 4.7), UP, 0.22, 1.0, 10, "steel")
    p.cylinder("y", (4.0, 3.82, 4.7), 0.2, 0.06, 10, "power")
    p.cylinder("y", (6.6, Y0 + 0.75, 1.6), 0.55, 1.5, 12, "paint")
    p.box((6.6, Y0 + 1.51, 1.6), (0.7, 0.03, 0.2), "hazard")
    cable(p, [(3.4, 1.4, 3.6), (2.4, 2.2, 2.6), (1.9, 3.4, 1.9)], r=0.09, kind="dark")
    # the spire: splayed legs on foot pads, braced rings, X bracing, front braces
    for sx, sz in CORNERS:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.4, "paint", bevel=0.04)
        p.box((sx * FOOT, Y0 + 0.2, sz * FOOT), (0.9, 0.4, 0.9), "trim", bevel=0.04)
    ys = (3.3, 6.0, 8.6)
    for y in ys:
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.2, "steel")
    for i, (sx, sz) in enumerate(CORNERS):
        nx, nz = CORNERS[(i + 1) % 4]
        for ya, yb in ((Y0 + 0.3, ys[0]), (ys[0], ys[1]), (ys[1], ys[2]), (ys[2], Y1 - 0.2)):
            beam(p, leg_at(sx, sz, ya), leg_at(nx, nz, yb), 0.11, "steel")
            beam(p, leg_at(nx, nz, ya), leg_at(sx, sz, yb), 0.11, "steel")
    for y in (3.5, 7.5):  # the blockout's front braces, heavier
        beam(p, leg_at(-1, -1, y), leg_at(1, -1, y), 0.3, "trim")
    for sx, sz in CORNERS:
        x, y, z = leg_at(sx, sz, 6.0)
        p.box((x, y + 0.28, z), (0.48, 0.32, 0.48), "light")
    # guy cables to anchor blocks
    for sx, sz in ((1, -1), (-1, 1)):
        p.box((sx * 6.4, Y0 + 0.2, sz * 6.4), (0.6, 0.4, 0.6), "trim")
        cable(p, [leg_at(sx, sz, 8.6), (sx * 6.4, Y0 + 0.4, sz * 6.4)], r=0.05, kind="steel")
    # grated platform, rail posts, the bearing
    p.box((0, Y1 + 0.15, 0), (2.8, 0.3, 2.8), "trim", bevel=0.04)
    p.box((0, Y1 + 0.31, 0), (2.5, 0.03, 2.5), "grille")
    for sx, sz in CORNERS:
        p.box((sx * 1.3, Y1 + 0.5, sz * 1.3), (0.1, 0.5, 0.1), "steel")
        p.box((sx * 1.3, Y1 + 0.8, sz * 1.3), (0.22, 0.12, 0.22), "light")
    p.cylinder("y", (0, Y1 + 0.42, 0), 0.7, 0.24, 12, "steel")
    # the eye: a housing hung under the platform at the front (blockout's), amber lens
    p.box((0, 10.75, -1.55), (0.3, 0.6, 0.5), "steel")
    p.ocyl((0, 10.1, -1.5), (0, 0, -1), 0.8, 0.8, 16, "dark")
    p.ocyl((0, 10.1, -2.3), (0, 0, -1), 0.6, 0.06, 16, "light")
    clamped_cable(p, [(1.7, 3.4, 1.5), (1.4, 6.4, 1.3), (1.1, 9.6, 1.0)], r=0.08)


def details_base(p):
    rivets(p, (-3.0, Y0 + 0.01, -7.2), (3.0, Y0 + 0.01, -7.2), 8, UP)
    rivets(p, (3.4, 2.81, 5.3), (5.8, 2.81, 5.3), 4, UP)
    ring(p, (0, 10.1, -2.37), (0, 0, -1), 0.7)


def build_radar(p):
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):
        p.cylinder("y", (0, 11.8, 0), 0.5, 0.4, 12, "trim")
        p.obox(at(0, -1.2, -0.42), U, N, 0.5, 2.4, 0.4, "steel")
        p.obox(PANEL, U, N, PW, PH, 0.34, "paint", bevel=0.04)
        p.obox(at(0, 0, 0.18), U, N, PW - 0.5, PH - 0.5, 0.03, "dark")
        for b in (-(PH - 0.6) / 2, (PH - 0.6) / 2):  # amber edge
            p.obox(at(0, b, 0.2), U, N, PW - 0.5, 0.08, 0.02, "light")
        for a in (-(PW - 0.6) / 2, (PW - 0.6) / 2):
            p.obox(at(a, 0, 0.2), U, N, 0.08, PH - 0.5, 0.02, "light")
        for i in range(1, 5):  # cell lines
            p.obox(at(-(PW - 0.6) / 2 + i * (PW - 0.6) / 5, 0, 0.2), U, N, 0.04, PH - 0.6, 0.02, "light")
        for j in (-0.6, 0.6):
            p.obox(at(0, j, 0.2), U, N, PW - 0.6, 0.04, 0.02, "light")
        p.obox(at(-1.6, 0.8, 0.22), U, N, 1.2, 1.0, 0.03, "steel")  # welded patches over the face
        p.obox(at(1.9, -1.0, 0.22), U, N, 0.9, 0.7, 0.03, "steel")
        for sx in (-1, 1):  # tracker horns
            p.obox(at(sx * (PW / 2 + 0.35), 0.4, 0.0), U, N, 0.7, 1.0, 0.7, "trim", bevel=0.03)
            p.obox(at(sx * (PW / 2 + 0.35), 0.4, 0.36), U, N, 0.4, 0.5, 0.03, "light")
        p.obox(at(0, 0.2, -0.19), U, N, PW - 0.6, PH - 1.0, 0.03, "team")  # big team plate on the back
        p.obox(at(0, PH / 2 - 0.15, -0.2), U, N, PW - 0.8, 0.3, 0.05, "team")  # the blockout's top strip
        p.obox(at(1.8, -1.2, -0.65), U, N, 1.1, 1.0, 0.8, "trim", bevel=0.04)  # counterweight
        cable(p, [at(1.8, -0.8, -0.3), at(0.8, -1.4, -0.35), at(0, -1.6, -0.4)], r=0.07, kind="steel")


def build_base_and_radar(p):
    build_base(p)
    build_radar(p)


def details_base_and_radar(p):
    details_base(p)
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):
        bolts(p, at(-(PW - 0.4) / 2, PH / 2 - 0.12, 0.17), at((PW - 0.4) / 2, PH / 2 - 0.12, 0.17), 10, N)


unit.run(__file__, "chs_seekerspire", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base_and_radar, details_base_and_radar)],
         budget=6000,
         previews=[("35", (-28, 23, -33), (0, 7.0, 0), 50),
                   ("80", (0, 52, 8), (0, 6, 0), 50),
                   ("close", (-12, 16, -14), (0, 10.0, 0), 45)])
