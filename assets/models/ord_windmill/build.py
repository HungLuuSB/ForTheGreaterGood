"""Wind turbine (Order, T1 structure, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_windmill/build.py

A tapered round tower on a chamfered armored footing, an armored nacelle
with a team band and cyan generator vents (power channel: dims on an energy
stall), a beacon on top, and the client-spun `rotor` (blockout visual piece,
turning about Z at the hub): a hub cone and three broad blades (BAR style,
M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

HUB = (0.0, 11.6, -1.6)
FOOT = [(-2.0, -2.6), (2.0, -2.6), (2.6, -2.0), (2.6, 2.0), (2.0, 2.6), (-2.0, 2.6), (-2.6, 2.0), (-2.6, -2.0)]


def build_base(p):
    p.prism_y([(-3.6, -3.6), (3.6, -3.6), (3.6, 3.6), (-3.6, 3.6)], 0.0, 0.45, "trim", bevel=0.05, top_scale=0.97)
    p.prism_y(FOOT, 0.45, 1.4, "paint", bevel=0.06, top_scale=0.82)
    p.cylinder("y", (0, 1.55, 0), 1.25, 0.3, 16, "steel")
    p.cylinder("y", (0, 1.78, 0), 1.1, 0.16, 16, "power")  # inverter ring
    p.cylinder("y", (0, 6.3, 0), 0.85, 9.0, 16, "paint", radius2=0.55)
    p.cylinder("y", (0, 10.85, 0), 0.62, 0.3, 14, "trim")
    # nacelle, team band, vents, beacon
    p.box((0, 11.6, 0.4), (1.7, 1.5, 3.4), "paint", bevel=0.08)
    p.box((0, 12.36, 0.6), (1.5, 0.05, 2.0), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 0.86, 11.75, 0.8), (0.06, 0.6, 1.8), "grille")
        p.box((sx * 0.87, 11.25, 0.8), (0.06, 0.2, 2.2), "power")
        p.box((sx * 0.87, 11.3, -0.9), (0.06, 0.2, 0.5), "team")
    p.box((0, 11.6, 2.12), (1.2, 1.0, 0.06), "grille")
    p.box((0, 12.5, 1.65), (0.36, 0.22, 0.36), "light")  # beacon
    for sx in (-1, 1):  # footing lights
        p.box((sx * 2.55, 0.95, 0), (0.06, 0.14, 2.8), "light")
        p.box((0, 0.95, sx * 2.55), (2.8, 0.14, 0.06), "light")
    p.box((0, 2.6, -0.8), (0.7, 1.4, 0.1), "dark")  # access door


def details_base(p):
    box_seams(p, (0, 0, 0), (4.4, 0, 4.4), 1.401)
    bolts(p, (-3.2, 0.451, 3.2), (3.2, 0.451, 3.2), 8, UP)
    bolts(p, (-3.2, 0.451, -3.2), (3.2, 0.451, -3.2), 8, UP)
    ring(p, (0, 1.701, 0), UP, 1.0)
    seam(p, (-0.86, 11.0, -1.0), (-0.86, 11.0, 2.0), (-1, 0, 0))
    seam(p, (0.86, 11.0, -1.0), (0.86, 11.0, 2.0), (1, 0, 0))


def build_rotor(p):
    hx, hy, hz = HUB
    p.cylinder("z", (hx, hy, hz + 0.1), 0.55, 0.6, 14, "trim")
    p.ocyl((hx, hy, hz - 0.2), (0, 0, -1), 0.55, 0.45, 14, "paint", radius2=0.12)  # spinner
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        d = (math.cos(a), math.sin(a), 0.0)
        u = (-math.sin(a), math.cos(a), 0.0)
        root = (hx + d[0] * 0.75, hy + d[1] * 0.75, hz)
        p.obox(root, u, (0, 0, -1), 0.35, 0.5, 0.3, "steel")  # blade root
        mid = (hx + d[0] * 3.4, hy + d[1] * 3.4, hz - 0.05)
        p.obox(mid, u, (0, 0, -1), 0.55, 5.0, 0.14, "paint", bevel=0.03)
        tip = (hx + d[0] * 5.9, hy + d[1] * 5.9, hz - 0.05)
        p.obox(tip, u, (0, 0, -1), 0.4, 0.4, 0.15, "team")  # tip band


def details_rotor(p):
    ring(p, (HUB[0], HUB[1], HUB[2] - 0.2), (0, 0, -1), 0.5)


unit.run(__file__, "ord_windmill", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", HUB, build_rotor, details_rotor)],
         budget=6000)
