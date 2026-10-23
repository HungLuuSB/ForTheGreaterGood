"""Vigil (Order IR SAM site, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_vigil/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 5 tall). Big shapes first: a chamfered slab with hazard striping, an
armored octagonal block with sloped walls, team plates and running strips,
a reload hatch and a ready-rack of spare canisters at the back, a pedestal
with a glowing bearing ring; the `launcher` (turned by the def on the
pedestal's axis, M-3): an armored sensor head with an ice-white seeker
window and a sensor mast, two heavy closed canister pods on yoke arms with
large team tops, each pod's front a grid of six canister caps with ready
lights (weapon channel), status strips along the pods. The muzzle is the
left pod's top-outer cap. Order reads heavy and clean (M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring, seam  # noqa: E402

PIVOT = (0.0, 2.7, 0.0)
POD_X, POD_Y, POD_Z = 1.65, 3.55, -0.2  # pod centre (x mirrored)
CAPS_X, CAPS_Y = (-0.3, 0.3), (-0.42, 0.0, 0.42)
MUZZLE = (-(POD_X + 0.3), POD_Y + 0.42, -2.25)


def build_base(p):
    p.prism_y(octagon(3.85, 0.6), 0.0, 0.5, "trim", bevel=0.08, top_scale=0.98)
    hazard(p, (0, 0.52, -3.35), (1, 0, 0), UP, 4.8, 0.4, stripes=10)
    p.prism_y(octagon(3.0, 0.9), 0.5, 1.5, "paint", bevel=0.12)
    p.prism_y(octagon(3.0, 0.9), 1.5, 2.1, "paint", bevel=0.12, top_scale=0.72)
    for sx in (-1, 1):  # team plates on the sloped sides, running strips under them
        p.obox((sx * 2.6, 1.8, 0), (0, 0, 1), (sx * 0.6, 0.8, 0), 2.6, 0.7, 0.05, "team", bevel=0.015)
        p.box((sx * 3.02, 1.0, 0), (0.05, 0.12, 2.8), "light")
    p.box((0, 1.0, -3.02), (2.8, 0.12, 0.05), "light")
    # reload hatch and a ready-rack of spare canisters at the back
    p.obox((0, 1.85, 2.45), (1, 0, 0), (0, 0.8, 0.6), 1.8, 0.8, 0.08, "trim", bevel=0.02)
    p.prism_y(rect(0, 3.3, 1.5, 0.45), 0.5, 1.1, "trim", bevel=0.04)
    for x in (-1.0, -0.33, 0.33, 1.0):
        drum(p, (x, 1.35, 3.3), 0.26, 0.8, "steel", "dark", sides=10, axis="z")
    # pedestal and the glowing bearing ring
    p.cylinder("y", (0, 2.3, 0), 0.95, 0.5, 16, "steel")
    p.cylinder("y", (0, 2.5, 0), 1.12, 0.12, 18, "light")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 3.5, 0.56, sz * 3.5), (0.3, 0.12, 0.3), "light")


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 3.83, 0.25, -2.6), (sx * 3.83, 0.25, 2.6), 6, (sx, 0, 0))
    seam(p, (-1.4, 2.101, -0.6), (1.4, 2.101, -0.6), UP)
    ring(p, (0, 2.551, 0), UP, 0.8)


def build_launcher(p):
    # armored sensor head: sloped front, seeker window, a sensor mast
    p.cylinder("y", (0, 2.82, 0), 1.0, 0.24, 16, "trim")
    p.box((0, 3.45, 0.25), (1.5, 1.1, 1.9), "paint", bevel=0.08)
    p.prism_x([(-0.7, 2.9), (-0.7, 4.0), (-1.15, 3.8), (-1.15, 3.1)], -0.7, 0.7, "paint", bevel=0.05)
    p.obox((0, 3.6, -1.16), (1, 0, 0), (0, 0.1, -1), 0.9, 0.45, 0.06, "dark")
    p.obox((0, 3.6, -1.19), (1, 0, 0), (0, 0.1, -1), 0.7, 0.3, 0.04, "weapon")  # seeker window
    p.box((0, 4.02, 0.4), (1.2, 0.05, 1.4), "team", bevel=0.012)
    p.cylinder("y", (0.45, 4.5, 0.9), 0.06, 1.0, 6, "steel")
    p.box((0.45, 5.05, 0.9), (0.3, 0.16, 0.3), "light")
    for sx in (-1, 1):
        x = sx * POD_X
        p.box((sx * 0.95, 3.4, 0.2), (0.5, 0.55, 1.2), "steel", bevel=0.03)  # yoke arms
        drum(p, (sx * 0.95, 3.4, 0.2), 0.32, 0.6, "trim", "steel", sides=12, axis="x")
        p.box((x, POD_Y, POD_Z), (1.3, 1.55, 3.9), "paint", bevel=0.08)
        p.box((x, POD_Y + 0.8, POD_Z), (1.05, 0.05, 3.2), "team", bevel=0.012)
        p.box((x, POD_Y, -2.16), (1.15, 1.35, 0.06), "dark")
        for cx in CAPS_X:  # canister caps with ready lights
            for cy in CAPS_Y:
                p.cylinder("z", (x + cx, POD_Y + cy, -2.2), 0.17, 0.06, 10, "steel")
                p.cylinder("z", (x + cx, POD_Y + cy, -2.24), 0.08, 0.03, 8, "weapon")
        p.box((x, POD_Y, 1.77), (0.9, 1.1, 0.05), "grille")
        p.box((sx * (POD_X + 0.66), POD_Y + 0.3, POD_Z), (0.05, 0.14, 3.2), "light")  # pod status strip


def details_launcher(p):
    for sx in (-1, 1):
        seam(p, (sx * POD_X - 0.5, POD_Y + 0.776, 1.2), (sx * POD_X + 0.5, POD_Y + 0.776, 1.2), UP)
        bolts(p, (sx * (POD_X + 0.651), POD_Y - 0.5, -1.8), (sx * (POD_X + 0.651), POD_Y - 0.5, 1.4), 6, (sx, 0, 0))


unit.run(__file__, "ord_vigil", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 2.5, -0.5), 50),
                   ("80", (0, 26, 4), (0, 2, -0.5), 50),
                   ("close", (-7, 7, -9), (0, 3.0, -1.0), 40)])
