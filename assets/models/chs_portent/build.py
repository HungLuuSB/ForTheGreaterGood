"""Portent (Chaos radar bot, T2, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_portent/build.py

From its blockout: spindly, on bare strut legs (tools/bots.py). The
`torso` (turns): a chamfered body with one big amber eye and short spikes;
a lattice mast rises from its back and carries the `radar` (a client piece
that turns): a long slatted bar with a lit face. Chaos reads crude (M-14).
Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.9, 0.0)
BODY = ((0, 3.5, 0), (1.6, 1.2, 1.4))
RADAR = (0.0, 6.8, 0.6)
MZ = 0.6


def build_base(p):
    p.box((0, 2.5, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 2.85, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    p.ocyl((0, 3.7, -0.68), k.FWD, 0.3, 0.12, 14, "trim")
    p.ocyl((0, 3.7, -0.8), k.FWD, 0.22, 0.04, 14, "head")
    p.box((0, 3.2, -0.71), (0.8, 0.35, 0.04), "team", bevel=0.01)
    for sx in (-1, 1):
        k.beam(p, (sx * 0.4, 4.05, MZ), (sx * 0.12, 6.6, MZ), 0.1, 0.1, "steel", bevel=0.01)
        p.ocyl((sx * 0.6, 4.05, 0.2), k.UP, 0.12, 0.5, 6, "steel", radius2=0.02)
    for i in range(4):
        y = 4.5 + i * 0.55
        w = 0.72 - i * 0.12
        p.box((0, y, MZ), (w, 0.06, 0.06), "dark")
        if i < 3:
            k.beam(p, (-w / 2, y, MZ), (w / 2 - 0.06, y + 0.55, MZ), 0.04, 0.04, "dark", bevel=0.0)
    drum(p, (0, 6.65, MZ), 0.18, 0.2, "steel", "trim", axis="y")


def details_torso(p):
    k.shell_details(p, *BODY)


def build_radar(p):
    x, y, z = RADAR
    p.box((x, y, z), (0.4, 0.3, 0.4), "trim", bevel=0.03)
    p.box((x, y + 0.1, z), (3.0, 0.5, 0.18), "paint", bevel=0.03)
    for i in range(7):
        p.box((x - 1.2 + i * 0.4, y + 0.1, z - 0.11), (0.08, 0.42, 0.04), "dark")
    p.box((x, y + 0.1, z - 0.13), (2.6, 0.1, 0.02), "head")
    p.box((x, y + 0.38, z), (2.8, 0.06, 0.1), "steel")


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_portent", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("radar", "torso", RADAR, build_radar, none)]
         + k.biped(2.3, 0.6, 0.5, "chaos"),
         budget=3400,
         previews=k.previews(7.2))
