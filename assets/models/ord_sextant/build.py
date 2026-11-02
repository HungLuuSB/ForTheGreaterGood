"""Sextant (Order radar bot, T2, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sextant/build.py

From its blockout: a compact bot on armoured legs (tools/bots.py). The
`torso` (turns) carries a mast on its back and on top the `radar` (a
client piece that turns): a big tilted dish with a team face, a rim and a
lit feed horn on a strut. Order reads clean (M-14). Our own design.
Writes export/ through tools/unit.py.
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
BODY = ((0, 3.45, 0), (1.6, 1.3, 1.4))
RADAR = (0.0, 6.1, 0.6)
TILT = math.radians(25)
N = (0.0, math.cos(TILT), -math.sin(TILT))  # the dish faces up and forward


def build_base(p):
    p.box((0, 2.4, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 2.75, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order", team_face=(0.9, 0.45, 3.5))
    k.head(p, (0, 4.33, -0.2), (0.8, 0.45, 0.7), "order")
    p.box((0, 3.6, 0.85), (1.2, 1.0, 0.35), "trim", bevel=0.04)
    p.box((0, 3.8, 1.03), (0.8, 0.1, 0.03), "power")
    p.ocyl((0, 4.1, 0.6), k.UP, 0.12, 1.9, 10, "steel")
    drum(p, (0, 5.95, 0.6), 0.2, 0.25, "steel", "trim", axis="y")


def details_torso(p):
    k.shell_details(p, *BODY)


def build_radar(p):
    c, n = lib.vec(RADAR), lib.vec(N)
    base = c + n * 0.15
    p.ocyl(tuple(c), N, 0.2, 0.2, 10, "steel")
    p.ocyl(tuple(base), N, 0.5, 0.14, 20, "trim", radius2=1.35)  # the dish's back
    p.ocyl(tuple(base + n * 0.14), N, 1.35, 0.06, 24, "trim")
    p.ocyl(tuple(base + n * 0.2), N, 1.2, 0.03, 24, "team")
    k.beam(p, tuple(base + n * 0.2), tuple(base + n * 0.85), 0.08, 0.08, "steel")
    p.ocyl(tuple(base + n * 0.85), N, 0.14, 0.18, 10, "trim")
    p.ocyl(tuple(base + n * 1.03), N, 0.1, 0.03, 10, "power")


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_sextant", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("radar", "torso", RADAR, build_radar, none)]
         + k.biped(2.2, 0.6, 0.5, "order"),
         budget=2600,
         previews=k.previews(7.0))
