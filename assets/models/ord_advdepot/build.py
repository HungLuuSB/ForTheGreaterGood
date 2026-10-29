"""Supply Vault (Order hardened supply storage, T2, footprint 3; S-209,
BAR's armuwadvms): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advdepot/build.py

24 x 24 studs, about 9 tall: the T1 Depot's flank cylinders grown into one
huge armored storage drum, as BAR's armuwadvms. Big shapes first: a
chamfered slab; a big horizontal drum lying across the pad with team bands
and rows of steel loading ports; four heavy stepped armor ribs clamped over
it, capped by two steel tie rods along the crown; a loading bay at the
front between two team-plated buttress feet, a fill gauge over the bay
(power: dims on an energy stall), buttresses at the back; hazard striping
and corner lights. Little glow: supply storage reads as a sealed vault,
power storage (ord_advcapacitor) as glowing cells. Order reads heavy and
clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, octagon, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, seam  # noqa: E402

Y0 = 0.7
DY, DR = 4.5, 3.9  # the drum's axis height and radius
RIBS = (-7.4, -2.6, 2.6, 7.4)
RIB = [(-6.2, Y0), (6.2, Y0), (6.2, 4.0), (4.6, 7.2), (2.2, 8.6), (-2.2, 8.6), (-4.6, 7.2), (-6.2, 4.0)]  # (z, y)


def build_base(p):
    p.prism_y(octagon(11.8, 1.6), 0.0, Y0, "trim", bevel=0.16, top_scale=0.985)
    hazard(p, (0, Y0 + 0.02, -11.0), (1, 0, 0), UP, 6.0, 0.45, stripes=11)
    # the storage drum lying across the pad, on a dark cradle
    p.prism_x([(-4.0, Y0), (4.0, Y0), (3.0, 2.2), (-3.0, 2.2)], -9.0, 9.0, "dark", bevel=0.06)
    drum(p, (0, DY, 0), DR, 18.6, "paint", "trim", sides=24, axis="x")
    for x in (0.0, -5.0, 5.0):
        p.cylinder("x", (x, DY, 0), DR + 0.05, 2.2 if x == 0 else 1.2, 24, "team")
    for x in (-4.0, -1.3, 1.3, 4.0, 6.2, -6.2):  # loading ports along the drum's front and back
        for sz in (-1, 1):
            p.obox((x, DY + 1.6, sz * 3.55), (1, 0, 0), (0, 0.42, sz * 0.91), 0.9, 0.9, 0.18, "steel", bevel=0.04)
    # heavy stepped armor ribs clamped over the drum
    for x in RIBS:
        w = 1.8 if abs(x) > 5 else 1.4
        p.prism_x(RIB, x - w / 2, x + w / 2, "trim", bevel=0.16)
        p.box((x, 8.66, 0), (w - 0.4, 0.12, 4.0), "paint", bevel=0.04)
        for sz in (-1, 1):
            p.obox((x, 5.63, sz * 5.45), (1, 0, 0), (0, 0.45, sz * 0.89), w - 0.5, 2.8, 0.1, "paint", bevel=0.03)
            p.box((x, 2.4, sz * 6.22), (w - 0.5, 2.6, 0.05), "dark")
            p.box((x, 3.6, sz * 6.24), (w - 0.6, 0.14, 0.04), "light")
    # steel tie rods along the crown
    for sz in (-1, 1):
        p.cylinder("x", (0, 9.0, sz * 1.0), 0.28, 16.6, 10, "steel")
    # front loading bay between team-plated buttress feet; fill gauge over it
    p.box((0, 2.4, -6.6), (3.6, 3.4, 1.4), "paint", bevel=0.12)
    p.box((0, 2.2, -7.32), (2.4, 2.4, 0.05), "dark")
    louver(p, (0, 2.0, -7.34), (1, 0, 0), (0, 0, -1), 2.2, 1.6, slats=4)
    p.box((0, 4.3, -7.0), (3.4, 0.5, 0.6), "dark", bevel=0.04)
    for i in range(5):
        p.box((-1.2 + i * 0.6, 4.3, -7.31), (0.48, 0.32, 0.05), "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 5.0, sz * 7.8
            p.prism_x([(z - sz * 1.4, Y0), (z + sz * 2.4, Y0), (z + sz * 2.4, Y0 + 1.0), (z - sz * 1.4, Y0 + 3.6)][::sz],
                      x - 1.5, x + 1.5, "paint", bevel=0.12)
            if sz < 0:
                p.obox((x, Y0 + 2.2, z + sz * 0.45), (1, 0, 0), (0, 0.6, sz * 0.8), 2.6, 2.6, 0.05, "team", bevel=0.015)
            else:
                p.obox((x, Y0 + 2.2, z + sz * 0.45), (1, 0, 0), (0, 0.6, sz * 0.8), 2.0, 1.4, 0.05, "trim", bevel=0.015)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.9, Y0 + 0.08, sz * 10.9), (0.6, 0.14, 0.6), "light")


def details_base(p):
    for x in RIBS:
        rivets(p, (x - 0.4, 8.73, -1.6), (x - 0.4, 8.73, 1.6), 4, UP)
    seam(p, (-9.0, DY + DR + 0.01, 0), (9.0, DY + DR + 0.01, 0), UP)


unit.run(__file__, "ord_advdepot", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-33, 26, -39), (0, 4.0, 0), 50),
                   ("80", (0, 56, 9), (0, 3, 0), 50),
                   ("close", (-16, 14, -20), (0, 4.5, -2.0), 40)])
