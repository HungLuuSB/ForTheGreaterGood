"""Supply Converter (Order converter, T1 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_converter/build.py

New mesh in the size-scale style (S-104, M-26: footprint 2, 16 x 16 studs,
about 7 tall), from its blockout. Big shapes first: a chamfered slab with
hazard striping, an armored housing with sloped upper walls and a large
team deck, a converter column of stacked armored rings with glowing coil
bands (`coil`, pulse, rig.md 9) under a heavy cap, two power intake drums
on the flanks with pipes and valves into the housing, an output hopper at
the front with a team panel and a lit chute, corner lights. Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.985)
    hazard(p, (0, 0.62, -7.0), (1, 0, 0), UP, 6.0, 0.4, stripes=12)
    # armored housing, sloped upper walls, team deck
    p.prism_y(octagon(4.6, 1.2, 0, 0.6), 0.6, 2.6, "paint", bevel=0.16)
    p.prism_y(octagon(4.6, 1.2, 0, 0.6), 2.6, 3.6, "paint", bevel=0.16, top_scale=0.8)
    p.prism_y(octagon(3.6, 0.9, 0, 0.6), 3.6, 3.66, "team", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 4.62, 1.6, 0.6), (0.05, 0.4, 5.6), "light")
        p.box((sx * 4.62, 2.2, 0.6), (0.05, 0.12, 6.4), "power")
    # intake drums on the flanks, pipes and valves into the housing
    for sx in (-1, 1):
        drum(p, (sx * 6.2, 1.7, 1.2), 1.15, 5.4, "paint", "trim", sides=16, axis="z")
        p.cylinder("z", (sx * 6.2, 1.7, 1.2), 1.19, 1.0, 16, "team")
        for z in (-0.8, 3.2):
            p.cylinder("z", (sx * 6.2, 1.7, z), 1.18, 0.16, 16, "dark")
        p.cylinder("x", (sx * 5.0, 2.2, 2.8), 0.28, 1.6, 10, "steel")
        p.cylinder("x", (sx * 5.2, 2.2, 2.8), 0.4, 0.2, 10, "dark")  # valve
        p.box((sx * 6.2, 1.7, -1.62), (0.9, 0.3, 0.05), "power")
    # output hopper at the front: a sloped chute with a team panel
    p.prism_x([(-5.8, 0.6), (-3.6, 0.6), (-3.6, 2.6), (-4.6, 2.6)], -1.8, 1.8, "trim", bevel=0.06)
    p.obox((0, 1.9, -4.95), (1, 0, 0), (0, 0.5, -0.87), 3.0, 1.4, 0.05, "team", bevel=0.012)
    p.box((0, 0.95, -5.82), (2.6, 0.3, 0.05), "power")
    # the converter column base and bearing on the deck
    p.cylinder("y", (0, 3.95, 0.6), 2.3, 0.6, 22, "trim", bevel=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.2, 0.68, sz * 7.2), (0.4, 0.12, 0.4), "light")
    cable(p, [(-3.0, 3.7, 3.4), (-2.0, 4.6, 2.6), (-1.6, 5.4, 1.6)], r=0.12, kind="steel")

    # the converter column: stacked armored rings and glowing coil bands
    with p.sub("coil", (0.0, 4.25, 0.6), "pulse", (0, 1, 0)):
        for k in range(3):
            y = 4.55 + k * 0.85
            p.cylinder("y", (0, y, 0.6), 1.75 - k * 0.12, 0.55, 22, "paint", bevel=0.04)
            p.cylinder("y", (0, y + 0.42, 0.6), 1.62 - k * 0.12, 0.28, 22, "power")
        p.ocyl((0, 7.05, 0.6), UP, 1.7, 0.5, 22, "trim", radius2=1.2)
        p.cylinder("y", (0, 7.62, 0.6), 0.9, 0.14, 16, "power")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 4.62, 1.0, -2.4), (sx * 4.62, 1.0, 3.6), 7, (sx, 0, 0))
    seam(p, (-3.0, 3.661, 3.0), (3.0, 3.661, 3.0), UP)
    ring(p, (0, 4.251, 0.6), UP, 2.0)


unit.run(__file__, "ord_converter", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 3.0, 0), 50),
                   ("80", (0, 38, 6), (0, 2, 0), 50),
                   ("close", (-11, 10, -14), (0, 3.5, -1.0), 40)])
