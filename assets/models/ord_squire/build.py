"""Squire (Order fast infantry bot, T1, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_squire/build.py

From its blockout: small and light on quick legs (tools/bots.py). The
`torso` (turns) is a compact body with a team chest plate, a visored head,
a backpack with a whip antenna, a short left arm and on the right arm a
plasma gun with a lit bore (`muzzle`). Order reads clean (M-14). Our own
design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.5, 0.0)
BODY = ((0, 3.1, 0), (1.5, 1.2, 1.3))
GX, GY = 0.95, 3.05


def build_base(p):
    p.box((0, 2.1, 0), (1.2, 0.7, 1.0), "dark", bevel=0.05)
    drum(p, (0, 2.45, 0), 0.45, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order", team_face=(0.9, 0.45, 3.15))
    p.obox((0, 3.55, -0.62), (1, 0, 0), (0, 0.6, -1), 1.3, 0.5, 0.1, "paint", bevel=0.03)
    k.head(p, (0, 3.95, -0.1), (0.8, 0.5, 0.75), "order")
    p.box((0, 3.15, 0.9), (1.1, 0.9, 0.5), "trim", bevel=0.05)
    p.box((0, 3.35, 1.16), (0.7, 0.1, 0.03), "power")
    p.ocyl((-0.45, 3.6, 0.8), k.UP, 0.05, 1.5, 6, "dark")
    p.box((-0.45, 5.1, 0.8), (0.1, 0.1, 0.1), "light")
    drum(p, (GX - 0.15, 3.35, -0.1), 0.22, 0.3, "steel", "trim")
    p.box((GX, GY, -0.4), (0.45, 0.45, 1.1), "paint", bevel=0.05)
    p.box((GX, GY + 0.24, -0.45), (0.3, 0.03, 0.7), "team")
    k.gun(p, GX, GY, -0.95, 1.0, 0.15)
    p.box((-0.95, 3.05, 0), (0.4, 0.9, 0.45), "trim", bevel=0.05)
    drum(p, (-0.8, 3.45, 0), 0.2, 0.25, "steel", "trim")


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_squire", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(1.9, 0.5, 0.4, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [GX, GY, -2.05]}},
         budget=2400,
         previews=k.previews(5.0))
