"""Marshal (Order skirmisher bot, gauss guns, T2, footprint 1; batch 2 of
the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_marshal/build.py

From its blockout: tall and lean on armoured legs (tools/bots.py). The
`torso` (turns): a body with a raked team chest plate and a sensor head;
both forearms are long gauss rails, twin rails with lit coils between them
(`muzzle` right, `muzzle2` left). Order reads clean (M-14). Our own design.
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.6, 0.0)
BODY = ((0, 4.4, 0), (2.0, 1.6, 1.6))
AX, AY = 1.35, 3.8


def build_base(p):
    p.box((0, 3.2, 0), (1.7, 0.8, 1.4), "dark", bevel=0.06)
    drum(p, (0, 3.55, 0), 0.6, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.obox((0, 4.55, -0.86), (1, 0, 0), (0, 0.4, -1), 1.6, 1.0, 0.12, "team", bevel=0.03)
    k.head(p, (0, 5.45, -0.2), (0.8, 0.5, 0.8), "order")
    p.box((0, 4.4, 0.95), (1.3, 1.0, 0.3), "trim", bevel=0.04)
    p.box((0, 4.6, 1.11), (0.8, 0.1, 0.03), "power")
    for sx in (-1, 1):
        x = sx * AX
        drum(p, (sx * 1.15, 4.85, 0), 0.3, 0.3, "steel", "trim")
        p.box((x, 4.35, 0), (0.55, 1.1, 0.6), "trim", bevel=0.05)
        p.box((x, AY, -0.1), (0.6, 0.6, 0.9), "paint", bevel=0.06)
        for dx in (-0.17, 0.17):
            p.box((x + dx, AY, -1.5), (0.14, 0.42, 2.6), "steel", bevel=0.02)
        for z in (-0.75, -1.45, -2.15):
            p.box((x, AY, z), (0.24, 0.3, 0.14), "power")
        p.box((x, AY + 0.24, -1.4), (0.5, 0.06, 2.2), "trim")


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_marshal", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(3.0, 0.7, 0.55, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [AX, AY, -2.85]},
                      "muzzle2": {"parent": "torso", "at": [-AX, AY, -2.85]}},
         budget=3000,
         previews=k.previews(5.8))
