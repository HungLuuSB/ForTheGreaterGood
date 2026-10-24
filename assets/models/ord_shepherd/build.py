"""Shepherd (Order mobile point defence, T2 ground, footprint 1; S-149): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_shepherd/build.py

From its blockout: an armored 6x6 about 1.3x a T1 truck. Big shapes first: a
long armored hull with a sloped glacis and a raised cab with a wraparound
glass band, armored skirts with team strips and running lights, headlights.
The `launcher` (static: the def doesn't turn it; launches straight up): a
vertical-launch module on the back, sloped armored walls round a 2 x 4 grid of
cell hatches, each with a ready light (`weapon`) and a vent strip, a large
team plate at its rear; `muzzle` at the front left cell. A compact search
panel on a short mast behind the cab (`radar`, M-27, client-turned): unlit
face, glowing edge. Order reads heavy and clean (M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, rect  # noqa: E402
from unit import UP, bolts, seam, wheel  # noqa: E402

PIVOT = (0.0, 2.7, 2.2)
ROOF = 4.3
RADAR = (-1.4, 5.4, -1.8)
CELLS = [(-0.75 + j * 1.5, 0.35 + i * 1.05) for i in range(4) for j in range(2)]
MUZZLE = (CELLS[0][0], ROOF + 0.2, CELLS[0][1])


def build_base(p):
    p.prism_x([(-5.6, 1.1), (-4.4, 0.9), (5.0, 0.9), (5.0, 2.7), (-3.0, 2.7), (-5.6, 1.9)], -2.3, 2.3, "paint", bevel=0.08)
    p.prism_x([(-4.9, 2.6), (-2.4, 2.6), (-2.4, 4.2), (-3.2, 4.2), (-4.7, 3.0)], -2.2, 2.2, "paint", bevel=0.08)
    p.obox((0, 3.4, -4.05), (1, 0, 0), (0, 0.75, -0.66), 3.6, 0.55, 0.05, "glass")
    for sx in (-1, 1):
        p.box((sx * 2.21, 3.6, -3.3), (0.05, 0.4, 1.4), "glass")
    p.box((0, 4.24, -3.3), (3.2, 0.05, 1.4), "team", bevel=0.012)
    p.box((0, 1.9, -5.62), (2.8, 0.14, 0.05), "light")
    for sx in (-1, 1):
        p.box((sx * 1.5, 1.5, -5.65), (0.6, 0.2, 0.08), "head")
        p.box((sx * 2.38, 1.85, 0.3), (0.16, 0.8, 8.8), "paint", bevel=0.03)
        p.box((sx * 2.47, 1.85, 1.0), (0.04, 0.3, 4.0), "team", bevel=0.01)
        p.box((sx * 2.47, 2.4, 0.3), (0.04, 0.12, 8.0), "light")
        for i, z in enumerate((-3.4, 0.2, 3.6)):
            wheel(p, sx * 2.15, 0.8, z, 0.8, 0.7, name=f"wheel{'L' if sx < 0 else 'R'}{i + 1}")
    hazard(p, (0, 2.72, 4.85), (1, 0, 0), UP, 3.6, 0.3, stripes=8)
    p.box((0, 1.8, 5.03), (2.8, 0.14, 0.05), "light")
    p.cylinder("y", (RADAR[0], 4.8, RADAR[2]), 0.16, 1.2, 8, "steel")
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        t = math.radians(15)
        n = (0, math.sin(t), -math.cos(t))
        c = (RADAR[0], 5.85, RADAR[2])
        p.obox(c, (1, 0, 0), n, 1.6, 0.95, 0.16, "paint", bevel=0.02)
        p.obox(tuple(c[k] + n[k] * 0.09 for k in range(3)), (1, 0, 0), n, 1.42, 0.78, 0.02, "dark")
        p.obox(tuple(c[k] + n[k] * 0.1 for k in range(3)), (1, 0, 0), n, 1.46, 0.06, 0.02, "light")


def details_base(p):
    bolts(p, (-1.8, 2.701, -1.0), (1.8, 2.701, -1.0), 6, UP)
    seam(p, (-2.2, 3.6, -2.39), (2.2, 3.6, -2.39), (0, 0, 1))


def build_launcher(p):
    x, y, z = PIVOT
    p.prism_y(rect(0, z, 1.8, 2.4), y, ROOF, "paint", bevel=0.08, top_scale=0.92)
    for cx, cz in CELLS:
        p.box((cx, ROOF + 0.02, cz), (1.2, 0.06, 0.85), "trim", bevel=0.01)
        p.box((cx, ROOF + 0.06, cz - 0.32), (0.5, 0.03, 0.1), "weapon")
        p.box((cx, ROOF + 0.06, cz + 0.32), (0.9, 0.02, 0.06), "dark")
    p.box((0, ROOF - 0.6, z + 2.22), (2.8, 0.8, 0.05), "team", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * 1.66, ROOF - 0.8, z), (0.04, 0.1, 4.0), "light")


def details_launcher(p):
    bolts(p, (-1.5, ROOF + 0.001, PIVOT[2] - 2.1), (1.5, ROOF + 0.001, PIVOT[2] - 2.1), 6, UP)


unit.run(__file__, "ord_shepherd", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}},
         budget=5000)
