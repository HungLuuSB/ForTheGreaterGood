"""Choir (Order sonar station, T2 structure, footprint 3, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_choir/build.py

New mesh at the size scale (S-104, M-26: footprint 3, 24 x 24 studs, about
11 above the water), from its blockout; the T1 Ear's big brother, not a
rescale. The waterline is y = 0. Big shapes first: a floating armored
octagonal hull with sloped upper sides, running strips at the waterline,
team plates on the sloped sides and on the deck corners, hazard edges,
bollards, corner sponsons with lights, grated walkways and two towed-array
winch houses; hydrophone booms reaching out to port and starboard with pods
hanging in the water; the client-turned glowing sonar `ring` (turn Y,
rig.md 9) round the base of a stepped armored housing with a team roof ring
and a domed cap, a big sonar dome under the hull; a tall armored mast with a
lit collar and a flat sensor panel (unlit face, glowing edge), a lamp and
aerials; a control cabin with a lit window strip at the back. Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

DECK = 1.4
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))
VV = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 11.5, 0.2)


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


def build_base(p):
    # the hull: below the water, upright sides, sloped upper sides, a deck
    p.prism_y(octagon(11.2, 2.6), -1.6, 0.5, "paint", bevel=0.14)
    p.prism_y(octagon(11.2, 2.6), 0.5, DECK, "paint", bevel=0.14, top_scale=0.92)
    for s in (-1, 1):
        p.box((s * 11.22, 0.15, 0), (0.05, 0.16, 5.0), "light")
        p.box((0, 0.15, s * 11.22), (5.0, 0.16, 0.05), "light")
        k = math.atan2(0.9, 11.2 * 0.08)
        n = (0.0, math.cos(k), s * math.sin(k))
        p.obox((0, 0.95, s * 10.77), (1, 0, 0), n, 6.0, 1.0, 0.05, "team", bevel=0.012)
    for sx in (-1, 1):  # team plates on the deck corners
        p.box((sx * 5.4, DECK + 0.03, sx * 5.4), (3.6, 0.06, 3.6), "team", bevel=0.02)
    # towed-array winch houses on the other two corners, hazard striping
    for sx in (-1, 1):
        wx, wz = -sx * 5.6, sx * 5.6
        p.prism_y(rect(wx, wz, 1.3, 1.0), DECK, DECK + 1.6, "paint", bevel=0.08)
        p.box((wx, DECK + 1.62, wz), (2.2, 0.04, 1.6), "grille")
        p.cylinder("x", (wx, DECK + 0.75, wz + sx * 1.6), 0.6, 2.0, 12, "dark", cap_kinds=("steel", "steel"))
        p.box((wx, DECK + 1.2, wz - sx * 1.02), (1.6, 0.14, 0.04), "light")
        hazard(p, (wx, DECK + 0.03, wz + sx * 2.8), (1, 0, 0), UP, 2.8, 0.45, stripes=6)
        p.cylinder("z", (wx, DECK + 0.2, wz + sx * 3.8), 0.05, 2.0, 6, "steel")
    # grated walkways round the housing
    p.box((0, DECK + 0.02, -7.4), (5.0, 0.04, 2.4), "grille")
    for sx in (-1, 1):
        p.box((sx * 7.0, DECK + 0.02, 0), (2.2, 0.04, 5.0), "grille")
    # corner sponsons with lights, bollards
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 8.1, sz * 8.1
            p.prism_y([(x - 0.8, z - 0.8), (x + 0.8, z - 0.8), (x + 0.8, z + 0.8), (x - 0.8, z + 0.8)],
                      DECK, DECK + 0.6, "trim", bevel=0.06, top_scale=0.8)
            p.box((x, DECK + 0.66, z), (0.5, 0.12, 0.5), "light")
    for x, z in ((-3.6, -9.4), (3.6, -9.4), (-3.6, 9.4), (3.6, 9.4)):
        p.cylinder("y", (x, DECK + 0.25, z), 0.24, 0.5, 10, "steel")
    p.cylinder("y", (0, -2.1, 0), 3.6, 1.2, 20, "dark")  # sonar dome under the hull
    # hydrophone booms to port and starboard, with hanging pods
    for sx in (-1, 1):
        p.box((sx * 9.3, DECK + 0.35, 0), (1.6, 0.7, 1.8), "trim", bevel=0.06)
        p.box((sx * 10.6, DECK + 0.4, 0), (2.4, 0.36, 0.5), "paint", bevel=0.04)
        p.cylinder("y", (sx * 11.5, 0.2, 0), 0.1, 2.0, 6, "steel")
        p.cylinder("y", (sx * 11.5, -0.6, 0), 0.42, 0.9, 12, "dark")
        p.box((sx * 11.5, DECK + 0.62, 0), (0.3, 0.1, 0.3), "light")
    # stepped armored housing on a plinth, a team roof ring, a domed cap
    p.cylinder("y", (0, DECK + 0.2, 0), 5.2, 0.4, 24, "trim", bevel=0.04)
    p.cylinder("y", (0, 3.4, 0), 3.9, 2.3, 24, "paint", bevel=0.06)
    p.ocyl((0, 4.55, 0), UP, 3.9, 0.7, 24, "paint", radius2=3.1)
    p.cylinder("y", (0, 5.28, 0), 3.0, 0.06, 22, "team")
    p.ocyl((0, 5.25, 0), UP, 1.9, 0.9, 16, "trim", radius2=1.2)
    for k in range(8):  # running lights round the housing
        t = 2 * math.pi * (k + 0.5) / 8
        p.box((math.cos(t) * 3.92, 3.6, math.sin(t) * 3.92), (0.5, 0.12, 0.5), "light")
    # control cabin at the back with a lit window strip and a team roof
    p.prism_y(rect(0, 6.6, 2.4, 1.3), DECK + 0.4, 3.6, "paint", bevel=0.08)
    p.box((0, 3.64, 6.6), (4.2, 0.05, 2.2), "team", bevel=0.015)
    p.box((0, 3.0, 7.92), (3.6, 0.3, 0.05), "light")
    # the armored mast with its sensor panel, a lamp and aerials
    p.ocyl((0, 6.1, 0), UP, 0.95, 3.4, 8, "paint", radius2=0.6)
    p.prism_y(octagon(0.95, 0.3), 7.4, 7.9, "trim", bevel=0.04)
    p.prism_y(octagon(0.97, 0.31), 7.6, 7.72, "light")
    p.box((0, 9.7, 0.2), (0.8, 0.8, 0.8), "trim", bevel=0.04)
    p.obox(at(0, -0.6, -0.4), U, N, 0.6, 1.4, 0.45, "steel")
    p.obox(PANEL, U, N, 5.6, 2.8, 0.34, "paint", bevel=0.04)
    p.obox(at(0, 0, 0.18), U, N, 5.2, 2.4, 0.03, "dark")
    for b in (-1.15, 1.15):
        p.obox(at(0, b, 0.2), U, N, 5.2, 0.08, 0.02, "light")
    for a in (-2.55, 2.55):
        p.obox(at(a, 0, 0.2), U, N, 0.08, 2.3, 0.02, "light")
    for a in (-1.7, -0.85, 0.0, 0.85, 1.7):
        p.obox(at(a, 0, 0.2), U, N, 0.035, 2.3, 0.02, "light")
    p.obox(at(0, 0.0, 0.2), U, N, 5.1, 0.035, 0.02, "light")
    p.obox(at(0, 0.2, -0.19), U, N, 4.8, 1.8, 0.03, "team")
    p.cylinder("y", (0, 13.3, 0.85), 0.07, 2.0, 6, "steel")
    p.box((0, 14.35, 0.85), (0.22, 0.14, 0.22), "light")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 1.6, 4.3, 7.2), 0.05, 1.6, 6, "steel")

    # the sonar ring: hydrophone blocks on a turning band with a glowing rim
    with p.sub("ring", (0.0, DECK + 0.6, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, DECK + 0.78, 0), 4.8, 0.36, 28, "dark")
        for k in range(10):
            t = 2 * math.pi * k / 10
            p.box((4.8 * math.cos(t), DECK + 0.78, 4.8 * math.sin(t)), (0.5, 0.44, 0.5), "steel")
        hoop(p, (0, DECK + 0.78, 0), 4.84, 4.6, 0.12, 28, "power")


def details_base(p):
    for s in (-1, 1):
        rivets(p, (s * 4.2, DECK + 0.01, -8.4), (s * 4.2, DECK + 0.01, -3.0), 6, UP)
        seam(p, (s * 11.2, 0.5, -3.5), (s * 11.2, 0.5, 3.5), (s, 0, 0))
    ring(p, (0, 5.29, 0), UP, 2.4)
    rivets(p, (-2.0, 3.65, 5.7), (2.0, 3.65, 5.7), 6, UP)


unit.run(__file__, "ord_choir", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-32, 25, -38), (0, 3.0, 0), 50),
                   ("80", (0, 52, 9), (0, 2, 0), 50),
                   ("close", (-16, 12, -19), (0, 4.0, 0), 38)])
