"""Advanced Bot Lab (Order bot factory, T2, footprint 5; S-181): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advbotlab/build.py

From its approved blockout (2026-10-26), 40 x 40 studs: the Bot Lab grown
for heavy bots. Big shapes first: a chamfered slab; a taller armored hall
at the back (a sloped front over a big lit door, deep side buttresses,
two team roof plates, a control cab and a turning radar, `radar`); in
front a big lit assembly pad (`buildpad`) under a heavy portal gantry
(pillars on sloped feet with team panels, a double beam with a light
strip tied back to the hall) whose four emitter heads glow (`nano1..4`,
tools/anchors.py). Order reads heavy and clean (M-14). Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, seam  # noqa: E402

PZ = -8.0  # the pad's centre
GY = 17.4  # the gantry beam's underside
EMITTERS = (-9.0, -3.0, 3.0, 9.0)


def build_base(p):
    p.prism_y(octagon(19.6, 2.0), 0.0, 0.6, "trim", bevel=0.16, top_scale=0.99)
    p.prism_y(rect(0, PZ, 9.0, 8.0), 0.6, 0.72, "dark", bevel=0.04)
    p.cylinder("y", (0, 0.75, PZ), 6.4, 0.06, 36, "team")
    p.cylinder("y", (0, 0.79, PZ), 5.6, 0.04, 36, "power")
    p.cylinder("y", (0, 0.8, PZ), 5.2, 0.05, 36, "dark")
    hazard(p, (0, 0.74, PZ - 8.3), (1, 0, 0), UP, 16.0, 0.5, stripes=26)
    # the hall
    p.prism_x([(1.0, 0.6), (18.6, 0.6), (18.6, 12.6), (17.2, 13.6), (2.6, 13.6), (-1.0, 11.6), (-1.0, 0.6)], -17.0, 17.0, "paint", bevel=0.22)
    p.box((0, 5.1, -1.03), (14.0, 9.0, 0.05), "dark")
    p.box((0, 9.9, -1.05), (14.0, 0.35, 0.05), "light")
    for sx in (-1, 1):
        p.box((sx * 7.2, 5.1, -1.06), (0.35, 9.0, 0.05), "power")
        p.box((sx * 8.5, 13.63, 10.0), (11.0, 0.06, 11.0), "team", bevel=0.02)
        p.prism_x([(5.0, 0.6), (14.0, 0.6), (12.8, 8.6), (6.2, 8.6)], *sorted((sx * 17.0, sx * 20.0)), "paint", bevel=0.12)
        louver(p, (sx * 17.02, 5.0, 2.8), (0, 0, 1), (sx, 0, 0), 4.0, 1.2, slats=4)
        p.box((sx * 17.03, 8.0, 15.0), (0.05, 0.16, 5.0), "light")
    p.prism_y(rect(12.0, 14.5, 3.0, 2.5), 13.6, 18.0, "paint", bevel=0.12, top_scale=0.94)
    p.box((12.0, 16.6, 11.98), (5.4, 1.2, 0.05), "glass")
    p.box((12.0, 18.03, 14.5), (4.4, 0.05, 3.4), "team", bevel=0.01)
    p.cylinder("y", (-13.0, 16.6, 15.0), 0.3, 6.0, 8, "steel")
    with p.sub("radar", (-13.0, 19.8, 15.0), "turn", (0, 1, 0)):
        p.box((-13.0, 20.2, 15.0), (4.0, 1.4, 0.3), "trim", bevel=0.04)
        p.box((-13.0, 20.2, 14.83), (3.4, 0.2, 0.04), "light")
    # the heavy portal gantry
    for sx in (-1, 1):
        p.prism_y(rect(sx * 11.5, PZ, 1.3, 1.4), 0.6, GY + 2.6, "paint", bevel=0.12)
        p.prism_x([(PZ - 4.0, 0.6), (PZ + 1.4, 0.6), (PZ + 1.4, 4.6), (PZ - 1.4, 4.6)], sx * 11.5 - 1.4, sx * 11.5 + 1.4, "paint", bevel=0.1)
        p.box((sx * 12.83, 8.0, PZ), (0.06, 5.0, 1.8), "team", bevel=0.01)
        p.box((sx * 12.83, 12.0, PZ), (0.05, 0.16, 2.0), "light")
    p.box((0, GY + 1.2, PZ), (26.0, 2.4, 3.0), "paint", bevel=0.16)
    p.box((0, GY + 1.6, PZ + 3.2), (26.0, 1.6, 1.6), "trim", bevel=0.1)
    p.box((0, GY + 1.2, PZ - 1.53), (20.0, 0.25, 0.05), "light")
    p.box((0, GY + 2.43, PZ), (16.0, 0.06, 2.0), "team", bevel=0.01)
    p.box((0, GY + 1.0, PZ + 6.0), (2.0, 1.6, 6.4), "trim", bevel=0.08)
    for x in EMITTERS:
        p.box((x, GY - 0.4, PZ), (1.2, 0.8, 1.2), "trim", bevel=0.06)
        p.cylinder("y", (x, GY - 0.9, PZ), 0.45, 0.2, 12, "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 18.4, 0.68, sz * 18.4), (0.7, 0.12, 0.7), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 17.02, 1.4, 1.5), (sx * 17.02, 1.4, 18.0), 14, (sx, 0, 0))
        seam(p, (sx * 17.02, 11.0, 1.2), (sx * 17.02, 11.0, 18.4), (sx, 0, 0))
    seam(p, (-12.0, GY + 2.0, PZ - 1.51), (12.0, GY + 2.0, PZ - 1.51), (0, 0, -1))


unit.run(__file__, "ord_advbotlab", "order", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=7000,
         previews=[("35", (-50, 42, -60), (0, 8.0, 0), 50),
                   ("80", (0, 82, 12), (0, 5, 0), 50),
                   ("close", (-22, 22, -32), (0, 9.0, -6.0), 35)])
