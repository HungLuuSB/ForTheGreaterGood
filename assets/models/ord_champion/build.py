"""Champion (Order battle mech, rapid laser, T3, footprint 3; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_champion/build.py

From its blockout, laid out at bot size and scaled x2.1 (unit.run `scale`;
the blockout scales the same). A heavy upright mech on armoured legs
(tools/bots.py). The `torso` (turns): a big chest with a raked team crest,
a sensor head, team shoulder pads and a backpack with radiators; the right
arm is a rotary laser cannon, four barrels round a lit lens (`muzzle`);
the left carries a tower shield with a team blazon. Order reads clean and
heavy (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402

S = 2.1
TORSO = (0.0, 3.6, 0.0)
BODY = ((0, 4.7, 0), (3.0, 2.2, 2.4))
LX, LY = 2.0, 3.7


def build_base(p):
    p.box((0, 3.2, 0), (2.4, 0.8, 1.8), "dark", bevel=0.06)
    drum(p, (0, 3.55, 0), 0.85, 0.14, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.obox((0, 4.8, -1.3), (1, 0, 0), (0, 0.4, -1), 2.6, 1.6, 0.2, "team", bevel=0.05)
    p.box((0, 4.0, -1.27), (2.0, 0.12, 0.08), "light")
    k.head(p, (0, 6.13, -0.4), (1.1, 0.65, 1.0), "order")
    for sx in (-1, 1):
        k.pad(p, (sx * 1.95, 5.75, 0), (1.25, 0.8, 2.25), "order")
        drum(p, (sx * 1.62, 5.1, 0), 0.4, 0.4, "steel", "trim")
    p.box((0, 4.8, 1.6), (2.2, 1.6, 0.9), "trim", bevel=0.06)
    for x in (-0.7, 0.0, 0.7):
        p.box((x, 4.8, 2.07), (0.4, 1.2, 0.04), "dark")
    p.box((0, 5.5, 2.07), (1.6, 0.12, 0.04), "power")
    # the rotary laser
    p.box((LX, 4.4, -0.2), (0.9, 1.6, 1.0), "trim", bevel=0.06)
    p.ocyl((LX, LY, 0.0), k.FWD, 0.62, 2.3, 18, "paint")
    p.ocyl((LX, LY, -2.25), k.FWD, 0.5, 0.12, 18, "power")
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, y = LX + math.cos(a) * 0.3, LY + math.sin(a) * 0.3
        p.ocyl((x, y, -2.3), k.FWD, 0.13, 1.35, 10, "steel")
    p.ocyl((LX, LY, -3.5), k.FWD, 0.52, 0.18, 18, "trim")
    p.ocyl((LX, LY, -3.62), k.FWD, 0.14, 0.03, 10, "weapon")
    # the shield
    p.box((-2.0, 4.4, -0.2), (0.8, 1.4, 0.9), "trim", bevel=0.05)
    p.box((-2.15, 4.0, -0.6), (0.4, 2.6, 2.0), "paint", bevel=0.08)
    p.box((-2.37, 4.1, -0.6), (0.04, 1.6, 1.2), "team", bevel=0.01)
    p.box((-2.37, 2.85, -0.6), (0.04, 0.12, 1.6), "light")


def details_torso(p):
    k.shell_details(p, *BODY)
    rivets(p, (-2.36, 5.1, -1.3), (-2.36, 5.1, 0.1), 4, (-1, 0, 0))


none = lambda p: None  # noqa: E731

# its wreck lies face down, knees bent, its guns dug into the dirt (S-234)
FALLEN = unit.Fallen(body=[("x", -86), ("y", -10)],
                     joints={"thighL": [("x", 12)], "shinL": [("x", -85)], "thighR": [("x", 4)], "shinR": [("x", -40)]},
                     rest=("base", "thighL", "thighR"))

unit.run(__file__, "ord_champion", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(3.0, 1.0, 0.85, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [LX, LY, -3.7]}},
         budget=5000, tex=2048, scale=(S, S, S),
         previews=k.previews(6.6 * S), fallen=FALLEN)
