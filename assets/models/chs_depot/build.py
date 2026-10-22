"""Depot (Chaos storage, T1 structure, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_depot/build.py

Salvaged tanks on a skid: a big upright drum with a team-painted cap, a
smaller drum, a horizontal tank behind, a pipe bridge, orange level gauges
on the drums (power channel: dims on an energy stall) and a warning light
(BAR style, M-15; Chaos reads light and open, M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402


def build_base(p):
    p.prism_y([(-3.3, -3.3), (3.3, -3.3), (3.3, 3.3), (-3.3, 3.3)], 0.0, 0.4, "dark", bevel=0.03)
    # drum A (big), drum B (small), each with bands and a level gauge
    for x, z, r, h in ((-1.4, -1.2, 1.6, 3.2), (1.8, -1.4, 1.2, 2.4)):
        p.cylinder("y", (x, 0.4 + h / 2, z), r, h, 14, "paint")
        p.cylinder("y", (x, 0.4 + h * 0.2, z), r + 0.04, 0.12, 14, "steel")
        p.cylinder("y", (x, 0.4 + h * 0.8, z), r + 0.05, 0.28, 14, "power", cap_kinds=("steel", "steel"))  # charge band
        p.box((x, 0.4 + h * 0.5, z - r - 0.02), (0.36, h * 0.5, 0.06), "dark")
        p.box((x, 0.4 + h * 0.42, z - r - 0.05), (0.22, h * 0.32, 0.04), "power")
        p.cylinder("y", (x, 0.4 + h + 0.1, z), r * 0.85, 0.2, 12, "trim")
    p.cylinder("y", (-1.4, 3.86, -1.2), 1.25, 0.06, 12, "team")
    # horizontal tank behind on saddles
    p.cylinder("z", (0.6, 1.45, 1.9), 1.0, 3.6, 12, "trim")
    for z in (0.7, 3.1):
        p.box((0.6, 0.6, z), (1.8, 0.4, 0.3), "steel")
    p.box((0.6, 2.47, 1.9), (0.9, 0.05, 2.2), "team", bevel=0.01)
    p.cylinder("z", (0.6, 1.45, -0.0), 0.3, 0.4, 8, "dark")
    # pipes, warning light, a gauge strip on the horizontal tank
    p.cylinder("x", (0.2, 2.9, -1.3), 0.2, 3.2, 8, "steel")
    p.cylinder("y", (1.8, 3.1, -1.4), 0.12, 0.2, 8, "steel")
    p.box((1.8, 3.32, -1.4), (0.36, 0.24, 0.36), "light")
    p.box((0.6, 1.45, 3.72), (1.2, 0.5, 0.04), "power")
    for sx in (-1, 1):
        p.box((sx * 3.25, 0.25, 0), (0.06, 0.12, 4.4), "light")


def details_base(p):
    bolts(p, (-3.0, 0.401, 3.0), (3.0, 0.401, 3.0), 8, UP)
    bolts(p, (-3.0, 0.401, -3.0), (3.0, 0.401, -3.0), 8, UP)
    ring(p, (-1.4, 3.721, -1.2), UP, 1.4)


unit.run(__file__, "chs_depot", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
