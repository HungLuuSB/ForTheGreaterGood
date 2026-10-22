"""Forgemaster (Chaos advanced ground worker, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_forgemaster/build.py

A heavier Scrapper: a light tracked hull with slat cages over the running
gear, an open cab; on the `nano` turntable (off-centre) a tall lattice
crane arm with a hook and a glowing emitter plus a short second arm with a
smaller emitter (power channel: brighten while building) (BAR style, M-15;
Chaos reads light and open, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

NANO = (0.8, 2.2, -0.2)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    d = hulls.tracked(p, "chaos", length=8.0, width=5.6, deck=1.8)
    p.box((-1.3, d + 0.6, -2.6), (1.8, 1.2, 1.6), "paint", bevel=0.04)  # open cab
    p.box((-1.3, d + 1.22, -2.6), (2.0, 0.08, 1.8), "trim")
    p.box((-1.3, d + 0.8, -3.41), (1.4, 0.3, 0.04), "light")
    p.cylinder("y", (0.8, d + 0.05, -0.2), 1.25, 0.1, 12, "steel")


def details_base(p):
    bolts(p, (-2.4, 1.801, 3.2), (2.4, 1.801, 3.2), 8, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y + 0.2, z), 1.2, 0.4, 12, "paint")
    p.cylinder("y", (x, y + 0.42, z), 0.9, 0.04, 12, "team")
    for dx in (0.0, 0.6):  # lattice arm, two chords and ties
        beam(p, (0.5 + dx, 2.7, 0.6), (0.8 + dx, 6.9, -3.0), 0.22, "paint")
    for k in range(4):
        t = (k + 0.5) / 4
        a = (0.5 + 0.3 * t, 2.7 + 4.2 * t, 0.6 - 3.6 * t)
        beam(p, a, (a[0] + 0.6, a[1], a[2]), 0.1, "steel")
    p.box((1.1, 6.4, -3.0), (0.15, 1.2, 0.15), "dark")  # hook line
    p.cylinder("y", (1.1, 5.7, -3.0), 0.4, 0.7, 10, "power")  # emitter
    beam(p, (0.2, 2.6, 0.2), (0.2, 3.7, 1.8), 0.4, "trim")  # short arm
    p.cylinder("y", (0.2, 3.9, 1.9), 0.28, 0.45, 8, "power")
    p.box((x, y + 0.9, z + 1.0), (1.4, 0.8, 0.8), "trim")  # counterweight


def no_details(p):
    pass


unit.run(__file__, "chs_forgemaster", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)])
