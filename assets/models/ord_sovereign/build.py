"""Sovereign (Order Commander, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sovereign/build.py

The unit a player must keep alive, seen in every match, so the most detailed
unit in the game (user, 2026-10-23: within 5,000 triangles). A long heavy
tracked hull behind thick four-panel skirts, a raised armored glacis with a
big team plate, headlight clusters and a prow ridge; a command tower with a
wraparound glass band over a cyan command ring, an armored brow, smoke
dischargers, a satcom radome and a crown of antennas with a command beacon
and a team pennant; stowage boxes, rear engine grilles and exhausts. On the
`nano` turntable at the back: a heavy boom on a yoke with a hydraulic ram,
rising to the rear, and a large build emitter (power). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

NANO_PIVOT = (0.0, 2.3, 2.85)
DECK = 2.3
HL = 4.4  # half length of the upper hull
SKIRTS = [(-4.2, -2.15), (-2.1, 0.0), (0.05, 2.15), (2.2, 4.25)]
SKIRT_IN, SKIRT_OUT = 3.05, 3.32
WHEELS = [-3.3 + i * 1.1 for i in range(7)]
GLACIS = [(-4.75, 1.95), (-2.35, DECK)]  # (z, y) from the nose up to the deck
TOWER = [(-1.75, -1.35), (1.75, -1.35), (2.0, -0.85), (2.0, 1.65), (-2.0, 1.65), (-2.0, -0.85)]


def glacis_frame():
    (z0, y0), (z1, y1) = GLACIS
    d = lib.vec((0, y1 - y0, z1 - z0)).normalized()
    n = lib.vec((0, z1 - z0, -(y1 - y0))).normalized()  # up and forward
    return d, n


def on_glacis(t, lift=0.0):
    """A point a share t up the glacis (0 = nose, 1 = deck) at x = 0."""
    (z0, y0), (z1, y1) = GLACIS
    _, n = glacis_frame()
    return lib.vec((0, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t)) + n * lift


def build_base(p):
    # lower hull between the tracks, upper hull over them with a long glacis
    p.prism_x([(-4.0, 0.45), (4.15, 0.45), (4.45, 0.85), (4.45, 1.8), (-4.45, 1.8)], -2.05, 2.05, "trim", bevel=0.03)
    p.prism_x([(-4.75, 1.72), (HL, 1.72), (HL, 2.12), (HL - 0.2, DECK), (-2.35, DECK), (-4.75, 1.95)],
              -3.05, 3.05, "paint", bevel=0.05)
    d, n = glacis_frame()
    # prow ridge and the big glacis team plate either side of it
    p.prism_x([(-4.8, 1.85), (-2.6, DECK), (-2.6, DECK + 0.22), (-4.35, 2.12)], -0.55, 0.55, "paint", bevel=0.04)
    for sx in (-1, 1):
        c = on_glacis(0.55, 0.03)
        p.obox((sx * 1.75, c.y, c.z), (1, 0, 0), tuple(n), 2.1, 1.6, 0.05, "team", bevel=0.012)
    p.obox(tuple(on_glacis(0.1, 0.03)), (1, 0, 0), tuple(n), 3.2, 0.16, 0.05, "light")  # glacis light bar
    # headlight clusters at the nose corners, two lamps each
    for sx in (-1, 1):
        p.box((sx * 2.45, 1.86, -4.62), (0.9, 0.42, 0.3), "trim", bevel=0.04)
        for dx in (-0.2, 0.2):
            p.box((sx * 2.45 + dx, 1.86, -4.78), (0.28, 0.24, 0.04), "head")
    # tracks: a band round sprocket and idler, seven road wheels, return rollers
    outline = [(-3.85, 0.0), (3.95, 0.0)]
    outline += lib.outline_circle(3.95, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-4.0, 1.05)]
    outline += lib.outline_circle(-4.0, 0.62, 0.43, 90, 210, 5)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.05, 3.0) if sx > 0 else (-3.0, -2.05)
        with p.sub("trackL" if sx < 0 else "trackR", (sx * 2.52, 0.46, 0.0), "scroll", (1, 0, 0)):  # M-27 track set
            p.band_x(outline, inner, x0, x1, "track")
            for z in WHEELS:
                p.cylinder("x", (sx * 2.52, 0.46, z), 0.4, 0.4, 12, "rubber", cap_kinds=("trim", "trim"))
                p.cylinder("x", (sx * 2.52, 0.46, z), 0.14, 0.48, 8, "steel")
            p.cylinder("x", (sx * 2.52, 0.5, 3.95), 0.44, 0.5, 12, "steel")
            p.cylinder("x", (sx * 2.52, 0.62, -4.0), 0.34, 0.5, 12, "steel")
    # thick skirts in four panels, the front one cut back; team plate, running strip
    for sx in (-1, 1):
        x0, x1 = (SKIRT_IN, SKIRT_OUT) if sx > 0 else (-SKIRT_OUT, -SKIRT_IN)
        for i, (z0, z1) in enumerate(SKIRTS):
            prof = [(z0 + 0.5, 0.55), (z1, 0.55), (z1, 2.1), (z0, 2.1), (z0, 1.15)] if i == 0 else \
                [(z0, 0.55), (z1, 0.55), (z1, 2.1), (z0, 2.1)]
            p.prism_x(prof, x0, x1, "paint", bevel=0.04)
        p.box((sx * (SKIRT_OUT + 0.025), 1.55, 0.05), (0.05, 0.5, 4.0), "team", bevel=0.012)
        p.box((sx * (SKIRT_OUT + 0.03), 1.98, 0.05), (0.05, 0.12, 7.6), "light")
    # stowage boxes beside the tower, tow hooks, rear plate
    for sx in (-1, 1):
        p.box((sx * 2.55, DECK + 0.28, 0.2), (0.8, 0.56, 2.4), "trim", bevel=0.04)
        p.box((sx * 2.55, DECK + 0.57, 0.2), (0.6, 0.04, 1.6), "dark")
        p.box((sx * 1.5, 1.2, 4.5), (0.3, 0.3, 0.2), "steel")
    # rear: engine grilles, exhaust slots, tail lights
    p.box((0, 1.35, HL + 0.02), (3.4, 0.6, 0.06), "grille")
    for y in (1.15, 1.55):
        p.box((0, y, HL + 0.05), (3.0, 0.08, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 2.6, 1.95, HL + 0.03), (0.55, 0.18, 0.06), "light")
    p.box((0, DECK + 0.02, 3.95), (3.6, 0.05, 0.6), "grille")

    # command tower: armored body, cyan command ring, glass band, roof
    p.prism_y(TOWER, DECK, 3.5, "paint", bevel=0.05)
    p.prism_y([(x * 1.03, z * 1.03 + 0.008) for x, z in TOWER], 3.5, 3.58, "light")
    p.prism_y([(x * 1.01, z * 1.01) for x, z in TOWER], 3.58, 3.98, "glass")
    p.prism_y([(x * 1.04, z * 1.04) for x, z in TOWER], 3.98, 4.45, "paint", bevel=0.04, top_scale=0.9)
    p.prism_x([(-1.42, 3.98), (-1.75, 4.05), (-1.75, 4.2), (-1.35, 4.3)], -1.85, 1.85, "paint", bevel=0.02)  # brow
    p.box((0, 4.47, 0.3), (2.5, 0.05, 1.6), "team", bevel=0.012)
    p.box((0, 4.55, -0.95), (1.2, 0.14, 0.12), "head")  # roof work light
    for sx in (-1, 1):  # smoke dischargers, three each, on the tower's front corners
        for i in range(3):
            base = (sx * (1.95 - i * 0.18), 3.2, -1.05 - i * 0.05)
            p.ocyl(base, (sx * 0.4, 0.5, -1), 0.09, 0.42, 8, "dark")
        p.box((sx * 2.02, 3.05, 0.4), (0.05, 0.14, 2.0), "light")  # tower side sensor strips
    # satcom radome, antenna crown, command beacon, team pennant
    p.cylinder("y", (1.05, 4.6, 1.0), 0.48, 0.3, 14, "trim")
    p.ocyl((1.05, 4.75, 1.0), UP, 0.46, 0.32, 14, "radome", radius2=0.3)
    p.ocyl((1.05, 5.07, 1.0), UP, 0.3, 0.12, 14, "radome", radius2=0.08)
    for x, z, h in ((-1.55, 1.25, 2.7), (1.6, -0.75, 1.7), (-0.6, 1.4, 1.5)):
        p.cylinder("y", (x, 4.45 + 0.1, z), 0.12, 0.2, 8, "steel")
        p.cylinder("y", (x, 4.45 + h / 2, z), 0.045, h, 6, "dark")
    p.box((-1.55, 7.2, 1.25), (0.24, 0.22, 0.24), "light")  # command beacon
    p.obox((-1.55 + 0.36, 6.6, 1.25), (1, 0, 0), (0, 0, 1), 0.66, 0.42, 0.03, "team")  # pennant


def details_base(p):
    d, n = glacis_frame()
    for sx in (-1, 1):
        x = sx * SKIRT_OUT
        for z0, z1 in SKIRTS:
            bolts(p, (x, 2.0, z0), (x, 2.0, z1), 4, (sx, 0, 0))
            seam(p, (x, 0.95, z0 + 0.15), (x, 0.95, z1 - 0.15), (sx, 0, 0), width=0.05, height=0.015)
        bolts(p, (sx * 2.2, DECK + 0.001, -2.2), (sx * 2.2, DECK + 0.001, 3.6), 9, UP)
        seam(p, (sx * 0.62, DECK + 0.001, 1.75), (sx * 0.62, DECK + 0.001, 3.55), UP)
    for z in (1.75, 3.55):
        seam(p, (-2.0, DECK + 0.001, z), (2.0, DECK + 0.001, z), UP)
    # tower: door seams, hatch ring, periscopes over the glass band
    seam(p, (2.01, 2.5, 0.0), (2.01, 3.4, 0.0), (1, 0, 0))
    seam(p, (-2.01, 2.5, 0.0), (-2.01, 3.4, 0.0), (-1, 0, 0))
    ring(p, (-0.6, 4.451, 0.3), UP, 0.36)
    for dx in (-0.9, -0.3, 0.3, 0.9):
        p.obox((dx, 4.0, -1.38), (1, 0, 0), (0, 0, -1), 0.22, 0.1, 0.06, "glass")
    bolts(p, (-1.6, 3.3, -1.36), (1.6, 3.3, -1.36), 8, (0, 0, -1))
    # glacis: bolts round the team plates, a seam up the ridge
    for sx in (-1, 1):
        c = on_glacis(0.55, 0.04)
        for t in (-0.85, 0.85):
            p.ocyl(tuple(c + lib.vec((sx * 1.75 + t, 0, 0)) + d * 0.9), tuple(n), 0.05, 0.03, 6, "steel")
    seam(p, (0, 2.1, -4.6), (0, DECK + 0.21, -2.7), (0, 1, -0.3))


def build_nano(p):
    px, py, pz = NANO_PIVOT
    # turntable: drum, team top ring, power ring round its foot
    p.cylinder("y", (0, py + 0.2, pz), 1.3, 0.4, 18, "paint")
    p.cylinder("y", (0, py + 0.42, pz), 1.1, 0.05, 18, "team")
    p.cylinder("y", (0, py + 0.06, pz), 1.33, 0.12, 18, "power")
    # yoke and pin
    for sx in (-1, 1):
        p.obox((sx * 0.5, py + 0.85, pz + 0.1), UP, (1, 0, 0), 0.9, 0.8, 0.2, "trim", bevel=0.03)
    p.cylinder("x", (0, py + 1.05, pz + 0.1), 0.2, 1.25, 10, "steel")
    # heavy boom rising to the rear, a team stripe along its top, a ram under it
    base = lib.vec((0, py + 1.05, pz + 0.1))
    tip = lib.vec((0, py + 2.75, pz + 1.75))
    dvec = tip - base
    p.obox(tuple((base + tip) / 2), tuple(dvec), (1, 0, 0), dvec.length + 0.3, 0.65, 0.7, "paint", bevel=0.05)
    up = dvec.cross(lib.vec((1, 0, 0))).normalized()
    if up.y < 0:
        up = -up
    p.obox(tuple((base + tip) / 2 + up * 0.36), tuple(dvec), tuple(up), dvec.length * 0.7, 0.45, 0.04, "team")
    a = lib.vec((0, py + 0.5, pz - 0.6))
    b = base + dvec * 0.55
    p.obox(tuple((a + b) / 2), tuple(b - a), (1, 0, 0), (b - a).length, 0.24, 0.24, "steel")
    p.obox(tuple(a + (b - a) * 0.3), tuple(b - a), (1, 0, 0), (b - a).length * 0.5, 0.34, 0.34, "trim")
    # emitter head: an armored housing, a big glowing lens ring and core, fins
    head = tip + lib.vec((0, 0.1, 0.15))
    p.box(tuple(head), (1.3, 1.0, 1.0), "trim", bevel=0.06)
    p.cylinder("y", tuple(head + lib.vec((0, 0.55, 0))), 0.55, 0.12, 14, "dark")
    p.cylinder("y", tuple(head + lib.vec((0, 0.62, 0))), 0.45, 0.06, 14, "power")
    p.cylinder("z", tuple(head + lib.vec((0, 0, 0.53))), 0.42, 0.08, 14, "power")
    for sx in (-1, 1):
        p.obox(tuple(head + lib.vec((sx * 0.72, 0, 0))), UP, (1, 0, 0), 0.8, 0.9, 0.08, "dark", bevel=0.02)
        p.box(tuple(head + lib.vec((sx * 0.77, 0.2, -0.2))), (0.03, 0.12, 0.5), "light")


def details_nano(p):
    px, py, pz = NANO_PIVOT
    ring(p, (0, py + 0.401, pz), UP, 1.2)
    for i in range(10):
        t = 2 * math.pi * i / 10
        unit.bolt(p, (math.cos(t) * 1.2, py + 0.402, pz + math.sin(t) * 1.2), UP)


unit.run(__file__, "ord_sovereign", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO_PIVOT, build_nano, details_nano)],
         budget=5000,
         previews=[("35", (-15, 12, 18), (0, 2.2, 0), 50),
                   ("side", (20, 4, -1.0), (0, 2.4, -1.0), 50),
                   ("80", (0, 30, 5), (0, 2, 0), 50),
                   ("close", (-6.5, 6.0, -8.0), (0, 3.0, -0.5), 35)])
