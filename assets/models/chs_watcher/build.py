"""Watcher (Chaos mobile radar, T1, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_watcher/build.py

A high-riding 4 x 4 on big exposed wheels with a push ram, a slab cab with
a slit, a generator with a stack, and on a braced mast at the back the
`dish`: a round flat array (an octagonal panel, not a parabolic dish) tilted
back 25°, a glowing ring round its face and a feed horn in front. Team
plate on the array's back and the cab roof (BAR style, M-15; Chaos reads
light, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring, wheel  # noqa: E402

DISH_PIVOT = (-1.0, 4.4, 1.4)
TILT = math.radians(25)
N = (0.0, math.sin(TILT), -math.cos(TILT))


def build_base(p):
    p.prism_x([(-3.3, 1.2), (3.8, 1.2), (3.8, 2.4), (-3.0, 2.4)], -1.9, 1.9, "paint", bevel=0.04)
    p.obox((0, 1.3, -3.6), (1, 0, 0), (0, 0.34, -0.94), 5.0, 0.8, 0.35, "era", bevel=0.03)
    p.prism_y([(-2.0, -3.3), (2.0, -3.3), (2.0, -1.5), (-2.0, -1.5)], 2.4, 3.6, "paint", bevel=0.04, top_scale=0.9)
    p.box((0, 3.3, -3.32), (3.0, 0.22, 0.05), "light")
    p.box((0, 3.62, -2.4), (2.6, 0.05, 1.1), "team", bevel=0.012)
    p.box((1.5, 3.0, 1.9), (1.4, 1.2, 2.0), "steel", bevel=0.03)
    p.cylinder("y", (1.9, 4.1, 2.7), 0.22, 1.6, 8, "steel")
    p.box((-1.0, 3.4, 1.4), (0.6, 2.0, 0.6), "dark", bevel=0.02)
    p.obox((-1.6, 3.2, 2.1), (0.3, 1, 0.35), (1, 0, 0), 1.8, 0.2, 0.2, "dark")
    for sx in (-1, 1):
        for z in (-2.3, 2.3):
            wheel(p, sx * 2.45, 0.9, z, 0.9, 0.85)


def build_dish(p):
    c = lib.vec((-1.0, 5.6, 1.4))
    n = lib.vec(N)
    u = lib.vec((1, 0, 0))
    v = n.cross(u).normalized()
    pts = []
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4
        pts.append(c + u * math.cos(a) * 1.85 + v * math.sin(a) * 1.85)
    # octagonal slab: front and back faces offset along n
    verts = [tuple(q + n * 0.15) for q in pts] + [tuple(q - n * 0.15) for q in pts]
    faces = [list(range(8)), list(range(15, 7, -1))] + [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)]
    p._shell(verts, faces, "paint", bevel=0.03)
    p.ocyl(tuple(c + n * 0.15), N, 1.6, 0.04, 16, "light")
    p.ocyl(tuple(c + n * 0.15), N, 1.35, 0.06, 16, "dark")
    p.ocyl(tuple(c - n * 0.2), tuple(-n), 1.1, 0.04, 12, "team")
    feed_end = c + n * 1.4
    p.obox(tuple((c + feed_end) / 2), N, (1, 0, 0), 1.4, 0.16, 0.16, "steel")
    p.obox(tuple(feed_end), N, (1, 0, 0), 0.4, 0.4, 0.4, "trim", bevel=0.03)
    p.ocyl(tuple(feed_end + n * 0.2), N, 0.14, 0.04, 8, "light")
    p.cylinder("y", (-1.0, 4.5, 1.4), 0.35, 0.3, 8, "trim")


def details_base(p):
    bolts(p, (-1.7, 2.401, 3.5), (1.7, 2.401, 3.5), 6, UP)


def details_dish(p):
    c = lib.vec((-1.0, 5.6, 1.4))
    ring(p, tuple(c + lib.vec(N) * 0.16), N, 0.9, width=0.05)


unit.run(__file__, "chs_watcher", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH_PIVOT, build_dish, details_dish)])
