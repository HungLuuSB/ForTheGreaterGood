"""Listener (Chaos sonar buoy, T1 structure, footprint 1, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_listener/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 4 above the water), from its blockout. The waterline is y = 0. Big
shapes first: two strapped drum floats under an open deck frame with team
plates and hazard striping, a sonar drum hung between them on a frame with
a glowing band (`drum`, turn Y, rig.md 9), a stub lattice post with an
amber lamp, a battery crate and a cable. Chaos reads rugged, light and open
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, rivets  # noqa: E402
from unit import UP  # noqa: E402

V = lib.vec


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    for sx in (-1, 1):
        drum(p, (sx * 2.6, 0.1, 0), 1.15, 7.2, "paint", "trim", sides=14, axis="z")
        for z in (-2.2, 2.2):
            p.cylinder("z", (sx * 2.6, 0.1, z), 1.19, 0.2, 14, "dark")
        p.box((sx * 2.6, 1.42, 0), (1.6, 0.18, 6.6), "trim", bevel=0.03)  # deck rails on the floats
        p.box((sx * 2.6, 1.53, 1.9), (1.4, 0.05, 2.4), "team", bevel=0.01)
    for z in (-2.6, 2.6):  # cross beams of the open deck
        p.box((0, 1.4, z), (4.2, 0.25, 0.6), "steel")
    hazard(p, (-2.6, 1.53, -2.2), (0, 0, 1), UP, 2.2, 0.5, stripes=5)
    # the drum's hanging frame
    for sx in (-1, 1):
        beam(p, (sx * 1.9, 1.4, 0), (sx * 0.4, 3.0, 0), 0.18, "steel")
    p.box((0, 3.05, 0), (1.2, 0.25, 0.5), "trim")
    # stub lattice post with an amber lamp, a battery crate, a cable
    for dx in (-0.25, 0.25):
        p.box((2.6 + dx, 2.6, -2.5), (0.1, 2.2, 0.1), "steel")
    p.box((2.6, 3.8, -2.5), (0.3, 0.2, 0.3), "light")
    p.box((-2.6, 1.95, 2.2), (0.9, 0.7, 0.8), "trim", bevel=0.04)
    p.box((-2.6, 1.95, 1.78), (0.6, 0.2, 0.05), "power")
    cable(p, [(-2.2, 2.1, 1.9), (-1.0, 2.6, 1.0), (-0.3, 2.95, 0.2)], r=0.07, kind="dark")

    with p.sub("drum", (0.0, 1.4, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 2.5, 0), 0.12, 1.0, 6, "steel")
        p.cylinder("y", (0, 1.3, 0), 1.25, 1.6, 16, "paint", bevel=0.04)
        p.cylinder("y", (0, 1.75, 0), 1.29, 0.24, 16, "power")
        for k in range(4):
            import math
            a = k * math.pi / 2
            p.box((1.3 * math.cos(a), 1.0, 1.3 * math.sin(a)), (0.3, 0.6, 0.3), "dark")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.6 - 0.6, 1.511, -3.0), (sx * 2.6 - 0.6, 1.511, 0.4), 5, UP)


unit.run(__file__, "chs_listener", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 1.5, 0), 50),
                   ("80", (0, 26, 4), (0, 1, 0), 50),
                   ("close", (-7, 6, -9), (0, 1.5, 0), 40)])
