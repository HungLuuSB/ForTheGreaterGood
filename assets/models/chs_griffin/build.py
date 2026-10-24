"""Griffin (Chaos mobile point defence, T2 ground, footprint 1; S-149): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_griffin/build.py

From its blockout: a lighter 6x6 truck. Big shapes first: a slab hull with
exposed wheels, an open-backed cab with an amber slit and a team roof, team
plates on the flatbed, a spare tube crate and a strapped fuel drum. The
`launcher` (static: launches straight up): an open welded rack of twelve
upright interceptor tubes (3 x 4), the deep stock, each mouth ringed with an
amber ready light (`weapon`); `muzzle` at the front left tube. A lattice radar
mast behind the cab carrying a small panel with an amber edge (`radar`,
M-27, client-turned) and a beacon. Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import cable, drum, hazard  # noqa: E402
from unit import UP, bolts, ring, wheel  # noqa: E402

PIVOT = (0.0, 2.3, 2.0)
TUBES = [(-1.0 + j * 1.0, 0.5 + i * 1.0) for i in range(4) for j in range(3)]
TOP = 4.9
RADAR = (-1.5, 5.5, -2.2)
MUZZLE = (TUBES[0][0], TOP + 0.1, TUBES[0][1])


def build_base(p):
    p.prism_x([(-5.2, 1.2), (-4.4, 1.0), (4.9, 1.0), (4.9, 2.3), (-4.6, 2.3)], -2.0, 2.0, "paint", bevel=0.06)
    p.box((0, 3.05, -3.7), (3.8, 1.5, 2.2), "paint", bevel=0.06)
    p.box((0, 3.4, -4.82), (3.0, 0.3, 0.05), "light")  # amber slit
    p.box((0, 3.84, -3.7), (3.0, 0.05, 1.6), "team", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 1.6, 2.34, 1.4), (0.8, 0.05, 3.6), "team", bevel=0.01)
        p.box((sx * 1.2, 1.45, -5.22), (0.5, 0.2, 0.08), "head")
        p.box((sx * 2.02, 2.1, 0.0), (0.05, 0.12, 8.0), "light")
        for i, z in enumerate((-3.4, 0.4, 3.6)):
            wheel(p, sx * 2.2, 0.75, z, 0.75, 0.6, name=f"wheel{'L' if sx < 0 else 'R'}{i + 1}")
    p.box((1.5, 2.65, -1.6), (1.0, 0.7, 1.6), "trim", bevel=0.03)  # spare tube crate
    drum(p, (-1.5, 2.8, -1.4), 0.45, 1.0, "steel", "trim", sides=12, axis="y")
    hazard(p, (0, 2.32, 4.6), (1, 0, 0), UP, 3.4, 0.3, stripes=8)
    # lattice radar mast
    for dx in (-0.22, 0.22):
        for dz in (-0.22, 0.22):
            p.box((RADAR[0] + dx, 3.9, RADAR[2] + dz), (0.08, 3.2, 0.08), "paint")
    for y in (3.0, 4.2):
        p.box((RADAR[0], y, RADAR[2]), (0.55, 0.06, 0.55), "steel")
    p.box((RADAR[0], 6.45, RADAR[2]), (0.3, 0.3, 0.3), "light")  # beacon
    cable(p, [(-1.3, 5.2, -2.0), (-1.0, 3.6, -1.0), (-0.8, 2.4, 0.2)], r=0.04, kind="dark")
    with p.sub("radar", RADAR, "turn", (0, 1, 0)):  # M-27
        p.box((RADAR[0], 5.9, RADAR[2]), (1.6, 0.8, 0.14), "paint", bevel=0.02)
        p.box((RADAR[0], 5.9, RADAR[2] - 0.09), (1.42, 0.62, 0.02), "dark")
        p.box((RADAR[0], 5.9, RADAR[2] - 0.1), (1.48, 0.06, 0.02), "light")


def details_base(p):
    bolts(p, (-1.6, 2.301, -1.8), (1.6, 2.301, -1.8), 6, UP)


def build_launcher(p):
    x, y, z = PIVOT
    p.box((0, y + 0.2, z), (3.2, 0.4, 4.2), "steel", bevel=0.03)
    for zz in (z - 2.0, z + 2.0):  # welded frame posts and rails
        for sx in (-1, 1):
            p.box((sx * 1.5, y + 1.4, zz), (0.16, 2.4, 0.16), "trim")
        p.box((0, y + 2.4, zz), (3.1, 0.14, 0.14), "trim")
    for sx in (-1, 1):
        p.box((sx * 1.5, y + 2.4, z), (0.14, 0.14, 4.0), "trim")
    for tx, tz in TUBES:
        p.cylinder("y", (tx, y + 1.5, tz), 0.3, 2.2, 10, "paint")
        p.cylinder("y", (tx, y + 2.62, tz), 0.33, 0.06, 10, "dark")
        p.cylinder("y", (tx, y + 2.64, tz), 0.22, 0.04, 10, "weapon")
    p.box((0, y + 1.0, z + 2.12), (2.4, 0.6, 0.05), "team", bevel=0.01)


def details_launcher(p):
    ring(p, (TUBES[4][0], PIVOT[1] + 2.66, TUBES[4][1]), UP, 0.25)


unit.run(__file__, "chs_griffin", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("launcher", "base", PIVOT, build_launcher, details_launcher)],
         attachments={"muzzle": {"parent": "launcher", "at": list(MUZZLE)}},
         budget=5000)
