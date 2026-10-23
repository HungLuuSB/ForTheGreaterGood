"""Solar (Chaos solar collector, T1 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_solar/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs),
not rescaled: a low, improvised collector field. Five salvaged panels of
different sizes at uneven tilts on rails between posts over a skid, patched
cells, team plates on the skid and a team band on the biggest panel, a
junction box with a battery stack and an orange light, loose cables, hazard
striping and beacons. Chaos reads rugged and improvised (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP  # noqa: E402

V = lib.vec
PANELS = [  # (cx, cz, width, depth, tilt deg, yaw deg, height)
    (-4.0, -3.2, 5.4, 4.2, 28, 6, 2.3),
    (2.4, -3.8, 4.2, 3.4, 20, -8, 2.0),
    (-3.6, 3.4, 4.0, 3.6, 34, -4, 2.5),
    (2.8, 2.6, 5.0, 4.0, 24, 10, 2.2),
    (6.0, -0.6, 2.4, 2.4, 40, 25, 1.8),
]


def panel(p, cx, cz, w, d, tilt, yaw, h, team=False):
    t, y = math.radians(tilt), math.radians(yaw)
    u = V((math.cos(y), 0, math.sin(y)))
    fwd = V((math.sin(y), 0, -math.cos(y)))
    n = (V((0, math.cos(t), 0)) + fwd * math.sin(t)).normalized()
    c = V((cx, h, cz))
    for s in (-1, 1):  # posts
        q = c + u * (s * w * 0.38)
        p.box((q.x, (q.y + 0.6) / 2, q.z), (0.24, q.y - 0.6, 0.24), "dark")
    p.obox(tuple(c), tuple(u), tuple(n), w, d, 0.18, "trim", bevel=0.04)
    wv = n.cross(u).normalized()
    cols, rows = max(2, round(w / 1.3)), max(2, round(d / 1.3))
    for i in range(cols):
        for j in range(rows):
            if (i * 7 + j * 3) % 9 == 4:
                continue  # a missing cell
            q = c + u * (-w / 2 + (i + 0.5) * w / cols) + wv * (-d / 2 + (j + 0.5) * d / rows) + n * 0.1
            p.obox(tuple(q), tuple(u), tuple(n), w / cols - 0.12, d / rows - 0.12, 0.04, "glass")
    p.obox(tuple(c - wv * (d / 2 - 0.08) + n * 0.1), tuple(u), tuple(n), w * 0.9, 0.22, 0.05, "light")
    if team:
        p.obox(tuple(c + wv * (d / 2 - 0.12) + n * 0.1), tuple(u), tuple(n), w * 0.95, 0.24, 0.05, "team")


def build_base(p):
    p.prism_y(octagon(7.8, 0.7), 0.0, 0.6, "dark", bevel=0.1, top_scale=0.985)
    for i, pr in enumerate(PANELS):
        panel(p, *pr, team=(i == 0))
    for x, z in ((-6.2, 6.3), (6.4, 6.3)):
        p.box((x, 0.64, z), (2.2, 0.05, 1.0), "team", bevel=0.01)
    # junction box with a battery stack and a light
    p.prism_y(rect(0.6, 0.0, 1.0, 0.8), 0.6, 2.1, "paint", bevel=0.08)
    for k in range(3):
        p.box((0.6, 2.3 + k * 0.35, 0.0), (1.6 - k * 0.3, 0.3, 1.2 - k * 0.2), "trim", bevel=0.03)
    p.box((0.6, 1.4, -0.82), (1.6, 0.6, 0.05), "power")
    p.cylinder("y", (0.6, 3.5, 0.0), 0.16, 0.3, 8, "light")
    for pr in PANELS:
        cable(p, [(0.6, 0.75, 0.0), ((pr[0] + 0.6) / 2, 0.68, pr[1] / 2), (pr[0], 0.7, pr[1])], r=0.07)
    hazard(p, (-1.5, 0.62, -7.1), (1, 0, 0), (0, 1, 0), 5.0, 0.4, stripes=9)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.68, sz * 7.0), (0.3, 0.15, 0.3), "light")


def details_base(p):
    rivets(p, (-0.2, 2.1, -0.81), (1.4, 2.1, -0.81), 4, (0, 0, -1))


unit.run(__file__, "chs_solar", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 2.0, 0), 50),
                   ("80", (0, 36, 6), (0, 1.5, 0), 50),
                   ("close", (-11, 9, -13), (0, 2.5, 0), 35)])
