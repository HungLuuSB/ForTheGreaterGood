"""Cutpurse (Chaos stealthy jamming combat engineer, T2, footprint 1; batch
2 of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_cutpurse/build.py

From its blockout: lean and dark on bare strut legs (tools/bots.py). The
`torso` (turns): a narrow dark body under a hood with one amber eye, cloak
plates swept over the shoulders, two whip antennas (the jammer), a short
gun on the right (`muzzle`) and on the left the `nano` (its own piece), a
claw arm with a lit tip (`nano1`). Chaos reads crude (M-14). Our own
design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.2, 0.0)
NANO = (-1.05, 3.7, -0.2)
GX, GY = 1.05, 3.7


def build_base(p):
    p.box((0, 2.8, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 3.15, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    p.box((0, 3.9, 0), (1.7, 1.4, 1.4), "dark", bevel=0.1)
    p.box((0.3, 4.1, -0.72), (0.5, 0.35, 0.04), "team", bevel=0.01)
    p.prism_x([(-0.65, 4.6), (0.5, 4.6), (0.5, 5.15), (0.0, 5.3), (-0.65, 4.95)], -0.5, 0.5, "paint", bevel=0.04)
    p.ocyl((0, 4.82, -0.66), k.FWD, 0.13, 0.04, 12, "head")
    for sx in (-1, 1):
        p.obox((sx * 0.95, 4.25, 0.1), (0, 0, 1), (sx, 0.6, 0), 1.6, 1.1, 0.08, "paint", bevel=0.03)
        p.ocyl((sx * 0.5, 4.6, 0.6), k.UP, 0.04, 2.2, 6, "steel")
        p.box((sx * 0.5, 6.85, 0.6), (0.08, 0.1, 0.08), "light")
    drum(p, (-0.95, 3.7, -0.1), 0.25, 0.3, "steel", "trim")
    p.box((GX, GY, -0.1), (0.45, 0.45, 0.7), "trim", bevel=0.04)
    k.gun(p, GX, GY, -0.45, 0.95, 0.12)
    p.box((0, 3.9, 0.82), (1.1, 0.9, 0.25), "trim", bevel=0.03)


def build_nano(p):
    k.nano_arm(p, *NANO, 1.6, "chaos")


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_cutpurse", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none),
                 unit.PieceSpec("nano", "torso", NANO, build_nano, none)]
         + k.biped(2.6, 0.6, 0.5, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [GX, GY, -1.5]},
                      "nano1": {"parent": "nano", "at": [-1.05, 3.7, -2.2]}},
         budget=3400,
         previews=k.previews(6.8))
