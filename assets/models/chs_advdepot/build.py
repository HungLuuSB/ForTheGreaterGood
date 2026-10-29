"""Great Hoard (Chaos hardened supply storage, T2, footprint 3; S-209,
BAR's coruwadvms): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advdepot/build.py

24 x 24 studs, about 11 tall: the T1 Hoard's tank farm grown into four
squat armored silos round a central pump tower, as BAR's coruwadvms. Big
shapes first: a skid slab; four octagonal silos, each on a sloped armored
skirt with team plates and claw feet splayed round it, a dark riveted tank
body with vent slits and a hatch cap; a tall octagonal pump tower in the
middle with a team cap, its four heavy elbow pipes arching down into the
silos' caps; hazard striping, beacons. Little glow: supply storage reads as
sealed tanks, power storage (chs_advaccumulator) as glowing cells. Chaos
reads rugged and improvised (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

Y0 = 0.6
PODS = [(sx * 5.4, sz * 5.4) for sx in (-1, 1) for sz in (-1, 1)]
TOWER_TOP = 10.6


def silo(p, cx, cz):
    # sloped armored skirt with team plates on its outer faces
    p.prism_y(octagon(4.6, 1.5, cx, cz), Y0, Y0 + 0.7, "trim", bevel=0.08)
    p.prism_y(octagon(4.6, 1.5, cx, cz), Y0 + 0.7, Y0 + 2.4, "paint", bevel=0.12, top_scale=0.74)
    ox, oz = math.copysign(1, cx), math.copysign(1, cz)
    for nx, nz in ((ox, 0), (0, oz)):
        u = (nz, 0, -nx)
        n = (nx * 0.82, 0.58, nz * 0.82)
        p.obox((cx + nx * 3.99, Y0 + 1.57, cz + nz * 3.99), u, n, 3.4, 1.7, 0.05, "team", bevel=0.012)
    dx, dz = ox * 0.7071, oz * 0.7071
    p.obox((cx + dx * 4.77, Y0 + 1.57, cz + dz * 4.77), (dz, 0, -dx), (dx * 0.77, 0.64, dz * 0.77), 1.4, 1.7, 0.05, "team", bevel=0.012)
    # claw feet splayed round it
    for k in range(8):
        t = math.radians(22.5 + 45 * k)
        dx, dz = math.cos(t), math.sin(t)
        if dx * ox + dz * oz < 0.2:
            continue  # only on the outer side
        bx, bz = cx + dx * 4.7, cz + dz * 4.7
        p.obox((bx, Y0 + 0.45, bz), (dx, 0, dz), (0, 1, 0), 1.6, 1.0, 0.9, "dark", bevel=0.08)
        p.obox((bx + dx * 0.7, Y0 + 0.2, bz + dz * 0.7), (dx, -0.3, dz), (0, 1, 0), 0.8, 0.8, 0.5, "steel", bevel=0.04)
    # the dark tank body, vents, a hatch cap
    p.prism_y(octagon(2.9, 1.0, cx, cz), Y0 + 2.4, Y0 + 5.6, "trim", bevel=0.12)
    p.prism_y(octagon(2.9, 1.0, cx, cz), Y0 + 5.6, Y0 + 6.3, "trim", bevel=0.1, top_scale=0.8)
    for nx, nz in ((ox, 0), (0, oz)):
        p.box((cx + nx * 2.92, Y0 + 4.0, cz + nz * 2.92), (1.6 if nz else 0.05, 1.4, 1.6 if nx else 0.05), "grille")
        p.box((cx + nx * 2.94, Y0 + 4.95, cz + nz * 2.94), (1.4 if nz else 0.05, 0.16, 1.4 if nx else 0.05), "light")
    p.cylinder("y", (cx, Y0 + 6.5, cz), 1.2, 0.4, 12, "dark", bevel=0.04)
    p.box((cx, Y0 + 6.75, cz), (1.0, 0.1, 1.0), "team", bevel=0.02)


def build_base(p):
    p.prism_y(octagon(11.7, 0.8), 0.0, Y0, "dark", bevel=0.1, top_scale=0.985)
    hazard(p, (0, Y0 + 0.03, -11.0), (1, 0, 0), UP, 6.0, 0.45, stripes=11)
    for cx, cz in PODS:
        silo(p, cx, cz)
    # the pump tower: dark octagon, armored waist, team cap
    p.prism_y(octagon(2.3, 0.8), Y0, TOWER_TOP - 1.0, "dark", bevel=0.12)
    p.prism_y(octagon(2.6, 0.9), 6.4, 9.2, "paint", bevel=0.12)
    p.prism_y(octagon(2.6, 0.9), TOWER_TOP - 1.0, TOWER_TOP, "paint", bevel=0.12, top_scale=0.82)
    p.prism_y(octagon(1.8, 0.62), TOWER_TOP, TOWER_TOP + 0.06, "team", bevel=0.02)
    for nx, nz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        p.box((nx * 2.62, 7.8, nz * 2.62), (1.2 if nz else 0.05, 0.6, 1.2 if nx else 0.05), "grille")
    # heavy elbow pipes from the tower down into the silo caps
    for cx, cz in PODS:
        d = (cx / abs(cx), cz / abs(cz))
        a = (d[0] * 1.9, 8.4, d[1] * 1.9)
        b = (cx * 0.9, 8.4, cz * 0.9)
        c = (cx, Y0 + 6.5, cz)
        cable(p, [a, (cx * 0.62, 8.6, cz * 0.62), b, (cx * 0.98, 7.9, cz * 0.98), c], r=0.62, kind="trim")
        p.box(a, (1.6, 1.6, 1.6), "dark", bevel=0.08)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 11.0, Y0 + 0.1, sz * 11.0), (0.4, 0.2, 0.4), "light")


def details_base(p):
    for cx, cz in PODS:
        ring(p, (cx, Y0 + 6.31, cz), UP, 1.8)
    rivets(p, (-1.6, 9.21, -2.6), (1.6, 9.21, -2.6), 5, UP)


unit.run(__file__, "chs_advdepot", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-33, 26, -39), (0, 4.0, 0), 50),
                   ("80", (0, 56, 9), (0, 3, 0), 50),
                   ("close", (-16, 14, -20), (0, 4.5, -2.0), 40)])
