"""Buzzard (Chaos light air transport, T1 air, footprint 2; S-219): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_buzzard/build.py

A skeletal lifter: a short cockpit pod with a dark bubble nose and a team
roof plate, an open lattice spine (two longerons and cross braces) running
back to a thin tail with a team fin and tail rotor, an exposed engine on
top with an amber exhaust, tall thin legs with wheels, and under the spine
a pair of folded grapple talons on a cross beam (the `cargo` attachment
between them: where a carried unit hangs). The client-spun `rotor`
(blockout visual piece) has two long blades. Chaos reads light, open and
high off the ground (M-14), BAR style (M-15). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

ROTOR = (0.0, 4.6, -0.4)
TAIL = (0.28, 3.9, 9.6)
CARGO = (0.0, 0.5, 0.4)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    # cockpit pod and bubble nose
    p.box((0, 2.6, -2.6), (2.0, 1.7, 3.0), "paint", bevel=0.08)
    p.ocyl((0, 2.5, -4.1), (0, 0, -1), 0.95, 0.6, 12, "glass", radius2=0.7)
    p.ocyl((0, 2.5, -4.7), (0, 0, -1), 0.7, 0.4, 12, "glass", radius2=0.2)
    p.box((0, 3.46, -2.4), (1.5, 0.05, 1.8), "team", bevel=0.01)
    # open lattice spine: upper and lower longerons per side, cross braces
    for sx in (-1, 1):
        x = sx * 0.7
        beam(p, (x, 3.3, -1.2), (x * 0.4, 3.3, 8.6), 0.18, "trim")
        beam(p, (x, 2.0, -1.2), (x * 0.4, 3.0, 8.6), 0.18, "trim")
        for i, z in enumerate((-0.6, 1.4, 3.4, 5.4, 7.4)):
            t = (z + 1.2) / 9.8
            xx = x * (1 - 0.6 * t)
            lo = 2.0 + 1.0 * t
            beam(p, (xx, lo, z), (xx, 3.3, z + (0.9 if i % 2 == 0 else -0.9)), 0.1, "dark")
    for z in (-0.6, 2.4, 5.4):
        t = (z + 1.2) / 9.8
        beam(p, (-0.7 * (1 - 0.6 * t), 3.3, z), (0.7 * (1 - 0.6 * t), 3.3, z), 0.12, "dark")
    # exposed engine, exhaust, mast
    p.cylinder("z", (0, 3.75, 0.6), 0.55, 2.6, 10, "steel")
    p.cylinder("z", (0, 3.75, -0.75), 0.45, 0.12, 10, "dark")  # intake
    p.cylinder("z", (0, 3.75, 1.95), 0.38, 0.14, 10, "light")  # exhaust glow
    p.cylinder("y", (0, 4.2, -0.4), 0.2, 0.8, 8, "steel")
    # tail: fin, small stabilizer, tail rotor
    p.box((0, 3.15, 8.9), (0.3, 0.4, 1.0), "trim")
    p.prism_x([(8.6, 3.2), (10.1, 3.2), (10.1, 5.0), (9.4, 5.0)], -0.08, 0.08, "team", bevel=0.02)
    p.box((0, 3.1, 8.7), (2.0, 0.1, 0.6), "dark")
    with p.sub("tailRotor", TAIL, "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", TAIL, 1.05, 0.06, 8, "dark")
    # tall thin legs with wheels: two mains behind the cockpit, one at the nose
    for sx in (-1, 1):
        beam(p, (sx * 0.7, 2.0, -0.6), (sx * 1.7, 0.4, 0.2), 0.14, "steel")
        beam(p, (sx * 0.7, 2.0, 1.2), (sx * 1.7, 0.4, 0.2), 0.12, "steel")
        p.cylinder("x", (sx * 1.85, 0.32, 0.2), 0.32, 0.22, 10, "rubber", cap_kinds=("steel", "steel"))
        p.box((sx * 1.02, 3.1, -2.6), (0.05, 0.14, 2.0), "light")  # amber nav strips
    beam(p, (0, 1.8, -3.4), (0, 0.4, -3.6), 0.14, "steel")
    p.cylinder("x", (0, 0.26, -3.6), 0.24, 0.18, 10, "rubber", cap_kinds=("steel", "steel"))
    # grapple talons on a cross beam under the spine, folded in
    beam(p, (-1.5, 1.6, 0.4), (1.5, 1.6, 0.4), 0.22, "dark")
    p.box((0, 1.6, 0.4), (0.7, 0.4, 0.7), "trim", bevel=0.04)  # winch drum housing
    for sx in (-1, 1):
        x = sx * 1.4
        beam(p, (x, 1.6, 0.4), (x, 0.9, 0.4), 0.16, "steel")
        beam(p, (x, 0.9, 0.4), (sx * 1.0, 0.45, 0.4), 0.14, "steel")
        for dz in (-0.35, 0.35):
            beam(p, (sx * 1.0, 0.45, 0.4 + dz), (sx * 0.7, 0.3, 0.4 + dz), 0.1, "weapon")  # lit claw tips
    p.box((0, 1.38, 0.4), (0.74, 0.06, 0.74), "hazard")
    p.box((0, 1.72, -3.9), (0.4, 0.06, 0.3), "head")  # landing light


def details_base(p):
    bolts(p, (-0.7, 3.451, -1.3), (0.7, 3.451, -1.3), 5, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.32, 0.22, 8, "trim")
    for s in (-1, 1):
        a = math.radians(20)
        d = (math.cos(a) * s, 0.0, math.sin(a) * s)
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 3.6, y + 0.02, z + d[2] * 3.6), u, (0, 1, 0), 0.55, 6.6, 0.09, "dark")
        p.obox((x + d[0] * 6.6, y + 0.03, z + d[2] * 6.6), u, (0, 1, 0), 0.57, 0.5, 0.1, "team")


def no_details(p):
    pass


unit.run(__file__, "chs_buzzard", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details)],
         attachments={"cargo": {"parent": "base", "at": list(CARGO)}},
         team_pieces=["base", "rotor"], budget=6000)
