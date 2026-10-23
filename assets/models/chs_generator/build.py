"""Generator (Chaos power generator, T1 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_generator/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs),
not rescaled; the bulkiest T1 economy building. Big shapes first: a skid
slab, three upright reactor tanks of different heights with hot bands and
team caps, the big tank's glowing core band (`core`, pulse, rig.md 9), pipe
bridges between them, a tall exhaust stack with a hot rim, an open scaffold
with a catwalk, a generator shed with a team roof, hazard striping and
beacons. Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

BIG = (-2.4, 1.0)  # (x, z) of the big tank


def tank(p, x, z, r, h, y0=0.75):
    p.cylinder("y", (x, y0 + h / 2, z), r, h, 18, "paint", bevel=0.05)
    p.ocyl((x, y0 + h, z), UP, r, 0.5, 18, "trim", radius2=r * 0.7)
    p.cylinder("y", (x, y0 + h + 0.55, z), r * 0.68, 0.05, 16, "team")
    for y in (y0 + 0.3, y0 + h * 0.5):
        p.cylinder("y", (x, y, z), r + 0.05, 0.16, 18, "dark")


def build_base(p):
    p.prism_y(octagon(7.8, 0.8), 0.0, 0.75, "dark", bevel=0.12, top_scale=0.985)
    hazard(p, (0, 0.77, -6.6), (1, 0, 0), (0, 1, 0), 10.0, 0.5, stripes=18)
    # three reactor tanks
    tank(p, BIG[0], BIG[1], 2.6, 6.2)
    tank(p, 3.4, 2.6, 2.0, 4.6)
    tank(p, 3.0, -3.4, 1.5, 3.4)
    for x, z, r, y in ((3.4, 2.6, 2.0, 3.6), (3.0, -3.4, 1.5, 2.8)):
        p.cylinder("y", (x, y, z), r + 0.06, 0.22, 18, "power")
    # pipe bridges between the tanks
    for a, b in (((BIG[0] + 2.4, 5.2, BIG[1]), (3.4 - 1.8, 4.6, 2.6)), ((BIG[0] + 2.2, 3.4, BIG[1] - 1.0), (3.0 - 1.3, 3.0, -3.4))):
        cable(p, [a, b], r=0.24, kind="steel")
    # exhaust stack with a hot rim and a soot band
    p.ocyl((-5.6, 0.75, -4.4), UP, 0.85, 9.0, 14, "trim", radius2=0.65)
    p.cylinder("y", (-5.6, 9.8, -4.4), 0.68, 0.14, 14, "power")
    p.cylinder("y", (-5.6, 8.6, -4.4), 0.74, 0.5, 14, "dark")
    hazard(p, (-5.6, 4.0, -5.27), (0, 1, 0), (0, 0, -1), 1.8, 0.5, stripes=5)
    # open scaffold with a catwalk round the big tank
    for x, z in ((-5.4, -1.2), (-5.4, 3.6), (0.6, 3.6), (0.6, -1.6)):
        p.box((x, 3.4, z), (0.24, 5.3, 0.24), "dark")
    p.box((-2.4, 5.9, 1.0), (6.4, 0.12, 5.6), "grille")
    for z in (-1.4, 3.4):
        p.box((-2.4, 6.6, z), (6.0, 0.08, 0.08), "trim")
    # generator shed at the front right with a team roof and a glowing vent
    p.prism_y(rect(3.6, -6.3, 2.6, 1.1), 0.75, 2.9, "paint", bevel=0.1)
    p.box((3.6, 2.95, -6.3), (4.8, 0.05, 1.8), "team", bevel=0.02)
    p.box((3.6, 1.9, -7.42), (3.6, 0.5, 0.05), "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.85, sz * 7.0), (0.35, 0.2, 0.35), "light")
    p.cylinder("y", (-5.6, 10.0, -4.4), 0.2, 0.3, 8, "light")

    # the big tank's core band: a glowing ring with vents, pulsing
    with p.sub("core", (BIG[0], 4.2, BIG[1]), "pulse", (0, 1, 0)):
        p.cylinder("y", (BIG[0], 4.2, BIG[1]), 2.7, 0.4, 20, "power")
        for k in range(6):
            import math
            a = math.radians(30 + 60 * k)
            p.box((BIG[0] + math.cos(a) * 2.72, 4.2, BIG[1] + math.sin(a) * 2.72), (0.3, 0.8, 0.3), "dark")


def details_base(p):
    rivets(p, (1.4, 2.96, -6.9), (5.8, 2.96, -6.9), 6, UP)
    seam(p, (1.0, 1.4, -7.41), (6.2, 1.4, -7.41), (0, 0, -1))


unit.run(__file__, "chs_generator", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 18, -26), (0, 3.5, 0), 50),
                   ("80", (0, 38, 6), (0, 3, 0), 50),
                   ("close", (-11, 10, -13), (0, 4.0, 0), 35)])
