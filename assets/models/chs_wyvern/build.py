"""Wyvern (Chaos long-range radar SAM site, T2 structure, footprint 3):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_wyvern/build.py

New mesh from its blockout, at the T2 defense size (S-104: footprint 3,
24 x 24 studs, about 12 tall at the radar mast). Big shapes first: a round
patched pad with large team plates and hazard striping, a ring of reactive
blocks with amber lights round a glowing turret ring, ammo crates and fuel
drums cabled in, and a lattice mast at the back right carrying a flat radar
panel with an amber eye (client-turned `radar`, M-27). The `launcher` (the
def turns it, M-3): a welded turntable post with a slab blast shield and a
team plate, an open frame holding twelve bare canister tubes standing
upright in two rows (vertical launch, the user 2026-10-24; more tubes than
the Aegis), their mouths ringed amber when ready (`weapon`), `muzzle` at the
front left tube. Chaos reads rugged and
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
PIVOT = (-3.0, 3.8, 1.0)
MAST = (6.0, 5.0)
ELEV = math.radians(90)  # vertical launch
AXIS = (0.0, math.sin(ELEV), -math.cos(ELEV))
NORM = (0.0, math.cos(ELEV), math.sin(ELEV))
FRAME = (-3.0, 7.6, 1.0)  # centre of the tube frame, above the post
TUBE_LEN = 6.4
XS = (-4.4, -3.6, -2.8, 2.8, 3.6, 4.4)  # tube columns either side of the post
ROWS = (-0.45, 0.45)  # along NORM


def along(c, d, k):
    return tuple(c[i] + d[i] * k for i in range(3))


def tube_c(dx, row):
    return tuple(FRAME[i] + (dx if i == 0 else 0) + NORM[i] * row for i in range(3))


MUZZLE = along(tube_c(XS[0], ROWS[1]), AXIS, TUBE_LEN / 2 + 0.1)


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.cylinder("y", (0, 0.4, 0), 11.4, 0.8, 32, "dark", bevel=0.1)
    for x, z, w, d in ((7.5, -6.0, 4.0, 3.0), (-7.5, 5.5, 3.6, 4.4), (1.0, 8.6, 3.0, 2.0)):
        p.box((x, 0.82, z), (w, 0.04, d), "trim", bevel=0.01)  # patches
    p.box((5.0, 0.85, -5.0), (4.4, 0.05, 4.4), "team", bevel=0.015)
    p.box((-7.6, 0.85, -3.0), (2.6, 0.05, 5.0), "team", bevel=0.015)
    hazard(p, (0, 0.85, -10.2), (1, 0, 0), UP, 7.0, 0.6, stripes=12)
    # reactive blocks round the post, a glowing turret ring
    x0, _, z0 = PIVOT
    for i in range(10):
        a = math.radians(i * 36 + 18)
        c, s = math.cos(a), math.sin(a)
        p.obox((x0 + c * 4.2, 1.4, z0 + s * 4.2), (-s, 0, c), (c, 0, s), 2.2, 1.2, 0.6, "era", bevel=0.05)
        p.obox((x0 + c * 4.52, 1.7, z0 + s * 4.52), (-s, 0, c), (c, 0, s), 1.4, 0.18, 0.04, "light")
    p.cylinder("y", (x0, 1.4, z0), 2.6, 1.2, 20, "paint", bevel=0.05)
    p.cylinder("y", (x0, 2.04, z0), 2.4, 0.1, 20, "power")
    # ammo crates, fuel drums, cables
    for x, z in ((3.4, 6.6), (4.8, 6.9), (4.1, 8.1)):
        p.box((x, 1.3, z), (1.2, 1.0, 2.6), "trim", bevel=0.05)
        p.box((x, 1.82, z), (1.0, 0.04, 2.2), "team", bevel=0.01)
    for x, z in ((-8.0, -7.0), (-6.6, -7.8)):
        drum(p, (x, 1.6, z), 0.8, 1.6, "paint", "trim", sides=14, axis="y")
    p.box((-8.0, 1.6, -7.82), (0.36, 0.7, 0.05), "power")
    cable(p, [(-6.0, 0.9, -6.4), (-4.6, 0.9, -3.4), (-3.4, 1.2, -1.6)], r=0.13, kind="dark")
    cable(p, [(MAST[0] - 1.0, 0.9, MAST[1] - 1.0), (2.0, 0.9, 3.0), (-1.0, 1.2, 1.6)], r=0.13, kind="dark")
    # lattice mast at the back right
    mx, mz = MAST
    for dx in (-0.7, 0.7):
        for dz in (-0.7, 0.7):
            beam(p, (mx + dx * 1.8, 0.8, mz + dz * 1.8), (mx + dx, 9.2, mz + dz), 0.2, "paint")
    for y in (3.0, 6.0):
        p.box((mx, y, mz), (1.8, 0.12, 1.8), "steel")
        beam(p, (mx - 0.9, y - 1.4, mz - 0.9), (mx + 0.9, y + 1.4, mz - 0.9), 0.12, "trim")
    p.box((mx, 9.4, mz), (1.6, 0.4, 1.6), "trim", bevel=0.04)
    p.box((mx + 1.0, 10.6, mz + 0.6), (0.2, 0.2, 0.2), "light")  # beacon
    for x, z in ((10.4, 3.0), (-10.4, 3.0), (3.0, -10.6), (-3.0, 10.6)):
        p.box((x, 0.86, z), (0.45, 0.14, 0.45), "light")

    t = math.radians(14)
    n = (0, math.sin(t), -math.cos(t))
    c = (mx, 11.2, mz)
    with p.sub("radar", (mx, 9.6, mz), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (mx, 9.9, mz), 0.5, 0.6, 12, "dark")
        p.obox(c, (1, 0, 0), n, 5.2, 3.0, 0.36, "paint", bevel=0.04)
        p.obox(along(c, n, 0.19), (1, 0, 0), n, 4.6, 2.5, 0.03, "grille")
        p.obox(along(c, n, 0.21), (1, 0, 0), n, 1.2, 0.5, 0.03, "head")  # the amber eye
        p.obox(along(c, n, -0.2), (1, 0, 0), n, 3.6, 2.2, 0.03, "team")
        for sx in (-1, 1):
            beam(p, (mx + sx * 2.4, 9.8, mz + 0.6), (mx + sx * 2.0, 10.6, mz + 0.2), 0.12, "trim")


def details_base(p):
    rivets(p, (-3.0, 0.841, -9.4), (3.0, 0.841, -9.4), 8, UP)
    ring(p, (PIVOT[0], 2.001, PIVOT[2]), UP, 1.8)


def build_launcher(p):
    x0, y0, z0 = PIVOT
    p.cylinder("y", (x0, y0 - 1.6, z0), 1.4, 3.2, 14, "trim")  # welded post
    p.cylinder("y", (x0, y0 + 0.1, z0), 2.0, 0.4, 18, "steel")  # turntable
    # slab blast shield behind the frame, with a team plate
    p.obox((x0, y0 + 2.6, z0 + 1.9), (1, 0, 0), (0, 0, 1), 10.6, 3.4, 0.4, "era", bevel=0.05)
    p.obox((x0, y0 + 2.8, z0 + 2.12), (1, 0, 0), (0, 0, 1), 3.2, 1.4, 0.05, "team", bevel=0.01)
    # the frame: rails along the tubes and cross bars, raised 38 degrees
    for dx in (-5.0, -2.2, 2.2, 5.0):  # posts behind the tubes
        p.obox(tuple(FRAME[i] + (dx if i == 0 else 0) + NORM[i] * 0.95 for i in range(3)), (1, 0, 0), NORM, 0.35, TUBE_LEN, 0.35, "steel")
    for k in (-2.2, 0.0, 2.2):  # cross bars strapping the tubes
        p.obox(along(tuple(FRAME[i] + NORM[i] * 0.9 for i in range(3)), AXIS, k), (1, 0, 0), NORM, 10.4, 0.3, 0.3, "trim")
    p.box((x0, y0 + 0.6, z0), (10.0, 0.4, 2.6), "steel")  # the cross beam the tubes stand on
    for sx in (-1, 1):
        p.box((x0 + sx * 1.5, y0 + 1.0, z0 - 1.0), (0.4, 1.4, 0.4), "dark")
    # twelve bare tubes, amber ready rings at the mouths
    for dx in XS:
        for row in ROWS:
            c = tube_c(dx, row)
            p.ocyl(along(c, AXIS, -TUBE_LEN / 2), AXIS, 0.38, TUBE_LEN, 12, "paint")
            m = along(c, AXIS, TUBE_LEN / 2)
            p.ocyl(m, AXIS, 0.42, 0.08, 12, "weapon")
            p.ocyl(along(c, AXIS, -TUBE_LEN / 2 + 1.2), AXIS, 0.41, 0.5, 12, "team")
    hazard(p, (PIVOT[0], PIVOT[1] + 0.81, PIVOT[2] - 1.31), (1, 0, 0), (0, 0, -1), 8.0, 0.4, stripes=14)
    # sensor box on the post
    p.box((x0, y0 + 1.6, z0 - 1.4), (1.0, 0.6, 0.8), "trim", bevel=0.04)
    p.box((x0, y0 + 1.6, z0 - 1.82), (0.7, 0.3, 0.05), "head")


def no_details(p):
    pass


unit.run(__file__, "chs_wyvern", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [round(v, 3) for v in MUZZLE]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.5, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 5.0, -1.0), 40)])
