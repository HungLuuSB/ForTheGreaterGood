"""Sanctuary (Order carrier, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sanctuary/build.py

New mesh from its blockout, at the T2 capital-ship size (size-scale.md:
29-30 long): a broad hull with a dark waterline band under a full flight
deck with chamfered corners, three rearm pads ringed in team color with
landing marks, a centre line and hazard deck edges, edge lights, a tall
island to starboard with a glass band, a lit strip, a team roof, a funnel
and a solid mast with the client-turned radar (`radar`, M-27); `turret1`
and `turret2` twin flak mounts on port sponsons, fore and aft
(`muzzle1`, `muzzle2`). Model space, waterline at y = 0. Order reads heavy
and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, rect  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

DECK = 3.4
T1 = (-4.6, DECK, -10.0)
T2 = (-4.6, DECK, 9.6)
RADAR = (4.2, 11.2, 1.6)
PADS = [(-0.8, -8.0), (-0.8, 0.0), (-0.8, 8.0)]


def flak(p, c):
    x, y, z = c
    p.cylinder("y", (x, y + 0.15, z), 0.8, 0.3, 12, "trim")
    p.box((x, y + 0.7, z + 0.2), (1.2, 0.8, 1.2), "paint", bevel=0.04)
    p.box((x, y + 1.12, z + 0.2), (0.8, 0.04, 0.8), "team")
    for sx in (-1, 1):
        p.cylinder("z", (x + sx * 0.3, y + 0.75, z - 1.1), 0.09, 1.7, 8, "steel")
        p.cylinder("z", (x + sx * 0.3, y + 0.75, z - 1.95), 0.12, 0.08, 8, "weapon")


def build_base(p):
    p.prism_x([(-14.4, DECK - 0.4), (-11.0, -0.9), (13.0, -0.9), (13.6, DECK - 0.4)], -4.0, 4.0, "paint", bevel=0.12)
    p.prism_x([(-12.6, 0.0), (-10.8, -0.6), (13.4, -0.6), (13.4, 0.0)], -4.07, 4.07, "dark", bevel=0.02)
    # flight deck with chamfered corners
    deck = [(-5.2, -15.0), (4.0, -15.0), (5.6, -13.4), (5.6, 14.0), (-5.6, 14.0), (-5.6, -13.4)]
    p.prism_y(deck, DECK - 0.5, DECK, "trim", bevel=0.08)
    p.box((-0.8, DECK + 0.02, 0.0), (0.2, 0.03, 26.0), "paint")  # centre line
    for x, z in PADS:
        p.cylinder("y", (x, DECK + 0.03, z), 2.6, 0.04, 24, "team")
        p.cylinder("y", (x, DECK + 0.05, z), 2.3, 0.04, 24, "dark")
        p.box((x, DECK + 0.08, z), (0.3, 0.03, 2.0), "paint")
        p.box((x, DECK + 0.08, z), (1.4, 0.03, 0.3), "paint")
    for sz in (-1, 1):
        hazard(p, (-0.8, DECK + 0.03, sz * 13.6), (1, 0, 0), UP, 9.0, 0.4, stripes=18)
    for z in range(-12, 14, 4):
        for sx in (-1, 1):
            p.box((sx * 5.62, DECK - 0.15, z), (0.06, 0.16, 0.4), "light")
    # sponsons for the flak mounts (port)
    for z in (T1[2], T2[2]):
        p.box((-4.6, DECK - 0.6, z), (2.2, 0.8, 2.6), "paint", bevel=0.05)
    # island to starboard
    p.prism_y(rect(4.2, 1.6, 1.4, 4.0), DECK, 7.6, "paint", bevel=0.1, top_scale=0.93)
    p.box((2.78, 6.8, 1.6), (0.06, 0.5, 6.4), "glass")
    p.box((2.77, 6.35, 1.6), (0.04, 0.1, 6.2), "light")
    p.box((4.2, 7.63, 0.6), (2.2, 0.05, 3.6), "team", bevel=0.012)
    p.prism_y(rect(4.2, 4.0, 0.8, 0.9), 7.6, 9.2, "trim", bevel=0.06, top_scale=0.85)
    p.box((4.2, 9.22, 4.0), (1.2, 0.06, 1.4), "power")
    p.prism_y(rect(4.2, 1.6, 0.5, 0.5), 7.6, 10.6, "trim", bevel=0.05, top_scale=0.7)
    p.cylinder("y", (4.2, 12.2, 1.6), 0.07, 1.2, 6, "steel")
    p.box((4.2, 12.85, 1.6), (0.2, 0.14, 0.2), "light")
    p.box((0, 1.3, 13.62), (6.0, 0.24, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((4.2, 11.2, 1.6), (3.0, 0.8, 0.4), "paint", bevel=0.03)
        p.box((4.2, 11.2, 1.38), (2.8, 0.6, 0.04), "dark")
        p.box((4.2, 11.2, 1.36), (2.85, 0.06, 0.03), "light")


def details_base(p):
    seam(p, (-5.5, DECK + 0.001, -4.0), (5.5, DECK + 0.001, -4.0), UP)
    seam(p, (-5.5, DECK + 0.001, 4.0), (5.5, DECK + 0.001, 4.0), UP)
    bolts(p, (-5.0, DECK + 0.001, 12.4), (5.0, DECK + 0.001, 12.4), 10, UP)


def build_turret1(p):
    flak(p, T1)


def build_turret2(p):
    flak(p, T2)


def no_details(p):
    pass


unit.run(__file__, "ord_sanctuary", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [T1[0], T1[1] + 0.75, T1[2] - 2.05]},
                      "muzzle2": {"parent": "turret2", "at": [T2[0], T2[1] + 0.75, T2[2] - 2.05]}},
         budget=10000)
