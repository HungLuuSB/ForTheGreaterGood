"""Hover Dock (Order hovercraft factory, T1 structure, footprint 4; batch 1 of
the BAR roster, S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_hoverdock/build.py

It stands on land or water, so it floats: big shapes first, at the size
scale (S-104: footprint 4, 32 x 32 studs, about 10 tall):
- a deck on two long armoured pontoons with team bands, rubber fenders and
  tip lights;
- a covered bay at the back with sloped roof walls, a team roof, roof fans
  and a big lit door facing the pad;
- the build pad mid-deck (octagonal, team ring, hazard edges, `buildpad`),
  exiting at -Z down a slipway ramp into the water;
- three cranes: two jib cranes either side of the pad with glowing heads
  (`nano1`, `nano2`) and a portal gantry over it with a build lamp
  (`nano3`).
Order reads heavy and clean (M-14). The attachments match the blockout's.
Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

DECK = 1.0
PAD = (0.0, DECK + 0.1, -2.2)
PX = 12.0  # pontoon centre x
CRANE_X = 9.6
NANO1 = (-6.82, 7.6, -2.75)
NANO2 = (6.82, 7.6, -2.75)
NANO3 = (0.0, 8.8, 0.22)
BEAM_Y = 9.6


def build_base(p):
    # pontoons
    for sx in (-1, 1):
        x = sx * PX
        p.prism_x([(-13.0, -0.6), (12.6, -0.6), (13.6, 0.2), (13.6, DECK + 0.4), (-13.6, DECK + 0.4), (-15.0, 0.4)],
                  x - 2.6, x + 2.6, "paint", bevel=0.12)
        p.box((x, DECK + 0.44, -6.0), (4.2, 0.06, 6.0), "team", bevel=0.02)
        p.box((x + sx * 2.62, 0.5, -1.0), (0.06, 0.16, 22.0), "light")
        for z in (-10.0, -4.0, 2.0, 8.0):
            drum(p, (x + sx * 2.85, 0.3, z), 0.35, 2.0, "rubber", "rubber", sides=10, axis="z")
        p.box((x, DECK + 0.8, -14.2), (0.7, 0.7, 0.7), "light")  # tip lights
    # the deck between them
    p.prism_y(rect(0, 0, PX - 2.6, 13.0), 0.2, DECK, "trim", bevel=0.08)
    # build pad
    px, py, pz = PAD
    p.prism_y(octagon(5.0, 1.4, px, pz), DECK, py, "paint", bevel=0.05)
    p.prism_y(octagon(4.2, 1.2, px, pz), py, py + 0.02, "team")
    p.prism_y(octagon(3.6, 1.0, px, pz), py + 0.02, py + 0.04, "dark")
    for sx in (-1, 1):
        hazard(p, (px + sx * 5.3, DECK + 0.02, pz), (0, 0, 1), UP, 9.0, 0.5, stripes=12)
    # slipway ramp out the front, down into the water
    p.prism_x([(-13.0, DECK), (-13.0, 0.2), (-17.2, -0.4), (-17.2, -0.2)], -5.0, 5.0, "trim", bevel=0.05)
    hazard(p, (0, DECK - 0.55, -15.1), (1, 0, 0), (0, 0.95, -0.3), 9.6, 0.4, stripes=14)
    # covered bay at the back
    p.prism_x([(5.0, DECK), (13.0, DECK), (13.0, 7.2), (11.6, 8.6), (6.4, 8.6), (5.0, 7.2)], -8.8, 8.8, "paint",
              bevel=0.14)
    p.box((0, 8.64, 9.0), (15.6, 0.06, 4.6), "team", bevel=0.02)
    for sx in (-1, 1):
        p.ocyl((sx * 5.0, 8.6, 10.8), UP, 0.8, 1.2, 14, "trim", radius2=0.66)
        p.cylinder("y", (sx * 5.0, 9.84, 10.8), 0.66, 0.08, 14, "power")
        p.box((sx * 8.83, 4.0, 9.0), (0.06, 0.16, 6.0), "light")
        p.box((sx * 8.83, 5.6, 10.0), (0.06, 1.6, 3.0), "grille")
    p.box((0, DECK + 3.0, 4.94), (13.0, 5.6, 0.1), "dark")  # door
    for i in range(3):
        p.box((0, DECK + 1.2 + i * 1.6, 4.87), (12.4, 0.12, 0.06), "power")
    p.box((0, DECK + 6.0, 4.84), (14.0, 0.3, 0.14), "power")
    hazard(p, (0, DECK + 0.03, 4.4), (1, 0, 0), UP, 13.0, 0.5, stripes=20)
    # jib cranes either side of the pad
    for sx, head in ((-1, NANO1), (1, NANO2)):
        x = sx * CRANE_X
        p.cylinder("y", (x, DECK + 0.3, head[2]), 1.0, 0.6, 12, "trim")
        p.prism_y(rect(x, head[2], 0.5, 0.5), DECK + 0.6, head[1] + 0.9, "paint", bevel=0.06, top_scale=0.8)
        p.box((x - sx * 0.6, head[1] + 0.9, head[2]), (3.2, 0.5, 0.6), "paint", bevel=0.04)  # jib
        p.box((x - sx * 0.6, head[1] + 1.17, head[2]), (2.6, 0.05, 0.4), "team")
        p.box((x + sx * 0.9, head[1] + 0.7, head[2]), (0.9, 0.8, 0.9), "trim", bevel=0.04)  # counterweight
        p.cylinder("y", (head[0], head[1] + 0.45, head[2]), 0.3, 0.5, 10, "trim")
        p.cylinder("y", (head[0], head[1], head[2]), 0.24, 0.3, 10, "power")
    # portal gantry over the pad
    for sx in (-1, 1):
        p.prism_y(rect(sx * 7.6, NANO3[2], 0.45, 0.6), DECK, BEAM_Y - 0.3, "paint", bevel=0.06, top_scale=0.75)
        p.box((sx * 7.6, DECK + 0.3, NANO3[2]), (1.6, 0.6, 2.0), "trim", bevel=0.04)
    p.box((0, BEAM_Y, NANO3[2]), (16.6, 0.9, 1.2), "paint", bevel=0.06)
    p.box((0, BEAM_Y + 0.47, NANO3[2]), (12.0, 0.05, 0.9), "team")
    hazard(p, (0, BEAM_Y, NANO3[2] - 0.62), (1, 0, 0), (0, 0, -1), 14.0, 0.4, stripes=20)
    p.box((0, BEAM_Y - 0.5, NANO3[2]), (1.6, 0.4, 1.4), "trim", bevel=0.03)
    p.box((0, NANO3[1] + 0.05, NANO3[2]), (0.9, 0.1, 0.9), "power")


def details_base(p):
    for sx in (-1, 1):
        for z in (-10.0, -2.0, 6.0):
            seam(p, (sx * PX - 2.4, DECK + 0.401, z), (sx * PX + 2.4, DECK + 0.401, z), UP)
        rivets(p, (sx * 8.83, DECK + 0.6, 6.0), (sx * 8.83, DECK + 0.6, 12.4), 7, (sx, 0, 0))
    bolts(p, (-8.6, DECK + 0.001, -12.4), (8.6, DECK + 0.001, -12.4), 12, UP)


unit.run(__file__, "ord_hoverdock", "order", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         attachments={"buildpad": {"parent": "base", "at": list(PAD)},
                      "nano1": {"parent": "base", "at": list(NANO1)},
                      "nano2": {"parent": "base", "at": list(NANO2)},
                      "nano3": {"parent": "base", "at": list(NANO3)}},
         budget=6000, tex=2048, preview_size=40)
