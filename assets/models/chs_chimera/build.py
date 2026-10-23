"""Chimera (Chaos mobile anti-nuke, T2 ground): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_chimera/build.py

New mesh from its blockout, at the T2 light size (size-scale.md: about
1.3x a T1 truck, fits one cell). A lighter 6x6 truck (`wheelL1..3` /
`wheelR1..3`, spin) with an open-backed armored cab, an amber slit and a
team roof, a flatbed with team plates and a rest, and the `launcher` (the
def's piece, hinged at its rear end): an exposed rail with one slim
interceptor, fins, a strap and a glowing readiness nose (weapon); a braced
lattice mast at the back with the client-turned radar array (`radar`,
M-27). `muzzle` at the rail's front. Chaos reads light and improvised
(M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard  # noqa: E402
from unit import UP, bolts, wheel  # noqa: E402

PIVOT = (0.0, 2.7, 4.4)
MIS_Y = 3.6
RADAR = (1.7, 7.7, 4.2)


def build_base(p):
    # chassis, flatbed, open-backed cab
    p.prism_x([(-5.0, 1.2), (-4.2, 1.0), (4.9, 1.0), (4.9, 2.3), (-5.0, 2.3)], -2.0, 2.0, "dark", bevel=0.05)
    p.prism_x([(-4.9, 2.2), (-2.6, 2.2), (-2.6, 3.9), (-3.4, 4.0), (-4.9, 3.2)], -2.0, 2.0, "paint", bevel=0.06)
    p.box((0, 3.5, -4.92), (3.0, 0.25, 0.06), "light")  # amber slit
    p.box((0, 4.03, -3.4), (2.8, 0.05, 1.2), "team", bevel=0.01)
    p.box((-1.4, 2.34, 1.4), (1.0, 0.05, 3.4), "team", bevel=0.01)
    hazard(p, (1.4, 2.33, 1.4), (0, 0, 1), UP, 3.4, 0.5, stripes=7)
    p.box((0, 2.7, -1.9), (1.6, 0.8, 0.4), "steel")  # rest
    for sx in (-1, 1):
        p.box((sx * 1.4, 1.6, -5.05), (0.5, 0.18, 0.06), "head")
        p.box((sx * 2.03, 1.8, 0.4), (0.04, 0.12, 7.6), "light")
        for i, z in enumerate((-3.6, 1.2, 3.6)):
            wheel(p, sx * 2.25, 0.75, z, 0.75, 0.6, name=f"wheel{'L' if sx < 0 else 'R'}{i + 1}")
    drum(p, (-1.4, 2.9, 3.9), 0.5, 1.6, "paint", "trim", sides=12, axis="z")  # fuel drum
    # braced lattice mast at the back right
    for dx in (-0.3, 0.3):
        for dz in (-0.3, 0.3):
            p.box((RADAR[0] + dx, 4.95, RADAR[2] + dz), (0.12, 5.4, 0.12), "paint")
    for y in (3.5, 5.5):
        p.box((RADAR[0], y, RADAR[2]), (0.8, 0.08, 0.8), "steel")
    p.box((RADAR[0], 7.0, RADAR[2] - 0.45), (0.25, 0.18, 0.25), "light")
    cable(p, [(RADAR[0] - 0.3, 2.5, RADAR[2] - 0.4), (0.6, 2.6, 2.8), (0.2, 2.8, 1.8)], r=0.06, kind="dark")

    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        t = math.radians(15)
        n = (0, math.sin(t), -math.cos(t))
        c = (RADAR[0], 8.3, RADAR[2])
        p.cylinder("y", (RADAR[0], 7.8, RADAR[2]), 0.25, 0.2, 8, "steel")
        p.obox(c, (1, 0, 0), n, 2.4, 1.4, 0.2, "paint", bevel=0.02)
        p.obox(tuple(c[k] + n[k] * 0.11 for k in range(3)), (1, 0, 0), n, 2.2, 1.2, 0.02, "dark")
        p.obox(tuple(c[k] + n[k] * 0.12 for k in range(3)), (1, 0, 0), n, 2.25, 0.06, 0.02, "light")
        p.obox(tuple(c[k] - n[k] * 0.11 for k in range(3)), (1, 0, 0), n, 1.8, 0.4, 0.02, "team")


def details_base(p):
    bolts(p, (-1.8, 2.301, 3.6), (1.8, 2.301, 3.6), 6, UP)


def build_launcher(p):
    p.box((0, 2.95, 0.6), (0.8, 0.35, 7.6), "steel")  # rail
    for z in (-2.4, 3.4):
        p.box((0, 3.2, z), (0.9, 0.5, 0.3), "trim")
    p.cylinder("z", (0, MIS_Y, 0.9), 0.45, 6.4, 12, "paint")
    p.ocyl((0, MIS_Y, -2.3), (0, 0, -1), 0.45, 0.9, 12, "trim", radius2=0.12)
    p.ocyl((0, MIS_Y, -3.1), (0, 0, -1), 0.14, 0.18, 8, "weapon")
    p.cylinder("z", (0, MIS_Y, 0.2), 0.48, 0.2, 12, "dark")  # strap
    p.cylinder("z", (0, MIS_Y, 2.6), 0.47, 1.0, 12, "team")
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        c, s = math.cos(a), math.sin(a)
        p.obox((c * 0.7, MIS_Y + s * 0.7, 3.7), (0, 0, 1), (c, s, 0), 1.0, 0.06, 0.5, "trim")


def no_details(p):
    pass


unit.run(__file__, "chs_chimera", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, no_details)],
         attachments={"muzzle": {"parent": "launcher", "at": [0, MIS_Y, -3.3]}})
