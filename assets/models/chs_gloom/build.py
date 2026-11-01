"""Gloom (Chaos jammer bot, T2, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_gloom/build.py

From its blockout: a hunched little bot on bare strut legs (tools/bots.py).
The `torso` (turns): a chamfered body with a low head and an amber slit;
on its back a jammer dish bristling with four spined antennas splayed
outward, their tips lit. Chaos reads crude (M-14). Our own design. Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.6, 0.0)
BODY = ((0, 3.2, 0.1), (1.8, 1.2, 1.6))
SPINES = [(-0.5, 0.0, 2.2, 15), (0.5, 0.0, 2.0, 15), (-0.3, 0.7, 1.6, 10), (0.35, 0.7, 1.8, 10)]


def build_base(p):
    p.box((0, 2.2, 0), (1.5, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 2.55, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (0, 3.5, -0.95), (0.8, 0.45, 0.7), "chaos")
    p.box((0, 2.95, -0.72), (0.9, 0.35, 0.04), "team", bevel=0.01)
    p.ocyl((0, 3.8, 0.3), k.UP, 0.7, 0.2, 16, "trim", radius2=0.55)
    p.ocyl((0, 4.0, 0.3), k.UP, 0.4, 0.06, 14, "power")
    for x, z, h, deg in SPINES:
        sx = 1 if x > 0 else -1
        a = math.radians(deg)
        d = lib.vec((sx * math.sin(a), math.cos(a), 0.0))
        b = lib.vec((x, 4.0, z))
        p.ocyl(tuple(b), tuple(d), 0.09, h, 6, "dark", radius2=0.03)
        for f in (0.35, 0.6):
            p.ocyl(tuple(b + d * (h * f)), tuple(d), 0.12, 0.12, 6, "steel", radius2=0.05)
        p.ocyl(tuple(b + d * h), tuple(d), 0.08, 0.14, 6, "power", radius2=0.02)


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_gloom", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.0, 0.65, 0.55, "chaos"),
         budget=2600,
         previews=k.previews(6.4))
