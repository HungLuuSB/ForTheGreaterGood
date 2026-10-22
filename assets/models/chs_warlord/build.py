"""Warlord (Chaos Commander, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_warlord/build.py

The unit a player must keep alive, seen in every match, so the most detailed
Chaos unit (user, 2026-10-23: within 5,000 triangles). Chaos reads light and
exposed (M-14): a high-riding gunmetal hull on four big exposed road wheels
with spiked hubs inside the track loop, mudguards with team plates, a spiked
ram; a slab-armored command cabin with an angled front slab, a glowing slit,
reactive blocks and roof spikes; a tall lattice mast flying a big team
banner under an amber beacon; twin exhaust stacks and fuel drums at the
back. On the `nano` turntable: a crane arm with a hydraulic ram, claw prongs
and a glowing emitter (power). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

NANO_PIVOT = (0.8, 2.45, 2.4)
DECK = 2.45
WHEELS = (-2.1, -0.7, 0.7, 2.1)
CABIN = [(-2.0, -2.5), (2.0, -2.5), (2.1, -0.6), (2.0, 0.1), (-2.0, 0.1), (-2.1, -0.6)]
MAST = (-1.9, 1.0)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    # hull: high-riding, between the tracks
    p.prism_x([(-3.4, 1.1), (3.7, 1.1), (3.95, 1.5), (3.95, DECK), (-2.6, DECK), (-3.65, 1.9)], -2.3, 2.3, "paint", bevel=0.05)
    p.prism_x([(-3.0, 0.75), (3.3, 0.75), (3.3, 1.12), (-3.2, 1.12)], -1.9, 1.9, "dark", bevel=0.03)  # belly
    # tracks round four big exposed road wheels, spiked hubs
    outline = [(-2.6, 0.0), (2.6, 0.0)]
    outline += lib.outline_circle(3.15, 0.75, 0.75, -90, 90, 8)[1:]
    outline += [(-3.15, 1.6)]
    outline += lib.outline_circle(-3.15, 0.85, 0.75, 90, 270, 8)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.3, 3.3) if sx > 0 else (-3.3, -2.3)
        p.band_x(outline, inner, x0, x1, "track")
        for z in WHEELS:
            p.cylinder("x", (sx * 2.8, 0.8, z), 0.62, 0.7, 12, "rubber", cap_kinds=("trim", "trim"))
            p.ocyl((sx * 3.15, 0.8, z), (sx, 0, 0), 0.18, 0.32, 6, "steel", radius2=0.02)  # hub spike
        for z in (-3.2, 3.2):
            p.cylinder("x", (sx * 2.8, 0.8, z), 0.44, 0.74, 10, "steel")
        # mudguard over the track, a team plate on it, a running strip on its edge
        p.prism_x([(-3.6, 1.62), (3.7, 1.62), (3.7, 1.78), (-3.3, 1.86)], sx * 2.25, sx * 3.38, "trim", bevel=0.02) \
            if sx > 0 else p.prism_x([(-3.6, 1.62), (3.7, 1.62), (3.7, 1.78), (-3.3, 1.86)], -3.38, -2.25, "trim", bevel=0.02)
        p.box((sx * 2.82, 1.8, 2.0), (0.85, 0.04, 2.6), "team", bevel=0.01)
        p.box((sx * 3.4, 1.7, 0.2), (0.04, 0.1, 6.0), "light")
        p.box((sx * 2.0, 2.0, 3.97), (0.5, 0.16, 0.05), "light")  # tail lights
    # spiked ram
    p.prism_x([(-4.15, 0.35), (-3.85, 0.35), (-3.6, 1.2), (-3.75, 1.95), (-4.3, 1.3)], -2.95, 2.95, "dark", bevel=0.03)
    for x in (-2.0, -1.0, 0.0, 1.0, 2.0):
        p.ocyl((x, 0.95, -4.2), (0, 0, -1), 0.15, 0.55, 6, "steel", radius2=0.01)
    p.box((0, 1.6, -4.13), (4.4, 0.08, 0.05), "hazard")
    for sx in (-1, 1):
        p.box((sx * 2.1, 2.05, -3.75), (0.5, 0.26, 0.2), "trim", bevel=0.02)
        p.box((sx * 2.1, 2.05, -3.86), (0.36, 0.16, 0.04), "head")

    # command cabin: slabs, angled front slab, glowing slit, reactive blocks, spikes
    p.prism_y(CABIN, DECK, 4.05, "paint", bevel=0.05, top_scale=0.86)
    n = lib.vec((0, 0.35, -1)).normalized()
    p.obox((0, 3.05, -2.62), (1, 0, 0), tuple(n), 4.3, 1.5, 0.2, "trim", bevel=0.03)
    p.obox((0, 3.6, -2.78), (1, 0, 0), tuple(n), 3.4, 0.32, 0.06, "light")  # the slit
    p.box((0, 4.08, -1.2), (2.6, 0.05, 1.6), "team", bevel=0.012)
    for sx in (-1, 1):
        for z in (-2.0, -1.2, -0.4):
            p.box((sx * 2.1, 3.05, z), (0.22, 0.7, 0.7), "era", bevel=0.02)
        p.ocyl((sx * 1.55, 4.0, -2.0), UP, 0.18, 0.75, 6, "dark", radius2=0.02)  # roof spikes
        p.box((sx * 2.07, 3.75, -1.2), (0.05, 0.18, 2.6), "light")  # cabin side strips
        p.ocyl((sx * 1.55, 4.0, -0.6), UP, 0.14, 0.5, 6, "dark", radius2=0.02)
    p.box((0, 3.5, 0.13), (2.6, 0.7, 0.06), "grille")

    # lattice mast: three legs, braces, banner on a crossbar, beacon
    mx, mz = MAST
    legs = [(mx - 0.28, mz - 0.22), (mx + 0.28, mz - 0.22), (mx, mz + 0.3)]
    for lx, lz in legs:
        beam(p, (lx, DECK, lz), (mx + (lx - mx) * 0.4, 8.4, mz + (lz - mz) * 0.4), 0.12, "dark")
    for y in (3.8, 5.3, 6.8):
        f = 1 - 0.6 * (y - DECK) / (8.4 - DECK)
        pts = [(mx + (lx - mx) * f, y, mz + (lz - mz) * f) for lx, lz in legs]
        for i in range(3):
            beam(p, pts[i], pts[(i + 1) % 3], 0.07, "steel")
    p.box((mx, 2.6, mz), (0.9, 0.3, 0.9), "trim", bevel=0.03)  # mast foot
    beam(p, (mx, 8.0, mz), (mx, 8.0, mz + 1.9), 0.1, "steel")  # crossbar
    p.box((mx, 7.05, mz + 1.0), (0.05, 1.8, 1.7), "team")  # banner
    p.box((mx, 7.05, mz + 1.0), (0.03, 1.9, 1.8), "dark")  # banner backing
    p.box((mx, 8.62, mz), (0.42, 0.36, 0.42), "light")  # beacon
    p.cylinder("y", (mx, 8.45, mz), 0.08, 0.1, 6, "steel")

    # back: twin exhaust stacks with hot rims, fuel drums
    for z in (3.3, 3.8):
        p.cylinder("y", (2.0, 3.3, z), 0.22, 1.7, 10, "dark")
        p.cylinder("y", (2.0, 4.1, z), 0.24, 0.2, 10, "light")
    for z in (3.0, 3.6):
        p.cylinder("x", (-0.9, 2.78, z), 0.3, 1.2, 10, "trim")
        p.cylinder("x", (-0.9, 2.78, z), 0.31, 0.12, 10, "hazard")


def details_base(p):
    for sx in (-1, 1):
        bolts(p, (sx * 2.82, 1.81, -3.2), (sx * 2.82, 1.81, 0.4), 6, UP)
        seam(p, (sx * 2.3, 1.6, -3.0), (sx * 2.3, 1.6, 3.4), (sx, 0, 0))
    bolts(p, (-1.8, 4.06, -2.2), (1.8, 4.06, -2.2), 7, UP)
    ring(p, (0.7, 4.051, -0.5), UP, 0.3)
    seam(p, (-2.0, DECK + 0.001, 0.5), (2.0, DECK + 0.001, 0.5), UP)
    box_seams(p, (0, 0, 2.3), (3.6, 0, 3.0), DECK + 0.001)


def build_nano(p):
    px, py, pz = NANO_PIVOT
    p.cylinder("y", (px, py + 0.18, pz), 1.1, 0.36, 14, "dark")
    p.cylinder("y", (px, py + 0.38, pz), 0.92, 0.05, 14, "team")
    p.cylinder("y", (px, py + 0.05, pz), 1.13, 0.1, 14, "power")
    for sx in (-1, 1):
        p.obox((px + sx * 0.4, py + 0.7, pz + 0.05), UP, (1, 0, 0), 0.7, 0.6, 0.16, "trim", bevel=0.02)
    p.cylinder("x", (px, py + 0.85, pz + 0.05), 0.16, 1.0, 8, "steel")
    base = lib.vec((px, py + 0.85, pz + 0.05))
    tip = lib.vec((px, 5.0, 4.0))
    d = tip - base
    p.obox(tuple((base + tip) / 2), tuple(d), (1, 0, 0), d.length + 0.2, 0.5, 0.55, "paint", bevel=0.03)
    for t in (0.25, 0.5, 0.75):  # lightening holes read as dark plates
        p.obox(tuple(base + d * t), tuple(d), (1, 0, 0), 0.4, 0.3, 0.57, "dark")
    up = d.cross(lib.vec((1, 0, 0))).normalized()
    if up.y < 0:
        up = -up
    p.obox(tuple((base + tip) / 2 + up * 0.29), tuple(d), tuple(up), d.length * 0.6, 0.36, 0.04, "team")
    for t in (0.35, 0.62):  # power coils round the arm
        p.obox(tuple(base + d * t), tuple(d), (1, 0, 0), 0.14, 0.62, 0.67, "power")
    a = lib.vec((px, py + 0.4, pz - 0.5))
    b = base + d * 0.6
    p.obox(tuple((a + b) / 2), tuple(b - a), (1, 0, 0), (b - a).length, 0.2, 0.2, "steel")
    # claw prongs and the emitter between them
    for sx in (-1, 1):
        beam(p, tuple(tip + lib.vec((sx * 0.3, 0, 0))), tuple(tip + lib.vec((sx * 0.45, 0.2, 0.75))), 0.14, "trim")
    p.box(tuple(tip), (0.8, 0.5, 0.5), "dark", bevel=0.03)
    e = lib.vec((px, 5.3, 4.3))
    p.ocyl(tuple(e - lib.vec((0, 0.42, 0))), UP, 0.25, 0.42, 12, "power", radius2=0.48)
    p.ocyl(tuple(e), UP, 0.48, 0.38, 12, "power", radius2=0.2)


def details_nano(p):
    px, py, pz = NANO_PIVOT
    ring(p, (px, py + 0.361, pz), UP, 1.0)
    for i in range(8):
        t = 2 * math.pi * i / 8
        unit.bolt(p, (px + math.cos(t) * 1.0, py + 0.362, pz + math.sin(t) * 1.0), UP)


unit.run(__file__, "chs_warlord", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO_PIVOT, build_nano, details_nano)],
         budget=5000,
         previews=[("35", (-15, 12, 18), (0, 2.5, 0), 50),
                   ("side", (20, 4, -0.5), (0, 3.0, -0.5), 50),
                   ("80", (0, 30, 5), (0, 2.5, 0), 50),
                   ("close", (-6.5, 6.0, -8.0), (0, 3.0, -0.5), 35)])
