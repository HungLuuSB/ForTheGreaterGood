"""Deepear (Chaos sonar station, T2 structure, footprint 3, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_deepear/build.py

New mesh at the size scale (S-104, M-26: footprint 3, 24 x 24 studs, about
10 above the water), from its blockout; the T1 Listener's big brother, not a
rescale. The waterline is y = 0. Big shapes first: four strapped drum floats
on the corners with beacons, an open deck frame of beams with grated panels
round a central well, large team plates and hazard edges; over the well an
A-frame gantry with a winch, and hung from it the client-turned sonar `drum`
(turn Y, rig.md 9) with its glowing band (the blockout's ring) and
hydrophone fins; a lattice mast with a strut, a flat sensor panel (unlit
face, amber edge) and a lamp; a generator crate with a team roof and a hot
vent, fuel drums, a cable reel and cable runs. Chaos reads rugged, light and
open (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

V = lib.vec
DECK = 1.4  # deck top
WELL = 3.6  # half size of the central well
FL = 8.6  # float offset
MAST = (6.4, 6.4)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))
VV = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (MAST[0], 9.6, MAST[1])


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


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + VV[k] * b + N[k] * n for k in range(3))


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def build_base(p):
    # four strapped drum floats with conical tops and beacons
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * FL, sz * FL
            p.cylinder("y", (x, -0.3, z), 2.4, 2.6, 16, "paint", bevel=0.05)
            p.ocyl((x, 1.0, z), UP, 2.4, 0.4, 16, "trim", radius2=1.9)
            for y in (-0.6, 0.4):
                p.cylinder("y", (x, y, z), 2.45, 0.22, 16, "dark")
            p.box((x + sx * 1.0, DECK + 0.25, z + sz * 1.0), (0.4, 0.3, 0.4), "light")
    # the open deck frame: perimeter and well beams, grated panels
    for s in (-1, 1):
        p.box((0, DECK - 0.35, s * 9.6), (19.6, 0.7, 0.7), "trim", bevel=0.05)
        p.box((s * 9.6, DECK - 0.35, 0), (0.7, 0.7, 19.6), "trim", bevel=0.05)
        p.box((0, DECK - 0.3, s * WELL), (2 * WELL + 0.6, 0.6, 0.5), "steel")
        p.box((s * WELL, DECK - 0.3, 0), (0.5, 0.6, 2 * WELL + 0.6), "steel")
        p.box((0, DECK - 0.03, s * 6.6), (18.6, 0.06, 5.4), "grille")
        p.box((s * 6.6, DECK - 0.03, 0), (5.4, 0.06, 2 * WELL - 0.4), "grille")
    p.box((-5.8, DECK + 0.03, 6.4), (4.6, 0.05, 4.6), "team", bevel=0.015)
    p.box((6.0, DECK + 0.03, -6.2), (4.6, 0.05, 4.6), "team", bevel=0.015)
    for s in (-1, 1):  # hazard edges round the well
        hazard(p, (0, DECK + 0.02, s * (WELL + 0.6)), (1, 0, 0), UP, 6.4, 0.5, stripes=11)
    p.box((-2.6, DECK + 0.02, -8.2), (2.2, 0.04, 1.6), "steel", bevel=0.01)  # welded patch
    # A-frame gantry over the well with a winch
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(p, (sx * (WELL + 0.2), DECK, sz * 1.6), (sx * 1.0, 6.2, 0), 0.32, "paint", bevel=0.03)
    p.box((0, 6.35, 0), (3.4, 0.5, 0.6), "trim", bevel=0.04)
    p.cylinder("x", (0, 6.9, 0.0), 0.5, 1.6, 12, "dark", cap_kinds=("steel", "steel"))
    p.box((0, 7.0, 0), (0.4, 0.14, 0.5), "light")
    # the lattice mast with a strut, its sensor panel and a lamp
    mx, mz = MAST
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            p.box((mx + dx, 4.9, mz + dz), (0.18, 7.0, 0.18), "steel")
    for y in (2.4, 4.0, 5.6, 7.2):
        p.box((mx, y, mz), (1.1, 0.1, 1.1), "dark")
    beam(p, (mx + 2.4, DECK, mz), (mx + 0.45, 6.0, mz), 0.2, "steel")
    beam(p, (mx, DECK, mz - 2.4), (mx, 6.0, mz - 0.45), 0.2, "steel")
    p.box((mx, 8.5, mz), (1.2, 0.3, 1.2), "trim")
    p.obox(at(0, -0.5, -0.3), U, N, 0.4, 1.0, 0.3, "steel")
    p.obox(PANEL, U, N, 3.4, 2.0, 0.26, "paint", bevel=0.03)
    p.obox(at(0, 0, 0.14), U, N, 3.1, 1.7, 0.03, "dark")
    for b in (-0.8, 0.8):
        p.obox(at(0, b, 0.16), U, N, 3.1, 0.08, 0.02, "light")
    for a in (-1.5, 1.5):
        p.obox(at(a, 0, 0.16), U, N, 0.08, 1.6, 0.02, "light")
    p.obox(at(0, 0, 0.16), U, N, 0.04, 1.6, 0.02, "light")
    p.obox(at(-0.8, 0.3, 0.18), U, N, 0.9, 0.6, 0.03, "steel")  # welded patch
    p.obox(at(0, 0.1, -0.15), U, N, 3.0, 1.2, 0.03, "team")
    p.box((mx + 0.6, 10.9, mz + 0.4), (0.26, 0.18, 0.26), "light")
    p.cylinder("y", (mx + 0.6, 10.3, mz + 0.4), 0.06, 1.0, 6, "steel")
    # generator crate (front left) with a team roof and a hot vent; fuel drums
    p.prism_y(rect(-6.2, -6.4, 1.7, 1.3), DECK, 3.5, "paint", bevel=0.07)
    p.box((-6.2, 3.54, -6.4), (3.2, 0.05, 2.4), "team", bevel=0.012)
    p.box((-6.2, 2.4, -7.72), (2.2, 0.45, 0.05), "power")
    p.ocyl((-7.2, 3.5, -5.8), UP, 0.26, 1.2, 10, "steel")
    p.cylinder("y", (-7.2, 4.74, -5.8), 0.24, 0.07, 10, "power")
    for z in (-3.0, -1.9):
        drum(p, (-7.6, DECK + 0.45, z), 0.45, 1.0, "trim", "dark", sides=10, axis="x")
    # cable reel by the winch, cable runs
    p.cylinder("z", (2.4, DECK + 0.9, 6.0), 0.9, 1.2, 14, "dark", cap_kinds=("trim", "trim"))
    p.box((2.4, DECK + 0.3, 6.0), (1.6, 0.6, 1.4), "trim")
    cable(p, [(2.4, DECK + 1.6, 5.4), (1.2, 4.0, 2.4), (0.4, 6.4, 0.4)], r=0.07, kind="dark")
    cable(p, [(-4.6, 2.4, -6.0), (-3.0, DECK + 0.1, -4.2), (-1.2, DECK + 0.1, -4.0)], r=0.09, kind="dark")

    # the sonar drum: hung on its cable, a glowing band, hydrophone fins
    with p.sub("drum", (0.0, DECK, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 4.0, 0), 0.12, 4.0, 6, "steel")
        p.cylinder("y", (0, 0.2, 0), 3.0, 2.4, 18, "paint", bevel=0.05)
        p.ocyl((0, 1.4, 0), UP, 3.0, 0.35, 18, "trim", radius2=2.2)
        hoop(p, (0, 0.9, 0), 3.06, 2.85, 0.3, 18, "power")
        for k in range(6):
            t = 2 * math.pi * (k + 0.5) / 6
            p.box((3.0 * math.cos(t), -0.2, 3.0 * math.sin(t)), (0.45, 1.2, 0.45), "dark")


def details_base(p):
    for s in (-1, 1):
        rivets(p, (-9.0, DECK + 0.01, s * 9.6), (9.0, DECK + 0.01, s * 9.6), 14, UP)
    rivets(p, (-7.6, 3.541, -7.4), (-4.8, 3.541, -7.4), 5, UP)
    ring(p, (0, 1.76, 0), UP, 1.6)


unit.run(__file__, "chs_deepear", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-32, 25, -38), (0, 3.0, 0), 50),
                   ("80", (0, 52, 9), (0, 2, 0), 50),
                   ("close", (-16, 12, -19), (0, 4.0, 0), 38)])
