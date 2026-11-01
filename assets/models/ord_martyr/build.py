"""Martyr (Order amphibious rolling bomb, T2, footprint 1; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_martyr/build.py

From its blockout: no legs. A small sealed chassis (`base`) under the
`shell`, a ball that rolls (a client piece spinning about X): armoured
segments with a team band round its middle, hazard rings either side and
lit charge windows at the axle ends. The trigger weapon's `muzzle` (it
never fires) sits at the front. Order reads clean (M-14). Our own design.
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum  # noqa: E402

C = (0.0, 1.35, 0.0)
R = 1.3
X = (1, 0, 0)


def r_at(x):
    return math.sqrt(max(R * R - x * x, 0.0025))


def build_base(p):
    p.box((0, 0.35, 0), (1.2, 0.5, 1.2), "dark", bevel=0.06)
    drum(p, (0, 1.35, 0), 0.18, 2.3, "steel", "trim")


def build_shell(p):
    cx, cy, cz = C
    cuts = [-1.22, -1.0, -0.72, -0.3, 0.3, 0.72, 1.0, 1.22]
    kinds = ["trim", "paint", "hazard", "team", "hazard", "paint", "trim"]
    for (a, b), kind in zip(zip(cuts, cuts[1:]), kinds):
        mid = (a + b) / 2
        for x0, x1 in ((a, mid), (mid, b)):
            p.ocyl((cx + x0, cy, cz), X, r_at(x0), x1 - x0, 20, kind, radius2=r_at(x1))
    for sx in (-1, 1):
        p.ocyl((cx + sx * 1.22, cy, cz), (sx, 0, 0), r_at(1.22) + 0.02, 0.04, 16, "power")
        for k in range(4):  # armour seams round each half
            a = math.radians(45 + k * 90)
            p.box((cx + sx * 0.86, cy + math.sin(a) * 0.93, cz + math.cos(a) * 0.93), (0.3, 0.06, 0.06), "dark")


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_martyr", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("shell", "base", C, build_shell, none)],
         attachments={"muzzle": {"parent": "base", "at": [0.0, 1.35, -1.4]}},
         budget=2000,
         previews=[("35", (-5.5, 4.5, -6.5), (0, 1.2, 0), 50), ("side", (7.5, 1.6, 0), (0, 1.2, 0), 50),
                   ("80", (0, 9.0, 1.8), (0, 1.1, 0), 50), ("close", (-2.9, 2.6, -3.4), (0, 1.3, 0), 35)])
