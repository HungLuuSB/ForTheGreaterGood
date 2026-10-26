"""Scylla (Chaos naval SAM platform, T2 structure, footprint 3, floats; S-166):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_scylla/build.py

From its approved blockout (2026-10-26): a monstrous ruin afloat. Big shapes
first: two rusted drum floats with straps under a tilted deck of broken
slabs, team plates and a hazard strip; ruined columns (one standing with a
capital and an amber lamp, one broken short, one toppled across the deck);
a crooked armored pedestal with side plates, spikes and an amber eye slit.
The `launcher` (yaws and pitches, the def's piece) is the beast: a slab
skull with a dark jaw, horns and a team plate, and six missile tubes fanned
out like necks, each mouth ringed in glowing amber (`muzzle` at the middle
top neck). Chaos reads crude and brutal (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, rivets  # noqa: E402
from towers import band_round  # noqa: E402
from unit import UP, seam  # noqa: E402

LAUNCHER = (0.0, 8.0, 0.0)
# the six necks: (x, y, z of the centre, yaw degrees, length)
NECKS = [(-1.5, 9.1, -3.4, 12, 4.6), (0.0, 9.3, -3.7, 0, 5.0), (1.5, 9.1, -3.4, -12, 4.6),
         (-1.6, 7.9, -3.2, 18, 4.2), (0.0, 7.8, -3.4, 0, 4.4), (1.6, 7.9, -3.2, -18, 4.2)]


def yaw_dir(deg):
    a = math.radians(deg)
    return (-math.sin(a), 0.0, -math.cos(a))


def build_base(p):
    # the drum floats and their straps
    p.cylinder("z", (-7.0, -0.2, 0), 2.5, 21.0, 18, "dark", bevel=0.06)
    p.cylinder("z", (7.2, -0.3, 0.6), 2.3, 19.0, 18, "dark", bevel=0.06)
    for z in (-6.0, -1.0, 4.0, 8.0):
        p.cylinder("z", (-7.0, -0.2, z), 2.58, 0.4, 18, "steel")
        p.cylinder("z", (7.2, -0.3, z + 0.6), 2.38, 0.4, 18, "steel")
    # the tilted deck of broken slabs
    p.obox((0, 1.5, 0), (0.999, 0.035, 0), (-0.035, 0.999, 0), 18.0, 16.0, 0.9, "paint", bevel=0.08)
    p.obox((-6.0, 2.3, -6.6), (0.94, 0, 0.34), (0, 1, 0), 6.0, 4.0, 1.2, "paint", bevel=0.06)
    p.obox((6.0, 2.2, 6.0), (0.98, 0.1, -0.2), (0, 0.99, 0.1), 5.0, 4.0, 0.8, "paint", bevel=0.06)
    p.box((0, 2.0, -6.4), (5.0, 0.08, 1.6), "team", bevel=0.01)
    p.box((-4.6, 2.0, 5.4), (3.0, 0.08, 3.0), "team", bevel=0.01)
    hazard(p, (3.4, 2.03, -7.4), (1, 0, 0), UP, 6.0, 0.5, stripes=10)
    # ruined columns
    p.cylinder("y", (-7.4, 5.4, -6.2), 0.9, 7.0, 10, "trim", radius2=0.8)
    p.box((-7.4, 9.2, -6.2), (2.4, 0.6, 2.4), "trim", bevel=0.06)
    p.box((-7.4, 9.75, -6.2), (0.5, 0.5, 0.5), "light")
    p.cylinder("y", (7.4, 3.6, -6.0), 0.9, 3.4, 10, "trim")
    p.obox((7.4, 5.4, -6.0), (1, 0, 0), (0.3, 1, 0.1), 1.6, 1.6, 0.3, "trim")  # the broken top
    p.obox((3.4, 2.7, 5.6), (0.906, 0, 0.423), (0, 0, 1), 7.0, 1.6, 1.6, "trim", bevel=0.2)
    # the crooked pedestal: side plates, spikes, the eye slit
    a = math.radians(15)
    u, n = (math.cos(a), 0, -math.sin(a)), (math.sin(a), 0, math.cos(a))
    p.obox((0, 4.4, 0), u, n, 6.0, 5.0, 6.0, "dark", bevel=0.1)
    for sx in (-1, 1):
        p.obox((sx * 3.3, 4.4, 0), (0, 0, 1), (sx, sx * -0.07, 0), 4.0, 3.6, 0.6, "paint", bevel=0.06)
        p.ocyl((sx * 2.8, 6.9, 2.3), (sx * 0.2, 1, 0.1), 0.45, 2.4, 6, "steel", radius2=0.03)
    p.obox((-0.6, 5.6, -3.1), u, (-n[0], 0, -n[2]), 3.0, 0.4, 0.2, "head")


def details_base(p):
    band_round(p, -0.2, 2.52, segments=12, cx=-7.0)
    rivets(p, (-8.6, 2.0, -3.0), (-8.6, 2.0, 3.0), 6, UP)
    seam(p, (-8.5, 1.98, 2.0), (8.5, 2.6, 2.0), UP)


def build_launcher(p):
    p.box((0, 8.3, 0.4), (4.2, 2.6, 3.6), "paint", bevel=0.14)
    p.prism_x([(-0.6, 6.4), (-2.6, 7.2), (-0.6, 7.6)], -2.1, 2.1, "dark", bevel=0.06)  # the jaw
    p.box((0, 9.63, 0.6), (2.8, 0.06, 2.2), "team", bevel=0.01)
    for sx in (-1, 1):
        p.ocyl((sx * 2.0, 9.6, 1.0), (sx * 0.3, 1, 0.5), 0.5, 1.8, 6, "dark", radius2=0.05)
        p.box((sx * 1.2, 8.7, -1.42), (0.7, 0.3, 0.06), "head")  # eyes
    for x, y, z, deg, ln in NECKS:
        d = yaw_dir(deg)
        base = (x - d[0] * ln / 2, y, z - d[2] * ln / 2)
        p.ocyl(base, d, 0.45, ln, 10, "trim")
        for t in (0.25, 0.6):
            p.ocyl((base[0] + d[0] * ln * t, y, base[2] + d[2] * ln * t), d, 0.55, 0.25, 10, "steel")
        tip = (base[0] + d[0] * ln, y, base[2] + d[2] * ln)
        p.ocyl(tip, d, 0.58, 0.18, 10, "dark")
        p.ocyl((tip[0] + d[0] * 0.18, y, tip[2] + d[2] * 0.18), d, 0.4, 0.04, 10, "weapon")


def details_launcher(p):
    rivets(p, (-1.8, 9.61, 1.8), (1.8, 9.61, 1.8), 5, UP)


unit.run(__file__, "chs_scylla", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", LAUNCHER, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [0.0, 9.3, -6.4]}},
         budget=6000,
         previews=[("35", (-34, 28, -40), (0, 4.0, 0), 50),
                   ("80", (0, 58, 9), (0, 3, 0), 50),
                   ("close", (-12, 14, -16), (0, 7.5, -2.0), 38)])
