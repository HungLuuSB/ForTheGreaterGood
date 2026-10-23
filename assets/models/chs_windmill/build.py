"""Wind turbine (Chaos, T1 structure, footprint 2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_windmill/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
a thin mast to about 18), not rescaled. Big shapes first: a skid slab with
team plates, a tall open lattice mast on four splayed legs with braced
rings and guy cables to anchor blocks, a generator shed with a team roof
and a hot vent at the foot, a boxy nacelle with an orange generator band
(power: dims on an energy stall) and a beacon, and the client-spun `rotor`
(turning about Z at the hub): a stubby hub and one long two-ended blade
bar, crooked like salvage, with team tips. Chaos reads rugged and open
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

HUB = (0.0, 15.4, -1.8)
FOOT, TOP = 3.6, 0.8
Y0, Y1 = 0.7, 14.6


def leg_at(sx, sz, y):
    t = (y - Y0) / (Y1 - Y0)
    r = FOOT + (TOP - FOOT) * t
    return (sx * r, y, sz * r)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(7.8, 0.7), 0.0, 0.7, "dark", bevel=0.1, top_scale=0.985)
    for z in (-6.2, 6.2):
        p.box((-4.0, 0.74, z), (3.0, 0.05, 1.2), "team", bevel=0.012)
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sz in corners:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.36, "paint")
        p.box((sx * FOOT, 0.95, sz * FOOT), (0.9, 0.5, 0.9), "trim", bevel=0.05)
    for y in (3.8, 7.2, 10.6, 13.4):
        for i, (sx, sz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.16, "steel")
    for i, (sx, sz) in enumerate(corners):  # X-braces in the lowest bay
        nx, nz = corners[(i + 1) % 4]
        beam(p, leg_at(sx, sz, Y0 + 0.3), leg_at(nx, nz, 3.8), 0.1, "dark")
    for sx, sz in corners:  # beacons on the legs
        x, y, z = leg_at(sx, sz, 7.6)
        p.box((x, y, z), (0.45, 0.3, 0.45), "light")
    # guy cables to anchor blocks
    for sx, sz in ((-1, -1), (1, 1)):
        a = (sx * 6.6, 0.7, sz * 6.6)
        p.box((a[0], 1.0, a[2]), (0.9, 0.6, 0.9), "trim", bevel=0.06)
        cable(p, [(a[0], 1.3, a[2]), leg_at(sx, sz, 10.6)], r=0.04, kind="steel")
    # generator shed at the foot: team roof, hot vent, a cable up the mast
    p.prism_y(rect(4.4, -4.6, 1.8, 1.5), 0.7, 2.8, "paint", bevel=0.1)
    p.box((4.4, 2.84, -4.6), (3.2, 0.05, 2.6), "team", bevel=0.02)
    p.box((4.4, 1.8, -6.12), (2.4, 0.45, 0.05), "power")
    cable(p, [(3.0, 2.0, -3.4), (1.6, 3.0, -1.6), (0.3, 14.0, 0.2)], r=0.07)
    hazard(p, (-2.0, 0.72, -6.9), (1, 0, 0), (0, 1, 0), 4.0, 0.4, stripes=8)
    # nacelle: boxy, generator band, team top, beacon, a vent at the back
    p.cylinder("y", (0, 14.75, 0.3), 0.7, 0.3, 12, "steel")
    p.box((0, 15.4, 0.6), (1.9, 1.5, 3.6), "paint", bevel=0.08)
    p.box((0, 15.4, 0.7), (1.96, 0.4, 2.6), "power")
    p.box((0, 16.17, 0.9), (1.5, 0.05, 1.8), "team", bevel=0.01)
    p.box((0, 16.3, 2.0), (0.36, 0.24, 0.36), "light")
    p.box((0, 15.4, 2.42), (1.4, 1.0, 0.05), "grille")


def details_base(p):
    rivets(p, (2.8, 2.83, -5.6), (6.0, 2.83, -5.6), 5, UP)


def build_rotor(p):
    hx, hy, hz = HUB
    p.cylinder("z", (hx, hy, hz + 0.15), 0.62, 0.7, 12, "trim")
    p.ocyl((hx, hy, hz - 0.2), (0, 0, -1), 0.6, 0.45, 12, "dark")
    a = math.radians(108)  # one long bar, crooked off vertical
    d = (math.cos(a), math.sin(a), 0.0)
    u = (-math.sin(a), math.cos(a), 0.0)
    p.obox((hx, hy, hz - 0.35), u, (0, 0, -1), 0.75, 13.6, 0.18, "paint", bevel=0.03)
    p.obox((hx, hy, hz - 0.3), u, (0, 0, -1), 0.45, 2.4, 0.35, "steel")  # clamp
    for s in (-1, 1):
        tip = (hx + d[0] * s * 6.3, hy + d[1] * s * 6.3, hz - 0.35)
        p.obox(tip, u, (0, 0, -1), 0.78, 0.9, 0.2, "team")
        patch = (hx + d[0] * s * 3.4, hy + d[1] * s * 3.4, hz - 0.45)
        p.obox(patch, u, (0, 0, -1), 0.9, 0.7, 0.06, "trim")  # welded patch


def details_rotor(p):
    ring(p, (HUB[0], HUB[1], HUB[2] - 0.42), (0, 0, -1), 0.5, segments=10)


unit.run(__file__, "chs_windmill", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", HUB, build_rotor, details_rotor)],
         budget=6000,
         previews=[("35", (-26, 22, -30), (0, 9.0, 0), 50),
                   ("80", (0, 46, 8), (0, 6, 0), 50),
                   ("close", (-13, 15, -16), (0, 12.0, 0), 35)])
