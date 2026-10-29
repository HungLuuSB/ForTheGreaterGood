"""Advanced Solar Collector (Order solar, T1 structure, footprint 2; S-209):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advsolar/build.py

After BAR's armadvsol, 16 x 16 studs and about 10 tall, so it reads well
above the low T1 Solar field. Big shapes first: a chamfered slab with team
fins on the corners; a heavy ribbed generator drum lying across it in two
cradles, its ends glowing rings; a yoke and a central mast lifting a big
curved collector dish (five columns of framed dark cells, the outer ones
stepped down, tilted towards the front) with a team band on its back edge
and a lit strip on its front edge. Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec
DRUM_Y, DRUM_R, DRUM_Z = 3.1, 2.3, 0.6
TILT = math.radians(22)
DISH_C = V((0.0, 7.6, 0.4))  # the dish's centre
N0 = V((0, math.cos(TILT), -math.sin(TILT)))  # its mean normal, up and to the front
W0 = V((1, 0, 0)).cross(N0).normalized()  # in its plane, towards the back
R_DISH = 13.0  # dish curvature (radius of the sphere it lies on)
FOCUS = DISH_C + N0 * R_DISH
COLS = [(-2, (-0.5, 0.5)), (-1, (-1.0, 0.0, 1.0)), (0, (-1.0, 0.0, 1.0)), (1, (-1.0, 0.0, 1.0)), (2, (-0.5, 0.5))]
CELL_W, CELL_D = 2.55, 2.35


def on_dish(x, y):
    """The point (x across, y back) of the flat panel bent onto the dish, and its normal."""
    q = DISH_C + V((1, 0, 0)) * x + W0 * y
    d = (q - FOCUS).normalized()
    return FOCUS + d * R_DISH, -d


def build_base(p):
    p.prism_y(octagon(7.8, 1.2), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.985)
    p.prism_y(octagon(6.2, 1.4), 0.6, 0.9, "dark", bevel=0.05)
    # team fins on the corners (BAR's blue wings)
    for sx in (-1, 1):
        for sz in (-1, 1):
            d = V((sx, 0, sz)).normalized()
            c = V((sx * 5.9, 0.0, sz * 5.9))
            p.obox((c.x, 0.95, c.z), tuple(d), UP, 2.6, 0.7, 1.2, "paint", bevel=0.08)
            p.obox((c.x + d.x * 0.3, 1.32, c.z + d.z * 0.3), tuple(d), UP, 1.9, 0.9, 0.05, "team")
            p.box((sx * 7.25, 0.68, sz * 7.25), (0.35, 0.12, 0.35), "light")
    # cradles and the ribbed generator drum lying across the slab
    for sx in (-1, 1):
        p.prism_x([(DRUM_Z - 2.4, 0.9), (DRUM_Z + 2.4, 0.9), (DRUM_Z + 1.9, 2.4), (DRUM_Z - 1.9, 2.4)],
                  sx * 3.6 - 0.8, sx * 3.6 + 0.8, "paint", bevel=0.1)
        p.box((sx * 4.42, 1.6, DRUM_Z), (0.05, 0.16, 3.2), "light")
    p.cylinder("x", (0, DRUM_Y, DRUM_Z), DRUM_R, 9.2, 16, "trim")
    for x in (-3.2, -1.7, 1.7, 3.2):
        p.cylinder("x", (x, DRUM_Y, DRUM_Z), DRUM_R + 0.14, 0.5, 16, "dark")
    p.cylinder("x", (0, DRUM_Y, DRUM_Z), DRUM_R + 0.1, 1.4, 16, "team")
    for sx in (-1, 1):  # the drum's end faces: armored rims round glowing rings
        x = sx * 4.6
        p.cylinder("x", (x + sx * 0.25, DRUM_Y, DRUM_Z), DRUM_R + 0.3, 0.5, 20, "paint")
        p.cylinder("x", (x + sx * 0.52, DRUM_Y, DRUM_Z), DRUM_R * 0.92, 0.06, 20, "power")
        p.cylinder("x", (x + sx * 0.56, DRUM_Y, DRUM_Z), DRUM_R * 0.58, 0.06, 18, "dark")
        p.cylinder("x", (x + sx * 0.6, DRUM_Y, DRUM_Z), DRUM_R * 0.32, 0.08, 14, "steel")
    # inverter boxes on the slab, front and back of the drum
    for z, w in ((-4.6, 3.0), (5.4, 2.2)):
        p.prism_y(rect(0, z, w, 0.9), 0.9, 2.0, "paint", bevel=0.08, top_scale=0.9)
        p.box((0, 1.45, z - 0.93 if z < 0 else z + 0.93), (w * 1.4, 0.45, 0.05), "power")
    hazard(p, (0, 0.92, -6.4), (1, 0, 0), UP, 6.0, 0.4, stripes=10)
    # the yoke: two arms from the drum ends and a central mast up to the dish
    back, nb = on_dish(0, 0)
    for sx in (-1, 1):
        a = V((sx * 3.9, DRUM_Y + 0.6, DRUM_Z))
        b, _ = on_dish(sx * 3.8, 0.4)
        b = b - N0 * 0.7
        u = b - a
        p.obox(tuple((a + b) / 2), tuple(u), (sx, 0, 0), u.length, 0.7, 0.9, "paint", bevel=0.08)
    m0 = V((0, DRUM_Y + DRUM_R - 0.2, DRUM_Z))
    m1 = back - N0 * 0.8
    p.ocyl(tuple(m0), tuple((m1 - m0).normalized()), 0.75, (m1 - m0).length, 10, "steel")
    p.ocyl(tuple(m1 - N0 * 0.3), tuple(N0), 1.6, 0.5, 12, "trim", radius2=1.3)
    cable(p, [(-1.0, DRUM_Y + 1.8, DRUM_Z - 0.6), (-0.8, 5.6, 0.2), (-0.6, m1.y - 0.4, m1.z)], r=0.12, kind="dark")
    cable(p, [(1.0, DRUM_Y + 1.8, DRUM_Z + 0.6), (0.8, 5.6, 0.8), (0.6, m1.y - 0.4, m1.z + 0.3)], r=0.12, kind="dark")
    # the curved collector dish: framed dark cells, outer columns stepped down
    for i, rows in COLS:
        x = i * (CELL_W + 0.12)
        for j in rows:
            y = j * (CELL_D + 0.12)
            c, n = on_dish(x, y)
            u = V((1, 0, 0)) - n * n.x
            u = u.normalized()
            p.obox(tuple(c - n * 0.14), tuple(u), tuple(n), CELL_W + 0.14, CELL_D + 0.14, 0.24, "trim", bevel=0.05)
            for a in (-1, 1):  # two cells per frame
                q = c + u * (a * CELL_W / 4)
                p.obox(tuple(q), tuple(u), tuple(n), CELL_W / 2 - 0.12, CELL_D - 0.14, 0.05, "glass")
        top = max(rows) * (CELL_D + 0.12) + CELL_D / 2 + 0.05
        bot = min(rows) * (CELL_D + 0.12) - CELL_D / 2 - 0.05
        c, n = on_dish(x, top)
        w = n.cross(V((1, 0, 0))).normalized()
        p.obox(tuple(c - n * 0.05), (1, 0, 0), tuple(n), CELL_W + 0.1, 0.26, 0.2, "team")
        c, n = on_dish(x, bot)
        p.obox(tuple(c - n * 0.05), (1, 0, 0), tuple(n), CELL_W + 0.1, 0.22, 0.2, "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 4.86, DRUM_Y + DRUM_R + 0.05, DRUM_Z - 1.2), (sx * 4.86, DRUM_Y + DRUM_R + 0.05, DRUM_Z + 1.2), 5, UP)
    seam(p, (-2.6, 2.0, -5.51), (2.6, 2.0, -5.51), (0, 0, -1))


unit.run(__file__, "ord_advsolar", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-24, 20, -28), (0, 4.0, 0), 50),
                   ("80", (0, 40, 7), (0, 3.0, 0), 50),
                   ("close", (-12, 11, -14), (0, 5.0, 0), 35)])
