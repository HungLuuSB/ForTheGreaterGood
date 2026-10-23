"""Siren (Chaos naval jammer, T2 ship): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_siren/build.py

New mesh from its blockout, at the T2 small-ship size (size-scale.md: ~14
long): a low narrow hull with a raked bow and a dark waterline band, team
plates fore and aft, a squat deckhouse with an amber slit and a generator
vent, hazard striping, tyre fenders, amber gunwale strips; `turret1` and
`turret2` two turning emitter masts, each a lattice post ringed with
glowing rods and a cap lamp (`muzzle1`, `muzzle2` at the caps). Unarmed.
Model space, waterline at y = 0. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.6
T1 = (0.0, DECK, -3.6)
T2 = (0.0, DECK, 3.4)


def mast(p, c):
    x, y, z = c
    p.cylinder("y", (x, y + 0.15, z), 0.7, 0.3, 12, "trim")
    for dx in (-0.2, 0.2):
        for dz in (-0.2, 0.2):
            p.box((x + dx, y + 1.8, z + dz), (0.08, 3.0, 0.08), "paint")
    for k in range(8):
        a = k * math.pi / 4
        c, s = math.cos(a), math.sin(a)
        p.obox((x + c * 0.4, y + 2.6, z + s * 0.4), (c, 0, s), (0, 1, 0), 0.5, 0.08, 0.08, "steel")
        p.cylinder("y", (x + c * 0.65, y + 2.6, z + s * 0.65), 0.06, 0.9, 6, "power")
    p.box((x, y + 3.4, z), (0.5, 0.2, 0.5), "trim")
    p.box((x, y + 3.6, z), (0.22, 0.16, 0.22), "light")


def build_base(p):
    p.prism_x([(-8.4, DECK + 0.2), (-6.0, -0.6), (6.0, -0.6), (6.0, DECK)], -2.0, 2.0, "paint", bevel=0.06)
    p.prism_x([(-7.6, 0.0), (-5.7, -0.45), (6.05, -0.45), (6.05, 0.0)], -2.07, 2.07, "dark", bevel=0.02)
    p.box((0, DECK + 0.03, -6.0), (2.6, 0.05, 1.6), "team", bevel=0.012)
    p.box((0, DECK + 0.03, 5.4), (2.6, 0.05, 1.0), "team", bevel=0.012)
    p.box((0, DECK + 0.6, 0.0), (2.4, 1.2, 2.6), "paint", bevel=0.05)
    p.box((0, DECK + 0.85, -1.32), (1.8, 0.24, 0.05), "light")
    p.box((0, DECK + 1.22, 0.0), (1.4, 0.04, 1.4), "grille")
    p.box((0.7, DECK + 1.24, 0.6), (0.6, 0.05, 0.6), "power")
    hazard(p, (0, DECK + 0.03, 1.8), (1, 0, 0), UP, 3.2, 0.35, stripes=7)
    for sx in (-1, 1):
        p.box((sx * 2.02, 1.2, 0.0), (0.05, 0.14, 9.0), "light")
        for z in (-4.0, 2.0):
            p.ocyl((sx * 2.1, 0.8, z), (sx, 0, 0), 0.4, 0.26, 10, "rubber")
    p.box((0, 0.8, 6.07), (3.0, 0.2, 0.05), "light")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -4.8), (1.6, DECK + 0.001, -4.8), 6, UP)


def build_turret1(p):
    mast(p, T1)


def build_turret2(p):
    mast(p, T2)


def no_details(p):
    pass


unit.run(__file__, "chs_siren", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [T1[0], T1[1] + 3.7, T1[2]]},
                      "muzzle2": {"parent": "turret2", "at": [T2[0], T2[1] + 3.7, T2[2]]}})
