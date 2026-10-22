"""Radiance (Order beam tower, T2 structure, footprint 2; S-96): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_radiance/build.py

An octagonal armored drum with glowing charge rails on its corner chamfers
(`power`), grilles and team plates; the `shell`, an armored collar round
the pit with hinge rods; two armored lids (`shellL` / `shellR`, client-only
pieces hinged on the collar) standing open beside the turret; the `turret`,
a tall column with a core band (`power`) and a heavy head; and the long
emitter `barrel` with focusing rings, charge rails and a lens (`weapon`).
Retracted (pose in Blockouts/Pending/Registry) the turret sinks into the
drum, the emitter folds down and the lids close: their outer team stripes
face up. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

SHELL_PIVOT = (0.0, 4.0, 0.0)
TURRET_PIVOT = (0.0, 4.0, 0.0)
BARREL_PIVOT = (0.0, 10.8, -1.2)
LID_PIVOT = {"shellL": (-3.4, 4.8, 0.0), "shellR": (3.4, 4.8, 0.0)}
MUZZLE = (0.0, 10.8, -7.1)
S2 = math.sqrt(0.5)


def octagon(h, c):
    return [(-h + c, -h), (h - c, -h), (h, -h + c), (h, h - c), (h - c, h), (-h + c, h), (-h, h - c), (-h, -h + c)]


HEAD = [(-1.5, -1.4), (1.5, -1.4), (1.8, -0.7), (1.8, 1.8), (-1.8, 1.8), (-1.8, -0.7)]


def build_base(p):
    p.prism_y(octagon(7.4, 2.1), 0.0, 0.5, "trim", bevel=0.04)
    p.prism_y(octagon(7.0, 1.9), 0.5, 3.6, "paint", bevel=0.06)
    p.prism_y(octagon(7.0, 1.9), 3.6, 4.0, "paint", bevel=0.04, top_scale=0.93)
    p.box((0, 4.02, 0), (6.6, 0.06, 6.6), "dark")  # pit floor
    for sz in (-1, 1):  # the pit's glowing inner edge (power)
        p.box((0, 4.06, sz * 3.0), (6.0, 0.06, 0.35), "power")
        p.box((sz * 3.0, 4.06, 0), (0.35, 0.06, 5.3), "power")
    for sz in (-1, 1):
        p.box((0, 4.03, sz * 5.35), (4.2, 0.06, 1.0), "team", bevel=0.015)
    # charge rails on the four chamfers: a dark frame and the glowing rail
    for sx in (-1, 1):
        for sz in (-1, 1):
            n = (sx * S2, 0, sz * S2)
            c = 6.05 + 0.03
            p.obox((sx * c * 1.0, 2.05, sz * c), UP, n, 3.0, 1.0, 0.08, "dark")
            p.obox((sx * (c + 0.05), 2.05, sz * (c + 0.05)), UP, n, 2.7, 0.55, 0.1, "power")
            p.box((sx * 6.9, 0.56, sz * 6.9), (0.3, 0.1, 0.3), "light")  # footing corner lights
    # grilles on the flat sides, a sensor strip over each
    for sx, sz in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        w = (3.4, 1.1, 0.06) if sx == 0 else (0.06, 1.1, 3.4)
        p.box((sx * 7.01, 1.9, sz * 7.01), w, "grille")
        s = (2.6, 0.12, 0.05) if sx == 0 else (0.05, 0.12, 2.6)
        p.box((sx * 7.02, 2.75, sz * 7.02), s, "light")
        b = (5.6, 0.25, 0.06) if sx == 0 else (0.06, 0.25, 5.6)
        p.box((sx * 7.02, 3.35, sz * 7.02), b, "power")  # charge band under the cap


def details_base(p):
    box_seams(p, (0, 0, 0), (12.0, 0, 12.0), 3.98)
    for sz in (-1, 1):
        bolts(p, (-4.5, 0.501, sz * 7.1), (4.5, 0.501, sz * 7.1), 10, UP)
        bolts(p, (sz * 7.1, 0.501, -4.5), (sz * 7.1, 0.501, 4.5), 10, UP)
        seam(p, (-4.8, 3.2, sz * 7.0), (4.8, 3.2, sz * 7.0), (0, 0, sz))


def build_shell(p):
    for sz in (-1, 1):
        p.box((0, 4.4, sz * 3.7), (8.4, 0.8, 1.0), "paint", bevel=0.05)
        p.box((sz * 3.7, 4.4, 0), (1.0, 0.8, 6.4), "paint", bevel=0.05)
        p.box((0, 4.81, sz * 3.25), (6.4, 0.04, 0.1), "hazard")
    for sx in (-1, 1):  # hinge rods and knuckles
        p.cylinder("z", (sx * 3.4, 4.8, 0), 0.16, 6.2, 10, "steel")
        for z in (-2.4, 0.0, 2.4):
            p.cylinder("z", (sx * 3.4, 4.8, z), 0.24, 0.6, 10, "trim")


def details_shell(p):
    for sz in (-1, 1):
        bolts(p, (-3.6, 4.801, sz * 3.95), (3.6, 4.801, sz * 3.95), 8, UP)


def lid(sx):
    def build(p):
        x = sx * 3.4
        p.box((x, 6.4, 0), (0.4, 3.2, 6.4), "paint", bevel=0.05)
        for z in (-2.2, 0.0, 2.2):  # outer ribs
            p.box((x + sx * 0.23, 6.3, z), (0.06, 2.6, 0.3), "trim", bevel=0.01)
        p.box((x + sx * 0.215, 7.3, -1.1), (0.04, 0.7, 1.8), "team", bevel=0.01)
        p.box((x + sx * 0.215, 7.3, 1.1), (0.04, 0.7, 1.8), "team", bevel=0.01)
        p.box((x, 7.98, 0), (0.42, 0.06, 6.0), "trim")
        p.box((x - sx * 0.215, 7.2, 0), (0.04, 0.3, 5.6), "power")  # inner face, toward the turret
    return build


def lid_details(sx):
    def details(p):
        bolts(p, (sx * 3.62, 5.2, -3.0), (sx * 3.62, 5.2, 3.0), 8, (sx, 0, 0))
    return details


def build_turret(p):
    col = [(-1.3, -1.0), (-1.0, -1.3), (1.0, -1.3), (1.3, -1.0), (1.3, 1.0), (1.0, 1.3), (-1.0, 1.3), (-1.3, 1.0)]
    p.prism_y(col, 2.6, 9.2, "paint", bevel=0.05)
    p.prism_y([(x * 1.04, z * 1.04) for x, z in col], 9.2, 9.75, "power")  # core band
    for sx in (-1, 1):  # column armor strips
        p.box((sx * 1.33, 7.0, 0), (0.08, 3.6, 1.6), "trim", bevel=0.02)
    p.prism_y(HEAD, 9.75, 11.6, "paint", bevel=0.06, top_scale=0.9)
    p.box((0, 11.62, 0.5), (2.2, 0.06, 1.8), "team", bevel=0.015)
    for sx in (-1, 1):
        p.box((sx * 1.8, 10.8, 0.6), (0.05, 0.2, 2.2), "light")
    p.box((0, 10.6, 1.82), (2.6, 0.9, 0.08), "grille")
    p.box((0, 10.8, -1.55), (1.5, 1.2, 0.4), "trim", bevel=0.05)  # mantlet


def details_turret(p):
    ring(p, (0, 11.601, 0.5), UP, 0.45)
    seam(p, (-1.5, 11.0, -1.42), (1.5, 11.0, -1.42), (0, 0, -1))
    bolts(p, (-1.0, 8.6, -1.36), (1.0, 8.6, -1.36), 5, (0, 0, -1))


def build_barrel(p):
    p.cylinder("z", (0, 10.8, -4.0), 0.42, 5.6, 14, "paint")
    p.cylinder("z", (0, 10.8, -2.9), 0.52, 1.3, 14, "trim")  # coil sleeve
    for z in (-2.55, -3.25):
        p.cylinder("z", (0, 10.8, z), 0.55, 0.2, 14, "weapon")
    for z in (-3.9, -4.8, -5.7):
        p.cylinder("z", (0, 10.8, z), 0.5, 0.16, 14, "steel")
    for a in (0, 90, 180, 270):  # charge rails along the emitter
        r = math.radians(a)
        p.box((math.cos(r) * 0.43, 10.8 + math.sin(r) * 0.43, -4.8),
              (0.1 if a in (0, 180) else 0.14, 0.14 if a in (0, 180) else 0.1, 3.2), "weapon")
    p.cylinder("z", (0, 10.8, -6.7), 0.62, 0.5, 14, "steel")
    p.cylinder("z", (0, 10.8, -6.98), 0.56, 0.08, 14, "weapon")  # lens


def details_barrel(p):
    ring(p, (0, 10.8, -6.951), (0, 0, -1), 0.56)


unit.run(__file__, "ord_radiance", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("shell", "base", SHELL_PIVOT, build_shell, details_shell),
                 unit.PieceSpec("shellL", "shell", LID_PIVOT["shellL"], lid(-1), lid_details(-1)),
                 unit.PieceSpec("shellR", "shell", LID_PIVOT["shellR"], lid(1), lid_details(1)),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL_PIVOT, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=6000)
