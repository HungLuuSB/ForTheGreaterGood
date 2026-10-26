"""Rookery (Chaos advanced rearm pad, T2 structure, footprint 4, two bays;
S-166): mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_rookery/build.py

From its approved blockout (2026-10-26): the Roost grown up. Big shapes
first: a patched dark slab with welded patches, a grated runway between
the bays and a hazard edge; two matte landing circles in team rings with
amber lamps round them; a scrap barricade along the back with a team
plate; three strapped fuel tanks with a team cap and a hose; a crane stub
with a jib and a hook over the left bay; a tall lattice light mast with a
glowing floodlight; a stack of ammo crates. Chaos reads crude and exposed
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

BAYS = (-7.6, 7.6)
BZ = -2.0


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(15.0, 2.6), 0.0, 0.8, "dark", bevel=0.1, top_scale=0.99)
    p.obox((-9.0, 0.82, 9.0), (0.99, 0, 0.14), UP, 8.0, 6.0, 0.06, "steel")
    p.obox((10.0, 0.82, -11.0), (0.99, 0, -0.1), UP, 6.0, 5.0, 0.06, "steel")
    p.box((0, 0.83, -2.0), (3.0, 0.06, 22.0), "grille")
    hazard(p, (0, 0.82, -14.4), (1, 0, 0), UP, 20.0, 0.6, stripes=32)
    for x in BAYS:
        p.cylinder("y", (x, 0.86, BZ), 6.4, 0.15, 36, "team")
        p.cylinder("y", (x, 0.9, BZ), 6.2, 0.2, 36, "trim")
        for dx in (-1.4, 1.4):
            p.box((x + dx, 1.03, BZ), (0.6, 0.04, 5.2), "paint")
        p.box((x, 1.03, BZ), (2.8, 0.04, 0.6), "paint")
        for a in (45, 135, 225, 315):
            r = math.radians(a)
            p.box((x + math.cos(r) * 6.9, 1.05, BZ + math.sin(r) * 6.9), (0.5, 0.4, 0.5), "light")
    # scrap barricade along the back, a team plate on it
    p.prism_x([(13.2, 0.8), (14.8, 0.8), (14.8, 1.4), (13.6, 3.0)], -13.5, -4.5, "paint", bevel=0.06)
    p.obox((1.0, 1.7, 14.2), (0.998, 0, -0.07), (0.07, 0, 0.998), 7.0, 1.8, 1.6, "paint", bevel=0.06)
    p.box((-9.0, 1.8, 13.15), (5.0, 1.2, 0.06), "team", bevel=0.01)
    # fuel tanks with straps, a team cap and a hose
    for x, z, r, h in ((11.6, 9.2, 1.3, 3.0), (11.6, 12.2, 1.3, 3.0), (8.8, 12.6, 1.1, 2.4)):
        p.cylinder("y", (x, 0.8 + h / 2, z), r, h, 14, "trim")
        p.cylinder("y", (x, 0.8 + h * 0.3, z), r + 0.06, 0.25, 14, "steel")
        p.cylinder("y", (x, 0.8 + h * 0.75, z), r + 0.06, 0.25, 14, "steel")
    p.cylinder("y", (11.6, 3.88, 9.2), 1.2, 0.15, 14, "team")
    cable(p, [(10.8, 1.2, 8.2), (10.4, 0.95, 5.0), (9.6, 0.95, 1.0), (8.8, 0.95, -0.4)], r=0.15, kind="dark")
    # crane stub over the left bay
    p.box((-14.0, 3.8, 5.0), (1.2, 6.0, 1.2), "paint", bevel=0.05)
    p.box((-11.4, 6.6, 5.0), (6.0, 0.6, 0.6), "trim")
    beam(p, (-14.0, 7.6, 5.0), (-9.0, 6.9, 5.0), 0.1, "steel")
    p.cylinder("y", (-8.8, 5.9, 5.0), 0.05, 1.4, 6, "steel")
    p.box((-8.8, 5.0, 5.0), (0.6, 0.6, 0.6), "dark", bevel=0.04)
    # the lattice light mast
    for dx in (-0.6, 0.6):
        for dz in (-0.6, 0.6):
            beam(p, (13.0 + dx, 0.8, -13.6 + dz), (13.0 + dx * 0.5, 9.6, -13.6 + dz * 0.5), 0.2, "dark")
    for y in (3.0, 6.0):
        beam(p, (12.4, y - 1.4, -14.2), (13.6, y + 1.4, -14.2), 0.1, "steel")
    p.box((13.0, 10.0, -13.6), (1.6, 0.6, 0.8), "dark", bevel=0.04)
    p.box((13.0, 10.0, -14.02), (1.4, 0.4, 0.04), "head")
    # ammo crates
    for x, y, z, a in ((-12.6, 1.4, 10.6, 0), (-12.6, 1.4, 12.0, 12), (-12.4, 2.6, 11.2, -8)):
        r = math.radians(a)
        p.obox((x, y, z), (math.cos(r), 0, math.sin(r)), UP, 1.6, 1.2, 1.2, "trim", bevel=0.04)


def details_base(p):
    for x in BAYS:
        ring(p, (x, 1.01, BZ), UP, 4.8)
    rivets(p, (-12.6, 0.81, 6.4), (-5.4, 0.81, 6.4), 8, UP)


unit.run(__file__, "chs_rookery", "chaos", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-40, 32, -48), (0, 3.0, 0), 50),
                   ("80", (0, 66, 10), (0, 2, 0), 50),
                   ("close", (-18, 14, -24), (0, 3.0, 0.0), 38)])
