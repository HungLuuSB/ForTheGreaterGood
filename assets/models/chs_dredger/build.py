"""Dredger (Chaos amphibious constructor, T1; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_dredger/build.py

A salvage dredge: the amphibious hull in Chaos dress with an open-framed
cab, a spoil hopper at the back, and on a turntable (`nano`, the def's
turning piece) a lattice boom ending in a three-tined claw round a glowing
emitter (power channel: brightens while building) (BAR style, M-15; Chaos
reads light and open, M-14). Our own design.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.9
NANO = (0.8, DECK, 0.6)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    d = hulls.amphibious(p, "chaos", length=7.0, width=4.6, deck=DECK, wheels=5)
    # open cab: a floor, corner posts and a roof
    x0, x1, z0, z1 = -2.0, -0.3, -2.7, -1.0
    p.box(((x0 + x1) / 2, d + 0.05, (z0 + z1) / 2), (x1 - x0, 0.1, z1 - z0), "dark")
    for x in (x0 + 0.08, x1 - 0.08):
        for z in (z0 + 0.08, z1 - 0.08):
            p.box((x, d + 0.6, z), (0.12, 1.1, 0.12), "steel")
    p.box(((x0 + x1) / 2, d + 1.18, (z0 + z1) / 2), (x1 - x0 + 0.1, 0.08, z1 - z0 + 0.1), "paint", bevel=0.02)
    p.box(((x0 + x1) / 2, d + 1.23, (z0 + z1) / 2), (1.1, 0.04, 1.0), "team", bevel=0.01)
    p.box(((x0 + x1) / 2, d + 0.9, z0 - 0.02), (1.2, 0.3, 0.04), "head")  # lamp bar
    # spoil hopper at the back
    p.prism_y([(-2.0, 1.2), (-0.2, 1.2), (-0.2, 3.1), (-2.0, 3.1)], d, d + 0.9, "trim", bevel=0.03, top_scale=1.12)
    p.box((-1.1, d + 0.88, 2.15), (1.6, 0.04, 1.7), "grille")


def details_base(p):
    bolts(p, (0.3, DECK + 0.001, -2.6), (2.0, DECK + 0.001, -2.6), 4, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y + 0.2, z), 0.8, 0.4, 12, "dark")
    p.box((x, y + 0.6, z + 0.2), (0.7, 0.5, 0.9), "paint", bevel=0.03)
    # lattice boom, raised forward
    top = y + 1.9
    a0, a1 = (x - 0.2, y + 0.8, z), (x - 0.2, top, z - 2.6)
    b0, b1 = (x + 0.2, y + 0.8, z), (x + 0.2, top, z - 2.6)
    beam(p, a0, a1, 0.12, "paint")
    beam(p, b0, b1, 0.12, "paint")
    for k in range(1, 5):
        t = k / 5
        pa = tuple(a0[i] + (a1[i] - a0[i]) * t for i in range(3))
        pb = tuple(b0[i] + (b1[i] - b0[i]) * t for i in range(3))
        beam(p, pa, pb, 0.07, "steel")
    p.box((x, top - 0.45, z - 1.3), (0.3, 0.04, 1.4), "team")
    # claw round the emitter
    cx, cy, cz = x, top - 0.25, z - 2.9
    p.cylinder("y", (cx, cy + 0.15, cz), 0.3, 0.25, 10, "dark")
    p.cylinder("y", (cx, cy - 0.15, cz), 0.18, 0.3, 10, "power")
    for k in range(3):
        a = k * 2.094
        tip = (cx + math.cos(a) * 0.4, cy - 0.7, cz + math.sin(a) * 0.4)
        beam(p, (cx + math.cos(a) * 0.25, cy + 0.05, cz + math.sin(a) * 0.25), tip, 0.08, "steel")


def no_details(p):
    pass


unit.run(__file__, "chs_dredger", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         attachments={"nano1": {"parent": "nano", "at": [NANO[0], NANO[1] + 1.25, NANO[2] - 2.9]}})
