"""Talos (Chaos artillery battery, T1 structure, footprint 2; S-157): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_talos/build.py

From its approved blockout (the user's reference 2026-10-24: a low wide
battery with twin barrels and heavy side pods). Big shapes first: a square
dark pad, a round squat emplacement, four big angled armor pods at the
corners (team colour on the front two), a fuel drum. The `turret` (yaw): a
boxy housing with a team roof plate. The `barrel` (pitch, up to 85 degrees
for high-arc shells): a ridged slab housing with two thick ribbed barrels
side by side; `muzzle` between the mouths. Chaos reads rugged and heavy
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import cable, drum, hazard, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

TURRET = (0.0, 3.8, 0.0)
BARREL = (0.0, 7.4, 0.6)
MUZZLE = (0.0, 7.4, -7.3)


def build_base(p):
    p.prism_y(rect(0, 0, 5.3, 5.3), 0.0, 1.2, "dark", bevel=0.08)
    p.box((-3.0, 1.22, 3.6), (1.8, 0.04, 1.2), "trim", bevel=0.01)
    p.cylinder("y", (0, 2.5, 0), 3.8, 2.6, 24, "dark", bevel=0.08)
    for k in range(4):
        a = math.radians(k * 90 + 45)
        t = math.radians(12)
        out = (math.sin(a), 0.0, math.cos(a))
        n = (out[0] * math.cos(t), math.sin(t), out[2] * math.cos(t))
        u = (math.cos(a), 0.0, -math.sin(a))
        p.obox((out[0] * 4.4, 2.2, out[2] * 4.4), u, n, 3.2, 2.8, 2.0, "team" if k in (1, 2) else "era", bevel=0.1)
    drum(p, (3.6, 1.9, 0), 0.6, 1.4, "paint", "trim", sides=12, axis="y")
    cable(p, [(3.2, 1.3, 0.3), (2.4, 2.0, 0.6), (1.6, 3.4, 0.8)], r=0.12, kind="dark")
    hazard(p, (0, 1.23, -4.6), (1, 0, 0), UP, 4.0, 0.45, stripes=10)
    p.cylinder("y", (0, 3.82, 0), 2.6, 0.04, 24, "power")
    skirt_square(p, 5.3)
    louver(p, (0, 0.6, 5.32), (1, 0, 0), (0, 0, 1), 3.0, 0.7, slats=3)
    for sx in (-1, 1):
        louver(p, (sx * 5.32, 0.6, 0), (0, 0, 1), (sx, 0, 0), 3.0, 0.7, slats=3)
    glow_strip(p, (0, 1.5, -3.82), (0, 3.5, -3.82), (0, 0, -1), width=0.12)
    clamped_cable(p, [(-3.4, 1.3, -3.0), (-2.6, 2.2, -2.6), (-1.8, 3.6, -1.6)], r=0.1)


def details_base(p):
    band_round(p, 2.0, 3.8)
    band_round(p, 3.2, 3.8)
    ring(p, (0, 3.81, 0), UP, 2.2)


def build_turret(p):
    p.prism_y(rect(0, 0.8, 2.7, 2.5), 3.8, 6.4, "paint", bevel=0.1, top_scale=0.9)
    p.box((0, 6.44, 2.2), (3.0, 0.05, 1.8), "team", bevel=0.01)
    p.box((-2.72, 5.2, 1.4), (0.06, 1.0, 2.0), "grille")
    p.box((1.8, 6.0, -1.72), (0.5, 0.36, 0.06), "head")
    louver(p, (0, 5.0, 3.32), (1, 0, 0), (0, 0, 1), 2.4, 1.2)
    antenna(p, (-1.8, 6.4, 2.6), 1.6)


def details_turret(p):
    band_box(p, 5.0, 0, 0.8, 2.7, 2.5)
    rivets(p, (-2.4, 4.4, -1.71), (2.4, 4.4, -1.71), 7, (0, 0, -1))


def build_barrel(p):
    p.box((0, 7.4, -0.2), (4.2, 2.4, 4.6), "era", bevel=0.1)
    for sx in (-1, 1):
        p.box((sx * 1.6, 8.8, -0.2), (0.5, 0.6, 4.4), "dark", bevel=0.04)  # ridges
        x = sx * 1.0
        p.ocyl((x, 7.4, -2.5), (0, 0, -1), 0.55, 4.4, 14, "steel")
        p.ocyl((x, 7.4, -3.6), (0, 0, -1), 0.7, 0.4, 14, "dark")
        p.ocyl((x, 7.4, -5.0), (0, 0, -1), 0.7, 0.4, 14, "dark")
        p.ocyl((x, 7.4, -6.6), (0, 0, -1), 0.72, 0.6, 14, "dark")
        p.ocyl((x, 7.4, -7.22), (0, 0, -1), 0.36, 0.04, 12, "dark")


def details_barrel(p):
    rivets(p, (-2.11, 7.0, 1.4), (-2.11, 7.0, -1.8), 5, (-1, 0, 0))
    rivets(p, (2.11, 7.0, 1.4), (2.11, 7.0, -1.8), 5, (1, 0, 0))


unit.run(__file__, "chs_talos", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=4000,
         previews=[("35", (-20, 14, -24), (0, 4.0, 0), 40),
                   ("close", (-11, 11, -12), (0, 6.0, -2.0), 38)])
