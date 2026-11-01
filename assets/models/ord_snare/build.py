"""Snare (Order all-terrain spider with an EMP laser, T2, footprint 1;
batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_snare/build.py

From its blockout: a light body on four long jointed legs, knees high and
claw tips (tools/botkit.py `spider`, the client's diagonal gait). On top
the `torso` (turns): a compact team-capped head with the EMP emitter in
front, a barrel ringed with lit coils and a wide lit ring at its mouth
(`muzzle`). Order reads clean (M-14). Our own design. Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 2.4, 0.0)
EY = 2.75


def build_base(p):
    p.box((0, 2.0, 0), (1.5, 0.8, 2.0), "paint", bevel=0.1)
    p.box((0, 1.55, 0.1), (1.2, 0.15, 1.6), "trim")
    p.box((0, 2.1, 1.02), (0.9, 0.4, 0.04), "team")
    p.box((0, 2.1, -1.01), (0.7, 0.1, 0.03), "light")
    drum(p, (0, 2.42, 0), 0.5, 0.05, "steel", "trim", axis="y")


def build_torso(p):
    p.box((0, EY, -0.1), (1.2, 0.7, 1.4), "paint", bevel=0.08)
    p.box((0, 3.12, 0.15), (0.9, 0.04, 0.8), "team")
    k.visor(p, (0, 2.95, -0.81), 0.7, 0.12)
    p.ocyl((0, EY, -0.75), k.FWD, 0.27, 0.75, 14, "steel")
    for z in (-0.95, -1.2):
        p.ocyl((0, EY, z), k.FWD, 0.36, 0.08, 14, "power")
    p.ocyl((0, EY, -1.38), k.FWD, 0.48, 0.12, 18, "trim")
    p.ocyl((0, EY, -1.5), k.FWD, 0.4, 0.03, 18, "weapon")


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_snare", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none)]
         + k.spider(4, 0.8, 2.0, 2.2, 3.4, 3.2, 0.28, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, EY, -1.6]}},
         budget=2800,
         previews=k.previews(3.5, 6.4))
