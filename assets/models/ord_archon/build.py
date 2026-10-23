"""Archon (Order air superiority fighter, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_archon/build.py

New mesh from its blockout, about 1.35x the Falcon (size-scale.md: T2
aircraft, span 12-14): a long stealth-faceted fuselage with chined edges, a
framed canopy, broad trapezoid wings with team plates and wingtip lights,
canted team tails, twin flattened nozzles with glow, the chin sensor
`turret` (its radar missiles turn it) with an ice-white seeker window, and
under the wing roots the `pylon` with four radar missiles (seekers on
weapon; `muzzle` on the pylon). Formation strips along the fuselage and the
wings (BAR style, M-15; Order reads heavy and clean, M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, seam  # noqa: E402

TURRET = (0.0, 0.25, -4.4)
PYLON = (0.0, 0.05, 0.4)


def build_base(p):
    p.prism_x([(-7.0, 0.7), (-5.0, 0.35), (5.0, 0.35), (5.3, 0.65), (5.0, 1.15), (-2.8, 1.25), (-5.0, 1.0)], -1.0, 1.0, "paint", bevel=0.06)
    for sx in (-1, 1):  # chines along the fuselage
        p.obox((sx * 1.1, 0.75, -2.0), (0, 0, 1), (sx, 0.6, 0), 6.0, 0.3, 0.06, "trim")
    p.prism_x([(-4.4, 1.2), (-2.8, 1.25), (-1.8, 1.75), (-3.3, 1.66)], -0.46, 0.46, "glass", bevel=0.03)  # canopy
    p.box((0, 1.78, -2.6), (0.08, 0.04, 1.4), "trim")  # canopy frame
    for sx in (-1, 1):  # broad trapezoid wings, team plates, wingtip lights
        pts = [(sx * 1.0, -1.8), (sx * 6.4, 2.2), (sx * 6.4, 3.0), (sx * 1.0, 3.6)]
        if sx < 0:
            pts = pts[::-1]
        p.prism_y(pts, 0.45, 0.62, "paint", bevel=0.03)
        p.box((sx * 3.4, 0.64, 1.8), (2.2, 0.04, 1.3), "team")
        p.box((sx * 6.42, 0.54, 2.6), (0.06, 0.14, 0.7), "light")
        t = math.radians(18) * sx  # canted team tails
        p.obox((sx * 0.85, 2.0, 4.0), (0, 0, 1), (math.cos(t), -math.sin(t), 0), 1.9, 1.6, 0.14, "team", bevel=0.02)
        p.cylinder("z", (sx * 0.5, 0.72, 5.3), 0.36, 0.4, 10, "dark", radius2=0.3)  # nozzles
        p.cylinder("z", (sx * 0.5, 0.72, 5.52), 0.26, 0.02, 10, "light")
        p.box((sx * 1.02, 0.85, -2.2), (0.06, 0.36, 1.2), "dark")  # intakes
        p.box((sx * 1.01, 1.0, 0.8), (0.04, 0.14, 5.6), "light")  # formation strips
        p.obox((sx * 3.6, 0.64, 1.6), (1, 0, 0), (0, 1, 0), 0.12, 2.6, 0.03, "light")
    p.box((0, 0.32, -5.0), (0.3, 0.06, 0.3), "head")


def details_base(p):
    seam(p, (-1.0, 1.251, -0.4), (1.0, 1.251, -0.4), UP)
    seam(p, (-1.0, 1.211, 2.2), (1.0, 1.211, 2.2), UP)


def build_turret(p):
    x, y, z = TURRET
    p.cylinder("y", (x, y + 0.05, z), 0.35, 0.12, 12, "trim")
    p.ocyl((x, y - 0.05, z), (0, -1, 0), 0.32, 0.3, 12, "dark", radius2=0.18)
    p.box((x, y - 0.15, z - 0.3), (0.3, 0.14, 0.04), "weapon")  # seeker window


def build_pylon(p):
    p.box((0, 0.15, 0.4), (3.0, 0.22, 1.8), "trim", bevel=0.03)
    for x in (-1.3, -0.5, 0.5, 1.3):
        p.cylinder("z", (x, -0.18, 0.1), 0.17, 2.6, 8, "paint")
        p.ocyl((x, -0.18, -1.2), (0, 0, -1), 0.17, 0.3, 8, "weapon", radius2=0.04)
        p.box((x, -0.18, 1.2), (0.46, 0.04, 0.3), "trim")


def no_details(p):
    pass


unit.run(__file__, "ord_archon", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("pylon", "base", PYLON, build_pylon, no_details)],
         attachments={"muzzle": {"parent": "pylon", "at": [-1.3, -0.18, -1.55]}},
         team_pieces=["base"])
