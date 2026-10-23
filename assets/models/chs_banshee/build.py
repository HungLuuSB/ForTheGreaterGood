"""Banshee (Chaos EW jammer jet, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_banshee/build.py

New mesh from its blockout, at the T2 aircraft size (size-scale.md: span
12-14): the Chaos delta stretched, a round fuselage with a pointed nose and
a bubble canopy, canards, a tall team fin, twin engine pods with glowing
nozzles, emitter pods on the wing tips with amber tips, formation strips
along the leading edges, and on the spine the `dish` (the def's piece): a
flat jammer box, a panel and never a dish, its top glowing in bars.
Unarmed. Chaos reads light and aggressive (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import ring  # noqa: E402

DISH = (0.0, 1.7, 0.4)


def build_base(p):
    p.cylinder("z", (0, 0.8, -0.2), 0.75, 8.0, 14, "paint")
    p.ocyl((0, 0.8, -4.2), (0, 0, -1), 0.75, 2.2, 14, "paint", radius2=0.08)
    p.ocyl((0, 1.45, -3.6), (0, 0, 1), 0.36, 1.8, 10, "glass", radius2=0.38)
    p.prism_y([(-6.0, 3.8), (0.0, -2.0), (6.0, 3.8)], 0.48, 0.64, "paint", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 2.8, 0.66, 2.6), (2.4, 0.04, 1.3), "team")
        p.box((sx * 1.3, 1.0, -2.4), (2.0, 0.14, 0.8), "dark")  # canards
        p.cylinder("z", (sx * 1.2, 0.5, 2.9), 0.45, 3.0, 12, "trim")
        p.cylinder("z", (sx * 1.2, 0.5, 4.42), 0.36, 0.06, 12, "light")
        p.cylinder("z", (sx * 6.0, 0.56, 3.0), 0.22, 2.0, 10, "trim")  # wing-tip emitter pods
        p.ocyl((sx * 6.0, 0.56, 2.0), (0, 0, -1), 0.22, 0.4, 10, "power", radius2=0.06)
        p.obox((sx * 3.0, 0.66, 0.9), (0.695, 0, -sx * 0.719), (0, 1, 0), 0.14, 8.0, 0.03, "light")
    p.prism_x([(2.0, 1.4), (4.2, 1.4), (4.4, 3.8), (3.3, 3.8)], -0.11, 0.11, "team", bevel=0.02)
    p.box((0, 3.82, 3.8), (0.16, 0.08, 1.0), "light")
    p.box((0, 0.05, -2.4), (0.34, 0.06, 0.34), "head")


def details_base(p):
    ring(p, (0, 0.8, -1.0), (0, 0, -1), 0.73)
    ring(p, (0, 0.8, 2.0), (0, 0, -1), 0.73)


def build_dish(p):
    x, y, z = DISH
    p.box((x, y, z), (2.2, 0.6, 4.2), "trim", bevel=0.05)
    p.box((x, y + 0.31, z), (1.9, 0.03, 3.8), "dark")
    for k in range(5):
        p.box((x, y + 0.33, z - 1.6 + k * 0.8), (1.7, 0.02, 0.18), "power")
    for sx in (-1, 1):
        p.box((sx * 1.12, y, z), (0.04, 0.3, 3.6), "team")


def no_details(p):
    pass


unit.run(__file__, "chs_banshee", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH, build_dish, no_details)],
         team_pieces=["base", "dish"])
