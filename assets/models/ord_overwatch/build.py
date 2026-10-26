"""Overwatch (Order twin laser tower, T1 structure, footprint 2; S-157):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_overwatch/build.py

From its approved blockout (the user's reference 2026-10-24: a flared base,
a thin mast, a wide head). Big shapes first: a flared footing ringed with a
lit vent band and four fins, a neck, a thin tall mast. The `turret` (yaw): a
wide saucer head with a team band, a lit dome and running lights. The
`mount` (pitch, -60..+60 degrees): a trunnion bar carrying two long green
laser barrels, each its own client piece (`barrel1` left, `barrel2` right;
recoil along +Z) with `muzzle1` / `muzzle2` at their lenses. Writes export/
through tools/unit.py.

F18 (the user's beta feedback 2026-10-26, "turret should stand high,
proud, tower above others"): the approved mesh scaled x1.281 (the
`scale` below), so it stands as tall as its approved F18 blockout
(~18.7 studs) and reads heavier; same shapes, pieces and anchors.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import hazard, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

TURRET = (0.0, 11.8, 0.0)
MOUNT = (0.0, 12.2, -0.6)
BX = 2.6
MUZZLES = {"muzzle1": (-BX, 12.2, -5.8), "muzzle2": (BX, 12.2, -5.8)}


def build_base(p):
    p.cylinder("y", (0, 0.5, 0), 4.2, 1.0, 28, "trim", bevel=0.06)
    p.cylinder("y", (0, 2.5, 0), 3.2, 3.0, 28, "paint", radius2=2.4, bevel=0.08)
    p.cylinder("y", (0, 2.3, 0), 3.08, 1.2, 28, "light")  # the lit vent band
    p.cylinder("y", (0, 2.3, 0), 3.12, 1.4, 28, "grille")
    for k in range(4):
        a = math.radians(k * 90 + 45)
        u = (math.cos(a), 0.0, -math.sin(a))
        n = (math.sin(a), 0.0, math.cos(a))
        p.obox((n[0] * 3.5, 1.9, n[2] * 3.5), u, n, 0.5, 2.6, 1.8, "paint", bevel=0.05)
        p.obox((n[0] * 4.42, 1.9, n[2] * 4.42), u, n, 0.06, 1.6, 0.04, "team")
    p.cylinder("y", (0, 5.2, 0), 1.8, 2.4, 24, "paint", radius2=1.3, bevel=0.06)
    p.cylinder("y", (0, 9.1, 0), 0.6, 5.4, 14, "dark")
    p.cylinder("y", (0, 11.6, 0), 0.9, 0.4, 16, "trim")
    hazard(p, (0, 1.02, -3.4), (1, 0, 0), UP, 2.6, 0.35, stripes=6)
    skirt_round(p, 4.2, sides=28)
    for sx in (-1, 1):
        clamped_cable(p, [(sx * 1.5, 6.3, 0.6), (sx * 0.72, 7.0, 0.3), (sx * 0.72, 11.3, 0.3)], r=0.08)
    glow_strip(p, (0, 6.6, -0.62), (0, 11.2, -0.62), (0, 0, -1), width=0.12)


def details_base(p):
    band_round(p, 8.0, 0.6)
    band_round(p, 10.0, 0.6)
    band_round(p, 3.4, 2.56)
    seam(p, (-2.4, 4.0, -0.01), (2.4, 4.0, -0.01), UP)
    ring(p, (0, 6.42, 0), UP, 0.9)


def build_turret(p):
    p.cylinder("y", (0, 12.4, 0), 2.8, 1.6, 28, "paint", radius2=2.3, bevel=0.1)
    p.box((0, 12.5, 0), (1.6, 1.7, 4.6), "team", bevel=0.02)
    p.cylinder("y", (0, 13.3, 0.4), 0.9, 0.3, 16, "trim")
    p.ocyl((0, 13.4, 0.4), UP, 0.6, 0.55, 14, "light", radius2=0.2)  # the lit dome
    for sx in (-1, 1):
        p.box((sx * 1.6, 12.6, -2.32), (0.6, 0.18, 0.06), "light")
        p.box((sx * 2.4, 12.2, 1.4), (0.9, 0.6, 1.0), "trim", bevel=0.04)
    louver(p, (0, 12.4, 2.52), (1, 0, 0), (0, 0, 1), 1.8, 0.9)
    antenna(p, (-1.4, 13.2, 1.2), 1.4)


def details_turret(p):
    band_round(p, 12.0, 2.75)
    rivets(p, (-2.1, 13.21, -1.0), (2.1, 13.21, -1.0), 7, UP)


def build_mount(p):
    p.box((0, 12.2, -1.0), (5.8, 0.8, 1.2), "trim", bevel=0.06)
    for sx in (-1, 1):
        x = sx * BX
        with p.sub("barrel1" if sx < 0 else "barrel2", (x, 12.2, -1.2), "slide", (0, 0, 1), 0.6):
            p.box((x, 12.2, -1.6), (0.9, 0.9, 1.2), "paint", bevel=0.06)
            p.ocyl((x, 12.2, -2.2), (0, 0, -1), 0.3, 3.4, 12, "steel")
            p.ocyl((x, 12.2, -3.4), (0, 0, -1), 0.42, 0.24, 12, "dark")
            p.ocyl((x, 12.2, -5.2), (0, 0, -1), 0.36, 0.3, 12, "dark")
            p.ocyl((x, 12.2, -5.62), (0, 0, -1), 0.24, 0.1, 12, "weapon")


def details_mount(p):
    seam(p, (-2.8, 12.61, -1.0), (2.8, 12.61, -1.0), UP)


F18 = 1.281  # the F18 scale (old top 14.6 -> 18.7 studs)

unit.run(__file__, "ord_overwatch", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("mount", "turret", MOUNT, build_mount, details_mount)],
         attachments={k: {"parent": "barrel1" if k == "muzzle1" else "barrel2", "at": list(v)} for k, v in MUZZLES.items()},
         budget=4000,
         scale=(F18, F18, F18),
         previews=[("35", (-25.6, 21.8, -30.7), (0.0, 9.0, 0.0), 40),
                   ("close", (-12.8, 20.5, -14.1), (0.0, 15.4, -1.3), 38)])
