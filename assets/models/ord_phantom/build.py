"""Phantom (Order strategic bomber, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_phantom/build.py

New mesh from its blockout, at the T2 aircraft size (size-scale.md: span
12-14): a stealth flying wing with no tails, a sawtooth trailing edge, a
raised faceted spine with a slim canopy, buried intakes, a slit exhaust
with a glow line, large team panels on the wing tips, formation strips
along the leading edges; the bomb `bay` (doors ajar, a bay light on
weapon) and a `pylon` with two heavy bombs. `muzzle` in the bay. Order
reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, seam  # noqa: E402

BAY = (0.0, 0.2, 0.0)
PYLON = (0.0, 0.2, 2.2)


def build_base(p):
    # the flying wing: a swept outline with a sawtooth trailing edge
    wing = [(0.0, -4.2), (7.0, 1.6), (7.0, 2.3), (5.2, 2.0), (3.6, 3.4), (1.8, 2.4), (0.0, 3.6),
            (-1.8, 2.4), (-3.6, 3.4), (-5.2, 2.0), (-7.0, 2.3), (-7.0, 1.6)]
    p.prism_y(wing, 0.35, 0.65, "paint", bevel=0.04)
    # raised faceted spine, slim canopy, buried intakes, slit exhaust
    p.prism_x([(-4.0, 0.6), (3.2, 0.6), (3.4, 0.9), (-1.0, 1.45), (-3.2, 1.0)], -1.3, 1.3, "paint", bevel=0.06)
    p.prism_x([(-3.0, 1.0), (-1.4, 1.36), (-1.0, 1.6), (-2.2, 1.45)], -0.35, 0.35, "glass", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 1.0, 1.15, -0.8), (0.7, 0.12, 0.9), "dark")  # intakes
        p.box((sx * 5.4, 0.67, 1.7), (2.6, 0.04, 1.0), "team")  # wing-tip team panels
        p.box((sx * 7.02, 0.5, 1.95), (0.06, 0.14, 0.6), "light")
        p.obox((sx * 3.5, 0.67, -1.3), (0.64, 0, -sx * 0.77), (0, 1, 0), 0.12, 8.8, 0.03, "light")  # leading edges
    p.box((0, 0.75, 3.3), (2.2, 0.16, 0.2), "dark")  # slit exhaust
    p.box((0, 0.75, 3.41), (2.0, 0.06, 0.04), "light")
    p.box((0, 0.33, -3.6), (0.3, 0.06, 0.3), "head")


def details_base(p):
    seam(p, (-1.2, 1.2, 0.6), (1.2, 1.2, 0.6), UP)
    seam(p, (-4.0, 0.651, 1.2), (4.0, 0.651, 1.2), UP)


def build_bay(p):
    p.box((0, 0.3, 0.0), (1.4, 0.12, 3.0), "dark")
    for sx in (-1, 1):  # doors, ajar
        p.obox((sx * 0.74, 0.15, 0.0), (0, 0, 1), (sx * 0.95, -0.3, 0), 2.8, 0.34, 0.05, "paint")
    p.box((0, 0.22, 0.0), (0.6, 0.02, 2.0), "weapon")  # bay light


def build_pylon(p):
    p.box((0, 0.24, 2.2), (2.6, 0.14, 0.6), "trim")
    for sx in (-1, 1):
        p.cylinder("z", (sx * 0.9, -0.05, 2.0), 0.26, 1.8, 10, "paint")
        p.ocyl((sx * 0.9, -0.05, 1.1), (0, 0, -1), 0.26, 0.4, 10, "trim", radius2=0.06)
        p.box((sx * 0.9, -0.05, 2.9), (0.6, 0.04, 0.4), "trim")


def no_details(p):
    pass


unit.run(__file__, "ord_phantom", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("bay", "base", BAY, build_bay, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "bay", "at": [0, 0.1, 0.0]}},
         team_pieces=["base"])
