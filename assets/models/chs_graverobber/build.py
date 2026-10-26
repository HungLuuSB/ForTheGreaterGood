"""Graverobber (Chaos helper bot, T1, footprint 1; S-181; repairs,
resurrects, reclaims, builds nothing): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_graverobber/build.py

From its approved blockout (2026-10-26): a hunched scavenger. Big shapes
first: a pelvis on bowed strut legs (tools/bots.py, swinging for the
client's walk), a slab body, a small head thrust forward with an amber
eye, a scrap hopper on its back (open, scrap sticking out, a team plate),
a stub left arm, and the `nano` (the def's piece): a long claw arm on the
right that grabs and sprays (`nano1`, tools/anchors.py). Chaos reads crude
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

NANO = (1.35, 4.0, 0.0)
TIP = (1.45, 3.35, -2.6)


def beam(p, a, b, w, d, kind, bevel=0.03):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(u.cross(n)), w, (b - a).length, d, kind, bevel=bevel)


def build_base(p):
    p.box((0, 2.4, 0), (1.8, 0.8, 1.4), "dark", bevel=0.05)
    p.box((0, 3.6, 0), (2.2, 1.6, 2.0), "paint", bevel=0.1)
    p.box((-0.3, 4.4, -1.1), (1.0, 0.8, 0.9), "paint", bevel=0.06)  # the head
    p.box((-0.3, 4.45, -1.56), (0.6, 0.18, 0.04), "head")
    # the scrap hopper on the back: walls, an open dark top, scrap
    p.box((0, 4.5, 1.5), (2.4, 1.8, 1.6), "trim", bevel=0.06)
    p.box((0, 5.42, 1.5), (2.0, 0.06, 1.2), "dark")
    p.obox((-0.5, 5.8, 1.4), (0.9, 0, 0.3), (0.2, 0.4, 0.9), 0.3, 1.2, 0.8, "paint")
    p.obox((0.5, 5.7, 1.7), (0.8, -0.5, 0.3), (0, 0.3, 1), 0.9, 0.3, 0.3, "steel")
    p.box((-1.22, 4.5, 1.5), (0.05, 1.0, 1.0), "team", bevel=0.01)
    p.box((1.22, 4.0, 1.5), (0.05, 0.2, 1.2), "power")
    drum(p, (-1.25, 4.0, -0.2), 0.3, 0.4, "steel", "trim")
    p.box((-1.4, 3.3, -0.2), (0.5, 1.3, 0.5), "trim", bevel=0.04)


def details_base(p):
    rivets(p, (-1.0, 3.0, -1.01), (1.0, 3.0, -1.01), 5, (0, 0, -1))
    seam(p, (1.21, 4.9, 0.8), (1.21, 4.9, 2.2), (1, 0, 0))


def build_nano(p):
    drum(p, NANO, 0.34, 0.5, "steel", "trim")
    beam(p, NANO, TIP, 0.5, 0.5, "paint")
    p.box((1.45, 3.35, -2.6), (0.7, 0.55, 0.6), "dark", bevel=0.04)
    for sx in (-1, 1):  # the claw
        p.prism_x([(-2.85, 3.2), (-3.4, 3.0), (-3.3, 2.7), (-2.75, 2.95)], 1.45 + sx * 0.22 - 0.07, 1.45 + sx * 0.22 + 0.07, "steel")
    p.box((1.45, 3.62, -2.92), (0.3, 0.12, 0.04), "power")


def details_nano(p):
    pass


unit.run(__file__, "chs_graverobber", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, details_nano)]
         + bots.legs(2.3, 0.75, 0.6, "chaos"),
         budget=3000,
         previews=bots.previews(6.0))
