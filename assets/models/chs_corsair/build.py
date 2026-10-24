"""Corsair (Chaos destroyer, T2 ship, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_corsair/build.py

v2, the user's review 2026-10-24 (the hulls read as flat barges): a real hull
from tools/ships.py, lean and fast: narrower than the Crusader with a sharper,
more raked bow and a high sheer, flared sides, a tapered transom stern, a dark
boot-top. Chaos reads rugged and improvised (M-14): welded deck patches and
hazard striping, tyre fenders along the topsides, a stepped superstructure (a
low deckhouse, a raised bridge with an amber slit and a team roof), two raked
funnels with hot bands, a tall braced lattice mast with the client-turned
radar array (`radar`, M-27). `turret1` an open gun mount with a slab shield
raised on a barbette forward (`muzzle1`), `launcher` a SAM rail box on a
raised platform amidships (`muzzle3`), `turret2` a twin ASW torpedo mount aft
(`muzzle2`). Model space, waterline at y = 0. Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, rect  # noqa: E402
from ships import barbette, deck_at, deck_strip, half_beam_at  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

H = ships.Hull(length=28.6, beam=5.8, freeboard=1.7, depth=1.4, sheer_bow=2.0, sheer_stern=0.2,
               flare=0.24, transom=0.55, rake=2.8, max_at=0.38, fine=1.7)
T1_Z = -9.2
T1 = (0.0, deck_at(H, T1_Z) + 0.8, T1_Z)
SAM_Z = 4.8
SAM = (0.0, deck_at(H, SAM_Z) + 0.9, SAM_Z)
T2_Z = 10.0
T2 = (0.0, deck_at(H, T2_Z), T2_Z)
SUP = deck_at(H, -1.0)
RADAR = (0.0, SUP + 8.6, 1.4)


def build_base(p):
    ships.hull(p, H)
    d0 = deck_at(H, -12.0)
    p.obox((0, d0 + 0.04, -12.0), (1, 0, 0), (0, 1, 0.16), 2.6, 2.2, 0.05, "team", bevel=0.012)
    hazard(p, (0, deck_at(H, -6.8) + 0.04, -6.8), (1, 0, 0), UP, 4.4, 0.4, stripes=10)
    p.box((1.6, deck_at(H, 2.0) + 0.03, 2.0), (1.0, 0.04, 2.6), "steel", bevel=0.01)  # welded patch
    barbette(p, (0, T1_Z), H, T1[1], 1.4, kind="trim")
    # low deckhouse, raised bridge with the amber slit and a team roof
    p.prism_y(rect(0, -1.2, 2.0, 2.6), SUP - 0.2, SUP + 1.8, "paint", bevel=0.08, top_scale=0.95)
    p.prism_y(rect(0, -1.6, 1.6, 1.4), SUP + 1.8, SUP + 3.6, "paint", bevel=0.08, top_scale=0.9)
    p.box((0, SUP + 3.0, -3.0), (2.6, 0.3, 0.05), "light")  # amber slit
    p.box((0, SUP + 3.64, -1.6), (2.4, 0.05, 2.2), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 2.02, SUP + 0.9, -1.2), (0.3, 1.2, 1.6), "era", bevel=0.03)  # reactive slabs
    # two raked funnels with hot bands
    for k, z in enumerate((1.6, 3.0)):
        p.prism_y(rect(0.7 - k * 1.4, z, 0.6, 0.55), SUP - 0.2, SUP + 4.2 - k * 0.6, "trim", bevel=0.05,
                  top_scale=0.85, top_center=(0.7 - k * 1.4, z + 0.5))
        p.box((0.7 - k * 1.4, SUP + 3.7 - k * 0.6, z + 0.45), (1.1, 0.2, 1.0), "light")
    # braced lattice mast
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            p.box((dx, SUP + 5.1, 1.4 + dz), (0.14, 6.6, 0.14), "paint")
    for y in (SUP + 3.4, SUP + 5.4, SUP + 7.4):
        p.box((0, y, 1.4), (1.1, 0.1, 1.1), "steel")
    p.box((0, SUP + 8.3, 1.4), (1.2, 0.2, 1.2), "trim")
    cable(p, [(0.4, SUP + 8.2, 1.4), (2.0, deck_at(H, 7.0) + 1.2, 7.0), (2.2, deck_at(H, 9.0) + 0.2, 9.0)], r=0.03, kind="steel")
    # SAM platform, tyre fenders, strips
    p.prism_y(rect(0, SAM_Z, 1.5, 1.6), deck_at(H, SAM_Z) - 0.2, SAM[1], "trim", bevel=0.05)
    for z in (-7.0, 0.0, 7.0):
        for sx in (-1, 1):
            b = half_beam_at(H, z)
            p.ocyl((sx * (b + 0.02), deck_at(H, z) - 0.7, z), (sx, 0, 0), 0.45, 0.3, 10, "rubber")
    deck_strip(p, H, -12.6, 12.8, 0.1)
    p.box((0, 0.9, H.z(0.0) + 0.03), (half_beam_at(H, H.z(0.0)) * 1.4, 0.22, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, RADAR[1] + 0.3, 1.4), (2.8, 0.7, 0.3), "paint", bevel=0.03)
        p.box((0, RADAR[1] + 0.3, 1.24), (2.6, 0.5, 0.04), "dark")
        p.box((0, RADAR[1] + 0.3, 1.22), (2.65, 0.06, 0.03), "light")
        p.box((0, RADAR[1] + 0.67, 1.4), (2.0, 0.04, 0.2), "team")


def details_base(p):
    ships.hull_details(p, H)
    bolts(p, (-2.0, deck_at(H, -10.6) + 0.001, -10.6), (2.0, deck_at(H, -10.6) + 0.001, -10.6), 7, UP)
    ring(p, (0, T1[1] + 0.001, T1_Z), UP, 1.0)


def build_turret1(p):
    x, y, z = T1
    p.cylinder("y", (x, y + 0.2, z), 1.3, 0.4, 16, "trim")
    p.box((x, y + 0.9, z + 0.4), (1.6, 1.0, 1.8), "paint", bevel=0.05)
    p.obox((x, y + 1.0, z - 0.8), (1, 0, 0), (0, 0.25, -1), 2.6, 1.5, 0.25, "era", bevel=0.05)
    p.obox((x, y + 1.1, z - 0.96), (1, 0, 0), (0, 0.25, -1), 1.4, 0.6, 0.05, "team", bevel=0.01)
    p.cylinder("z", (x, y + 0.9, z - 3.0), 0.2, 4.0, 10, "steel")
    p.cylinder("z", (x, y + 0.9, z - 5.15), 0.26, 0.4, 10, "dark")
    p.cylinder("z", (x, y + 0.9, z - 4.9), 0.25, 0.08, 10, "weapon")


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 0.7, 0.3, 12, "trim")
    for sx in (-1, 1):
        p.cylinder("z", (x + sx * 0.3, y + 0.6, z - 0.4), 0.2, 2.2, 10, "paint")
        p.cylinder("z", (x + sx * 0.3, y + 0.6, z - 1.52), 0.12, 0.04, 8, "weapon")


def build_launcher(p):
    x, y, z = SAM
    p.cylinder("y", (x, y + 0.15, z), 0.9, 0.3, 12, "trim")
    p.box((x, y + 0.9, z), (2.4, 1.2, 2.6), "paint", bevel=0.05)
    for cx, cy in ((-0.6, 0.6), (0.6, 0.6), (-0.6, 1.2), (0.6, 1.2)):
        p.cylinder("z", (x + cx, y + cy, z - 1.0), 0.22, 1.0, 10, "steel")
        p.ocyl((x + cx, y + cy, z - 1.5), (0, 0, -1), 0.22, 0.3, 10, "weapon", radius2=0.05)
    p.box((x, y + 1.53, z + 0.3), (1.6, 0.05, 1.4), "team", bevel=0.01)


def no_details(p):
    pass


unit.run(__file__, "chs_corsair", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details),
                 unit.PieceSpec("launcher", "base", SAM, build_launcher, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 0.9, T1[2] - 5.4]},
                      "muzzle2": {"parent": "turret2", "at": [0, T2[1] + 0.6, T2[2] - 1.6]},
                      "muzzle3": {"parent": "launcher", "at": [SAM[0], SAM[1] + 0.9, SAM[2] - 1.8]}},
         budget=10000,
         previews=[("35", (-26, 20, -30), (0, 3.0, 0), 45),
                   ("close", (-14, 12, -16), (0, 4.0, -2.0), 40)])
