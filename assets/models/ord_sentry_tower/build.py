"""Sentry (Order laser tower, T1 structure, footprint 2; S-157): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_sentry_tower/build.py

From its approved blockout (the user's reference 2026-10-24: a tall slim
laser tower). Big shapes first: a ring of eight armored petals round an
octagonal footing (team colour on every other petal), a tall slim column
with a lit band, a dark spine and team strips, a collar. The `turret` (yaw):
an upright armored head with a sensor, a grille and a team panel. The
`barrel` (pitch, -60..+60 degrees): the emitter's mount on the head's left,
a ribbed laser tube and a glowing lens; `muzzle` at the lens. Order reads
clean and heavy (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

TURRET = (0.0, 11.3, 0.0)
BARREL = (-1.2, 12.6, -0.8)
MUZZLE = (-1.2, 12.6, -4.3)


def build_base(p):
    p.prism_y(octagon(3.4, 1.0), 0.0, 0.6, "trim", bevel=0.06)
    for k in range(8):  # the petal skirt, leaning out
        a = math.radians(k * 45 + 22.5)
        t = math.radians(18)
        out = (math.sin(a), 0.0, math.cos(a))
        n = (out[0] * math.cos(t), math.sin(t), out[2] * math.cos(t))
        u = (math.cos(a), 0.0, -math.sin(a))
        p.obox((out[0] * 3.3, 1.6, out[2] * 3.3), u, n, 2.5, 2.4, 0.4, "team" if k % 2 == 0 else "paint", bevel=0.06)
    p.cylinder("y", (0, 2.2, 0), 2.1, 3.2, 16, "paint", bevel=0.08)
    p.cylinder("y", (0, 3.85, 0), 2.2, 0.2, 16, "trim")
    p.prism_y(rect(0, 0, 1.0, 1.0), 3.8, 11.2, "paint", bevel=0.1)
    p.box((0, 7.4, 1.05), (0.5, 6.8, 0.12), "dark")  # spine
    p.box((0, 5.4, 0), (2.08, 0.3, 2.08), "light")  # lit band
    for sx in (-1, 1):
        p.box((sx * 1.02, 8.4, 0), (0.06, 3.4, 0.9), "team", bevel=0.01)
    p.box((0, 8.6, -1.02), (0.9, 2.0, 0.06), "grille")
    p.cylinder("y", (0, 11.1, 0), 1.4, 0.5, 16, "trim", bevel=0.04)
    hazard(p, (0, 0.62, -2.6), (1, 0, 0), UP, 2.4, 0.35, stripes=6)
    skirt_round(p, 3.4, sides=8)
    louver(p, (0, 6.5, -1.04), (1, 0, 0), (0, 0, -1), 0.8, 1.0)
    for sx in (-1, 1):
        glow_strip(p, (sx * 0.78, 4.2, -1.03), (sx * 0.78, 10.8, -1.03), (0, 0, -1), width=0.1)
    clamped_cable(p, [(2.0, 1.0, 2.4), (1.2, 3.9, 1.15), (0.7, 6.0, 1.12), (0.7, 10.9, 1.12)])


def details_base(p):
    band_box(p, 4.6, 0, 0, 1.0, 1.0)
    band_box(p, 9.9, 0, 0, 1.0, 1.0)
    band_round(p, 2.0, 2.1)
    rivets(p, (-0.9, 4.2, -1.01), (0.9, 4.2, -1.01), 5, (0, 0, -1))
    seam(p, (-1.0, 6.6, -1.01), (1.0, 6.6, -1.01), (0, 0, -1))
    ring(p, (0, 11.36, 0), UP, 0.9)


def build_turret(p):
    p.prism_y(rect(0.3, 0.2, 1.2, 1.4), 11.4, 14.6, "paint", bevel=0.12, top_scale=0.9)
    p.box((1.52, 13.2, 0.2), (0.06, 1.8, 1.8), "team", bevel=0.01)
    p.box((0.8, 14.0, -1.24), (0.6, 0.5, 0.06), "light")  # sensor
    p.box((0.8, 14.0, -1.22), (0.8, 0.7, 0.04), "dark")
    p.box((0.3, 12.2, 1.62), (1.6, 1.0, 0.06), "grille")
    p.box((0.3, 14.65, 0.2), (1.6, 0.1, 1.8), "trim", bevel=0.02)
    louver(p, (-0.92, 13.2, 0.2), (0, 0, 1), (-1, 0, 0), 1.6, 1.0)
    antenna(p, (1.1, 14.7, 1.2), 1.2)
    glow_strip(p, (-0.7, 11.7, -1.23), (1.3, 11.7, -1.23), (0, 0, -1), width=0.1)


def details_turret(p):
    band_box(p, 12.0, 0.3, 0.2, 1.2, 1.4)
    seam(p, (-0.9, 13.0, -1.21), (1.5, 13.0, -1.21), (0, 0, -1))
    rivets(p, (1.51, 12.1, -0.6), (1.51, 12.1, 1.0), 4, (1, 0, 0))


def build_barrel(p):
    x, y, z = BARREL
    p.box((x, y, z), (1.2, 1.2, 1.3), "trim", bevel=0.08)
    p.ocyl((x, y, z - 0.6), (0, 0, -1), 0.36, 2.9, 14, "steel")
    for k in (0.6, 1.5, 2.3):
        p.ocyl((x, y, z - 0.6 - k), (0, 0, -1), 0.5, 0.22, 14, "dark")
    p.ocyl((x, y, MUZZLE[2] + 0.25), (0, 0, -1), 0.3, 0.12, 14, "weapon")  # the lens


def details_barrel(p):
    ring(p, (BARREL[0], BARREL[1] + 0.61, BARREL[2]), UP, 0.3)


unit.run(__file__, "ord_sentry_tower", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=4000,
         previews=[("35", (-20, 17, -24), (0, 7.0, 0), 40),
                   ("close", (-9, 15, -10), (-0.3, 11.6, -1.0), 35)])
