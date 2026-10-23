"""Kraken (Chaos cruiser, T2 ship, footprint 3): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_kraken/build.py

New mesh from its blockout, at the T2 capital-ship size (size-scale.md:
29-30 long): a low long hull with a raked bow and a dark waterline band,
welded patches, team plates on the foredeck and the bridge roof, hazard
striping, a squat bridge with an amber slit, two funnels with hot bands, a
braced lattice mast with the client-turned radar array (`radar`, M-27),
tyre fenders, amber gunwale strips; `turret1` a triple open gun mount
forward with a slab shield and a team plate (`muzzle1`), `turret2` a quad
flak mount aft (`muzzle2`). Model space, waterline at y = 0. Chaos reads
rugged and improvised (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

DECK = 2.2
T1 = (0.0, DECK, -9.0)
T2 = (0.0, DECK, 9.2)
RADAR = (0.0, 10.0, 0.4)


def build_base(p):
    p.prism_x([(-15.4, DECK + 0.3), (-11.4, -0.9), (13.8, -0.9), (13.8, DECK)], -3.6, 3.6, "paint", bevel=0.08)
    p.prism_x([(-13.6, 0.0), (-11.2, -0.6), (13.85, -0.6), (13.85, 0.0)], -3.67, 3.67, "dark", bevel=0.02)
    for x, z, w, d in ((2.0, -4.0, 1.4, 3.0), (-1.8, 5.6, 1.6, 2.4)):
        p.box((x, DECK + 0.03, z), (w, 0.04, d), "steel", bevel=0.01)
    p.box((0, DECK + 0.03, -12.6), (4.0, 0.05, 2.4), "team", bevel=0.012)
    hazard(p, (0, DECK + 0.03, -5.8), (1, 0, 0), UP, 6.0, 0.4, stripes=12)
    # squat bridge, amber slit, team roof, two funnels
    p.box((0, DECK + 1.3, -1.6), (4.6, 2.6, 5.0), "paint", bevel=0.06)
    p.box((0, DECK + 1.9, -4.12), (3.8, 0.36, 0.05), "light")
    p.box((0, DECK + 2.63, -1.6), (4.0, 0.05, 4.4), "team", bevel=0.012)
    for z in (2.0, 3.8):
        p.cylinder("y", (0.0, DECK + 3.6, z), 0.85, 2.6, 12, "trim")
        p.cylinder("y", (0.0, DECK + 4.65, z), 0.88, 0.25, 12, "light")
    # braced lattice mast
    for dx in (-0.5, 0.5):
        for dz in (-0.5, 0.5):
            p.box((dx, DECK + 5.0, 0.4 + dz), (0.15, 5.4, 0.15), "paint")
    for y in (DECK + 3.4, DECK + 5.6):
        p.box((0, y, 0.4), (1.2, 0.1, 1.2), "steel")
    p.box((0, DECK + 7.5, 0.4), (1.3, 0.2, 1.3), "trim")
    for sx in (-1, 1):
        p.box((sx * 3.62, 1.5, 0.0), (0.05, 0.16, 24.0), "light")
        for z in (-9.0, -1.0, 7.0):
            p.ocyl((sx * 3.7, 0.95, z), (sx, 0, 0), 0.55, 0.34, 10, "rubber")
    p.box((0, 1.1, 13.87), (5.0, 0.24, 0.05), "light")
    p.cylinder("y", (0, DECK + 0.05, -9.0), 1.9, 0.1, 18, "dark")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((0, 10.2, 0.4), (3.2, 0.8, 0.3), "paint", bevel=0.03)
        p.box((0, 10.2, 0.24), (3.0, 0.6, 0.04), "dark")
        p.box((0, 10.2, 0.22), (3.05, 0.06, 0.03), "light")
        p.box((0, 10.62, 0.4), (2.4, 0.04, 0.2), "team")


def details_base(p):
    bolts(p, (-3.0, DECK + 0.001, -10.6), (3.0, DECK + 0.001, -10.6), 9, UP)
    ring(p, (0.0, DECK + 4.901, 2.0), UP, 0.6)


def build_turret1(p):
    x, y, z = T1
    p.cylinder("y", (x, y + 0.2, z), 1.8, 0.4, 18, "trim")
    p.box((x, y + 1.0, z + 0.5), (2.6, 1.2, 2.2), "paint", bevel=0.05)
    p.obox((x, y + 1.1, z - 0.9), (1, 0, 0), (0, 0.25, -1), 3.6, 1.7, 0.3, "era", bevel=0.05)
    p.obox((x, y + 1.2, z - 1.08), (1, 0, 0), (0, 0.25, -1), 2.0, 0.7, 0.05, "team", bevel=0.01)
    for xx in (-0.85, 0.0, 0.85):
        p.cylinder("z", (xx, y + 1.0, z - 3.6), 0.2, 4.6, 10, "steel")
        p.cylinder("z", (xx, y + 1.0, z - 6.05), 0.26, 0.4, 10, "dark")
        p.cylinder("z", (xx, y + 1.0, z - 5.8), 0.25, 0.08, 10, "weapon")


def build_turret2(p):
    x, y, z = T2
    p.cylinder("y", (x, y + 0.15, z), 1.0, 0.3, 14, "trim")
    p.box((x, y + 0.7, z + 0.3), (1.6, 0.8, 1.2), "paint", bevel=0.04)
    p.box((x, y + 1.12, z + 0.3), (1.2, 0.04, 0.8), "team")
    for xx in (-0.5, -0.17, 0.17, 0.5):
        p.cylinder("z", (xx, y + 0.8, z - 1.0), 0.09, 1.8, 8, "steel")
        p.cylinder("z", (xx, y + 0.8, z - 1.9), 0.12, 0.08, 8, "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_kraken", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, T1[1] + 1.0, T1[2] - 6.3]},
                      "muzzle2": {"parent": "turret2", "at": [0, T2[1] + 0.8, T2[2] - 2.0]}},
         budget=10000)
