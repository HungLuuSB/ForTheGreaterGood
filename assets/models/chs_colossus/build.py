"""Colossus (Chaos barely mobile heavy turret, T3, footprint 5; batch 2 of
the BAR roster, remodelled for S-236, the user's FTGG-FEEDBACK-5: "it must
be bigger... And a remodel too"): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_colossus/build.py

From its blockout, laid out at half size and scaled x2.5 (unit.run `scale`;
the blockout scales the same). A low, wide fortress hull over a dark skirt,
a raked glacis with amber slits, team panels on its flanks, spikes and rear
exhaust stacks, on four short trunk legs (`legFL` .. `legBR`, client pieces
swinging at the hip like the Mammoth's) with broad clawed feet. On it the
`torso` (turns) is a massive turret built round one dominant cannon (`muzzle`,
the D-Gun bolt) with glowing heat coils and a muzzle brake; two lower lasers
in sponsons under it (`muzzle2` on the left one) and a top laser in a cupola
(`muzzle3`). Every weapon turns with the torso. Chaos reads crude and brutal
(M-14). Our own design. Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import botkit as k  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard, rivets  # noqa: E402
from unit import seam  # noqa: E402

S = 2.5
TORSO = (0.0, 7.0, 0.6)
LEGS = {"FL": (-4.0, -3.4), "FR": (4.0, -3.4), "BL": (-4.0, 3.6), "BR": (4.0, 3.6)}
CY, CZ = 8.7, -2.9  # the cannon's axis height and where it leaves the mantlet
CLEN = 6.8
LX, LY = 2.5, 7.75  # the lower lasers' sponsons
TOP = (1.5, 10.25, 0.9)  # the top laser's cupola


def build_base(p):
    p.prism_x([(-5.0, 3.0), (5.0, 3.0), (5.0, 6.2), (4.2, 7.0), (-3.8, 7.0), (-5.0, 5.8)], -5.0, 5.0, "paint", bevel=0.18)
    p.box((0, 3.2, 0), (10.8, 0.8, 10.6), "dark", bevel=0.1)
    p.prism_x([(-5.0, 3.3), (-5.0, 5.4), (-6.6, 3.9), (-6.4, 3.3)], -4.8, 4.8, "trim", bevel=0.08)
    for x in (-3.3, -1.65, 0.0, 1.65, 3.3):
        p.obox((x, 4.5, -5.75), (1, 0, 0), (0, 0.72, -1), 1.1, 0.2, 0.05, "head", bevel=0.0)
    hazard(p, (0, 3.65, -6.45), (1, 0, 0), (0, -0.35, -1), 8.6, 0.45, stripes=18)
    for sx in (-1, 1):
        # flank armour: a team panel between bolted skirts
        p.box((sx * 5.02, 5.0, 0.4), (0.06, 1.6, 6.4), "team", bevel=0.02)
        for z in (-2.4, -0.4, 1.6, 3.6):
            p.box((sx * 5.06, 6.25, z), (0.12, 0.5, 1.4), "trim", bevel=0.02)
        p.box((sx * 5.1, 3.9, 0.4), (0.3, 0.7, 8.6), "trim", bevel=0.05)
    for x, z in ((-4.0, 4.0), (4.0, 4.0), (-4.0, 0.6), (4.0, 0.6), (-3.2, -2.6), (3.2, -2.6)):
        p.ocyl((x, 6.95, z), k.UP, 0.5, 1.8, 6, "steel", radius2=0.05)
    # rear exhaust stacks, lit inside
    for x in (-3.3, -1.9, 1.9, 3.3):
        p.ocyl((x, 6.2, 5.0), k.UP, 0.45, 2.6, 8, "dark")
        p.ocyl((x, 8.78, 5.0), k.UP, 0.32, 0.04, 8, "power")
    p.box((0, 5.0, 5.05), (5.4, 1.6, 0.2), "trim", bevel=0.05)
    drum(p, (0, 7.02, TORSO[2]), 3.3, 0.08, "steel", "trim", axis="y")


def details_base(p):
    for sx in (-1, 1):
        seam(p, (sx * 5.01, 4.1, -4.5), (sx * 5.01, 4.1, 4.5), (sx, 0, 0))
    rivets(p, (-4.5, 4.0, 5.01), (4.5, 4.0, 5.01), 10, (0, 0, 1))
    rivets(p, (-4.5, 6.6, -4.65), (4.5, 6.6, -4.65), 10, (0, 0.6, -1))


def leg(tag, x, z):
    def build(p):
        p.box((x, 1.85, z), (2.8, 2.9, 2.8), "trim", bevel=0.14)
        p.box((x, 2.4, z - 1.42), (2.0, 1.5, 0.08), "paint", bevel=0.03)
        p.ocyl((x, 0.0, z), k.UP, 1.9, 0.6, 8, "dark", radius2=1.6)
        for dx in (-1.0, 0.0, 1.0):
            p.prism_x([(z - 2.25, 0.02), (z - 1.4, 0.02), (z - 1.4, 0.5)], x + dx - 0.22, x + dx + 0.22, "steel", bevel=0.02)
        drum(p, (x, 3.2, z), 0.75, 3.0, "steel", "trim")
    return unit.PieceSpec(f"leg{tag}", "base", (x, 3.2, z), build, lambda p: None)


def build_torso(p):
    # the turret: a squat chamfered block, its front cut back round the mantlet
    p.prism_x([(-2.6, 7.0), (3.6, 7.0), (3.6, 9.5), (2.9, 10.2), (-1.6, 10.2), (-2.6, 9.2)], -3.4, 3.4, "paint", bevel=0.14)
    p.box((0, 7.2, 0.5), (7.2, 0.4, 6.6), "dark", bevel=0.06)
    p.box((-1.4, 10.22, 2.4), (2.6, 0.06, 1.6), "team", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 3.42, 8.8, 0.8), (0.06, 1.0, 3.2), "team", bevel=0.02)
        p.prism_x([(-1.0, 10.15), (0.2, 10.15), (-0.4, 11.2)], sx * 2.6 - 0.18, sx * 2.6 + 0.18, "steel", bevel=0.02)
    # the cannon: a heavy mantlet, a thick barrel wound with glowing heat coils, a muzzle brake
    p.box((0, CY, CZ + 0.45), (3.0, 2.2, 1.0), "trim", bevel=0.12)
    p.ocyl((0, CY, CZ), k.FWD, 1.05, 0.7, 16, "dark", radius2=0.9)
    p.ocyl((0, CY, CZ - 0.7), k.FWD, 0.72, CLEN - 1.3, 16, "dark")
    for i in range(5):
        z = CZ - 1.1 - i * 0.85
        p.ocyl((0, CY, z), k.FWD, 0.95, 0.22, 16, "steel")
        p.ocyl((0, CY, z - 0.22), k.FWD, 0.82, 0.2, 16, "power")
    zb = CZ - CLEN + 0.6
    p.box((0, CY, zb - 0.35), (2.0, 1.3, 1.1), "trim", bevel=0.1)
    for sx in (-1, 1):
        p.box((sx * 1.02, CY, zb - 0.35), (0.06, 0.7, 0.7), "dark")
    p.ocyl((0, CY, zb - 0.9), k.FWD, 0.62, 0.05, 16, "weapon")
    # the two lower lasers, in sponsons under the cannon
    for sx in (-1, 1):
        x = sx * LX
        p.box((x, LY, -2.2), (1.4, 1.1, 1.6), "trim", bevel=0.08)
        k.gun(p, x, LY, -3.0, 1.9, 0.3, kind="dark", mouth="steel")
    # the top laser, in a cupola
    tx, ty, tz = TOP
    p.ocyl((tx, 10.2, tz), k.UP, 0.85, 0.5, 10, "trim", radius2=0.7)
    p.box((tx, ty + 0.1, tz - 0.3), (0.8, 0.5, 1.0), "dark", bevel=0.05)
    k.gun(p, tx, ty + 0.1, tz - 0.8, 1.8, 0.24, kind="steel", mouth="trim")
    # sensor slit and aerials
    p.box((-1.6, 9.75, -1.75), (1.2, 0.14, 0.04), "head")
    for x, z in ((-2.6, 2.9), (2.7, 2.9)):
        p.ocyl((x, 10.2, z), k.UP, 0.06, 1.6, 6, "steel")


def details_torso(p):
    rivets(p, (-3.0, 7.6, 3.61), (3.0, 7.6, 3.61), 8, (0, 0, 1))


none = lambda p: None  # noqa: E731

# its wreck lies belly down, its trunk legs splayed out, the turret slewed (S-234)
FALLEN = unit.Fallen(body=[("z", 9), ("x", 5)],
                     joints={"torso": [("y", 24)], **k.sprawl(4, splay=100, prefix=("leg",), vary={"FR": 10, "BL": -10})},
                     rest=("base",), sink=2.5)

unit.run(__file__, "chs_colossus", "chaos", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)]
         + [leg(t, x, z) for t, (x, z) in LEGS.items()]
         + [unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)],
         attachments={"muzzle": {"parent": "torso", "at": [0.0, CY, CZ - CLEN - 0.45]},
                      "muzzle2": {"parent": "torso", "at": [-LX, LY, -5.0]},
                      "muzzle3": {"parent": "torso", "at": [TOP[0], TOP[1] + 0.1, TOP[2] - 2.7]}},
         budget=7000, tex=2048, scale=(S, S, S),
         previews=k.previews(28.0, 32.0), fallen=FALLEN)
