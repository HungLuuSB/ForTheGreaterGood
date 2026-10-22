"""Halo (Order mobile IR SAM, T1, footprint 1): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_halo/build.py

An armored 6 x 6 with a sloped nose and a cab with a glass band; on the
rear deck the `turret` (a turntable drum) carrying the `launcher`: a
central sensor head with a glowing seeker window between two sealed
missile pods, their front caps dark (the weapon turns the turret and
pitches the launcher). Team plates on the pods, the cab roof and the
flanks (BAR style, M-15; Order reads heavy, M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring, seam, wheel  # noqa: E402

TURRET_PIVOT = (0.0, 2.2, 1.6)
LAUNCHER_PIVOT = (0.0, 4.0, 1.6)
MUZZLE = (-1.25, 4.0, -0.35)
WHEELS_Z = (-2.4, 0.2, 2.6)


def build_base(p):
    p.prism_x([(-4.2, 1.2), (-3.0, 0.8), (3.6, 0.8), (3.6, 2.2), (-2.4, 2.2), (-4.2, 1.6)], -2.0, 2.0, "paint", bevel=0.05)
    for sx in (-1, 1):
        x0, x1 = (2.0, 2.35) if sx > 0 else (-2.35, -2.0)
        p.prism_x([(-3.3, 1.25), (3.4, 1.25), (3.4, 1.9), (-3.3, 1.9)], x0, x1, "paint", bevel=0.03)
        p.box((sx * 2.37, 1.6, 0.2), (0.05, 0.32, 3.4), "team", bevel=0.01)
        p.box((sx * 2.37, 1.95, 0.2), (0.06, 0.1, 6.0), "light")  # flank running strip
    p.prism_y([(-1.8, -2.4), (1.8, -2.4), (1.8, -0.9), (-1.8, -0.9)], 2.2, 3.0, "paint", bevel=0.04, top_scale=0.86)
    p.box((0, 2.65, -2.42), (3.0, 0.3, 0.05), "glass")
    p.box((0, 3.02, -1.65), (2.4, 0.05, 1.0), "team", bevel=0.012)
    p.box((0, 2.95, -2.42), (3.0, 0.08, 0.05), "light")  # cab sensor strip
    for sx in (-1, 1):
        p.box((sx * 1.4, 1.35, -4.18), (0.6, 0.2, 0.08), "head")
    p.cylinder("y", (0, 2.3, 1.6), 1.0, 0.2, 14, "dark")
    for sx in (-1, 1):
        for z in WHEELS_Z:
            wheel(p, sx * 2.2, 0.75, z, 0.75, 0.6)


def build_turret(p):
    p.cylinder("y", (0, 2.9, 1.6), 0.75, 1.2, 14, "trim")
    p.box((0, 3.45, 1.6), (0.5, 0.6, 1.0), "dark")


def build_launcher(p):
    p.box((0, 4.0, 1.6), (1.2, 1.1, 1.4), "paint", bevel=0.05)
    p.box((0, 4.15, 0.88), (0.8, 0.46, 0.06), "weapon")  # seeker window
    for sx in (-1, 1):
        x = sx * 1.25
        p.box((x, 4.0, 1.3), (1.1, 1.2, 3.0), "paint", bevel=0.05)
        p.box((x, 4.62, 1.3), (0.9, 0.05, 2.4), "team", bevel=0.012)
        p.box((sx * 1.82, 4.0, 1.3), (0.04, 0.14, 2.6), "light")  # pod sensor strip
        p.box((x, 4.0, -0.22), (0.92, 1.0, 0.06), "dark")
        p.box((x, 4.0, -0.25), (0.6, 0.12, 0.04), "weapon")  # ready light on the cap
        p.cylinder("x", (sx * 0.65, 4.0, 1.6), 0.18, 0.3, 8, "steel")


def details_base(p):
    seam(p, (-1.9, 2.201, 0.4), (1.9, 2.201, 0.4), UP)
    bolts(p, (-1.8, 2.201, 3.4), (1.8, 2.201, 3.4), 6, UP)


def details_turret(p):
    ring(p, (0, 3.501, 1.6), UP, 0.6)


def details_launcher(p):
    for sx in (-1, 1):
        x = sx * 1.25
        bolts(p, (x - 0.4, 4.0, -0.25), (x + 0.4, 4.0, -0.25), 3, (0, 0, -1))
        seam(p, (x - 0.55, 4.601, 2.0), (x + 0.55, 4.601, 2.0), UP)


unit.run(__file__, "ord_halo", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret),
                 unit.PieceSpec("launcher", "turret", LAUNCHER_PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}})
