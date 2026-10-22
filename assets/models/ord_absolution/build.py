"""Absolution (Order bomber, T1 air, jet): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_absolution/build.py

A heavy twin-engine strike bomber: a long slab-sided fuselage with a dark
canopy, broad swept wings with team plates and cyan wingtip nav lights,
canted twin tails in team color, two engine nozzles with a cyan glow
(running channel); the `pylon` spans under the wings with two hard points,
and the `bay` (the bomb bay, the weapon's muzzle) under the belly shows its
doors and an ice-white bay light (weapon channel) (BAR style, M-15; Order
reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, seam  # noqa: E402

PYLON = (0.0, 0.2, 1.0)
BAY = (0.0, 0.1, 0.2)


def build_base(p):
    p.prism_x([(-5.6, 0.6), (-3.8, 0.25), (4.0, 0.25), (4.2, 0.55), (4.0, 1.05), (-2.2, 1.1), (-3.9, 0.85)], -0.85, 0.85, "paint", bevel=0.05)
    p.prism_x([(-3.6, 1.0), (-2.4, 1.08), (-1.6, 1.5), (-2.8, 1.42)], -0.4, 0.4, "glass", bevel=0.03)
    for sx in (-1, 1):
        pts = [(sx * 0.85, -1.2), (sx * 3.8, 1.5), (sx * 3.8, 2.3), (sx * 0.85, 2.5)]
        if sx < 0:
            pts = pts[::-1]
        p.prism_y(pts, 0.36, 0.52, "paint", bevel=0.02)
        p.box((sx * 2.45, 0.54, 1.1), (1.3, 0.04, 1.0), "team")
        p.box((sx * 3.82, 0.45, 1.9), (0.06, 0.12, 0.7), "light")
        p.obox((sx * 2.4, 0.54, 0.6), (1, 0, 0), (0, 1, 0), 0.12, 2.8, 0.03, "light")
        p.box((sx * 0.86, 0.8, 0.6), (0.04, 0.14, 5.0), "light")
        t = math.radians(15) * sx
        p.obox((sx * 0.62, 1.55, 3.3), (0, 0, 1), (math.cos(t), -math.sin(t), 0), 1.4, 1.2, 0.12, "team", bevel=0.02)
        p.cylinder("z", (sx * 0.42, 0.62, 4.25), 0.3, 0.3, 10, "dark", radius2=0.26)
        p.cylinder("z", (sx * 0.42, 0.62, 4.41), 0.22, 0.02, 10, "light")
        p.box((sx * 0.86, 0.75, -1.9), (0.04, 0.3, 0.9), "dark")
    p.box((0, 0.24, -4.0), (0.3, 0.06, 0.3), "head")


def details_base(p):
    seam(p, (-0.85, 1.101, 0.0), (0.85, 1.101, 0.0), UP)
    seam(p, (-0.85, 1.081, 2.2), (0.85, 1.081, 2.2), UP)


def build_pylon(p):
    p.box((0, 0.22, 1.0), (5.2, 0.12, 0.6), "trim")
    for sx in (-1, 1):
        p.box((sx * 2.2, 0.08, 1.0), (0.3, 0.2, 0.9), "steel")


def build_bay(p):
    p.box((0, 0.12, 0.2), (1.2, 0.12, 2.6), "dark")
    for sx in (-1, 1):  # doors, ajar
        p.obox((sx * 0.62, 0.0, 0.2), (0, 0, 1), (sx * 0.95, -0.3, 0), 2.4, 0.3, 0.05, "paint")
    p.box((0, 0.04, -1.1), (1.4, 0.1, 0.2), "steel")
    p.box((0, 0.05, 0.2), (0.5, 0.02, 1.6), "weapon")  # bay light


def no_details(p):
    pass


unit.run(__file__, "ord_absolution", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("bay", "base", BAY, build_bay, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "bay", "at": [0, -0.1, 0.2]}},
         team_pieces=["base"])
