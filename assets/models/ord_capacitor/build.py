"""Capacitor Bank (Order energy storage, T1 structure, footprint 2; S-209):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_capacitor/build.py

After BAR's armestor, 16 x 16 studs and about 9.5 tall: an upright cell
stack, where the Depot is a low supply store. Big shapes first: a
chamfered slab; four armored feet with team plates; an octagonal core
whose stacked capacitor cells glow between chevron spacers; four heavy
corner pillars with team panels and lit edges holding the stack; a
capped top with a glowing charge port. Order reads heavy and clean
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec
TOP = 8.4  # the stack's top
CELLS = [2.1, 3.7, 5.3, 6.9]  # cell band bottoms


def band(p, outline, y0, y1, kind):
    """The side walls of a prism only (no caps): a glow band whose hidden
    top and bottom would only pad the glow area."""
    n = len(outline)
    v = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
    p._shell(v, [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)], kind)


def build_base(p):
    p.prism_y(octagon(7.8, 1.6), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.985)
    p.prism_y(octagon(4.6, 1.5), 0.6, 1.0, "dark", bevel=0.05)
    # four armored feet with team plates (front, back, sides)
    for d in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        n = V((d[0], 0, d[1]))
        t = V((-n.z, 0, n.x))
        c = n * 5.4
        p.obox((c.x, 1.1, c.z), tuple(n), UP, 3.6, 2.6, 1.0, "paint", bevel=0.1)
        p.obox((c.x + n.x * 0.8, 1.62, c.z + n.z * 0.8), tuple(n), UP, 1.6, 1.8, 0.05, "team")
        p.obox((c.x + n.x * 1.82, 1.1, c.z + n.z * 1.82), tuple(t), tuple(n), 1.8, 0.14, 0.05, "light")
    # the core and its glowing cells between chevron spacers
    p.prism_y(octagon(3.3, 1.0), 1.0, TOP, "dark", bevel=0.05)
    for y in CELLS:
        p.prism_y(octagon(3.6, 1.1), y, y + 0.3, "dark", bevel=0.02)
        band(p, octagon(3.75, 1.15), y + 0.3, y + 0.85, "power")
        p.prism_y(octagon(3.9, 1.2), y + 0.85, y + 1.3, "trim", bevel=0.05, top_scale=0.94)
    p.prism_y(octagon(3.9, 1.2), 1.0, CELLS[0], "paint", bevel=0.08)
    # four heavy corner pillars holding the stack
    for sx in (-1, 1):
        for sz in (-1, 1):
            n = V((sx, 0, sz)).normalized()
            t = V((-n.z, 0, n.x))
            c = n * 4.6
            p.obox((c.x, 0.6 + (TOP + 0.6) / 2, c.z), tuple(t), tuple(n), 2.5, TOP + 0.6, 1.8, "paint", bevel=0.14)
            p.obox((c.x + n.x * 0.92, 5.0, c.z + n.z * 0.92), tuple(t), tuple(n), 1.4, 5.2, 0.05, "team")
            for s in (-1, 1):
                q = c + n * 0.92 + t * (s * 1.0)
                p.obox((q.x, 5.0, q.z), tuple(t), tuple(n), 0.1, 6.4, 0.06, "light")
            # a sloped shoulder over the pillar top
            p.obox((c.x - n.x * 0.2, TOP + 0.95, c.z - n.z * 0.2), tuple(t), tuple((n * 0.5 + V(UP)).normalized()), 2.3, 1.6, 0.5, "trim", bevel=0.08)
    # the cap and the glowing charge port
    p.prism_y(octagon(4.1, 1.3), TOP, TOP + 0.6, "paint", bevel=0.1, top_scale=0.86)
    p.prism_y(octagon(2.6, 0.9), TOP + 0.6, TOP + 0.85, "trim", bevel=0.05)
    p.cylinder("y", (0, TOP + 0.92, 0), 1.6, 0.12, 16, "power")
    p.cylinder("y", (0, TOP + 1.0, 0), 0.9, 0.14, 12, "steel")
    hazard(p, (0, 0.62, -7.05), (1, 0, 0), UP, 5.0, 0.45, stripes=9)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.68, sz * 7.0), (0.35, 0.12, 0.35), "light")


def details_base(p):
    for d in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        n = V((d[0], 0, d[1]))
        t = V((-n.z, 0, n.x))
        a, b = n * 6.6 + t * 1.1, n * 6.6 - t * 1.1
        rivets(p, (a.x, 1.61, a.z), (b.x, 1.61, b.z), 4, UP)
    seam(p, (-2.4, TOP + 0.3, -3.92), (2.4, TOP + 0.3, -3.92), (0, 0, -1))


unit.run(__file__, "ord_capacitor", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-24, 20, -28), (0, 4.0, 0), 50),
                   ("80", (0, 40, 7), (0, 3.0, 0), 50),
                   ("close", (-12, 11, -14), (0, 5.0, 0), 35)])
