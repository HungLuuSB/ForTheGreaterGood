"""Shipyard (Order naval factory, T1 structure, footprint 5, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_shipyard/build.py

A heavy quay at the back with an armored construction hall (team plate on
the roof, a big door with door-frame build lights: power channel, pulses
while producing), two long armored piers reaching out over the water with
cyan edge lights and a light at each tip, and a gantry crane spanning the
slip between the piers with a team band and build lamps under its beam
(BAR style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, seam  # noqa: E402


def build_base(p):
    # quay and hall
    p.prism_y([(-19, 11), (19, 11), (19, 19), (-19, 19)], 0.0, 0.6, "trim", bevel=0.06)
    p.prism_x([(11.5, 0.6), (18.5, 0.6), (18.5, 6.8), (12.6, 7.6), (11.5, 6.8)], -13, 13, "paint", bevel=0.08)
    p.box((0, 7.66, 15.2), (20, 0.05, 4.2), "team", bevel=0.015)
    p.box((0, 3.4, 11.42), (18, 5.5, 0.14), "dark")
    for i in range(4):
        p.box((0, 1.2 + i * 1.2, 11.33), (17.4, 0.14, 0.06), "power")  # build lights through the door
    p.box((0, 6.35, 11.3), (19, 0.36, 0.16), "power")  # lintel
    for sx in (-1, 1):
        p.box((sx * 9.2, 3.4, 11.3), (0.3, 5.8, 0.16), "power")  # door frame
        p.box((sx * 13.03, 3.0, 15.0), (0.06, 0.16, 6.0), "light")
        p.box((sx * 13.0, 4.8, 16.5), (0.06, 1.6, 3.0), "grille")
    # piers with tips, edge lights, tip lights
    for sx in (-1, 1):
        x = sx * 16
        p.prism_x([(-18.0, 0.0), (11.0, 0.0), (11.0, 2.4), (-18.0, 2.4), (-21.0, 1.2)], x - 3, x + 3, "paint", bevel=0.06)
        p.box((x, 2.43, -4.0), (4.0, 0.05, 8.0), "team", bevel=0.012)
        for z in (-14.0, -6.0, 2.0, 9.0):
            p.box((x - sx * 3.03, 1.6, z), (0.06, 0.16, 3.0), "light")
        p.box((x, 2.8, -17.0), (0.8, 0.8, 0.8), "light")
        for z in (-12.0, 0.0):  # bollards
            p.cylinder("y", (x - sx * 2.3, 2.7, z), 0.25, 0.6, 8, "steel")
    # gantry crane over the slip
    for sx in (-1, 1):
        p.box((sx * 16, 6.9, -6), (1.0, 9.0, 1.0), "steel", bevel=0.04)
        p.box((sx * 16, 2.7, -6), (1.6, 0.6, 2.2), "trim", bevel=0.03)
    p.box((0, 11.8, -6), (33, 1.4, 1.6), "paint", bevel=0.05)
    p.box((0, 12.53, -6), (20, 0.05, 1.2), "team", bevel=0.012)
    with p.sub("trolley", (4.0, 10.7, -6.0), "slide", (1, 0, 0), 12):  # M-27 along the gantry
        p.box((4.0, 10.7, -6), (2.0, 0.8, 2.0), "trim", bevel=0.04)  # trolley
    for x in (-10.0, -4.0, 2.0, 8.0):
        p.box((x, 11.08, -6), (1.6, 0.06, 0.9), "power")  # build lamps under the beam
    with p.sub("trolley", (4.0, 10.7, -6.0), "slide", (1, 0, 0), 12):
        p.box((4.0, 10.28, -6), (1.0, 0.06, 1.0), "power")


def details_base(p):
    box_seams(p, (0, 0, 15.0), (24.0, 0, 6.0), 7.601)
    for sx in (-1, 1):
        for z in (-12.0, -2.0, 6.0):
            seam(p, (sx * 16 - 2.8, 2.401, z), (sx * 16 + 2.8, 2.401, z), UP)
    bolts(p, (-18.5, 0.601, 18.5), (18.5, 0.601, 18.5), 20, UP)


unit.run(__file__, "ord_shipyard", "order", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
