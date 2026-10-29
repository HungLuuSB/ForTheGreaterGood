"""Construction Turret (Chaos nano turret, T1 structure, footprint 2; S-209,
BAR cornanotc): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_nano/build.py

16 x 16 studs, about 11 tall. Big readable shapes first: a thick dark
octagonal slab; a squat octagonal tower with a hazard-striped front, a
band of grilled vents up top, and a ring of salvaged supply crates stacked
round its foot (team and gunmetal, strapped); on top the `turret` (yaws to
its work): a dark turntable and a boxy armored head with team side plates,
a hazard-striped roof and a beacon; on its front the `nano` emitter (the
def's piece, the spray's start): a heavy round pod with a big glowing lens
in a thick octagonal rim, so it reads from 150 studs. `nano1` sits at the
lens (rig.md 8). Chaos reads rugged and improvised (M-14). Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
DECK = 6.2  # top of the tower, where the turret turns
TURRET = (0.0, DECK, 0.0)
NANO = (0.0, 8.0, -0.9)  # the pod's pitch pivot
LENS = (0.0, 8.0, -3.25)


def crate(p, c, size, yaw, kind):
    """A strapped supply crate turned `yaw` degrees about Y."""
    a = math.radians(yaw)
    u, n = (math.cos(a), 0, -math.sin(a)), UP
    w, h, d = size
    p.obox(c, u, n, w, d, h, kind, bevel=0.08)
    cx, cy, cz = c
    for s in (-0.3, 0.3):
        q = (cx + u[0] * s * w, cy, cz + u[2] * s * w)
        p.obox(q, u, n, 0.14, d + 0.06, h + 0.06, "dark")
    p.obox((cx, cy + h / 2 + 0.02, cz), u, n, w * 0.5, d * 0.5, 0.04, "grille")


def build_base(p):
    p.prism_y(octagon(7.8, 2.4), 0.0, 0.8, "dark", bevel=0.14, top_scale=0.98)
    p.prism_y(octagon(6.8, 2.1), 0.8, 0.95, "trim", bevel=0.04)
    # the tower: octagonal, sloped at the top, hazard striping on the front
    p.prism_y(octagon(3.4, 1.1), 0.95, 5.0, "trim", bevel=0.1)
    p.prism_y(octagon(3.4, 1.1), 5.0, DECK, "paint", bevel=0.1, top_scale=0.86)
    p.box((0, 2.7, -3.43), (2.6, 3.2, 0.06), "dark")  # the hazard column
    for y in (1.6, 2.4, 3.2, 3.95):
        hazard(p, (0, y, -3.47), (1, 0, 0), (0, 0, -1), 2.2, 0.6, stripes=4, t=0.03)
    for k in range(4):  # grilled vents round the top band
        a = math.radians(90 * k)
        d = V((math.sin(a), 0, -math.cos(a)))
        c = d * 3.42
        p.obox((c.x, 4.4, c.z), (d.z, 0, -d.x), tuple(d), 3.2, 0.9, 0.06, "grille")
        for i in range(5):
            q = c + V((d.z, 0, -d.x)) * (-1.2 + i * 0.6) + d * 0.04
            p.obox(tuple(q), (0, 1, 0), tuple(d), 0.75, 0.16, 0.04, "dark")
    p.box((0, 4.4, -3.5), (1.4, 0.16, 0.04), "power")
    # salvaged crates stacked round the foot
    crates = [((-4.6, -3.8), 0, "team"), ((4.6, -3.8), 0, "team"), ((-5.2, 0.4), 90, "paint"),
              ((5.2, 0.4), 90, "team"), ((-4.2, 4.4), 10, "team"), ((4.4, 4.6), -12, "paint"),
              ((0.0, 5.2), 0, "team")]
    for (x, z), yaw, kind in crates:
        crate(p, (x, 2.1, z), (2.6, 2.3, 2.0), yaw, kind)
    for (x, z), yaw, kind in ((( -4.6, -3.9), 8, "paint"), ((5.0, 0.6), 84, "team")):
        crate(p, (x, 3.95, z), (1.9, 1.4, 1.6), yaw, kind)
    cable(p, [(-3.4, 1.0, 2.6), (-2.2, 1.2, 4.6), (2.0, 1.2, 5.6)], r=0.16, kind="dark")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 6.9, 0.86, sz * 3.2), (0.35, 0.14, 0.35), "light")


def details_base(p):
    for s in (-1, 1):
        rivets(p, (s * 3.42, 1.5, -1.6), (s * 3.42, 1.5, 1.6), 4, (s, 0, 0))
        seam(p, (s * 3.42, 3.4, -1.8), (s * 3.42, 3.4, 1.8), (s, 0, 0))
    rivets(p, (-2.0, 5.2, 3.0), (2.0, 5.2, 3.0), 5, (0, 0.4, 1))


def build_turret(p):
    drum(p, (0, DECK + 0.35, 0), 2.2, 0.7, "steel", "dark", sides=8, axis="y")
    # the boxy head: a chamfered armored block, team side plates, hazard roof
    p.prism_x([(-1.2, DECK + 0.7), (2.6, DECK + 0.7), (2.6, 9.4), (1.8, 10.0), (-0.6, 10.0), (-1.2, 9.4)],
              -2.0, 2.0, "paint", bevel=0.14)
    for sx in (-1, 1):
        p.obox((sx * 2.1, 8.4, 0.9), (0, 0, 1), (sx, 0, 0), 3.0, 2.4, 0.3, "team", bevel=0.06)
        p.box((sx * 2.27, 8.4, 0.9), (0.04, 0.5, 2.2), "dark")
    hazard(p, (0, 10.03, 0.6), (1, 0, 0), UP, 3.0, 0.8, stripes=6)
    p.box((1.4, 10.3, 1.6), (0.35, 0.5, 0.35), "light")  # beacon
    p.cylinder("y", (-1.2, 10.4, 1.8), 0.12, 0.8, 6, "steel")


def details_turret(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.26, 9.4, -0.4), (sx * 2.26, 9.4, 2.2), 4, (sx, 0, 0))


def build_nano(p):
    f = (0, 0, -1)
    p.cylinder("x", NANO, 0.9, 3.0, 8, "steel", cap_kinds=("dark", "dark"))  # trunnion
    p.ocyl((0, 8.0, -0.9), f, 1.5, 1.2, 8, "trim")  # the pod
    p.ocyl((0, 8.0, -2.1), f, 1.7, 0.9, 8, "dark")  # the thick octagonal rim
    p.ocyl((0, 8.0, -2.98), f, 1.2, 0.2, 12, "power")  # the big lens
    p.ocyl((0, 8.0, -3.0), f, 0.5, 0.25, 10, "weapon", radius2=0.25)
    for sx in (-1, 1):
        p.box((sx * 1.55, 8.0, -2.55), (0.3, 2.2, 0.5), "trim", bevel=0.04)  # rim clamps


def details_nano(p):
    ring(p, (0, 8.0, -3.0), (0, 0, -1), 1.4)


unit.run(__file__, "chs_nano", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("nano", "turret", NANO, build_nano, details_nano)],
         attachments={"nano1": {"parent": "nano", "at": list(LENS)}},
         budget=4000,
         previews=[("35", (-22, 18, -26), (0, 4.5, 0), 50),
                   ("80", (0, 38, 7), (0, 3.0, 0), 50),
                   ("close", (-11, 11, -13), (0, 6.5, -1.0), 35)])
