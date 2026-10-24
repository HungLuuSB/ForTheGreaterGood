"""Leviathan (Chaos carrier, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_leviathan/build.py

v2, the user's review 2026-10-24: the offset flat flight deck stays, over a
proper hull from tools/ships.py (a flared raked bow, a tapered stern, a dark
boot-top) and a hangar deck. Chaos reads rugged and improvised (M-14): the deck
overhangs to starboard on welded braces, patched plates, three rearm pads in
team rings, hazard ends, amber edge lights. A taller island to port: a stepped
deckhouse with reactive slabs, a raised bridge with an amber slit and a team
roof, a raked funnel with a hot band and a braced lattice mast carrying the
client-turned radar (`radar`, M-27). Quad flak mounts `turret1` / `turret2` on
port sponsons (`muzzle1`, `muzzle2`). Model space, waterline at y = 0. Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import ships  # noqa: E402
import unit  # noqa: E402
from mech import hazard, rect  # noqa: E402
from ships import deck_at, half_beam_at  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

V = lib.vec
H = ships.Hull(length=28.6, beam=7.0, freeboard=1.7, depth=1.6, sheer_bow=1.5, sheer_stern=0.2,
               flare=0.24, transom=0.7, rake=2.6, max_at=0.44, fine=2.2)
DECK = 4.0
T1 = (-4.4, DECK - 1.4, -10.2)
T2 = (-4.4, DECK - 1.4, 9.8)
RADAR = (-3.8, DECK + 9.4, 1.0)
PADS = [(1.6, -7.6), (1.6, 0.4), (1.6, 8.4)]


def flak(p, c):
    x, y, z = c
    p.cylinder("y", (x, y + 0.15, z), 0.9, 0.3, 12, "trim")
    p.box((x, y + 0.65, z + 0.3), (1.4, 0.7, 1.1), "paint", bevel=0.04)
    p.box((x, y + 1.02, z + 0.3), (1.0, 0.04, 0.7), "team")
    for xx in (-0.45, -0.15, 0.15, 0.45):
        p.cylinder("z", (x + xx, y + 0.7, z - 0.9), 0.08, 1.6, 8, "steel")
        p.cylinder("z", (x + xx, y + 0.7, z - 1.7), 0.11, 0.08, 8, "weapon")


def build_base(p):
    ships.hull(p, H)
    hangar = [(-3.0, -10.6), (3.0, -10.6), (3.2, -7.6), (3.2, 12.4), (-3.2, 12.4), (-3.2, -7.6)]
    p.prism_y(hangar, deck_at(H, 0.0) - 0.3, DECK - 0.5, "paint", bevel=0.06)
    p.box((3.22, DECK - 1.5, 1.0), (0.06, 1.0, 7.0), "dark")
    # offset flight deck on braces, overhanging to starboard
    p.box((1.6, DECK - 0.25, 0.0), (7.6, 0.5, 28.4), "trim", bevel=0.06)
    for z in (-10.0, -3.0, 4.0, 11.0):
        a, b = V((half_beam_at(H, z) * 0.9, deck_at(H, z) - 0.4, z)), V((5.2, DECK - 0.5, z))
        p.obox(tuple((a + b) / 2), tuple(b - a), (0, 0, 1), (b - a).length, 0.4, 0.4, "steel")
    for x, z, w, d in ((3.2, -3.0, 2.0, 3.6), (0.0, 11.0, 2.4, 2.0)):
        p.box((x, DECK + 0.02, z), (w, 0.04, d), "steel", bevel=0.01)  # patches
    for x, z in PADS:
        p.cylinder("y", (x, DECK + 0.03, z), 2.5, 0.04, 22, "team")
        p.cylinder("y", (x, DECK + 0.05, z), 2.2, 0.04, 22, "rubber")
        p.box((x, DECK + 0.08, z), (0.3, 0.03, 2.0), "trim")
        p.box((x, DECK + 0.08, z), (1.4, 0.03, 0.3), "trim")
    for sz in (-1, 1):
        hazard(p, (1.6, DECK + 0.03, sz * 13.8), (1, 0, 0), UP, 7.0, 0.4, stripes=14)
    for z in range(-12, 14, 4):
        p.box((5.42, DECK - 0.2, z), (0.06, 0.2, 0.4), "light")
    for z in (T1[2], T2[2]):  # port sponsons
        p.box((-4.4, T1[1] - 0.4, z), (2.2, 0.8, 2.4), "paint", bevel=0.05)
    # a taller island to port: stepped deckhouse, raised bridge, funnel, lattice mast
    p.prism_y(rect(-3.8, -1.4, 1.3, 3.2), DECK, DECK + 2.6, "paint", bevel=0.06, top_scale=0.95)
    for z in (-3.4, -0.6):
        p.box((-5.12, DECK + 1.3, z), (0.3, 1.4, 2.0), "era", bevel=0.03)
    p.prism_y(rect(-3.8, -1.8, 1.1, 1.8), DECK + 2.6, DECK + 4.6, "paint", bevel=0.06, top_scale=0.92)
    p.box((-2.68, DECK + 4.0, -1.8), (0.05, 0.3, 3.0), "light")  # amber slit
    p.box((-3.8, DECK + 4.64, -1.8), (1.8, 0.05, 3.0), "team", bevel=0.012)
    p.prism_y(rect(-3.8, -3.8, 0.7, 0.7), DECK + 2.6, DECK + 5.8, "trim", bevel=0.05, top_scale=0.85, top_center=(-3.8, -3.3))
    p.box((-3.8, DECK + 5.4, -3.4), (1.2, 0.2, 1.2), "light")
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            p.box((-3.8 + dx, DECK + 5.6, 1.0 + dz), (0.14, 7.0, 0.14), "paint")
    for y in (DECK + 3.4, DECK + 5.8, DECK + 8.2):
        p.box((-3.8, y, 1.0), (1.1, 0.1, 1.1), "steel")
    p.box((-3.8, DECK + 9.0, 1.0), (1.2, 0.2, 1.2), "trim")
    p.box((0, 1.1, H.z(0.0) + 0.03), (half_beam_at(H, H.z(0.0)) * 1.4, 0.24, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((-3.8, RADAR[1] + 0.2, 1.0), (3.2, 0.8, 0.3), "paint", bevel=0.03)
        p.box((-3.8, RADAR[1] + 0.2, 0.84), (3.0, 0.6, 0.04), "dark")
        p.box((-3.8, RADAR[1] + 0.2, 0.82), (3.05, 0.06, 0.03), "light")
        p.box((-3.8, RADAR[1] + 0.62, 1.0), (2.4, 0.04, 0.2), "team")


def details_base(p):
    ships.hull_details(p, H)
    bolts(p, (-1.6, DECK + 0.001, -12.6), (4.8, DECK + 0.001, -12.6), 9, UP)
    ring(p, (-3.8, DECK + 5.801, -3.3), UP, 0.45)


def build_turret1(p):
    flak(p, T1)


def build_turret2(p):
    flak(p, T2)


def no_details(p):
    pass


unit.run(__file__, "chs_leviathan", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [T1[0], T1[1] + 0.7, T1[2] - 1.8]},
                      "muzzle2": {"parent": "turret2", "at": [T2[0], T2[1] + 0.7, T2[2] - 1.8]}},
         budget=10000,
         previews=[("35", (-28, 24, -32), (0, 4.0, 0), 45),
                   ("close", (-15, 15, -17), (0, 5.0, -2.0), 40)])
