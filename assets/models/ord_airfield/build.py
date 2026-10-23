"""Airfield (Order air factory, T1 structure, footprint 5): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_airfield/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 5, 40 x 40
studs; the hangar about 11 tall, the control tower about 12: the tallest
T1 buildings). Big shapes first:
- a chamfered slab;
- a runway along Z with team centre dashes, hazard threshold bars,
  edge and approach lights;
- a big armored arched hangar with ribs, a team roof in three bays,
  armored pilasters and a lit door frame facing the -Z exit (power: pulses
  while producing), back vents with glowing rims;
- the build pad in front of the hangar (team ring, hazard border,
  `buildpad`), two emitter booms from the pilasters and one on the lintel
  (`nano1..3`), a taxi line to the runway;
- a control tower with team plates, a lit glass cab and the client-turned
  `radar` panel (unlit face, glowing edge, M-27);
- fuel tanks with team bands and gauges, crates.
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import arch, cable, hazard, octagon, prism_z, rect, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

V = lib.vec
RX = 6.0  # runway centre line x
HX, HW, Z0, Z1, HTOP = -10.4, 8.0, 0.0, 17.0, 10.6  # hangar centre x, half width, depth, height
PAD = (-10.4, -8.0)
TX, TZ = 15.5, 12.5  # control tower
BAYS = [(3.15, 4.9), (8.75, 4.7), (14.15, 4.5)]  # team roof bays: (z centre, length)


def hangar_profile(grow=0.0):
    return arch(HX - HW - grow, HX + HW + grow, 0.5, HTOP + grow, steps=10, flat=0.3)


def boom(p, a, b):
    a, b = V(a), V(b)
    u = b - a
    p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.55, 0.55, "trim", bevel=0.04)
    p.ocyl(tuple(b), (0, -1, 0), 0.5, 0.45, 14, "dark")
    p.cylinder("y", (b.x, b.y - 0.47, b.z), 0.36, 0.06, 14, "power")


def build_base(p):
    p.prism_y(octagon(19.6, 1.6), 0.0, 0.5, "trim", bevel=0.16, top_scale=0.995)
    # runway: dark surface, team centre dashes, hazard thresholds, lights
    p.box((RX, 0.56, 0), (11, 0.12, 37), "dark")
    for i in range(7):
        p.box((RX, 0.635, -15 + i * 5), (0.9, 0.03, 3.0), "team")
    for zs in (-1, 1):
        hazard(p, (RX, 0.63, zs * 17.0), (1, 0, 0), UP, 10.4, 1.0, stripes=14)
        for k in range(5):
            p.box((RX - 3.2 + k * 1.6, 0.6, zs * 18.9), (0.9, 0.16, 0.4), "light")
    for i in range(6):
        z = -14.5 + i * 5.8
        for x in (RX - 5.75, RX + 5.75):
            p.box((x, 0.68, z), (0.45, 0.3, 0.45), "light")
    # the hangar: arched hall, ribs, team roof bays
    prism_z(p, hangar_profile(), Z0, Z1, "paint", bevel=0.12)
    pts = hangar_profile(0.02)
    for z in (0.2, 6.0, 11.5, 16.8):  # ribs: plate rings along the arch
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            d = V((x2 - x1, y2 - y1, 0))
            n = V((-d.y, d.x, 0)).normalized()
            c = V(((x1 + x2) / 2, (y1 + y2) / 2, z)) + n * 0.12
            p.obox(tuple(c), (0, 0, 1), tuple(n), 0.6, d.length + 0.12, 0.3, "trim")
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        if min(y1, y2) < 8.4:
            continue
        d = V((x2 - x1, y2 - y1, 0))
        n = V((-d.y, d.x, 0)).normalized()
        for zc, length in BAYS:
            c = V(((x1 + x2) / 2, (y1 + y2) / 2, zc)) + n * 0.03
            p.obox(tuple(c), (0, 0, 1), tuple(n), length, d.length * 1.02, 0.05, "team")
    # front: armored pilasters, door, lit frame, build lights, sill hazard
    for sx in (-1, 1):
        p.prism_y(rect(HX + sx * 7.0, -0.2, 1.1, 0.8), 0.5, 7.6, "paint", bevel=0.1, top_scale=0.85)
        p.box((HX + sx * 6.05, 0.5 + 3.9, -0.45), (0.3, 7.6, 0.14), "power")  # door frame
    p.box((HX, 4.4, -0.07), (11.6, 7.8, 0.1), "dark")
    p.box((HX, 8.45, -0.45), (12.4, 0.36, 0.16), "power")  # lintel
    for i in range(3):
        p.box((HX, 2.0 + i * 1.9, -0.12), (11.0, 0.14, 0.06), "power")  # build lights through the door
    hazard(p, (HX, 0.53, -0.9), (1, 0, 0), UP, 11.6, 0.7, stripes=18)
    # back: vents with glowing rims, a big grille
    for sx in (-1, 1):
        p.ocyl((HX + sx * 3.0, 9.8, 14.6), UP, 0.85, 1.8, 14, "trim", radius2=0.7)
        p.cylinder("y", (HX + sx * 3.0, 11.62, 14.6), 0.71, 0.08, 14, "power")
    p.box((HX, 4.0, Z1 + 0.03), (9.0, 4.0, 0.05), "grille")
    # build pad: dark plate, team ring, hazard edges, corner lights
    p.prism_y(octagon(4.7, 1.2, *PAD), 0.5, 0.62, "team", bevel=0.02)
    p.prism_y(octagon(4.2, 1.0, *PAD), 0.5, 0.7, "dark", bevel=0.04)
    for sz in (-1, 1):
        hazard(p, (PAD[0], 0.72, PAD[1] + sz * 5.0), (1, 0, 0), UP, 9.0, 0.4, stripes=16)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((PAD[0] + sx * 4.4, 0.78, PAD[1] + sz * 4.4), (0.4, 0.16, 0.4), "light")
    # emitter booms from the pilasters and a head on the lintel
    for sx in (-1, 1):
        boom(p, (HX + sx * 7.0, 7.2, -0.8), (HX + sx * 3.2, 5.8, -4.4))
    p.box((HX, 8.75, -1.0), (1.4, 0.6, 1.2), "trim", bevel=0.04)
    p.ocyl((HX, 8.5, -1.5), (0, -1, 0), 0.5, 0.45, 14, "dark")
    p.cylinder("y", (HX, 8.03, -1.5), 0.36, 0.06, 14, "power")
    # taxi line from the pad to the runway
    for k in range(5):
        p.box((-4.6 + k * 1.1, 0.53, PAD[1]), (0.6, 0.03, 0.3), "hazard")
    # control tower: tapered shaft, team plates, glass cab, roof
    p.prism_y(rect(TX, TZ, 2.0, 2.0), 0.5, 8.6, "paint", bevel=0.1, top_scale=0.82)
    for sx, sz in ((-1, 0), (0, -1)):
        if sx:
            p.obox((TX - 1.93, 6.2, TZ), (0, 0, 1), (-1, 0.045, 0), 2.4, 2.6, 0.05, "team", bevel=0.015)
        else:
            p.obox((TX, 6.2, TZ - 1.93), (1, 0, 0), (0, 0.045, -1), 2.4, 2.6, 0.05, "team", bevel=0.015)
    p.box((TX - 2.03, 2.0, TZ), (0.06, 2.4, 1.0), "dark")  # door
    p.prism_y(rect(TX, TZ, 2.3, 2.3), 8.6, 10.0, "glass", bevel=0.05)
    p.prism_y(rect(TX, TZ, 2.55, 2.55), 10.0, 10.45, "trim", bevel=0.05)
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):  # cab lights under the windows
        if sx:
            p.box((TX + sx * 2.33, 8.7, TZ), (0.06, 0.14, 4.2), "light")
        else:
            p.box((TX, 8.7, TZ + sz * 2.33), (4.2, 0.14, 0.06), "light")
    p.cylinder("y", (TX, 10.7, TZ), 0.5, 0.5, 12, "steel")
    t = math.radians(20)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (TX, 11.8, TZ)
    with p.sub("radar", (TX, 10.95, TZ), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (TX, 11.05, TZ), 0.4, 0.2, 10, "trim")
        p.obox(c, (1, 0, 0), n, 3.6, 2.2, 0.3, "paint", bevel=0.03)
        p.obox(tuple(c[k] + n[k] * 0.16 for k in range(3)), (1, 0, 0), n, 3.3, 1.9, 0.03, "dark")
        for b in (-0.95, 0.95):
            p.obox(tuple(c[k] + n[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), n, 3.3, 0.08, 0.02, "light")
        for a in (-1.65, 1.65):
            p.obox((c[0] + a, c[1] + n[1] * 0.18, c[2] + n[2] * 0.18), (1, 0, 0), n, 0.08, 1.9, 0.02, "light")
        p.obox(tuple(c[k] - n[k] * 0.17 for k in range(3)), (1, 0, 0), n, 2.8, 1.4, 0.03, "team")
    # fuel tanks with team bands and gauges, a feed pipe, crates
    for z in (-13.0, -8.4):
        p.cylinder("y", (15.6, 2.15, z), 1.7, 3.3, 18, "paint", bevel=0.05)
        p.ocyl((15.6, 3.8, z), UP, 1.7, 0.45, 18, "trim", radius2=1.25)
        p.cylinder("y", (15.6, 2.9, z), 1.74, 0.6, 18, "team")
        p.box((13.88, 1.8, z), (0.05, 1.4, 0.4), "power")
    cable(p, [(14.2, 1.0, -10.7), (13.0, 0.75, -10.7), (12.4, 0.75, -6.0)], r=0.16, kind="steel")
    for x, z in ((-1.2, 9.0), (-1.2, 11.0), (-2.6, 9.9)):
        p.box((x, 1.1, z), (1.3, 1.2, 1.3), "trim", bevel=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 19.0, 0.56, sz * 19.0), (0.6, 0.14, 0.6), "light")


def details_base(p):
    for z in (-12.0, 0.0, 12.0):
        seam(p, (-19.0, 0.501, z), (-0.5, 0.501, z), UP)
    seam(p, (13.0, 0.501, -18.5), (13.0, 0.501, 18.5), UP)
    for sx in (-1, 1):
        rivets(p, (HX + sx * 7.0 - 1.0, 1.4, -1.01), (HX + sx * 7.0 + 1.0, 1.4, -1.01), 4, (0, 0, -1))
    bolts(p, (-18.0, 0.501, 19.0), (18.0, 0.501, 19.0), 20, UP)


unit.run(__file__, "ord_airfield", "order", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
