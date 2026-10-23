"""Corsair (Chaos destroyer, T2 ship, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_corsair/build.py

New mesh from its blockout, at the T2 capital-ship size (size-scale.md:
29-30 long): a low narrow hull with a raked bow and a dark waterline band,
team plates on the foredeck and the bridge roof, hazard striping, a squat
bridge with an amber slit, a funnel with a hot band, a braced lattice mast
with the client-turned radar array (`radar`, M-27), tyre fenders, amber
gunwale strips; `turret1` an open gun mount forward with a slab shield and
a team plate (`muzzle1`), `turret2` a twin ASW torpedo mount aft
(`muzzle2`), `launcher` a SAM rail box with four missiles and amber
seekers (`muzzle3`). Model space, waterline at y = 0. Chaos reads rugged
and improvised (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, hazard  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

DECK = 2.0
T1 = (0.0, DECK, -9.4)
T2 = (0.0, DECK, 9.6)
SAM = (0.0, DECK, 5.4)
RADAR = (0.0, 9.0, 1.8)


def build_base(p):
    p.prism_x([(-15.0, DECK + 0.3), (-11.0, -0.8), (13.0, -0.8), (13.0, DECK)], -3.0, 3.0, "paint", bevel=0.08)
    p.prism_x([(-13.2, 0.0), (-10.8, -0.55), (13.05, -0.55), (13.05, 0.0)], -3.07, 3.07, "dark", bevel=0.02)
    p.box((0, DECK + 0.03, -12.0), (3.4, 0.05, 2.4), "team", bevel=0.012)
    hazard(p, (0, DECK + 0.03, -6.6), (1, 0, 0), UP, 5.0, 0.4, stripes=10)
    p.box((2.0, DECK + 0.03, 1.0), (1.2, 0.04, 3.0), "steel", bevel=0.01)  # welded patch
    # squat bridge, amber slit, team roof, funnel
    p.box((0, DECK + 1.1, -1.4), (4.0, 2.2, 4.4), "paint", bevel=0.06)
    p.box((0, DECK + 1.6, -3.62), (3.2, 0.32, 0.05), "light")
    p.box((0, DECK + 2.23, -1.4), (3.4, 0.05, 3.8), "team", bevel=0.012)
    p.cylinder("y", (0.9, DECK + 3.2, 0.9), 0.85, 2.4, 12, "trim")
    p.cylinder("y", (0.9, DECK + 4.15, 0.9), 0.88, 0.25, 12, "light")
    # braced lattice mast
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            p.box((dx, DECK + 4.6, 1.8 + dz), (0.14, 5.0, 0.14), "paint")
    for y in (DECK + 3.2, DECK + 5.2):
        p.box((0, y, 1.8), (1.1, 0.1, 1.1), "steel")
    p.box((0, DECK + 6.9, 1.8), (1.2, 0.2, 1.2), "trim")
    cable(p, [(0.4, DECK + 6.8, 1.8), (2.4, DECK + 2.0, 6.0), (2.8, DECK + 0.2, 9.0)], r=0.03, kind="steel")
    for sx in (-1, 1):
        p.box((sx * 3.02, 1.4, 0.0), (0.05, 0.16, 22.0), "light")
        for z in (-8.0, 0.0, 8.0):
            p.ocyl((sx * 3.1, 0.9, z), (sx, 0, 0), 0.5, 0.32, 10, "rubber")
    p.box((0, 1.0, 13.07), (4.4, 0.24, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, 9.4, 1.8), (2.8, 0.7, 0.3), "paint", bevel=0.03)
        p.box((0, 9.4, 1.64), (2.6, 0.5, 0.04), "dark")
        p.box((0, 9.4, 1.62), (2.65, 0.06, 0.03), "light")
        p.box((0, 9.77, 1.8), (2.0, 0.04, 0.2), "team")


def details_base(p):
    bolts(p, (-2.6, DECK + 0.001, -10.4), (2.6, DECK + 0.001, -10.4), 8, UP)
    ring(p, (0.9, DECK + 4.401, 0.9), UP, 0.6)


def build_turret1(p):
    x, y, z = T1
    p.cylinder("y", (x, y + 0.2, z), 1.4, 0.4, 16, "trim")
    p.box((x, y + 0.9, z + 0.4), (1.6, 1.0, 1.8), "paint", bevel=0.05)
    p.obox((x, y + 1.0, z - 0.8), (1, 0, 0), (0, 0.25, -1), 2.6, 1.5, 0.25, "era", bevel=0.05)
    p.obox((x, y + 1.1, z - 0.96), (1, 0, 0), (0, 0.25, -1), 1.4, 0.6, 0.05, "team", bevel=0.01)
    p.cylinder("z", (x, y + 0.9, z - 3.0), 0.2, 4.0, 10, "steel")
    p.cylinder("z", (x, y + 0.9, z - 5.15), 0.26, 0.4, 10, "dark")
    p.cylinder("z", (x, y + 0.9, z - 4.9), 0.25, 0.08, 10, "weapon")


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 0.7, 0.3, 12, "trim")
    for sx in (-1, 1):
        p.cylinder("z", (x + sx * 0.3, y + 0.6, z - 0.4), 0.2, 2.2, 10, "paint")
        p.cylinder("z", (x + sx * 0.3, y + 0.6, z - 1.52), 0.12, 0.04, 8, "weapon")


def build_launcher(p):
    x, y, z = SAM
    p.cylinder("y", (x, y + 0.15, z), 0.9, 0.3, 12, "trim")
    p.box((x, y + 0.9, z), (2.4, 1.2, 2.6), "paint", bevel=0.05)
    for i, (cx, cy) in enumerate(((-0.6, 0.6), (0.6, 0.6), (-0.6, 1.2), (0.6, 1.2))):
        p.cylinder("z", (x + cx, y + cy, z - 1.0), 0.22, 1.0, 10, "steel")
        p.ocyl((x + cx, y + cy, z - 1.5), (0, 0, -1), 0.22, 0.3, 10, "weapon", radius2=0.05)
    p.box((x, y + 1.53, z + 0.3), (1.6, 0.05, 1.4), "team", bevel=0.01)


def no_details(p):
    pass


unit.run(__file__, "chs_corsair", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details),
                 unit.PieceSpec("launcher", "base", SAM, build_launcher, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 0.9, T1[2] - 5.4]},
                      "muzzle2": {"parent": "turret2", "at": [0, T2[1] + 0.6, T2[2] - 1.6]},
                      "muzzle3": {"parent": "launcher", "at": [SAM[0], SAM[1] + 0.9, SAM[2] - 1.8]}},
         budget=10000)
