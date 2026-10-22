"""Hornet (Chaos mobile IR SAM, T1, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_hornet/build.py

A high-riding 6 x 6 truck on big exposed wheels, a push ram, a slab cab
offset left with a slit, a stack; on a turret ring at the back the `turret`
(a short drum) carrying the `launcher`: an open rail with two bare
missiles on the left, a boxy seeker rack with an orange seeker on the
right, a counterweight behind (the weapon turns the turret and pitches the
launcher). Team plates on the rack and the cab roof (BAR style, M-15; Chaos
reads light, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring, wheel  # noqa: E402

TURRET_PIVOT = (0.2, 2.6, 1.6)
LAUNCHER_PIVOT = (0.2, 4.0, 1.6)
MUZZLE = (-0.65, 4.3, -0.2)
WHEELS_Z = (-2.3, 1.3, 3.1)


def build_base(p):
    p.prism_x([(-3.3, 1.2), (3.7, 1.2), (3.7, 2.3), (-3.0, 2.3)], -1.9, 1.9, "paint", bevel=0.04)
    p.obox((0, 1.35, -3.45), (1, 0, 0), (0, 0.34, -0.94), 5.0, 0.8, 0.3, "era", bevel=0.03)
    p.prism_y([(-2.2, -3.0), (0.4, -3.0), (0.4, -1.2), (-2.2, -1.2)], 2.3, 3.5, "paint", bevel=0.04, top_scale=0.88)
    p.box((-0.9, 3.2, -3.02), (2.0, 0.22, 0.05), "light")
    p.box((-0.9, 3.52, -2.1), (1.6, 0.05, 1.2), "team", bevel=0.012)
    p.cylinder("y", (1.4, 3.2, -2.4), 0.24, 2.0, 8, "steel")
    p.cylinder("y", (0.2, 2.45, 1.6), 1.1, 0.3, 12, "dark")
    for y in (1.0, 2.0):
        p.box((0, y, 3.75), (3.6, 0.08, 0.08), "dark")
    for sx in (-1, 1):
        for z in WHEELS_Z:
            wheel(p, sx * 2.4, 0.9, z, 0.9, 0.8)


def build_turret(p):
    p.cylinder("y", (0.2, 3.1, 1.6), 0.6, 1.0, 12, "trim")


def build_launcher(p):
    p.box((0.2, 4.0, 1.6), (0.8, 1.0, 1.0), "steel", bevel=0.03)
    p.box((1.3, 4.1, 1.3), (1.4, 1.2, 2.6), "paint", bevel=0.04)
    p.box((1.3, 4.72, 1.3), (1.1, 0.05, 2.0), "team", bevel=0.012)
    p.box((1.3, 4.3, -0.02), (0.5, 0.5, 0.05), "light")
    p.box((-0.3, 4.0, 1.3), (0.2, 1.2, 2.6), "dark")
    for y in (4.3, 3.75):
        p.cylinder("z", (-0.65, y, 1.1), 0.22, 2.6, 10, "steel")
        p.cylinder("z", (-0.65, y, -0.25), 0.22, 0.1, 10, "era", radius2=0.05)
    p.box((0.2, 3.9, 2.9), (1.6, 0.8, 0.6), "dark", bevel=0.03)


def details_base(p):
    bolts(p, (-1.7, 2.301, 3.4), (1.7, 2.301, 3.4), 6, UP)


def details_turret(p):
    ring(p, (0.2, 3.601, 1.6), UP, 0.5)


def details_launcher(p):
    bolts(p, (0.7, 4.701, 2.4), (1.9, 4.701, 2.4), 3, UP)


unit.run(__file__, "chs_hornet", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret),
                 unit.PieceSpec("launcher", "turret", LAUNCHER_PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}})
