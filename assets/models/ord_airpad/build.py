"""Aerie (Order rearm pad, T1 structure, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_airpad/build.py

New mesh in the size-scale style (S-104, M-26: footprint 3, 24 x 24
studs, low: about 5 tall at the rearm arm), from its blockout. Big shapes
first: a chamfered slab, a raised octagonal landing pad with a team ring,
landing marks, a hazard border and edge lights; an armored rearm pedestal
with a jointed boom and a lit head over the pad; a fuel block with a team
top, glowing gauges and a hose; a small control booth with a lit window;
corner lights. Order reads heavy and clean (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec


def build_base(p):
    p.prism_y(octagon(11.6, 1.4), 0.0, 0.5, "trim", bevel=0.12, top_scale=0.99)
    # landing pad: team ring, dark deck, marks, hazard border, edge lights
    p.prism_y(octagon(7.6, 2.2), 0.5, 0.66, "team", bevel=0.02)
    p.prism_y(octagon(7.1, 2.05), 0.5, 0.74, "dark", bevel=0.04)
    for dx in (-1.8, 1.8):
        p.box((dx, 0.77, 0), (0.7, 0.04, 6.0), "paint")
    p.box((0, 0.77, 0), (3.6, 0.04, 0.7), "paint")
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        c, s = math.cos(a), math.sin(a)
        p.box((c * 7.0, 0.82, s * 7.0), (0.35, 0.14, 0.35), "light")
    for sz in (-1, 1):
        hazard(p, (0, 0.52, sz * 8.6), (1, 0, 0), UP, 9.0, 0.5, stripes=16)
    # rearm pedestal, jointed boom and a lit head over the pad
    p.prism_y(rect(-9.4, 0.0, 1.0, 1.0), 0.5, 3.0, "paint", bevel=0.1, top_scale=0.85)
    p.box((-9.4, 2.0, -1.0), (1.2, 0.8, 0.05), "team", bevel=0.01)
    p.cylinder("y", (-9.4, 3.2, 0), 0.7, 0.4, 14, "steel")
    a, b = V((-9.4, 3.5, 0)), V((-6.4, 4.6, 0))
    p.obox(tuple((a + b) / 2), tuple(b - a), (0, 1, 0), (b - a).length, 0.5, 0.5, "trim", bevel=0.04)
    p.cylinder("z", (-6.4, 4.6, 0), 0.35, 0.7, 12, "steel")
    c_ = V((-4.4, 3.9, 0))
    p.obox(tuple((b + c_) / 2), tuple(c_ - b), (0, 1, 0), (c_ - b).length, 0.4, 0.4, "paint", bevel=0.03)
    p.box((-4.2, 3.6, 0), (0.7, 0.6, 0.7), "trim", bevel=0.04)
    p.box((-4.2, 3.28, 0), (0.5, 0.05, 0.5), "power")
    cable(p, [(-9.0, 1.2, 0.9), (-7.5, 2.8, 0.5), (-5.0, 3.9, 0.3)], r=0.07, kind="dark")
    # fuel block with a team top, gauges and a hose to the pad
    p.prism_y(rect(9.0, -6.6, 1.6, 1.1), 0.5, 2.3, "paint", bevel=0.1)
    p.box((9.0, 2.34, -6.6), (2.6, 0.05, 1.6), "team", bevel=0.012)
    p.box((7.38, 1.4, -6.6), (0.05, 0.9, 1.4), "power")
    cable(p, [(7.5, 0.8, -5.6), (6.4, 0.65, -4.0), (5.2, 0.85, -3.2)], r=0.14, kind="dark")
    # control booth with a lit window
    p.prism_y(rect(9.0, 7.0, 1.4, 1.4), 0.5, 2.8, "paint", bevel=0.1, top_scale=0.9)
    p.box((9.0, 2.84, 7.0), (2.2, 0.05, 2.2), "team", bevel=0.012)
    p.box((7.58, 2.0, 7.0), (0.05, 0.6, 1.8), "glass")
    p.box((7.58, 1.6, 7.0), (0.05, 0.1, 2.0), "light")
    p.cylinder("y", (9.6, 3.4, 7.6), 0.05, 1.2, 6, "steel")
    p.box((9.6, 4.05, 7.6), (0.22, 0.16, 0.22), "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 0.56, sz * 11.0), (0.45, 0.14, 0.45), "light")


def details_base(p):
    for z in (-10.0, 10.0):
        seam(p, (-10.0, 0.501, z), (10.0, 0.501, z), UP)
    rivets(p, (-10.4, 1.2, -1.01), (-8.4, 1.2, -1.01), 4, (0, 0, -1))
    ring(p, (0, 0.741, 0), UP, 5.6)


unit.run(__file__, "ord_airpad", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-30, 22, -36), (0, 1.5, 0), 50),
                   ("80", (0, 52, 8), (0, 1, 0), 50),
                   ("close", (-15, 11, -18), (-2.0, 2.0, 0), 40)])
