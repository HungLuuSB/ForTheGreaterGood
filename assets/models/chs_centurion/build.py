"""Centurion (Chaos heavy laser bot, T2, footprint 2; S-181; very tough, a
long red laser that cuts a line of light units): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_centurion/build.py

From its approved blockout (2026-10-26): a tall armored knight, 12 studs.
Big shapes first: a pelvis with a front tasset on long strut legs
(tools/bots.py, swinging for the client's walk), the `torso` (turns, the
def's piece): a broad slab chest with a team plate, spiked shoulder
plates, a helmet head with a red slit and a crest, a slab shield on the
left arm with a team panel, and the laser lance as the right forearm: a
housing, a long ringed lance and a glowing lens at the tip (`muzzle`).
Chaos reads crude and brutal (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

LX, LY = 3.0, 7.2  # the lance's axis
TORSO = (0.0, 6.6, 0.0)


def build_base(p):
    p.box((0, 5.9, 0), (3.6, 1.4, 2.4), "dark", bevel=0.08)
    p.prism_x([(-1.3, 5.6), (-1.1, 6.4), (-1.6, 4.0)], -1.5, 1.5, "trim", bevel=0.04)  # the tasset
    drum(p, (0, 6.65, 0), 1.3, 0.2, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-1.4, 5.5, -1.21), (1.4, 5.5, -1.21), 5, (0, 0, -1))


def build_torso(p):
    p.prism_x([(-1.5, 6.8), (1.5, 6.8), (1.6, 9.8), (0.9, 10.4), (-1.0, 10.4), (-1.7, 9.4)], -2.3, 2.3, "paint", bevel=0.14)
    p.box((0, 8.8, -1.56), (2.0, 1.2, 0.05), "team", bevel=0.01)
    p.box((0, 7.4, -1.52), (2.6, 0.14, 0.05), "power")
    # the helmet head: a red slit, a crest
    p.box((0, 11.1, -0.3), (1.3, 1.4, 1.5), "paint", bevel=0.1)
    p.box((0, 11.2, -1.07), (0.9, 0.2, 0.05), "weapon")
    p.prism_x([(-0.8, 11.8), (0.8, 11.8), (0.4, 12.6)], -0.15, 0.15, "steel")
    # spiked shoulder plates
    for sx in (-1, 1):
        p.obox((sx * 3.0, 10.1, 0), (1, sx * -0.21, 0), (0, 0, 1), 1.8, 1.4, 2.6, "trim", bevel=0.1)
        p.ocyl((sx * 3.3, 10.7, -0.4), (sx * 0.3, 1.0, 0), 0.28, 1.3, 6, "steel", radius2=0.02)
        p.ocyl((sx * 3.1, 10.8, 0.6), (sx * 0.2, 1.0, 0.2), 0.22, 1.0, 6, "steel", radius2=0.02)
    # the left arm with its shield
    drum(p, (-2.6, 9.2, -0.2), 0.6, 0.8, "steel", "trim")
    p.box((-3.0, 8.2, -0.2), (1.0, 3.0, 1.0), "trim", bevel=0.06)
    p.box((-3.7, 7.6, -0.8), (0.4, 4.4, 3.0), "steel", bevel=0.08)
    p.box((-3.92, 7.8, -0.8), (0.05, 1.6, 1.4), "team", bevel=0.01)
    # the right arm and the laser lance
    drum(p, (2.6, 9.2, -0.2), 0.6, 0.8, "steel", "trim")
    p.box((LX, 8.6, -0.2), (1.0, 2.6, 1.0), "trim", bevel=0.06)
    p.box((LX, LY, -0.6), (1.2, 1.2, 2.0), "dark", bevel=0.08)
    p.ocyl((LX, LY, -1.6), (0, 0, -1), 0.35, 5.6, 12, "steel")
    for z in (-3.0, -4.6, -6.0):
        p.ocyl((LX, LY, z), (0, 0, -1), 0.5, 0.25, 12, "dark")
    p.ocyl((LX, LY, -7.22), (0, 0, -1), 0.28, 0.06, 12, "weapon")


def details_torso(p):
    for sx in (-1, 1):
        seam(p, (sx * 2.31, 8.0, -1.2), (sx * 2.31, 8.0, 1.2), (sx, 0, 0))
    rivets(p, (-1.4, 10.0, -1.4), (1.4, 10.0, -1.4), 6, (0, 0.3, -1))


unit.run(__file__, "chs_centurion", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + bots.legs(5.6, 1.4, 1.1, "chaos", foot_scale=1.2),
         attachments={"muzzle": {"parent": "torso", "at": [LX, LY, -7.4]}},
         budget=5000,
         previews=bots.previews(12.6))
