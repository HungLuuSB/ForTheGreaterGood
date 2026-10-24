"""Advanced Vehicle Plant (Order factory, T2, footprint 6): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advvehplant/build.py

Designed at the size scale (S-104, M-26: footprint 6, 48 x 48 studs; the
assembly hall about 15.5 tall, over the T1 plant's 11), bigger and busier
than the T1 Vehicle Plant rather than a rescale. Big shapes first:
- a chamfered slab;
- a deep assembly bay down the middle with the build pad (team ring, hazard
  border, `buildpad` at its centre facing the exit at -Z), a long exit ramp
  under a heavy portal: armored lintel, lit door jambs and ticks;
- two-tier armored wings either side: a tall inner hall with a sloped
  front glacis and a large team roof plate, a lower outer hall with its own
  team plate, side doors, buttresses, louvres and running strips;
- a tall assembly hall closing the bay at the back (the tallest block, team
  roof, a lit opening into the bay, a parts conveyor to the pad);
- a power annex behind the wings: two reactor cells with glowing rims on
  the left, a cooling block with exhaust stacks on the right;
- a bridge gantry crane over the bay on rails along the wing tops that
  slides along Z (`gantry`, slide, rig.md 9) with a hoist and a build lamp
  (`nano7`, rides with it);
- six emitter arms on the bay walls with glowing heads (`nano1..6`);
- a sensor mast on the right wing with the client-turned `radar` array
  (unlit face, glowing edge, M-27).
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

BAY_X = 7.5  # half width of the bay
PAD = (0.0, -4.0)  # (x, z) of the build pad centre
IN_X, OUT_X = 14.5, 22.4  # inner / outer hall outer faces (x mirrored)
IN_TOP, OUT_TOP, HALL_TOP = 13.6, 8.6, 15.4
ARMS = [(sx, z) for sx in (-1, 1) for z in (-9.0, -4.0, 1.0)]  # emitter arms: (side, z)
GZ = -6.0  # gantry rest z
MAST = (11.2, 10.6)  # sensor mast on the right inner hall


def arm_tip(sx, z):
    return (sx * (BAY_X - 2.3), 7.4, z)


def build_base(p):
    p.prism_y(octagon(23.6, 2.0), 0.0, 0.7, "trim", bevel=0.18, top_scale=0.992)
    # bay floor and the build pad: dark plate, team ring, hazard bars, lights
    p.box((0, 0.74, 0.0), (BAY_X * 2, 0.08, 15.0), "steel", bevel=0.02)
    p.prism_y(octagon(6.4, 1.6, *PAD), 0.7, 0.82, "team", bevel=0.02)
    p.prism_y(octagon(5.9, 1.4, *PAD), 0.7, 0.9, "dark", bevel=0.04)
    for sz in (-1, 1):
        hazard(p, (0, 0.84, PAD[1] + sz * 6.75), (1, 0, 0), UP, 13.4, 0.5, stripes=20)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((PAD[0] + sx * 6.1, 0.95, PAD[1] + sz * 6.1), (0.45, 0.14, 0.45), "light")
    # exit ramp down to the front edge, hazard edges and guide lights on it
    p.prism_x([(-23.4, 0.7), (-15.6, 0.7), (-15.6, 1.0)], -BAY_X + 0.2, BAY_X - 0.2, "steel", bevel=0.03)
    for sx in (-1, 1):
        hazard(p, (sx * (BAY_X - 0.9), 0.88, -19.5), (0, 0.3, 7.8), (0, 7.8, -0.3), 7.4, 0.7, stripes=10)
        for z in (-22.4, -20.0, -17.6):
            p.box((sx * (BAY_X - 0.1), 0.95 + (z + 23.4) * 0.3 / 7.8, z), (0.3, 0.2, 0.5), "light")
    # portal: armored lintel across the bay, lit jambs, ticks and lintel strip
    p.prism_x([(-16.6, 11.0), (-14.0, 11.0), (-14.0, IN_TOP + 0.6), (-16.0, IN_TOP + 0.6), (-16.6, 13.0)],
              -BAY_X - 0.4, BAY_X + 0.4, "paint", bevel=0.14)
    p.box((0, 10.9, -16.0), (BAY_X * 2 - 0.4, 0.24, 0.1), "power")
    p.box((0, IN_TOP + 0.66, -15.0), (BAY_X * 2 - 2.0, 0.06, 1.6), "team", bevel=0.015)
    for sx in (-1, 1):
        p.box((sx * (BAY_X - 0.06), 5.6, -15.0), (0.06, 9.4, 0.36), "power")
        for y in (2.4, 4.8, 7.2, 9.6):
            p.box((sx * (BAY_X - 0.1), y, -14.4), (0.12, 0.14, 0.7), "power")
    # wings: tall inner halls (front glacis), lower outer halls, team roofs
    inner = [(-16.0, 0.7), (14.0, 0.7), (14.0, 11.8), (12.2, IN_TOP), (-12.6, IN_TOP), (-14.4, 11.8), (-14.4, 6.0)]
    outer = [(-13.0, 0.7), (13.0, 0.7), (13.0, 7.0), (11.4, OUT_TOP), (-10.4, OUT_TOP), (-13.0, 6.2)]
    for sx in (-1, 1):
        x0, x1 = sorted((sx * BAY_X, sx * IN_X))
        p.prism_x(inner, x0, x1, "paint", bevel=0.22)
        x0, x1 = sorted((sx * IN_X, sx * OUT_X))
        p.prism_x(outer, x0, x1, "paint", bevel=0.2)
        p.box((sx * 11.0, IN_TOP + 0.04, -2.2), (5.4, 0.06, 19.0), "team", bevel=0.02)
        p.box((sx * 18.4, OUT_TOP + 0.04, 0.4), (6.2, 0.06, 18.6), "team", bevel=0.02)
        # the step between the tiers: a lit strip and a vent row
        p.box((sx * (IN_X + 0.03), 11.2, 0.0), (0.06, 0.16, 24.0), "light")
        for z in (-6.0, -1.0, 4.0, 9.0):
            p.box((sx * (IN_X + 0.03), 10.0, z), (0.06, 1.4, 3.0), "grille")
        # outer wall: running strips, a power band, a side door, louvres
        p.box((sx * (OUT_X + 0.03), 6.2, 0.0), (0.06, 0.16, 24.0), "light")
        p.box((sx * (OUT_X + 0.03), 4.2, 5.5), (0.06, 0.5, 9.0), "power")
        p.box((sx * (OUT_X + 0.03), 2.6, -6.5), (0.06, 3.6, 4.4), "dark")
        hazard(p, (sx * (OUT_X + 0.06), 0.95, -6.5), (0, 0, 1), (sx, 0, 0), 4.6, 0.4, stripes=7)
        for z in (-11.0, -1.0, 9.0):  # buttresses
            p.prism_x([(z - 1.0, 0.7), (z + 1.0, 0.7), (z + 0.7, 6.4), (z - 0.7, 6.4)],
                      *sorted((sx * OUT_X, sx * (OUT_X + 1.0))), "paint", bevel=0.08)
        # outer hall front: armored face with a vehicle door and a lamp
        p.box((sx * 18.4, 3.2, -13.04), (5.2, 4.4, 0.08), "dark")
        p.box((sx * 18.4, 5.6, -13.06), (5.6, 0.2, 0.06), "light")
        hazard(p, (sx * 18.4, 0.75, -13.6), (1, 0, 0), UP, 5.2, 0.8, stripes=8)
    # back assembly hall closing the bay (the tallest block)
    p.prism_x([(8.0, 0.7), (22.6, 0.7), (22.6, 12.6), (20.6, HALL_TOP), (10.0, HALL_TOP), (8.0, 13.4)],
              -BAY_X - 0.6, BAY_X + 0.6, "paint", bevel=0.22)
    p.box((0, HALL_TOP + 0.04, 15.4), (12.0, 0.06, 8.6), "team", bevel=0.02)
    p.box((0, 12.4, 7.95), (BAY_X * 2 + 0.8, 0.2, 0.06), "light")  # running strip over the opening
    for sx in (-1, 1):
        p.box((sx * (BAY_X + 0.63), 10.0, 15.4), (0.06, 0.18, 12.0), "light")
        p.box((sx * (BAY_X - 0.05), 12.4, -4.0), (0.06, 0.18, 19.0), "light")  # bay wall strips
    p.box((0, 4.8, 7.98), (9.6, 8.2, 0.06), "dark")  # opening into the bay
    p.box((0, 9.2, 7.94), (10.4, 0.26, 0.06), "power")
    for sx in (-1, 1):
        p.box((sx * 5.0, 4.8, 7.94), (0.26, 8.2, 0.06), "power")
    p.box((0, 6.0, 22.64), (10.0, 5.0, 0.06), "grille")
    # power annex behind the wings: reactor cells (left), cooling block (right)
    for z in (16.6, 20.8):
        p.cylinder("y", (-16.4, 3.9, z), 2.0, 6.4, 18, "paint", bevel=0.06)
        p.ocyl((-16.4, 7.1, z), UP, 2.0, 0.7, 18, "trim", radius2=1.4)
        p.cylinder("y", (-16.4, 7.86, z), 1.3, 0.12, 18, "power")
        p.cylinder("y", (-16.4, 5.2, z), 2.04, 0.6, 18, "team")
        p.cylinder("y", (-16.4, 1.3, z), 2.1, 0.5, 18, "trim")
    p.box((-11.2, 2.0, 18.6), (2.4, 2.6, 6.0), "trim", bevel=0.08)  # transformer
    p.box((-11.2, 3.35, 18.6), (2.0, 0.08, 5.4), "grille")
    p.prism_x([(14.6, 0.7), (22.6, 0.7), (22.6, 6.4), (21.0, 7.6), (14.6, 7.6)], 8.2, 21.6, "paint", bevel=0.16)
    p.box((14.9, 7.64, 18.6), (9.0, 0.06, 5.6), "grille")
    for x in (11.4, 18.6):
        p.ocyl((x, 7.6, 20.4), UP, 0.9, 3.4, 14, "trim", radius2=0.75)
        p.cylinder("y", (x, 11.06, 20.4), 0.76, 0.1, 14, "power")
    cable(p, [(-14.4, 2.0, 18.6), (-12.4, 2.4, 18.6)], r=0.2, kind="steel")
    cable(p, [(-16.4, 7.4, 18.7), (-12.0, 9.0, 18.7), (-8.1, 9.0, 18.7)], r=0.16, kind="steel")
    # parts conveyor from the back hall to the pad
    p.box((0, 1.15, 4.6), (3.0, 0.8, 6.6), "trim", bevel=0.06)
    p.box((0, 1.57, 4.6), (2.6, 0.04, 6.4), "grille")
    for z in (2.0, 4.6, 7.2):
        p.box((0, 1.15, z), (3.2, 0.12, 0.12), "light")
    # emitter arms on the bay walls: a mount, an arm, a glowing head
    for sx, z in ARMS:
        wx = sx * BAY_X
        p.box((wx - sx * 0.35, 7.4, z), (0.7, 1.6, 1.4), "trim", bevel=0.06)
        tip = arm_tip(sx, z)
        p.obox(((wx + tip[0]) / 2, 7.6, z), (sx, 0.18, 0), (0, 0, 1), 2.3, 0.55, 0.55, "paint", bevel=0.05)
        p.cylinder("x", (tip[0], tip[1], z), 0.46, 0.55, 14, "dark")
        p.cylinder("x", (tip[0] - sx * 0.3, tip[1], z), 0.35, 0.06, 14, "power")
    # gantry rails on the inner hall tops
    for sx in (-1, 1):
        p.box((sx * (BAY_X + 0.9), IN_TOP + 0.16, -2.0), (0.55, 0.3, 21.0), "steel")
    # sensor mast on the right inner hall (the radar array turns on it)
    p.prism_y(rect(MAST[0], MAST[1], 1.2, 1.2), IN_TOP, IN_TOP + 1.2, "trim", bevel=0.08, top_scale=0.8)
    p.cylinder("y", (MAST[0], IN_TOP + 2.0, MAST[1]), 0.35, 1.6, 10, "steel")
    p.box((-11.0, IN_TOP + 0.5, 10.6), (1.6, 0.9, 1.6), "trim", bevel=0.06)  # comms box (left)
    p.cylinder("y", (-11.0, IN_TOP + 2.4, 10.6), 0.08, 3.0, 6, "steel")
    p.box((-11.0, IN_TOP + 3.95, 10.6), (0.3, 0.3, 0.3), "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 22.8, 0.78, sz * 22.8), (0.6, 0.14, 0.6), "light")
    t = math.radians(18)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (MAST[0], IN_TOP + 3.6, MAST[1])
    with p.sub("radar", (MAST[0], IN_TOP + 2.8, MAST[1]), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (MAST[0], IN_TOP + 2.9, MAST[1]), 0.45, 0.2, 10, "trim")
        p.obox(c, (1, 0, 0), n, 3.4, 1.8, 0.3, "paint", bevel=0.03)
        p.obox(tuple(c[k] + n[k] * 0.16 for k in range(3)), (1, 0, 0), n, 3.1, 1.5, 0.03, "dark")
        for b in (-0.78, 0.78):
            p.obox(tuple(c[k] + n[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), n, 3.1, 0.08, 0.02, "light")
        p.obox(tuple(c[k] - n[k] * 0.17 for k in range(3)), (1, 0, 0), n, 2.6, 1.1, 0.03, "team")

    # bridge gantry crane: slides along Z over the bay, a hoist with a build lamp
    gy = IN_TOP + 0.9
    with p.sub("gantry", (0.0, gy, GZ), "slide", (0, 0, 1), 8.0):
        p.box((0, gy, GZ), (BAY_X * 2 + 3.0, 0.9, 1.6), "trim", bevel=0.08)
        p.box((0, gy + 0.47, GZ), (BAY_X * 2 + 0.4, 0.05, 1.0), "team")
        for sx in (-1, 1):
            p.box((sx * (BAY_X + 0.9), gy - 0.25, GZ), (1.0, 0.6, 2.6), "paint", bevel=0.06)
            p.box((sx * (BAY_X + 0.9), gy - 0.3, GZ - 1.32), (0.5, 0.18, 0.05), "light")
        p.box((-2.2, gy - 1.0, GZ), (2.4, 1.2, 2.2), "paint", bevel=0.07)  # hoist house
        p.cylinder("y", (-2.2, gy - 2.6, GZ), 0.06, 2.0, 6, "steel")
        p.box((-2.2, gy - 3.8, GZ), (1.0, 0.5, 1.0), "trim", bevel=0.04)
        p.box((3.0, gy - 0.62, GZ), (1.6, 0.4, 1.2), "dark", bevel=0.04)  # build lamp
        p.box((3.0, gy - 0.84, GZ), (1.2, 0.05, 0.8), "power")
        hazard(p, (0, gy, GZ - 0.82), (1, 0, 0), (0, 0, -1), 13.0, 0.45, stripes=20)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * (OUT_X + 0.02), 1.6, -11.0), (sx * (OUT_X + 0.02), 1.6, 11.0), 16, (sx, 0, 0))
        seam(p, (sx * (OUT_X + 0.02), 7.4, -11.0), (sx * (OUT_X + 0.02), 7.4, 11.0), (sx, 0, 0))
        for z in (-8.0, 2.0):
            seam(p, (sx * IN_X - sx * 6.8, IN_TOP + 0.001, z), (sx * IN_X - sx * 0.2, IN_TOP + 0.001, z), UP)
        rivets(p, (sx * (BAY_X + 0.01), 2.0, -13.0), (sx * (BAY_X + 0.01), 2.0, 6.0), 12, (-sx, 0, 0))
    rivets(p, (-6.0, 1.6, 22.62), (6.0, 1.6, 22.62), 10, (0, 0, 1))
    bolts(p, (-21.0, 0.701, -23.2), (-8.5, 0.701, -23.2), 10, UP)
    bolts(p, (8.5, 0.701, -23.2), (21.0, 0.701, -23.2), 10, UP)


unit.run(__file__, "ord_advvehplant", "order", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000, tex=2048,
         previews=[("35", (-56, 45, -67), (0, 6.0, 0), 50),
                   ("80", (0, 124, 22), (0, 4, 0), 50),
                   ("close", (-26, 23, -34), (0, 6.5, -3.0), 35),
                   ("back", (52, 42, 62), (0, 6.0, 0), 50)])
