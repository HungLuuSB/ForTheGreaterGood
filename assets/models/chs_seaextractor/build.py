"""Sunken Excavator (Chaos submerged supply extractor, T1 structure,
footprint 2; S-209, BAR cormex / coruwmex): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_seaextractor/build.py

16 x 16 studs, about 6 tall, sitting on the seabed. Big readable shapes
first: a heavy dark octagonal platform ringed by a pipe loop with team
bands and clamp blocks; a hexagonal pump house in the middle with a
lit window band, bulky armor blocks round it (team and gunmetal); on top
a turning three-armed cutter (`drill`, turn Y, rig.md 9) whose arms end
in heavy perforated heads, round a capped hub. Lights stay bright, so it
reads through the water. Chaos reads rugged and improvised (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, octagon, rivets  # noqa: E402
from unit import UP, ring, seam  # noqa: E402

V = lib.vec
TOP = 4.4  # top of the pump house, where the cutter turns


def hexagon(r, cx=0.0, cz=0.0):
    return [(cx + math.cos(math.radians(30 + 60 * k)) * r, cz + math.sin(math.radians(30 + 60 * k)) * r) for k in range(6)]


def build_base(p):
    p.prism_y(octagon(7.6, 2.2), 0.0, 1.0, "dark", bevel=0.14, top_scale=0.97)
    p.prism_y(octagon(6.9, 2.0), 1.0, 1.12, "trim", bevel=0.03)
    p.box((0, 1.14, -5.0), (3.0, 0.04, 2.6), "grille")  # the walkway to the hatch
    # the pipe loop round the rim, team bands, clamp blocks
    loop = octagon(7.2, 2.1)
    for i in range(8):
        a, b = V((loop[i][0], 0.75, loop[i][1])), V((loop[(i + 1) % 8][0], 0.75, loop[(i + 1) % 8][1]))
        u = b - a
        p.ocyl(tuple(a), tuple(u), 0.36, u.length, 8, "steel")
        m = (a + b) / 2
        if i % 2 == 0:
            p.ocyl(tuple(m - u.normalized() * 0.6), tuple(u), 0.4, 1.2, 8, "team")
        else:
            p.box(tuple(m + V((0, 0.2, 0))), (0.9, 0.9, 0.9), "trim", bevel=0.06)
    # the pump house: hexagonal, a lit window band, a sloped cap
    p.prism_y(hexagon(2.6), 1.12, 3.6, "trim", bevel=0.1)
    p.prism_y(hexagon(2.6), 3.6, TOP, "paint", bevel=0.08, top_scale=0.8)
    p.box((0, 3.0, -2.27), (1.8, 0.5, 0.06), "power")
    p.box((0, 3.0, -2.25), (2.2, 0.8, 0.04), "dark")
    # bulky armor blocks round the house
    for k in range(6):
        a = math.radians(60 * k)
        d = V((math.sin(a), 0, -math.cos(a)))
        side = V((d.z, 0, -d.x))
        c = d * 4.0 + V((0, 2.1, 0))
        kind = "team" if k % 2 == 0 else "paint"
        p.obox(tuple(c), tuple(side), UP, 2.6, 1.8, 2.0, kind, bevel=0.12)
        p.obox(tuple(c + V((0, 1.05, 0)) - d * 0.3), tuple(side), UP, 1.8, 1.0, 0.3, "trim", bevel=0.05)
        p.obox(tuple(c + d * 0.92 + V((0, 0.3, 0))), tuple(side), tuple(d), 1.6, 0.14, 0.04, "light" if k % 3 == 0 else "dark")
    # the front hatch with a lamp
    p.box((0, 1.6, -6.4), (2.2, 1.0, 1.4), "trim", bevel=0.08)
    p.box((0, 1.7, -7.12), (1.2, 0.4, 0.04), "head")

    # the cutter: three arms ending in perforated heads round a capped hub
    with p.sub("drill", (0.0, TOP, 0.0), "turn", (0, 1, 0)):
        drum(p, (0, TOP + 0.4, 0), 1.5, 0.8, "steel", "dark", sides=8, axis="y")
        p.cylinder("y", (0, TOP + 0.85, 0), 1.1, 0.12, 8, "power")
        p.prism_y(octagon(1.0, 0.3), TOP + 0.9, TOP + 1.5, "trim", bevel=0.06, top_scale=0.85)
        p.box((0, TOP + 1.53, 0), (1.0, 0.05, 0.5), "dark")
        for k in range(3):
            a = math.radians(90 + 120 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            side = V((-d.z, 0, d.x))
            p.obox(tuple(d * 2.4 + V((0, TOP + 0.8, 0))), tuple(d), UP, 2.8, 1.2, 0.9, "paint", bevel=0.1)
            p.obox(tuple(d * 2.4 + V((0, TOP + 1.26, 0))), tuple(d), UP, 2.0, 0.5, 0.04, "team", bevel=0.01)
            h = d * 4.4 + V((0, TOP + 0.85, 0))
            p.obox(tuple(h), tuple(d), UP, 1.8, 1.9, 1.3, "trim", bevel=0.1)
            p.obox(tuple(h + d * 0.92), tuple(side), tuple(d), 1.6, 1.1, 0.04, "dark")
            for i in (-1, 0, 1):  # the perforations
                for j in (-1, 1):
                    q = h + d * 0.95 + side * (i * 0.5) + V((0, j * 0.28, 0))
                    p.ocyl(tuple(q), tuple(d), 0.16, 0.04, 6, "grille")
            p.box(tuple(h + V((0, 0.68, 0))), (0.3, 0.12, 0.3), "light")


def details_base(p):
    for k in range(6):
        a = math.radians(60 * k)
        d = V((math.sin(a), 0, -math.cos(a)))
        side = V((d.z, 0, -d.x))
        c = d * 2.27 + V((0, 2.0, 0))
        seam(p, tuple(c - side * 1.0), tuple(c + side * 1.0), tuple(d))
    rivets(p, (-1.0, 1.4, -7.12), (1.0, 1.4, -7.12), 4, (0, 0, -1))
    ring(p, (0, TOP + 0.02, 0), UP, 1.8)


unit.run(__file__, "chs_seaextractor", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=4000,
         previews=[("35", (-22, 17, -26), (0, 2.5, 0), 50),
                   ("80", (0, 36, 6), (0, 2, 0), 50),
                   ("close", (-11, 9, -13), (0, 3.0, 0), 35)])
