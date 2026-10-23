"""Custodian (Order mobile anti-nuke, T2 ground): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_custodian/build.py

New mesh from its blockout, at the T2 light size (size-scale.md: about
1.3x a T1 truck, fits one cell). An armored 8x8 carrier (`wheelL1..4` /
`wheelR1..4`, spin) with a sloped armored cab, a glass strip and a team
roof, side skirts with team strips and running lights, a front and a rear
cradle, and the `launcher` (the def's piece, hinged at its rear end): one
large interceptor canister with armored rings, a team band and a glowing
readiness ring at its mouth (weapon); a compact radar on the cab roof
(client-turned `radar`, M-27). `muzzle` at the canister mouth. Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard  # noqa: E402
from unit import UP, bolts, wheel  # noqa: E402

PIVOT = (0.0, 4.0, 4.7)
CAN_Y = 4.0
RADAR = (1.5, 5.1, -3.4)


def build_base(p):
    # armored hull and a sloped cab
    p.prism_x([(-5.6, 1.1), (-4.4, 0.9), (5.4, 0.9), (5.4, 2.7), (-3.2, 2.7), (-5.6, 1.9)], -2.4, 2.4, "paint", bevel=0.08)
    p.prism_x([(-5.2, 2.6), (-2.6, 2.6), (-2.6, 4.4), (-3.4, 4.4), (-5.0, 3.1)], -2.3, 2.3, "paint", bevel=0.08)
    p.obox((0, 3.5, -4.35), (1, 0, 0), (0, 0.75, -0.66), 3.8, 0.6, 0.05, "glass")
    p.box((0, 4.44, -3.0), (3.4, 0.05, 0.9), "team", bevel=0.012)
    p.box((0, 1.9, -5.62), (3.0, 0.14, 0.05), "light")
    for sx in (-1, 1):
        p.box((sx * 1.6, 1.55, -5.65), (0.6, 0.2, 0.08), "head")
        # skirts with team strips and running lights
        p.box((sx * 2.48, 1.85, 0.4), (0.16, 0.8, 9.4), "paint", bevel=0.03)
        p.box((sx * 2.57, 1.85, 1.0), (0.04, 0.3, 4.0), "team", bevel=0.01)
        p.box((sx * 2.57, 2.4, 0.4), (0.04, 0.12, 8.6), "light")
        for i, z in enumerate((-3.9, -1.6, 1.8, 4.1)):
            wheel(p, sx * 2.25, 0.85, z, 0.85, 0.7, name=f"wheel{'L' if sx < 0 else 'R'}{i + 1}")
    # cradles for the canister
    p.box((0, 3.2, -1.6), (3.4, 1.0, 0.6), "trim", bevel=0.04)
    p.box((0, 3.3, 4.6), (3.4, 1.2, 0.9), "trim", bevel=0.04)
    hazard(p, (0, 2.72, 5.2), (1, 0, 0), UP, 4.0, 0.35, stripes=8)
    p.box((0, 1.8, 5.43), (3.0, 0.14, 0.05), "light")
    p.cylinder("y", (RADAR[0], 4.75, RADAR[2]), 0.18, 0.7, 8, "steel")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        t = math.radians(15)
        n = (0, math.sin(t), -math.cos(t))
        c = (RADAR[0], 5.65, RADAR[2])
        p.obox(c, (1, 0, 0), n, 1.9, 1.15, 0.18, "paint", bevel=0.02)
        p.obox(tuple(c[k] + n[k] * 0.1 for k in range(3)), (1, 0, 0), n, 1.7, 0.95, 0.02, "dark")
        p.obox(tuple(c[k] + n[k] * 0.11 for k in range(3)), (1, 0, 0), n, 1.75, 0.06, 0.02, "light")


def details_base(p):
    bolts(p, (-2.0, 2.701, 2.6), (2.0, 2.701, 2.6), 7, UP)


def build_launcher(p):
    drum(p, (0, CAN_Y, 0.9), 1.3, 7.6, "paint", "trim", sides=20, axis="z")
    for z in (-1.4, 1.2, 3.6):
        p.cylinder("z", (0, CAN_Y, z), 1.35, 0.3, 20, "trim")
    p.cylinder("z", (0, CAN_Y, 2.4), 1.33, 1.2, 20, "team")
    p.box((0, CAN_Y + 1.32, 0.0), (0.9, 0.05, 2.0), "team", bevel=0.01)
    p.cylinder("z", (0, CAN_Y, -2.85), 1.0, 0.06, 18, "dark")
    p.cylinder("z", (0, CAN_Y, -2.9), 0.75, 0.04, 16, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_custodian", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [0, CAN_Y, -3.0]}})
