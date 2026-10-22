"""Barracuda (Chaos corvette, T1 ship): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_barracuda/build.py

A cheap fast gunboat: the Wrecker's narrow hull and dark waterline, a squat
bridge with an amber slit window, an offset funnel with a lit band, a thin
braced mast with a sensor panel and a beacon, a team plate aft and on the
bridge; `turret1` a round open gun mount with a bare barrel and a muzzle
ring (weapon channel), `turret2` a small aft mount (BAR style, M-15; Chaos
reads light, M-14). Model space, waterline at y = 0. Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

T1 = (0.0, 1.3, -2.6)
T2 = (0.0, 1.3, 3.3)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.prism_x([(-6.6, 1.3), (-4.6, -0.5), (4.6, -0.5), (4.6, 1.3)], -1.6, 1.6, "paint", bevel=0.05)
    p.prism_x([(-6.0, 0.0), (-4.4, -0.35), (4.65, -0.35), (4.65, 0.0)], -1.66, 1.66, "dark", bevel=0.02)
    p.box((0, 1.33, 4.2), (2.24, 0.05, 0.74), "team", bevel=0.01)
    p.box((0, 1.82, 0.6), (1.92, 1.04, 1.76), "paint", bevel=0.04)
    p.box((0, 2.15, -0.3), (1.44, 0.22, 0.05), "light")
    p.box((0, 2.36, 0.6), (1.5, 0.05, 1.2), "team", bevel=0.01)
    p.cylinder("y", (0.48, 2.94, 1.7), 0.45, 1.6, 10, "trim")
    p.cylinder("y", (0.48, 3.5, 1.7), 0.47, 0.16, 10, "light")
    # thin braced mast, sensor panel, beacon
    p.box((0, 3.2, 1.2), (0.25, 1.8, 0.25), "dark")
    beam(p, (0.6, 2.35, 1.2), (0.12, 3.8, 1.2), 0.12, "dark")
    p.box((0, 3.8, 1.2), (1.4, 0.8, 0.15), "trim")
    p.box((0, 3.8, 1.11), (1.2, 0.08, 0.04), "light")
    p.box((0, 4.4, 1.2), (0.3, 0.3, 0.3), "light")
    for sx in (-1, 1):
        p.box((sx * 0.98, 2.0, 0.6), (0.06, 0.14, 0.4), "light")
        p.box((sx * 1.63, 1.1, 0.0), (0.05, 0.14, 6.6), "light")
    p.box((0, 0.7, 4.63), (2.6, 0.2, 0.05), "light")


def details_base(p):
    bolts(p, (-1.4, 1.301, -4.0), (1.4, 1.301, -4.0), 6, UP)
    ring(p, (0.48, 3.741, 1.7), UP, 0.35)


def build_turret1(p):
    p.cylinder("y", (0, 1.7, -2.6), 0.7, 0.8, 12, "paint")
    p.cylinder("y", (0, 2.12, -2.6), 0.55, 0.05, 12, "team")
    p.cylinder("z", (0, 1.75, -4.0), 0.15, 2.3, 8, "steel")
    p.cylinder("z", (0, 1.75, -5.0), 0.17, 0.1, 8, "weapon")


def build_turret2(p):
    p.cylinder("y", (0, 1.6, 3.3), 0.45, 0.6, 10, "paint")
    p.cylinder("z", (0, 1.6, 2.55), 0.1, 1.0, 8, "steel")
    p.cylinder("z", (0, 1.6, 2.05), 0.12, 0.08, 8, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_barracuda", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, 1.75, -5.42]},
                      "muzzle2": {"parent": "turret2", "at": [0, 1.6, 1.95]}})
