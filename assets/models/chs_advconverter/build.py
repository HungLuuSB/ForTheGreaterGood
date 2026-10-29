"""Great Smelter (Chaos T2 converter, footprint 3; S-209, BAR's cormmkr):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advconverter/build.py

24 x 24 studs, about 9 tall: the T1 Smelter's furnace grown into a
fortified octagonal kiln, as BAR's cormmkr. Big shapes first: a patched
skid slab with hazard striping; a dark octagonal lower housing under a
sloped armored ring with team plates on its flanks and back; on top a ring
of glowing furnace panels round a grilled flue cap (`crucible`, pulse,
rig.md 9); a big armored charging hatch sloping down to the pad at the
front over a glowing mouth; thick corrugated hoses either side down to
anchor blocks; slag ingots, beacons. Chaos reads rugged and improvised
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec
Y0 = 0.6
H1, H2, H3 = 3.4, 6.0, 7.4  # tops of the housing, the sloped ring, the furnace ring


def hose(p, a, c, b, r, segs=12):
    """A corrugated hose along a quadratic curve a -> c -> b."""
    a, c, b = V(a), V(c), V(b)
    pts = [a * (1 - t) ** 2 + c * (2 * t * (1 - t)) + b * t * t for t in (i / segs for i in range(segs + 1))]
    for i in range(segs):
        d = pts[i + 1] - pts[i]
        p.ocyl(tuple(pts[i]), tuple(d), r, d.length, 10, "rubber")
        p.ocyl(tuple(pts[i] + d * 0.3), tuple(d), r * 1.18, d.length * 0.4, 10, "rubber")
    for q in (a, b):
        p.box(tuple(q), (r * 2.8, r * 2.8, r * 2.8), "steel", bevel=0.05)


def facets(p, r, cut, y0, y1, scale0, scale1, kind, inset, t=0.05, skip=()):
    """Plates on the faces of an octagonal frustum (r, cut at y0 scaled by
    scale0 to scale1 at y1), inset from the edges."""
    pts = octagon(r, cut)
    out = []
    for i in range(8):
        if i in skip:
            continue
        a, b = V((pts[i][0], 0, pts[i][1])), V((pts[(i + 1) % 8][0], 0, pts[(i + 1) % 8][1]))
        lo0, lo1, hi0, hi1 = a * scale0, b * scale0, a * scale1, b * scale1
        lo0.y = lo1.y = y0
        hi0.y = hi1.y = y1
        cen = (lo0 + lo1 + hi0 + hi1) / 4
        u = (lo1 - lo0).normalized()
        up = ((hi0 + hi1) / 2 - (lo0 + lo1) / 2)
        n = u.cross(up).normalized()
        if n.dot(V((cen.x, 0, cen.z))) < 0:
            n = -n
        out.append((cen, u, n, (lo1 - lo0).length * inset, up.length * inset))
    for cen, u, n, w, h in out:
        p.obox(tuple(cen + n * (t / 2)), tuple(u), tuple(n), w, h, t, kind, bevel=0.012)


def build_base(p):
    p.prism_y(octagon(11.7, 1.0), 0.0, Y0, "dark", bevel=0.1, top_scale=0.985)
    hazard(p, (0, Y0 + 0.03, -11.0), (1, 0, 0), UP, 7.0, 0.45, stripes=12)
    p.box((8.0, Y0 + 0.03, 8.0), (3.4, 0.04, 3.0), "trim", bevel=0.01)  # welded patch
    # dark octagonal housing, the sloped armored ring, its team plates
    p.prism_y(octagon(8.4, 2.6), Y0, H1, "trim", bevel=0.14)
    p.prism_y(octagon(9.0, 2.8), H1, H1 + 0.5, "paint", bevel=0.1)
    p.prism_y(octagon(9.0, 2.8), H1 + 0.5, H2, "paint", bevel=0.14, top_scale=0.72)
    s1 = 0.72
    facets(p, 9.0, 2.8, H1 + 0.5, H2, 1.0, s1, "team", 0.7, skip=(0,))
    # vents round the housing
    for i, (x, z, nx, nz) in enumerate(((-8.42, 0, -1, 0), (8.42, 0, 1, 0), (0, 8.42, 0, 1))):
        p.obox((x, 2.0, z), (nz, 0, -nx), (nx, 0, nz), 3.0, 1.2, 0.05, "grille")
        p.obox((x + nx * 0.03, 2.9, z + nz * 0.03), (nz, 0, -nx), (nx, 0, nz), 3.0, 0.18, 0.05, "power")
    # the charging hatch at the front: a sloped armored lid over a glowing mouth
    p.prism_x([(-7.6, Y0), (-11.2, Y0), (-11.2, Y0 + 0.8), (-7.6, H1 + 0.4)], -3.4, 3.4, "paint", bevel=0.12)
    slope = V((0, H1 + 0.4 - (Y0 + 0.8), 3.6)).normalized()  # up the lid
    lid_n = V((0, slope.z, -slope.y))
    lid_c = V((0, (Y0 + 0.8 + H1 + 0.4) / 2, -9.4))
    for k in range(5):
        q = lid_c + slope * (-1.6 + k * 0.8) + lid_n * 0.06
        p.obox(tuple(q), (1, 0, 0), tuple(lid_n), 5.6, 0.5, 0.12, "trim", bevel=0.03)
    for sx in (-1, 1):
        p.obox(tuple(lid_c + V((sx * 3.25, 0, 0)) + lid_n * 0.15), tuple(slope), tuple(lid_n), 4.9, 0.4, 0.3, "steel")
    p.box((0, Y0 + 0.4, -11.22), (5.4, 0.5, 0.05), "power")  # the mouth under the lid's lip
    # thick corrugated hoses either side down to anchor blocks
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = (sx * 7.0, 4.6, sz * 3.6)
            b = (sx * 10.4, Y0 + 0.6, sz * 6.4)
            hose(p, a, (sx * 10.8, 5.2, sz * 4.4), b, 0.42)
            p.prism_y([(sx * 10.4 - 1.1, sz * 6.4 - 1.1), (sx * 10.4 + 1.1, sz * 6.4 - 1.1),
                       (sx * 10.4 + 1.1, sz * 6.4 + 1.1), (sx * 10.4 - 1.1, sz * 6.4 + 1.1)], Y0, Y0 + 0.9, "trim", bevel=0.08, top_scale=0.8)
    # slag ingots and beacons
    for x, z in ((6.2, -9.6), (7.0, -9.0), (6.6, -10.3)):
        p.box((x, Y0 + 0.22, z), (0.9, 0.44, 0.55), "dark", bevel=0.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.8, Y0 + 0.1, sz * 10.8), (0.4, 0.2, 0.4), "light")

    # the furnace crown: glowing panels round a grilled flue cap
    with p.sub("crucible", (0.0, H2, 0.0), "pulse", (0, 1, 0)):
        r2 = 9.0 * s1
        p.prism_y(octagon(r2 - 0.4, 2.8 * s1 - 0.1), H2, H3, "dark", bevel=0.1, top_scale=0.86)
        facets(p, r2 - 0.4, 2.8 * s1 - 0.1, H2, H3, 1.0, 0.86, "power", 0.72)
        p.prism_y(octagon((r2 - 0.4) * 0.86, (2.8 * s1 - 0.1) * 0.86), H3, H3 + 0.25, "trim", bevel=0.06)
        p.prism_y(octagon((r2 - 0.4) * 0.66, (2.8 * s1 - 0.1) * 0.66), H3 + 0.25, H3 + 0.32, "grille")


def details_base(p):
    rivets(p, (-8.42, 1.0, -3.0), (-8.42, 1.0, 3.0), 7, (-1, 0, 0))
    rivets(p, (8.42, 1.0, -3.0), (8.42, 1.0, 3.0), 7, (1, 0, 0))
    ring(p, (0, H3 + 0.33, 0), UP, 2.6)


unit.run(__file__, "chs_advconverter", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-33, 26, -39), (0, 4.0, 0), 50),
                   ("80", (0, 56, 9), (0, 3, 0), 50),
                   ("close", (-16, 14, -20), (0, 4.5, -2.0), 40)])
