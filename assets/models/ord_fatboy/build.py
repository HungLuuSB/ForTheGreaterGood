"""Fatboy (Order heavy plasma bot, T2, footprint 2; S-181; slow, flattens
bases from long range): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_fatboy/build.py

From its approved blockout (2026-10-26). Big shapes first: a fat armored
body (the `base`: chamfered sides, a sloped front with lit vents, team
plates on its flanks, a dark belly, a reactor pack on the back with a
glowing band) on short thick armored legs (tools/bots.py, swinging for the
client's walk), and on top the `cannon` (turns, the def's piece): a turret
block with a team roof, a sight, and a huge plasma barrel with a breech
housing, glowing coils and a heavy muzzle ring (`muzzle`). Order reads
clean and heavy (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, seam  # noqa: E402

CY = 9.2  # the barrel's height
CANNON = (0.0, 8.0, 0.2)
BODY = [(-3.0, 3.4), (3.4, 3.4), (3.4, 7.4), (2.8, 8.0), (-2.6, 8.0), (-3.6, 6.6), (-3.6, 4.2)]  # (z, y)


def build_base(p):
    p.prism_x(BODY, -3.7, 3.7, "paint", bevel=0.2)
    p.box((0, 3.1, 0.2), (5.6, 0.8, 5.0), "dark", bevel=0.08)  # the belly
    for sx in (-1, 1):
        p.box((sx * 3.72, 6.0, 0.4), (0.06, 2.2, 3.6), "team", bevel=0.02)
        p.box((sx * 3.72, 4.4, 0.4), (0.05, 0.14, 4.6), "light")
        louver(p, (sx * 2.0, 6.6, -3.42), (1, 0, 0), (0, 0.35, -1), 1.8, 0.8, slats=3)
        p.obox((sx * 2.0, 5.6, -3.5), (1, 0, 0), (0, 0.2, -1), 1.6, 0.3, 0.05, "power")
    # reactor pack on the back with a glowing band
    p.box((0, 6.2, 4.2), (5.0, 3.0, 1.6), "trim", bevel=0.12)
    p.box((0, 6.8, 5.02), (3.6, 0.4, 0.05), "power")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 1.8, 8.2, 4.4), 0.32, 1.4, 10, "steel")
    drum(p, (0, 7.95, 0.2), 2.2, 0.2, "steel", "trim", axis="y")  # the turret ring


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 3.71, 7.2, -2.0), (sx * 3.71, 7.2, 2.8), 8, (sx, 0, 0))
        seam(p, (sx * 3.71, 5.0, -2.6), (sx * 3.71, 5.0, 3.0), (sx, 0, 0))


def build_cannon(p):
    p.prism_x([(-1.8, 8.0), (3.0, 8.0), (3.0, 9.9), (2.4, 10.4), (-0.8, 10.4), (-1.8, 9.4)], -2.2, 2.2, "paint", bevel=0.14)
    p.box((0, 10.43, 1.0), (3.0, 0.06, 2.4), "team", bevel=0.02)
    p.box((1.6, 9.9, -1.5), (0.8, 0.5, 0.06), "head")
    p.ocyl((0, CY, -1.6), (0, 0, -1), 1.2, 1.4, 16, "trim")  # the breech housing
    p.ocyl((0, CY, -2.6), (0, 0, -1), 0.85, 5.4, 16, "steel")
    for z in (-4.0, -5.6):
        p.ocyl((0, CY, z), (0, 0, -1), 1.05, 0.35, 16, "power")
    p.ocyl((0, CY, -6.4), (0, 0, -1), 0.95, 0.2, 16, "trim")
    p.ocyl((0, CY, -7.9), (0, 0, -1), 1.2, 0.8, 16, "dark")
    p.ocyl((0, CY, -8.72), (0, 0, -1), 0.6, 0.05, 14, "weapon")
    for sx in (-1, 1):
        p.box((sx * 2.22, 9.2, 0.6), (0.05, 0.14, 3.2), "light")


def details_cannon(p):
    seam(p, (-2.0, 10.39, -0.4), (2.0, 10.39, -0.4), UP)
    for sx in (-1, 1):
        rivets(p, (sx * 2.21, 8.4, -1.4), (sx * 2.21, 8.4, 2.6), 5, (sx, 0, 0))


unit.run(__file__, "ord_fatboy", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("cannon", "base", CANNON, build_cannon, details_cannon)]
         + bots.legs(3.6, 2.5, 1.5, "order"),
         attachments={"muzzle": {"parent": "cannon", "at": [0.0, CY, -8.8]}},
         budget=5000,
         previews=bots.previews(10.6))
