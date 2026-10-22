"""Eye (Chaos radar tower, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_eye/build.py

An open lattice mast on a skid: four splayed legs with braces, a small
platform, the amber "eye" sensor hung under it, amber aviation lights at the
corners, and on a bearing the client-turned `radar` (blockout visual piece):
a flat phased-array panel tilted back 15°, never a dish, its face unlit with
an amber edge and three cell lines, a counterweight box hung on one side and
a team stripe on its back (BAR style, M-15; Chaos reads light and open,
M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

RADAR_PIVOT = (0.0, 8.9, 0.0)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))
V = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 10.0, 0.0)
FOOT, TOP = 2.3, 0.75  # leg spread at the skid and at the top
Y0, Y1 = 0.45, 8.4


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
    p.prism_y([(-3.3, -3.3), (3.3, -3.3), (3.3, 3.3), (-3.3, 3.3)], 0.0, 0.45, "dark", bevel=0.03)
    for sz in (-1, 1):  # skid team plates between the foot pads (bigger, user review 2026-10-23)
        p.box((0, 0.49, sz * 2.35), (3.7, 0.05, 1.7), "team", bevel=0.012)
    for sx in (-1, 1):  # skid edge lights, all four sides
        p.box((sx * 3.25, 0.3, 0), (0.06, 0.12, 4.6), "light")
        p.box((0, 0.3, sx * 3.25), (4.6, 0.12, 0.06), "light")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sz in corners:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.3, "paint")
        p.box((sx * FOOT, 0.6, sz * FOOT), (0.7, 0.3, 0.7), "trim")
    # braces: rings of beams at two heights, an X on the front and back
    for y in (3.0, 6.0):
        for i, (sx, sz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.16, "steel")
    for sz in (-1, 1):
        beam(p, leg_at(-1, sz, Y0 + 0.3), leg_at(1, sz, 3.0), 0.12, "steel")
        beam(p, leg_at(1, sz, Y0 + 0.3), leg_at(-1, sz, 3.0), 0.12, "steel")
    # platform, bearing, aviation lights on its corners
    p.box((0, 8.55, 0), (1.9, 0.3, 1.9), "trim", bevel=0.03)
    p.cylinder("y", (0, 8.8, 0), 0.55, 0.2, 12, "steel")
    for sx, sz in corners:
        p.box((sx * 0.85, 8.78, sz * 0.85), (0.22, 0.16, 0.22), "light")
    for sx, sz in corners:  # beacons half-way up the legs
        x, y, z = leg_at(sx, sz, 4.5)
        p.box((x, y, z), (0.42, 0.3, 0.42), "light")
    # the eye: a housing hung under the platform, its amber lens forward
    p.box((0, 7.9, -0.6), (0.3, 0.9, 0.3), "steel")
    p.ocyl((0, 7.3, -0.6), (0, 0, -1), 0.6, 0.5, 14, "dark")
    p.ocyl((0, 7.3, -1.1), (0, 0, -1), 0.42, 0.06, 14, "light")


def details_base(p):
    bolts(p, (-3.0, 0.451, -3.0), (3.0, 0.451, -3.0), 8, UP)
    bolts(p, (-3.0, 0.451, 3.0), (3.0, 0.451, 3.0), 8, UP)
    ring(p, (0, 7.3, -1.17), (0, 0, -1), 0.5)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_radar(p):
    p.cylinder("y", (0, 9.1, 0), 0.35, 0.4, 10, "trim")
    p.obox(at(0, -0.7, -0.35), U, N, 0.3, 1.4, 0.3, "steel")
    p.obox(PANEL, U, N, 4.8, 2.4, 0.3, "paint", bevel=0.03)
    p.obox(at(0, 0, 0.16), U, N, 4.4, 2.0, 0.03, "dark")
    for b in (-0.98, 0.98):  # amber edge
        p.obox(at(0, b, 0.18), U, N, 4.4, 0.08, 0.02, "light")
    for a in (-2.16, 2.16):
        p.obox(at(a, 0, 0.18), U, N, 0.08, 1.88, 0.02, "light")
    for a in (-1.1, 0.0, 1.1):  # three cell lines
        p.obox(at(a, 0, 0.18), U, N, 0.04, 1.88, 0.02, "light")
    p.obox(at(0, 0.75, -0.16), U, N, 4.0, 0.4, 0.03, "team")
    p.obox(at(2.1, -0.9, -0.45), U, N, 0.8, 0.7, 0.5, "trim", bevel=0.03)  # counterweight


def details_radar(p):
    bolts(p, at(-2.2, 1.1, 0.16), at(2.2, 1.1, 0.16), 8, N)


unit.run(__file__, "chs_eye", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("radar", "base", RADAR_PIVOT, build_radar, details_radar)],
         budget=6000)
