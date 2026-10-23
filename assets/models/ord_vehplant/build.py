"""Vehicle Plant (Order factory, T1, footprint 4): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_vehplant/build.py

Redesigned at the size scale (S-104, M-26: footprint 3 -> 4, 32 x 32 studs,
about 11 tall: the tallest T1 buildings), not rescaled. Big shapes first:
- a chamfered slab;
- an open assembly bay down the middle with the build pad (team ring,
  hazard border, `buildpad` at its centre facing the exit at -Z), a front
  exit ramp under a lit door frame;
- two armored side halls with sloped roofs and large team roof plates;
- a back assembly hall feeding the bay through a parts conveyor, with
  vents and an exhaust stack;
- a bridge gantry crane over the bay that slides along Z (`gantry`, slide,
  rig.md 9) with a hook block;
- four emitter arms on the bay walls with glowing heads (`nano1..4`).
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

BAY_X = 5.2  # half width of the bay
PAD = (0.0, -3.0)  # (x, z) of the build pad centre
ARMS = [(-1, -6.0), (-1, 0.0), (1, -6.0), (1, 0.0)]  # emitter arms: (side, z)


def arm_tip(sx, z):
    return (sx * (BAY_X - 1.9), 6.4, z)


def build_base(p):
    p.prism_y(octagon(15.6, 1.6), 0.0, 0.6, "trim", bevel=0.16, top_scale=0.99)
    # build pad: a dark plate, team ring border, hazard edges
    p.prism_y(octagon(4.2, 1.0, *PAD), 0.6, 0.72, "dark", bevel=0.04)
    p.prism_y(octagon(4.6, 1.1, *PAD), 0.6, 0.66, "team", bevel=0.02)
    for sz in (-1, 1):
        hazard(p, (0, 0.74, PAD[1] + sz * 4.75), (1, 0, 0), (0, 1, 0), 9.0, 0.35, stripes=16)
    # exit ramp at the front and a lit door frame
    p.prism_x([(-15.4, 0.6), (-9.4, 0.6), (-9.4, 0.85)], -BAY_X + 0.2, BAY_X - 0.2, "steel", bevel=0.03)
    for sx in (-1, 1):
        p.prism_y(rect(sx * (BAY_X + 0.5), -9.6, 0.6, 0.6), 0.6, 10.0, "paint", bevel=0.1)
        p.box((sx * (BAY_X - 0.12), 5.0, -9.6), (0.05, 8.0, 0.4), "light")
    p.prism_x([(-10.2, 9.6), (-9.0, 9.6), (-9.0, 11.0), (-10.4, 10.6)], -BAY_X - 1.1, BAY_X + 1.1, "paint", bevel=0.1)
    p.box((0, 9.75, -10.25), (BAY_X * 2, 0.2, 0.05), "power")
    # side halls: armored walls, sloped roofs, team roof plates, vents, lights
    for sx in (-1, 1):
        x0, x1 = sorted((sx * BAY_X, sx * 14.2))
        p.prism_x([(-9.2, 0.6), (8.6, 0.6), (8.6, 8.4), (6.8, 10.2), (-7.4, 10.2), (-9.2, 8.4)], x0, x1, "paint", bevel=0.2)
        cx = sx * 9.7
        p.box((cx, 10.24, -0.3), (7.0, 0.06, 13.0), "team", bevel=0.02)
        p.box((sx * 14.22, 4.5, -0.3), (0.05, 0.6, 14.0), "power")
        p.box((sx * 14.22, 6.0, -0.3), (0.05, 0.15, 16.0), "light")
        p.box((sx * 14.22, 2.4, -6.0), (0.05, 2.6, 3.0), "dark")  # side door
        # buttresses
        for z in (-6.0, 1.0, 7.0):
            p.prism_x([(z - 0.9, 0.6), (z + 0.9, 0.6), (z + 0.6, 5.8), (z - 0.6, 5.8)], *sorted((sx * 14.2, sx * 15.3)), "paint", bevel=0.08)
    # back hall closing the bay, with a big intake, vents and a stack
    p.prism_x([(8.6, 0.6), (15.4, 0.6), (15.4, 9.0), (13.6, 11.2), (8.6, 11.2)], -BAY_X - 0.2, BAY_X + 0.2, "paint", bevel=0.2)
    p.box((0, 11.24, 12.0), (8.0, 0.06, 4.6), "team", bevel=0.02)
    p.box((0, 4.0, 8.58), (6.0, 6.0, 0.05), "dark")  # the opening into the bay
    p.box((0, 7.2, 8.56), (6.4, 0.18, 0.05), "power")
    for sx in (-1, 1):
        p.ocyl((sx * 3.0, 11.2, 13.6), UP, 0.8, 2.6, 14, "trim", radius2=0.65)
        p.cylinder("y", (sx * 3.0, 13.85, 13.6), 0.66, 0.1, 14, "power")
    p.box((0, 5.0, 15.42), (8.0, 4.0, 0.05), "grille")
    # parts conveyor from the back hall to the pad
    p.box((0, 1.0, 5.2), (2.4, 0.8, 7.0), "trim", bevel=0.06)
    p.box((0, 1.42, 5.2), (2.0, 0.04, 6.8), "grille")
    for z in (2.4, 5.2, 8.0):
        p.box((0, 1.0, z), (2.6, 0.12, 0.12), "light")
    # emitter arms on the bay walls: a mount, a jointed arm, a glowing head
    for sx, z in ARMS:
        wx = sx * BAY_X
        p.box((wx - sx * 0.3, 6.4, z), (0.6, 1.4, 1.2), "trim", bevel=0.06)
        tip = arm_tip(sx, z)
        p.obox(((wx + tip[0]) / 2, 6.6, z), (sx, 0.2, 0), (0, 0, 1), 1.9, 0.5, 0.5, "paint", bevel=0.05)
        p.cylinder("x", (tip[0], tip[1], z), 0.42, 0.5, 14, "dark")
        p.cylinder("x", (tip[0] - sx * 0.27, tip[1], z), 0.32, 0.06, 14, "power")
    # gantry rails on the hall tops
    for sx in (-1, 1):
        p.box((sx * (BAY_X + 0.4), 10.35, -0.5), (0.5, 0.3, 18.0), "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 14.6, 0.68, sz * 14.6), (0.6, 0.12, 0.6), "light")

    # bridge gantry crane: slides along Z over the bay, a hook block under it
    with p.sub("gantry", (0.0, 10.9, -1.0), "slide", (0, 0, 1), 7.0):
        p.box((0, 10.9, -1.0), (BAY_X * 2 + 1.6, 0.7, 1.2), "trim", bevel=0.08)
        p.box((0, 11.27, -1.0), (BAY_X * 2, 0.05, 0.7), "team")
        for sx in (-1, 1):
            p.box((sx * (BAY_X + 0.4), 10.6, -1.0), (0.8, 0.5, 1.8), "paint", bevel=0.05)
        p.box((0, 10.1, -1.0), (1.4, 0.9, 1.4), "paint", bevel=0.06)
        p.cylinder("y", (0, 8.9, -1.0), 0.05, 1.6, 6, "steel")
        p.box((0, 7.9, -1.0), (0.7, 0.4, 0.7), "trim", bevel=0.04)
        hazard(p, (0, 10.9, -1.62), (1, 0, 0), (0, 0, -1), 8.0, 0.4, stripes=14)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 14.22, 1.4, -8.0), (sx * 14.22, 1.4, 7.0), 12, (sx, 0, 0))
        seam(p, (sx * 14.22, 8.4, -8.6), (sx * 14.22, 8.4, 8.0), (sx, 0, 0))
    rivets(p, (-4.0, 1.4, 15.42), (4.0, 1.4, 15.42), 8, (0, 0, 1))


unit.run(__file__, "ord_vehplant", "order", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-40, 32, -48), (0, 4.5, 0), 50),
                   ("80", (0, 66, 10), (0, 3, 0), 50),
                   ("close", (-18, 16, -24), (0, 5.0, -2.0), 35)])
