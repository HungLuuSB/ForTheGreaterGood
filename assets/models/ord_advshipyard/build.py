"""Advanced Shipyard (Order naval factory, T2 structure, footprint 6, on
water): mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advshipyard/build.py

Designed at the size scale (S-104, M-26: footprint 6, 48 x 48 studs; the
covered dock about 15 tall, the gantry about 17.5), bigger and busier than
the T1 Shipyard rather than a rescale. The waterline is y = 0. Big shapes
first:
- a chamfered armored quay at the back carrying a tall construction hall
  (sloped roof walls, a large team roof, vents with glowing rims, a big
  door with a lit frame facing the slip) between a power annex and a
  control annex with a glass front;
- two long armored piers with chamfered tips, large team deck plates,
  hazard edges along the slip, crane rails, fenders, bollards, running
  strips and tip lights;
- a covered building dock over the slip (the T2 signature, T1 vs T2 check
  2026-10-22): armored walls on the piers with buttresses, a lit portal at
  the front (power: pulses while producing) and a roof of two team-plated
  halves on four portal frames with a long open slot between them, so the
  hull on the slip shows from the game camera; four build lamps along the
  slot (`nano1..4`), the build pad in the slip below (`buildpad`, y = 0);
- a heavy portal gantry crane on bogies at the front that travels along the
  pier rails (`gantry`, slide Z, rig.md 9) with a team band, a hoist house
  and two build lamps under the beam (`nano5`, `nano6`, ride with it).
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, rect, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

PX, PW = 19.2, 4.0  # pier centre (x mirrored), half width
DZ0, DZ1 = -9.6, 13.0  # covered dock z span
WALL_X = 15.2  # dock wall inner face (x mirrored)
ROOF_Y = 14.2
SLOT = 5.0  # half width of the roof slot
RIBS = (-9.2, -1.6, 6.0, 12.6)
GZ, BEAM_Y = -17.4, 16.6  # gantry rest z, beam height
LAMPS = [(sx * (SLOT + 0.3), z) for sx in (-1, 1) for z in (-4.0, 6.0)]


def build_base(p):
    # quay: chamfered armored block from below the water to the deck
    quay = [(-23.6, 13.4), (23.6, 13.4), (23.6, 21.6), (21.6, 23.6), (-21.6, 23.6), (-23.6, 21.6)]
    p.prism_y(quay, -1.2, 0.9, "trim", bevel=0.16)
    p.box((0, 0.35, 13.36), (37.0, 0.16, 0.06), "light")
    # construction hall: walls, sloped roof walls, team roof, vents, door
    p.prism_x([(14.0, 0.9), (23.2, 0.9), (23.2, 11.4), (21.4, 13.4), (15.8, 13.4), (14.0, 11.8)], -14.6, 14.6, "paint", bevel=0.2)
    p.box((0, 13.44, 18.6), (24.0, 0.06, 4.8), "team", bevel=0.02)
    for sx in (-1, 1):
        p.ocyl((sx * 9.6, 13.4, 21.6), UP, 0.95, 1.8, 14, "trim", radius2=0.78)
        p.cylinder("y", (sx * 9.6, 15.24, 21.6), 0.8, 0.08, 14, "power")
        p.box((sx * 14.63, 6.6, 18.6), (0.06, 0.16, 8.0), "light")
    p.box((0, 5.0, 13.98), (18.0, 8.2, 0.06), "dark")
    for i in range(4):
        p.box((0, 1.8 + i * 1.7, 13.93), (17.4, 0.14, 0.06), "power")
    p.box((0, 9.3, 13.9), (19.2, 0.36, 0.1), "power")  # lintel
    for sx in (-1, 1):
        p.box((sx * 9.3, 5.0, 13.9), (0.32, 8.4, 0.1), "power")  # door frame
    # annexes on the quay: power (left), control with a glass front (right)
    p.prism_x([(14.6, 0.9), (23.0, 0.9), (23.0, 6.4), (21.8, 7.6), (14.6, 7.6)], -23.0, -15.0, "paint", bevel=0.14)
    p.box((-19.0, 7.64, 18.8), (6.4, 0.06, 6.4), "grille")
    for z in (16.8, 20.8):
        p.cylinder("y", (-19.0, 8.6, z), 1.3, 1.8, 14, "trim")
        p.cylinder("y", (-19.0, 9.54, z), 1.0, 0.1, 14, "power")
    p.prism_x([(14.6, 0.9), (23.0, 0.9), (23.0, 7.6), (14.6, 7.6), (14.0, 6.8)], 15.0, 23.0, "paint", bevel=0.14)
    p.box((19.0, 7.64, 18.8), (6.6, 0.06, 7.2), "team", bevel=0.02)
    p.obox((19.0, 5.6, 14.25), (1, 0, 0), (0, 0.6, -1), 6.6, 1.6, 0.05, "glass")
    p.box((19.0, 4.6, 14.62), (6.8, 0.14, 0.06), "light")
    # piers: armored, chamfered tips, team decks, hazard slip edges, rails
    for sx in (-1, 1):
        x = sx * PX
        p.prism_x([(-21.4, -1.2), (13.4, -1.2), (13.4, 2.6), (-21.4, 2.6), (-23.4, 1.4), (-23.4, -1.2)], x - PW, x + PW, "paint", bevel=0.14)
        p.box((x, 2.64, -16.2), (6.0, 0.06, 8.0), "team", bevel=0.02)
        hazard(p, (x - sx * (PW - 0.3), 2.65, -16.0), (0, 0, 1), UP, 12.0, 0.5, stripes=16)
        for dx in (-1.9, 1.9):  # crane rails
            p.box((x + dx, 2.7, -15.4), (0.3, 0.12, 13.0), "steel")
        p.box((x + sx * (PW + 0.02), 1.4, -5.0), (0.06, 0.16, 34.0), "light")  # outer running strip
        for z in (-20.0, -14.0, -8.0, -2.0, 4.0, 10.0):  # fenders on the slip side
            drum(p, (x - sx * (PW + 0.25), 1.0, z), 0.42, 2.4, "rubber", "rubber", sides=10, axis="z")
        for z in (-22.0, -10.5):  # bollards
            p.cylinder("y", (x + sx * 2.6, 2.95, z), 0.32, 0.7, 10, "steel")
        p.box((x, 3.1, -22.6), (1.0, 1.0, 1.0), "light")  # tip light
    # covered dock: walls on the piers with buttresses and a lit portal
    for sx in (-1, 1):
        x0, x1 = sorted((sx * WALL_X, sx * (WALL_X + 1.5)))
        p.prism_x([(DZ0, 2.6), (DZ1, 2.6), (DZ1, ROOF_Y), (DZ0 + 1.2, ROOF_Y), (DZ0, ROOF_Y - 1.6)], x0, x1, "paint", bevel=0.12)
        for z in (-6.0, 1.8, 9.6):
            p.prism_x([(z - 0.9, 2.6), (z + 0.9, 2.6), (z + 0.6, 10.4), (z - 0.6, 10.4)],
                      *sorted((sx * (WALL_X + 1.5), sx * (WALL_X + 2.6))), "paint", bevel=0.08)
        p.box((sx * (WALL_X + 1.53), 11.4, 1.8), (0.06, 0.16, 21.0), "light")
        p.box((sx * (WALL_X - 0.05), 8.4, 1.8), (0.06, 1.2, 20.0), "grille")
        p.box((sx * (WALL_X + 0.4), 8.0, DZ0 - 0.05), (0.32, 10.0, 0.1), "power")  # portal jamb
    # the roof: two team-plated halves, portal frames across the open slot
    for sx in (-1, 1):
        x0, x1 = sorted((sx * SLOT, sx * (WALL_X + 2.2)))
        p.prism_x([(DZ0 - 0.4, ROOF_Y - 0.6), (DZ1, ROOF_Y - 0.6), (DZ1, ROOF_Y + 0.8), (DZ0 + 0.8, ROOF_Y + 0.8)], x0, x1, "paint", bevel=0.1)
        p.box((sx * 10.9, ROOF_Y + 0.84, 2.0), (9.0, 0.06, 18.6), "team", bevel=0.02)
        p.box((sx * (SLOT + 0.03), ROOF_Y + 0.2, 1.8), (0.06, 0.16, 21.0), "light")
    for z in RIBS:
        p.box((0, ROOF_Y + 1.25, z), (WALL_X * 2 + 4.6, 0.9, 1.0), "trim", bevel=0.06)
    p.box((0, ROOF_Y - 0.6, DZ0 - 0.25), (WALL_X * 2 + 1.0, 0.3, 0.1), "power")  # portal lintel
    for sx in (-1, 1):  # roof vents, a beacon mast at the front corner
        for z in (9.3, -5.4):
            p.box((sx * 10.9, ROOF_Y + 1.1, z), (3.2, 0.6, 1.8), "trim", bevel=0.06)
            p.box((sx * 10.9, ROOF_Y + 1.42, z), (2.8, 0.04, 1.4), "grille")
        p.box((sx * 16.4, ROOF_Y + 1.2, -8.4), (0.9, 0.8, 0.9), "trim", bevel=0.05)
        p.cylinder("y", (sx * 16.4, ROOF_Y + 2.6, -8.4), 0.07, 2.0, 6, "steel")
        p.box((sx * 16.4, ROOF_Y + 3.7, -8.4), (0.32, 0.32, 0.32), "light")
        for z in (-3.5, 5.5):  # wall-mounted service platforms with rails
            p.box((sx * (WALL_X + 2.1), 6.0, z), (1.2, 0.2, 3.0), "steel")
            p.box((sx * (WALL_X + 2.65), 6.55, z), (0.08, 0.9, 3.0), "trim")
    for x, z in LAMPS:  # build lamps along the slot
        p.box((x, ROOF_Y - 0.85, z), (1.2, 0.5, 1.2), "dark", bevel=0.04)
        p.box((x, ROOF_Y - 1.12, z), (0.9, 0.05, 0.9), "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 23.0, 1.0, 18.5 + sz * 4.6), (0.5, 0.14, 0.5), "light")

    # portal gantry crane: travels along the pier rails, lamps under the beam
    with p.sub("gantry", (0.0, BEAM_Y, GZ), "slide", (0, 0, 1), 5.0):
        for sx in (-1, 1):
            x = sx * PX
            p.box((x, 3.2, GZ), (4.6, 0.9, 3.6), "trim", bevel=0.06)  # bogie
            for dz in (-1.2, 1.2):
                p.cylinder("x", (x, 2.95, GZ + dz), 0.42, 4.2, 12, "dark")
            p.prism_y(rect(x, GZ, 1.4, 1.2), 3.6, BEAM_Y - 0.7, "paint", bevel=0.1, top_scale=0.7)
            p.box((x - sx * 1.02, 8.6, GZ), (0.06, 6.0, 0.3), "light")
            p.obox((x - sx * 2.8, BEAM_Y - 2.2, GZ), (sx * -1.0, 1.0, 0), (0, 0, 1), 3.8, 0.6, 0.5, "trim")  # knee brace
        p.box((0, BEAM_Y, GZ), (PX * 2 + 2.6, 1.5, 2.0), "paint", bevel=0.1)
        p.box((0, BEAM_Y + 0.78, GZ), (30.0, 0.06, 1.5), "team", bevel=0.015)
        hazard(p, (0, BEAM_Y, GZ - 1.02), (1, 0, 0), (0, 0, -1), 34.0, 0.5, stripes=44)
        p.box((-5.0, BEAM_Y + 1.1, GZ + 0.4), (3.4, 1.0, 1.6), "trim", bevel=0.05)  # hoist house
        p.box((-5.0, BEAM_Y + 1.1, GZ - 0.42), (2.6, 0.24, 0.05), "light")
        for x in (-7.0, 7.0):
            p.box((x, BEAM_Y - 0.95, GZ), (1.6, 0.4, 1.2), "dark", bevel=0.04)
            p.box((x, BEAM_Y - 1.17, GZ), (1.2, 0.05, 0.9), "power")


def details_base(p):
    for sx in (-1, 1):
        for z in (-19.0, -12.0):
            seam(p, (sx * PX - 3.6, 2.601, z), (sx * PX + 3.6, 2.601, z), UP)
        rivets(p, (sx * (WALL_X + 1.51), 3.4, -8.6), (sx * (WALL_X + 1.51), 3.4, 12.0), 14, (sx, 0, 0))
        seam(p, (sx * 10.9 - 4.4, ROOF_Y + 0.801, -3.0), (sx * 10.9 + 4.4, ROOF_Y + 0.801, -3.0), UP)
    bolts(p, (-21.0, 0.901, 23.2), (21.0, 0.901, 23.2), 24, UP)
    rivets(p, (-14.0, 1.6, 14.01), (-9.8, 1.6, 14.01), 5, (0, 0, -1))


unit.run(__file__, "ord_advshipyard", "order", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000, tex=2048,
         previews=[("35", (-56, 48, -67), (0, 6.0, 0), 50),
                   ("80", (0, 124, 22), (0, 4, 0), 50),
                   ("close", (-24, 26, -38), (0, 7.0, -4.0), 35),
                   ("back", (52, 44, 62), (0, 6.0, 0), 50)])
