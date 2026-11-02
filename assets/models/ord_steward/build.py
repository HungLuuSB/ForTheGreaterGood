"""Steward (Order fast assist and repair bot, T2, footprint 1; batch 2 of
the BAR roster, 2026-11-01): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_steward/build.py

From its blockout: light and long-legged (tools/bots.py). The `torso`
(turns): a small body with a team chest plate and a visored head; a mast on
its back carries the `nano` (its own piece), a crane arm arching over the
head and down to a lit emitter in front (`nano1`). Order reads clean
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum  # noqa: E402

TORSO = (0.0, 3.3, 0.0)
BODY = ((0, 3.9, 0), (1.5, 1.2, 1.3))
NANO = (0.35, 5.8, 0.6)


def build_base(p):
    p.box((0, 2.9, 0), (1.3, 0.7, 1.1), "dark", bevel=0.05)
    drum(p, (0, 3.25, 0), 0.5, 0.1, "steel", "trim", axis="y")


def build_torso(p):
    k.shell(p, *BODY, "order", team_face=(0.8, 0.4, 3.95))
    k.head(p, (-0.15, 4.73, -0.2), (0.7, 0.45, 0.7), "order")
    p.box((0.35, 5.0, 0.6), (0.35, 1.6, 0.35), "paint", bevel=0.05)
    p.box((0.35, 5.0, 0.79), (0.2, 1.2, 0.03), "team")
    p.box((-0.3, 3.9, 0.8), (0.7, 0.8, 0.35), "trim", bevel=0.04)
    p.box((-0.3, 4.1, 0.99), (0.4, 0.1, 0.03), "power")
    for sx in (-1, 1):
        p.box((sx * 0.9, 3.75, -0.1), (0.3, 0.8, 0.35), "trim", bevel=0.04)


def details_torso(p):
    k.shell_details(p, *BODY)


def build_nano(p):
    k.nano_arm(p, *NANO, 2.4, "order", rise=-0.6)


none = lambda p: None  # noqa: E731

unit.run(__file__, "ord_steward", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, none),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso),
                 unit.PieceSpec("nano", "torso", NANO, build_nano, none)]
         + k.biped(2.7, 0.55, 0.42, "order"),
         attachments={"nano1": {"parent": "nano", "at": [0.35, 5.2, -2.2]}},
         budget=2600,
         previews=k.previews(6.0))
