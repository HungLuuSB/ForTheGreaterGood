"""Solar (Order solar collector, T1 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_solar/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs),
not rescaled: a low collector field. Four big framed panels tilted 25
degrees towards the front on armored pedestals over a chamfered slab, their
faces grids of dark glass cells with framed edges, team bands along the
upper frames, a glowing strip on each low edge; a central inverter box with
a power vent, cable trays to every panel, corner lights. Order reads clean
and heavy (M-14). Writes export/ through tools/unit.py.
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
TILT = math.radians(25)


def panel(p, cx, cz):
    """A framed tilted panel (5.6 wide, 5.0 deep) on a pedestal at (cx, cz)."""
    n = V((0, math.cos(TILT), -math.sin(TILT)))  # facing up and forward
    u = V((1, 0, 0))
    c = V((cx, 2.3, cz))
    p.prism_y(rect(cx, cz, 0.7, 0.7), 0.6, 1.6, "paint", bevel=0.08, top_scale=0.8)
    p.cylinder("y", (cx, 1.85, cz), 0.35, 0.5, 10, "steel")
    p.obox(tuple(c), tuple(u), tuple(n), 5.6, 5.0, 0.22, "trim", bevel=0.06)  # frame
    w = n.cross(u).normalized()
    for i in range(4):  # cell grid: 4 x 3 dark glass cells
        for j in range(3):
            q = c + u * (-2.1 + i * 1.4) + w * (-1.55 + j * 1.55) + n * 0.12
            p.obox(tuple(q), tuple(u), tuple(n), 1.28, 1.42, 0.04, "glass")
    p.obox(tuple(c + w * 2.45 + n * 0.12), tuple(u), tuple(n), 5.4, 0.22, 0.05, "team")
    p.obox(tuple(c - w * 2.42 + n * 0.12), tuple(u), tuple(n), 5.2, 0.24, 0.05, "light")


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.6, "trim", bevel=0.12, top_scale=0.985)
    for cx in (-3.6, 3.6):
        for cz in (-3.4, 3.6):
            panel(p, cx, cz)
    # inverter box in the middle with a power vent and a team top
    p.prism_y(rect(0, 0.1, 0.9, 1.3), 0.6, 2.0, "paint", bevel=0.1, top_scale=0.9)
    p.box((0, 2.03, 0.1), (1.3, 0.05, 2.0), "team")
    p.box((0, 1.3, -1.22), (1.4, 0.7, 0.05), "power")
    for sx in (-1, 1):
        p.box((sx * 0.92, 1.3, 0.1), (0.05, 0.5, 2.2), "power")
    # cable trays to the panels
    for cx in (-3.6, 3.6):
        for cz in (-3.4, 3.6):
            cable(p, [(0, 0.7, 0.1), (cx * 0.5, 0.7, cz * 0.5), (cx, 0.7, cz)], r=0.1, kind="dark")
    hazard(p, (0, 0.62, -7.0), (1, 0, 0), (0, 1, 0), 4.0, 0.4, stripes=8)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.2, 0.68, sz * 7.2), (0.4, 0.1, 0.4), "light")


def details_base(p):
    rivets(p, (-0.7, 1.8, -1.22), (0.7, 1.8, -1.22), 3, (0, 0, -1))
    seam(p, (-0.85, 1.0, -1.21), (0.85, 1.0, -1.21), (0, 0, -1))


unit.run(__file__, "ord_solar", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 2.0, 0), 50),
                   ("80", (0, 36, 6), (0, 1.5, 0), 50),
                   ("close", (-11, 9, -13), (0, 2.5, 0), 35)])
