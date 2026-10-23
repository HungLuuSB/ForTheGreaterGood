"""KEPT for reference (2026-10-23): mech v1 (too small and blocky in the review), replaced by ../build.py (M-32).

Sovereign (Order Commander, footprint 1): the walking battle mech (M-31).
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sovereign/build.py

The user (2026-10-23): a tall, upright, heavily armored mech, BAR-commander
silhouette but an original design, clearly the most imposing ground unit
(about 1.5x a Lancer's height). Clean sloped plates; a broad chest and big
shoulder armor with team plates; a sensor head under an armored brow; a big
cyan command core in the chest (power); the left forearm is the build
emitter (`nano`, power), the right forearm a weapon pod (`muzzle`, weapon).
Rigged as a walker on the blockout's pivots (rig.md 10): base (pelvis),
torso, head, armL / nano, armR / forearmR, and per leg hip, thigh, shin and
foot. The tracked design is kept in tracked/. Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

FWD = (0, 0, -1)
X = (1, 0, 0)


def plate(p, center, n, w, h, kind="team", t=0.04):
    """A thin plate facing n, w wide along X (or Z when n is along X)."""
    u = X if abs(n[0]) < 0.9 else (0, 0, 1)
    p.obox(center, u, n, w, h, t, kind, bevel=0.01)


# ---------------------------------------------------------------- pelvis


def build_base(p):
    # pelvis block, armored front and rear, the hip axle through it
    p.prism_x([(-0.7, 2.2), (0.7, 2.2), (0.8, 2.85), (0.55, 3.1), (-0.55, 3.1), (-0.8, 2.85)], -1.05, 1.05, "trim", bevel=0.05)
    p.prism_x([(-1.0, 2.3), (-0.72, 2.12), (-0.72, 3.0), (-0.92, 2.95)], -0.75, 0.75, "paint", bevel=0.04)  # cod plate
    p.prism_x([(0.72, 2.25), (0.95, 2.4), (0.92, 2.95), (0.72, 3.0)], -0.85, 0.85, "paint", bevel=0.04)  # rear plate
    p.cylinder("x", (0, 2.6, 0), 0.32, 2.3, 12, "steel")
    p.cylinder("y", (0, 3.05, 0), 0.65, 0.12, 16, "dark")  # waist bearing
    p.box((0, 2.75, -1.0), (0.9, 0.08, 0.04), "light")


def details_base(p):
    seam(p, (-0.6, 2.62, -0.99), (0.6, 2.62, -0.99), FWD)
    bolts(p, (-0.55, 2.35, -0.95), (0.55, 2.35, -0.95), 4, FWD)


# ---------------------------------------------------------------- torso

TORSO = [(-1.2, -0.85), (1.2, -0.85), (1.32, -0.3), (1.25, 0.95), (-1.25, 0.95), (-1.32, -0.3)]


def build_torso(p):
    p.cylinder("y", (0, 3.3, 0), 0.55, 0.5, 14, "trim")  # waist column
    p.cylinder("y", (0, 3.3, 0), 0.6, 0.1, 14, "dark")
    p.prism_y(TORSO, 3.5, 4.9, "paint", bevel=0.06, top_scale=0.92)
    # the sloped chest plate wrapping the front, the command core in it
    p.prism_x([(-0.85, 3.5), (-1.12, 3.62), (-1.38, 4.1), (-1.22, 4.78), (-0.85, 4.9)], -1.15, 1.15, "paint", bevel=0.05)
    p.cylinder("z", (0, 4.05, -1.38), 0.55, 0.1, 18, "trim")
    p.cylinder("z", (0, 4.05, -1.43), 0.46, 0.06, 18, "dark")
    p.cylinder("z", (0, 4.05, -1.46), 0.36, 0.05, 18, "power")  # command core
    for sx in (-1, 1):
        plate(p, (sx * 0.85, 4.12, -1.37), FWD, 0.42, 0.62)  # chest team plates
        p.obox((sx * 0.55, 3.62, -1.14), X, (0, 0.35, -1), 0.4, 0.12, 0.04, "light")  # abdominal strips
    # armored collar round the neck
    p.prism_x([(-0.9, 4.85), (-0.62, 5.05), (0.25, 5.05), (0.3, 4.85)], -0.9, 0.9, "paint", bevel=0.04)
    # shoulder armor: big sloped pauldrons, a team plate on each, side strips
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 1.3, sx * 2.7))
        p.prism_x([(-1.0, 3.95), (0.95, 3.95), (1.02, 4.62), (0.72, 5.02), (-0.72, 5.02), (-1.02, 4.62)], x0, x1, "paint", bevel=0.06)
        p.box((sx * 2.0, 5.04, 0.0), (1.0, 0.04, 1.25), "team", bevel=0.01)
        p.box((sx * 2.71, 4.35, 0.0), (0.04, 0.1, 1.45), "light")
        p.box((sx * 2.0, 4.0, -1.0), (1.2, 0.12, 0.06), "trim")
    # backpack: reactor housing, grilles, a power vent, the antenna mast
    p.box((0, 4.05, 1.3), (2.0, 1.3, 0.7), "trim", bevel=0.06)
    p.box((0, 4.35, 1.66), (1.4, 0.5, 0.04), "grille")
    p.box((0, 3.75, 1.66), (1.2, 0.08, 0.04), "power")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 0.72, 4.9, 1.35), 0.2, 0.3, 10, "dark")
    p.cylinder("y", (0.72, 5.5, 1.35), 0.05, 1.0, 6, "dark")
    p.box((0.72, 6.02, 1.35), (0.12, 0.1, 0.12), "light")


def details_torso(p):
    ring(p, (0, 4.05, -1.44), FWD, 0.5)
    seam(p, (-1.2, 4.5, -1.15), (1.2, 4.5, -1.15), (0, 0.4, -1))
    for sx in (-1, 1):
        bolts(p, (sx * 1.5, 5.03, -0.6), (sx * 2.5, 5.03, -0.6), 4, UP)
        bolts(p, (sx * 1.5, 5.03, 0.6), (sx * 2.5, 5.03, 0.6), 4, UP)
        seam(p, (sx * 2.7, 4.0, -0.5), (sx * 2.7, 4.6, -0.5), (sx, 0, 0))
    bolts(p, (-0.8, 4.75, 1.66), (0.8, 4.75, 1.66), 5, (0, 0, 1))


# ---------------------------------------------------------------- head


def build_head(p):
    p.cylinder("y", (0, 4.95, -0.1), 0.38, 0.2, 12, "dark")  # neck
    p.prism_y([(-0.42, -0.6), (0.42, -0.6), (0.5, -0.22), (0.46, 0.35), (-0.46, 0.35), (-0.5, -0.22)],
              5.0, 5.45, "paint", bevel=0.04, top_scale=0.86)
    p.prism_x([(-0.78, 5.3), (-0.66, 5.52), (0.05, 5.58), (0.05, 5.4)], -0.6, 0.6, "trim", bevel=0.03)  # brow
    p.box((0, 5.17, -0.61), (0.72, 0.12, 0.04), "light")  # visor
    for sx in (-1, 1):
        p.cylinder("x", (sx * 0.5, 5.17, -0.1), 0.13, 0.1, 10, "dark")
        p.box((sx * 0.56, 5.17, -0.1), (0.02, 0.06, 0.12), "light")
    p.cylinder("y", (0.32, 5.85, 0.15), 0.04, 0.7, 6, "dark")
    p.cylinder("y", (-0.25, 5.7, 0.2), 0.035, 0.45, 6, "dark")


def details_head(p):
    seam(p, (-0.45, 5.3, -0.58), (0.45, 5.3, -0.58), FWD)


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 2.05
    p.cylinder("x", (x, 4.3, 0), 0.42, 0.62, 14, "steel")  # shoulder joint
    p.prism_x([(-0.4, 3.35), (0.4, 3.35), (0.45, 4.05), (-0.45, 4.05)], x - 0.33, x + 0.33, "trim", bevel=0.04)
    p.box((x + sx * 0.36, 3.75, 0), (0.08, 0.62, 0.72), "paint", bevel=0.02)
    p.cylinder("x", (x, 3.12, 0), 0.32, 0.78, 12, "steel")  # elbow


def build_armL(p):
    upper_arm(p, -1)


def build_armR(p):
    upper_arm(p, 1)


def details_arm(sx):
    def d(p):
        bolts(p, (sx * 2.42, 3.5, -0.3), (sx * 2.42, 4.0, -0.3), 3, (sx, 0, 0))
    return d


def build_nano(p):
    x = -2.05
    p.prism_x([(-1.25, 2.55), (0.35, 2.5), (0.38, 3.25), (-1.2, 3.28)], x - 0.42, x + 0.42, "paint", bevel=0.06)
    p.box((x, 3.32, -0.45), (0.42, 0.04, 1.0), "team", bevel=0.01)
    # emitter: a ringed barrel, a glowing lens and three focusing fins
    p.cylinder("z", (x, 2.9, -1.38), 0.33, 0.35, 14, "trim")
    p.cylinder("z", (x, 2.9, -1.58), 0.37, 0.06, 14, "power")
    p.cylinder("z", (x, 2.9, -1.62), 0.22, 0.04, 12, "power")
    for a in (90, 210, 330):
        r = math.radians(a)
        p.obox((x + math.cos(r) * 0.4, 2.9 + math.sin(r) * 0.4, -1.45), (0, 0, 1), (math.cos(r), math.sin(r), 0),
               0.5, 0.06, 0.18, "dark")
    p.box((x - 0.43, 2.9, -0.5), (0.02, 0.08, 0.9), "light")


def details_nano(p):
    seam(p, (-2.47, 2.6, -1.0), (-2.47, 3.2, -1.0), (-1, 0, 0))
    bolts(p, (-2.47, 2.65, -0.2), (-2.47, 3.15, -0.2), 3, (-1, 0, 0))


def build_forearmR(p):
    x = 2.1
    p.prism_x([(-1.45, 2.4), (0.4, 2.35), (0.45, 3.32), (-1.35, 3.35)], x - 0.5, x + 0.5, "paint", bevel=0.06)
    p.box((x + 0.51, 2.9, -0.5), (0.04, 0.55, 1.2), "team", bevel=0.01)
    p.box((x - 0.51, 3.0, -0.5), (0.04, 0.4, 0.9), "grille")
    # twin barrels in a shroud, ready lights
    p.box((x, 2.78, -1.55), (0.7, 0.55, 0.35), "trim", bevel=0.04)
    for dx in (-0.16, 0.16):
        p.cylinder("z", (x + dx, 2.78, -1.95), 0.12, 0.6, 10, "dark")
        p.cylinder("z", (x + dx, 2.78, -2.27), 0.13, 0.05, 10, "weapon")
    p.box((x, 3.12, -1.47), (0.4, 0.06, 0.04), "weapon")


def details_forearmR(p):
    seam(p, (2.61, 2.55, -1.0), (2.61, 3.25, -1.0), X)
    bolts(p, (1.62, 2.55, 0.1), (1.62, 3.2, 0.1), 3, (-1, 0, 0))


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    x = sx * 1.3

    def hip(p):
        p.cylinder("x", (x, 2.6, 0), 0.36, 0.6, 12, "steel")
        p.prism_x([(-0.55, 2.25), (0.5, 2.25), (0.5, 2.92), (-0.4, 3.02)], *sorted((sx * 1.62, sx * 1.74)), "paint", bevel=0.02)

    def thigh(p):
        p.prism_x([(-0.48, 1.35), (0.42, 1.35), (0.52, 2.22), (-0.42, 2.45)], x - 0.4, x + 0.4, "paint", bevel=0.05)
        p.prism_x([(-0.66, 1.0), (-0.42, 1.02), (-0.36, 1.62), (-0.6, 1.48)], x - 0.36, x + 0.36, "trim", bevel=0.03)  # knee armor
        p.cylinder("x", (x, 1.25, 0), 0.3, 0.9, 12, "steel")
        p.obox((x, 1.78, 0.5), (0, 0.95, -0.1), X, 0.75, 0.16, 0.16, "steel")  # hydraulic piston
        p.box((x + sx * 0.41, 1.95, -0.1), (0.03, 0.42, 0.06), "light")

    def shin(p):
        p.prism_x([(-0.5, 0.42), (0.45, 0.42), (0.5, 1.12), (-0.45, 1.28)], x - 0.38, x + 0.38, "paint", bevel=0.05)
        p.obox((x, 0.88, -0.5), X, (0, 0.2, -1), 0.42, 0.52, 0.04, "team")
        p.box((x, 0.72, 0.5), (0.5, 0.4, 0.06), "grille")

    def foot(p):
        p.prism_x([(-1.1, 0.0), (0.7, 0.0), (0.76, 0.24), (0.4, 0.42), (-0.6, 0.42), (-1.05, 0.2)], x - 0.52, x + 0.52, "trim", bevel=0.04)
        p.prism_x([(-1.18, 0.0), (-0.85, 0.0), (-0.75, 0.3), (-1.1, 0.22)], x - 0.46, x + 0.46, "paint", bevel=0.03)  # toe cap
        p.cylinder("x", (x, 0.38, 0), 0.24, 0.7, 10, "steel")
        p.box((x, 0.12, -1.13), (0.6, 0.06, 0.03), "light")

    def det_thigh(p):
        seam(p, (x - 0.41, 1.5, -0.3), (x - 0.41, 2.2, -0.35), (-1, 0, 0))
        seam(p, (x + 0.41, 1.5, -0.3), (x + 0.41, 2.2, -0.35), X)

    def det_shin(p):
        bolts(p, (x - 0.2, 1.1, -0.48), (x + 0.2, 1.1, -0.48), 3, (0, 0.2, -1))

    none = lambda p: None  # noqa: E731
    return [
        unit.PieceSpec(f"hip{n}", "base", (sx * 1.2, 2.6, 0.0), hip, none),
        unit.PieceSpec(f"thigh{n}", f"hip{n}", (x, 2.4, 0.0), thigh, det_thigh),
        unit.PieceSpec(f"shin{n}", f"thigh{n}", (x, 1.25, 0.0), shin, det_shin),
        unit.PieceSpec(f"foot{n}", f"shin{n}", (x, 0.35, 0.0), foot, none),
    ]


unit.run(__file__, "ord_sovereign", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", (0.0, 3.1, 0.0), build_torso, details_torso),
                 unit.PieceSpec("head", "torso", (0.0, 4.8, -0.1), build_head, details_head),
                 unit.PieceSpec("armL", "torso", (-2.05, 4.3, 0.0), build_armL, details_arm(-1)),
                 unit.PieceSpec("nano", "armL", (-2.05, 3.1, 0.0), build_nano, details_nano),
                 unit.PieceSpec("armR", "torso", (2.05, 4.3, 0.0), build_armR, details_arm(1)),
                 unit.PieceSpec("forearmR", "armR", (2.05, 3.1, 0.0), build_forearmR, details_forearmR)]
         + leg_specs(-1) + leg_specs(1),
         attachments={"muzzle": {"parent": "forearmR", "at": [2.1, 2.78, -2.32]}},
         budget=6000,
         previews=[("35", (-11, 9, -13), (0, 2.9, 0), 50),
                   ("side", (14, 3.5, 0), (0, 2.9, 0), 50),
                   ("80", (0, 22, 3), (0, 2.8, 0), 50),
                   ("close", (-5.0, 5.0, -6.5), (0, 3.6, -0.5), 35)])
