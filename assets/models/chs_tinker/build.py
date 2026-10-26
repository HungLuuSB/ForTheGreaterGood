"""Tinker (Chaos bot constructor, T1, footprint 1; S-181): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_tinker/build.py

From its approved blockout (2026-10-26): a hunched scrap worker on bowed
legs (tools/bots.py: `thighL/R`, `shinL/R`, `footL/R`, bare struts with
pistons and claw toes, swinging for the client's walk), a slab body with
a hunched back plate, an amber eye slit, an exhaust pipe and a team plate,
a stub left arm, and the `nano` (the def's piece): a crane boom from its
back over the right shoulder with a claw and a lamp at the tip (`nano1`,
tools/anchors.py). Chaos reads crude (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

NANO = (0.95, 4.7, 1.0)  # the boom's root behind the shoulder
TIP = (0.95, 5.55, -2.2)


def beam(p, a, b, w, d, kind, bevel=0.03):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(u.cross(n)), w, (b - a).length, d, kind, bevel=bevel)


def build_base(p):
    p.box((0, 2.4, 0), (1.8, 0.8, 1.4), "dark", bevel=0.05)
    p.box((0, 3.6, 0.3), (2.4, 1.6, 2.2), "paint", bevel=0.1)
    p.prism_x([(-0.8, 4.4), (1.4, 4.4), (1.4, 4.9), (0.2, 5.3)], -1.2, 1.2, "paint", bevel=0.08)  # the hunch
    p.box((0, 3.9, -0.82), (1.2, 0.25, 0.06), "head")
    p.box((0, 3.9, -0.84), (1.5, 0.45, 0.04), "dark")
    p.cylinder("y", (-0.8, 5.3, 1.1), 0.18, 1.6, 8, "steel")
    p.cylinder("y", (-0.8, 6.1, 1.1), 0.22, 0.1, 8, "power")
    p.box((-1.22, 3.6, 0.3), (0.05, 0.8, 1.2), "team", bevel=0.01)
    p.box((1.1, 3.2, 0.9), (0.4, 0.6, 0.6), "trim", bevel=0.04)  # a patch box
    drum(p, (-1.3, 4.0, -0.1), 0.3, 0.4, "steel", "trim")
    p.box((-1.5, 3.3, -0.1), (0.55, 1.3, 0.55), "trim", bevel=0.04)
    p.box((-1.5, 2.6, -0.1), (0.6, 0.3, 0.6), "dark")


def details_base(p):
    rivets(p, (-1.0, 3.1, -0.81), (1.0, 3.1, -0.81), 5, (0, 0, -1))
    seam(p, (1.21, 3.4, -0.6), (1.21, 3.4, 1.2), (1, 0, 0))


def build_nano(p):
    drum(p, NANO, 0.32, 0.5, "steel", "trim")
    beam(p, NANO, TIP, 0.4, 0.4, "trim")
    p.box((0.95, 5.55, -2.2), (0.7, 0.5, 0.6), "dark", bevel=0.04)
    for sx in (-1, 1):
        p.box((0.95 + sx * 0.22, 5.2, -2.35), (0.1, 0.5, 0.12), "steel")
    p.box((0.95, 5.55, -2.52), (0.3, 0.2, 0.04), "power")


def details_nano(p):
    pass


unit.run(__file__, "chs_tinker", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, details_nano)]
         + bots.legs(2.3, 0.75, 0.6, "chaos"),
         budget=3000,
         previews=bots.previews(5.6))
