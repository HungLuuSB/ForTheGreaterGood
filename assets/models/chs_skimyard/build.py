"""Skim Yard (Chaos hovercraft factory, T1 structure, footprint 4; batch 1 of
the BAR roster, S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_skimyard/build.py

It stands on land or water, so it floats: big shapes first, at the size
scale (S-104: footprint 4, 32 x 32 studs, about 10 tall):
- a patched deck on pontoons of welded drums lashed to girders, spiked
  ram corners, tyre fenders, amber lamps;
- an open bay at the back: a girder frame with a corrugated half-roof and a
  team panel, a forge stack with a hot rim;
- the build pad mid-deck (patched plates, team stripes, hazard edges,
  `buildpad`), exiting at -Z down a plank ramp into the water;
- three cranes: two lattice jibs either side of the pad with glowing hook
  lamps (`nano1`, `nano2`) and a girder gantry over it (`nano3`).
Chaos reads rugged and improvised (M-14). The attachments match the
blockout's. Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, rect, rivets  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.0
PAD = (0.0, DECK + 0.1, -2.2)
PX = 12.0
CRANE_X = 9.6
NANO1 = (-6.82, 7.6, -2.75)
NANO2 = (6.82, 7.6, -2.75)
NANO3 = (0.0, 8.8, 0.22)
BEAM_Y = 9.6


def lattice(p, x, z, y0, y1, half=0.5):
    """A square lattice column: four corner posts and cross braces."""
    for dx in (-half, half):
        for dz in (-half, half):
            p.box((x + dx, (y0 + y1) / 2, z + dz), (0.14, y1 - y0, 0.14), "steel")
    n = int((y1 - y0) / 1.2)
    for i in range(n):
        y = y0 + 0.6 + i * 1.2
        p.box((x, y, z - half), (2 * half, 0.1, 0.1), "steel")
        p.box((x, y, z + half), (2 * half, 0.1, 0.1), "steel")
        p.box((x - half, y + 0.3, z), (0.1, 0.1, 2 * half), "steel")
        p.box((x + half, y + 0.3, z), (0.1, 0.1, 2 * half), "steel")


def build_base(p):
    # pontoons: welded drums along girders
    for sx in (-1, 1):
        x = sx * PX
        for z in (-9.0, 0.0, 9.0):
            drum(p, (x, 0.0, z), 1.3, 8.6, "dark", "trim", sides=12, axis="z")
        p.box((x, DECK + 0.2, -0.5), (3.0, 0.4, 27.0), "trim", bevel=0.05)  # girder deck
        p.box((x + sx * 1.5, DECK - 0.1, -0.5), (0.1, 0.12, 25.0), "light")
        for z in (-12.0, -5.0, 3.0, 10.0):  # tyre fenders
            p.cylinder("x", (x + sx * 1.8, 0.5, z), 0.55, 0.4, 10, "rubber")
        for sz in (-1, 1):  # spiked ram corners
            p.ocyl((x + sx * 1.2, 0.6, sz * 14.0), (sx * 0.5, 0.1, sz), 0.45, 1.6, 6, "steel", radius2=0.04)
    # patched deck
    p.prism_y(rect(0, 0, PX - 1.5, 13.0), 0.2, DECK, "paint", bevel=0.06)
    for (cx, cz, hx, hz) in ((-6.0, 8.0, 2.4, 1.8), (5.0, -9.5, 2.0, 1.4), (-4.0, -10.0, 1.4, 1.2)):
        p.prism_y(rect(cx, cz, hx, hz), DECK, DECK + 0.06, "trim")  # patches
    # build pad
    px, py, pz = PAD
    p.prism_y(rect(px, pz, 4.6, 4.6), DECK, py, "trim", bevel=0.04)
    for k in (-1, 1):
        p.box((px + k * 3.6, py + 0.02, pz), (0.6, 0.04, 8.0), "team")
    for sz in (-1, 1):
        hazard(p, (px, DECK + 0.02, pz + sz * 4.9), (1, 0, 0), UP, 9.2, 0.5, stripes=12)
    # plank ramp into the water
    for i in range(6):
        x = -3.75 + i * 1.5
        p.prism_x([(-13.0, DECK), (-13.0, DECK - 0.25), (-17.0, -0.45), (-17.0, -0.2)], x - 0.65, x + 0.65,
                  "trim" if i % 2 else "paint", bevel=0.03)
    # open bay: girder frame and a corrugated half roof
    for sx in (-1, 1):
        for z in (5.4, 12.4):
            p.box((sx * 8.4, DECK + 3.8, z), (0.5, 7.6, 0.5), "steel")
    for z in (5.4, 12.4):
        p.box((0, DECK + 7.6, z), (17.3, 0.5, 0.5), "steel")
    p.obox((0, DECK + 7.9, 9.6), (1, 0, 0), (0, 1, -0.25), 17.0, 6.4, 0.12, "dark")  # roof
    for i in range(9):
        p.obox((-8.0 + i * 2.0, DECK + 8.0, 9.6), (0, -0.25, -1), (0, 1, -0.25), 6.4, 0.2, 0.1, "steel")
    p.obox((0, DECK + 8.08, 9.0), (1, 0, 0), (0, 1, -0.25), 9.0, 2.6, 0.04, "team")
    p.box((0, DECK + 1.2, 12.4), (16.0, 2.4, 0.3), "trim")  # back wall stub
    p.cylinder("y", (-6.0, DECK + 5.0, 11.0), 0.8, 10.0, 10, "trim")  # forge stack
    p.cylinder("y", (-6.0, DECK + 10.05, 11.0), 0.66, 0.1, 10, "power")
    p.box((4.0, DECK + 0.6, 10.0), (3.0, 1.2, 2.0), "trim", bevel=0.04)  # parts crates
    p.box((4.0, DECK + 1.22, 10.0), (2.6, 0.04, 1.6), "grille")
    # lattice jib cranes
    for sx, head in ((-1, NANO1), (1, NANO2)):
        x = sx * CRANE_X
        lattice(p, x, head[2], DECK, head[1] + 0.8)
        p.box((x - sx * 0.8, head[1] + 0.95, head[2]), (3.4, 0.3, 0.3), "steel")  # jib
        p.box((x + sx * 1.0, head[1] + 0.7, head[2]), (1.0, 0.8, 0.8), "dark")  # counterweight
        p.cylinder("y", (head[0], head[1] + 0.5, head[2]), 0.04, 0.6, 4, "dark")  # hook cable
        p.box((head[0], head[1] + 0.15, head[2]), (0.4, 0.2, 0.4), "trim")
        p.cylinder("y", (head[0], head[1], head[2]), 0.22, 0.12, 8, "power")
    # girder gantry over the pad
    for sx in (-1, 1):
        lattice(p, sx * 7.6, NANO3[2], DECK, BEAM_Y - 0.3, half=0.45)
    p.box((0, BEAM_Y, NANO3[2]), (16.4, 0.6, 0.8), "steel")
    p.box((0, BEAM_Y + 0.31, NANO3[2]), (8.0, 0.04, 0.6), "team")
    p.box((0, BEAM_Y - 0.45, NANO3[2]), (1.4, 0.3, 1.2), "dark")
    p.box((0, NANO3[1] + 0.05, NANO3[2]), (0.8, 0.1, 0.8), "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.0, DECK + 0.2, sz * 12.6), (0.4, 0.4, 0.4), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * PX, DECK + 0.401, -12.0), (sx * PX, DECK + 0.401, 11.0), 14, UP)
    bolts(p, (-8.0, DECK + 0.001, -12.4), (8.0, DECK + 0.001, -12.4), 10, UP)


unit.run(__file__, "chs_skimyard", "chaos", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         attachments={"buildpad": {"parent": "base", "at": list(PAD)},
                      "nano1": {"parent": "base", "at": list(NANO1)},
                      "nano2": {"parent": "base", "at": list(NANO2)},
                      "nano3": {"parent": "base", "at": list(NANO3)}},
         budget=6000, tex=2048, preview_size=40)
