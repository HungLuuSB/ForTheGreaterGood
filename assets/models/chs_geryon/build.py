"""Geryon (Chaos triple laser tower, T1 structure, footprint 2; S-157):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_geryon/build.py

From its approved blockout (the user's reference 2026-10-24: a tall column
with a heavy head of three long barrels). Big shapes first: a square armored
footing with hazard striping, a tall slab column with team panels down its
faces. The `turret` (yaw): an angular armored head with a team roof plate
and an amber sensor. The `mount` (pitch, -60..+60 degrees): a block holding
the `drum`, a rotary cluster of three long green laser barrels in a
triangle about its forward axis; only the top barrel fires and the client
turns the drum 120 degrees per shot (`muzzle1` on top at rest). Each barrel
is its own client piece (`barrel1..3`, recoil along +Z). Chaos reads rugged
and improvised (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import hazard, rect, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

CY, CZ, R = 12.6, -1.4, 0.9  # the drum's axis and the barrels' distance from it
TURRET = (0.0, 10.8, 0.3)
MOUNT = (0.0, CY, CZ + 1.2)
DRUM = (0.0, CY, CZ)


def at(k, z):
    a = math.radians(90 + (k - 1) * 120)
    return (R * math.cos(a), CY + R * math.sin(a), z)


def build_base(p):
    p.prism_y(rect(0, 0, 3.5, 3.5), 0.0, 1.2, "dark", bevel=0.08)
    p.prism_y(rect(0, 0, 2.5, 2.5), 1.2, 3.2, "trim", bevel=0.08, top_scale=0.9)
    p.prism_y(rect(0, 0.3, 1.7, 1.5), 3.2, 10.8, "paint", bevel=0.1)
    for sx in (-1, 1):
        p.box((sx * 0.9, 7.0, -1.22), (1.0, 6.4, 0.06), "team", bevel=0.01)
        p.box((sx * 1.72, 7.0, 0.3), (0.06, 6.4, 1.6), "team", bevel=0.01)
    p.box((0, 7.0, -1.24), (0.3, 6.6, 0.08), "dark")
    p.box((0, 9.6, 1.82), (2.0, 1.4, 0.06), "power")
    hazard(p, (0, 1.22, -3.0), (1, 0, 0), UP, 5.0, 0.5, stripes=12)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 3.2, 1.26, sz * 3.2), (0.4, 0.1, 0.4), "light")
    skirt_square(p, 3.5)
    louver(p, (0, 6.0, 1.83), (1, 0, 0), (0, 0, 1), 1.6, 1.6)
    for sx in (-1, 1):
        glow_strip(p, (sx * 1.58, 3.6, -1.23), (sx * 1.58, 10.4, -1.23), (0, 0, -1), width=0.1)
    clamped_cable(p, [(-3.0, 1.2, 2.6), (-1.8, 3.3, 2.0), (-1.75, 10.5, 1.9)], r=0.1)


def details_base(p):
    band_box(p, 5.2, 0, 0.3, 1.7, 1.5)
    band_box(p, 8.8, 0, 0.3, 1.7, 1.5)
    rivets(p, (-1.6, 4.0, -1.21), (1.6, 4.0, -1.21), 7, (0, 0, -1))
    rivets(p, (-1.6, 10.2, -1.21), (1.6, 10.2, -1.21), 7, (0, 0, -1))


def build_turret(p):
    p.prism_y(rect(0, 0.8, 1.7, 1.8), 11.0, 13.8, "paint", bevel=0.1, top_scale=0.86)
    p.prism_x([(-1.0, 13.8), (0.6, 13.8), (0.6, 14.8), (0.0, 14.8)], -1.7, 1.7, "paint", bevel=0.06)
    p.box((0, 13.84, 1.6), (2.0, 0.05, 1.4), "team", bevel=0.01)
    p.box((1.3, 13.4, -1.02), (0.5, 0.36, 0.06), "head")
    louver(p, (-1.72, 12.2, 1.2), (0, 0, 1), (-1, 0, 0), 1.4, 1.0)
    antenna(p, (1.2, 14.8, 1.8), 1.2)


def details_turret(p):
    band_box(p, 12.0, 0, 0.8, 1.7, 1.8)
    rivets(p, (-1.5, 11.4, -1.01), (1.5, 11.4, -1.01), 6, (0, 0, -1))


def build_mount(p):
    p.box((0, CY, CZ + 1.0), (2.2, 2.2, 0.8), "dark", bevel=0.06)


def details_mount(p):
    ring(p, (0, CY + 1.11, CZ + 1.0), UP, 0.4)


def build_drum(p):
    p.cylinder("z", (0, CY, CZ), 1.4, 1.2, 18, "steel", bevel=0.05)
    p.cylinder("z", (0, CY, CZ - 3.0), 1.3, 0.3, 18, "trim")
    for k in (1, 2, 3):
        with p.sub(f"barrel{k}", at(k, CZ - 0.6), "slide", (0, 0, 1), 0.5):
            p.ocyl(at(k, CZ - 0.6), (0, 0, -1), 0.3, 5.0, 12, "steel")
            p.ocyl(at(k, CZ - 2.2), (0, 0, -1), 0.38, 0.3, 12, "dark")
            p.ocyl(at(k, CZ - 5.0), (0, 0, -1), 0.36, 0.5, 12, "dark")
            p.ocyl(at(k, CZ - 5.55), (0, 0, -1), 0.24, 0.1, 12, "weapon")


def details_drum(p):
    ring(p, (0, CY, CZ - 0.61), (0, 0, -1), 0.5)


unit.run(__file__, "chs_geryon", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("mount", "turret", MOUNT, build_mount, details_mount),
                 unit.PieceSpec("drum", "mount", DRUM, build_drum, details_drum)],
         attachments={f"muzzle{k}": {"parent": f"barrel{k}", "at": [round(v, 3) for v in at(k, CZ - 5.8)]} for k in (1, 2, 3)},
         budget=4000,
         previews=[("35", (-20, 18, -24), (0, 7.5, 0), 40),
                   ("close", (-10, 16, -11), (0, 12.4, -2.0), 38)])
