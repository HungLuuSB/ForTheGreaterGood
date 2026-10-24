"""Bastion (Order heavy turret, T2 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_bastion/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 3, 24 x 24
studs, about 12 tall), from its scaled blockout (turret pivot, sight,
guns, sensor mast and muzzle where Scale.scaled puts them), and bigger and
more elaborate than the T1 Bulwark, not a rescale. Big shapes first: a
chamfered slab, a sloped lower tier with team plates on its four slopes,
corner buttresses, a stepped armored keep, the raised plinth (the T2
signature) with its team band, an ammo hoist up the back, and a lit ring.
The `turret` (yaw, the def's piece): a broad wedge house with stacked
cheek armor, side skirts, a large team roof plate, a sight in the front
slope, a sensor mast with a lit head, a louvred bustle, and twin long guns
with sleeves, evacuators, muzzle brakes and ready rings (`muzzle` at the
left gun's mouth, as the blockout). Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_octagon, clamped_cable, glow_strip, louver  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

S = 1.884  # the blockout's scale (footprint 1 -> 3)
TURRET_PIVOT = (0.0, 4.0 * S, 0.0)  # 7.54
GY = 5.0 * S  # 9.42, gun axis height
GX = 0.7 * S  # 1.32, guns either side
MUZZLE = (-GX, GY, -8.25 * S)  # -15.54
TY0, TY1 = 7.6, 11.3  # turret house bottom and roof
HOUSE = [(-5.6, TY0), (4.5, TY0), (4.5, 10.8), (4.0, TY1), (-2.8, TY1), (-5.6, 8.6)]  # (z, y)
SLOPE_N = (0.0, 2.8, -2.7)  # the house's sloped front


def diamond(cx, cz, r):
    return [(cx, cz - r), (cx + r, cz), (cx, cz + r), (cx - r, cz)]


def build_base(p):
    p.prism_y(octagon(11.7, 1.6), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.99)
    # sloped lower tier, team plates on its four slopes
    p.prism_y(octagon(9.6, 2.6), 0.6, 1.4, "paint", bevel=0.14)
    p.prism_y(octagon(9.6, 2.6), 1.4, 2.6, "paint", bevel=0.14, top_scale=0.8)
    for k, (nx, nz) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
        u = (abs(nz), 0, abs(nx))
        p.obox((nx * 8.66, 2.03, nz * 8.66), u, (nx * 1.2, 1.92, nz * 1.2), 6.0, 1.2, 0.06, "team", bevel=0.02)
    # buttresses on the diagonals
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.prism_y(diamond(sx * 5.6, sz * 5.6, 1.3), 2.4, 5.0, "paint", bevel=0.1, top_scale=0.5)
    # stepped keep (the blockout's base with its slopes)
    p.prism_y(octagon(6.4, 1.6), 2.6, 3.8, "paint", bevel=0.14)
    p.prism_y(octagon(6.4, 1.6), 3.8, 4.9, "paint", bevel=0.14, top_scale=0.86)
    for sx in (-1, 1):
        p.box((sx * 6.42, 3.2, 0), (0.05, 0.14, 4.0), "light")
        louver(p, (0, 3.2, sx * 6.42), (1, 0, 0), (0, 0, sx), 3.0, 0.8, slats=3)
    # the raised plinth, its team band, the ring
    p.prism_y(octagon(4.6, 1.2), 4.9, 7.3, "paint", bevel=0.12, top_scale=0.95)
    p.box((0, 6.2, -4.5), (6.0, 0.7, 0.06), "team", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * 4.5, 6.2, 0), (0.06, 0.7, 4.4), "team", bevel=0.01)
    p.cylinder("y", (0, 7.42, 0), 4.0, 0.24, 28, "dark")
    p.cylinder("y", (0, 7.27, 0), 4.12, 0.06, 28, "light")
    # ammo hoist up the back with a lit door, cable run
    p.prism_y(rect(0, 5.8, 1.3, 0.9), 2.6, 6.8, "trim", bevel=0.08)
    p.box((0, 3.6, 6.72), (1.4, 1.6, 0.05), "dark")
    p.box((0, 4.5, 6.73), (1.4, 0.12, 0.05), "power")
    p.box((0, 6.82, 5.8), (2.2, 0.05, 1.4), "hazard")
    clamped_cable(p, [(1.6, 2.6, 6.6), (1.5, 4.4, 5.8), (1.4, 6.6, 4.9)], r=0.09)
    # slab dressing: hazard edge, corner lights
    hazard(p, (0, 0.62, -11.2), (1, 0, 0), UP, 9.0, 0.4, stripes=16)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.2, 0.68, sz * 10.2), (0.45, 0.12, 0.45), "light")


def details_base(p):
    band_octagon(p, 3.8, 6.4, 1.6)
    band_octagon(p, 6.0, 4.6, 1.2)
    for sx in (-1, 1):
        rivets(p, (sx * 9.62, 0.95, -6.4), (sx * 9.62, 0.95, 6.4), 10, (sx, 0, 0))
        rivets(p, (-6.4, 0.95, sx * 9.62), (6.4, 0.95, sx * 9.62), 10, (0, 0, sx))
    ring(p, (0, 7.55, 0), UP, 3.4)


def build_turret(p):
    p.prism_x(HOUSE, -4.15, 4.15, "paint", bevel=0.16)
    # stacked cheek armor and side skirts
    for sx in (-1, 1):
        p.obox((sx * 4.4, 9.6, -0.2), (0, 0, 1), (sx, 0.2, 0), 6.6, 2.6, 0.5, "paint", bevel=0.1)
        p.obox((sx * 4.75, 9.4, 0.4), (0, 0, 1), (sx, 0.2, 0), 4.4, 1.5, 0.3, "trim", bevel=0.06)
        glow_strip(p, (sx * 4.92, 9.4, -1.4), (sx * 4.92, 9.4, 2.2), (sx, 0.2, 0), width=0.1)
        p.box((sx * 4.3, 7.95, 0.6), (0.4, 0.7, 7.4), "trim", bevel=0.05)
    p.box((0, TY1 + 0.03, 1.1), (6.4, 0.06, 5.6), "team", bevel=0.02)
    # sight in the front slope (the blockout's)
    p.obox((2.83, 10.36, -3.77), (1, 0, 0), SLOPE_N, 1.3, 0.8, 0.4, "trim", bevel=0.05)
    p.obox((2.83, 10.51, -3.92), (1, 0, 0), SLOPE_N, 0.9, 0.38, 0.06, "light")
    # sensor mast with a lit head (the blockout's, back left)
    p.box((-2.83, 12.4, 3.39), (0.5, 2.2, 0.5), "steel")
    p.box((-2.83, 14.0, 3.39), (2.2, 1.1, 1.1), "trim", bevel=0.06)
    p.box((-2.83, 14.0, 2.82), (1.7, 0.55, 0.05), "light")
    antenna(p, (2.6, TY1, 3.8), 2.2)
    # bustle louvres and an ammo box
    louver(p, (-1.8, 9.4, 4.52), (1, 0, 0), (0, 0, 1), 2.6, 1.6)
    louver(p, (1.8, 9.4, 4.52), (1, 0, 0), (0, 0, 1), 2.6, 1.6)
    # twin long guns: mantlets, sleeves, evacuators, brakes, ready rings
    for sx in (-1, 1):
        x = sx * GX
        p.box((x, GY, -5.0), (1.8, 2.0, 1.6), "trim", bevel=0.12)
        p.ocyl((x, GY, -5.7), (0, 0, -1), 0.7, 2.2, 14, "trim")
        p.ocyl((x, GY, -5.7), (0, 0, -1), 0.47, 8.9, 14, "paint")
        p.ocyl((x, GY, -9.4), (0, 0, -1), 0.64, 1.3, 14, "paint")
        for z in (-8.2, -12.0):
            p.ocyl((x, GY, z), (0, 0, -1), 0.51, 0.12, 14, "steel")
        p.ocyl((x, GY, -13.4), (0, 0, -1), 0.53, 0.14, 14, "weapon")
        p.ocyl((x, GY, -14.6), (0, 0, -1), 0.64, 0.9, 14, "dark")
        p.ocyl((x, GY, -15.5), (0, 0, -1), 0.32, 0.03, 12, "dark")


def details_turret(p):
    for sx in (-1, 1):
        seam(p, (sx * 4.16, 8.3, -5.0), (sx * 4.16, 8.3, 4.4), (sx, 0, 0))
        rivets(p, (sx * 4.68, 10.6, -2.6), (sx * 4.68, 10.6, 2.6), 6, (sx, 0.2, 0))
    seam(p, (-3.9, TY1 + 0.01, -2.2), (3.9, TY1 + 0.01, -2.2), UP)
    ring(p, (0, TY1 + 0.065, 1.1), UP, 0.7)


unit.run(__file__, "ord_bastion", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": [round(v, 3) for v in MUZZLE]}},
         budget=6000,
         previews=[("35", (-34, 30, -40), (0, 5.0, -3.0), 50),
                   ("80", (0, 60, 9), (0, 4, -3.0), 50),
                   ("close", (-17, 16, -20), (0, 7.0, -4.0), 38)])
