"""Thunderer (Order experimental lightning and EMP tank, T3; batch 1 of the BAR
roster, S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_thunderer/build.py

A rolling storm: a very wide, long tracked hull on broad tracks with
generator banks along the deck, a big stepped turret, and on its pitching
cross-yoke (`barrel`, the def's pitch piece) twin lightning coils with
glowing rings and crown spheres (`muzzle`, `muzzle2`, weapon channel)
joined by an arc bar; an EMP dish raked up at the turret's back
(`emp_muzzle`); team roof, cheeks and skirts (BAR style, M-15; Order reads
heavy, M-14). Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import math  # noqa: E402

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.6
TURRET = (0.0, DECK, 0.6)
BARREL = (0.0, DECK + 2.25, 0.0)
COIL_X = 2.1
COIL_TOP = BARREL[1] + 3.7
DISH = (0.0, DECK + 2.15, 3.0)
DISH_N = (0.0, math.cos(math.radians(35)), -math.sin(math.radians(35)))


def build_base(p):
    d = hulls.tracked(p, "order", length=13.4, width=10.0, deck=DECK, track_w=2.0, wheels=9)
    for sx in (-1, 1):
        for i in range(3):  # generator banks along the deck
            z = -3.6 + i * 1.3
            p.box((sx * 3.6, d + 0.3, z), (1.6, 0.6, 1.0), "trim", bevel=0.04)
            p.box((sx * 3.6, d + 0.62, z), (1.3, 0.04, 0.12), "light")
        p.box((sx * 3.6, d + 0.25, 4.2), (1.7, 0.5, 2.0), "grille")  # radiators
        p.box((sx * 2.8, d + 0.02, -5.0), (1.6, 0.05, 1.4), "team", bevel=0.01)
    p.box((0, d + 0.4, 5.6), (3.4, 0.8, 0.8), "trim", bevel=0.04)  # stern power block
    p.box((0, d + 0.4, 6.01), (2.8, 0.4, 0.04), "light")


def details_base(p):
    bolts(p, (-4.0, DECK + 0.001, -6.0), (4.0, DECK + 0.001, -6.0), 11, UP)
    bolts(p, (-4.0, DECK + 0.001, 5.0), (4.0, DECK + 0.001, 5.0), 11, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 1.6
    p.prism_y([(-2.2, -3.0), (2.2, -3.0), (3.4, -1.6), (3.4, 3.2), (2.6, 4.0), (-2.6, 4.0), (-3.4, 3.2), (-3.4, -1.6)],
              y0, y1, "paint", bevel=0.08, top_scale=0.9)
    p.prism_y([(-1.8, -1.8), (1.8, -1.8), (2.6, -0.8), (2.6, 1.8), (-2.6, 1.8), (-2.6, -0.8)], y1, y1 + 0.5, "paint",
              bevel=0.05, top_scale=0.9)  # upper step under the yoke
    p.box((0, y1 + 0.52, 0.0), (3.4, 0.05, 2.6), "team", bevel=0.012)
    for sx in (-1, 1):
        # cheek plates flush on the front facets
        p.obox((sx * 2.8, y0 + 0.8, -2.3), (sx * 0.76, 0, 0.65), (sx * 0.65, 0, -0.76), 1.4, 1.1, 0.06, "team")
        p.box((sx * 3.42, y0 + 0.8, 0.8), (0.04, 0.14, 3.6), "light")
        for j in range(3):  # capacitor cans either side of the dish
            p.cylinder("y", (sx * 2.2, y1 + 0.45, 2.4 + j * 0.55), 0.24, 0.9, 10, "trim")
            p.cylinder("y", (sx * 2.2, y1 + 0.92, 2.4 + j * 0.55), 0.25, 0.08, 10, "light")
    # EMP dish, raked up and forward
    bx, by, bz = DISH
    p.cylinder("y", (bx, y1 + 0.2, bz), 0.5, 0.4, 12, "dark")
    p.ocyl((bx, by - 0.2, bz), DISH_N, 0.35, 0.45, 18, "trim", radius2=1.35)
    p.ocyl((bx + DISH_N[0] * 0.44, by - 0.2 + DISH_N[1] * 0.44, bz + DISH_N[2] * 0.44), DISH_N, 1.2, 0.03, 18,
           "weapon")
    p.ocyl((bx, by - 0.2, bz), DISH_N, 0.1, 1.0, 6, "steel")  # feed horn
    p.ocyl((bx + DISH_N[0], by - 0.2 + DISH_N[1], bz + DISH_N[2]), DISH_N, 0.18, 0.12, 8, "weapon")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y + 0.15, z), (5.2, 0.4, 1.4), "trim", bevel=0.05)  # cross-yoke
    p.cylinder("x", (x, y, z), 0.42, 1.6, 12, "dark")  # trunnion
    for sx in (-1, 1):
        cx = x + sx * COIL_X
        p.cylinder("y", (cx, y + 0.55, z), 0.7, 0.4, 14, "paint")  # coil base
        p.cylinder("y", (cx, y + 2.1, z), 0.4, 2.8, 12, "steel")
        for i in range(4):
            p.cylinder("y", (cx, y + 1.05 + i * 0.6, z), 0.78, 0.14, 16, "dark")
            p.cylinder("y", (cx, y + 1.18 + i * 0.6, z), 0.68, 0.1, 16, "weapon")
        p.cylinder("y", (cx, y + 3.65, z), 0.62, 0.7, 14, "weapon", radius2=0.3)  # crown
    p.box((x, y + 3.0, z), (2 * COIL_X - 0.8, 0.12, 0.12), "weapon")  # arc bar


def no_details(p):
    pass


unit.run(__file__, "ord_thunderer", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [-COIL_X, COIL_TOP + 0.1, BARREL[2]]},
                      "muzzle2": {"parent": "barrel", "at": [COIL_X, COIL_TOP + 0.1, BARREL[2]]},
                      "emp_muzzle": {"parent": "turret",
                                     "at": [DISH[0] + DISH_N[0] * 1.1, DISH[1] - 0.2 + DISH_N[1] * 1.1,
                                            DISH[2] + DISH_N[2] * 1.1]}},
         budget=7000, preview_size=18)
