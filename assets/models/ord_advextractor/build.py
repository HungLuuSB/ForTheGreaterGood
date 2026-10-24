"""Advanced Extractor (Order supply extractor, T2 structure, footprint 3):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advextractor/build.py

New mesh at the size scale (S-104, M-26: footprint 3, 24 x 24 studs, about
11.5 tall), from its blockout; the T1 Extractor's big brother, not a
rescale. Big readable shapes first: a thick chamfered slab and a dark
plinth, a long armored housing with sloped upper walls and a large team
deck, twin turning drill crowns side by side (`drillL`, `drillR`, turn Y,
counter-rotating, rig.md 9; the blockout's two drill heads) with glowing
power bands, arms and spindles on armored collars; two ore slurry tanks on
cradles along the flanks with team strips (the blockout's side tanks: wider
than the T1), two ore silos with team bands fed by inclined conveyors at the
back, a lit armored door bay with a walkway, two pump units with valves and
hazard striping at the front, a control mast on the deck, corner anchor
blocks with lights. Order reads heavy and clean (M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
ROOF = 5.7  # top of the housing (the team deck)
DRILLS = ((-4.0, "drillL", 1), (4.0, "drillR", -1))  # x, piece, turn sense
HX, HZ = 7.8, 6.0  # housing half sizes


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


def octrect(hx, hz, cut, cx=0.0, cz=0.0):
    """Top-view octagon (x, z) on a rectangle of half sizes hx, hz, corners cut by `cut`."""
    pts = [(-hx + cut, -hz), (hx - cut, -hz), (hx, -hz + cut), (hx, hz - cut),
           (hx - cut, hz), (-hx + cut, hz), (-hx, hz - cut), (-hx, -hz + cut)]
    return [(cx + x, cz + z) for x, z in pts]


def build_base(p):
    # thick chamfered slab, a dark plinth under the housing
    p.prism_y(octagon(11.8, 1.6), 0.0, 0.85, "trim", bevel=0.16, top_scale=0.985)
    p.prism_y(octrect(9.4, 7.6, 1.8), 0.85, 1.15, "dark", bevel=0.06)
    # the long armored housing: upright walls, sloped upper walls, a team deck
    p.prism_y(octrect(HX, HZ, 1.8), 1.15, 4.3, "paint", bevel=0.2)
    p.prism_y(octrect(HX, HZ, 1.8), 4.3, ROOF, "paint", bevel=0.2, top_scale=0.85)
    p.prism_y(octrect(6.35, 4.85, 1.4), ROOF, ROOF + 0.07, "team", bevel=0.03)
    for sx in (-1, 1):  # power strips along the flanks, a running band at the back
        p.box((sx * (HX + 0.02), 2.7, 0.0), (0.05, 0.18, 6.4), "power")
    p.box((0.0, 2.7, HZ + 0.02), (8.0, 0.18, 0.05), "power")
    # front: an armored door bay with a lit lintel, a walkway, hazard striping
    p.box((0.0, 2.55, -HZ - 0.25), (4.4, 2.8, 0.5), "trim", bevel=0.08)
    p.box((0.0, 2.35, -HZ - 0.51), (3.4, 2.2, 0.04), "dark")
    p.box((0.0, 3.72, -HZ - 0.53), (3.2, 0.14, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 1.85, 2.35, -HZ - 0.53), (0.12, 2.0, 0.04), "light")
        p.box((sx * 4.6, 2.7, -HZ - 0.02), (2.6, 0.18, 0.05), "power")
    p.box((0.0, 1.21, -7.6), (4.4, 0.12, 2.4), "grille")
    hazard(p, (0.0, 0.87, -10.4), (1, 0, 0), UP, 9.0, 0.6, stripes=16)
    # control mast at the back of the deck: a box, an aerial, a lamp
    p.box((0.0, ROOF + 0.55, 3.6), (1.6, 1.1, 1.2), "trim", bevel=0.06)
    p.box((0.0, ROOF + 0.75, 2.98), (1.2, 0.12, 0.04), "light")
    p.cylinder("y", (0.45, ROOF + 2.0, 3.8), 0.07, 2.0, 6, "steel")
    p.box((0.45, ROOF + 3.05, 3.8), (0.22, 0.14, 0.22), "light")
    # armored collars under the drills
    for dx, _, _ in DRILLS:
        p.cylinder("y", (dx, ROOF + 0.32, 0.0), 2.2, 0.64, 20, "trim", bevel=0.05)
        p.cylinder("y", (dx, ROOF + 0.68, 0.0), 1.95, 0.1, 20, "dark")
    # ore slurry tanks on cradles along the flanks, team strips on top
    for sx in (-1, 1):
        tx = sx * 9.9
        for z in (-3.0, 3.0):
            p.box((tx, 1.25, z), (2.5, 0.8, 0.7), "trim", bevel=0.06)
        drum(p, (tx, 2.55, 0.0), 1.45, 9.2, "paint", "trim", sides=16, axis="z")
        for z in (-3.6, 3.6):
            p.cylinder("z", (tx, 2.55, z), 1.5, 0.22, 16, "dark")
        p.box((tx, 4.02, 0.0), (1.2, 0.05, 6.4), "team", bevel=0.012)
        p.box((tx + sx * 1.46, 2.55, 0.0), (0.05, 0.16, 4.6), "light")
        for z in (-2.2, 2.2):  # feed pipes into the housing
            cable(p, [(tx - sx * 0.6, 3.7, z), (sx * 8.6, 4.5, z), (sx * 7.3, 4.5, z)], r=0.16, kind="steel")
    # ore silos at the back corners, fed by inclined conveyors from the deck
    for sx in (-1, 1):
        cx, cz = sx * 8.4, 8.9
        p.cylinder("y", (cx, 3.45, cz), 1.6, 5.2, 16, "paint", bevel=0.04)
        p.ocyl((cx, 6.05, cz), UP, 1.6, 0.7, 16, "trim", radius2=0.95)
        p.cylinder("y", (cx, 4.7, cz), 1.63, 1.0, 16, "team")
        p.cylinder("y", (cx, 1.25, cz), 1.66, 0.22, 16, "dark")
        p.box((cx, 6.85, cz), (0.4, 0.16, 0.4), "light")
        a, b = V((sx * 5.0, ROOF + 0.3, 3.6)), V((cx - sx * 0.3, 6.9, cz - 0.6))
        u = b - a
        p.obox(tuple((a + b) / 2), tuple(u), UP, u.length, 1.0, 0.32, "trim", bevel=0.05)
        p.obox(tuple((a + b) / 2 + V((0, 0.18, 0))), tuple(u), UP, u.length * 0.94, 0.76, 0.04, "grille")
    # pump units either side of the walkway: drums, valves, pipes into the wall
    for sx in (-1, 1):
        px, pz = sx * 5.6, -8.4
        p.box((px, 1.2, pz), (2.8, 0.7, 1.9), "trim", bevel=0.08)
        drum(p, (px, 2.05, pz), 0.75, 2.4, "paint", "trim", sides=14)
        p.box((px, 2.05, pz - 0.78), (1.7, 0.14, 0.04), "power")
        p.cylinder("y", (px + sx * 0.7, 3.0, pz), 0.17, 1.2, 8, "steel")
        p.cylinder("x", (px + sx * 0.7, 3.6, pz), 0.32, 0.12, 10, "dark")  # valve wheel
        cable(p, [(px - sx * 1.0, 2.2, pz), (px - sx * 1.0, 2.2, -HZ - 0.3), (px - sx * 1.0, 3.2, -HZ + 0.1)], r=0.15, kind="steel")
    # corner anchor blocks at the front with lights
    for sx in (-1, 1):
        c = (sx * 9.6, -9.0)
        p.prism_y([(c[0] - 0.9, c[1] - 0.9), (c[0] + 0.9, c[1] - 0.9), (c[0] + 0.9, c[1] + 0.9), (c[0] - 0.9, c[1] + 0.9)],
                  0.85, 1.75, "paint", bevel=0.1, top_scale=0.78)
        p.box((c[0], 1.8, c[1]), (0.5, 0.12, 0.5), "light")

    # the twin drill crowns: tall turning drums with power bands, four arms, a spindle
    for dx, name, sense in DRILLS:
        with p.sub(name, (dx, ROOF + 0.72, 0.0), "turn", (0, sense, 0)):
            y0 = ROOF + 0.72
            p.cylinder("y", (dx, y0 + 1.1, 0), 1.85, 2.2, 20, "steel")
            for y in (y0 + 0.35, y0 + 1.1, y0 + 1.85):
                hoop(p, (dx, y, 0), 1.88, 1.7, 0.16, 20, "power")
            p.cylinder("y", (dx, y0 + 2.45, 0), 1.6, 0.5, 18, "trim")
            for k in range(4):
                a = math.radians(45 + 90 * k)
                d = V((math.cos(a), 0, math.sin(a)))
                p.obox(tuple(V((dx, y0 + 2.9, 0)) + d * 1.5), tuple(d), UP, 1.9, 0.6, 0.55, "paint", bevel=0.06)
                p.box(tuple(V((dx, y0 + 2.95, 0)) + d * 2.4), (0.32, 0.12, 0.32), "light")
            p.box((dx, y0 + 3.2, 0), (2.6, 0.04, 0.6), "team")
            p.cylinder("y", (dx, y0 + 3.5, 0), 0.95, 0.9, 14, "dark")
            p.cylinder("y", (dx, y0 + 4.6, 0), 0.38, 1.4, 8, "steel")
            p.cylinder("y", (dx, y0 + 5.38, 0), 0.46, 0.22, 10, "power")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * (HX + 0.02), 1.6, -4.0), (sx * (HX + 0.02), 1.6, 4.0), 9, (sx, 0, 0))
        seam(p, (sx * (HX + 0.02), 4.3, -4.2), (sx * (HX + 0.02), 4.3, 4.2), (sx, 0, 0))
        rivets(p, (sx * 9.9 - 0.4, 4.05, -3.0), (sx * 9.9 - 0.4, 4.05, 3.0), 7, UP)
    rivets(p, (-3.6, 1.6, HZ + 0.02), (3.6, 1.6, HZ + 0.02), 8, (0, 0, 1))
    for dx, _, _ in DRILLS:
        ring(p, (dx, ROOF + 0.645, 0), UP, 2.08)


unit.run(__file__, "ord_advextractor", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-32, 25, -38), (0, 4.0, 0), 50),
                   ("80", (0, 52, 9), (0, 3, 0), 50),
                   ("close", (-16, 13, -19), (0, 5.0, 0), 35)])
