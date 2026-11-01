"""Petard (Order rocket bot, T1, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_petard/build.py

From its blockout: an upright bot on armoured legs (tools/bots.py). The
`torso` (turns) carries a square team rocket pod on the right shoulder,
four tubes lit on its face (`muzzle`), a sensor head, a short left arm and
a team chest plate. Order reads clean (M-14). Our own design. Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402

TORSO = (0.0, 3.1, 0.0)
BODY = ((0, 3.9, 0), (2.0, 1.6, 1.7))
POD = (1.5, 4.9, 0.1)


def build_base(p):
    p.box((0, 2.7, 0), (1.8, 0.8, 1.4), "dark", bevel=0.06)
    drum(p, (0, 3.05, 0), 0.6, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.box((-0.3, 4.0, -0.88), (0.9, 0.5, 0.04), "team", bevel=0.01)
    k.head(p, (-0.2, 4.98, -0.1), (0.8, 0.55, 0.8), "order")
    x, y, z = POD
    p.box(POD, (1.4, 1.3, 1.8), "team", bevel=0.08)
    p.box((x, y, z - 0.86), (1.25, 1.15, 0.12), "dark", bevel=0.03)
    p.box((x + 0.71, y, z + 0.2), (0.03, 0.9, 0.08), "light")
    k.tubes(p, x, y, z - 0.92, 2, 2, 0.5, 0.18)
    drum(p, (0.85, 4.6, 0.1), 0.35, 0.3, "steel", "trim")
    p.box((-1.25, 3.8, 0), (0.45, 1.1, 0.5), "trim", bevel=0.05)
    drum(p, (-1.1, 4.3, 0), 0.22, 0.25, "steel", "trim")
    p.box((0, 3.9, 0.95), (1.2, 0.9, 0.25), "trim", bevel=0.04)


def details_torso(p):
    k.shell_details(p, *BODY)
    x, y, z = POD
    rivets(p, (x - 0.5, y + 0.66, z - 0.6), (x - 0.5, y + 0.66, z + 0.6), 4, k.UP)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_petard", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.5, 0.7, 0.55, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [POD[0], POD[1], POD[2] - 1.05]}},
         budget=2600,
         previews=k.previews(5.7))
