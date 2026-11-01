"""Newt (Chaos amphibious bot, laser and torpedo, T2, footprint 1; batch 2
of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_newt/build.py

From its blockout: squat and frog-wide on short strut legs (tools/bots.py).
The `torso` (turns): a wide flat body with a jutting jaw, float pods on its
flanks, two bulging amber eyes, a team plate on its back, a small laser
turret on top (`muzzle`) and a torpedo tube under the chin (`muzzle2`).
Chaos reads crude (M-14). Our own design. Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.4, 0.0)
BODY = ((0, 3.0, 0), (2.6, 1.2, 2.4))
LY = 3.85


def build_base(p):
    p.box((0, 2.0, 0), (2.2, 0.75, 1.6), "dark", bevel=0.05)
    drum(p, (0, 2.35, 0), 0.7, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    p.prism_x([(-1.15, 2.4), (-1.15, 3.2), (-1.95, 2.75), (-1.9, 2.4)], -1.2, 1.2, "paint", bevel=0.05)
    p.box((0, 3.62, 0.4), (1.2, 0.04, 0.8), "team", bevel=0.01)
    for sx in (-1, 1):
        p.ocyl((sx * 1.6, 2.85, 1.2), k.FWD, 0.45, 2.2, 14, "dark")
        p.ocyl((sx * 1.6, 2.85, -1.0), k.FWD, 0.45, 0.3, 14, "trim", radius2=0.2)
        p.ocyl((sx * 0.7, 3.55, -0.9), k.UP, 0.26, 0.3, 12, "trim", radius2=0.2)
        p.ocyl((sx * 0.7, 3.62, -1.13), k.FWD, 0.15, 0.04, 12, "head")
    drum(p, (0, 3.62, -0.1), 0.35, 0.15, "steel", "trim", axis="y")
    p.box((0, LY, -0.1), (0.6, 0.4, 0.8), "trim", bevel=0.04)
    k.gun(p, 0, LY, -0.5, 1.2, 0.14)
    p.ocyl((0, 2.5, -0.7), k.FWD, 0.3, 1.35, 12, "steel")
    p.ocyl((0, 2.5, -2.05), k.FWD, 0.2, 0.03, 12, "dark")


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_newt", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(1.8, 1.0, 0.7, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, LY, -1.8]},
                      "muzzle2": {"parent": "torso", "at": [0.0, 2.5, -2.15]}},
         budget=3400,
         previews=k.previews(4.4))
