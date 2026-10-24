"""Gauntlet (Order artillery battery, T1 structure, footprint 2; S-157):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_gauntlet/build.py

From its approved blockout (the user's reference 2026-10-24: a low wide
battery with long twin barrels). Big shapes first: a round pad, a chamfered
emplacement with four angled team-colour armor panels, a turret ring. The
`turret` (yaw): a boxy gun house with trunnion cheeks and a team roof
plate. The `barrel` (pitch, up to 85 degrees for high-arc shells): a long
housing with two barrels side by side, jackets and muzzle brakes; `muzzle`
between the two mouths. Order reads clean and heavy (M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

TURRET = (0.0, 4.2, 0.0)
BARREL = (0.0, 7.6, 0.4)
MUZZLE = (0.0, 7.6, -8.9)


def build_base(p):
    p.cylinder("y", (0, 0.6, 0), 5.7, 1.2, 32, "trim", bevel=0.08)
    p.prism_y(octagon(4.3, 1.2), 1.2, 3.6, "paint", bevel=0.1, top_scale=0.9)
    for k in range(4):
        a = math.radians(k * 90 + 45)
        t = math.radians(15)
        out = (math.sin(a), 0.0, math.cos(a))
        n = (out[0] * math.cos(t), math.sin(t), out[2] * math.cos(t))
        u = (math.cos(a), 0.0, -math.sin(a))
        p.obox((out[0] * 4.9, 2.2, out[2] * 4.9), u, n, 3.8, 2.6, 0.5, "team", bevel=0.06)
    p.cylinder("y", (0, 3.9, 0), 3.3, 0.6, 28, "steel")
    p.cylinder("y", (0, 3.62, 0), 3.4, 0.08, 28, "light")
    hazard(p, (0, 3.62, -3.6), (1, 0, 0), UP, 3.2, 0.4, stripes=8)
    skirt_round(p, 5.7, sides=32)
    for sx in (-1, 1):
        louver(p, (sx * 4.32, 2.3, 0), (0, 0, 1), (sx, 0, 0), 2.0, 1.2)
    louver(p, (0, 2.3, 4.32), (1, 0, 0), (0, 0, 1), 2.0, 1.2)
    clamped_cable(p, [(3.2, 1.2, 4.6), (2.9, 2.6, 3.9), (2.5, 3.7, 3.3)])


def details_base(p):
    band_octagon(p, 2.4, 4.3, 1.2)
    ring(p, (0, 4.21, 0), UP, 2.6)
    rivets(p, (-3.0, 3.61, 3.4), (3.0, 3.61, 3.4), 8, UP)


def build_turret(p):
    p.prism_y(rect(0, 0.6, 2.8, 2.7), 4.2, 6.6, "paint", bevel=0.1, top_scale=0.9)
    p.box((0, 6.64, 2.0), (3.4, 0.05, 2.0), "team", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * 2.4, 7.4, 0), (0.6, 2.2, 3.2), "paint", bevel=0.06)
        p.cylinder("x", (sx * 2.72, 7.6, 0.4), 0.5, 0.2, 14, "trim")
    p.box((2.81, 5.4, 1.6), (0.06, 1.0, 2.0), "grille")
    p.box((0, 5.3, -2.12), (2.6, 0.18, 0.06), "light")
    louver(p, (0, 5.4, 3.32), (1, 0, 0), (0, 0, 1), 2.6, 1.2)
    antenna(p, (2.0, 6.6, 2.6), 1.6)
    for sx in (-1, 1):
        glow_strip(p, (sx * 2.82, 4.6, -1.6), (sx * 2.82, 4.6, 2.8), (sx, 0, 0), width=0.1)


def details_turret(p):
    band_box(p, 5.0, 0, 0.6, 2.8, 2.7)
    seam(p, (-2.5, 6.4, -2.11), (2.5, 6.4, -2.11), (0, 0, -1))


def build_barrel(p):
    p.prism_x([(1.8, 6.6), (1.8, 8.6), (-2.4, 8.6), (-2.6, 8.0), (-2.6, 6.6)], -1.9, 1.9, "paint", bevel=0.06)
    p.box((0, 8.64, -0.4), (2.4, 0.05, 2.6), "team", bevel=0.01)
    for sx in (-1, 1):
        x = sx * 0.9
        p.ocyl((x, 7.6, -2.6), (0, 0, -1), 0.55, 1.4, 14, "trim")  # jacket
        p.ocyl((x, 7.6, -2.6), (0, 0, -1), 0.42, 5.6, 14, "steel")
        p.ocyl((x, 7.6, -7.8), (0, 0, -1), 0.6, 0.9, 12, "dark")  # muzzle brake
        p.ocyl((x, 7.6, -8.72), (0, 0, -1), 0.3, 0.06, 12, "dark")


def details_barrel(p):
    rivets(p, (-1.91, 7.0, 1.2), (-1.91, 7.0, -2.0), 5, (-1, 0, 0))
    rivets(p, (1.91, 7.0, 1.2), (1.91, 7.0, -2.0), 5, (1, 0, 0))


unit.run(__file__, "ord_gauntlet", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=4000,
         previews=[("35", (-20, 14, -24), (0, 4.0, 0), 40),
                   ("close", (-11, 11, -12), (0, 6.0, -2.0), 38)])
