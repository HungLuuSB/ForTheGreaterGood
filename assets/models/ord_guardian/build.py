"""Guardian (Order attack helicopter, T1 air): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_guardian/build.py

An armored gunship: a narrow slab-sided body with a stepped tandem canopy, a
chin sensor turret (weapon channel), stub wings, a team roof plate, a tail
boom with a team fin, stabilizer and tail rotor, skids, nav lights; the
client-spun `rotor` (blockout visual piece) with four blades; the `pylon`
(the weapon turret piece) carries two rocket pods on the stub wings, their
tube mouths ringed with ready lights (weapon channel) (BAR style, M-15;
Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 2.8, 0.2)
PYLON = (0.0, 0.6, -0.4)


def build_base(p):
    # cabin: slab sides, sloped nose
    p.prism_x([(-3.9, 0.55), (1.7, 0.55), (1.9, 1.0), (1.7, 1.85), (-2.0, 1.85), (-3.0, 1.55), (-3.9, 0.95)], -0.7, 0.7, "paint", bevel=0.06)
    p.prism_x([(-3.2, 1.45), (-2.4, 1.6), (-2.4, 2.0), (-2.9, 1.85)], -0.5, 0.5, "glass", bevel=0.03)  # gunner
    p.prism_x([(-2.3, 1.75), (-1.4, 1.9), (-1.4, 2.35), (-1.9, 2.2)], -0.5, 0.5, "glass", bevel=0.03)  # pilot, stepped up
    p.cylinder("y", (0, 0.45, -3.4), 0.28, 0.3, 10, "dark")  # chin sensor
    p.box((0, 0.45, -3.69), (0.3, 0.16, 0.04), "weapon")
    p.box((0, 0.9, -0.4), (3.4, 0.2, 0.8), "paint", bevel=0.03)  # stub wings
    p.box((0, 1.88, 0.4), (1.2, 0.05, 1.6), "team", bevel=0.012)
    p.box((0, 2.0, 0.5), (1.2, 0.3, 1.8), "trim", bevel=0.04)  # engine cowl
    for sx in (-1, 1):
        p.box((sx * 0.62, 2.0, 1.2), (0.05, 0.16, 0.6), "light")  # engine exhausts
    p.cylinder("y", (0, 2.45, 0.2), 0.18, 0.6, 8, "steel")  # mast
    # tail: boom, fin, stabilizer, tail rotor
    p.box((0, 1.3, 3.6), (0.5, 0.5, 4.0), "paint", bevel=0.04)
    p.box((0, 1.56, 3.6), (0.12, 0.04, 3.4), "light")  # boom strip
    p.prism_x([(4.7, 1.32), (6.05, 1.32), (6.05, 3.0), (5.4, 3.0)], -0.08, 0.08, "team", bevel=0.02)
    p.box((0, 1.4, 5.0), (1.8, 0.12, 0.6), "paint", bevel=0.02)
    p.cylinder("x", (0.2, 2.0, 5.4), 0.8, 0.06, 10, "dark")
    p.cylinder("x", (0.16, 2.0, 5.4), 0.12, 0.2, 6, "steel")
    # skids on struts
    for sx in (-1, 1):
        p.box((sx * 0.8, 0.08, -0.4), (0.15, 0.15, 4.4), "dark")
        for z in (-1.6, 0.8):
            p.box((sx * 0.65, 0.32, z), (0.12, 0.5, 0.12), "steel")
    # lights: nav lights on the stabilizer tips, beacon, landing light
    for sx in (-1, 1):
        p.box((sx * 0.92, 1.4, 5.0), (0.08, 0.14, 0.3), "light")
        p.box((sx * 0.72, 1.2, -0.8), (0.05, 0.14, 2.4), "light")
        p.box((sx * 1.72, 0.9, -0.4), (0.06, 0.12, 0.6), "light")  # stub tip lights
    p.box((0, 2.18, -0.6), (0.2, 0.08, 0.2), "light")
    p.box((0, 0.56, -3.2), (0.5, 0.06, 0.3), "head")


def details_base(p):
    seam(p, (-0.701, 1.0, -1.5), (-0.701, 1.6, -1.5), (-1, 0, 0))
    seam(p, (0.701, 1.0, -1.5), (0.701, 1.6, -1.5), (1, 0, 0))
    bolts(p, (-0.5, 1.851, -1.8), (0.5, 1.851, -1.8), 4, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.3, 0.2, 10, "trim")
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 2.25, y + 0.02, z + d[2] * 2.25), u, (0, 1, 0), 0.4, 4.1, 0.08, "dark")
        p.obox((x + d[0] * 4.15, y + 0.03, z + d[2] * 4.15), u, (0, 1, 0), 0.42, 0.3, 0.09, "team")  # tip bands


def build_pylon(p):
    p.box((0, 0.6, -0.4), (3.0, 0.3, 0.6), "trim", bevel=0.03)
    for sx in (-1, 1):
        x = sx * 1.3
        p.cylinder("z", (x, 0.55, -0.5), 0.27, 1.6, 10, "paint")
        p.cylinder("z", (x, 0.55, -1.32), 0.22, 0.04, 10, "dark")
        for dx, dy in ((-0.1, 0.1), (0.1, 0.1), (-0.1, -0.1), (0.1, -0.1)):
            p.cylinder("z", (x + dx, 0.55 + dy, -1.35), 0.06, 0.03, 6, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_guardian", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "pylon", "at": [0, 0.55, -1.4]}},
         team_pieces=["base", "rotor"])
