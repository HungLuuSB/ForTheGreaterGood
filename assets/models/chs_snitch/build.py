"""Snitch (Chaos cloaked spy bot, T2, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_snitch/build.py

From its blockout: tiny and crouched on short strut legs (tools/bots.py).
The `torso` (turns): a dark body under a wedge head with one amber eye
(`muzzle` below it), a whip antenna, a team fin and the EMP charge glowing
in its back. Chaos reads crude (M-14). Our own design. Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.1, 0.0)


def build_base(p):
    p.box((0, 1.7, 0), (1.0, 0.7, 0.9), "dark", bevel=0.05)
    drum(p, (0, 2.05, 0), 0.4, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    p.prism_x([(-0.7, 2.1), (0.7, 2.1), (0.7, 2.85), (0.2, 3.0), (-0.7, 2.75)], -0.6, 0.6, "dark", bevel=0.06)
    p.prism_x([(-0.85, 2.9), (0.0, 2.9), (0.0, 3.4), (-0.85, 3.05)], -0.4, 0.4, "paint", bevel=0.04)
    p.ocyl((0, 3.1, -0.84), k.FWD, 0.13, 0.04, 12, "head")
    p.ocyl((0.3, 3.0, 0.5), k.UP, 0.035, 1.8, 6, "steel")
    p.box((0.3, 4.82, 0.5), (0.07, 0.09, 0.07), "light")
    p.prism_x([(0.0, 2.95), (0.65, 2.95), (0.6, 3.35)], -0.34, -0.26, "team", bevel=0.01)
    p.box((0, 2.5, 0.72), (0.8, 0.6, 0.12), "trim", bevel=0.03)
    p.ocyl((0, 2.5, 0.78), (0, 0, 1), 0.24, 0.04, 14, "power")


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_snitch", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none)]
         + k.biped(1.5, 0.45, 0.35, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, 3.1, -0.95]}},
         budget=2200,
         previews=k.previews(4.8))
