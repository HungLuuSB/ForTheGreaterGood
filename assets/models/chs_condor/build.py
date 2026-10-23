"""Condor (Chaos advanced air worker, T2 air, helicopter): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_condor/build.py

The Vulture's big brother, about 1.35x its size (docs/art/size-scale.md),
Chaos-light and visibly more advanced: a skeletal sky-crane. A bubble
cockpit pod at the front of a long spine, an open belly bay between four
splayed legs, two exposed turbine engines with hot exhaust rings on the
spine, a four-blade rotor (the client-spun `rotor` visual piece), a lattice
tail boom with a team fin and tail rotor; in the bay the `nano` turret with
two crane arms, fore and aft, each with an emitter (power). Team plates on
the spine, the fin and the blade tips. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

ROTOR = (0.0, 3.7, 0.0)
NANO = (0.0, 1.55, 0.2)


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_base(p):
    # cockpit pod: a box with a bubble nose
    p.box((0, 1.9, -3.3), (1.7, 1.5, 2.2), "paint", bevel=0.05)
    p.ocyl((0, 1.8, -4.4), (0, 0, -1), 0.85, 0.55, 12, "glass", radius2=0.6)
    p.ocyl((0, 1.8, -4.95), (0, 0, -1), 0.6, 0.35, 12, "glass", radius2=0.18)
    p.box((0, 2.68, -3.2), (1.1, 0.05, 1.4), "team", bevel=0.01)
    # the spine over the open bay
    p.prism_x([(-2.2, 2.3), (3.2, 2.3), (3.6, 2.6), (3.2, 3.15), (-2.2, 3.15)], -0.55, 0.55, "paint", bevel=0.04)
    p.box((0, 3.17, 0.5), (0.8, 0.05, 2.6), "team", bevel=0.01)
    for sx in (-1, 1):  # spine flanks, rail lights
        p.box((sx * 0.57, 2.6, 0.5), (0.04, 0.12, 4.6), "light")
    # four splayed legs round the bay, feet with pads
    for sx in (-1, 1):
        for z in (-1.6, 2.4):
            beam(p, (sx * 0.5, 2.4, z), (sx * 1.6, 0.15, z), 0.24, "trim")
            p.box((sx * 1.62, 0.08, z), (0.5, 0.16, 0.7), "dark")
        beam(p, (sx * 1.25, 0.8, -1.6), (sx * 1.25, 0.8, 2.4), 0.12, "steel")
    # two exposed turbines on the spine, hot exhaust rings, the mast
    for sx in (-1, 1):
        p.cylinder("z", (sx * 0.62, 3.45, 1.2), 0.36, 2.0, 10, "steel")
        p.cylinder("z", (sx * 0.62, 3.45, 0.18), 0.3, 0.06, 10, "grille")
        p.cylinder("z", (sx * 0.62, 3.45, 2.25), 0.33, 0.14, 10, "light")
    p.cylinder("y", (0, 3.35, 0.0), 0.2, 0.7, 8, "steel")
    # lattice tail boom, fin with team plate, tail rotor
    for sx, y in ((-0.25, 2.5), (0.25, 2.5), (0.0, 2.95)):
        beam(p, (sx, y, 3.3), (sx * 0.4, 2.5 + (y - 2.5) * 0.4, 7.4), 0.1, "dark")
    for z in (4.3, 5.4, 6.5):
        beam(p, (-0.2, 2.5, z), (0.2, 2.5, z), 0.06, "steel")
    p.prism_x([(6.9, 2.3), (7.7, 2.3), (7.9, 4.0), (7.4, 4.0)], -0.08, 0.08, "team", bevel=0.02)
    with p.sub("tailRotor", (0.22, 3.0, 7.5), "spin", (1, 0, 0)):  # M-27
        p.cylinder("x", (0.22, 3.0, 7.5), 0.85, 0.06, 8, "dark")
        p.cylinder("x", (0.18, 3.0, 7.5), 0.12, 0.22, 6, "steel")
    # lights: beacon, landing light, nav lights on the legs
    p.box((0, 3.25, -0.9), (0.22, 0.1, 0.22), "light")
    p.box((0, 1.12, -4.1), (0.5, 0.06, 0.3), "head")
    for sx in (-1, 1):
        p.box((sx * 1.62, 0.2, -1.95), (0.3, 0.12, 0.05), "light")


def details_base(p):
    bolts(p, (-0.45, 3.151, -1.8), (-0.45, 3.151, 2.9), 7, UP)
    bolts(p, (0.45, 3.151, -1.8), (0.45, 3.151, 2.9), 7, UP)
    seam(p, (-0.86, 1.4, -2.6), (-0.86, 2.5, -2.6), (-1, 0, 0))
    seam(p, (0.86, 1.4, -2.6), (0.86, 2.5, -2.6), (1, 0, 0))


def build_rotor(p):
    x, y, z = ROTOR
    p.cylinder("y", (x, y, z), 0.34, 0.24, 10, "trim")
    for i in range(4):
        a = i * math.pi / 2
        d = (math.cos(a), 0.0, math.sin(a))
        u = (-math.sin(a), 0.0, math.cos(a))
        p.obox((x + d[0] * 2.9, y + 0.02, z + d[2] * 2.9), u, (0, 1, 0), 0.46, 5.3, 0.09, "dark")
        p.obox((x + d[0] * 5.35, y + 0.03, z + d[2] * 5.35), u, (0, 1, 0), 0.48, 0.4, 0.1, "team")


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 0.62, 0.35, 12, "trim")
    p.cylinder("y", (x, y - 0.2, z), 0.64, 0.06, 12, "power")
    for tip_z, tip_y in ((-1.9, 0.35), (2.1, 0.45)):  # crane arms, fore and aft
        beam(p, (0, y - 0.1, z), (0, tip_y + 0.35, tip_z), 0.26, "steel")
        beam(p, (0.18, y - 0.1, z), (0.18, tip_y + 0.35, tip_z), 0.08, "dark")  # hydraulic line
        p.box((0, tip_y + 0.3, tip_z), (0.6, 0.35, 0.5), "dark", bevel=0.03)
        p.ocyl((0, tip_y + 0.12, tip_z), (0, -1, 0), 0.3, 0.4, 10, "power", radius2=0.14)


def no_details(p):
    pass


unit.run(__file__, "chs_condor", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("rotor", "base", ROTOR, build_rotor, no_details),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)],
         team_pieces=["base", "rotor"],
         previews=[("35", (-16, 12, 18), (0, 2.0, 0.5), 50),
                   ("side", (20, 3, 0.5), (0, 2.0, 0.5), 50),
                   ("80", (0, 30, 5), (0, 1.5, 0.5), 50),
                   ("close", (-7, 5.5, -8), (0, 2.2, -1.0), 35)])
