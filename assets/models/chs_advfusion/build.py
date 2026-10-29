"""Great Hellforge (Chaos advanced fusion plant, T2 structure, footprint 6;
S-209, BAR corafus): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advfusion/build.py

48 x 48 studs, about 29 tall: the Hellforge's big and dangerous brother,
after BAR's corafus. Big shapes first: a patched skid slab with team plates
and hazard striping; a squat stepped armored block ringed with reactive
"era" blocks and heavy sloped buttresses with team tops (a ramp-like one at
the front); a deep cup holding a huge bare glowing sphere crawling with hot
arcs (`core`, pulse, rig.md 9), its rim a team band; over it a triple pipe
arch clamped by heavy blocks, its feet bolted on the block; corrugated
hoses from the cup down to the slab, steel guard rails round the corners,
amber beacons. Chaos reads rugged and improvised (M-14); the bare sphere
in its crude cage says it goes up like a small nuke. Writes export/
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
from unit import UP, seam  # noqa: E402

V = lib.vec
T1, T2 = 4.4, 6.0  # tops of the block's wall and its sloped band
CUP_Y = 11.6  # the cup's rim
CORE = (0.0, 18.0, 0.0)  # sphere centre
R_CORE = 9.0
ARCH = math.radians(-30)  # the pipe arch's plane, turned from the X axis


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


def hoop(p, center, r_out, r_in, h, sides, kind):
    """An open ring band about Y (no caps over the hole)."""
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


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def radial(p, profile_ry, d, w, kind, bevel=0.0):
    """A (r, y) side profile in the vertical plane along the horizontal
    direction d, extruded `w` wide across it (buttresses)."""
    d = V(d).normalized()
    t = V((-d.z, 0, d.x))
    n = len(profile_ry)
    v = [tuple(d * r + V((0, y, 0)) + t * (s * w / 2)) for s in (-1, 1) for r, y in profile_ry]
    f = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    p._shell(v, f, kind, bevel)


def hose(p, pts, r):
    """A corrugated hose through points: alternating thick and thin rings."""
    for a, b in zip(pts, pts[1:]):
        a, b = V(a), V(b)
        u = b - a
        k = max(2, int(u.length / 0.7))
        for i in range(k):
            q = a + u * (i / k)
            p.ocyl(tuple(q), tuple(u), r if i % 2 == 0 else r * 0.78, u.length / k + 0.02, 6, "dark" if i % 2 == 0 else "rubber")


def buttress(p, ang, front=False):
    d = V((math.cos(ang), 0, math.sin(ang)))
    if front:  # a ramp-like wedge with a team top
        radial(p, [(15.0, 1.0), (23.0, 1.0), (23.0, 2.0), (16.6, 7.4), (15.0, 7.4)], d, 7.0, "paint", bevel=0.2)
        radial(p, [(16.8, 7.42), (22.6, 2.4), (22.66, 2.52), (16.86, 7.56)], d, 5.6, "team", bevel=0.02)
    else:
        radial(p, [(15.4, 1.0), (21.8, 1.0), (21.8, 3.2), (18.4, 7.0), (15.4, 8.2)], d, 6.0, "paint", bevel=0.2)
        radial(p, [(15.6, 8.22), (18.4, 7.06), (18.46, 7.2), (15.66, 8.36)], d, 4.8, "team", bevel=0.02)
        p.obox(tuple(d * 20.6 + V((0, 2.4, 0))), (-d.z, 0, d.x), tuple(d), 4.2, 0.4, 0.06, "light")


def arch(p):
    """Three parallel pipes in one plane, over the sphere from rim to rim,
    clamped by heavy blocks."""
    a = V((math.cos(ARCH), 0, math.sin(ARCH)))
    nrm = V((-a.z, 0, a.x))
    ra = R_CORE + 1.8
    lo = math.asin((CUP_Y - 0.6 - CORE[1]) / ra)
    steps = 18
    angles = [lo + (math.pi - 2 * lo) * i / steps for i in range(steps + 1)]

    def at(phi, off):
        return V(CORE) + a * (math.cos(phi) * ra) + V((0, math.sin(phi) * ra, 0)) + nrm * off

    for off in (-0.9, 0.0, 0.9):
        for p0, p1 in zip(angles, angles[1:]):
            beam(p, tuple(at(p0, off)), tuple(at(p1, off)), 0.62, "steel")
    for i in range(0, steps + 1, 3):
        phi = angles[i]
        c = at(phi, 0.0)
        tang = V((0, 0, 0)) + a * (-math.sin(phi)) + V((0, math.cos(phi), 0))
        out = (c - V(CORE)).normalized()
        p.obox(tuple(c), tuple(tang), tuple(out), 1.6, 3.4, 1.5, "trim" if i % 6 else "paint", bevel=0.1)
        for s in (-1, 1):
            p.obox(tuple(c + nrm * (s * 1.72) + out * 0.2), tuple(tang), tuple(nrm * s), 1.0, 0.9, 0.06, "dark")
    for s in (-1, 1):  # feet bolted on the block
        c = V(CORE) + a * (s * (ra + 0.4))
        p.box((c.x, CUP_Y - 2.4, c.z), (3.4, 4.0, 3.4), "trim", bevel=0.14)
        p.box((c.x, CUP_Y - 0.36, c.z), (2.6, 0.05, 2.6), "team", bevel=0.01)


def build_base(p):
    p.prism_y(octagon(23.8, 3.0), 0.0, 1.0, "dark", bevel=0.14, top_scale=0.99)
    for sx, sz in ((-1, -1), (1, 1)):
        p.box((sx * 19.0, 1.03, sz * 12.6), (5.0, 0.06, 5.0), "team", bevel=0.02)
    p.box((-15.6, 1.02, 15.4), (5.0, 0.04, 3.4), "steel", bevel=0.01)  # welded patches
    p.box((17.0, 1.02, -15.0), (3.0, 0.04, 4.2), "steel", bevel=0.01)
    hazard(p, (0, 1.03, -22.6), (1, 0, 0), UP, 16.0, 0.9, stripes=22)
    # the block: a wall ringed with reactive blocks, a sloped band, the deck
    p.prism_y(octagon(14.6, 4.0), 1.0, T1, "paint", bevel=0.2)
    p.prism_y(octagon(14.6, 4.0), T1, T2, "paint", bevel=0.2, top_scale=0.86)
    for k in range(16):
        t = 2 * math.pi * (k + 0.5) / 16
        d = V((math.cos(t), 0, math.sin(t)))
        rr = 14.6 / max(abs(d.x), abs(d.z)) if k % 2 else 13.4
        p.obox(tuple(d * (min(rr, 15.2) + 0.2) + V((0, 2.6, 0))), (-d.z, 0, d.x), tuple(d), 2.6, 2.2, 0.4, "era", bevel=0.04)
    p.prism_y(octagon(12.4, 3.4), T2, T2 + 0.1, "grille", bevel=0.02)
    # buttresses: a ramp at the front, heavy wedges round the rest
    buttress(p, math.radians(-90), front=True)
    for deg in (-30, 30, 90, 150, 210):
        buttress(p, math.radians(deg))
    # the cup: a flared bowl with a team rim, ribs under it
    p.cylinder("y", (0, T2 + 1.0, 0), 7.6, 2.0, 24, "trim", bevel=0.08)
    p.ocyl((0, T2 + 2.0, 0), UP, 7.6, CUP_Y - T2 - 2.0, 24, "paint", radius2=10.4)
    hoop(p, (0, CUP_Y, 0), 10.6, 8.2, 0.7, 24, "team")
    for k in range(10):
        t = 2 * math.pi * (k + 0.5) / 10
        d = V((math.cos(t), 0, math.sin(t)))
        radial(p, [(7.4, T2 + 0.1), (9.6, T2 + 0.1), (10.6, CUP_Y - 0.5), (9.4, CUP_Y - 0.5)], d, 0.8, "dark", bevel=0.04)
    arch(p)
    # corrugated hoses from the cup down to the slab
    for deg in (20, 120, 200, 300):
        t = math.radians(deg)
        d = V((math.cos(t), 0, math.sin(t)))
        hose(p, [tuple(d * 9.6 + V((0, CUP_Y - 1.4, 0))), tuple(d * 12.8 + V((0, 9.4, 0))),
                 tuple(d * 16.2 + V((0, 4.6, 0))), tuple(d * 17.4 + V((0, 1.2, 0)))], 0.55)
    # steel guard rails round the slab corners
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = (sx * 21.4, sz * 16.0)
            e = (sx * 16.0, sz * 21.4)
            for y in (1.8, 2.8):
                beam(p, (c[0], y, c[1]), (e[0], y, e[1]), 0.18, "steel")
            for q in (c, e, ((c[0] + e[0]) / 2, (c[1] + e[1]) / 2)):
                p.cylinder("y", (q[0], 1.95, q[1]), 0.14, 1.9, 6, "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 21.6, 1.2, sz * 21.6), (0.6, 0.4, 0.6), "light")
    cable(p, [(-12.4, 1.1, -6.0), (-15.6, 1.1, -9.6), (-19.4, 1.1, -9.6)], r=0.2, kind="dark")

    # the sphere: a bare glowing heart with hot arcs, pulsing
    with p.sub("core", CORE, "pulse", (0, 1, 0)):
        sphere(p, CORE, R_CORE, "power", seg=24, rings=14)
        rng = random.Random(9283)
        for _ in range(8):
            th, ph = rng.uniform(0, 2 * math.pi), rng.uniform(-0.5, 0.9)
            prev = None
            for i in range(7):
                th += rng.uniform(0.1, 0.26)
                ph += rng.uniform(-0.25, 0.25)
                q = V(CORE) + V((math.cos(th) * math.cos(ph), math.sin(ph), math.sin(th) * math.cos(ph))) * (R_CORE + 0.06)
                if prev is not None:
                    u = q - prev
                    nrm = (q + prev) / 2 - V(CORE)
                    p.obox(tuple((q + prev) / 2), tuple(u), tuple(nrm), u.length + 0.1, 0.34, 0.08, "head")
                prev = q
        # solid fittings on the core itself (a glow-only core would be empty once the glow is split off)
        p.cylinder("y", (0, CORE[1] + R_CORE * 0.98, 0), R_CORE * 0.2, 0.4, 12, "steel")
        p.cylinder("y", (0, CORE[1] - R_CORE * 0.9, 0), R_CORE * 0.4, 0.3, 16, "trim")


def details_base(p):
    rivets(p, (-18.0, 1.04, 13.2), (-14.0, 1.04, 13.2), 6, UP)
    rivets(p, (15.6, 1.04, -12.8), (18.4, 1.04, -12.8), 5, UP)
    for s in (-1, 1):
        seam(p, (s * 14.62, 3.6, -5.0), (s * 14.62, 3.6, 5.0), (s, 0, 0))


unit.run(__file__, "chs_advfusion", "chaos", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000,
         previews=[("35", (-66, 52, -78), (0, 11.0, 0), 50),
                   ("80", (0, 108, 18), (0, 8, 0), 50),
                   ("close", (-30, 30, -36), (0, 17.0, 0), 35)])
