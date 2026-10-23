"""Extractor (Chaos excavator, T1 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_extractor/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
up to about 8 tall), not rescaled. Big readable shapes first: a thick
slab (hides the deposit under any quadrant) with a raised grated platform
and team plates, an open four-leg lattice derrick over a turning drill
shaft (`drill`, turn Y, rig.md 9) with glowing bands, a heavy engine house
with twin stacks and a team roof, a salvaged ore tank and a skip conveyor,
hazard striping and beacons. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard, piston, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec
LEG_FOOT, LEG_TOP, TOP_Y = 4.4, 1.1, 7.4


def build_base(p):
    # slab, a raised grated platform, team plates on the platform deck
    p.prism_y([(-7.8, -7.0), (-7.0, -7.8), (7.0, -7.8), (7.8, -7.0), (7.8, 7.0), (7.0, 7.8), (-7.0, 7.8), (-7.8, 7.0)],
              0.0, 0.75, "dark", bevel=0.12, top_scale=0.985)
    p.box((0, 1.0, 0), (11.0, 0.5, 11.0), "paint", bevel=0.1)
    p.box((0, 1.27, 0), (10.2, 0.04, 10.2), "grille")
    for sx in (-1, 1):
        p.box((sx * 3.6, 1.29, -4.3), (2.6, 0.05, 1.6), "team", bevel=0.02)
    hazard(p, (0, 1.29, 5.0), (1, 0, 0), (0, 1, 0), 9.0, 0.5, stripes=16)
    # the derrick: four legs, three rings of braces, X-bracing on the sides
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = V((sx * LEG_FOOT, 1.25, sz * LEG_FOOT))
            b = V((sx * LEG_TOP, TOP_Y, sz * LEG_TOP))
            p.obox(tuple((a + b) / 2), tuple(b - a), (sz, 0, -sx), (b - a).length, 0.36, 0.36, "trim", bevel=0.04)
            p.box((sx * LEG_FOOT, 1.45, sz * LEG_FOOT), (0.8, 0.4, 0.8), "dark", bevel=0.05)  # foot plates
    for y in (3.0, 4.8, 6.4):
        t = (y - 1.25) / (TOP_Y - 1.25)
        w = LEG_FOOT + (LEG_TOP - LEG_FOOT) * t
        for sz in (-1, 1):
            p.box((0, y, sz * w), (2 * w, 0.2, 0.2), "dark")
        for sx in (-1, 1):
            p.box((sx * w, y, 0), (0.2, 0.2, 2 * w), "dark")
    # X-bracing on the front and back faces between the first two rings
    for sz in (-1, 1):
        y0, y1 = 3.0, 4.8
        w0 = LEG_FOOT + (LEG_TOP - LEG_FOOT) * ((y0 - 1.25) / (TOP_Y - 1.25))
        w1 = LEG_FOOT + (LEG_TOP - LEG_FOOT) * ((y1 - 1.25) / (TOP_Y - 1.25))
        for s in (-1, 1):
            a, b = V((s * w0, y0, sz * w0)), V((-s * w1, y1, sz * w1))
            p.obox(tuple((a + b) / 2), tuple(b - a), (0, 0, 1), (b - a).length, 0.14, 0.14, "dark")
    # head block at the top with a team roof and a beacon
    p.box((0, TOP_Y + 0.45, 0), (2.8, 0.9, 2.8), "paint", bevel=0.08)
    p.box((0, TOP_Y + 0.92, 0), (2.0, 0.05, 2.0), "team", bevel=0.015)
    p.cylinder("y", (0, TOP_Y + 1.15, 0), 0.26, 0.4, 8, "light")
    p.box((0, TOP_Y + 0.45, -1.42), (1.8, 0.14, 0.04), "light")
    # engine house (right rear): a heavy block, team roof, twin stacks with
    # hot rings, a glowing vent, a piston-driven pump
    p.box((5.0, 2.4, 3.6), (3.6, 2.4, 4.4), "paint", bevel=0.14)
    p.box((5.0, 3.62, 3.6), (3.0, 0.05, 3.8), "team", bevel=0.02)
    p.box((6.82, 2.4, 3.6), (0.05, 0.7, 2.8), "power")
    for dz in (-1.0, 1.0):
        p.cylinder("y", (4.0, 4.6, 3.6 + dz), 0.32, 2.2, 10, "steel")
        p.cylinder("y", (4.0, 5.72, 3.6 + dz), 0.35, 0.12, 10, "power")
    piston(p, (3.2, 3.2, 1.5), (1.5, 2.0, 0.9), r=0.12)
    # salvaged ore tank (left), strapped, with a skip conveyor up to the platform
    drum(p, (-5.2, 2.6, 2.4), 1.25, 4.2, "paint", "trim", sides=18, axis="z")
    for dz in (-1.2, 0.0, 1.2):
        p.cylinder("z", (-5.2, 2.6, 2.4 + dz), 1.29, 0.14, 18, "dark")
    p.box((-5.2, 3.9, 2.4), (1.4, 0.05, 2.6), "team")
    a, b = V((-3.2, 1.3, -2.0)), V((-5.2, 3.8, -0.6))
    u = b - a
    p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.9, 0.3, "trim", bevel=0.04)
    p.obox(tuple((a + b) / 2 + V((0, 0.17, 0))), tuple(u), (0, 1, 0), u.length * 0.95, 0.7, 0.04, "grille")
    # beacons on the platform corners
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 5.3, 1.4, sz * 5.3), (0.3, 0.25, 0.3), "light")

    # the drill: a turning shaft with power bands, a collar and a cutter head
    with p.sub("drill", (0.0, 1.25, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 1.65, 0), 1.25, 0.8, 16, "trim")
        p.cylinder("y", (0, 2.1, 0), 1.2, 0.18, 16, "power")
        p.cylinder("y", (0, 4.6, 0), 0.75, 5.6, 12, "steel")
        for y in (3.2, 4.6, 6.0):
            p.cylinder("y", (0, y, 0), 0.8, 0.16, 12, "power")
        for k in range(4):  # flights spiralling round the shaft
            a = math.radians(45 + 90 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            p.obox(tuple(V((0, 2.8 + k * 0.9, 0)) + d * 0.95), tuple(d), (0, 1, 0), 0.5, 0.6, 0.1, "dark")


def details_base(p):
    rivets(p, (3.4, 3.61, 1.6), (6.6, 3.61, 1.6), 6, UP)
    seam(p, (3.2, 2.4, 1.39), (6.8, 2.4, 1.39), (0, 0, -1))
    for sx in (-1, 1):
        rivets(p, (sx * 5.45, 1.26, -4.5), (sx * 5.45, 1.26, 4.5), 7, UP)


unit.run(__file__, "chs_extractor", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 3.0, 0), 50),
                   ("80", (0, 36, 6), (0, 2, 0), 50),
                   ("close", (-11, 10, -13), (0, 3.5, 0), 35)])
