"""Deep Excavator (Chaos supply extractor, T2 structure, footprint 2): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_advextractor/build.py

F6 (the user 2026-10-26: "T2 of the T1 extractor must be the same size,
they should look like an upgrade version"; S-184 footprint 2, upgraded in
place over the T1 on its 2 x 2 deposit patch, S-108): the T1 Excavator's
mesh (chs_extractor/build.py: the slab, the raised grated platform with
team plates, the four-leg lattice derrick, the engine house with its
stacks, the salvaged ore tank and skip conveyor) grown into the upgrade:
the derrick nearly twice as tall with five brace rings and X-bracing on
every face, armored feet with spikes, a heavier head with a lamp cage, a
thicker drill (`drill`, turn Y, rig.md 9) with four power bands, a second
engine drum beside the house and a third stack, fuel tanks. About 15 studs
tall to the T1's 8. Chaos reads rugged and improvised (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard, piston, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

V = lib.vec
LEG_FOOT, LEG_TOP, TOP_Y = 4.8, 1.3, 13.0


def build_base(p):
    # slab, a raised grated platform, team plates on the platform deck
    p.prism_y([(-7.8, -7.0), (-7.0, -7.8), (7.0, -7.8), (7.8, -7.0), (7.8, 7.0), (7.0, 7.8), (-7.0, 7.8), (-7.8, 7.0)],
              0.0, 0.75, "dark", bevel=0.12, top_scale=0.985)
    p.box((0, 1.0, 0), (11.0, 0.5, 11.0), "paint", bevel=0.1)
    p.box((0, 1.27, 0), (10.2, 0.04, 10.2), "grille")
    for sx in (-1, 1):
        p.box((sx * 3.6, 1.29, -4.3), (2.6, 0.05, 1.6), "team", bevel=0.02)
    hazard(p, (0, 1.29, 5.0), (1, 0, 0), (0, 1, 0), 9.0, 0.5, stripes=16)
    # the derrick: four legs, three rings of braces, X-bracing on the sides
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = V((sx * LEG_FOOT, 1.25, sz * LEG_FOOT))
            b = V((sx * LEG_TOP, TOP_Y, sz * LEG_TOP))
            p.obox(tuple((a + b) / 2), tuple(b - a), (sz, 0, -sx), (b - a).length, 0.36, 0.36, "trim", bevel=0.04)
            p.box((sx * LEG_FOOT, 1.6, sz * LEG_FOOT), (1.2, 0.7, 1.2), "trim", bevel=0.06)  # armored feet
            p.ocyl((sx * (LEG_FOOT + 0.45), 1.6, sz * (LEG_FOOT + 0.45)), (sx * 0.6, 1.0, sz * 0.6), 0.22, 1.3, 6, "steel", radius2=0.02)
    for y in (3.2, 5.6, 8.0, 10.4, 12.2):
        t = (y - 1.25) / (TOP_Y - 1.25)
        w = LEG_FOOT + (LEG_TOP - LEG_FOOT) * t
        for sz in (-1, 1):
            p.box((0, y, sz * w), (2 * w, 0.2, 0.2), "dark")
        for sx in (-1, 1):
            p.box((sx * w, y, 0), (0.2, 0.2, 2 * w), "dark")
    # X-bracing on every face, two tiers
    for y0, y1 in ((3.2, 5.6), (5.6, 8.0)):
        w0 = LEG_FOOT + (LEG_TOP - LEG_FOOT) * ((y0 - 1.25) / (TOP_Y - 1.25))
        w1 = LEG_FOOT + (LEG_TOP - LEG_FOOT) * ((y1 - 1.25) / (TOP_Y - 1.25))
        for sz in (-1, 1):
            for s in (-1, 1):
                a, b = V((s * w0, y0, sz * w0)), V((-s * w1, y1, sz * w1))
                p.obox(tuple((a + b) / 2), tuple(b - a), (0, 0, 1), (b - a).length, 0.14, 0.14, "dark")
                a, b = V((sz * w0, y0, s * w0)), V((sz * w1, y1, -s * w1))
                p.obox(tuple((a + b) / 2), tuple(b - a), (1, 0, 0), (b - a).length, 0.14, 0.14, "dark")
    # head block at the top with a team roof and a beacon
    p.box((0, TOP_Y + 0.7, 0), (3.6, 1.4, 3.6), "paint", bevel=0.1)
    p.box((0, TOP_Y + 1.42, 0), (2.8, 0.05, 2.8), "team", bevel=0.015)
    p.box((0, TOP_Y + 0.7, -1.82), (2.6, 0.18, 0.04), "light")
    p.cylinder("y", (0, TOP_Y + 1.75, 0), 0.32, 0.5, 8, "light")
    for sx in (-1, 1):  # the lamp cage
        for sz in (-1, 1):
            p.box((sx * 0.45, TOP_Y + 1.8, sz * 0.45), (0.08, 0.7, 0.08), "steel")
    # engine house (right rear): a heavy block, team roof, twin stacks with
    # hot rings, a glowing vent, a piston-driven pump
    p.box((5.0, 2.4, 3.6), (3.6, 2.4, 4.4), "paint", bevel=0.14)
    p.box((5.0, 3.62, 3.6), (3.0, 0.05, 3.8), "team", bevel=0.02)
    p.box((6.82, 2.4, 3.6), (0.05, 0.7, 2.8), "power")
    for dz in (-1.2, 0.0, 1.2):
        p.cylinder("y", (4.0, 4.8, 3.6 + dz), 0.32, 2.6, 10, "steel")
        p.cylinder("y", (4.0, 6.12, 3.6 + dz), 0.35, 0.12, 10, "power")
    # F6: a second engine drum beside the house, fuel tanks in front
    drum(p, (5.4, 2.3, -2.2), 1.05, 3.0, "dark", "trim", sides=16, axis="z")
    p.box((5.4, 3.4, -2.2), (1.2, 0.05, 2.2), "team")
    p.box((6.47, 2.3, -2.2), (0.05, 0.3, 2.0), "power")
    for x in (-5.6, -4.2):
        p.cylinder("y", (x, 2.5, -5.4), 0.6, 2.4, 12, "paint")
        p.cylinder("y", (x, 3.75, -5.4), 0.4, 0.12, 10, "dark")
    piston(p, (3.2, 3.2, 1.5), (1.5, 2.0, 0.9), r=0.12)
    # salvaged ore tank (left), strapped, with a skip conveyor up to the platform
    drum(p, (-5.2, 2.6, 2.4), 1.25, 4.2, "paint", "trim", sides=18, axis="z")
    for dz in (-1.2, 0.0, 1.2):
        p.cylinder("z", (-5.2, 2.6, 2.4 + dz), 1.29, 0.14, 18, "dark")
    p.box((-5.2, 3.9, 2.4), (1.4, 0.05, 2.6), "team")
    a, b = V((-3.2, 1.3, -2.0)), V((-5.2, 3.8, -0.6))
    u = b - a
    p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.9, 0.3, "trim", bevel=0.04)
    p.obox(tuple((a + b) / 2 + V((0, 0.17, 0))), tuple(u), (0, 1, 0), u.length * 0.95, 0.7, 0.04, "grille")
    # beacons on the platform corners
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 5.3, 1.4, sz * 5.3), (0.3, 0.25, 0.3), "light")

    # the drill: a turning shaft with power bands, a collar and a cutter head
    with p.sub("drill", (0.0, 1.25, 0.0), "turn", (0, 1, 0)):
        p.cylinder("y", (0, 1.65, 0), 1.25, 0.8, 16, "trim")
        p.cylinder("y", (0, 2.1, 0), 1.2, 0.18, 16, "power")
        p.cylinder("y", (0, 7.2, 0), 1.0, 10.8, 14, "steel")
        for y in (3.4, 6.0, 8.6, 11.2):
            p.cylinder("y", (0, y, 0), 1.06, 0.2, 14, "power")
        for k in range(8):  # flights spiralling round the shaft
            a = math.radians(45 + 90 * k)
            d = V((math.cos(a), 0, math.sin(a)))
            p.obox(tuple(V((0, 2.8 + k * 1.1, 0)) + d * 1.22), tuple(d), (0, 1, 0), 0.55, 0.7, 0.12, "dark")


def details_base(p):
    rivets(p, (3.4, 3.61, 1.6), (6.6, 3.61, 1.6), 6, UP)
    seam(p, (3.2, 2.4, 1.39), (6.8, 2.4, 1.39), (0, 0, -1))
    for sx in (-1, 1):
        rivets(p, (sx * 5.45, 1.26, -4.5), (sx * 5.45, 1.26, 4.5), 7, UP)


unit.run(__file__, "chs_advextractor", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000,
         previews=[("35", (-30, 26, -36), (0, 7.0, 0), 50),
                   ("80", (0, 40, 6), (0, 4, 0), 50),
                   ("close", (-12, 14, -14), (0, 7.0, 0), 35)])
