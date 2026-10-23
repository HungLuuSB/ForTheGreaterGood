"""Tidewatch (Order ASW helicopter, T2 air): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_tidewatch/build.py

About 1.35x the T1 Guardian (docs/art/size-scale.md) and visibly a naval
machine: an armored cabin on a boat-hull belly with flotation sponsons, a
white search radome under the nose, the dipping-sonar winch drum and its
glowing transducer under the belly, a long boom with a tail rotor and a
canted fin, and the client-spun `rotor` (five folding blades). The `rack`
(the weapon's turret piece) is a stub wing under the cabin carrying two
torpedoes with weapon-ready seekers; `muzzle` at its front. Team plates on
the roof, the fin and the blade tips. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 3.3, 0.2)
RACK = (0.0, 0.85, 0.2)
MUZZLE = (0.0, 0.6, -1.6)
CABIN = [(-4.3, 0.75), (2.2, 0.75), (2.4, 1.25), (2.2, 2.4), (-2.3, 2.4), (-3.3, 2.0), (-4.3, 1.3)]


def build_base(p):
    p.prism_x(CABIN, -1.15, 1.15, "paint", bevel=0.06)
    p.prism_x([(-3.25, 2.0), (-2.25, 2.4), (-2.25, 2.8), (-2.85, 2.55)], -0.9, 0.9, "glass", bevel=0.03)
    p.prism_x([(-4.25, 1.3), (-3.3, 1.98), (-3.45, 2.0), (-4.35, 1.35)], -1.1, 1.1, "glass", bevel=0.02)
    # boat-hull belly and flotation sponsons
    p.prism_x([(-3.9, 0.75), (2.0, 0.75), (1.6, 0.4), (-3.4, 0.4)], -0.9, 0.9, "trim", bevel=0.04)
    for sx in (-1, 1):
        p.cylinder("z", (sx * 1.35, 0.9, -0.6), 0.32, 3.0, 10, "paint", radius2=0.28)
        p.box((sx * 1.68, 0.95, -0.6), (0.04, 0.12, 2.4), "light")
    p.box((0, 2.43, 0.4), (1.5, 0.05, 1.9), "team", bevel=0.012)
    for sx in (-1, 1):  # cabin flank running strips
        p.box((sx * 1.16, 2.15, -0.7), (0.04, 0.16, 3.6), "light")
    # radome under the nose, sonar winch and transducer under the belly
    p.ocyl((0, 0.55, -3.3), (0, -1, 0), 0.5, 0.35, 12, "radome", radius2=0.3)
    p.cylinder("x", (0, 0.35, 1.4), 0.32, 0.9, 12, "steel")
    with p.sub("sonar", (0, 0.05, 1.4), "lower", (0, -1, 0), 8):  # M-27 dipping sonar
        p.cylinder("y", (0, 0.05, 1.4), 0.28, 0.25, 12, "dark")
        p.cylinder("y", (0, -0.12, 1.4), 0.3, 0.1, 12, "light")
    # engines, mast
    p.box((0, 2.65, 0.6), (1.4, 0.5, 2.2), "trim", bevel=0.05)
    for sx in (-1, 1):
        p.box((sx * 0.71, 2.65, 1.4), (0.05, 0.3, 0.8), "light")
    p.cylinder("y", (0, 3.0, 0.2), 0.2, 0.6, 8, "steel")
    # boom, canted fin with team plate, tail rotor, stabilizer
    p.prism_x([(2.2, 1.25), (6.6, 1.6), (6.6, 2.0), (2.2, 2.25)], -0.3, 0.3, "paint", bevel=0.04)
    p.prism_x([(6.0, 1.6), (7.0, 1.6), (7.3, 3.4), (6.7, 3.4)], -0.1, 0.1, "team", bevel=0.02)
    with p.sub("tailRotor", (0.24, 2.4, 6.8), "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", (0.24, 2.4, 6.8), 0.9, 0.06, 10, "dark")
        p.cylinder("x", (0.2, 2.4, 6.8), 0.13, 0.22, 6, "steel")
    p.box((0, 1.75, 5.9), (2.0, 0.1, 0.6), "paint", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 1.02, 1.75, 5.9), (0.06, 0.12, 0.35), "light")
    p.box((0, 2.48, -0.9), (0.22, 0.1, 0.22), "light")  # beacon
    p.box((0, 0.42, -2.6), (0.5, 0.06, 0.3), "head")  # landing light


def details_base(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.151, 1.0, -1.8), (sx * 1.151, 2.2, -1.8), (sx, 0, 0))
        seam(p, (sx * 1.151, 1.0, 1.0), (sx * 1.151, 2.2, 1.0), (sx, 0, 0))
    bolts(p, (-0.6, 2.401, -1.7), (0.6, 2.401, -1.7), 5, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.36, 0.24, 12, "trim")
    for i in range(5):
        a = i * 2 * math.pi / 5 + 0.3
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 0.55, y, z + d[2] * 0.55), u, (0, 1, 0), 0.3, 0.4, 0.14, "steel")  # fold hinge
        p.obox((x + d[0] * 2.85, y + 0.02, z + d[2] * 2.85), u, (0, 1, 0), 0.42, 4.3, 0.09, "dark")
        p.obox((x + d[0] * 4.85, y + 0.03, z + d[2] * 4.85), u, (0, 1, 0), 0.44, 0.36, 0.1, "team")


def build_rack(p):
    x, y, z = RACK
    p.prism_x([(-0.6, y - 0.1), (0.9, y - 0.1), (0.9, y + 0.1), (-0.4, y + 0.1)], -1.9, 1.9, "trim", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 1.5, y - 0.25, z), (0.14, 0.3, 0.6), "dark")
        p.box((sx * 1.91, y, z + 0.2), (0.05, 0.14, 0.7), "weapon")  # wing-tip ready lights
        p.cylinder("z", (sx * 1.5, y - 0.48, z), 0.24, 2.4, 10, "steel")
        p.ocyl((sx * 1.5, y - 0.48, z - 1.2), (0, 0, -1), 0.24, 0.3, 10, "weapon", radius2=0.08)  # seeker
        p.ocyl((sx * 1.5, y - 0.48, z + 1.2), (0, 0, 1), 0.24, 0.2, 10, "dark", radius2=0.12)


def no_details(p):
    pass


unit.run(__file__, "ord_tidewatch", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("rack", "base", RACK, build_rack, no_details)],
         attachments={"muzzle": {"parent": "rack", "at": list(MUZZLE)}},
         team_pieces=["base", "rotor"],
         previews=[("35", (-16, 12, 18), (0, 1.5, 0.5), 50),
                   ("side", (20, 3, 0.5), (0, 1.5, 0.5), 50),
                   ("80", (0, 30, 5), (0, 1.2, 0.5), 50),
                   ("close", (-7, 5.0, -8), (0, 1.6, -1.0), 35)])
