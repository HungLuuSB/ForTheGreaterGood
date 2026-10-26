"""Tzar (Chaos heavy plasma tank, T2, footprint 2; S-181; the Fatboy's
counterpart): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_tzar/build.py

From its approved blockout (2026-10-26). Big shapes first: a long heavy
tracked hull (tools/hulls.py: exposed running gear under a slat cage,
`trackL` / `trackR` scrolling) with reactive blocks on its glacis and
exhaust stacks at the back, and a big cast `turret` (turns, the def's
piece) with a team roof plate, a hatch, an amber lamp, and a fat plasma
cannon in a mantlet with glowing coils and a heavy muzzle ring (`muzzle`).
Chaos reads crude and brutal (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from mech import rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

CY = 4.3  # the barrel's height
TURRET = (0.0, 3.1, 0.4)
DECK = 3.1


def build_base(p):
    hulls.tracked(p, "chaos", length=12.4, width=9.0, deck=DECK, track_w=1.9, wheels=7)
    for sx in (-1, 1):
        p.obox((sx * 2.2, 2.9, -5.5), (1, 0, 0), (0, 0.6, -1), 2.0, 1.0, 0.5, "era", bevel=0.05)
        p.cylinder("y", (sx * 2.4, DECK + 0.9, 5.0), 0.4, 1.8, 10, "dark")
        p.cylinder("y", (sx * 2.4, DECK + 1.82, 5.0), 0.42, 0.06, 10, "power")
    p.box((0, DECK + 0.03, 4.4), (3.0, 0.05, 1.6), "team", bevel=0.01)


def details_base(p):
    rivets(p, (-3.6, DECK + 0.01, -2.0), (3.6, DECK + 0.01, -2.0), 8, UP)


def build_turret(p):
    p.prism_x([(-3.4, DECK), (3.6, DECK), (3.6, 4.6), (3.0, 5.1), (-1.8, 5.1), (-3.4, 4.0)], -2.8, 2.8, "paint", bevel=0.18)
    p.box((0, 5.13, 1.2), (3.4, 0.06, 3.0), "team", bevel=0.02)
    p.cylinder("y", (1.6, 5.3, 2.0), 0.7, 0.4, 12, "dark")
    p.box((-2.0, 4.6, -2.7), (0.5, 0.3, 0.06), "head")
    for sx in (-1, 1):
        p.obox((sx * 2.9, 4.0, -0.4), (0, 0, 1), (sx, 0.2, 0), 4.0, 1.4, 0.4, "era", bevel=0.05)
    # the mantlet and the fat plasma cannon
    p.box((0, CY, -3.9), (2.6, 1.8, 0.8), "trim", bevel=0.1)
    p.ocyl((0, CY, -4.3), (0, 0, -1), 0.7, 6.0, 14, "steel")
    for z in (-5.6, -7.0):
        p.ocyl((0, CY, z), (0, 0, -1), 0.9, 0.3, 14, "power")
    p.ocyl((0, CY, -8.4), (0, 0, -1), 0.82, 0.2, 14, "trim")
    p.ocyl((0, CY, -10.2), (0, 0, -1), 1.0, 0.8, 14, "dark")
    p.ocyl((0, CY, -11.02), (0, 0, -1), 0.5, 0.05, 12, "weapon")


def details_turret(p):
    seam(p, (-2.6, 5.09, -1.0), (2.6, 5.09, -1.0), UP)
    for sx in (-1, 1):
        rivets(p, (sx * 2.81, 3.6, -2.4), (sx * 2.81, 3.6, 2.8), 6, (sx, 0, 0))


unit.run(__file__, "chs_tzar", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": [0.0, CY, -11.1]}},
         budget=5000)
