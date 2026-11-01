"""Pandemonium (Chaos heavy rocket mech, T3, footprint 3; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_pandemonium/build.py

From its blockout, laid out at bot size and scaled x2.0 (unit.run `scale`;
the blockout scales the same). A stooped mech on thick strut legs
(tools/bots.py). The `torso` (turns): a chamfered body with a small
armoured head jutting low and an amber slit, and on each shoulder a
massive rocket box, nine lit tubes on its face, a team flank and spikes
on top (`muzzle` right, `muzzle2` left). Chaos reads crude and brutal
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, piston, rivets  # noqa: E402

S = 2.0
TORSO = (0.0, 3.4, 0.0)
BODY = ((0, 4.35, 0.1), (2.6, 1.9, 2.2))
BX, BY = 2.25, 5.6


def build_base(p):
    p.box((0, 3.0, 0), (2.3, 0.8, 1.8), "dark", bevel=0.05)
    drum(p, (0, 3.35, 0), 0.8, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (0, 4.8, -1.35), (0.9, 0.55, 0.8), "chaos")
    p.box((0, 4.0, -1.02), (1.2, 0.5, 0.04), "team", bevel=0.01)
    p.box((0, 4.5, 1.3), (1.8, 1.3, 0.3), "trim", bevel=0.04)
    for sx in (-1, 1):
        x = sx * BX
        drum(p, (sx * 1.3, 5.0, 0.1), 0.4, 0.5, "steel", "trim")
        p.box((x, BY, 0.1), (1.8, 1.8, 2.4), "paint", bevel=0.1)
        p.box((x, BY, -1.12), (1.6, 1.6, 0.06), "dark", bevel=0.02)
        k.tubes(p, x, BY, -1.15, 3, 3, 0.5, 0.18)
        p.box((x + sx * 0.92, BY, 0.2), (0.04, 1.0, 1.6), "team")
        for z in (-0.5, 0.6):
            p.ocyl((x + sx * 0.3, BY + 0.9, z), k.UP, 0.2, 0.75, 6, "steel", radius2=0.03)
        piston(p, (sx * 1.2, 4.0, 0.6), (x - sx * 0.6, BY - 0.8, 0.8), r=0.1)


def details_torso(p):
    k.shell_details(p, *BODY)
    for sx in (-1, 1):
        rivets(p, (sx * BX - 0.7, BY + 0.91, -0.9), (sx * BX + 0.7, BY + 0.91, -0.9), 4, k.UP)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_pandemonium", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.8, 1.0, 0.85, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [BX, BY, -1.3]},
                      "muzzle2": {"parent": "torso", "at": [-BX, BY, -1.3]}},
         budget=5000, tex=2048, scale=(S, S, S),
         previews=k.previews(14.4))
