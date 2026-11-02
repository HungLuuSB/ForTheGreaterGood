"""Draftsman (Order advanced constructor bot, T2, footprint 1; batch 2 of
the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_draftsman/build.py

From its blockout: a heavier worker than the Artisan on armoured legs
(tools/bots.py). The `torso` (turns): a broad body with a sensor head, a
team backpack with a lit power band, a hazard-tipped tool arm on the left,
and on a shoulder mount the `nano` (its own piece): a long jointed
construction arm raised forward with a lit emitter (`nano1`). Order reads
clean (M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard, piston  # noqa: E402

TORSO = (0.0, 3.4, 0.0)
BODY = ((0, 4.35, 0), (2.5, 1.9, 2.1))
NANO = (1.3, 5.8, 0.2)


def build_base(p):
    p.box((0, 3.0, 0), (2.0, 0.8, 1.6), "dark", bevel=0.06)
    drum(p, (0, 3.35, 0), 0.7, 0.14, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order", team_face=(1.0, 0.5, 4.5))
    k.head(p, (-0.2, 5.6, -0.4), (1.0, 0.6, 0.9), "order")
    p.box((0, 4.4, 1.45), (2.0, 1.6, 0.9), "team", bevel=0.08)
    p.box((0, 5.0, 1.92), (1.4, 0.14, 0.04), "power")
    for x in (-0.6, 0.6):
        p.box((x, 4.3, 1.93), (0.35, 0.8, 0.04), "trim")
    drum(p, (1.3, 5.45, 0.2), 0.45, 0.4, "steel", "trim", axis="y")
    drum(p, (-1.3, 4.9, -0.1), 0.3, 0.35, "steel", "trim")
    p.box((-1.5, 4.0, -0.3), (0.5, 1.2, 0.5), "trim", bevel=0.05)
    p.box((-1.5, 3.35, -0.6), (0.6, 0.3, 0.7), "paint", bevel=0.04)
    hazard(p, (-1.5, 3.35, -0.96), (1, 0, 0), (0, 0, -1), 0.55, 0.25, stripes=3)
    piston(p, (-1.3, 4.5, 0.1), (-1.4, 3.6, -0.3), r=0.07)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_nano(p):
    k.nano_arm(p, *NANO, 3.2, "order", rise=0.6)
    piston(p, (1.3, 5.45, 0.0), (1.3, 6.0, -1.4), r=0.08)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_draftsman", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("nano", "torso", NANO, build_nano, none)]
         + k.biped(2.8, 0.85, 0.65, "order"),
         attachments={"nano1": {"parent": "nano", "at": [1.3, 6.4, -3.4]}},
         budget=3200,
         previews=k.previews(6.6))
