"""Deep Excavator (Chaos supply extractor, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advextractor/build.py

New mesh at the size scale (S-104, M-26: footprint 3, 24 x 24 studs, about
16 tall), from its blockout; the T1 Excavator's big brother, not a rescale.
Big readable shapes first: a skid slab with a raised grated platform and
team plates, a tall open four-leg lattice derrick (braced rings, X bracing,
guy cables to anchor blocks, amber beacons) with a head block, a team roof
and a crown sheave; under it the thick turning drill string (`drill`, turn
Y, rig.md 9) with a glowing collar, hot bands and spiral flights; two engine
houses with team roofs, twin stacks with hot rims and glowing vents (the
blockout's two engines); two strapped fuel tanks with team caps piped to the
collar; slat cages along the platform edges, an ore hopper fed by a skip
conveyor, hazard striping. Chaos reads rugged and improvised (M-14). Writes
export/ through tools/unit.py.
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
DECK = 1.4  # platform top
LEG_FOOT, LEG_TOP, TOP_Y = 5.8, 1.7, 13.2
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]


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


def leg_at(sx, sz, y):
    t = (y - DECK) / (TOP_Y - DECK)
    r = LEG_FOOT + (LEG_TOP - LEG_FOOT) * t
    return (sx * r, y, sz * r)


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def tank(p, x, z, r, h, y0):
    p.cylinder("y", (x, y0 + h / 2, z), r, h, 16, "paint", bevel=0.05)
    p.ocyl((x, y0 + h, z), UP, r, 0.5, 16, "trim", radius2=r * 0.7)
    p.cylinder("y", (x, y0 + h + 0.55, z), r * 0.68, 0.05, 14, "team")
    for y in (y0 + 0.35, y0 + h * 0.55):
        p.cylinder("y", (x, y, z), r + 0.05, 0.18, 16, "dark")


def build_base(p):
    # skid slab, a raised grated platform, team plates on its deck
    p.prism_y(octagon(11.8, 1.2), 0.0, 0.8, "dark", bevel=0.14, top_scale=0.985)
    p.box((0, 1.1, 0), (14.4, 0.6, 14.4), "paint", bevel=0.12)
    p.box((0, DECK + 0.02, 0), (13.6, 0.04, 13.6), "grille")
    for sx in (-1, 1):
        p.box((sx * 3.6, DECK + 0.04, -5.2), (3.6, 0.05, 2.4), "team", bevel=0.02)
        p.box((sx * 3.6, DECK + 0.04, 5.2), (3.6, 0.05, 2.4), "team", bevel=0.02)
    hazard(p, (0, 0.82, -10.0), (1, 0, 0), UP, 10.0, 0.6, stripes=18)
    p.box((5.6, DECK + 0.03, -1.8), (2.0, 0.04, 2.6), "steel", bevel=0.01)  # welded patch
    # the derrick: four legs on foot plates, four braced rings, X bracing
    for sx, sz in CORNERS:
        beam(p, leg_at(sx, sz, DECK), leg_at(sx, sz, TOP_Y), 0.5, "trim", bevel=0.04)
        p.box((sx * LEG_FOOT, DECK + 0.22, sz * LEG_FOOT), (1.1, 0.44, 1.1), "dark", bevel=0.05)
    for y in (3.8, 6.6, 9.4, 11.8):
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.26, "dark")
    for i, (sx, sz) in enumerate(CORNERS):
        nx, nz = CORNERS[(i + 1) % 4]
        for ya, yb in ((3.8, 6.6), (6.6, 9.4), (9.4, 11.8)):
            beam(p, leg_at(sx, sz, ya), leg_at(nx, nz, yb), 0.16, "steel")
            beam(p, leg_at(nx, nz, ya), leg_at(sx, sz, yb), 0.16, "steel")
    for sx, sz in CORNERS:  # amber beacons on the legs
        x, y, z = leg_at(sx, sz, 6.6)
        p.box((x, y + 0.32, z), (0.55, 0.34, 0.55), "light")
    # guy cables from the top ring to anchor blocks on the back corners
    for sx in (-1, 1):
        p.box((sx * 9.6, 1.1, 9.0), (1.0, 0.6, 1.0), "trim", bevel=0.05)
        cable(p, [leg_at(sx, 1, 11.8), (sx * 9.6, 1.4, 9.0)], r=0.06, kind="steel")
    # head block: a team roof, a crown sheave, a lit front, a beacon
    p.box((0, TOP_Y + 0.6, 0), (4.4, 1.2, 4.4), "paint", bevel=0.1)
    p.box((0, TOP_Y + 1.22, 0), (3.6, 0.05, 3.6), "team", bevel=0.015)
    p.box((0, TOP_Y + 0.6, -2.22), (3.0, 0.16, 0.04), "light")
    p.cylinder("x", (0, TOP_Y + 1.9, 0.6), 1.0, 0.5, 14, "steel", cap_kinds=("trim", "trim"))
    for sx in (-1, 1):
        p.box((sx * 0.45, TOP_Y + 1.6, 0.6), (0.14, 0.9, 0.5), "dark")
    p.cylinder("y", (1.6, TOP_Y + 1.5, -1.6), 0.24, 0.5, 8, "light")
    # engine houses on the right flank: team roofs, twin stacks, hot vents
    for sz in (-1, 1):
        ex, ez = 9.2, sz * 4.2
        p.prism_y(rect(ex, ez, 1.8, 1.9), 0.8, 3.6, "paint", bevel=0.12)
        p.box((ex, 3.64, ez), (3.2, 0.05, 3.4), "team", bevel=0.02)
        p.box((ex + 1.82, 2.2, ez), (0.05, 0.8, 2.6), "power")
        p.box((ex, 2.0, ez - sz * 1.92), (2.6, 1.4, 0.05), "grille")
        for dz in (-0.7, 0.7):
            p.cylinder("y", (ex - 0.6, 4.8, ez + dz), 0.3, 2.4, 10, "steel")
            p.cylinder("y", (ex - 0.6, 6.05, ez + dz), 0.33, 0.12, 10, "power")
        cable(p, [(ex - 1.8, 2.6, ez), (7.0, 2.6, ez * 0.5), (2.2, 2.2, ez * 0.2)], r=0.18, kind="steel")
    # strapped fuel tanks on the left flank, piped to the drill collar
    for sz in (-1, 1):
        tank(p, -9.2, sz * 4.2, 1.75, 4.4, 0.8)
        cable(p, [(-7.5, 2.0, sz * 4.2), (-4.0, 2.0, sz * 2.5), (-2.1, 2.0, sz * 0.9)], r=0.2, kind="steel")
    # slat cages along the front and back platform edges
    for sz in (-1, 1):
        z = sz * 7.15
        for y in (2.3, 3.2):
            p.box((0, y, z), (9.6, 0.14, 0.14), "dark")
        for i in range(15):
            p.box((-4.6 + i * (9.2 / 14), 2.6, z), (0.1, 1.5, 0.08), "steel")
        for sx in (-1, 1):
            p.box((sx * 4.8, 2.4, z), (0.24, 2.0, 0.24), "trim")
    # ore hopper (front left corner) fed by a skip conveyor from the deck
    hx, hz = -8.6, -8.4
    for lx in (-1.0, 1.0):
        for lz in (-1.0, 1.0):
            p.box((hx + lx, 2.2, hz + lz), (0.26, 2.8, 0.26), "dark")
    p.prism_y(rect(hx, hz, 1.2, 1.2), 3.0, 5.0, "paint", bevel=0.1, top_scale=1.35)
    p.obox((hx + 1.45, 4.0, hz), (0, 0, 1), (1, 0.25, 0), 2.4, 1.4, 0.06, "team", bevel=0.02)
    p.box((hx, 5.02, hz), (2.9, 0.06, 2.9), "grille")
    a, b = V((-4.2, DECK + 0.2, -5.6)), V((hx + 0.9, 5.3, hz + 0.6))
    u = b - a
    p.obox(tuple((a + b) / 2), tuple(u), UP, u.length, 1.0, 0.3, "trim", bevel=0.04)
    p.obox(tuple((a + b) / 2 + V((0, 0.17, 0))), tuple(u), UP, u.length * 0.95, 0.76, 0.04, "grille")
    for sx in (-1, 1):  # beacons on the platform corners
        for sz in (-1, 1):
            p.box((sx * 6.9, DECK + 0.12, sz * 6.9), (0.36, 0.24, 0.36), "light")

    # the drill string: a glowing collar, a thick turning shaft, hot bands, flights
    with p.sub("drill", (0.0, DECK, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, DECK + 0.55, 0), 2.0, 1.1, 16, "trim")
        hoop(p, (0, DECK + 1.26, 0), 1.95, 1.75, 0.26, 16, "power")
        p.cylinder("y", (0, 7.4, 0), 1.05, 10.6, 12, "steel")
        for y in (4.6, 7.4, 10.2):
            hoop(p, (0, y, 0), 1.1, 0.95, 0.22, 12, "power")
        for k in range(6):  # flights spiralling round the shaft
            a = math.radians(30 + 60 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            p.obox(tuple(V((0, 3.4 + k * 1.05, 0)) + d * 1.3), tuple(d), UP, 0.7, 0.9, 0.12, "dark")
        p.box((0, 12.6, 0), (1.5, 0.7, 1.5), "trim", bevel=0.05)  # kelly drive


def details_base(p):
    for sz in (-1, 1):
        rivets(p, (7.6, 3.62, sz * 4.2 - 1.4), (10.8, 3.62, sz * 4.2 - 1.4), 6, UP)
        seam(p, (7.4, 2.2, sz * 4.2 - sz * 1.91), (11.0, 2.2, sz * 4.2 - sz * 1.91), (0, 0, -sz))
    for sx in (-1, 1):
        rivets(p, (sx * 7.1, DECK + 0.01, -6.4), (sx * 7.1, DECK + 0.01, 6.4), 10, UP)


unit.run(__file__, "chs_advextractor", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-34, 27, -40), (0, 6.0, 0), 50),
                   ("80", (0, 56, 9), (0, 4, 0), 50),
                   ("close", (-17, 15, -20), (0, 7.0, 0), 35)])
