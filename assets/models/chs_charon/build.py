"""Charon (Chaos heavy air transport, T2 air, footprint 3; S-219): mesh,
textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_charon/build.py

A flying crane, the ferryman: a narrow armored spine with a cockpit pod at
the front (dark glass, a team roof plate) and a lit lantern hanging off a
bow arm, twin exposed engines on top with amber exhausts, a thin tail
boom with a team fin and tail rotor, four long splayed legs with pads, and
under the spine an open cargo cradle with four chain hooks (the `cargo`
attachment in it: where the carried units hang). The client-spun `rotor`
(blockout visual piece) has six long blades. Chaos reads light, open and
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

ROTOR = (0.0, 7.6, -1.2)
TAIL = (0.42, 6.0, 13.4)
CARGO = (0.0, 0.8, -0.8)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    # spine: narrow, deep at the rotor, thinning into the tail
    p.prism_x([(-8.4, 3.8), (5.0, 4.0), (7.0, 4.6), (7.0, 5.4), (-1.0, 6.0), (-6.4, 5.8), (-8.4, 5.2)], -0.9, 0.9, "paint", bevel=0.08)
    p.box((0, 5.95, -3.4), (1.1, 0.05, 4.4), "team", bevel=0.01)
    # cockpit pod hung at the front of the spine
    p.prism_x([(-12.2, 3.2), (-8.2, 3.0), (-7.8, 4.0), (-8.2, 5.6), (-10.4, 5.6), (-12.2, 4.6)], -1.4, 1.4, "paint", bevel=0.1)
    p.prism_x([(-12.0, 4.0), (-10.5, 5.45), (-10.0, 5.65), (-12.3, 4.25)], -1.15, 1.15, "glass", bevel=0.03)
    p.prism_x([(-12.25, 3.4), (-12.05, 3.3), (-12.05, 3.9), (-12.3, 3.95)], -1.2, 1.2, "glass", bevel=0.02)  # chin window
    p.box((0, 5.63, -9.3), (1.6, 0.05, 1.6), "team", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * 1.41, 4.6, -10.6), (0.05, 0.7, 1.2), "glass")
        p.box((sx * 0.91, 4.9, 1.0), (0.05, 0.14, 6.0), "light")  # amber nav strips
    # the ferryman's lantern on a bow arm
    beam(p, (0, 4.6, -12.0), (0, 4.4, -13.4), 0.14, "steel")
    beam(p, (0, 4.4, -13.4), (0, 3.6, -13.4), 0.06, "dark")
    p.cylinder("y", (0, 3.25, -13.4), 0.26, 0.6, 8, "head")
    p.cylinder("y", (0, 3.6, -13.4), 0.32, 0.1, 8, "dark")
    p.cylinder("y", (0, 2.92, -13.4), 0.3, 0.08, 8, "dark")
    # twin exposed engines, mast
    for sx in (-1, 1):
        x = sx * 1.35
        p.cylinder("z", (x, 6.1, -1.0), 0.65, 4.2, 12, "steel")
        p.cylinder("z", (x, 6.1, -3.15), 0.52, 0.12, 12, "dark")  # intake
        p.cylinder("z", (x, 6.1, 1.15), 0.45, 0.14, 12, "light")  # exhaust glow
        beam(p, (x, 5.5, -1.0), (sx * 0.8, 5.5, -1.0), 0.3, "trim")
    p.cylinder("y", (0, 6.7, -1.2), 0.32, 1.4, 8, "steel")
    # tail boom, fin, stabilizer, tail rotor
    p.box((0, 5.0, 10.2), (0.5, 0.5, 6.6), "trim", bevel=0.04)
    p.prism_x([(12.4, 4.9), (14.2, 4.9), (14.2, 7.2), (13.3, 7.2)], -0.1, 0.1, "team", bevel=0.02)
    p.box((0, 5.0, 12.0), (3.0, 0.12, 0.8), "dark")
    p.box((0, 7.3, 13.8), (0.12, 0.1, 0.25), "light")
    with p.sub("tailRotor", TAIL, "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", TAIL, 1.8, 0.07, 10, "dark")
        p.cylinder("x", (TAIL[0] - 0.04, TAIL[1], TAIL[2]), 0.22, 0.25, 6, "steel")
    # four long splayed legs with pads
    for sx in (-1, 1):
        for z0, z1 in ((-6.2, -7.4), (4.2, 5.6)):
            beam(p, (sx * 0.8, 4.0, z0), (sx * 3.6, 0.35, z1), 0.24, "trim")
            beam(p, (sx * 0.8, 4.0, z0 + (1.4 if z0 < 0 else -1.4)), (sx * 3.6, 0.35, z1), 0.14, "steel")
            p.cylinder("y", (sx * 3.6, 0.15, z1), 0.5, 0.3, 10, "dark")
    # open cargo cradle under the spine with four chain hooks
    for sx in (-1, 1):
        beam(p, (sx * 2.0, 2.4, -5.4), (sx * 2.0, 2.4, 3.8), 0.22, "dark")
        for z in (-5.4, 3.8):
            beam(p, (sx * 2.0, 2.4, z), (sx * 0.6, 3.9, z), 0.16, "steel")
    for z in (-5.4, -0.8, 3.8):
        beam(p, (-2.0, 2.4, z), (2.0, 2.4, z), 0.18, "dark")
    for sx in (-1, 1):
        for z in (-4.0, 2.4):
            x = sx * 1.6
            p.box((x, 2.25, z), (0.4, 0.18, 0.4), "trim")
            beam(p, (x, 2.2, z), (x, 1.15, z), 0.07, "steel")
            p.box((x, 1.0, z), (0.3, 0.22, 0.14), "weapon")  # lit hooks
    p.box((0, 2.42, -0.8), (4.2, 0.06, 0.4), "hazard")
    p.box((0, 3.75, -9.8), (0.6, 0.06, 0.4), "head")  # landing light


def details_base(p):
    bolts(p, (-0.5, 5.991, -6.0), (0.5, 5.991, -6.0), 4, UP)
    bolts(p, (-0.6, 5.601, -10.4), (0.6, 5.601, -10.4), 4, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.7, 0.35, 12, "trim")
    for i in range(6):
        a = i * math.pi / 3
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 5.4, y + 0.03, z + d[2] * 5.4), u, (0, 1, 0), 0.7, 9.6, 0.11, "dark")
        p.obox((x + d[0] * 9.85, y + 0.04, z + d[2] * 9.85), u, (0, 1, 0), 0.72, 0.6, 0.12, "team")


def no_details(p):
    pass


unit.run(__file__, "chs_charon", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details)],
         attachments={"cargo": {"parent": "base", "at": list(CARGO)}},
         team_pieces=["base", "rotor"], budget=8000)
