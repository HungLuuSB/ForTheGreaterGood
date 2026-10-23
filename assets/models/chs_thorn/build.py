"""Thorn (Chaos IR SAM site, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_thorn/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 5 tall). Big shapes first: a patched skid slab with large team plates
and hazard striping, a ring of sandbag-like reactive blocks with amber
edge lights, a battery crate cabled to a thick post with gusset plates and
a hot band; the `launcher` (turned by the def on the post's axis, M-3): a
sensor box with an amber seeker and a big team roof, an open welded frame
carrying six bare canister tubes, three a side, staggered, each mouth
ringed with a ready light (weapon channel), a cable mast with a lamp and a
spare canister strapped at the back. The muzzle is the outer lower left
tube. Chaos reads rugged, light and open (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

PIVOT = (0.0, 2.8, 0.0)
TUBES = [(-2.4, 3.2), (-1.85, 3.75), (-1.3, 3.2), (1.3, 3.2), (1.85, 3.75), (2.4, 3.2)]
MOUTH = -1.9


def build_base(p):
    p.prism_y(octagon(3.85, 0.7), 0.0, 0.5, "dark", bevel=0.06, top_scale=0.985)
    for sz in (-1, 1):
        p.box((0, 0.53, sz * 2.75), (3.6, 0.05, 1.2), "team", bevel=0.012)
    hazard(p, (-3.0, 0.53, 0), (0, 0, 1), UP, 3.4, 0.45, stripes=8)
    p.box((2.6, 0.53, 0.6), (1.2, 0.04, 1.6), "steel", bevel=0.01)  # welded patch
    # ring of reactive blocks with amber edge lights
    for i in range(8):
        a = math.radians(22.5 + i * 45)
        c, s = math.cos(a), math.sin(a)
        if i in (1, 2):  # leave a gap for the battery crate (back right)
            continue
        p.obox((c * 2.25, 0.85, s * 2.25), (-s, 0, c), (c, 0, s), 1.4, 0.7, 0.55, "era", bevel=0.05)
        p.obox((c * 2.54, 1.0, s * 2.54), (-s, 0, c), (c, 0, s), 0.9, 0.14, 0.03, "light")
    # battery crate cabled to the post
    p.prism_y(rect(1.3, 2.6, 0.8, 0.55), 0.5, 1.5, "trim", bevel=0.05)
    p.box((1.3, 1.1, 2.04), (1.0, 0.25, 0.05), "power")
    cable(p, [(0.8, 1.4, 2.2), (0.6, 1.2, 1.2), (0.45, 1.3, 0.5)], r=0.1, kind="steel")
    # the post with gussets and a hot band
    p.cylinder("y", (0, 1.65, 0), 0.65, 2.3, 12, "paint", bevel=0.04)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        p.obox((math.sin(a) * 0.95, 1.0, math.cos(a) * 0.95), (math.cos(a), 0, -math.sin(a)),
               (math.sin(a), 0, math.cos(a)), 0.14, 1.0, 0.7, "steel")
    p.cylinder("y", (0, 2.2, 0), 0.68, 0.16, 12, "power")
    p.cylinder("y", (0, 2.75, 0), 0.85, 0.1, 12, "steel")


def details_base(p):
    rivets(p, (2.1, 0.541, -0.1), (3.1, 0.541, -0.1), 4, UP)
    ring(p, (0, 0.501, 0), UP, 3.2)
    bolts(p, (-1.6, 0.561, -2.75), (1.6, 0.561, -2.75), 6, UP)


def build_launcher(p):
    p.cylinder("y", (0, 2.9, 0), 0.75, 0.2, 12, "trim")
    p.box((0, 3.5, 0.15), (1.4, 1.1, 1.6), "paint", bevel=0.06)
    p.box((0, 3.6, -0.67), (1.0, 0.5, 0.05), "dark")
    p.box((0, 3.6, -0.7), (0.8, 0.32, 0.04), "weapon")  # seeker
    p.box((0, 4.07, 0.15), (1.3, 0.05, 1.5), "team", bevel=0.01)
    # open welded frame: two cross bars, end plates, a diagonal brace
    p.box((0, 3.25, 0.7), (5.6, 0.22, 0.22), "steel")
    p.box((0, 3.25, -0.9), (5.6, 0.18, 0.18), "steel")
    for sx in (-1, 1):
        p.box((sx * 2.85, 3.45, -0.1), (0.12, 0.9, 1.9), "trim", bevel=0.02)
        p.obox((sx * 1.6, 3.4, -0.1), (sx * 1.0, 0.3, 0), (0, 0, 1), 1.4, 0.12, 0.12, "steel")
    for x, y in TUBES:
        p.cylinder("z", (x, y, -0.25), 0.26, 3.3, 10, "trim")
        p.cylinder("z", (x, y, 0.6), 0.28, 0.2, 10, "dark")  # strap
        p.cylinder("z", (x, y, MOUTH - 0.03), 0.2, 0.04, 10, "weapon")  # ready light at the mouth
    p.box((-2.4, 4.1, 0.9), (0.3, 1.3, 0.3), "dark")  # cable mast
    p.box((-2.4, 4.8, 0.9), (0.26, 0.14, 0.26), "light")
    drum(p, (1.0, 3.55, 1.25), 0.24, 1.6, "steel", "dark", sides=10, axis="x")  # spare canister


def details_launcher(p):
    for x, y in TUBES:
        ring(p, (x, y, 1.401), (0, 0, 1), 0.18, segments=8)


unit.run(__file__, "chs_thorn", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": [TUBES[0][0], TUBES[0][1], MOUTH - 0.05]}},
         budget=6000,
         previews=[("35", (-15, 12, -18), (0, 2.5, -0.5), 50),
                   ("80", (0, 26, 4), (0, 2, -0.5), 50),
                   ("close", (-7, 7, -9), (0, 3.0, -1.0), 40)])
