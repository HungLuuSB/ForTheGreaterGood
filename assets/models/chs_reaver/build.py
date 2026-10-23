"""Reaver (Chaos advanced naval worker, T2 ship): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_reaver/build.py

New mesh from its blockout, the Wrecker's hull at the T2 small-ship size
(size-scale.md: about 1.3x, ~14 long): a narrow salvage hull with a dark
waterline band, a team plate on the stern deck and the bridge, a lattice
deck crane forward with a hook, a scrap bin with hazard striping, a squat
bridge with an amber slit, a funnel with a hot band, tyre fenders, amber
gunwale strips; the `nano` turret aft with two build arms, fore and aft,
each with an emitter (power; `nano1`, `nano2`). Model space, waterline at
y = 0. Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

V = lib.vec
NANO = (0.0, 1.95, 3.6)
ARMS = [((-0.5, 2.3, 3.6), (-0.5, 4.2, 1.2)), ((0.5, 2.3, 3.6), (0.5, 3.8, 5.8))]


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_x([(-8.6, 1.7), (-6.0, -0.6), (6.0, -0.6), (6.0, 1.7)], -2.1, 2.1, "paint", bevel=0.06)
    p.prism_x([(-7.8, 0.0), (-5.7, -0.45), (6.05, -0.45), (6.05, 0.0)], -2.17, 2.17, "dark", bevel=0.02)
    p.box((0, 1.73, 5.2), (3.2, 0.05, 1.4), "team", bevel=0.012)
    # scrap bin with hazard striping
    p.box((0, 2.1, -3.2), (2.6, 0.8, 2.2), "trim", bevel=0.04)
    hazard(p, (0, 2.1, -4.32), (1, 0, 0), (0, 0, -1), 2.4, 0.4, stripes=6)
    # lattice deck crane forward with a hook
    for dx in (-0.25, 0.25):
        for dz in (-0.25, 0.25):
            p.box((1.3 + dx, 2.8, -5.6 + dz), (0.1, 2.2, 0.1), "steel")
    beam(p, (1.3, 3.9, -5.6), (0.0, 4.6, -7.6), 0.25, "paint")
    p.cylinder("y", (0.0, 3.8, -7.6), 0.03, 1.4, 6, "steel")
    p.box((0.0, 3.0, -7.6), (0.3, 0.3, 0.3), "dark")
    # squat bridge, amber slit, team roof, funnel with a hot band
    p.box((0, 2.45, 0.2), (2.6, 1.5, 2.4), "paint", bevel=0.05)
    p.box((0, 2.85, -1.02), (2.0, 0.28, 0.05), "light")
    p.box((0, 3.23, 0.2), (2.1, 0.05, 1.8), "team", bevel=0.01)
    p.cylinder("y", (0.7, 3.9, 1.8), 0.6, 2.0, 12, "trim")
    p.cylinder("y", (0.7, 4.65, 1.8), 0.62, 0.2, 12, "light")
    for sx in (-1, 1):
        p.box((sx * 2.13, 1.45, 0.0), (0.05, 0.16, 8.0), "light")
        for z in (-4.0, 0.8, 3.6):
            p.ocyl((sx * 2.2, 0.9, z), (sx, 0, 0), 0.45, 0.3, 10, "rubber")  # tyre fenders
    p.box((0, 0.9, 6.07), (3.4, 0.24, 0.05), "light")


def details_base(p):
    bolts(p, (-1.8, 1.701, -1.8), (1.8, 1.701, -1.8), 7, UP)
    ring(p, (0.7, 4.901, 1.8), UP, 0.45)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 1.0, 0.5, 12, "trim")
    for a, b in ARMS:
        a, b = V(a), V(b)
        p.obox(tuple((a + b) / 2), tuple(b - a), (1, 0, 0), (b - a).length, 0.35, 0.35, "steel")
        p.cylinder("y", (b.x, b.y - 0.1, b.z), 0.42, 0.5, 10, "dark")
        p.cylinder("y", (b.x, b.y - 0.38, b.z), 0.34, 0.06, 10, "power")


def no_details(p):
    pass


unit.run(__file__, "chs_reaver", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)])
