"""Taskmaster (Chaos advanced constructor bot, T2, footprint 1; batch 2 of
the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_taskmaster/build.py

From its blockout: a bulky worker on bare strut legs (tools/bots.py). The
`torso` (turns): a chamfered body with a low head and an amber slit, a
hazard band across the chest, two exhaust stacks, and on a boom block the
`nano` (its own piece): a long crane arm with a piston, ending in a lit
claw (`nano1`). Chaos reads crude (M-14). Our own design. Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard  # noqa: E402

TORSO = (0.0, 3.2, 0.0)
BODY = ((0, 4.1, 0), (2.6, 1.8, 2.2))
NANO = (1.3, 5.5, 0.2)


def build_base(p):
    p.box((0, 2.8, 0), (2.1, 0.8, 1.6), "dark", bevel=0.05)
    drum(p, (0, 3.15, 0), 0.7, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (-0.6, 5.27, -0.5), (0.9, 0.55, 0.8), "chaos")
    hazard(p, (0, 3.6, -1.13), (1, 0, 0), (0, 0, -1), 2.2, 0.3, stripes=7)
    p.box((0.4, 4.3, -1.12), (1.0, 0.5, 0.04), "team", bevel=0.01)
    for x in (-0.7, -0.2):
        p.ocyl((x, 4.9, 0.9), k.UP, 0.18, 1.2, 8, "dark")
        p.ocyl((x, 6.1, 0.9), k.UP, 0.22, 0.12, 8, "steel")
    p.box((1.3, 5.25, 0.4), (0.7, 0.7, 0.9), "trim", bevel=0.04)
    for sx in (-1, 1):
        p.box((sx * 1.4, 4.0, 0), (0.25, 1.2, 1.6), "trim", bevel=0.04)
    p.box((-1.5, 3.8, -0.3), (0.5, 1.1, 0.5), "trim", bevel=0.04)
    p.prism_x([(-0.55, 3.3), (-0.1, 3.3), (-0.1, 3.1), (-0.75, 3.1)], -1.7, -1.3, "steel", bevel=0.01)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_nano(p):
    k.nano_arm(p, *NANO, 3.4, "chaos", rise=0.8)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_taskmaster", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("nano", "torso", NANO, build_nano, none)]
         + k.biped(2.6, 0.9, 0.75, "chaos"),
         attachments={"nano1": {"parent": "nano", "at": [1.3, 6.3, -3.6]}},
         budget=3200,
         previews=k.previews(6.5))
