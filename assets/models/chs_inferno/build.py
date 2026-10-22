"""Inferno (Chaos beam tower, T2 structure, footprint 2; S-96): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_inferno/build.py

A low gunmetal drum ringed with reactive blocks, open-framed at the front
and back round two big glowing charge coils (`power`), a fuel tank behind;
the `shell`, a crude welded collar round the pit; two crude lids (`shellL`
/ `shellR`, client-only, hinged on the collar) with welded strips; the
`turret`, a thin ribbed column with a glowing collar under a heavy head and
its big amber "eye" lens (`weapon`); and the short forked emitter `barrel`
with glowing coil rings. Retracts like Order's Radiance (pose in
Blockouts/Pending/Registry). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, ring, seam  # noqa: E402

SHELL_PIVOT = (0.0, 3.0, 0.0)
TURRET_PIVOT = (0.0, 3.0, 0.0)
BARREL_PIVOT = (0.0, 9.6, -1.4)
LID_PIVOT = {"shellL": (-3.2, 3.6, 0.0), "shellR": (3.2, 3.6, 0.0)}
MUZZLE = (0.0, 9.6, -5.5)


def octagon(h, c):
    return [(-h + c, -h), (h - c, -h), (h, -h + c), (h, h - c), (h - c, h), (-h + c, h), (-h, h - c), (-h, -h + c)]


def build_base(p):
    p.prism_y(octagon(7.0, 1.6), 0.0, 0.5, "trim", bevel=0.04)
    p.prism_y(octagon(6.5, 1.4), 0.5, 2.6, "paint", bevel=0.05, top_scale=0.95)
    p.prism_y(octagon(6.15, 1.3), 2.6, 3.0, "dark", bevel=0.03)
    p.box((0, 3.02, 0), (6.2, 0.06, 6.2), "dark")  # pit floor
    p.box((0, 3.03, 5.0), (3.6, 0.06, 1.4), "team", bevel=0.015)
    # charge coils in open frames, front and back: brackets, coil, end caps
    for sz in (-1, 1):
        z = sz * 6.75
        p.box((0, 1.0, z), (9.6, 0.3, 0.9), "dark")
        for x in (-4.6, 4.6):
            p.box((x, 2.0, z), (0.4, 2.0, 0.9), "trim", bevel=0.03)
        p.cylinder("x", (0, 2.05, z), 0.55, 8.6, 14, "power")
        for x in (-2.9, 0.0, 2.9):
            p.cylinder("x", (x, 2.05, z), 0.62, 0.22, 14, "steel")
        p.box((0, 2.95, z), (9.6, 0.2, 0.9), "trim")
    # reactive blocks along the sides, a running light at each end
    for sx in (-1, 1):
        for z in (-3.6, -1.2, 1.2, 3.6):
            p.box((sx * 6.55, 1.55, z), (0.3, 1.2, 2.1), "era", bevel=0.03)
        p.box((sx * 6.72, 2.4, 0), (0.05, 0.16, 8.6), "light")
    # fuel tank, back left, with a team band
    p.cylinder("y", (-4.9, 4.3, 4.4), 1.1, 2.6, 14, "steel")
    p.cylinder("y", (-4.9, 4.4, 4.4), 1.14, 0.4, 14, "team")
    p.cylinder("y", (-4.9, 5.68, 4.4), 0.4, 0.16, 10, "dark")


def details_base(p):
    box_seams(p, (0, 0, 0), (11.0, 0, 11.0), 2.99)
    for sx in (-1, 1):
        bolts(p, (sx * 6.9, 0.501, -4.8), (sx * 6.9, 0.501, 4.8), 10, UP)
    seam(p, (-4.0, 2.2, -6.45), (4.0, 2.2, -6.45), (0, 0, -1))


def build_shell(p):
    for sz in (-1, 1):
        p.box((0, 3.3, sz * 3.5), (8.0, 0.6, 1.0), "trim", bevel=0.03)
        p.box((sz * 3.5, 3.3, 0), (1.0, 0.6, 6.0), "trim", bevel=0.03)
        p.box((0, 3.61, sz * 3.1), (5.6, 0.04, 0.12), "hazard")
    for sx in (-1, 1):
        p.cylinder("z", (sx * 3.2, 3.6, 0), 0.15, 5.8, 8, "steel")
        for z in (-2.2, 2.2):
            p.box((sx * 3.2, 3.6, z), (0.5, 0.5, 0.6), "dark")


def details_shell(p):
    for sz in (-1, 1):
        bolts(p, (-3.4, 3.601, sz * 3.8), (3.4, 3.601, sz * 3.8), 6, UP)


def lid(sx):
    def build(p):
        x = sx * 3.2
        p.box((x, 5.1, 0), (0.5, 3.0, 6.0), "paint", bevel=0.04)
        for y in (4.3, 5.9):  # welded strips on the outer face
            p.box((x + sx * 0.28, y, 0), (0.08, 0.25, 5.8), "trim")
        p.box((x + sx * 0.27, 5.1, 1.6), (0.04, 0.9, 1.6), "team", bevel=0.01)
        for z in (-2.0, -0.6):
            p.box((x + sx * 0.33, 5.1, z), (0.16, 0.9, 0.9), "era", bevel=0.02)
        p.box((x - sx * 0.27, 6.2, 0), (0.04, 0.3, 5.2), "power")  # inner face, toward the turret
    return build


def lid_details(sx):
    def details(p):
        bolts(p, (sx * 3.46, 6.45, -2.8), (sx * 3.46, 6.45, 2.8), 7, (sx, 0, 0))
    return details


def build_turret(p):
    p.box((0, 5.6, 0), (1.6, 6.2, 1.6), "trim", bevel=0.04)
    for y in (4.4, 5.6, 6.8):  # ribs
        p.box((0, y, 0), (1.8, 0.2, 1.8), "dark", bevel=0.02)
    p.cylinder("y", (0, 8.45, 0), 1.05, 0.4, 12, "power")  # glowing collar
    p.prism_y([(-1.5, -1.0), (1.5, -1.0), (1.5, 1.5), (-1.5, 1.5)], 8.7, 10.5, "paint", bevel=0.05, top_scale=0.86)
    p.box((0, 10.52, 0.4), (1.9, 0.06, 1.5), "team", bevel=0.015)
    p.cylinder("z", (0, 9.6, -1.05), 0.9, 0.3, 14, "dark")  # eye housing
    p.cylinder("z", (0, 9.6, -1.25), 0.72, 0.16, 14, "weapon")  # the eye
    for sx in (-1, 1):
        p.box((sx * 1.52, 9.9, 0.3), (0.05, 0.18, 1.8), "light")
        p.box((sx * 1.6, 9.0, 0.6), (0.2, 0.6, 1.2), "era", bevel=0.02)
    p.box((0, 9.6, 1.52), (2.2, 0.8, 0.06), "grille")


def details_turret(p):
    ring(p, (0, 9.6, -1.331), (0, 0, -1), 0.6)
    bolts(p, (-1.3, 10.3, -1.02), (1.3, 10.3, -1.02), 5, (0, 0, -1))


def build_barrel(p):
    p.cylinder("z", (0, 9.6, -3.0), 0.36, 3.2, 12, "dark")
    for z in (-2.3, -3.0, -3.7):
        p.cylinder("z", (0, 9.6, z), 0.46, 0.22, 12, "weapon")
    for sx in (-1, 1):  # the fork
        p.box((sx * 0.42, 9.6, -4.6), (0.16, 0.22, 1.9), "trim", bevel=0.02)
    p.cylinder("z", (0, 9.6, -4.75), 0.24, 1.3, 10, "steel")
    p.cylinder("z", (0, 9.6, -5.42), 0.3, 0.06, 10, "weapon")


def details_barrel(p):
    seam(p, (0, 9.97, -1.6), (0, 9.97, -4.4), UP)


unit.run(__file__, "chs_inferno", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("shell", "base", SHELL_PIVOT, build_shell, details_shell),
                 unit.PieceSpec("shellL", "shell", LID_PIVOT["shellL"], lid(-1), lid_details(-1)),
                 unit.PieceSpec("shellR", "shell", LID_PIVOT["shellR"], lid(1), lid_details(1)),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret),
                 unit.PieceSpec("barrel", "turret", BARREL_PIVOT, build_barrel, details_barrel)],
         attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
         budget=6000)
