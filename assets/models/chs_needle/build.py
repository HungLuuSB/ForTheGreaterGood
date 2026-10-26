"""Needle (Chaos anti-air bot, T1, footprint 1; S-181): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_needle/build.py

From its approved blockout (2026-10-26): a hunched bot. Big shapes first:
a pelvis on bowed strut legs (tools/bots.py, swinging for the client's
walk), the `torso` (turns, the def's piece): a slab body with an amber eye
slit, a team flank plate and two stub arms, and on its back the
`launcher` (pitches, the def's piece): a rack plate carrying three bare
missile tubes over the shoulders with amber-lit mouths and white radome
noses (`muzzle` at the mouths). Chaos reads crude (M-14). Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

LY, LZ = 5.1, 0.4  # the launcher's tubes
TORSO = (0.0, 2.8, 0.0)
LAUNCHER = (0.0, LY - 0.5, LZ + 0.6)


def build_base(p):
    p.box((0, 2.4, 0), (1.8, 0.8, 1.4), "dark", bevel=0.05)
    drum(p, (0, 2.75, 0), 0.6, 0.12, "steel", "trim", axis="y")


def details_base(p):
    pass


def build_torso(p):
    p.box((0, 3.6, 0), (2.2, 1.6, 1.8), "paint", bevel=0.1)
    p.box((0, 3.9, -0.92), (0.9, 0.22, 0.05), "head")
    p.box((0, 3.9, -0.94), (1.3, 0.45, 0.03), "dark")
    p.box((1.12, 3.6, 0), (0.05, 0.8, 1.2), "team", bevel=0.01)
    for sx in (-1, 1):
        drum(p, (sx * 1.2, 4.0, -0.1), 0.28, 0.36, "steel", "trim")
        p.box((sx * 1.4, 3.3, -0.1), (0.5, 1.3, 0.5), "trim", bevel=0.04)
    for sx in (-1, 1):
        drum(p, (sx * 0.8, LY - 0.5, LZ + 0.6), 0.22, 0.3, "steel", "trim")  # the rack's hinges


def details_torso(p):
    rivets(p, (-0.9, 3.0, -0.91), (0.9, 3.0, -0.91), 5, (0, 0, -1))


def build_launcher(p):
    p.box((0, LY - 0.55, LZ + 0.3), (2.0, 0.4, 1.6), "trim", bevel=0.05)
    for x in (-0.65, 0.0, 0.65):
        p.ocyl((x, LY, LZ + 1.0), (0, 0, -1), 0.26, 2.0, 10, "steel")
        p.ocyl((x, LY, LZ - 0.95), (0, 0, -1), 0.18, 0.06, 10, "light")
        p.ocyl((x, LY, LZ - 0.7), (0, 0, -1), 0.2, 0.25, 8, "radome", radius2=0.05)
        p.box((x, LY - 0.3, LZ + 0.3), (0.12, 0.3, 0.2), "dark")


def details_launcher(p):
    pass


unit.run(__file__, "chs_needle", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("launcher", "torso", LAUNCHER, build_launcher, details_launcher)]
         + bots.legs(2.3, 0.75, 0.6, "chaos"),
         attachments={"muzzle": {"parent": "launcher", "at": [0.0, LY, LZ - 1.1]}},
         budget=3200,
         previews=bots.previews(5.8))
