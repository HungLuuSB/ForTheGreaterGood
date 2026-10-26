"""Guard (Chaos laser tower, T1 structure, footprint 2; S-157): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_guard/build.py

From its approved blockout (the user's reference 2026-10-24: a tall laser
tower on an armored skirt). Big shapes first: a patched round pad, a skirt
of six heavy angled armor plates (team colour on every other one), a dark
footing, a stout octagonal column with welded bands, a glowing vent and a
cable. The `turret` (yaw): a rounded head with a team roof plate and an
amber sensor. The `barrel` (pitch, -60..+60 degrees): a ribbed armored
shroud and a stubby laser tube with a glowing lens; `muzzle` at the lens.
Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.

F18 (the user's beta feedback 2026-10-26, "turret should stand high,
proud, tower above others"): the approved mesh scaled x1.259 (the
`scale` below), so it stands as tall as its approved F18 blockout
(~17.5 studs) and reads heavier; same shapes, pieces and anchors.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

TURRET = (0.0, 10.0, 0.0)
BARREL = (0.0, 11.3, -0.8)
MUZZLE = (0.0, 11.3, -5.0)


def build_base(p):
    p.cylinder("y", (0, 0.6, 0), 3.6, 1.2, 24, "dark", bevel=0.08)
    p.box((-1.8, 1.22, 2.2), (1.6, 0.04, 1.2), "trim", bevel=0.01)  # patch
    for k in range(6):  # the heavy skirt
        a = math.radians(k * 60 + 30)
        t = math.radians(24)
        out = (math.sin(a), 0.0, math.cos(a))
        n = (out[0] * math.cos(t), math.sin(t), out[2] * math.cos(t))
        u = (math.cos(a), 0.0, -math.sin(a))
        p.obox((out[0] * 3.6, 1.9, out[2] * 3.6), u, n, 3.2, 2.6, 0.6, "team" if k % 2 == 0 else "era", bevel=0.08)
    p.cylinder("y", (0, 2.3, 0), 2.3, 2.2, 16, "dark", bevel=0.06)
    p.prism_y(octagon(1.5, 0.45), 3.4, 10.0, "paint", bevel=0.08)
    for y in (4.4, 9.4):
        p.prism_y(octagon(1.65, 0.5), y - 0.2, y + 0.2, "trim", bevel=0.03)
    p.box((0, 7.4, -1.52), (1.0, 1.6, 0.06), "power")  # vent glow
    p.box((0, 7.4, -1.5), (1.2, 1.8, 0.04), "grille")
    cable(p, [(1.4, 1.3, 2.2), (1.55, 3.4, 1.0), (1.55, 7.0, 0.9)], r=0.12, kind="dark")
    hazard(p, (0, 1.23, -2.4), (1, 0, 0), UP, 2.2, 0.35, stripes=6)
    skirt_round(p, 3.6, sides=24)
    louver(p, (0, 6.6, 1.53), (1, 0, 0), (0, 0, 1), 1.0, 1.4)
    for sx in (-1, 1):
        glow_strip(p, (sx * 0.55, 4.8, -1.53), (sx * 0.55, 6.3, -1.53), (0, 0, -1), width=0.1)
    clamped_cable(p, [(-2.6, 1.3, -1.6), (-1.6, 3.4, -0.8), (-1.6, 9.0, -0.6)], r=0.1)


def details_base(p):
    band_round(p, 1.8, 2.3)
    band_octagon(p, 6.2, 1.5, 0.45)
    rivets(p, (-1.0, 5.0, -1.51), (1.0, 5.0, -1.51), 5, (0, 0, -1))
    rivets(p, (-1.0, 8.8, -1.51), (1.0, 8.8, -1.51), 5, (0, 0, -1))


def build_turret(p):
    p.cylinder("y", (0, 11.2, 0.2), 1.7, 2.4, 20, "paint", bevel=0.1)
    p.cylinder("y", (0, 12.45, 0.2), 1.5, 0.12, 20, "trim")
    p.box((0, 12.53, 0.5), (1.8, 0.05, 1.6), "team", bevel=0.01)
    p.box((1.1, 11.8, -1.3), (0.5, 0.36, 0.36), "head")  # amber sensor
    p.box((-1.6, 11.0, 0.8), (0.3, 0.8, 1.2), "era", bevel=0.03)
    louver(p, (0, 11.2, 1.92), (1, 0, 0), (0, 0, 1), 1.0, 0.9)
    antenna(p, (-0.8, 12.5, 0.8), 1.4)


def details_turret(p):
    band_round(p, 10.6, 1.7, cz=0.2)
    ring(p, (0, 12.56, 0.5), UP, 0.5)


def build_barrel(p):
    p.box((0, 11.4, -1.6), (1.6, 1.4, 2.2), "paint", bevel=0.1)
    p.box((0, 12.12, -1.6), (1.7, 0.16, 1.8), "dark")  # ribs
    p.box((0, 11.4, -2.72), (1.3, 1.1, 0.06), "grille")
    p.ocyl((0, 11.3, -2.6), (0, 0, -1), 0.42, 2.2, 14, "steel")
    p.ocyl((0, 11.3, -3.5), (0, 0, -1), 0.52, 0.3, 14, "dark")
    p.ocyl((0, 11.3, -4.75), (0, 0, -1), 0.3, 0.12, 14, "weapon")


def details_barrel(p):
    rivets(p, (-0.81, 11.0, -0.7), (-0.81, 11.0, -2.5), 4, (-1, 0, 0))
    rivets(p, (0.81, 11.0, -0.7), (0.81, 11.0, -2.5), 4, (1, 0, 0))


F18 = 1.259  # the F18 scale (old top 13.9 -> 17.5 studs)

unit.run(__file__, "chs_guard", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=4000,
         scale=(F18, F18, F18),
         previews=[("35", (-25.2, 20.1, -30.2), (0.0, 8.2, 0.0), 40),
                   ("close", (-11.3, 17.6, -12.6), (0.0, 13.3, -1.3), 35)])
