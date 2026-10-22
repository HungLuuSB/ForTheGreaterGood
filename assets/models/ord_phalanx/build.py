"""Phalanx (Order shield generator, T2 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_phalanx/build.py

A fortress-like emitter: a sloped armored base with team plates on all four
sides, a central block, a deck ringed with cyan sensor lights, a plinth and
collar, four corner pylons with glowing power bands, three prongs leaning in
round the `core` (the def's piece): a glowing column (power channel) whose
top carries the `beam` attachment, where the client's shield beam starts
(docs/contracts/fx.md; BAR style, M-15; Order reads heavy, M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring  # noqa: E402

OUTER = [(-6.2, -7.4), (6.2, -7.4), (7.4, -6.2), (7.4, 6.2), (6.2, 7.4), (-6.2, 7.4), (-7.4, 6.2), (-7.4, -6.2)]
BLOCK = [(-3.8, -4.5), (3.8, -4.5), (4.5, -3.8), (4.5, 3.8), (3.8, 4.5), (-3.8, 4.5), (-4.5, 3.8), (-4.5, -3.8)]


def beam(p, a, b, w, d, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)).cross(n).normalized() if abs(n.y) < 0.99 else lib.vec((1, 0, 0))
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, d, (b - a).length, kind, bevel=0.03)


def build_base(p):
    p.prism_y(OUTER, 0.0, 1.2, "paint", bevel=0.08, top_scale=0.86)
    p.prism_y(BLOCK, 1.2, 3.0, "paint", bevel=0.07, top_scale=0.9)
    for sx, sz in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        if sx:
            p.box((sx * 5.5, 1.23, 0), (1.2, 0.05, 4.0), "team", bevel=0.012)
        else:
            p.box((0, 1.23, sz * 5.5), (4.0, 0.05, 1.2), "team", bevel=0.012)
    p.cylinder("y", (0, 3.5, 0), 3.2, 1.0, 20, "dark")
    for i in range(8):  # sensor ring round the deck
        a = i * math.pi / 4 + math.pi / 8
        p.box((math.cos(a) * 3.18, 3.6, math.sin(a) * 3.18), (0.4, 0.22, 0.4), "light")
    p.cylinder("y", (0, 4.45, 0), 2.2, 0.9, 18, "paint")
    p.cylinder("y", (0, 5.3, 0), 1.5, 0.8, 16, "trim")
    for cx, cz in ((-5.4, -5.4), (5.4, -5.4), (-5.4, 5.4), (5.4, 5.4)):  # pylons
        p.cylinder("y", (cx, 2.8, cz), 0.6, 3.2, 10, "steel")
        p.cylinder("y", (cx, 3.6, cz), 0.68, 0.3, 10, "power")
        p.box((cx, 4.55, cz), (1.5, 0.3, 1.5), "trim", bevel=0.04)
    for i in range(3):  # prongs leaning in round the core
        a = math.pi / 2 + i * 2 * math.pi / 3
        ox, oz = math.cos(a), math.sin(a)
        beam(p, (ox * 2.0, 4.9, oz * 2.0), (ox * 1.35, 9.1, oz * 1.35), 1.0, 0.7, "paint")
        p.box((ox * 1.35, 9.35, oz * 1.35), (0.75, 0.45, 0.75), "trim", bevel=0.03)
        p.box((ox * 1.62, 7.6, oz * 1.62), (0.12, 1.6, 0.12), "light")
    for sx in (-1, 1):  # base edge lights
        p.box((sx * 7.3, 0.55, 0), (0.06, 0.16, 6.0), "light")
        p.box((0, 0.55, sx * 7.3), (6.0, 0.16, 0.06), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (7.6, 0, 7.6), 3.001)
    ring(p, (0, 4.001, 0), UP, 2.8)
    bolts(p, (-6.0, 1.201, -5.0), (6.0, 1.201, -5.0), 10, UP)
    bolts(p, (-6.0, 1.201, 5.0), (6.0, 1.201, 5.0), 10, UP)


def build_core(p):
    p.cylinder("y", (0, 5.8, 0), 0.8, 0.2, 14, "steel")
    p.cylinder("y", (0, 7.0, 0), 0.55, 2.4, 14, "power")
    for y in (6.3, 7.7):
        p.cylinder("y", (0, y, 0), 0.62, 0.12, 14, "steel")
    p.cylinder("y", (0, 8.25, 0), 0.7, 0.1, 14, "trim")


def details_core(p):
    pass


unit.run(__file__, "ord_phalanx", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("core", "base", (0.0, 5.7, 0.0), build_core, details_core)],
         attachments={"beam": {"parent": "core", "at": [0, 8.3, 0]}},
         budget=6000, tex=1024)
