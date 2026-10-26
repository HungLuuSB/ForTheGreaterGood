"""Thug (Chaos assault bot, T1, footprint 1; S-181; tough, short-ranged):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_thug/build.py

From its approved blockout (2026-10-26): a stocky brawler. Big shapes
first: a wide pelvis on short thick strut legs (tools/bots.py, swinging
for the client's walk), the `torso` (turns, the def's piece): a wide slab
body with a team chest plate, a small head sunk between spiked shoulder
plates with an amber slit, a fist on the left and the plasma cannon as the
right forearm with jacket rings and a glowing mouth (`muzzle`). Chaos
reads crude and brutal (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

CX, CY = 1.9, 3.6  # the cannon's axis
TORSO = (0.0, 2.8, 0.0)


def build_base(p):
    p.box((0, 2.3, 0), (2.2, 0.8, 1.6), "dark", bevel=0.05)
    drum(p, (0, 2.75, 0), 0.75, 0.12, "steel", "trim", axis="y")


def details_base(p):
    pass


def build_torso(p):
    p.box((0, 3.8, 0), (3.0, 2.0, 2.4), "paint", bevel=0.12)
    p.box((0, 3.6, -1.22), (1.4, 0.7, 0.05), "team", bevel=0.01)
    p.box((0, 5.0, -0.3), (1.0, 0.7, 1.0), "paint", bevel=0.06)  # the sunk head
    p.box((0, 5.05, -0.82), (0.7, 0.15, 0.04), "head")
    for sx in (-1, 1):  # spiked shoulder plates
        p.prism_x([(-1.3, 4.7), (1.3, 4.7), (1.1, 5.3), (-1.0, 5.4)], sx * 1.0 - 0.6, sx * 1.0 + 0.6, "trim", bevel=0.06)
        p.ocyl((sx * 1.6, 5.3, -0.2), (sx * 0.3, 1.0, 0.0), 0.2, 0.8, 6, "steel", radius2=0.02)
        p.ocyl((sx * 1.3, 5.35, 0.6), (sx * 0.3, 1.0, 0.2), 0.16, 0.6, 6, "steel", radius2=0.02)
    p.box((1.52, 3.4, 0.6), (0.05, 0.8, 0.8), "power")
    # the left fist
    drum(p, (-1.65, 4.2, -0.2), 0.36, 0.4, "steel", "trim")
    p.box((-1.9, 3.3, -0.4), (0.9, 1.6, 0.9), "trim", bevel=0.08)
    # the cannon forearm
    drum(p, (1.65, 4.2, -0.2), 0.36, 0.4, "steel", "trim")
    p.box((CX, CY, -0.4), (1.0, 1.0, 1.4), "trim", bevel=0.08)
    p.ocyl((CX, CY, -1.1), (0, 0, -1), 0.42, 1.6, 12, "dark")
    for z in (-1.4, -2.1):
        p.ocyl((CX, CY, z), (0, 0, -1), 0.48, 0.14, 12, "steel")
    p.ocyl((CX, CY, -2.72), (0, 0, -1), 0.3, 0.05, 12, "weapon")


def details_torso(p):
    rivets(p, (-1.3, 3.0, -1.21), (1.3, 3.0, -1.21), 6, (0, 0, -1))
    for sx in (-1, 1):
        seam(p, (sx * 1.51, 3.8, -1.0), (sx * 1.51, 3.8, 1.0), (sx, 0, 0))


unit.run(__file__, "chs_thug", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + bots.legs(2.2, 0.95, 0.75, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [CX, CY, -2.85]}},
         budget=3000,
         previews=bots.previews(5.8))
