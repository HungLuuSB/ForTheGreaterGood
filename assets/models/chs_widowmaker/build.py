"""Widowmaker (Chaos all-terrain assault spider mech, missiles, T3,
footprint 3; batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig
data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_widowmaker/build.py

From its blockout, laid out at bot size and scaled x1.8 (unit.run `scale`;
the blockout scales the same). An armoured dark body and a ribbed abdomen
glowing amber on six long jointed legs, knees high, pistons and hooked
claws (tools/botkit.py `spider`, the client's tripod gait), spikes along
its back. On top the `torso` (turns): a raised cockpit turret with an
amber eye slit and a team plate, a missile pod either side with four lit
cells (`muzzle` right, `muzzle2` left). Chaos reads crude and brutal
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402

S = 1.8
TORSO = (0.0, 2.95, -0.2)
PX, PY = 1.3, 3.5


def build_base(p):
    p.box((0, 2.4, 0), (2.4, 1.1, 3.2), "dark", bevel=0.1)
    p.prism_x([(-1.6, 1.9), (-1.6, 2.9), (-2.3, 2.35), (-2.15, 1.95)], -1.1, 1.1, "paint", bevel=0.05)
    p.box((0, 1.8, 0), (2.0, 0.15, 2.8), "trim")
    p.box((0, 2.6, 2.1), (2.0, 1.2, 1.6), "paint", bevel=0.1)
    for z in (1.6, 2.0, 2.4):
        p.box((0, 3.22, z), (1.4, 0.06, 0.2), "power")
    for x in (-0.6, 0.6):
        p.ocyl((x, 3.2, 2.5), (0, 1, 0.5), 0.2, 0.8, 6, "steel", radius2=0.02)
    drum(p, (0, 2.97, -0.2), 0.9, 0.05, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-1.0, 2.1, -1.61), (1.0, 2.1, -1.61), 5, k.FWD)


def build_torso(p):
    k.shell(p, (0, 3.5, -0.4), (1.8, 1.1, 1.8), "chaos")
    p.box((0, 3.7, -1.32), (1.2, 0.15, 0.04), "head")
    p.box((0, 4.07, -0.2), (1.0, 0.04, 0.8), "team", bevel=0.01)
    for sx in (-1, 1):
        x = sx * PX
        drum(p, (sx * 0.95, PY, -0.4), 0.25, 0.3, "steel", "trim")
        p.box((x, PY, -0.5), (0.8, 0.8, 1.4), "trim", bevel=0.06)
        p.box((x, PY, -1.19), (0.7, 0.7, 0.05), "dark", bevel=0.02)
        k.tubes(p, x, PY, -1.22, 2, 2, 0.34, 0.12)
        p.ocyl((x, PY + 0.4, 0.0), k.UP, 0.12, 0.45, 6, "steel", radius2=0.02)


none = lambda p: None  # noqa: E731

# its wreck lies belly down, six legs sprawled, two knocked off (S-234)
FALLEN = unit.Fallen(body=[("z", -6)],
                     joints={"torso": [("y", -30)], **k.sprawl(6, splay=82, sag=35, vary={"FL": 6, "MR": -8, "BL": 10})},
                     off={"shinML": (k.outward(6, "ML", 4.0), []), "shinBR": (k.outward(6, "BR", 3.5), [])}, rest=("base",))

unit.run(__file__, "chs_widowmaker", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, none)]
         + k.spider(6, 1.1, 2.4, 2.9, 4.1, 4.0, 0.4, "chaos"),
         attachments={"muzzle": {"parent": "torso", "at": [PX, PY, -1.35]},
                      "muzzle2": {"parent": "torso", "at": [-PX, PY, -1.35]}},
         budget=5600, tex=2048, scale=(S, S, S),
         previews=k.previews(7.8, 14.8), fallen=FALLEN)
