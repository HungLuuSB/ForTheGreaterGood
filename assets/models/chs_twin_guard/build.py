"""Twin Guard (Chaos twin laser tower, T1 structure, footprint 2; S-157):
mesh, textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_twin_guard/build.py

From its approved blockout: the Guard's tower (patched pad, heavy angled
skirt, octagonal column with welded bands, a glowing vent) with a wider
rounded `turret` (yaw). The `mount` (pitch, -60..+60 degrees): a welded bar
carrying two Guard laser shrouds, each its own client piece (`barrel1`
left, `barrel2` right; recoil along +Z) with `muzzle1` / `muzzle2` at their
lenses. Chaos reads rugged and improvised (M-14). Writes export/ through
tools/unit.py.

F18 (the user's beta feedback 2026-10-26, "turret should stand high,
proud, tower above others"): the approved mesh scaled x1.259 (the
`scale` below), so it stands as tall as its approved F18 blockout
(~17.5 studs) and reads heavier; same shapes, pieces and anchors.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from towers import antenna, band_box, band_octagon, band_round, clamped_cable, glow_strip, louver, skirt_round, skirt_square  # noqa: E402,F401
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

TURRET = (0.0, 10.0, 0.0)
MOUNT = (0.0, 11.2, -0.6)
BX = 1.6
MUZZLES = {"muzzle1": (-BX, 11.2, -5.2), "muzzle2": (BX, 11.2, -5.2)}


def build_base(p):
    p.cylinder("y", (0, 0.6, 0), 3.7, 1.2, 24, "dark", bevel=0.08)
    p.box((1.9, 1.22, 2.3), (1.6, 0.04, 1.2), "trim", bevel=0.01)
    for k in range(6):
        a = math.radians(k * 60 + 30)
        t = math.radians(24)
        out = (math.sin(a), 0.0, math.cos(a))
        n = (out[0] * math.cos(t), math.sin(t), out[2] * math.cos(t))
        u = (math.cos(a), 0.0, -math.sin(a))
        p.obox((out[0] * 3.7, 1.9, out[2] * 3.7), u, n, 3.2, 2.6, 0.6, "team" if k % 2 == 0 else "era", bevel=0.08)
    p.cylinder("y", (0, 2.3, 0), 2.4, 2.2, 16, "dark", bevel=0.06)
    p.prism_y(octagon(1.6, 0.5), 3.4, 10.0, "paint", bevel=0.08)
    for y in (4.4, 9.4):
        p.prism_y(octagon(1.75, 0.52), y - 0.2, y + 0.2, "trim", bevel=0.03)
    p.box((0, 7.4, -1.62), (1.0, 1.6, 0.06), "power")
    p.box((0, 7.4, -1.6), (1.2, 1.8, 0.04), "grille")
    cable(p, [(-1.5, 1.3, 2.3), (-1.65, 3.4, 1.0), (-1.65, 7.0, 0.9)], r=0.12, kind="dark")
    hazard(p, (0, 1.23, -2.5), (1, 0, 0), UP, 2.2, 0.35, stripes=6)
    skirt_round(p, 3.7, sides=24)
    louver(p, (0, 6.6, 1.63), (1, 0, 0), (0, 0, 1), 1.0, 1.4)
    for sx in (-1, 1):
        glow_strip(p, (sx * 0.6, 4.8, -1.63), (sx * 0.6, 6.3, -1.63), (0, 0, -1), width=0.1)
    clamped_cable(p, [(2.7, 1.3, -1.6), (1.7, 3.4, -0.8), (1.7, 9.0, -0.6)], r=0.1)


def details_base(p):
    band_round(p, 1.8, 2.4)
    band_octagon(p, 6.2, 1.6, 0.5)
    rivets(p, (-1.0, 5.0, -1.61), (1.0, 5.0, -1.61), 5, (0, 0, -1))


def build_turret(p):
    p.cylinder("y", (0, 11.2, 0.2), 2.2, 2.4, 22, "paint", bevel=0.1)
    p.cylinder("y", (0, 12.45, 0.2), 2.0, 0.12, 22, "trim")
    p.box((0, 12.53, 0.5), (2.2, 0.05, 1.8), "team", bevel=0.01)
    p.box((0, 12.0, -2.0), (0.5, 0.36, 0.36), "head")  # amber sensor
    p.box((2.1, 11.0, 1.0), (0.3, 0.9, 1.4), "era", bevel=0.03)
    louver(p, (0, 11.2, 2.42), (1, 0, 0), (0, 0, 1), 1.2, 0.9)
    antenna(p, (1.2, 12.5, 1.2), 1.4)


def details_turret(p):
    band_round(p, 10.6, 2.2, cz=0.2)
    ring(p, (0, 12.56, 0.5), UP, 0.6)


def build_mount(p):
    p.box((0, 11.2, -1.0), (4.4, 1.0, 1.0), "steel", bevel=0.05)
    for sx in (-1, 1):
        x = sx * BX
        with p.sub("barrel1" if sx < 0 else "barrel2", (x, 11.2, -1.0), "slide", (0, 0, 1), 0.5):
            p.box((x, 11.2, -2.0), (1.3, 1.3, 2.4), "paint", bevel=0.08)
            p.box((x, 11.9, -2.0), (1.4, 0.14, 2.0), "dark")
            p.ocyl((x, 11.2, -3.2), (0, 0, -1), 0.36, 1.8, 12, "steel")
            p.ocyl((x, 11.2, -3.9), (0, 0, -1), 0.46, 0.26, 12, "dark")
            p.ocyl((x, 11.2, -4.98), (0, 0, -1), 0.26, 0.1, 12, "weapon")


def details_mount(p):
    for sx in (-1, 1):
        rivets(p, (sx * 2.26, 10.9, -0.9), (sx * 2.26, 10.9, -2.9), 4, (sx, 0, 0))


F18 = 1.259  # the F18 scale (old top 13.9 -> 17.5 studs)

unit.run(__file__, "chs_twin_guard", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, details_turret),
                 unit.PieceSpec("mount", "turret", MOUNT, build_mount, details_mount)],
         attachments={k: {"parent": "barrel1" if k == "muzzle1" else "barrel2", "at": list(v)} for k, v in MUZZLES.items()},
         budget=4000,
         scale=(F18, F18, F18),
         previews=[("35", (-25.2, 20.1, -30.2), (0.0, 8.2, 0.0), 40),
                   ("close", (-11.3, 17.6, -12.6), (0.0, 13.3, -1.3), 36)])
