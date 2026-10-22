"""Plague (Chaos bomber, T1 air, jet): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_plague/build.py

A carpet bomber on the Harpy's lines, longer: a round fuselage with a
pointed nose and a bubble canopy, a wide delta with a team plate, dark
canards, a tall team fin, two engine pods with amber glow (running
channel); the `pylon` across the wing carries racks of small bombs, and the
`bay` (the weapon's muzzle) under the belly with its doors and an amber bay
light (weapon channel) (BAR style, M-15; Chaos reads light, M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import ring  # noqa: E402

PYLON = (0.0, 0.3, 1.4)
BAY = (0.0, 0.1, 0.2)


def build_base(p):
    p.cylinder("z", (0, 0.7, -0.2), 0.62, 6.8, 12, "paint")
    p.ocyl((0, 0.7, -3.6), (0, 0, -1), 0.62, 1.8, 12, "paint", radius2=0.06)
    p.ocyl((0, 1.25, -3.2), (0, 0, 1), 0.3, 1.4, 10, "glass", radius2=0.32)
    p.prism_y([(-3.8, 3.2), (0.0, -1.4), (3.8, 3.2)], 0.42, 0.56, "paint", bevel=0.02)
    p.box((0, 0.58, 2.4), (3.8, 0.04, 1.0), "team")
    for sx in (-1, 1):
        p.box((sx * 3.75, 0.5, 3.0), (0.08, 0.12, 0.4), "light")
        p.box((sx * 1.1, 0.9, -2.2), (1.6, 0.12, 0.7), "dark")
        p.cylinder("z", (sx * 1.0, 0.45, 2.8), 0.35, 2.4, 10, "trim")
        p.cylinder("z", (sx * 1.0, 0.45, 4.02), 0.28, 0.06, 10, "light")
        p.obox((sx * 1.9, 0.58, 0.9), (0.771, 0, -sx * 0.637), (0, 1, 0), 0.12, 5.37, 0.03, "light")  # along the leading edge
    p.prism_x([(1.9, 1.2), (3.8, 1.2), (3.8, 3.0), (2.9, 3.0)], -0.09, 0.09, "team", bevel=0.02)
    p.box((0, 1.33, 1.0), (0.12, 0.04, 3.4), "light")
    p.box((0, 3.02, 3.2), (0.14, 0.06, 0.8), "light")
    p.box((0, 0.1, -2.6), (0.3, 0.06, 0.3), "head")


def details_base(p):
    ring(p, (0, 0.7, -1.2), (0, 0, -1), 0.6)
    ring(p, (0, 0.7, 1.6), (0, 0, -1), 0.6)


def build_pylon(p):
    p.box((0, 0.3, 1.4), (4.6, 0.12, 0.6), "trim")
    for x in (-1.9, -1.4, 1.4, 1.9):
        p.cylinder("z", (x, 0.12, 1.4), 0.14, 0.8, 8, "paint")


def build_bay(p):
    p.box((0, 0.12, 0.2), (1.2, 0.12, 2.6), "dark")
    for sx in (-1, 1):
        p.obox((sx * 0.62, 0.0, 0.2), (0, 0, 1), (sx * 0.95, -0.3, 0), 2.4, 0.3, 0.05, "trim")
    p.box((0, 0.04, -1.1), (1.4, 0.1, 0.2), "steel")
    p.box((0, 0.05, 0.2), (0.5, 0.02, 1.6), "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_plague", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("bay", "base", BAY, build_bay, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "bay", "at": [0, -0.1, 0.2]}},
         team_pieces=["base"])
