"""Firebrand (Chaos rocket bot, T1, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_firebrand/build.py

From its blockout: a hunched bot on bare strut legs with pistons and claw
toes (tools/bots.py). The `torso` (turns) is a chamfered body with a low
head and an amber slit, and over the right shoulder an open rail rack of
three rockets raked up, their tips lit (`muzzle`); a spiked pad on the
left. Chaos reads crude (M-14). Our own design. Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.9, 0.0)
BODY = ((0, 3.65, 0.1), (2.2, 1.5, 1.8))
RAKE = math.radians(14)
AIM = (0.0, math.sin(RAKE), -math.cos(RAKE))
RX, RY = 1.4, 5.0


def build_base(p):
    p.box((0, 2.5, 0), (2.0, 0.8, 1.5), "dark", bevel=0.05)
    drum(p, (0, 2.85, 0), 0.65, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    p.box((-0.3, 3.6, -0.83), (0.9, 0.5, 0.04), "team", bevel=0.01)
    k.head(p, (-0.35, 4.65, -0.5), (0.8, 0.5, 0.8), "chaos")
    # the rail rack: a frame on a post, three rockets on rails
    drum(p, (1.15, 4.45, 0.1), 0.3, 0.35, "steel", "trim")
    p.box((1.4, 4.55, 0.4), (0.3, 0.6, 0.3), "trim")
    c = lib.vec((RX, RY - 0.25, 0.1))
    a = lib.vec(AIM)
    k.beam(p, tuple(c + a * 1.1), tuple(c - a * 1.1), 1.4, 0.12, "trim")
    for dx in (-0.42, 0.0, 0.42):
        r = lib.vec((RX + dx, RY, 0.1))
        p.ocyl(tuple(r - a * 0.9), AIM, 0.15, 1.6, 8, "dark")
        p.ocyl(tuple(r + a * 0.7), AIM, 0.15, 0.3, 8, "steel", radius2=0.03)
        p.ocyl(tuple(r + a * 0.65), AIM, 0.155, 0.06, 8, "weapon")
    p.box((-1.45, 4.3, 0), (1.0, 0.7, 1.8), "trim", bevel=0.05)
    for z in (-0.4, 0.4):
        p.ocyl((-1.6, 4.65, z), k.UP, 0.16, 0.7, 6, "steel", radius2=0.02)
    p.box((0, 3.5, 1.05), (1.4, 0.8, 0.3), "trim", bevel=0.03)
    for x in (-0.4, 0.0, 0.4):
        p.box((x, 3.5, 1.21), (0.2, 0.5, 0.03), "dark")


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731
tip = lib.vec((RX, RY, 0.1)) + lib.vec(AIM) * 1.05

unit.run(__file__, "chs_firebrand", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.3, 0.8, 0.65, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [tip.x, tip.y, tip.z]}},
         budget=3000,
         previews=k.previews(5.4))
