"""Herald (Order scout car, T1, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_herald/build.py

A low armored 4 x 4 with a long sloped nose, a faceted crew cab with a
glass band, deep wheel arches over four big wheels, and on the rear deck
the `turret`: a small angular gun house with a long machine gun (the weapon
turns the turret; no pitch piece). Team plates on the cab roof, the turret
and the flanks (BAR style, M-15; Order reads heavy, M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam, wheel  # noqa: E402

TURRET_PIVOT = (0.0, 2.15, 1.5)
MUZZLE = (0.0, 2.55, -1.45)
WHEELS_Z = (-2.0, 2.0)


def build_base(p):
    # hull: belly, sloped nose, raised rear deck
    p.prism_x([(-3.9, 1.1), (-2.6, 0.75), (3.0, 0.75), (3.0, 2.05), (-1.2, 2.05), (-3.9, 1.5)], -1.75, 1.75, "paint", bevel=0.05)
    # wheel arches either side
    for sx in (-1, 1):
        x0, x1 = (1.75, 2.15) if sx > 0 else (-2.15, -1.75)
        for z in WHEELS_Z:
            p.prism_x([(z - 1.0, 1.2), (z + 1.0, 1.2), (z + 0.75, 1.75), (z - 0.75, 1.75)], x0, x1, "paint", bevel=0.03)
        p.box((sx * 1.78, 1.45, 0.0), (0.05, 0.3, 2.0), "team", bevel=0.01)
    # crew cab with a glass band
    p.prism_y([(-1.45, -1.6), (1.45, -1.6), (1.45, 0.4), (-1.45, 0.4)], 2.05, 2.85, "paint", bevel=0.04, top_scale=0.86)
    p.box((0, 2.5, -1.62), (2.4, 0.3, 0.05), "glass")
    for sx in (-1, 1):
        p.box((sx * 1.47, 2.5, -0.6), (0.05, 0.3, 1.6), "glass")
    p.box((0, 2.87, -0.6), (1.6, 0.05, 1.2), "team", bevel=0.012)
    # lights, antenna, wheels
    for sx in (-1, 1):
        p.box((sx * 1.2, 1.25, -3.88), (0.4, 0.14, 0.06), "light")
        p.box((sx * 1.4, 1.6, 3.02), (0.3, 0.12, 0.04), "light")
    p.cylinder("y", (1.3, 2.9, 2.6), 0.03, 1.7, 4, "dark")
    for sx in (-1, 1):
        for z in WHEELS_Z:
            wheel(p, sx * 1.95, 0.75, z, 0.75, 0.6)


def build_turret(p):
    p.cylinder("y", (0, 2.12, 1.5), 0.85, 0.12, 12, "dark")
    p.prism_y([(-0.6, 0.85), (0.6, 0.85), (0.8, 1.3), (0.8, 2.2), (-0.8, 2.2), (-0.8, 1.3)], 2.18, 2.85, "paint", bevel=0.04, top_scale=0.88)
    p.box((0, 2.87, 1.65), (1.1, 0.05, 0.9), "team", bevel=0.01)
    p.cylinder("z", (0, 2.55, -0.1), 0.09, 2.0, 8, "steel")
    p.cylinder("z", (0, 2.55, -1.2), 0.12, 0.4, 8, "dark")
    p.box((0.45, 2.95, 1.2), (0.3, 0.18, 0.3), "trim")
    p.box((0.45, 2.96, 1.04), (0.22, 0.08, 0.03), "light")


def details_base(p):
    seam(p, (-1.7, 2.051, 0.6), (1.7, 2.051, 0.6), UP)
    bolts(p, (-1.5, 2.051, 2.8), (1.5, 2.051, 2.8), 5, UP)


def details_turret(p):
    bolts(p, (-0.6, 2.851, 2.0), (0.6, 2.851, 2.0), 3, UP)


unit.run(__file__, "ord_herald", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}})
