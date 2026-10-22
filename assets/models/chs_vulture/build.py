"""Vulture (Chaos air worker, T1 air, helicopter): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_vulture/build.py

A light open helicopter: a short boxy pod with a dark bubble nose, an
exposed engine on top with an amber exhaust, a thin braced tail boom with a
team fin and tail rotor, wheels, amber nav lights; the client-spun `rotor`
(blockout visual piece) with two long blades; the `nano` builder arm under
the belly with its emitter (power channel: brightens while building), like
the Scrapper (BAR style, M-15; Chaos reads light and open, M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

ROTOR = (0.0, 3.4, 0.2)
NANO = (0.0, 0.25, -0.2)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.box((0, 1.2, -0.2), (1.6, 1.5, 3.4), "paint", bevel=0.05)
    # bubble nose: two stacked frustums
    p.ocyl((0, 1.1, -1.9), (0, 0, -1), 0.8, 0.5, 12, "glass", radius2=0.55)
    p.ocyl((0, 1.1, -2.4), (0, 0, -1), 0.55, 0.3, 12, "glass", radius2=0.15)
    p.box((0, 1.98, -0.9), (1.2, 0.05, 1.2), "team", bevel=0.01)
    # exposed engine, exhaust, mast
    p.cylinder("z", (0, 2.25, 0.6), 0.45, 1.8, 10, "steel")
    p.cylinder("z", (0, 2.25, 1.55), 0.32, 0.12, 10, "light")  # exhaust glow
    p.cylinder("y", (0, 2.85, 0.2), 0.18, 0.8, 8, "steel")
    # tail boom with brace, fin, tail rotor
    p.box((0, 1.4, 3.8), (0.35, 0.35, 4.2), "trim")
    beam(p, (0, 0.6, 1.5), (0, 1.3, 5.6), 0.15, "dark")
    p.prism_x([(5.1, 1.32), (6.35, 1.32), (6.35, 3.2), (5.75, 3.2)], -0.08, 0.08, "team", bevel=0.02)
    p.cylinder("x", (0.2, 2.1, 5.7), 0.8, 0.06, 8, "dark")
    for sx in (-1, 1):
        p.cylinder("x", (sx * 0.8, 0.3, -0.8), 0.3, 0.25, 10, "rubber", cap_kinds=("steel", "steel"))
        p.box((sx * 0.6, 0.55, -0.8), (0.12, 0.5, 0.12), "steel")
        p.box((sx * 0.82, 1.6, 0.3), (0.05, 0.14, 2.0), "light")  # nav strips
    p.box((0, 1.6, 6.25), (0.1, 0.14, 0.1), "light")
    p.box((0, 0.48, -1.6), (0.5, 0.06, 0.3), "head")


def details_base(p):
    bolts(p, (-0.6, 1.951, 0.4), (0.6, 1.951, 0.4), 5, UP)


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.25, 0.2, 8, "trim")
    for s in (-1, 1):
        a = math.radians(20)
        d = (math.cos(a) * s, 0.0, math.sin(a) * s)
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 2.25, y + 0.02, z + d[2] * 2.25), u, (0, 1, 0), 0.45, 4.2, 0.08, "dark")
        p.obox((x + d[0] * 4.15, y + 0.03, z + d[2] * 4.15), u, (0, 1, 0), 0.47, 0.35, 0.09, "team")


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 0.6, 0.3, 10, "trim")
    p.obox((0, 0.0, -0.9), (1, 0, 0), (0, math.sin(math.radians(20)), -math.cos(math.radians(20))), 0.25, 0.25, 1.6, "steel")
    p.cylinder("y", (0, -0.3, -1.7), 0.32, 0.5, 10, "power")
    p.cylinder("y", (0, -0.05, -1.7), 0.36, 0.08, 10, "dark")


def no_details(p):
    pass


unit.run(__file__, "chs_vulture", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         team_pieces=["base", "rotor"])
