"""Ark (Order heavy air transport, T2 air, footprint 3; S-219): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_ark/build.py

A tandem-rotor heavy lifter: a long armored box fuselage with a sloped nose
and dark canopy, add-on plates along the sides, long sponsons with the
landing wheels, a loading ramp at the back, a team stripe down the roof
and team side plates, a low front pylon and a tall aft pylon carrying the
two rotors, twin engine pods with exhausts on the aft pylon, and two cargo
hooks under the belly (the `cargo` attachment between them: where the
carried units hang). The client-spun `rotor` (blockout visual piece) is
the front rotor; the aft one is `tailRotor` turning the other way (axis
-Y), which the client already runs with the main rotor (Ambient). Order
reads heavy (M-14), BAR style (M-15). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 6.3, -7.0)
AFT = (0.0, 7.4, 7.6)
CARGO = (0.0, 0.4, 0.0)
W = 2.2  # half width of the fuselage


def blades(p, hub, count, length, phase, kind="dark"):
    x, y, z = hub
    p.cylinder("y", hub, 0.6, 0.35, 10, "trim")
    for i in range(count):
        a = phase + i * 2 * math.pi / count
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * (0.5 + length / 2), y + 0.03, z + d[2] * (0.5 + length / 2)), u, (0, 1, 0), 0.75, length, 0.12, kind)
        p.obox((x + d[0] * (length - 0.1), y + 0.04, z + d[2] * (length - 0.1)), u, (0, 1, 0), 0.77, 0.7, 0.13, "team")


def build_base(p):
    # fuselage: side profile (z, y), sloped nose, ramp up at the back
    p.prism_x([(-10.6, 1.3), (6.6, 1.3), (9.6, 2.6), (9.6, 4.9), (-7.6, 4.9), (-9.6, 4.1), (-10.6, 2.6)], -W, W, "paint", bevel=0.12)
    p.prism_x([(-10.3, 2.75), (-9.45, 4.05), (-7.7, 4.7), (-7.7, 4.95), (-9.55, 4.3), (-10.45, 2.95)], -1.9, 1.9, "glass", bevel=0.03)
    for sx in (-1, 1):
        x = sx * W
        p.box((x + sx * 0.01, 3.4, -8.6), (0.05, 0.9, 1.4), "glass")  # cockpit side windows
        for z in (-5.0, -2.6, -0.2, 2.2):
            p.box((x + sx * 0.01, 3.9, z), (0.05, 0.5, 0.7), "glass")  # cabin windows
        p.box((x + sx * 0.12, 2.0, -1.0), (0.24, 1.0, 13.0), "trim", bevel=0.06)  # add-on armor
        p.box((x + sx * 0.03, 3.25, 4.6), (0.05, 1.2, 3.4), "team", bevel=0.01)  # side plates
        # sponsons with the landing wheels
        p.box((sx * (W + 0.75), 1.75, 0.2), (1.3, 1.3, 7.6), "paint", bevel=0.18)
        p.box((sx * (W + 1.41), 1.95, 0.2), (0.05, 0.14, 6.0), "light")
        for z in (-2.2, 2.6):
            p.cylinder("x", (sx * (W + 0.75), 0.55, z), 0.55, 0.5, 12, "rubber", cap_kinds=("steel", "steel"))
            p.box((sx * (W + 0.75), 0.95, z), (0.2, 0.6, 0.2), "steel")
    p.prism_x([(-9.6, 1.0), (-8.6, 1.0), (-8.6, 1.3), (-9.6, 1.3)], -0.3, 0.3, "steel")  # nose gear leg
    p.cylinder("x", (0, 0.45, -9.1), 0.45, 0.6, 12, "rubber", cap_kinds=("steel", "steel"))
    p.box((0, 4.93, -1.5), (1.6, 0.05, 11.0), "team", bevel=0.012)  # roof stripe
    p.box((0, 3.0, 9.62), (3.4, 2.6, 0.05), "dark")  # ramp, closed
    p.box((0, 1.6, 9.0), (3.4, 0.1, 0.6), "hazard")
    # front pylon and rotor mast
    p.prism_x([(-8.6, 4.9), (-5.4, 4.9), (-5.9, 5.8), (-8.1, 5.8)], -1.0, 1.0, "trim", bevel=0.08)
    p.cylinder("y", (0, 6.05, -7.0), 0.35, 0.5, 8, "steel")
    # aft pylon, engine pods, rotor mast
    p.prism_x([(2.0, 4.9), (9.6, 4.9), (9.6, 6.6), (5.6, 6.9), (3.6, 6.4)], -1.2, 1.2, "paint", bevel=0.1)
    p.box((0, 6.62, 7.3), (1.6, 0.05, 2.6), "team", bevel=0.01)
    for sx in (-1, 1):
        x = sx * 1.75
        p.cylinder("z", (x, 5.8, 5.0), 0.6, 3.6, 12, "trim")
        p.cylinder("z", (x, 5.8, 3.15), 0.45, 0.1, 12, "dark")  # intake
        p.cylinder("z", (x, 5.8, 6.85), 0.42, 0.12, 12, "light")  # exhaust
        p.box((x * 0.8, 5.3, 5.0), (0.3, 0.5, 2.0), "steel")
    p.cylinder("y", (0, 7.1, 7.6), 0.35, 0.6, 8, "steel")
    # the aft rotor: turns with the front one, the other way (Ambient spins `tailRotor`)
    with p.sub("tailRotor", AFT, "spin", (0, -1, 0)):  # M-27
        blades(p, AFT, 3, 7.6, math.pi / 6)
    # cargo hooks under the belly
    for z in (-3.0, 3.0):
        p.box((0, 1.12, z), (1.4, 0.36, 1.0), "trim", bevel=0.04)
        p.box((0, 0.92, z), (1.46, 0.06, 1.06), "hazard")
        p.cylinder("y", (0, 0.7, z), 0.07, 0.4, 6, "steel")
        p.box((0, 0.45, z), (0.5, 0.16, 0.4), "dark")
    # lights: landing lights under the nose, beacons on the pylons, tail lights
    for sx in (-1, 1):
        p.box((sx * 0.9, 1.28, -8.8), (0.5, 0.06, 0.4), "head")
        p.box((sx * 1.6, 4.0, 9.64), (0.25, 0.25, 0.05), "light")
    p.box((0, 5.83, -6.0), (0.25, 0.08, 0.25), "light")
    p.box((0, 6.93, 5.2), (0.25, 0.08, 0.25), "light")


def details_base(p):
    for sx in (-1, 1):
        x = sx * (W + 0.25)
        n = (sx, 0, 0)
        for z in (-6.0, -2.0, 2.0):
            seam(p, (x, 1.55, z), (x, 2.45, z), n)
    bolts(p, (-1.2, 4.901, -6.6), (1.2, 4.901, -6.6), 6, UP)
    bolts(p, (-1.2, 4.901, 3.0), (1.2, 4.901, 3.0), 6, UP)


def build_rotor(p):
    blades(p, ROTOR, 3, 7.6, 0.0)


def no_details(p):
    pass


unit.run(__file__, "ord_ark", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details)],
         attachments={"cargo": {"parent": "base", "at": list(CARGO)}},
         team_pieces=["base", "rotor"], budget=8000)
