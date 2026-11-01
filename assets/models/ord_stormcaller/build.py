"""Stormcaller (Order heavy assault bot, lightning rifle, T2, footprint 1;
batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_stormcaller/build.py

From its blockout: broad and armoured on heavy legs (tools/bots.py). The
`torso` (turns): a big body with a raked chest plate, a sensor head and
large team shoulder pads; the right forearm is the lightning rifle, a long
housing ringed with three lit coils ending in twin prongs (`muzzle`); a
capacitor pack with a lit band on the back, a short left arm. Order reads
clean and heavy (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.5, 0.0)
BODY = ((0, 4.5, 0), (2.7, 2.0, 2.2))
RX, RY = 1.75, 3.9


def build_base(p):
    p.box((0, 3.1, 0), (2.2, 0.8, 1.7), "dark", bevel=0.06)
    drum(p, (0, 3.45, 0), 0.75, 0.14, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order")
    p.obox((0, 4.55, -1.2), (1, 0, 0), (0, 0.4, -1), 2.3, 1.4, 0.18, "paint", bevel=0.04)
    p.box((0, 4.6, -1.3), (1.2, 0.5, 0.04), "team", bevel=0.01)
    k.head(p, (0, 5.8, -0.3), (1.0, 0.6, 0.9), "order")
    for sx in (-1, 1):
        k.pad(p, (sx * 1.75, 5.45, 0), (1.15, 0.7, 2.05), "order")
        drum(p, (sx * 1.45, 4.9, 0), 0.35, 0.35, "steel", "trim")
    p.box((RX, 4.5, -0.1), (0.7, 1.0, 0.8), "trim", bevel=0.05)
    p.box((RX, RY, -1.0), (0.8, 0.8, 3.0), "paint", bevel=0.07)
    p.box((RX, RY + 0.42, -0.6), (0.5, 0.04, 1.6), "team")
    for z in (-0.6, -1.3, -2.0):
        p.ocyl((RX, RY, z + 0.08), k.FWD, 0.52, 0.16, 16, "power")
    for dx in (-0.2, 0.2):
        p.box((RX + dx, RY, -2.85), (0.14, 0.3, 0.8), "steel", bevel=0.02)
    p.ocyl((RX, RY, -2.6), k.FWD, 0.12, 0.6, 8, "weapon")
    p.box((-1.75, 4.0, -0.1), (0.7, 1.4, 0.8), "trim", bevel=0.05)
    p.box((-1.75, 3.25, -0.2), (0.8, 0.3, 0.9), "paint", bevel=0.04)
    p.box((0, 4.6, 1.45), (1.8, 1.4, 0.8), "trim", bevel=0.06)
    p.box((0, 5.0, 1.87), (1.2, 0.14, 0.04), "power")
    for x in (-0.55, 0.55):
        p.ocyl((x, 5.35, 1.45), k.UP, 0.2, 0.35, 10, "steel")


def details_torso(p):
    k.shell_details(p, *BODY)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_stormcaller", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + k.biped(2.9, 0.9, 0.75, "order"),
         attachments={"muzzle": {"parent": "torso", "at": [RX, RY, -3.35]}},
         budget=3200,
         previews=k.previews(6.2))
