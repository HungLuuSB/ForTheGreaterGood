"""Advanced Sun Trap (Chaos solar, T1 structure, footprint 2; S-209): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advsolar/build.py

After BAR's coradvsol, 16 x 16 studs: a round collector bowl, low and wide
where the T1 Sun Trap is a field of loose panels. Big shapes first: a
skid slab; a heavy segmented armored rim ringed by eight bolted armor
pods (team-painted caps); inside it a sloped bowl of dark collector cells
falling to a turbine of slanted steel vanes round a raised hub with a
glowing core cap. Chaos reads rugged and improvised (M-14): patched and
missing cells, uneven pods, a cable to a junction box. Writes export/
through tools/unit.py.
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
SEG = 14  # rim segments
R_OUT, R_IN = 6.3, 5.3  # the rim
RIM_Y = 2.1
BOWL_IN, BOWL_Y = 2.3, 0.95  # the bowl's inner edge and its height there


def ring_pts(r, n, phase=0.0):
    return [(math.cos(2 * math.pi * (i + phase) / n) * r, math.sin(2 * math.pi * (i + phase) / n) * r) for i in range(n)]


def cone_band(p, r0, y0, r1, y1, n, kind):
    """An open sloped ring facing up (like fusion's hoop): outer edge r0 at
    y0, inner edge r1 at y1."""
    v = [(math.cos(2 * math.pi * i / n) * r0, y0, math.sin(2 * math.pi * i / n) * r0) for i in range(n)]
    v += [(math.cos(2 * math.pi * i / n) * r1, y1, math.sin(2 * math.pi * i / n) * r1) for i in range(n)]
    p._shell(v, [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)], kind)


def build_base(p):
    p.prism_y(octagon(7.8, 1.6), 0.0, 0.55, "dark", bevel=0.1, top_scale=0.985)
    # the rim: a sloped outer wall, an upright inner lip, a flat top
    p.prism_y(ring_pts(R_OUT + 0.5, SEG, 0.5), 0.55, 0.8, "trim", bevel=0.08, top_scale=0.96)
    for i in range(SEG):  # rim segments: slightly uneven armor blocks
        a0, a1 = 2 * math.pi * (i + 0.04) / SEG, 2 * math.pi * (i + 0.96) / SEG
        h = RIM_Y + (0.12 if i % 3 == 0 else 0.0)
        pts = [(math.cos(a0) * R_IN, math.sin(a0) * R_IN), (math.cos(a0) * R_OUT, math.sin(a0) * R_OUT),
               (math.cos(a1) * R_OUT, math.sin(a1) * R_OUT), (math.cos(a1) * R_IN, math.sin(a1) * R_IN)]
        p.prism_y(pts, 0.8, h, "paint", bevel=0.06, top_scale=0.94)
    # the bowl: rings of dark collector cells sloping down to the turbine
    rings = [(R_IN, RIM_Y - 0.15, 4.25, 1.75), (4.25, 1.75, 3.25, 1.35), (3.25, 1.35, BOWL_IN, BOWL_Y)]
    for k, (r0, y0, r1, y1) in enumerate(rings):
        n = SEG if k < 2 else 12
        for i in range(n):
            if (i * 5 + k * 3) % 11 == 7:
                continue  # a missing cell: the frame shows
            a = 2 * math.pi * (i + 0.5) / n
            d = V((math.cos(a), 0, math.sin(a)))
            t = V((-d.z, 0, d.x))
            c = V((d.x * (r0 + r1) / 2, (y0 + y1) / 2, d.z * (r0 + r1) / 2))
            slope = V((d.x * (r0 - r1), y0 - y1, d.z * (r0 - r1)))
            nrm = slope.cross(t).normalized()
            if nrm.y < 0:
                nrm = -nrm
            w = 2 * math.pi * (r0 + r1) / 2 / n
            p.obox(tuple(c), tuple(t), tuple(nrm), w - 0.12, slope.length - 0.1, 0.05, "glass")
        cone_band(p, r0, y0 - 0.05, r1, y1 - 0.05, n, "trim")  # the frame under the cells
    # turbine vanes round the hub, then the hub and its glowing cap
    p.cylinder("y", (0, BOWL_Y - 0.2, 0), BOWL_IN + 0.1, 0.3, 20, "dark")
    cone_band(p, BOWL_IN + 0.05, BOWL_Y + 0.02, BOWL_IN - 0.3, BOWL_Y - 0.03, 20, "power")  # a glowing ring round the turbine
    for i in range(14):
        a = 2 * math.pi * i / 14
        d = V((math.cos(a), 0, math.sin(a)))
        t = V((-d.z, 0, d.x))
        c = d * 1.75 + V((0, BOWL_Y + 0.1, 0))
        p.obox(tuple(c), tuple(d), tuple((t * 0.8 + V(UP) * 0.6).normalized()), 1.2, 0.5, 0.06, "steel")
    p.prism_y(ring_pts(1.25, 12), BOWL_Y - 0.1, BOWL_Y + 0.85, "paint", bevel=0.06, top_scale=0.85)
    p.cylinder("y", (0, BOWL_Y + 0.88, 0), 0.82, 0.08, 14, "team")
    p.cylinder("y", (0, BOWL_Y + 0.95, 0), 0.6, 0.12, 12, "power")
    # eight armor pods round the rim, team-painted caps, a little uneven
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8 + (0.05 if i % 2 else -0.04)
        d = V((math.cos(a), 0, math.sin(a)))
        t = V((-d.z, 0, d.x))
        c = d * (R_OUT + 0.55)
        s = 1.0 + (0.1 if i % 3 == 1 else 0.0)
        p.obox((c.x, 1.25 * s, c.z), tuple(t), tuple(d), 1.9 * s, 2.0 * s, 1.5, "paint", bevel=0.14)
        p.obox((c.x + d.x * 0.18, 2.35 * s, c.z + d.z * 0.18), tuple(t), UP, 1.6 * s, 1.1, 0.2, "team", bevel=0.05)
        p.obox((c.x + d.x * 0.77, 1.25 * s, c.z + d.z * 0.77), tuple(t), tuple(d), 1.2 * s, 0.7, 0.06, "team")
    # junction box at the back with an orange light, a cable into the rim
    p.prism_y(rect(0, 7.0, 1.1, 0.5), 0.55, 1.6, "trim", bevel=0.05)
    p.box((0, 1.1, 6.48), (1.4, 0.4, 0.05), "power")
    cable(p, [(0.6, 0.8, 6.5), (1.4, 0.7, 6.4), (2.2, 1.2, 6.0)], r=0.1)
    hazard(p, (0, 0.57, -7.25), (1, 0, 0), UP, 5.0, 0.4, stripes=9)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.62, sz * 7.0), (0.3, 0.15, 0.3), "light")


def details_base(p):
    for i in range(0, SEG, 2):
        a = 2 * math.pi * (i + 0.5) / SEG
        rivets(p, (math.cos(a) * (R_IN + 0.2), RIM_Y + 0.01, math.sin(a) * (R_IN + 0.2)),
               (math.cos(a) * (R_OUT - 0.2), RIM_Y + 0.01, math.sin(a) * (R_OUT - 0.2)), 2, UP)


unit.run(__file__, "chs_advsolar", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 1.5, 0), 50),
                   ("80", (0, 36, 6), (0, 1.0, 0), 50),
                   ("close", (-11, 9, -13), (0, 1.5, 0), 35)])
