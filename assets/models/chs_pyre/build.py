"""Pyre (Chaos fast flamethrower bot, T2, footprint 1; batch 2 of the BAR
roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_pyre/build.py

From its blockout: lean, on bare strut legs (tools/bots.py). The `torso`
(turns) leans forward: a chamfered body with a low head and an amber slit,
two hazard fuel tanks on its back feeding a hose to the right arm, a
flamer nozzle with a lit pilot (`muzzle`), a spike on the left shoulder.
Chaos reads crude (M-14). Our own design. Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum  # noqa: E402

TORSO = (0.0, 3.2, 0.0)
NX, NY = 1.05, 3.7


def build_base(p):
    p.box((0, 2.8, 0), (1.4, 0.75, 1.2), "dark", bevel=0.05)
    drum(p, (0, 3.15, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    # leaning forward: a raked chamfered body
    p.prism_x([(-0.9, 3.3), (0.7, 3.2), (0.6, 4.4), (0.0, 4.6), (-1.1, 4.3)], -0.85, 0.85, "paint", bevel=0.06)
    p.box((-0.4, 3.75, -0.93), (0.5, 0.35, 0.04), "team", bevel=0.01)
    k.head(p, (-0.3, 4.65, -0.65), (0.7, 0.45, 0.7), "chaos")
    for sx in (-1, 1):
        p.ocyl((sx * 0.35, 3.4, 0.95), k.UP, 0.28, 1.4, 12, "hazard")
        p.ocyl((sx * 0.35, 4.8, 0.95), k.UP, 0.28, 0.12, 12, "steel", radius2=0.12)
    cable(p, [(0.35, 3.5, 1.2), (0.75, 3.3, 0.6), (1.0, 3.5, -0.1)], r=0.07)
    drum(p, (0.9, 3.95, -0.2), 0.25, 0.3, "steel", "trim")
    p.box((NX, NY, -0.5), (0.55, 0.55, 1.2), "trim", bevel=0.04)
    k.gun(p, NX, NY, -1.1, 0.85, 0.2, kind="dark", mouth="steel")
    p.box((NX, NY - 0.32, -1.6), (0.1, 0.1, 0.2), "power")
    p.ocyl((-0.7, 4.35, 0.0), k.UP, 0.15, 0.6, 6, "steel", radius2=0.02)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_pyre", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none)]
         + k.biped(2.6, 0.6, 0.5, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [NX, NY, -2.05]}},
         budget=3400,
         previews=k.previews(5.0))
