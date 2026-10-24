"""Sanctum (Order point defence, T2 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sanctum/build.py

New mesh for the sim's S-149 (shoots down missiles and rockets with small
vertical-launch interceptors, never units), at the T2 defense size (S-104:
footprint 3, 24 x 24 studs, about 9 tall at the radar). Big shapes first: a
chamfered slab with team plates and hazard striping, an armored bunker with
sloped walls, a short radar tower at the back right carrying a white radome
over a client-turned search panel (`radar`, M-27). The `launcher` (static:
the def doesn't turn it): the vertical-launch module on the bunker roof, a
4 x 4 grid of armored cell hatches, each with a ready ring (`weapon`) and a
blast vent strip, a large team plate in front, `muzzle` at the front left
cell, launching straight up. Reads apart from the Aegis (a turning canister
pack) by its low flat grid. Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

VLS = (-2.0, 0.0)  # centre of the cell grid
ROOF = 4.0
CELL = 1.55  # cell pitch
RADAR = (7.0, 7.0)
MUZZLE = (VLS[0] - 1.5 * CELL, ROOF + 0.7, VLS[1] - 1.5 * CELL)


def build_base(p):
    p.prism_y(octagon(11.6, 1.4), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.99)
    hazard(p, (0, 0.62, -10.8), (1, 0, 0), UP, 8.0, 0.5, stripes=14)
    # the armored bunker under the launcher, sloped walls, team plates
    p.prism_y(rect(VLS[0], VLS[1], 5.6, 5.6), 0.6, 2.6, "paint", bevel=0.18)
    p.prism_y(rect(VLS[0], VLS[1], 5.6, 5.6), 2.6, ROOF, "paint", bevel=0.16, top_scale=0.88)
    for sx in (-1, 1):
        p.obox((VLS[0] + sx * 5.3, 3.3, VLS[1]), (0, 0, 1), (sx * 1.1, 1.3, 0), 6.0, 1.2, 0.06, "team", bevel=0.02)
        p.box((VLS[0] + sx * 5.62, 1.6, VLS[1]), (0.05, 0.16, 8.0), "light")
    p.box((VLS[0], 1.6, VLS[1] - 5.62), (8.0, 0.16, 0.05), "light")
    p.box((VLS[0], 1.7, VLS[1] + 5.62), (3.0, 1.8, 0.06), "dark")  # reload door
    # radar tower, back right
    p.prism_y(rect(RADAR[0], RADAR[1], 1.6, 1.6), 0.6, 5.4, "paint", bevel=0.12, top_scale=0.8)
    p.box((RADAR[0] - 1.42, 3.6, RADAR[1]), (0.05, 1.8, 1.6), "team", bevel=0.01)
    p.box((RADAR[0], 2.0, RADAR[1] - 1.62), (1.6, 0.16, 0.05), "light")
    p.cylinder("y", (RADAR[0], 5.6, RADAR[1]), 1.5, 0.4, 20, "trim", bevel=0.04)
    # power cabinet and cable trench
    p.prism_y(rect(7.4, -6.0, 1.8, 1.4), 0.6, 2.2, "trim", bevel=0.1)
    p.box((7.4, 1.4, -7.42), (2.0, 0.3, 0.05), "power")
    p.box((4.4, 0.66, 2.6), (0.9, 0.1, 9.0), "dark")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, 0.66, sz * 11.0), (0.5, 0.12, 0.5), "light")

    with p.sub("radar", (RADAR[0], 5.8, RADAR[1]), "turn", (0, 1, 0)):  # M-27: the search panel under the radome
        p.cylinder("y", (RADAR[0], 6.0, RADAR[1]), 0.5, 0.4, 12, "steel")
        p.box((RADAR[0], 7.0, RADAR[1] - 0.2), (2.4, 1.4, 0.2), "dark")
        p.box((RADAR[0], 7.0, RADAR[1] - 0.32), (2.0, 0.08, 0.03), "light")
    p.cylinder("y", (RADAR[0], 6.0, RADAR[1]), 1.45, 0.2, 20, "steel")
    p.ocyl((RADAR[0], 6.2, RADAR[1]), UP, 1.45, 2.0, 20, "radome", radius2=0.9)  # the radome over the panel


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (VLS[0] + sx * 5.62, 1.0, VLS[1] - 4.0), (VLS[0] + sx * 5.62, 1.0, VLS[1] + 4.0), 9, (sx, 0, 0))
    seam(p, (-9.0, 0.601, 8.6), (9.0, 0.601, 8.6), UP)


def build_launcher(p):
    x0, z0 = VLS
    # the vertical-launch module: a raised deck with a 4 x 4 grid of cell hatches
    p.prism_y(rect(x0, z0, 3.6, 3.6), ROOF, ROOF + 0.5, "trim", bevel=0.08)
    p.box((x0, ROOF + 0.52, z0), (6.6, 0.04, 6.6), "dark")
    for i in range(4):
        for j in range(4):
            cx, cz = x0 + (i - 1.5) * CELL, z0 + (j - 1.5) * CELL
            p.box((cx, ROOF + 0.6, cz), (1.2, 0.16, 1.2), "paint", bevel=0.03)  # hatch
            p.cylinder("y", (cx, ROOF + 0.7, cz), 0.42, 0.04, 14, "weapon")  # ready ring
            p.cylinder("y", (cx, ROOF + 0.72, cz), 0.3, 0.04, 14, "steel")
    for k in range(5):  # blast vent strips between the rows
        p.box((x0 + (k - 2) * CELL, ROOF + 0.55, z0), (0.12, 0.06, 6.2), "grille")
    p.box((x0, ROOF - 0.1, z0 - 3.65), (6.0, 0.9, 0.06), "team", bevel=0.02)
    hazard(p, (x0, ROOF + 0.53, z0 - 3.3), (1, 0, 0), UP, 6.4, 0.35, stripes=12)


def details_launcher(p):
    ring(p, (VLS[0], ROOF + 0.541, VLS[1] + 3.2), UP, 0.6)


unit.run(__file__, "ord_sanctum", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", (VLS[0], ROOF, VLS[1]), build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [round(v, 3) for v in MUZZLE]}},
         budget=8000,
         previews=[("35", (-30, 24, -36), (0, 3.0, 0), 50),
                   ("80", (0, 52, 8), (0, 2, 0), 50),
                   ("close", (-15, 13, -18), (0, 4.0, -1.0), 40)])
