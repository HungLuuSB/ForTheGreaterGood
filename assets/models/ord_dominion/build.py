"""Dominion (Order cruiser, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_dominion/build.py

New mesh from its blockout, at the T2 capital-ship size (size-scale.md:
29-30 long): a big faceted hull with a flared bow, a dark waterline band
and an armored belt, large team plates fore and aft, a tall stepped block
superstructure with a glass band, two funnels with glowing caps, a solid
mast with the client-turned radar (`radar`, M-27); `turret1` a heavy
triple gun house forward (`muzzle1`), a second triple house aft facing
astern (decoration, on the base), `turret2` a twin flak mount on the aft
superstructure (`muzzle2`). Gunwale strips, nav lights, bollards. Model
space, waterline at y = 0. Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import rect  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

DECK = 2.6
T1 = (0.0, DECK, -8.6)
T2 = (0.0, 5.8, 5.4)
RADAR = (0.0, 10.4, -0.8)


def gun_house(p, z, facing, y=DECK):
    """A heavy triple gun house centred at z, barrels toward `facing` (-1 fore, +1 aft)."""
    f = facing
    p.prism_y([(-1.8, z + f * 1.6), (1.8, z + f * 1.6), (2.2, z + f * 0.6), (2.2, z - f * 1.8), (-2.2, z - f * 1.8),
               (-2.2, z + f * 0.6)], y + 0.1, y + 1.8, "paint", bevel=0.1, top_scale=0.88)
    p.box((0, y + 1.84, z - f * 0.2), (3.0, 0.05, 2.4), "team", bevel=0.015)
    for x in (-0.8, 0.0, 0.8):
        p.cylinder("z", (x, y + 1.0, z + f * 4.2), 0.2, 5.0, 10, "steel")
        p.cylinder("z", (x, y + 1.0, z + f * 6.75), 0.26, 0.3, 10, "dark")
        p.cylinder("z", (x, y + 1.0, z + f * 6.55), 0.25, 0.08, 10, "weapon")


def build_base(p):
    p.prism_x([(-15.4, DECK + 0.4), (-11.4, -1.0), (13.4, -1.0), (14.0, 0.4), (14.0, DECK)], -4.1, 4.1, "paint", bevel=0.14)
    p.prism_x([(-14.8, DECK + 0.4), (-12.4, DECK - 0.6), (-12.4, DECK)], -2.4, 2.4, "paint", bevel=0.06)
    p.prism_x([(-13.4, 0.0), (-11.2, -0.7), (14.05, -0.7), (14.05, 0.0)], -4.17, 4.17, "dark", bevel=0.02)
    for sx in (-1, 1):  # armored belt, gunwale strips
        p.box((sx * 4.15, 1.1, 0.0), (0.12, 0.9, 18.0), "trim", bevel=0.03)
        p.box((sx * 4.22, 1.9, 0.0), (0.05, 0.18, 24.0), "light")
        for z in (-12.6, 12.0):
            p.cylinder("y", (sx * 3.6, DECK + 0.25, z), 0.22, 0.5, 8, "steel")
    p.box((0, DECK + 0.03, -12.6), (4.6, 0.05, 2.4), "team", bevel=0.015)
    p.box((0, DECK + 0.03, 12.4), (5.0, 0.05, 2.4), "team", bevel=0.015)
    # stepped superstructure, glass band, funnels, mast
    p.prism_y(rect(0, 0.6, 3.0, 4.4), DECK, 5.8, "paint", bevel=0.14, top_scale=0.94)
    p.prism_y(rect(0, -0.8, 2.2, 2.0), 5.8, 8.2, "paint", bevel=0.1, top_scale=0.9)
    p.box((0, 7.4, -2.82), (3.6, 0.5, 0.06), "glass")
    p.box((0, 6.95, -2.83), (3.4, 0.1, 0.04), "light")
    for z in (2.2, 4.0):
        p.prism_y(rect(0, z, 0.8, 0.7), 5.8, 7.8, "trim", bevel=0.06, top_scale=0.85)
        p.box((0, 7.82, z), (1.2, 0.06, 1.0), "power")
    p.prism_y(rect(0, -0.8, 0.6, 0.6), 8.2, 9.9, "trim", bevel=0.05, top_scale=0.7)
    p.cylinder("y", (0, 11.0, -0.8), 0.08, 1.4, 6, "steel")
    p.box((0, 11.75, -0.8), (0.2, 0.14, 0.2), "light")
    for sx in (-1, 1):
        p.box((sx * 3.02, 4.4, 0.6), (0.05, 0.16, 8.0), "light")
    p.box((0, 1.3, 14.07), (6.0, 0.26, 0.05), "light")
    gun_house(p, 7.2, 1)  # aft triple, decoration (barrels end inside the stern)
    p.cylinder("y", (0, DECK + 0.05, -8.6), 2.0, 0.1, 20, "dark")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, 10.4, -0.8), (3.0, 0.7, 0.45), "paint", bevel=0.03)
        p.box((0, 10.4, -1.05), (2.8, 0.5, 0.04), "dark")
        p.box((0, 10.4, -1.07), (2.85, 0.06, 0.03), "light")


def details_base(p):
    seam(p, (-4.0, DECK + 0.001, -5.2), (4.0, DECK + 0.001, -5.2), UP)
    seam(p, (-4.0, DECK + 0.001, 6.2), (4.0, DECK + 0.001, 6.2), UP)
    bolts(p, (-3.4, DECK + 0.001, -14.0), (3.4, DECK + 0.001, -14.0), 8, UP)


def build_turret1(p):
    gun_house(p, T1[2], -1)


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 0.9, 0.3, 14, "trim")
    p.box((x, y + 0.75, z + 0.2), (1.4, 0.9, 1.4), "paint", bevel=0.05)
    p.box((x, y + 1.22, z + 0.2), (1.0, 0.04, 1.0), "team")
    for sx in (-1, 1):
        p.cylinder("z", (x + sx * 0.35, y + 0.8, z - 1.2), 0.1, 1.8, 8, "steel")
        p.cylinder("z", (x + sx * 0.35, y + 0.8, z - 2.1), 0.13, 0.08, 8, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_dominion", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 1.0, T1[2] - 6.95]},
                      "muzzle2": {"parent": "turret2", "at": [0, T2[1] + 0.8, T2[2] - 2.2]}},
         budget=10000)
