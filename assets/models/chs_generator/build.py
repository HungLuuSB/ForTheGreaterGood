"""Generator (Chaos power generator, T1 structure, footprint 1): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_generator/build.py

Two upright reactor tanks of different heights on a skid, each with a
glowing orange band, a pipe bridge between them, an open frame with posts
in front, a team plate on the skid and on the big tank's cap (BAR style,
M-15; Chaos reads light, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402


def build_base(p):
    p.prism_y([(-3.3, -3.3), (3.3, -3.3), (3.3, 3.3), (-3.3, 3.3)], 0.0, 0.45, "dark", bevel=0.03)
    p.box((0.4, 0.49, -2.4), (4.4, 0.05, 1.1), "team", bevel=0.012)
    # tank A (tall) and tank B (short)
    for x, z, r, h in ((-1.3, 0.6, 1.6, 4.6), (1.7, 1.2, 1.3, 3.2)):
        p.cylinder("y", (x, 0.45 + h / 2, z), r, h, 14, "paint")
        p.cylinder("y", (x, 0.45 + h * 0.62, z), r + 0.06, 0.3, 14, "power")
        for y in (0.45 + h * 0.25, 0.45 + h * 0.9):
            p.cylinder("y", (x, y, z), r + 0.04, 0.1, 14, "steel")
        p.cylinder("y", (x, 0.45 + h + 0.2, z), r * 0.7, 0.4, 12, "trim")
    p.box((-1.3, 5.7, 0.6), (1.4, 0.05, 1.4), "team", bevel=0.012)
    # pipe bridge from A to B, a stack on B
    p.cylinder("x", (0.2, 3.6, 0.9), 0.22, 3.0, 8, "steel")
    p.cylinder("y", (2.1, 4.5, 1.6), 0.2, 1.6, 8, "steel")
    # open frame in front: two posts and a beam with lights
    for sx in (-1, 1):
        p.box((sx * 2.8, 2.25, -1.4), (0.3, 3.6, 0.3), "dark")
    p.box((0, 4.1, -1.4), (5.9, 0.3, 0.3), "dark")
    for sx in (-1, 1):
        p.box((sx * 2.8, 4.35, -1.4), (0.3, 0.2, 0.3), "light")


def details_base(p):
    ring(p, (-1.3, 5.251, 0.6), UP, 1.1)
    bolts(p, (-3.0, 0.451, 3.0), (3.0, 0.451, 3.0), 8, UP)
    bolts(p, (-3.0, 0.451, -3.0), (3.0, 0.451, -3.0), 8, UP)


unit.run(__file__, "chs_generator", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
