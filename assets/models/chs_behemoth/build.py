"""Behemoth (Chaos strategic bomber, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_behemoth/build.py

New mesh from its blockout, the biggest Chaos delta (size-scale.md: T2
aircraft, span 12-14): a long round fuselage with an armored belly tub, a
blunt nose and a stepped canopy, a broad delta with team plates and a tall
team fin, four engine pods with glowing nozzles, chaff boxes on the
outer pods, formation strips along the leading edges; the bomb `bay`
(doors ajar, amber bay light on weapon) and a `pylon` rail with a row of
bombs. `muzzle` in the bay. Chaos reads rugged and aggressive (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import ring  # noqa: E402

BAY = (0.0, 0.0, 0.2)
PYLON = (0.0, 0.0, 2.6)


def build_base(p):
    p.cylinder("z", (0, 0.9, 0.0), 0.9, 9.2, 14, "paint")
    p.ocyl((0, 0.9, -4.6), (0, 0, -1), 0.9, 1.6, 14, "paint", radius2=0.3)  # blunt nose
    p.box((0, 0.35, 0.2), (1.5, 0.5, 6.4), "trim", bevel=0.06)  # armored belly tub
    p.prism_x([(-4.6, 1.5), (-3.2, 1.5), (-2.8, 1.95), (-3.8, 1.85)], -0.5, 0.5, "glass", bevel=0.03)
    p.prism_y([(-6.6, 4.0), (0.0, -2.6), (6.6, 4.0)], 0.6, 0.8, "paint", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 3.0, 0.82, 2.8), (3.0, 0.04, 1.6), "team")
        p.box((sx * 6.52, 0.7, 3.8), (0.1, 0.14, 0.5), "light")
        p.obox((sx * 3.3, 0.82, 0.7), (0.707, 0, -sx * 0.707), (0, 1, 0), 0.14, 9.0, 0.03, "light")
        for x, chaff in ((1.4, False), (3.2, True)):  # engine pods
            p.cylinder("z", (sx * x, 0.55, 3.2), 0.5, 3.0, 12, "trim")
            p.cylinder("z", (sx * x, 0.55, 4.72), 0.4, 0.06, 12, "light")
            if chaff:
                p.box((sx * x, 1.05, 2.8), (0.5, 0.35, 1.2), "dark", bevel=0.02)
    p.prism_x([(2.4, 1.7), (4.6, 1.7), (4.8, 4.4), (3.6, 4.4)], -0.12, 0.12, "team", bevel=0.02)
    p.box((0, 4.42, 4.2), (0.18, 0.08, 1.0), "light")
    p.box((0, 0.08, -3.4), (0.36, 0.06, 0.36), "head")


def details_base(p):
    ring(p, (0, 0.9, -1.6), (0, 0, -1), 0.88)
    ring(p, (0, 0.9, 1.8), (0, 0, -1), 0.88)


def build_bay(p):
    p.box((0, 0.08, 0.2), (1.2, 0.12, 3.0), "dark")
    for sx in (-1, 1):
        p.obox((sx * 0.64, -0.05, 0.2), (0, 0, 1), (sx * 0.95, -0.3, 0), 2.8, 0.32, 0.05, "paint")
    p.box((0, 0.01, 0.2), (0.5, 0.02, 2.0), "weapon")


def build_pylon(p):
    p.box((0, -0.05, 2.6), (3.6, 0.14, 0.5), "trim")
    for x in (-1.4, -0.7, 0.0, 0.7, 1.4):
        p.cylinder("z", (x, -0.3, 2.5), 0.2, 1.2, 8, "paint")
        p.ocyl((x, -0.3, 1.9), (0, 0, -1), 0.2, 0.3, 8, "trim", radius2=0.05)


def no_details(p):
    pass


unit.run(__file__, "chs_behemoth", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("bay", "base", BAY, build_bay, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "bay", "at": [0, -0.1, 0.2]}},
         team_pieces=["base"])
