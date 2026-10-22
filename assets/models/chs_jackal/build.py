"""Jackal (Chaos raider buggy, T1, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_jackal/build.py

A light open buggy: a thin chassis tub, a push bumper, an armored driver's
plate with a slit on the left, a roll cage, an exposed engine with a stack
at the back, small front wheels and big rear ones, and on the right the
`turret`: a pintle gun behind a shield (the weapon turns the turret; no
pitch piece). Team plates on the shield and the engine cover (BAR style,
M-15; Chaos reads light, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, wheel  # noqa: E402

TURRET_PIVOT = (0.9, 1.8, 0.4)
MUZZLE = (0.9, 2.5, -2.35)


def build_base(p):
    p.prism_x([(-2.6, 1.0), (2.9, 1.0), (2.9, 1.65), (-2.3, 1.65)], -1.7, 1.7, "paint", bevel=0.04)
    p.box((0, 0.95, -2.85), (4.2, 0.45, 0.3), "dark", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 1.8, 1.15, -2.7), (0.2, 0.2, 0.6), "dark")
    # driver's plate and slit on the left
    p.obox((-0.8, 2.1, -1.55), (1, 0, 0), (0, 0.34, -0.94), 1.6, 0.85, 0.12, "trim", bevel=0.02)
    p.obox((-0.8, 2.22, -1.62), (1, 0, 0), (0, 0.34, -0.94), 1.2, 0.14, 0.03, "light")
    # roll cage
    for sx in (-1, 1):
        p.box((sx * 1.5, 2.3, -0.6), (0.14, 1.3, 0.14), "dark")
        p.obox((sx * 1.5, 2.2, 0.4), (0, 0.6, 1), (1, 0, 0), 2.2, 0.14, 0.14, "dark")
    p.box((0, 2.95, -0.6), (3.14, 0.14, 0.14), "dark")
    for x in (-1.0, -0.35, 0.35, 1.0):  # roll-cage light bar
        p.box((x, 3.06, -0.66), (0.4, 0.14, 0.12), "head")
    # engine, its cover plate (team), the stack
    p.box((-0.3, 2.15, 2.0), (2.0, 0.9, 1.6), "steel", bevel=0.04)
    p.box((-0.3, 2.62, 2.0), (1.6, 0.05, 1.2), "team", bevel=0.01)
    p.box((-0.3, 2.0, 2.82), (1.5, 0.5, 0.05), "light")  # exhaust glow
    p.cylinder("y", (-1.4, 2.55, 2.6), 0.17, 1.4, 8, "steel")
    p.cylinder("y", (-1.4, 3.27, 2.6), 0.19, 0.06, 8, "light")
    for sx in (-1, 1):
        p.box((sx * 1.3, 1.35, -2.62), (0.45, 0.2, 0.06), "head")
    for sx in (-1, 1):
        wheel(p, sx * 2.05, 0.65, -1.9, 0.65, 0.6)
        wheel(p, sx * 2.15, 0.9, 1.8, 0.9, 0.8)


def build_turret(p):
    p.cylinder("y", (0.9, 1.85, 0.4), 0.55, 0.15, 10, "dark")
    p.cylinder("y", (0.9, 2.15, 0.4), 0.18, 0.5, 8, "steel")
    p.box((0.9, 2.45, 0.3), (0.5, 0.3, 0.8), "trim", bevel=0.02)
    p.box((0.9, 2.7, -0.3), (1.3, 0.85, 0.12), "paint", bevel=0.02)
    p.box((0.9, 2.85, -0.37), (1.0, 0.35, 0.03), "team")
    p.cylinder("z", (0.9, 2.5, -1.25), 0.09, 2.2, 8, "steel")
    p.box((1.25, 2.4, 0.6), (0.35, 0.3, 0.45), "dark")
    p.cylinder("z", (0.9, 2.5, -2.2), 0.12, 0.1, 8, "weapon")  # muzzle ring


def details_base(p):
    bolts(p, (-1.5, 1.651, 1.0), (1.5, 1.651, 1.0), 5, UP)


def details_turret(p):
    bolts(p, (0.5, 3.1, -0.3), (1.3, 3.1, -0.3), 3, (0, 0, -1))


unit.run(__file__, "chs_jackal", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}})
