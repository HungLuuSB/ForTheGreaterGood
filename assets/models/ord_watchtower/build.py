"""Watchtower (Order radar tower, T1 structure, footprint 1): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_watchtower/build.py

A square armored tower on a chamfered plinth with front and back buttresses,
a collar and team plates near the top, cyan aviation strips up its corners,
and on a bearing the client-turned `radar` (blockout visual piece): a wide
flat phased-array panel tilted back 15°, its face unlit with a glowing edge
and a thin cell grid (style guide, "Sensor faces"), a team plate on its back
(BAR style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

RADAR_PIVOT = (0.0, 9.0, 0.0)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))  # panel face: forward and up
V = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 10.4, 0.0)
PLINTH = [(-2.3, -3.0), (2.3, -3.0), (3.0, -2.3), (3.0, 2.3), (2.3, 3.0), (-2.3, 3.0), (-3.0, 2.3), (-3.0, -2.3)]


def build_base(p):
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.45, "trim", bevel=0.05, top_scale=0.97)
    p.prism_y(PLINTH, 0.45, 1.9, "paint", bevel=0.06, top_scale=0.9)
    # the tower, its collar and the bearing
    p.prism_y([(-1.2, -1.2), (1.2, -1.2), (1.2, 1.2), (-1.2, 1.2)], 1.9, 8.0, "paint", bevel=0.05)
    p.prism_y([(-1.5, -1.5), (1.5, -1.5), (1.5, 1.5), (-1.5, 1.5)], 8.0, 8.6, "trim", bevel=0.05, top_scale=0.9)
    p.cylinder("y", (0, 8.8, 0), 0.7, 0.4, 14, "steel")
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):  # collar running band
        if sx:
            p.box((sx * 1.47, 8.2, 0), (0.06, 0.12, 2.6), "light")
        else:
            p.box((0, 8.2, sz * 1.47), (2.6, 0.12, 0.06), "light")
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if sx:
            p.box((sx * 1.215, 7.1, 0), (0.05, 0.8, 1.9), "team", bevel=0.01)
        else:
            p.box((0, 7.1, sz * 1.215), (1.9, 0.8, 0.05), "team", bevel=0.01)
    # buttresses front and back, a door with its light, a cable conduit
    for sz in (-1, 1):
        p.prism_x([(sz * 1.2, 1.9), (sz * 1.2, 5.2), (sz * 2.6, 1.9)], -0.35, 0.35, "paint", bevel=0.03)
    p.box((1.21, 3.0, 0), (0.06, 1.8, 0.9), "dark")
    p.box((1.25, 4.05, 0), (0.06, 0.12, 0.8), "light")
    p.cylinder("y", (-1.32, 4.9, 0.7), 0.12, 6.0, 8, "steel")
    # aviation strips up the corners, plinth running lights, louvres
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 1.2, 5.0, sz * 1.2), (0.12, 4.6, 0.12), "light")
    for sx in (-1, 1):
        p.box((sx * 2.95, 1.25, 0), (0.06, 0.12, 3.0), "light")
        p.box((sx * 2.9, 0.9, 0), (0.06, 0.5, 3.4), "grille")


def details_base(p):
    box_seams(p, (0, 0, 0), (5.4, 0, 5.4), 1.901)
    for y in (3.6, 5.6):
        for sx in (-1, 1):
            seam(p, (sx * 1.201, y, -1.1), (sx * 1.201, y, 1.1), (sx, 0, 0))
    bolts(p, (-3.3, 0.451, 3.3), (3.3, 0.451, 3.3), 8, UP)
    bolts(p, (-3.3, 0.451, -3.3), (3.3, 0.451, -3.3), 8, UP)
    ring(p, (0, 8.601, 0), UP, 1.0)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_radar(p):
    p.cylinder("y", (0, 9.25, 0), 0.45, 0.5, 12, "trim")
    for sx in (-1, 1):  # yoke arms up to the panel's back
        p.obox(at(sx * 1.6, -0.6, -0.45), U, N, 0.3, 1.6, 0.3, "steel")
    p.obox((0, 9.55, -0.05), U, (0, 0, 1), 3.6, 0.3, 0.5, "steel")
    p.obox(PANEL, U, N, 5.6, 2.8, 0.35, "paint", bevel=0.04)
    p.obox(at(0, 0, 0.18), U, N, 5.1, 2.4, 0.03, "dark")
    for b in (-1.16, 1.16):  # glowing edge, top and bottom
        p.obox(at(0, b, 0.2), U, N, 5.1, 0.08, 0.02, "light")
    for a in (-2.51, 2.51):  # sides
        p.obox(at(a, 0, 0.2), U, N, 0.08, 2.24, 0.02, "light")
    for i in range(1, 7):  # cell grid columns
        p.obox(at(-2.55 + i * 0.73, 0, 0.2), U, N, 0.04, 2.24, 0.02, "light")
    for b in (-0.4, 0.4):  # rows
        p.obox(at(0, b, 0.2), U, N, 4.94, 0.04, 0.02, "light")
    p.obox(at(0, 0, -0.18), U, N, 4.2, 1.8, 0.03, "team")


def details_radar(p):
    for b in (-1.3, 1.3):
        bolts(p, at(-2.6, b, 0.18), at(2.6, b, 0.18), 10, N)


unit.run(__file__, "ord_watchtower", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("radar", "base", RADAR_PIVOT, build_radar, details_radar)],
         budget=6000)
