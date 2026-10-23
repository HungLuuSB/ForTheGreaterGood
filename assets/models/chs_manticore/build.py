"""Manticore (Chaos air superiority fighter, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_manticore/build.py

New mesh from its blockout, about 1.35x the Harpy (size-scale.md: T2
aircraft, span 12-14): a bigger delta with a long round fuselage, a
pointed nose, a bubble canopy, canards, a tall team fin with a dorsal
spine, two big engine pods with glowing nozzles and flare dispensers on
them, the chin sensor `turret` (its heavy missiles turn it) with an amber
seeker, and the belly `pylon` with four heavy missiles (seekers on weapon;
`muzzle` on the turret, as in the blockout). Formation strips along the
leading edges (BAR style, M-15; Chaos reads light and aggressive, M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import ring  # noqa: E402

TURRET = (0.0, 0.05, -3.4)
PYLON = (0.0, -0.05, 0.4)


def build_base(p):
    p.cylinder("z", (0, 0.8, -0.2), 0.8, 8.4, 14, "paint")
    p.ocyl((0, 0.8, -4.4), (0, 0, -1), 0.8, 2.4, 14, "paint", radius2=0.08)  # nose
    p.ocyl((0, 1.5, -3.8), (0, 0, 1), 0.38, 1.9, 10, "glass", radius2=0.4)  # canopy
    p.box((0, 1.62, 0.6), (0.3, 0.3, 4.4), "trim", bevel=0.03)  # dorsal spine
    # big delta wing, team plates, wingtip lights
    p.prism_y([(-4.8, 4.2), (0.0, -2.2), (4.8, 4.2)], 0.48, 0.66, "paint", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 2.3, 0.68, 2.8), (2.2, 0.04, 1.4), "team")
        p.box((sx * 4.72, 0.58, 4.0), (0.1, 0.14, 0.5), "light")
        p.box((sx * 1.4, 1.05, -2.6), (2.2, 0.14, 0.9), "dark")  # canards
        # engine pods, glowing nozzles, flare dispensers
        p.cylinder("z", (sx * 1.3, 0.5, 3.2), 0.48, 3.2, 12, "trim")
        p.cylinder("z", (sx * 1.3, 0.5, 4.82), 0.38, 0.06, 12, "light")
        p.box((sx * 1.85, 0.75, 2.6), (0.35, 0.35, 1.0), "dark", bevel=0.02)
        p.obox((sx * 2.4, 0.68, 1.0), (0.8, 0, -sx * 0.6), (0, 1, 0), 0.14, 6.6, 0.03, "light")  # leading edges
    p.prism_x([(2.2, 1.5), (4.4, 1.5), (4.6, 3.9), (3.5, 3.9)], -0.11, 0.11, "team", bevel=0.02)  # fin
    p.box((0, 3.92, 4.0), (0.16, 0.08, 1.0), "light")
    p.box((0, 0.05, -2.6), (0.34, 0.06, 0.34), "head")


def details_base(p):
    ring(p, (0, 0.8, -1.2), (0, 0, -1), 0.78)
    ring(p, (0, 0.8, 1.8), (0, 0, -1), 0.78)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.1, z), 0.45, 0.14, 12, "trim")
    p.ocyl((x, y, z), (0, -1, 0), 0.4, 0.35, 12, "dark", radius2=0.22)
    p.box((x, y - 0.15, z - 0.38), (0.34, 0.16, 0.04), "weapon")


def build_pylon(p):
    p.box((0, -0.05, 0.4), (1.3, 0.4, 3.0), "trim", bevel=0.03)
    p.box((0, -0.18, 0.2), (4.0, 0.12, 0.8), "dark")
    for x in (-1.9, -0.8, 0.8, 1.9):
        p.cylinder("z", (x, -0.42, 0.2), 0.17, 2.2, 8, "paint")
        p.ocyl((x, -0.42, -0.9), (0, 0, -1), 0.17, 0.3, 8, "weapon", radius2=0.04)


def no_details(p):
    pass


unit.run(__file__, "chs_manticore", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, -0.1, -3.85]}},
         team_pieces=["base"])
