"""Glint (Order scout bot, T1, footprint 1; S-181): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_glint/build.py

From its approved blockout (2026-10-26): a slim fast runner on long legs.
Big shapes first: a compact pelvis on two armored legs (tools/bots.py:
`thighL/R`, `shinL/R`, `footL/R`, swinging for the client's walk), the
`torso` (turns, the def's piece) a sleek wedge cockpit with a glazed front,
a team stripe and a dorsal fin, and an `arm_l` / `arm_r` either side
(children of the torso), each a slim armored arm ending in a laser tube
with a glowing lens (`arm_l_muzzle` / `arm_r_muzzle`, firing in turn).
Order reads clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

AY = 3.9  # the arms' axis height
ARM = 1.2  # the arms' offset either side
HIP_Y, HIP_X, THICK = 2.8, 0.55, 0.45
TORSO = (0.0, 3.3, 0.0)
SIDE = [(-1.05, 3.3), (0.85, 3.3), (0.95, 4.25), (0.55, 4.65), (-0.35, 4.7), (-1.15, 4.05)]  # (z, y)


def build_base(p):
    p.box((0, 2.95, 0.0), (1.4, 0.6, 1.0), "dark", bevel=0.06)
    for sx in (-1, 1):
        p.box((sx * 0.62, 3.0, 0.0), (0.18, 0.7, 1.1), "paint", bevel=0.05)
    p.box((0, 2.95, 0.52), (0.8, 0.3, 0.04), "light")
    drum(p, (0, 3.22, 0), 0.5, 0.14, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-0.5, 2.7, -0.51), (0.5, 2.7, -0.51), 3, (0, 0, -1))


def build_torso(p):
    p.prism_x(SIDE, -0.85, 0.85, "paint", bevel=0.1)
    p.obox((0, 4.3, -0.98), (1, 0, 0), (0, 0.4, -1), 1.3, 0.75, 0.05, "glass")  # the glazed front
    p.obox((0, 4.05, -1.06), (1, 0, 0), (0, 0.4, -1), 0.5, 0.12, 0.03, "head")  # the sensor eye
    p.box((0, 4.72, 0.15), (0.4, 0.04, 1.2), "team", bevel=0.01)
    p.prism_x([(0.1, 4.68), (1.0, 4.62), (0.85, 5.0)], -0.05, 0.05, "trim")  # dorsal fin
    for sx in (-1, 1):
        p.box((sx * 0.87, 3.8, 0.3), (0.04, 0.5, 1.0), "grille")
        p.box((sx * 0.86, 4.25, -0.3), (0.03, 0.08, 0.9), "light")
    p.box((0, 3.6, 1.0), (1.2, 0.6, 0.3), "trim", bevel=0.04)  # power pack


def details_torso(p):
    for sx in (-1, 1):
        seam(p, (sx * 0.86, 3.5, -0.9), (sx * 0.86, 3.5, 0.8), (sx, 0, 0))
    seam(p, (-0.6, 4.69, -0.2), (0.6, 4.69, -0.2), UP)


def arm(sx):
    x = sx * ARM

    def build(p):
        drum(p, (sx * 1.0, AY, 0.2), 0.32, 0.36, "steel", "trim")
        p.box((x, AY, -0.45), (0.5, 0.52, 1.7), "paint", bevel=0.07)
        p.box((x + sx * 0.26, AY, -0.45), (0.04, 0.12, 1.2), "light")
        p.ocyl((x, AY, -1.3), (0, 0, -1), 0.17, 0.9, 10, "dark")
        for z in (-1.55, -1.95):
            p.ocyl((x, AY, z), (0, 0, -1), 0.21, 0.08, 10, "steel")
        p.ocyl((x, AY, -2.2), (0, 0, -1), 0.13, 0.06, 10, "weapon")

    def details(p):
        seam(p, (x - 0.25, AY + 0.27, -1.1), (x + 0.25, AY + 0.27, -1.1), UP)
    return build, details


arm_l, arm_l_details = arm(-1)
arm_r, arm_r_details = arm(1)

unit.run(__file__, "ord_glint", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("arm_l", "torso", (-1.0, AY, 0.2), arm_l, arm_l_details),
                 unit.PieceSpec("arm_r", "torso", (1.0, AY, 0.2), arm_r, arm_r_details)]
         + bots.legs(HIP_Y, HIP_X, THICK, "order"),
         attachments={"arm_l_muzzle": {"parent": "arm_l", "at": [-ARM, AY, -2.35]},
                      "arm_r_muzzle": {"parent": "arm_r", "at": [ARM, AY, -2.35]}},
         budget=3000,
         previews=bots.previews(5.2))
