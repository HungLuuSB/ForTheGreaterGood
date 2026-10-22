"""Ragnarok (Chaos nuclear silo, T3 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_ragnarok/build.py

A round silo tube on a dark pad, ringed with reactive-armor blocks, a round
`hatch` (the def's piece, hinged at its back edge) with a hazard ring, an
open launch gantry with a crane arm beside it, fuel tanks with orange
gauges, and an orange warning ring round the tube (power channel: the
silo's charge state); team plates on the pad (BAR style, M-15; Chaos reads
light and exposed, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

HATCH = (0.0, 3.25, 3.8)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.cylinder("y", (0, 0.4, 0), 10.0, 0.8, 24, "dark")
    for a in (math.radians(45), math.radians(225)):
        p.obox((math.cos(a) * 7.6, 0.83, math.sin(a) * 7.6), (math.cos(a + math.pi / 2), 0, math.sin(a + math.pi / 2)),
               (0, 1, 0), 3.4, 1.6, 0.05, "team")
    # silo tube, warning ring, reactive armour blocks
    p.cylinder("y", (0, 1.9, 0), 4.6, 2.2, 20, "paint")
    p.cylinder("y", (0, 2.55, 0), 4.65, 0.5, 20, "power", cap_kinds=("paint", "paint"))
    for i in range(10):
        a = i * 2 * math.pi / 10
        d = (math.cos(a), 0, math.sin(a))
        p.obox((d[0] * 4.85, 1.6, d[2] * 4.85), (-d[2], 0, d[0]), (0, 1, 0), 2.2, 0.5, 1.1, "trim", bevel=0.03)
    p.cylinder("y", (0, 3.02, 0), 4.0, 0.05, 20, "dark")
    for i in range(12):  # hazard ring round the hatch
        a = i * 2 * math.pi / 12
        d = (math.cos(a), 0, math.sin(a))
        p.obox((d[0] * 4.3, 3.05, d[2] * 4.3), (-d[2], 0, d[0]), (0, 1, 0), 1.9, 0.12, 0.6,
               "hazard" if i % 2 == 0 else "dark")
    # launch gantry and crane arm at the back left
    for dz in (-1.0, 1.0):
        for dx in (-1.0, 1.0):
            beam(p, (-7.0 + dx, 0.8, 1.5 + dz), (-7.0 + dx, 11.0, 1.5 + dz), 0.3, "paint")
    for y in (4.0, 7.5, 11.0):
        p.box((-7.0, y, 1.5), (2.4, 0.2, 2.4), "steel")
        p.box((-5.75, y, 1.5), (0.06, 0.16, 2.0), "light")
    beam(p, (-7.0, 11.0, 1.5), (-1.5, 11.6, 0.0), 0.35, "trim")
    p.box((-1.5, 10.6, 0.0), (0.2, 2.0, 0.2), "steel")
    p.box((-7.0, 11.4, 1.5), (0.4, 0.4, 0.4), "light")  # beacon
    # fuel tanks with gauges
    for x, z in ((6.4, 3.6), (4.2, 6.4)):
        p.cylinder("y", (x, 2.0, z), 1.2, 2.4, 12, "trim")
        p.box((x - 1.21, 2.0, z), (0.06, 1.2, 0.3), "dark")
        p.box((x - 1.23, 1.8, z), (0.04, 0.8, 0.18), "power")
    for i in range(8):  # pad edge lights
        a = i * 2 * math.pi / 8 + math.pi / 8
        p.box((math.cos(a) * 9.6, 0.82, math.sin(a) * 9.6), (1.0, 0.12, 1.0), "light")


def details_base(p):
    ring(p, (0, 0.801, 0), UP, 9.0)
    bolts(p, (-8.0, 0.801, -1.0), (8.0, 0.801, -1.0), 16, UP)


def build_hatch(p):
    p.cylinder("y", (0, 3.25, 0), 3.8, 0.5, 20, "steel")
    p.cylinder("y", (0, 3.52, 0), 1.2, 0.06, 16, "hazard")
    for k in range(4):
        a = k * math.pi / 4
        p.obox((0, 3.52, 0), (math.cos(a), 0, math.sin(a)), (0, 1, 0), 7.0, 0.3, 0.06, "trim")
    p.box((0, 3.4, 3.8), (2.4, 0.5, 0.6), "dark")  # hinge


def no_details(p):
    pass


unit.run(__file__, "chs_ragnarok", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("hatch", "base", HATCH, build_hatch, no_details)],
         attachments={"muzzle": {"parent": "base", "at": [0, 3.0, 0]}},
         team_pieces=["base"], budget=6000, tex=2048, preview_size=26)
