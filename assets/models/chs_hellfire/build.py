"""Hellfire (Chaos heavy missile tank, T2; batch 1 of the BAR roster, S-230):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_hellfire/build.py

A heavy angular hull with slat cages over the tracks and a spiked ram, a
low turret ring carrying a big armoured missile box: six tubes in two rows
under an armoured brow (weapon channel caps), slatted heat vents on
its flanks, a sensor mast; amber slits and a team stripe across the box
(BAR style, M-15; Chaos reads raw and spiky, M-14). The def has no pitch
piece, so the box is fixed on the turret. Our own design.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.0
TURRET = (0.0, DECK, 0.6)
BOX_Y = DECK + 1.55
BOX_FRONT = -1.25


def build_base(p):
    d = hulls.tracked(p, "chaos", length=8.6, width=5.6, deck=DECK, wheels=7)
    # spiked ram under the glacis
    p.prism_x([(-4.35, 0.5), (-4.85, 0.85), (-4.6, 1.6), (-4.2, 1.5)], -2.2, 2.2, "steel", bevel=0.04)
    for x in (-1.5, 0.0, 1.5):
        p.ocyl((x, 1.0, -4.8), (0, 0, -1), 0.22, 0.6, 6, "steel", radius2=0.02)
    for sx in (-1, 1):
        for i in range(7):  # slat cages over the tracks
            p.box((sx * 2.85, d - 0.35, -3.3 + i * 1.1), (0.08, 0.7, 0.1), "steel")
        p.box((sx * 2.85, d - 0.02, 0.0), (0.12, 0.1, 7.0), "dark")
        p.box((sx * 1.9, d + 0.12, 3.3), (1.1, 0.25, 1.4), "grille")  # exhausts
    p.box((0, d + 0.02, -2.6), (2.4, 0.05, 0.9), "team", bevel=0.01)


def details_base(p):
    bolts(p, (-2.2, DECK + 0.001, -3.4), (2.2, DECK + 0.001, -3.4), 7, UP)


def build_turret(p):
    y0 = DECK
    p.cylinder("y", (0, y0 + 0.25, 0.6), 1.5, 0.5, 14, "dark")  # turret ring
    # the missile box: a chamfered armoured block with a flat face
    p.prism_x([(BOX_FRONT, BOX_Y - 0.85), (BOX_FRONT, BOX_Y + 0.85), (2.1, BOX_Y + 0.95), (2.4, BOX_Y - 0.85)],
              -2.0, 2.0, "paint", bevel=0.07)
    p.box((0, BOX_Y + 0.93, 0.5), (3.4, 0.05, 0.5), "team", bevel=0.01)
    for r, y in enumerate((BOX_Y + 0.38, BOX_Y - 0.38)):
        for i in range(3):
            x = -1.2 + i * 1.2
            p.cylinder("z", (x, y, BOX_FRONT - 0.03), 0.33, 0.1, 10, "dark")
            p.cylinder("z", (x, y, BOX_FRONT - 0.06), 0.24, 0.04, 10, "weapon")
    # armoured brow over the tubes
    p.prism_x([(BOX_FRONT + 0.1, BOX_Y + 0.7), (BOX_FRONT - 0.45, BOX_Y + 0.82), (BOX_FRONT - 0.45, BOX_Y + 1.0),
               (BOX_FRONT + 0.1, BOX_Y + 1.05)], -2.05, 2.05, "trim", bevel=0.02)
    for sx in (-1, 1):
        for j in range(4):  # heat vents
            p.box((sx * 2.03, BOX_Y - 0.4 + j * 0.25, 0.8), (0.06, 0.08, 2.2), "steel")
        p.box((sx * 2.05, BOX_Y + 0.65, -0.4), (0.04, 0.1, 1.2), "light")
        p.ocyl((sx * 1.7, BOX_Y + 0.95, 2.1), (sx * 0.3, 1, 0.4), 0.12, 0.7, 5, "steel", radius2=0.01)  # spikes
    # sensor mast
    p.cylinder("y", (-1.5, BOX_Y + 1.35, 1.6), 0.08, 0.8, 6, "steel")
    p.box((-1.5, BOX_Y + 1.8, 1.6), (0.5, 0.22, 0.2), "dark")
    p.box((-1.5, BOX_Y + 1.8, 1.49), (0.36, 0.08, 0.04), "light")


def no_details(p):
    pass


unit.run(__file__, "chs_hellfire", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, BOX_Y, BOX_FRONT - 0.15]}})
