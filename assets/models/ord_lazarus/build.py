"""Lazarus (Order helper bot, T1, footprint 1; S-181; repairs, resurrects,
reclaims, builds nothing): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_lazarus/build.py

From its approved blockout (2026-10-26): a field medic. Big shapes first:
a pelvis on armored legs (tools/bots.py, swinging for the client's walk),
a round armored body with a team cross on the chest and lit bands, a glass
dome head on a collar, a backpack with a lit cell, a tool arm on the
right, and on the left the `nano` (the def's piece): the repair emitter
arm with a glowing lens (`nano1`, tools/anchors.py). Order reads clean
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

NANO = (-1.35, 4.5, 0.0)


def build_base(p):
    p.box((0, 2.8, 0), (1.8, 0.8, 1.4), "dark", bevel=0.06)
    p.cylinder("y", (0, 4.1, 0), 1.2, 1.8, 18, "paint", bevel=0.08)
    p.cylinder("y", (0, 3.3, 0), 1.24, 0.16, 18, "trim")
    p.cylinder("y", (0, 4.75, 0), 1.24, 0.12, 18, "power")
    p.cylinder("y", (0, 5.15, 0), 1.0, 0.3, 16, "dark")
    p.cylinder("y", (0, 5.45, 0), 0.85, 0.5, 16, "glass", radius2=0.45)  # the dome head
    p.cylinder("y", (0, 5.35, -0.62), 0.12, 0.1, 8, "head")
    # the team cross on the chest
    p.obox((0, 4.2, -1.2), (1, 0, 0), (0, 0, -1), 0.9, 0.28, 0.06, "team")
    p.obox((0, 4.2, -1.2), (1, 0, 0), (0, 0, -1), 0.28, 0.9, 0.06, "team")
    # backpack with a lit cell
    p.box((0, 4.1, 1.45), (1.4, 1.2, 0.7), "trim", bevel=0.06)
    p.box((0, 4.1, 1.81), (0.6, 0.6, 0.04), "power")
    # the tool arm on the right
    drum(p, (1.25, 4.2, 0.0), 0.3, 0.4, "steel", "trim")
    p.box((1.4, 4.1, -0.5), (0.45, 0.45, 1.6), "paint", bevel=0.05)
    p.box((1.4, 4.1, -1.45), (0.55, 0.3, 0.4), "dark", bevel=0.03)
    p.box((1.4, 4.1, -1.68), (0.3, 0.12, 0.04), "light")


def details_base(p):
    ring(p, (0, 4.1, 0), UP, 1.21, width=0.04, segments=18)
    rivets(p, (-0.6, 3.5, -1.15), (0.6, 3.5, -1.15), 4, (0, 0, -1))


def build_nano(p):
    drum(p, NANO, 0.32, 0.45, "steel", "trim")
    p.box((-1.45, 4.5, -0.75), (0.5, 0.5, 1.8), "paint", bevel=0.06)
    p.box((-1.45, 4.77, -0.75), (0.3, 0.05, 1.2), "team")
    p.ocyl((-1.45, 4.5, -1.65), (0, 0, -1), 0.32, 0.25, 12, "trim")
    p.ocyl((-1.45, 4.5, -1.9), (0, 0, -1), 0.26, 0.1, 12, "power")


def details_nano(p):
    seam(p, (-1.2, 4.5, -1.3), (-1.2, 4.5, -0.3), (1, 0, 0))


unit.run(__file__, "ord_lazarus", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, details_nano)]
         + bots.legs(2.6, 0.7, 0.55, "order"),
         budget=3000,
         previews=bots.previews(5.8))
