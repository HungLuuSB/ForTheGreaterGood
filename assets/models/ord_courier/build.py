"""Courier (Order light air transport, T1 air, footprint 2; S-219): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_courier/build.py

An armored utility lifter, a size up from the Skywright: a slab-sided cabin
with a sloped nose and a dark wrap-round canopy, add-on armor along the
lower hull, fuel sponsons, team door plates and roof plate, a long engine
cowl with twin exhausts, a tapered tail boom with a team fin, stabilizer
and tail rotor, tall skids so a carried unit fits under the belly, and a
hazard-banded cargo winch with its hook between them (the `cargo`
attachment: where a carried unit hangs). The client-spun `rotor`
(blockout visual piece) has four blades. Order reads heavy (M-14), BAR
style (M-15). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 4.4, -0.6)
TAIL = (0.32, 4.1, 10.3)
CARGO = (0.0, 0.25, -0.4)


def build_base(p):
    # cabin: slab sides, sloped nose (side profile z, y)
    p.prism_x([(-6.2, 1.0), (3.2, 1.0), (3.6, 1.6), (3.4, 3.2), (-3.0, 3.2), (-4.6, 2.7), (-6.2, 1.8)], -1.4, 1.4, "paint", bevel=0.08)
    p.prism_x([(-5.75, 2.02), (-3.35, 3.17), (-3.35, 3.42), (-5.85, 2.24)], -1.2, 1.2, "glass", bevel=0.03)  # windscreen
    for sx in (-1, 1):
        p.box((sx * 1.41, 2.45, -3.9), (0.05, 0.75, 1.3), "glass")  # side windows
        p.box((sx * 1.43, 2.05, -0.6), (0.05, 1.1, 2.6), "team", bevel=0.01)  # door plates
        p.box((sx * 1.52, 1.3, -1.0), (0.22, 0.5, 6.4), "trim", bevel=0.05)  # add-on armor
        p.box((sx * 1.78, 1.75, 1.6), (0.7, 0.9, 2.8), "paint", bevel=0.12)  # fuel sponsons
        p.box((sx * 1.41, 2.95, -1.0), (0.05, 0.12, 3.0), "light")  # nav strips
    p.box((0, 3.23, 0.9), (1.8, 0.05, 2.0), "team", bevel=0.012)  # roof plate
    # engine cowl, intakes, exhausts, mast
    p.box((0, 3.55, 0.5), (2.2, 0.7, 3.4), "trim", bevel=0.08)
    for sx in (-1, 1):
        p.box((sx * 0.6, 3.6, -1.22), (0.6, 0.42, 0.05), "dark")
        p.box((sx * 1.11, 3.6, 1.7), (0.05, 0.26, 0.9), "light")
    p.cylinder("y", (0, 4.1, -0.6), 0.25, 0.7, 8, "steel")
    # tail: tapered boom, fin, stabilizer with end plates, tail rotor
    p.prism_x([(3.2, 1.9), (10.0, 2.75), (10.0, 3.3), (3.2, 3.1)], -0.45, 0.45, "paint", bevel=0.04)
    p.prism_x([(9.3, 3.2), (10.9, 3.2), (10.9, 5.0), (10.2, 5.0)], -0.1, 0.1, "team", bevel=0.02)
    p.box((0, 2.95, 8.8), (3.0, 0.14, 0.9), "paint", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 1.52, 3.1, 8.85), (0.08, 0.5, 0.8), "team", bevel=0.01)
        p.box((sx * 1.57, 3.1, 8.85), (0.04, 0.16, 0.3), "light")
    p.box((0, 5.05, 10.6), (0.12, 0.1, 0.25), "light")  # fin-top beacon
    with p.sub("tailRotor", TAIL, "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", TAIL, 1.25, 0.07, 10, "dark")
        p.cylinder("x", (TAIL[0] - 0.04, TAIL[1], TAIL[2]), 0.18, 0.25, 6, "steel")
    # tall skids on struts, upturned at the front
    for sx in (-1, 1):
        p.box((sx * 1.6, 0.1, -0.6), (0.2, 0.2, 6.0), "dark")
        p.obox((sx * 1.6, 0.3, -3.85), (1, 0, 0), (0, math.sin(math.radians(35)), -math.cos(math.radians(35))), 0.2, 0.2, 0.7, "dark")
        for z in (-2.6, 1.2):
            p.box((sx * 1.5, 0.55, z), (0.16, 0.9, 0.16), "steel")
    # cargo winch with its hazard band, cable and hook
    p.box((0, 0.8, -0.4), (1.2, 0.4, 1.2), "trim", bevel=0.04)
    p.box((0, 0.98, -0.4), (1.26, 0.06, 1.26), "hazard")
    p.cylinder("y", (0, 0.48, -0.4), 0.06, 0.3, 6, "steel")
    p.box((0, 0.27, -0.4), (0.4, 0.14, 0.4), "dark")
    p.box((0, 0.12, -0.25), (0.1, 0.18, 0.14), "steel")
    # lights: landing light under the nose, beacon on the cowl
    p.box((0, 0.98, -5.4), (0.6, 0.06, 0.4), "head")
    p.box((0, 3.93, 1.9), (0.22, 0.08, 0.22), "light")


def details_base(p):
    for sx in (-1, 1):
        x = sx * 1.451
        n = (sx, 0, 0)
        seam(p, (x, 1.45, -1.95), (x, 2.65, -1.95), n)
        seam(p, (x, 1.45, 0.75), (x, 2.65, 0.75), n)
        seam(p, (x, 2.65, -1.95), (x, 2.65, 0.75), n)
    bolts(p, (-0.8, 3.201, -2.2), (0.8, 3.201, -2.2), 5, UP)
    bolts(p, (-0.8, 3.901, 2.0), (0.8, 3.901, 2.0), 4, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.45, 0.25, 10, "trim")
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 3.7, y + 0.02, z + d[2] * 3.7), u, (0, 1, 0), 0.55, 6.4, 0.1, "dark")
        p.obox((x + d[0] * 6.65, y + 0.03, z + d[2] * 6.65), u, (0, 1, 0), 0.57, 0.5, 0.11, "team")  # tip bands


def no_details(p):
    pass


unit.run(__file__, "ord_courier", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details)],
         attachments={"cargo": {"parent": "base", "at": list(CARGO)}},
         team_pieces=["base", "rotor"], budget=6000)
