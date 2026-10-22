"""Vigil (Order IR SAM site, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_vigil/build.py

A heavy chamfered base on a pad with a pedestal and a glowing bearing ring;
the `launcher` (turned by the def on the pedestal's axis, M-3) is a sensor
head with an ice-white seeker window between two closed canister pods, team
plates on the pods' tops, each pod's front a grid of canister caps with
ready lights (weapon channel). The muzzle is the left pod's top-outer cap
(BAR style, M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

PIVOT = (0.0, 3.0, 0.0)
BLOCK = [(-2.2, -2.9), (2.2, -2.9), (2.9, -2.2), (2.9, 2.2), (2.2, 2.9), (-2.2, 2.9), (-2.9, 2.2), (-2.9, -2.2)]


def build_base(p):
    p.prism_y([(-3.7, -3.7), (3.7, -3.7), (3.7, 3.7), (-3.7, 3.7)], 0.0, 0.45, "trim", bevel=0.05, top_scale=0.97)
    p.prism_y(BLOCK, 0.45, 1.7, "paint", bevel=0.06, top_scale=0.8)
    p.cylinder("y", (0, 2.15, 0), 0.85, 0.9, 14, "steel")
    p.cylinder("y", (0, 2.68, 0), 1.0, 0.16, 16, "light")  # bearing ring
    p.cylinder("y", (0, 2.85, 0), 0.95, 0.2, 16, "trim")
    for sx in (-1, 1):
        p.box((sx * 2.84, 1.05, 0), (0.06, 0.12, 3.6), "light")
        p.box((sx * 2.76, 0.75, 0), (0.06, 0.4, 3.2), "grille")
    for sz in (-1, 1):
        p.box((0, 1.71, sz * 1.6), (2.6, 0.05, 0.9), "team", bevel=0.012)
        p.box((0, 0.6, sz * 3.55), (2.0, 0.1, 0.06), "light")


def details_base(p):
    box_seams(p, (0, 0, 0), (4.0, 0, 4.0), 1.701)
    bolts(p, (-3.3, 0.451, 3.3), (3.3, 0.451, 3.3), 8, UP)
    bolts(p, (-3.3, 0.451, -3.3), (3.3, 0.451, -3.3), 8, UP)
    ring(p, (0, 2.951, 0), UP, 0.7)


def build_launcher(p):
    p.box((0, 3.6, 0.1), (1.4, 1.3, 1.8), "paint", bevel=0.05)
    p.box((0, 3.75, -0.82), (0.9, 0.45, 0.06), "dark")
    p.box((0, 3.75, -0.86), (0.7, 0.3, 0.04), "weapon")  # seeker window
    for sx in (-1, 1):
        x = sx * 1.5
        p.box((sx * 0.85, 3.5, 0.1), (0.4, 0.5, 1.0), "steel")  # arms
        p.box((x, 3.6, -0.2), (1.3, 1.5, 3.2), "paint", bevel=0.05)
        p.box((x, 4.37, -0.2), (1.0, 0.05, 2.5), "team", bevel=0.012)
        p.box((x, 3.6, -1.82), (1.12, 1.32, 0.06), "dark")
        for cx in (-0.27, 0.27):  # canister caps with ready lights
            for cy in (-0.32, 0.32):
                p.box((x + cx, 3.6 + cy, -1.86), (0.4, 0.4, 0.04), "steel")
                p.box((x + cx, 3.6 + cy, -1.89), (0.14, 0.14, 0.03), "weapon")
        p.box((x, 3.6, 1.42), (0.9, 1.0, 0.06), "grille")
        p.box((sx * 2.16, 3.95, -0.2), (0.06, 0.2, 2.8), "light")  # pod status strip


def details_launcher(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.5 - 0.55, 4.351, 0.9), (sx * 1.5 + 0.55, 4.351, 0.9), UP)
        bolts(p, (sx * 2.151, 3.1, -1.5), (sx * 2.151, 3.1, 1.1), 5, (sx, 0, 0))


unit.run(__file__, "ord_vigil", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [-1.77, 3.92, -1.95]}},
         budget=6000)
