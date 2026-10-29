"""Advanced Fusion Reactor (Order power plant, T2 structure, footprint 6;
S-209, BAR armafus): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advfusion/build.py

48 x 48 studs, about 28 tall: the Fusion Reactor's big and dangerous
brother, after BAR's armafus. Big shapes first: a thick chamfered slab, a
stepped armored ziggurat (two tiers with sloped walls, team plates on the
lower deck, glowing vents and radiator louvres on the upper walls), a
pedestal and cradle cup holding a huge glowing containment sphere crawling
with white arcs (`core`, pulse, rig.md 9), gripped by four massive claw
pylons on the diagonals (team plates and glowing power seams on their
backs, fingers bent over the sphere); a white-steel intake gate with three
coolant tubes at the front, coolant pipes and hazard striping round the
slab, corner beacons. Order reads heavy and clean (M-14); the bare
sphere and the claws say it goes up like a small nuke. Writes export/
through tools/unit.py.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
T1, T2 = 5.0, 9.6  # tops of the lower and upper tier
CORE = (0.0, 20.0, 0.0)  # sphere centre
R_CORE = 7.6


def sphere(p, c, r, kind, seg=24, rings=14):
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


def radial(p, profile_ry, d, w0, kind, w1=None, bevel=0.0):
    """A (r, y) side profile in the vertical plane along the horizontal
    direction d, extruded across it (w0 wide at the first point's side, w1
    at the last): the diagonal claw pylons."""
    d = V(d).normalized()
    t = V((-d.z, 0, d.x))
    w1 = w0 if w1 is None else w1
    n = len(profile_ry)
    rs = [r for r, _ in profile_ry]
    r0, r1 = min(rs), max(rs)
    v = []
    for s in (-1, 1):
        for r, y in profile_ry:
            k = 0.0 if r1 == r0 else (r - r0) / (r1 - r0)
            w = w1 + (w0 - w1) * k
            v.append(tuple(d * r + V((0, y, 0)) + t * (s * w / 2)))
    f = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    p._shell(v, f, kind, bevel)


def along(p, d, r, y, edge, w, h, kind, out=0.05):
    """A plate on a radial profile's face: centred at (r, y) in direction
    d's plane, `edge` the face's (dr, dy) direction, pushed `out` off it."""
    d = V(d).normalized()
    t = V((-d.z, 0, d.x))
    e = (d * edge[0] + V((0, edge[1], 0))).normalized()
    n = e.cross(t).normalized()
    c = d * r + V((0, y, 0))
    if n.dot(c - V((0, y, 0))) < 0 and abs(edge[0]) > 0.2:
        n = -n
    p.obox(tuple(c + n * out), tuple(e), tuple(n), h, w, 0.08, kind, bevel=0.02)
    return n


def claw(p, ang):
    d = V((math.cos(ang), 0, math.sin(ang)))
    t = V((-d.z, 0, d.x))
    # the pylon, the arm and the finger bent over the sphere
    radial(p, [(12.8, 1.2), (21.6, 1.2), (19.6, 15.0), (14.4, 16.2), (12.6, 8.0)], d, 6.4, "paint", bevel=0.25)
    radial(p, [(14.6, 14.6), (19.8, 15.2), (14.6, 26.6), (10.8, 25.2)], d, 4.8, "paint", w1=4.4, bevel=0.2)
    radial(p, [(10.8, 25.2), (14.6, 26.6), (10.6, 28.0), (7.6, 25.6)], d, 4.4, "trim", w1=3.6, bevel=0.15)
    radial(p, [(7.6, 25.6), (9.0, 25.0), (8.6, 23.6)], d, 2.6, "dark", bevel=0.05)  # the grip pad
    # armor collar at the elbow, a team plate and glowing seams on the back
    radial(p, [(14.2, 13.4), (20.4, 13.6), (20.4, 16.6), (14.2, 17.2)], d, 7.0, "trim", bevel=0.12)
    along(p, d, 20.7, 7.6, (-2.0, 13.8), 3.8, 8.6, "team")
    along(p, d, 17.3, 21.0, (-5.2, 11.4), 0.3, 9.4, "power", out=0.06)
    for s in (-1, 1):
        q = d * 17.2 + V((0, 20.9, 0)) + t * (s * 2.42)
        p.obox(tuple(q), tuple((d * -5.2 + V((0, 11.4, 0))).normalized()), tuple(t * s), 9.0, 0.24, 0.05, "light")
    # side power conduits up the pylon
    for s in (-1, 1):
        cable(p, [tuple(d * 19.8 + V((0, 1.4, 0)) + t * (s * 3.4)), tuple(d * 18.6 + V((0, 9.0, 0)) + t * (s * 3.4)),
                  tuple(d * 17.4 + V((0, 13.6, 0)) + t * (s * 3.6))], r=0.32, kind="steel")


def gate(p):
    """The intake gate at the front: a white-steel block with three
    coolant tubes, a grille and lit edges."""
    z0 = -15.4
    p.prism_x([(z0 - 2.4, 1.2), (z0 + 1.0, 1.2), (z0 + 1.0, 9.4), (z0 - 1.0, 9.8), (z0 - 2.4, 8.4)], -4.6, 4.6, "steel", bevel=0.2)
    p.box((0, 4.6, z0 - 2.46), (6.8, 5.6, 0.05), "grille")
    p.box((0, 7.9, z0 - 2.47), (7.4, 0.3, 0.05), "power")
    for x in (-2.6, 0.0, 2.6):
        p.ocyl((x, 1.2, z0 - 5.8), (0, 1, 0.42), 0.95, 8.2, 12, "trim")
        p.cylinder("y", (x, 1.7, z0 - 5.75), 1.1, 1.0, 12, "dark")
        p.ocyl((x, 4.2, z0 - 4.53), (0, 1, 0.42), 1.0, 0.35, 12, "power")
    for sx in (-1, 1):
        p.box((sx * 4.64, 5.4, z0 - 0.7), (0.05, 7.0, 0.24), "light")
        p.prism_x([(z0 - 7.0, 1.2), (z0 - 2.4, 1.2), (z0 - 2.4, 4.0)], sx * 4.6 - 0.6, sx * 4.6 + 0.6, "paint", bevel=0.08)


def build_base(p):
    p.prism_y(octagon(23.8, 4.0), 0.0, 1.2, "trim", bevel=0.2, top_scale=0.99)
    # lower tier: upright walls, a sloped band, team plates on its deck
    p.prism_y(octagon(20.4, 5.6), 1.2, 3.8, "paint", bevel=0.25)
    p.prism_y(octagon(20.4, 5.6), 3.8, T1, "paint", bevel=0.25, top_scale=0.92)
    for s in (-1, 1):
        p.box((s * 16.6, T1 + 0.03, 0), (3.0, 0.06, 9.0), "team", bevel=0.02)
        p.box((0, T1 + 0.03, s * 16.6), (9.0, 0.06, 3.0), "team", bevel=0.02)
        p.box((s * 20.42, 2.5, 0), (0.05, 0.24, 8.4), "light")
        p.box((0, 2.5, s * 20.42), (8.4, 0.24, 0.05), "light")
    # upper tier: louvred walls with glowing vents, a sloped crown
    p.prism_y(octagon(14.2, 4.0), T1, 8.2, "paint", bevel=0.22)
    p.prism_y(octagon(14.2, 4.0), 8.2, T2, "paint", bevel=0.22, top_scale=0.84)
    for s in (-1, 1):
        louver(p, (s * 14.22, 6.6, 0), (0, 0, 1), (s, 0, 0), 6.0, 1.8, slats=4)
        louver(p, (0, 6.6, s * 14.22), (1, 0, 0), (0, 0, s), 6.0, 1.8, slats=4)
        p.box((s * 14.24, 8.0, 0), (0.05, 0.3, 7.0), "power")
        p.box((0, 8.0, s * 14.24), (7.0, 0.3, 0.05), "power")
    p.prism_y(octagon(9.0, 2.6), T2, T2 + 0.1, "grille", bevel=0.03)
    # the pedestal and the cradle cup under the sphere
    p.cylinder("y", (0, T2 + 1.6, 0), 6.4, 3.2, 24, "trim", bevel=0.08)
    p.ocyl((0, T2 + 3.2, 0), UP, 5.4, 1.4, 24, "steel", radius2=6.6)
    p.cylinder("y", (0, T2 + 1.0, 0), 6.46, 0.4, 24, "team")
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        d = V((math.cos(a), 0, math.sin(a)))
        p.obox(tuple(d * 6.3 + V((0, T2 + 4.2, 0))), (-d.z, 0, d.x), tuple(d), 2.4, 1.6, 0.9, "trim", bevel=0.06)
    # four claw pylons on the diagonals
    for k in range(4):
        claw(p, math.radians(45 + 90 * k))
    gate(p)
    # coolant pipes on the back and sides
    for s in (-1, 1):
        cable(p, [(s * 6.0, 2.0, 21.0), (s * 6.0, 2.0, 14.6), (s * 4.0, 7.4, 14.4)], r=0.55, kind="steel")
        p.cylinder("z", (s * 6.0, 2.0, 21.6), 0.8, 1.2, 12, "trim")
        p.cylinder("x", (s * 21.4, 2.2, 0), 1.0, 2.6, 12, "steel", cap_kinds=("trim", "trim"))
    hazard(p, (0, 1.22, -22.0), (1, 0, 0), UP, 14.0, 1.0, stripes=18)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 19.4, 1.32, sz * 19.4), (0.9, 0.2, 0.9), "light")

    # the containment sphere: the glowing core with white arcs, pulsing
    with p.sub("core", CORE, "pulse", (0, 1, 0)):
        sphere(p, CORE, R_CORE, "light", seg=24, rings=14)
        rng = random.Random(4471)
        for _ in range(7):
            th, ph = rng.uniform(0, 2 * math.pi), rng.uniform(-0.6, 0.9)
            prev = None
            for i in range(7):
                th += rng.uniform(0.12, 0.3)
                ph += rng.uniform(-0.25, 0.25)
                q = V(CORE) + V((math.cos(th) * math.cos(ph), math.sin(ph), math.sin(th) * math.cos(ph))) * (R_CORE + 0.06)
                if prev is not None:
                    u = q - prev
                    nrm = (q + prev) / 2 - V(CORE)
                    p.obox(tuple((q + prev) / 2), tuple(u), tuple(nrm), u.length + 0.1, 0.32, 0.08, "head")
                prev = q
        # solid fittings on the core itself (a glow-only core would be empty once the glow is split off)
        p.cylinder("y", (0, CORE[1] - R_CORE * 0.98, 0), R_CORE * 0.22, 0.4, 14, "steel")
        p.cylinder("y", (0, CORE[1] - R_CORE * 0.86, 0), R_CORE * 0.5, 0.3, 18, "trim")


def details_base(p):
    for s in (-1, 1):
        rivets(p, (s * 20.42, 1.8, -6.0), (s * 20.42, 1.8, 6.0), 12, (s, 0, 0))
        rivets(p, (-6.0, 1.8, s * 20.42), (6.0, 1.8, s * 20.42), 12, (0, 0, s))
        seam(p, (s * 14.22, 8.6, -4.0), (s * 14.22, 8.6, 4.0), (s, 0, 0))
    ring(p, (0, T2 + 3.21, 0), UP, 6.0)


unit.run(__file__, "ord_advfusion", "order", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000,
         previews=[("35", (-66, 52, -78), (0, 11.0, 0), 50),
                   ("80", (0, 108, 18), (0, 8, 0), 50),
                   ("close", (-30, 30, -36), (0, 17.0, 0), 35)])
