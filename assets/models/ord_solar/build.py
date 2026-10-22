"""Solar (Order solar collector, T1 structure, footprint 1): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_solar/build.py

One big framed collector panel tilted 25° on an armored pedestal over a
square pad, its face a grid of dark glass cells, a glowing strip along the
low edge, a team band on the pad and the frame (BAR style, M-15).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import bolts, seam  # noqa: E402

TILT = math.radians(25)
CENTER = (0.0, 2.75, 0.0)
U = (1.0, 0.0, 0.0)
N = (0.0, math.cos(TILT), math.sin(TILT))  # panel normal: up and back (the face looks up-south)


def on_panel(a, b, lift=0.0):
    """Point on the panel plane: a along X, b along the tilted Z, lift along the normal."""
    c = CENTER
    v = (0.0, -math.sin(TILT), math.cos(TILT))
    return (c[0] + a, c[1] + v[1] * b + N[1] * lift, c[2] + v[2] * b + N[2] * lift)


def build_base(p):
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.55, "paint", bevel=0.05, top_scale=0.96)
    p.box((0, 0.58, 2.9), (5.6, 0.05, 1.2), "team", bevel=0.012)
    p.prism_y([(-0.9, -0.9), (0.9, -0.9), (0.9, 0.9), (-0.9, 0.9)], 0.55, 2.3, "trim", bevel=0.04, top_scale=0.7)
    p.cylinder("x", (0, 2.45, 0), 0.3, 1.6, 10, "steel")
    # the panel: a frame slab, a glass face, a team band along the top edge
    p.obox(on_panel(0, 0), U, N, 7.0, 5.6, 0.22, "paint", bevel=0.04)
    p.obox(on_panel(0, 0, 0.12), U, N, 6.6, 5.2, 0.03, "glass")
    p.obox(on_panel(0, 2.65, 0.1), U, N, 6.8, 0.25, 0.05, "light")  # low front edge
    p.obox(on_panel(0, -2.62, 0.13), U, N, 6.8, 0.3, 0.05, "team")  # top back edge
    # back struts to the pad
    for sx in (-1, 1):
        top = on_panel(sx * 2.8, 1.8, -0.12)
        foot = (sx * 2.8, 0.55, 2.4)
        d = (top[0] - foot[0], top[1] - foot[1], top[2] - foot[2])
        mid = tuple((top[k] + foot[k]) / 2 for k in range(3))
        p.obox(mid, d, (1, 0, 0), math.sqrt(sum(c * c for c in d)), 0.2, 0.2, "dark")


def details_base(p):
    # the cell grid on the glass face
    for i in range(1, 6):
        a = -3.3 + i * 1.1
        seam(p, on_panel(a, -2.6, 0.14), on_panel(a, 2.6, 0.14), N, width=0.04)
    for j in range(1, 4):
        b = -2.6 + j * 1.3
        seam(p, on_panel(-3.3, b, 0.14), on_panel(3.3, b, 0.14), N, width=0.04)
    bolts(p, (-3.3, 0.551, -3.3), (3.3, 0.551, -3.3), 8, (0, 1, 0))


unit.run(__file__, "ord_solar", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
