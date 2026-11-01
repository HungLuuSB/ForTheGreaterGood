"""Skyguard (Order amphibious anti-air bot, T2, footprint 1; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_skyguard/build.py

From its blockout: a rounded, sealed bot on armoured legs (tools/bots.py)
with team float collars at the hips. The `torso` (turns) is a body with a
domed top and a lit visor band; across its shoulders the `launcher`
(pitches) carries two missile pods, four lit cells on each face (`muzzle`
on the right pod). Order reads clean (M-14). Our own design. Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.2, 0.0)
BODY = ((0, 4.05, 0), (2.2, 1.7, 2.0))
LAUNCHER = (0.0, 5.1, 0.2)
PX, PY = 1.6, 5.1


def build_base(p):
    p.box((0, 2.8, 0), (2.0, 0.8, 1.6), "dark", bevel=0.06)
    drum(p, (0, 3.15, 0), 0.7, 0.12, "steel", "trim", axis="y")
    for sx in (-1, 1):
        p.ocyl((sx * 1.45, 2.9, 0.9), k.FWD, 0.4, 1.8, 14, "team")
        p.ocyl((sx * 1.45, 2.9, -0.9), k.FWD, 0.4, 0.2, 14, "trim", radius2=0.2)


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.ocyl((0, 4.85, 0), k.UP, 1.0, 0.4, 18, "paint", radius2=0.65)
    k.visor(p, (0, 4.45, -1.03), 1.2, 0.22)
    p.box((0, 3.85, -1.02), (1.3, 0.45, 0.04), "team", bevel=0.01)
    drum(p, (0, 4.85, 0.2), 0.3, 2.0, "steel", "trim")
    for sx in (-1, 1):
        p.box((sx * 1.2, 3.9, 0), (0.3, 1.0, 1.2), "trim", bevel=0.04)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_launcher(p):
    p.box((0, PY, 0.2), (2.3, 0.35, 0.5), "trim", bevel=0.04)
    for sx in (-1, 1):
        x = sx * PX
        p.box((x, PY, 0), (0.9, 1.0, 1.6), "paint", bevel=0.07)
        p.box((x + sx * 0.46, PY, 0), (0.04, 0.6, 1.2), "team")
        p.box((x, PY, -0.78), (0.8, 0.9, 0.06), "dark", bevel=0.02)
        k.tubes(p, x, PY, -0.82, 2, 2, 0.4, 0.13)
        p.box((x, PY + 0.52, 0.3), (0.5, 0.04, 0.6), "light")


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_skyguard", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("launcher", "torso", LAUNCHER, build_launcher, none)]
         + k.biped(2.6, 0.8, 0.65, "order"),
         attachments={"muzzle": {"parent": "launcher", "at": [PX, PY, -0.95]}},
         budget=3000,
         previews=k.previews(5.7))
