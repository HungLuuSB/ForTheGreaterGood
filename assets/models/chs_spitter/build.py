"""Spitter (Chaos mortar bot, T2, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_spitter/build.py

From its blockout: squat and low on thick strut legs (tools/bots.py), its
head jutting in front. The `torso` (turns) carries on its back an ammo
drum and, in a cradle beside it, the `barrel` (pitches): a fat mortar tube
with a reinforcing band and a lit mouth (`muzzle`). Chaos reads crude
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum  # noqa: E402

TORSO = (0.0, 2.6, 0.0)
BODY = ((0, 3.25, 0), (2.3, 1.3, 2.1))
PIVOT = (0.5, 4.2, 0.5)
D = (0.0, math.sin(math.radians(50)), -math.cos(math.radians(50)))


def build_base(p):
    p.box((0, 2.2, 0), (2.0, 0.8, 1.6), "dark", bevel=0.05)
    drum(p, (0, 2.55, 0), 0.7, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (0, 3.4, -1.3), (0.8, 0.45, 0.7), "chaos")
    p.box((0, 2.9, -1.07), (1.2, 0.4, 0.04), "team", bevel=0.01)
    drum(p, (-0.75, 4.35, 0.5), 0.45, 1.0, "dark", "steel")
    cable(p, [(-0.5, 4.1, 0.1), (0.0, 4.0, 0.0), (0.3, 4.1, 0.2)], r=0.08)
    p.box((0.5, 4.0, 0.5), (1.0, 0.3, 1.0), "trim", bevel=0.03)
    for sx in (-1, 1):
        p.box((0.5 + sx * 0.55, 4.25, 0.5), (0.12, 0.6, 0.8), "trim", bevel=0.02)
        p.ocyl((sx * 1.0, 3.9, -0.6), k.UP, 0.13, 0.5, 6, "steel", radius2=0.02)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_barrel(p):
    c, d = lib.vec(PIVOT), lib.vec(D)
    drum(p, PIVOT, 0.32, 0.95, "steel", "trim")
    p.ocyl(tuple(c - d * 0.2), D, 0.5, 1.9, 16, "steel")
    p.ocyl(tuple(c + d * 0.5), D, 0.56, 0.3, 16, "paint")
    p.ocyl(tuple(c + d * 1.55), D, 0.58, 0.18, 16, "trim")
    p.ocyl(tuple(c + d * 1.72), D, 0.36, 0.03, 16, "weapon")


none = lambda p: None  # noqa: E731
mouth = lib.vec(PIVOT) + lib.vec(D) * 1.85

unit.run(__file__, "chs_spitter", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("barrel", "torso", PIVOT, build_barrel, none)]
         + k.biped(2.0, 0.9, 0.75, "chaos"),
         attachments={"muzzle": {"parent": "barrel", "at": [mouth.x, mouth.y, mouth.z]}},
         budget=3400,
         previews=k.previews(6.0))
