"""Vehicle plant (Chaos factory, T1 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_vehplant/build.py

A long slab shed on one side of a grated apron and an open assembly bay
beside it under a gantry: four lattice columns, two beams and a crane
rail; fuel tanks behind, orange work lights, team plates on the shed roof
and the apron (BAR style, M-15; Chaos reads light and open, M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, seam  # noqa: E402

COLUMNS = [(-2.0, -4.0), (9.0, -4.0), (-2.0, 8.0), (9.0, 8.0)]


def build_base(p):
    p.prism_y([(-11, -11), (11, -11), (11, 11), (-11, 11)], 0.0, 0.5, "dark", bevel=0.05)
    p.box((3.5, 0.52, 2.0), (10.6, 0.04, 12.0), "grille")
    p.box((4.0, 0.53, -8.5), (8.0, 0.05, 3.0), "team", bevel=0.015)
    # the shed with a pitched roof
    p.box((-6.5, 3.0, 2.0), (8.0, 5.0, 14.0), "paint", bevel=0.06)
    p.prism_x([(-5.0, 5.5), (9.0, 5.5), (9.0, 6.2), (2.0, 7.0), (-5.0, 6.2)], -10.5, -2.5, "paint", bevel=0.05)
    p.box((-6.5, 6.25, -2.8), (5.0, 0.05, 4.0), "team", bevel=0.015)
    p.box((-6.5, 2.6, -5.04), (5.0, 4.0, 0.1), "dark")
    p.box((-6.5, 4.85, -5.1), (5.0, 0.2, 0.06), "light")
    # the gantry: four columns, two beams, the crane rail and its trolley
    for x, z in COLUMNS:
        p.box((x, 3.8, z), (0.6, 6.6, 0.6), "trim", bevel=0.03)
    for z in (-4.0, 8.0):
        p.box((3.5, 7.2, z), (11.6, 0.7, 0.7), "steel", bevel=0.03)
    p.box((4.0, 7.65, 2.0), (0.8, 0.5, 12.6), "trim", bevel=0.03)
    p.box((4.0, 7.0, -0.5), (1.6, 0.8, 1.4), "paint", bevel=0.04)
    p.box((4.0, 5.6, -0.5), (0.12, 2.0, 0.12), "dark")
    for x, z in ((9.0, -4.0), (-2.0, -4.0)):
        p.box((x, 7.65, z), (0.5, 0.4, 0.5), "light")
    # tanks behind the bay
    p.cylinder("y", (7.0, 3.0, 9.2), 1.5, 5.0, 12, "steel")
    p.cylinder("y", (3.4, 2.5, 9.6), 1.2, 4.0, 12, "steel")
    p.cylinder("y", (7.0, 3.6, 9.2), 1.55, 0.25, 12, "light")


def details_base(p):
    box_seams(p, (-6.5, 0, 2.0), (8.0, 0, 14.0), 5.501)
    for z in (-2.0, 2.0, 6.0):
        seam(p, (-10.5, 3.0, z), (-10.5, 5.0, z), (-1, 0, 0))
    for x, z in COLUMNS:
        bolts(p, (x - 0.3, 0.501, z - 0.5), (x + 0.3, 0.501, z - 0.5), 2, UP)
    bolts(p, (-10.5, 0.501, -10.5), (10.5, 0.501, -10.5), 14, UP)


unit.run(__file__, "chs_vehplant", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
