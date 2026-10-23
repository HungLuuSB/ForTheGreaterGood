"""Sovereign (Order Commander, footprint 2): the heroic walking mech, v3
(M-33). blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sovereign/build.py

The user's review of v2 (2026-10-23): the size is right; the look is too
blocky. v3 keeps v2's rig and pivots and rebuilds the shapes:
- balanced mass: thick armored legs (tapered thigh plates, big rounded knee
  guards, shin armor, wide feet with toe and heel plates) and thick arms
  (forearm armor, elbow guards); a sturdy, grounded stance;
- shapes, not boxes: round shoulder housings and joint drums, tapered and
  angled plates with bevels big enough to read at 55 degrees, overlapping
  armor over a dark under-frame, pistons behind the knees and elbows;
- a small sleek helmet with a narrow cyan visor, set down between the
  shoulders;
- team color in large areas: the arched pauldron shells, the chest plates,
  the shin plates and the backpack panels; the sand-grey faction paint on
  the frame and secondary plates;
- hazard striping on the joints, vents, cables, lights, a bigger weapon pod
  with long twin barrels (`muzzle`) and a clear build-emitter arm (`nano`).
Original design. v2, v1 and the tracked design are kept in v2/, v1/ and
tracked/. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import arch, cable, drum, hazard, piston, rivets, tseg  # noqa: E402
from unit import UP, seam  # noqa: E402

FWD = (0, 0, -1)
X = (1, 0, 0)
V = lib.vec


# ---------------------------------------------------------------- pelvis


def build_base(p):
    p.prism_x([(-0.75, 4.2), (0.75, 4.2), (0.9, 4.85), (0.65, 5.2), (-0.65, 5.2), (-0.9, 4.85)], -0.95, 0.95, "dark", bevel=0.1)
    # tapered cod plate and a rear plate, both with big bevels
    p.prism_x([(-1.15, 4.45), (-0.82, 4.05), (-0.72, 4.05), (-0.72, 5.15), (-1.05, 5.05)], -0.75, 0.75, "paint", bevel=0.12)
    p.prism_x([(0.72, 4.25), (1.05, 4.45), (1.0, 5.05), (0.72, 5.15)], -0.8, 0.8, "paint", bevel=0.1)
    hazard(p, (0, 4.32, -1.08), X, (0, -0.4, -1), 1.1, 0.22, stripes=6)
    # hip skirts: angled plates over the hip joints
    for sx in (-1, 1):
        p.obox((sx * 1.05, 4.95, -0.2), (0, 0, 1), (sx, 0.35, 0), 1.5, 0.95, 0.14, "paint", bevel=0.05)
    drum(p, (0, 4.6, 0), 0.4, 3.0, "steel", "trim")
    p.cylinder("y", (0, 5.25, 0), 0.8, 0.12, 20, "trim")
    p.box((0, 4.75, -1.12), (1.1, 0.14, 0.04), "light")


def details_base(p):
    rivets(p, (-0.5, 4.95, -1.05), (0.5, 4.95, -1.05), 4, (0, -0.3, -1))


# ---------------------------------------------------------------- torso

CHEST = [(-1.35, -1.0), (1.35, -1.0), (1.55, -0.3), (1.45, 1.05), (-1.45, 1.05), (-1.55, -0.3)]


def build_torso(p):
    # waist: a steel column, four abdominal pistons, dark abdomen with bands
    p.cylinder("y", (0, 5.6, 0), 0.66, 0.62, 18, "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            piston(p, (sx * 0.6, 5.3, sz * 0.45), (sx * 0.85, 6.3, sz * 0.55), r=0.07)
    p.prism_y([(-0.95, -0.78), (0.95, -0.78), (1.08, 0.0), (0.95, 0.78), (-0.95, 0.78), (-1.08, 0.0)], 5.85, 6.55, "dark", bevel=0.08)
    for i, y in enumerate((5.92, 6.27)):
        p.prism_x([(-1.0 - 0.05 * i, y), (-0.8, y), (-0.8, y + 0.3), (-0.96 - 0.06 * i, y + 0.3)], -0.78 + 0.06 * i, 0.78 - 0.06 * i, "paint", bevel=0.05)
    # chest: a V widening up to the shoulders, big bevels
    p.prism_y(CHEST, 6.45, 8.05, "paint", bevel=0.18, top_scale=1.3)
    # large team chest plates either side of the core, angled outward
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.62, sx * 2.0))
        p.prism_x([(-1.22, 6.55), (-1.62, 7.05), (-1.92, 7.95), (-1.42, 8.05), (-1.18, 7.25)], x0, x1, "team", bevel=0.1)
        p.obox((sx * 1.62, 6.75, -1.47), (sx * 0.35, 1, -0.3), (0, 0.3, -1), 1.2, 0.16, 0.05, "light")
    # the command core: a ringed housing, lens, four radial fins
    p.cylinder("z", (0, 7.25, -1.52), 0.7, 0.3, 22, "trim", bevel=0.04)
    p.cylinder("z", (0, 7.25, -1.69), 0.6, 0.06, 22, "dark")
    p.cylinder("z", (0, 7.25, -1.73), 0.5, 0.05, 22, "power")
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        p.obox((math.cos(r) * 0.66, 7.25 + math.sin(r) * 0.66, -1.66), (math.cos(r), math.sin(r), 0), FWD, 0.34, 0.09, 0.14, "steel")
    # a low collar round the helmet (the head sits down between the shoulders)
    p.prism_x([(-1.0, 7.9), (-0.55, 8.55), (0.9, 8.6), (1.2, 7.9)], -1.55, 1.55, "paint", bevel=0.14)
    for sx in (-1, 1):
        p.prism_x([(-0.75, 8.0), (-0.45, 8.85), (0.6, 8.85), (0.85, 8.0)], *sorted((sx * 0.75, sx * 1.55)), "paint", bevel=0.1)
    # round shoulder housings
    for sx in (-1, 1):
        drum(p, (sx * 2.85, 7.6, 0), 0.82, 0.8, "dark", "trim", sides=20)
    # pauldrons: arched team shells over a trim under-layer, a paint rim,
    # a front light strip, hazard striping on the lower front edge, side vents
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 2.5, sx * 5.0))
        p.prism_x(arch(-1.75, 1.75, 7.45, 9.2, steps=9, flat=0.3), x0, x1, "team", bevel=0.14)
        xu0, xu1 = sorted((sx * 2.75, sx * 4.8))
        p.prism_x(arch(-1.5, 1.5, 6.95, 7.6, steps=5, flat=0.5), xu0, xu1, "trim", bevel=0.06)
        xr0, xr1 = sorted((sx * 4.95, sx * 5.12))
        p.prism_x(arch(-1.6, 1.6, 7.35, 8.95, steps=9, flat=0.3), xr0, xr1, "paint", bevel=0.04)
        p.obox((sx * 3.75, 8.62, -1.6), X, (0, 0.6, -0.8), 2.0, 0.3, 0.04, "light")
        p.box((sx * 3.75, 7.05, -1.52), (1.7, 0.12, 0.04), "power")
        hazard(p, (sx * 3.75, 7.55, -1.76), X, FWD, 2.1, 0.22, stripes=7)
        p.box((sx * 5.13, 8.15, 0.25), (0.04, 0.55, 1.5), "power")
        p.box((sx * 5.14, 7.7, 0.25), (0.03, 0.1, 1.3), "light")
    # reactor backpack: a rounded housing, team side panels, glowing turbine
    # ends, a vent, cables to the pauldrons, the antenna mast
    p.box((0, 7.45, 1.95), (3.3, 2.2, 1.6), "trim", bevel=0.28)
    for sx in (-1, 1):
        p.obox((sx * 1.68, 7.45, 1.95), (0, 0, 1), (sx, 0, 0), 1.3, 1.7, 0.08, "team", bevel=0.03)
        p.cylinder("z", (sx * 0.85, 7.2, 2.8), 0.56, 0.16, 20, "dark")
        p.cylinder("z", (sx * 0.85, 7.2, 2.89), 0.44, 0.04, 20, "power")
        p.cylinder("z", (sx * 0.85, 7.2, 2.91), 0.14, 0.06, 8, "steel")
        cable(p, [(sx * 1.4, 8.3, 1.5), (sx * 2.2, 8.6, 1.3), (sx * 2.8, 8.4, 1.15)])
        cable(p, [(sx * 1.5, 6.5, 1.5), (sx * 2.1, 6.3, 0.9), (sx * 2.6, 6.9, 0.5)])
    p.box((0, 8.12, 2.77), (2.4, 0.42, 0.04), "power")
    for sx in (-1, 1):
        p.box((sx * 1.66, 6.6, 1.95), (0.03, 0.14, 1.3), "light")
    p.box((0, 8.62, 1.95), (2.6, 0.04, 1.2), "team", bevel=0.01)
    p.cylinder("y", (1.2, 9.25, 2.3), 0.06, 1.6, 6, "dark")
    p.box((1.2, 10.08, 2.3), (0.14, 0.12, 0.14), "light")


def details_torso(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.8, 9.18, -0.9), (sx * 4.7, 9.18, -0.9), 6, UP)
        rivets(p, (sx * 2.8, 9.18, 0.9), (sx * 4.7, 9.18, 0.9), 6, UP)
        seam(p, (sx * 2.6, 9.19, 0.0), (sx * 4.9, 9.19, 0.0), UP)
    rivets(p, (-1.3, 6.55, 2.76), (1.3, 6.55, 2.76), 7, (0, 0, 1))
    seam(p, (-1.4, 8.0, -1.62), (1.4, 8.0, -1.62), (0, 0.4, -1))


# ---------------------------------------------------------------- head


def build_head(p):
    # a small sleek helmet set down in the collar: pointed brow, narrow visor
    p.cylinder("y", (0, 8.35, -0.2), 0.32, 0.4, 12, "steel")
    p.prism_y([(-0.5, 0.35), (0.5, 0.35), (0.58, -0.25), (0.28, -0.95), (-0.28, -0.95), (-0.58, -0.25)],
              8.45, 9.15, "paint", bevel=0.1, top_scale=0.68, top_center=(0, -0.1))
    p.prism_x([(-0.95, 8.95), (-0.6, 9.28), (0.15, 9.32), (0.2, 9.1)], -0.32, 0.32, "team", bevel=0.05)  # crest
    p.obox((0, 8.85, -0.9), X, (0, 0.25, -1), 0.62, 0.09, 0.05, "light")  # narrow visor
    p.prism_x([(-0.9, 8.45), (-0.72, 8.45), (-0.6, 8.75), (-0.92, 8.7)], -0.38, 0.38, "trim", bevel=0.03)  # chin guard
    for sx in (-1, 1):
        p.obox((sx * 0.55, 8.75, -0.3), (0, 0, 1), (sx, 0, 0), 0.6, 0.45, 0.08, "trim", bevel=0.02)  # cheek plates
        p.cylinder("x", (sx * 0.6, 8.8, -0.25), 0.12, 0.08, 10, "head")
    p.cylinder("y", (0.38, 9.55, 0.15), 0.035, 0.8, 6, "dark")


def details_head(p):
    seam(p, (-0.4, 9.0, -0.75), (0.4, 9.0, -0.75), (0, 0.4, -1))


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 3.35
    drum(p, (sx * 3.3, 7.6, 0), 0.66, 1.05, "steel", "trim", sides=18)
    tseg(p, (x, 7.2, 0), (x, 5.8, 0), 1.0, 1.0, 0.95, 0.95, "dark", pad=0.1)
    # overlapping armor: a tapered outer shell and a front plate
    tseg(p, (x, 7.1, 0), (x, 5.9, 0), 1.45, 1.35, 1.3, 1.2, "paint", bevel=0.12)
    p.obox((x + sx * 0.74, 6.5, 0), UP, X, 0.9, 0.8, 0.08, "trim", bevel=0.02)
    piston(p, (x, 7.0, 0.62), (x, 5.95, 0.66), r=0.11)  # sleeve behind the elbow
    drum(p, (x, 5.5, 0), 0.5, 1.25, "steel", "trim")
    hazard(p, (x, 5.5, 0.52), X, (0, 0, 1), 1.15, 0.22, stripes=5)


def build_armL(p):
    upper_arm(p, -1)


def build_armR(p):
    upper_arm(p, 1)


def details_arm(sx):
    def d(p):
        rivets(p, (sx * 4.07, 6.1, -0.3), (sx * 4.07, 6.9, -0.3), 3, (sx, 0, 0))
    return d


NANO_A, NANO_B = (-3.35, 5.5, 0.0), (-3.35, 3.75, -0.85)


def build_nano(p):
    x = -3.35
    tseg(p, NANO_A, NANO_B, 0.95, 0.95, 0.9, 0.9, "dark", pad=0.15)
    tseg(p, NANO_A, NANO_B, 1.4, 0.75, 1.25, 0.6, "paint", off0=0.25, off1=0.25, bevel=0.12)  # forearm armor
    # elbow guard: a rounded cap over the back of the elbow
    p.prism_x(arch(-0.45, 0.85, 5.45, 6.05, steps=5, flat=0.2), x - 0.6, x + 0.6, "paint", bevel=0.08)
    piston(p, (x, 5.15, 0.6), (x, 4.45, 0.15), r=0.09, sleeve="steel")  # the rod behind the elbow
    # the emitter: a ringed barrel, a big glowing lens, three focusing prongs
    p.cylinder("z", (x, 3.55, -1.25), 0.52, 0.55, 20, "trim", bevel=0.04)
    p.cylinder("z", (x, 3.55, -1.55), 0.56, 0.07, 20, "power")
    p.cylinder("z", (x, 3.55, -1.6), 0.34, 0.04, 16, "power")
    for a in (90, 210, 330):
        r = math.radians(a)
        p.obox((x + math.cos(r) * 0.62, 3.55 + math.sin(r) * 0.62, -1.55), (0, 0, 1), (math.cos(r), math.sin(r), 0),
               0.75, 0.09, 0.22, "dark", bevel=0.02)
    for s2 in (-1, 1):
        p.obox((x + s2 * 0.71, 4.6, -0.45), (0, -1.75, -0.85), (s2, 0, 0), 1.3, 0.14, 0.03, "light")


def details_nano(p):
    rivets(p, (-4.06, 5.0, -0.1), (-4.06, 4.0, -0.55), 4, (-1, 0, 0))


def build_forearmR(p):
    x = 3.45
    # a big pod: armored block over a dark frame, a team side panel, an
    # ammo drum, vents; long twin barrels in a shroud, ready lights
    p.prism_x([(-0.35, 4.0), (0.5, 4.0), (0.62, 5.2), (-0.2, 5.62), (-3.05, 5.55), (-3.25, 5.1), (-3.1, 4.0)],
              x - 0.78, x + 0.78, "paint", bevel=0.16)
    p.prism_x([(-2.8, 3.82), (0.25, 3.82), (0.25, 4.08), (-2.8, 4.08)], x - 0.6, x + 0.6, "dark", bevel=0.04)
    p.obox((x + 0.8, 4.85, -1.35), (0, 0, 1), X, 2.4, 0.95, 0.06, "team", bevel=0.02)
    p.box((x - 0.79, 4.95, -1.3), (0.04, 0.6, 1.8), "grille")
    p.box((x, 5.6, -1.7), (0.9, 0.04, 1.5), "grille")
    drum(p, (x + 0.95, 4.45, -0.15), 0.5, 0.4, "trim", "dark", sides=18)
    p.box((x, 4.62, -3.35), (1.15, 0.85, 0.35), "trim", bevel=0.06)
    for dx in (-0.27, 0.27):
        p.cylinder("z", (x + dx, 4.65, -4.05), 0.18, 1.6, 12, "dark")
        p.cylinder("z", (x + dx, 4.65, -4.3), 0.22, 0.22, 12, "steel")
        p.cylinder("z", (x + dx, 4.65, -4.82), 0.22, 0.2, 12, "steel")
        p.cylinder("z", (x + dx, 4.65, -4.95), 0.19, 0.05, 12, "weapon")
    p.box((x, 5.1, -3.2), (0.55, 0.06, 0.04), "weapon")
    for s2 in (-1, 1):
        p.box((x + s2 * 0.79, 5.3, -1.8), (0.03, 0.14, 2.2), "light")
    hazard(p, (x, 4.06, -0.4), (0, 0, 1), (0, -1, 0), 1.0, 0.5, stripes=4)


def details_forearmR(p):
    rivets(p, (4.24, 4.25, -2.8), (4.24, 4.25, -0.3), 6, X)


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    x = sx * 1.5
    HIP, KNEE, ANKLE = (x, 4.5, 0.0), (x, 2.6, -0.55), (x, 0.8, 0.15)

    def hip(p):
        drum(p, (sx * 1.55, 4.6, 0), 0.62, 0.75, "steel", "trim")
        p.obox((sx * 1.98, 4.65, 0.0), UP, X, 1.1, 1.3, 0.14, "paint", bevel=0.04)
        hazard(p, (sx * 2.06, 4.65, 0.0), (0, 0, 1), X, 1.0, 0.24, stripes=5)

    def thigh(p):
        tseg(p, HIP, KNEE, 1.05, 1.05, 1.0, 1.0, "dark", pad=0.12)
        # tapered front plate, side plates, a rear plate: overlapping armor
        tseg(p, HIP, KNEE, 1.8, 0.8, 1.5, 0.6, "paint", off0=0.32, off1=0.38, pad=-0.1, bevel=0.14)
        for s2 in (-1, 1):
            p.obox(tuple((V(HIP) + V(KNEE)) / 2 + V((s2 * 0.62, 0.1, 0.0))), tuple(V(KNEE) - V(HIP)), (s2, 0, 0),
                   1.55, 1.15, 0.12, "paint", bevel=0.04)
        tseg(p, HIP, KNEE, 1.2, 0.35, 1.0, 0.3, "trim", off0=-0.6, off1=-0.55, pad=-0.25, bevel=0.06)
        piston(p, (x, 3.95, 0.72), (x, 2.75, 0.52), r=0.13)  # sleeve behind the knee
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.69, 3.55, -0.32), (0, -1.9, -0.55), (s2, 0, 0), 1.4, 0.14, 0.03, "light")
        drum(p, KNEE, 0.55, 1.35, "steel", "trim")
        # big rounded knee guard
        p.prism_x([(-1.2, 2.1), (-0.85, 1.95), (-0.72, 2.6), (-0.85, 3.25), (-1.25, 3.05), (-1.4, 2.6)],
                  x - 0.68, x + 0.68, "paint", bevel=0.14)
        hazard(p, (x, 3.12, -1.12), X, (0, 0.5, -0.87), 1.1, 0.18, stripes=5)

    def shin(p):
        tseg(p, KNEE, ANKLE, 1.0, 1.0, 0.95, 0.95, "dark", pad=0.08)
        tseg(p, KNEE, ANKLE, 1.65, 0.75, 1.45, 0.65, "team", off0=0.32, off1=0.3, pad=-0.2, bevel=0.14)  # team shin plate
        for s2 in (-1, 1):
            p.obox(tuple((V(KNEE) + V(ANKLE)) / 2 + V((s2 * 0.6, 0.0, 0.08))), tuple(V(ANKLE) - V(KNEE)), (s2, 0, 0),
                   1.5, 1.05, 0.12, "paint", bevel=0.04)
        piston(p, (x, 2.4, 0.42), (x, 1.15, 0.85), r=0.1, sleeve="steel")  # the rod behind the knee
        p.prism_x([(0.35, 1.0), (0.85, 1.05), (0.95, 1.9), (0.55, 2.05)], x - 0.55, x + 0.55, "paint", bevel=0.08)  # calf
        p.box((x, 1.45, 0.98), (0.75, 0.7, 0.04), "power")
        p.obox((x, 2.2, -0.82), X, (0, 0.37, -1), 1.2, 0.12, 0.05, "light")
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.67, 1.55, -0.32), (0, -1.8, 0.7), (s2, 0, 0), 1.2, 0.12, 0.03, "light")

    def foot(p):
        drum(p, ANKLE, 0.44, 1.15, "steel", "trim")
        p.box((x, 0.5, 0.15), (1.05, 0.62, 1.0), "dark", bevel=0.08)
        # wide feet: a toe plate with a ridge, a heel plate, a dark sole
        p.prism_x([(-1.75, 0.0), (-0.1, 0.0), (-0.1, 0.55), (-0.85, 0.66), (-1.6, 0.36)], x - 0.82, x + 0.82, "paint", bevel=0.14)
        p.prism_x([(-1.65, 0.38), (-0.9, 0.66), (-0.4, 0.7), (-0.4, 0.78), (-0.95, 0.76), (-1.7, 0.45)], x - 0.18, x + 0.18, "trim", bevel=0.03)
        p.prism_x([(0.45, 0.0), (1.45, 0.0), (1.45, 0.36), (1.1, 0.58), (0.45, 0.58)], x - 0.68, x + 0.68, "paint", bevel=0.12)
        p.box((x, 0.04, -0.15), (1.5, 0.08, 3.1), "dark")
        p.box((x, 0.24, -1.72), (1.3, 0.16, 0.03), "light")
        for s2 in (-1, 1):
            p.box((x + s2 * 0.83, 0.3, -0.9), (0.03, 0.14, 1.3), "light")
        p.box((x, 0.28, 1.46), (0.8, 0.1, 0.03), "light")

    def det_thigh(p):
        rivets(p, (x + sx * 0.69, 4.15, -0.15), (x + sx * 0.69, 3.0, -0.45), 4, (sx, 0, 0))

    def det_shin(p):
        seam(p, (x - 0.55, 2.0, -0.95), (x + 0.55, 2.0, -0.95), (0, 0.35, -1))

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
         attachments={"muzzle": {"parent": "forearmR", "at": [3.45, 4.65, -5.0]}},
         budget=12000,
         previews=[("35", (-17, 13, -20), (0, 5.0, 0), 50),
                   ("side", (24, 5.5, 0), (0, 5.0, 0), 50),
                   ("80", (0, 34, 4), (0, 5.0, 0), 50),
                   ("close", (-8.0, 9.0, -10.5), (0, 6.5, -0.5), 35)])
