"""Crusader (Order destroyer, T2 ship, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_crusader/build.py

v2, the user's review 2026-10-24 (the hulls read as flat barges from the game
camera): a real hull from tools/ships.py, lean and fast: a long fine raked bow
with a high sheer, flared sides, a tapered stern with a transom, a sheer strake,
a dark boot-top. A stepped superstructure: a forward deckhouse, a tall bridge
with a wraparound glass band and wings, a lattice-free solid mast with the
client-turned radar (`radar`, M-27), a raked funnel with a glowing cap, a hangar
and helideck aft. `turret1` a sloped gun house raised on a barbette forward
(`muzzle1`), `launcher` a VLS block on a raised deck behind it (`muzzle3`),
`turret2` a triple ASW torpedo mount on the starboard side aft (`muzzle2`).
Large team plates on the foredeck and the helideck, running strips along the
sheer. Model space, waterline at y = 0. Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from mech import hazard, rect  # noqa: E402
from ships import barbette, deck_at, deck_strip, half_beam_at  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

H = ships.Hull(length=29.0, beam=6.6, freeboard=1.9, depth=1.5, sheer_bow=1.7, sheer_stern=0.25,
               flare=0.2, transom=0.6, rake=2.2, max_at=0.4, fine=1.9)
T1_Z, T1_TOP = -8.6, deck_at(H, -8.6) + 0.9
T1 = (0.0, T1_TOP, T1_Z)
VLS_Z = -4.4
VLS = (0.0, deck_at(H, VLS_Z) + 0.5, VLS_Z)
T2 = (2.2, deck_at(H, 6.0), 6.0)
SUP = deck_at(H, 0.0)  # the superstructure's foot
RADAR = (0.0, SUP + 8.4, 0.9)


def build_base(p):
    ships.hull(p, H)
    d0 = deck_at(H, -11.5)
    p.obox((0, d0 + 0.04, -11.5), (1, 0, 0), (0, 1, 0.12), 3.0, 2.6, 0.05, "team", bevel=0.012)  # foredeck plate
    barbette(p, (0, T1_Z), H, T1_TOP, 1.5)
    # forward deckhouse with the VLS deck on top, the bridge behind it
    p.prism_y(rect(0, -3.2, 2.2, 2.0), SUP - 0.2, SUP + 1.6, "paint", bevel=0.1, top_scale=0.94)
    p.prism_y(rect(0, 0.6, 2.6, 2.4), SUP - 0.2, SUP + 2.6, "paint", bevel=0.12, top_scale=0.93)
    p.prism_y(rect(0, 0.4, 2.0, 1.8), SUP + 2.6, SUP + 4.6, "paint", bevel=0.1, top_scale=0.9)
    p.prism_x([(-1.6, SUP + 4.6), (-1.1, SUP + 5.8), (1.6, SUP + 5.8), (1.9, SUP + 4.6)], -1.6, 1.6, "paint", bevel=0.08)
    p.box((0, SUP + 5.2, -1.42), (3.0, 0.5, 0.06), "glass")  # wraparound bridge glass
    for sx in (-1, 1):
        p.box((sx * 1.62, SUP + 5.2, 0.2), (0.06, 0.5, 2.6), "glass")
        p.box((sx * 2.5, SUP + 4.7, -1.0), (1.2, 0.18, 0.9), "paint", bevel=0.03)  # bridge wings
        p.box((sx * 2.62, SUP + 1.3, 0.6), (0.05, 0.14, 4.4), "light")
    p.box((0, SUP + 5.84, 0.6), (2.6, 0.05, 2.2), "team", bevel=0.012)
    p.box((0, SUP + 4.3, -1.43), (3.0, 0.08, 0.04), "light")
    # mast and funnel
    p.prism_y(rect(0, 0.9, 0.55, 0.55), SUP + 5.8, SUP + 8.0, "trim", bevel=0.05, top_scale=0.6)
    p.box((0, SUP + 7.2, 0.9), (2.4, 0.12, 0.12), "steel")  # yardarm
    p.cylinder("y", (0, SUP + 9.6, 0.9), 0.07, 1.6, 6, "steel")
    p.box((0, SUP + 10.45, 0.9), (0.2, 0.14, 0.2), "light")
    p.prism_y(rect(0, 4.4, 0.9, 1.2), SUP + 2.4, SUP + 5.2, "trim", bevel=0.08, top_scale=0.82, top_center=(0, 4.9))
    p.box((0, SUP + 5.22, 4.9), (1.3, 0.06, 1.6), "power")
    # hangar and helideck aft
    p.prism_y(rect(0, 6.6, 2.2, 1.8), SUP - 0.2, SUP + 2.2, "paint", bevel=0.1, top_scale=0.95)
    p.box((0, SUP + 1.1, 8.42), (3.2, 1.8, 0.06), "dark")  # hangar door
    hd = deck_at(H, 11.2)
    p.box((0, hd + 0.03, 11.2), (half_beam_at(H, 11.2) * 2 - 0.4, 0.05, 4.4), "dark")
    p.box((0, hd + 0.06, 11.2), (3.0, 0.04, 3.0), "team", bevel=0.01)
    hazard(p, (0, hd + 0.07, 9.2), (1, 0, 0), UP, 4.6, 0.3, stripes=10)
    deck_strip(p, H, -12.0, 12.6, 0.12)
    for z in (-12.5, -6.0, 9.5):
        for sx in (-1, 1):
            p.cylinder("y", (sx * (half_beam_at(H, z) - 0.45), deck_at(H, z) + 0.25, z), 0.18, 0.5, 8, "steel")
    p.box((0, 1.0, H.z(0.0) + 0.03), (half_beam_at(H, H.z(0.0)) * 1.4, 0.24, 0.05), "light")  # stern light bar

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, RADAR[1], 0.9), (2.8, 0.7, 0.4), "paint", bevel=0.03)
        p.box((0, RADAR[1], 0.68), (2.6, 0.5, 0.04), "dark")
        p.box((0, RADAR[1], 0.66), (2.65, 0.06, 0.03), "light")


def details_base(p):
    ships.hull_details(p, H)
    seam(p, (-2.5, SUP + 2.601, -1.6), (2.5, SUP + 2.601, -1.6), UP)
    bolts(p, (-1.4, deck_at(H, -13.0) + 0.001, -13.0), (1.4, deck_at(H, -13.0) + 0.001, -13.0), 6, UP)


def build_turret1(p):
    x, y, z = T1
    p.prism_y([(-1.1, z - 1.3), (1.1, z - 1.3), (1.5, z - 0.4), (1.5, z + 1.5), (-1.5, z + 1.5), (-1.5, z - 0.4)],
              y, y + 1.4, "paint", bevel=0.08, top_scale=0.84)
    p.box((0, y + 1.44, z + 0.4), (2.0, 0.05, 1.6), "team", bevel=0.012)
    p.box((1.0, y + 1.2, z - 0.9), (0.3, 0.3, 0.06), "light")
    p.cylinder("z", (0, y + 0.7, z - 3.5), 0.22, 4.4, 12, "steel")
    p.cylinder("z", (0, y + 0.7, z - 1.6), 0.36, 0.7, 12, "trim")  # mantlet collar
    p.cylinder("z", (0, y + 0.7, z - 5.85), 0.28, 0.5, 12, "dark")
    p.cylinder("z", (0, y + 0.7, z - 5.55), 0.27, 0.1, 12, "weapon")


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 0.7, 0.3, 12, "trim")
    for k, dy in enumerate((0.55, 0.95, 1.35)):
        p.cylinder("z", (x, y + dy - 0.1 * k, z - 0.2), 0.16, 2.0, 10, "paint")
        p.cylinder("z", (x, y + dy - 0.1 * k, z - 1.22), 0.1, 0.04, 8, "weapon")
    p.box((x, y + 0.8, z + 0.6), (0.8, 1.2, 0.4), "paint", bevel=0.03)


def build_launcher(p):
    x, y, z = VLS
    p.box((x, y + 0.4, z), (3.4, 0.8, 2.6), "paint", bevel=0.06)
    for i in range(4):
        for j in range(2):
            cx, cz = x - 1.2 + i * 0.8, z - 0.55 + j * 1.1
            p.box((cx, y + 0.82, cz), (0.6, 0.05, 0.85), "team" if (i + j) % 2 == 0 else "trim")
            p.box((cx, y + 0.85, cz - 0.32), (0.3, 0.02, 0.06), "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_crusader", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details),
                 unit.PieceSpec("launcher", "base", VLS, build_launcher, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 0.7, T1[2] - 6.15]},
                      "muzzle2": {"parent": "turret2", "at": [T2[0], T2[1] + 0.95, T2[2] - 1.3]},
                      "muzzle3": {"parent": "launcher", "at": [VLS[0], VLS[1] + 1.0, VLS[2]]}},
         budget=10000,
         previews=[("35", (-26, 20, -30), (0, 3.0, 0), 45),
                   ("close", (-14, 12, -16), (0, 4.0, -2.0), 40)])
