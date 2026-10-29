"""Great Accumulator (Chaos hardened power storage, T2, footprint 3;
S-209, BAR's coruwadves): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advaccumulator/build.py

24 x 24 studs, about 9 tall: the Accumulator grown into a fortified cell
bunker, as BAR's coruwadves. Big shapes first: a skid slab; an octagonal
bunker ring of riveted armor blocks, each with a tall glowing charge cell
in its face (all the glow in `cells`, pulse, rig.md 9: the charge reads
from far), a sloped shoulder ring; four heavy team-colored buttresses on the diagonals climbing to the crown; an
armored dome with a glowing cross under four hatch plates; hazard
striping, beacons. Power storage reads as glowing cells, supply storage
(chs_advdepot) as sealed tanks. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec
Y0 = 0.6
R1, C1 = 8.8, 3.0  # the bunker ring's octagon
H1, H2, H3 = 4.4, 5.6, 8.2  # tops of the ring, the shoulder, the dome


def fin(p, d, profile, thick, kind, bevel=0.1):
    """A plate whose (radial, y) profile runs out along d, thick across it."""
    d = V(d).normalized()
    t = V((-d.z, 0, d.x))
    n = len(profile)
    v = [tuple(d * r + V((0, y, 0)) + t * s * thick / 2) for s in (-1, 1) for r, y in profile]
    f = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    p._shell(v, f, kind, bevel)


def faces(r, cut):
    """The octagon's 8 faces: (centre x, z, outward normal, width)."""
    pts = octagon(r, cut)
    out = []
    for i in range(8):
        a, b = V((pts[i][0], 0, pts[i][1])), V((pts[(i + 1) % 8][0], 0, pts[(i + 1) % 8][1]))
        c = (a + b) / 2
        out.append((c, V((c.x, 0, c.z)).normalized(), (b - a).length))
    return out


def build_base(p):
    p.prism_y(octagon(11.7, 1.0), 0.0, Y0, "dark", bevel=0.1, top_scale=0.985)
    hazard(p, (0, Y0 + 0.03, -11.1), (1, 0, 0), UP, 6.0, 0.45, stripes=11)
    # the bunker ring of armor blocks
    p.prism_y(octagon(R1 - 0.6, C1), Y0, H1, "trim", bevel=0.12)
    for c, n, w in faces(R1 - 0.6, C1):
        u = V((-n.z, 0, n.x))
        for k in (-1, 0, 1):
            q = c + u * (k * w / 3.1) + n * 0.45
            p.obox(tuple(V((q.x, (Y0 + H1) / 2, q.z))), tuple(u), tuple(n), w / 3.4, H1 - Y0 - 0.2, 0.9, "paint", bevel=0.1)
            p.obox(tuple(V((q.x, (Y0 + H1) / 2 + 0.2, q.z)) + n * 0.47), tuple(u), tuple(n), w / 3.4 - 0.6, H1 - Y0 - 1.6, 0.05, "dark")
    # the sloped shoulder and the dome
    p.prism_y(octagon(R1, C1), H1, H1 + 0.3, "paint", bevel=0.08)
    p.prism_y(octagon(R1, C1), H1 + 0.3, H2, "trim", bevel=0.12, top_scale=0.7)
    p.prism_y(octagon(R1 * 0.7, C1 * 0.7), H2, H2 + 1.2, "paint", bevel=0.14)
    p.prism_y(octagon(R1 * 0.7, C1 * 0.7), H2 + 1.2, H3, "paint", bevel=0.14, top_scale=0.62)
    for c, n, w in faces(R1 * 0.7, C1 * 0.7):
        p.box(tuple(c + n * 0.03 + V((0, H2 + 0.6, 0))), (abs(n.z) * w * 0.6 + 0.05, 0.3, abs(n.x) * w * 0.6 + 0.05), "team")
    # four team buttresses on the diagonals, climbing to the crown
    for sx in (-1, 1):
        for sz in (-1, 1):
            d = (sx, 0, sz)
            fin(p, d, [(5.4, Y0), (12.4, Y0), (12.4, Y0 + 1.4), (10.8, H1 + 0.8), (7.2, H2 + 1.6), (5.4, H2 + 1.6)], 2.4, "team", bevel=0.12)
            dn = V(d).normalized()
            t = V((-dn.z, 0, dn.x))
            for s in (-1, 1):
                p.obox(tuple(dn * 9.6 + V((0, 2.4, 0)) + t * s * 1.23), tuple(dn), tuple(t * s), 3.0, 0.9, 0.05, "dark", bevel=0.012)
            p.obox(tuple(dn * 12.2 + V((0, Y0 + 0.5, 0))), tuple(t), tuple(dn), 1.6, 0.6, 0.6, "steel", bevel=0.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, Y0 + 0.1, sz * 11.0), (0.4, 0.2, 0.4), "light")

    # charge cells: a glowing cell in each armor block, the dome's cross
    with p.sub("cells", (0.0, Y0, 0.0), "pulse", (0, 1, 0)):
        for c, n, w in faces(R1 - 0.6, C1):
            u = V((-n.z, 0, n.x))
            for k in (-1, 0, 1):
                q = c + u * (k * w / 3.1) + n * 0.96
                p.obox(tuple(V((q.x, (Y0 + H1) / 2 + 0.2, q.z))), tuple(u), tuple(n), w / 3.4 - 0.9, H1 - Y0 - 1.9, 0.06, "power")
        top = R1 * 0.7 * 0.62
        for ax in ((1, 0, 0), (0, 0, 1)):
            p.box((0, H3 + 0.04, 0), (top * 1.7 if ax[0] else 0.9, 0.08, top * 1.7 if ax[2] else 0.9), "power")
        for sx in (-1, 1):
            for sz in (-1, 1):
                p.box((sx * top * 0.42, H3 + 0.12, sz * top * 0.42), (top * 0.62, 0.22, top * 0.62), "trim", bevel=0.05)


def details_base(p):
    ring(p, (0, H3 + 0.01, 0), UP, R1 * 0.7 * 0.62 * 0.95)
    for c, n, w in faces(R1, C1)[::2]:
        u = V((-n.z, 0, n.x))
        rivets(p, tuple(c - u * w * 0.4 + V((0, H1 + 0.32, 0))), tuple(c + u * w * 0.4 + V((0, H1 + 0.32, 0))), 6, UP)


unit.run(__file__, "chs_advaccumulator", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-33, 26, -39), (0, 4.0, 0), 50),
                   ("80", (0, 56, 9), (0, 3, 0), 50),
                   ("close", (-16, 14, -20), (0, 4.5, -2.0), 40)])
