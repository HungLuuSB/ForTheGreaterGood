"""Archangel (Order AWACS, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_archangel/build.py

New mesh from its blockout, at the T2 aircraft size (size-scale.md: span
12-14): a long Order jet with a stepped nose and a framed canopy, straight
high-aspect wings with team plates and wingtip lights, a T-tail with team
fins, two engines under the wings with glowing nozzles, and on two struts
along the spine the `dish` (the def's piece): a flat plank radar, a panel
and never a dish, its unlit faces edged in glow on both sides with a cell
grid. Unarmed. Order reads heavy and clean (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, seam  # noqa: E402

DISH = (0.0, 2.4, 0.4)


def build_base(p):
    p.prism_x([(-6.0, 0.7), (-4.4, 0.35), (4.6, 0.35), (5.4, 0.9), (4.6, 1.3), (-3.6, 1.35), (-5.2, 1.05)], -0.9, 0.9, "paint", bevel=0.06)
    p.prism_x([(-4.8, 1.12), (-3.6, 1.35), (-3.0, 1.62), (-4.0, 1.55)], -0.5, 0.5, "glass", bevel=0.02)
    for sx in (-1, 1):  # straight wings, team plates, wingtip lights, engines
        pts = [(sx * 0.9, -0.8), (sx * 6.8, 0.6), (sx * 6.8, 1.4), (sx * 0.9, 1.4)]
        if sx < 0:
            pts = pts[::-1]
        p.prism_y(pts, 0.55, 0.7, "paint", bevel=0.02)
        p.box((sx * 4.4, 0.72, 0.6), (2.6, 0.04, 0.9), "team")
        p.box((sx * 6.82, 0.62, 1.0), (0.06, 0.14, 0.6), "light")
        p.obox((sx * 3.85, 0.72, -0.08), (0.231, 0, -sx * 0.973), (0, 1, 0), 0.1, 5.8, 0.03, "light")  # leading edge
        p.cylinder("z", (sx * 2.6, 0.2, 0.4), 0.42, 2.4, 12, "trim")  # engines
        p.box((sx * 2.6, 0.5, 0.4), (0.2, 0.4, 1.4), "paint")
        p.cylinder("z", (sx * 2.6, 0.2, 1.62), 0.32, 0.06, 12, "light")
        # T-tail fins
        p.box((sx * 1.4, 2.6, 4.6), (2.4, 0.12, 1.0), "paint", bevel=0.02)
        p.box((sx * 1.4, 2.67, 4.6), (1.6, 0.04, 0.6), "team")
    p.prism_x([(3.2, 1.2), (5.2, 1.2), (5.2, 2.6), (4.2, 2.6)], -0.12, 0.12, "paint", bevel=0.02)
    for z in (-0.6, 1.4):  # struts to the plank radar
        p.box((0, 1.8, z), (0.25, 0.9, 0.4), "trim")
    p.box((0, 0.3, -5.0), (0.3, 0.06, 0.3), "head")


def details_base(p):
    seam(p, (-0.9, 1.33, -1.0), (0.9, 1.33, -1.0), UP)
    seam(p, (-0.9, 1.31, 2.4), (0.9, 1.31, 2.4), UP)


def build_dish(p):
    x, y, z = DISH
    p.box((x, y, z), (0.4, 0.9, 5.4), "paint", bevel=0.04)
    for sx in (-1, 1):
        p.box((sx * 0.21, y, z), (0.03, 0.7, 5.0), "dark")
        for b in (-0.36, 0.36):
            p.box((sx * 0.225, y + b, z), (0.02, 0.06, 5.0), "light")
        for zz in (-2.46, 2.46):
            p.box((sx * 0.225, y, z + zz), (0.02, 0.7, 0.06), "light")
        for k in range(1, 6):
            p.box((sx * 0.225, y, z - 2.5 + k * 0.83), (0.02, 0.7, 0.03), "light")
    p.box((x, y + 0.46, z), (0.3, 0.04, 3.6), "team")


def no_details(p):
    pass


unit.run(__file__, "ord_archangel", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("dish", "base", DISH, build_dish, no_details)],
         team_pieces=["base", "dish"])
