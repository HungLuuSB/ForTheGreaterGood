"""Marksman (Order cloaked sniper bot, T2, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_marksman/build.py

From its blockout: slim and tall on armoured legs (tools/bots.py). The
`torso` (turns) is a narrow dark body with a hooded sensor head and a lit
eye band, holding at the right shoulder a very long rifle: a stock, a
scope with a lit lens, a long barrel with a muzzle brake (`muzzle`). Order,
dark for the cloak (M-14). Our own design. Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.6, 0.0)
RX, RY = 0.75, 4.9


def build_base(p):
    p.box((0, 3.2, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 3.55, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    p.box((0, 4.3, 0), (1.6, 1.4, 1.4), "dark", bevel=0.12)
    p.obox((0, 4.45, -0.72), (1, 0, 0), (0, 0.4, -1), 1.3, 0.9, 0.08, "trim", bevel=0.02)
    p.box((-0.35, 4.2, -0.78), (0.5, 0.35, 0.04), "team", bevel=0.01)
    p.prism_x([(-0.6, 5.0), (0.45, 5.0), (0.45, 5.55), (0.0, 5.65), (-0.6, 5.25)], -0.45, 0.45, "dark", bevel=0.04)
    p.box((0, 5.18, -0.62), (0.6, 0.1, 0.03), "head")
    p.box((0, 4.3, 0.85), (1.1, 0.9, 0.35), "trim", bevel=0.04)
    drum(p, (0.9, 4.85, -0.1), 0.25, 0.3, "steel", "trim")
    p.box((0.95, 4.5, -0.2), (0.45, 0.9, 0.5), "trim", bevel=0.04)
    p.box((-0.95, 4.3, -0.1), (0.4, 1.0, 0.45), "trim", bevel=0.04)
    # the rifle
    p.box((RX, RY - 0.1, -0.2), (0.35, 0.5, 1.4), "dark", bevel=0.04)
    p.box((RX, RY - 0.05, -0.85), (0.3, 0.35, 0.4), "trim", bevel=0.03)
    k.gun(p, RX, RY, -1.0, 4.4, 0.11, kind="steel", glow=False)
    p.ocyl((RX, RY, -3.2), k.FWD, 0.15, 0.4, 10, "trim")
    p.ocyl((RX, 5.22, -0.65), k.FWD, 0.13, 0.9, 10, "trim")
    p.ocyl((RX, 5.22, -1.55), k.FWD, 0.1, 0.03, 10, "power")
    p.box((RX, 5.07, -1.1), (0.08, 0.15, 0.2), "steel")


def details_torso(p):
    pass


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_marksman", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(3.0, 0.6, 0.45, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [RX, RY, -5.5]}},
         budget=2600,
         previews=k.previews(5.8))
