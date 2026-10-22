"""Shipyard (Chaos naval factory, T1 structure, footprint 5, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_shipyard/build.py

A light quay at the back with a corrugated shed (shed-door build lights,
power channel, pulses while producing) and two salvage tanks, two narrow
piers on piles reaching over the water with team plates and amber lights at
the tips, and a tall lattice tower crane at the left with a long jib over
the slip, a team band and a build lamp at its hook trolley (BAR style, M-15;
Chaos reads light and open, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y([(-19, 12), (19, 12), (19, 19), (-19, 19)], 0.0, 0.6, "dark", bevel=0.04)
    # shed with door and build lights, two tanks
    p.box((-6, 3.1, 15.5), (14, 5, 6), "paint", bevel=0.05)
    p.box((-6, 5.63, 15.5), (12, 0.05, 4.6), "team", bevel=0.012)
    p.box((-6, 2.6, 12.46), (10, 4.0, 0.1), "dark")
    for i in range(4):
        p.box((-6, 1.0 + i * 0.95, 12.38), (9.6, 0.14, 0.06), "power")
    for sx in (-1, 1):
        p.box((-6 + sx * 5.2, 2.6, 12.4), (0.3, 4.2, 0.12), "power")
    for x in (6, 10):
        p.cylinder("y", (x, 2.6, 15.5), 1.5, 4.0, 12, "trim")
        p.cylinder("y", (x, 4.0, 15.5), 1.55, 0.12, 12, "steel")
        p.box((x, 2.4, 13.97), (0.3, 1.6, 0.06), "power")
    # piers on piles
    for sx in (-1, 1):
        x = sx * 16.5
        p.box((x, 1.4, -2), (4.5, 1.2, 33), "paint", bevel=0.04)
        p.box((x, 2.03, -10), (3.4, 0.05, 8), "team", bevel=0.01)
        for i in range(5):
            p.cylinder("y", (x, 0.4, -16 + i * 7.5), 0.4, 1.4, 8, "steel")
        p.box((x, 2.3, -18), (0.6, 0.6, 0.6), "light")
        for z in (-12.0, -2.0, 8.0):
            p.box((x - sx * 2.28, 1.4, z), (0.06, 0.16, 3.0), "light")
    # tower crane: lattice tower, jib, counter-jib, trolley
    for dx in (-1, 1):
        for dz in (-1, 1):
            beam(p, (-16.5 + dx, 2.0, 4 + dz), (-16.5 + dx, 14.0, 4 + dz), 0.3, "paint")
    for y in (5.0, 9.0, 13.0):
        for a, b in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
            beam(p, (-16.5 + a[0], y, 4 + a[1]), (-16.5 + b[0], y, 4 + b[1]), 0.14, "steel")
    p.box((-4, 14.2, 4), (26, 0.8, 1.0), "paint", bevel=0.03)
    p.box((0, 14.63, 4), (12, 0.05, 0.8), "team")
    p.box((-21.5, 14.2, 4), (5, 0.7, 1.0), "trim")
    p.box((-22.5, 13.3, 4), (1.6, 1.2, 1.2), "steel")  # counterweight
    p.box((4.0, 13.5, 4), (1.4, 0.6, 1.2), "trim")  # trolley
    p.box((4.0, 13.17, 4), (0.8, 0.06, 0.8), "power")
    p.box((9, 14.8, 4), (0.6, 0.6, 0.6), "light")


def details_base(p):
    bolts(p, (-18.5, 0.601, 18.5), (18.5, 0.601, 18.5), 20, UP)
    for x in (6, 10):
        ring(p, (x, 4.601, 15.5), UP, 1.2)


unit.run(__file__, "chs_shipyard", "chaos", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
