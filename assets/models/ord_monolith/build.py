"""Monolith (Order all-terrain heavy plasma artillery, T3, footprint 3;
batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_monolith/build.py

From its blockout, laid out at bot size and scaled x2.0 (unit.run `scale`;
the blockout scales the same). A broad armoured body with a dark skirt on
four massive jointed legs, knees high and claw feet (tools/botkit.py
`spider`, the client's diagonal gait); on top the `torso` (turns), a team
turret with a raked glacis and radiators, and in it the `barrel` (pitches):
a long heavy plasma cannon with a recoil sleeve, lit coils and a muzzle
brake (`muzzle`). Order reads clean and heavy (M-14). Our own design.
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import seam  # noqa: E402

S = 2.0
TORSO = (0.0, 3.15, 0.3)
BARREL = (0.0, 3.8, -0.3)
BY = 3.8


def build_base(p):
    p.box((0, 2.6, 0), (2.6, 1.1, 3.0), "paint", bevel=0.12)
    p.box((0, 2.0, 0), (2.8, 0.4, 3.2), "dark", bevel=0.05)
    p.prism_x([(-1.5, 2.1), (-1.5, 3.1), (-2.0, 2.5), (-1.9, 2.1)], -1.2, 1.2, "paint", bevel=0.05)
    p.box((0, 2.75, -1.86), (1.4, 0.12, 0.04), "head")
    for sx in (-1, 1):
        p.box((sx * 1.31, 2.65, 0.2), (0.04, 0.5, 1.8), "team")
    drum(p, (0, 3.17, 0.3), 1.0, 0.05, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-1.0, 2.3, 1.51), (1.0, 2.3, 1.51), 5, (0, 0, 1))
    for sx in (-1, 1):
        seam(p, (sx * 1.31, 2.9, -1.2), (sx * 1.31, 2.9, 1.2), (sx, 0, 0))


def build_torso(p):
    p.box((0, 3.65, 0.3), (2.2, 1.0, 2.4), "team", bevel=0.1)
    p.prism_x([(-0.9, 3.15), (-0.9, 4.1), (-1.6, 3.6), (-1.6, 3.15)], -1.1, 1.1, "paint", bevel=0.05)
    p.box((0, 4.17, 0.6), (1.6, 0.06, 1.4), "trim")
    for x in (-0.5, 0.0, 0.5):
        p.box((x, 4.22, 0.6), (0.3, 0.06, 1.2), "dark")
    p.box((0, 3.65, 1.52), (1.6, 0.7, 0.06), "trim")
    p.box((0, 3.85, 1.56), (1.0, 0.1, 0.03), "power")
    for sx in (-1, 1):
        p.box((sx * 1.11, 3.65, 0.3), (0.03, 0.1, 1.8), "light")


def build_barrel(p):
    drum(p, BARREL, 0.45, 1.3, "steel", "trim")
    p.ocyl((0, BY, -0.3), k.FWD, 0.42, 1.2, 16, "paint")
    p.ocyl((0, BY, -1.5), k.FWD, 0.3, 2.8, 16, "steel")
    for z in (-1.9, -2.7):
        p.ocyl((0, BY, z), k.FWD, 0.4, 0.15, 16, "power")
    p.ocyl((0, BY, -4.2), k.FWD, 0.42, 0.45, 16, "dark")
    for sx in (-1, 1):
        p.box((sx * 0.35, BY, -4.4), (0.12, 0.3, 0.25), "dark")
    p.ocyl((0, BY, -4.62), k.FWD, 0.24, 0.03, 14, "weapon")


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_monolith", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none),
                 unit.PieceSpec("barrel", "torso", BARREL, build_barrel, none)]
         + k.spider(4, 1.2, 2.6, 3.0, 4.0, 3.9, 0.5, "order"),
         attachments={"muzzle": {"parent": "barrel", "at": [0.0, BY, -4.7]}},
         budget=5000, tex=2048, scale=(S, S, S),
         previews=k.previews(4.4 * S, 7.8 * S))
