"""Mire (Chaos amphibious tank, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_mire/build.py

New mesh from its blockout, at the T2 light size (size-scale.md: 9-10 x
6.5 x ~5, fits one cell). A light open hull with a raked bow riding
between two strapped pontoon floats with team plates, three exposed wheels
a side below (`wheelL1..3` / `wheelR1..3`, spin), an open stern with one
big caged propeller housing, a tall snorkel with an amber lamp, a stowed
cable reel and hazard striping; a small round turret (`turret`, the def
turns it) with a team roof, a sensor box and a short gun with a muzzle
ring (`muzzle`). Chaos reads light and improvised (M-14). Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard  # noqa: E402
from unit import UP, bolts, wheel  # noqa: E402

TURRET = (0.0, 2.3, 0.5)
GUN_Y = 2.8


def build_base(p):
    # light open hull with a raked bow
    p.prism_x([(4.4, 0.9), (-3.0, 0.9), (-4.6, 1.8), (-4.6, 2.3), (4.4, 2.3)], -1.8, 1.8, "paint", bevel=0.06)
    p.box((0, 2.33, 3.0), (2.8, 0.04, 2.4), "grille")
    hazard(p, (0, 2.32, -3.3), (1, 0, 0), UP, 2.8, 0.4, stripes=6)
    # strapped pontoon floats with team plates
    for sx in (-1, 1):
        drum(p, (sx * 2.6, 1.7, 0.1), 0.75, 8.4, "paint", "trim", sides=14, axis="z")
        for z in (-2.6, 0.1, 2.8):
            p.cylinder("z", (sx * 2.6, 1.7, z), 0.79, 0.2, 14, "dark")
        p.box((sx * 2.6, 2.47, 1.45), (0.8, 0.05, 2.2), "team", bevel=0.01)
        p.box((sx * 2.6, 2.47, -1.25), (0.8, 0.05, 2.0), "team", bevel=0.01)
        p.box((sx * 3.37, 1.7, 0.1), (0.04, 0.12, 5.0), "light")
        p.box((sx * 1.9, 1.15, 0.1), (0.3, 0.3, 6.8), "steel")  # wheel beam
        for i, z in enumerate((-2.4, 0.1, 2.6)):
            wheel(p, sx * 1.75, 0.6, z, 0.6, 0.5, name=f"wheel{'L' if sx < 0 else 'R'}{i + 1}")
    p.box((-1.0, 1.9, -4.45), (0.5, 0.18, 0.06), "head")
    p.box((1.0, 1.9, -4.45), (0.5, 0.18, 0.06), "head")
    # open stern with a caged propeller housing
    drum(p, (0, 1.25, 4.7), 0.85, 1.0, "trim", "dark", sides=16, axis="z")
    for k in range(4):
        p.box((0, 1.25, 5.25), (1.6 if k % 2 == 0 else 0.08, 0.08 if k % 2 == 0 else 1.6, 0.06), "steel")
    # tall snorkel with an amber lamp, a cable reel
    p.cylinder("y", (1.3, 3.4, 2.8), 0.15, 2.4, 8, "steel")
    p.box((1.3, 4.7, 2.8), (0.3, 0.2, 0.3), "light")
    drum(p, (-1.0, 2.6, 3.2), 0.4, 0.8, "dark", "steel", sides=12, axis="x")
    cable(p, [(-1.0, 2.9, 3.2), (-0.6, 2.5, 3.8), (-0.2, 2.35, 4.2)], r=0.05, kind="dark")


def details_base(p):
    bolts(p, (-1.5, 2.301, -1.8), (1.5, 2.301, -1.8), 6, UP)


def build_turret(p):
    p.cylinder("y", (0, 2.75, 0.5), 1.3, 0.9, 16, "paint", radius2=1.15, bevel=0.05)
    p.cylinder("y", (0, 3.22, 0.6), 0.9, 0.05, 14, "team")
    p.box((-0.85, 3.2, -0.45), (0.55, 0.35, 0.4), "trim", bevel=0.03)  # sensor box
    p.box((-0.85, 3.2, -0.66), (0.4, 0.16, 0.04), "light")
    p.box((0, 2.8, -0.9), (0.7, 0.6, 0.5), "dark", bevel=0.04)
    p.cylinder("z", (0, GUN_Y, -2.6), 0.2, 3.2, 10, "steel")
    p.cylinder("z", (0, GUN_Y, -4.15), 0.26, 0.4, 10, "dark")
    p.cylinder("z", (0, GUN_Y, -3.9), 0.25, 0.08, 10, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_mire", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, GUN_Y, -4.4]}})
