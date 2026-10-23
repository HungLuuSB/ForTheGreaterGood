"""Tidal Generator (Order, T1 structure, footprint 2, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_tidal/build.py

New mesh in the size-scale style (S-104, M-26: footprint 2, 16 x 16 studs,
about 5 above the water), from its blockout. The waterline is y = 0. Big
shapes first: two armored pontoon hulls with chamfered bows, team plates
and running strips, bridged fore and aft by armored decks with hazard
edges; between them a ducted turbine half out of the water, its rotor
(`rotor`, spin Z, rig.md 9) inside a ribbed duct; an armored
generator housing with a glowing band, a large team roof and a vent with a
glowing rim, on the aft deck with a shaft housing to the duct and a
walkway over it; bollards and corner lights. Order reads heavy and clean
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

HX = 4.9  # hull centre (x mirrored)
HUB = (0.0, -0.3, 0.0)
R = 2.4  # rotor radius


def build_base(p):
    # pontoon hulls with chamfered bows and sterns
    for sx in (-1, 1):
        prof = [(-6.4, -1.4), (6.4, -1.4), (7.6, -0.2), (7.6, 1.0), (-7.6, 1.0), (-7.6, -0.2)]
        p.prism_x(prof, sx * HX - 2.7, sx * HX + 2.7, "paint", bevel=0.14)
        p.box((sx * HX, 1.04, 0), (4.4, 0.06, 7.0), "team", bevel=0.02)
        p.box((sx * (HX + 2.72), 0.5, 0), (0.05, 0.14, 12.0), "light")
        for z in (-6.0, 6.0):
            p.cylinder("y", (sx * (HX + 1.6), 1.3, z), 0.3, 0.6, 10, "steel")
    # fore and aft decks bridging the hulls, hazard edges toward the turbine
    for sz in (-1, 1):
        p.prism_y(rect(0, sz * 5.4, HX - 2.0, 1.9), -0.4, 1.0, "trim", bevel=0.1)
        hazard(p, (0, 1.02, sz * 3.65), (1, 0, 0), UP, 5.0, 0.4, stripes=10)
    # the duct around the rotor: a ribbed ring along Z
    for z in (-1.4, 1.4):  # open end rings
        for k in range(16):
            a = (k + 0.5) * math.pi / 8
            c, s = math.cos(a), math.sin(a)
            p.obox((c * (R + 0.4), HUB[1] + s * (R + 0.4), z), (-s, c, 0), (c, s, 0),
                   2 * math.pi * (R + 0.4) / 16 * 1.06, 0.6, 0.45, "trim")
    for k in range(8):
        a = k * math.pi / 4
        c, s = math.cos(a), math.sin(a)
        p.obox((c * (R + 0.3), HUB[1] + s * (R + 0.3), 0), (0, 0, 1), (c, s, 0), 2.8, 0.5, 0.3, "steel")
    # generator housing on the aft deck: armored, glowing band, team roof, vent
    p.prism_y(rect(0, 5.5, 2.4, 1.6), 1.0, 3.6, "paint", bevel=0.14, top_scale=0.85)
    p.box((0, 3.64, 5.5), (3.4, 0.06, 2.2), "team", bevel=0.02)
    p.box((0, 2.3, 3.89), (4.2, 0.3, 0.05), "power")
    p.ocyl((1.2, 3.6, 6.0), UP, 0.5, 0.8, 12, "trim", radius2=0.4)
    p.cylinder("y", (1.2, 4.44, 6.0), 0.41, 0.08, 12, "power")
    # drive shaft housing from the duct to the generator, a walkway over the duct
    p.box((0, 2.5, 2.4), (0.9, 0.8, 3.0), "trim", bevel=0.05)
    p.box((0, 2.75, 0.0), (2 * HX - 4.6, 0.25, 1.1), "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * (HX + 2.0), 1.12, sz * 7.0), (0.4, 0.16, 0.4), "light")

    # the turbine rotor: hub and five blades, half out of the water
    with p.sub("rotor", HUB, "spin", (0, 0, 1)):
        p.cylinder("z", HUB, 0.6, 1.6, 14, "trim")
        p.ocyl((0, HUB[1], -0.8), (0, 0, -1), 0.6, 0.5, 14, "steel", radius2=0.2)
        for k in range(5):
            a = k * 2 * math.pi / 5
            c, s = math.cos(a), math.sin(a)
            p.obox((c * 1.45, HUB[1] + s * 1.45, 0), (c, s, 0), (0.0, 0.0, 1.0), 1.9, 0.9, 0.16, "paint", bevel=0.02)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * (HX + 2.72), 0.2, -5.5), (sx * (HX + 2.72), 0.2, 5.5), 10, (sx, 0, 0))
        seam(p, (sx * HX - 2.2, 1.001, -4.2), (sx * HX + 2.2, 1.001, -4.2), UP)
    ring(p, (0, 4.241, 0), UP, 1.0)


unit.run(__file__, "ord_tidal", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 1.5, 0), 50),
                   ("80", (0, 38, 6), (0, 1, 0), 50),
                   ("close", (-11, 9, -13), (0, 1.5, -1.0), 40)])
