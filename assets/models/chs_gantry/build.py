"""Experimental Gantry (Chaos T3 factory, footprint 7; S-209, BAR corgant):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_gantry/build.py

From its blockout, 56 x 56 studs, about 17 tall: the factory that builds
the Juggernaut. Big shapes first: a patched slab; a huge raised assembly
platform whose floor is two armored doors split along a zigzag seam (rows
of vents and hazard tabs on them; `buildpad` at its centre facing the exit
at -Z), a wide ramp down at the front; low armored side walls clad in
reactive blocks, each carrying three heavy emitter heads (team-coloured
housings, glowing lenses facing the floor: `nano1..6`, tools/anchors.py);
a stepped bunker at the back with a pod (a lit slit, a team roof) and two
more heads (`nano7`, `nano8`); hazard plates on the wall ends, cable runs,
team plates on the slab, amber beacons. Chaos reads crude and exposed
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, seam  # noqa: E402

PY = 4.0  # the platform's top
PZ = -3.0  # the pad's centre
WX = 23.5  # the side walls' centre
HX = 20.4  # the emitter heads' x
HY = 9.6  # the emitter heads' height
HEAD_Z = (-14.0, -3.0, 8.0)
Z0, Z1 = PZ - 14.0, PZ + 14.0  # the doors' ends


def head(p, c, facing):
    """A heavy emitter head: a team-coloured housing on a dark mount with
    a glowing lens towards `facing`."""
    x, y, z = c
    fx, fz = facing
    if fx:
        p.box((x, y, z), (4.0, 3.0, 3.6), "paint", bevel=0.18)
        p.box((x, y + 1.53, z), (3.2, 0.06, 2.8), "team", bevel=0.02)
        p.box((x - fx * 0.4, y, z + 1.82), (2.6, 2.0, 0.05), "team")
        p.box((x - fx * 0.4, y, z - 1.82), (2.6, 2.0, 0.05), "team")
        p.cylinder("x", (x + fx * 2.0, y, z), 0.95, 0.4, 12, "trim")
        p.cylinder("x", (x + fx * 2.25, y, z), 0.7, 0.12, 12, "power")
        p.box((x - fx * 2.1, y - 0.6, z), (0.6, 1.2, 2.4), "dark")
    else:
        p.box((x, y, z), (4.0, 3.0, 3.4), "paint", bevel=0.18)
        p.box((x, y + 1.53, z), (3.2, 0.06, 2.6), "team", bevel=0.02)
        for sx in (-1, 1):
            p.box((x + sx * 2.02, y, z + 0.4), (0.05, 2.0, 2.4), "team")
        p.cylinder("z", (x, y, z + fz * 1.8), 0.95, 0.4, 12, "trim")
        p.cylinder("z", (x, y, z + fz * 2.05), 0.7, 0.12, 12, "power")


def build_base(p):
    p.prism_y(octagon(27.8, 3.0), 0.0, 0.5, "dark", bevel=0.12, top_scale=0.99)
    for sx in (-1, 1):
        p.box((sx * 21.0, 0.53, -23.0), (5.0, 0.06, 5.0), "team", bevel=0.02)
        p.box((sx * 25.6, 0.7, -25.6), (0.7, 0.4, 0.7), "light")
        p.box((sx * 25.6, 0.7, 25.6), (0.7, 0.4, 0.7), "light")
    p.box((-12.0, 0.52, 24.0), (4.0, 0.04, 3.0), "steel", bevel=0.01)
    # the platform, its ramp and the split floor doors
    p.prism_y(rect(0, -2.0, 20.0, 18.0), 0.5, PY - 0.1, "trim", bevel=0.18)
    p.prism_y(rect(0, PZ, 19.4, 14.4), PY - 0.1, PY, "dark")
    p.prism_x([(-27.4, 0.5), (-20.0, 0.5), (-20.0, PY - 0.1)], -11.0, 11.0, "trim", bevel=0.06)
    hazard(p, (0, 0.53, -27.0), (1, 0, 0), UP, 22.0, 0.7, stripes=28)
    for i in range(7):
        za, zb = Z0 + i * 4.0, Z0 + (i + 1) * 4.0
        xa, xb = (1.2 if i % 2 == 0 else -1.2), (-1.2 if i % 2 == 0 else 1.2)
        p.prism_y([(-19.2, za), (xa - 0.18, za), (xb - 0.18, zb), (-19.2, zb)], PY, PY + 0.22, "trim", bevel=0.03)
        p.prism_y([(xa + 0.18, za), (19.2, za), (19.2, zb), (xb + 0.18, zb)], PY, PY + 0.22, "trim", bevel=0.03)
    for sx in (-1, 1):
        for z in (PZ - 10.0, PZ - 5.0, PZ, PZ + 5.0, PZ + 10.0):
            p.box((sx * 8.0, PY + 0.24, z), (4.4, 0.05, 1.3), "grille")
            p.box((sx * 13.6, PY + 0.24, z), (2.6, 0.05, 1.3), "grille")
        for z in (PZ - 12.6, PZ + 12.6):
            hazard(p, (sx * 16.4, PY + 0.24, z), (1, 0, 0), UP, 3.2, 0.7, stripes=4)
    # the side walls: reactive blocks outside, three emitter heads on each
    for sx in (-1, 1):
        x = sx * WX
        p.prism_y(rect(x, -2.0, 3.5, 16.0), 0.5, 8.0, "paint", bevel=0.2)
        p.prism_y(rect(x, -2.0, 3.5, 16.0), 8.0, 8.6, "paint", bevel=0.2, top_scale=0.92)
        for z in (-15.0, -10.0, -5.0, 0.0, 5.0, 10.0):
            p.box((x + sx * 3.62, 4.0, z + 1.5), (0.4, 4.0, 4.2), "era", bevel=0.05)
        p.box((x + sx * 3.84, 7.0, -2.0), (0.06, 0.2, 28.0), "light")
        hazard(p, (x, 4.4, -18.04), (1, 0, 0), (0, 0, -1), 6.4, 4.0, stripes=6)
        louver(p, (x - sx * 3.52, 6.4, -2.0), (0, 0, 1), (-sx, 0, 0), 10.0, 1.6, slats=4)
        for z in HEAD_Z:
            p.box((sx * (HX + 1.6), 8.85, z), (2.6, 0.6, 2.6), "dark", bevel=0.04)
            head(p, (sx * (HX + 0.6), HY + 0.4, z), (-sx, 0))
        cable(p, [(x, 8.7, -16.0), (x - sx * 1.0, 8.7, 14.0)], r=0.26, kind="steel")
    # the bunker at the back, its pod and heads
    p.prism_x([(16.0, 0.5), (27.4, 0.5), (27.4, 10.4), (25.8, 11.0), (18.4, 11.0), (16.0, 9.0)], -21.0, 21.0, "paint", bevel=0.22)
    p.box((0, 6.0, 15.97), (30.0, 3.0, 0.05), "dark")
    p.box((0, 7.7, 15.95), (30.0, 0.25, 0.05), "light")
    for sx in (-1, 1):
        louver(p, (sx * 14.0, 6.0, 15.94), (1, 0, 0), (0, 0, -1), 10.0, 2.4, slats=4)
        p.box((sx * 17.0, 11.03, 22.6), (6.0, 0.06, 6.0), "team", bevel=0.02)
        p.box((sx * 7.5, 10.5, 15.6), (3.0, 1.0, 3.0), "dark", bevel=0.04)
        head(p, (sx * 7.5, 12.0, 15.4), (0, -1))
    p.prism_y(rect(0, 21.0, 6.0, 4.0), 11.0, 16.5, "paint", bevel=0.18, top_scale=0.9)
    p.box((0, 16.53, 21.0), (8.0, 0.06, 5.0), "team", bevel=0.02)
    p.box((0, 14.0, 16.95), (8.0, 1.2, 0.05), "power")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 4.0, 18.0, 23.6), 0.6, 3.6, 10, "steel")
        p.cylinder("y", (sx * 4.0, 19.85, 23.6), 0.66, 0.12, 10, "power")
    cable(p, [(-20.0, 1.6, 16.0), (-23.0, 1.6, 14.0), (-23.0, 1.6, 12.0)], r=0.3, kind="dark")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * (WX + 3.52), 7.6, -16.0), (sx * (WX + 3.52), 7.6, 12.0), 16, (sx, 0, 0))
        seam(p, (sx * 19.2, PY + 0.23, Z0 + 0.4), (sx * 19.2, PY + 0.23, Z1 - 0.4), UP)
    rivets(p, (-14.0, 1.2, -20.02), (14.0, 1.2, -20.02), 16, (0, 0, -1))
    seam(p, (-20.0, 9.6, 15.96), (20.0, 9.6, 15.96), (0, 0, -1))


unit.run(__file__, "chs_gantry", "chaos", footprint=7,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000,
         previews=[("35", (-76, 60, -90), (0, 6.0, 0), 50),
                   ("80", (0, 124, 20), (0, 4, 0), 50),
                   ("close", (-36, 32, -44), (0, 8.0, -4.0), 35)])
