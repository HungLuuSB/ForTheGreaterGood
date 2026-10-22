"""Solar (Chaos solar collector, T1 structure, footprint 1): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_solar/build.py

Three salvaged collector panels at uneven tilts on a rail between two posts,
over a skid; a junction box with an orange light, a team plate on the skid
(BAR style, M-15; Chaos reads light and improvised, M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import bolts, seam  # noqa: E402

PANELS = [(-2.1, 30, 0), (0.0, 20, 4), (2.1, 35, -3)]  # x, tilt, roll (degrees)


def frame(tilt, roll):
    """Panel axes: up tilted toward +Z by `tilt`, then rolled about Z by `roll`."""
    t, r = math.radians(tilt), math.radians(roll)
    n = (-math.cos(t) * math.sin(r), math.cos(t) * math.cos(r), math.sin(t))
    u = (math.cos(r), math.sin(r), 0.0)
    return u, n


def build_base(p):
    p.prism_y([(-3.3, -3.3), (3.3, -3.3), (3.3, 3.3), (-3.3, 3.3)], 0.0, 0.4, "dark", bevel=0.03)
    p.box((2.0, 0.43, 2.0), (2.2, 0.05, 2.2), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 2.9, 1.0, 0), (0.3, 1.2, 0.3), "dark")
    p.box((0, 1.75, 0), (6.2, 0.3, 0.3), "trim")
    for x, tilt, roll in PANELS:
        u, n = frame(tilt, roll)
        c = (x, 2.15, -0.5)
        p.obox(c, u, n, 1.9, 3.3, 0.14, "paint", bevel=0.02)
        p.obox((c[0] + n[0] * 0.08, c[1] + n[1] * 0.08, c[2] + n[2] * 0.08), u, n, 1.7, 3.0, 0.03, "glass")
        p.box((x, 1.95, 0.1), (0.25, 0.5, 0.25), "dark")
    p.box((-2.6, 0.85, 1.6), (0.9, 0.9, 0.7), "paint", bevel=0.03)
    p.box((-2.6, 1.4, 1.6), (0.3, 0.2, 0.3), "light")


def details_base(p):
    for x, tilt, roll in PANELS:
        u, n = frame(tilt, roll)
        v = (n[1] * u[2] - n[2] * u[1], n[2] * u[0] - n[0] * u[2], n[0] * u[1] - n[1] * u[0])
        c = (x + n[0] * 0.1, 2.15 + n[1] * 0.1, -0.5 + n[2] * 0.1)
        for k in (-0.5, 0.5):
            a = tuple(c[i] + v[i] * k * 1.5 - u[i] * 0.8 for i in range(3))
            b = tuple(c[i] + v[i] * k * 1.5 + u[i] * 0.8 for i in range(3))
            seam(p, a, b, n, width=0.04)
    bolts(p, (-3.0, 0.401, -3.0), (3.0, 0.401, -3.0), 7, (0, 1, 0))


unit.run(__file__, "chs_solar", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)])
