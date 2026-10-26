"""Artisan (Order bot constructor, T1, footprint 1; S-181): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_artisan/build.py

From its approved blockout (2026-10-26): an upright two-legged worker.
Big shapes first: a pelvis on armored legs (tools/bots.py: `thighL/R`,
`shinL/R`, `footL/R`, swinging for the client's walk), a boxy body with a
wide visor, a backpack with a team panel and a lit spool, a short left arm
with a gripper, and on the right shoulder the `nano` (the def's piece): a
jointed emitter arm with a glowing lens (`nano1`, tools/anchors.py).
Order reads clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

NANO = (1.35, 4.6, 0.0)  # the emitter arm's shoulder joint
TIP = (1.45, 4.6, -2.2)


def build_base(p):
    p.box((0, 2.8, 0), (1.8, 0.8, 1.4), "dark", bevel=0.06)
    p.box((0, 4.1, 0.1), (2.2, 1.8, 1.8), "paint", bevel=0.14)
    p.box((0, 3.25, 0.1), (1.9, 0.12, 1.6), "trim")
    p.obox((0, 4.55, -0.81), (1, 0, 0), (0, 0.2, -1), 1.5, 0.45, 0.06, "glass")  # visor
    p.obox((0, 4.55, -0.84), (1, 0, 0), (0, 0.2, -1), 0.5, 0.1, 0.03, "head")
    p.box((-0.5, 3.75, -0.83), (0.8, 0.5, 0.05), "team", bevel=0.01)
    # backpack: a team panel, a cable spool, a lit band
    p.box((0, 4.0, 1.4), (1.6, 1.6, 0.9), "trim", bevel=0.08)
    p.box((0, 4.15, 1.87), (1.0, 0.8, 0.05), "team", bevel=0.01)
    drum(p, (0, 4.95, 1.4), 0.38, 1.2, "steel", "dark")
    p.box((0, 3.4, 1.87), (1.2, 0.1, 0.04), "power")
    # the short left arm with a gripper
    drum(p, (-1.25, 4.5, 0.0), 0.32, 0.4, "steel", "trim")
    p.box((-1.4, 3.9, 0.0), (0.5, 1.3, 0.5), "paint", bevel=0.06)
    for dz in (-0.15, 0.15):
        p.box((-1.4, 3.1, dz), (0.12, 0.4, 0.1), "steel")
    for sx in (-1, 1):
        p.box((sx * 1.11, 4.1, 0.1), (0.04, 0.12, 1.4), "light")


def details_base(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.11, 4.6, -0.7), (sx * 1.11, 4.6, 0.9), (sx, 0, 0))
    rivets(p, (-0.8, 3.4, -0.81), (0.8, 3.4, -0.81), 5, (0, 0, -1))


def build_nano(p):
    drum(p, NANO, 0.36, 0.5, "steel", "trim")
    p.box((1.45, 4.6, -0.7), (0.6, 0.6, 1.9), "paint", bevel=0.08)
    p.box((1.45, 4.92, -0.7), (0.4, 0.05, 1.3), "team")
    p.ocyl((1.45, 4.6, -1.65), (0, 0, -1), 0.3, 0.4, 12, "trim")
    p.ocyl((1.45, 4.6, -2.05), (0, 0, -1), 0.24, 0.12, 12, "power")


def details_nano(p):
    seam(p, (1.16, 4.6, -1.2), (1.16, 4.6, -0.2), (-1, 0, 0))


unit.run(__file__, "ord_artisan", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, details_nano)]
         + bots.legs(2.6, 0.7, 0.55, "order"),
         budget=3000,
         previews=bots.previews(5.4))
