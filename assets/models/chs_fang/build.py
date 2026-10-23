"""Fang (Chaos torpedo launcher, T1 structure, footprint 1, on water): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_fang/build.py

New mesh in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 3 above the water), from its blockout. The waterline is y = 0. Big
shapes first: a pontoon raft of two strapped drum floats under a plated
deck with team plates and hazard striping; a turntable (`turret`, the def's
piece, static); the `launcher` (the def turns it, M-3): two bare tubes on a
welded cradle with ready lights at the mouths (`muzzle` between them), a
loading crane stub and a spare torpedo; a hydrophone the client lowers
(`sonar`, lower, rig.md 9); amber beacons. Chaos reads rugged, light and
open (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

PIVOT = (0.0, 1.5, -0.3)
TUBE_Y = 2.05
MOUTH = -2.75


def build_base(p):
    for sx in (-1, 1):
        drum(p, (sx * 2.6, 0.1, 0), 1.05, 7.2, "paint", "trim", sides=14, axis="z")
        for z in (-2.4, 0.0, 2.4):
            p.cylinder("z", (sx * 2.6, 0.1, z), 1.09, 0.2, 14, "dark")
    p.box((0, 1.25, 0), (6.6, 0.3, 6.6), "trim", bevel=0.04)
    p.box((-2.2, 1.42, 2.3), (1.8, 0.05, 1.6), "team", bevel=0.01)
    p.box((2.2, 1.42, 2.3), (1.8, 0.05, 1.6), "team", bevel=0.01)
    hazard(p, (0, 1.42, 3.0), (1, 0, 0), UP, 2.2, 0.4, stripes=5)
    p.box((2.2, 1.42, -2.2), (1.4, 0.04, 1.6), "steel", bevel=0.01)  # welded patch
    for sx in (-1, 1):
        p.box((sx * 3.1, 1.6, -3.0), (0.3, 0.3, 0.3), "light")
    with p.sub("sonar", (2.6, -0.8, -2.8), "lower", (0, -1, 0), 8):
        p.cylinder("y", (2.6, -0.4, -2.8), 0.05, 1.6, 6, "steel")
        p.box((2.6, -1.25, -2.8), (0.5, 0.3, 0.5), "dark", bevel=0.03)
        p.box((2.6, -1.25, -3.06), (0.4, 0.12, 0.04), "power")


def build_turret(p):
    p.cylinder("y", (0, 1.5, -0.3), 1.2, 0.3, 14, "steel")


def build_launcher(p):
    p.box((0, 1.75, -0.3), (2.0, 0.3, 2.8), "trim", bevel=0.03)  # cradle
    for sz in (-1.2, 0.6):
        p.box((0, 2.05, sz), (1.9, 0.5, 0.2), "steel")
    for x in (-0.5, 0.5):
        p.cylinder("z", (x, TUBE_Y, -0.8), 0.32, 3.9, 12, "paint")
        p.cylinder("z", (x, TUBE_Y, MOUTH + 0.1), 0.35, 0.2, 12, "dark")
        p.cylinder("z", (x, TUBE_Y, MOUTH - 0.03), 0.2, 0.04, 10, "weapon")
    drum(p, (1.25, 1.95, 0.4), 0.2, 2.2, "steel", "dark", sides=10, axis="z")  # spare torpedo
    p.box((-1.1, 2.4, 0.9), (0.2, 1.4, 0.2), "dark")  # crane stub
    p.box((-0.8, 3.05, 0.9), (0.8, 0.16, 0.16), "dark")
    cable(p, [(-0.45, 3.0, 0.9), (-0.45, 2.6, 0.9)], r=0.03, kind="steel")


def details_base(p):
    rivets(p, (-3.0, 1.401, -0.4), (-3.0, 1.401, 1.2), 4, UP)


def details_launcher(p):
    for x in (-0.5, 0.5):
        ring(p, (x, TUBE_Y, 1.16), (0, 0, 1), 0.2, segments=8)


unit.run(__file__, "chs_fang", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", (0.0, 1.5, -0.3), build_turret, lambda p: None),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [0.0, TUBE_Y, MOUTH - 0.05]}},
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 1.5, -0.5), 50),
                   ("80", (0, 26, 4), (0, 1, -0.5), 50),
                   ("close", (-7, 6, -9), (0, 2.0, -1.0), 40)])
