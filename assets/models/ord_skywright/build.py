"""Skywright (Order air worker, T1 air, helicopter): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_skywright/build.py

An armored utility helicopter: a slab-sided cabin with a sloped nose and a
dark canopy, a team roof plate, a tail boom with a team fin, stabilizer and
tail rotor, skids, nav lights and a landing light; the client-spun `rotor`
(blockout visual piece) with four blades; the `nano` builder arm under the
belly with its emitter (power channel: brightens while building), like the
Mason (BAR style, M-15; Order reads heavy, M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 2.8, 0.2)
NANO = (0.0, 0.25, -0.2)


def build_base(p):
    # cabin: slab sides, sloped nose
    p.prism_x([(-3.9, 0.55), (1.7, 0.55), (1.9, 1.0), (1.7, 1.85), (-2.0, 1.85), (-3.0, 1.55), (-3.9, 0.95)], -0.9, 0.9, "paint", bevel=0.06)
    p.prism_x([(-2.9, 1.55), (-1.95, 1.85), (-1.95, 2.25), (-2.5, 2.05)], -0.7, 0.7, "glass", bevel=0.03)  # canopy
    p.box((0, 1.88, 0.4), (1.2, 0.05, 1.6), "team", bevel=0.012)
    p.box((0, 2.0, 0.5), (1.2, 0.3, 1.8), "trim", bevel=0.04)  # engine cowl
    for sx in (-1, 1):
        p.box((sx * 0.62, 2.0, 1.2), (0.05, 0.16, 0.6), "light")  # engine exhausts
    p.cylinder("y", (0, 2.45, 0.2), 0.18, 0.6, 8, "steel")  # mast
    # tail: boom, fin, stabilizer, tail rotor
    p.box((0, 1.3, 3.6), (0.5, 0.5, 4.0), "paint", bevel=0.04)
    p.prism_x([(4.8, 1.4), (5.9, 1.4), (5.9, 2.8), (5.4, 2.8)], -0.08, 0.08, "team", bevel=0.02)
    p.box((0, 1.4, 5.0), (1.8, 0.12, 0.6), "paint", bevel=0.02)
    p.cylinder("x", (0.2, 2.0, 5.4), 0.8, 0.06, 10, "dark")
    p.cylinder("x", (0.16, 2.0, 5.4), 0.12, 0.2, 6, "steel")
    # skids on struts
    for sx in (-1, 1):
        p.box((sx * 0.9, 0.08, -0.4), (0.15, 0.15, 4.4), "dark")
        for z in (-1.6, 0.8):
            p.box((sx * 0.75, 0.32, z), (0.12, 0.5, 0.12), "steel")
    # lights: nav lights on the stabilizer tips, beacon, landing light
    for sx in (-1, 1):
        p.box((sx * 0.92, 1.4, 5.0), (0.08, 0.14, 0.3), "light")
        p.box((sx * 0.92, 1.2, -0.8), (0.05, 0.14, 2.4), "light")
    p.box((0, 2.18, -0.6), (0.2, 0.08, 0.2), "light")
    p.box((0, 0.56, -3.2), (0.5, 0.06, 0.3), "head")


def details_base(p):
    seam(p, (-0.901, 1.0, -1.5), (-0.901, 1.6, -1.5), (-1, 0, 0))
    seam(p, (0.901, 1.0, -1.5), (0.901, 1.6, -1.5), (1, 0, 0))
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


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 0.6, 0.3, 12, "trim")
    p.obox((0, 0.0, -0.9), (1, 0, 0), (0, math.sin(math.radians(20)), -math.cos(math.radians(20))), 0.3, 0.3, 1.6, "steel")
    p.cylinder("y", (0, -0.3, -1.7), 0.32, 0.5, 10, "power")  # emitter
    p.cylinder("y", (0, -0.05, -1.7), 0.36, 0.08, 10, "dark")


def no_details(p):
    pass


unit.run(__file__, "ord_skywright", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         team_pieces=["base", "rotor"])
