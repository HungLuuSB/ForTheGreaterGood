"""Wind turbine (Chaos, T1 structure, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_windmill/build.py

An open lattice mast on a skid with a team plate, a small boxy nacelle with
an orange generator band (power channel: dims on an energy stall) and a
beacon, and the client-spun `rotor` (blockout visual piece, turning about Z
at the hub): a stubby hub and one long two-ended blade bar, crooked like
salvage (BAR style, M-15; Chaos reads light and open, M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

HUB = (0.0, 10.4, -1.2)
FOOT, TOP = 2.2, 0.6
Y0, Y1 = 0.45, 9.8


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
    p.prism_y([(-3.2, -3.2), (3.2, -3.2), (3.2, 3.2), (-3.2, 3.2)], 0.0, 0.45, "dark", bevel=0.03)
    p.box((0, 0.49, 2.2), (4.0, 0.05, 1.2), "team", bevel=0.012)
    p.box((1.6, 0.85, -1.9), (1.4, 0.8, 1.0), "trim", bevel=0.03)  # inverter box
    p.box((1.6, 0.85, -2.41), (1.1, 0.3, 0.04), "power")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sz in corners:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.28, "paint")
        p.box((sx * FOOT, 0.6, sz * FOOT), (0.6, 0.3, 0.6), "trim")
    for y in (3.4, 6.8):
        for i, (sx, sz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.14, "steel")
    for sx, sz in corners:  # leg beacons
        x, y, z = leg_at(sx, sz, 5.0)
        p.box((x, y, z), (0.4, 0.28, 0.4), "light")
    # nacelle, generator band, beacon
    p.box((0, 10.4, 0.3), (1.3, 1.1, 2.6), "paint", bevel=0.05)
    p.box((0, 10.4, 0.3), (1.36, 0.3, 1.8), "power")
    p.box((0, 10.97, 0.6), (1.0, 0.05, 1.2), "team", bevel=0.01)
    p.box((0, 11.05, 1.3), (0.3, 0.2, 0.3), "light")
    p.cylinder("y", (0, 9.85, 0.3), 0.45, 0.2, 10, "steel")


def details_base(p):
    bolts(p, (-2.9, 0.451, -2.9), (2.9, 0.451, -2.9), 8, UP)
    bolts(p, (-2.9, 0.451, 2.9), (2.9, 0.451, 2.9), 8, UP)


def build_rotor(p):
    hx, hy, hz = HUB
    p.cylinder("z", (hx, hy, hz + 0.1), 0.42, 0.5, 10, "trim")
    p.ocyl((hx, hy, hz - 0.15), (0, 0, -1), 0.4, 0.3, 10, "dark")
    a = math.radians(110)  # one long bar, crooked off vertical
    d = (math.cos(a), math.sin(a), 0.0)
    u = (-math.sin(a), math.cos(a), 0.0)
    p.obox((hx, hy, hz - 0.25), u, (0, 0, -1), 0.5, 9.0, 0.12, "paint", bevel=0.02)
    p.obox((hx, hy, hz - 0.2), u, (0, 0, -1), 0.3, 1.6, 0.25, "steel")  # clamp
    for s in (-1, 1):
        tip = (hx + d[0] * s * 4.2, hy + d[1] * s * 4.2, hz - 0.25)
        p.obox(tip, u, (0, 0, -1), 0.52, 0.5, 0.14, "team")


def details_rotor(p):
    ring(p, (HUB[0], HUB[1], HUB[2] - 0.3), (0, 0, -1), 0.35, segments=10)


unit.run(__file__, "chs_windmill", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", HUB, build_rotor, details_rotor)],
         budget=6000)
