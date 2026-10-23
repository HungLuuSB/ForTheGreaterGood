"""Depot (Chaos storage, T1 structure, footprint 2): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_depot/build.py

Redesigned at the size scale (S-104, M-26: footprint 1 -> 2, 16 x 16 studs,
low to medium: about 6 tall), not rescaled: a salvage tank farm. Big shapes
first: a skid slab, two big upright drums with team-painted caps and
strapped bands, a long horizontal tank on cradles behind them, a pipe
bridge and valves, orange level gauges (power: dims on an energy stall), a
loading shack with a team roof, hazard striping, a warning light and corner
beacons. Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP  # noqa: E402


def drum_up(p, x, z, r, h, y0=0.7):
    p.cylinder("y", (x, y0 + h / 2, z), r, h, 18, "paint", bevel=0.05)
    p.ocyl((x, y0 + h, z), UP, r, 0.45, 18, "trim", radius2=r * 0.75)
    p.cylinder("y", (x, y0 + h + 0.5, z), r * 0.72, 0.06, 16, "team")
    for y in (y0 + 0.5, y0 + h * 0.55):
        p.cylinder("y", (x, y, z), r + 0.05, 0.18, 18, "dark")
    # level gauge: a dark strip with a lit fill
    p.box((x, y0 + h * 0.5, z - r - 0.02), (0.5, h * 0.7, 0.05), "dark")
    p.box((x, y0 + h * 0.36, z - r - 0.05), (0.42, h * 0.42, 0.05), "power")
    p.cylinder("y", (x, y0 + h * 0.85, z), r + 0.04, 0.14, 18, "power")


def build_base(p):
    p.prism_y(octagon(7.8, 0.7), 0.0, 0.7, "dark", bevel=0.1, top_scale=0.985)
    drum_up(p, -3.4, -2.0, 2.4, 4.8)
    drum_up(p, 2.2, -3.0, 1.9, 3.8)
    # long horizontal tank on cradles at the back, with a team band
    drum(p, (0.0, 2.25, 4.0), 1.45, 11.0, "paint", "trim", sides=18, axis="x")
    for dx in (-3.6, 0.0, 3.6):
        p.cylinder("x", (dx, 2.25, 4.0), 1.49, 0.2, 18, "dark")
        p.box((dx, 1.0, 4.0), (0.5, 0.6, 2.6), "trim", bevel=0.04)
    p.cylinder("x", (1.8, 2.25, 4.0), 1.48, 1.4, 18, "team")
    p.box((-1.8, 2.25, 2.53), (3.0, 0.45, 0.05), "power")
    # pipe bridge and valves between the drums and the tank
    cable(p, [(-3.4, 5.3, -0.4), (-3.4, 5.6, 2.2), (-3.4, 3.4, 3.4)], r=0.22, kind="steel")
    cable(p, [(2.2, 4.4, -1.4), (2.2, 4.7, 2.0), (2.2, 3.5, 3.0)], r=0.18, kind="steel")
    for x, y, z in ((-3.4, 5.6, 1.2), (2.2, 4.7, 0.8)):
        p.cylinder("x", (x, y + 0.4, z), 0.28, 0.12, 10, "dark")
    # loading shack (front right) with a team roof and a lit door
    p.prism_y(rect(5.4, 1.4, 1.6, 1.8), 0.7, 2.9, "paint", bevel=0.1)
    p.box((5.4, 2.94, 1.4), (2.8, 0.05, 3.2), "team", bevel=0.02)
    p.box((5.4, 1.5, -0.42), (1.2, 1.4, 0.05), "dark")
    p.box((5.4, 2.4, -0.44), (1.0, 0.12, 0.04), "light")
    p.box((7.02, 1.8, 1.4), (0.05, 0.5, 2.4), "power")
    hazard(p, (-1.0, 0.72, -6.8), (1, 0, 0), (0, 1, 0), 7.0, 0.45, stripes=13)
    p.cylinder("y", (-3.4, 6.2, -2.0), 0.2, 0.3, 8, "light")  # warning light
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 7.0, 0.78, sz * 7.0), (0.3, 0.15, 0.3), "light")


def details_base(p):
    rivets(p, (4.0, 2.93, 0.0), (6.8, 2.93, 0.0), 5, UP)


unit.run(__file__, "chs_depot", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-22, 17, -26), (0, 2.5, 0), 50),
                   ("80", (0, 36, 6), (0, 2, 0), 50),
                   ("close", (-11, 9, -13), (0, 3.0, 0), 35)])
