"""Vehicle plant (Order factory, T1 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_vehplant/build.py

A heavy armored hall on an apron: sloped front roof edge over a big door
with a glowing lintel and door frame (the power channel's build lights), a ramp out, angled buttresses either side, a roof
with two big team plates and a vent block, beacons on the apron corners
(BAR style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, seam  # noqa: E402


def build_base(p):
    p.prism_y([(-11, -11), (11, -11), (11, 11), (-11, 11)], 0.0, 0.6, "trim", bevel=0.08, top_scale=0.985)
    for sx in (-1, 1):
        p.box((sx * 8.0, 0.62, -8.5), (4.0, 0.04, 3.0), "grille")
    # the hall, its roof with a sloped front edge
    p.prism_x([(-4.5, 0.6), (9.5, 0.6), (9.5, 6.6), (-3.2, 6.6), (-4.5, 5.6)], -9.0, 9.0, "paint", bevel=0.08)
    p.prism_x([(-4.7, 6.6), (9.7, 6.6), (9.7, 7.6), (-3.4, 7.6)], -9.3, 9.3, "paint", bevel=0.06)
    for sx in (-1, 1):
        p.box((sx * 4.4, 7.63, 3.4), (7.0, 0.06, 9.0), "team", bevel=0.02)
    p.box((0, 8.1, 7.2), (6.0, 1.0, 3.0), "trim", bevel=0.05)
    p.box((0, 8.62, 7.2), (5.2, 0.05, 2.4), "power")  # roof vent
    # the door, its glowing lintel, the ramp
    p.box((0, 3.1, -4.55), (10.0, 5.0, 0.12), "dark")
    for i in range(5):
        p.box((0, 1.0 + i * 1.0, -4.62), (9.8, 0.06, 0.04), "seam")
        p.box((0, 1.0 + i * 1.0, -4.64), (9.6, 0.12, 0.05), "power")  # build lights through the door
    p.box((0, 5.85, -4.66), (10.0, 0.4, 0.12), "power")  # door lintel
    for sx in (-1, 1):  # door-frame build lights up both jambs (pulse with production)
        p.box((sx * 5.12, 3.1, -4.66), (0.22, 5.1, 0.14), "power")
        for i in range(4):  # short chevron ticks, like the Chaos plant's slats
            p.box((sx * 5.45, 1.3 + i * 1.15, -4.56), (0.4, 0.12, 0.08), "power")
    p.prism_x([(-9.6, 0.6), (-4.6, 0.6), (-4.6, 1.2)], -6.0, 6.0, "steel", bevel=0.03)
    for sx in (-1, 1):  # ramp guide lights
        p.box((sx * 6.1, 0.75, -7.1), (0.16, 0.12, 5.0), "light")
    # buttresses either side of the door
    for sx in (-1, 1):
        x0, x1 = (9.0, 11.0) if sx > 0 else (-11.0, -9.0)
        p.prism_x([(-6.0, 0.6), (-1.0, 0.6), (-1.0, 5.6), (-3.0, 5.6)], x0, x1, "paint", bevel=0.05)
        p.box((sx * 10.0, 1.2, -10.0), (0.6, 0.6, 0.6), "light")
        p.box((sx * 9.06, 3.4, 4.0), (0.1, 0.36, 9.0), "light")


def details_base(p):
    box_seams(p, (0, 0, 2.5), (18.0, 0, 14.0), 7.601)
    for z in (-1.0, 3.0, 7.0):
        seam(p, (-9.0, 7.601, z), (9.0, 7.601, z), UP)
    for sx in (-1, 1):
        bolts(p, (sx * 9.05, 6.0, -4.0), (sx * 9.05, 6.0, 9.0), 10, (sx, 0, 0))
    bolts(p, (-10.5, 0.601, 10.5), (10.5, 0.601, 10.5), 14, UP)


unit.run(__file__, "ord_vehplant", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
