"""Extractor (Order supply extractor, T1 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_extractor/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
up to about 7 tall), not rescaled. Big readable shapes first: a thick
chamfered slab (hides the deposit under any quadrant), an armored octagonal
housing with a large team deck, a turning drill crown (`drill`, turn Y,
rig.md 9) with glowing power bands, two ore hoppers fed by inclined
conveyors, pump units with pipes and valves, corner anchor blocks with
lights. Order reads heavy and clean (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec


def octagon(r, cut):
    """Top-view octagon (x, z): a square of half-size r with corners cut by `cut`."""
    return [(-r + cut, -r), (r - cut, -r), (r, -r + cut), (r, r - cut), (r - cut, r), (-r + cut, r), (-r, r - cut), (-r, -r + cut)]


def build_base(p):
    # thick chamfered slab and a darker plinth ring round the housing
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.78, "trim", bevel=0.14, top_scale=0.985)
    p.prism_y(octagon(5.6, 1.4), 0.78, 1.05, "dark", bevel=0.06)
    # armored octagonal housing with sloped upper walls
    p.prism_y(octagon(4.6, 1.4), 1.05, 2.6, "paint", bevel=0.16)
    p.prism_y(octagon(4.6, 1.4), 2.6, 3.55, "paint", bevel=0.16, top_scale=0.82)
    p.prism_y(octagon(3.7, 1.15), 3.55, 3.62, "team", bevel=0.03)  # large team deck
    for sx in (-1, 1):  # power strips round the housing
        p.box((sx * 4.62, 2.0, 0.0), (0.04, 0.16, 3.0), "power")
        p.box((0.0, 2.0, sx * 4.62), (3.0, 0.16, 0.04), "power")
    # corner anchor blocks with lights and hazard striping
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = (sx * 6.3, 1.1, sz * 6.3)
            p.prism_y([(c[0] - 0.8, c[2] - 0.8), (c[0] + 0.8, c[2] - 0.8), (c[0] + 0.8, c[2] + 0.8), (c[0] - 0.8, c[2] + 0.8)],
                      0.78, 1.6, "paint", bevel=0.1, top_scale=0.8)
            p.box((c[0], 1.66, c[2]), (0.45, 0.12, 0.45), "light")
    hazard(p, (0, 0.8, -6.9), (1, 0, 0), (0, 1, 0), 6.0, 0.5, stripes=12)
    # ore hoppers (front left, back right): tapered bins on legs, team panels
    for sx, sz in ((-1, -1), (1, 1)):
        hx, hz = sx * 5.2, sz * 5.0
        for lx in (-0.9, 0.9):
            for lz in (-0.9, 0.9):
                p.box((hx + lx, 1.6, hz + lz), (0.22, 1.7, 0.22), "dark")
        p.prism_y([(hx - 1.0, hz - 1.0), (hx + 1.0, hz - 1.0), (hx + 1.0, hz + 1.0), (hx - 1.0, hz + 1.0)],
                  2.2, 4.0, "paint", bevel=0.1, top_scale=1.35)
        p.obox((hx - sx * 0.02, 3.2, hz + sz * 1.22), (1, 0, 0), (0, 0.25, sz), 2.0, 1.3, 0.06, "team", bevel=0.02)
        p.box((hx, 4.02, hz), (2.4, 0.06, 2.4), "grille")
        # inclined conveyor from the housing to the hopper
        a = V((sx * 2.2, 3.4, sz * 2.0))
        b = V((hx - sx * 0.6, 4.2, hz - sz * 0.6))
        u = b - a
        p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.9, 0.3, "trim", bevel=0.05)
        p.obox(tuple((a + b) / 2 + V((0, 0.17, 0))), tuple(u), (0, 1, 0), u.length * 0.95, 0.7, 0.04, "grille")
        for t in (0.25, 0.75):
            q = a + u * t
            p.box((q.x, (q.y + 1.0) / 2, q.z), (0.18, q.y - 1.0, 0.18), "dark")
    # pump units on the other two corners: horizontal drums, pipes, valves
    for sx, sz in ((1, -1), (-1, 1)):
        px, pz = sx * 5.0, sz * 5.0
        p.box((px, 1.4, pz), (2.4, 0.7, 1.8), "trim", bevel=0.08)
        drum(p, (px, 2.25, pz), 0.75, 2.2, "paint", "trim", sides=16)
        p.box((px, 2.25, pz + sz * 0.78), (1.6, 0.14, 0.04), "power")
        p.cylinder("y", (px - sx * 0.6, 3.2, pz), 0.18, 1.2, 8, "steel")
        p.cylinder("x", (px - sx * 0.6, 3.8, pz), 0.3, 0.4, 10, "dark")  # valve wheel
        cable(p, [(px - sx * 1.1, 2.3, pz), (sx * 4.2, 2.3, pz * 0.6), (sx * 4.2, 1.6, pz * 0.4)], r=0.14, kind="steel")
    # front walkway with a rail and a lit door
    p.box((0, 1.25, -5.0), (3.0, 0.12, 1.2), "grille")
    p.box((0, 2.0, -4.62), (1.6, 1.5, 0.06), "dark")
    p.box((0, 2.8, -4.64), (1.4, 0.12, 0.04), "light")

    # the drill crown: a turning drum with power bands, three arms and a cap
    with p.sub("drill", (0.0, 3.62, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 4.2, 0), 1.55, 1.15, 20, "steel")
        for y in (3.85, 4.55):
            p.cylinder("y", (0, y, 0), 1.58, 0.14, 20, "power")
        p.cylinder("y", (0, 5.0, 0), 1.25, 0.45, 18, "trim")
        for k in range(3):
            a = math.radians(90 + 120 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            p.obox(tuple(V((0, 5.25, 0)) + d * 1.3), tuple(d), (0, 1, 0), 1.6, 0.5, 0.45, "paint", bevel=0.06)
            p.box(tuple(V((0, 5.3, 0)) + d * 2.0), (0.3, 0.12, 0.3), "light")
        p.cylinder("y", (0, 5.75, 0), 0.75, 0.6, 14, "dark")
        p.cylinder("y", (0, 6.2, 0), 0.4, 0.3, 10, "power")
        p.box((0, 5.95, 0), (2.1, 0.04, 0.5), "team")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 4.62, 1.4, -2.2), (sx * 4.62, 1.4, 2.2), 6, (sx, 0, 0))
        rivets(p, (-2.2, 1.4, sx * 4.62), (2.2, 1.4, sx * 4.62), 6, (0, 0, sx))
        seam(p, (sx * 4.62, 2.6, -2.5), (sx * 4.62, 2.6, 2.5), (sx, 0, 0))


unit.run(__file__, "ord_extractor", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 2.5, 0), 50),
                   ("80", (0, 36, 6), (0, 2, 0), 50),
                   ("close", (-11, 9, -13), (0, 3.0, 0), 35)])
