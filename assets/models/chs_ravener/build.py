"""Ravener (Chaos heavy all-terrain spider, heat ray, T2, footprint 2; batch
2 of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_ravener/build.py

From its blockout: a heavy dark body on four thick jointed legs, knees
high, pistons and hooked claws (tools/botkit.py `spider`, the client's
diagonal gait), a raked glacis and spikes along its back. On top the
`torso` (turns): an armoured turret with a team plate and the heat-ray
projector, finned barrel and a wide amber lens (`muzzle`). Chaos reads
crude (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402

TORSO = (0.0, 2.7, 0.0)
PY = 3.15


def build_base(p):
    p.box((0, 2.2, 0), (2.2, 1.0, 2.8), "dark", bevel=0.1)
    p.prism_x([(-1.4, 1.75), (-1.4, 2.65), (-2.15, 2.15), (-2.0, 1.8)], -1.0, 1.0, "paint", bevel=0.05)
    p.box((0, 2.35, -1.85), (1.0, 0.1, 0.04), "head")
    p.box((0, 1.65, 0), (1.8, 0.15, 2.4), "trim")
    for x in (-0.7, 0.0, 0.7):
        p.ocyl((x, 2.7, 1.1), (0, 1, 0.4), 0.18, 0.7, 6, "steel", radius2=0.02)
    drum(p, (0, 2.68, 0), 0.8, 0.05, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-0.9, 1.9, 1.41), (0.9, 1.9, 1.41), 5, (0, 0, 1))


def build_torso(p):
    k.shell(p, (0, PY, -0.1), (1.7, 0.9, 1.8), "chaos")
    p.box((0, 3.62, 0.2), (1.1, 0.04, 0.8), "team", bevel=0.01)
    p.ocyl((0, PY, -0.9), k.FWD, 0.4, 1.3, 16, "steel")
    for z in (-1.15, -1.45, -1.75):
        p.ocyl((0, PY, z), k.FWD, 0.52, 0.08, 16, "dark")
    p.ocyl((0, PY, -2.15), k.FWD, 0.5, 0.15, 18, "trim")
    p.ocyl((0, PY, -2.27), k.FWD, 0.42, 0.03, 18, "weapon")


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_ravener", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none)]
         + k.spider(4, 1.0, 2.2, 2.8, 3.8, 3.8, 0.42, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, PY, -2.4]}},
         budget=3600, tex=2048,
         previews=k.previews(4.0, 7.6))
