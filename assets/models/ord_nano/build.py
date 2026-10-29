"""Construction Turret (Order nano turret, T1 structure, footprint 2; S-209,
BAR armnanotc): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_nano/build.py

16 x 16 studs, about 11 tall. Big readable shapes first: a stepped
chamfered pad with hazard-striped corners; four armored pillars round a
central core, their outer faces big team panels, lit strips between them;
on top the `turret` (yaws to its work): a turntable and a shoulder block
with a team roof; on it the `nano` emitter (the def's piece, the spray's
start): a thick barrel raised 22 degrees with glowing coils and a big
glowing lens in an armored ring, so it reads from 150 studs. `nano1` sits
at the lens (rig.md 8). Order reads heavy and clean (M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard, octagon, rivets  # noqa: E402
from towers import louver  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
DECK = 6.0  # top of the core, where the turret turns
TURRET = (0.0, DECK, 0.0)
NANO = (0.0, 8.3, 0.5)  # the emitter's pitch pivot
RAISE = math.radians(22)
D = (0.0, math.sin(RAISE), -math.cos(RAISE))  # the barrel's axis
LENS = tuple(V(NANO) + V(D) * 5.6)


def build_base(p):
    p.prism_y(octagon(7.8, 2.2), 0.0, 0.6, "trim", bevel=0.14, top_scale=0.985)
    p.prism_y(octagon(6.6, 1.9), 0.6, 1.0, "dark", bevel=0.06)
    for sx in (-1, 1):  # hazard striping on the chamfered corners
        for sz in (-1, 1):
            d = V((sx, 0, sz)).normalized()
            c = d * 9.1
            hazard(p, (c.x, 0.62, c.z), (-sz, 0, sx), UP, 3.4, 1.0, stripes=7)
    # the central core and four armored pillars round it
    p.prism_y(octagon(2.6, 0.8), 1.0, DECK - 0.4, "trim", bevel=0.1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * 2.7, sz * 2.7
            p.prism_y(octagon(1.75, 0.6, cx, cz), 1.0, 4.4, "paint", bevel=0.12)
            p.prism_y(octagon(1.75, 0.6, cx, cz), 4.4, 5.2, "paint", bevel=0.1, top_scale=0.8)
            p.box((cx + sx * 1.77, 2.7, cz), (0.06, 2.6, 2.0), "team", bevel=0.02)
            p.box((cx, 2.7, cz + sz * 1.77), (2.0, 2.6, 0.06), "team", bevel=0.02)
            p.box((cx + sx * 1.78, 4.0, cz), (0.05, 0.14, 1.6), "light")
    for sx in (-1, 1):  # lit vents between the pillars
        louver(p, (sx * 2.62, 3.0, 0), (0, 0, 1), (sx, 0, 0), 1.4, 2.4, slats=4)
        louver(p, (0, 3.0, sx * 2.62), (1, 0, 0), (0, 0, sx), 1.4, 2.4, slats=4)
    p.box((0, 1.8, -2.64), (1.0, 0.3, 0.05), "power")
    p.prism_y(octagon(2.9, 0.9), DECK - 0.4, DECK, "dark", bevel=0.04)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 6.6, 0.66, sz * 4.0), (0.4, 0.1, 0.4), "light")


def details_base(p):
    for s in (-1, 1):
        rivets(p, (s * 4.47, 1.4, -2.0), (s * 4.47, 1.4, -3.4), 3, (s, 0, 0))
        seam(p, (s * 4.47, 4.4, 2.0), (s * 4.47, 4.4, 3.4), (s, 0, 0))
    ring(p, (0, DECK + 0.01, 0), UP, 2.2)


def build_turret(p):
    drum(p, (0, DECK + 0.4, 0), 2.1, 0.8, "steel", "trim", sides=20, axis="y")
    # the shoulder block: a sloped armored housing round the emitter's trunnion
    p.prism_x([(-1.6, DECK + 0.8), (2.4, DECK + 0.8), (2.4, 8.4), (1.6, 9.4), (-0.6, 9.4), (-1.6, 8.6)],
              -1.7, 1.7, "paint", bevel=0.12)
    p.box((0, 9.43, 0.9), (2.4, 0.05, 2.4), "team", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 1.72, 7.8, 0.6), (0.05, 0.14, 2.6), "light")
        p.box((sx * 1.72, 7.4, 1.4), (0.05, 0.9, 1.4), "team", bevel=0.01)
    louver(p, (0, 7.8, 2.42), (1, 0, 0), (0, 0, 1), 2.4, 1.2, slats=3)
    p.box((1.1, 9.5, 1.8), (0.3, 0.2, 0.3), "light")  # beacon


def details_turret(p):
    for sx in (-1, 1):
        rivets(p, (sx * 1.71, 8.8, -0.8), (sx * 1.71, 8.8, 2.0), 4, (sx, 0, 0))


def build_nano(p):
    n = V(D)
    o = V(NANO)
    p.cylinder("x", tuple(o), 1.05, 3.6, 14, "steel", cap_kinds=("trim", "trim"))  # trunnion
    p.ocyl(tuple(o - n * 0.8), tuple(n), 1.25, 2.6, 12, "paint")  # breech housing
    p.ocyl(tuple(o + n * 1.8), tuple(n), 0.8, 2.6, 14, "steel")
    for t in (2.3, 3.4):
        p.ocyl(tuple(o + n * t), tuple(n), 0.95, 0.3, 14, "power")
    # the emitter head: an armored ring, a big glowing lens, a nozzle
    p.ocyl(tuple(o + n * 4.3), tuple(n), 1.35, 1.1, 16, "trim")
    p.ocyl(tuple(o + n * 5.38), tuple(n), 1.05, 0.12, 16, "power")
    p.ocyl(tuple(o + n * 5.4), tuple(n), 0.55, 0.3, 12, "weapon", radius2=0.2)
    p.ocyl(tuple(o + n * 0.2), tuple(n), 1.3, 0.7, 12, "team")  # team band on the breech


def details_nano(p):
    o, n = V(NANO), V(D)
    ring(p, tuple(o + n * 4.86), tuple(n), 1.2)


unit.run(__file__, "ord_nano", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("nano", "turret", NANO, build_nano, details_nano)],
         attachments={"nano1": {"parent": "nano", "at": [round(c, 3) for c in LENS]}},
         budget=4000,
         previews=[("35", (-22, 18, -26), (0, 4.5, 0), 50),
                   ("80", (0, 38, 7), (0, 3.0, 0), 50),
                   ("close", (-11, 11, -13), (0, 6.5, -1.0), 35)])
