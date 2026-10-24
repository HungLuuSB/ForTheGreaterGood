"""Kraken (Chaos cruiser, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_kraken/build.py

v2, the user's review 2026-10-24 (the hulls read as flat barges): a real hull
from tools/ships.py, bulkier than the Corsair: a fuller beam, a hard raked bow
with a high sheer, flared sides, a broad transom, a dark boot-top. Chaos reads
rugged and improvised (M-14): welded deck patches, hazard striping, tyre
fenders, reactive slabs on the deckhouse. Stacked decks: a long deckhouse, an
upper deck, a raised bridge with an amber slit and a team roof, two raked
funnels with hot bands, a tall braced lattice mast with the client-turned
radar (`radar`, M-27). `turret1` a heavy triple mount with a slab shield
raised on a barbette forward (`muzzle1`), `turret2` a quad flak mount on a
raised platform aft (`muzzle2`). Model space, waterline at y = 0. Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, rect  # noqa: E402
from ships import barbette, deck_at, deck_strip, half_beam_at  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

H = ships.Hull(length=29.6, beam=7.6, freeboard=2.0, depth=1.7, sheer_bow=1.8, sheer_stern=0.25,
               flare=0.2, transom=0.64, rake=2.6, max_at=0.44, fine=2.3)
T1_Z = -9.2
T1 = (0.0, deck_at(H, T1_Z) + 0.9, T1_Z)
T2_Z = 9.4
T2 = (0.0, deck_at(H, T2_Z) + 1.0, T2_Z)
SUP = deck_at(H, -1.0)
RADAR = (0.0, SUP + 9.4, 0.6)


def build_base(p):
    ships.hull(p, H)
    for x, z, w, d in ((2.0, -5.4, 1.4, 3.0), (-1.8, 6.0, 1.6, 2.4)):
        p.box((x, deck_at(H, z) + 0.03, z), (w, 0.04, d), "steel", bevel=0.01)
    p.obox((0, deck_at(H, -12.6) + 0.04, -12.6), (1, 0, 0), (0, 1, 0.1), 3.4, 2.2, 0.05, "team", bevel=0.012)
    hazard(p, (0, deck_at(H, -6.4) + 0.04, -6.4), (1, 0, 0), UP, 5.4, 0.4, stripes=12)
    barbette(p, (0, T1_Z), H, T1[1], 2.0)
    barbette(p, (0, T2_Z), H, T2[1], 1.3)
    # stacked decks: deckhouse with reactive slabs, upper deck, raised bridge
    p.prism_y(rect(0, -0.8, 2.8, 4.6), SUP - 0.2, SUP + 2.0, "paint", bevel=0.08, top_scale=0.96)
    for sx in (-1, 1):
        for z in (-3.6, -1.0, 1.6):
            p.box((sx * 2.86, SUP + 1.0, z), (0.3, 1.2, 1.8), "era", bevel=0.03)
        p.box((sx * 2.84, SUP + 1.9, -0.8), (0.05, 0.14, 8.0), "light")
    p.prism_y(rect(0, -0.6, 2.2, 3.4), SUP + 2.0, SUP + 3.8, "paint", bevel=0.08, top_scale=0.94)
    p.prism_y(rect(0, -2.2, 1.7, 1.4), SUP + 3.8, SUP + 5.6, "paint", bevel=0.08, top_scale=0.9)
    p.box((0, SUP + 5.0, -3.62), (2.8, 0.34, 0.05), "light")  # amber slit
    p.box((0, SUP + 5.64, -2.2), (2.6, 0.05, 2.2), "team", bevel=0.012)
    for k, z in enumerate((1.4, 3.0)):  # two raked funnels with hot bands
        p.prism_y(rect(0, z, 0.75, 0.65), SUP + 3.8, SUP + 6.4, "trim", bevel=0.05, top_scale=0.85, top_center=(0, z + 0.5))
        p.box((0, SUP + 5.9, z + 0.42), (1.3, 0.22, 1.1), "light")
    # braced lattice mast
    for dx in (-0.5, 0.5):
        for dz in (-0.5, 0.5):
            p.box((dx, SUP + 6.6, 0.6 + dz), (0.15, 5.6, 0.15), "paint")
    for y in (SUP + 5.0, SUP + 7.0, SUP + 9.0):
        p.box((0, y, 0.6), (1.2, 0.1, 1.2), "steel")
    p.box((0, SUP + 9.4 - 0.5, 0.6), (1.3, 0.2, 1.3), "trim")
    cable(p, [(0.5, SUP + 8.8, 0.6), (2.4, deck_at(H, 6.0) + 1.0, 6.0), (2.8, deck_at(H, 8.0) + 0.2, 8.0)], r=0.03, kind="steel")
    for z in (-9.0, -1.0, 7.0):
        for sx in (-1, 1):
            b = half_beam_at(H, z)
            p.ocyl((sx * (b + 0.02), deck_at(H, z) - 0.8, z), (sx, 0, 0), 0.5, 0.34, 10, "rubber")
    deck_strip(p, H, -12.8, 13.2, 0.12)
    p.box((0, 1.1, H.z(0.0) + 0.03), (half_beam_at(H, H.z(0.0)) * 1.4, 0.24, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, RADAR[1] + 0.2, 0.6), (3.2, 0.8, 0.3), "paint", bevel=0.03)
        p.box((0, RADAR[1] + 0.2, 0.44), (3.0, 0.6, 0.04), "dark")
        p.box((0, RADAR[1] + 0.2, 0.42), (3.05, 0.06, 0.03), "light")
        p.box((0, RADAR[1] + 0.62, 0.6), (2.4, 0.04, 0.2), "team")


def details_base(p):
    ships.hull_details(p, H)
    bolts(p, (-2.8, deck_at(H, -10.8) + 0.001, -10.8), (2.8, deck_at(H, -10.8) + 0.001, -10.8), 9, UP)
    ring(p, (0.0, SUP + 6.401, 1.4), UP, 0.5)


def build_turret1(p):
    x, y, z = T1
    p.cylinder("y", (x, y + 0.2, z), 1.8, 0.4, 18, "trim")
    p.box((x, y + 1.0, z + 0.5), (2.6, 1.2, 2.2), "paint", bevel=0.05)
    p.obox((x, y + 1.1, z - 0.9), (1, 0, 0), (0, 0.25, -1), 3.6, 1.7, 0.3, "era", bevel=0.05)
    p.obox((x, y + 1.2, z - 1.08), (1, 0, 0), (0, 0.25, -1), 2.0, 0.7, 0.05, "team", bevel=0.01)
    for xx in (-0.85, 0.0, 0.85):
        p.cylinder("z", (xx, y + 1.0, z - 3.6), 0.2, 4.6, 10, "steel")
        p.cylinder("z", (xx, y + 1.0, z - 6.05), 0.26, 0.4, 10, "dark")
        p.cylinder("z", (xx, y + 1.0, z - 5.8), 0.25, 0.08, 10, "weapon")


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 1.0, 0.3, 14, "trim")
    p.box((x, y + 0.7, z + 0.3), (1.6, 0.8, 1.2), "paint", bevel=0.04)
    p.box((x, y + 1.12, z + 0.3), (1.2, 0.04, 0.8), "team")
    for xx in (-0.5, -0.17, 0.17, 0.5):
        p.cylinder("z", (xx, y + 0.8, z - 1.0), 0.09, 1.8, 8, "steel")
        p.cylinder("z", (xx, y + 0.8, z - 1.9), 0.12, 0.08, 8, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_kraken", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 1.0, T1[2] - 6.3]},
                      "muzzle2": {"parent": "turret2", "at": [0, T2[1] + 0.8, T2[2] - 2.0]}},
         budget=10000,
         previews=[("35", (-28, 22, -32), (0, 3.5, 0), 45),
                   ("close", (-15, 13, -17), (0, 4.5, -2.0), 40)])
