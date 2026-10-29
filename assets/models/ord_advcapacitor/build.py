"""Grid Reservoir (Order hardened power storage, T2, footprint 3; S-209,
BAR's armuwadves): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advcapacitor/build.py

24 x 24 studs, about 11 tall: the Capacitor Bank grown into twin armored
cell towers, as BAR's armuwadves. Big shapes first: a chamfered slab; two
tall round towers side by side, each wrapped in vertical armor ribs with
team stripes over stacks of glowing charge cells (`cells`, pulse, rig.md
9: the charge level reads from far), capped by a steel collar round a
glowing top; a waist block joining them; flared side fins with team
panels; a front terminal plate with a team panel and a cable hatch; hazard
striping, corner lights. Power storage reads as glowing cells, supply
storage (ord_advdepot) as a sealed vault. Order reads heavy and clean
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, octagon, prism_z, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

Y0 = 0.7
TX, TR = 3.7, 3.9  # towers' x offset and radius
TOP = 10.4
CELLS = (2.4, 4.2, 6.0, 7.8)  # cell band centres


def ribs(p, cx, sx):
    """Vertical armor ribs round a tower, none on the side facing the other."""
    for k in range(10):
        t = 2 * math.pi * (k + 0.5) / 10
        dx, dz = math.cos(t), math.sin(t)
        if dx * sx < -0.55:
            continue
        x, z = cx + dx * (TR + 0.05), dz * (TR + 0.05)
        p.obox((x, (Y0 + TOP) / 2 - 0.2, z), (0, 1, 0), (dx, 0, dz), TOP - Y0 - 0.8, 1.1, 0.7, "paint", bevel=0.1)
        p.obox((x + dx * 0.36, (Y0 + TOP) / 2 - 0.2, z + dz * 0.36), (0, 1, 0), (dx, 0, dz), TOP - Y0 - 2.4, 0.4, 0.05, "team")


def build_base(p):
    p.prism_y(octagon(11.8, 1.6), 0.0, Y0, "trim", bevel=0.16, top_scale=0.985)
    hazard(p, (0, Y0 + 0.02, -11.0), (1, 0, 0), UP, 6.0, 0.45, stripes=11)
    for sx in (-1, 1):
        cx = sx * TX
        p.cylinder("y", (cx, (Y0 + TOP) / 2, 0), TR - 0.2, TOP - Y0, 20, "dark")
        ribs(p, cx, sx)
        # foot ring, top collar, glowing top
        p.cylinder("y", (cx, Y0 + 0.4, 0), TR + 0.55, 0.8, 20, "trim", bevel=0.06)
        p.ocyl((cx, TOP - 0.6, 0), UP, TR + 0.3, 0.9, 20, "trim", radius2=TR - 0.3)
        p.cylinder("y", (cx, TOP + 0.36, 0), TR - 0.35, 0.12, 20, "steel")
        p.cylinder("y", (cx, TOP + 0.45, 0), 1.8, 0.1, 18, "power")
        p.cylinder("y", (cx, TOP + 0.44, 0), 2.3, 0.08, 18, "dark")
    # the waist block joining the towers, front and back
    for sz in (-1, 1):
        p.prism_x([(sz * 1.6, Y0), (sz * 3.4, Y0), (sz * 3.4, 6.0), (sz * 2.4, 8.4), (sz * 1.6, 8.4)], -TX, TX, "paint", bevel=0.12)
        p.box((0, 4.6, sz * 3.42), (2.6, 1.6, 0.05), "team", bevel=0.01)
    # flared side fins with team panels
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 8.6, sz * 3.0
            prism_z(p, [(sx * 7.0, Y0), (sx * 11.0, Y0), (sx * 11.0, Y0 + 0.8), (sx * 7.0, 4.4)], z - 0.9, z + 0.9, "trim", bevel=0.1)
            p.obox((sx * 9.02, 2.98, z), (0, 0, 1), (sx * 0.59, 0.81, 0), 1.4, 3.6, 0.05, "team", bevel=0.01)
    # the front terminal: a plate with a team panel and a cable hatch
    p.prism_x([(-6.4, Y0), (-4.6, Y0), (-4.6, 3.0), (-5.6, 3.0)], -2.0, 2.0, "trim", bevel=0.1)
    p.obox((0, 2.1, -5.95), (1, 0, 0), (0, 0.6, -0.8), 2.8, 1.6, 0.05, "team", bevel=0.01)
    p.cylinder("z", (-6.4, 1.6, -4.4), 0.9, 0.5, 14, "steel", bevel=0.04)
    p.cylinder("z", (-6.4, 1.6, -4.68), 0.5, 0.1, 12, "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 10.9, Y0 + 0.08, sz * 10.9), (0.6, 0.14, 0.6), "light")

    # charge cells: stacked glowing bands under the ribs, pulsing
    with p.sub("cells", (0.0, Y0, 0.0), "pulse", (0, 1, 0)):
        for sx in (-1, 1):
            cx = sx * TX
            for y in CELLS:
                p.cylinder("y", (cx, y, 0), TR - 0.02, 0.7, 20, "power", cap_kinds=("dark", "dark"))
                p.cylinder("y", (cx, y + 0.55, 0), TR + 0.02, 0.4, 20, "steel")
                p.cylinder("y", (cx, y - 0.55, 0), TR + 0.02, 0.4, 20, "steel")


def details_base(p):
    for sx in (-1, 1):
        ring(p, (sx * TX, TOP + 0.43, 0), UP, 2.9)
    seam(p, (-TX, 8.41, -2.0), (TX, 8.41, -2.0), UP)
    rivets(p, (-1.6, 3.05, -5.4), (1.6, 3.05, -5.4), 5, UP)


unit.run(__file__, "ord_advcapacitor", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-33, 26, -39), (0, 5.0, 0), 50),
                   ("80", (0, 56, 9), (0, 3, 0), 50),
                   ("close", (-16, 14, -20), (0, 5.5, -1.0), 40)])
