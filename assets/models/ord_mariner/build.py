"""Mariner (Order amphibious bot, light laser, T2, footprint 1; batch 2 of
the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_mariner/build.py

From its blockout: a hull-like bot on armoured legs (tools/bots.py). The
`torso` (turns) is a sealed body with a raked boat bow and a lit visor,
team float tanks along its flanks, a snorkel at the back and a small laser
turret on top with a lit bore (`muzzle`). Order reads clean (M-14). Our own
design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.9, 0.0)
BODY = ((0, 3.6, 0.1), (2.0, 1.4, 1.9))
LX, LY = 0.3, 4.55


def build_base(p):
    p.box((0, 2.5, 0), (1.8, 0.8, 1.5), "dark", bevel=0.06)
    drum(p, (0, 2.85, 0), 0.6, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.prism_x([(-0.85, 2.95), (-0.85, 4.3), (-1.8, 3.4), (-1.6, 2.95)], -0.95, 0.95, "paint", bevel=0.06)
    k.visor(p, (0, 3.95, -1.15), 1.0, 0.2)
    for sx in (-1, 1):
        p.ocyl((sx * 1.3, 3.5, 1.1), k.FWD, 0.35, 2.0, 14, "team")
        p.ocyl((sx * 1.3, 3.5, -0.9), k.FWD, 0.35, 0.25, 14, "trim", radius2=0.15)
    p.ocyl((-0.6, 4.3, 0.7), k.UP, 0.12, 1.2, 10, "steel")
    p.ocyl((-0.6, 5.5, 0.7), k.FWD, 0.15, 0.3, 10, "trim")
    drum(p, (LX, 4.38, -0.2), 0.32, 0.2, "steel", "trim", axis="y")
    p.box((LX, LY, -0.2), (0.6, 0.4, 0.7), "paint", bevel=0.05)
    k.gun(p, LX, LY, -0.55, 0.95, 0.13)


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_mariner", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.3, 0.75, 0.6, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [LX, LY, -1.6]}},
         budget=2800,
         previews=k.previews(5.6))
