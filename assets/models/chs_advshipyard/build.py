"""Advanced Drydock (Chaos naval factory, T2 structure, footprint 6, on
water): mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advshipyard/build.py

Designed at the size scale (S-104, M-26: footprint 6, 48 x 48 studs; the
pier cranes about 18 tall, the hammerhead crane about 27: the tallest
factory), bigger and busier than the T1 Shipyard rather than a rescale. The
waterline is y = 0. Big shapes first:
- a patched quay at the back with a corrugated shed (a large team roof, a
  door with lit slats facing the slip: power, pulses while producing, a
  hot stack), salvage tanks with team caps and amber gauges;
- two narrow piers on piles with large team plates, hazard slip edges,
  tyre fenders, amber running and tip lights;
- a braced lattice tower crane on each pier, the left one forward of the
  right, each with an operator cab and a client-slewed girder jib over the
  slip (`jib1`, `jib2`, turn, M-27) carrying a team band, a counterweight
  inside the footprint and a hook trolley with a build lamp (`nano1`,
  `nano2`, slew with their jibs);
- a giant hammerhead crane on the quay (the T2 signature, T1 vs T2 check
  2026-10-22): a tall braced lattice tower and a long slewing jib reaching
  over the whole slip (`jib`, turn) with a team band, a cab, a counter-jib
  and its weight inside the footprint, and a hook block with a build lamp
  over the pad (`nano3`); the build pad in the slip below (`buildpad`,
  y = 0).
Chaos reads rugged, light and open (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

V = lib.vec
PX, PW = 19.2, 2.8  # pier centre (x mirrored), half width
CRANES = ((-1, -19.2, 4.6), (1, 19.2, -7.0))  # pier tower cranes: (side, x, z)
CRANE_TOP = 16.4
GX, GZ, G_TOP = 8.0, 18.4, 24.6  # hammerhead crane tower, top of the tower
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
PAD_Z = -1.0  # the build pad's z in the slip


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def tower(p, x, z, y0, y1, r0, r1, rings, leg_w):
    """A braced four-legged lattice tower from y0 to y1, tapering r0 -> r1."""
    def leg(dx, dz, y):
        f = r0 + (r1 - r0) * (y - y0) / (y1 - y0)
        return (x + dx * f, y, z + dz * f)

    for dx, dz in CORNERS:
        beam(p, leg(dx, dz, y0), leg(dx, dz, y1), leg_w, "paint", bevel=0.03)
        p.box((x + dx * r0, y0 + 0.25, z + dz * r0), (leg_w * 2.2, 0.5, leg_w * 2.2), "trim")
    step = (y1 - y0) / rings
    for k in range(1, rings + 1):
        y = y0 + k * step
        for i, (dx, dz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg(dx, dz, y), leg(nx, nz, y), 0.16, "steel")
            beam(p, leg(dx, dz, y - step), leg(nx, nz, y), 0.1, "steel")
    return leg


def build_base(p):
    # patched quay, from below the water to the deck
    quay = [(-23.6, 14.0), (23.6, 14.0), (23.6, 22.4), (22.4, 23.6), (-22.4, 23.6), (-23.6, 22.4)]
    p.prism_y(quay, -1.2, 0.8, "dark", bevel=0.1)
    for x, z, w, d in ((3.0, 15.6, 9.0, 2.4), (-14.0, 23.0, 7.0, 1.2), (17.0, 22.0, 6.0, 2.4)):
        p.box((x, 0.82, z), (w, 0.04, d), "trim", bevel=0.01)
    hazard(p, (0, 0.83, 14.5), (1, 0, 0), UP, 31.0, 0.6, stripes=30)
    # corrugated shed: team roof, door with build lights, a stack
    p.prism_x([(15.2, 0.8), (23.0, 0.8), (23.0, 7.4), (15.2, 8.6)], -22.4, -3.6, "paint", bevel=0.1)
    for i in range(12):
        p.box((-21.4 + i * 1.5, 4.1, 23.04), (0.24, 6.4, 0.08), "trim")
    p.obox((-13.0, 8.06, 19.1), (1, 0, 0), (0, 1, 0.153), 17.4, 7.0, 0.06, "team", bevel=0.015)
    p.box((-13.0, 3.6, 15.16), (12.0, 5.6, 0.1), "dark")
    for i in range(4):
        p.box((-13.0, 1.4 + i * 1.3, 15.09), (11.6, 0.14, 0.06), "power")
    for sx in (-1, 1):
        p.box((-13.0 + sx * 6.2, 3.7, 15.05), (0.3, 5.8, 0.12), "power")
    for y in (1.8, 3.6):  # reactive "era" blocks by the door
        for x in (-21.0, -5.0):
            p.box((x, y, 14.98), (1.8, 1.5, 0.4), "era", bevel=0.05)
    p.ocyl((-19.0, 7.6, 21.0), UP, 0.65, 3.6, 10, "steel")
    p.cylinder("y", (-19.0, 11.24, 21.0), 0.6, 0.08, 10, "power")
    # salvage tanks with team caps and gauges
    for x, r, h in ((-0.4, 2.0, 5.0), (3.8, 1.6, 4.0)):
        p.cylinder("y", (x, 0.8 + h / 2, 19.8), r, h, 16, "paint", bevel=0.05)
        p.ocyl((x, 0.8 + h, 19.8), UP, r, 0.4, 16, "trim", radius2=r * 0.75)
        p.cylinder("y", (x, 1.25 + h, 19.8), r * 0.72, 0.06, 14, "team")
        p.cylinder("y", (x, 0.8 + h * 0.55, 19.8), r + 0.05, 0.18, 16, "dark")
        p.box((x, 0.8 + h * 0.42, 19.8 - r - 0.03), (0.4, h * 0.45, 0.05), "power")
    cable(p, [(-0.4, 3.8, 17.7), (1.8, 2.8, 17.4), (3.8, 3.2, 18.1)], r=0.16, kind="steel")
    # salvage containers on the quay's right, one with a team stripe
    for x, y, z, w in ((17.4, 2.1, 20.0, 6.0), (17.4, 4.7, 20.0, 6.0), (17.8, 2.1, 16.6, 5.0)):
        p.box((x, y, z), (w, 2.6, 2.4), "paint" if y < 3 else "trim", bevel=0.04)
    p.box((17.4, 4.7, 18.77), (5.0, 0.6, 0.05), "team")
    p.box((20.43, 2.1, 16.6), (0.05, 0.4, 1.4), "power")
    # piers on piles: deck, team plates, hazard slip edges, fenders, lights
    for sx in (-1, 1):
        x = sx * PX
        p.box((x, 1.9, -4.4), (2 * PW, 1.0, 36.6), "paint", bevel=0.06)
        p.box((x, 2.43, -16.6), (4.6, 0.05, 9.0), "team", bevel=0.012)
        p.box((x, 2.43, 8.4), (4.6, 0.05, 7.0), "team", bevel=0.012)
        hazard(p, (x - sx * (PW - 0.3), 2.44, -4.4), (0, 0, 1), UP, 35.6, 0.45, stripes=30)
        for i in range(5):
            z = -21.0 + i * 8.4
            for dx in (-1.9, 1.9):
                p.cylinder("y", (x + dx, 0.1, z), 0.5, 2.8, 6, "steel")
        for z in (-18.0, -10.0, -2.0, 6.0):  # tyre fenders on the slip side
            p.ocyl((x - sx * (PW + 0.3), 1.6, z), (0, 0, 1), 0.6, 0.55, 10, "rubber")
        p.box((x + sx * (PW + 0.02), 1.8, -4.4), (0.06, 0.16, 33.0), "light")
        p.box((x, 2.8, -22.4), (0.6, 0.6, 0.6), "light")  # tip light
    # pier tower cranes: lattice towers, slewing rings
    for side, x, z in CRANES:
        leg = tower(p, x, z, 2.4, CRANE_TOP - 1.0, 1.5, 1.05, 3, 0.4)
        for dx, dz in CORNERS:
            lx, ly, lz = leg(dx, dz, 9.6)
            p.box((lx, ly + 0.2, lz), (0.36, 0.26, 0.36), "light")
        p.box((x, CRANE_TOP - 0.8, z), (2.8, 0.5, 2.8), "trim", bevel=0.04)
    # hammerhead crane: tall lattice tower on a footing
    p.box((GX, 1.3, GZ), (5.6, 1.0, 5.6), "trim", bevel=0.08)
    leg = tower(p, GX, GZ, 1.8, G_TOP - 1.0, 2.2, 1.3, 4, 0.48)
    for dx, dz in CORNERS:
        lx, ly, lz = leg(dx, dz, 13.0)
        p.box((lx, ly + 0.2, lz), (0.4, 0.3, 0.4), "light")
    p.box((GX, G_TOP - 0.7, GZ), (3.4, 0.6, 3.4), "trim", bevel=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 23.0, 0.9, 18.8 + sz * 4.2), (0.5, 0.2, 0.5), "light")

    # pier crane jibs: slew over the slip (M-27)
    for name, (side, x, z) in zip(("jib1", "jib2"), CRANES):
        y = CRANE_TOP
        s = -side  # the jib reaches toward the slip
        with p.sub(name, (x, y - 0.4, z), "turn", (0, 1, 0)):
            p.cylinder("y", (x, y - 0.4, z), 1.2, 0.4, 14, "steel")
            p.box((x + s * 1.7, y + 0.7, z - 1.5), (1.6, 1.5, 1.4), "paint", bevel=0.05)  # operator cab
            p.box((x + s * 1.7, y + 0.85, z - 2.22), (1.2, 0.6, 0.05), "glass")
            p.box((x + s * 10.8, y + 0.1, z), (20.0, 0.9, 1.1), "paint", bevel=0.04)  # jib
            for k in range(7):
                jx = x + s * (2.4 + k * 2.6)
                for dz in (-0.58, 0.58):
                    p.obox((jx, y + 0.1, z + dz), (1, 1, 0), (0, 0, 1), 1.2, 0.12, 0.06, "steel")
            p.box((x + s * 12.0, y + 0.58, z), (10.0, 0.05, 0.9), "team")
            p.box((x - s * 1.6, y + 0.1, z), (2.4, 0.8, 1.1), "trim")  # counter-jib, inside the footprint
            p.box((x - s * 2.3, y - 0.7, z), (1.2, 1.4, 1.4), "steel", bevel=0.04)  # counterweight
            hx = x + s * 17.4
            p.box((hx, y - 0.65, z), (1.6, 0.6, 1.4), "trim", bevel=0.04)  # trolley
            p.cylinder("y", (hx, y - 1.6, z), 0.05, 1.4, 6, "steel")
            p.box((hx, y - 2.45, z), (0.9, 0.4, 0.9), "dark", bevel=0.03)
            p.box((hx, y - 2.67, z), (0.7, 0.05, 0.7), "power")
            p.box((x + s * 20.6, y + 0.8, z), (0.5, 0.5, 0.5), "light")
            hazard(p, (x + s * 4.4, y + 0.1, z - 0.57), (1, 0, 0), (0, 0, -1), 5.0, 0.5, stripes=7)

    # hammerhead jib: reaches over the slip along -Z, counter-jib to +Z
    y = G_TOP + 0.9
    with p.sub("jib", (GX, G_TOP - 0.2, GZ), "turn", (0, 1, 0)):
        p.cylinder("y", (GX, G_TOP - 0.2, GZ), 1.5, 0.5, 16, "steel")
        p.box((GX + 1.9, y - 0.2, GZ - 1.2), (1.8, 1.8, 1.8), "paint", bevel=0.05)  # cab
        p.box((GX + 1.9, y, GZ - 2.12), (1.4, 0.7, 0.05), "glass")
        p.box((GX + 1.9, y - 0.5, GZ - 2.14), (1.4, 0.1, 0.05), "light")
        p.prism_y([(GX - 0.9, GZ + 1.6), (GX + 0.9, GZ + 1.6), (GX + 0.9, GZ - 1.6), (GX - 0.9, GZ - 1.6)],
                  G_TOP + 0.05, G_TOP + 2.6, "trim", bevel=0.05, top_scale=0.5)  # apex
        p.box((GX, y, GZ - 18.0), (1.4, 1.2, 33.0), "paint", bevel=0.05)  # jib, toward -Z
        for k in range(11):
            jz = GZ - 3.0 - k * 2.8
            for dx in (-0.73, 0.73):
                p.obox((GX + dx, y, jz), (0, 1, 1), (1, 0, 0), 1.5, 0.14, 0.06, "steel")
        p.box((GX, y + 0.63, GZ - 20.0), (1.1, 0.05, 16.0), "team")
        for dz in (-10.0, 4.4):  # tie bars from the apex
            beam(p, (GX, G_TOP + 2.5, GZ), (GX, y + 0.5, GZ + dz), 0.1, "steel")
        p.box((GX, y, GZ + 2.8), (1.6, 1.0, 4.4), "trim")  # counter-jib, inside the footprint
        p.box((GX, y - 1.1, GZ + 4.0), (2.4, 1.8, 1.6), "steel", bevel=0.05)  # counterweight
        tz = PAD_Z
        p.box((GX, y - 0.85, tz), (1.8, 0.6, 1.8), "trim", bevel=0.04)  # trolley
        for dx in (-0.4, 0.4):
            p.cylinder("y", (GX + dx, y - 3.6, tz), 0.05, 5.0, 6, "steel")
        p.box((GX, y - 6.4, tz), (1.3, 0.6, 1.3), "dark", bevel=0.04)
        p.box((GX, y - 6.73, tz), (1.0, 0.05, 1.0), "power")
        p.box((GX, y + 0.85, GZ - 34.2), (0.6, 0.6, 0.6), "light")
        hazard(p, (GX + 0.72, y, GZ - 6.0), (0, 0, 1), (1, 0, 0), 6.0, 0.6, stripes=8)


def details_base(p):
    bolts(p, (-21.5, 0.801, 23.2), (21.5, 0.801, 23.2), 24, UP)
    rivets(p, (-21.8, 1.4, 15.18), (-4.2, 1.4, 15.18), 14, (0, 0, -1))
    for x, r in ((-0.4, 2.0), (3.8, 1.6)):
        ring(p, (x, 1.9, 19.8 - r - 0.01), (0, 0, -1), 0.3)


unit.run(__file__, "chs_advshipyard", "chaos", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000, tex=2048,
         previews=[("35", (-66, 60, -80), (0, 10.0, 0), 50),
                   ("80", (0, 128, 22), (0, 6, 0), 50),
                   ("close", (-26, 30, -40), (0, 10.0, -2.0), 35),
                   ("back", (62, 56, 74), (0, 10.0, 0), 50)])
