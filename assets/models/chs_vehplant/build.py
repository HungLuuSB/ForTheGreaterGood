"""Vehicle Plant (Chaos factory, T1, footprint 4): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_vehplant/build.py

Redesigned at the size scale (S-104, M-26: footprint 3 -> 4, 32 x 32 studs,
about 12 tall), not rescaled. Big shapes first:
- a patched slab with a dark open yard;
- an open gantry bay framed by four lattice columns and a heavy girder
  crane with a trolley that slides along Z (`trolley`, slide, rig.md 9),
  the build pad under it (team stripes, hazard edges, `buildpad`, exit at
  -Z down a ramp);
- a corrugated workshop shed along the left with a team roof and a hot
  forge vent, a salvage stack with a hot rim;
- fuel tanks and a parts conveyor at the back;
- two crane-like emitter arms over the pad with glowing heads (`nano1`,
  `nano2`) and a third emitter on the trolley's hook block (`nano3`).
Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec
PAD = (3.0, -2.0)
COLUMNS = [(-3.0, -9.0), (9.0, -9.0), (-3.0, 7.0), (9.0, 7.0)]
TOP = 11.2


def lattice_column(p, x, z):
    for dx in (-0.5, 0.5):
        for dz in (-0.5, 0.5):
            p.box((x + dx, (0.6 + TOP) / 2, z + dz), (0.2, TOP - 0.6, 0.2), "trim")
    for k in range(5):
        y = 1.6 + k * 2.0
        p.box((x, y, z), (1.2, 0.12, 1.2), "dark")
        p.obox((x, y + 1.0, z - 0.5), (0.5, 1.0, 0), (0, 0, 1), 2.2, 0.1, 0.1, "dark")


def build_base(p):
    p.prism_y(octagon(15.6, 1.2), 0.0, 0.6, "dark", bevel=0.14, top_scale=0.99)
    # build pad: team stripes, hazard edges, a ramp down to the exit
    p.box((PAD[0], 0.66, PAD[1]), (9.0, 0.12, 9.0), "trim", bevel=0.04)
    for dx in (-3.6, 3.6):
        p.box((PAD[0] + dx, 0.74, PAD[1]), (0.8, 0.05, 8.4), "team")
    for sz in (-1, 1):
        hazard(p, (PAD[0], 0.75, PAD[1] + sz * 4.3), (1, 0, 0), (0, 1, 0), 8.6, 0.35, stripes=15)
    p.prism_x([(-15.4, 0.6), (-6.6, 0.6), (-6.6, 0.78)], PAD[0] - 4.0, PAD[0] + 4.0, "steel", bevel=0.03)
    # the gantry bay: four lattice columns, two girders, cross bracing
    for x, z in COLUMNS:
        lattice_column(p, x, z)
    for x in (-3.0, 9.0):
        p.box((x, TOP + 0.4, -1.0), (1.2, 0.9, 17.2), "paint", bevel=0.08)
        p.box((x, TOP + 0.87, -1.0), (0.9, 0.05, 14.0), "team")
        p.box((x, TOP - 0.1, -1.0), (0.5, 0.12, 16.0), "steel")  # trolley rail
    for z in (-9.0, 7.0):
        p.box((3.0, TOP + 0.4, z), (12.6, 0.6, 0.6), "trim", bevel=0.04)
    # emitter arms: crane-like booms from the columns towards the pad
    for (cx, cz), (tx, tz) in (((-3.0, -9.0), (0.2, -4.6)), ((9.0, 7.0), (5.8, 0.6))):
        a, b = V((cx, 8.6, cz)), V((tx, 6.6, tz))
        u = b - a
        p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.5, 0.5, "trim", bevel=0.04)
        p.ocyl(tuple(b), (0, -1, 0), 0.45, 0.4, 12, "dark")
        p.cylinder("y", (b.x, b.y - 0.45, b.z), 0.32, 0.06, 12, "power")
    # corrugated workshop shed (left) with a team roof and a hot forge vent
    p.prism_x([(-12.0, 0.6), (10.0, 0.6), (10.0, 7.2), (-12.0, 8.4)], -14.6, -6.0, "paint", bevel=0.14)
    for k in range(9):
        p.box((-14.62, 4.0, -10.5 + k * 2.4), (0.05, 6.4, 0.3), "trim")  # corrugation ribs
    p.obox((-10.3, 7.86, -1.0), (0, -0.055, 1), (0, 1, 0.055), 21.0, 7.6, 0.06, "team")
    p.box((-5.98, 2.6, -4.0), (0.05, 2.0, 4.0), "power")
    p.box((-5.98, 4.6, -4.0), (0.05, 0.16, 5.0), "light")
    p.ocyl((-12.8, 7.8, 7.6), UP, 0.9, 4.2, 12, "steel", radius2=0.7)
    p.cylinder("y", (-12.8, 12.05, 7.6), 0.72, 0.12, 12, "power")
    # fuel tanks and a parts conveyor at the back
    for x in (0.0, 4.2, 8.4):
        drum(p, (x, 2.0, 12.2), 1.4, 3.6, "paint", "trim", sides=16, axis="z")
        p.cylinder("z", (x, 2.0, 11.3), 1.44, 0.16, 16, "power")
    p.box((3.0, 1.0, 6.4), (2.2, 0.8, 4.0), "trim", bevel=0.05)
    p.box((3.0, 1.42, 6.4), (1.8, 0.04, 3.8), "grille")
    cable(p, [(0.0, 3.4, 10.8), (-2.0, 4.6, 8.6), (-6.0, 5.0, 6.0)], r=0.14, kind="steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 14.6, 0.7, sz * 14.6), (0.5, 0.2, 0.5), "light")
    for x, z in COLUMNS:
        p.box((x, TOP + 1.0, z), (0.4, 0.3, 0.4), "light")

    # the crane trolley: slides along Z on the girders, a hook block with an emitter
    with p.sub("trolley", (3.0, TOP - 0.5, -2.0), "slide", (0, 0, 1), 6.0):
        p.box((3.0, TOP - 0.4, -2.0), (13.0, 0.7, 1.6), "trim", bevel=0.06)
        p.box((3.0, TOP - 0.05, -2.0), (11.0, 0.05, 1.0), "team")
        p.box((3.0, TOP - 1.1, -2.0), (1.6, 0.9, 1.6), "paint", bevel=0.05)
        for dx in (-0.5, 0.5):
            p.cylinder("y", (3.0 + dx, TOP - 2.4, -2.0), 0.05, 1.8, 6, "steel")
        p.box((3.0, TOP - 3.5, -2.0), (1.0, 0.6, 1.0), "dark", bevel=0.04)
        p.cylinder("y", (3.0, TOP - 3.85, -2.0), 0.35, 0.06, 12, "power")


def details_base(p):
    rivets(p, (-6.0, 1.4, -10.0), (-6.0, 1.4, 8.0), 12, (1, 0, 0))
    seam(p, (-6.0, 6.0, -11.0), (-6.0, 6.0, 9.0), (1, 0, 0))


unit.run(__file__, "chs_vehplant", "chaos", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-40, 32, -48), (0, 5.0, 0), 50),
                   ("80", (0, 66, 10), (0, 3, 0), 50),
                   ("close", (-18, 17, -24), (2.0, 5.0, -2.0), 35)])
