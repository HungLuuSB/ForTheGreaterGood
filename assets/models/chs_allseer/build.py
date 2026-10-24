"""All-Seer (Chaos long-range radar, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_allseer/build.py

New mesh at the size scale (S-104, M-26: footprint 3, 24 x 24 studs, about
21 tall), from its blockout; the T1 Eye's big brother, not a rescale. Big
shapes first: a patched skid slab with large team plates on two corners and
hazard striping; a tall open lattice mast on four thick splayed legs with
heavy foot pads, five braced rings and X bracing on every side, guy cables
to anchor blocks on the other corners, amber beacons; a grated platform with
rail posts and lamps; the big amber "eye" sensor hung under its front in a
ribbed housing; a generator shed with a team roof and a hot vent, fuel
drums, a battery container and cable runs at the foot; and on a bearing the
client-turned `radar` (blockout visual piece, turn Y, rig.md 9): a very wide
flat phased array tilted back 15 degrees, never a dish, its face unlit with
an amber edge and cell lines, welded patches, a strut truss and a big team
plate on its back (the blockout's band) and hung counterweight boxes. Chaos
reads rugged, light and open (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

RADAR_PIVOT = (0.0, 15.4, 0.0)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))
VV = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 18.2, 0.0)
PW, PH = 12.0, 4.6
FOOT, TOP = 5.0, 1.45  # leg spread at the skid and at the top
Y0, Y1 = 0.7, 14.8
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
RINGS = (3.4, 6.2, 9.0, 11.6, 13.8)


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
    p.prism_y(octagon(11.8, 1.0), 0.0, 0.7, "dark", bevel=0.1, top_scale=0.985)
    for sx in (-1, 1):  # big team plates on two corners
        p.box((sx * 7.2, 0.73, sx * 7.2), (5.2, 0.05, 5.2), "team", bevel=0.015)
    hazard(p, (0, 0.73, -10.4), (1, 0, 0), UP, 9.0, 0.6, stripes=16)
    p.box((-7.8, 0.73, 1.2), (2.4, 0.04, 3.4), "steel", bevel=0.01)  # welded patches
    p.box((4.6, 0.73, -3.4), (1.8, 0.04, 2.2), "steel", bevel=0.01)
    for s in (-1, 1):
        p.box((s * 11.82, 0.38, 0), (0.05, 0.16, 6.0), "light")
    # the mast: thick splayed legs on foot pads, braced rings, X bracing
    for sx, sz in CORNERS:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.6, "paint", bevel=0.05)
        p.box((sx * FOOT, 0.95, sz * FOOT), (1.4, 0.5, 1.4), "trim", bevel=0.05)
    for y in RINGS:
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.28, "steel")
    bays = [(Y0 + 0.5, RINGS[0])] + list(zip(RINGS, RINGS[1:]))
    for i, (sx, sz) in enumerate(CORNERS):
        nx, nz = CORNERS[(i + 1) % 4]
        for ya, yb in bays:
            beam(p, leg_at(sx, sz, ya), leg_at(nx, nz, yb), 0.14, "steel")
            beam(p, leg_at(nx, nz, ya), leg_at(sx, sz, yb), 0.14, "steel")
    for sx, sz in CORNERS:  # amber beacons on the legs
        for y in (6.2, 11.6):
            x, yy, z = leg_at(sx, sz, y)
            p.box((x, yy + 0.32, z), (0.6, 0.34, 0.6), "light")
    # guy cables from the fourth ring to anchor blocks on the other corners
    for sx in (-1, 1):
        p.box((sx * 9.0, 0.95, -sx * 9.0), (1.2, 0.5, 1.2), "trim", bevel=0.05)
        p.box((sx * 9.0, 1.24, -sx * 9.0), (0.4, 0.1, 0.4), "light")
        cable(p, [leg_at(sx, -sx, 11.6), (sx * 9.0, 1.2, -sx * 9.0)], r=0.06, kind="steel")
    # grated platform, rail posts with lamps, the bearing
    p.box((0, Y1 + 0.2, 0), (4.0, 0.4, 4.0), "trim", bevel=0.05)
    p.box((0, Y1 + 0.42, 0), (3.6, 0.04, 3.6), "grille")
    for sx, sz in CORNERS:
        p.box((sx * 1.85, Y1 + 0.65, sz * 1.85), (0.12, 0.5, 0.12), "steel")
        p.box((sx * 1.85, Y1 + 0.96, sz * 1.85), (0.28, 0.14, 0.28), "light")
    p.cylinder("y", (0, Y1 + 0.55, 0), 0.9, 0.3, 12, "steel")
    # the eye: a ribbed housing hung under the platform front, its amber lens forward
    p.box((0, 14.2, -1.2), (0.5, 1.2, 0.5), "steel")
    p.ocyl((0, 13.4, -1.0), (0, 0, -1), 1.3, 1.2, 16, "dark")
    p.ocyl((0, 13.4, -2.2), (0, 0, -1), 1.3, 0.3, 16, "trim", radius2=1.1)
    p.ocyl((0, 13.4, -2.5), (0, 0, -1), 0.95, 0.08, 16, "light")
    for k in range(6):
        t = 2 * math.pi * k / 6
        p.obox((math.cos(t) * 1.32, 13.4 + math.sin(t) * 1.32, -1.6), (0, 0, 1), (math.cos(t), math.sin(t), 0),
               1.2, 0.2, 0.14, "trim")
    # generator shed at the foot (back left) with a team roof and a hot vent
    p.prism_y(rect(-6.8, 6.6, 1.8, 1.4), 0.7, 3.0, "paint", bevel=0.08)
    p.box((-6.8, 3.04, 6.6), (3.4, 0.05, 2.6), "team", bevel=0.012)
    p.box((-6.8, 1.8, 5.18), (2.2, 0.5, 0.05), "power")
    p.ocyl((-7.6, 3.0, 7.2), UP, 0.3, 1.4, 10, "steel")
    p.cylinder("y", (-7.6, 4.44, 7.2), 0.28, 0.08, 10, "power")
    for z in (8.9, 9.9):  # fuel drums
        drum(p, (-4.6, 1.2, z), 0.48, 1.1, "trim", "dark", sides=10, axis="x")
    # battery container (front right) with a hot vent, cabled to the mast
    p.prism_y(rect(8.6, -2.8, 1.2, 1.8), 0.7, 2.3, "trim", bevel=0.06)
    p.box((8.6, 2.33, -2.8), (2.0, 0.04, 3.2), "grille")
    p.box((7.38, 1.5, -2.8), (0.05, 0.36, 2.4), "power")
    cable(p, [(7.4, 2.0, -1.6), (5.4, 0.9, -1.2), leg_at(1, -1, 2.2)], r=0.09, kind="dark")
    cable(p, [(-5.0, 2.2, 5.4), (-3.4, 1.0, 3.6), (-2.4, 1.0, 2.4), leg_at(-1, 1, 3.4)], r=0.09, kind="dark")


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + VV[k] * b + N[k] * n for k in range(3))


def build_radar(p):
    p.cylinder("y", (0, 15.75, 0), 0.6, 0.7, 12, "trim")
    for sx in (-1, 1):  # strut legs to the panel's back
        beam(p, (sx * 0.4, 16.0, 0.0), at(sx * 2.8, -1.0, -0.3), 0.3, "steel")
    beam(p, (0, 16.0, 0.3), at(0, -0.4, -0.3), 0.36, "steel")
    p.obox(PANEL, U, N, PW, PH, 0.4, "paint", bevel=0.04)
    p.obox(at(0, 0, 0.21), U, N, PW - 0.5, PH - 0.45, 0.03, "dark")
    hw, hh = (PW - 0.5) / 2, (PH - 0.45) / 2
    for b in (-hh + 0.05, hh - 0.05):  # amber edge
        p.obox(at(0, b, 0.23), U, N, PW - 0.5, 0.1, 0.02, "light")
    for a in (-hw + 0.05, hw - 0.05):
        p.obox(at(a, 0, 0.23), U, N, 0.1, PH - 0.55, 0.02, "light")
    for a in (-3.9, -1.3, 1.3, 3.9):  # cell lines and one row
        p.obox(at(a, 0, 0.23), U, N, 0.045, PH - 0.55, 0.02, "light")
    p.obox(at(0, 0.0, 0.23), U, N, PW - 0.6, 0.045, 0.02, "light")
    p.obox(at(-4.2, 0.9, 0.26), U, N, 1.6, 1.3, 0.03, "steel")  # welded patches over the face
    p.obox(at(3.1, -1.1, 0.26), U, N, 1.2, 0.9, 0.03, "steel")
    # back: the big team plate, a strut truss, counterweight boxes
    p.obox(at(0, 0.5, -0.22), U, N, PW - 1.0, PH - 1.6, 0.03, "team")
    for a in (-4.4, 0.0, 4.4):
        p.obox(at(a, 0, -0.32), U, N, 0.24, PH - 0.2, 0.2, "dark")
    for s in (-1, 1):
        beam(p, at(s * 5.6, -1.9, -0.3), at(s * 1.0, 1.9, -0.3), 0.14, "steel")
    for sx in (-1, 1):
        p.obox(at(sx * 3.4, -1.6, -0.75), U, N, 1.3, 1.0, 0.8, "trim", bevel=0.04)
        cable(p, [at(sx * 3.4, -1.1, -0.35), at(sx * 2.0, -1.8, -0.45), at(sx * 0.4, -2.0, -0.5)], r=0.07, kind="steel")


def details_base(p):
    rivets(p, (-10.0, 0.701, -8.6), (10.0, 0.701, -8.6), 14, UP)
    rivets(p, (-8.4, 3.041, 5.6), (-5.2, 3.041, 5.6), 5, UP)
    ring(p, (0, 13.4, -2.56), (0, 0, -1), 0.8)
    with p.sub("radar", RADAR_PIVOT, "turn", (0, 1, 0)):
        bolts(p, at(-PW / 2 + 0.3, PH / 2 - 0.1, 0.2), at(PW / 2 - 0.3, PH / 2 - 0.1, 0.2), 16, N)


def build_all(p):
    build_base(p)
    with p.sub("radar", RADAR_PIVOT, "turn", (0, 1, 0)):
        build_radar(p)


unit.run(__file__, "chs_allseer", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_all, details_base)],
         budget=6000,
         previews=[("35", (-42, 37, -50), (0, 9.5, 0), 50),
                   ("80", (0, 66, 10), (0, 6, 0), 50),
                   ("close", (-18, 24, -21), (0, 14.0, 0), 50)])
