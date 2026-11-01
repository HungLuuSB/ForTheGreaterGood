"""Scaler (Order all-terrain rocket spider, T2, footprint 1; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_scaler/build.py

From its blockout: a flat armoured body on six long jointed legs, knees
high over it and claw tips (tools/botkit.py `spider`, the client's tripod
gait), a raked glacis with a lit sensor band; on its back the `torso`
(turns): a team rocket box with six lit tubes (`muzzle`). Order reads
clean (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402

TORSO = (0.0, 2.7, 0.1)


def build_base(p):
    p.box((0, 2.2, 0), (1.8, 0.9, 2.6), "paint", bevel=0.1)
    p.prism_x([(-1.3, 1.75), (-1.3, 2.65), (-2.0, 2.2), (-1.85, 1.85)], -0.85, 0.85, "paint", bevel=0.05)
    p.box((0, 2.35, -1.75), (0.8, 0.12, 0.04), "head")
    p.box((0, 1.7, 0), (1.5, 0.15, 2.2), "trim")
    p.box((0, 2.66, 0.85), (1.2, 0.04, 0.6), "team")
    drum(p, (0, 2.68, 0.1), 0.55, 0.06, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-0.7, 1.95, 1.31), (0.7, 1.95, 1.31), 4, (0, 0, 1))


def build_torso(p):
    p.box((0, 3.15, 0.1), (1.6, 0.9, 1.6), "team", bevel=0.07)
    p.box((0, 3.15, -0.72), (1.45, 0.75, 0.1), "dark", bevel=0.02)
    k.tubes(p, 0, 3.15, -0.78, 3, 2, 0.42, 0.14)
    p.box((0, 3.62, 0.3), (1.0, 0.04, 0.8), "trim")
    for sx in (-1, 1):
        p.box((sx * 0.81, 3.15, 0.2), (0.03, 0.1, 1.0), "light")


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_scaler", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none)]
         + k.spider(6, 0.9, 2.2, 2.3, 3.7, 3.4, 0.3, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, 3.15, -0.95]}},
         budget=4000,
         previews=k.previews(3.9, 6.9))
