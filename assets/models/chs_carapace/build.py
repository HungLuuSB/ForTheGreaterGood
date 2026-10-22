"""Carapace (Chaos shield generator, T2 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_carapace/build.py

A skid platform with a round pad and a glowing coil ring (power channel),
team plates at two corners, two tanks piped to the coil, and a tripod cage
round an exposed `core` (the def's piece): a glowing faceted orb (power
channel) whose top carries the `beam` attachment, where the client's shield
beam starts (docs/contracts/fx.md; BAR style, M-15; Chaos reads light and
open, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y([(-6.5, -6.5), (6.5, -6.5), (6.5, 6.5), (-6.5, 6.5)], 0.0, 0.8, "dark", bevel=0.04)
    p.cylinder("y", (0, 1.1, 0), 4.0, 0.6, 18, "paint")
    p.cylinder("y", (0, 1.8, 0), 2.8, 0.8, 18, "steel")
    p.cylinder("y", (0, 2.0, 0), 2.9, 0.22, 18, "power", cap_kinds=("steel", "steel"))  # coil glow
    p.cylinder("y", (0, 2.35, 0), 2.2, 0.1, 18, "dark")
    for x, z in ((-4.2, 5.2), (4.2, -5.2)):
        p.box((x, 0.84, z), (3.2, 0.05, 1.6), "team", bevel=0.01)
    for x, z in ((5.0, 4.6), (-5.0, -4.6)):  # tanks and pipes to the coil
        p.cylinder("y", (x, 2.1, z), 1.0, 2.6, 12, "trim")
        p.cylinder("y", (x, 3.45, z), 0.7, 0.1, 10, "steel")
        p.box((x - math.copysign(1.0, x), 2.0, z), (0.06, 1.2, 0.3), "power")
        beam(p, (x * 0.8, 1.0, z * 0.8), (x * 0.5, 1.4, z * 0.5), 0.35, "dark")
    for i in range(3):  # tripod legs, cage rings and bars
        a = math.pi / 2 + i * 2 * math.pi / 3
        ox, oz = math.cos(a), math.sin(a)
        beam(p, (ox * 3.4, 1.4, oz * 3.4), (ox * 1.6, 8.3, oz * 1.6), 0.3, "paint")
        beam(p, (ox * 1.5, 4.9, oz * 1.5), (ox * 1.5, 7.9, oz * 1.5), 0.15, "steel")
        p.box((ox * 3.4, 1.55, oz * 3.4), (0.6, 0.3, 0.6), "trim")
        p.box((ox * 2.5, 4.9, oz * 2.5), (0.3, 0.3, 0.3), "light")
    for y in (4.9, 7.9):
        p.cylinder("y", (0, y, 0), 1.6, 0.18, 14, "trim", cap_kinds=("trim", "trim"))
    for sx in (-1, 1):  # skid edge lights, all four sides
        p.box((sx * 6.45, 0.4, 0), (0.06, 0.2, 6.0), "light")
        p.box((0, 0.4, sx * 6.45), (6.0, 0.2, 0.06), "light")


def details_base(p):
    ring(p, (0, 1.401, 0), UP, 3.5)
    bolts(p, (-6.1, 0.801, -6.1), (6.1, 0.801, -6.1), 10, UP)
    bolts(p, (-6.1, 0.801, 6.1), (6.1, 0.801, 6.1), 10, UP)


def build_core(p):
    p.cylinder("y", (0, 5.85, 0), 1.1, 1.1, 10, "power", radius2=0.25 * 1.1)  # lower half of the orb
    p.cylinder("y", (0, 6.95, 0), 0.25 * 1.1, 1.1, 10, "power", radius2=1.1)  # reversed: upper half
    p.cylinder("y", (0, 6.4, 0), 1.15, 0.12, 10, "steel")
    p.cylinder("y", (0, 7.55, 0), 0.4, 0.1, 8, "trim")


def details_core(p):
    pass


unit.run(__file__, "chs_carapace", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("core", "base", (0.0, 5.3, 0.0), build_core, details_core)],
         attachments={"beam": {"parent": "core", "at": [0, 7.6, 0]}},
         budget=6000, tex=1024)
