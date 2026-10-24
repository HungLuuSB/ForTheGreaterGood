"""Beacon (Order long-range radar, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_beacon/build.py

New mesh at the size scale (S-104, M-26: footprint 3, 24 x 24 studs, about
22 tall), from its blockout; the T1 Watchtower's big brother, not a rescale.
Big shapes first: a chamfered slab, a stepped armored base with sloped
walls, team plates and running strips, an armored plinth with a large team
deck, a lit door and buttresses; a tall tapered square tower with corner
ribs and glowing strips, an armored collar with a team band (the blockout's
band), side equipment pods and a service ladder; an equipment deck with rail
posts and lights; on the deck a generator house with a team roof,
transformer boxes, aerials and corner pylons with lights; and on a bearing
the client-turned `radar` (blockout visual piece, turn Y, rig.md 9): a very
wide flat phased array tilted back 15 degrees, its face unlit with a glowing
edge and a fine cell grid (style guide, "Sensor faces"), an IFF bar on top,
a framed back with a large team plate, a truss and finned equipment boxes.
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

RADAR_PIVOT = (0.0, 15.6, 0.0)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))  # panel face: forward and up
VV = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 18.8, 0.0)
PW, PH = 12.4, 5.0  # panel width, height
T0, T1 = 4.8, 15.0  # tower bottom and top
H0, H1 = 2.0, 1.45  # tower half widths at the bottom and top


def half(y):
    return H0 + (H1 - H0) * (y - T0) / (T1 - T0)


def build_base(p):
    p.prism_y(octagon(11.8, 1.6), 0.0, 0.8, "trim", bevel=0.14, top_scale=0.985)
    # stepped armored base: upright walls, sloped walls, running strips
    p.prism_y(octagon(10.2, 2.4), 0.8, 1.8, "paint", bevel=0.16)
    p.prism_y(octagon(10.2, 2.4), 1.8, 2.6, "paint", bevel=0.16, top_scale=0.9)
    for s in (-1, 1):
        p.box((s * 10.22, 1.3, 0), (0.05, 0.16, 6.0), "light")
        p.box((0, 1.3, 10.22 * s), (6.0, 0.16, 0.05), "light")
    hazard(p, (0, 0.82, -11.0), (1, 0, 0), UP, 8.0, 0.5, stripes=14)
    # team plates on the base deck, front and sides
    p.box((0, 2.63, -7.4), (7.0, 0.06, 2.6), "team", bevel=0.02)
    for s in (-1, 1):
        p.box((s * 7.4, 2.63, -1.0), (2.6, 0.06, 6.0), "team", bevel=0.02)
    # armored plinth with a large team deck, sloped team plates, a lit door
    p.prism_y(octagon(5.0, 1.3), 2.6, 4.2, "paint", bevel=0.14)
    p.prism_y(octagon(5.0, 1.3), 4.2, T0, "paint", bevel=0.14, top_scale=0.88)
    p.prism_y(octagon(4.3, 1.1), T0, T0 + 0.06, "team", bevel=0.02)
    p.box((0, 3.4, -5.02), (2.0, 1.4, 0.05), "dark")
    p.box((0, 4.2, -5.04), (2.0, 0.12, 0.04), "light")
    # the tapered tower: corner ribs with strips, buttresses, a collar, a team band
    p.prism_y(rect(0, 0, H0, H0), T0, T1, "paint", bevel=0.12, top_scale=H1 / H0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = (sx * (H0 + 0.02), T0, sz * (H0 + 0.02))
            b = (sx * (H1 + 0.02), T1 - 0.2, sz * (H1 + 0.02))
            mid = tuple((a[k] + b[k]) / 2 for k in range(3))
            d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
            p.obox(mid, (sx, 0, -sz), d, 0.4, 0.4, math.dist(a, b), "trim")
            p.obox(mid, (sx, 0, -sz), d, 0.44, 0.08, math.dist(a, b) * 0.4, "light")
    for sx in (-1, 1):
        p.obox((sx * (H0 + 0.45), 6.2, 0), (0, 0, 1), (sx * 2.7, 1.0, 0), 0.7, 3.2, 0.6, "paint", bevel=0.06)
        p.obox((0, 6.2, sx * (H0 + 0.45)), (1, 0, 0), (0, 1.0, sx * 2.7), 0.7, 3.2, 0.6, "paint", bevel=0.06)
    p.prism_y(octagon(half(9.5) + 0.35, 0.45), 9.2, 9.9, "trim", bevel=0.06)
    p.prism_y(octagon(half(9.5) + 0.37, 0.46), 9.48, 9.62, "light")
    p.prism_y(rect(0, 0, half(13.0) + 0.06, half(13.0) + 0.06), 12.4, 13.6, "team", bevel=0.03)
    # side equipment pods with lit fronts, a service ladder, a conduit
    for sx in (-1, 1):
        x = sx * (half(11.0) + 0.55)
        p.box((x, 11.0, 0), (1.1, 2.0, 1.8), "trim", bevel=0.08)
        p.box((x, 11.0, -0.92), (0.7, 0.14, 0.04), "light")
        for i in range(4):
            p.box((x + sx * 0.57, 10.4 + i * 0.4, 0), (0.06, 0.08, 1.4), "grille")
    for x in (-0.4, 0.4):
        p.box((x, 9.9, half(9.9) + 0.3), (0.09, 10.2, 0.09), "steel")
    for i in range(17):
        y = 5.2 + i * 0.58
        p.box((0, y, half(y) + 0.3), (0.8, 0.06, 0.06), "steel")
    cable(p, [(-2.4, T0, 1.4), (-1.9, 6.0, 1.4), (-1.6, 14.6, 1.2)], r=0.12, kind="steel")
    # equipment deck: rail posts, lights, the bearing
    p.prism_y(octagon(2.5, 0.6), T1, 15.35, "trim", bevel=0.06)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 2.15, 15.65, sz * 2.15), (0.14, 0.6, 0.14), "steel")
            p.box((sx * 2.15, 16.0, sz * 2.15), (0.26, 0.14, 0.26), "light")
    p.cylinder("y", (0, 15.45, 0), 1.0, 0.3, 16, "steel")
    # generator house on the back deck with a team roof and a vent; transformers
    p.prism_y(rect(-5.8, 6.2, 1.9, 1.6), 2.6, 4.6, "paint", bevel=0.1)
    p.box((-5.8, 4.64, 6.2), (3.4, 0.05, 2.8), "team", bevel=0.015)
    p.box((-3.88, 3.6, 6.2), (0.05, 0.4, 2.0), "power")
    for i, x in enumerate((4.2, 6.6)):
        p.prism_y(rect(x, 6.4, 0.9, 1.2), 2.6, 4.2, "trim", bevel=0.06)
        for dz in (-0.8, 0.0, 0.8):
            p.cylinder("y", (x, 4.55, 6.4 + dz), 0.15, 0.7, 8, "steel")
        p.box((x, 3.4, 5.18), (1.2, 0.12, 0.04), "light")
    cable(p, [(-3.9, 4.0, 6.0), (-2.6, 4.4, 4.2), (-1.2, 4.6, 3.0)], r=0.1)
    # aerials and corner pylons with lights
    for x, z in ((7.6, -5.6), (-7.6, -5.6)):
        p.box((x, 2.9, z), (0.6, 0.6, 0.6), "trim")
        p.cylinder("y", (x, 4.6, z), 0.06, 2.8, 6, "steel")
        p.box((x, 6.05, z), (0.2, 0.14, 0.2), "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 9.6, 0.86, sz * 9.6), (0.5, 0.12, 0.5), "light")

    # the radar: a very wide flat array on its bearing
    with p.sub("radar", RADAR_PIVOT, "turn", (0, 1, 0)):
        build_radar(p)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + VV[k] * b + N[k] * n for k in range(3))


def build_radar(p):
    p.cylinder("y", (0, 15.95, 0), 0.8, 0.7, 16, "trim", bevel=0.03)
    p.obox((0, 16.4, 0.3), U, (0, 0, 1), 5.0, 0.5, 1.2, "paint", bevel=0.05)
    for sx in (-1, 1):  # yoke arms up to the panel's back
        p.obox(at(sx * 2.2, -1.2, -0.7), U, N, 0.5, 2.4, 0.5, "steel")
    p.obox(PANEL, U, N, PW, PH, 0.5, "paint", bevel=0.06)
    p.obox(at(0, 0, 0.26), U, N, PW - 0.6, PH - 0.5, 0.03, "dark")
    hw, hh = (PW - 0.6) / 2, (PH - 0.5) / 2
    for b in (-hh + 0.05, hh - 0.05):  # glowing edge, top and bottom
        p.obox(at(0, b, 0.28), U, N, PW - 0.6, 0.1, 0.02, "light")
    for a in (-hw + 0.05, hw - 0.05):
        p.obox(at(a, 0, 0.28), U, N, 0.1, PH - 0.6, 0.02, "light")
    for i in range(1, 12):  # fine cell grid
        p.obox(at(-hw + i * (2 * hw / 12), 0, 0.28), U, N, 0.04, PH - 0.6, 0.02, "light")
    for b in (-hh / 2, 0.0, hh / 2):
        p.obox(at(0, b, 0.28), U, N, PW - 0.7, 0.04, 0.02, "light")
    # IFF bar on top of the panel
    p.obox(at(0, PH / 2 + 0.3, 0), U, N, 7.0, 0.4, 0.35, "trim", bevel=0.03)
    p.obox(at(0, PH / 2 + 0.3, 0.19), U, N, 6.6, 0.08, 0.02, "light")
    # framed back: a large team plate, ribs, a truss, finned equipment boxes
    p.obox(at(0, 0.4, -0.27), U, N, PW - 1.6, PH - 1.8, 0.03, "team")
    for a in (-5.6, -2.0, 2.0, 5.6):
        p.obox(at(a, 0, -0.38), U, N, 0.36, PH - 0.2, 0.26, "trim")
    p.obox(at(0, -1.6, -0.45), U, N, PW - 0.8, 0.36, 0.36, "trim")
    for sx in (-1, 1):
        p.obox(at(sx * 3.2, -1.4, -0.95), U, N, 2.2, 1.2, 0.8, "trim", bevel=0.05)
        for i in range(5):
            p.obox(at(sx * 3.2 - 0.8 + i * 0.4, -1.4, -1.38), U, N, 0.06, 1.0, 0.14, "steel")


def details_base(p):
    for s in (-1, 1):
        rivets(p, (s * 10.22, 1.05, -3.0), (s * 10.22, 1.05, 3.0), 8, (s, 0, 0))
    for y in (7.4, 11.0):
        seam(p, (-0.9, y, -(half(y) + 0.005)), (0.9, y, -(half(y) + 0.005)), (0, 0, -1))
    ring(p, (0, 15.351, 0), UP, 1.6)
    with p.sub("radar", RADAR_PIVOT, "turn", (0, 1, 0)):
        for b in (-PH / 2 + 0.1, PH / 2 - 0.1):
            bolts(p, at(-PW / 2 + 0.2, b, 0.26), at(PW / 2 - 0.2, b, 0.26), 18, N)


unit.run(__file__, "ord_beacon", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-42, 37, -50), (0, 9.5, 0), 50),
                   ("80", (0, 66, 10), (0, 6, 0), 50),
                   ("close", (-18, 24, -21), (0, 14.0, 0), 50)])
