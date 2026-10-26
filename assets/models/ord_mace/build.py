"""Mace (Order skirmisher bot, T1, footprint 1; S-181; outranges T1 tanks
with slow plasma): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_mace/build.py

From its approved blockout (2026-10-26). Big shapes first: a pelvis on
armored legs (tools/bots.py, swinging for the client's walk), the `torso`
(turns, the def's piece): an upright armored body with a team chest plate,
a sensor head on the left, a short left arm, a glowing plasma cell on the
back, and over the right shoulder the long plasma barrel in an armored
housing with glowing coils and a muzzle ring (`muzzle` at its mouth).
Order reads clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

BX, BY = 1.15, 5.0  # the barrel's axis
TORSO = (0.0, 3.3, 0.0)


def build_base(p):
    p.box((0, 2.9, 0), (1.8, 0.8, 1.4), "dark", bevel=0.06)
    drum(p, (0, 3.25, 0), 0.6, 0.14, "steel", "trim", axis="y")


def details_base(p):
    pass


def build_torso(p):
    p.box((0, 4.2, 0), (2.2, 1.8, 1.8), "paint", bevel=0.14)
    p.box((0, 3.4, 0), (1.9, 0.14, 1.6), "trim")
    p.box((-0.4, 4.2, -0.92), (0.8, 0.6, 0.05), "team", bevel=0.01)
    p.box((-0.55, 5.4, -0.2), (0.9, 0.6, 0.9), "paint", bevel=0.06)  # the sensor head
    p.box((-0.55, 5.45, -0.67), (0.7, 0.18, 0.04), "head")
    p.box((0.3, 4.4, 1.2), (1.2, 1.2, 0.6), "trim", bevel=0.05)  # the plasma cell
    p.box((0.3, 4.4, 1.51), (0.8, 0.8, 0.04), "power")
    drum(p, (-1.25, 4.6, 0), 0.3, 0.4, "steel", "trim")
    p.box((-1.4, 3.9, 0), (0.5, 1.3, 0.5), "paint", bevel=0.05)
    for sx in (-1, 1):
        p.box((sx * 1.11, 4.2, 0.2), (0.04, 0.12, 1.2), "light")
    # the barrel housing over the right shoulder, the long barrel, coils, the muzzle ring
    p.box((BX, BY, 0.2), (0.9, 0.9, 1.8), "paint", bevel=0.08)
    p.box((BX, BY + 0.46, 0.2), (0.6, 0.05, 1.2), "team")
    p.ocyl((BX, BY, -0.7), (0, 0, -1), 0.24, 4.4, 12, "steel")
    for z in (-1.6, -2.6):
        p.ocyl((BX, BY, z), (0, 0, -1), 0.34, 0.2, 12, "power")
    p.ocyl((BX, BY, -3.6), (0, 0, -1), 0.3, 0.14, 12, "trim")
    p.ocyl((BX, BY, -4.8), (0, 0, -1), 0.32, 0.4, 12, "dark")
    p.ocyl((BX, BY, -5.18), (0, 0, -1), 0.2, 0.04, 10, "weapon")


def details_torso(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.11, 4.7, -0.7), (sx * 1.11, 4.7, 0.8), (sx, 0, 0))
    rivets(p, (-0.8, 3.6, -0.91), (0.8, 3.6, -0.91), 5, (0, 0, -1))


unit.run(__file__, "ord_mace", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + bots.legs(2.7, 0.7, 0.55, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [BX, BY, -5.3]}},
         budget=3000,
         previews=bots.previews(5.8))
