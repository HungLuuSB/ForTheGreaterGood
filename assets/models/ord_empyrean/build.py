"""Empyrean (Order advanced rearm pad, T2 structure, footprint 4, two bays;
S-166): mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_empyrean/build.py

From its approved blockout (2026-10-26): the Aerie grown up. Big shapes
first: a chamfered armored apron with hazard borders, a centre line and
edge lights; two landing bays, each a dark pad in a team ring with lit
markings; a blast deflector leaning back behind each bay; a rearm pedestal
with a boom and a glowing head beside each bay; fuel blocks with team tops;
between the bays at the back an armored control tower with a team band, a
glazed cab under a roof, a radar mast with an array and a beacon. Order
reads clean and heavy (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

BAYS = (-7.6, 7.6)
BZ = -1.4  # the bays' centre z


def build_base(p):
    p.prism_y(octagon(15.0, 1.8), 0.0, 0.8, "trim", bevel=0.14, top_scale=0.99)
    for sz in (-1, 1):
        hazard(p, (0, 0.82, sz * 14.4), (1, 0, 0), UP, 26.0, 0.6, stripes=40)
    p.box((0, 0.83, 3.0), (0.5, 0.06, 18.0), "dark")
    for x in BAYS:
        sx = 1 if x > 0 else -1
        p.cylinder("y", (x, 0.86, BZ), 6.4, 0.15, 36, "team")
        p.cylinder("y", (x, 0.9, BZ), 6.2, 0.2, 36, "dark")
        p.cylinder("y", (x, 1.01, BZ), 5.4, 0.02, 36, "light")
        p.cylinder("y", (x, 1.02, BZ), 5.25, 0.03, 36, "dark")
        for dx in (-1.4, 1.4):  # the H mark
            p.box((x + dx, 1.04, BZ), (0.6, 0.04, 5.2), "paint")
        p.box((x, 1.04, BZ), (2.8, 0.04, 0.6), "paint")
        # blast deflector leaning back behind the bay
        p.prism_x([(5.8, 0.8), (7.4, 0.8), (7.4, 1.2), (6.2, 3.2)], x - 5.0, x + 5.0, "paint", bevel=0.08)
        p.box((x, 2.1, 6.95), (8.0, 0.14, 0.05), "light")
        # rearm pedestal, boom and its glowing head
        p.prism_y(rect(sx * 14.0, BZ, 0.8, 0.8), 0.8, 3.8, "paint", bevel=0.08)
        p.box((sx * 12.0, 3.9, BZ), (4.4, 0.6, 0.7), "trim", bevel=0.05)
        p.box((sx * 9.8, 3.7, BZ), (0.8, 0.8, 0.8), "dark", bevel=0.05)
        p.box((sx * 9.8, 3.25, BZ), (0.5, 0.06, 0.5), "power")
        # fuel block with a team top
        p.box((sx * 12.4, 1.7, 10.4), (3.2, 1.8, 2.4), "paint", bevel=0.1)
        p.box((sx * 12.4, 2.63, 10.4), (2.4, 0.06, 1.6), "team", bevel=0.01)
        p.box((sx * 12.4, 1.6, 9.18), (2.0, 0.14, 0.05), "power")
        # edge lights
        for z in (-14.2, 4.4, 14.2):
            p.box((sx * 14.2, 0.95, z), (0.45, 0.2, 0.45), "light")
        p.box((sx * 1.2, 0.95, -14.2), (0.45, 0.2, 0.45), "light")
    # the control tower, its team band, the cab, mast, array and beacon
    p.prism_y(rect(0, 11.4, 2.2, 2.2), 0.8, 7.8, "paint", bevel=0.12)
    p.box((0, 3.2, 11.4), (4.5, 1.6, 4.5), "team", bevel=0.02)
    p.box((0, 1.8, 9.18), (1.4, 2.0, 0.05), "dark")
    louver(p, (2.22, 5.4, 11.4), (0, 0, 1), (1, 0, 0), 2.6, 1.0, slats=3)
    p.prism_y(rect(0, 11.4, 2.7, 2.7), 7.8, 9.6, "glass", top_scale=1.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 2.7, 8.7, 11.4 + sz * 2.7), (0.2, 1.8, 0.2), "trim")
    p.prism_y(rect(0, 11.4, 3.0, 3.0), 9.6, 10.1, "dark", bevel=0.06, top_scale=0.9)
    p.cylinder("y", (1.8, 11.6, 12.6), 0.2, 3.0, 8, "steel")
    p.box((1.8, 13.2, 12.6), (2.6, 0.9, 0.2), "trim", bevel=0.03)
    p.box((1.8, 13.2, 12.48), (2.2, 0.15, 0.03), "light")
    p.box((-2.0, 10.3, 13.0), (0.4, 0.4, 0.4), "light")


def details_base(p):
    for x in BAYS:
        ring(p, (x, 1.05, BZ), UP, 4.6)
    rivets(p, (-2.1, 3.0, 9.18), (2.1, 3.0, 9.18), 5, (0, 0, -1))
    seam(p, (-14.5, 0.81, 0.0), (14.5, 0.81, 0.0), UP)


unit.run(__file__, "ord_empyrean", "order", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-40, 32, -48), (0, 3.0, 0), 50),
                   ("80", (0, 66, 10), (0, 2, 0), 50),
                   ("close", (-18, 14, -24), (0, 3.0, 2.0), 38)])
