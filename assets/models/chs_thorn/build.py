"""Thorn (Chaos IR SAM site, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_thorn/build.py

A low round skid with amber edge lights and a team plate, a bare post; the
`launcher` (turned by the def on the post's axis, M-3) is a small sensor box
with an amber seeker between an open frame carrying six bare canister tubes,
three a side, staggered, each mouth ringed with a ready light (weapon
channel), a team plate on the sensor box. The muzzle is the outer lower
left tube (BAR style, M-15; Chaos reads light and open, M-14). Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

PIVOT = (0.0, 3.0, 0.0)
TUBES = [(-2.2, 3.3), (-1.7, 3.75), (-1.2, 3.3), (1.2, 3.3), (1.7, 3.75), (2.2, 3.3)]


def build_base(p):
    p.cylinder("y", (0, 0.25, 0), 3.0, 0.5, 12, "dark")
    p.cylinder("y", (0, 0.55, 0), 2.4, 0.1, 12, "trim")
    p.box((0, 0.62, 1.5), (2.4, 0.05, 1.0), "team", bevel=0.012)
    for i in range(6):  # edge lights round the skid
        import math
        a = math.pi / 6 + i * math.pi / 3
        p.box((math.sin(a) * 2.98, 0.3, math.cos(a) * 2.98), (0.4, 0.14, 0.4), "light")
    p.cylinder("y", (0, 1.8, 0), 0.55, 2.4, 10, "paint")
    for i in range(3):  # gusset plates
        import math
        a = i * 2 * math.pi / 3
        p.obox((math.sin(a) * 0.8, 1.1, math.cos(a) * 0.8), (math.cos(a), 0, -math.sin(a)), (math.sin(a), 0, math.cos(a)), 0.12, 1.0, 0.8, "steel")
    p.cylinder("y", (0, 3.0, 0), 0.7, 0.15, 12, "steel")
    p.cylinder("y", (0, 2.3, 0), 0.6, 0.18, 10, "light")  # post band


def details_base(p):
    ring(p, (0, 0.501, 0), UP, 2.7)
    bolts(p, (-1.8, 0.601, -1.0), (1.8, 0.601, -1.0), 6, UP)


def build_launcher(p):
    p.box((0, 3.55, 0.1), (1.2, 0.95, 1.4), "paint", bevel=0.04)
    p.box((0, 3.6, -0.62), (0.9, 0.5, 0.04), "weapon")  # seeker
    p.box((0, 4.04, 0.1), (0.9, 0.05, 1.0), "team", bevel=0.01)
    p.box((0, 3.4, 0.5), (4.9, 0.2, 0.2), "steel")  # frame
    p.box((0, 3.4, -0.7), (4.9, 0.16, 0.16), "steel")
    for x, y in TUBES:
        p.cylinder("z", (x, y, -0.2), 0.21, 3.0, 10, "trim")
        p.cylinder("z", (x, y, -1.72), 0.18, 0.04, 10, "weapon")  # ready light at the mouth
    p.box((-2.6, 3.9, 0.6), (0.3, 1.2, 0.3), "dark")  # cable mast
    p.box((-2.6, 4.55, 0.6), (0.24, 0.12, 0.24), "light")


def details_launcher(p):
    for x, y in TUBES:
        ring(p, (x, y, 1.301), (0, 0, 1), 0.15, segments=8)


unit.run(__file__, "chs_thorn", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [-2.2, 3.3, -1.75]}},
         budget=6000)
