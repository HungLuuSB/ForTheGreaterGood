"""Hush (Order jammer bot, T2, footprint 1; batch 2 of the BAR roster,
2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_hush/build.py

From its blockout: a small bot on armoured legs (tools/bots.py). The
`torso` (turns) carries a tall jammer mast on its back: three cross arms
narrowing upward with lit emitter tips, team bands on the mast and an
emitter dome on top. Order reads clean (M-14). Our own design. Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.7, 0.0)
BODY = ((0, 3.35, 0), (1.6, 1.3, 1.4))
MZ = 0.55


def build_base(p):
    p.box((0, 2.3, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 2.65, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order", team_face=(0.9, 0.45, 3.4))
    k.head(p, (0, 4.23, -0.2), (0.75, 0.45, 0.7), "order")
    p.box((0, 3.6, MZ + 0.25), (1.1, 1.1, 0.4), "trim", bevel=0.05)
    p.box((0, 4.1, MZ), (0.5, 0.3, 0.5), "paint", bevel=0.04)
    p.box((0, 5.5, MZ), (0.22, 3.0, 0.22), "paint", bevel=0.03)
    for y in (4.55, 6.3):
        p.box((0, y, MZ), (0.28, 0.25, 0.28), "team")
    for i, w in enumerate((1.8, 1.4, 1.0)):
        y = 5.0 + i * 0.85
        p.box((0, y, MZ), (w, 0.1, 0.1), "steel")
        for sx in (-1, 1):
            p.ocyl((sx * w / 2, y - 0.12, MZ), k.UP, 0.07, 0.3, 8, "trim")
            p.box((sx * w / 2, y + 0.2, MZ), (0.1, 0.12, 0.1), "power")
    p.ocyl((0, 6.95, MZ), k.UP, 0.32, 0.2, 14, "trim")
    p.ocyl((0, 7.15, MZ), k.UP, 0.25, 0.2, 14, "power", radius2=0.08)


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_hush", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.1, 0.6, 0.5, "order"),
         budget=2600,
         previews=k.previews(7.4))
