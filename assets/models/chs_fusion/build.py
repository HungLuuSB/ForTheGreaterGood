"""Hellforge (Chaos fusion plant, T2 structure, footprint 4): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_fusion/build.py

New mesh at the size scale (S-104, M-26: footprint 4, 32 x 32 studs, about
19 tall), from its blockout; the T1 Generator's big brother, not a rescale.
Big readable shapes first: a skid slab with team plates and hazard striping;
the tall round furnace stack on a flared skirt, clad in rows of reactive
"era" blocks, with a team band, a conical hood with a team ring and a hot
exhaust; its glowing heart (`core`, pulse, rig.md 9: two hot bands and the
furnace mouth); an open lattice frame of four posts round it with X bracing,
top rails, a gantry hoist and amber beacons, and a grated catwalk; two
salvage tanks with team caps piped into the stack, a slag trough from the
mouth to a glowing slag bucket, a generator shed with a team roof and hot
vents, cable runs and welded patches. Chaos reads rugged and improvised
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec
R_STACK = 5.0
STACK_Y0, STACK_Y1 = 2.4, 14.0
POST = 7.2  # frame post offset
TOP = 16.2  # frame top
CORE_Y = 8.0


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


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def tank(p, x, z, r, h, y0):
    p.cylinder("y", (x, y0 + h / 2, z), r, h, 16, "paint", bevel=0.05)
    p.ocyl((x, y0 + h, z), UP, r, 0.55, 16, "trim", radius2=r * 0.7)
    p.cylinder("y", (x, y0 + h + 0.6, z), r * 0.68, 0.05, 14, "team")
    for y in (y0 + 0.35, y0 + h * 0.55):
        p.cylinder("y", (x, y, z), r + 0.05, 0.2, 16, "dark")


def build_base(p):
    p.prism_y(octagon(15.8, 1.6), 0.0, 0.9, "dark", bevel=0.14, top_scale=0.985)
    p.box((-9.6, 0.93, -9.0), (5.0, 0.06, 5.0), "team", bevel=0.02)
    p.box((10.4, 0.93, 4.6), (3.6, 0.04, 4.0), "steel", bevel=0.01)  # welded patch
    hazard(p, (3.8, 0.93, -12.6), (1, 0, 0), UP, 11.0, 0.7, stripes=18)
    # the furnace stack: a flared skirt, the shell, era block rows, a team band
    p.ocyl((0, 0.9, 0), UP, 6.6, 1.5, 18, "trim", radius2=R_STACK + 0.2)
    p.cylinder("y", (0, (STACK_Y0 + STACK_Y1) / 2, 0), R_STACK, STACK_Y1 - STACK_Y0, 18, "paint")
    for row, y in enumerate((5.2, 11.9)):  # rows of reactive blocks between the hot bands
        for k in range(14):
            t = 2 * math.pi * (k + 0.5 * row) / 14
            d = V((math.cos(t), 0, math.sin(t)))
            p.obox(tuple(V((0, y, 0)) + d * (R_STACK + 0.12)), (-d.z, 0, d.x), tuple(d), 1.7, 1.3, 0.3, "era", bevel=0.03)
    p.cylinder("y", (0, 9.95, 0), R_STACK + 0.06, 1.3, 18, "team")
    for y in (6.2, 13.6):
        p.cylinder("y", (0, y, 0), R_STACK + 0.1, 0.22, 18, "dark")
    # conical hood with a team ring, the exhaust with a hot rim
    p.ocyl((0, STACK_Y1, 0), UP, R_STACK + 0.3, 1.6, 18, "trim", radius2=3.0)
    p.cylinder("y", (0, STACK_Y1 + 1.63, 0), 3.0, 0.06, 16, "team")
    p.cylinder("y", (0, STACK_Y1 + 3.2, 0), 1.6, 3.2, 14, "dark")
    hoop(p, (0, STACK_Y1 + 4.85, 0), 1.65, 1.3, 0.2, 14, "power")
    p.cylinder("y", (0, STACK_Y1 + 4.96, 0), 1.2, 0.04, 12, "dark")
    # the open frame: four posts, X bracing on the sides, top rails, beacons
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sz in corners:
        beam(p, (sx * POST, 0.9, sz * POST), (sx * POST, TOP, sz * POST), 0.6, "trim", bevel=0.04)
        p.box((sx * POST, 1.15, sz * POST), (1.3, 0.5, 1.3), "dark", bevel=0.05)
        p.box((sx * POST, TOP + 0.35, sz * POST), (0.6, 0.4, 0.6), "light")
    for i, (sx, sz) in enumerate(corners):
        nx, nz = corners[(i + 1) % 4]
        beam(p, (sx * POST, TOP - 0.3, sz * POST), (nx * POST, TOP - 0.3, nz * POST), 0.5, "dark")
        if sx != nx:  # front and back faces: X bracing below the catwalk
            for s in (-1, 1):
                beam(p, (s * POST, 1.6, sz * POST), (-s * POST, 8.2, sz * POST), 0.18, "steel")
        else:  # side faces: X bracing above the catwalk
            for s in (-1, 1):
                beam(p, (sx * POST, 9.2, s * POST), (sx * POST, TOP - 0.6, -s * POST), 0.18, "steel")
    # grated catwalk round the stack, with rails
    for s in (-1, 1):
        p.box((0, 8.6, s * 6.25), (14.4, 0.16, 1.9), "grille")
        p.box((s * 6.25, 8.6, 0), (1.9, 0.16, 10.6), "grille")
        p.box((0, 9.5, s * (POST + 0.05)), (14.0, 0.1, 0.1), "steel")
    # the gantry hoist on the top rails: a trolley, a hook block on a cable
    p.box((3.0, TOP + 0.1, 0), (1.8, 0.9, 2.4), "paint", bevel=0.06)
    p.box((3.0, TOP + 0.58, 0), (1.4, 0.05, 2.0), "team", bevel=0.01)
    for sz in (-1, 1):
        beam(p, (3.0, TOP - 0.3, sz * POST), (3.0, TOP - 0.3, 0), 0.4, "dark")
    p.cylinder("y", (3.0, TOP - 1.0, -1.6), 0.05, 1.6, 6, "steel")
    # salvage tanks piped into the stack
    tank(p, -10.2, 6.2, 2.3, 5.4, 0.9)
    tank(p, 10.0, -6.4, 1.9, 4.2, 0.9)
    cable(p, [(-8.2, 4.6, 5.0), (-6.4, 4.6, 3.8), (-4.4, 4.6, 2.6)], r=0.26, kind="steel")
    cable(p, [(8.4, 3.8, -5.4), (6.4, 3.8, -4.0), (4.4, 3.8, -2.6)], r=0.22, kind="steel")
    # generator shed (back right) with a team roof and hot vents
    p.prism_y(rect(10.0, 9.4, 2.8, 2.2), 0.9, 4.2, "paint", bevel=0.12)
    p.box((10.0, 4.25, 9.4), (5.2, 0.05, 4.0), "team", bevel=0.02)
    p.box((12.82, 2.6, 9.4), (0.05, 0.8, 3.0), "power")
    p.box((10.0, 2.6, 7.18), (3.6, 0.8, 0.05), "grille")
    for dx in (-1.2, 1.2):
        p.cylinder("y", (10.0 + dx, 5.4, 10.6), 0.32, 2.4, 10, "steel")
        p.cylinder("y", (10.0 + dx, 6.65, 10.6), 0.35, 0.12, 10, "power")
    cable(p, [(7.2, 3.0, 8.8), (5.4, 3.0, 6.8), (3.4, 3.4, 4.0)], r=0.14, kind="dark")
    # slag trough from the furnace mouth to a glowing slag bucket at the front
    p.obox((0, 1.5, -7.6), (0, -0.25, -1), (0, 1, 0), 4.6, 1.2, 0.4, "trim", bevel=0.04)
    p.box((0, 1.65, -9.8), (3.0, 1.5, 2.4), "dark", bevel=0.1)
    p.box((0, 2.42, -9.8), (2.4, 0.04, 1.8), "power")
    for sx in (-1, 1):
        p.box((sx * 1.6, 1.3, -9.8), (0.3, 0.9, 2.6), "trim")
    # beacons on the slab corners
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 13.4, 1.05, sz * 13.4), (0.5, 0.3, 0.5), "light")

    # the furnace heart: two hot bands and the glowing mouth, pulsing
    with p.sub("core", (0.0, CORE_Y, 0.0), "pulse", (0, 1, 0)):
        for y in (6.9, 13.0):
            hoop(p, (0, y, 0), R_STACK + 0.14, R_STACK - 0.1, 0.7, 18, "power")
        p.box((0, 3.4, -(R_STACK - 0.1)), (2.6, 1.4, 0.4), "power")
        for sx in (-1, 1):
            p.box((sx * 1.55, 3.4, -(R_STACK + 0.05)), (0.4, 1.9, 0.5), "dark")
        p.box((0, 4.3, -(R_STACK + 0.05)), (3.4, 0.4, 0.5), "dark")


def details_base(p):
    rivets(p, (7.4, 4.24, 7.8), (12.6, 4.24, 7.8), 8, UP)
    seam(p, (7.2, 2.6, 7.19), (12.8, 2.6, 7.19), (0, 0, -1))
    rivets(p, (-12.0, 0.94, -6.6), (-7.2, 0.94, -6.6), 6, UP)


unit.run(__file__, "chs_fusion", "chaos", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-44, 35, -52), (0, 7.0, 0), 50),
                   ("80", (0, 72, 12), (0, 5, 0), 50),
                   ("close", (-22, 20, -26), (0, 9.0, 0), 35)])
