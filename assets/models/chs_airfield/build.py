"""Airfield (Chaos air factory, T1 structure, footprint 5): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_airfield/build.py

A 38-stud dark apron of patched plates with a runway (team centre stripe,
amber edge lights), an open hangar (a roof on four posts and a back wall,
team plate on the roof, build lights along the posts and the roof edge:
power channel, pulses while producing), two fuel tanks with amber gauges,
and a braced lattice mast with a static radar panel and a beacon (BAR style,
M-15; Chaos reads light and open, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

RX = 3.0


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y([(-19, -19), (19, -19), (19, 19), (-19, 19)], 0.0, 0.4, "dark", bevel=0.05)
    for x, z, w, d in ((-10, -12, 9, 7), (11, 4, 7, 10), (-14, 1, 6, 5)):  # patch plates
        p.box((x, 0.42, z), (w, 0.04, d), "trim")
    # runway, team stripe, edge lights
    p.box((RX, 0.45, 0), (9, 0.1, 37), "steel")
    p.box((RX, 0.51, 0), (0.6, 0.03, 30), "team")
    for i in range(6):
        z = -16 + i * 6.4
        for x in (RX - 4.8, RX + 4.8):
            p.box((x, 0.55, z), (0.4, 0.3, 0.4), "light")
    # open hangar: roof on posts, back wall, team plate, build lights
    hx, hz = -12.0, 8.0
    p.box((hx, 5.4, hz), (12.4, 0.4, 12.4), "paint", bevel=0.04)
    p.box((hx, 5.63, hz), (8, 0.05, 6), "team")
    p.box((hx, 2.9, hz + 5.8), (12, 5, 0.4), "paint", bevel=0.03)
    for px, pz in ((-17.6, 2.4), (-6.4, 2.4), (-17.6, 13.6), (-6.4, 13.6)):
        p.box((px, 2.8, pz), (0.5, 5.2, 0.5), "trim")
    for px in (-17.6, -6.4):  # build lights up the front posts
        p.box((px, 2.8, 2.13), (0.36, 4.6, 0.06), "power")
        p.box((px + 0.27, 2.8, 2.4), (0.06, 4.6, 0.36), "power")
    p.box((hx, 5.15, hz - 6.15), (11.6, 0.2, 0.06), "power")  # roof edge
    for k in range(3):  # work lamps under the roof
        p.box((hx - 4 + k * 4, 5.15, hz), (2.4, 0.08, 1.0), "power")
    beam(p, (-17.6, 0.4, 2.4), (-17.6, 5.2, 7.0), 0.18, "steel")
    beam(p, (-6.4, 0.4, 2.4), (-6.4, 5.2, 7.0), 0.18, "steel")
    # fuel tanks with gauges
    for z in (-12.0, -7.6):
        p.cylinder("y", (13, 1.9, z), 1.7, 3.0, 12, "paint")
        p.cylinder("y", (13, 3.45, z), 1.3, 0.1, 12, "trim")
        p.box((11.27, 1.9, z), (0.06, 1.6, 0.3), "dark")
        p.box((11.24, 1.7, z), (0.04, 1.0, 0.18), "power")
    p.cylinder("z", (13, 2.6, -9.8), 0.2, 2.6, 8, "steel")
    # lattice mast, radar panel, beacon
    mx, mz = 13.0, 10.0
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(p, (mx + sx * 1.4, 0.4, mz + sz * 1.4), (mx + sx * 0.4, 10.0, mz + sz * 0.4), 0.22, "paint")
    for y in (3.5, 7.0):
        f = 1.4 - (1.0 * (y - 0.4) / 9.6)
        for a, b in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
            beam(p, (mx + a[0] * f, y, mz + a[1] * f), (mx + b[0] * f, y, mz + b[1] * f), 0.12, "steel")
    t = math.radians(20)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (mx, 11.0, mz)
    p.obox(c, (1, 0, 0), n, 3.0, 2.0, 0.3, "paint", bevel=0.03)
    p.obox(tuple(c[k] + n[k] * 0.16 for k in range(3)), (1, 0, 0), n, 2.7, 1.7, 0.03, "dark")
    for b in (-0.85, 0.85):
        p.obox(tuple(c[k] + n[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), n, 2.7, 0.08, 0.02, "light")
    p.box((mx, 12.3, mz), (0.5, 0.5, 0.5), "light")  # beacon
    p.box((mx, 10.1, mz), (1.2, 0.2, 1.2), "trim")

    # approach lights at both runway ends, apron edge lights
    for zs in (-1, 1):
        for k in range(5):
            p.box((RX - 3.2 + k * 1.6, 0.48, zs * 18.6), (0.9, 0.12, 0.4), "light")
    for i in range(7):
        t = -16.5 + i * 5.5
        for a, b in ((t, -18.85), (t, 18.85), (-18.85, t), (18.85, t)):
            p.box((a, 0.3, b), (0.5, 0.14, 0.5), "light")

def details_base(p):
    for z in (-10.0, 6.0):
        seam(p, (-18.5, 0.401, z), (-2.0, 0.401, z), UP)
    bolts(p, (-18.4, 0.401, 18.4), (18.4, 0.401, 18.4), 20, UP)
    for z in (-12.0, -7.6):
        ring(p, (13, 3.501, z), UP, 1.0)


unit.run(__file__, "chs_airfield", "chaos", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
