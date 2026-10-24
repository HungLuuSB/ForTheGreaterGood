"""Veilspire (Order jammer tower, T2 structure, footprint 2): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_veilspire/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16
studs, about 24 tall), from its scaled blockout, and bigger and more
elaborate than the T1 Curtain, not a rescale. Big shapes first: a
chamfered slab, a sloped plinth with team plates on its four slopes,
diagonal buttresses, a tall tapered armored pylon with corner ribs, team
plates on its faces, a lit door and a ladder, an armored collar with running lights half way up, four
emitter fins on brackets near the top (glowing `power` inlays, the
blockout's fins) and a pointed cap with a beacon. The client-spun `band`
(spin Y, rig.md 9; the blockout's team band): a heavy collar ring round
the pylon with a raised team band and four emitter pods. Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, clamped_cable, louver  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

BAND = (0.0, 8.0, 0.0)  # the band's pivot (blockout band centre)
P0, P1 = 2.6, 20.4  # pylon bottom and top
H0, H1 = 2.2, 1.6  # pylon half widths at the bottom and top


def half(y):
    return H0 + (H1 - H0) * (y - P0) / (P1 - P0)


def diamond(cx, cz, r):
    return [(cx, cz - r), (cx + r, cz), (cx, cz + r), (cx - r, cz)]


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.5, "trim", bevel=0.1, top_scale=0.985)
    hazard(p, (0, 0.52, -7.35), (1, 0, 0), UP, 6.0, 0.4, stripes=12)
    p.prism_y(octagon(5.6, 1.4), 0.5, 1.5, "paint", bevel=0.12)
    p.prism_y(octagon(5.6, 1.4), 1.5, P0, "paint", bevel=0.12, top_scale=0.74)
    for nx, nz in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        u = (abs(nz), 0, abs(nx))
        p.obox((nx * 4.89, 2.06, nz * 4.89), u, (nx * 1.1, 1.46, nz * 1.1), 5.2, 1.3, 0.06, "team", bevel=0.015)
        p.box((nx * 5.62, 0.95, nz * 5.62), (abs(nz) * 3.4 + 0.05, 0.14, abs(nx) * 3.4 + 0.05), "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.prism_y(diamond(sx * 2.7, sz * 2.7, 1.0), P0 - 0.2, 6.2, "paint", bevel=0.08, top_scale=0.35)
            p.box((sx * 7.0, 0.56, sz * 7.0), (0.35, 0.12, 0.35), "light")
    # the tapered pylon, corner ribs with running light segments
    p.prism_y(rect(0, 0, H0, H0), P0, P1, "paint", bevel=0.1, top_scale=H1 / H0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = (sx * (H0 + 0.02), P0, sz * (H0 + 0.02))
            b = (sx * (H1 + 0.02), P1 - 0.3, sz * (H1 + 0.02))
            d = tuple(b[k] - a[k] for k in range(3))
            p.obox(tuple((a[k] + b[k]) / 2 for k in range(3)), (sx, 0, -sz), d, 0.36, 0.36, math.dist(a, b), "trim")
            for y0 in (10.4,):
                ya, yb = y0, y0 + 2.4
                c = (sx * (half((ya + yb) / 2) + 0.2), (ya + yb) / 2, sz * (half((ya + yb) / 2) + 0.2))
                p.obox(c, (sx, 0, -sz), d, 0.4, 0.08, 2.4, "light")
    # door with its light (front), ladder (back), vents and a conduit
    p.box((0, 3.9, -(half(3.9) + 0.03)), (1.6, 2.6, 0.06), "dark")
    p.box((0, 5.35, -(half(5.35) + 0.04)), (1.6, 0.14, 0.06), "light")
    for x in (-0.4, 0.4):
        p.box((x, 11.0, half(11.0) + 0.3), (0.08, 16.0, 0.08), "steel")
    for i in range(26):
        y = 3.4 + i * 0.6
        p.box((0, y, half(y) + 0.3), (0.8, 0.05, 0.05), "steel")
    for sx in (-1, 1):
        louver(p, (sx * (half(4.4) + 0.03), 4.4, 0), (0, 0, 1), (sx, 0, 0), 2.0, 1.4)
    clamped_cable(p, [(-1.6, P0, -1.4), (-(half(6.0) + 0.1), 6.0, -1.2), (-(half(13.0) + 0.1), 13.0, -1.0)], r=0.1)
    # team plates on the pylon's faces above the band
    k = (H1 - H0) / (P1 - P0)
    for nx, nz in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        u = (abs(nz), 0, abs(nx))
        r = half(10.3) + 0.03
        p.obox((nx * r, 10.3, nz * r), u, (nx, -k, nz), 2.0, 2.0, 0.05, "team", bevel=0.015)
    # armored collar with a running band (half way up)
    p.prism_y(octagon(half(12.4) + 0.45, 0.5), 11.9, 12.9, "trim", bevel=0.06)
    p.prism_y(octagon(half(12.4) + 0.47, 0.5), 12.32, 12.48, "light")
    # four emitter fins on brackets near the top, glowing inlays both sides
    for nx, nz in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        u = (abs(nz), 0, abs(nx))
        r = half(17.2)
        p.box((nx * (r + 0.6), 15.0, nz * (r + 0.6)), (abs(nz) * 0.9 + abs(nx) * 1.2 + 0.0, 0.8, abs(nx) * 0.9 + abs(nz) * 1.2), "trim")
        p.box((nx * (r + 0.6), 19.4, nz * (r + 0.6)), (abs(nz) * 0.9 + abs(nx) * 1.2, 0.8, abs(nx) * 0.9 + abs(nz) * 1.2), "trim")
        c = (nx * (r + 1.5), 17.2, nz * (r + 1.5))
        p.box(c, (abs(nx) * 2.8 + abs(nz) * 0.4, 6.0, abs(nz) * 2.8 + abs(nx) * 0.4), "paint", bevel=0.06)
        for side in (-1, 1):
            for t in (-0.7, 0.7):
                q = (c[0] + nz * side * 0.21 + nx * t, 17.2, c[2] + nx * side * 0.21 + nz * t)
                p.box(q, (abs(nz) * 0.05 + abs(nx) * 0.22, 5.0, abs(nx) * 0.05 + abs(nz) * 0.22), "power")
    # the pointed cap, a beacon and an antenna
    p.prism_y(rect(0, 0, H1 + 0.2, H1 + 0.2), P1, P1 + 0.5, "trim", bevel=0.06)
    p.prism_y(rect(0, 0, H1, H1), P1 + 0.5, 23.6, "paint", bevel=0.06, top_scale=0.18)
    p.box((0, 23.7, 0), (0.4, 0.3, 0.4), "light")
    antenna(p, (1.0, P1 + 0.5, 1.0), 2.6, r=0.05)


def details_base(p):
    for y in (6.6, 9.6, 14.4, 18.0):
        band_box(p, y, 0, 0, half(y) + 0.005, half(y) + 0.005)
    for sx in (-1, 1):
        rivets(p, (sx * 5.62, 0.75, -3.8), (sx * 5.62, 0.75, 3.8), 8, (sx, 0, 0))
    seam(p, (-1.2, 23.0, -0.3), (1.2, 23.0, -0.3), (0, 0.4, -1))


def build_base_and_band(p):
    build_base(p)
    with p.sub("band", BAND, "spin", (0, 1, 0)):
        r = half(BAND[1]) + 0.35
        p.prism_y(octagon(r + 0.4, 0.7), 7.2, 8.8, "trim", bevel=0.08)
        p.prism_y(octagon(r + 0.5, 0.7), 7.5, 8.5, "team", bevel=0.04)
        for k in range(4):
            a = math.radians(45 + 90 * k)
            c, s = math.cos(a), math.sin(a)
            d = (2 * (r + 0.5) - 0.7) / math.sqrt(2)  # the band's chamfer face
            p.ocyl((s * (d - 0.1), 8.0, c * (d - 0.1)), (s, 0, c), 0.42, 0.7, 10, "dark")
            p.ocyl((s * (d + 0.6), 8.0, c * (d + 0.6)), (s, 0, c), 0.3, 0.06, 10, "power")


def details_base_and_band(p):
    details_base(p)


unit.run(__file__, "ord_veilspire", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base_and_band, details_base_and_band)],
         budget=6000,
         previews=[("35", (-30, 26, -36), (0, 11.0, 0), 50),
                   ("80", (0, 60, 9), (0, 8, 0), 50),
                   ("close", (-14, 16, -17), (0, 13.0, 0), 45)])
