"""Extractor (Chaos supply extractor, T1 structure, footprint 1): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_extractor/build.py

A lattice derrick of four splayed legs over an exposed drill shaft on a
grated platform, a head block with an orange beacon, an engine block with a
stack beside it, a team plate on the platform (BAR style, M-15; Chaos reads
light, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring  # noqa: E402

LEG_FOOT, LEG_TOP, TOP_Y = 2.4, 0.75, 6.2


def build_base(p):
    p.prism_y([(-3.3, -3.3), (3.3, -3.3), (3.3, 3.3), (-3.3, 3.3)], 0.0, 0.35, "dark", bevel=0.03)
    p.box((0, 0.6, 0), (4.6, 0.35, 4.6), "paint", bevel=0.04)
    p.box((0, 0.81, 0), (4.2, 0.04, 4.2), "grille")
    p.box((-1.2, 0.81, -1.7), (1.8, 0.05, 1.0), "team", bevel=0.012)
    # the derrick: four legs from the platform corners to the head, two rings of braces
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = lib.vec((sx * LEG_FOOT, 0.75, sz * LEG_FOOT))
            b = lib.vec((sx * LEG_TOP, TOP_Y, sz * LEG_TOP))
            p.obox(tuple((a + b) / 2), tuple(b - a), (sz, 0, -sx), (b - a).length, 0.24, 0.24, "dark", bevel=0.015)
    for y in (2.6, 4.4):
        t = (y - 0.75) / (TOP_Y - 0.75)
        w = LEG_FOOT + (LEG_TOP - LEG_FOOT) * t
        for sz in (-1, 1):
            p.box((0, y, sz * w), (2 * w, 0.14, 0.14), "dark")
        for sx in (-1, 1):
            p.box((sx * w, y, 0), (0.14, 0.14, 2 * w), "dark")
    # drill shaft, glowing collar, the head with its beacon
    p.cylinder("y", (0, 3.4, 0), 0.5, 5.2, 10, "steel")
    for y in (2.6, 3.8, 5.0):  # drill-shaft power bands
        p.cylinder("y", (0, y, 0), 0.53, 0.14, 10, "power")
    p.cylinder("y", (0, 1.2, 0), 0.85, 0.5, 12, "trim")
    p.cylinder("y", (0, 1.5, 0), 0.82, 0.2, 12, "power")
    p.box((0, TOP_Y + 0.35, 0), (1.9, 0.8, 1.9), "paint", bevel=0.05)
    p.box((0, TOP_Y + 0.77, 0), (1.3, 0.05, 1.3), "team", bevel=0.012)
    p.cylinder("y", (0, TOP_Y + 0.95, 0), 0.22, 0.3, 8, "light")
    # engine block with a stack on the right rear
    p.box((2.1, 1.45, 1.8), (1.6, 1.3, 2.2), "paint", bevel=0.05)
    p.box((2.92, 1.45, 1.8), (0.05, 0.5, 1.4), "power")  # engine vent
    p.cylinder("y", (2.4, 2.75, 2.5), 0.2, 1.4, 8, "steel")
    p.box((2.1, 1.6, 0.68), (0.9, 0.12, 0.04), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (4.6, 0, 4.6), 0.781)
    ring(p, (0, 1.451, 0), UP, 0.82)
    bolts(p, (1.4, 2.111, 0.8), (1.4, 2.111, 2.8), 4, UP)
    for i in range(4):
        t = math.pi / 4 + i * math.pi / 2
        bolts(p, (math.cos(t) * 2.9, 0.351, math.sin(t) * 2.9), (math.cos(t) * 3.2, 0.351, math.sin(t) * 3.2), 2, UP)


unit.run(__file__, "chs_extractor", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
