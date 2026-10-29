"""Titan (Order T3 assault mech, footprint 3; S-209, BAR's armbanth):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_titan/build.py

Built at the Commander's proportions and scaled x2.1 (unit.run `scale`; its
blockout scales the same), so it stands about 22 studs, twice a Sovereign.
After BAR's armbanth: a broad armored chest with a jutting front block (two
lit slits, a sensor head with a lens on top), huge rounded team shoulder
pads, a backpack with radiators and an antenna, the missile tube on the
left shoulder (`missile_pod`, vertical launch), thick armored legs with big
knee guards and wide feet (the S-181 leg kit's pieces and points, swinging
for the client's walk). The `torso` turns; each arm pitches at the
shoulder: the right `beam_arm` ends in the tachyon cannon (coils, a lens,
`beam_muzzle`), the left `blaster_arm` in twin plasma blasters
(`blaster_muzzle1` / `2`). Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
import mech  # noqa: E402
from mech import arch, cable, hazard, piston, rivets, tseg  # noqa: E402
from unit import UP, seam  # noqa: E402

S = 2.1  # every coordinate below is at the Commander's size; unit.run scales by S
FWD = (0, 0, -1)
X = (1, 0, 0)
V = lib.vec
HIP_Y, HIP_X, T = 4.6, 1.75, 1.3  # the leg kit (Blockouts/Bots.luau points)
TORSO = (0.0, 5.3, 0.0)
SHOULDER = 3.3
ARM_Y = 7.8
FORE_Y = 5.0  # the forearm guns' axis
BEAM_X, BLAST_X = 3.5, -3.5
POD = (-1.55, 10.5, 1.45)  # the missile tube's mouth


def drum(p, center, r, length, kind="steel", cap="trim", sides=8, axis="x"):
    """mech.drum with fewer sides: the hero budget (pipeline.md) over this many joints."""
    mech.drum(p, center, r, length, kind, cap, sides=8 if sides > 8 else sides, axis=axis)


def pts(sx):
    x = sx * HIP_X
    return (x, HIP_Y, 0.0), (x, HIP_Y * 0.52, -T * 0.45), (x, max(0.45, T * 0.7), 0.1)


# ---------------------------------------------------------------- pelvis


def build_base(p):
    p.prism_x([(-0.85, 4.0), (0.85, 4.0), (1.05, 4.7), (0.8, 5.25), (-0.8, 5.25), (-1.05, 4.7)], -1.25, 1.25, "dark", bevel=0.1)
    p.prism_x([(-1.3, 4.35), (-0.95, 3.85), (-0.8, 3.85), (-0.8, 5.2), (-1.2, 5.1)], -0.9, 0.9, "paint", bevel=0.12)  # cod plate
    p.prism_x([(0.8, 4.1), (1.2, 4.35), (1.15, 5.1), (0.8, 5.2)], -1.0, 1.0, "paint", bevel=0.1)
    drum(p, (0, HIP_Y, 0), 0.5, 2.6, "steel", "trim")
    for sx in (-1, 1):  # hip skirts over the joints
        p.obox((sx * 1.4, 4.95, -0.15), (0, 0, 1), (sx, 0.3, 0), 1.7, 1.1, 0.16, "paint", bevel=0.05)
        p.box((sx * 1.49, 4.6, -0.15), (0.03, 0.12, 1.3), "light")
    p.cylinder("y", (0, 5.3, 0), 0.95, 0.12, 14, "trim")


def details_base(p):
    rivets(p, (-0.6, 5.0, -1.2), (0.6, 5.0, -1.2), 4, (0, -0.3, -1))


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    hip, knee, ankle = pts(sx)
    x = hip[0]

    def thigh(p):
        drum(p, hip, 0.62, 1.3, "steel", "trim", sides=18)
        tseg(p, hip, knee, 1.1, 1.1, 1.0, 1.0, "dark", pad=0.12)
        tseg(p, hip, knee, 1.75, 0.8, 1.5, 0.6, "paint", off0=0.32, off1=0.38, pad=-0.1, bevel=0.14)
        for s2 in (-1, 1):
            p.obox(tuple((V(hip) + V(knee)) / 2 + V((s2 * 0.64, 0.05, 0.0))), tuple(V(knee) - V(hip)), (s2, 0, 0),
                   1.6, 1.15, 0.12, "paint", bevel=0.04)
        tseg(p, hip, knee, 1.15, 0.3, 1.0, 0.26, "team", off0=0.75, off1=0.78, pad=-0.35, bevel=0.04)
        piston(p, (x, 4.05, 0.72), (x, 2.6, 0.5), r=0.14)
        drum(p, knee, 0.58, 1.4, "steel", "trim")
        p.prism_x([(-1.3, 1.95), (-0.9, 1.8), (-0.75, 2.45), (-0.9, 3.15), (-1.35, 2.95), (-1.5, 2.45)],
                  x - 0.72, x + 0.72, "paint", bevel=0.14)  # knee guard

    def shin(p):
        tseg(p, knee, ankle, 1.7, 0.8, 1.5, 0.7, "team", off0=0.32, off1=0.3, pad=-0.2, bevel=0.14)
        for s2 in (-1, 1):
            p.obox(tuple((V(knee) + V(ankle)) / 2 + V((s2 * 0.62, 0.0, 0.08))), tuple(V(ankle) - V(knee)), (s2, 0, 0),
                   1.45, 1.1, 0.12, "paint", bevel=0.04)
        piston(p, (x, 2.2, 0.4), (x, 1.15, 0.85), r=0.11, sleeve="steel")
        p.prism_x([(0.35, 1.0), (0.9, 1.05), (1.0, 1.85), (0.55, 2.0)], x - 0.58, x + 0.58, "paint", bevel=0.08)  # calf
        p.box((x, 1.42, 1.02), (0.8, 0.6, 0.04), "power")
        p.obox((x, 2.05, -0.86), X, (0, 0.37, -1), 1.2, 0.12, 0.05, "light")

    def foot(p):
        drum(p, ankle, 0.46, 1.2, "steel", "trim")
        p.box((x, 0.5, 0.15), (1.1, 0.62, 1.05), "dark", bevel=0.08)
        p.prism_x([(-1.85, 0.0), (-0.1, 0.0), (-0.1, 0.58), (-0.9, 0.7), (-1.7, 0.38)], x - 0.88, x + 0.88, "paint", bevel=0.14)
        p.prism_x([(-1.75, 0.4), (-0.95, 0.7), (-0.4, 0.74), (-0.4, 0.82), (-1.0, 0.8), (-1.8, 0.47)], x - 0.2, x + 0.2, "team", bevel=0.03)
        p.prism_x([(0.45, 0.0), (1.5, 0.0), (1.5, 0.38), (1.15, 0.6), (0.45, 0.6)], x - 0.72, x + 0.72, "paint", bevel=0.12)
        p.box((x, 0.04, -0.15), (1.6, 0.08, 3.3), "dark")
        p.box((x, 0.24, -1.82), (1.4, 0.16, 0.03), "light")

    def det_thigh(p):
        rivets(p, (x + sx * 0.71, 4.1, -0.15), (x + sx * 0.71, 2.9, -0.45), 4, (sx, 0, 0))

    def det_shin(p):
        seam(p, (x - 0.55, 1.9, -0.98), (x + 0.55, 1.9, -0.98), (0, 0.35, -1))

    none = lambda p: None  # noqa: E731
    return [unit.PieceSpec(f"thigh{n}", "base", hip, thigh, det_thigh),
            unit.PieceSpec(f"shin{n}", f"thigh{n}", knee, shin, det_shin),
            unit.PieceSpec(f"foot{n}", f"shin{n}", ankle, foot, none)]


# ---------------------------------------------------------------- torso

CHEST = [(-1.55, -1.15), (1.55, -1.15), (1.75, -0.3), (1.6, 1.2), (-1.6, 1.2), (-1.75, -0.3)]


def build_torso(p):
    # waist: a steel column, pistons, a dark abdomen with banded plates
    p.cylinder("y", (0, 5.65, 0), 0.75, 0.6, 10, "steel")
    p.prism_y([(-1.05, -0.85), (1.05, -0.85), (1.2, 0.0), (1.05, 0.85), (-1.05, 0.85), (-1.2, 0.0)], 5.9, 6.6, "dark", bevel=0.08)
    # chest: a V widening up to the shoulders
    p.prism_y(CHEST, 6.5, 8.5, "paint", bevel=0.2, top_scale=1.22)
    for sx in (-1, 1):  # team chest plates either side of the front block
        x0, x1 = sorted((sx * 1.15, sx * 2.05))
        p.prism_x([(-1.3, 6.65), (-1.62, 7.15), (-1.88, 8.35), (-1.45, 8.45), (-1.25, 7.4)], x0, x1, "team", bevel=0.1)
    # the jutting front block (BAR's): dark, two tall lit slits, a team plate below, a yellow sensor
    p.prism_x([(-2.35, 6.0), (-1.2, 6.0), (-1.2, 8.3), (-2.05, 8.3), (-2.35, 7.9)], -1.15, 1.15, "trim", bevel=0.12)
    p.box((0, 7.15, -2.37), (1.6, 1.7, 0.04), "dark")
    for dx in (-0.32, 0.32):
        p.box((dx, 7.3, -2.4), (0.22, 1.15, 0.04), "power")
    p.box((0, 6.3, -2.37), (1.9, 0.38, 0.04), "team")
    p.cylinder("z", (0.85, 7.9, -2.25), 0.26, 0.1, 14, "head")
    hazard(p, (0, 6.05, -2.37), X, FWD, 2.0, 0.16, stripes=6)
    # the sensor head on top: a squat housing with a green-white lens, two side cheeks
    p.prism_y([(-0.6, -1.15), (0.6, -1.15), (0.75, -0.6), (0.75, 0.25), (-0.75, 0.25), (-0.75, -0.6)], 8.4, 9.25, "paint", bevel=0.1, top_scale=0.85)
    p.cylinder("z", (0, 8.85, -1.2), 0.28, 0.12, 10, "trim")
    p.cylinder("z", (0, 8.85, -1.28), 0.2, 0.04, 10, "head")
    for sx in (-1, 1):
        p.box((sx * 0.78, 8.8, -0.45), (0.05, 0.12, 0.9), "light")
    # shoulder drums and huge rounded team pads
    for sx in (-1, 1):
        drum(p, (sx * 2.6, ARM_Y, 0), 0.85, 0.9, "dark", "trim", sides=20)
        x0, x1 = sorted((sx * 2.35, sx * 5.0))
        p.prism_x(arch(-1.85, 1.85, 7.55, 9.75, steps=6, flat=0.25), x0, x1, "team", bevel=0.18)
        xu0, xu1 = sorted((sx * 2.6, sx * 4.8))
        p.prism_x(arch(-1.55, 1.55, 7.0, 7.7, steps=3, flat=0.5), xu0, xu1, "trim", bevel=0.06)
        p.obox((sx * 3.7, 9.2, -1.65), X, (0, 0.6, -0.8), 2.2, 0.3, 0.04, "light")
        p.box((sx * 5.01, 8.3, 0.2), (0.04, 0.6, 1.6), "power")
        hazard(p, (sx * 3.7, 7.6, -1.86), X, FWD, 2.2, 0.22, stripes=5)
    # backpack: radiator housing, team side panels, glowing vents, an antenna
    p.box((0.5, 7.5, 2.0), (3.0, 2.4, 1.6), "trim", bevel=0.25)
    for k in range(4):
        p.box((0.5, 6.7 + k * 0.45, 2.82), (2.4, 0.16, 0.06), "grille")
    p.box((0.5, 8.55, 2.82), (2.2, 0.2, 0.04), "power")
    for sx in (-1, 1):
        p.obox((0.5 + sx * 1.52, 7.5, 2.0), (0, 0, 1), (sx, 0, 0), 1.3, 1.9, 0.08, "team", bevel=0.03)
    p.cylinder("y", (1.45, 9.6, 2.2), 0.07, 2.4, 6, "dark")
    p.box((1.45, 10.85, 2.2), (0.16, 0.14, 0.16), "light")
    cable(p, [(-0.9, 8.4, 1.5), (-2.0, 8.8, 1.2), (-2.7, 8.6, 1.0)])
    cable(p, [(1.9, 8.4, 1.5), (2.4, 8.8, 1.2), (2.9, 8.6, 1.0)])
    # the missile tube's mount on the left shoulder
    p.box((POD[0], 8.75, POD[2]), (1.7, 0.5, 1.7), "trim", bevel=0.08)


def details_torso(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.7, 9.73, -0.95), (sx * 4.7, 9.73, -0.95), 6, UP)
        rivets(p, (sx * 2.7, 9.73, 0.95), (sx * 4.7, 9.73, 0.95), 6, UP)
        seam(p, (sx * 2.5, 9.74, 0.0), (sx * 4.9, 9.74, 0.0), UP)
    seam(p, (-1.5, 8.45, -1.7), (1.5, 8.45, -1.7), (0, 0.4, -1))
    rivets(p, (-1.0, 6.4, 2.81), (2.0, 6.4, 2.81), 7, (0, 0, 1))


def build_pod(p):
    x, y, z = POD
    p.cylinder("y", (x, y - 1.4, z), 0.82, 2.4, 10, "paint")
    p.cylinder("y", (x, y - 0.5, z), 0.88, 0.4, 10, "team")
    p.cylinder("y", (x, y - 0.02, z), 0.7, 0.06, 10, "dark")
    for k in range(4):  # launch cells round a centre cell
        t = 2 * math.pi * k / 4 + math.pi / 4
        p.cylinder("y", (x + math.cos(t) * 0.42, y + 0.02, z + math.sin(t) * 0.42), 0.15, 0.04, 6, "weapon")
    p.cylinder("y", (x, y + 0.02, z), 0.15, 0.04, 6, "weapon")
    p.box((x - 0.84, y - 1.4, z), (0.04, 1.4, 0.14), "light")


def details_pod(p):
    x, y, z = POD
    rivets(p, (x - 0.6, y - 2.1, z - 0.62), (x + 0.6, y - 2.1, z - 0.62), 5, FWD)


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 3.5
    drum(p, (sx * SHOULDER, ARM_Y, 0), 0.7, 1.1, "steel", "trim", sides=18)
    tseg(p, (x, 7.3, 0), (x, 6.1, 0), 1.55, 1.4, 1.4, 1.25, "paint", bevel=0.12)
    p.obox((x + sx * 0.79, 6.7, 0), UP, X, 0.95, 0.85, 0.08, "team", bevel=0.02)
    piston(p, (x, 7.2, 0.66), (x, 6.0, 0.7), r=0.12)
    drum(p, (x, 5.75, 0), 0.55, 1.35, "steel", "trim")


def build_beam_arm(p):
    x = BEAM_X
    upper_arm(p, 1)
    # the tachyon cannon: a long armored housing, coils, a heavy lens
    p.prism_x([(-1.6, 4.3), (1.1, 4.3), (1.3, 5.0), (1.0, 5.75), (-1.2, 5.85), (-1.85, 5.35)], x - 0.85, x + 0.85, "paint", bevel=0.16)
    p.obox((x + 0.87, 5.05, -0.2), (0, 0, 1), X, 2.2, 1.0, 0.06, "team", bevel=0.02)
    p.box((x - 0.86, 5.1, -0.2), (0.04, 0.7, 1.9), "grille")
    p.ocyl((x, FORE_Y, -1.75), FWD, 0.68, 0.5, 10, "trim")
    p.ocyl((x, FORE_Y, -2.2), FWD, 0.5, 2.5, 10, "steel")
    for z in (-2.55, -3.15, -3.75):
        p.ocyl((x, FORE_Y, z), FWD, 0.64, 0.22, 10, "power")
    p.ocyl((x, FORE_Y, -4.6), FWD, 0.75, 0.55, 10, "dark")
    p.ocyl((x, FORE_Y, -5.13), FWD, 0.45, 0.04, 10, "weapon")
    for s2 in (-1, 1):
        p.box((x + s2 * 0.86, 5.55, -0.3), (0.03, 0.14, 2.0), "light")


def build_blaster_arm(p):
    x = BLAST_X
    upper_arm(p, -1)
    # twin plasma blasters: a block housing with an ammo drum, two shrouded barrels
    p.prism_x([(-1.4, 4.25), (1.1, 4.25), (1.3, 5.0), (1.0, 5.75), (-1.1, 5.85), (-1.7, 5.3)], x - 0.95, x + 0.95, "paint", bevel=0.16)
    p.obox((x - 0.97, 5.05, -0.2), (0, 0, 1), X, 2.1, 1.0, 0.06, "team", bevel=0.02)
    drum(p, (x + 0.98, 4.7, 0.2), 0.48, 0.36, "trim", "dark", sides=16)
    p.box((x, 4.95, -1.75), (1.6, 1.2, 0.5), "trim", bevel=0.08)
    for dx in (-0.36, 0.36):
        p.ocyl((x + dx, FORE_Y, -1.9), FWD, 0.27, 2.1, 10, "dark")
        p.ocyl((x + dx, FORE_Y, -3.45), FWD, 0.34, 0.4, 10, "steel")
        p.ocyl((x + dx, FORE_Y, -3.98), FWD, 0.24, 0.04, 10, "weapon")
    p.box((x, 5.6, -1.75), (0.6, 0.06, 0.04), "power")
    for s2 in (-1, 1):
        p.box((x + s2 * 0.96, 5.55, -0.3), (0.03, 0.14, 2.0), "light")


def details_arm(sx):
    def d(p):
        rivets(p, (sx * 4.3, 6.3, -0.3), (sx * 4.3, 7.1, -0.3), 3, (sx, 0, 0))
        seam(p, (sx * 3.5 - 0.8, 5.84, -1.0), (sx * 3.5 + 0.8, 5.84, -1.0), UP)
    return d


unit.run(__file__, "ord_titan", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)]
         + leg_specs(-1) + leg_specs(1)
         + [unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
            unit.PieceSpec("missile_pod", "torso", POD, build_pod, details_pod),
            unit.PieceSpec("beam_arm", "torso", (SHOULDER, ARM_Y, 0.0), build_beam_arm, details_arm(1)),
            unit.PieceSpec("blaster_arm", "torso", (-SHOULDER, ARM_Y, 0.0), build_blaster_arm, details_arm(-1))],
         attachments={"beam_muzzle": {"parent": "beam_arm", "at": [BEAM_X, FORE_Y, -5.2]},
                      "blaster_muzzle1": {"parent": "blaster_arm", "at": [BLAST_X - 0.36, FORE_Y, -4.05]},
                      "blaster_muzzle2": {"parent": "blaster_arm", "at": [BLAST_X + 0.36, FORE_Y, -4.05]}},
         scale=(S, S, S), budget=6000,
         previews=bots.previews(22.5))
