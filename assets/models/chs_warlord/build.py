"""Warlord (Chaos Commander, footprint 2): the heroic walking mech, v3
(M-33). blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_warlord/build.py

The user's review of v2 (2026-10-23): the size is right; the look is too
blocky. v3 keeps v2's rig and pivots and rebuilds the shapes:
- balanced mass: thick armored legs (raked thigh slabs, big knee plates,
  shin armor, wide splayed clawed feet with a heel spur) and thick arms;
  a sturdy, aggressive, hunched stance;
- shapes, not boxes: round shoulder housings and joint drums, tapered and
  angled slabs with readable bevels, reactive blocks over a dark
  under-frame, exposed pistons behind the knees and elbows;
- a low, forward-thrust helmet with amber eye slits, set down between the
  shoulders;
- team color in large areas: the arched pauldron shells, the chest slabs
  behind the reactive blocks, the shin plates, the reactor hump and the
  banner; gunmetal faction paint on the frame and secondary plates;
- hazard striping on the joints, vents, cables, lights, exhaust stacks with
  hot rings, a long heavy gun with a muzzle brake (`muzzle`) and a clear
  claw crane arm with the build emitter (`nano`).
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
TILT = math.radians(18)  # the chest leans forward about (y 5.0, z 0.1)


def lean(x, y, z, y0=5.0, z0=0.1):
    dy, dz = y - y0, z - z0
    return (x, y0 + dy * math.cos(TILT) + dz * math.sin(TILT), z0 - dy * math.sin(TILT) + dz * math.cos(TILT))


def ldir(x, y, z):
    return (x, y * math.cos(TILT) + z * math.sin(TILT), -y * math.sin(TILT) + z * math.cos(TILT))


def lbox(p, center, size, kind, bevel=0.06):
    p.obox(lean(*center), ldir(1, 0, 0), ldir(0, 0, -1), size[0], size[1], size[2], kind, bevel=bevel)


def lprism(p, profile_zy, x0, x1, kind, bevel=0.1):
    """A side profile (z, y) in the leaning chest frame, extruded along X."""
    pts = [lean(0, y, z) for z, y in profile_zy]
    p.prism_x([(q[2], q[1]) for q in pts], x0, x1, kind, bevel)


# ---------------------------------------------------------------- pelvis


def build_base(p):
    p.prism_x([(-0.8, 3.95), (0.95, 3.95), (1.08, 4.6), (0.78, 4.95), (-0.6, 4.95), (-0.92, 4.55)], -1.1, 1.1, "dark", bevel=0.1)
    p.prism_x([(-1.1, 4.0), (-0.8, 3.85), (-0.72, 3.85), (-0.72, 4.75), (-1.0, 4.6)], -0.85, 0.85, "era", bevel=0.1)  # groin slab
    hazard(p, (0, 4.85, -0.95), X, (0, 0.3, -1), 1.3, 0.2, stripes=6)
    for sx in (-1, 1):
        p.obox((sx * 1.2, 4.6, 0.1), (0, 0, 1), (sx, 0.3, 0), 1.6, 0.9, 0.14, "era", bevel=0.05)
    drum(p, (0, 4.3, 0.25), 0.42, 3.4, "steel", "trim")
    p.cylinder("y", (0, 4.98, 0.1), 0.85, 0.12, 20, "steel")


def details_base(p):
    rivets(p, (-0.6, 4.35, -0.98), (0.6, 4.35, -0.98), 4, FWD)


# ---------------------------------------------------------------- torso


def build_torso(p):
    # waist with exposed pistons
    p.cylinder("y", (0, 5.25, 0.1), 0.7, 0.62, 16, "steel")
    for sx in (-1, 1):
        piston(p, (sx * 0.72, 5.05, 0.55), lean(sx * 1.0, 6.1, 0.7), r=0.08)
    # belly and chest (leaning): a dark frame, a broad tapered trim chest,
    # team slabs behind rows of reactive blocks
    lbox(p, (0, 5.95, -0.1), (2.9, 1.0, 2.0), "dark")
    lprism(p, [(-1.6, 6.3), (-1.85, 7.1), (-1.6, 8.0), (1.3, 8.1), (1.5, 6.3)], -2.35, 2.35, "trim", bevel=0.18)
    lprism(p, [(-1.82, 6.45), (-2.02, 7.1), (-1.8, 7.85), (-1.6, 7.85), (-1.6, 6.45)], -2.05, 2.05, "team", bevel=0.08)
    for x in (-1.35, 0.0, 1.35):
        for y in (6.75, 7.5):
            lbox(p, (x, y, -2.1), (1.12, 0.6, 0.3), "era", bevel=0.05)
    lbox(p, (0, 6.25, -2.0), (2.5, 0.32, 0.06), "power", bevel=0.0)  # core slit
    for sx in (-1, 1):
        lbox(p, (sx * 2.38, 6.95, -1.3), (0.14, 1.7, 0.06), "light", bevel=0.0)
    # reactor hump: team sides and top, a hot vent, twin stacks with hot rings
    p.prism_x([(0.15, 7.0), (2.25, 7.0), (2.35, 8.2), (1.95, 8.85), (0.45, 8.9), (0.15, 8.45)], -1.85, 1.85, "dark", bevel=0.16)
    p.box((0, 8.9, 1.25), (2.6, 0.05, 1.3), "team", bevel=0.01)
    for sx in (-1, 1):
        p.obox((sx * 1.87, 7.9, 1.25), (0, 0, 1), (sx, 0, 0), 1.6, 1.4, 0.08, "team", bevel=0.03)
    p.box((0, 7.65, 2.3), (2.8, 1.2, 0.04), "power")
    for sx in (-1, 1):
        p.box((sx * 1.9, 7.2, 1.25), (0.04, 0.18, 1.5), "light")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 1.0, 9.65, 1.9), 0.32, 2.2, 14, "steel")
        p.cylinder("y", (sx * 1.0, 9.0, 1.9), 0.4, 0.28, 14, "dark")
        p.cylinder("y", (sx * 1.0, 10.76, 1.9), 0.35, 0.12, 14, "power")
        p.cylinder("y", (sx * 1.0, 10.15, 1.9), 0.36, 0.08, 14, "power")
        hazard(p, (sx * 1.0, 9.35, 1.56), X, FWD, 0.55, 0.22, stripes=3)
        cable(p, [(sx * 1.6, 8.5, 1.3), (sx * 2.5, 8.6, 0.8), (sx * 3.0, 8.3, 0.2)])
    # banner mast with the team banner, a beacon
    p.cylinder("y", (1.95, 9.6, 2.05), 0.08, 3.7, 6, "steel")
    p.box((1.95, 10.55, 2.75), (0.04, 1.8, 1.3), "team")
    p.box((1.95, 11.47, 2.75), (0.06, 0.08, 1.35), "dark")
    p.box((1.95, 11.5, 2.05), (0.16, 0.14, 0.16), "light")
    # round shoulder housings
    for sx in (-1, 1):
        drum(p, (sx * 2.95, 7.2, -0.3), 0.85, 0.85, "dark", "trim", sides=20)
    # pauldrons: arched team shells (tipped forward and down at the outer
    # edge), a gunmetal rim, reactive blocks and hazard striping on the front,
    # side light strips
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 2.55, sx * 5.15))
        p.prism_x(arch(-2.0, 1.6, 7.15, 8.95, steps=9, flat=0.25), x0, x1, "team", bevel=0.15)
        xr0, xr1 = sorted((sx * 5.1, sx * 5.28))
        p.prism_x(arch(-1.85, 1.45, 7.05, 8.7, steps=9, flat=0.25), xr0, xr1, "paint", bevel=0.04)
        xu0, xu1 = sorted((sx * 2.8, sx * 4.9))
        p.prism_x(arch(-1.7, 1.3, 6.65, 7.3, steps=5, flat=0.5), xu0, xu1, "trim", bevel=0.06)
        for k in range(3):
            p.obox((sx * (3.15 + k * 0.7), 7.45, -2.08), X, (0, 0.2, -1), 0.62, 0.55, 0.3, "era", bevel=0.04)
        hazard(p, (sx * 3.85, 7.08, -1.98), X, FWD, 2.2, 0.2, stripes=7)
        p.box((sx * 5.29, 7.7, -0.2), (0.04, 0.4, 2.6), "light")
        p.box((sx * 3.85, 6.85, -1.75), (1.9, 0.12, 0.04), "power")


def details_torso(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.9, 8.94, -1.1), (sx * 4.8, 8.94, -1.1), 6, UP)
        seam(p, (sx * 2.7, 8.95, 0.3), (sx * 5.0, 8.95, 0.3), UP)
    rivets(p, (-1.5, 7.2, 2.29), (1.5, 7.2, 2.29), 6, (0, 0, 1))


# ---------------------------------------------------------------- head


def build_head(p):
    # a low, forward-thrust helmet between the shoulders, amber eye slits
    p.ocyl((0, 7.75, -1.2), (0, 0.4, -1), 0.4, 0.7, 10, "steel")
    p.prism_y([(-0.55, -1.35), (0.55, -1.35), (0.62, -1.95), (0.38, -2.5), (-0.38, -2.5), (-0.62, -1.95)],
              7.7, 8.4, "dark", bevel=0.1, top_scale=0.78, top_center=(0, -1.9))
    p.prism_x([(-2.55, 8.2), (-2.25, 8.45), (-1.4, 8.5), (-1.3, 8.35)], -0.42, 0.42, "trim", bevel=0.05)  # brow ridge
    p.prism_x([(-2.6, 7.55), (-2.25, 7.5), (-2.0, 7.8), (-2.5, 7.85)], -0.45, 0.45, "era", bevel=0.04)  # jaw
    for sx in (-1, 1):
        p.obox((sx * 0.22, 8.15, -2.52), (sx * 1, 0.18, 0.0), FWD, 0.36, 0.11, 0.04, "light")  # eye slits
        p.obox((sx * 0.62, 8.0, -1.85), (0, 0, 1), (sx, 0, 0), 0.8, 0.45, 0.12, "era", bevel=0.02)
    p.box((0, 7.7, -2.6), (0.6, 0.14, 0.04), "grille")
    p.cylinder("y", (0.35, 8.75, -1.6), 0.04, 0.7, 6, "dark")


def details_head(p):
    seam(p, (-0.45, 8.3, -2.3), (0.45, 8.3, -2.3), (0, 0.4, -1))


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 3.5
    drum(p, (sx * 3.4, 7.2, -0.3), 0.68, 1.1, "steel", "trim", sides=16)
    tseg(p, (x, 6.9, -0.3), (x, 5.2, 0.0), 1.0, 1.0, 0.95, 0.95, "dark", pad=0.1)
    tseg(p, (x, 6.8, -0.3), (x, 5.35, 0.0), 1.5, 1.3, 1.35, 1.15, "trim", bevel=0.12)
    p.obox((x + sx * 0.78, 6.05, -0.15), (0, -1.75, 0.3), X, 1.4, 0.95, 0.16, "era", bevel=0.04)
    piston(p, (x, 6.75, 0.5), (x, 5.35, 0.65), r=0.12)  # sleeve behind the elbow
    drum(p, (x, 5.05, 0.0), 0.52, 1.3, "steel", "trim")
    hazard(p, (x, 5.05, 0.55), X, (0, 0, 1), 1.2, 0.22, stripes=5)


def build_armL(p):
    upper_arm(p, -1)


def build_armR(p):
    upper_arm(p, 1)


def details_arm(sx):
    def d(p):
        rivets(p, (sx * 4.3, 5.6, -0.4), (sx * 4.3, 6.5, -0.45), 3, (sx, 0, 0))
    return d


NANO_A, NANO_B = (-3.5, 5.0, 0.0), (-3.5, 3.4, -1.8)


def build_nano(p):
    x = -3.5
    # crane boom: a tapered box beam with a top rail, armor, a hydraulic ram,
    # an elbow guard, claw fingers round the emitter
    tseg(p, NANO_A, NANO_B, 0.75, 0.75, 0.65, 0.65, "dark", pad=0.12)
    tseg(p, NANO_A, NANO_B, 1.05, 0.5, 0.9, 0.42, "trim", off0=0.2, off1=0.2, bevel=0.1)
    tseg(p, NANO_A, NANO_B, 0.85, 0.14, 0.75, 0.14, "steel", off0=-0.42, off1=-0.36, bevel=0.02)
    p.prism_x(arch(-0.5, 0.8, 4.95, 5.55, steps=5, flat=0.2), x - 0.58, x + 0.58, "era", bevel=0.08)  # elbow guard
    piston(p, (x, 4.85, 0.6), (x, 3.85, -1.15), r=0.11, sleeve="steel")
    for sx in (-1, 1):
        p.obox((x + sx * 0.38, 3.2, -2.2), (0, -0.5, -1), (sx * 0.95, 0, -0.3), 1.0, 0.8, 0.16, "steel", bevel=0.03)
        p.obox((x + sx * 0.25, 3.0, -2.72), (-sx * 0.5, -0.4, -1), (sx, 0, 0), 0.55, 0.7, 0.14, "trim", bevel=0.02)
    p.ocyl((x, 3.3, -1.9), (0, -0.2, -1), 0.36, 0.32, 14, "dark")
    p.ocyl((x, 3.24, -2.2), (0, -0.2, -1), 0.3, 0.14, 14, "power")  # emitter
    for s2 in (-1, 1):
        p.obox((x + s2 * 0.47, 4.2, -0.9), (0, -1.6, -1.8), (s2, 0, 0), 1.3, 0.12, 0.03, "light")


def details_nano(p):
    rivets(p, (-3.97, 4.8, -0.2), (-3.97, 3.7, -1.4), 5, (-1, 0, 0))


def build_forearmR(p):
    x = 3.6
    # a heavy gun: an armored block over a dark frame, reactive side plates,
    # a team top panel, a drum magazine; a long barrel with a muzzle brake
    p.prism_x([(-0.25, 3.65), (0.6, 3.65), (0.72, 5.0), (0.15, 5.38), (-2.55, 5.3), (-2.75, 4.65), (-2.55, 3.65)],
              x - 0.82, x + 0.82, "dark", bevel=0.16)
    for sx in (-1, 1):
        p.obox((x + sx * 0.86, 4.5, -1.0), (0, 0, 1), (sx, 0, 0), 2.4, 1.1, 0.16, "era", bevel=0.04)
    p.obox((x, 5.37, -1.1), (0, 0, 1), (0, 1, 0.05), 2.4, 1.1, 0.06, "team", bevel=0.02)
    drum(p, (x - 1.0, 4.3, -0.2), 0.55, 0.4, "steel", "dark", sides=16)
    p.cylinder("z", (x, 4.35, -3.3), 0.36, 1.5, 14, "steel")
    p.cylinder("z", (x, 4.35, -3.25), 0.42, 0.25, 14, "trim")
    p.cylinder("z", (x, 4.35, -4.35), 0.5, 0.6, 14, "dark")
    for sx in (-1, 1):
        p.box((x + sx * 0.51, 4.35, -4.35), (0.04, 0.3, 0.36), "grille")
    p.cylinder("z", (x, 4.35, -4.66), 0.3, 0.05, 14, "weapon")
    p.box((x, 5.36, -2.2), (0.45, 0.06, 0.6), "weapon")
    for sx in (-1, 1):
        p.box((x + sx * 0.95, 4.95, -1.0), (0.03, 0.2, 2.0), "light")
    hazard(p, (x, 3.6, -0.6), (0, 0, 1), (0, -1, 0), 1.2, 0.6, stripes=4)


def details_forearmR(p):
    rivets(p, (4.48, 4.0, -2.0), (4.48, 4.0, 0.0), 5, X)


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    x = sx * 1.7
    HIP, KNEE, ANKLE = (x, 4.2, 0.3), (x, 2.5, -0.85), (x, 0.75, 0.45)

    def hip(p):
        drum(p, (sx * 1.7, 4.3, 0.25), 0.62, 0.8, "steel", "trim")
        p.obox((sx * 2.15, 4.3, 0.2), UP, X, 1.2, 1.4, 0.16, "era", bevel=0.04)
        hazard(p, (sx * 2.24, 4.3, 0.2), (0, 0, 1), X, 1.1, 0.24, stripes=5)

    def thigh(p):
        tseg(p, HIP, KNEE, 1.1, 1.1, 1.05, 1.05, "dark", pad=0.12)
        tseg(p, HIP, KNEE, 1.85, 0.75, 1.55, 0.6, "trim", off0=0.36, off1=0.42, pad=-0.1, bevel=0.15)
        for s2 in (-1, 1):  # exposed pistons down both sides
            piston(p, (x + s2 * 0.82, 4.0, 0.15), (x + s2 * 0.82, 2.75, -0.55), r=0.11)
        tseg(p, HIP, KNEE, 1.2, 0.4, 1.05, 0.35, "era", off0=-0.62, off1=-0.58, pad=-0.25, bevel=0.06)
        piston(p, (x, 3.95, 0.95), (x, 2.75, 0.2), r=0.13)  # sleeve behind the knee
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.72, 3.4, -0.45), (0, -1.7, -1.15), (s2, 0, 0), 1.4, 0.14, 0.03, "light")
        drum(p, KNEE, 0.58, 1.4, "steel", "trim")
        p.obox((x, 2.45, -1.55), X, (0, 0.5, -0.87), 1.5, 1.1, 0.42, "era", bevel=0.08)  # knee plate
        hazard(p, (x, 2.95, -1.33), X, (0, 0.5, -0.87), 1.2, 0.18, stripes=5)

    def shin(p):
        tseg(p, KNEE, ANKLE, 1.1, 1.1, 1.0, 1.0, "dark", pad=0.08)
        tseg(p, KNEE, ANKLE, 1.7, 0.7, 1.5, 0.6, "team", off0=0.36, off1=0.32, pad=-0.25, bevel=0.15)  # team shin plate
        for s2 in (-1, 1):
            p.obox(tuple((V(KNEE) + V(ANKLE)) / 2 + V((s2 * 0.66, 0.0, 0.0))), tuple(V(ANKLE) - V(KNEE)), (s2, 0, 0),
                   1.6, 1.05, 0.14, "era", bevel=0.04)
        piston(p, (x, 2.2, 0.15), (x, 1.0, 1.0), r=0.12, sleeve="steel")  # the rod behind the knee
        p.box((x, 1.3, 0.92), (0.8, 0.6, 0.04), "power")
        p.obox((x, 2.05, -1.2), X, (0, 0.37, -1), 1.2, 0.14, 0.05, "light")
        for s2 in (-1, 1):
            p.obox((x + s2 * 0.74, 1.6, -0.2), (0, -1.75, 1.3), (s2, 0, 0), 1.3, 0.12, 0.03, "light")

    def foot(p):
        drum(p, ANKLE, 0.46, 1.2, "steel", "trim")
        p.box((x, 0.45, 0.45), (1.1, 0.65, 1.05), "dark", bevel=0.08)
        for dx in (-0.55, 0.0, 0.55):  # wide splayed clawed toes
            p.obox((x + dx * 1.15, 0.22, -0.6), (dx * 0.7, -0.15, -1), UP, 1.4, 0.5, 0.42, "trim", bevel=0.08)
            p.obox((x + dx * 1.45, 0.14, -1.42), (dx * 0.7, -0.4, -1), UP, 0.5, 0.36, 0.24, "steel", bevel=0.04)
        p.obox((x, 0.22, 1.45), (0, -0.1, 1), UP, 1.2, 0.65, 0.42, "trim", bevel=0.08)  # heel spur
        p.box((x, 0.04, -0.1), (1.8, 0.08, 2.8), "dark")
        p.box((x, 0.62, -0.1), (0.9, 0.12, 0.03), "light")
        p.box((x, 0.3, -1.95), (1.4, 0.1, 0.03), "light")
        for s2 in (-1, 1):
            p.box((x + s2 * 0.56, 0.5, 0.45), (0.03, 0.14, 0.8), "light")

    def det_thigh(p):
        rivets(p, (x - 0.55, 3.9, -0.25), (x + 0.55, 3.9, -0.25), 4, ldir(0, 0, -1))

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
         attachments={"muzzle": {"parent": "forearmR", "at": [3.6, 4.35, -4.72]}},
         budget=12000,
         previews=[("35", (-17, 13, -20), (0, 5.0, 0), 50),
                   ("side", (24, 5.5, 0), (0, 5.0, 0), 50),
                   ("80", (0, 34, 4), (0, 5.0, 0), 50),
                   ("close", (-8.0, 9.0, -10.5), (0, 6.5, -0.8), 35)])
