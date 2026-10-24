"""Fusion Reactor (Order power plant, T2 structure, footprint 4): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_fusion/build.py

New mesh at the size scale (S-104, M-26: footprint 4, 32 x 32 studs, about
16 tall), from its blockout; the T1 Generator's big brother, not a rescale.
Big readable shapes first: a thick chamfered slab, a stepped armored block
(two tiers with sloped walls) with large team plates on the lower deck, four
heat-exchanger towers on the deck corners with team bands and glowing vents,
cabled to the upper tier; on the roof a pedestal and a cradle holding the
glowing containment sphere (`core`, pulse, rig.md 9) inside a ribbed cage
and an armored equator ring, held by two clamp columns and a top bar with a
team plate and field emitters, four field coils on the roof diagonals; an
armored door bay with build lights, a walkway and hazard striping at the
front, glowing vents and running strips on the walls, corner lights. Order
reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
T1, T2 = 3.6, 7.2  # tops of the lower and upper tier
CORE = (0.0, 11.0, 0.0)  # sphere centre
R_CORE = 2.9
POST_X = 5.4


def hoop(p, center, r_out, r_in, h, sides, kind):
    """An open ring band about Y (no caps over the hole): glow bands that
    show only where they're seen."""
    cx, cy, cz = center
    v = []
    for r, y in ((r_out, cy - h / 2), (r_out, cy + h / 2), (r_in, cy - h / 2), (r_in, cy + h / 2)):
        for i in range(sides):
            t = 2 * math.pi * i / sides
            v.append((cx + math.cos(t) * r, y, cz + math.sin(t) * r))
    n = sides
    f = []
    for i in range(n):
        j = (i + 1) % n
        f += [(i, j, n + j, n + i), (2 * n + i, 3 * n + i, 3 * n + j, 2 * n + j),
              (n + i, n + j, 3 * n + j, 3 * n + i), (i, 2 * n + i, 2 * n + j, j)]
    p._shell(v, f, kind)


def sphere(p, c, r, kind, seg=16, rings=10):
    """A closed UV sphere shell."""
    cx, cy, cz = c
    verts = [(cx, cy + r, cz)]
    for i in range(1, rings):
        phi = math.pi * i / rings
        y, rr = math.cos(phi) * r, math.sin(phi) * r
        for j in range(seg):
            t = 2 * math.pi * j / seg
            verts.append((cx + math.cos(t) * rr, cy + y, cz + math.sin(t) * rr))
    verts.append((cx, cy - r, cz))
    last = len(verts) - 1
    faces = [(0, 1 + (j + 1) % seg, 1 + j) for j in range(seg)]
    for i in range(rings - 2):
        a, b = 1 + i * seg, 1 + (i + 1) * seg
        faces += [(a + j, a + (j + 1) % seg, b + (j + 1) % seg, b + j) for j in range(seg)]
    a = 1 + (rings - 2) * seg
    faces += [(a + j, a + (j + 1) % seg, last) for j in range(seg)]
    p._shell(verts, faces, kind)


def build_base(p):
    p.prism_y(octagon(15.8, 2.2), 0.0, 1.0, "trim", bevel=0.18, top_scale=0.985)
    # lower tier: upright walls, sloped upper walls, team plates on its deck
    p.prism_y(octagon(13.4, 3.2), 1.0, 2.6, "paint", bevel=0.2)
    p.prism_y(octagon(13.4, 3.2), 2.6, T1, "paint", bevel=0.2, top_scale=0.93)
    for s in (-1, 1):
        p.box((0, T1 + 0.03, s * 10.7), (8.4, 0.06, 2.8), "team", bevel=0.02)
        p.box((s * 10.7, T1 + 0.03, 0), (2.8, 0.06, 8.4), "team", bevel=0.02)
        p.box((s * 13.42, 1.8, 0), (0.05, 0.2, 7.0), "light")  # running strips
    p.box((0, 1.8, 13.42), (7.0, 0.2, 0.05), "light")
    # upper tier: upright walls with glowing vents, sloped walls, a dark roof ring
    p.prism_y(octagon(9.0, 2.4), T1, 6.2, "paint", bevel=0.2)
    p.prism_y(octagon(9.0, 2.4), 6.2, T2, "paint", bevel=0.2, top_scale=0.88)
    for s in (-1, 1):
        p.box((s * 9.02, 4.9, 0), (0.05, 0.5, 4.6), "power")
        p.box((0, 4.9, s * 9.02), (4.6, 0.5, 0.05), "power")
    p.prism_y(octagon(7.6, 2.0), T2, T2 + 0.08, "dark", bevel=0.03)
    # heat-exchanger towers on the deck corners, cabled to the upper tier
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 9.6, sz * 9.6
            p.cylinder("y", (x, T1 + 0.3, z), 2.1, 0.6, 8, "trim", bevel=0.06)
            p.ocyl((x, T1 + 0.6, z), UP, 1.75, 5.0, 8, "paint", radius2=1.45)
            p.cylinder("y", (x, T1 + 3.4, z), 1.62, 1.1, 8, "team")
            hoop(p, (x, T1 + 5.75, z), 1.52, 1.3, 0.3, 8, "power")
            p.cylinder("y", (x, T1 + 6.0, z), 1.25, 0.2, 8, "dark")
            cable(p, [(x - sx * 1.2, T1 + 2.0, z - sz * 1.2), (sx * 7.6, T1 + 2.0, sz * 7.6), (sx * 6.9, T1 + 1.6, sz * 6.9)],
                  r=0.2, kind="steel")
    # front: an armored door bay with build lights, a walkway, hazard striping
    p.box((0, 2.3, -13.6), (6.0, 2.6, 0.8), "trim", bevel=0.1)
    p.box((0, 2.1, -14.02), (4.6, 2.0, 0.04), "dark")
    p.box((0, 3.25, -14.04), (4.4, 0.16, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 2.45, 2.1, -14.04), (0.14, 1.9, 0.04), "light")
    p.box((0, 1.06, -14.8), (5.0, 0.12, 1.4), "grille")
    for sx in (-1, 1):
        hazard(p, (sx * 7.0, 1.02, -14.6), (1, 0, 0), UP, 5.0, 0.6, stripes=9)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 13.0, 1.08, sz * 13.0), (0.6, 0.14, 0.6), "light")
    # roof: a pedestal, a cradle cup, the lower field emitter
    p.cylinder("y", (0, T2 + 0.45, 0), 5.0, 0.9, 24, "trim", bevel=0.06)
    p.ocyl((0, T2 + 0.9, 0), UP, 4.1, 0.9, 24, "steel", radius2=2.6)
    p.cylinder("y", (0, T2 + 1.9, 0), 0.7, 0.4, 10, "dark")
    # field coils on the roof diagonals, cabled to the pedestal
    for k in range(4):
        t = math.radians(45 + 90 * k)
        d = V((math.cos(t), 0, math.sin(t)))
        c = d * 6.1
        p.obox((c.x, T2 + 0.95, c.z), tuple(d), UP, 1.7, 1.3, 1.9, "trim", bevel=0.06)
        p.obox((c.x, T2 + 1.92, c.z), tuple(d), UP, 1.1, 0.3, 0.04, "power")
        p.obox((c.x + d.x * 0.86, T2 + 1.1, c.z + d.z * 0.86), tuple(d), UP, 0.04, 0.9, 0.14, "light")
        q = d * 4.9
        cable(p, [(c.x - d.x * 0.85, T2 + 1.3, c.z - d.z * 0.85), (q.x, T2 + 1.1, q.z)], r=0.14, kind="steel")
    # cage ribs round the sphere and an armored equator ring
    rr = R_CORE + 0.28
    for k in range(8):
        t = 2 * math.pi * k / 8 + math.pi / 8
        prev = None
        for i in range(6):
            phi = math.radians(-60 + 24 * i)
            q = V((math.cos(t) * math.cos(phi) * rr, CORE[1] + math.sin(phi) * rr, math.sin(t) * math.cos(phi) * rr))
            if prev is not None:
                u = q - prev
                outward = V((math.cos(t), 0, math.sin(t)))
                p.obox(tuple((q + prev) / 2), tuple(u), tuple(outward), u.length + 0.1, 0.26, 0.18, "steel")
            prev = q
    for k in range(16):
        t = 2 * math.pi * (k + 0.5) / 16
        d = V((math.cos(t), 0, math.sin(t)))
        p.obox(tuple(V(CORE) + d * (rr + 0.35)), (-d.z, 0, d.x), tuple(d), 1.45, 0.9, 0.5, "trim")
    # clamp columns, the top bar with a team plate, the upper emitter
    for sx in (-1, 1):
        p.prism_y([(sx * POST_X - 0.9, -0.9), (sx * POST_X + 0.9, -0.9), (sx * POST_X + 0.9, 0.9), (sx * POST_X - 0.9, 0.9)],
                  T2, T2 + 1.2, "paint", bevel=0.08, top_scale=0.7)
        p.box((sx * POST_X, 11.4, 0), (1.1, 8.4, 1.1), "paint", bevel=0.08)
        p.box((sx * (POST_X + 0.57), 11.4, 0), (0.05, 5.0, 0.18), "light")
        p.box((sx * (POST_X - 0.95), CORE[1], 0), (1.2, 0.9, 0.9), "trim", bevel=0.05)  # arm to the ring
    p.box((0, 15.9, 0), (POST_X * 2 + 1.6, 1.0, 1.8), "paint", bevel=0.1)
    p.box((0, 16.42, 0), (POST_X * 2 + 0.6, 0.05, 1.3), "team", bevel=0.015)
    p.cylinder("y", (0, 15.0, 0), 0.75, 0.9, 12, "trim")
    p.cylinder("y", (0, 14.45, 0), 0.5, 0.2, 10, "power")
    for sx in (-1, 1):
        p.box((sx * (POST_X + 0.2), 16.55, 0), (0.3, 0.2, 0.3), "light")

    # the containment sphere: a glowing core, pulsing
    with p.sub("core", CORE, "pulse", (0, 1, 0)):
        sphere(p, CORE, R_CORE, "power", seg=16, rings=10)


def details_base(p):
    for s in (-1, 1):
        rivets(p, (s * 13.42, 1.4, -5.0), (s * 13.42, 1.4, 5.0), 10, (s, 0, 0))
        seam(p, (s * 9.02, 6.2, -3.4), (s * 9.02, 6.2, 3.4), (s, 0, 0))
        rivets(p, (-POST_X * 2 / 2 + 0.2, 16.41, s * 0.75), (POST_X - 0.2, 16.41, s * 0.75), 12, UP)
    ring(p, (0, T2 + 0.91, 0), UP, 4.6)
    rivets(p, (-5.0, 2.0, 13.42), (5.0, 2.0, 13.42), 10, (0, 0, 1))


unit.run(__file__, "ord_fusion", "order", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-44, 34, -52), (0, 5.0, 0), 50),
                   ("80", (0, 70, 12), (0, 4, 0), 50),
                   ("close", (-22, 18, -26), (0, 7.0, 0), 35)])
