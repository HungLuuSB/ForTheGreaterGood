"""Picket (Order anti-swarm bot, T1, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_picket/build.py

From its blockout: a stocky upright bot on armoured legs (tools/bots.py,
swinging for the client's walk). The `torso` (turns) is a broad armoured
body with a raked team chest plate, a sensor head, big team shoulder pads
and a power pack on the back; both forearms end in close-range laser
housings with lit lenses (`muzzle` right, `muzzle2` left). Order reads
clean and heavy (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.1, 0.0)
BODY = ((0, 4.0, 0), (2.6, 1.8, 2.0))
LY, LZ = 3.3, -0.9  # the laser housings


def build_base(p):
    p.box((0, 2.7, 0), (2.0, 0.8, 1.5), "dark", bevel=0.06)
    drum(p, (0, 3.05, 0), 0.7, 0.14, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.obox((0, 4.05, -1.08), (1, 0, 0), (0, 0.3, -1), 2.1, 1.3, 0.16, "team", bevel=0.04)  # the chest plate
    p.box((0, 3.35, -1.05), (1.6, 0.1, 0.1), "light")
    k.head(p, (0, 5.2, -0.2), (1.0, 0.6, 0.9), "order")
    p.box((0, 4.1, 1.15), (1.6, 1.2, 0.4), "trim", bevel=0.05)
    p.box((0, 4.3, 1.36), (1.1, 0.12, 0.04), "power")
    for sx in (-1, 1):
        x = sx * 1.65
        k.pad(p, (sx * 1.6, 4.85, 0), (0.95, 0.6, 1.9), "order")
        drum(p, (sx * 1.38, 4.4, 0), 0.32, 0.3, "steel", "trim")
        p.box((x, 3.85, -0.2), (0.7, 1.4, 0.8), "trim", bevel=0.05)
        p.box((x, LY, LZ), (0.8, 0.7, 1.5), "paint", bevel=0.08)
        p.box((x + sx * 0.41, LY, LZ), (0.03, 0.12, 1.0), "light")
        p.ocyl((x, LY, LZ - 0.75), k.FWD, 0.27, 0.14, 12, "trim")
        p.ocyl((x, LY, LZ - 0.89), k.FWD, 0.19, 0.03, 12, "weapon")


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_picket", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.5, 0.85, 0.65, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [1.65, LY, LZ - 0.95]},
                      "muzzle2": {"parent": "torso", "at": [-1.65, LY, LZ - 0.95]}},
         budget=3000,
         previews=k.previews(5.6))
