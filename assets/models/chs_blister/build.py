"""Blister (Chaos amphibious crawling bomb, T2, footprint 1; batch 2 of the
BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_blister/build.py

From its blockout: a low tick on four short clawed legs (tools/botkit.py
`spider`, the client's diagonal gait). The `base` is a dark body with
mandibles, a hazard band in front and a team band behind, and on its back
the swollen charge glowing through a cage of ribs. The trigger weapon's
`muzzle` (it never fires) sits between the mandibles. Chaos reads crude
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import hazard  # noqa: E402


def build_base(p):
    p.box((0, 1.0, 0), (1.4, 0.7, 1.8), "dark", bevel=0.08)
    p.box((0, 0.62, 0), (1.1, 0.12, 1.5), "trim")
    k.blob(p, (0, 1.55, 0.2), 0.85, 1.9, "power")
    for z in (-0.3, 0.2, 0.7):
        p.box((0, 2.12, z), (0.25, 0.08, 0.14), "steel")
        for sx in (-1, 1):
            k.beam(p, (sx * 0.12, 2.12, z), (sx * 0.95, 1.2, z), 0.12, 0.14, "steel", bevel=0.01)
    hazard(p, (0, 1.0, -0.92), (1, 0, 0), (0, 0, -1), 1.3, 0.22, stripes=5)
    p.box((0, 1.0, 0.92), (1.3, 0.22, 0.04), "team", bevel=0.01)


def build_torso(p):
    p.box((0, 0.95, -1.05), (0.9, 0.45, 0.4), "dark", bevel=0.05)
    for sx in (-1, 1):
        p.prism_x([(-0.85, 0.75), (-0.85, 1.05), (-1.4, 0.85), (-1.35, 0.75)], sx * 0.35 - 0.08, sx * 0.35 + 0.08, "steel", bevel=0.01)
        p.box((sx * 0.18, 1.06, -1.26), (0.14, 0.08, 0.04), "head")


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_blister", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", (0.0, 0.95, -0.85), build_torso, none)]
         + k.spider(4, 0.65, 1.0, 1.35, 1.7, 1.8, 0.24, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [0.0, 0.9, -1.3]}},
         budget=3400,
         previews=k.previews(2.2, 3.4))
