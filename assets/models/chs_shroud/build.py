"""Shroud (Chaos mobile jammer, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_shroud/build.py

A light 6 x 6 truck with a cab, a generator box and guy wires, carrying the
`array` (the def's piece, turning about the mast): a tall telescoping mast
with two rings of emitter rods near the top, their tips glowing on `power`
(the jammer draws power), and a beacon. Wide radius, so tall (BAR style,
M-15; Chaos reads light and open, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

ARRAY = (0.0, 5.9, 2.2)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    d = hulls.wheeled(p, "chaos", length=7.2, width=4.2, deck=2.2)
    p.box((0, d + 0.55, -2.7), (3.8, 1.1, 1.6), "paint", bevel=0.04)
    p.box((0, d + 0.75, -3.54), (3.0, 0.22, 0.05), "light")
    p.box((0, d + 1.12, -2.7), (2.8, 0.05, 1.0), "team", bevel=0.01)
    p.box((0, d + 0.45, -0.6), (3.0, 0.9, 1.4), "trim", bevel=0.03)  # generator
    p.box((0, d + 0.45, -1.31), (2.4, 0.3, 0.04), "power")
    p.box((0, d + 0.25, 2.2), (1.4, 0.5, 1.4), "dark")  # mast foot
    for sx in (-1, 1):  # guy wires
        beam(p, (sx * 1.9, d, 2.2), (sx * 0.3, 8.0, 2.2), 0.06, "steel")


def details_base(p):
    bolts(p, (-1.7, 2.201, 3.3), (1.7, 2.201, 3.3), 6, UP)


def build_array(p):
    x, y, z = ARRAY
    p.cylinder("y", (x, 5.9, z), 0.3, 6.4, 10, "paint")
    p.cylinder("y", (x, 10.3, z), 0.2, 2.4, 8, "trim")
    for r, yy in ((1, 8.4), (2, 9.9)):
        for k in range(4):
            a = math.radians(k * 90 + r * 45)
            d = (math.sin(a), 0, math.cos(a))
            p.obox((x + d[0] * 0.8, yy, z + d[2] * 0.8), (math.cos(a), 0, -math.sin(a)), d, 0.15, 0.15, 1.4, "steel")
            p.ocyl((x + d[0] * 1.5, yy, z + d[2] * 1.5), d, 0.14, 0.2, 8, "power")
    p.cylinder("y", (x, 11.7, z), 0.25, 0.4, 8, "light")  # beacon


def no_details(p):
    pass


unit.run(__file__, "chs_shroud", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("array", "base", ARRAY, build_array, no_details)])
