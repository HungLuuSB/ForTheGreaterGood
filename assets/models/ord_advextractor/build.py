"""Advanced Extractor (Order supply extractor, T2 structure, footprint 2):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advextractor/build.py

F6 (the user 2026-10-26: "T2 of the T1 extractor must be the same size,
they should look like an upgrade version"; S-184 footprint 2, upgraded in
place over the T1 on its 2 x 2 deposit patch, S-108): the T1 Extractor's
mesh (tools/../ord_extractor/build.py: the chamfered slab, the octagonal
armored housing with its team deck, ore hoppers on inclined conveyors,
pump units, corner anchors, the walkway) carrying the upgrade: a second
armored tier with a glowing power band, radiator fins on both flanks and
its own team deck, heavier twin pumps, and a taller drill tower (`drill`,
turn Y, rig.md 9) with three power bands and a four-armed crown. About 11
studs tall to the T1's 6. Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec


def octagon(r, cut):
    """Top-view octagon (x, z): a square of half-size r with corners cut by `cut`."""
    return [(-r + cut, -r), (r - cut, -r), (r, -r + cut), (r, r - cut), (r - cut, r), (-r + cut, r), (-r, r - cut), (-r, -r + cut)]


def build_base(p):
    # thick chamfered slab and a darker plinth ring round the housing
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.78, "trim", bevel=0.14, top_scale=0.985)
    p.prism_y(octagon(5.6, 1.4), 0.78, 1.05, "dark", bevel=0.06)
    # armored octagonal housing with sloped upper walls
    p.prism_y(octagon(4.6, 1.4), 1.05, 2.6, "paint", bevel=0.16)
    p.prism_y(octagon(4.6, 1.4), 2.6, 3.55, "paint", bevel=0.16, top_scale=0.82)
    p.prism_y(octagon(3.7, 1.15), 3.55, 3.62, "team", bevel=0.03)  # large team deck
    for sx in (-1, 1):  # power strips round the housing
        p.box((sx * 4.62, 2.0, 0.0), (0.04, 0.16, 3.0), "power")
        p.box((0.0, 2.0, sx * 4.62), (3.0, 0.16, 0.04), "power")
    # corner anchor blocks with lights and hazard striping
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = (sx * 6.3, 1.1, sz * 6.3)
            p.prism_y([(c[0] - 0.8, c[2] - 0.8), (c[0] + 0.8, c[2] - 0.8), (c[0] + 0.8, c[2] + 0.8), (c[0] - 0.8, c[2] + 0.8)],
                      0.78, 1.6, "paint", bevel=0.1, top_scale=0.8)
            p.box((c[0], 1.66, c[2]), (0.45, 0.12, 0.45), "light")
    hazard(p, (0, 0.8, -6.9), (1, 0, 0), (0, 1, 0), 6.0, 0.5, stripes=12)
    # ore hoppers (front left, back right): tapered bins on legs, team panels
    for sx, sz in ((-1, -1), (1, 1)):
        hx, hz = sx * 5.2, sz * 5.0
        for lx in (-0.9, 0.9):
            for lz in (-0.9, 0.9):
                p.box((hx + lx, 1.6, hz + lz), (0.22, 1.7, 0.22), "dark")
        p.prism_y([(hx - 1.0, hz - 1.0), (hx + 1.0, hz - 1.0), (hx + 1.0, hz + 1.0), (hx - 1.0, hz + 1.0)],
                  2.2, 4.0, "paint", bevel=0.1, top_scale=1.35)
        p.obox((hx - sx * 0.02, 3.2, hz + sz * 1.22), (1, 0, 0), (0, 0.25, sz), 2.0, 1.3, 0.06, "team", bevel=0.02)
        p.box((hx, 4.02, hz), (2.4, 0.06, 2.4), "grille")
        # inclined conveyor from the housing to the hopper
        a = V((sx * 2.2, 3.4, sz * 2.0))
        b = V((hx - sx * 0.6, 4.2, hz - sz * 0.6))
        u = b - a
        p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.9, 0.3, "trim", bevel=0.05)
        p.obox(tuple((a + b) / 2 + V((0, 0.17, 0))), tuple(u), (0, 1, 0), u.length * 0.95, 0.7, 0.04, "grille")
        for t in (0.25, 0.75):
            q = a + u * t
            p.box((q.x, (q.y + 1.0) / 2, q.z), (0.18, q.y - 1.0, 0.18), "dark")
    # pump units on the other two corners: horizontal drums, pipes, valves
    for sx, sz in ((1, -1), (-1, 1)):
        px, pz = sx * 5.0, sz * 5.0
        p.box((px, 1.4, pz), (2.4, 0.7, 1.8), "trim", bevel=0.08)
        drum(p, (px, 2.25, pz), 0.75, 2.2, "paint", "trim", sides=16)
        p.box((px, 2.25, pz + sz * 0.78), (1.6, 0.14, 0.04), "power")
        p.cylinder("y", (px - sx * 0.6, 3.2, pz), 0.18, 1.2, 8, "steel")
        p.cylinder("x", (px - sx * 0.6, 3.8, pz), 0.3, 0.4, 10, "dark")  # valve wheel
        cable(p, [(px - sx * 1.1, 2.3, pz), (sx * 4.2, 2.3, pz * 0.6), (sx * 4.2, 1.6, pz * 0.4)], r=0.14, kind="steel")
    # front walkway with a rail and a lit door
    p.box((0, 1.25, -5.0), (3.0, 0.12, 1.2), "grille")
    p.box((0, 2.0, -4.62), (1.6, 1.5, 0.06), "dark")
    p.box((0, 2.8, -4.64), (1.4, 0.12, 0.04), "light")

    # F6: the upgrade tier on the T1's team deck: armored, a power band,
    # radiator fins on both flanks, its own team deck
    p.prism_y(octagon(3.5, 1.05), 3.62, 5.2, "paint", bevel=0.14)
    p.prism_y(octagon(3.5, 1.05), 5.2, 6.0, "paint", bevel=0.14, top_scale=0.84)
    p.prism_y(octagon(2.75, 0.85), 6.0, 6.06, "team", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 3.52, 4.4, 0.0), (0.04, 0.18, 2.6), "power")
        p.box((0.0, 4.4, sx * 3.52), (2.6, 0.18, 0.04), "power")
        for k in range(5):  # radiator fins
            p.box((sx * 3.75, 4.6, -1.2 + k * 0.6), (0.5, 1.6, 0.08), "trim")
        p.box((sx * 3.62, 5.45, 0.0), (0.3, 0.12, 3.0), "steel")
    # heavier twin pumps: a second drum on each pump unit
    for sx, sz in ((1, -1), (-1, 1)):
        px, pz = sx * 5.0, sz * 5.0
        drum(p, (px, 3.3, pz), 0.55, 1.8, "paint", "trim", sides=14)
        p.box((px, 3.3, pz + sz * 0.58), (1.2, 0.12, 0.04), "power")

    # the drill tower: a tall turning drum with three power bands, four arms and a cap
    with p.sub("drill", (0.0, 6.06, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 7.6, 0), 1.6, 3.1, 20, "steel")
        for y in (6.6, 7.6, 8.6):
            p.cylinder("y", (0, y, 0), 1.64, 0.16, 20, "power")
        p.cylinder("y", (0, 9.4, 0), 1.3, 0.5, 18, "trim")
        for k in range(4):
            a = math.radians(45 + 90 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            p.obox(tuple(V((0, 9.7, 0)) + d * 1.45), tuple(d), (0, 1, 0), 1.9, 0.55, 0.5, "paint", bevel=0.06)
            p.box(tuple(V((0, 9.78, 0)) + d * 2.3), (0.32, 0.12, 0.32), "light")
        p.cylinder("y", (0, 10.25, 0), 0.8, 0.7, 14, "dark")
        p.cylinder("y", (0, 10.75, 0), 0.45, 0.3, 10, "power")
        p.box((0, 10.4, 0), (2.4, 0.04, 0.55), "team")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 4.62, 1.4, -2.2), (sx * 4.62, 1.4, 2.2), 6, (sx, 0, 0))
        rivets(p, (-2.2, 1.4, sx * 4.62), (2.2, 1.4, sx * 4.62), 6, (0, 0, sx))
        seam(p, (sx * 4.62, 2.6, -2.5), (sx * 4.62, 2.6, 2.5), (sx, 0, 0))
        seam(p, (sx * 3.52, 5.2, -1.6), (sx * 3.52, 5.2, 1.6), (sx, 0, 0))


unit.run(__file__, "ord_advextractor", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 19, -26), (0, 4.0, 0), 50),
                   ("80", (0, 38, 6), (0, 3, 0), 50),
                   ("close", (-11, 12, -13), (0, 5.0, 0), 35)])
