"""Generator (Order power generator, T1 structure, footprint 1): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_generator/build.py

A heavy armored block with chamfered corners on a pad, a stepped dome on
top with a glowing cyan core, team plates front and back on the roof, glowing
vent strips on the sides (BAR style, M-15; Order reads heavy, M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

BLOCK = [(-2.4, -3.0), (2.4, -3.0), (3.0, -2.4), (3.0, 2.4), (2.4, 3.0), (-2.4, 3.0), (-3.0, 2.4), (-3.0, -2.4)]


def build_base(p):
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.45, "trim", bevel=0.05, top_scale=0.97)
    p.prism_y(BLOCK, 0.45, 3.4, "paint", bevel=0.06, top_scale=0.93)
    for sz in (-1, 1):
        p.box((0, 3.43, sz * 2.0), (3.6, 0.06, 1.0), "team", bevel=0.015)
    # stepped dome and the core
    p.cylinder("y", (0, 3.75, 0), 2.0, 0.7, 16, "paint")
    p.cylinder("y", (0, 4.4, 0), 1.6, 0.6, 16, "trim", radius2=1.35)
    p.cylinder("y", (0, 4.1, 0), 1.65, 0.14, 16, "power")  # dome ring
    p.cylinder("y", (0, 4.85, 0), 1.0, 0.3, 14, "steel")
    p.cylinder("y", (0, 5.15, 0), 0.78, 0.34, 14, "power")
    p.cylinder("y", (0, 5.35, 0), 0.5, 0.1, 10, "dark")
    # glowing vents on the sides, louvred grilles, conduits
    for sx in (-1, 1):
        p.box((sx * 2.88, 2.2, 0), (0.06, 0.32, 3.8), "power")
        p.box((sx * 2.84, 1.4, 0), (0.06, 0.9, 3.6), "grille")
        p.cylinder("z", (sx * 2.2, 3.55, 0), 0.16, 3.4, 8, "steel")
    for sz in (-1, 1):
        p.box((0, 1.8, sz * 2.86), (2.6, 1.2, 0.06), "grille")
        p.box((0, 0.6, sz * 3.55), (1.8, 0.1, 0.06), "light")


def details_base(p):
    ring(p, (0, 4.101, 0), UP, 1.9)
    ring(p, (0, 5.001, 0), UP, 0.95)
    for sz in (-1, 1):
        seam(p, (-2.6, 3.401, sz * 0.9), (2.6, 3.401, sz * 0.9), UP)
        bolts(p, (-2.2, 3.401, sz * 2.75), (2.2, 3.401, sz * 2.75), 6, UP)
    for sx in (-1, 1):
        bolts(p, (sx * 2.9, 2.9, -2.0), (sx * 2.9, 2.9, 2.0), 5, (sx, 0, 0))


unit.run(__file__, "ord_generator", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
