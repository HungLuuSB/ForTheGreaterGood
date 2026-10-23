"""Wind turbine (Order, T1 structure, footprint 2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_windmill/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
a thin mast to about 18), not rescaled. Big shapes first: a chamfered slab
and an armored octagonal footing with an inverter house (glowing vents, a
team roof), a tall tapered tower with ribs and a service ladder, an armored
nacelle with a team band, cyan generator vents (power: dims on an energy
stall) and a beacon, and the client-spun `rotor` (turning about Z at the
hub): a spinner and three long broad blades with team tips. Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

HUB = (0.0, 16.2, -2.2)


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.6, "trim", bevel=0.12, top_scale=0.985)
    p.prism_y(octagon(3.6, 1.0), 0.6, 2.0, "paint", bevel=0.14, top_scale=0.82)
    p.cylinder("y", (0, 2.15, 0), 1.6, 0.3, 20, "steel")
    p.cylinder("y", (0, 2.38, 0), 1.45, 0.16, 20, "power")  # inverter ring
    # tower: tapered, with three ribs and a hatch band
    p.ocyl((0, 2.3, 0), UP, 1.15, 12.6, 18, "paint", radius2=0.7)
    for a in (90, 210, 330):
        r = math.radians(a)
        p.obox((math.cos(r) * 1.0, 8.6, math.sin(r) * 1.0), UP, (math.cos(r), 0, math.sin(r)), 12.0, 0.22, 0.18, "trim")
    p.cylinder("y", (0, 6.0, 0), 1.08, 0.3, 18, "team")
    p.cylinder("y", (0, 14.9, 0), 0.8, 0.4, 16, "trim")
    for k in range(12):  # service ladder
        p.box((0, 3.0 + k * 0.9, -1.05 + k * 0.03), (0.5, 0.06, 0.06), "dark")
    # nacelle: armored, team band on top, vents, beacon
    p.prism_x([(-1.6, 15.1), (2.6, 15.1), (2.9, 15.6), (2.6, 16.9), (-1.2, 17.1), (-1.8, 16.3)], -1.1, 1.1, "paint", bevel=0.12)
    p.box((0, 17.13, 0.7), (1.6, 0.05, 2.8), "team", bevel=0.015)
    for sx in (-1, 1):
        p.box((sx * 1.12, 16.4, 1.0), (0.05, 0.6, 2.2), "grille")
        p.box((sx * 1.12, 15.7, 1.0), (0.05, 0.22, 2.6), "power")
    p.box((0, 16.0, 2.92), (1.6, 1.2, 0.05), "grille")
    p.box((0, 17.3, 2.2), (0.36, 0.22, 0.36), "light")  # beacon
    # inverter house at the foot: a team roof and a glowing vent
    p.prism_y(rect(4.6, -3.4, 1.8, 1.4), 0.6, 2.6, "paint", bevel=0.1)
    p.box((4.6, 2.64, -3.4), (3.2, 0.05, 2.4), "team", bevel=0.02)
    p.box((4.6, 1.6, -4.82), (2.6, 0.4, 0.05), "power")
    hazard(p, (0, 0.62, -6.6), (1, 0, 0), (0, 1, 0), 4.0, 0.4, stripes=8)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.2, 0.68, sz * 7.2), (0.4, 0.1, 0.4), "light")
        p.box((sx * 3.62, 1.3, 0), (0.05, 0.14, 2.6), "light")


def details_base(p):
    rivets(p, (-2.6, 2.0, -3.62), (2.6, 2.0, -3.62), 6, (0, 0, -1))
    ring(p, (0, 2.301, 0), UP, 1.35)
    for sx in (-1, 1):
        seam(p, (sx * 1.11, 15.6, -1.0), (sx * 1.11, 15.6, 2.4), (sx, 0, 0))


def build_rotor(p):
    hx, hy, hz = HUB
    p.cylinder("z", (hx, hy, hz + 0.25), 0.8, 0.8, 16, "trim")
    p.ocyl((hx, hy, hz - 0.15), (0, 0, -1), 0.8, 0.8, 16, "paint", radius2=0.15)  # spinner
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        d = (math.cos(a), math.sin(a), 0.0)
        u = (-math.sin(a), math.cos(a), 0.0)
        p.obox((hx + d[0] * 1.1, hy + d[1] * 1.1, hz), u, (0, 0, -1), 0.5, 0.8, 0.45, "steel")  # blade root
        p.obox((hx + d[0] * 4.4, hy + d[1] * 4.4, hz - 0.05), u, (0, 0, -1), 0.95, 6.0, 0.2, "paint", bevel=0.05)
        p.obox((hx + d[0] * 7.9, hy + d[1] * 7.9, hz - 0.05), u, (0, 0, -1), 0.65, 1.2, 0.2, "paint", bevel=0.04)
        p.obox((hx + d[0] * 8.3, hy + d[1] * 8.3, hz - 0.1), u, (0, 0, -1), 0.6, 0.7, 0.21, "team")  # tip band


def details_rotor(p):
    ring(p, (HUB[0], HUB[1], HUB[2] - 0.15), (0, 0, -1), 0.7)


unit.run(__file__, "ord_windmill", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", HUB, build_rotor, details_rotor)],
         budget=6000,
         previews=[("35", (-26, 22, -30), (0, 9.0, 0), 50),
                   ("80", (0, 46, 8), (0, 6, 0), 50),
                   ("close", (-13, 15, -16), (0, 12.0, 0), 35)])
