"""Leviathan (Chaos carrier, T2 ship, footprint 3): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_leviathan/build.py

New mesh from its blockout, at the T2 capital-ship size (size-scale.md:
29-30 long): a long hull with a dark waterline band under an offset,
patched flight deck overhanging to starboard on braces, three rearm pads
in team rings with marks, hazard deck ends, amber edge lights, a low
island to port with an amber slit, a team roof and a funnel with a hot
band, a braced lattice mast with the client-turned radar array (`radar`,
M-27); `turret1` and `turret2` quad flak mounts on the port side, fore and
aft (`muzzle1`, `muzzle2`). Model space, waterline at y = 0. Chaos reads
rugged and improvised (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import hazard  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

V = lib.vec
DECK = 3.2
T1 = (-4.0, 2.4, -10.4)
T2 = (-4.0, 2.4, 10.0)
RADAR = (-3.6, 11.0, 1.0)
PADS = [(1.6, -7.6), (1.6, 0.4), (1.6, 8.4)]


def flak(p, c):
    x, y, z = c
    p.cylinder("y", (x, y + 0.15, z), 0.9, 0.3, 12, "trim")
    p.box((x, y + 0.65, z + 0.3), (1.4, 0.7, 1.1), "paint", bevel=0.04)
    p.box((x, y + 1.02, z + 0.3), (1.0, 0.04, 0.7), "team")
    for xx in (-0.45, -0.15, 0.15, 0.45):
        p.cylinder("z", (x + xx, y + 0.7, z - 0.9), 0.08, 1.6, 8, "steel")
        p.cylinder("z", (x + xx, y + 0.7, z - 1.7), 0.11, 0.08, 8, "weapon")


def build_base(p):
    p.prism_x([(-14.8, 2.4), (-11.2, -0.9), (13.2, -0.9), (13.2, 2.4)], -3.6, 3.6, "paint", bevel=0.08)
    p.prism_x([(-13.0, 0.0), (-11.0, -0.6), (13.25, -0.6), (13.25, 0.0)], -3.67, 3.67, "dark", bevel=0.02)
    # offset flight deck on braces, overhanging to starboard
    p.box((1.6, DECK - 0.25, 0.0), (7.4, 0.5, 28.0), "trim", bevel=0.06)
    for z in (-10.0, -3.0, 4.0, 11.0):
        a, b = V((3.4, 1.6, z)), V((5.0, DECK - 0.5, z))
        p.obox(tuple((a + b) / 2), tuple(b - a), (0, 0, 1), (b - a).length, 0.4, 0.4, "steel")
    for x, z, w, d in ((3.2, -3.0, 2.0, 3.6), (0.0, 11.0, 2.4, 2.0)):
        p.box((x, DECK + 0.02, z), (w, 0.04, d), "steel", bevel=0.01)  # patches
    for x, z in PADS:
        p.cylinder("y", (x, DECK + 0.03, z), 2.5, 0.04, 22, "team")
        p.cylinder("y", (x, DECK + 0.05, z), 2.2, 0.04, 22, "rubber")
        p.box((x, DECK + 0.08, z), (0.3, 0.03, 2.0), "trim")
        p.box((x, DECK + 0.08, z), (1.4, 0.03, 0.3), "trim")
    for sz in (-1, 1):
        hazard(p, (1.6, DECK + 0.03, sz * 13.6), (1, 0, 0), UP, 7.0, 0.4, stripes=14)
    for z in range(-12, 14, 4):
        p.box((5.32, DECK - 0.2, z), (0.06, 0.2, 0.4), "light")
    # low island to port, amber slit, team roof, funnel with a hot band
    p.box((-3.6, 3.6, -1.6), (2.4, 2.4, 6.0), "paint", bevel=0.06)
    p.box((-2.38, 4.2, -1.6), (0.05, 0.3, 5.0), "light")
    p.box((-3.6, 4.83, -1.6), (2.0, 0.05, 5.4), "team", bevel=0.012)
    p.cylinder("y", (-3.6, 5.6, -3.4), 0.7, 1.6, 12, "trim")
    p.cylinder("y", (-3.6, 6.3, -3.4), 0.72, 0.2, 12, "light")
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            p.box((-3.6 + dx, 7.6, 1.0 + dz), (0.14, 5.6, 0.14), "paint")
    for y in (6.0, 8.4):
        p.box((-3.6, y, 1.0), (1.1, 0.1, 1.1), "steel")
    p.box((-3.6, 10.45, 1.0), (1.2, 0.2, 1.2), "trim")
    for sx in (-1, 1):
        p.box((sx * 3.62, 1.5, 0.0), (0.05, 0.16, 22.0), "light")
    p.box((0, 1.1, 13.27), (5.0, 0.24, 0.05), "light")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((-3.6, 11.2, 1.0), (3.2, 0.8, 0.3), "paint", bevel=0.03)
        p.box((-3.6, 11.2, 0.84), (3.0, 0.6, 0.04), "dark")
        p.box((-3.6, 11.2, 0.82), (3.05, 0.06, 0.03), "light")
        p.box((-3.6, 11.62, 1.0), (2.4, 0.04, 0.2), "team")


def details_base(p):
    bolts(p, (-1.6, DECK + 0.001, -12.4), (4.8, DECK + 0.001, -12.4), 9, UP)
    ring(p, (-3.6, 6.401, -3.4), UP, 0.5)


def build_turret1(p):
    flak(p, T1)


def build_turret2(p):
    flak(p, T2)


def no_details(p):
    pass


unit.run(__file__, "chs_leviathan", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret1", "base", T1, build_turret1, no_details),
                 unit.PieceSpec("turret2", "base", T2, build_turret2, no_details)],
         attachments={"muzzle1": {"parent": "turret1", "at": [T1[0], T1[1] + 0.7, T1[2] - 1.8]},
                      "muzzle2": {"parent": "turret2", "at": [T2[0], T2[1] + 0.7, T2[2] - 1.8]}},
         budget=10000)
