"""Harpy (Chaos fighter, T1 air, jet): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_harpy/build.py

A light delta fighter: a round fuselage with a pointed nose and a bubble
canopy, a big delta wing with a team plate, dark canards, one tall team fin,
two engine pods under the wing roots with amber glow (running channel); the
`pylon` (the weapon's turret piece) carries four cheap missiles with amber
seekers (weapon channel) (BAR style, M-15; Chaos reads light, M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, ring  # noqa: E402

PYLON = (0.0, -0.05, 0.0)


def build_base(p):
    p.cylinder("z", (0, 0.7, -0.2), 0.62, 6.2, 12, "paint")
    p.ocyl((0, 0.7, -3.3), (0, 0, -1), 0.62, 1.8, 12, "paint", radius2=0.06)  # nose
    p.ocyl((0, 1.25, -2.9), (0, 0, 1), 0.3, 1.4, 10, "glass", radius2=0.32)  # canopy
    # delta wing, team plate, wingtip lights
    p.prism_y([(-3.4, 3.2), (0.0, -1.4), (3.4, 3.2)], 0.42, 0.56, "paint", bevel=0.02)
    p.box((0, 0.58, 2.4), (3.4, 0.04, 1.0), "team")
    for sx in (-1, 1):
        p.box((sx * 3.35, 0.5, 3.0), (0.08, 0.12, 0.4), "light")
        p.box((sx * 1.1, 0.9, -1.9), (1.6, 0.12, 0.7), "dark")  # canards
        # engine pods with glowing nozzles
        p.cylinder("z", (sx * 1.0, 0.45, 2.5), 0.35, 2.4, 10, "trim")
        p.cylinder("z", (sx * 1.0, 0.45, 3.72), 0.28, 0.06, 10, "light")
    p.prism_x([(1.6, 1.2), (3.4, 1.2), (3.4, 3.0), (2.6, 3.0)], -0.09, 0.09, "team", bevel=0.02)  # fin
    p.box((0, 0.1, -2.4), (0.3, 0.06, 0.3), "head")
    for sx in (-1, 1):  # formation strips along the wing's leading edges and the spine
        p.obox((sx * 1.7, 0.58, 0.9), (0.804, 0, -sx * 0.594), (0, 1, 0), 0.12, 5.15, 0.03, "light")  # along the leading edge
    p.box((0, 1.33, 1.0), (0.12, 0.04, 3.0), "light")
    p.box((0, 3.02, 2.8), (0.14, 0.06, 0.8), "light")


def details_base(p):
    ring(p, (0, 0.7, -1.0), (0, 0, -1), 0.6)
    ring(p, (0, 0.7, 1.4), (0, 0, -1), 0.6)


def build_pylon(p):
    p.box((0, -0.05, 0.0), (1.0, 0.35, 2.4), "trim", bevel=0.03)
    p.box((0, -0.15, -0.2), (3.0, 0.1, 0.6), "dark")
    for x in (-1.4, -0.6, 0.6, 1.4):
        p.cylinder("z", (x, -0.3, -0.2), 0.12, 1.6, 8, "paint")
        p.ocyl((x, -0.3, -1.0), (0, 0, -1), 0.12, 0.2, 8, "weapon", radius2=0.03)


def no_details(p):
    pass


unit.run(__file__, "chs_harpy", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "pylon", "at": [0, -0.3, -1.2]}},
         team_pieces=["base"])
