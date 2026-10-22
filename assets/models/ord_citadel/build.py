"""Citadel (Order fortress, T3 structure, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_citadel/build.py

A stepped armored block with sloped blast walls and team plates on all four
sides; on top the big `turret` with the long `barrel` (evacuator, muzzle
brake, ring on `weapon`), an IR SAM `launcher` (two canister pods with ready
lights) on a corner pedestal, and the static `radar` mast at the opposite
corner (unlit array with a glowing edge). Cyan running lights round the
steps and a power band round the turret ring (BAR style, M-15; Order reads
heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams  # noqa: E402

TURRET = (0.0, 4.4, 0.5)
BARREL = (0.0, 5.9, -4.0)
LAUNCHER = (-5.6, 5.8, -5.6)
RADAR = (5.6, 6.2, 5.6)


def octagon(r, c):
    return [(-r + c, -r), (r - c, -r), (r, -r + c), (r, r - c), (r - c, r), (-r + c, r), (-r, r - c), (-r, -r + c)]


def build_base(p):
    p.prism_y(octagon(11.8, 2.0), 0.0, 2.0, "paint", bevel=0.08, top_scale=0.92)
    p.prism_y(octagon(9.4, 1.6), 2.0, 4.2, "paint", bevel=0.08, top_scale=0.9)
    for sx, sz in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        if sx:
            p.box((sx * 9.5, 2.03, 0), (1.4, 0.05, 6.0), "team", bevel=0.015)
        else:
            p.box((0, 2.03, sz * 9.5), (6.0, 0.05, 1.4), "team", bevel=0.015)
    for sx in (-1, 1):  # running lights round both steps
        p.box((sx * 11.6, 1.2, 0), (0.06, 0.2, 14.0), "light")
        p.box((0, 1.2, sx * 11.6), (14.0, 0.2, 0.06), "light")
        p.box((sx * 8.5, 3.4, 0), (0.06, 0.2, 10.0), "light")
        p.box((0, 3.4, sx * 8.5), (10.0, 0.2, 0.06), "light")
    p.cylinder("y", (0, 4.3, 0.5), 4.4, 0.2, 20, "trim")
    p.cylinder("y", (0, 4.25, 0.5), 4.5, 0.14, 20, "power", cap_kinds=("trim", "trim"))  # turret ring band
    p.cylinder("y", (-5.6, 5.0, -5.6), 1.0, 1.6, 12, "steel")  # launcher pedestal
    p.box((5.6, 5.2, 5.6), (0.6, 2.0, 0.6), "steel")  # radar mast


def details_base(p):
    box_seams(p, (0, 0, 0), (14.0, 0, 14.0), 4.201)
    bolts(p, (-11.0, 2.001, -10.4), (11.0, 2.001, -10.4), 16, UP)


def build_turret(p):
    p.prism_y(octagon(4.0, 1.0), 4.4, 7.0, "paint", bevel=0.08, top_scale=0.88)
    p.box((0, 7.03, 1.2), (5.0, 0.05, 4.0), "team", bevel=0.015)
    p.box((2.2, 7.3, -1.6), (0.9, 0.6, 0.9), "trim", bevel=0.03)
    p.box((2.2, 7.32, -2.07), (0.7, 0.3, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 4.02, 5.8, 0.5), (0.05, 0.24, 5.0), "light")


def build_barrel(p):
    y = 5.9
    p.box((0, y, -4.2), (2.0, 1.6, 1.0), "paint", bevel=0.08)
    p.cylinder("z", (0, y, -9.6), 0.6, 10.6, 16, "paint")
    p.cylinder("z", (0, y, -8.0), 0.8, 1.2, 16, "paint")
    p.cylinder("z", (0, y, -8.0), 0.83, 0.16, 16, "weapon")
    p.box((0, y, -14.5), (1.8, 1.4, 1.4), "dark", bevel=0.06)
    p.cylinder("z", (0, y, -13.7), 0.68, 0.16, 16, "weapon")


def build_launcher(p):
    x, y, z = LAUNCHER
    p.box((x, 6.0, z), (1.2, 1.0, 1.2), "trim", bevel=0.04)
    for sx in (-1, 1):
        p.box((x + sx * 1.0, 6.6, z - 0.2), (0.9, 1.1, 2.8), "paint", bevel=0.04)
        p.box((x + sx * 1.0, 7.17, z - 0.2), (0.7, 0.05, 2.2), "team")
        for cy in (-0.25, 0.25):
            p.box((x + sx * 1.0, 6.6 + cy, z - 1.62), (0.5, 0.4, 0.04), "steel")
            p.box((x + sx * 1.0, 6.6 + cy, z - 1.65), (0.16, 0.16, 0.03), "weapon")


def build_radar(p):
    t = math.radians(20)
    n = (0, math.sin(t), -math.cos(t))
    v = (0, math.cos(t), math.sin(t))
    c = (5.6, 7.6, 5.6)
    p.obox(c, (1, 0, 0), n, 4.4, 2.8, 0.35, "paint", bevel=0.03)
    p.obox(tuple(c[k] + n[k] * 0.18 for k in range(3)), (1, 0, 0), n, 4.1, 2.5, 0.03, "dark")
    for b in (-1.2, 1.2):
        p.obox(tuple(c[k] + n[k] * 0.2 + v[k] * b for k in range(3)), (1, 0, 0), n, 4.1, 0.08, 0.02, "light")
    for a in (-2.0, -1.0, 0.0, 1.0, 2.0):
        p.obox((c[0] + a, c[1] + n[1] * 0.2, c[2] + n[2] * 0.2), (1, 0, 0), n, 0.06, 2.4, 0.02, "light")
    p.obox(tuple(c[k] - n[k] * 0.18 for k in range(3)), (1, 0, 0), n, 3.6, 2.0, 0.03, "team")


def no_details(p):
    pass


unit.run(__file__, "ord_citadel", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL, build_barrel, no_details),
                 unit.PieceSpec("launcher", "base", LAUNCHER, build_launcher, no_details),
                 unit.PieceSpec("radar", "base", RADAR, build_radar, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, 5.9, -15.1]},
                      "muzzle2": {"parent": "launcher", "at": [-5.6, 6.6, -7.2]}},
         budget=6000, tex=2048, preview_size=26)
