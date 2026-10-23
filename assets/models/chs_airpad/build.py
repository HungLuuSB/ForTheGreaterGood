"""Roost (Chaos rearm pad, T1 structure, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_airpad/build.py

New mesh in the size-scale style (S-104, M-26: footprint 3, 24 x 24
studs, low: about 6 tall at the light mast), from its blockout. Big shapes
first: a patched dark slab with grated sections, a landing circle ringed
in team color with marks, hazard striping and amber edge lights; two
strapped fuel tanks with team caps, amber gauges and a hose to the pad;
ammo crates and a rearm crane stub; a lattice light mast with an amber
lamp. Chaos reads rugged, light and open (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(11.6, 1.0), 0.0, 0.5, "dark", bevel=0.08, top_scale=0.99)
    for x, z, w, d in ((-8.5, -8.5, 5.0, 4.0), (8.5, 8.0, 4.0, 5.0), (-9.0, 6.0, 3.0, 4.0)):
        p.box((x, 0.52, z), (w, 0.04, d), "trim", bevel=0.01)  # patch plates
    p.box((0, 0.52, 9.8), (8.0, 0.04, 2.6), "grille")
    # landing circle: team ring, dark deck, marks, amber edge lights
    p.cylinder("y", (0, 0.58, 0), 7.4, 0.16, 32, "team")
    p.cylinder("y", (0, 0.62, 0), 6.9, 0.2, 32, "rubber")
    for dx in (-1.8, 1.8):
        p.box((dx, 0.74, 0), (0.7, 0.04, 6.0), "trim")
    p.box((0, 0.74, 0), (3.6, 0.04, 0.7), "trim")
    for k in range(8):
        a = k * math.pi / 4
        c, s = math.cos(a), math.sin(a)
        p.box((c * 7.7, 0.7, s * 7.7), (0.35, 0.24, 0.35), "light")
    hazard(p, (0, 0.53, -8.8), (1, 0, 0), UP, 8.0, 0.6, stripes=14)
    # fuel tanks with team caps and gauges, a hose to the pad
    for z in (-8.2, -4.8):
        p.cylinder("y", (8.8, 1.85, z), 1.35, 2.7, 16, "paint", bevel=0.05)
        p.ocyl((8.8, 3.2, z), UP, 1.35, 0.35, 16, "trim", radius2=1.0)
        p.cylinder("y", (8.8, 3.58, z), 0.95, 0.05, 14, "team")
        for y in (1.0, 2.4):
            p.cylinder("y", (8.8, y, z), 1.39, 0.16, 16, "dark")
        p.box((7.43, 1.7, z), (0.05, 1.1, 0.35), "power")
    cable(p, [(7.5, 0.9, -6.5), (6.2, 0.7, -5.0), (5.4, 0.8, -3.6)], r=0.14, kind="dark")
    # ammo crates and a rearm crane stub on the left
    for x, z, s in ((-9.0, -2.0, 1.4), (-9.2, -0.4, 1.2), (-7.8, -1.2, 1.0)):
        p.box((x, 0.5 + s / 2, z), (s, s, s), "trim", bevel=0.05)
    p.box((-9.4, 2.0, 1.6), (0.35, 3.0, 0.35), "steel")
    p.box((-8.2, 3.45, 1.6), (2.8, 0.25, 0.25), "steel")
    cable(p, [(-6.9, 3.4, 1.6), (-6.9, 2.4, 1.6)], r=0.03, kind="steel")
    p.box((-6.9, 2.25, 1.6), (0.4, 0.3, 0.4), "dark")
    # lattice light mast with an amber lamp
    for dx in (-0.35, 0.35):
        for dz in (-0.35, 0.35):
            beam(p, (-9.6 + dx * 1.6, 0.5, 9.6 + dz * 1.6), (-9.6 + dx, 5.8, 9.6 + dz), 0.12, "paint")
    for y in (2.0, 4.0):
        p.box((-9.6, y, 9.6), (0.9, 0.08, 0.9), "steel")
    p.box((-9.6, 6.0, 9.6), (0.6, 0.35, 0.6), "light")


def details_base(p):
    rivets(p, (-10.5, 0.541, -10.0), (-6.5, 0.541, -10.0), 6, UP)
    for z in (-8.2, -4.8):
        ring(p, (8.8, 3.55, z), UP, 0.8)


unit.run(__file__, "chs_airpad", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-30, 22, -36), (0, 1.5, 0), 50),
                   ("80", (0, 52, 8), (0, 1, 0), 50),
                   ("close", (-15, 11, -18), (-2.0, 2.0, 0), 40)])
