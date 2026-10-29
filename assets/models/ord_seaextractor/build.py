"""Offshore Extractor (Order submerged supply extractor, T1 structure,
footprint 2; S-209, BAR armmex / armuwmex): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_seaextractor/build.py

16 x 16 studs, about 6 tall, sitting on the seabed. Big readable shapes
first: a thick chamfered footing anchored by four ballast blocks; a
stepped octagonal pyramid of three armored tiers with ribbed radiator
steps; four buttress ramps down the sides with team panels and amber
marker lights at their feet; on top a turning four-bladed impeller
(`drill`, turn Y, rig.md 9) with team panels on its blades and a glowing
hub. Lights everywhere stay bright, so it reads through the water. Order
reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
TOP = 4.0  # top of the pyramid, where the impeller turns


def build_base(p):
    p.prism_y(octagon(7.8, 2.0), 0.0, 0.7, "trim", bevel=0.14, top_scale=0.985)
    # ballast blocks on the corners, chained to the footing
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = (sx * 6.1, sz * 6.1)
            p.prism_y(octagon(1.0, 0.35, *c), 0.0, 1.3, "dark", bevel=0.08, top_scale=0.8)
            p.box((c[0], 1.34, c[1]), (0.4, 0.08, 0.4), "light")
    # the stepped pyramid: three tiers with ribbed radiator steps
    tiers = [(6.4, 1.8, 0.7, 1.6), (5.2, 1.5, 1.6, 2.5), (3.9, 1.2, 2.5, 3.4)]
    for r, cut, y0, y1 in tiers:
        p.prism_y(octagon(r, cut), y0, y1 - 0.25, "paint", bevel=0.1)
        p.prism_y(octagon(r, cut), y1 - 0.25, y1, "paint", bevel=0.06, top_scale=0.95)
        p.prism_y(octagon(r + 0.04, cut + 0.02), y0 + 0.3, y0 + 0.42, "dark")  # radiator groove
    p.prism_y(octagon(2.8, 0.9), 3.4, TOP, "trim", bevel=0.08, top_scale=0.9)
    p.prism_y(octagon(2.4, 0.8), TOP, TOP + 0.05, "dark")
    # four buttress ramps down the sides with team panels and amber markers
    for k in range(4):
        a = math.radians(90 * k)
        d = V((math.sin(a), 0, -math.cos(a)))
        side = V((d.z, 0, -d.x))
        prof = [(2.4, 0.7), (7.6, 0.7), (7.6, 1.1), (3.2, 3.9), (2.4, 3.9)]
        pts = []
        for r_, y in prof:
            q = d * r_
            pts.append((q, y))
        for s, kind in ((-1, "paint"),):
            # a ramp: an oriented box along the slope, a flat foot pad
            a0, b0 = d * 2.8 + V((0, 3.6, 0)), d * 7.2 + V((0, 1.0, 0))
            u = b0 - a0
            nrm = u.cross(side).normalized()
            if nrm.y < 0:
                nrm = -nrm
            p.obox(tuple((a0 + b0) / 2), tuple(u), tuple(nrm), u.length + 0.4, 1.8, 0.7, kind, bevel=0.1)
            p.obox(tuple((a0 + b0) / 2 + nrm * 0.37), tuple(u), tuple(nrm), u.length * 0.7, 1.2, 0.05, "team", bevel=0.02)
            p.obox(tuple(a0 + u * 0.15 + nrm * 0.38), tuple(u), tuple(nrm), 0.6, 1.3, 0.04, "light")
        foot = d * 7.4
        p.box((foot.x, 0.85, foot.z), (1.4 if abs(d.x) < 0.5 else 1.0, 0.4, 1.0 if abs(d.x) < 0.5 else 1.4), "trim", bevel=0.06)
        lamp = d * 7.95
        p.box((lamp.x, 0.85, lamp.z), (0.6 if abs(d.x) < 0.5 else 0.08, 0.5, 0.08 if abs(d.x) < 0.5 else 0.6), "head")

    # the impeller: four blades with team panels round a glowing hub
    with p.sub("drill", (0.0, TOP, 0.0), "turn", (0, 1, 0)):
        drum(p, (0, TOP + 0.35, 0), 1.3, 0.7, "steel", "trim", sides=16, axis="y")
        p.cylinder("y", (0, TOP + 0.75, 0), 1.0, 0.12, 16, "power")
        p.cylinder("y", (0, TOP + 1.0, 0), 0.8, 0.45, 12, "trim")
        p.cylinder("y", (0, TOP + 1.28, 0), 0.45, 0.12, 10, "power")
        for k in range(4):
            a = math.radians(45 + 90 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            side = V((-d.z, 0, d.x))
            c = d * 3.3 + V((0, TOP + 0.75, 0))
            p.obox(tuple(c), tuple(d), tuple(V(UP) + side * 0.25), 4.4, 1.5, 0.35, "paint", bevel=0.08)
            p.obox(tuple(c + d * 0.3 + V((0, 0.2, 0))), tuple(d), tuple(V(UP) + side * 0.25), 2.8, 1.0, 0.05, "team", bevel=0.02)
            p.box(tuple(d * 5.4 + V((0, TOP + 0.75, 0))), (0.3, 0.3, 0.3), "light")


def details_base(p):
    for k in range(4):
        a = math.radians(90 * k)
        d = V((math.sin(a), 0, -math.cos(a)))
        side = V((d.z, 0, -d.x))
        c = d * 6.42 + V((0, 1.2, 0))
        rivets(p, tuple(c - side * 1.6), tuple(c + side * 1.6), 5, tuple(d))
        q = d * 3.92 + V((0, 2.95, 0))
        seam(p, tuple(q - side * 1.2), tuple(q + side * 1.2), tuple(d))
    ring(p, (0, TOP + 0.06, 0), UP, 2.0)


unit.run(__file__, "ord_seaextractor", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=4000,
         previews=[("35", (-22, 17, -26), (0, 2.5, 0), 50),
                   ("80", (0, 36, 6), (0, 2, 0), 50),
                   ("close", (-11, 9, -13), (0, 3.0, 0), 35)])
