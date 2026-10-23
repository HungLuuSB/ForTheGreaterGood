"""Watchtower (Order radar tower, T1 structure, footprint 1): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_watchtower/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 12 tall: thin and tall). Big shapes first: a chamfered slab, an
armored plinth with sloped walls, team plates and a lit door, a tapered
square tower with corner ribs, buttresses, an armored collar with a running
band, large team plates on its upper faces and a service ladder at the
back; an equipment deck with corner lights and rail posts; and on a
bearing the client-turned `radar` (blockout visual piece): a wide flat
phased-array panel tilted back 15 degrees, its face unlit with a glowing
edge and a cell grid (style guide, "Sensor faces"), a framed back with a
large team plate and a finned equipment box. Order reads heavy and clean
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

RADAR_PIVOT = (0.0, 9.3, 0.0)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))  # panel face: forward and up
V = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 11.0, 0.0)
T0, T1 = 1.9, 8.6  # tower bottom and top
H0, H1 = 1.45, 1.05  # tower half widths at the bottom and top


def half(y):
    return H0 + (H1 - H0) * (y - T0) / (T1 - T0)


def build_base(p):
    p.prism_y(octagon(3.85, 0.6), 0.0, 0.5, "trim", bevel=0.08, top_scale=0.98)
    p.prism_y(octagon(3.0, 0.8), 0.5, 1.9, "paint", bevel=0.12, top_scale=0.84)
    for sz in (-1, 1):
        p.obox((0, 1.25, sz * 2.78), (1, 0, 0), (0.0, 0.48, sz * 1.4), 2.6, 0.9, 0.05, "team", bevel=0.015)
    for sx in (-1, 1):
        p.obox((sx * 2.78, 1.25, 0), (0, 0, 1), (sx * 1.4, 0.48, 0), 2.6, 0.9, 0.05, "paint", bevel=0.015)
        p.box((sx * 3.82, 0.3, 0), (0.05, 0.12, 3.6), "light")
    hazard(p, (0, 0.52, -3.4), (1, 0, 0), UP, 4.6, 0.36, stripes=10)
    # the tapered tower and its corner ribs
    p.prism_y(rect(0, 0, H0, H0), T0, T1, "paint", bevel=0.1, top_scale=H1 / H0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = (sx * (H0 + 0.02), T0, sz * (H0 + 0.02))
            b = (sx * (H1 + 0.02), T1 - 0.2, sz * (H1 + 0.02))
            p.obox(tuple((a[k] + b[k]) / 2 for k in range(3)), (sx, 0, -sz), (b[0] - a[0], b[1] - a[1], b[2] - a[2]),
                   0.32, 0.32, math.dist(a, b), "trim")
            p.obox(tuple((a[k] + b[k]) / 2 for k in range(3)), (sx, 0, -sz), (b[0] - a[0], b[1] - a[1], b[2] - a[2]),
                   0.36, 0.08, math.dist(a, b) * 0.42, "light")
    # buttresses on all four sides: sloped plates leaning on the tower
    for sx in (-1, 1):
        p.obox((sx * (H0 + 0.35), 2.9, 0), (0, 0, 1), (sx * 2.7, 1.0, 0), 0.6, 2.6, 0.5, "paint", bevel=0.05)
        p.obox((0, 2.9, sx * (H0 + 0.35)), (1, 0, 0), (0, 1.0, sx * 2.7), 0.6, 2.6, 0.5, "paint", bevel=0.05)
    # armored collar with a running band
    p.prism_y(octagon(half(5.2) + 0.3, 0.35), 4.9, 5.5, "trim", bevel=0.06)
    p.prism_y(octagon(half(5.2) + 0.32, 0.36), 5.12, 5.28, "light")
    # team plates on the tower's upper faces (slightly sloped)
    k = (H1 - H0) / (T1 - T0)
    for sx in (-1, 1):
        p.obox((sx * (half(7.0) + 0.03), 7.0, 0), (0, 0, 1), (sx, -k * sx * sx, 0), 1.6, 2.2, 0.05, "team", bevel=0.015)
    for sz in (-1, 1):
        p.obox((0, 7.0, sz * (half(7.0) + 0.03)), (1, 0, 0), (0, -k, sz), 1.6, 2.2, 0.05, "team", bevel=0.015)
    # front door with its light, a service ladder at the back, a conduit
    p.box((0, 3.0, -(half(3.0) + 0.02)), (1.0, 1.8, 0.05), "dark")
    p.box((0, 4.05, -(half(4.05) + 0.04)), (1.0, 0.12, 0.05), "light")
    for x in (-0.35, 0.35):
        p.box((x, 5.5, half(5.5) + 0.25), (0.08, 6.6, 0.08), "steel")
    for i in range(12):
        y = 2.4 + i * 0.55
        p.box((0, y, half(y) + 0.25), (0.7, 0.05, 0.05), "steel")
    cable(p, [(-1.6, 1.9, 1.0), (-1.3, 3.2, 1.0), (-1.2, 8.4, 0.9)], r=0.1, kind="steel")
    # equipment deck: rail posts, corner lights, the bearing
    p.prism_y(octagon(1.8, 0.45), T1, 9.0, "trim", bevel=0.06)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 1.55, 9.25, sz * 1.55), (0.12, 0.5, 0.12), "steel")
            p.box((sx * 1.55, 9.55, sz * 1.55), (0.22, 0.14, 0.22), "light")
    p.cylinder("y", (0, 9.15, 0), 0.8, 0.3, 16, "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 3.5, 0.55, sz * 3.5), (0.3, 0.12, 0.3), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 3.83, 0.25, -2.6), (sx * 3.83, 0.25, 2.6), 6, (sx, 0, 0))
    for y in (3.6, 6.2):
        seam(p, (-(half(y) + 0.005), y, -0.9), (-(half(y) + 0.005), y, 0.9), (-1, 0, 0))
    ring(p, (0, 9.001, 0), UP, 1.2)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_radar(p):
    p.cylinder("y", (0, 9.55, 0), 0.6, 0.5, 14, "trim", bevel=0.03)
    p.obox((0, 9.9, 0.2), U, (0, 0, 1), 3.4, 0.4, 0.8, "paint", bevel=0.04)
    for sx in (-1, 1):  # yoke arms up to the panel's back
        p.obox(at(sx * 1.5, -0.7, -0.55), U, N, 0.4, 1.8, 0.4, "steel")
    p.obox(PANEL, U, N, 6.4, 3.1, 0.4, "paint", bevel=0.05)
    p.obox(at(0, 0, 0.21), U, N, 5.9, 2.65, 0.03, "dark")
    for b in (-1.29, 1.29):  # glowing edge, top and bottom
        p.obox(at(0, b, 0.23), U, N, 5.9, 0.09, 0.02, "light")
    for a in (-2.91, 2.91):  # sides
        p.obox(at(a, 0, 0.23), U, N, 0.09, 2.5, 0.02, "light")
    for i in range(1, 8):  # cell grid columns
        p.obox(at(-2.95 + i * 0.7375, 0, 0.23), U, N, 0.04, 2.5, 0.02, "light")
    for b in (-0.43, 0.43):  # rows
        p.obox(at(0, b, 0.23), U, N, 5.74, 0.04, 0.02, "light")
    # framed back: a large team plate, ribs, a finned equipment box
    p.obox(at(0, 0.2, -0.22), U, N, 5.2, 1.9, 0.03, "team")
    for a in (-2.7, 2.7):
        p.obox(at(a, 0, -0.3), U, N, 0.3, 2.9, 0.2, "trim")
    p.obox(at(0, -0.9, -0.6), U, N, 2.2, 0.9, 0.6, "trim", bevel=0.05)
    for i in range(5):
        p.obox(at(-0.8 + i * 0.4, -0.9, -0.95), U, N, 0.06, 0.8, 0.14, "steel")


def details_radar(p):
    for b in (-1.45, 1.45):
        bolts(p, at(-3.0, b, 0.21), at(3.0, b, 0.21), 12, N)


unit.run(__file__, "ord_watchtower", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("radar", "base", RADAR_PIVOT, build_radar, details_radar)],
         budget=6000,
         previews=[("35", (-24, 19, -28), (0, 6.0, 0), 50),
                   ("80", (0, 42, 6), (0, 5, 0), 50),
                   ("close", (-11, 14, -13), (0, 8.0, 0), 45)])
