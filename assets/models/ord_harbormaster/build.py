"""Harbormaster (Order advanced naval worker, T2 ship): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_harbormaster/build.py

New mesh from its blockout, the Tidewright's hull at the T2 small-ship
size (size-scale.md: about 1.3x, ~14 long): a raked armored hull with a
dark waterline band, a large team foredeck plate, a cargo hatch with
status lights, a deck crane (post, jib and hook) forward, a slab bridge
with a glass band, a lit strip and a team roof, a mast with a lamp, nav
lights, gunwale strips and bollards, hazard striping on the work deck; the
`nano` turret aft with two build arms, fore and aft, each with an emitter
(power; `nano1`, `nano2`). Model space, waterline at y = 0. Order reads
heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import ships  # noqa: E402
import unit  # noqa: E402
from mech import hazard  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

V = lib.vec
NANO = (0.0, 1.95, 3.6)
ARMS = [((-0.55, 2.3, 3.6), (-0.55, 4.3, 1.1)), ((0.55, 2.3, 3.6), (0.55, 3.9, 5.7))]
H = ships.Hull(length=14.50, beam=4.89, freeboard=1.70, depth=0.70, sheer_bow=0.50, sheer_stern=0.15, flare=0.2, transom=0.6, rake=1.4, max_at=0.42, fine=2.0, z0=-1.35)  # v2 hull (tools/ships.py)

def build_base(p):
    ships.hull(p, H)
    p.box((0, 1.73, -5.6), (3.6, 0.05, 2.0), "team", bevel=0.015)
    for z in (-3.0,):  # cargo hatch with status lights
        p.box((0, 2.0, z), (2.6, 0.6, 1.6), "trim", bevel=0.05)
        for sx in (-1, 1):
            p.box((sx * 1.32, 2.15, z), (0.04, 0.16, 1.4), "light")
    hazard(p, (0, 1.72, 5.4), (1, 0, 0), UP, 3.6, 0.4, stripes=8)
    # deck crane forward: post, jib, hook
    p.cylinder("y", (1.4, 2.6, -4.2), 0.3, 1.8, 10, "trim")
    a, b = V((1.4, 3.4, -4.2)), V((0.0, 4.4, -6.8))
    p.obox(tuple((a + b) / 2), tuple(b - a), (0, 1, 0), (b - a).length, 0.3, 0.3, "steel")
    p.cylinder("y", (0.0, 3.6, -6.8), 0.03, 1.6, 6, "steel")
    p.box((0.0, 2.75, -6.8), (0.35, 0.3, 0.35), "dark")
    # bridge
    p.prism_y([(-1.8, -1.6), (1.8, -1.6), (1.8, 1.4), (-1.8, 1.4)], 1.7, 3.9, "paint", bevel=0.06, top_scale=0.93)
    p.box((0, 3.3, -1.62), (2.9, 0.4, 0.06), "glass")
    p.box((0, 2.9, -1.63), (2.7, 0.1, 0.04), "light")
    p.box((0, 3.95, -0.1), (2.6, 0.05, 2.4), "team", bevel=0.012)
    p.cylinder("y", (0, 4.6, 0.6), 0.1, 1.3, 6, "steel")
    p.box((0, 5.3, 0.6), (0.22, 0.14, 0.22), "light")
    for sx in (-1, 1):
        p.box((sx * 1.82, 3.2, -0.2), (0.06, 0.18, 0.5), "light")
        if sx > 0:  # running strips along the sheer, both sides
            ships.deck_strip(p, H, H.z0 - 0.36 * H.length, H.z0 + 0.42 * H.length, 0.1)
        for z in (-5.2, 4.6):
            p.cylinder("y", (sx * 2.0, 1.9, z), 0.15, 0.4, 8, "steel")
    p.box((0, 0.9, H.z(0.0) + 0.03), (ships.half_beam_at(H, H.z(0.0)) * 1.3, 0.24, 0.05), "light")


def details_base(p):
    ships.hull_details(p, H)
    seam(p, (-2.3, 1.701, -1.9), (2.3, 1.701, -1.9), UP)
    bolts(p, (-2.0, 1.701, 2.6), (2.0, 1.701, 2.6), 8, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 1.0, 0.5, 16, "trim")
    p.cylinder("y", (x, y + 0.27, z), 1.02, 0.06, 16, "power")
    for a, b in ARMS:
        a, b = V(a), V(b)
        p.obox(tuple((a + b) / 2), tuple(b - a), (1, 0, 0), (b - a).length, 0.4, 0.4, "steel")
        p.cylinder("y", (b.x, b.y - 0.1, b.z), 0.42, 0.5, 12, "dark")
        p.cylinder("y", (b.x, b.y - 0.38, b.z), 0.34, 0.06, 12, "power")


def no_details(p):
    pass


unit.run(__file__, "ord_harbormaster", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)])
