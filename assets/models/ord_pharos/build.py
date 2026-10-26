"""Pharos (Order naval SAM platform, T2 structure, footprint 3, floats; S-166):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_pharos/build.py

From its approved blockout (2026-10-26). Big shapes first: a round armored
caisson riding at the waterline (y = 0) with a dark boot-top skirt, four
fenders, a team deck ring, hazard edge and deck lights; a reload magazine
with two hatches behind the tower; a tall lighthouse: a ribbed lower drum
with a door, a team band, a slimmer upper drum with lit windows, a gallery
with a rail and a glowing lantern room under a domed roof. The `launcher`
(yaws and pitches, the def's piece): a turntable, a sensor head with a lit
seeker, and two armored canister pods with team tops and ready-lit caps
(`muzzle` at the left pod's caps). Order reads clean and heavy (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import hazard, rivets  # noqa: E402
from towers import band_round, louver  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

LAUNCHER = (0.0, 19.8, 0.0)


def build_base(p):
    # the caisson: boot-top skirt, armored drum, deck, team ring
    p.cylinder("y", (0, -0.2, 0), 11.3, 0.5, 40, "dark")
    p.cylinder("y", (0, 0.5, 0), 11.0, 2.0, 40, "paint", radius2=10.6, bevel=0.1)
    p.cylinder("y", (0, 1.62, 0), 9.6, 0.16, 40, "team")
    p.cylinder("y", (0, 1.7, 0), 8.6, 0.16, 36, "trim")
    for k in range(4):  # fenders
        a = math.radians(k * 90)
        c, s = math.cos(a), math.sin(a)
        p.obox((s * 11.15, 0.6, c * 11.15), (c, 0, -s), (s, 0, c), 4.0, 1.0, 0.8, "rubber", bevel=0.1)
    for k in range(4):  # deck lights
        a = math.radians(45 + k * 90)
        p.box((math.sin(a) * 9.0, 1.85, math.cos(a) * 9.0), (0.45, 0.2, 0.45), "light")
    hazard(p, (0, 1.82, -7.6), (1, 0, 0), UP, 6.0, 0.5, stripes=10)
    # reload magazine with two hatches
    p.box((0, 2.3, 6.0), (5.0, 1.2, 3.0), "paint", bevel=0.1)
    for sx in (-1, 1):
        p.box((sx * 1.2, 2.93, 6.0), (1.9, 0.08, 1.8), "team", bevel=0.01)
    louver(p, (0, 2.3, 7.52), (1, 0, 0), (0, 0, 1), 3.0, 0.6, slats=2)
    # the lighthouse: ribbed lower drum, door, team band
    p.cylinder("y", (0, 5.7, 0), 3.2, 8.0, 24, "paint", radius2=2.9, bevel=0.06)
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10
        c, s = math.cos(a), math.sin(a)
        p.obox((s * 3.12, 4.4, c * 3.12), (c, 0, -s), (s, 0.04, c), 0.3, 5.0, 0.2, "trim")
    p.cylinder("y", (0, 8.2, 0), 3.1, 1.0, 24, "team")
    p.box((0, 2.9, -3.15), (1.4, 2.4, 0.3), "dark", bevel=0.04)
    p.box((0, 4.2, -3.25), (1.6, 0.14, 0.12), "light")
    # the upper drum with lit windows
    p.cylinder("y", (0, 12.7, 0), 2.4, 6.0, 20, "paint", radius2=2.25, bevel=0.05)
    p.box((0, 11.5, -2.42), (0.5, 1.0, 0.2), "head")
    p.box((0, 13.5, 2.32), (0.5, 1.0, 0.2), "head")
    # gallery, rail posts, lantern room, roof
    p.cylinder("y", (0, 15.9, 0), 3.7, 0.4, 24, "trim")
    p.cylinder("y", (0, 16.9, 0), 3.6, 0.1, 24, "steel")
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.box((math.sin(a) * 3.55, 16.5, math.cos(a) * 3.55), (0.08, 0.8, 0.08), "steel")
    p.cylinder("y", (0, 17.2, 0), 1.9, 2.2, 16, "power")
    for k in range(8):  # lantern mullions
        a = 2 * math.pi * k / 8
        p.box((math.sin(a) * 1.92, 17.2, math.cos(a) * 1.92), (0.12, 2.2, 0.12), "dark")
    p.cylinder("y", (0, 18.55, 0), 2.2, 0.5, 16, "dark", radius2=1.6)


def details_base(p):
    band_round(p, 1.2, 10.8, segments=32)
    band_round(p, 6.5, 3.0, segments=20)
    rivets(p, (-2.4, 1.71, 6.0), (2.4, 1.71, 6.0), 6, UP)
    ring(p, (0, 1.79, 0), UP, 5.0)


def build_launcher(p):
    p.cylinder("y", (0, 19.1, 0), 1.7, 0.6, 16, "trim")
    p.box((0, 20.1, -0.4), (1.4, 1.4, 1.6), "paint", bevel=0.08)
    p.box((0, 20.2, -1.22), (0.8, 0.6, 0.06), "head")
    for sx in (-1, 1):
        x = sx * 1.8
        p.box((x, 20.2, -0.3), (1.8, 1.8, 4.4), "paint", bevel=0.12)
        p.box((x, 21.12, -0.3), (1.4, 0.06, 3.4), "team", bevel=0.01)
        p.box((x, 20.2, -2.5), (1.6, 1.6, 0.06), "trim")
        for dx in (-0.4, 0.4):
            for dy in (-0.4, 0.4):
                p.ocyl((x + dx, 20.2 + dy, -2.52), (0, 0, -1), 0.28, 0.06, 10, "weapon")


def details_launcher(p):
    for sx in (-1, 1):
        seam(p, (sx * 1.8 - 0.9, 20.7, 0.8), (sx * 1.8 + 0.9, 20.7, 0.8), (0, 1, 0))


unit.run(__file__, "ord_pharos", "order", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", LAUNCHER, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [-1.8, 20.2, -2.7]}},
         budget=6000,
         previews=[("35", (-36, 34, -44), (0, 9.0, 0), 50),
                   ("80", (0, 62, 10), (0, 6, 0), 50),
                   ("close", (-14, 22, -18), (0, 16.0, -1.0), 38)])
