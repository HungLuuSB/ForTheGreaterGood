"""Silence (Order submarine, T1 naval, always submerged): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_silence/build.py

A heavy attack submarine: a long round hull with a blunt nose and a tapered
tail, cross planes and a team rudder, a tall armored sail with a team band,
a periscope and a cyan sail light, cyan hull strips (running channel: the
only thing that reads through the water); `turret1` a bow torpedo door
block with its tube light (weapon channel), `turret2` a small aft launcher
(BAR style, M-15; Order reads heavy, M-14). Model space: the hull's axis at
y = -0.6. Writes export/ through tools/unit.py.
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
    p.cylinder("z", (0, Y, 0), 1.1, 8.0, 16, "paint")
    p.ocyl((0, Y, -4.0), (0, 0, -1), 1.1, 1.3, 16, "paint", radius2=0.45)  # nose
    p.ocyl((0, Y, 4.0), (0, 0, 1), 1.1, 2.0, 16, "paint", radius2=0.35)  # tail taper
    p.cylinder("z", (0, Y, 6.2), 0.35, 0.4, 10, "dark")  # propeller hub
    p.box((0, Y, 5.3), (3.2, 0.12, 0.8), "trim")  # stern planes
    p.box((0, Y + 0.2, 5.6), (0.15, 1.8, 1.0), "team")  # rudder
    # sail: tall, armored, team band, periscope, light
    p.prism_x([(-2.6, 0.3), (-0.2, 0.3), (-0.4, 1.9), (-2.2, 1.9)], -0.45, 0.45, "paint", bevel=0.05)
    p.box((0, 1.5, -1.4), (0.94, 0.4, 1.6), "team")
    p.box((0, 1.0, -1.4), (1.6, 0.1, 0.6), "trim")  # sail planes
    p.cylinder("y", (0, 2.3, -1.0), 0.07, 0.8, 6, "steel")
    p.box((0, 1.92, -2.3), (0.5, 0.12, 0.06), "light")
    for sx in (-1, 1):  # hull strips
        p.box((sx * 1.09, Y + 0.3, 0.0), (0.04, 0.12, 6.0), "light")
        p.box((sx * 1.6, Y, 5.3), (0.06, 0.1, 0.6), "light")


def details_base(p):
    for z in (-2.0, 1.0, 3.5):
        ring(p, (0, Y, z), (0, 0, -1), 1.1)


def build_turret1(p):
    p.box((0, 0.4, -3.4), (1.0, 0.4, 0.8), "trim", bevel=0.04)
    p.box((0, 0.4, -3.81), (0.6, 0.2, 0.04), "weapon")


def build_turret2(p):
    p.box((0, 0.4, 3.0), (0.8, 0.3, 0.6), "trim", bevel=0.03)
    p.box((0, 0.4, 2.69), (0.5, 0.14, 0.04), "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_silence", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [0, 0.4, -3.9]},
                      "muzzle2": {"parent": "turret2", "at": [0, 0.4, 2.6]}},
         team_pieces=["base"])
