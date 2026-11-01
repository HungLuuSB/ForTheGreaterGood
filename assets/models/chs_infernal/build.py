"""Infernal (Chaos flamethrower mech with anti-air shoulder rockets, T3,
footprint 3; batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig
data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_infernal/build.py

From its blockout, laid out at bot size and scaled x2.2 (unit.run `scale`;
the blockout scales the same). A heavy mech on thick strut legs
(tools/bots.py). The `torso` (turns): a chamfered body under a horned head
with an amber slit, two hazard fuel tanks on its back feeding hoses to the
arms; each forearm a flamer cannon with a lit pilot (`muzzle` right,
`muzzle2` left); a rocket pod on each shoulder raked skyward, its cells lit
(`aa_muzzle`). Chaos reads crude and brutal (M-14). Our own design. Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum  # noqa: E402

S = 2.2
TORSO = (0.0, 3.6, 0.0)
BODY = ((0, 4.65, 0), (2.8, 2.1, 2.3))
FX, FY = 1.95, 3.8
RAKE = math.radians(55)
POD_N = (0.0, math.sin(RAKE), -math.cos(RAKE))  # the pods' faces, up and forward
PODS = (1.75, 6.05, 0.2)


def build_base(p):
    p.box((0, 3.2, 0), (2.4, 0.8, 1.8), "dark", bevel=0.05)
    drum(p, (0, 3.55, 0), 0.85, 0.12, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "chaos")
    k.head(p, (0, 6.0, -0.6), (1.0, 0.65, 0.9), "chaos")
    for sx in (-1, 1):
        p.ocyl((sx * 0.45, 6.25, -0.5), (sx * 0.5, 1, 0.15), 0.16, 1.0, 6, "steel", radius2=0.02)
    p.box((0, 4.4, -1.17), (1.4, 0.5, 0.04), "team", bevel=0.01)
    for sx in (-1, 1):
        p.ocyl((sx * 0.55, 3.9, 1.45), k.UP, 0.35, 1.6, 12, "hazard")
        p.ocyl((sx * 0.55, 5.5, 1.45), k.UP, 0.35, 0.14, 12, "steel", radius2=0.15)
        cable(p, [(sx * 0.55, 4.1, 1.75), (sx * 1.5, 4.0, 0.9), (sx * FX, FY + 0.3, 0.2)], r=0.08)
        x = sx * FX
        drum(p, (sx * 1.6, 5.2, 0), 0.4, 0.5, "steel", "trim")
        p.box((x, 4.5, -0.1), (0.9, 1.6, 1.0), "trim", bevel=0.06)
        p.box((x, FY, -0.4), (0.9, 0.8, 1.0), "paint", bevel=0.05)
        k.gun(p, x, FY, -0.6, 1.75, 0.34, kind="dark", mouth="steel")
        p.box((x, FY - 0.42, -2.0), (0.12, 0.12, 0.25), "power")
        c, n = lib.vec((x, PODS[1], PODS[2])), lib.vec(POD_N)
        p.obox(tuple(c), (1, 0, 0), POD_N, 1.0, 0.9, 1.4, "paint", bevel=0.06)
        k.tilted_tubes(p, tuple(c + n * 0.72), POD_N, (1, 0, 0), 2, 2, 0.4, 0.14)


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731
aa = lib.vec(PODS) + lib.vec(POD_N) * 0.85

# its wreck lies face down and twisted, one leg kicked up (S-234)
FALLEN = unit.Fallen(body=[("x", -80), ("z", -10)],
                     joints={"thighL": [("x", 5)], "shinL": [("x", -30)], "thighR": [("x", 15)], "shinR": [("x", -95)]},
                     rest=("base", "thighL", "thighR"))

unit.run(__file__, "chs_infernal", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(3.0, 1.0, 0.9, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [FX, FY, -2.45]},
                      "muzzle2": {"parent": "torso", "at": [-FX, FY, -2.45]},
                      "aa_muzzle": {"parent": "torso", "at": [aa.x, aa.y, aa.z]}},
         budget=5000, tex=2048, scale=(S, S, S),
         previews=k.previews(15.9), fallen=FALLEN)
