"""Crusader (Order destroyer, T2 ship, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_crusader/build.py

New mesh from its blockout, at the T2 capital-ship size (size-scale.md:
29-30 long): a faceted hull with a flared bow and a dark waterline band,
large team plates on the foredeck and the helideck, a helideck aft with
hazard edges, a tall stepped block superstructure with a glass band and a
lit strip, a solid mast with the client-turned radar (`radar`, M-27) and a
funnel with a glowing cap; `turret1` a sloped gun house forward with a long
barrel (`muzzle1`), `launcher` a VLS block with team cells and readiness
lights (`muzzle3`), `turret2` a triple ASW torpedo mount on the starboard
side aft (`muzzle2`). Gunwale strips, nav lights, bollards. Model space,
waterline at y = 0. Order reads heavy and clean (M-14). Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, rect  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

DECK = 2.4
T1 = (0.0, DECK, -9.0)
T2 = (2.4, DECK, 6.2)
VLS = (0.0, DECK, -4.6)
RADAR = (0.0, 9.2, 0.6)


def build_base(p):
    p.prism_x([(-15.0, DECK + 0.4), (-11.0, -0.9), (12.8, -0.9), (13.4, 0.4), (13.4, DECK)], -3.4, 3.4, "paint", bevel=0.12)
    p.prism_x([(-14.4, DECK + 0.4), (-12.0, DECK - 0.6), (-12.0, DECK)], -2.0, 2.0, "paint", bevel=0.06)  # flared bow
    p.prism_x([(-13.0, 0.0), (-10.8, -0.6), (13.45, -0.6), (13.45, 0.0)], -3.47, 3.47, "dark", bevel=0.02)
    p.box((0, DECK + 0.03, -11.2), (4.0, 0.05, 3.0), "team", bevel=0.015)
    # helideck aft
    p.box((0, DECK + 0.02, 10.6), (6.0, 0.05, 5.0), "dark")
    p.box((0, DECK + 0.05, 10.6), (3.4, 0.04, 3.4), "team", bevel=0.01)
    for sz in (-1, 1):
        hazard(p, (0, DECK + 0.06, 10.6 + sz * 2.4), (1, 0, 0), UP, 5.8, 0.3, stripes=12)
    # stepped block superstructure, glass band, lit strip
    p.prism_y(rect(0, 0.4, 2.6, 3.6), DECK, 5.6, "paint", bevel=0.12, top_scale=0.93)
    p.prism_y(rect(0, 0.0, 2.0, 2.2), 5.6, 7.4, "paint", bevel=0.1, top_scale=0.9)
    p.box((0, 6.7, -2.22), (3.4, 0.45, 0.06), "glass")
    p.box((0, 6.3, -2.23), (3.2, 0.1, 0.04), "light")
    p.box((0, 5.62, 2.6), (4.0, 0.05, 1.6), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 2.62, 4.2, 0.4), (0.05, 0.16, 6.4), "light")
    # solid mast and funnel
    p.prism_y(rect(0, 0.6, 0.6, 0.6), 7.4, 8.9, "trim", bevel=0.05, top_scale=0.7)
    p.cylinder("y", (0, 9.6, 0.6), 0.08, 1.4, 6, "steel")
    p.box((0, 10.35, 0.6), (0.2, 0.14, 0.2), "light")
    p.prism_y(rect(0, 4.4, 1.0, 1.2), 5.6, 7.6, "trim", bevel=0.08, top_scale=0.85)
    p.box((0, 7.62, 4.4), (1.5, 0.06, 1.8), "power")
    for sx in (-1, 1):
        p.box((sx * 3.42, 1.7, 0.0), (0.05, 0.2, 24.0), "light")
        for z in (-12.0, 8.0):
            p.cylinder("y", (sx * 3.0, DECK + 0.25, z), 0.2, 0.5, 8, "steel")
    p.box((0, 1.2, 13.42), (5.0, 0.24, 0.05), "light")
    p.cylinder("y", (0, DECK + 0.05, -9.0), 1.6, 0.1, 18, "dark")  # gun ring

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, 9.0, 0.6), (2.6, 0.6, 0.4), "paint", bevel=0.03)
        p.box((0, 9.0, 0.38), (2.4, 0.4, 0.04), "dark")
        p.box((0, 9.0, 0.36), (2.45, 0.06, 0.03), "light")


def details_base(p):
    seam(p, (-3.3, DECK + 0.001, -7.0), (3.3, DECK + 0.001, -7.0), UP)
    seam(p, (-3.3, DECK + 0.001, 7.4), (3.3, DECK + 0.001, 7.4), UP)
    bolts(p, (-2.8, DECK + 0.001, -13.2), (2.8, DECK + 0.001, -13.2), 8, UP)


def build_turret1(p):
    x, y, z = T1
    p.prism_y([(-1.2, z - 1.2), (1.2, z - 1.2), (1.5, z - 0.4), (1.5, z + 1.6), (-1.5, z + 1.6), (-1.5, z - 0.4)],
              y + 0.1, y + 1.6, "paint", bevel=0.08, top_scale=0.86)
    p.box((0, y + 1.64, z + 0.4), (2.0, 0.05, 1.8), "team", bevel=0.012)
    p.cylinder("z", (0, y + 0.9, z - 3.4), 0.22, 4.4, 12, "steel")
    p.cylinder("z", (0, y + 0.9, z - 5.75), 0.28, 0.5, 12, "dark")
    p.cylinder("z", (0, y + 0.9, z - 5.45), 0.27, 0.1, 12, "weapon")


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 0.7, 0.3, 12, "trim")
    for k, dy in enumerate((0.55, 0.95, 1.35)):
        p.cylinder("z", (x, y + dy - 0.1 * k, z - 0.2), 0.16, 2.0, 10, "paint")
        p.cylinder("z", (x, y + dy - 0.1 * k, z - 1.22), 0.1, 0.04, 8, "weapon")
    p.box((x, y + 0.8, z + 0.6), (0.8, 1.2, 0.4), "paint", bevel=0.03)


def build_launcher(p):
    x, y, z = VLS
    p.box((x, y + 0.6, z), (3.6, 1.2, 2.4), "paint", bevel=0.06)
    for i in range(4):
        for j in range(2):
            cx, cz = x - 1.2 + i * 0.8, z - 0.5 + j * 1.0
            p.box((cx, y + 1.22, cz), (0.6, 0.05, 0.75), "team" if (i + j) % 2 == 0 else "trim")
            p.box((cx, y + 1.25, cz - 0.3), (0.3, 0.02, 0.06), "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_crusader", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details),
                 unit.PieceSpec("launcher", "base", VLS, build_launcher, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 0.9, T1[2] - 6.05]},
                      "muzzle2": {"parent": "turret2", "at": [T2[0], T2[1] + 0.95, T2[2] - 1.3]},
                      "muzzle3": {"parent": "launcher", "at": [VLS[0], VLS[1] + 1.4, VLS[2]]}},
         budget=10000)
