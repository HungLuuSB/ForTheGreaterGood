"""KEPT for reference (2026-10-23): heroic mech v2 (size approved, look too blocky), replaced by ../build.py (v3, M-33).

Sovereign (Order Commander, footprint 2): the heroic walking battle mech
(M-32). blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sovereign/build.py

The user's review of v1 (2026-10-23): higher, bigger, a heroic mech, not a
box robot; an original design, BAR-level finish. About 2.7x a Lancer's
height (9.7 studs to the brow), pauldrons spanning 10 studs. Long legs (45%)
with a real knee bend: armored thighs and shins over a dark under-frame,
pistons behind, knee caps, compact feet with toe and heel plates. A narrow
armored pelvis under a broad V chest with the cyan command core (power) and
chest team plates; a sensor head on a neck under an armored brow with a
cyan visor; big layered pauldrons past the body with the team plates; a
reactor backpack with two glowing turbine ends; long arms: the build
forearm with the emitter (`nano`, power) and a twin-barrel weapon pod
(`forearmR`, `muzzle`, weapon). Clean, sleek, heavy sloped plates, upright
and noble (Order, M-14). Same rig as v1 (rig.md 10). v1 and the tracked
design are kept in v1/ and tracked/. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, joint, piston, plate_on, rivets, seg  # noqa: E402
from unit import UP, seam  # noqa: E402

FWD = (0, 0, -1)
X = (1, 0, 0)
V = lib.vec


# ---------------------------------------------------------------- pelvis


def build_base(p):
    # dark under-frame core, armored cod plate and hip guards over it
    p.prism_x([(-0.7, 4.3), (0.7, 4.3), (0.85, 4.9), (0.62, 5.22), (-0.62, 5.22), (-0.85, 4.9)], -0.9, 0.9, "dark", bevel=0.06)
    p.prism_x([(-1.08, 4.4), (-0.8, 4.12), (-0.72, 4.12), (-0.72, 5.15), (-0.98, 5.1)], -0.7, 0.7, "paint", bevel=0.05)
    p.prism_x([(0.72, 4.3), (1.0, 4.45), (0.98, 5.05), (0.72, 5.12)], -0.75, 0.75, "paint", bevel=0.05)
    for sx in (-1, 1):
        p.obox((sx * 0.98, 4.85, -0.25), (0, 0, 1), (sx, 0.25, 0), 1.3, 0.75, 0.1, "paint", bevel=0.03)  # hip guards
    joint(p, (0, 4.6, 0), 0.32, 3.2)
    p.cylinder("y", (0, 5.25, 0), 0.78, 0.12, 18, "trim")  # waist bearing
    p.box((0, 4.62, -1.07), (0.9, 0.08, 0.04), "light")


def details_base(p):
    rivets(p, (-0.5, 4.95, -1.0), (0.5, 4.95, -1.0), 4, FWD)
    seam(p, (-0.6, 4.75, -1.06), (0.6, 4.75, -1.06), FWD)


# ---------------------------------------------------------------- torso

CHEST = [(-1.4, -1.0), (1.4, -1.0), (1.55, -0.3), (1.45, 1.05), (-1.45, 1.05), (-1.55, -0.3)]


def build_torso(p):
    # waist: a steel column with four abdominal pistons round it
    p.cylinder("y", (0, 5.6, 0), 0.62, 0.62, 14, "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            piston(p, (sx * 0.62, 5.3, sz * 0.45), (sx * 0.85, 6.3, sz * 0.55), r=0.06)
    # abdomen: dark frame and two armored bands on the front
    p.prism_y([(-0.95, -0.75), (0.95, -0.75), (1.05, 0.0), (0.95, 0.75), (-0.95, 0.75), (-1.05, 0.0)], 5.85, 6.55, "dark", bevel=0.05)
    for i, y in enumerate((5.95, 6.3)):
        p.prism_x([(-0.98 - 0.04 * i, y), (-0.8, y), (-0.8, y + 0.3), (-0.95 - 0.06 * i, y + 0.3)], -0.75 + 0.05 * i, 0.75 - 0.05 * i, "paint", bevel=0.03)
    # chest: widening upward into the V, sloped front plates round the core
    p.prism_y(CHEST, 6.45, 8.0, "paint", bevel=0.08, top_scale=1.32)
    for sx in (-1, 1):
        p.prism_x([(-1.25, 6.45), (-1.62, 7.0), (-1.95, 7.95), (-1.45, 8.05), (-1.2, 7.2)], *sorted((sx * 0.62, sx * 1.95)), "paint", bevel=0.05)
        p.obox((sx * 1.3, 7.55, -1.78), X, (0, 0.45, -1), 0.7, 0.62, 0.05, "team", bevel=0.01)  # chest team plates
        p.obox((sx * 1.55, 6.85, -1.5), (sx * 0.4, 1, -0.3), (0, 0.3, -1), 1.0, 0.12, 0.04, "light")
    # the command core in a ringed housing, with four radial fins
    p.cylinder("z", (0, 7.2, -1.5), 0.66, 0.28, 18, "trim")
    p.cylinder("z", (0, 7.2, -1.66), 0.56, 0.06, 18, "dark")
    p.cylinder("z", (0, 7.2, -1.7), 0.5, 0.05, 18, "power")
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        p.obox((math.cos(r) * 0.62, 7.2 + math.sin(r) * 0.62, -1.62), (math.cos(r), math.sin(r), 0), FWD, 0.3, 0.08, 0.12, "steel")
    # armored collar behind the head
    p.prism_x([(-1.05, 7.85), (-0.7, 8.42), (0.95, 8.42), (1.15, 7.85)], -1.6, 1.6, "paint", bevel=0.06)
    # shoulder sockets
    for sx in (-1, 1):
        p.cylinder("x", (sx * 2.75, 7.6, 0), 0.62, 0.5, 14, "dark")
    # pauldrons: a big sloped shell over an under-layer, team plate on top,
    # a light strip down the front slope, a vent on the outside
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 2.65, sx * 4.95))
        p.prism_x([(-1.5, 7.35), (1.5, 7.35), (1.62, 8.3), (1.2, 8.95), (-1.2, 8.95), (-1.62, 8.3)], x0, x1, "paint", bevel=0.09)
        xu0, xu1 = sorted((sx * 3.1, sx * 4.75))
        p.prism_x([(-1.25, 6.95), (1.25, 6.95), (1.3, 7.4), (-1.3, 7.4)], xu0, xu1, "trim", bevel=0.04)
        p.box((sx * 3.8, 8.97, 0.0), (1.75, 0.04, 2.25), "team", bevel=0.01)
        p.obox((sx * 3.8, 8.62, -1.42), X, (0, 0.6, -0.8), 1.7, 0.3, 0.04, "light")
        p.box((sx * 4.97, 8.0, 0.2), (0.04, 0.6, 1.6), "light")
        p.box((sx * 4.98, 7.6, 0.2), (0.03, 0.08, 1.4), "light")
    # reactor backpack: housing, two glowing turbine ends, grilles, cables to the pauldrons
    p.box((0, 7.4, 1.95), (3.4, 2.2, 1.6), "trim", bevel=0.1)
    p.box((0, 8.0, 2.76), (2.6, 0.5, 0.04), "power")
    for sx in (-1, 1):
        p.box((sx * 1.71, 7.4, 1.95), (0.03, 0.12, 1.3), "light")
    for sx in (-1, 1):
        p.cylinder("z", (sx * 0.9, 7.15, 2.8), 0.55, 0.14, 16, "dark")
        p.cylinder("z", (sx * 0.9, 7.15, 2.88), 0.42, 0.04, 16, "power")
        p.cylinder("z", (sx * 0.9, 7.15, 2.9), 0.14, 0.06, 8, "steel")
        cable(p, [(sx * 1.6, 8.2, 1.6), (sx * 2.4, 8.5, 1.3), (sx * 3.0, 8.4, 1.2)])
        cable(p, [(sx * 1.6, 6.6, 1.6), (sx * 2.1, 6.4, 1.0), (sx * 2.7, 7.0, 0.6)])
    p.cylinder("y", (1.2, 9.25, 2.3), 0.06, 1.7, 6, "dark")
    p.box((1.2, 10.12, 2.3), (0.14, 0.12, 0.14), "light")
    p.cylinder("y", (-1.2, 8.75, 2.3), 0.18, 0.4, 8, "trim")


def details_torso(p):
    seam(p, (-1.6, 7.75, -1.6), (-0.7, 7.75, -1.62), (0, 0.45, -1))
    seam(p, (0.7, 7.75, -1.62), (1.6, 7.75, -1.6), (0, 0.45, -1))
    for sx in (-1, 1):
        rivets(p, (sx * 3.0, 8.96, -1.0), (sx * 4.6, 8.96, -1.0), 5, UP)
        rivets(p, (sx * 3.0, 8.96, 1.0), (sx * 4.6, 8.96, 1.0), 5, UP)
        seam(p, (sx * 4.96, 7.5, -1.2), (sx * 4.96, 8.6, -1.2), (sx, 0, 0))
    rivets(p, (-1.4, 6.65, 2.76), (1.4, 6.65, 2.76), 7, (0, 0, 1))


# ---------------------------------------------------------------- head


def build_head(p):
    p.cylinder("y", (0, 8.55, -0.2), 0.36, 0.55, 12, "steel")
    p.cylinder("y", (0, 8.35, -0.2), 0.5, 0.12, 12, "dark")
    p.prism_y([(-0.55, -1.0), (0.55, -1.0), (0.68, -0.5), (0.62, 0.4), (-0.62, 0.4), (-0.68, -0.5)],
              8.62, 9.5, "paint", bevel=0.06, top_scale=0.84)
    p.prism_x([(-1.1, 9.32), (-0.92, 9.62), (0.25, 9.7), (0.25, 9.46)], -0.78, 0.78, "trim", bevel=0.04)  # brow
    p.box((0, 9.08, -1.02), (0.95, 0.16, 0.04), "light")  # visor
    p.box((0, 8.78, -0.98), (0.6, 0.18, 0.04), "grille")  # chin vent
    for sx in (-1, 1):
        p.cylinder("x", (sx * 0.7, 9.0, -0.3), 0.2, 0.14, 10, "dark")
        p.box((sx * 0.78, 9.0, -0.3), (0.02, 0.07, 0.14), "light")
    p.cylinder("y", (0.42, 9.95, 0.12), 0.04, 0.9, 6, "dark")
    p.cylinder("y", (-0.3, 9.8, 0.18), 0.035, 0.6, 6, "dark")


def details_head(p):
    seam(p, (-0.55, 9.32, -1.0), (0.55, 9.32, -1.0), FWD)


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 3.35
    joint(p, (sx * 3.3, 7.6, 0), 0.58, 0.95)
    a, b = (x, 7.25, 0), (x, 5.75, 0)
    seg(p, a, b, 0.8, 0.85, "dark", pad=0.1)
    p.obox((x + sx * 0.38, 6.55, 0), UP, X, 1.25, 1.0, 0.14, "paint", bevel=0.04)  # outer armor
    p.obox((x, 6.6, -0.48), UP, FWD, 1.0, 0.7, 0.1, "paint", bevel=0.03)  # front armor
    piston(p, (x, 7.0, 0.45), (x, 5.8, 0.4))
    joint(p, (x, 5.5, 0), 0.44, 1.0)


def build_armL(p):
    upper_arm(p, -1)


def build_armR(p):
    upper_arm(p, 1)


def details_arm(sx):
    def d(p):
        rivets(p, (sx * 3.81, 6.1, -0.35), (sx * 3.81, 7.0, -0.35), 3, (sx, 0, 0))
    return d


NANO_A, NANO_B = (-3.35, 5.5, 0.0), (-3.35, 3.75, -0.85)


def build_nano(p):
    x = -3.35
    seg(p, NANO_A, NANO_B, 0.85, 0.85, "dark", pad=0.15)
    seg(p, NANO_A, NANO_B, 1.15, 0.5, "paint", offset=0.32, pad=0.05)  # front armor
    plate_on(p, NANO_A, NANO_B, 0.2, 0.7, 0.36, "team", 0.58)
    seg(p, NANO_A, NANO_B, 0.18, 0.95, "trim", pad=0.0)  # spine
    # emitter: a ringed barrel facing forward, a glowing lens, three focusing fins
    p.cylinder("z", (x, 3.55, -1.25), 0.42, 0.55, 16, "trim")
    p.cylinder("z", (x, 3.55, -1.55), 0.46, 0.07, 16, "power")
    p.cylinder("z", (x, 3.55, -1.6), 0.28, 0.04, 14, "power")
    for a in (90, 210, 330):
        r = math.radians(a)
        p.obox((x + math.cos(r) * 0.5, 3.55 + math.sin(r) * 0.5, -1.45), (0, 0, 1), (math.cos(r), math.sin(r), 0),
               0.6, 0.07, 0.2, "dark")
    for s2 in (-1, 1):
        p.obox((x + s2 * 0.58, 4.6, -0.45), (0, -1.75, -0.85), (s2, 0, 0), 1.2, 0.12, 0.03, "light")


def details_nano(p):
    rivets(p, (-3.79, 5.1, -0.1), (-3.79, 4.1, -0.6), 4, (-1, 0, 0))


def build_forearmR(p):
    x = 3.45
    # the pod: an armored block over a dark frame, held forward from the elbow
    p.prism_x([(-0.35, 4.05), (0.45, 4.05), (0.55, 5.2), (-0.2, 5.55), (-2.85, 5.5), (-3.05, 5.1), (-2.95, 4.05)],
              x - 0.62, x + 0.62, "paint", bevel=0.08)
    p.prism_x([(-2.6, 3.88), (0.2, 3.88), (0.2, 4.1), (-2.6, 4.1)], x - 0.5, x + 0.5, "dark", bevel=0.03)
    p.box((x + 0.64, 4.85, -1.2), (0.04, 0.7, 1.8), "team", bevel=0.01)
    p.box((x - 0.63, 4.95, -1.0), (0.04, 0.5, 1.4), "grille")
    p.box((x, 5.56, -1.6), (0.7, 0.04, 1.4), "grille")
    # ammo drum on the side, a feed into the pod
    p.cylinder("x", (x + 0.75, 4.45, -0.1), 0.42, 0.3, 14, "trim")
    p.cylinder("x", (x + 0.92, 4.45, -0.1), 0.25, 0.05, 10, "dark")
    # twin barrels in a shroud, muzzle rings, a ready light
    p.box((x, 4.65, -3.1), (1.0, 0.75, 0.3), "trim", bevel=0.05)
    for dx in (-0.24, 0.24):
        p.cylinder("z", (x + dx, 4.65, -3.55), 0.17, 1.0, 10, "dark")
        p.cylinder("z", (x + dx, 4.65, -3.9), 0.2, 0.18, 10, "steel")
        p.cylinder("z", (x + dx, 4.65, -4.02), 0.18, 0.05, 10, "weapon")
    p.box((x, 5.08, -2.98), (0.5, 0.06, 0.04), "weapon")
    p.box((x + 0.63, 5.25, -1.8), (0.03, 0.12, 2.0), "light")
    p.box((x - 0.63, 5.25, -1.8), (0.03, 0.12, 2.0), "light")


def details_forearmR(p):
    rivets(p, (4.08, 4.3, -2.6), (4.08, 4.3, -0.3), 6, X)
    seam(p, (4.08, 5.3, -2.6), (4.08, 5.3, -0.3), X)


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    x = sx * 1.5
    HIP, KNEE, ANKLE = (x, 4.5, 0.0), (x, 2.6, -0.55), (x, 0.8, 0.15)

    def hip(p):
        joint(p, (sx * 1.45, 4.6, 0), 0.5, 0.6)
        p.obox((sx * 1.8, 4.65, 0.0), UP, X, 1.0, 1.2, 0.12, "paint", bevel=0.03)

    def thigh(p):
        seg(p, HIP, KNEE, 0.95, 0.95, "dark", pad=0.15)
        seg(p, HIP, KNEE, 1.3, 0.55, "paint", offset=0.32, pad=-0.15)  # front armor
        for s2 in (-1, 1):  # side armor
            p.obox(tuple((V(HIP) + V(KNEE)) / 2 + V((s2 * 0.55, 0.05, 0.05))), tuple(V(KNEE) - V(HIP)), (s2, 0, 0),
                   1.4, 0.95, 0.1, "paint", bevel=0.03)
        piston(p, (x, 4.25, 0.55), (x, 2.95, 0.15))
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.62, 3.6, -0.25), (0, -1.9, -0.55), (s2, 0, 0), 1.5, 0.14, 0.03, "light")
        joint(p, KNEE, 0.45, 1.05)
        p.prism_x([(-1.15, 2.2), (-0.8, 2.15), (-0.75, 3.05), (-1.05, 2.95)], x - 0.55, x + 0.55, "paint", bevel=0.05)  # knee cap

    def shin(p):
        seg(p, KNEE, ANKLE, 0.9, 0.9, "dark", pad=0.1)
        seg(p, KNEE, ANKLE, 1.25, 0.6, "paint", offset=0.28, pad=-0.2)
        plate_on(p, KNEE, ANKLE, 0.3, 0.75, 0.62, "team", 0.6)
        piston(p, (x, 2.3, 0.15), (x, 1.05, 0.6))
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.64, 1.6, -0.3), (0, -1.8, 0.7), (s2, 0, 0), 1.2, 0.12, 0.03, "light")
        p.box((x, 1.3, 0.62), (0.6, 0.5, 0.04), "power")

    def foot(p):
        joint(p, ANKLE, 0.34, 0.95)
        p.box((x, 0.5, 0.15), (0.85, 0.55, 0.85), "dark", bevel=0.05)  # tarsal block
        p.prism_x([(-1.5, 0.0), (-0.15, 0.0), (-0.15, 0.48), (-0.85, 0.56), (-1.48, 0.28)], x - 0.64, x + 0.64, "paint", bevel=0.05)  # toe plate
        p.prism_x([(0.45, 0.0), (1.25, 0.0), (1.25, 0.32), (0.95, 0.5), (0.45, 0.5)], x - 0.5, x + 0.5, "paint", bevel=0.05)  # heel plate
        p.box((x, 0.04, -0.3), (1.15, 0.08, 1.9), "dark")  # sole
        p.box((x, 0.2, -1.5), (0.9, 0.1, 0.03), "light")
        p.box((x, 0.25, 1.26), (0.6, 0.1, 0.03), "light")

    def det_thigh(p):
        rivets(p, (x + sx * 0.62, 4.2, -0.2), (x + sx * 0.62, 3.0, -0.5), 4, (sx, 0, 0))

    def det_shin(p):
        seam(p, (x - 0.45, 2.1, -0.85), (x + 0.45, 2.1, -0.85), (0, 0.35, -1))

    none = lambda p: None  # noqa: E731
    return [
        unit.PieceSpec(f"hip{n}", "base", (sx * 1.3, 4.6, 0.0), hip, none),
        unit.PieceSpec(f"thigh{n}", f"hip{n}", HIP, thigh, det_thigh),
        unit.PieceSpec(f"shin{n}", f"thigh{n}", KNEE, shin, det_shin),
        unit.PieceSpec(f"foot{n}", f"shin{n}", (x, 0.75, 0.15), foot, none),
    ]


unit.run(__file__, "ord_sovereign", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", (0.0, 5.3, 0.0), build_torso, details_torso),
                 unit.PieceSpec("head", "torso", (0.0, 8.5, -0.2), build_head, details_head),
                 unit.PieceSpec("armL", "torso", (-3.3, 7.6, 0.0), build_armL, details_arm(-1)),
                 unit.PieceSpec("nano", "armL", NANO_A, build_nano, details_nano),
                 unit.PieceSpec("armR", "torso", (3.3, 7.6, 0.0), build_armR, details_arm(1)),
                 unit.PieceSpec("forearmR", "armR", (3.35, 5.5, 0.0), build_forearmR, details_forearmR)]
         + leg_specs(-1) + leg_specs(1),
         attachments={"muzzle": {"parent": "forearmR", "at": [3.45, 4.65, -4.1]}},
         budget=9000,
         previews=[("35", (-17, 13, -20), (0, 5.0, 0), 50),
                   ("side", (24, 5.5, 0), (0, 5.0, 0), 50),
                   ("80", (0, 34, 4), (0, 5.0, 0), 50),
                   ("close", (-8.0, 9.0, -10.5), (0, 6.5, -0.5), 35)])
