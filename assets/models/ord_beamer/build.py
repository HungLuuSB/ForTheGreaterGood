"""Beamer (Order beam tower, T1 structure, footprint 2; S-157): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_beamer/build.py

From its approved blockout (the user's reference 2026-10-24: a tall beam
tower with an arched frame). Big shapes first: a heavy armored footing with
team panels and capacitor drums, a tall column with a team strip, braced by
two conduit pipes meeting in an arch behind it. The `turret` (yaw): a long
boxy housing with a lit top. The `barrel` (pitch, -60..+60 degrees): a
focusing emitter, coil rings and a glowing blue lens; `muzzle` at the lens
(the beam's start). Order reads clean and heavy (M-14). Writes export/
through tools/unit.py.

F18 (the user's beta feedback 2026-10-26, "turret should stand high,
proud, tower above others"): the approved mesh scaled x1.197 (the
`scale` below), so it stands as tall as its approved F18 blockout
(~19.1 studs) and reads heavier; same shapes, pieces and anchors.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

TURRET = (0.0, 12.8, 0.0)
BARREL = (0.0, 13.8, -1.8)
MUZZLE = (0.0, 13.8, -5.3)


def build_base(p):
    p.cylinder("y", (0, 0.6, 0), 4.0, 1.2, 24, "trim", bevel=0.06)
    p.prism_y(octagon(2.8, 0.8), 1.2, 5.2, "paint", bevel=0.1, top_scale=0.9)
    for sx in (-1, 1):
        p.box((sx * 2.82, 3.2, 0), (0.06, 2.8, 2.4), "team", bevel=0.01)
        p.cylinder("z", (sx * 1.5, 2.4, -2.95), 0.6, 1.0, 14, "steel", bevel=0.03)
        p.cylinder("z", (sx * 1.5, 2.4, -3.47), 0.4, 0.06, 14, "light")
    p.prism_y(rect(0, 0.4, 1.2, 1.0), 5.2, 12.6, "paint", bevel=0.1)
    p.box((0, 9.0, -0.62), (1.2, 5.6, 0.06), "team", bevel=0.01)
    for sx in (-1, 1):  # the conduit pipes and their arch
        p.cylinder("y", (sx * 2.0, 8.9, 1.4), 0.3, 7.4, 12, "steel")
        p.cylinder("y", (sx * 2.0, 5.3, 1.4), 0.45, 0.4, 12, "trim")
    p.cylinder("x", (0, 12.6, 1.4), 0.3, 4.6, 12, "steel")
    hazard(p, (0, 1.22, -3.3), (1, 0, 0), UP, 2.8, 0.35, stripes=7)
    skirt_round(p, 4.0, sides=24)
    for sx in (-1, 1):
        glow_strip(p, (sx * 1.1, 5.6, -0.63), (sx * 1.1, 12.2, -0.63), (0, 0, -1), width=0.1)
        louver(p, (sx * 1.23, 7.0, 0.4), (0, 0, 1), (sx, 0, 0), 1.4, 1.6)
    clamped_cable(p, [(-2.6, 1.2, 2.4), (-1.25, 5.4, 1.2), (-1.25, 12.2, 1.2)])


def details_base(p):
    band_box(p, 8.0, 0, 0.4, 1.2, 1.0)
    band_box(p, 11.0, 0, 0.4, 1.2, 1.0)
    seam(p, (-1.2, 7.0, -0.61), (1.2, 7.0, -0.61), (0, 0, -1))
    rivets(p, (-2.4, 5.21, -2.4), (2.4, 5.21, -2.4), 7, UP)


def build_turret(p):
    p.prism_y(rect(0, 0.4, 1.3, 2.3), 12.9, 14.9, "paint", bevel=0.1, top_scale=0.92)
    p.box((0, 14.94, 0.6), (1.6, 0.08, 3.4), "light")
    p.box((-1.32, 13.9, 0.6), (0.06, 1.2, 2.4), "team", bevel=0.01)
    p.box((1.32, 13.9, 1.2), (0.06, 1.0, 1.6), "grille")
    louver(p, (0, 13.9, 2.72), (1, 0, 0), (0, 0, 1), 1.6, 1.2)
    antenna(p, (0.8, 14.95, 2.0), 1.0)


def details_turret(p):
    band_box(p, 13.6, 0, 0.4, 1.3, 2.3)
    rivets(p, (1.31, 13.1, -1.2), (1.31, 13.1, 2.2), 5, (1, 0, 0))


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z + 0.1), (1.6, 1.4, 1.0), "trim", bevel=0.06)
    p.ocyl((x, y, z - 0.4), (0, 0, -1), 0.6, 3.0, 16, "steel")
    for k in (0.6, 1.8):
        p.ocyl((x, y, z - 0.4 - k), (0, 0, -1), 0.85, 0.3, 16, "dark")
    p.ocyl((x, y, MUZZLE[2] + 0.3), (0, 0, -1), 0.7, 0.2, 16, "trim")
    p.ocyl((x, y, MUZZLE[2] + 0.12), (0, 0, -1), 0.45, 0.1, 16, "weapon")


def details_barrel(p):
    seam(p, (-0.5, 14.41, -1.4), (0.5, 14.41, -1.4), UP)


F18 = 1.197  # the F18 scale (old top 15.95 -> 19.1 studs)

unit.run(__file__, "ord_beamer", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=4000,
         scale=(F18, F18, F18),
         previews=[("35", (-23.9, 21.5, -28.7), (0.0, 9.0, 0.0), 40),
                   ("close", (-12.0, 19.2, -13.2), (0.0, 15.3, -1.2), 38)])
