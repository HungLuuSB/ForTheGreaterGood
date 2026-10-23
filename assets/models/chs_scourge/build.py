"""Scourge (Chaos missile battery, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_scourge/build.py

New mesh at the T2 defense size (S-104: footprint 3, 24 x 24 studs, about
9 tall with the mast), no blockout before it (the sim's S-106). Big shapes
first: a patched pad with large team plates and hazard striping, a ring of
reactive blocks with amber lights, missile crates and a fuel drum, a
lattice fire-control mast with a radar box and a beacon, a glowing turret
ring; the `launcher` (the def turns it, M-3): an open welded frame on a
turntable with a slab blast shield and a team plate, three exposed
missiles on rails (3-missile salvo) with glowing nose rings, the `muzzle`
at the left missile's nose. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec
PIVOT = (0.0, 1.6, 0.0)
MIS = [(-1.6, 4.4), (0.0, 4.9), (1.6, 4.4)]  # (x, y) of the three missiles
NOSE = -4.2


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(11.6, 1.0), 0.0, 0.8, "dark", bevel=0.1, top_scale=0.99)
    for x, z, w, d in ((7.0, -7.5, 5.0, 4.0), (-8.5, 6.0, 4.0, 5.0)):
        p.box((x, 0.82, z), (w, 0.04, d), "trim", bevel=0.01)
    for sz in (-1, 1):
        p.box((0, 0.84, sz * 9.6), (7.0, 0.05, 2.4), "team", bevel=0.015)
    hazard(p, (-9.6, 0.84, 0), (0, 0, 1), UP, 7.0, 0.6, stripes=12)
    # ring of reactive blocks with amber lights around the turret
    for i in range(12):
        a = math.radians(15 + i * 30)
        c, s = math.cos(a), math.sin(a)
        if i in (2, 3):
            continue  # the crates' gap
        p.obox((c * 5.6, 1.45, s * 5.6), (-s, 0, c), (c, 0, s), 2.6, 1.3, 0.6, "era", bevel=0.05)
        p.obox((c * 5.92, 1.75, s * 5.92), (-s, 0, c), (c, 0, s), 1.8, 0.2, 0.04, "light")
    p.cylinder("y", (0, 1.2, 0), 3.6, 0.8, 24, "paint", bevel=0.05)
    p.cylinder("y", (0, 1.62, 0), 3.4, 0.1, 24, "power")  # turret ring
    # missile crates, a fuel drum, cables
    for x, z, w in ((2.6, 6.4, 1.2), (3.9, 6.6, 1.2), (3.2, 7.8, 1.0)):
        p.box((x, 0.8 + 0.5, z), (w * 2.4, 1.0, w), "trim", bevel=0.05)
    drum(p, (-6.8, 1.6, -6.6), 0.9, 1.6, "paint", "trim", sides=14, axis="y")
    p.box((-6.8, 1.6, -7.52), (0.4, 0.8, 0.05), "power")
    cable(p, [(2.0, 1.4, 5.8), (1.2, 1.4, 4.2), (0.8, 1.5, 3.4)], r=0.12, kind="dark")
    # lattice fire-control mast with a radar box and a beacon
    mx, mz = 7.6, 7.6
    for dx in (-0.6, 0.6):
        for dz in (-0.6, 0.6):
            beam(p, (mx + dx * 1.6, 0.8, mz + dz * 1.6), (mx + dx, 8.0, mz + dz), 0.18, "paint")
    for y in (3.0, 5.5):
        p.box((mx, y, mz), (1.6, 0.1, 1.6), "steel")
    p.box((mx, 8.5, mz), (1.8, 1.0, 1.2), "trim", bevel=0.05)
    p.box((mx, 8.5, mz - 0.62), (1.4, 0.5, 0.05), "light")
    p.box((mx, 9.15, mz), (0.3, 0.3, 0.3), "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 0.86, sz * 11.0), (0.45, 0.14, 0.45), "light")


def details_base(p):
    rivets(p, (-3.0, 0.841, -9.6), (3.0, 0.841, -9.6), 8, UP)
    ring(p, (0, 1.601, 0), UP, 2.6)


def build_launcher(p):
    p.cylinder("y", (0, 1.85, 0), 3.0, 0.5, 20, "trim")  # turntable
    # open welded frame with posts and a slab blast shield
    p.box((0, 3.1, 0.6), (5.2, 0.3, 6.0), "steel")
    for sx in (-1, 1):
        p.box((sx * 2.4, 3.7, 0.6), (0.3, 1.0, 5.6), "trim")
        p.box((sx * 2.4, 2.5, 2.4), (0.4, 1.2, 0.4), "dark")
    p.obox((0, 3.4, 3.6), (1, 0, 0), (0, 0.4, 1), 5.6, 2.4, 0.4, "era", bevel=0.05)
    p.obox((0, 3.5, 3.82), (1, 0, 0), (0, 0.4, 1), 3.0, 1.2, 0.05, "team", bevel=0.01)
    # three exposed missiles on rails with glowing nose rings
    for x, y in MIS:
        p.box((x, y - 0.55, 0.4), (0.3, 0.25, 6.0), "steel")  # rail
        p.cylinder("z", (x, y, 0.6), 0.42, 6.4, 12, "paint")
        p.ocyl((x, y, -2.6), (0, 0, -1), 0.42, 1.4, 12, "trim", radius2=0.1)
        p.cylinder("z", (x, y, -2.45), 0.44, 0.12, 12, "weapon")
        p.cylinder("z", (x, y, 2.4), 0.43, 0.6, 12, "team")
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            c, s = math.cos(a), math.sin(a)
            p.obox((x + c * 0.6, y + s * 0.6, 3.5), (0, 0, 1), (c, s, 0), 0.9, 0.05, 0.4, "trim")
    hazard(p, (0, 3.27, -2.0), (1, 0, 0), UP, 4.8, 0.4, stripes=9)


def no_details(p):
    pass


unit.run(__file__, "chs_scourge", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [MIS[0][0], MIS[0][1], NOSE]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.0, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 4.0, -1.0), 40)])
