"""Airfield (Chaos air factory, T1 structure, footprint 5): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_airfield/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 5, 40 x 40
studs; the hangar about 10 tall, the mast about 13: the tallest T1
buildings). Big shapes first:
- a dark slab of patched plates;
- a matte runway along Z (user review 2026-10-23) with team centre
  dashes, hazard thresholds, amber edge and approach lights;
- an open hangar: a big sloped corrugated roof on braced lattice posts with
  a large team plate, a corrugated back wall and a half side wall, the
  build pad under it (team stripes, hazard edges, `buildpad`), a hoist
  girder with three hanging emitter heads (`nano1..3`), work lamps and a
  lit roof edge (power: pulses while producing);
- a braced lattice mast with the client-turned `radar` panel (amber edge,
  M-27) and a beacon;
- salvage fuel drums with team caps and amber gauges, a pipe, crates.
Chaos reads rugged, light and open (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

V = lib.vec
RX = 6.0  # runway centre line x
HX, HW, HZ0, HZ1 = -10.8, 8.0, -0.4, 16.4  # hangar centre x, half width, front and back z
PAD = (-10.8, 6.8)
SLOPE = 1.0 / 17.0  # roof rises toward the back
MX, MZ = 15.4, 12.6  # radar mast
HEADS = (-3.6, 0.0, 3.6)  # emitter heads along the girder (x offsets)


def roof_y(z):
    return 8.6 + (z - HZ0) * SLOPE


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def build_base(p):
    p.prism_y(octagon(19.6, 1.2), 0.0, 0.5, "dark", bevel=0.1, top_scale=0.995)
    for x, z, w, d in ((-9, -13, 10, 8), (-1.5, 4, 3.5, 10), (15, -1, 7, 6)):  # patch plates
        p.box((x, 0.52, z), (w, 0.04, d), "trim", bevel=0.01)
    # runway: matte surface, team centre dashes, hazard thresholds, lights
    p.box((RX, 0.56, 0), (10, 0.12, 37), "rubber")
    for i in range(7):
        p.box((RX, 0.635, -15 + i * 5), (0.8, 0.03, 3.2), "team")
    for zs in (-1, 1):
        hazard(p, (RX, 0.63, zs * 17.0), (1, 0, 0), UP, 9.4, 1.0, stripes=13)
        for k in range(5):
            p.box((RX - 3.2 + k * 1.6, 0.6, zs * 18.9), (0.9, 0.16, 0.4), "light")
    for i in range(6):
        z = -14.5 + i * 5.8
        for x in (RX - 5.3, RX + 5.3):
            p.box((x, 0.68, z), (0.45, 0.3, 0.45), "light")
    # open hangar: lattice posts with braces, sloped corrugated roof
    for sx in (-1, 1):
        x = HX + sx * HW
        for z in (HZ0 + 0.4, 8.0, HZ1 - 0.4):
            beam(p, (x, 0.5, z), (x, roof_y(z) - 0.2, z), 0.55, "paint", bevel=0.04)
            p.box((x, 0.75, z), (1.0, 0.5, 1.0), "trim", bevel=0.04)
        for z0, z1 in ((HZ0 + 0.4, 8.0), (8.0, HZ1 - 0.4)):
            beam(p, (x, 1.0, z0), (x, roof_y(z1) - 1.0, z1), 0.18, "steel")
            beam(p, (x, roof_y(z0) - 1.0, z0), (x, 1.0, z1), 0.18, "steel")
    n = V((0, 1, -SLOPE)).normalized()
    zc = (HZ0 + HZ1) / 2
    p.obox((HX, roof_y(zc) + 0.2, zc), (1, 0, 0), tuple(n), 2 * HW + 1.6, HZ1 - HZ0 + 1.0, 0.4, "paint", bevel=0.06)
    for i in range(9):  # corrugation ribs along the roof
        x = HX - HW + i * HW / 4
        p.obox((x, roof_y(zc) + 0.43, zc), (1, 0, 0), tuple(n), 0.22, HZ1 - HZ0 + 0.8, 0.08, "trim")
    p.obox((HX, roof_y(zc) + 0.45, zc + 0.6), (1, 0, 0), tuple(n), 11.0, 12.0, 0.05, "team")
    p.box((HX, roof_y(HZ0) - 0.1, HZ0 - 0.45), (2 * HW + 1.4, 0.22, 0.08), "power")  # lit roof edge
    # corrugated back wall and a half side wall
    p.box((HX, 4.6, HZ1), (2 * HW, 8.2, 0.4), "paint", bevel=0.04)
    for i in range(11):
        p.box((HX - HW + 0.8 + i * 1.44, 4.6, HZ1 + 0.24), (0.24, 7.8, 0.08), "trim")
    p.box((HX - HW, 3.3, 11.6), (0.4, 5.6, 9.2), "paint", bevel=0.04)
    p.box((HX - HW - 0.22, 2.0, 11.6), (0.05, 0.16, 8.0), "light")
    # build pad under the roof: steel plate, team stripes, hazard edges
    p.box((PAD[0], 0.58, PAD[1]), (10.0, 0.16, 10.0), "steel", bevel=0.04)
    for dx in (-4.0, 4.0):
        p.box((PAD[0] + dx, 0.68, PAD[1]), (0.9, 0.05, 9.4), "team")
    for sz in (-1, 1):
        hazard(p, (PAD[0], 0.69, PAD[1] + sz * 4.8), (1, 0, 0), UP, 9.6, 0.4, stripes=16)
    # hoist girder with three hanging emitter heads, work lamps
    p.box((HX, roof_y(PAD[1]) - 0.55, PAD[1]), (2 * HW, 0.7, 0.8), "trim", bevel=0.05)
    for dx in HEADS:
        y = roof_y(PAD[1]) - 0.9
        p.cylinder("y", (HX + dx, y - 0.5, PAD[1]), 0.06, 1.0, 6, "steel")
        p.ocyl((HX + dx, y - 1.0, PAD[1]), (0, -1, 0), 0.5, 0.45, 12, "dark")
        p.cylinder("y", (HX + dx, y - 1.47, PAD[1]), 0.36, 0.06, 12, "power")
    for z in (1.6, 12.2):
        p.box((HX, roof_y(z) - 0.06, z), (6.0, 0.08, 1.0), "power")
    # lattice mast: four legs, braced rings, X braces, platform, beacon
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(p, (MX + sx * 1.8, 0.5, MZ + sz * 1.8), (MX + sx * 0.6, 11.0, MZ + sz * 0.6), 0.3, "paint", bevel=0.03)
            p.box((MX + sx * 1.8, 0.75, MZ + sz * 1.8), (0.7, 0.5, 0.7), "trim")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

    def leg(sx, sz, y):
        f = 1.8 - 1.2 * (y - 0.5) / 10.5
        return (MX + sx * f, y, MZ + sz * f)

    for y in (3.6, 7.2):
        for i, (sx, sz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg(sx, sz, y), leg(nx, nz, y), 0.14, "steel")
            beam(p, leg(sx, sz, y - 3.0), leg(nx, nz, y), 0.1, "steel")
    p.box((MX, 11.15, MZ), (1.8, 0.3, 1.8), "trim", bevel=0.03)
    p.cylinder("y", (MX, 11.4, MZ), 0.45, 0.2, 10, "steel")
    for sx, sz in corners:
        x, y, z = leg(sx, sz, 7.2)
        p.box((x, y + 0.2, z), (0.36, 0.26, 0.36), "light")
    t = math.radians(20)
    nn, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (MX, 12.5, MZ)
    with p.sub("radar", (MX, 11.5, MZ), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (MX, 11.6, MZ), 0.35, 0.2, 10, "trim")
        p.obox(c, (1, 0, 0), nn, 3.4, 2.1, 0.3, "paint", bevel=0.03)
        p.obox(tuple(c[k] + nn[k] * 0.16 for k in range(3)), (1, 0, 0), nn, 3.1, 1.8, 0.03, "dark")
        for b in (-0.9, 0.9):
            p.obox(tuple(c[k] + nn[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), nn, 3.1, 0.08, 0.02, "light")
        for a in (-1.55, 1.55):
            p.obox((c[0] + a, c[1] + nn[1] * 0.18, c[2] + nn[2] * 0.18), (1, 0, 0), nn, 0.08, 1.8, 0.02, "light")
        p.obox(tuple(c[k] - nn[k] * 0.17 + v[k] * 0.4 for k in range(3)), (1, 0, 0), nn, 3.0, 0.6, 0.03, "team")
    p.box((MX + 0.7, 12.0, MZ + 0.7), (0.4, 0.4, 0.4), "light")  # beacon
    # salvage fuel drums with team caps and gauges, a pipe, crates
    for x, z, r, h in ((15.2, -12.6, 1.8, 3.6), (15.6, -7.6, 1.4, 2.8)):
        p.cylinder("y", (x, 0.5 + h / 2, z), r, h, 16, "paint", bevel=0.05)
        p.ocyl((x, 0.5 + h, z), UP, r, 0.4, 16, "trim", radius2=r * 0.75)
        p.cylinder("y", (x, 0.95 + h, z), r * 0.72, 0.06, 14, "team")
        for y in (0.9, 0.5 + h * 0.6):
            p.cylinder("y", (x, y, z), r + 0.05, 0.18, 16, "dark")
        p.box((x - r - 0.03, 0.5 + h * 0.4, z), (0.05, h * 0.45, 0.4), "power")
    cable(p, [(13.4, 2.5, -12.6), (12.4, 0.9, -11.0), (12.0, 0.8, -5.0)], r=0.18, kind="steel")
    for x, z, s in ((-1.4, -6.0, 1.4), (-1.6, -4.2, 1.1), (-0.6, -5.2, 1.0)):
        p.box((x, 0.5 + s / 2, z), (s, s, s), "trim", bevel=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 19.0, 0.56, sz * 19.0), (0.6, 0.14, 0.6), "light")


def details_base(p):
    for z in (-10.0, 18.0):
        seam(p, (-18.5, 0.501, z), (-1.0, 0.501, z), UP)
    rivets(p, (-14.0, 0.541, -9.0), (-4.0, 0.541, -9.0), 10, UP)
    bolts(p, (-18.0, 0.501, 19.0), (18.0, 0.501, 19.0), 20, UP)


unit.run(__file__, "chs_airfield", "chaos", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
