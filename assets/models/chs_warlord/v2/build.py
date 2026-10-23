"""KEPT for reference (2026-10-23): heroic mech v2 (size approved, look too blocky), replaced by ../build.py (v3, M-33).

Warlord (Chaos Commander, footprint 2): the heroic walking battle mech
(M-32). blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_warlord/build.py

The user's review of v1 (2026-10-23): higher, bigger, a heroic mech, not a
box robot; an original design, BAR-level finish. Rugged, hunched and
aggressive (Chaos, M-14): long, deeply bent legs (a forward knee over a
raked shin) with exposed hydraulics and splayed clawed feet; a narrow
armored pelvis under a broad chest leaning forward, covered in reactive
blocks, a glowing core slit (power); a heavy sensor head thrust forward and
up out of the chest with amber eye slits; big slab pauldrons past the body
(team plate on the right one); a reactor hump with a team plate, twin
exhaust stacks with hot rings (power) and a banner mast with the team
banner; long arms: a crane-like claw arm with the build emitter (`nano`,
power) and a heavy gun with a muzzle brake (`forearmR`, `muzzle`, weapon).
About 2.6x a Lancer's height to the shoulders (8.9 studs; stacks and banner
to 11), pauldrons spanning 10.4 studs. Same rig as v1 (rig.md 10). v1 and
the tracked design are kept in v1/ and tracked/. Writes export/ through
tools/unit.py.
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
TILT = math.radians(18)  # the chest leans forward about (y 5.0, z 0.1)


def lean(x, y, z, y0=5.0, z0=0.1):
    dy, dz = y - y0, z - z0
    return (x, y0 + dy * math.cos(TILT) + dz * math.sin(TILT), z0 - dy * math.sin(TILT) + dz * math.cos(TILT))


def ldir(x, y, z):
    return (x, y * math.cos(TILT) + z * math.sin(TILT), -y * math.sin(TILT) + z * math.cos(TILT))


def lbox(p, center, size, kind, bevel=0.05):
    """A box in the leaning chest frame."""
    p.obox(lean(*center), ldir(1, 0, 0), ldir(0, 0, -1), size[0], size[1], size[2], kind, bevel=bevel)


# ---------------------------------------------------------------- pelvis


def build_base(p):
    p.prism_x([(-0.75, 3.95), (0.95, 3.95), (1.05, 4.6), (0.75, 4.95), (-0.55, 4.95), (-0.85, 4.55)], -1.05, 1.05, "dark", bevel=0.06)
    p.box((0, 4.2, -0.78), (1.6, 0.8, 0.28), "era", bevel=0.03)  # groin slab
    for sx in (-1, 1):
        p.obox((sx * 1.15, 4.6, 0.1), (0, 0, 1), (sx, 0.3, 0), 1.5, 0.8, 0.12, "era", bevel=0.03)
    joint(p, (0, 4.3, 0.25), 0.34, 3.6)
    p.cylinder("y", (0, 4.98, 0.1), 0.82, 0.12, 16, "steel")


def details_base(p):
    rivets(p, (-0.6, 4.45, -0.93), (0.6, 4.45, -0.93), 4, FWD)


# ---------------------------------------------------------------- torso


def build_torso(p):
    # waist column with exposed pistons
    p.cylinder("y", (0, 5.25, 0.1), 0.66, 0.6, 12, "steel")
    for sx in (-1, 1):
        piston(p, (sx * 0.7, 5.05, 0.5), lean(sx * 0.95, 6.1, 0.65), r=0.07)
    # belly and chest (leaning): dark frame, slab armor, reactive blocks
    lbox(p, (0, 5.95, -0.1), (2.8, 1.0, 2.0), "dark")
    lbox(p, (0, 7.1, -0.4), (4.6, 1.8, 2.8), "trim", bevel=0.08)
    lbox(p, (0, 7.15, -1.85), (4.0, 1.5, 0.25), "dark", bevel=0.03)
    for i, x in enumerate((-1.3, 0.0, 1.3)):
        for y in (6.75, 7.5):
            lbox(p, (x, y, -2.05), (1.1, 0.62, 0.32), "era", bevel=0.03)
    lbox(p, (0, 6.25, -1.95), (2.1, 0.22, 0.06), "power", bevel=0.0)  # core slit
    for sx in (-1, 1):
        lbox(p, (sx * 2.12, 6.9, -1.4), (0.1, 1.5, 0.06), "light", bevel=0.0)
    # reactor hump with a team plate, twin stacks with hot rings, a vent
    p.prism_x([(0.2, 7.0), (2.25, 7.0), (2.3, 8.2), (1.9, 8.8), (0.5, 8.85), (0.2, 8.4)], -1.8, 1.8, "dark", bevel=0.07)
    p.box((0, 8.86, 1.25), (2.1, 0.04, 1.2), "team", bevel=0.01)
    p.box((0, 7.65, 2.27), (2.8, 1.0, 0.04), "power")
    for sx in (-1, 1):
        p.box((sx * 1.81, 7.9, 1.2), (0.04, 0.5, 1.6), "power")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 1.0, 9.6, 1.9), 0.3, 2.2, 10, "steel")
        p.cylinder("y", (sx * 1.0, 9.0, 1.9), 0.36, 0.25, 10, "dark")
        p.cylinder("y", (sx * 1.0, 10.72, 1.9), 0.33, 0.12, 10, "power")
        p.cylinder("y", (sx * 1.0, 10.1, 1.9), 0.34, 0.08, 10, "power")
        cable(p, [(sx * 1.6, 8.5, 1.3), (sx * 2.5, 8.6, 0.8), (sx * 3.0, 8.3, 0.2)])
    # banner mast with the team banner, a beacon
    p.cylinder("y", (1.95, 9.6, 2.05), 0.08, 3.7, 6, "steel")
    p.box((1.95, 10.55, 2.75), (0.04, 1.8, 1.3), "team")
    p.box((1.95, 11.47, 2.75), (0.06, 0.08, 1.35), "dark")
    p.box((1.95, 11.5, 2.05), (0.16, 0.14, 0.16), "light")
    # slab pauldrons past the body, reactive blocks on the fronts, a team plate on the right
    for sx in (-1, 1):
        c = (sx * 3.95, 8.0, -0.2)
        p.obox(c, (math.cos(math.radians(8)) * sx, -math.sin(math.radians(8)), 0), (0, math.cos(math.radians(10)), -math.sin(math.radians(10))),
               2.5, 3.2, 1.6, "dark", bevel=0.09)
        p.obox((sx * 3.95, 7.75, -1.87), X, (0, 0.17, -1), 2.1, 0.7, 0.4, "era", bevel=0.03)
        p.obox((sx * 5.1, 7.7, -0.2), (0, 0, 1), (sx, 0, 0), 2.6, 0.3, 0.04, "light")
        p.cylinder("x", (sx * 2.95, 7.2, -0.3), 0.66, 0.5, 12, "dark")
    p.obox((3.95, 8.82, -0.33), (math.cos(math.radians(8)), -math.sin(math.radians(8)), 0), (0.0, math.cos(math.radians(10)), -math.sin(math.radians(10))),
           1.8, 2.2, 0.04, "team")


def details_torso(p):
    for sx in (-1, 1):
        rivets(p, lean(sx * 1.8, 7.95, -1.95), lean(sx * 0.6, 7.95, -1.95), 3, ldir(0, 0, -1))
    rivets(p, (-1.5, 7.2, 2.26), (1.5, 7.2, 2.26), 6, (0, 0, 1))
    seam(p, (-1.7, 8.5, 0.4), (1.7, 8.5, 0.4), UP)


# ---------------------------------------------------------------- head


def build_head(p):
    p.ocyl((0, 7.8, -1.2), (0, 0.6, -1), 0.4, 0.6, 10, "steel")
    p.prism_y([(-0.62, -2.55), (0.62, -2.55), (0.72, -2.1), (0.62, -1.25), (-0.62, -1.25), (-0.72, -2.1)],
              7.8, 8.72, "dark", bevel=0.06, top_scale=0.82)
    p.box((0, 7.72, -2.3), (1.05, 0.38, 0.5), "trim", bevel=0.04)  # jaw
    p.box((0, 7.7, -2.56), (0.7, 0.16, 0.04), "grille")
    for sx in (-1, 1):
        p.obox((sx * 0.32, 8.35, -2.57), (sx * 1, 0.12, 0.0), FWD, 0.5, 0.16, 0.04, "light")  # eye slits
        p.obox((sx * 0.72, 8.25, -1.9), (0, 0, 1), (sx, 0, 0), 0.8, 0.5, 0.12, "era", bevel=0.02)
    p.box((0, 8.74, -1.9), (0.8, 0.06, 0.9), "trim")
    p.cylinder("y", (0.4, 9.1, -1.6), 0.04, 0.7, 6, "dark")


def details_head(p):
    seam(p, (-0.55, 8.5, -2.54), (0.55, 8.5, -2.54), FWD)


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 3.5
    joint(p, (sx * 3.4, 7.2, -0.3), 0.62, 1.0)
    seg(p, (x, 6.9, -0.3), (x, 5.15, 0.0), 0.85, 0.9, "dark", pad=0.1)
    p.obox((x + sx * 0.42, 6.05, -0.15), (0, -1.75, 0.3), X, 1.6, 1.0, 0.16, "era", bevel=0.03)
    piston(p, (x, 6.7, 0.35), (x, 5.3, 0.45), r=0.1)
    joint(p, (x, 5.05, 0.0), 0.46, 1.0)


def build_armL(p):
    upper_arm(p, -1)


def build_armR(p):
    upper_arm(p, 1)


def details_arm(sx):
    def d(p):
        rivets(p, (sx * 3.93, 5.6, -0.3), (sx * 3.93, 6.5, -0.35), 3, (sx, 0, 0))
    return d


NANO_A, NANO_B = (-3.5, 5.0, 0.0), (-3.5, 3.4, -1.8)


def build_nano(p):
    x = -3.5
    # crane boom: a box beam with a top rail, a hydraulic ram, claw fingers, the emitter
    seg(p, NANO_A, NANO_B, 0.6, 0.6, "dark", pad=0.1)
    seg(p, NANO_A, NANO_B, 0.68, 0.12, "steel", offset=-0.36)
    seg(p, NANO_A, NANO_B, 0.12, 0.7, "trim")
    plate_on(p, NANO_A, NANO_B, 0.2, 0.55, 0.4, "team", 0.33)
    piston(p, (x, 5.25, 0.35), (x, 3.85, -1.2), r=0.1)
    for sx in (-1, 1):  # claw fingers round the emitter
        p.obox((x + sx * 0.32, 3.2, -2.15), (0, -0.5, -1), (sx * 0.95, 0, -0.3), 0.85, 0.7, 0.14, "steel", bevel=0.02)
        p.obox((x + sx * 0.22, 3.05, -2.62), (-sx * 0.5, -0.4, -1), (sx, 0, 0), 0.45, 0.6, 0.12, "trim", bevel=0.02)
    p.ocyl((x, 3.3, -1.9), (0, -0.2, -1), 0.3, 0.3, 10, "dark")
    p.ocyl((x, 3.24, -2.2), (0, -0.2, -1), 0.24, 0.12, 10, "power")  # emitter
    p.box((x - 0.33, 4.3, -0.85), (0.02, 0.12, 1.0), "light")


def details_nano(p):
    rivets(p, (-3.81, 4.8, -0.2), (-3.81, 3.6, -1.55), 5, (-1, 0, 0))


def build_forearmR(p):
    x = 3.6
    # a heavy gun block over a dark frame, reactive plates, a drum magazine
    p.prism_x([(-0.25, 3.7), (0.55, 3.7), (0.6, 5.0), (0.1, 5.3), (-2.4, 5.2), (-2.55, 4.6), (-2.4, 3.7)],
              x - 0.7, x + 0.7, "dark", bevel=0.08)
    for sx in (-1, 1):
        p.obox((x + sx * 0.74, 4.5, -1.0), (0, 0, 1), (sx, 0, 0), 2.2, 1.0, 0.14, "era", bevel=0.03)
    p.cylinder("x", (x - 0.85, 4.3, -0.2), 0.48, 0.32, 12, "steel")
    p.cylinder("x", (x - 1.04, 4.3, -0.2), 0.3, 0.06, 10, "dark")
    # barrel, a muzzle brake, a ready light
    p.cylinder("z", (x, 4.35, -3.0), 0.36, 1.2, 12, "steel")
    p.cylinder("z", (x, 4.35, -3.55), 0.46, 0.45, 12, "dark")
    for sx in (-1, 1):
        p.box((x + sx * 0.47, 4.35, -3.55), (0.04, 0.28, 0.3), "grille")
    p.cylinder("z", (x, 4.35, -3.8), 0.3, 0.05, 12, "weapon")
    p.box((x, 5.28, -1.9), (0.4, 0.06, 0.6), "weapon")
    for sx in (-1, 1):
        p.box((x + sx * 0.82, 4.95, -1.0), (0.03, 0.2, 1.8), "light")


def details_forearmR(p):
    rivets(p, (4.36, 4.0, -2.0), (4.36, 4.0, 0.0), 5, X)


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    x = sx * 1.7
    HIP, KNEE, ANKLE = (x, 4.2, 0.3), (x, 2.5, -0.85), (x, 0.75, 0.45)

    def hip(p):
        joint(p, (sx * 1.65, 4.3, 0.25), 0.55, 0.65)
        p.obox((sx * 2.05, 4.3, 0.2), UP, X, 1.1, 1.3, 0.14, "era", bevel=0.03)

    def thigh(p):
        seg(p, HIP, KNEE, 1.0, 1.0, "dark", pad=0.15)
        seg(p, HIP, KNEE, 1.4, 0.45, "trim", offset=0.36, pad=-0.2)
        for s2 in (-1, 1):  # exposed pistons down both sides
            piston(p, (x + s2 * 0.75, 4.0, 0.15), (x + s2 * 0.75, 2.75, -0.55), r=0.1)
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.72, 3.4, -0.45), (0, -1.7, -1.15), (s2, 0, 0), 1.4, 0.14, 0.03, "light")
        joint(p, KNEE, 0.5, 1.15)
        p.obox((x, 2.45, -1.45), X, (0, 0.5, -0.87), 1.2, 0.85, 0.38, "era", bevel=0.03)  # knee plate

    def shin(p):
        seg(p, KNEE, ANKLE, 1.0, 1.0, "dark", pad=0.1)
        seg(p, KNEE, ANKLE, 1.3, 0.5, "trim", offset=0.32, pad=-0.25)
        plate_on(p, KNEE, ANKLE, 0.3, 0.65, 0.7, "era", 0.6, thickness=0.18)
        piston(p, (x, 2.2, 0.0), (x, 1.0, 0.85), r=0.11)
        p.box((x, 1.3, 0.75), (0.7, 0.5, 0.04), "power")
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.67, 1.6, -0.2), (0, -1.75, 1.3), (s2, 0, 0), 1.3, 0.12, 0.03, "light")

    def foot(p):
        joint(p, ANKLE, 0.38, 1.05)
        p.box((x, 0.45, 0.45), (0.95, 0.6, 1.0), "dark", bevel=0.05)
        for dx in (-0.48, 0.0, 0.48):  # splayed clawed toes
            p.obox((x + dx * 1.15, 0.2, -0.55), (dx * 0.7, -0.15, -1), UP, 1.25, 0.42, 0.36, "steel", bevel=0.04)
            p.obox((x + dx * 1.4, 0.12, -1.25), (dx * 0.7, -0.4, -1), UP, 0.4, 0.3, 0.2, "trim", bevel=0.02)
        p.obox((x, 0.2, 1.35), (0, -0.1, 1), UP, 1.0, 0.55, 0.36, "steel", bevel=0.04)  # spur
        p.box((x, 0.6, -0.08), (0.7, 0.1, 0.03), "light")

    def det_thigh(p):
        rivets(p, (x - 0.5, 3.9, -0.2), (x + 0.5, 3.9, -0.2), 4, ldir(0, 0, -1))

    none = lambda p: None  # noqa: E731
    return [
        unit.PieceSpec(f"hip{n}", "base", (sx * 1.5, 4.3, 0.25), hip, none),
        unit.PieceSpec(f"thigh{n}", f"hip{n}", HIP, thigh, det_thigh),
        unit.PieceSpec(f"shin{n}", f"thigh{n}", KNEE, shin, none),
        unit.PieceSpec(f"foot{n}", f"shin{n}", (x, 0.7, 0.45), foot, none),
    ]


unit.run(__file__, "chs_warlord", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", (0.0, 5.0, 0.1), build_torso, details_torso),
                 unit.PieceSpec("head", "torso", (0.0, 7.9, -1.3), build_head, details_head),
                 unit.PieceSpec("armL", "torso", (-3.4, 7.2, -0.3), build_armL, details_arm(-1)),
                 unit.PieceSpec("nano", "armL", NANO_A, build_nano, details_nano),
                 unit.PieceSpec("armR", "torso", (3.4, 7.2, -0.3), build_armR, details_arm(1)),
                 unit.PieceSpec("forearmR", "armR", (3.5, 5.1, 0.0), build_forearmR, details_forearmR)]
         + leg_specs(-1) + leg_specs(1),
         attachments={"muzzle": {"parent": "forearmR", "at": [3.6, 4.35, -3.85]}},
         budget=9000,
         previews=[("35", (-17, 13, -20), (0, 5.0, 0), 50),
                   ("side", (24, 5.5, 0), (0, 5.0, 0), 50),
                   ("80", (0, 34, 4), (0, 5.0, 0), 50),
                   ("close", (-8.0, 9.0, -10.5), (0, 6.5, -0.8), 35)])
