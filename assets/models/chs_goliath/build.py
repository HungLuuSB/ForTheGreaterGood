"""Juggernaut (Chaos main battle tank, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_goliath/build.py

A tall brute: a wide tracked hull with slat cages, and a boxy turret
(team-painted top) carrying two gun arms on shoulder joints, `armL` and
`armR` (the def's pieces; they raise to fire, guide 14.4, S-20), each a
short fat cannon with a muzzle ring (weapon channel); amber eye slits on
the turret front, a sensor mast (BAR style, M-15; Chaos reads light, M-14:
here a brute). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

TURRET = (0.0, 3.0, 0.3)
ARM_L = (-2.3, 4.6, 0.4)
ARM_R = (2.3, 4.6, 0.4)


def build_base(p):
    hulls.tracked(p, "chaos", length=8.4, width=6.2, deck=2.6)


def details_base(p):
    bolts(p, (-2.8, 2.601, 3.6), (2.8, 2.601, 3.6), 8, UP)


def build_turret(p):
    p.prism_y([(-1.7, -1.1), (1.7, -1.1), (1.7, 1.9), (-1.7, 1.9)], 2.9, 5.4, "paint", bevel=0.05, top_scale=0.9)
    p.box((0, 5.43, 0.4), (2.6, 0.05, 2.4), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 0.7, 4.6, -1.13), (0.9, 0.3, 0.05), "light")  # eye slits
        p.cylinder("x", (sx * 1.85, 4.6, 0.4), 0.55, 0.4, 12, "steel")  # shoulder joints
        p.box((sx * 1.72, 3.5, 0.4), (0.04, 0.22, 2.6), "light")
    p.cylinder("y", (-0.9, 6.1, 1.2), 0.08, 1.4, 6, "steel")  # sensor mast
    p.box((-0.9, 6.85, 1.2), (0.3, 0.2, 0.3), "light")
    p.box((0, 3.6, 2.05), (2.8, 1.0, 0.3), "grille")


def build_arm(sx):
    def build(p):
        x = sx * 2.3
        p.box((x, 4.6, -0.6), (1.0, 1.1, 2.6), "paint", bevel=0.05)
        p.cylinder("z", (x, 4.6, -3.1), 0.32, 2.6, 12, "trim")
        p.cylinder("z", (x, 4.6, -4.6), 0.42, 0.6, 12, "dark", cap_kinds=("dark", "dark"))
        p.cylinder("z", (x, 4.6, -4.2), 0.36, 0.1, 12, "weapon")
        p.box((x, 5.17, -0.6), (0.7, 0.05, 1.8), "team")
        p.box((x + sx * 0.52, 4.6, -0.6), (0.04, 0.2, 2.2), "light")  # arm side strips
    return build


def no_details(p):
    pass


unit.run(__file__, "chs_goliath", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("armL", "turret", ARM_L, build_arm(-1), no_details),
                 unit.PieceSpec("armR", "turret", ARM_R, build_arm(1), no_details)],
         attachments={"muzzle": {"parent": "armR", "at": [2.3, 4.6, -5.2]}})
