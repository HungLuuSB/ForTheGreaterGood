"""Juggernaut (chs_juggernaut, Chaos T3 assault mech, footprint 3; S-209, BAR's
corkorg): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_juggernaut/build.py

Built at the Commander's proportions and scaled x2.15 (unit.run `scale`; its
blockout scales the same), so it stands about 23 studs. After BAR's
corkorg: a huge boxy chest of team armor slabs with dark grooves over a
gunmetal frame, slab pauldrons, a low helmet with a team crest whose snout
is the heat ray (`ray_arm` pitches, `ray_muzzle` at its lens), the missile
tube on the right shoulder (`missile_pod`, vertical launch), exhaust
stacks, thick slab-armored legs with claw toes (the S-181 leg kit's pieces
and points, swinging for the client's walk). The `torso` turns; each arm
(`gunL`, `gunR`) pitches at the shoulder and ends in a double-barrelled
shotgun cannon with steel sleeves (`gun{L,R}_muzzle1` / `2`). Chaos reads
heavy and brutal (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import lib  # noqa: E402
import mech  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, piston, rivets, tseg  # noqa: E402
from unit import UP, seam  # noqa: E402

S = 2.15  # every coordinate below is at the Commander's size; unit.run scales by S
FWD = (0, 0, -1)
X = (1, 0, 0)
V = lib.vec
HIP_Y, HIP_X, T = 4.5, 1.95, 1.45  # the leg kit (Blockouts/Bots.luau points)
TORSO = (0.0, 5.2, 0.0)
ARM_Y = 8.0
ARM_X = 3.55
FORE_Y = 5.0
HEAD = (0.0, 9.25, -0.7)
RAY = (0.0, 9.35, -2.15)
POD = (1.75, 11.0, 1.35)


def drum(p, center, r, length, kind="steel", cap="trim", sides=8, axis="x"):
    """mech.drum with fewer sides: the hero budget (pipeline.md) over this many joints."""
    mech.drum(p, center, r, length, kind, cap, sides=min(sides, 8), axis=axis)


def pts(sx):
    x = sx * HIP_X
    return (x, HIP_Y, 0.0), (x, HIP_Y * 0.52, -T * 0.45), (x, max(0.45, T * 0.7), 0.1)


# ---------------------------------------------------------------- pelvis


def build_base(p):
    p.prism_x([(-0.95, 3.85), (0.95, 3.85), (1.15, 4.6), (0.9, 5.2), (-0.9, 5.2), (-1.15, 4.6)], -1.35, 1.35, "dark", bevel=0.1)
    p.prism_x([(-1.45, 4.3), (-1.05, 3.7), (-0.9, 3.7), (-0.9, 5.1), (-1.35, 5.0)], -1.0, 1.0, "paint", bevel=0.1)
    p.box((0, 4.35, -1.47), (1.2, 0.5, 0.04), "team")
    drum(p, (0, HIP_Y, 0), 0.55, 3.0, "steel", "trim")
    for sx in (-1, 1):
        p.obox((sx * 1.5, 4.9, -0.1), (0, 0, 1), (sx, 0.35, 0), 1.9, 1.2, 0.18, "paint", bevel=0.05)
    p.cylinder("y", (0, 5.2, 0), 1.05, 0.12, 12, "trim")


def details_base(p):
    rivets(p, (-0.7, 4.9, -1.32), (0.7, 4.9, -1.32), 4, (0, -0.3, -1))


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    hip, knee, ankle = pts(sx)
    x = hip[0]

    def thigh(p):
        drum(p, hip, 0.7, 1.45, "steel", "trim")
        tseg(p, hip, knee, 1.25, 1.2, 1.1, 1.05, "dark", pad=0.12)
        tseg(p, hip, knee, 1.95, 0.75, 1.7, 0.6, "paint", off0=0.4, off1=0.45, pad=-0.15, bevel=0.1)  # raked slab
        tseg(p, hip, knee, 1.3, 0.3, 1.1, 0.26, "team", off0=0.85, off1=0.88, pad=-0.4, bevel=0.04)
        for s2 in (-1, 1):
            p.obox(tuple((V(hip) + V(knee)) / 2 + V((s2 * 0.72, 0.0, 0.05))), tuple(V(knee) - V(hip)), (s2, 0, 0),
                   1.7, 1.25, 0.14, "trim", bevel=0.03)
        piston(p, (x + sx * 0.5, 4.1, 0.75), (x + sx * 0.5, 2.6, 0.45), r=0.15)
        drum(p, knee, 0.62, 1.5, "steel", "trim")
        p.prism_x([(-1.45, 1.85), (-0.95, 1.7), (-0.8, 2.4), (-1.0, 3.2), (-1.55, 3.0), (-1.65, 2.35)],
                  x - 0.8, x + 0.8, "paint", bevel=0.1)  # knee block
        p.box((x, 2.4, -1.67), (1.0, 0.16, 0.04), "light")

    def shin(p):
        tseg(p, knee, ankle, 1.85, 0.85, 1.6, 0.75, "paint", off0=0.25, off1=0.2, pad=-0.1, bevel=0.1)
        tseg(p, knee, ankle, 1.2, 0.3, 1.0, 0.28, "team", off0=0.72, off1=0.62, pad=-0.3, bevel=0.04)
        for s2 in (-1, 1):
            p.obox(tuple((V(knee) + V(ankle)) / 2 + V((s2 * 0.72, 0.0, 0.25))), tuple(V(ankle) - V(knee)), (s2, 0, 0),
                   1.4, 1.2, 0.14, "trim", bevel=0.03)
        piston(p, (x, 2.1, 0.6), (x, 1.15, 0.95), r=0.12, sleeve="steel")
        p.box((x, 1.5, 1.05), (0.9, 0.5, 0.04), "power")

    def foot(p):
        drum(p, ankle, 0.5, 1.3, "steel", "trim")
        p.box((x, 0.55, 0.2), (1.3, 0.7, 1.3), "dark", bevel=0.08)
        p.prism_x([(-1.4, 0.0), (1.45, 0.0), (1.45, 0.42), (1.0, 0.68), (-0.6, 0.72), (-1.3, 0.4)], x - 0.95, x + 0.95, "paint", bevel=0.12)
        p.box((x, 0.74, 0.15), (1.2, 0.05, 1.2), "team")
        for k in (-1, 0, 1):  # claw toes
            p.prism_x([(-2.15, 0.03), (-1.2, 0.03), (-1.2, 0.5), (-1.7, 0.42)],
                      x + k * 0.6 - 0.22, x + k * 0.6 + 0.22, "steel", bevel=0.03)
        p.prism_x([(1.4, 0.03), (2.0, 0.03), (1.4, 0.45)], x - 0.25, x + 0.25, "steel", bevel=0.03)  # heel spur

    def det_thigh(p):
        rivets(p, (x + sx * 0.8, 4.1, -0.1), (x + sx * 0.8, 2.9, -0.5), 4, (sx, 0, 0))

    def det_shin(p):
        seam(p, (x - 0.7, 1.7, -0.85), (x + 0.7, 1.7, -0.85), (0, 0.3, -1))

    none = lambda p: None  # noqa: E731
    return [unit.PieceSpec(f"thigh{n}", "base", hip, thigh, det_thigh),
            unit.PieceSpec(f"shin{n}", f"thigh{n}", knee, shin, det_shin),
            unit.PieceSpec(f"foot{n}", f"shin{n}", ankle, foot, none)]


# ---------------------------------------------------------------- torso


def build_torso(p):
    p.cylinder("y", (0, 5.6, 0), 0.85, 0.8, 12, "steel")
    p.prism_y([(-1.2, -0.9), (1.2, -0.9), (1.35, 0.0), (1.2, 0.9), (-1.2, 0.9), (-1.35, 0.0)], 5.9, 6.5, "dark", bevel=0.08)
    # the gunmetal frame: a deep box flaring to the shoulders
    p.prism_y([(-2.0, -1.2), (2.0, -1.2), (2.3, -0.4), (2.2, 1.4), (-2.2, 1.4), (-2.3, -0.4)], 6.4, 9.1, "paint", bevel=0.18, top_scale=1.08)
    # the team chest: two tall armor slabs and a belly slab, dark grooves between
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.08, sx * 2.25))
        p.prism_x([(-2.05, 7.35), (-1.25, 7.2), (-1.25, 9.25), (-1.9, 9.25), (-2.15, 8.9)], x0, x1, "team", bevel=0.12)
        p.box((sx * 1.15, 8.3, -2.12), (0.06, 1.5, 0.04), "dark")  # panel groove
    p.prism_x([(-1.85, 6.35), (-1.2, 6.25), (-1.2, 7.25), (-2.0, 7.25)], -1.7, 1.7, "team", bevel=0.1)
    for dx in (-1.0, -0.35, 0.35, 1.0):  # belly vents
        p.box((dx, 6.75, -1.9), (0.42, 0.42, 0.04), "grille")
    p.box((0, 7.3, -2.09), (4.2, 0.08, 0.04), "dark")
    hazard(p, (0, 6.15, -1.6), X, (0, -0.3, -1), 2.6, 0.2, stripes=6)
    # a neck collar for the helmet
    p.prism_x([(-1.3, 9.0), (-0.9, 9.6), (0.9, 9.6), (1.2, 9.0)], -1.05, 1.05, "trim", bevel=0.1)
    # slab pauldrons over shoulder drums, team bands, vents
    for sx in (-1, 1):
        drum(p, (sx * 2.75, ARM_Y, 0), 0.9, 1.0, "dark", "trim")
        x0, x1 = sorted((sx * 2.35, sx * 4.85))
        p.prism_x([(-1.75, 7.6), (1.75, 7.6), (1.75, 9.15), (1.0, 9.75), (-1.15, 9.75), (-1.85, 9.0)], x0, x1, "paint", bevel=0.16)
        xt0, xt1 = sorted((sx * 2.6, sx * 4.6))
        p.prism_x([(-1.95, 8.3), (-1.8, 8.3), (-1.8, 9.05), (-1.95, 8.95)], xt0, xt1, "team", bevel=0.02)
        p.box((sx * 4.87, 8.6, 0.0), (0.04, 0.5, 2.2), "grille")
        p.box((sx * 4.88, 8.0, 0.0), (0.03, 0.12, 2.6), "light")
    # back: a reactor hump with glowing vents, two exhaust stacks with hot rings
    p.box((-0.55, 7.8, 2.0), (2.6, 2.6, 1.4), "trim", bevel=0.22)
    for k in range(3):
        p.box((-0.55, 7.0 + k * 0.6, 2.72), (2.0, 0.22, 0.05), "power")
    p.cylinder("y", (-1.45, 9.7, 1.9), 0.28, 1.8, 8, "dark")
    p.cylinder("y", (-1.45, 10.62, 1.9), 0.33, 0.12, 8, "power")
    cable(p, [(1.0, 8.6, 1.55), (1.6, 9.2, 1.45), (1.75, 9.6, 1.35)], r=0.08)
    p.box((POD[0], 9.25, POD[2]), (1.9, 0.5, 1.9), "trim", bevel=0.08)  # the missile tube's mount


def details_torso(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.6, 9.74, -0.9), (sx * 4.6, 9.74, -0.9), 6, UP)
        seam(p, (sx * 2.5, 9.0, -1.86), (sx * 4.7, 9.0, -1.86), FWD)
        rivets(p, (sx * 0.4, 9.2, -2.12), (sx * 2.0, 9.2, -2.12), 5, FWD)
    seam(p, (-1.7, 7.3, -2.1), (1.7, 7.3, -2.1), FWD)


def build_pod(p):
    x, y, z = POD
    p.prism_y(mech.octagon(0.9, 0.3, x, z), y - 1.75, y - 0.1, "paint", bevel=0.08)
    p.prism_y(mech.octagon(0.95, 0.32, x, z), y - 0.75, y - 0.35, "team", bevel=0.03)
    p.prism_y(mech.octagon(0.7, 0.25, x, z), y - 0.1, y, "dark")
    for dx in (-0.3, 0.3):
        for dz in (-0.3, 0.3):
            p.cylinder("y", (x + dx, y + 0.02, z + dz), 0.17, 0.04, 6, "weapon")
    p.box((x + 0.92, y - 1.0, z), (0.04, 1.0, 0.14), "light")


def details_pod(p):
    x, y, z = POD
    rivets(p, (x - 0.6, y - 1.5, z - 0.92), (x + 0.6, y - 1.5, z - 0.92), 5, FWD)


# ---------------------------------------------------------------- head: the heat ray


def build_ray(p):
    hx, hy, hz = HEAD
    p.prism_x([(hz - 1.15, 8.95), (hz + 0.75, 8.95), (hz + 0.75, 9.75), (hz + 0.2, 10.1), (hz - 0.8, 10.0), (hz - 1.35, 9.55)],
              -0.72, 0.72, "paint", bevel=0.1)
    p.prism_x([(hz - 0.9, 10.0), (hz + 0.5, 10.05), (hz + 0.6, 10.55), (hz - 0.35, 10.75)], -0.22, 0.22, "team", bevel=0.04)  # crest
    for sx in (-1, 1):
        p.obox((sx * 0.6, 9.75, hz - 1.0), X, (0, 0.3, -1), 0.4, 0.1, 0.04, "head")  # amber eye slits
    # the heat-ray snout: a ribbed emitter with a glowing lens
    p.ocyl((0, RAY[1], hz - 1.0), FWD, 0.42, 0.8, 10, "trim")
    p.ocyl((0, RAY[1], hz - 1.25), FWD, 0.5, 0.12, 10, "power")
    p.ocyl((0, RAY[1], RAY[2] + 0.15), FWD, 0.36, 0.1, 10, "steel")
    p.ocyl((0, RAY[1], RAY[2] + 0.05), FWD, 0.26, 0.04, 10, "weapon")


def details_ray(p):
    seam(p, (-0.6, 9.8, HEAD[2] - 0.6), (0.6, 9.8, HEAD[2] - 0.6), (0, 0.4, -1))


# ---------------------------------------------------------------- arms: the shotgun cannons


def build_gun(sx):
    def build(p):
        x = sx * ARM_X
        drum(p, (sx * 3.35, ARM_Y, 0), 0.75, 1.2, "steel", "trim")
        tseg(p, (x, 7.6, 0), (x, 6.0, 0), 1.6, 1.5, 1.45, 1.35, "trim", bevel=0.1)
        p.obox((x + sx * 0.82, 6.8, 0), UP, X, 1.1, 0.9, 0.08, "team", bevel=0.02)
        piston(p, (x - sx * 0.3, 7.4, 0.75), (x - sx * 0.3, 6.0, 0.8), r=0.13)
        drum(p, (x, 5.75, 0), 0.6, 1.5, "steel", "trim")
        # the cannon: a slab housing (team side), an ammo box, two barrels in steel sleeves
        p.prism_x([(-1.5, 4.15), (1.35, 4.15), (1.5, 5.0), (1.2, 5.85), (-1.1, 5.95), (-1.75, 5.4)], x - 1.0, x + 1.0, "paint", bevel=0.14)
        p.obox((x + sx * 1.02, 5.0, -0.2), (0, 0, 1), X, 2.2, 1.1, 0.06, "team", bevel=0.02)
        p.box((x - sx * 1.05, 4.6, 0.4), (0.5, 0.9, 1.4), "trim", bevel=0.06)
        p.box((x, 5.0, -1.85), (1.7, 1.35, 0.5), "dark", bevel=0.06)
        for dx in (-0.36, 0.36):
            p.ocyl((x + dx, FORE_Y, -2.0), FWD, 0.3, 2.2, 10, "dark")
            p.ocyl((x + dx, FORE_Y, -3.1), FWD, 0.38, 1.0, 10, "steel")  # the silver sleeves
            p.ocyl((x + dx, FORE_Y, -4.15), FWD, 0.25, 0.04, 10, "weapon")
        p.box((x, 5.65, -1.85), (1.2, 0.06, 0.04), "light")
    return build


def details_gun(sx):
    def d(p):
        x = sx * ARM_X
        rivets(p, (x + sx * 1.01, 5.55, -1.0), (x + sx * 1.01, 5.55, 0.8), 5, (sx, 0, 0))
        seam(p, (x - 0.9, 5.94, -0.8), (x + 0.9, 5.94, -0.8), UP)
    return d


def gun_muzzles(sx):
    n = "L" if sx < 0 else "R"
    x = sx * ARM_X
    return {f"gun{n}_muzzle1": {"parent": f"gun{n}", "at": [x - 0.36, FORE_Y, -4.25]},
            f"gun{n}_muzzle2": {"parent": f"gun{n}", "at": [x + 0.36, FORE_Y, -4.25]}}


unit.run(__file__, "chs_juggernaut", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)]
         + leg_specs(-1) + leg_specs(1)
         + [unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
            unit.PieceSpec("missile_pod", "torso", POD, build_pod, details_pod),
            unit.PieceSpec("ray_arm", "torso", HEAD, build_ray, details_ray),
            unit.PieceSpec("gunL", "torso", (-3.35, ARM_Y, 0.0), build_gun(-1), details_gun(-1)),
            unit.PieceSpec("gunR", "torso", (3.35, ARM_Y, 0.0), build_gun(1), details_gun(1))],
         attachments={"ray_muzzle": {"parent": "ray_arm", "at": [0.0, RAY[1], RAY[2]]}, **gun_muzzles(-1), **gun_muzzles(1)},
         scale=(S, S, S), budget=6000,
         previews=bots.previews(23.5))
