"""Veil (Order mobile jammer, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_veil/build.py

An armored 8 x 8 truck with a squared cab, carrying the `array` (the def's
piece, turning on its turntable): a squat armored emitter block with a team
band, a raised core and four emitter fins in a cross, their faces glowing
on `power` (the jammer draws power: dims on a stall). Compact, short range,
next to the Chaos Shroud's tall mast (BAR style, M-15; Order reads heavy,
M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

ARRAY = (0.0, 3.2, 1.6)


def build_base(p):
    d = hulls.wheeled(p, "order", length=7.6, width=4.8, deck=2.4, axles=4)
    p.prism_y([(-2.3, -3.7), (2.3, -3.7), (2.3, -1.9), (-2.3, -1.9)], d, d + 1.3, "paint", bevel=0.05, top_scale=0.9)
    p.box((0, d + 0.85, -3.72), (3.8, 0.35, 0.05), "glass")
    p.box((0, d + 1.33, -2.8), (3.4, 0.05, 1.2), "team", bevel=0.012)
    p.box((0, d + 0.4, -3.73), (3.6, 0.12, 0.04), "light")
    p.cylinder("y", (0, d + 0.1, 1.6), 1.5, 0.2, 14, "trim")


def details_base(p):
    bolts(p, (-2.0, 2.401, 3.4), (2.0, 2.401, 3.4), 6, UP)


def build_array(p):
    x, y, z = ARRAY
    p.box((x, 3.2, z), (2.6, 1.6, 2.6), "paint", bevel=0.06)
    p.box((x, 3.2, z), (2.68, 0.4, 2.68), "team", bevel=0.01)
    p.box((x, 4.6, z), (1.0, 1.2, 1.0), "trim", bevel=0.04)
    for dx, dz, w, d in ((0, -1.1, 0.15, 1.2), (0, 1.1, 0.15, 1.2), (-1.1, 0, 1.2, 0.15), (1.1, 0, 1.2, 0.15)):
        p.box((x + dx, 4.7, z + dz), (w, 1.4, d), "paint", bevel=0.02)  # fins
        p.box((x + dx * 1.07, 4.7, z + dz * 1.07), (w if w > 1 else 0.04, 1.1, d if d > 1 else 0.04), "power")
    p.box((x, 5.25, z), (0.4, 0.1, 0.4), "light")


def no_details(p):
    pass


unit.run(__file__, "ord_veil", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("array", "base", ARRAY, build_array, no_details)])
