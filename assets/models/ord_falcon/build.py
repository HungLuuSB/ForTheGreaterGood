"""Falcon (Order fighter, T1 air, jet): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_falcon/build.py

A heavy twin-engine air-superiority fighter: a slab-sided fuselage with a
long nose and a dark canopy, swept wings with team plates and cyan wingtip
nav lights, canted twin tails in team color, two engine nozzles with a cyan
glow (running channel); the `pylon` (the weapon's turret piece) under the
belly carries two missiles with ice-white seekers (weapon channel) (BAR
style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, seam  # noqa: E402

PYLON = (0.0, 0.05, 0.2)


def build_base(p):
    p.prism_x([(-5.3, 0.6), (-3.6, 0.3), (3.7, 0.3), (3.9, 0.55), (3.7, 1.0), (-2.0, 1.05), (-3.6, 0.85)], -0.8, 0.8, "paint", bevel=0.05)
    p.prism_x([(-3.2, 1.0), (-2.0, 1.05), (-1.3, 1.45), (-2.4, 1.38)], -0.38, 0.38, "glass", bevel=0.03)  # canopy
    for sx in (-1, 1):  # swept wings, team plates, wingtip nav lights
        pts = [(sx * 0.8, -1.0), (sx * 3.4, 1.4), (sx * 3.4, 2.1), (sx * 0.8, 2.3)]
        if sx < 0:
            pts = pts[::-1]
        p.prism_y(pts, 0.38, 0.52, "paint", bevel=0.02)
        p.box((sx * 2.1, 0.54, 1.3), (1.1, 0.04, 0.8), "team")
        p.box((sx * 3.42, 0.45, 1.75), (0.06, 0.12, 0.6), "light")
        p.box((sx * 0.45, 0.6, 3.82), (0.1, 0.1, 0.1), "steel")
        # canted tails in team color
        t = math.radians(15) * sx
        p.obox((sx * 0.62, 1.55, 3.0), (0, 0, 1), (math.cos(t), -math.sin(t), 0), 1.4, 1.2, 0.12, "team", bevel=0.02)
        # engine nozzles with glow
        p.cylinder("z", (sx * 0.42, 0.62, 3.95), 0.3, 0.3, 10, "dark", radius2=0.26)
        p.cylinder("z", (sx * 0.42, 0.62, 4.11), 0.22, 0.02, 10, "light")
        p.box((sx * 0.82, 0.75, -1.6), (0.04, 0.3, 0.9), "dark")  # intakes
    p.box((0, 0.3, -3.8), (0.3, 0.06, 0.3), "head")  # landing light
    for sx in (-1, 1):  # formation strips: fuselage sides, wing tops, tail tips
        p.box((sx * 0.81, 0.8, 0.6), (0.04, 0.14, 4.4), "light")
        p.obox((sx * 2.2, 0.54, 0.7), (1, 0, 0), (0, 1, 0), 0.12, 2.6, 0.03, "light")
        p.box((sx * 0.8, 2.16, 3.0), (0.14, 0.06, 1.2), "light")


def details_base(p):
    seam(p, (-0.8, 1.051, 0.0), (0.8, 1.051, 0.0), UP)
    seam(p, (-0.8, 1.031, 2.0), (0.8, 1.031, 2.0), UP)


def build_pylon(p):
    x, y, z = PYLON
    p.box((0, 0.15, 0.2), (2.2, 0.2, 1.4), "trim", bevel=0.03)
    for sx in (-1, 1):
        p.cylinder("z", (sx * 0.9, -0.15, -0.1), 0.15, 2.0, 8, "paint")
        p.ocyl((sx * 0.9, -0.15, -1.1), (0, 0, -1), 0.15, 0.25, 8, "weapon", radius2=0.04)  # seekers
        p.box((sx * 0.9, -0.15, 0.8), (0.4, 0.04, 0.3), "trim")


def no_details(p):
    pass


unit.run(__file__, "ord_falcon", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "pylon", "at": [0, -0.15, -1.2]}},
         team_pieces=["base"])
