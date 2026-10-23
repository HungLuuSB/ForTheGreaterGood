"""Zenith (Order advanced air worker, T2 air, helicopter): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_zenith/build.py

The Skywright's big brother, about 1.35x its size (docs/art/size-scale.md)
and visibly more advanced: a long armored heavy-lift cabin with a stepped
nose, a wraparound canopy and side sponsons on wheeled gear; twin engine
nacelles on the roof with glowing exhausts; a five-blade main rotor (the
client-spun `rotor` visual piece); a long boom ending in a ducted tail fan
and a T-tail; and under the belly the `nano` turret with two build arms,
fore and aft, each with an emitter (power). Team plates on the roof, the fin
and the blade tips. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 3.35, 0.3)
NANO = (0.0, 0.4, -0.2)
CABIN = [(-4.7, 0.7), (2.3, 0.7), (2.5, 1.2), (2.3, 2.45), (-2.5, 2.45), (-3.6, 2.05), (-4.7, 1.2)]


def build_base(p):
    # cabin: slab sides, stepped nose, canopy wrapped round the front
    p.prism_x(CABIN, -1.2, 1.2, "paint", bevel=0.06)
    p.prism_x([(-3.55, 2.05), (-2.45, 2.45), (-2.45, 2.85), (-3.05, 2.6)], -0.95, 0.95, "glass", bevel=0.03)
    p.prism_x([(-4.65, 1.2), (-3.6, 2.02), (-3.75, 2.05), (-4.75, 1.25)], -1.15, 1.15, "glass", bevel=0.02)
    p.box((0, 2.48, 0.5), (1.6, 0.05, 2.0), "team", bevel=0.012)
    # sponsons with wheeled gear, running strips along them
    for sx in (-1, 1):
        p.box((sx * 1.45, 1.05, -0.2), (0.6, 0.7, 3.2), "paint", bevel=0.05)
        p.box((sx * 1.76, 1.1, -0.2), (0.04, 0.14, 2.8), "light")
        for z in (-1.2, 0.9):
            p.cylinder("y", (sx * 1.45, 0.55, z), 0.08, 0.5, 6, "steel")
            p.cylinder("x", (sx * 1.45, 0.25, z), 0.25, 0.2, 10, "rubber", cap_kinds=("steel", "steel"))
    p.cylinder("y", (0, 0.65, -3.4), 0.07, 0.4, 6, "steel")
    p.cylinder("x", (0, 0.27, -3.4), 0.22, 0.18, 10, "rubber", cap_kinds=("steel", "steel"))
    # twin engine nacelles on the roof, glowing exhausts, the mast
    for sx in (-1, 1):
        p.cylinder("z", (sx * 0.7, 2.75, 0.9), 0.38, 2.4, 12, "trim")
        p.cylinder("z", (sx * 0.7, 2.75, -0.35), 0.3, 0.1, 12, "grille")
        p.cylinder("z", (sx * 0.7, 2.75, 2.15), 0.3, 0.12, 12, "light")
    p.cylinder("y", (0, 3.0, 0.3), 0.22, 0.75, 8, "steel")
    # boom, ducted tail fan in the fin, T-tail
    p.prism_x([(2.3, 1.2), (6.6, 1.55), (6.6, 2.05), (2.3, 2.3)], -0.32, 0.32, "paint", bevel=0.04)
    p.prism_x([(6.0, 1.4), (7.4, 1.4), (7.6, 3.6), (6.9, 3.6)], -0.14, 0.14, "paint", bevel=0.03)
    with p.sub("tailRotor", (0, 2.1, 6.75), "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", (0, 2.1, 6.75), 0.55, 0.32, 14, "dark")
    p.prism_x([(6.3, 2.8), (7.5, 2.8), (7.6, 3.5), (6.85, 3.5)], -0.15, 0.15, "team", bevel=0.02)
    p.box((0, 3.62, 7.25), (2.4, 0.1, 0.7), "paint", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 1.22, 3.62, 7.25), (0.06, 0.12, 0.4), "light")
    # lights: beacon, landing lights, cockpit strip
    p.box((0, 2.53, -0.9), (0.24, 0.1, 0.24), "light")
    for sx in (-1, 1):
        p.box((sx * 0.5, 0.68, -4.2), (0.4, 0.06, 0.3), "head")
    p.box((0, 1.25, -4.74), (1.6, 0.08, 0.04), "light")


def details_base(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.201, 1.0, -2.0), (sx * 1.201, 2.2, -2.0), (sx, 0, 0))
        seam(p, (sx * 1.201, 1.0, 1.2), (sx * 1.201, 2.2, 1.2), (sx, 0, 0))
        bolts(p, (sx * 1.75, 1.35, -1.6), (sx * 1.75, 1.35, 1.2), 5, (sx, 0, 0))
    bolts(p, (-0.7, 2.451, -1.9), (0.7, 2.451, -1.9), 5, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.38, 0.26, 12, "trim")
    p.cylinder("y", (x, y + 0.2, z), 0.18, 0.2, 8, "steel")
    for i in range(5):
        a = i * 2 * math.pi / 5
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 2.75, y + 0.02, z + d[2] * 2.75), u, (0, 1, 0), 0.42, 5.0, 0.09, "dark")
        p.obox((x + d[0] * 5.1, y + 0.03, z + d[2] * 5.1), u, (0, 1, 0), 0.44, 0.36, 0.1, "team")


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 0.7, 0.3, 14, "trim")
    p.cylinder("y", (x, y - 0.17, z), 0.72, 0.06, 14, "power")
    for sign, tip in ((-1, -2.1), (1, 1.6)):  # fore and aft arms
        mid = (0, 0.05, z + (tip - z) / 2)
        n = (0, -0.35, sign * 1.0)
        p.obox(mid, (1, 0, 0), n, 0.32, 0.32, abs(tip - z) + 0.2, "steel")
        p.cylinder("y", (0, -0.25, tip), 0.34, 0.5, 12, "power")
        p.cylinder("y", (0, 0.03, tip), 0.4, 0.1, 12, "dark")


def no_details(p):
    pass


unit.run(__file__, "ord_zenith", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         team_pieces=["base", "rotor"],
         previews=[("35", (-16, 12, 18), (0, 1.8, 0.5), 50),
                   ("side", (20, 3, 0.5), (0, 1.8, 0.5), 50),
                   ("80", (0, 30, 5), (0, 1.5, 0.5), 50),
                   ("close", (-7, 5.5, -8), (0, 2.0, -1.0), 35)])
