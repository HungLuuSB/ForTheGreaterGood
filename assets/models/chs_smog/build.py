"""Smog (Chaos jammer tower, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_smog/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 6 tall), from its blockout. Big shapes first: a patched skid with
large team plates and hazard striping, a generator box with a hot vent, a
short lattice mast on four splayed legs with braces and amber beacons, and
the client-spun `spine` (spin Y, rig.md 9): a post with a ring of glowing
emitter rods on struts and a cap lamp. Chaos reads rugged, light and open
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP  # noqa: E402

V = lib.vec
SPINE = (0.0, 4.2, 0.0)


def beam(p, a, b, w, kind):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_y(octagon(3.85, 0.5), 0.0, 0.5, "dark", bevel=0.06, top_scale=0.985)
    for sz in (-1, 1):
        p.box((0, 0.53, sz * 2.9), (3.6, 0.05, 1.3), "team", bevel=0.012)
    hazard(p, (-2.95, 0.53, 0), (0, 0, 1), UP, 3.0, 0.45, stripes=7)
    p.box((2.6, 0.53, 0.4), (1.2, 0.04, 1.6), "steel", bevel=0.01)  # welded patch
    # generator box with a hot vent
    p.prism_y(rect(2.3, -1.9, 0.8, 0.7), 0.5, 1.6, "paint", bevel=0.05)
    p.box((2.3, 1.63, -1.9), (1.4, 0.04, 1.2), "team", bevel=0.01)
    p.box((2.3, 1.0, -2.62), (1.0, 0.3, 0.05), "power")
    cable(p, [(1.6, 1.2, -1.4), (0.8, 1.6, -0.8), (0.3, 2.4, -0.3)], r=0.08, kind="dark")
    # lattice mast: four splayed legs, rings, beacons
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(p, (sx * 1.6, 0.5, sz * 1.6), (sx * 0.5, 4.0, sz * 0.5), 0.24, "paint")
            p.box((sx * 1.6, 0.7, sz * 1.6), (0.55, 0.4, 0.55), "trim")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for y, f in ((1.8, 1.19), (3.2, 0.75)):
        for i, (sx, sz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, (sx * f, y, sz * f), (nx * f, y, nz * f), 0.1, "steel")
    for sx, sz in corners:
        p.box((sx * 0.98, 2.55, sz * 0.98), (0.3, 0.22, 0.3), "light")
    p.box((0, 4.05, 0), (1.3, 0.2, 1.3), "trim", bevel=0.03)

    with p.sub("spine", SPINE, "spin", (0, 1, 0)):
        p.cylinder("y", (0, 4.9, 0), 0.28, 1.6, 10, "paint")
        for k in range(6):
            a = k * math.pi / 3
            c, s = math.cos(a), math.sin(a)
            p.obox((c * 0.55, 5.3, s * 0.55), (c, 0, s), (0, 1, 0), 0.8, 0.12, 0.12, "steel")
            p.cylinder("y", (c * 0.95, 5.3, s * 0.95), 0.09, 0.9, 6, "power")
        p.cylinder("y", (0, 5.78, 0), 0.32, 0.12, 10, "trim")
        p.box((0, 5.95, 0), (0.24, 0.2, 0.24), "light")


def details_base(p):
    rivets(p, (-1.6, 0.531, -3.5), (1.6, 0.531, -3.5), 6, UP)


unit.run(__file__, "chs_smog", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-15, 13, -18), (0, 3.0, 0), 50),
                   ("80", (0, 28, 4), (0, 2, 0), 50),
                   ("close", (-7, 7, -9), (0, 3.5, 0), 40)])
