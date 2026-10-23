"""Shipyard (Order naval factory, T1 structure, footprint 5, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_shipyard/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 5, 40 x 40
studs; the hall about 10.5 tall, the gantry about 13: the tallest T1
buildings). The waterline is y = 0. Big shapes first:
- a chamfered armored quay at the back carrying a construction hall with
  sloped roof walls, a large team roof, front buttresses, a big door with a
  lit frame and build lights facing the slip (power: pulses while
  producing), roof vents with glowing rims;
- two long armored piers with chamfered tips, large team deck plates,
  hazard edges along the slip, crane rails, rubber fenders, bollards,
  running strips and tip lights;
- a heavy portal gantry crane on bogies over the slip with tapered legs, a
  team band on the beam, four build lamps under it and the client-slid
  `trolley` (slide X, M-27) with its own lamp (`nano1..5`).
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

PX = 16.0  # pier centre (x mirrored)
PW = 3.2  # pier half width
GZ = -6.0  # gantry z
BEAM_Y = 11.8


def build_base(p):
    # quay: chamfered armored block from below the water to the deck
    quay = [(-19.6, 10.4), (19.6, 10.4), (19.6, 18.4), (18.4, 19.6), (-18.4, 19.6), (-19.6, 18.4)]
    p.prism_y(quay, -1.0, 0.8, "trim", bevel=0.14)
    p.box((0, 0.3, 10.36), (38.8, 0.16, 0.06), "light")
    # construction hall: walls, sloped roof walls, team roof, vents
    p.prism_x([(11.2, 0.8), (19.0, 0.8), (19.0, 8.6), (17.6, 10.4), (12.6, 10.4), (11.2, 8.6)], -13.0, 13.0, "paint", bevel=0.18)
    p.box((0, 10.44, 15.1), (24.0, 0.06, 4.8), "team", bevel=0.02)
    for sx in (-1, 1):
        p.ocyl((sx * 8.5, 10.4, 17.4), UP, 0.9, 1.6, 14, "trim", radius2=0.75)
        p.cylinder("y", (sx * 8.5, 12.04, 17.4), 0.76, 0.08, 14, "power")
        p.box((sx * 13.03, 4.6, 15.1), (0.06, 0.16, 6.6), "light")
        p.box((sx * 13.03, 6.6, 16.0), (0.06, 2.0, 3.6), "grille")
        # front buttresses
        p.prism_x([(9.6, 0.8), (11.2, 0.8), (11.2, 7.6), (10.6, 7.6)], sx * 12.2 - 0.9, sx * 12.2 + 0.9, "paint", bevel=0.08)
    # big door with a lit frame and build lights through it
    p.box((0, 4.3, 11.14), (19.0, 7.0, 0.1), "dark")
    for i in range(4):
        p.box((0, 1.6 + i * 1.5, 11.07), (18.4, 0.14, 0.06), "power")
    p.box((0, 8.0, 11.02), (20.0, 0.36, 0.16), "power")  # lintel
    for sx in (-1, 1):
        p.box((sx * 9.8, 4.4, 11.02), (0.32, 7.2, 0.16), "power")  # door frame
    hazard(p, (0, 0.83, 10.9), (1, 0, 0), UP, 19.0, 0.6, stripes=28)
    # piers: armored, chamfered tips, team decks, hazard slip edges, rails
    for sx in (-1, 1):
        x = sx * PX
        p.prism_x([(-17.6, -1.0), (10.6, -1.0), (10.6, 2.4), (-17.6, 2.4), (-19.6, 1.2), (-19.6, -1.0)], x - PW, x + PW, "paint", bevel=0.12)
        p.box((x, 2.44, -1.0), (4.6, 0.06, 9.0), "team", bevel=0.02)
        p.box((x, 2.44, -13.0), (4.6, 0.06, 5.0), "team", bevel=0.02)
        hazard(p, (x - sx * (PW - 0.3), 2.45, -4.0), (0, 0, 1), UP, 28.0, 0.5, stripes=36)
        for dx in (-1.6, 1.6):  # crane rails
            p.box((x + dx, 2.5, -4.0), (0.3, 0.12, 26.0), "steel")
        p.box((x + sx * (PW + 0.02), 1.2, -4.0), (0.06, 0.16, 26.0), "light")  # outer running strip
        for z in (-15.0, -9.0, -3.0, 3.0, 9.0):  # fenders on the slip side
            drum(p, (x - sx * (PW + 0.25), 0.9, z), 0.4, 2.2, "rubber", "rubber", sides=10, axis="z")
        for z in (-17.0, 7.0):  # bollards
            p.cylinder("y", (x + sx * 2.2, 2.75, z), 0.3, 0.7, 10, "steel")
        p.box((x, 2.9, -18.6), (0.9, 0.9, 0.9), "light")  # tip light
    # portal gantry crane: bogies, tapered legs, beam, lamps, team band
    for sx in (-1, 1):
        x = sx * PX
        p.box((x, 3.0, GZ), (4.0, 0.9, 3.4), "trim", bevel=0.06)  # bogie
        for dz in (-1.1, 1.1):
            p.cylinder("x", (x, 2.75, GZ + dz), 0.42, 3.6, 12, "dark")
        p.prism_y(rect(x, GZ, 1.3, 1.1), 3.4, BEAM_Y - 0.7, "paint", bevel=0.1, top_scale=0.7)
        p.box((x - sx * 0.95, 7.2, GZ), (0.06, 5.0, 0.3), "light")
        p.obox((x - sx * 2.6, BEAM_Y - 2.0, GZ), (sx * -1.0, 1.0, 0), (0, 0, 1), 3.4, 0.6, 0.5, "trim")  # knee brace
    p.box((0, BEAM_Y, GZ), (34.6, 1.4, 1.8), "paint", bevel=0.08)
    p.box((0, BEAM_Y + 0.73, GZ), (26.0, 0.06, 1.4), "team", bevel=0.015)
    hazard(p, (0, BEAM_Y, GZ - 0.92), (1, 0, 0), (0, 0, -1), 30.0, 0.5, stripes=40)
    p.box((0, BEAM_Y + 1.0, GZ + 0.6), (3.0, 0.9, 1.2), "trim", bevel=0.05)  # hoist house
    for x in (-10.0, -4.0, 2.0, 8.0):
        p.box((x, BEAM_Y - 0.72, GZ), (1.6, 0.06, 1.0), "power")  # build lamps under the beam
    with p.sub("trolley", (4.0, 10.7, GZ), "slide", (1, 0, 0), 12):  # M-27 along the gantry
        p.box((4.0, 10.7, GZ), (2.2, 0.8, 2.2), "trim", bevel=0.05)
        p.box((4.0, 10.28, GZ), (1.0, 0.06, 1.0), "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 19.0, 0.86, 10.8 + sz * 0.0 + (sz + 1) * 4.2), (0.5, 0.14, 0.5), "light")


def details_base(p):
    for sx in (-1, 1):
        for z in (-14.0, -6.0, 2.0):
            seam(p, (sx * PX - 2.8, 2.401, z), (sx * PX + 2.8, 2.401, z), UP)
        rivets(p, (sx * 13.03, 1.4, 12.0), (sx * 13.03, 1.4, 18.4), 7, (sx, 0, 0))
    bolts(p, (-18.0, 0.801, 19.2), (18.0, 0.801, 19.2), 20, UP)


unit.run(__file__, "ord_shipyard", "order", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
