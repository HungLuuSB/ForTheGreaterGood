"""Tide Mill (Chaos tidal generator, T1 structure, footprint 2, on water):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_tidal/build.py

New mesh in the size-scale style (S-104, M-26: footprint 2, 16 x 16 studs,
about 5 above the water), from its blockout. The waterline is y = 0. Big
shapes first: two strapped salvage drum floats, a deck of patched plates on
cross beams with team plates and hazard striping, an exposed paddle wheel
between the floats (`rotor`, spin X, rig.md 9), its axle on bearing blocks,
a generator shed on the aft deck with a team roof, a hot band and a stack,
loose cables, amber beacons. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

FX = 4.8  # float centre (x mirrored)
HUB = (0.0, 0.5, -1.0)
R = 2.6  # wheel radius


def build_base(p):
    # salvage drum floats with straps
    for sx in (-1, 1):
        drum(p, (sx * FX, 0.1, 0), 1.7, 14.6, "paint", "trim", sides=16, axis="z")
        for z in (-5.0, -1.0, 3.0, 6.0):
            p.cylinder("z", (sx * FX, 0.1, z), 1.74, 0.22, 16, "dark")
    # deck of patched plates on cross beams (open over the wheel)
    for z in (-6.2, 4.2):
        p.box((0, 1.65, z), (12.6, 0.3, 0.6), "steel")
    for sx in (-1, 1):
        p.box((sx * FX, 1.95, 0), (3.6, 0.3, 14.0), "trim", bevel=0.04)
        p.box((sx * FX, 2.12, -4.0), (3.0, 0.05, 4.0), "team", bevel=0.012)
        hazard(p, (sx * (FX - 1.6), 2.12, -1.0), (0, 0, 1), UP, 6.0, 0.35, stripes=10)
        p.box((sx * (FX + 1.78), 1.9, 2.0), (0.05, 0.14, 8.0), "light")
    p.prism_y(rect(0, 4.8, 3.4, 2.2), 1.5, 2.1, "trim", bevel=0.05)  # aft deck between the floats
    p.box((1.6, 2.13, 6.2), (2.0, 0.04, 1.4), "steel", bevel=0.01)  # welded patch
    # axle bearing blocks on the floats' inner sides
    for sx in (-1, 1):
        p.box((sx * 3.0, 1.4, HUB[2]), (0.9, 1.4, 1.2), "trim", bevel=0.05)
    # generator shed on the aft deck: team roof, hot band, stack
    p.prism_y(rect(0, 4.8, 2.4, 1.8), 2.1, 4.4, "paint", bevel=0.1)
    p.obox((0, 4.48, 4.8), (1, 0, 0), (0, 1, 0.06), 5.0, 3.8, 0.06, "team", bevel=0.015)
    p.box((0, 3.0, 2.98), (3.6, 0.3, 0.05), "power")
    p.ocyl((-1.6, 4.4, 6.0), UP, 0.35, 1.6, 10, "steel")
    p.cylinder("y", (-1.6, 6.04, 6.0), 0.3, 0.08, 10, "power")
    cable(p, [(1.8, 3.0, 3.2), (2.8, 2.4, 1.0), (3.0, 1.9, HUB[2] + 0.5)], r=0.12, kind="dark")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * (FX + 1.4), 2.3, sz * 6.6), (0.35, 0.3, 0.35), "light")

    # the paddle wheel: axle, two rims, eight paddles
    with p.sub("rotor", HUB, "spin", (1, 0, 0)):
        p.cylinder("x", HUB, 0.3, 6.0, 10, "steel")
        for x in (-1.9, 1.9):
            p.cylinder("x", (x, HUB[1], HUB[2]), R, 0.2, 20, "trim")
            p.cylinder("x", (x, HUB[1], HUB[2]), 0.7, 0.4, 12, "dark")
        for k in range(8):
            a = k * math.pi / 4
            c, s = math.cos(a), math.sin(a)
            p.obox((0, HUB[1] + s * (R - 0.7), HUB[2] + c * (R - 0.7)), (1, 0, 0), (0, s, c), 4.0, 0.12, 1.5, "paint")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * FX - 1.4, 2.101, 1.5), (sx * FX - 1.4, 2.101, 6.5), 6, UP)
    ring(p, (-1.6, 6.0, 6.0), UP, 0.25, segments=8)


unit.run(__file__, "chs_tidal", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 1.5, 0), 50),
                   ("80", (0, 38, 6), (0, 1, 0), 50),
                   ("close", (-11, 9, -13), (0, 1.5, -1.0), 40)])
