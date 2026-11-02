"""Gargoyle (Chaos heavy amphibious anti-air bot, T2, footprint 1; batch 2
of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_gargoyle/build.py

From its blockout: big and hunched on thick strut legs (tools/bots.py).
The `torso` (turns): a chamfered body with a low horned head and an amber
slit; across its shoulders the `launcher` (pitches) carries two tall
missile racks raked back like folded wings, six lit cells on each face
(`muzzle`). Chaos reads crude (M-14). Our own design. Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.2, 0.0)
BODY = ((0, 4.1, 0.1), (2.8, 1.8, 2.4))
LAUNCHER = (0.0, 5.2, 0.4)
RX = 1.75


def build_base(p):
    p.box((0, 2.8, 0), (2.3, 0.8, 1.8), "dark", bevel=0.05)
    drum(p, (0, 3.15, 0), 0.8, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (0, 4.5, -1.4), (1.0, 0.6, 0.9), "chaos")
    for sx in (-1, 1):
        p.ocyl((sx * 0.4, 4.75, -1.3), (sx * 0.4, 1, 0.3), 0.14, 0.7, 6, "steel", radius2=0.02)
    p.box((0, 3.7, -1.12), (1.4, 0.5, 0.04), "team", bevel=0.01)
    p.box((0, 4.1, 1.35), (1.8, 1.2, 0.3), "trim", bevel=0.04)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_launcher(p):
    drum(p, LAUNCHER, 0.35, 2.6, "steel", "trim")
    for sx in (-1, 1):
        x = sx * RX
        p.prism_x([(-0.4, 5.0), (1.2, 5.0), (1.2, 6.2), (0.5, 7.4), (-0.4, 6.6)], x - 0.55, x + 0.55, "paint", bevel=0.06)
        p.box((x, 5.95, -0.42), (0.95, 1.3, 0.06), "dark", bevel=0.02)
        k.tubes(p, x, 5.95, -0.45, 2, 3, 0.42, 0.14)
        p.box((x + sx * 0.56, 6.0, 0.4), (0.04, 0.9, 1.0), "team")
        p.ocyl((x, 7.2, 0.6), (0, 0.6, 1), 0.14, 0.6, 6, "steel", radius2=0.02)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_gargoyle", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("launcher", "torso", LAUNCHER, build_launcher, none)]
         + k.biped(2.6, 1.0, 0.8, "chaos"),
         attachments={"muzzle": {"parent": "launcher", "at": [RX, 5.95, -0.6]}},
         budget=3600,
         previews=k.previews(7.4))
