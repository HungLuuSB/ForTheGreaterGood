"""Bot Lab (Order bot factory, T1, footprint 4; S-181): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_botlab/build.py

From its approved blockout (2026-10-26), 32 x 32 studs. Big shapes first:
a chamfered slab; an armored assembly hall at the back (a sloped front
over a lit door, side buttresses, two team roof plates, a control cab
with a glazed front and a mast); in front a lit assembly pad (a team
ring, a glowing inner ring, hazard edges; `buildpad` at its centre facing
the exit at -Z) under a tall portal gantry (armored pillars with team
panels, a beam with a light strip tied back to the hall) whose three
emitter heads glow (`nano1..3`, tools/anchors.py). Order reads heavy and
clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, seam  # noqa: E402

PZ = -6.5  # the pad's centre
GY = 13.6  # the gantry beam's underside


def build_base(p):
    p.prism_y(octagon(15.6, 1.6), 0.0, 0.6, "trim", bevel=0.16, top_scale=0.99)
    # the pad: a dark plate, a team ring, a glowing inner ring, hazard edges
    p.prism_y(rect(0, PZ, 6.5, 6.0), 0.6, 0.72, "dark", bevel=0.04)
    p.cylinder("y", (0, 0.75, PZ), 4.6, 0.06, 32, "team")
    p.cylinder("y", (0, 0.79, PZ), 4.0, 0.04, 32, "power")
    p.cylinder("y", (0, 0.8, PZ), 3.7, 0.05, 32, "dark")
    hazard(p, (0, 0.74, PZ - 6.2), (1, 0, 0), UP, 12.0, 0.45, stripes=20)
    # the hall: walls, a sloped front over the lit door, a roof with team plates
    p.prism_x([(0.5, 0.6), (14.5, 0.6), (14.5, 9.6), (13.4, 10.2), (1.6, 10.2), (-0.4, 8.6), (-0.4, 0.6)], -13.0, 13.0, "paint", bevel=0.2)
    p.box((0, 3.85, -0.43), (10.0, 6.5, 0.05), "dark")
    p.box((0, 7.3, -0.45), (10.0, 0.3, 0.05), "light")
    for sx in (-1, 1):
        p.box((sx * 5.2, 3.85, -0.46), (0.3, 6.5, 0.05), "power")
        p.box((sx * 6.5, 10.23, 8.0), (9.0, 0.06, 9.0), "team", bevel=0.02)
        p.prism_x([(4.5, 0.6), (10.5, 0.6), (9.6, 6.6), (5.4, 6.6)], *sorted((sx * 13.0, sx * 15.2)), "paint", bevel=0.1)
        louver(p, (sx * 13.02, 4.0, 2.4), (0, 0, 1), (sx, 0, 0), 3.0, 1.0, slats=3)
        p.box((sx * 13.03, 6.0, 12.0), (0.05, 0.14, 4.0), "light")
    # the control cab with a glazed front, a mast with a beacon
    p.prism_y(rect(9.5, 11.0, 2.5, 2.2), 10.2, 13.8, "paint", bevel=0.12, top_scale=0.94)
    p.box((9.5, 12.6, 8.78), (4.2, 1.0, 0.05), "glass")
    p.box((9.5, 13.83, 11.0), (3.4, 0.05, 2.8), "team", bevel=0.01)
    p.cylinder("y", (11.2, 15.6, 12.0), 0.12, 3.6, 6, "steel")
    p.box((11.2, 17.5, 12.0), (0.4, 0.3, 0.4), "light")
    # the portal gantry: pillars with team panels, a beam, a tie to the hall, emitter heads
    for sx in (-1, 1):
        p.prism_y(rect(sx * 8.5, PZ, 1.0, 1.1), 0.6, GY + 2.0, "paint", bevel=0.12)
        p.prism_y(rect(sx * 8.5, PZ, 1.5, 1.6), 0.6, 2.2, "trim", bevel=0.1, top_scale=0.8)
        p.box((sx * 9.53, 6.0, PZ), (0.06, 4.0, 1.4), "team", bevel=0.01)
        p.box((sx * 9.53, 9.0, PZ), (0.05, 0.14, 1.6), "light")
    p.box((0, GY + 1.0, PZ), (19.0, 2.0, 2.6), "paint", bevel=0.14)
    p.box((0, GY + 1.0, PZ - 1.33), (15.0, 0.2, 0.05), "light")
    p.box((0, GY + 2.03, PZ), (12.0, 0.06, 1.6), "team", bevel=0.01)
    p.box((0, GY + 0.8, PZ + 4.3), (1.6, 1.4, 6.6), "trim", bevel=0.08)
    for x in (-4.5, 0.0, 4.5):
        p.box((x, GY - 0.3, PZ), (1.0, 0.6, 1.0), "trim", bevel=0.06)
        p.cylinder("y", (x, GY - 0.7, PZ), 0.38, 0.2, 12, "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 14.6, 0.68, sz * 14.6), (0.6, 0.12, 0.6), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 13.02, 1.4, 1.0), (sx * 13.02, 1.4, 14.0), 12, (sx, 0, 0))
        seam(p, (sx * 13.02, 8.4, 0.8), (sx * 13.02, 8.4, 14.2), (sx, 0, 0))
    seam(p, (-9.0, GY + 1.6, PZ - 1.31), (9.0, GY + 1.6, PZ - 1.31), (0, 0, -1))


unit.run(__file__, "ord_botlab", "order", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-40, 34, -48), (0, 6.0, 0), 50),
                   ("80", (0, 66, 10), (0, 4, 0), 50),
                   ("close", (-18, 18, -26), (0, 7.0, -4.0), 35)])
