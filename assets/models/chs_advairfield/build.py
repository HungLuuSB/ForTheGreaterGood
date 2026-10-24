"""Advanced Aerodrome (Chaos air factory, T2 structure, footprint 6): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advairfield/build.py

Designed at the size scale (S-104, M-26: footprint 6, 48 x 48 studs; the
hangars about 10 tall, the radar mast about 18), bigger and busier than the
T1 Airfield rather than a rescale. Big shapes first:
- a dark slab of patched plates;
- a matte runway along Z with team centre dashes and amber edge lights, a
  braced ski-jump ramp at its -Z end with a large team plate and a blast
  deflector raised on struts at its +Z end (the T2 signature, T1 vs T2
  check 2026-10-22);
- an open assembly hangar at the front left: a big sloped corrugated roof
  on braced lattice posts with a team plate, corrugated back and side
  walls, the build pad under it (team stripes, hazard edges, `buildpad`),
  a hoist girder with an emitter head at each end (`nano1`, `nano2`) and a
  hoist trolley running along it with a third (`trolley`, slide, rig.md 9;
  `nano3` rides with it), work lamps and a lit roof edge (power: pulses
  while producing);
- a corrugated arched workshop hut at the back left with a team ridge plate
  and an amber-lit door toward the runway;
- two rough rearm pads (the def's `rearmPads`) with a fuel bowser;
- a tall braced lattice mast with guy cables, the client-turned
  `radarPanel` (amber edge, M-27) and a beacon;
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
from mech import arch, cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

V = lib.vec
RX, RW = 7.0, 11.0  # runway centre line x, width
HX, HW, HZ0, HZ1 = -15.0, 8.0, -20.4, -2.8  # front hangar centre x, half width, front and back z
PAD = (-15.0, -11.4)
SLOPE = 1.6 / 17.6  # roof rises toward the back
MX, MZ = 18.6, 17.4  # radar mast
QZ0, QZ1, QX0, QX1 = 1.6, 19.0, -23.0, -8.4  # back hut: z span, x span (door at QX1)
REARM = ((18.6, -2.6), (18.6, 6.4))


def roof_y(z):
    return 8.4 + (z - HZ0) * SLOPE


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def head(p, x, y, z):
    p.cylinder("y", (x, y - 0.5, z), 0.06, 1.0, 6, "steel")
    p.ocyl((x, y - 1.0, z), (0, -1, 0), 0.52, 0.45, 12, "dark")
    p.cylinder("y", (x, y - 1.47, z), 0.38, 0.06, 12, "power")


def build_base(p):
    p.prism_y(octagon(23.6, 1.4), 0.0, 0.5, "dark", bevel=0.1, top_scale=0.996)
    for x, z, w, d in ((-4.0, -18.0, 4.0, 9.0), (-2.5, 8.0, 3.5, 12.0), (18.0, -21.0, 8.0, 3.0), (-15.0, 21.6, 12.0, 3.0)):
        p.box((x, 0.52, z), (w, 0.04, d), "trim", bevel=0.01)  # patch plates
    # runway: matte surface, team centre dashes, amber edge lights
    p.box((RX, 0.56, 2.0), (RW, 0.12, 36.0), "rubber")
    for i in range(6):
        p.box((RX, 0.635, -12.5 + i * 5.6), (0.9, 0.03, 3.2), "team")
    hazard(p, (RX, 0.63, -14.6), (1, 0, 0), UP, RW - 0.6, 1.0, stripes=15)
    for i in range(6):
        z = -13.0 + i * 6.2
        for x in (RX - RW / 2 - 0.3, RX + RW / 2 + 0.3):
            p.box((x, 0.68, z), (0.45, 0.3, 0.45), "light")
    # ski-jump ramp at the -Z end: a curved deck, a team plate, side trusses
    prof = [(-16.0, 0.5), (-16.0, 0.62), (-18.0, 0.95), (-19.8, 1.6), (-21.3, 2.45), (-22.4, 3.2), (-23.2, 3.3), (-23.2, 0.5)]
    p.prism_x(prof, RX - RW / 2, RX + RW / 2, "paint", bevel=0.05)
    for (z1, y1), (z2, y2) in zip(prof[1:5], prof[2:6]):
        d = V((0, y2 - y1, z2 - z1))
        n = V((0, -(z2 - z1), (y2 - y1))).normalized()
        if n.y < 0:
            n = -n
        p.obox((RX, (y1 + y2) / 2 + n.y * 0.04, (z1 + z2) / 2 + n.z * 0.04), (1, 0, 0), tuple(n), RW - 2.4, d.length * 1.02, 0.05, "team")
    hazard(p, (RX, 3.33, -22.8), (1, 0, 0), UP, RW - 0.4, 0.7, stripes=15)
    for sx in (-1, 1):
        x = RX + sx * (RW / 2 + 0.15)
        for a, b in (((-16.4, 0.6), (-22.8, 3.1)), ((-19.0, 0.6), (-22.8, 2.4)), ((-19.0, 1.2), (-21.4, 2.3))):
            beam(p, (x, a[1], a[0]), (x, b[1], b[0]), 0.2, "steel")
        p.box((x, 3.4, -23.0), (0.36, 0.26, 0.36), "light")
    # blast deflector at the +Z end, raised on struts
    t = math.radians(55)
    dn = V((0, math.cos(t), -math.sin(t)))
    p.obox((RX, 2.4, 21.6), (1, 0, 0), tuple(dn), RW - 0.4, 4.0, 0.3, "trim", bevel=0.04)
    for k in range(6):
        p.obox(tuple(V((RX - 4.5 + k * 1.8, 2.4, 21.6)) + dn * 0.17), (1, 0, 0), tuple(dn), 0.2, 3.8, 0.06, "steel")
    for sx in (-1, 0, 1):
        beam(p, (RX + sx * 4.2, 0.5, 23.2), (RX + sx * 4.2, 3.6, 22.4), 0.3, "dark")
    p.box((RX, 0.6, 20.2), (RW - 0.4, 0.2, 0.3), "light")
    # front hangar: lattice posts with braces, sloped corrugated roof
    for sx in (-1, 1):
        x = HX + sx * HW
        for z in (HZ0 + 0.4, (HZ0 + HZ1) / 2, HZ1 - 0.4):
            beam(p, (x, 0.5, z), (x, roof_y(z) - 0.2, z), 0.6, "paint", bevel=0.04)
            p.box((x, 0.75, z), (1.1, 0.5, 1.1), "trim", bevel=0.04)
        zm = (HZ0 + HZ1) / 2
        for z0, z1 in ((HZ0 + 0.4, zm), (zm, HZ1 - 0.4)):
            beam(p, (x, 1.0, z0), (x, roof_y(z1) - 1.0, z1), 0.2, "steel")
            beam(p, (x, roof_y(z0) - 1.0, z0), (x, 1.0, z1), 0.2, "steel")
    n = V((0, 1, -SLOPE)).normalized()
    zc = (HZ0 + HZ1) / 2
    p.obox((HX, roof_y(zc) + 0.2, zc), (1, 0, 0), tuple(n), 2 * HW + 1.8, HZ1 - HZ0 + 1.2, 0.4, "paint", bevel=0.06)
    for i in range(9):  # corrugation ribs along the roof
        x = HX - HW + i * HW / 4
        p.obox((x, roof_y(zc) + 0.43, zc), (1, 0, 0), tuple(n), 0.24, HZ1 - HZ0 + 1.0, 0.08, "trim")
    p.obox((HX, roof_y(zc) + 0.45, zc + 0.4), (1, 0, 0), tuple(n), 12.2, 12.8, 0.05, "team")
    p.box((HX, roof_y(HZ0) - 0.1, HZ0 - 0.55), (2 * HW + 1.6, 0.24, 0.08), "power")  # lit roof edge
    # corrugated back wall and a half side wall
    p.box((HX, 4.5, HZ1), (2 * HW, 8.0, 0.4), "paint", bevel=0.04)
    for i in range(11):
        p.box((HX - HW + 0.8 + i * 1.44, 4.5, HZ1 - 0.24), (0.24, 7.6, 0.08), "trim")
    p.box((HX - HW, 3.3, -8.2), (0.4, 5.6, 10.4), "paint", bevel=0.04)
    for i in range(6):
        p.box((HX - HW - 0.24, 3.3, -12.6 + i * 1.76), (0.08, 5.4, 0.24), "trim")
    p.box((HX - HW - 0.24, 5.9, -8.2), (0.05, 0.16, 9.6), "light")
    # build pad under the roof: steel plate, team stripes, hazard edges
    p.box((PAD[0], 0.58, PAD[1]), (12.0, 0.16, 12.0), "steel", bevel=0.04)
    for dx in (-4.9, 4.9):
        p.box((PAD[0] + dx, 0.68, PAD[1]), (1.0, 0.05, 11.4), "team")
    for sz in (-1, 1):
        hazard(p, (PAD[0], 0.69, PAD[1] + sz * 5.8), (1, 0, 0), UP, 11.6, 0.45, stripes=18)
    # taxi line from the pad to the runway
    for k in range(6):
        p.box((-5.6 + k * 1.5, 0.53, PAD[1]), (0.8, 0.03, 0.35), "hazard")
    # hoist girder with an emitter head at each end, work lamps
    gy = roof_y(PAD[1]) - 0.55
    p.box((HX, gy, PAD[1]), (2 * HW, 0.7, 0.9), "trim", bevel=0.05)
    p.box((HX, gy - 0.4, PAD[1]), (2 * HW - 1.0, 0.1, 0.3), "steel")  # trolley rail
    for dx in (-5.4, 5.4):
        head(p, HX + dx, gy - 0.35, PAD[1])
    for z in (-18.2, -5.0):
        p.box((HX, roof_y(z) - 0.06, z), (8.0, 0.08, 1.4), "power")
    for sx in (-1, 1):  # lit eaves along the roof's sides
        p.obox((HX + sx * (HW + 0.93), roof_y(zc) + 0.2, zc), (0, SLOPE, 1), (sx, 0, 0), HZ1 - HZ0 + 1.0, 0.24, 0.06, "light")
    # back hut: a corrugated arched workshop, a team ridge plate, a lit door
    hut = arch(QZ0, QZ1, 0.5, 9.0, steps=8, flat=0.25)
    p.prism_x(hut, QX0, QX1, "paint", bevel=0.08)
    pts = arch(QZ0 - 0.06, QZ1 + 0.06, 0.5, 9.06, steps=8, flat=0.25)
    for x in [QX0 + 0.8 + i * 2.15 for i in range(7)]:
        for (z1, y1), (z2, y2) in zip(pts, pts[1:]):
            d = V((0, y2 - y1, z2 - z1))
            nn = V((0, z2 - z1, -(y2 - y1))).normalized()
            p.obox((x, (y1 + y2) / 2 + nn.y * 0.02, (z1 + z2) / 2 + nn.z * 0.02), (1, 0, 0), tuple(nn), 0.24, d.length + 0.05, 0.08, "trim")
    for (z1, y1), (z2, y2) in zip(pts, pts[1:]):
        if min(y1, y2) < 7.0:
            continue
        d = V((0, y2 - y1, z2 - z1))
        nn = V((0, z2 - z1, -(y2 - y1))).normalized()
        p.obox((-15.7, (y1 + y2) / 2 + nn.y * 0.1, (z1 + z2) / 2 + nn.z * 0.1), (1, 0, 0), tuple(nn), 12.0, d.length * 1.02, 0.05, "team")
    qz = (QZ0 + QZ1) / 2
    p.box((QX1 + 0.05, 3.6, qz), (0.1, 6.2, 9.0), "dark")
    for sz in (-1, 1):
        p.box((QX1 + 0.12, 3.6, qz + sz * 4.6), (0.12, 6.2, 0.26), "light")
    p.box((QX1 + 0.12, 6.8, qz), (0.12, 0.24, 9.4), "light")
    hazard(p, (QX1 + 0.5, 0.53, qz), (0, 0, 1), UP, 9.0, 0.5, stripes=12)
    p.ocyl((-19.4, 8.4, 14.0), UP, 0.6, 2.6, 10, "steel")  # stack
    p.cylinder("y", (-19.4, 11.04, 14.0), 0.55, 0.08, 10, "power")
    # rearm pads with a fuel bowser
    for x, z in REARM:
        p.box((x, 0.56, z), (6.4, 0.12, 6.4), "steel", bevel=0.03)
        p.box((x - 2.6, 0.64, z), (0.7, 0.04, 5.8), "team")
        p.box((x + 2.6, 0.64, z), (0.7, 0.04, 5.8), "team")
        for sx in (-1, 1):
            for sz in (-1, 1):
                p.box((x + sx * 3.0, 0.68, z + sz * 3.0), (0.36, 0.18, 0.36), "light")
    p.box((22.2, 1.6, 1.9), (2.2, 2.2, 4.4), "paint", bevel=0.05)  # bowser
    p.cylinder("z", (22.2, 2.9, 1.9), 0.9, 3.8, 12, "trim")
    p.box((21.08, 1.6, 1.9), (0.05, 0.4, 2.0), "power")
    # lattice mast: four legs, braced rings, X braces, platform, beacon
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    top = 15.4

    def leg(sx, sz, y):
        f = 2.0 - 1.3 * (y - 0.5) / (top - 0.5)
        return (MX + sx * f, y, MZ + sz * f)

    for sx, sz in corners:
        beam(p, leg(sx, sz, 0.5), leg(sx, sz, top), 0.32, "paint", bevel=0.03)
        p.box((MX + sx * 2.0, 0.75, MZ + sz * 2.0), (0.7, 0.5, 0.7), "trim")
    for y in (3.8, 7.4, 11.0, 14.6):
        for i, (sx, sz) in enumerate(corners):
            nx, nz = corners[(i + 1) % 4]
            beam(p, leg(sx, sz, y), leg(nx, nz, y), 0.14, "steel")
            beam(p, leg(sx, sz, y - 3.4), leg(nx, nz, y), 0.1, "steel")
    for sx, sz in ((-1, -1), (1, 1)):  # guy cables
        cable(p, [leg(sx, sz, 12.0), (MX + sx * 4.6, 0.5, MZ + sz * 4.6)], r=0.04, kind="steel")
    p.box((MX, top + 0.15, MZ), (2.0, 0.3, 2.0), "trim", bevel=0.03)
    p.cylinder("y", (MX, top + 0.4, MZ), 0.45, 0.2, 10, "steel")
    for sx, sz in corners:
        x, y, z = leg(sx, sz, 7.4)
        p.box((x, y + 0.2, z), (0.36, 0.26, 0.36), "light")
    p.box((MX + 0.8, top + 1.0, MZ + 0.8), (0.4, 0.4, 0.4), "light")  # beacon
    t = math.radians(20)
    nn, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (MX, top + 1.6, MZ)
    with p.sub("radarPanel", (MX, top + 0.5, MZ), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (MX, top + 0.6, MZ), 0.35, 0.2, 10, "trim")
        p.obox(c, (1, 0, 0), nn, 3.8, 2.4, 0.3, "paint", bevel=0.03)
        p.obox(tuple(c[k] + nn[k] * 0.16 for k in range(3)), (1, 0, 0), nn, 3.5, 2.1, 0.03, "dark")
        for b in (-1.05, 1.05):
            p.obox(tuple(c[k] + nn[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), nn, 3.5, 0.08, 0.02, "light")
        for a in (-1.75, 1.75):
            p.obox((c[0] + a, c[1] + nn[1] * 0.18, c[2] + nn[2] * 0.18), (1, 0, 0), nn, 0.08, 2.1, 0.02, "light")
        p.obox(tuple(c[k] - nn[k] * 0.17 + v[k] * 0.4 for k in range(3)), (1, 0, 0), nn, 3.4, 0.7, 0.03, "team")
    # salvage fuel drums with team caps and gauges, a pipe, crates
    for x, z, r, h in ((19.6, -18.6, 2.2, 4.2), (19.8, -12.6, 1.7, 3.4), (15.6, -19.4, 1.4, 2.8)):
        p.cylinder("y", (x, 0.5 + h / 2, z), r, h, 16, "paint", bevel=0.05)
        p.ocyl((x, 0.5 + h, z), UP, r, 0.4, 16, "trim", radius2=r * 0.75)
        p.cylinder("y", (x, 0.95 + h, z), r * 0.72, 0.06, 14, "team")
        for y in (0.9, 0.5 + h * 0.6):
            p.cylinder("y", (x, y, z), r + 0.05, 0.18, 16, "dark")
        p.box((x - r - 0.03, 0.5 + h * 0.4, z), (0.05, h * 0.45, 0.4), "power")
    cable(p, [(17.4, 2.6, -18.6), (15.4, 0.9, -16.0), (14.0, 0.8, -12.0)], r=0.2, kind="steel")
    for x, z, s in ((-3.4, -21.0, 1.4), (-3.6, -19.2, 1.1), (-2.2, -20.2, 1.0), (-4.0, 15.0, 1.3)):
        p.box((x, 0.5 + s / 2, z), (s, s, s), "trim", bevel=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 22.9, 0.56, sz * 22.9), (0.6, 0.14, 0.6), "light")

    # hoist trolley: runs along the girder with the third emitter head
    with p.sub("trolley", (HX - 2.0, gy - 0.6, PAD[1]), "slide", (1, 0, 0), 4.0):
        p.box((HX - 2.0, gy - 0.75, PAD[1]), (1.6, 0.6, 1.3), "paint", bevel=0.05)
        head(p, HX - 2.0, gy - 1.05, PAD[1])


def details_base(p):
    for z in (-12.0, 18.0):
        seam(p, (-2.0, 0.501, z), (1.0, 0.501, z), UP)
    rivets(p, (-6.0, 0.541, -18.0), (-2.0, 0.541, -18.0), 6, UP)
    rivets(p, (HX - 7.0, 0.8, HZ1 - 0.21), (HX + 7.0, 0.8, HZ1 - 0.21), 12, (0, 0, -1))
    bolts(p, (-21.5, 0.501, -23.1), (21.5, 0.501, -23.1), 24, UP)


unit.run(__file__, "chs_advairfield", "chaos", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000, tex=2048,
         previews=[("35", (-56, 45, -67), (0, 5.0, 0), 50),
                   ("80", (0, 124, 22), (0, 4, 0), 50),
                   ("close", (-2, 22, -40), (-12.0, 5.0, -10.0), 35),
                   ("back", (52, 42, 62), (0, 5.0, 0), 50)])
