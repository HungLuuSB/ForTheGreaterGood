"""Advanced Supply Converter (Order T2 converter, footprint 3; S-209, BAR's
armmmkr): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advconverter/build.py

24 x 24 studs, about 9 tall: the T1 converter's coil column laid down and
grown into a coil tunnel, as BAR's armmmkr. Big shapes first: a chamfered
slab with hazard striping; a long arched hull across the pad (left to
right) ribbed by heavy armored arches, with coil windings and glowing bands between
them (`coil`, pulse, rig.md 9) over a dark core; armored end blocks at both
ends with sloped tops, team panels and lit vents; four splayed feet with
team plates; clamp blocks and a steel spine on the crown; intake pipes;
corner lights. Order reads heavy and clean (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, rect, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, seam  # noqa: E402

Y0 = 0.7  # the slab's top
RIBS = (-7.0, -3.5, 0.0, 3.5, 7.0)
BANDS = (-5.25, -1.75, 1.75, 5.25)


def arch(r, h, y0=Y0, steps=12):
    """A half-ellipse side profile (z, y): r wide either side, h tall."""
    pts = []
    for i in range(steps + 1):
        t = math.pi * i / steps
        pts.append((-math.cos(t) * r, y0 + math.sin(t) * h))
    return pts


def build_base(p):
    p.prism_y(octagon(11.8, 1.6), 0.0, Y0, "trim", bevel=0.16, top_scale=0.985)
    hazard(p, (0, Y0 + 0.02, -10.6), (1, 0, 0), UP, 9.0, 0.5, stripes=16)
    # the dark core and the armored arches
    p.prism_x(arch(5.0, 6.4), -7.6, 7.6, "dark")
    for x in RIBS:
        w = 1.1 if abs(x) > 6 else 0.8
        p.prism_x(arch(6.0, 7.5), x - w / 2, x + w / 2, "paint", bevel=0.12)
        p.prism_x(arch(6.25, 7.75), x - w / 2 + 0.2, x + w / 2 - 0.2, "trim", bevel=0.06)
    # crown: a steel spine and clamp blocks
    p.cylinder("x", (0, Y0 + 7.95, 0), 0.32, 14.6, 10, "steel")
    for x in (-3.5, 3.5):
        p.box((x, Y0 + 7.9, 0), (1.4, 0.9, 1.6), "trim", bevel=0.08)
        p.box((x, Y0 + 8.37, 0), (0.9, 0.05, 1.0), "light")
    # end blocks: sloped tops, team panels, lit vents
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 7.6, sx * 10.6))
        p.prism_x([(-4.6, Y0), (4.6, Y0), (4.6, 3.4), (3.0, 5.0), (-3.0, 5.0), (-4.6, 3.4)], x0, x1, "paint", bevel=0.18)
        p.box((sx * 9.1, 5.03, 0), (2.4, 0.06, 5.2), "team", bevel=0.02)
        p.box((sx * 10.62, 2.6, 0), (0.06, 2.4, 6.0), "team", bevel=0.02)
        p.box((sx * 10.63, 4.15, 0), (0.05, 0.18, 6.4), "light")
        for sz in (-1, 1):
            louver(p, (sx * 9.1, 2.6, sz * 4.62), (1, 0, 0), (0, 0, sz), 2.0, 1.4, slats=3)
            p.box((sx * 9.1, 4.2, sz * 4.63), (2.0, 0.22, 0.05), "power")
        # splayed feet with team plates
        for sz in (-1, 1):
            z = sz * 6.6
            p.prism_x([(z - sz * 1.6, Y0), (z + sz * 2.0, Y0), (z + sz * 2.0, Y0 + 0.9), (z - sz * 1.6, Y0 + 2.2)][::sz],
                      sx * 8.0 - 1.4, sx * 8.0 + 1.4, "trim", bevel=0.1)
            p.obox((sx * 8.0, Y0 + 1.6, z + sz * 0.1), (1, 0, 0), (0, 0.84, sz * 0.54), 2.4, 1.6, 0.05, "team", bevel=0.015)
    # intake pipes along the hull's foot into the end blocks
    for sz in (-1, 1):
        p.cylinder("x", (0, 1.15, sz * 5.6), 0.32, 15.2, 10, "steel")
        for x in BANDS:
            p.box((x, 1.15, sz * 5.6), (0.4, 0.9, 0.9), "trim", bevel=0.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.9, Y0 + 0.08, sz * 10.9), (0.6, 0.14, 0.6), "light")

    # the coil bands: wide glowing arches between the ribs, pulsing
    with p.sub("coil", (0.0, Y0, 0.0), "pulse", (0, 1, 0)):
        for x in BANDS:
            p.prism_x(arch(5.3, 6.7), x - 1.25, x + 1.25, "steel")
            for k in (-0.6, 0.6):
                p.band_x(arch(5.36, 6.81, Y0 - 0.05), arch(5.2, 6.65, Y0 - 0.05), x + k - 0.17, x + k + 0.17, "power")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 10.62, 1.2, -4.0), (sx * 10.62, 1.2, 4.0), 8, (sx, 0, 0))
        seam(p, (sx * 9.1, 3.4, -4.62), (sx * 9.1, 3.4, 4.62), UP)
    seam(p, (-7.0, Y0 + 0.4, -5.6), (7.0, Y0 + 0.4, -5.6), (0, 0, -1))


unit.run(__file__, "ord_advconverter", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-33, 26, -39), (0, 4.0, 0), 50),
                   ("80", (0, 56, 9), (0, 3, 0), 50),
                   ("close", (-16, 14, -20), (0, 4.5, -1.0), 40)])
