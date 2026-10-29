"""Accumulator (Chaos energy storage, T1 structure, footprint 2; S-209):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_accumulator/build.py

After BAR's corestor, 16 x 16 studs and about 7.5 tall: a squat stepped
dome, where the Depot is a salvage tank farm. Big shapes first: a skid
slab; a ring of eight heavy armor blocks round the foot (team-painted
faces, uneven); an octagonal stepped body, its four sloped faces tall
glowing charge wedges between four dark armored buttresses (the front
one a hatch); ladder ribs up the upper tier to a glowing octagonal charge
cap. Chaos reads rugged and improvised (M-14): a patched plate, cables,
hazard striping. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import BOX_FACES, cable, hazard, octagon, rivets  # noqa: E402
from unit import UP  # noqa: E402

V = lib.vec
T1, T2 = 3.6, 6.2  # tops of the lower and upper tier


def taper(p, a, b, n, w0, w1, thick, kind, bevel=0.0):
    """A flat tapered plate from a (w0 wide) to b (w1 wide), n its face normal."""
    a, b, n = V(a), V(b), V(n).normalized()
    u = n.cross((b - a).normalized()).normalized()
    pts = []
    for c, w in ((a, w0), (b, w1)):
        for s in (-1, 1):
            for d in (-1, 1):
                pts.append(tuple(c + u * (s * w / 2) + n * (d * thick / 2)))
    return p._shell(pts, BOX_FACES, kind, bevel)


def build_base(p):
    p.prism_y(octagon(7.8, 1.6), 0.0, 0.5, "dark", bevel=0.1, top_scale=0.985)
    # the stepped octagonal body
    p.prism_y(octagon(5.0, 1.5), 0.5, 1.4, "trim", bevel=0.1)
    p.prism_y(octagon(5.0, 1.5), 1.4, T1, "paint", bevel=0.14, top_scale=0.72)
    p.prism_y(octagon(3.5, 1.1), T1, T1 + 0.5, "trim", bevel=0.06)
    p.prism_y(octagon(3.5, 1.1), T1 + 0.5, T2, "paint", bevel=0.12, top_scale=0.62)
    # the glowing charge cap
    p.prism_y(octagon(2.25, 0.7), T2, T2 + 0.35, "trim", bevel=0.05)
    p.prism_y(octagon(1.8, 0.55), T2 + 0.35, T2 + 0.5, "power", bevel=0.03)
    # charge wedges on the diagonal faces, dark buttresses on the cardinal ones
    for k in range(8):
        a = math.pi / 4 * k
        d = V((math.sin(a), 0, -math.cos(a)))  # k = 0: the front
        t = V((-d.z, 0, d.x))
        if k % 2:  # the diagonal faces lie further out: sqrt(2) * (r - cut / 2)
            for (r0, y0, r1, y1, w0, w1) in ((6.0, 1.45, 4.35, 3.55, 2.8, 2.0), (4.15, T1 + 0.55, 2.6, T2 - 0.05, 1.9, 1.0)):
                lo, hi = d * (r0 + 0.12) + V((0, y0, 0)), d * (r1 + 0.12) + V((0, y1, 0))
                nrm = (d * (y1 - y0) + V(UP) * (r0 - r1)).normalized()
                taper(p, lo, hi, nrm, w0, w1, 0.24, "trim", bevel=0.04)
                taper(p, lo + nrm * 0.14 + (hi - lo) * 0.06, hi + nrm * 0.14 - (hi - lo) * 0.08, nrm, w0 - 0.6, w1 - 0.45, 0.06, "power")
        else:
            c = d * 4.45
            p.obox((c.x, 2.6, c.z), tuple(t), tuple(d), 2.8, 4.2, 1.6, "dark", bevel=0.1)
            p.obox((c.x - d.x * 0.5, 4.95, c.z - d.z * 0.5), tuple(t), tuple((d + V(UP)).normalized()), 2.6, 1.6, 0.5, "trim", bevel=0.06)
            if k == 0:  # the front hatch
                p.obox((c.x + d.x * 0.81, 2.3, c.z + d.z * 0.81), tuple(t), tuple(d), 1.8, 3.0, 0.05, "grille")
                p.obox((c.x + d.x * 0.83, 4.0, c.z + d.z * 0.83), tuple(t), tuple(d), 1.6, 0.14, 0.04, "light")
            else:
                p.obox((c.x + d.x * 0.81, 3.0, c.z + d.z * 0.81), tuple(t), tuple(d), 1.6, 2.4, 0.05, "trim")
            # ladder ribs up the upper tier
            for s in (-1, 1):
                q0 = d * 3.35 + t * (s * 0.55) + V((0, T1 + 0.5, 0))
                q1 = d * 2.1 + t * (s * 0.4) + V((0, T2 - 0.05, 0))
                u = q1 - q0
                p.obox(tuple((q0 + q1) / 2), tuple(u), tuple(t), u.length, 0.18, 0.18, "steel")
            for i in range(4):
                f = (i + 0.5) / 4
                q = d * (3.35 - 1.25 * f) + V((0, T1 + 0.5 + (T2 - T1 - 0.55) * f + 0.1, 0))
                p.obox(tuple(q), tuple(t), tuple(d), 1.0 - 0.2 * f, 0.08, 0.1, "steel")
    # eight armor blocks round the foot, team-painted faces, a little uneven
    for k in range(8):
        a = math.pi / 4 * k + math.pi / 8
        d = V((math.sin(a), 0, -math.cos(a)))
        t = V((-d.z, 0, d.x))
        h = 1.7 if k % 3 else 2.0
        c = d * 6.0
        p.obox((c.x, 0.5 + h / 2, c.z), tuple(t), tuple(d), 2.5, h, 2.0, "paint", bevel=0.14)
        p.obox((c.x + d.x * 1.02, 0.5 + h / 2, c.z + d.z * 1.02), tuple(t), tuple(d), 2.1, h - 0.4, 0.05, "team")
        p.obox((c.x - d.x * 0.1, 0.52 + h, c.z - d.z * 0.1), tuple(t), tuple((d * 0.6 + V(UP)).normalized()), 2.3, 1.6, 0.06, "team")
    # a patched plate, cables, hazard striping, corner beacons
    p.obox((2.6, 2.6, -2.9), (1, 0, 0.6), (0.5, 0.75, -0.45), 1.2, 0.9, 0.06, "steel")
    cable(p, [(-4.6, 0.6, 3.6), (-4.0, 1.2, 2.6), (-3.2, 2.4, 2.2)], r=0.1)
    cable(p, [(4.4, 0.6, 3.9), (3.8, 1.4, 3.0)], r=0.09)
    hazard(p, (0, 0.52, -7.3), (1, 0, 0), UP, 4.4, 0.35, stripes=8)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.58, sz * 7.0), (0.3, 0.15, 0.3), "light")


def details_base(p):
    rivets(p, (-1.4, 1.42, -5.02), (1.4, 1.42, -5.02), 5, (0, 0, -1))
    rivets(p, (-1.0, T1 + 0.25, -3.52), (1.0, T1 + 0.25, -3.52), 4, (0, 0, -1))


unit.run(__file__, "chs_accumulator", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 18, -26), (0, 3.0, 0), 50),
                   ("80", (0, 38, 6), (0, 2.5, 0), 50),
                   ("close", (-11, 10, -13), (0, 3.5, 0), 35)])
