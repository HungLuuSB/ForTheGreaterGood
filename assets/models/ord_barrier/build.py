"""Barrier (Order wall segment, T1 structure, footprint 1): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_barrier/build.py

A thick armored wall block with sloped faces on both sides and a capping
beam, a team stripe along the top, cyan running lights along the cap (so a
wall line reads at night) and lit end caps where segments meet. Segments
line up along X, 8 studs per cell (BAR style, M-15; Order reads heavy,
M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402


def build_base(p):
    p.prism_x([(-1.6, 0.0), (1.6, 0.0), (0.9, 2.8), (-0.9, 2.8)], -3.9, 3.9, "paint", bevel=0.06)
    p.box((0, 3.0, 0), (7.9, 0.4, 2.0), "trim", bevel=0.05)  # capping beam
    p.box((0, 3.22, 0), (7.4, 0.05, 0.8), "team")
    for sz in (-1, 1):
        p.box((0, 3.05, sz * 1.01), (7.6, 0.14, 0.04), "light")  # cap running lights
        for x in (-2.6, 0.0, 2.6):
            p.obox((x, 1.2, sz * 1.25), (1, 0, 0), (0, 0.4, sz * 0.92), 1.6, 1.4, 0.06, "trim", bevel=0.02)  # plates
    for sx in (-1, 1):
        p.box((sx * 3.92, 1.6, 0), (0.05, 2.2, 0.5), "light")  # end caps


def details_base(p):
    seam(p, (-1.3, 3.201, -0.5), (1.3, 3.201, -0.5), UP)
    bolts(p, (-3.6, 3.201, 0.7), (3.6, 3.201, 0.7), 10, UP)


unit.run(__file__, "ord_barrier", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
