"""Colossus (Chaos barely mobile walking fortress, three lasers, T3,
footprint 4; batch 2 of the BAR roster, 2026-11-01): mesh, textures, rig
data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_colossus/build.py

From its blockout, laid out at half size and scaled x2 (unit.run `scale`;
the blockout scales the same). A massive chamfered block of armour over a
dark skirt, a raked glacis with amber slits, team panels on its flanks,
spikes and vents, standing on four stubby trunk legs (`legFL` .. `legBR`,
client pieces swinging at the hip like the Mammoth's) with broad clawed
feet. Crowning it the `torso` (turns), a squat turret with a heavy laser
(`muzzle`), and at its front corners two fixed laser casemates (`muzzle2`
left, `muzzle3` right). Chaos reads crude and brutal (M-14). Our own
design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard, rivets  # noqa: E402
from unit import seam  # noqa: E402

S = 2.0
TORSO = (0.0, 7.0, 0.6)
LEGS = {"FL": (-3.2, -3.0), "FR": (3.2, -3.0), "BL": (-3.2, 3.0), "BR": (3.2, 3.0)}
PX, PY = 2.9, 7.6


def build_base(p):
    p.prism_x([(-4.0, 3.0), (4.0, 3.0), (4.0, 6.3), (3.2, 7.0), (-3.0, 7.0), (-4.0, 6.0)], -4.0, 4.0, "paint", bevel=0.15)
    p.box((0, 3.2, 0), (8.6, 0.8, 8.6), "dark", bevel=0.1)
    p.prism_x([(-4.0, 3.3), (-4.0, 5.6), (-5.6, 3.9), (-5.4, 3.3)], -3.8, 3.8, "trim", bevel=0.08)
    for x in (-2.4, -0.8, 0.8, 2.4):
        p.obox((x, 4.6, -4.75), (1, 0, 0), (0, 0.72, -1), 1.0, 0.18, 0.05, "head", bevel=0.0)
    hazard(p, (0, 3.65, -5.45), (1, 0, 0), (0, -0.35, -1), 6.8, 0.4, stripes=14)
    for sx in (-1, 1):
        p.box((sx * 4.02, 5.0, 0.5), (0.06, 1.4, 5.0), "team", bevel=0.02)
        for z in (-1.5, 0.0, 1.5):
            p.box((sx * 4.05, 6.1, z + 0.5), (0.1, 0.5, 1.0), "trim", bevel=0.02)
    for x, z in ((-3.0, 2.8), (3.0, 2.8), (-3.0, -0.5), (3.0, -0.5)):
        p.ocyl((x, 6.95, z), k.UP, 0.42, 1.5, 6, "steel", radius2=0.05)
    for x in (-1.6, 1.6):
        p.box((x, 7.02, 3.2), (1.2, 0.08, 1.2), "dark")
        for i in range(4):
            p.box((x - 0.45 + i * 0.3, 7.08, 3.2), (0.1, 0.06, 1.0), "trim")
    drum(p, (0, 7.02, 0.6), 2.1, 0.06, "steel", "trim", axis="y")
    for sx in (-1, 1):
        x = sx * PX
        p.box((x, PY, -2.6), (1.6, 1.2, 1.8), "trim", bevel=0.08)
        p.box((x, PY + 0.62, -2.6), (1.2, 0.05, 1.4), "dark")
        k.gun(p, x, PY, -3.5, 1.4, 0.28, kind="dark", mouth="steel")
        p.box((x, PY + 0.25, -3.52), (0.6, 0.12, 0.04), "head")


def details_base(p):
    for sx in (-1, 1):
        seam(p, (sx * 4.01, 4.0, -3.5), (sx * 4.01, 4.0, 3.5), (sx, 0, 0))
    rivets(p, (-3.5, 4.0, 4.01), (3.5, 4.0, 4.01), 8, (0, 0, 1))


def leg(tag, x, z):
    def build(p):
        p.box((x, 1.9, z), (2.2, 2.9, 2.2), "trim", bevel=0.12)
        p.box((x, 2.4, z - 1.12), (1.6, 1.5, 0.08), "paint", bevel=0.03)
        p.ocyl((x, 0.0, z), k.UP, 1.5, 0.55, 8, "dark", radius2=1.25)
        for dx in (-0.8, 0.0, 0.8):
            p.prism_x([(z - 1.8, 0.02), (z - 1.1, 0.02), (z - 1.1, 0.42)], x + dx - 0.18, x + dx + 0.18, "steel", bevel=0.02)
        drum(p, (x, 3.2, z), 0.6, 2.4, "steel", "trim")
    return unit.PieceSpec(f"leg{tag}", "base", (x, 3.2, z), build, lambda p: None)


def build_torso(p):
    p.prism_x([(-1.2, 7.0), (2.4, 7.0), (2.4, 8.4), (1.8, 8.8), (-0.9, 8.8), (-1.4, 8.1)], -1.8, 1.8, "paint", bevel=0.1)
    p.box((0, 8.82, 1.2), (2.4, 0.06, 1.6), "team", bevel=0.02)
    p.box((0, 8.0, -0.95), (1.4, 1.1, 0.6), "trim", bevel=0.06)
    k.gun(p, 0, 8.0, -1.2, 3.1, 0.45, kind="dark", mouth="steel")
    for z in (-1.9, -2.6, -3.3):
        p.ocyl((0, 8.0, z), k.FWD, 0.58, 0.14, 12, "steel")
    p.box((0, 8.62, -0.4), (0.9, 0.12, 0.04), "head")
    for sx in (-1, 1):
        p.ocyl((sx * 1.4, 8.8, 0.0), k.UP, 0.25, 0.9, 6, "steel", radius2=0.03)


none = lambda p: None  # noqa: E731

unit.run(__file__, "chs_colossus", "chaos", footprint=4,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)]
         + [leg(t, x, z) for t, (x, z) in LEGS.items()]
         + [unit.PieceSpec("torso", "base", TORSO, build_torso, none)],
         attachments={"muzzle": {"parent": "torso", "at": [0.0, 8.0, -4.4]},
                      "muzzle2": {"parent": "base", "at": [-PX, PY, -5.0]},
                      "muzzle3": {"parent": "base", "at": [PX, PY, -5.0]}},
         budget=6000, tex=2048, scale=(S, S, S),
         previews=k.previews(17.7, 20.0))
