"""Leech (Chaos ASW helicopter, T2 air): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_leech/build.py

About 1.35x the T1 Wasp (docs/art/size-scale.md), Chaos-light and rough: a
gunmetal box cabin with a big bubble nose, an exposed turbine on the roof
with a hot exhaust, wheeled gear, a braced lattice boom with a tall team fin
and tail rotor, the client-spun `rotor` (four blades), and the dipping
sonar slung in an open cage under the belly with its amber transducer. The
`rack` (the weapon's turret piece) is a crude crossbeam carrying two
torpedoes with weapon-ready seekers; `muzzle` at its front. Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 3.9, 0.2)
RACK = (0.0, 0.9, 0.2)
MUZZLE = (0.0, 0.6, -1.6)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    p.box((0, 1.7, -0.2), (2.1, 1.9, 4.4), "paint", bevel=0.06)
    p.ocyl((0, 1.55, -2.4), (0, 0, -1), 1.0, 0.7, 12, "glass", radius2=0.75)
    p.ocyl((0, 1.55, -3.1), (0, 0, -1), 0.75, 0.45, 12, "glass", radius2=0.2)
    p.box((0, 2.68, -1.0), (1.5, 0.05, 1.5), "team", bevel=0.01)
    for sx in (-1, 1):  # slab armor on the flanks, a running strip
        p.box((sx * 1.1, 1.6, 0.2), (0.12, 1.1, 2.6), "era", bevel=0.02)
        p.box((sx * 1.18, 2.35, -0.2), (0.04, 0.2, 3.6), "light")
    # exposed turbine, hot exhaust, mast
    p.cylinder("z", (0, 2.95, 0.7), 0.55, 2.3, 12, "steel")
    p.cylinder("z", (0, 2.95, -0.47), 0.45, 0.06, 12, "grille")
    p.cylinder("z", (0, 2.95, 1.9), 0.48, 0.24, 12, "light")
    p.cylinder("y", (0, 3.6, 0.2), 0.2, 0.6, 8, "steel")
    # wheeled gear
    for sx in (-1, 1):
        beam(p, (sx * 0.8, 0.9, -1.0), (sx * 1.1, 0.35, -1.0), 0.14, "steel")
        p.cylinder("x", (sx * 1.1, 0.35, -1.0), 0.35, 0.3, 10, "rubber", cap_kinds=("steel", "steel"))
    p.cylinder("x", (0, 0.3, 1.8), 0.28, 0.25, 10, "rubber", cap_kinds=("steel", "steel"))
    # sonar cage and transducer under the belly
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(p, (sx * 0.45, 0.75, 1.0 + sz * 0.45), (sx * 0.3, 0.2, 1.0 + sz * 0.3), 0.08, "dark")
    with p.sub("sonar", (0, 0.45, 1.0), "lower", (0, -1, 0), 8):  # M-27 dipping sonar
        p.cylinder("y", (0, 0.45, 1.0), 0.32, 0.4, 10, "steel")
        p.cylinder("y", (0, 0.18, 1.0), 0.28, 0.1, 10, "light")
    # lattice boom, team fin, tail rotor
    for sx, y in ((-0.25, 1.4), (0.25, 1.4), (0.0, 2.0)):
        beam(p, (sx, y, 2.0), (sx * 0.4, 1.6 + (y - 1.4) * 0.4, 6.6), 0.12, "dark")
    for z in (3.2, 4.4, 5.6):
        beam(p, (-0.2, 1.45, z), (0.2, 1.45, z), 0.07, "steel")
    p.prism_x([(5.9, 1.4), (6.9, 1.4), (7.2, 3.8), (6.6, 3.8)], -0.08, 0.08, "team", bevel=0.02)
    with p.sub("tailRotor", (0.22, 2.6, 6.6), "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", (0.22, 2.6, 6.6), 0.95, 0.06, 8, "dark")
        p.cylinder("x", (0.18, 2.6, 6.6), 0.13, 0.22, 6, "steel")
    p.box((0, 2.72, 0.9), (0.22, 0.1, 0.22), "light")  # beacon
    p.box((0, 0.77, -1.9), (0.5, 0.06, 0.3), "head")


def details_base(p):
    bolts(p, (-0.9, 2.651, -2.0), (0.9, 2.651, -2.0), 6, UP)
    seam(p, (-1.051, 1.0, -1.2), (-1.051, 2.5, -1.2), (-1, 0, 0))
    seam(p, (1.051, 1.0, -1.2), (1.051, 2.5, -1.2), (1, 0, 0))


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.34, 0.24, 10, "trim")
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 2.8, y + 0.02, z + d[2] * 2.8), u, (0, 1, 0), 0.46, 5.0, 0.09, "dark")
        p.obox((x + d[0] * 5.1, y + 0.03, z + d[2] * 5.1), u, (0, 1, 0), 0.48, 0.4, 0.1, "team")


def build_rack(p):
    x, y, z = RACK
    beam(p, (-1.8, y, z), (1.8, y, z), 0.24, "dark")
    for sx in (-1, 1):
        beam(p, (sx * 1.0, y, z), (sx * 0.6, y + 0.5, z), 0.12, "steel")
        p.box((sx * 1.55, y - 0.2, z), (0.12, 0.3, 0.5), "trim")
        p.box((sx * 1.82, y, z), (0.06, 0.18, 0.5), "weapon")  # ready lights
        p.cylinder("z", (sx * 1.55, y - 0.45, z), 0.24, 2.3, 10, "trim")
        p.ocyl((sx * 1.55, y - 0.45, z - 1.15), (0, 0, -1), 0.24, 0.3, 10, "weapon", radius2=0.08)
        p.ocyl((sx * 1.55, y - 0.45, z + 1.15), (0, 0, 1), 0.24, 0.2, 10, "dark", radius2=0.12)


def no_details(p):
    pass


unit.run(__file__, "chs_leech", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("rack", "base", RACK, build_rack, no_details)],
         attachments={"muzzle": {"parent": "rack", "at": list(MUZZLE)}},
         team_pieces=["base", "rotor"],
         previews=[("35", (-16, 12, 18), (0, 1.8, 0.5), 50),
                   ("side", (20, 3, 0.5), (0, 1.8, 0.5), 50),
                   ("80", (0, 30, 5), (0, 1.5, 0.5), 50),
                   ("close", (-7, 5.5, -8), (0, 2.0, -1.0), 35)])
