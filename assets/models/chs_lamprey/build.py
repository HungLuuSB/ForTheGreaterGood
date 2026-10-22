"""Lamprey (Chaos submarine, T1 naval, always submerged): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_lamprey/build.py

A crude diesel submarine: a round hull with a rounded nose and a tail cone,
cross planes and a team rudder, a long low sail with a team band, a snorkel
and an amber sensor eye, salvage tanks strapped along the hull, amber hull
strips (running channel); `turret1` a bow torpedo block with its tube light
(weapon channel), `turret2` a small aft launcher (BAR style, M-15; Chaos
reads light, M-14). Model space: the hull's axis at y = -0.6. Writes export/
through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import ring  # noqa: E402

T1 = (0.0, 0.2, -3.4)
T2 = (0.0, 0.2, 3.0)
Y = -0.6


def build_base(p):
    p.cylinder("z", (0, Y, 0), 1.1, 8.4, 12, "paint")
    p.ocyl((0, Y, -4.2), (0, 0, -1), 1.1, 1.0, 12, "paint", radius2=0.6)
    p.ocyl((0, Y, -5.2), (0, 0, -1), 0.6, 0.3, 12, "paint", radius2=0.2)
    p.cylinder("z", (0, Y, 5.0), 0.6, 1.6, 10, "dark")  # tail cone
    p.cylinder("z", (0, Y, 4.3), 0.66, 0.14, 10, "light", cap_kinds=("dark", "dark"))  # tail ring
    p.box((0, 0.3, 1.5), (0.14, 0.04, 2.2), "light")  # spine strip
    p.box((0, Y, 5.3), (3.2, 0.12, 0.8), "trim")
    p.box((0, Y + 0.2, 5.6), (0.15, 1.8, 1.0), "team")
    # long low sail, team band, snorkel, sensor eye
    p.box((0, 0.95, -0.8), (1.0, 1.3, 3.0), "paint", bevel=0.05)
    p.box((0, 1.3, -0.8), (1.04, 0.4, 1.8), "team")
    p.box((0, 2.1, -0.2), (0.2, 1.0, 0.2), "steel")
    p.box((0, 1.2, -2.32), (0.6, 0.16, 0.05), "light")
    for sx in (-1, 1):  # strapped salvage tanks, hull strips
        p.cylinder("z", (sx * 1.15, Y - 0.3, 0.6), 0.32, 3.4, 8, "trim")
        p.box((sx * 1.15, Y + 0.03, 0.6), (0.14, 0.04, 2.8), "light")  # along the tank tops
        p.box((sx * 1.6, Y, 5.3), (0.06, 0.1, 0.6), "light")
        p.box((sx * 1.0, Y + 0.5, -0.4), (0.04, 0.14, 5.4), "light")  # hull strips above the tanks


def details_base(p):
    for z in (-2.5, 0.0, 2.5):
        ring(p, (0, Y, z), (0, 0, -1), 1.1)


def build_turret1(p):
    p.box((0, 0.4, -3.4), (1.0, 0.4, 0.8), "trim", bevel=0.03)
    p.box((0, 0.4, -3.81), (0.6, 0.2, 0.04), "weapon")


def build_turret2(p):
    p.box((0, 0.4, 3.0), (0.8, 0.3, 0.6), "trim", bevel=0.03)
    p.box((0, 0.4, 2.69), (0.5, 0.14, 0.04), "weapon")


def no_details(p):
    pass


unit.run(__file__, "chs_lamprey", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, 0.4, -3.9]},
                      "muzzle2": {"parent": "turret2", "at": [0, 0.4, 2.6]}},
         team_pieces=["base"])
