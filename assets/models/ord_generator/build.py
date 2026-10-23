"""Generator (Order power generator, T1 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_generator/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs),
not rescaled; the bulkiest T1 economy building. Big shapes first: a thick
chamfered slab, a heavy armored reactor housing with sloped upper walls and
a large team roof, a stepped reactor dome with the glowing core (`core`,
pulse, rig.md 9), two tall cooling stacks with glowing rims at the back,
two transformer banks with fins and insulators cabled to the housing,
glowing vents and hazard striping. Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.7, "trim", bevel=0.14, top_scale=0.985)
    # reactor housing: upright walls, then sloped upper walls, a team roof
    p.prism_y(octagon(5.4, 1.2, 0, -0.4), 0.7, 3.4, "paint", bevel=0.18)
    p.prism_y(octagon(5.4, 1.2, 0, -0.4), 3.4, 4.7, "paint", bevel=0.18, top_scale=0.8)
    p.prism_y(octagon(4.25, 0.95, 0, -0.4), 4.7, 4.77, "team", bevel=0.03)
    for sx in (-1, 1):  # glowing vents on the sides and front
        p.box((sx * 5.42, 2.2, -0.4), (0.05, 0.5, 4.2), "power")
    p.box((0, 2.2, -5.82), (4.2, 0.5, 0.05), "power")
    p.box((0, 3.25, -5.83), (5.0, 0.12, 0.04), "light")
    hazard(p, (0, 0.95, -5.85), (1, 0, 0), (0, 0, -1), 6.5, 0.4, stripes=12)
    # stepped reactor dome on the roof
    p.cylinder("y", (0, 5.15, -0.6), 2.4, 0.8, 22, "trim", bevel=0.06)
    p.cylinder("y", (0, 5.75, -0.6), 1.9, 0.5, 22, "paint", bevel=0.05)
    # cooling stacks at the back with glowing rims and team bands
    for sx in (-1, 1):
        p.ocyl((sx * 2.6, 4.5, 4.6), UP, 1.35, 3.8, 18, "trim", radius2=1.1)
        p.cylinder("y", (sx * 2.6, 8.35, 4.6), 1.12, 0.12, 18, "power")
        p.cylinder("y", (sx * 2.6, 6.2, 4.6), 1.26, 0.5, 18, "team")
        p.cylinder("y", (sx * 2.6, 8.44, 4.6), 0.8, 0.06, 14, "dark")
    p.box((0, 3.6, 5.2), (2.6, 2.0, 1.2), "paint", bevel=0.1)  # stack plinth
    # transformer banks on both flanks: a body with fins, three insulators
    for sx in (-1, 1):
        cx = sx * 6.6
        p.prism_y(rect(cx, -3.0, 0.9, 1.8), 0.7, 2.9, "trim", bevel=0.08)
        for dz in (-1.3, -0.65, 0.0, 0.65, 1.3):
            p.box((cx + sx * 0.95, 1.8, -3.0 + dz), (0.14, 1.6, 0.25), "grille")
        for dz in (-1.1, 0.0, 1.1):
            p.cylinder("y", (cx, 3.3, -3.0 + dz), 0.18, 0.8, 8, "steel")
            p.cylinder("y", (cx, 3.75, -3.0 + dz), 0.24, 0.1, 8, "dark")
        cable(p, [(cx, 3.7, -3.0), (sx * 5.6, 4.0, -2.4), (sx * 5.0, 3.6, -1.8)], r=0.08)
        p.box((cx, 3.0, -4.85), (1.2, 0.12, 0.04), "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.2, 0.78, sz * 7.2), (0.4, 0.1, 0.4), "light")

    # the reactor core: a glowing column in a ring housing, pulsing
    with p.sub("core", (0.0, 6.0, -0.6), "pulse", (0, 1, 0)):
        p.cylinder("y", (0, 6.3, -0.6), 1.35, 0.6, 22, "power")
        p.cylinder("y", (0, 6.7, -0.6), 0.9, 0.3, 18, "steel")
        p.cylinder("y", (0, 6.95, -0.6), 0.45, 0.25, 12, "power")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 5.42, 1.2, -3.5), (sx * 5.42, 1.2, 2.7), 7, (sx, 0, 0))
        seam(p, (sx * 5.42, 3.4, -3.8), (sx * 5.42, 3.4, 3.0), (sx, 0, 0))
    rivets(p, (-3.0, 1.2, -5.82), (3.0, 1.2, -5.82), 7, (0, 0, -1))


unit.run(__file__, "ord_generator", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 18, -26), (0, 3.5, 0), 50),
                   ("80", (0, 38, 6), (0, 3, 0), 50),
                   ("close", (-11, 10, -13), (0, 4.0, 0), 35)])
