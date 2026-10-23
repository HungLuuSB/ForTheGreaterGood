"""Curtain (Order jammer tower, T1 structure, footprint 1): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_curtain/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 6 tall), from its blockout. Big shapes first: a chamfered slab with
hazard striping, an armored block with sloped walls, large team plates and
running strips, a tapered emitter post with two glowing fins on armored
brackets, and the client-spun emitter `tip` (spin Y, rig.md 9): a faceted
head with three small emitter dishes and a glowing crown. Order reads heavy
and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

TIP = (0.0, 5.2, -0.3)


def build_base(p):
    p.prism_y(octagon(3.85, 0.6), 0.0, 0.5, "trim", bevel=0.08, top_scale=0.98)
    hazard(p, (0, 0.52, -3.45), (1, 0, 0), UP, 4.4, 0.35, stripes=9)
    p.prism_y(octagon(2.9, 0.8), 0.5, 1.5, "paint", bevel=0.12)
    p.prism_y(octagon(2.9, 0.8), 1.5, 2.1, "paint", bevel=0.12, top_scale=0.72)
    for sz in (-1, 1):
        p.obox((0, 1.8, sz * 2.55), (1, 0, 0), (0, 0.8, sz * 0.6), 2.4, 0.7, 0.05, "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 2.92, 1.0, 0), (0.05, 0.12, 2.6), "light")
        p.box((sx * 3.5, 0.56, sx * 3.5), (0.3, 0.12, 0.3), "light")
    # tapered emitter post, fins on brackets
    p.prism_y(rect(0, -0.3, 0.75, 0.75), 2.1, 4.9, "paint", bevel=0.08, top_scale=0.7)
    for sx in (-1, 1):
        p.box((sx * 0.85, 3.4, -0.3), (0.5, 0.5, 0.6), "trim", bevel=0.03)
        p.box((sx * 1.4, 3.5, -0.3), (0.9, 2.0, 0.12), "trim", bevel=0.02)
        p.box((sx * 1.4, 3.5, -0.37), (0.7, 1.8, 0.04), "power")
        p.box((sx * 1.4, 3.5, -0.23), (0.7, 1.8, 0.04), "power")
    p.cylinder("y", TIP, 0.45, 0.2, 12, "steel")

    with p.sub("tip", TIP, "spin", (0, 1, 0)):
        p.prism_y(octagon(0.55, 0.18, TIP[0], TIP[2]), 5.3, 6.0, "trim", bevel=0.04, top_scale=0.6)
        for k in range(3):
            a = k * 2 * math.pi / 3
            c, s = math.cos(a), math.sin(a)
            p.ocyl((TIP[0] + c * 0.55, 5.6, TIP[2] + s * 0.55), (c, 0, s), 0.28, 0.12, 10, "dark")
            p.ocyl((TIP[0] + c * 0.66, 5.6, TIP[2] + s * 0.66), (c, 0, s), 0.2, 0.03, 10, "power")
        p.cylinder("y", (TIP[0], 6.05, TIP[2]), 0.25, 0.1, 10, "power")


def details_base(p):
    rivets(p, (-1.8, 2.101, 0.6), (1.8, 2.101, 0.6), 6, UP)
    ring(p, (0, 2.101, -0.3), UP, 0.9)


unit.run(__file__, "ord_curtain", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-15, 13, -18), (0, 3.0, 0), 50),
                   ("80", (0, 28, 4), (0, 2, 0), 50),
                   ("close", (-7, 7, -9), (0, 3.5, 0), 40)])
