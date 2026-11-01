"""Informant (Order cloaked spy bot, T2, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_informant/build.py

From its blockout: small and crouched on short legs (tools/bots.py). The
`torso` (turns) is a low faceted body of dark plates sloping to the front,
one lit sensor eye in a hooded socket (`muzzle` below it), a team fin on
the back and the EMP charge glowing in a ribbed back housing. Order, but
dark for the cloak (M-14). Our own design. Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402

TORSO = (0.0, 2.1, 0.0)


def build_base(p):
    p.box((0, 1.7, 0), (1.0, 0.7, 0.9), "dark", bevel=0.05)
    drum(p, (0, 2.05, 0), 0.4, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    prof = [(-1.0, 2.15), (-0.45, 2.85), (0.6, 3.0), (1.15, 2.85), (1.15, 2.15)]
    p.prism_x(prof, -0.65, 0.65, "dark", bevel=0.06)
    p.prism_x([(-0.85, 2.3), (-0.4, 2.92), (0.5, 3.06), (0.5, 2.9), (-0.45, 2.75), (-0.75, 2.3)], -0.45, 0.45, "trim", bevel=0.03)
    for sx in (-1, 1):
        p.obox((sx * 0.7, 2.5, 0.1), (0, 0, 1), (sx, 0.5, 0), 1.6, 0.6, 0.06, "dark", bevel=0.02)
    p.box((0, 2.5, -0.92), (0.6, 0.45, 0.25), "trim", bevel=0.04)
    p.ocyl((0, 2.45, -1.0), k.FWD, 0.17, 0.06, 12, "head")
    p.box((0, 3.25, 0.55), (0.06, 0.4, 0.8), "team")
    p.box((0, 2.55, 0.95), (1.1, 0.75, 0.4), "trim", bevel=0.04)
    for y in (2.35, 2.55, 2.75):
        p.box((0, y, 1.16), (0.7, 0.07, 0.03), "power")


def details_torso(p):
    rivets(p, (-0.5, 2.2, -0.95), (0.5, 2.2, -0.95), 4, k.FWD)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_informant", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(1.5, 0.45, 0.35, "order", team=False),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, 2.45, -1.1]}},
         budget=2200,
         previews=k.previews(3.4))
