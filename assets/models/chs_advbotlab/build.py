"""Advanced Bot Pit (Chaos bot factory, T2, footprint 5; S-181): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advbotlab/build.py

From its approved blockout (2026-10-26), 40 x 40 studs: the Bot Pit
grown for heavy bots. Big shapes first: a patched slab; a bigger pit (a
grated floor with a glowing grate and a team ring; `buildpad` at its
centre facing the exit at -Z) walled by tall leaning scrap plates with
spikes, open at the front over a wide ramp; a lattice tower crane at the
back with a cab, a long jib over the pit and a counterweight, its
trolley's hook glowing (`nano1`); two lamp masts with arms whose lamps
spray from the sides (`nano2`, `nano3`, tools/anchors.py); two furnace
stacks with glowing mouths, team plates on the slab. Chaos reads crude
and exposed (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

PZ = -3.0  # the pit's centre
JY = 21.0  # the jib's height
TZ = 13.5  # the tower's z


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(19.6, 3.0), 0.0, 0.5, "dark", bevel=0.1, top_scale=0.99)
    for sx in (-1, 1):
        p.box((sx * 14.0, 0.53, -14.0), (6.0, 0.06, 6.0), "team", bevel=0.01)
    p.box((10.0, 0.52, 6.0), (4.0, 0.04, 3.0), "steel", bevel=0.01)
    # the pit
    p.cylinder("y", (0, 0.6, PZ), 11.6, 0.2, 36, "trim")
    p.cylinder("y", (0, 0.72, PZ), 6.4, 0.06, 36, "team")
    p.cylinder("y", (0, 0.76, PZ), 5.0, 0.06, 28, "grille")
    p.cylinder("y", (0, 0.78, PZ), 2.0, 0.04, 16, "power")
    for i in range(20):
        a = 2 * math.pi * (i + 0.5) / 20
        if abs(math.degrees(a) - 180) < 28:
            continue
        c, s = math.cos(a), math.sin(a)
        h = 3.4 + (i % 3) * 0.8
        p.obox((s * 12.4, 0.5 + h / 2, PZ + c * 12.4), (c, 0, -s), (s, 0.15, c), 3.8, h, 0.6, "paint" if i % 2 else "trim", bevel=0.04)
        if i % 2 == 0:
            p.ocyl((s * 12.5, 0.4 + h, PZ + c * 12.5), (s * 0.4, 1.0, c * 0.4), 0.28, 1.6, 6, "steel", radius2=0.02)
        if i % 5 == 2:
            p.obox((s * 12.75, 1.6, PZ + c * 12.75), (c, 0, -s), (s, 0.15, c), 2.2, 0.18, 0.04, "light")
    p.prism_x([(PZ - 17.0, 0.5), (PZ - 12.0, 0.5), (PZ - 12.0, 0.75)], -5.0, 5.0, "steel", bevel=0.03)
    hazard(p, (0, 0.52, PZ - 17.3), (1, 0, 0), UP, 10.0, 0.6, stripes=16)
    # the tower crane: a lattice tower, a cab, the jib, a counterweight, the trolley
    for dx in (-1.3, 1.3):
        for dz in (-1.3, 1.3):
            beam(p, (dx, 0.5, TZ + dz), (dx, JY - 0.4, TZ + dz), 0.36, "dark")
    for y in range(3, int(JY), 3):
        for dz in (-1.3, 1.3):
            p.box((0, y, TZ + dz), (2.6, 0.18, 0.18), "steel")
        for dx in (-1.3, 1.3):
            p.box((dx, y, TZ), (0.18, 0.18, 2.6), "steel")
    for y0 in range(1, int(JY) - 3, 6):
        beam(p, (-1.3, y0, TZ - 1.3), (1.3, y0 + 6.0, TZ - 1.3), 0.14, "steel")
    p.box((0, 8.0, TZ - 1.36), (2.0, 4.0, 0.05), "team", bevel=0.01)
    p.box((2.6, JY - 1.0, TZ), (3.4, 2.6, 3.4), "paint", bevel=0.1)
    p.box((2.6, JY - 0.6, TZ - 1.72), (3.0, 0.8, 0.05), "glass")
    p.box((0, JY + 0.8, TZ - 10.0), (1.6, 1.6, 24.0), "trim", bevel=0.05)
    p.box((0, JY + 1.63, TZ - 10.0), (1.0, 0.05, 18.0), "team")
    p.box((0, JY + 0.8, TZ + 4.5), (1.6, 1.4, 6.0), "trim", bevel=0.05)
    p.box((0, JY - 0.6, TZ + 5.7), (3.0, 2.4, 2.6), "paint", bevel=0.08)
    p.box((0, JY - 0.8, PZ), (2.0, 1.6, 2.0), "dark", bevel=0.06)
    p.cylinder("y", (0, JY - 1.4, PZ), 0.06, 1.0, 6, "steel")
    p.box((0, JY - 1.75, PZ), (0.8, 0.12, 0.8), "power")
    p.box((0, JY + 2.0, TZ), (0.7, 0.7, 0.7), "light")
    # two lamp masts with arms, furnace stacks with glowing mouths
    for sx in (-1, 1):
        x = sx * 14.5
        p.box((x, 7.0, PZ), (1.0, 13.0, 1.0), "dark")
        p.box((x, 0.9, PZ), (2.4, 0.8, 2.4), "trim", bevel=0.05)
        p.box((sx * 12.3, 13.2, PZ), (5.0, 0.6, 0.6), "trim")
        p.box((sx * 10.2, 12.6, PZ), (1.0, 0.8, 1.0), "dark", bevel=0.04)
        p.box((sx * 10.2, 12.18, PZ), (0.7, 0.06, 0.7), "power")
        p.cylinder("y", (sx * 13.5, 6.5, 14.5), 1.6, 12.0, 14, "paint")
        for y in (3.0, 7.0, 11.0):
            p.cylinder("y", (sx * 13.5, y, 14.5), 1.68, 0.3, 14, "dark")
        p.cylinder("y", (sx * 13.5, 12.52, 14.5), 1.2, 0.06, 14, "power")


def details_base(p):
    rivets(p, (8.2, 0.51, 4.8), (11.8, 0.51, 4.8), 6, UP)
    seam(p, (-1.0, 12.0, TZ - 1.36), (1.0, 12.0, TZ - 1.36), (0, 0, -1))


unit.run(__file__, "chs_advbotlab", "chaos", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=7000,
         previews=[("35", (-50, 42, -60), (0, 8.0, 0), 50),
                   ("80", (0, 82, 12), (0, 5, 0), 50),
                   ("close", (-22, 24, -32), (0, 10.0, -4.0), 35)])
