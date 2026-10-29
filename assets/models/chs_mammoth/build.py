"""Mammoth (Chaos T2 armored assault bot, footprint 2; S-209, no BAR
counterpart): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_mammoth/build.py

An armored war elephant, heavier than the Fatboy: a long domed body of
gunmetal plates with big team flank slabs and reactive blocks on four
thick pillar legs (`legFL` / `legFR` / `legBL` / `legBR`, each one piece
jointed at the hip that swings for the walk, with knee guards and broad
round feet with steel toenails); an armored head low in front with ear
plates (team), steel tusks and a segmented trunk; two exhaust stacks with
hot rings and a reactor vent on the rump. On its back the `turret` (turns)
carries the `barrels` (pitch): a mantlet with two long laser barrels in
cooling shrouds, `muzzle1` (left) / `muzzle2` (right) at their lenses. Chaos reads heavy
and brutal (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import mech  # noqa: E402
import unit  # noqa: E402
from mech import arch, cable, hazard, rivets, tseg  # noqa: E402
from unit import UP, seam  # noqa: E402

FWD = (0, 0, -1)
X = (1, 0, 0)
V = lib.vec
HIP_Y = 5.6
LEGS = {"FL": (-3.15, -3.6), "FR": (3.15, -3.6), "BL": (-3.15, 3.5), "BR": (3.15, 3.5)}  # (x, z) of each hip
TURRET = (0.0, 9.1, 0.6)
GUN_Y, GUN_Z = 10.15, -0.9  # the barrels' axis height and the mantlet's pivot
BARREL_X = 1.0
MUZZLE_Z = -6.75


def drum(p, center, r, length, kind="steel", cap="trim", sides=10, axis="x"):
    mech.drum(p, center, r, length, kind, cap, sides=min(sides, 10), axis=axis)


# ---------------------------------------------------------------- body


def build_base(p):
    # the long domed hull: a side profile (z, y) extruded across, wider low
    hull = [(-6.4, 4.7), (5.9, 4.7), (6.6, 6.0), (6.2, 8.3), (4.6, 9.1), (-4.0, 9.2), (-5.9, 8.4), (-6.7, 6.4)]
    p.prism_x(hull, -4.1, 4.1, "paint", bevel=0.25)
    p.prism_x([(-5.6, 4.2), (5.2, 4.2), (5.4, 4.75), (-5.8, 4.75)], -3.3, 3.3, "dark", bevel=0.1)  # belly
    # flank armor: big team slabs over a trim skirt, reactive blocks above
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 4.05, sx * 4.45))
        p.prism_x([(-5.4, 5.0), (4.9, 5.0), (5.5, 6.0), (5.2, 7.6), (-4.9, 7.7), (-5.8, 6.4)], x0, x1, "team", bevel=0.12)
        xs0, xs1 = sorted((sx * 4.4, sx * 4.6))
        p.prism_x([(-5.2, 4.6), (4.8, 4.6), (5.1, 5.15), (-5.5, 5.15)], xs0, xs1, "trim", bevel=0.05)
        for k in range(4):
            z = -3.9 + k * 2.4
            p.obox((sx * 3.55, 8.35, z), (0, 0, 1), (sx, 0.9, 0), 1.9, 0.9, 0.35, "trim", bevel=0.06)
        p.box((sx * 4.46, 6.3, 0), (0.04, 0.14, 8.5), "light")
    # the turret ring on the back
    p.cylinder("y", (TURRET[0], 9.2, TURRET[2]), 2.9, 0.3, 14, "trim")
    # rump: a reactor vent, two exhaust stacks with hot rings, a hazard band
    p.box((0, 7.2, 6.45), (4.0, 2.0, 0.4), "trim", bevel=0.1)
    for k in range(3):
        p.box((0, 6.6 + k * 0.55, 6.67), (3.2, 0.22, 0.05), "power")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 2.3, 9.9, 4.6), 0.38, 2.2, 8, "dark")
        p.cylinder("y", (sx * 2.3, 10.95, 4.6), 0.44, 0.15, 8, "power")
    hazard(p, (0, 5.05, 6.4), X, (0, 0, 1), 5.0, 0.4, stripes=7)
    # the head: armored and low in front, ear plates, tusks, a segmented trunk
    p.prism_x([(-8.0, 5.3), (-6.2, 4.7), (-5.5, 6.5), (-5.6, 8.6), (-6.6, 8.6), (-7.9, 7.4)], -2.2, 2.2, "paint", bevel=0.2)
    p.prism_x([(-8.05, 7.0), (-7.0, 8.4), (-6.3, 8.75), (-6.5, 8.95), (-7.3, 8.6), (-8.15, 7.4)], -0.5, 0.5, "team", bevel=0.05)  # brow crest
    for sx in (-1, 1):
        p.obox((sx * 2.75, 7.0, -6.0), (0, -0.25, 1), (sx, 0, 0.35), 2.6, 3.0, 0.22, "team", bevel=0.08)  # ear plates
        p.obox((sx * 1.3, 7.3, -7.86), (sx * 0.3, 0, 0), (0, 0.15, -1), 0.6, 0.18, 0.04, "head")  # eye slits
        tusk = [(sx * 1.4, 5.4, -7.6), (sx * 1.6, 4.6, -8.6), (sx * 1.7, 4.4, -9.6)]
        p.ocyl(tusk[0], tuple(V(tusk[1]) - V(tusk[0])), 0.32, (V(tusk[1]) - V(tusk[0])).length, 7, "steel", radius2=0.26)
        p.ocyl(tusk[1], tuple(V(tusk[2]) - V(tusk[1])), 0.26, (V(tusk[2]) - V(tusk[1])).length, 7, "steel", radius2=0.06)
    prev = (0.0, 6.0, -8.0)
    for i, (y, z) in enumerate(((5.0, -8.35), (4.0, -8.5), (3.0, -8.4), (2.15, -8.05))):
        q = (0.0, y, z)
        r = 0.72 - 0.08 * i
        p.ocyl(prev, tuple(V(q) - V(prev)), r, (V(q) - V(prev)).length, 8, "dark" if i % 2 else "trim", radius2=r * 0.92)
        prev = q
    p.cylinder("y", (0.0, 2.1, -8.05), 0.42, 0.12, 8, "weapon")
    cable(p, [(-1.6, 8.6, -5.6), (-2.2, 9.0, -3.0), (-2.4, 9.1, -1.2)], r=0.12)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 4.46, 7.3, -4.5), (sx * 4.46, 7.3, 4.6), 12, (sx, 0, 0))
        seam(p, (sx * 4.46, 5.5, -4.8), (sx * 4.46, 5.5, 5.0), (sx, 0, 0))
    seam(p, (-3.0, 9.19, -3.0), (3.0, 9.19, -3.0), UP)
    rivets(p, (-1.8, 8.62, -6.6), (1.8, 8.62, -6.6), 6, UP)


# ---------------------------------------------------------------- legs


def leg_spec(key):
    x, z = LEGS[key]
    sx = -1 if x < 0 else 1
    hip = (x, HIP_Y, z)
    knee = (x, 2.9, z - 0.25)
    ankle = (x, 0.9, z)

    def leg(p):
        drum(p, hip, 1.05, 1.6, "steel", "trim")
        tseg(p, hip, knee, 2.4, 2.4, 2.1, 2.1, "paint", pad=0.15, bevel=0.2)  # thick upper pillar
        tseg(p, hip, knee, 1.7, 0.3, 1.4, 0.3, "team", off0=1.25, off1=1.1, pad=-0.3, bevel=0.04)
        p.obox((x + sx * 1.1, 4.3, z), UP, (sx, 0, 0), 1.6, 1.8, 0.2, "trim", bevel=0.05)
        # the knee guard and the lower pillar
        p.prism_x([(z - 1.35, 2.2), (z - 0.9, 1.95), (z - 0.75, 3.0), (z - 1.0, 3.75), (z - 1.45, 3.5), (z - 1.6, 2.9)],
                  x - 1.0, x + 1.0, "trim", bevel=0.1)
        tseg(p, knee, ankle, 2.0, 2.0, 2.2, 2.2, "paint", pad=0.1, bevel=0.18)
        p.box((x, 2.1, z + 1.12), (1.0, 0.35, 0.04), "power")
        # the foot: a broad round pad, a rim, steel toenails at the front
        p.cylinder("y", (x, 0.35, z), 1.6, 0.7, 12, "dark")
        p.cylinder("y", (x, 0.82, z), 1.4, 0.24, 12, "trim")
        for k in (-1, 0, 1):
            a = math.radians(k * 32)
            c = (x + math.sin(a) * 1.55, 0.3, z - math.cos(a) * 1.55)
            p.obox(c, (math.cos(a), 0, math.sin(a)), (math.sin(a), 0, -math.cos(a)), 0.6, 0.45, 0.22, "steel", bevel=0.04)

    def det(p):
        rivets(p, (x + sx * 1.21, 5.0, z - 0.8), (x + sx * 1.21, 5.0, z + 0.8), 4, (sx, 0, 0))

    return unit.PieceSpec(f"leg{key}", "base", hip, leg, det)


# ---------------------------------------------------------------- turret and barrels


def build_turret(p):
    x, y, z = TURRET
    p.prism_y([(-2.3, -1.6), (2.3, -1.6), (2.7, -0.6), (2.6, 2.6), (1.8, 3.3), (-1.8, 3.3), (-2.6, 2.6), (-2.7, -0.6)],
              9.3, 11.1, "paint", bevel=0.18, top_scale=0.88, top_center=(0, z))
    p.prism_y([(-1.5, 0.2), (1.5, 0.2), (1.5, 2.6), (-1.5, 2.6)], 11.1, 11.16, "team", bevel=0.02)
    for sx in (-1, 1):
        p.obox((sx * 2.55, 10.2, 1.0), (0, 0, 1), (sx, 0.2, 0), 2.6, 1.2, 0.08, "team", bevel=0.03)
        p.box((sx * 2.68, 9.55, 1.0), (0.04, 0.12, 3.0), "light")
    p.box((0, 10.3, 3.42), (2.6, 0.8, 0.06), "grille")
    p.cylinder("y", (1.6, 11.6, 2.4), 0.06, 1.2, 6, "dark")  # antenna
    p.box((1.6, 12.25, 2.4), (0.14, 0.12, 0.14), "light")


def details_turret(p):
    rivets(p, (-1.4, 11.15, -0.6), (1.4, 11.15, -0.6), 6, UP)
    seam(p, (-2.2, 10.0, -1.62), (2.2, 10.0, -1.62), FWD)


def build_barrels(p):
    # the mantlet, then two long laser barrels in cooling shrouds
    p.prism_x(arch(GUN_Z - 1.0, GUN_Z + 1.2, 9.3, 11.0, steps=4, flat=0.4), -1.9, 1.9, "trim", bevel=0.12)
    for sx in (-1, 1):
        bx = sx * BARREL_X
        p.ocyl((bx, GUN_Y, GUN_Z - 0.9), FWD, 0.5, 1.2, 10, "dark")
        p.ocyl((bx, GUN_Y, GUN_Z - 2.0), FWD, 0.34, 4.0, 10, "steel")
        for k in range(3):  # cooling fins
            p.ocyl((bx, GUN_Y, GUN_Z - 2.5 - k * 0.7), FWD, 0.48, 0.18, 10, "trim")
        p.ocyl((bx, GUN_Y, MUZZLE_Z + 0.55), FWD, 0.46, 0.5, 10, "dark")
        p.ocyl((bx, GUN_Y, MUZZLE_Z + 0.05), FWD, 0.28, 0.04, 10, "weapon")
    p.box((0, 10.95, GUN_Z - 0.85), (1.2, 0.06, 0.04), "light")


def details_barrels(p):
    seam(p, (-1.8, 10.6, GUN_Z - 1.0), (1.8, 10.6, GUN_Z - 1.0), FWD)


unit.run(__file__, "chs_mammoth", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)]
         + [leg_spec(k) for k in ("FL", "FR", "BL", "BR")]
         + [unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
            unit.PieceSpec("barrels", "turret", (0.0, GUN_Y, GUN_Z), build_barrels, details_barrels)],
         attachments={"muzzle1": {"parent": "barrels", "at": [-BARREL_X, GUN_Y, MUZZLE_Z]},
                      "muzzle2": {"parent": "barrels", "at": [BARREL_X, GUN_Y, MUZZLE_Z]}},
         budget=5000,
         previews=[("35", (-24, 19, -29), (0, 5.5, -0.5), 50),
                   ("side", (34, 7, 0), (0, 5.5, 0), 50),
                   ("80", (0, 42, 8), (0, 5.0, 0), 50),
                   ("close", (-12, 11, -15), (0, 7.0, -3.0), 35)])
