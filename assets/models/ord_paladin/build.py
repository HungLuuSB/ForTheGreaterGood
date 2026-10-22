"""Paladin (Order main battle tank, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_paladin/build.py

A heavier Lancer: a long tracked hull with thick skirts, and a big wedge
turret carrying a very long gun with a bore evacuator and a muzzle brake.
The def turns `turret` and has no barrel piece, so the gun is part of the
turret (the muzzle 11 studs forward). Muzzle ring and rail strip on
`weapon`, sights and sensor strips on `running`, a team roof plate (BAR
style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

TURRET = (0.0, 2.2, 0.3)


def build_base(p):
    hulls.tracked(p, "order", length=8.4, width=6.0, deck=2.2)
    for sx in (-1, 1):
        p.box((sx * 2.3, 2.23, 1.6), (0.6, 0.05, 3.6), "team", bevel=0.012)


def details_base(p):
    seam(p, (-2.9, 2.201, -1.6), (2.9, 2.201, -1.6), UP)
    bolts(p, (-2.6, 2.201, 3.6), (2.6, 2.201, 3.6), 8, UP)


def build_turret(p):
    p.prism_y([(-2.0, -1.6), (2.0, -1.6), (2.4, -0.8), (2.4, 2.6), (-2.4, 2.6), (-2.4, -0.8)], 2.2, 3.7, "paint",
              bevel=0.06, top_scale=0.92)
    p.prism_x([(-2.6, 2.2), (-1.6, 2.2), (-1.6, 3.7), (-2.0, 3.7)], -1.9, 1.9, "paint", bevel=0.05)  # wedge front
    p.box((0, 3.73, 0.6), (3.4, 0.05, 2.8), "team", bevel=0.015)
    p.box((0, 3.0, 2.8), (3.6, 0.8, 0.5), "grille", bevel=0.02)  # bustle rack
    p.box((0, 3.2, 3.07), (3.4, 0.2, 0.05), "light")  # turret rear light bar
    for sx in (-1, 1):
        p.box((sx * 2.0, 3.72, 0.6), (0.12, 0.04, 3.4), "light")  # roof edge strips
    p.box((1.3, 3.95, -0.6), (0.6, 0.4, 0.6), "trim", bevel=0.03)  # gunner's sight
    p.box((1.3, 3.97, -0.92), (0.46, 0.2, 0.04), "light")
    p.box((-1.2, 4.0, 1.6), (0.5, 0.5, 0.5), "trim", bevel=0.03)  # commander's sight
    p.box((-1.2, 4.02, 1.33), (0.4, 0.18, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 2.42, 3.0, 0.6), (0.04, 0.16, 3.0), "light")
    # the gun
    p.box((0, 2.95, -2.3), (1.2, 0.9, 0.7), "paint", bevel=0.06)  # mantlet
    p.cylinder("z", (0, 2.95, -6.6), 0.28, 8.0, 16, "paint")
    p.cylinder("z", (0, 2.95, -5.0), 0.4, 0.8, 16, "paint")  # evacuator
    p.cylinder("z", (0, 2.95, -5.0), 0.42, 0.12, 16, "weapon")
    p.box((0, 2.95, -10.7), (0.9, 0.7, 0.8), "dark", bevel=0.05)  # muzzle brake
    p.cylinder("z", (0, 2.95, -10.15), 0.33, 0.12, 16, "weapon")
    p.box((0, 3.25, -7.0), (0.09, 0.05, 4.0), "weapon")  # rail strip


def no_details(p):
    pass


unit.run(__file__, "ord_paladin", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, 2.95, -11.05]}})
