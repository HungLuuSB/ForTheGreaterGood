"""Bot Pit (Chaos bot factory, T1, footprint 4; S-181): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_botlab/build.py

From its approved blockout (2026-10-26), 32 x 32 studs. Big shapes first:
a patched slab; a round assembly pit (a grated floor with a glowing grate
and a team ring; `buildpad` at its centre facing the exit at -Z) walled by
leaning scrap plates, open at the front where a ramp leads out over a
hazard edge; two braced lattice crane masts reaching over the pit, their
hook blocks glowing (`nano1`, `nano2`, tools/anchors.py), amber lamps on
the mast heads; a shed with a team plate and fuel tanks at the back.
Chaos reads crude and exposed (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

PZ = -2.0  # the pit's centre
JY = 14.2  # the jibs' height


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(15.6, 2.6), 0.0, 0.5, "dark", bevel=0.1, top_scale=0.99)
    p.box((-9.0, 0.52, 10.0), (4.0, 0.04, 2.6), "steel", bevel=0.01)  # welded patch
    # the pit: floor, glowing grate, team ring
    p.cylinder("y", (0, 0.6, PZ), 8.6, 0.2, 32, "trim")
    p.cylinder("y", (0, 0.72, PZ), 4.6, 0.06, 32, "team")
    p.cylinder("y", (0, 0.76, PZ), 3.6, 0.06, 24, "grille")
    p.cylinder("y", (0, 0.78, PZ), 1.4, 0.04, 16, "power")
    # leaning scrap walls round the pit, open at the front
    for i in range(16):
        a = 2 * math.pi * (i + 0.5) / 16
        if abs(math.degrees(a) - 180) < 30:
            continue
        c, s = math.cos(a), math.sin(a)
        h = 2.6 + (i % 3) * 0.6
        p.obox((s * 9.2, 0.5 + h / 2, PZ + c * 9.2), (c, 0, -s), (s, 0.15, c), 3.5, h, 0.5, "paint" if i % 2 else "trim", bevel=0.04)
        if i % 4 == 1:
            p.obox((s * 9.5, 1.4, PZ + c * 9.5), (c, 0, -s), (s, 0.15, c), 2.0, 0.16, 0.04, "light")
    # the ramp out at the front over a hazard edge
    p.prism_x([(PZ - 13.0, 0.5), (PZ - 9.0, 0.5), (PZ - 9.0, 0.7)], -3.5, 3.5, "steel", bevel=0.03)
    hazard(p, (0, 0.52, PZ - 13.3), (1, 0, 0), UP, 7.0, 0.5, stripes=12)
    # the crane masts with braces, jibs, hook blocks, lamps
    for sx in (-1, 1):
        x = sx * 11.5
        for dx in (-0.6, 0.6):
            for dz in (-0.6, 0.6):
                beam(p, (x + dx, 0.5, PZ + dz), (x + dx * 0.7, JY, PZ + dz * 0.7), 0.3, "dark")
        for y in (3.0, 6.5, 10.0):
            p.box((x, y, PZ), (1.4, 0.2, 1.4), "steel")
        for y0, y1 in ((0.6, 6.5), (6.5, JY - 0.2)):
            beam(p, (x - 0.6, y0, PZ - 0.6), (x + 0.6, y1, PZ - 0.6), 0.14, "steel")
        p.box((x, 0.8, PZ), (2.6, 0.6, 2.6), "trim", bevel=0.05)
        p.box((sx * 7.0, JY + 0.5, PZ), (10.0, 0.9, 0.9), "trim", bevel=0.05)
        p.box((sx * 7.0, JY + 0.97, PZ), (6.0, 0.05, 0.6), "team")
        beam(p, (x, JY + 2.6, PZ), (sx * 3.4, JY + 0.95, PZ), 0.12, "steel")
        beam(p, (x, JY + 2.6, PZ), (x, JY + 0.9, PZ), 0.3, "dark")
        p.cylinder("y", (sx * 3.5, JY - 0.4, PZ), 0.06, 1.0, 6, "steel")
        p.box((sx * 3.5, JY - 1.1, PZ), (1.0, 0.8, 1.0), "dark", bevel=0.05)
        p.box((sx * 3.5, JY - 1.52, PZ), (0.6, 0.06, 0.6), "power")
        p.box((x, JY + 1.3, PZ), (0.6, 0.6, 0.6), "light")
    # the shed with a team plate, fuel tanks
    p.prism_x([(9.0, 0.5), (14.0, 0.5), (14.0, 6.2), (9.0, 7.4)], -11.0, 3.0, "paint", bevel=0.12)
    p.box((-4.0, 4.0, 8.97), (6.0, 2.0, 0.05), "team", bevel=0.01)
    p.box((-8.0, 2.4, 8.96), (2.0, 3.6, 0.05), "dark")
    p.box((-8.0, 4.4, 8.95), (2.0, 0.14, 0.05), "light")
    for x in (8.0, 11.5):
        p.cylinder("y", (x, 3.0, 11.0), 1.5, 5.0, 14, "trim")
        p.cylinder("y", (x, 5.6, 11.0), 1.1, 0.2, 14, "dark")
        p.box((x, 3.0, 9.48), (0.6, 2.4, 0.05), "hazard")
    p.box((-10.5, 0.53, -10.5), (5.0, 0.06, 5.0), "team", bevel=0.01)


def details_base(p):
    rivets(p, (-10.8, 0.51, 7.6), (-7.2, 0.51, 7.6), 6, UP)
    seam(p, (-11.0, 3.0, 8.97), (3.0, 3.0, 8.97), (0, 0, -1))


unit.run(__file__, "chs_botlab", "chaos", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-40, 34, -48), (0, 6.0, 0), 50),
                   ("80", (0, 66, 10), (0, 4, 0), 50),
                   ("close", (-18, 18, -26), (0, 7.0, -2.0), 35)])
