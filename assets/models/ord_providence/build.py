"""Providence (Order anti-nuke, T2 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_providence/build.py

New mesh from its blockout, at the T2 defense size (S-104: footprint 3,
24 x 24 studs, about 11 tall with the radar). Big shapes first: a chamfered
slab, an armored launch bunker with sloped upper walls and large team
plates, a raised silo collar with hazard striping and a row of readiness
lights (weapon: a loaded interceptor reads at a glance), the heavy armored
`hatch` (the def's piece, hinged at its back edge) with a team plate and
ribs, blast vents, a reload door at the back, and a tracking radar on a
short tower (client-turned `radar`, M-27) with a glowing edge. `muzzle` at
the silo mouth, launching straight up. Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

HATCH_PIVOT = (0.0, 4.35, 2.7)
SILO = (0.0, -1.0)
RADAR = (7.0, 7.4, 7.0)


def build_base(p):
    p.prism_y(octagon(11.6, 1.4), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.99)
    # armored launch bunker: walls, sloped upper walls, team plates
    p.prism_y(octagon(10.0, 2.2), 0.6, 2.3, "paint", bevel=0.18)
    p.prism_y(octagon(10.0, 2.2), 2.3, 3.4, "paint", bevel=0.18, top_scale=0.84)
    for sx in (-1, 1):
        p.obox((sx * 9.1, 2.85, -0.5), (0, 0, 1), (sx * 1.1, 1.6, 0), 6.0, 1.2, 0.06, "team", bevel=0.02)
        p.box((sx * 10.02, 1.4, 0), (0.05, 0.16, 8.0), "light")
    p.box((0, 1.4, -10.02), (8.0, 0.16, 0.05), "light")
    # silo collar, the pit, hazard ring, readiness lights
    p.prism_y(rect(*SILO, 4.6, 4.3), 3.4, 4.0, "trim", bevel=0.1)
    p.box((SILO[0], 4.02, SILO[1]), (6.8, 0.05, 6.4), "dark")
    for sz in (-1, 1):
        hazard(p, (SILO[0], 4.03, SILO[1] + sz * 3.85), (1, 0, 0), UP, 8.6, 0.5, stripes=16)
    for k in range(5):
        p.box((-3.2 + k * 1.6, 3.7, SILO[1] - 4.32), (1.0, 0.3, 0.06), "weapon")
    # blast vents either side of the silo, a reload door at the back
    for sx in (-1, 1):
        p.box((sx * 6.0, 3.45, -1.0), (1.4, 0.3, 5.0), "grille")
        p.box((sx * 6.0, 3.62, -1.0), (1.6, 0.06, 5.2), "trim")
    p.box((0, 1.6, 10.02), (4.0, 2.0, 0.06), "dark")
    p.box((0, 2.75, 10.04), (4.4, 0.16, 0.05), "light")
    # radar tower (back right)
    p.prism_y(rect(RADAR[0], RADAR[2], 1.4, 1.4), 3.0, 6.9, "paint", bevel=0.1, top_scale=0.8)
    p.box((RADAR[0] - 1.17, 5.2, RADAR[2]), (0.05, 1.6, 1.4), "team", bevel=0.01)
    p.cylinder("y", (RADAR[0], 7.1, RADAR[2]), 0.6, 0.4, 14, "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 0.66, sz * 11.0), (0.5, 0.12, 0.5), "light")

    t = math.radians(20)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (RADAR[0], 8.6, RADAR[2])
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (RADAR[0], 7.5, RADAR[2]), 0.45, 0.3, 12, "trim")
        p.obox(c, (1, 0, 0), n, 4.2, 2.6, 0.32, "paint", bevel=0.04)
        p.obox(tuple(c[k] + n[k] * 0.17 for k in range(3)), (1, 0, 0), n, 3.8, 2.2, 0.03, "dark")
        for b in (-1.08, 1.08):
            p.obox(tuple(c[k] + n[k] * 0.19 + v[k] * b for k in range(3)), (1, 0, 0), n, 3.8, 0.08, 0.02, "light")
        for a in (-1.88, 1.88):
            p.obox((c[0] + a, c[1] + n[1] * 0.19, c[2] + n[2] * 0.19), (1, 0, 0), n, 0.08, 2.2, 0.02, "light")
        p.obox(tuple(c[k] - n[k] * 0.18 for k in range(3)), (1, 0, 0), n, 3.4, 1.8, 0.03, "team")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 10.02, 1.0, -6.0), (sx * 10.02, 1.0, 6.0), 12, (sx, 0, 0))
    seam(p, (-7.0, 3.401, 6.0), (7.0, 3.401, 6.0), UP)


def build_hatch(p):
    p.box((SILO[0], 4.35, SILO[1]), (7.0, 0.8, 7.4), "paint", bevel=0.1)
    p.box((SILO[0], 4.78, SILO[1] - 0.2), (4.0, 0.05, 4.0), "team", bevel=0.015)
    for z in (-4.2, 2.2):
        p.box((SILO[0], 4.85, z), (7.2, 0.3, 0.6), "trim", bevel=0.04)
    for sx in (-1, 1):
        p.cylinder("x", (sx * 2.6, 4.35, 2.7), 0.45, 1.2, 12, "steel")  # hinge knuckles
    p.box((SILO[0], 4.78, -4.62), (6.0, 0.05, 0.12), "light")


def details_hatch(p):
    ring(p, (SILO[0], 4.751, SILO[1] - 0.2), UP, 1.4)


unit.run(__file__, "ord_providence", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("hatch", "base", HATCH_PIVOT, build_hatch, details_hatch)],
         attachments={"muzzle": {"parent": "base", "at": [SILO[0], 3.2, SILO[1]]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.0, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 4.0, -1.0), 40)])
