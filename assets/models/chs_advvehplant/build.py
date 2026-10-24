"""Advanced Foundry (Chaos factory, T2, footprint 6): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advvehplant/build.py

Designed at the size scale (S-104, M-26: footprint 6, 48 x 48 studs; the
gantry yard about 14.5 tall, over the T1 foundry's 12), bigger and busier
than the T1 Vehicle Plant rather than a rescale. Big shapes first:
- a dark slab of patched plates;
- a long corrugated workshop shed along the left with a sawtooth roof of
  three teeth, each slope a large team plate (amber skylights on the back
  faces), reactive "era" blocks and patch plates on the walls, a hot forge
  stack and a yard door with lit slats (power: pulses while producing);
- a wide open gantry yard: six braced lattice columns, two girders along X
  and two bridge cranes spanning Z that run toward each other along X
  (`trolley1`, `trolley2`, slide, rig.md 9), each with a hook block and an
  emitter (`nano1`, `nano2`, ride with them); the build pad under them
  (team stripes, hazard edges, `buildpad`, exit at -Z down a long apron
  with team edge strips);
- two boom emitters off the front columns (`nano3`, `nano4`);
- a row of four salvage tanks at the back with team caps, amber gauges and
  a pipe manifold, a generator box, a parts conveyor from the shed;
- a container control cabin on legs and a lattice lamp tower at the front.
Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

V = lib.vec
PAD = (6.5, -1.0)
COL_X, COL_Z = (-8.0, 6.5, 21.0), (-12.0, 14.0)
TOP = 12.6  # column tops
SHED = (-23.0, -11.5, -17.0, 21.0)  # x0, x1, z0, z1
TEETH = 3
TANKS = (-6.0, 0.0, 6.0, 12.0)


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V((0, 1, 0)) if abs(n.y) < 0.9 else V((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def lattice_column(p, x, z):
    for dx in (-0.6, 0.6):
        for dz in (-0.6, 0.6):
            p.box((x + dx, (0.6 + TOP) / 2, z + dz), (0.24, TOP - 0.6, 0.24), "trim")
    p.box((x, 0.85, z), (1.9, 0.5, 1.9), "dark", bevel=0.04)
    for k in range(4):
        y = 2.4 + k * 2.6
        p.box((x, y, z), (1.4, 0.14, 1.4), "dark")
        p.obox((x, y + 1.3, z - 0.6), (0.6, 1.3, 0), (0, 0, 1), 2.9, 0.12, 0.12, "steel")
        p.obox((x - 0.6, y + 1.3, z), (0, 1.3, 0.6), (1, 0, 0), 2.9, 0.12, 0.12, "steel")


def build_base(p):
    p.prism_y(octagon(23.6, 1.4), 0.0, 0.6, "dark", bevel=0.14, top_scale=0.994)
    for x, z, w, d in ((-4.0, -18.0, 8.0, 6.0), (16.0, -16.0, 7.0, 5.0), (-6.0, 8.0, 4.0, 9.0), (18.0, 6.0, 5.0, 7.0)):
        p.box((x, 0.62, z), (w, 0.04, d), "trim", bevel=0.01)  # patch plates
    # build pad under the cranes: steel plate, team stripes, hazard edges
    p.box((PAD[0], 0.68, PAD[1]), (13.0, 0.16, 13.0), "trim", bevel=0.04)
    for dx in (-5.6, 5.6):
        p.box((PAD[0] + dx, 0.78, PAD[1]), (1.0, 0.05, 12.2), "team")
    for sz in (-1, 1):
        hazard(p, (PAD[0], 0.79, PAD[1] + sz * 6.2), (1, 0, 0), UP, 12.4, 0.45, stripes=18)
    # apron down to the exit: a ramp, team edge strips, amber guide lights
    p.prism_x([(-23.4, 0.6), (-7.5, 0.6), (-7.5, 0.76)], PAD[0] - 5.6, PAD[0] + 5.6, "steel", bevel=0.03)
    for sx in (-1, 1):
        p.obox((PAD[0] + sx * 4.4, 0.71, -15.4), (0, 0.16, 15.9), (0, 15.9, -0.16), 15.0, 1.0, 0.05, "team")
    p.obox((PAD[0], 0.71, -15.4), (0, 0.16, 15.9), (0, 15.9, -0.16), 15.0, 0.5, 0.05, "hazard")
    for z in (-22.0, -18.0, -14.0, -10.0):
        for sx in (-1, 1):
            p.box((PAD[0] + sx * 5.8, 0.75, z), (0.4, 0.18, 0.4), "light")
    # the gantry yard: lattice columns, girders along X with rails
    for x in COL_X:
        for z in COL_Z:
            lattice_column(p, x, z)
            p.box((x, TOP + 1.45, z), (0.5, 0.36, 0.5), "light")
    for z in COL_Z:
        p.box((6.5, TOP + 0.4, z), (30.6, 0.9, 1.3), "paint", bevel=0.08)
        p.box((6.5, TOP + 0.88, z), (29.0, 0.12, 0.4), "steel")  # crane rail
        hazard(p, (6.5, TOP + 0.4, z - 0.67), (1, 0, 0), (0, 0, -1), 26.0, 0.4, stripes=20)
    for x in COL_X:  # tie beams along Z on the outer columns
        if x != 6.5:
            p.box((x, TOP + 0.3, 1.0), (0.7, 0.6, 25.4), "trim", bevel=0.04)
    # boom emitters off the front columns toward the pad
    for (cx, cz), (tx, tz) in (((-8.0, -12.0), (0.4, -6.2)), ((21.0, -12.0), (12.6, -6.2))):
        a, b = V((cx, 9.4, cz + 0.6)), V((tx, 7.2, tz))
        u = b - a
        p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.55, 0.55, "trim", bevel=0.04)
        p.ocyl(tuple(b), (0, -1, 0), 0.5, 0.45, 12, "dark")
        p.cylinder("y", (b.x, b.y - 0.48, b.z), 0.36, 0.06, 12, "power")
        cable(p, [(cx, 10.4, cz + 0.6), ((cx + tx) / 2, 9.4, (cz + tz) / 2), (tx, 7.7, tz)], r=0.07, kind="dark")
    # corrugated workshop shed with a sawtooth roof
    x0, x1, z0, z1 = SHED
    xc, w = (x0 + x1) / 2, x1 - x0
    p.box((xc, 4.3, (z0 + z1) / 2), (w, 7.4, z1 - z0), "paint", bevel=0.1)
    step = (z1 - z0) / TEETH
    normal = V((0, step, -3.0)).normalized()
    for k in range(TEETH):
        a = z0 + k * step
        b = a + step
        p.prism_x([(a, 8.0), (b, 8.0), (b, 11.0)], x0 - 0.2, x1 + 0.2, "paint", bevel=0.06)
        mid = V((xc, 9.5, (a + b) / 2)) + normal * 0.04
        p.obox(tuple(mid), (1, 0, 0), tuple(normal), w - 1.4, step - 1.6, 0.06, "team", bevel=0.015)
        p.box((xc, 9.6, b + 0.03), (w - 1.6, 1.6, 0.06), "light")  # skylight on the back face
    for i in range(12):  # corrugation ribs on the outer wall
        p.box((x0 - 0.03, 4.3, z0 + 1.4 + i * 3.2), (0.06, 7.0, 0.3), "trim")
    for i in range(4):  # ribs on the front wall
        p.box((x0 + 1.6 + i * 2.8, 4.3, z0 - 0.03), (0.3, 7.0, 0.06), "trim")
    # reactive "era" blocks and patch plates on the yard wall, the yard door
    for z in (-14.0, -11.6, -9.2, 11.0, 13.4, 15.8):
        for y in (2.0, 4.0):
            p.box((x1 + 0.2, y, z), (0.4, 1.6, 2.0), "era", bevel=0.05)
    p.box((x1 + 0.03, 3.4, 1.0), (0.06, 5.6, 9.0), "dark")
    for i in range(4):
        p.box((x1 + 0.08, 1.4 + i * 1.3, 1.0), (0.06, 0.14, 8.6), "power")
    for sz in (-1, 1):
        p.box((x1 + 0.1, 3.5, 1.0 + sz * 4.7), (0.14, 5.8, 0.3), "power")
    p.box((x1 + 0.05, 6.8, 1.0), (0.08, 0.18, 30.0), "light")  # running strip
    p.ocyl((-20.0, 11.0, 17.8), UP, 1.0, 4.4, 12, "steel", radius2=0.8)  # forge stack
    p.cylinder("y", (-20.0, 15.45, 17.8), 0.82, 0.12, 12, "power")
    p.ocyl((-15.6, 11.0, 17.8), UP, 0.7, 2.6, 10, "steel", radius2=0.6)
    p.cylinder("y", (-15.6, 13.65, 17.8), 0.62, 0.1, 10, "power")
    # parts conveyor from the shed door to the pad
    p.box((-5.2, 1.0, 1.0), (12.4, 0.8, 2.4), "trim", bevel=0.05)
    p.box((-5.2, 1.42, 1.0), (12.0, 0.04, 2.0), "grille")
    for x in (-9.0, -5.2, -1.4):
        p.box((x, 1.0, 1.0), (0.12, 0.12, 2.6), "light")
    # salvage tanks at the back with team caps, gauges and a manifold
    for i, x in enumerate(TANKS):
        r, h = (2.2, 5.6) if i % 2 == 0 else (1.9, 4.6)
        p.cylinder("y", (x, 0.6 + h / 2, 19.6), r, h, 16, "paint", bevel=0.05)
        p.ocyl((x, 0.6 + h, 19.6), UP, r, 0.45, 16, "trim", radius2=r * 0.74)
        p.cylinder("y", (x, 1.1 + h, 19.6), r * 0.72, 0.06, 14, "team")
        for y in (1.1, 0.6 + h * 0.62):
            p.cylinder("y", (x, y, 19.6), r + 0.05, 0.2, 16, "dark")
        p.box((x, 0.6 + h * 0.38, 19.6 - r - 0.03), (0.4, h * 0.4, 0.05), "power")
    p.cylinder("x", (3.0, 1.5, 16.6), 0.3, 20.0, 10, "steel")
    for x in TANKS:
        p.cylinder("y", (x, 2.2, 17.4), 0.22, 1.6, 8, "steel")
    p.box((19.6, 2.4, 19.4), (5.0, 3.6, 5.6), "trim", bevel=0.08)  # generator box
    p.box((19.6, 4.25, 19.4), (4.2, 0.06, 4.6), "grille")
    p.box((17.07, 2.0, 19.4), (0.05, 0.5, 3.6), "power")
    # container control cabin on legs (front right)
    for dx in (-1.9, 1.9):
        for dz in (-1.2, 1.2):
            p.box((18.4 + dx, 2.0, -18.2 + dz), (0.3, 2.8, 0.3), "dark")
    p.box((18.4, 4.6, -18.2), (4.6, 2.6, 3.0), "paint", bevel=0.06)
    p.box((18.4, 5.0, -19.72), (3.8, 0.9, 0.05), "glass")
    p.box((18.4, 4.38, -19.74), (3.8, 0.12, 0.05), "light")
    p.box((18.4, 5.94, -18.2), (3.6, 0.06, 2.2), "team")
    # lattice lamp tower (front left of the yard)
    for dx in (-0.7, 0.7):
        for dz in (-0.7, 0.7):
            beam(p, (-10.0 + dx, 0.6, -19.0 + dz), (-10.0 + dx * 0.5, 10.0, -19.0 + dz * 0.5), 0.22, "paint")
    for y in (3.6, 6.8):
        p.box((-10.0, y, -19.0), (1.3, 0.12, 1.3), "dark")
    p.box((-10.0, 10.2, -19.0), (1.6, 0.4, 1.0), "trim", bevel=0.03)
    p.obox((-9.4, 10.0, -19.6), (1, 0, -1), (0.5, -0.4, -0.5), 0.9, 0.5, 0.05, "power")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 22.9, 0.68, sz * 22.9), (0.5, 0.2, 0.5), "light")

    # the bridge cranes: run along X on the girders, a hook block with an emitter
    for name, cx, sign in (("trolley1", -1.0, 1), ("trolley2", 14.0, -1)):
        y = TOP + 1.5
        with p.sub(name, (cx, y, PAD[1]), "slide", (sign, 0, 0), 4.0):
            p.box((cx, y, 1.0), (1.2, 1.1, 27.6), "trim", bevel=0.06)
            p.box((cx, y + 0.57, 1.0), (0.9, 0.05, 22.0), "team")
            for z in COL_Z:
                p.box((cx, y - 0.4, z), (2.2, 0.6, 1.8), "paint", bevel=0.05)
            p.box((cx, y - 1.0, PAD[1]), (1.8, 0.9, 1.8), "paint", bevel=0.05)
            for dz in (-0.5, 0.5):
                p.cylinder("y", (cx, y - 2.6, PAD[1] + dz), 0.05, 2.4, 6, "steel")
            p.box((cx, y - 4.0, PAD[1]), (1.1, 0.6, 1.1), "dark", bevel=0.04)
            p.cylinder("y", (cx, y - 4.35, PAD[1]), 0.38, 0.06, 12, "power")
            p.box((cx, y + 0.1, -12.95), (0.5, 0.3, 0.06), "light")


def details_base(p):
    x1 = SHED[1]
    rivets(p, (x1 + 0.01, 0.9, -16.0), (x1 + 0.01, 0.9, 20.0), 20, (1, 0, 0))
    seam(p, (x1 + 0.01, 6.0, -16.5), (x1 + 0.01, 6.0, -4.0), (1, 0, 0))
    seam(p, (x1 + 0.01, 6.0, 6.0), (x1 + 0.01, 6.0, 20.5), (1, 0, 0))
    bolts(p, (-21.0, 0.601, -23.1), (21.0, 0.601, -23.1), 24, UP)
    for x, z in ((-4.0, -18.0), (16.0, -16.0)):
        rivets(p, (x - 3.0, 0.641, z), (x + 3.0, 0.641, z), 6, UP)


unit.run(__file__, "chs_advvehplant", "chaos", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000, tex=2048,
         previews=[("35", (-56, 45, -67), (0, 6.0, 0), 50),
                   ("80", (0, 124, 22), (0, 4, 0), 50),
                   ("close", (-20, 24, -36), (5.0, 6.5, -2.0), 35),
                   ("back", (52, 42, 62), (0, 6.0, 0), 50)])
