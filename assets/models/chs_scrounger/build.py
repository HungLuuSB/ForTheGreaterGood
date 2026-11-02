"""Scrounger (Chaos combat engineer bot, T2, footprint 1; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_scrounger/build.py

From its blockout: wiry and quick on bare strut legs (tools/bots.py). The
`torso` (turns): a chamfered body with a low head and an amber slit, an
open scrap hopper on its back heaped with plates, a short gun on the left
(`muzzle`) and on the right the `nano` (its own piece), a claw arm with a
lit tip (`nano1`). Chaos reads crude (M-14). Our own design. Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.0, 0.0)
BODY = ((0, 3.65, 0), (1.7, 1.3, 1.5))
NANO = (1.05, 3.6, -0.1)
GX, GY = -1.05, 3.5


def build_base(p):
    p.box((0, 2.6, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 2.95, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (-0.2, 4.52, -0.4), (0.75, 0.45, 0.7), "chaos")
    p.box((0.2, 3.6, -0.77), (0.6, 0.35, 0.04), "team", bevel=0.01)
    # the hopper: an open bin raked back, scrap heaped in it
    p.prism_x([(0.3, 4.2), (1.3, 4.2), (1.45, 5.0), (1.32, 5.0), (1.18, 4.32), (0.42, 4.32), (0.3, 5.0), (0.18, 5.0)],
              -0.8, 0.8, "trim", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 0.76, 4.6, 0.8), (0.08, 0.75, 1.0), "trim")
    p.obox((-0.2, 4.7, 0.8), (1, 0.2, 0.1), (0.1, 1, -0.3), 0.9, 0.6, 0.06, "steel", bevel=0.01)
    p.obox((0.3, 4.75, 0.9), (0.9, 0, 0.4), (-0.2, 1, 0.3), 0.6, 0.5, 0.06, "dark", bevel=0.01)
    p.ocyl((0.05, 4.6, 0.6), (0.3, 1, 0.2), 0.07, 0.8, 6, "steel")
    drum(p, (0.95, 3.6, 0), 0.25, 0.3, "steel", "trim")
    drum(p, (-0.95, 3.5, 0), 0.25, 0.3, "steel", "trim")
    p.box((GX, GY, -0.15), (0.45, 0.45, 0.6), "trim", bevel=0.04)
    k.gun(p, GX, GY, -0.45, 0.95, 0.12)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_nano(p):
    k.nano_arm(p, *NANO, 1.6, "chaos")


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_scrounger", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("nano", "torso", NANO, build_nano, none)]
         + k.biped(2.4, 0.6, 0.5, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [GX, GY, -1.5]},
                      "nano1": {"parent": "nano", "at": [1.05, 3.6, -2.1]}},
         budget=3400,
         previews=k.previews(5.4))
