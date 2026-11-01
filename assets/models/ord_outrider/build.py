"""Outrider (Order fast raider bot, T2, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_outrider/build.py

From its blockout: long legs (tools/bots.py) under a small body leaning
forward. The `torso` (turns): a wedge-nosed team-capped body with a lit
eye band, a tall team fin on its back and a light gun under each side
(`muzzle` right, `muzzle2` left). Order reads clean (M-14). Our own design.
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.5, 0.0)
GX, GY = 0.85, 3.75


def build_base(p):
    p.box((0, 3.1, 0), (1.2, 0.75, 1.1), "dark", bevel=0.05)
    drum(p, (0, 3.45, 0), 0.45, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    prof = [(-1.9, 3.75), (-1.1, 4.45), (0.75, 4.55), (0.75, 3.55), (-1.1, 3.5)]
    p.prism_x(prof, -0.7, 0.7, "paint", bevel=0.08)
    p.prism_x([(-1.75, 3.95), (-1.1, 4.5), (-0.1, 4.6), (-0.1, 4.52), (-1.1, 4.42), (-1.68, 3.93)], -0.55, 0.55, "team")
    p.box((0, 4.15, -1.38), (0.9, 0.12, 0.04), "head")
    p.prism_x([(0.0, 4.55), (0.75, 4.55), (0.75, 5.35)], -0.05, 0.05, "team", bevel=0.01)
    p.box((0, 4.0, 0.85), (1.0, 0.7, 0.25), "trim", bevel=0.04)
    p.box((0, 4.15, 0.99), (0.6, 0.08, 0.03), "power")
    for sx in (-1, 1):
        p.box((sx * GX, GY, -0.4), (0.3, 0.3, 0.6), "trim", bevel=0.03)
        k.gun(p, sx * GX, GY, -0.6, 1.2, 0.11)
        p.box((sx * 0.71, 4.0, -0.4), (0.03, 0.08, 1.2), "light")


def details_torso(p):
    pass


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_outrider", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.9, 0.55, 0.45, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [GX, GY, -1.9]},
                      "muzzle2": {"parent": "torso", "at": [-GX, GY, -1.9]}},
         budget=2600,
         previews=k.previews(5.4))
