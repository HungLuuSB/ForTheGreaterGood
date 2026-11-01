"""Culverin (Order mortar bot, T2, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_culverin/build.py

From its blockout: a squat, wide bot on armoured legs (tools/bots.py). The
`torso` (turns) is a broad low body behind a raked team shield with a lit
visor slit; on its back a cradle holds the `barrel` (pitches): a short fat
mortar with a recoil sleeve and a lit mouth ring (`muzzle`). Order reads
clean (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.8, 0.0)
BODY = ((0, 3.5, 0), (2.4, 1.4, 2.2))
PIVOT = (0.0, 4.5, 0.5)
D = (0.0, math.sin(math.radians(45)), -math.cos(math.radians(45)))


def build_base(p):
    p.box((0, 2.4, 0), (2.0, 0.8, 1.6), "dark", bevel=0.06)
    drum(p, (0, 2.75, 0), 0.7, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.obox((0, 3.5, -1.25), (1, 0, 0), (0, 0.45, -1), 2.3, 1.4, 0.18, "team", bevel=0.04)
    p.box((0, 3.95, -1.18), (1.0, 0.16, 0.04), "head")
    p.box((0, 4.3, 0.5), (1.3, 0.3, 1.3), "trim", bevel=0.04)
    for sx in (-1, 1):
        p.box((sx * 0.55, 4.55, 0.5), (0.2, 0.6, 0.9), "paint", bevel=0.03)
    p.box((0, 3.6, 1.15), (1.6, 0.9, 0.3), "trim", bevel=0.04)
    for x in (-0.5, 0.0, 0.5):
        p.ocyl((x, 3.6, 1.3), (0, 0, 1), 0.16, 0.2, 10, "steel")


def details_torso(p):
    k.shell_details(p, *BODY)


def build_barrel(p):
    c, d = lib.vec(PIVOT), lib.vec(D)
    drum(p, PIVOT, 0.35, 0.95, "steel", "trim")
    p.ocyl(tuple(c - d * 0.3), D, 0.48, 1.0, 16, "paint")
    p.ocyl(tuple(c + d * 0.7), D, 0.4, 1.3, 16, "steel")
    p.ocyl(tuple(c + d * 1.8), D, 0.5, 0.25, 16, "trim")
    p.ocyl(tuple(c + d * 2.03), D, 0.32, 0.03, 16, "weapon")


none = lambda p: None  # noqa: E731
mouth = lib.vec(PIVOT) + lib.vec(D) * 2.15

unit.run(__file__, "ord_culverin", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("barrel", "torso", PIVOT, build_barrel, none)]
         + k.biped(2.2, 0.9, 0.7, "order"),
         attachments={"muzzle": {"parent": "barrel", "at": [mouth.x, mouth.y, mouth.z]}},
         budget=3000,
         previews=k.previews(6.2))
