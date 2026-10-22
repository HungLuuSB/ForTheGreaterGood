"""Hydra (Chaos MLRS, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_hydra/build.py

A light tracked launcher: a slat-caged hull with an open cab, a turntable
`turret` and the `launcher` (pitches about its rear trunnion) as an open
rack of bare rocket tubes, 4 x 3, every mouth ringed with an amber ready
light (weapon channel); a team plate on the rack's back (BAR style, M-15;
Chaos reads light and open, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

TURRET = (0.0, 2.5, 1.2)
LAUNCHER = (0.0, 2.8, 3.0)
T = math.radians(30)
N = (0.0, math.sin(T), -math.cos(T))
V = (0.0, math.cos(T), math.sin(T))


def build_base(p):
    d = hulls.tracked(p, "chaos", length=7.6, width=4.8, deck=2.1)
    p.box((0, d + 0.5, -2.9), (2.2, 1.0, 1.4), "paint", bevel=0.04)
    p.box((0, d + 0.7, -3.61), (1.6, 0.22, 0.04), "light")


def details_base(p):
    bolts(p, (-2.0, 2.101, 3.2), (2.0, 2.101, 3.2), 6, UP)


def build_turret(p):
    p.cylinder("y", (0, 2.5, 1.2), 1.5, 0.4, 12, "trim")
    p.cylinder("y", (0, 2.62, 1.2), 1.52, 0.14, 12, "light", cap_kinds=("trim", "trim"))  # ring light
    for sx in (-1, 1):
        p.box((sx * 1.1, 2.9, 2.8), (0.3, 0.6, 0.6), "steel")


def at(a, b, n):
    c = (0.0, 3.3, 0.8)
    return tuple(c[k] + (1, 0, 0)[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_launcher(p):
    for b in (-0.55, 0.55):  # frame
        p.obox(at(0, b, 0), (1, 0, 0), N, 3.6, 0.12, 4.6, "steel")
    for a in (-1.8, 1.8):
        p.obox(at(a, 0, 0), (1, 0, 0), N, 0.12, 1.2, 4.6, "steel")
        p.obox(at(a * 1.04, 0.3, 0), (1, 0, 0), N, 0.04, 0.32, 4.0, "light")  # rack side strips
    for a in (-1.2, -0.4, 0.4, 1.2):
        for b in (-0.35, 0.0, 0.35):
            c = at(a, b, -2.2)
            p.ocyl(c, N, 0.15, 4.4, 8, "trim")
            p.ocyl(at(a, b, 2.21), N, 0.13, 0.03, 8, "weapon")
    p.obox(at(0, 0, -2.25), (1, 0, 0), N, 2.4, 0.8, 0.04, "team")


def no_details(p):
    pass


unit.run(__file__, "chs_hydra", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("launcher", "turret", LAUNCHER, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [0, 4.3, -1.8]}})
