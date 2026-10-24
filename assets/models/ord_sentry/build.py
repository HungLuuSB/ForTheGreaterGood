"""Sentry (Order corvette, T1 ship): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sentry/build.py

A fast armored corvette: the Tidewright's raked hull with a dark waterline
band, a slab bridge with a dark window and lit strip, a mast with a sensor
array and its cyan band, team plates on the foredeck and the bridge roof,
nav lights and gunwale strips; `turret1` (the gun, forward) a wedge-fronted
mount with a long barrel and a muzzle ring (weapon channel), `turret2` a
small aft mount (BAR style, M-15; Order reads heavy, M-14). Model space,
waterline at y = 0. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

T1 = (0.0, 1.3, -2.6)
T2 = (0.0, 1.3, 3.3)
H = ships.Hull(length=11.00, beam=3.74, freeboard=1.30, depth=0.60, sheer_bow=0.50, sheer_stern=0.15, flare=0.2, transom=0.6, rake=1.4, max_at=0.42, fine=2.0, z0=-1.00)  # v2 hull (tools/ships.py)

def build_base(p):
    ships.hull(p, H)
    p.box((0, 1.33, -4.3), (2.8, 0.05, 1.4), "team", bevel=0.012)
    p.prism_y([(-1.35, -0.5), (1.35, -0.5), (1.35, 1.7), (-1.35, 1.7)], 1.3, 2.9, "paint", bevel=0.05, top_scale=0.94)
    p.box((0, 2.5, -0.52), (2.16, 0.3, 0.06), "glass")
    p.box((0, 2.2, -0.53), (2.0, 0.08, 0.04), "light")
    p.box((0, 2.94, 0.6), (1.89, 0.05, 1.32), "team", bevel=0.012)
    # mast with a sensor array
    p.box((0, 3.6, 1.2), (0.9, 1.4, 0.9), "paint", bevel=0.04)
    with p.sub("radar", (0, 4.3, 1.2), "turn", (0, 1, 0)):  # M-27
        p.box((0, 4.3, 1.2), (1.5, 0.9, 1.5), "dark", bevel=0.04)
        p.box((0, 4.3, 1.2), (1.56, 0.2, 1.56), "light")  # sensor band
    p.cylinder("y", (0, 4.95, 1.2), 0.06, 0.5, 6, "steel")
    p.box((0, 5.25, 1.2), (0.16, 0.12, 0.16), "light")
    for sx in (-1, 1):
        p.box((sx * 1.37, 2.4, 0.2), (0.06, 0.16, 0.4), "light")
        if sx > 0:  # running strips along the sheer, both sides
            ships.deck_strip(p, H, H.z0 - 0.36 * H.length, H.z0 + 0.42 * H.length, 0.1)
    p.box((0, 0.7, H.z(0.0) + 0.03), (ships.half_beam_at(H, H.z(0.0)) * 1.3, 0.2, 0.05), "light")


def details_base(p):
    ships.hull_details(p, H)
    seam(p, (-1.8, 1.301, -1.2), (1.8, 1.301, -1.2), UP)
    bolts(p, (-1.6, 1.301, 4.2), (1.6, 1.301, 4.2), 6, UP)


def build_turret1(p):
    p.cylinder("y", (0, 1.4, -2.6), 0.75, 0.2, 12, "trim")
    p.prism_x([(-3.4, 1.4), (-2.0, 1.4), (-1.8, 1.7), (-1.8, 2.1), (-3.0, 2.1), (-3.6, 1.7)], -0.7, 0.7, "paint", bevel=0.04)
    p.cylinder("z", (0, 1.75, -4.6), 0.15, 2.4, 10, "steel")
    p.cylinder("z", (0, 1.75, -5.7), 0.18, 0.3, 10, "dark")
    p.cylinder("z", (0, 1.75, -5.4), 0.17, 0.1, 10, "weapon")
    p.box((0, 2.12, -2.6), (0.9, 0.04, 0.8), "team")


def build_turret2(p):
    p.cylinder("y", (0, 1.4, 3.3), 0.5, 0.2, 10, "trim")
    p.box((0, 1.65, 3.3), (0.9, 0.5, 0.9), "paint", bevel=0.04)
    p.cylinder("z", (0, 1.65, 2.3), 0.1, 1.1, 8, "steel")
    p.cylinder("z", (0, 1.65, 1.75), 0.12, 0.08, 8, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_sentry", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, 1.75, -6.06]},
                      "muzzle2": {"parent": "turret2", "at": [0, 1.65, 1.59]}})
