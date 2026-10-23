"""Depot (Order storage, T1 structure, footprint 2): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_depot/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
low: about 5 tall), not rescaled: a storage vault. Big shapes first: a
chamfered slab, a long armored vault with sloped sides and a large team
roof, two heavy loading hatches and a loading dock with a door at the back,
a fill gauge across the front slope (power: dims on an energy stall), two
armored capacitor cylinders lying along the flanks with team bands and
glowing charge rings, hazard striping and corner lights. Order reads heavy
and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

VAULT = [(-3.6, -5.2), (3.6, -5.2), (4.4, -4.4), (4.4, 4.4), (3.6, 5.2), (-3.6, 5.2), (-4.4, 4.4), (-4.4, -4.4)]


def build_base(p):
    p.prism_y(octagon(7.8, 1.0), 0.0, 0.6, "trim", bevel=0.12, top_scale=0.985)
    p.prism_y(VAULT, 0.6, 2.4, "paint", bevel=0.18)
    p.prism_y(VAULT, 2.4, 4.4, "paint", bevel=0.18, top_scale=0.72)
    p.box((0, 4.43, -0.6), (4.4, 0.06, 5.0), "team", bevel=0.02)
    for sx in (-1, 1):  # loading hatches on the roof's back
        p.box((sx * 1.1, 4.55, 2.6), (1.6, 0.3, 1.4), "steel", bevel=0.05)
        p.box((sx * 1.1, 4.71, 2.6), (1.1, 0.04, 0.14), "light")
    # fill gauge on the front slope: a dark window with lit segments
    p.obox((0, 3.35, -4.62), (1, 0, 0), (0, 0.6, -0.8), 5.0, 0.8, 0.06, "dark")
    for i in range(6):
        p.obox((-2.05 + i * 0.82, 3.37, -4.66), (1, 0, 0), (0, 0.6, -0.8), 0.7, 0.6, 0.05, "power")
    p.box((0, 1.5, -5.22), (4.0, 0.14, 0.05), "light")
    # loading dock at the back with a door and a ramp
    p.box((0, 1.4, 5.7), (3.6, 1.6, 1.0), "trim", bevel=0.08)
    p.box((0, 1.5, 6.22), (2.4, 1.1, 0.05), "dark")
    p.prism_x([(6.2, 0.6), (7.6, 0.6), (6.2, 1.0)], -1.4, 1.4, "dark", bevel=0.03)
    hazard(p, (0, 2.3, 6.24), (1, 0, 0), (0, 0, 1), 2.6, 0.25, stripes=6)
    # capacitor cylinders along the flanks: team bands, glowing charge rings
    for sx in (-1, 1):
        drum(p, (sx * 5.9, 1.55, 0.0), 0.95, 8.4, "paint", "trim", sides=18, axis="z")
        for dz in (-2.6, 0.0, 2.6):
            p.cylinder("z", (sx * 5.9, 1.55, dz), 0.99, 0.1, 18, "power")
        p.cylinder("z", (sx * 5.9, 1.55, -1.3), 0.98, 1.1, 18, "team")
        for dz in (-3.0, 3.0):
            p.box((sx * 5.9, 0.75, dz), (1.6, 0.35, 0.5), "dark")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.2, 0.68, sz * 7.2), (0.4, 0.1, 0.4), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 4.42, 1.4, -3.8), (sx * 4.42, 1.4, 3.8), 8, (sx, 0, 0))
        seam(p, (sx * 4.42, 2.4, -4.2), (sx * 4.42, 2.4, 4.2), (sx, 0, 0))
    seam(p, (-2.4, 4.42, 1.6), (2.4, 4.42, 1.6), UP)


unit.run(__file__, "ord_depot", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 2.5, 0), 50),
                   ("80", (0, 36, 6), (0, 2, 0), 50),
                   ("close", (-11, 9, -13), (0, 3.0, 0), 35)])
