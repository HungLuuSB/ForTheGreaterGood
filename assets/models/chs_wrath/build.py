"""Wrath (Chaos heavy rocket artillery bot, T2, footprint 1; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_wrath/build.py

From its blockout: a squat bot on bare strut legs (tools/bots.py), its head
jutting low in front. The `torso` (turns) hauls the `launcher` (pitches) on
its back: a big armoured box raked up, nine lit tubes on its face
(`muzzle`), spikes on its top corners, on a frame with pistons. Chaos reads
crude (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, piston  # noqa: E402

TORSO = (0.0, 3.1, 0.0)
BODY = ((0, 3.85, 0), (2.4, 1.5, 2.0))
LAUNCHER = (0.0, 4.6, 0.8)
RAKE = math.radians(20)
N = (0.0, math.sin(RAKE), -math.cos(RAKE))  # the launcher's face
BOX = (0.0, 5.5, 0.3)


def build_base(p):
    p.box((0, 2.7, 0), (2.1, 0.8, 1.6), "dark", bevel=0.05)
    drum(p, (0, 3.05, 0), 0.7, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (0, 4.1, -1.3), (0.9, 0.5, 0.8), "chaos")
    p.box((0, 3.5, -1.02), (1.2, 0.4, 0.04), "team", bevel=0.01)
    p.box((0, 4.65, 0.4), (2.8, 0.2, 2.4), "trim", bevel=0.03)
    for sx in (-1, 1):
        piston(p, (sx * 1.2, 4.0, -0.6), (sx * 1.2, 4.95, -0.4), r=0.08)
        p.box((sx * 1.3, 3.8, 0.1), (0.2, 1.1, 1.5), "trim", bevel=0.03)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_launcher(p):
    c, n, u = lib.vec(BOX), lib.vec(N), lib.vec((1, 0, 0))
    v = n.cross(u)
    drum(p, LAUNCHER, 0.3, 2.2, "steel", "trim")
    p.obox(BOX, (1, 0, 0), N, 2.6, 1.6, 2.2, "paint", bevel=0.08)
    p.obox(tuple(c + n * 1.11), (1, 0, 0), N, 2.4, 1.4, 0.06, "dark", bevel=0.02)
    k.tilted_tubes(p, tuple(c + n * 1.15), N, (1, 0, 0), 3, 3, 0.7, 0.18)
    p.obox(tuple(c + v * 0.82 - n * 0.3), (1, 0, 0), tuple(v), 1.6, 1.2, 0.05, "team", bevel=0.01)
    for sx in (-1, 1):
        base = c + u * (sx * 1.05) + v * 0.8 + n * 0.5
        p.ocyl(tuple(base), tuple(v), 0.2, 0.7, 6, "steel", radius2=0.03)
        p.obox(tuple(c + u * (sx * 1.31)), tuple(v), (sx, 0, 0), 1.2, 1.8, 0.04, "trim", bevel=0.0)


none = lambda p: None  # noqa: E731
mouth = lib.vec(BOX) + lib.vec(N) * 1.3

unit.run(__file__, "chs_wrath", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("launcher", "torso", LAUNCHER, build_launcher, none)]
         + k.biped(2.5, 0.9, 0.75, "chaos"),
         attachments={"muzzle": {"parent": "launcher", "at": [mouth.x, mouth.y, mouth.z]}},
         budget=3400,
         previews=k.previews(6.8))
