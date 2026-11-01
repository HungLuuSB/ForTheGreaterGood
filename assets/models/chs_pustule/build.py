"""Pustule (Chaos cloaked amphibious crawling bomb with a big blast, T2,
footprint 1; batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig
data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_pustule/build.py

From its blockout: a fat tick on four clawed legs (tools/botkit.py
`spider`, the client's diagonal gait). The `base` is a dark body with a
hazard band in front and a team band behind, carrying a huge glowing
charge caged in heavy ribs and a spine. The trigger weapon's `muzzle` (it
never fires) sits at the front. Chaos reads crude (M-14). Our own design.
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import hazard, rivets  # noqa: E402


def build_base(p):
    p.box((0, 1.2, 0), (1.8, 0.8, 2.2), "dark", bevel=0.08)
    p.box((0, 0.78, 0), (1.5, 0.12, 1.9), "trim")
    k.blob(p, (0, 2.0, 0.3), 1.2, 2.6, "power", slices=10)
    p.box((0, 2.95, 0.3), (0.2, 0.2, 2.6), "steel", bevel=0.02)
    for z in (-0.5, 0.2, 0.9):
        for sx in (-1, 1):
            k.beam(p, (sx * 0.1, 2.95, z), (sx * 0.85, 2.65, z), 0.18, 0.18, "steel", bevel=0.02)
            k.beam(p, (sx * 0.85, 2.65, z), (sx * 1.25, 1.4, z), 0.18, 0.18, "steel", bevel=0.02)
    for z in (-0.85, 1.45):
        p.ocyl((0, 2.95, z), (0, 0, 1), 0.16, 0.2, 8, "dark")
    hazard(p, (0, 1.2, -1.12), (1, 0, 0), (0, 0, -1), 1.7, 0.26, stripes=6)
    p.box((0, 1.2, 1.12), (1.7, 0.26, 0.04), "team", bevel=0.01)
    p.box((0, 1.45, -1.12), (0.5, 0.1, 0.04), "head")


def details_base(p):
    rivets(p, (-0.8, 0.95, -1.11), (0.8, 0.95, -1.11), 5, (0, 0, -1))


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_pustule", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)]
         + k.spider(4, 0.85, 1.2, 1.75, 2.2, 2.4, 0.3, "chaos"),
         attachments={"muzzle": {"parent": "base", "at": [0.0, 1.2, -1.3]}},
         budget=4000,
         previews=k.previews(3.1, 4.6))
