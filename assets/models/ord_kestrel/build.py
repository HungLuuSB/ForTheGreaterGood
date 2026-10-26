"""Kestrel (Order anti-air bot, T1, footprint 1; S-181): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_kestrel/build.py

From its approved blockout (2026-10-26). Big shapes first: a pelvis on
armored legs (tools/bots.py, swinging for the client's walk), the `torso`
(turns, the def's piece): an upright body with a visor, a team flank
plate and a sensor mast on the left shoulder, and on the right the
`launcher` (pitches, the def's piece): a box pod of four missile cells
with white radome caps and ready lights, a team side panel (`muzzle` at
the cells). Order reads clean (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

LX, LY = 1.5, 5.0  # the launcher's centre
TORSO = (0.0, 3.3, 0.0)
LAUNCHER = (LX, LY - 0.2, 0.2)


def build_base(p):
    p.box((0, 2.9, 0), (1.8, 0.8, 1.4), "dark", bevel=0.06)
    drum(p, (0, 3.25, 0), 0.6, 0.14, "steel", "trim", axis="y")


def details_base(p):
    pass


def build_torso(p):
    p.box((0, 4.1, 0), (2.0, 1.6, 1.6), "paint", bevel=0.12)
    p.obox((-0.2, 4.5, -0.82), (1, 0, 0), (0, 0.2, -1), 1.2, 0.35, 0.05, "glass")
    p.obox((-0.2, 4.5, -0.85), (1, 0, 0), (0, 0.2, -1), 0.4, 0.08, 0.03, "head")
    p.box((-1.03, 4.0, 0), (0.05, 0.7, 1.0), "team", bevel=0.01)
    p.box((0, 3.4, 0.81), (1.2, 0.1, 0.04), "light")
    p.box((-0.8, 5.5, 0.3), (0.16, 1.2, 0.16), "steel")  # the sensor mast
    p.box((-0.8, 6.2, 0.3), (0.8, 0.4, 0.22), "trim", bevel=0.03)
    p.box((-0.8, 6.2, 0.18), (0.6, 0.18, 0.03), "light")
    drum(p, (-1.15, 4.4, 0), 0.28, 0.36, "steel", "trim")
    p.box((-1.3, 3.8, 0), (0.45, 1.2, 0.45), "paint", bevel=0.05)
    drum(p, (1.1, LY - 0.2, 0.2), 0.3, 0.4, "steel", "trim")  # the launcher's trunnion


def details_torso(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.01, 4.6, -0.6), (sx * 1.01, 4.6, 0.6), (sx, 0, 0))


def build_launcher(p):
    p.box((LX, LY, 0), (1.2, 1.2, 1.8), "paint", bevel=0.08)
    p.box((LX + 0.62, LY, 0.1), (0.05, 0.6, 1.2), "team", bevel=0.01)
    p.box((LX, LY, -0.88), (1.0, 1.0, 0.08), "trim")
    for dx in (-0.25, 0.25):
        for dy in (-0.25, 0.25):
            p.ocyl((LX + dx, LY + dy, -0.92), (0, 0, -1), 0.17, 0.08, 10, "radome")
    p.box((LX, LY + 0.62, -0.5), (0.5, 0.04, 0.12), "light")


def details_launcher(p):
    seam(p, (LX - 0.6, LY + 0.61, 0.4), (LX + 0.6, LY + 0.61, 0.4), UP)


unit.run(__file__, "ord_kestrel", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("launcher", "torso", LAUNCHER, build_launcher, details_launcher)]
         + bots.legs(2.7, 0.7, 0.55, "order"),
         attachments={"muzzle": {"parent": "launcher", "at": [LX, LY, -1.0]}},
         budget=3000,
         previews=bots.previews(6.0))
