"""Undertow (Order torpedo launcher, T1 structure, footprint 1, on water):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_undertow/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 4 above the water), from its blockout. The waterline is y = 0. Big
shapes first: an armored octagonal float with sloped sides, team plates,
running strips and a hazard edge; a turntable ring (`turret`, the def's
piece, static); the `launcher` (the def turns it, M-3): an armored house
with a sloped roof and a large team plate over three torpedo tubes with
ready lights at the mouths (`muzzle` at the centre tube) and a sensor
head; a sonar dome under the float the client lowers (`sonar`, lower,
rig.md 9). Order reads heavy and clean (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

PIVOT = (0.0, 1.4, -0.4)
TUBE_Y = 1.95
MUZZLE = (0.0, TUBE_Y, -3.25)


def build_base(p):
    p.prism_y(octagon(3.7, 1.0), -0.9, 0.2, "paint", bevel=0.1)
    p.prism_y(octagon(3.7, 1.0), 0.2, 0.9, "paint", bevel=0.1, top_scale=0.88)
    for sz in (-1, 1):
        p.obox((0, 0.6, sz * 3.45), (1, 0, 0), (0, 0.55, sz * 1.0), 2.8, 0.6, 0.05, "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 3.72, 0.0, 0), (0.05, 0.14, 3.0), "light")
        p.box((sx * 2.7, 0.98, 2.4), (0.3, 0.14, 0.3), "light")
    hazard(p, (0, 0.92, 2.8), (1, 0, 0), UP, 3.0, 0.35, stripes=7)
    with p.sub("sonar", (0.0, -1.2, 0.0), "lower", (0, -1, 0), 8):
        p.cylinder("y", (0, -1.2, 0.0), 1.2, 0.6, 16, "dark")
        p.cylinder("y", (0, -1.0, 0.0), 1.24, 0.12, 16, "power")


def build_turret(p):
    p.cylinder("y", (0, 1.15, -0.4), 1.6, 0.5, 20, "trim", bevel=0.04)
    p.cylinder("y", (0, 1.42, -0.4), 1.7, 0.06, 20, "light")


def build_launcher(p):
    p.box((0, 2.0, 0.0), (2.8, 1.2, 2.6), "paint", bevel=0.08)
    p.prism_x([(-1.3, 2.6), (1.3, 2.6), (1.3, 2.75), (-0.6, 3.05), (-1.3, 2.9)], -1.4, 1.4, "paint", bevel=0.06)
    p.obox((0, 3.0, 0.2), (1, 0, 0), (0, 1, 0.12), 2.2, 1.6, 0.05, "team", bevel=0.012)
    for x in (-0.8, 0.0, 0.8):
        p.cylinder("z", (x, TUBE_Y, -1.9), 0.32, 2.6, 14, "trim")
        p.cylinder("z", (x, TUBE_Y, -3.15), 0.36, 0.2, 14, "dark")
        p.cylinder("z", (x, TUBE_Y, -3.27), 0.2, 0.04, 12, "weapon")
    p.box((1.0, 3.25, 0.8), (0.5, 0.4, 0.6), "trim", bevel=0.03)  # sensor head
    p.box((1.0, 3.25, 0.48), (0.35, 0.2, 0.05), "light")


def details_base(p):
    rivets(p, (-2.4, 0.901, -2.6), (2.4, 0.901, -2.6), 8, UP)


def details_launcher(p):
    seam(p, (-1.1, 2.601, 1.2), (1.1, 2.601, 1.2), UP)
    ring(p, (0, TUBE_Y, -3.3), (0, 0, -1), 0.22, segments=8)


unit.run(__file__, "ord_undertow", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", (0.0, 1.15, -0.4), build_turret, lambda p: None),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 1.5, -0.5), 50),
                   ("80", (0, 26, 4), (0, 1, -0.5), 50),
                   ("close", (-7, 6, -9), (0, 2.0, -1.0), 40)])
