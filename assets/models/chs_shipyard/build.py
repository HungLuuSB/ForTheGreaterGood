"""Shipyard (Chaos naval factory, T1 structure, footprint 5, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_shipyard/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 5, 40 x 40
studs; the shed about 7 tall, the tower crane about 15: the tallest T1
buildings). The waterline is y = 0. Big shapes first:
- a patched quay at the back with a corrugated shed (a large team roof, a
  door with build lights: power, pulses while producing), salvage tanks
  with team caps and amber gauges, a hot stack;
- two narrow piers on piles with large team plates, hazard slip edges,
  rubber-tyre fenders, amber running and tip lights, and an emitter arm on
  the right pier over the slip (`nano2`);
- a tall braced lattice tower crane on the left pier with an operator cab
  and the client-slewed `jib` (turn, M-27): a girder jib with a team band,
  a counter-jib with its counterweight inside the footprint (user review
  2026-10-23) and a hook trolley with a build lamp (`nano1`, on the jib).
Chaos reads rugged, light and open (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, rect, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

V = lib.vec
PX, PW = 16.5, 2.4  # pier centre (x mirrored), half width
TX, TZ = -16.5, 4.0  # tower crane
JIB_Y = 14.6


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def build_base(p):
    # patched quay, from below the water to the deck
    quay = [(-19.6, 11.4), (19.6, 11.4), (19.6, 18.6), (18.6, 19.6), (-18.6, 19.6), (-19.6, 18.6)]
    p.prism_y(quay, -1.0, 0.7, "dark", bevel=0.1)
    for x, z, w, d in ((4.0, 13.0, 8.0, 2.4), (-12.0, 18.4, 6.0, 1.8)):
        p.box((x, 0.72, z), (w, 0.04, d), "trim", bevel=0.01)
    hazard(p, (0, 0.73, 11.9), (1, 0, 0), UP, 36.0, 0.6, stripes=48)
    # corrugated shed: team roof, door with build lights
    p.prism_x([(12.6, 0.7), (19.2, 0.7), (19.2, 6.4), (12.6, 7.4)], -14.0, 1.0, "paint", bevel=0.1)
    for i in range(10):
        p.box((-13.0 + i * 1.5, 3.55, 19.24), (0.24, 5.3, 0.08), "trim")
    p.obox((-6.5, 6.97, 15.9), (1, 0, 0), (0, 1, 0.152), 14.0, 6.0, 0.06, "team", bevel=0.015)
    p.box((-6.5, 3.2, 12.56), (10.0, 5.0, 0.1), "dark")
    for i in range(4):
        p.box((-6.5, 1.3 + i * 1.15, 12.49), (9.6, 0.14, 0.06), "power")
    for sx in (-1, 1):
        p.box((-6.5 + sx * 5.2, 3.3, 12.45), (0.3, 5.2, 0.12), "power")
    p.ocyl((-12.0, 6.6, 17.6), UP, 0.55, 3.0, 10, "steel")
    p.cylinder("y", (-12.0, 9.64, 17.6), 0.5, 0.08, 10, "power")
    # salvage tanks with team caps and gauges
    for x, r, h in ((6.0, 1.8, 4.6), (10.6, 1.5, 3.8), (14.6, 1.3, 3.2)):
        p.cylinder("y", (x, 0.7 + h / 2, 15.8), r, h, 16, "paint", bevel=0.05)
        p.ocyl((x, 0.7 + h, 15.8), UP, r, 0.4, 16, "trim", radius2=r * 0.75)
        p.cylinder("y", (x, 1.15 + h, 15.8), r * 0.72, 0.06, 14, "team")
        p.cylinder("y", (x, 0.7 + h * 0.55, 15.8), r + 0.05, 0.18, 16, "dark")
        p.box((x, 0.7 + h * 0.42, 15.8 - r - 0.03), (0.4, h * 0.45, 0.05), "power")
    cable(p, [(6.0, 3.6, 13.9), (8.3, 2.6, 13.6), (10.6, 3.0, 14.2)], r=0.16, kind="steel")
    # piers on piles: deck, team plates, hazard slip edges, fenders, lights
    for sx in (-1, 1):
        x = sx * PX
        p.box((x, 1.7, -3.6), (2 * PW, 1.0, 30.0), "paint", bevel=0.06)
        p.box((x, 2.23, -12.0), (3.8, 0.05, 8.0), "team", bevel=0.012)
        p.box((x, 2.23, 4.0), (3.8, 0.05, 6.0), "team", bevel=0.012)
        hazard(p, (x - sx * (PW - 0.3), 2.24, -3.6), (0, 0, 1), UP, 29.0, 0.45, stripes=36)
        for i in range(6):
            z = -17.0 + i * 5.6
            p.cylinder("y", (x - sx * 1.6, 0.0, z), 0.42, 2.6, 8, "steel")
            p.cylinder("y", (x + sx * 1.6, 0.0, z), 0.42, 2.6, 8, "steel")
        for z in (-14.0, -6.0, 2.0):  # tyre fenders on the slip side
            p.ocyl((x - sx * (PW + 0.3), 1.4, z), (0, 0, 1), 0.55, 0.5, 10, "rubber")
        p.box((x + sx * (PW + 0.02), 1.6, -3.6), (0.06, 0.16, 26.0), "light")
        p.box((x, 2.6, -18.4), (0.6, 0.6, 0.6), "light")  # tip light
    # emitter arm on the right pier over the slip
    a, b = V((PX - 1.2, 2.3, 1.5)), V((11.6, 4.6, 1.2))
    p.box((PX - 1.2, 2.7, 1.5), (1.2, 0.8, 1.2), "trim", bevel=0.04)
    p.obox(tuple((a + b) / 2), tuple(b - a), (0, 1, 0), (b - a).length, 0.45, 0.45, "trim", bevel=0.03)
    p.ocyl(tuple(b), (0, -1, 0), 0.45, 0.4, 12, "dark")
    p.cylinder("y", (b.x, b.y - 0.42, b.z), 0.32, 0.06, 12, "power")
    # tower crane: four legs, braced rings, X braces, cab, slewing ring
    for dx in (-1, 1):
        for dz in (-1, 1):
            beam(p, (TX + dx * 1.4, 2.2, TZ + dz * 1.4), (TX + dx * 1.0, JIB_Y - 1.0, TZ + dz * 1.0), 0.38, "paint", bevel=0.03)
            p.box((TX + dx * 1.4, 2.45, TZ + dz * 1.4), (0.8, 0.5, 0.8), "trim")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

    def leg(dx, dz, y):
        f = 1.4 - 0.4 * (y - 2.2) / (JIB_Y - 3.2)
        return (TX + dx * f, y, TZ + dz * f)

    for y in (5.0, 8.4, 11.8):
        for i, (dx, dz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg(dx, dz, y), leg(nx, nz, y), 0.16, "steel")
            beam(p, leg(dx, dz, y - 3.0), leg(nx, nz, y), 0.1, "steel")
    for dx, dz in corners:
        x, y, z = leg(dx, dz, 8.4)
        p.box((x, y + 0.2, z), (0.36, 0.26, 0.36), "light")
    p.box((TX, JIB_Y - 0.8, TZ), (2.6, 0.5, 2.6), "trim", bevel=0.04)
    with p.sub("jib", (TX, JIB_Y - 0.4, TZ), "turn", (0, 1, 0)):  # M-27 the tower crane slews
        p.cylinder("y", (TX, JIB_Y - 0.4, TZ), 1.1, 0.4, 14, "steel")
        p.box((TX + 1.6, JIB_Y + 0.6, TZ - 1.4), (1.6, 1.4, 1.4), "paint", bevel=0.05)  # operator cab
        p.box((TX + 1.6, JIB_Y + 0.75, TZ - 2.12), (1.2, 0.6, 0.05), "glass")
        p.box((TX + 13.0, JIB_Y, TZ), (26.0, 0.9, 1.1), "paint", bevel=0.04)  # jib
        for k in range(9):  # lattice triangles on the jib's sides
            x = TX + 1.8 + k * 2.7
            for dz in (-0.58, 0.58):
                p.obox((x, JIB_Y, TZ + dz), (1, 1, 0), (0, 0, 1), 1.2, 0.12, 0.06, "steel")
        p.box((TX + 14.0, JIB_Y + 0.48, TZ), (12.0, 0.05, 0.9), "team")
        p.box((TX - 1.4, JIB_Y, TZ), (2.6, 0.8, 1.1), "trim")  # counter-jib, inside the footprint
        p.box((TX - 2.2, JIB_Y - 0.8, TZ), (1.2, 1.4, 1.4), "steel", bevel=0.04)  # counterweight
        p.box((TX + 20.5, JIB_Y - 0.75, TZ), (1.6, 0.6, 1.4), "trim", bevel=0.04)  # trolley
        p.cylinder("y", (TX + 20.5, JIB_Y - 1.6, TZ), 0.05, 1.2, 6, "steel")
        p.box((TX + 20.5, JIB_Y - 2.35, TZ), (0.9, 0.4, 0.9), "dark", bevel=0.03)
        p.box((TX + 20.5, JIB_Y - 2.57, TZ), (0.7, 0.05, 0.7), "power")
        p.box((TX + 25.4, JIB_Y + 0.7, TZ), (0.5, 0.5, 0.5), "light")
        hazard(p, (TX + 5.0, JIB_Y, TZ - 0.57), (1, 0, 0), (0, 0, -1), 6.0, 0.5, stripes=8)


def details_base(p):
    bolts(p, (-18.0, 0.701, 19.2), (18.0, 0.701, 19.2), 20, UP)
    rivets(p, (-13.6, 1.4, 12.58), (-1.0, 1.4, 12.58), 12, (0, 0, -1))
    for x, r in ((6.0, 1.8), (10.6, 1.5)):
        ring(p, (x, 0.7 + 1.0, 15.8 - r - 0.01), (0, 0, -1), 0.3)


unit.run(__file__, "chs_shipyard", "chaos", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
