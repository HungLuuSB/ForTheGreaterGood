"""Fulgur (Order lightning tank with an anti-air missile, T2; batch 1 of the
BAR roster, S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_fulgur/build.py

A storm-caller: the tracked hull, a squat turret, and on its pitching
`barrel` mount (the def's pitch piece) a tall lightning coil: insulator
stack, three glowing rings and a crown sphere (weapon channel), so the coil
leans to aim; a twin-cell anti-air missile box on the turret's right
(`aa_muzzle`); team roof and box panels (BAR style, M-15; Order, M-14).
Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.0
TURRET = (0.0, DECK, 0.4)
BARREL = (-0.2, DECK + 1.05, 0.2)


def build_base(p):
    hulls.tracked(p, "order", length=8.2, width=5.4, deck=DECK)


def details_base(p):
    bolts(p, (-2.2, DECK + 0.001, 3.4), (2.2, DECK + 0.001, 3.4), 7, UP)


def build_turret(p):
    y0, y1 = DECK, DECK + 0.95
    p.prism_y([(-1.4, -1.4), (1.4, -1.4), (1.9, -0.6), (1.9, 1.8), (-1.9, 1.8), (-1.9, -0.6)], y0, y1, "paint",
              bevel=0.06, top_scale=0.9)
    p.box((-0.7, y1 + 0.02, 1.1), (1.2, 0.05, 1.2), "team", bevel=0.012)
    p.cylinder("y", (-0.2, y1 + 0.06, 0.2), 0.8, 0.12, 14, "dark")  # coil seat
    # anti-air box on the right
    p.box((1.85, y1 + 0.2, 0.3), (0.9, 0.9, 2.0), "paint", bevel=0.04)
    p.box((2.31, y1 + 0.2, 0.3), (0.04, 0.6, 1.4), "team")
    for k in (-0.2, 0.2):
        p.cylinder("z", (1.85, y1 + 0.2 + k, -0.72), 0.16, 0.06, 8, "weapon")
    for sx in (-1, 1):
        p.box((sx * 1.91, y0 + 0.45, 0.5), (0.04, 0.12, 1.8), "light")


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y + 0.1, z), (1.1, 0.25, 1.1), "trim", bevel=0.03)  # tilting mount
    p.cylinder("y", (x, y + 1.25, z), 0.32, 2.1, 12, "steel")
    for i in range(3):
        p.cylinder("y", (x, y + 0.7 + i * 0.55, z), 0.6, 0.14, 14, "dark")
        p.cylinder("y", (x, y + 0.82 + i * 0.55, z), 0.52, 0.1, 14, "weapon")
    p.cylinder("y", (x, y + 2.45, z), 0.42, 0.42, 12, "weapon", radius2=0.18)  # crown


def no_details(p):
    pass


unit.run(__file__, "ord_fulgur", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [BARREL[0], BARREL[1] + 2.75, BARREL[2]]},
                      "aa_muzzle": {"parent": "turret", "at": [1.85, DECK + 1.15, -0.8]}})
