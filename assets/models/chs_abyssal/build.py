"""Abyssal (Chaos amphibious siege mech, heavy cannon, T3, footprint 3;
batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_abyssal/build.py

From its blockout, laid out at bot size and scaled x1.8 (unit.run `scale`;
the blockout scales the same). A sealed, rounded hulk on thick strut legs
(tools/bots.py). The `torso` (turns): a chamfered body with a domed top, an
amber slit, two ballast tanks on its back, a claw arm on the left and on
the right shoulder a single huge cannon on an armoured mount, with a
recoil sleeve and a muzzle brake (`muzzle`). Chaos reads crude and brutal
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, piston  # noqa: E402

S = 1.8
TORSO = (0.0, 3.4, 0.0)
BODY = ((0, 4.4, 0), (2.6, 2.0, 2.4))
CX, CY = 1.85, 5.2


def build_base(p):
    p.box((0, 3.0, 0), (2.3, 0.8, 1.8), "dark", bevel=0.05)
    drum(p, (0, 3.35, 0), 0.8, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    p.ocyl((0, 5.2, 0), k.UP, 1.15, 0.6, 18, "paint", radius2=0.6)
    p.box((-0.3, 4.85, -1.23), (1.0, 0.15, 0.04), "head")
    p.box((-0.3, 4.1, -1.22), (1.2, 0.5, 0.04), "team", bevel=0.01)
    for sx in (-1, 1):
        p.ocyl((sx * 0.6, 3.6, 1.5), k.UP, 0.4, 2.0, 14, "dark")
        p.ocyl((sx * 0.6, 5.6, 1.5), k.UP, 0.4, 0.15, 14, "steel", radius2=0.2)
    drum(p, (-1.5, 4.85, 0), 0.4, 0.5, "steel", "trim")
    p.box((-1.75, 4.1, -0.1), (0.9, 1.5, 1.0), "trim", bevel=0.06)
    for dx in (-0.25, 0.25):
        p.prism_x([(-0.1, 3.3), (-0.95, 3.0), (-0.95, 2.85), (-0.1, 3.1)], -1.75 + dx - 0.1, -1.75 + dx + 0.1, "steel", bevel=0.01)
    drum(p, (1.45, 5.2, 0.2), 0.45, 0.5, "steel", "trim")
    p.box((CX, CY, 0.2), (1.2, 1.2, 2.0), "paint", bevel=0.08)
    p.box((CX + 0.62, CY, 0.3), (0.04, 0.7, 1.4), "team")
    p.ocyl((CX, CY, -0.8), k.FWD, 0.52, 1.0, 16, "dark")
    k.gun(p, CX, CY, -1.8, 2.6, 0.36)
    for sx in (-1, 1):
        p.box((CX + sx * 0.45, CY, -4.3), (0.15, 0.35, 0.35), "dark")
    piston(p, (CX, CY - 0.6, 0.6), (CX, CY - 0.45, -1.2), r=0.1)


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

# its wreck lies face down, legs bent (S-234)
FALLEN = unit.Fallen(body=[("x", -85), ("y", -15)],
                     joints={"thighL": [("x", 15)], "shinL": [("x", -85)], "thighR": [("x", 5)], "shinR": [("x", -25)]},
                     rest=("base", "thighL", "thighR"))

unit.run(__file__, "chs_abyssal", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.8, 1.0, 0.85, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [CX, CY, -4.55]}},
         budget=5000, tex=2048, scale=(S, S, S),
         previews=k.previews(10.8), fallen=FALLEN)
