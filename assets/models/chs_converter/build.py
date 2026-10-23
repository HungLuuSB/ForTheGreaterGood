"""Smelter (Chaos converter, T1 structure, footprint 2): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_converter/build.py

New mesh in the size-scale style (S-104, M-26: footprint 2, 16 x 16 studs,
about 8 tall with its stack), from its blockout. Big shapes first: a
patched skid slab with team plates and hazard striping, a squat riveted
furnace with a glowing mouth and a team roof, a strapped crucible tank with
a hot band (`crucible`, pulse, rig.md 9), a tall chimney with a hot rim,
an ore skip on an inclined rail feeding the furnace, exposed pipework with
valves, slag ingots and beacons. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402


def build_base(p):
    p.prism_y(octagon(7.8, 0.7), 0.0, 0.6, "dark", bevel=0.1, top_scale=0.985)
    for sx in (-1, 1):
        p.box((sx * 4.6, 0.63, -5.6), (3.6, 0.05, 2.2), "team", bevel=0.012)
    hazard(p, (0, 0.63, -7.1), (1, 0, 0), UP, 5.0, 0.4, stripes=10)
    p.box((5.4, 0.63, 4.2), (3.0, 0.04, 3.0), "trim", bevel=0.01)  # welded patch
    # squat furnace: riveted walls, team roof, glowing mouth
    p.prism_y(rect(-2.4, 0.4, 3.0, 3.2), 0.6, 4.2, "paint", bevel=0.12, top_scale=0.9)
    p.box((-2.4, 4.24, 0.4), (5.0, 0.05, 5.4), "team", bevel=0.015)
    p.box((-2.4, 2.0, -2.82), (2.6, 1.6, 0.06), "dark")
    p.box((-2.4, 1.9, -2.86), (2.2, 1.1, 0.04), "power")  # the mouth
    p.box((-2.4, 3.0, -2.86), (2.8, 0.2, 0.05), "trim")
    for x in (-5.4, 0.6):
        p.box((x, 2.4, -2.8), (0.3, 3.6, 0.3), "trim")  # corner straps
    # chimney with a hot rim, a pipe from the furnace
    p.ocyl((-4.4, 4.2, 2.6), UP, 0.85, 4.4, 12, "steel", radius2=0.7)
    p.cylinder("y", (-4.4, 8.62, 2.6), 0.72, 0.12, 12, "power")
    for y in (5.4, 7.0):
        p.cylinder("y", (-4.4, y, 2.6), 0.85, 0.16, 12, "dark")
    # ore skip on an inclined rail feeding the furnace from the right
    p.obox((3.6, 2.6, -1.6), (-1.0, 0.75, 0), (0, 0, 1), 5.4, 0.3, 0.3, "steel")
    p.obox((3.6, 2.6, -0.4), (-1.0, 0.75, 0), (0, 0, 1), 5.4, 0.3, 0.3, "steel")
    p.box((5.6, 1.4, -1.0), (1.6, 1.2, 1.6), "trim", bevel=0.05)  # skip at the bottom
    p.box((5.6, 2.02, -1.0), (1.2, 0.05, 1.2), "grille")
    # exposed pipework with valves to the crucible
    cable(p, [(0.6, 3.0, 1.6), (1.6, 3.6, 2.0), (2.6, 3.2, 2.6)], r=0.22, kind="steel")
    p.cylinder("x", (1.4, 3.55, 1.95), 0.32, 0.18, 10, "dark")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.7, sz * 7.0), (0.35, 0.2, 0.35), "light")
    for x, z in ((1.8, -5.0), (2.6, -4.6), (2.2, -5.6)):  # slag ingots
        p.box((x, 0.82, z), (0.8, 0.4, 0.5), "dark", bevel=0.04)

    # the crucible: a strapped tank with a hot band and a team cap
    with p.sub("crucible", (4.0, 0.6, 3.4), "pulse", (0, 1, 0)):
        p.cylinder("y", (4.0, 2.6, 3.4), 2.0, 4.0, 18, "paint", bevel=0.06)
        p.ocyl((4.0, 4.6, 3.4), UP, 2.0, 0.5, 18, "trim", radius2=1.4)
        p.cylinder("y", (4.0, 5.15, 3.4), 1.3, 0.06, 16, "team")
        p.cylinder("y", (4.0, 2.9, 3.4), 2.04, 0.5, 18, "power")
        for y in (1.4, 4.0):
            p.cylinder("y", (4.0, y, 3.4), 2.05, 0.18, 18, "dark")


def details_base(p):
    rivets(p, (-5.4, 1.4, -2.83), (0.6, 1.4, -2.83), 8, (0, 0, -1))
    rivets(p, (-5.42, 1.4, -2.4), (-5.42, 1.4, 3.2), 7, (-1, 0, 0))
    ring(p, (4.0, 5.11, 3.4), UP, 0.9)


unit.run(__file__, "chs_converter", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 3.0, 0), 50),
                   ("80", (0, 38, 6), (0, 2, 0), 50),
                   ("close", (-11, 10, -14), (0, 3.5, -1.0), 40)])
