"""Dominion (Order cruiser, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_dominion/build.py

v2, the user's review 2026-10-24 (the hulls read as flat barges): a real hull
from tools/ships.py, bulkier than the destroyers: a fuller beam, a raked bow
with a strong sheer, flared sides with an armored belt, a broad transom, a dark
boot-top. Stacked decks: a long main deckhouse, a second deck, a tall bridge
block with a wraparound glass band and wings, a tower mast with the
client-turned radar (`radar`, M-27), two funnels with glowing caps. `turret1`
the heavy triple gun house raised on a barbette forward (`muzzle1`), a second
triple (decoration) superfiring aft on its own barbette, `turret2` a twin flak
mount on the upper deck behind the bridge (`muzzle2`). Large team plates on the
foredeck, the quarterdeck and the bridge roof; running strips along the sheer.
Model space, waterline at y = 0. Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from mech import rect  # noqa: E402
from ships import barbette, deck_at, deck_strip, half_beam_at  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

H = ships.Hull(length=30.0, beam=8.4, freeboard=2.2, depth=1.8, sheer_bow=1.5, sheer_stern=0.3,
               flare=0.16, transom=0.68, rake=2.0, max_at=0.45, fine=2.6)
T1_Z = -9.0
T1 = (0.0, deck_at(H, T1_Z) + 1.0, T1_Z)
AFT_Z = 8.6
AFT_Y = deck_at(H, AFT_Z) + 1.6
SUP = deck_at(H, 0.0)
T2 = (0.0, SUP + 4.6, 4.4)
RADAR = (0.0, SUP + 10.2, -0.6)


def gun_house(p, z, facing, y):
    """A heavy triple gun house centred at z on top of y, barrels toward `facing` (-1 fore, +1 aft)."""
    f = facing
    p.prism_y([(-1.8, z + f * 1.6), (1.8, z + f * 1.6), (2.2, z + f * 0.6), (2.2, z - f * 1.8), (-2.2, z - f * 1.8),
               (-2.2, z + f * 0.6)], y, y + 1.7, "paint", bevel=0.1, top_scale=0.88)
    p.box((0, y + 1.74, z - f * 0.2), (3.0, 0.05, 2.4), "team", bevel=0.015)
    p.box((f * 0.0 + 1.6, y + 1.3, z + f * 1.0), (0.4, 0.3, 0.06), "light")
    for x in (-0.8, 0.0, 0.8):
        p.cylinder("z", (x, y + 0.9, z + f * 4.2), 0.2, 5.0, 10, "steel")
        p.cylinder("z", (x, y + 0.9, z + f * 2.0), 0.3, 0.6, 10, "trim")
        p.cylinder("z", (x, y + 0.9, z + f * 6.75), 0.26, 0.3, 10, "dark")
        p.cylinder("z", (x, y + 0.9, z + f * 6.55), 0.25, 0.08, 10, "weapon")


def build_base(p):
    ships.hull(p, H)
    for sx in (-1, 1):  # armored belt on the topsides, amidships
        for z0 in range(-8, 8, 2):
            z = z0 + 1.0
            b = half_beam_at(H, z)
            p.obox((sx * (b * 0.93 + 0.08), 1.0, z), (0, 0, 1), (sx, 0.1, 0), 2.0, 0.9, 0.12, "trim", bevel=0.02)
    for z in (-12.6, 12.2):
        p.obox((0, deck_at(H, z) + 0.04, z), (1, 0, 0), (0, 1, 0.05 if z < 0 else -0.02), 4.0, 2.2, 0.05, "team", bevel=0.015)
    barbette(p, (0, T1_Z), H, T1[1], 2.1)
    barbette(p, (0, AFT_Z), H, AFT_Y, 2.1)
    gun_house(p, AFT_Z, 1, AFT_Y)  # aft triple, superfiring decoration
    # stacked decks: main deckhouse, second deck, bridge block
    p.prism_y(rect(0, 0.4, 3.2, 5.2), SUP - 0.2, SUP + 2.2, "paint", bevel=0.14, top_scale=0.96)
    p.prism_y(rect(0, 0.6, 2.7, 4.0), SUP + 2.2, SUP + 4.2, "paint", bevel=0.12, top_scale=0.94)
    p.prism_y(rect(0, -1.6, 2.1, 1.8), SUP + 4.2, SUP + 6.4, "paint", bevel=0.1, top_scale=0.9)
    p.prism_x([(-3.4, SUP + 6.4), (-2.9, SUP + 7.4), (0.2, SUP + 7.4), (0.2, SUP + 6.4)], -1.9, 1.9, "paint", bevel=0.08)
    p.box((0, SUP + 6.9, -3.28), (3.4, 0.5, 0.06), "glass")
    for sx in (-1, 1):
        p.box((sx * 1.92, SUP + 6.9, -1.6), (0.06, 0.5, 3.0), "glass")
        p.box((sx * 2.8, SUP + 6.3, -2.8), (1.4, 0.18, 1.0), "paint", bevel=0.03)  # bridge wings
        p.box((sx * 3.22, SUP + 1.2, 0.4), (0.05, 0.16, 8.6), "light")
        p.box((sx * 2.72, SUP + 3.2, 0.6), (0.05, 0.14, 6.4), "light")
    p.box((0, SUP + 7.44, -1.4), (3.0, 0.05, 2.6), "team", bevel=0.012)
    p.box((0, SUP + 6.0, -3.42), (3.6, 0.08, 0.04), "light")
    # tower mast and two funnels
    p.prism_y(rect(0, -0.6, 0.8, 0.8), SUP + 6.4, SUP + 9.6, "trim", bevel=0.05, top_scale=0.6)
    p.box((0, SUP + 8.6, -0.6), (3.2, 0.14, 0.14), "steel")
    p.cylinder("y", (0, SUP + 11.4, -0.6), 0.08, 1.6, 6, "steel")
    p.box((0, SUP + 12.25, -0.6), (0.2, 0.14, 0.2), "light")
    for z in (1.2, 2.8):
        p.prism_y(rect(0, z, 0.8, 0.7), SUP + 4.2, SUP + 6.6, "trim", bevel=0.06, top_scale=0.85, top_center=(0, z + 0.3))
        p.box((0, SUP + 6.62, z + 0.3), (1.2, 0.06, 1.0), "power")
    deck_strip(p, H, -12.6, 13.0, 0.14)
    for z in (-12.6, 11.6):
        for sx in (-1, 1):
            p.cylinder("y", (sx * (half_beam_at(H, z) - 0.5), deck_at(H, z) + 0.25, z), 0.22, 0.5, 8, "steel")
    p.box((0, 1.3, H.z(0.0) + 0.03), (half_beam_at(H, H.z(0.0)) * 1.4, 0.26, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, RADAR[1], -0.6), (3.2, 0.8, 0.45), "paint", bevel=0.03)
        p.box((0, RADAR[1], -0.85), (3.0, 0.6, 0.04), "dark")
        p.box((0, RADAR[1], -0.87), (3.05, 0.06, 0.03), "light")


def details_base(p):
    ships.hull_details(p, H)
    seam(p, (-3.0, SUP + 2.201, -3.0), (3.0, SUP + 2.201, -3.0), UP)
    bolts(p, (-3.2, deck_at(H, -14.0) + 0.001, -14.0), (3.2, deck_at(H, -14.0) + 0.001, -14.0), 8, UP)


def build_turret1(p):
    gun_house(p, T1[2], -1, T1[1])


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
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 0.9, T1[2] - 6.95]},
                      "muzzle2": {"parent": "turret2", "at": [0, T2[1] + 0.8, T2[2] - 2.2]}},
         budget=10000,
         previews=[("35", (-28, 22, -32), (0, 3.5, 0), 45),
                   ("close", (-15, 13, -17), (0, 4.5, -2.0), 40)])
