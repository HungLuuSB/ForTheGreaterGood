"""Paragon (Order amphibious assault mech, twin gauss cannons, T3,
footprint 2; batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig
data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_paragon/build.py

From its blockout, laid out at bot size and scaled x1.7 (unit.run `scale`;
the blockout scales the same). Heavy armoured legs (tools/bots.py) under a
pelvis with team float collars. The `torso` (turns): a sealed body with a
raked bow, a sensor head and a radiator pack; on each shoulder a team
mount carrying a long gauss cannon with a lit coil and a muzzle collar
(`muzzle` right, `muzzle2` left). Order reads clean and heavy (M-14). Our
own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

S = 1.7
TORSO = (0.0, 3.5, 0.0)
BODY = ((0, 4.45, 0), (2.6, 1.9, 2.3))
CX, CY = 1.75, 5.3


def build_base(p):
    p.box((0, 3.1, 0), (2.2, 0.8, 1.7), "dark", bevel=0.06)
    drum(p, (0, 3.45, 0), 0.8, 0.14, "steel", "trim", axis="y")
    for sx in (-1, 1):
        p.ocyl((sx * 1.5, 3.15, 1.0), k.FWD, 0.4, 2.0, 14, "team")
        p.ocyl((sx * 1.5, 3.15, -1.0), k.FWD, 0.4, 0.25, 14, "trim", radius2=0.18)


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.prism_x([(-1.15, 3.55), (-1.15, 4.95), (-1.85, 4.2), (-1.7, 3.55)], -1.2, 1.2, "paint", bevel=0.06)
    p.box((0, 4.25, -1.6), (1.2, 0.4, 0.04), "team", bevel=0.01)
    k.head(p, (0, 5.68, -0.3), (1.0, 0.55, 0.9), "order")
    p.box((0, 4.6, 1.35), (1.9, 1.4, 0.5), "trim", bevel=0.05)
    for x in (-0.6, 0.0, 0.6):
        p.box((x, 4.6, 1.61), (0.35, 1.0, 0.04), "dark")
    for sx in (-1, 1):
        x = sx * CX
        drum(p, (sx * 1.35, 5.0, 0), 0.4, 0.4, "steel", "trim")
        p.box((x, CY, 0.1), (0.9, 0.9, 1.6), "team", bevel=0.08)
        p.box((x, CY + 0.46, 0.3), (0.5, 0.04, 0.9), "trim")
        k.gun(p, x, CY, -0.7, 2.8, 0.22)
        p.ocyl((x, CY, -1.2), k.FWD, 0.33, 0.18, 14, "power")
        p.box((x, 4.2, -0.2), (0.7, 1.2, 0.8), "trim", bevel=0.05)


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_paragon", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.9, 0.95, 0.75, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [CX, CY, -3.6]},
                      "muzzle2": {"parent": "torso", "at": [-CX, CY, -3.6]}},
         budget=4500, tex=2048, scale=(S, S, S),
         previews=k.previews(6.0 * S))
