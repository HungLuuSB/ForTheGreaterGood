"""Sanctuary (Order carrier, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sanctuary/build.py

v2, the user's review 2026-10-24: the flat flight deck stays, over a proper
hull from tools/ships.py (a flared raked bow rising under the deck's front, a
tapered stern, a dark boot-top), with a hangar deck between them. The flight
deck has chamfered corners, three rearm pads in team rings, a centre line,
hazard ends and edge lights. A taller island to starboard: three stepped
levels, a wraparound glass band and lit strip on the bridge, a funnel with a
glowing cap and a tower mast carrying the client-turned radar (`radar`,
M-27). Flak mounts `turret1` / `turret2` on port sponsons (`muzzle1`,
`muzzle2`). Model space, waterline at y = 0. Order reads heavy and clean
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from mech import hazard, rect  # noqa: E402
from ships import deck_at, half_beam_at  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

H = ships.Hull(length=29.0, beam=7.6, freeboard=1.8, depth=1.7, sheer_bow=1.3, sheer_stern=0.2,
               flare=0.25, transom=0.72, rake=2.4, max_at=0.45, fine=2.4)
DECK = 4.2  # the flight deck
T1 = (-5.0, DECK - 0.7, -9.6)
T2 = (-5.0, DECK - 0.7, 9.4)
RADAR = (4.4, DECK + 9.2, 1.6)
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
    ships.hull(p, H)
    # hangar deck between the hull and the flight deck, a little inset
    hangar = [(-3.4, -11.0), (3.4, -11.0), (3.6, -8.0), (3.6, 12.6), (-3.6, 12.6), (-3.6, -8.0)]
    p.prism_y(hangar, deck_at(H, 0.0) - 0.3, DECK - 0.5, "paint", bevel=0.08)
    for sx in (-1, 1):
        p.box((sx * 3.62, DECK - 1.6, 1.0), (0.06, 1.2, 8.0), "dark")  # hangar openings
        p.box((sx * 3.63, DECK - 1.0, 1.0), (0.05, 0.12, 8.0), "light")
    # flight deck with chamfered corners
    deck = [(-5.4, -15.6), (4.2, -15.6), (5.8, -13.8), (5.8, 14.2), (-5.8, 14.2), (-5.8, -13.8)]
    p.prism_y(deck, DECK - 0.5, DECK, "trim", bevel=0.08)
    p.box((-0.8, DECK + 0.02, 0.0), (0.2, 0.03, 26.0), "paint")  # centre line
    for x, z in PADS:
        p.cylinder("y", (x, DECK + 0.03, z), 2.6, 0.04, 24, "team")
        p.cylinder("y", (x, DECK + 0.05, z), 2.3, 0.04, 24, "dark")
        p.box((x, DECK + 0.08, z), (0.3, 0.03, 2.0), "paint")
        p.box((x, DECK + 0.08, z), (1.4, 0.03, 0.3), "paint")
    for sz in (-1, 1):
        hazard(p, (-0.8, DECK + 0.03, sz * 13.8), (1, 0, 0), UP, 9.0, 0.4, stripes=18)
    for z in range(-12, 14, 4):
        for sx in (-1, 1):
            p.box((sx * 5.82, DECK - 0.15, z), (0.06, 0.16, 0.4), "light")
    for z in (T1[2], T2[2]):  # port sponsons for the flak mounts
        p.box((-5.0, T1[1] - 0.4, z), (2.2, 0.8, 2.6), "paint", bevel=0.05)
        p.obox((-4.4, T1[1] - 1.4, z), (0, 0, 1), (-0.7, -0.7, 0), 2.4, 1.6, 0.3, "paint")
    # the island: three stepped levels, bridge glass, funnel, tower mast
    p.prism_y(rect(4.4, 1.6, 1.4, 4.2), DECK, DECK + 3.4, "paint", bevel=0.1, top_scale=0.95)
    p.prism_y(rect(4.4, 1.2, 1.2, 3.2), DECK + 3.4, DECK + 5.8, "paint", bevel=0.1, top_scale=0.93)
    p.prism_y(rect(4.4, 0.4, 1.0, 1.8), DECK + 5.8, DECK + 7.4, "paint", bevel=0.08, top_scale=0.9)
    p.box((3.18, DECK + 6.7, 0.4), (0.06, 0.5, 3.2), "glass")
    p.box((4.4, DECK + 6.7, -1.42), (1.8, 0.5, 0.06), "glass")
    p.box((3.17, DECK + 6.25, 0.4), (0.04, 0.1, 3.0), "light")
    p.box((2.98, DECK + 1.8, 1.6), (0.04, 0.12, 7.6), "light")
    p.box((4.4, DECK + 7.44, 0.4), (1.6, 0.05, 2.8), "team", bevel=0.012)
    p.prism_y(rect(4.4, 4.0, 0.8, 0.9), DECK + 5.8, DECK + 7.8, "trim", bevel=0.06, top_scale=0.85)
    p.box((4.4, DECK + 7.82, 4.0), (1.2, 0.06, 1.4), "power")
    p.prism_y(rect(4.4, 1.6, 0.5, 0.5), DECK + 7.4, DECK + 8.8, "trim", bevel=0.05, top_scale=0.7)
    p.cylinder("y", (4.4, DECK + 10.4, 1.6), 0.07, 1.2, 6, "steel")
    p.box((4.4, DECK + 11.05, 1.6), (0.2, 0.14, 0.2), "light")
    p.box((0, 1.3, H.z(0.0) + 0.03), (half_beam_at(H, H.z(0.0)) * 1.4, 0.24, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((4.4, RADAR[1], 1.6), (3.0, 0.8, 0.4), "paint", bevel=0.03)
        p.box((4.4, RADAR[1], 1.38), (2.8, 0.6, 0.04), "dark")
        p.box((4.4, RADAR[1], 1.36), (2.85, 0.06, 0.03), "light")


def details_base(p):
    ships.hull_details(p, H)
    seam(p, (-5.7, DECK + 0.001, -4.0), (5.7, DECK + 0.001, -4.0), UP)
    seam(p, (-5.7, DECK + 0.001, 4.0), (5.7, DECK + 0.001, 4.0), UP)
    bolts(p, (-5.2, DECK + 0.001, 12.6), (5.2, DECK + 0.001, 12.6), 10, UP)


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
         budget=10000,
         previews=[("35", (-28, 24, -32), (0, 4.0, 0), 45),
                   ("close", (-15, 15, -17), (0, 5.0, -2.0), 40)])
