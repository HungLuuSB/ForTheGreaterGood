"""Ear (Order sonar buoy, T1 structure, footprint 1, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_ear/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 4 above the water), from its blockout. The waterline is y = 0. Big
shapes first: an armored octagonal float with sloped sides, team plates
and running strips, a hazard edge and bollards; a squat armored sonar
housing with the client-turned glowing `ring` (turn Y, rig.md 9) and a
domed cap, a sonar dome under the float; a whip mast with a lamp. Order
reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402


def build_base(p):
    p.prism_y(octagon(3.6, 1.0), -0.9, 0.2, "paint", bevel=0.1)
    p.prism_y(octagon(3.6, 1.0), 0.2, 0.8, "paint", bevel=0.1, top_scale=0.9)
    for sz in (-1, 1):
        p.obox((0, 0.55, sz * 3.4), (1, 0, 0), (0, 0.55, sz * 1.0), 2.8, 0.6, 0.05, "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 3.62, 0.0, 0), (0.05, 0.14, 3.0), "light")
        p.cylinder("y", (sx * 2.2, 1.0, 2.2), 0.22, 0.45, 10, "steel")
    hazard(p, (0, 0.82, -2.6), (1, 0, 0), UP, 3.0, 0.35, stripes=7)
    p.cylinder("y", (0, -1.3, 0), 1.6, 0.8, 18, "dark")  # sonar dome under the float
    # squat armored sonar housing and cap
    p.cylinder("y", (0, 1.15, 0), 1.9, 0.7, 20, "trim", bevel=0.05)
    p.cylinder("y", (0, 2.2, 0), 1.5, 0.9, 20, "paint", bevel=0.05)
    p.ocyl((0, 2.65, 0), UP, 1.5, 0.5, 20, "trim", radius2=0.8)
    p.cylinder("y", (0, 3.18, 0), 0.5, 0.08, 14, "power")
    # whip mast with a lamp
    p.box((2.2, 1.0, -2.2), (0.7, 0.4, 0.7), "trim", bevel=0.04)
    p.cylinder("y", (2.2, 2.6, -2.2), 0.07, 2.8, 6, "steel")
    p.box((2.2, 4.05, -2.2), (0.24, 0.16, 0.24), "light")

    with p.sub("ring", (0.0, 1.65, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 1.65, 0), 1.95, 0.3, 20, "dark")
        for k in range(6):  # hydrophone blocks on the ring
            import math
            a = k * math.pi / 3
            p.box((1.95 * math.cos(a), 1.65, 1.95 * math.sin(a)), (0.35, 0.28, 0.35), "steel")
        p.cylinder("y", (0, 1.65, 0), 1.97, 0.1, 20, "power")


def details_base(p):
    rivets(p, (-2.4, 0.801, 2.4), (1.0, 0.801, 2.4), 6, UP)
    ring(p, (0, 2.651, 0), UP, 1.3)


unit.run(__file__, "ord_ear", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 1.5, 0), 50),
                   ("80", (0, 26, 4), (0, 1, 0), 50),
                   ("close", (-7, 6, -9), (0, 1.5, 0), 40)])
