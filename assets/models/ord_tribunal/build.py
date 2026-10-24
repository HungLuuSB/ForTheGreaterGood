"""Tribunal (Order fire-control radar, T2 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_tribunal/build.py

From its blockout, at the size scale (S-104: footprint 2, 16 x 16 studs,
about 12.5 tall): bigger and more elaborate than the T1 Watchtower, not a
rescale. Big shapes first: a chamfered slab, a sloped plinth with a front
glacis (the blockout's wedge) and team plates on its flanks, an armored
block with sloped upper walls, corner buttresses, a large team roof plate,
a lit door and a ladder, a cooling unit with fan grilles and a power
cabinet on the sides, and an armored bearing drum with a running band.
The client-turned `radar` (turn Y, the blockout's visual piece and pivot):
a yoke carrying two tall flat phased-array panels back to back, never a
dish, each face unlit with a glowing edge and a fine cell grid (style
guide, "Sensor faces"), framed, with an equipment spine between them and a
cap housing with a team plate on top. Order reads heavy and clean (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, clamped_cable, louver  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

RADAR = (0.0, 6.6, 0.0)  # the radar's pivot (blockout)
PC = (0.0, 9.4, 0.0)  # panel pair centre
PW, PH = 6.2, 5.0  # panel width and height
PZ = 0.5  # each face's distance from the centre plane
B0, B1 = 1.4, 4.4  # the block's bottom and roof


def diamond(cx, cz, r):
    return [(cx, cz - r), (cx + r, cz), (cx, cz + r), (cx - r, cz)]


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.5, "trim", bevel=0.1, top_scale=0.985)
    p.prism_y(octagon(6.6, 1.4), 0.5, 0.9, "paint", bevel=0.1)
    p.prism_y(octagon(6.6, 1.4), 0.9, B0, "paint", bevel=0.1, top_scale=0.92)
    p.prism_x([(-7.5, 0.5), (-6.4, 0.5), (-6.4, 1.2), (-6.7, 1.2)], -4.4, 4.4, "paint", bevel=0.06)  # front glacis
    p.box((0, 0.65, -7.52), (6.0, 0.12, 0.05), "light")
    hazard(p, (0, 0.52, -7.62), (1, 0, 0), UP, 2.0, 0.2, stripes=5)
    for sx in (-1, 1):
        p.obox((sx * 6.35, 1.17, 0.4), (0, 0, 1), (sx * 0.5, 0.53, 0), 6.0, 0.55, 0.05, "team", bevel=0.01)
    # the armored block with sloped upper walls, buttresses, a big team roof
    p.prism_y(rect(0, 0, 3.7, 3.7), B0, 3.6, "paint", bevel=0.14)
    p.prism_y(rect(0, 0, 3.7, 3.7), 3.6, B1, "paint", bevel=0.14, top_scale=0.86)
    p.box((0, B1 + 0.03, 0), (5.4, 0.06, 5.4), "team", bevel=0.02)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.prism_y(diamond(sx * 3.6, sz * 3.6, 0.9), B0 - 0.1, 3.4, "paint", bevel=0.08, top_scale=0.45)
            p.box((sx * 7.0, 0.56, sz * 7.0), (0.35, 0.12, 0.35), "light")
    # door with its light (front), ladder (back)
    p.box((0, 2.4, -3.72), (1.4, 2.0, 0.05), "dark")
    p.box((0, 3.5, -3.73), (1.4, 0.12, 0.05), "light")
    for x in (-0.35, 0.35):
        p.box((x, 3.0, 3.85), (0.08, 3.2, 0.08), "steel")
    for i in range(5):
        p.box((0, B0 + 0.4 + i * 0.55, 3.85), (0.7, 0.05, 0.05), "steel")
    # cooling unit with fan grilles (left), power cabinet (right)
    p.prism_y(rect(-5.0, 0.6, 1.0, 2.0), B0, 2.8, "trim", bevel=0.06)
    for z in (-0.4, 1.6):
        p.cylinder("y", (-5.0, 2.82, z), 0.75, 0.06, 14, "grille")
    p.box((-6.02, 2.1, 0.6), (0.05, 0.12, 3.0), "light")
    p.prism_y(rect(5.0, -0.4, 0.9, 1.6), B0, 3.2, "trim", bevel=0.06)
    louver(p, (5.92, 2.3, -0.4), (0, 0, 1), (1, 0, 0), 2.0, 1.2, slats=3)
    p.box((5.0, 3.22, -0.4), (1.4, 0.05, 2.8), "team", bevel=0.01)
    clamped_cable(p, [(4.2, 2.6, 0.9), (3.9, 3.0, 1.6), (3.75, 3.4, 2.4)], r=0.09)
    # bearing drum with a running band
    p.cylinder("y", (0, 5.2, 0), 1.25, 1.6, 18, "paint", bevel=0.05)
    p.cylinder("y", (0, 5.0, 0), 1.29, 0.12, 18, "light")
    p.cylinder("y", (0, 6.2, 0), 1.45, 0.4, 18, "trim", bevel=0.04)
    antenna(p, (-2.8, B1, 2.8), 2.2)


def details_base(p):
    band_box(p, 2.6, 0, 0, 3.705, 3.705)
    for sx in (-1, 1):
        rivets(p, (sx * 3.72, 1.8, -2.8), (sx * 3.72, 1.8, 2.8), 6, (sx, 0, 0))
    ring(p, (0, 6.41, 0), UP, 0.9)
    seam(p, (-4.4, 0.91, -6.2), (4.4, 0.91, -6.2), UP)


def face(p, sz):
    """One array face on the side sz (-1 front, +1 back): unlit, glowing edge, grid."""
    z = sz * (PZ + 0.16)
    n = (0, 0, sz)
    cx, cy = PC[0], PC[1]
    p.box((cx, cy, z), (PW - 0.5, PH - 0.5, 0.03), "dark")
    zz = z + sz * 0.02
    for b in (-(PH - 0.6) / 2, (PH - 0.6) / 2):
        p.box((cx, cy + b, zz), (PW - 0.5, 0.08, 0.02), "light")
    for a in (-(PW - 0.6) / 2, (PW - 0.6) / 2):
        p.box((cx + a, cy, zz), (0.08, PH - 0.5, 0.02), "light")
    for i in range(1, 8):
        p.box((cx - (PW - 0.6) / 2 + i * (PW - 0.6) / 8, cy, zz), (0.04, PH - 0.6, 0.02), "light")
    for j in range(1, 4):
        p.box((cx, cy - (PH - 0.6) / 2 + j * (PH - 0.6) / 4, zz), (PW - 0.6, 0.04, 0.02), "light")
    return n


def build_radar(p):
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):
        p.cylinder("y", (0, 6.75, 0), 1.0, 0.3, 16, "steel")
        p.box((0, 6.95, 0), (PW - 0.6, 0.3, 1.0), "trim", bevel=0.04)  # yoke
        for sz in (-1, 1):  # two panels back to back, framed
            p.box((PC[0], PC[1], sz * PZ), (PW, PH, 0.3), "paint", bevel=0.06)
            face(p, sz)
        p.box((0, PC[1], 0), (PW - 1.2, PH - 0.6, 0.8), "trim")  # equipment spine
        for sx in (-1, 1):
            p.box((sx * (PW / 2 + 0.12), PC[1], 0), (0.3, PH + 0.2, 1.4), "trim", bevel=0.04)
        p.box((0, PC[1] + PH / 2 + 0.25, 0), (PW + 0.2, 0.5, 1.6), "paint", bevel=0.06)  # cap housing
        p.box((0, PC[1] + PH / 2 + 0.53, 0), (PW - 0.6, 0.06, 1.2), "team", bevel=0.01)
        for sx in (-1, 1):
            p.box((sx * (PW / 2 + 0.12), PC[1] + PH / 2 + 0.6, 0), (0.24, 0.2, 0.24), "light")


def build_base_and_radar(p):
    build_base(p)
    build_radar(p)


def details_base_and_radar(p):
    details_base(p)
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):
        for sz in (-1, 1):
            bolts(p, (-PW / 2 + 0.2, PC[1] + PH / 2 - 0.12, sz * (PZ + 0.16)),
                  (PW / 2 - 0.2, PC[1] + PH / 2 - 0.12, sz * (PZ + 0.16)), 12, (0, 0, sz))


unit.run(__file__, "ord_tribunal", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base_and_radar, details_base_and_radar)],
         budget=6000,
         previews=[("35", (-26, 21, -31), (0, 5.5, 0), 50),
                   ("80", (0, 48, 7), (0, 4, 0), 50),
                   ("close", (-12, 13, -14), (0, 7.0, 0), 45)])
