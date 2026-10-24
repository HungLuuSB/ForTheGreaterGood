"""Aegis (Order long-range radar SAM site, T2 structure, footprint 3):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_aegis/build.py

New mesh from its blockout, at the T2 defense size (S-104: footprint 3,
24 x 24 studs, about 10 tall at the radar). Big shapes first: a chamfered
slab with team plates and hazard striping, an armored octagonal emplacement
under the launcher with a glowing turret ring, a cable trench, and an
armored radar block at the back right carrying the big engagement radar
(client-turned `radar`, M-27): a tilted phased-array panel with glowing
edges and a team back. The `launcher` (the def turns it, M-3): a turntable
with armored cradle cheeks and six round canisters standing upright in an
open strapped frame (the radar SAMs launch vertically, the user
2026-10-24; v2 after the key art 3 review: the closed box with a big team
plate read as a plain block), team bands near their tops, cap rings that
light when ready (`weapon`), `muzzle` at the front left cap. Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

PIVOT = (-3.0, 3.4, 1.0)
RADAR = (6.0, 4.6, 5.0)
ELEV = math.radians(90)  # vertical launch
AXIS = (0.0, math.sin(ELEV), -math.cos(ELEV))  # the canisters' axis, forward and up
NORM = (0.0, math.cos(ELEV), math.sin(ELEV))  # the pack's top
PACK = (-3.0, 7.4, 1.0)  # centre of the canister pack, standing on the turntable
PACK_LEN = 7.0


def along(c, d, k):
    return tuple(c[i] + d[i] * k for i in range(3))


def shifted(pts, dx, dz):
    return [(x + dx, z + dz) for x, z in pts]


COLS = (-1.95, 0.0, 1.95)  # canister columns across the pack (x, from PACK)
ROWS = (-1.0, 1.0)  # front and back rows (z, from PACK)
CAN_R = 0.9


def mouth(col, row):
    """Centre of a canister's top cap."""
    return (PACK[0] + COLS[col], PACK[1] + PACK_LEN / 2 + 0.05, PACK[2] + ROWS[row])


MUZZLE = mouth(0, 0)  # the front left canister


def build_base(p):
    p.prism_y(octagon(11.6, 1.4), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.99)
    hazard(p, (0, 0.62, -10.8), (1, 0, 0), UP, 8.0, 0.5, stripes=14)
    for sx in (-1, 1):
        p.box((sx * 9.6, 0.64, -2.0), (2.4, 0.05, 8.0), "team", bevel=0.015)
    # armored emplacement under the launcher, turret ring
    p.prism_y(shifted(octagon(5.2, 1.4), PIVOT[0], PIVOT[2]), 0.6, 2.4, "paint", bevel=0.16)
    p.prism_y(shifted(octagon(5.2, 1.4), PIVOT[0], PIVOT[2]), 2.4, 3.2, "paint", bevel=0.14, top_scale=0.86)
    p.cylinder("y", (PIVOT[0], 3.22, PIVOT[2]), 3.0, 0.1, 28, "power")
    p.box((PIVOT[0], 1.5, PIVOT[2] - 5.22), (5.0, 0.16, 0.05), "light")
    # cable trench to the radar block
    p.box((2.0, 0.66, 3.4), (6.0, 0.1, 0.9), "dark")
    # the armored radar block, back right
    p.prism_y(rect(RADAR[0], RADAR[2], 2.6, 2.6), 0.6, 4.2, "paint", bevel=0.14, top_scale=0.84)
    p.box((RADAR[0] - 2.62, 2.4, RADAR[2]), (0.05, 2.2, 3.6), "team", bevel=0.015)
    p.box((RADAR[0], 1.4, RADAR[2] - 2.62), (3.6, 0.16, 0.05), "light")
    p.box((RADAR[0], 2.6, RADAR[2] + 2.62), (3.0, 1.6, 0.05), "grille")
    p.cylinder("y", (RADAR[0], 4.3, RADAR[2]), 0.9, 0.3, 16, "steel")
    # generator box and spare canisters, front right
    p.prism_y(rect(6.4, -5.4, 2.2, 1.6), 0.6, 2.2, "trim", bevel=0.1)
    p.box((6.4, 2.22, -5.4), (3.6, 0.05, 2.4), "team", bevel=0.015)
    p.box((6.4, 1.4, -7.02), (2.4, 0.3, 0.05), "power")
    for k in range(2):
        p.cylinder("x", (6.4, 0.95 + k * 0.8, -1.2), 0.4, 3.6, 14, "paint")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 0.66, sz * 11.0), (0.5, 0.12, 0.5), "light")

    # the engagement radar (client-turned): a tilted phased array
    t = math.radians(18)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (RADAR[0], 7.2, RADAR[2])
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (RADAR[0], 4.8, RADAR[2]), 0.7, 0.5, 14, "trim")
        p.box((RADAR[0], 5.5, RADAR[2] + 0.3), (1.0, 1.4, 1.2), "paint", bevel=0.06)
        p.obox(c, (1, 0, 0), n, 5.6, 4.0, 0.4, "paint", bevel=0.05)
        p.obox(along(c, n, 0.21), (1, 0, 0), n, 5.0, 3.4, 0.03, "dark")
        for b in (-1.75, 1.75):
            p.obox(tuple(c[k] + n[k] * 0.23 + v[k] * b for k in range(3)), (1, 0, 0), n, 5.0, 0.1, 0.02, "light")
        for a in (-2.55, 2.55):
            p.obox((c[0] + a, c[1] + n[1] * 0.23, c[2] + n[2] * 0.23), (1, 0, 0), n, 0.1, 3.4, 0.02, "light")
        for gx in (-1.2, 0.0, 1.2):  # array tiles
            p.obox((c[0] + gx, c[1] + n[1] * 0.24, c[2] + n[2] * 0.24), (1, 0, 0), n, 0.06, 3.2, 0.01, "trim")
        p.obox(along(c, n, -0.22), (1, 0, 0), n, 4.6, 3.0, 0.03, "team")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 10.8, 0.61, -6.0), (sx * 10.8, 0.61, 2.0), 8, UP)
    seam(p, (RADAR[0] - 2.0, 4.201, RADAR[2]), (RADAR[0] + 2.0, 4.201, RADAR[2]), UP)


def build_launcher(p):
    x0, y0, z0 = PIVOT
    p.cylinder("y", (x0, y0 + 0.2, z0), 2.8, 0.4, 28, "trim", bevel=0.05)  # turntable
    for sx in (-1, 1):  # armored cradle cheeks hugging the pack's sides
        p.prism_x([(z0 - 2.6, y0 + 0.4), (z0 + 2.6, y0 + 0.4), (z0 + 2.6, y0 + 3.0), (z0 + 1.4, y0 + 4.2), (z0 - 2.6, y0 + 4.2)],
                  x0 + sx * 3.25 - 0.3, x0 + sx * 3.25 + 0.3, "paint", bevel=0.08)
        p.box((x0 + sx * 3.57, y0 + 2.2, z0), (0.05, 0.16, 4.0), "light")
        p.box((x0 + sx * 3.56, y0 + 3.4, z0 - 0.4), (0.05, 1.2, 2.6), "team", bevel=0.015)
    # the canister pack: six round canisters standing upright in an open frame (vertical launch)
    base_y = PACK[1] - PACK_LEN / 2
    p.box((PACK[0], base_y - 0.15, PACK[2]), (6.4, 0.3, 4.4), "trim", bevel=0.05)  # the cradle floor
    for ci, cx in enumerate(COLS):
        for ri, rz in enumerate(ROWS):
            c = (PACK[0] + cx, PACK[1], PACK[2] + rz)
            p.cylinder("y", c, CAN_R, PACK_LEN, 20, "paint", bevel=0.04)
            p.cylinder("y", (c[0], PACK[1] + PACK_LEN / 2 - 1.0, c[2]), CAN_R + 0.03, 0.5, 20, "team")  # team band near the top
            p.cylinder("y", (c[0], PACK[1] - 1.2, c[2]), CAN_R + 0.03, 0.16, 20, "dark")  # seam
            m = mouth(ci, ri)
            p.cylinder("y", m, CAN_R - 0.05, 0.1, 20, "steel")  # the cap
            p.cylinder("y", (m[0], m[1] + 0.07, m[2]), 0.62, 0.04, 18, "weapon")  # ready ring
            p.cylinder("y", (m[0], m[1] + 0.09, m[2]), 0.4, 0.05, 16, "steel")
    for k in (-2.4, 0.4, 2.9):  # straps binding the pack
        p.box((PACK[0], PACK[1] + k, PACK[2]), (6.5, 0.32, 4.5), "trim", bevel=0.03)
        p.box((PACK[0], PACK[1] + k, PACK[2] - 2.26), (6.0, 0.18, 0.04), "light" if k > 2 else "dark")
    for sx in (-1, 1):  # frame posts at the corners
        for sz in (-1, 1):
            p.box((PACK[0] + sx * 3.05, PACK[1], PACK[2] + sz * 2.05), (0.32, PACK_LEN, 0.32), "trim")
    hazard(p, (PACK[0], base_y + 0.02, PACK[2] - 2.25), (1, 0, 0), (0, 0, -1), 6.0, 0.35, stripes=12)
    # fire-control sensor on the cradle
    p.box((x0 + 2.0, y0 + 4.9, z0 - 2.9), (1.0, 0.7, 1.0), "trim", bevel=0.05)
    p.box((x0 + 2.0, y0 + 4.9, z0 - 3.42), (0.8, 0.36, 0.05), "light")


def details_launcher(p):
    ring(p, (PACK[0], PACK[1] - 3.0, PACK[2] - 2.24), (0, 0, -1), 0.6)


unit.run(__file__, "ord_aegis", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [round(v, 3) for v in MUZZLE]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.5, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 5.0, -1.0), 40)])
