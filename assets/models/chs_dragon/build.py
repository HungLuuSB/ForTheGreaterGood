"""Dragon (Chaos flying fortress, T2 air, footprint 3; S-181; huge, tough
and fast; pours fire straight down, two green lasers): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_dragon/build.py

From its approved blockout (2026-10-26), a 32-stud span. Big shapes
first: a long armored hull tapering into a dragon head (a snout with a
dark jaw, glowing eyes, swept horns), a spined back with a team plate, a
long tail ending in a blade with a team fin and side fins, broad swept
wings with ribbed leading edges, team panels and claw tips, a big ducted
fan in each wing (`fanL` / `fanR`, client-spun, tools/animate.py). Under
the hull the `belly` turret (turns) with the `flame` nozzle hanging from
it, a glowing throat (the fire gun fires from it), and a `laser_l` /
`laser_r` turret on each wing tip with a ringed barrel and a green lens
(`laser_l_muzzle` / `laser_r_muzzle`). Chaos reads crude and brutal
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

WY = 3.6  # the wings' height
TX, TZ = 15.2, -1.2  # the wing-tip turrets
FAN = 8.6  # the fans' offset either side
BELLY = (0.0, 1.0, -2.0)
SIDE = [(-9.0, 1.2), (8.0, 1.6), (9.4, 2.6), (9.0, 4.6), (2.0, 5.2), (-6.0, 5.1), (-9.4, 4.0)]  # hull (z, y)


def build_base(p):
    p.prism_x(SIDE, -3.5, 3.5, "paint", bevel=0.2)
    p.box((0, 1.0, -0.5), (5.0, 0.4, 13.0), "dark")  # the belly armor
    p.box((0, 5.22, 2.0), (3.6, 0.06, 6.0), "team", bevel=0.02)
    # the dragon head: a tapering snout, a dark jaw, glowing eyes, horns
    p.prism_x([(-9.4, 1.6), (-9.4, 5.0), (-12.0, 4.3), (-14.2, 3.2), (-14.2, 2.4), (-12.0, 2.0)], -2.5, 2.5, "paint", bevel=0.16)
    p.prism_x([(-9.0, 0.9), (-13.8, 1.6), (-13.8, 2.3), (-9.0, 2.0)], -1.8, 1.8, "dark", bevel=0.08)
    for k in range(5):  # teeth
        p.box((-1.2 + k * 0.6, 2.1, -13.4), (0.18, 0.4, 0.18), "steel")
    for sx in (-1, 1):
        p.obox((sx * 1.7, 4.3, -10.6), (0, 0, 1), (sx, 0.4, -0.3), 0.9, 0.4, 0.08, "weapon")
        p.ocyl((sx * 1.6, 4.8, -9.0), (sx * 0.4, 0.6, 0.8), 0.45, 3.2, 6, "steel", radius2=0.05)  # horns
    # the spined back, the long tail, its blade, fins
    for i, z in enumerate((-6.0, -3.0, 0.0, 3.0, 6.0)):
        h = 1.6 - i * 0.12
        p.prism_x([(z - 0.9, 5.0), (z + 0.9, 5.0), (z + 0.6, 5.0 + h)], -0.22, 0.22, "steel")
    p.prism_x([(8.0, 2.4), (18.0, 3.4), (18.6, 3.8), (18.0, 4.4), (8.4, 5.0)], -1.6, 1.6, "paint", bevel=0.12)
    p.prism_x([(13.0, 4.2), (16.0, 4.0), (17.0, 7.0), (15.0, 6.6)], -0.2, 0.2, "team")
    for sx in (-1, 1):
        p.obox((sx * 3.8, 3.8, 15.0), (1, sx * -0.17, 0), (0, 0, 1), 5.0, 0.4, 2.6, "trim", bevel=0.04)
    # swept wings: ribbed leading edges, team panels, claw tips
    for sx in (-1, 1):
        wing = [(sx * 3.4, -3.4), (sx * 15.8, 0.4), (sx * 15.8, 3.8), (sx * 13.0, 5.4), (sx * 3.4, 5.0)]
        if sx > 0:
            wing.reverse()
        p.prism_y([(x, z) for x, z in wing], WY - 0.4, WY + 0.4, "paint", bevel=0.1)
        p.obox((sx * 9.6, WY + 0.15, -1.5), (sx * 0.95, 0, 0.31), (0, 1, 0), 12.6, 0.7, 0.4, "trim", bevel=0.04)
        p.box((sx * 13.0, WY + 0.43, 3.4), (3.0, 0.06, 2.6), "team", bevel=0.02)
        p.prism_x([(2.6, WY - 0.4), (4.8, WY - 0.4), (3.6, WY - 2.0)], sx * 15.6 - 0.3, sx * 15.6 + 0.3, "steel")
        p.box((sx * 15.82, WY, 2.0), (0.05, 0.14, 3.0), "light")
        # the ducted fan: an open ring of armored segments (the fan shows), glowing studs on its lip
        for k in range(16):
            a = 2 * math.pi * (k + 0.5) / 16
            c, s = math.cos(a), math.sin(a)
            p.obox((sx * FAN + s * 3.0, WY + 0.4, 1.6 + c * 3.0), (c, 0, -s), (s, 0, c), 1.25, 1.6, 0.5, "dark", bevel=0.04)
            if k % 4 == 0:
                p.box((sx * FAN + s * 3.0, WY + 1.24, 1.6 + c * 3.0), (0.3, 0.06, 0.3), "power")
        for k in range(2):  # struts across the duct
            a = math.radians(45 + 90 * k)
            p.obox((sx * FAN, WY - 0.2, 1.6), (math.cos(a), 0, math.sin(a)), (0, 1, 0), 5.8, 0.3, 0.25, "steel")
    # under the head and the wings: lights
    p.box((0, 1.65, -13.0), (1.0, 0.1, 0.3), "light")


def details_base(p):
    for sx in (-1, 1):
        seam(p, (sx * 3.51, 3.0, -8.0), (sx * 3.51, 3.0, 7.6), (sx, 0, 0))
        rivets(p, (sx * 3.51, 4.2, -6.0), (sx * 3.51, 4.2, 6.0), 10, (sx, 0, 0))


def fan(sx):
    def build(p):
        for k in range(3):
            a = math.radians(k * 60)
            p.obox((sx * FAN, WY + 0.5, 1.6), (math.cos(a), 0, math.sin(a)), (0, 1, 0), 5.8, 0.9, 0.18, "steel")
        p.cylinder("y", (sx * FAN, WY + 0.6, 1.6), 0.6, 0.5, 12, "power")
    return build


def build_belly(p):
    p.cylinder("y", (0, 0.4, -2.0), 1.9, 1.4, 16, "trim", bevel=0.06)
    p.box((0, 0.4, -3.95), (1.2, 0.5, 0.05), "light")


def build_flame(p):
    p.cylinder("y", (0, -1.0, -2.0), 0.8, 1.6, 12, "dark", radius2=0.95)
    for y in (-0.6, -1.3):
        p.cylinder("y", (0, y, -2.0), 0.98, 0.18, 12, "steel")
    p.cylinder("y", (0, -1.83, -2.0), 0.6, 0.04, 12, "weapon")


def laser(sx):
    x = sx * TX

    def build(p):
        p.box((x, WY, TZ), (1.8, 1.6, 2.2), "trim", bevel=0.1)
        p.ocyl((x, WY, TZ - 1.0), (0, 0, -1), 0.35, 3.2, 10, "steel")
        for z in (TZ - 2.0, TZ - 3.2):
            p.ocyl((x, WY, z), (0, 0, -1), 0.46, 0.2, 10, "dark")
        p.ocyl((x, WY, TZ - 4.2), (0, 0, -1), 0.28, 0.05, 10, "weapon")
    return build


none = lambda p: None  # noqa: E731
unit.run(__file__, "chs_dragon", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("fanL", "base", (-FAN, WY + 0.5, 1.6), fan(-1), none),
                 unit.PieceSpec("fanR", "base", (FAN, WY + 0.5, 1.6), fan(1), none),
                 unit.PieceSpec("belly", "base", BELLY, build_belly, none),
                 unit.PieceSpec("flame", "belly", (0.0, -0.3, -2.0), build_flame, none),
                 unit.PieceSpec("laser_l", "base", (-TX, WY, TZ + 0.6), laser(-1), none),
                 unit.PieceSpec("laser_r", "base", (TX, WY, TZ + 0.6), laser(1), none)],
         attachments={"laser_l_muzzle": {"parent": "laser_l", "at": [-TX, WY, TZ - 4.4]},
                      "laser_r_muzzle": {"parent": "laser_r", "at": [TX, WY, TZ - 4.4]}},
         budget=8000,
         previews=[("35", (-40, 34, -46), (0, 3.0, 0), 50),
                   ("80", (0, 64, 10), (0, 3.0, 0), 50),
                   ("close", (-18, 14, -22), (0, 3.5, -6.0), 38)])
