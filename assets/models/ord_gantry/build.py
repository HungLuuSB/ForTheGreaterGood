"""Experimental Gantry (Order T3 factory, footprint 7; S-209, BAR armshltx):
mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_gantry/build.py

From its blockout, 56 x 56 studs, about 33 tall: the factory that builds
the Titan. Big shapes first: a chamfered slab; at the back a tall armored
hall (a big lit door, louvred side wings, team roof plates) under a
stepped command tower (a glowing screen between hazard plates, twin vent
stacks, a team roof); in front a big pad (a diamond-plate field framed by
hazard striping, `buildpad` at its centre facing the exit at -Z) between
two tall emitter towers on heavy sloped feet with team panels, each
carrying a beam over the pad with three glowing emitter heads (`nano1..6`,
tools/anchors.py), three antennas on the right tower. Order reads heavy
and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from towers import antenna, louver  # noqa: E402
from unit import UP, seam  # noqa: E402

PZ = -9.0  # the pad's centre
GY = 26.0  # the emitter beams' height
TX = 16.5  # the towers' x
BX = 13.6  # the emitter beams' x
EMIT_Z = (PZ - 6.0, PZ, PZ + 6.0)


def build_base(p):
    p.prism_y(octagon(27.8, 3.0), 0.0, 0.6, "trim", bevel=0.16, top_scale=0.99)
    # the pad: a diamond-plate field framed by hazard striping, an apron to the front edge
    p.prism_y(rect(0, PZ, 13.0, 13.0), 0.6, 0.72, "dark", bevel=0.04)
    p.box((0, 0.75, PZ), (20.0, 0.05, 20.0), "grille")
    for s in (-1, 1):
        hazard(p, (0, 0.76, PZ + s * 10.6), (1, 0, 0), UP, 21.8, 0.6, stripes=30)
        hazard(p, (s * 10.6, 0.76, PZ), (0, 0, 1), UP, 20.4, 0.6, stripes=28)
        p.box((s * 12.6, 0.78, PZ), (0.2, 0.05, 24.0), "light")
    p.prism_x([(-27.6, 0.6), (PZ - 13.0, 0.6), (PZ - 13.0, 0.72), (-25.0, 0.72)], -10.0, 10.0, "trim", bevel=0.04)
    p.box((0, 0.74, -24.0), (16.0, 0.04, 2.0), "steel")
    # the hall: a big lit door, roof team plates, louvred side wings
    p.prism_x([(3.0, 0.6), (27.0, 0.6), (27.0, 15.6), (25.6, 16.6), (6.0, 16.6), (3.0, 14.0)], -19.0, 19.0, "paint", bevel=0.24)
    p.box((0, 6.6, 2.97), (20.0, 12.0, 0.05), "dark")
    p.box((0, 12.9, 2.95), (20.0, 0.4, 0.05), "light")
    for sx in (-1, 1):
        p.box((sx * 10.3, 6.6, 2.95), (0.4, 12.0, 0.05), "power")
        p.box((sx * 12.5, 16.63, 17.0), (10.0, 0.06, 14.0), "team", bevel=0.02)
        p.prism_x([(5.0, 0.6), (24.0, 0.6), (24.0, 9.6), (22.6, 10.6), (7.6, 10.6), (5.0, 8.0)], *sorted((sx * 19.0, sx * 23.0)), "paint", bevel=0.14)
        louver(p, (sx * 23.02, 5.6, 14.0), (0, 0, 1), (sx, 0, 0), 8.0, 2.2, slats=5)
        p.box((sx * 23.03, 9.0, 14.0), (0.05, 0.18, 12.0), "light")
        hazard(p, (sx * 21.0, 3.0, 4.97), (1, 0, 0), (0, 0, -1), 3.6, 4.4, stripes=4)
    # the command tower: a lit screen between hazard plates, twin stacks, a team roof
    p.prism_x([(9.0, 16.6), (23.0, 16.6), (23.0, 27.6), (21.6, 28.6), (12.0, 28.6), (9.0, 25.0)], -7.0, 7.0, "paint", bevel=0.2)
    p.box((0, 21.0, 8.97), (6.0, 4.2, 0.05), "dark")
    p.box((0, 21.0, 8.94), (5.0, 3.4, 0.05), "power")
    for sx in (-1, 1):
        hazard(p, (sx * 5.0, 21.0, 8.97), (0, 1, 0), (0, 0, -1), 6.0, 2.6, stripes=6)
        p.cylinder("y", (sx * 2.4, 30.6, 19.0), 1.5, 4.0, 14, "steel", bevel=0.04)
        p.cylinder("y", (sx * 2.4, 32.65, 19.0), 1.2, 0.1, 12, "dark")
        p.cylinder("y", (sx * 2.4, 31.4, 19.0), 1.56, 0.4, 14, "trim")
        p.box((sx * 7.03, 22.0, 16.0), (0.05, 0.2, 12.0), "light")
    p.box((0, 28.63, 17.5), (10.0, 0.06, 9.0), "team", bevel=0.02)
    p.box((0, 17.6, 7.6), (8.0, 2.0, 3.0), "trim", bevel=0.1)  # the cab under the screen
    p.box((0, 17.8, 6.08), (6.0, 0.7, 0.05), "glass")
    # the emitter towers: sloped feet, team panels, beams with emitter heads
    for sx in (-1, 1):
        x = sx * TX
        p.prism_y(rect(x, PZ, 1.7, 2.0), 0.6, GY + 3.4, "paint", bevel=0.14)
        p.prism_x([(PZ - 7.0, 0.6), (PZ + 7.0, 0.6), (PZ + 3.6, 5.6), (PZ - 3.6, 5.6)], *sorted((x - sx * 1.2, x + sx * 3.6)), "paint", bevel=0.16)
        p.box((x + sx * 1.73, 12.0, PZ), (0.06, 7.0, 2.6), "team", bevel=0.01)
        p.box((x + sx * 1.73, 20.0, PZ), (0.05, 5.0, 0.2), "light")
        p.box((x, GY + 3.45, PZ), (3.0, 0.1, 3.6), "dark")
        hazard(p, (x + sx * 2.4, 3.2, PZ - 5.36), (sx, 0, 0), (0, 0.6, -0.8), 2.6, 3.0, stripes=4)
        p.box((sx * (TX - 1.6), GY + 1.6, PZ), (3.2, 1.4, 2.2), "trim", bevel=0.06)
        p.box((sx * BX, GY + 1.0, PZ), (2.2, 2.0, 18.0), "paint", bevel=0.12)
        p.box((sx * (BX - 1.12), GY + 1.0, PZ), (0.05, 0.3, 16.0), "light")
        p.box((sx * BX, GY + 2.03, PZ), (1.6, 0.05, 14.0), "team")
        for z in EMIT_Z:
            p.box((sx * BX, GY - 0.4, z), (1.4, 1.0, 1.4), "trim", bevel=0.06)
            p.cylinder("y", (sx * BX, GY - 0.95, z), 0.5, 0.12, 12, "power")
        cable(p, [(x, 9.0, PZ + 2.0), (x * 0.95, 9.0, 1.0), (x * 0.95, 9.0, 4.0)], r=0.3, kind="steel")
    for i, h in enumerate((6.0, 7.5, 9.0)):
        antenna(p, (TX - 0.9 + i * 0.9, GY + 3.5, PZ + 1.2 - i * 0.6), h, r=0.12)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 25.6, 0.68, sz * 25.6), (0.8, 0.14, 0.8), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 19.02, 1.4, 4.0), (sx * 19.02, 1.4, 26.0), 14, (sx, 0, 0))
        seam(p, (sx * 23.02, 10.0, 6.0), (sx * 23.02, 10.0, 23.0), (sx, 0, 0))
    seam(p, (-6.8, 26.0, 8.99), (6.8, 26.0, 8.99), (0, 0, -1))
    rivets(p, (-9.0, 15.0, 2.98), (9.0, 15.0, 2.98), 14, (0, 0, -1))


unit.run(__file__, "ord_gantry", "order", footprint=7,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000,
         previews=[("35", (-76, 60, -90), (0, 10.0, 0), 50),
                   ("80", (0, 124, 20), (0, 6, 0), 50),
                   ("close", (-36, 34, -44), (0, 14.0, -4.0), 35)])
