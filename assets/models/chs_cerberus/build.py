"""Cerberus (Chaos anti-nuke, T2 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_cerberus/build.py

New mesh from its blockout, at the T2 defense size (S-104: footprint 3,
24 x 24 studs, about 14 tall at the radar mast). Big shapes first: a
reinforced patched pad with large team plates and hazard striping, a
sloped blast deflector at the back, concrete blocks either side of the
launch bay, and the `launcher` (the def's piece, hinged at its rear end): a
rail frame with two interceptor tubes, readiness rings at their mouths
(weapon), a team plate and hazard edges; a braced lattice mast with the
client-turned radar array (`radar`, M-27) and a beacon, a fuel tank with a
gauge. `muzzle` between the tube mouths. Chaos reads rugged and improvised
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec
PIVOT = (0.0, 1.6, 5.2)
MAST = (-7.4, 7.4)


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(11.6, 1.0), 0.0, 1.0, "dark", bevel=0.1, top_scale=0.99)
    for x, z, w, d in ((7.5, 2.0, 5.0, 6.0), (-8.0, -2.5, 4.0, 5.0), (1.5, -9.0, 6.0, 2.6)):
        p.box((x, 1.02, z), (w, 0.04, d), "trim", bevel=0.01)  # patch plates
    for sx in (-1, 1):
        p.box((sx * 7.2, 1.04, -7.6), (4.6, 0.05, 3.2), "team", bevel=0.015)
    hazard(p, (0, 1.04, -6.2), (1, 0, 0), UP, 8.0, 0.6, stripes=14)
    # blast deflector at the back, concrete blocks either side of the bay
    p.prism_x([(6.4, 1.0), (9.6, 1.0), (9.6, 1.6), (7.0, 4.2), (6.4, 4.2)], -4.6, 4.6, "steel", bevel=0.08)
    for sx in (-1, 1):
        p.prism_y(rect(sx * 4.6, 0.8, 0.9, 4.6), 1.0, 3.2, "paint", bevel=0.1, top_scale=0.92)
        p.box((sx * 4.6, 3.24, 0.8), (1.4, 0.05, 6.0), "team", bevel=0.012)
        p.box((sx * (4.6 + 0.92), 2.0, 0.8), (0.05, 0.16, 7.0), "light")
    # fuel tank with a gauge, a cable to the bay
    drum(p, (8.0, 2.2, 7.4), 1.2, 3.2, "paint", "trim", sides=16, axis="x")
    p.cylinder("x", (8.0, 2.2, 7.4), 1.24, 0.6, 16, "team")
    p.box((8.0, 2.2, 6.17), (1.4, 0.4, 0.05), "power")
    cable(p, [(6.4, 1.6, 7.0), (4.0, 1.2, 6.0), (1.5, 1.6, 5.4)], r=0.14, kind="dark")
    # lattice radar mast at the back left, beacons
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

    def leg(dx, dz, y):
        f = 1.3 - 0.8 * (y - 1.0) / 11.0
        return (MAST[0] + dx * f, y, MAST[1] + dz * f)

    for dx, dz in corners:
        beam(p, leg(dx, dz, 1.0), leg(dx, dz, 12.0), 0.24, "paint")
    for y in (4.0, 7.5, 10.5):
        for i, (dx, dz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg(dx, dz, y), leg(nx, nz, y), 0.12, "steel")
            beam(p, leg(dx, dz, y - 3.0), leg(nx, nz, y), 0.08, "steel")
    for dx, dz in corners:
        x, y, z = leg(dx, dz, 7.5)
        p.box((x, y + 0.2, z), (0.32, 0.24, 0.32), "light")
    p.box((MAST[0], 12.1, MAST[1]), (1.2, 0.25, 1.2), "trim")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 1.06, sz * 11.0), (0.45, 0.14, 0.45), "light")

    t = math.radians(20)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (MAST[0], 13.4, MAST[1])
    with p.sub("radar", (MAST[0], 12.3, MAST[1]), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (MAST[0], 12.4, MAST[1]), 0.35, 0.3, 10, "steel")
        p.obox(c, (1, 0, 0), n, 4.2, 2.4, 0.28, "paint", bevel=0.03)
        p.obox(tuple(c[k] + n[k] * 0.15 for k in range(3)), (1, 0, 0), n, 3.8, 2.0, 0.03, "dark")
        for b in (-0.98, 0.98):
            p.obox(tuple(c[k] + n[k] * 0.17 + v[k] * b for k in range(3)), (1, 0, 0), n, 3.8, 0.08, 0.02, "light")
        for a in (-1.25, 0.0, 1.25):
            p.obox((c[0] + a, c[1] + n[1] * 0.17, c[2] + n[2] * 0.17), (1, 0, 0), n, 0.05, 1.9, 0.02, "light")
        p.obox(tuple(c[k] - n[k] * 0.16 + v[k] * 0.5 for k in range(3)), (1, 0, 0), n, 3.6, 0.7, 0.03, "team")
        p.box((MAST[0] + 0.7, 12.9, MAST[1] + 0.6), (0.4, 0.4, 0.4), "light")  # beacon


def details_base(p):
    rivets(p, (-9.5, 1.041, 9.6), (9.5, 1.041, 9.6), 14, UP)


def build_launcher(p):
    p.box((0, 1.95, 0.6), (5.0, 0.5, 9.4), "steel", bevel=0.05)  # rail frame
    for sx in (-1, 1):
        p.box((sx * 2.55, 2.4, 0.6), (0.2, 0.6, 9.0), "trim")
    for z in (-3.2, 0.6, 4.4):
        p.box((0, 2.4, z), (5.0, 0.4, 0.4), "trim")
    hazard(p, (0, 2.22, -4.3), (1, 0, 0), UP, 4.6, 0.4, stripes=9)
    for sx in (-1, 1):
        x = sx * 1.35
        drum(p, (x, 3.1, 0.6), 0.8, 8.6, "paint", "trim", sides=16, axis="z")
        for z in (-1.8, 3.0):
            p.cylinder("z", (x, 3.1, z), 0.84, 0.25, 16, "dark")
        p.cylinder("z", (x, 3.1, -3.72), 0.6, 0.06, 14, "dark")
        p.cylinder("z", (x, 3.1, -3.76), 0.4, 0.04, 14, "weapon")
    p.box((0, 3.95, 1.2), (1.0, 0.05, 4.0), "team", bevel=0.01)


def details_launcher(p):
    for sx in (-1, 1):
        ring(p, (sx * 1.35, 3.1, 4.91), (0, 0, 1), 0.5)


unit.run(__file__, "chs_cerberus", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [0.0, 3.1, -3.9]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 4.0, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 3.0, -1.0), 40)])
