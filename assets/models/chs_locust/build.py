"""Locust (Chaos swarm tank, T1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_locust/build.py

A very small cheap tracked tank, narrow and high off the ground: a short
slat-caged hull, a little boxy turret with an amber sight and a team top,
and a long thin autocannon (`barrel`) with a muzzle ring (weapon channel).
Reads smaller and lighter than the Ravager (BAR style, M-15; Chaos reads
light, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402

TURRET = (0.0, 1.8, 0.7)
BARREL = (0.0, 2.2, -0.3)


def build_base(p):
    hulls.tracked(p, "chaos", length=5.2, width=3.6, deck=1.8, track_w=0.6, wheels=4)


def no_details(p):
    pass


def build_turret(p):
    p.prism_y([(-1.0, -0.4), (1.0, -0.4), (1.0, 1.75), (-1.0, 1.75)], 1.8, 2.6, "paint", bevel=0.04, top_scale=0.88)
    p.box((0, 2.62, 0.8), (1.4, 0.04, 1.4), "team")
    p.box((0.6, 2.75, 0.1), (0.4, 0.3, 0.4), "trim")
    p.box((0.6, 2.77, -0.12), (0.3, 0.14, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 1.01, 2.2, 0.7), (0.04, 0.16, 1.6), "light")


def build_barrel(p):
    p.box((0, 2.2, -0.45), (0.6, 0.5, 0.4), "paint", bevel=0.03)
    p.cylinder("z", (0, 2.2, -1.95), 0.12, 2.8, 8, "steel")
    p.cylinder("z", (0, 2.2, -3.3), 0.16, 0.3, 8, "dark")
    p.cylinder("z", (0, 2.2, -3.05), 0.15, 0.08, 8, "weapon")


unit.run(__file__, "chs_locust", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, no_details),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, 2.2, -3.5]}})
