"""Cataclysm (Chaos artillery emplacement, T2 structure, footprint 3): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_cataclysm/build.py

F18 (the user's beta feedback 2026-10-26, "turret should stand high,
proud, tower above others"): the approved turret stands LIFT studs higher
on a tall round pit tower (ribs, raking struts, team plates, amber slits,
a spiked rim, the slab wall and propellant tanks up on its top deck) and
its barrel is raised 40 degrees like a mortar (top ~25 studs, the F18
blockout). First built from its blockout, at the size scale (S-104:
footprint 3): bigger and more elaborate than the T1 Talos, not a rescale.
Big shapes first: a patched pad, an open gun pit (a sloped berm round a
sunken floor with a low inner wall) ringed with eight reactive-armor blocks
and amber strips, team plates on the berm, two propellant tanks on saddles
with a hose to the ring, a crate stack, a lattice floodlight mast and an
antenna on the rear corners (outside the barrel's sweep). The `turret`
(yaw, the def's piece; pivot as the blockout): a squat domed drum with a
team roof plate, team-painted reactive slabs on its front quarters, an
exposed cradle of two cheek plates and trunnions, a breech block with a shell hoist, and a huge
fat barrel with jacket rings, a glowing breech band (`weapon`) and a heavy
lip (`muzzle` at its mouth). Chaos reads rugged and improvised (M-14).
Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from towers import antenna, band_round, clamped_cable, louver  # noqa: E402
from mech import cable, drum, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

LIFT = 18.4 - 4.8  # F18: the trunnions at the blockout's 18.4
ELEV = 40  # F18: the barrel raised like a mortar's
TURRET_PIVOT = (0.0, 1.0 + LIFT, 1.0)
GY = 4.8  # barrel axis height before the lift (the turret is built there, then lifted)
TRUNNION = (0.0, GY, -1.2)
_m = unit.pitched_point((0.0, GY, -12.7), TRUNNION, ELEV)
MUZZLE = (0.0, round(_m[1] + LIFT, 3), round(_m[2], 3))
TOP = 1.62 + LIFT  # the tower's top deck (the old pit floor, lifted)
TR = 7.4  # the tower's radius
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def on(c, n, d):
    """Point d studs out from c along n (normalized)."""
    k = d / math.sqrt(sum(v * v for v in n))
    return tuple(c[i] + n[i] * k for i in range(3))


def build_base(p):
    p.prism_y(octagon(11.7, 2.6), 0.0, 0.4, "dark", bevel=0.08, top_scale=0.99)
    p.box((-8.4, 0.42, -7.0), (3.0, 0.04, 2.2), "steel", bevel=0.01)  # welded patch
    hazard(p, (0, 0.42, -11.3), (1, 0, 0), UP, 10.0, 0.5, stripes=18)
    # the berm at the foot, then the tall round tower (F18)
    p.cylinder("y", (0, 1.0, 0), 10.3, 1.2, 32, "paint", radius2=9.5)
    p.cylinder("y", (0, (1.6 + TOP) / 2, 0), TR, TOP - 1.6, 32, "paint", bevel=0.06)
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        c, s = math.cos(a), math.sin(a)
        p.obox((s * (TR + 0.05), (1.6 + TOP) / 2, c * (TR + 0.05)), (c, 0, -s), (s, 0, c), 0.4, TOP - 2.4, 0.3, "trim")
    p.cylinder("y", (0, 8.4, 0), TR + 0.2, 0.6, 32, "dark")
    for sz in (-1, 1):
        p.obox((0, 6.0, sz * (TR + 0.08)), (1, 0, 0), (0, 0, sz), 3.6, 2.2, 0.08, "team", bevel=0.015)
    for k in range(3):
        a = math.radians(-90 + k * 90)
        c, s = math.cos(a), math.sin(a)
        p.obox((s * (TR + 0.06), 11.0, -c * (TR + 0.06)), (c, 0, s), (s, 0, -c), 2.6, 0.3, 0.05, "light")
    for i in range(4):  # raking struts from the berm up the tower
        a = 2 * math.pi * (i + 0.5) / 4
        c, s = math.cos(a), math.sin(a)
        beam(p, (s * 9.4, 1.6, c * 9.4), (s * (TR + 0.3), 10.6, c * (TR + 0.3)), 0.8, "trim")
    # the top deck: a spiked rim, the low inner wall of slabs
    p.cylinder("y", (0, TOP - 0.2, 0), TR + 0.6, 0.8, 32, "trim", bevel=0.05)
    p.cylinder("y", (0, TOP + 0.02, 0), TR - 0.2, 0.04, 32, "dark")
    for i in range(8):
        a = 2 * math.pi * i / 8
        c, s = math.cos(a), math.sin(a)
        p.ocyl((s * (TR + 0.4), TOP + 0.1, c * (TR + 0.4)), (s * 0.5, 1.0, c * 0.5), 0.3, 1.8, 6, "steel", radius2=0.02)
    for i in range(16):
        a = 2 * math.pi * (i + 0.5) / 16
        c, s = math.cos(a), math.sin(a)
        p.obox((s * (TR - 0.6), TOP + 0.3, c * (TR - 0.6)), (c, 0, -s), (s * 0.3, 1, c * 0.3), 2.6, 0.6, 0.5, "trim", bevel=0.04)
    # eight reactive blocks round the berm (the blockout's ring), amber strips on the outer face
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        c, s = math.cos(a), math.sin(a)
        n = (s, 0.35, c)
        p.obox((s * 9.3, 1.75, c * 9.3), (c, 0, -s), n, 3.2, 1.3, 0.7, "era", bevel=0.05)
        p.obox(on((s * 9.3, 1.75, c * 9.3), n, 0.36), (c, 0, -s), n, 2.2, 0.16, 0.04, "light")
    for x, z in ((-4.8, -3.0), (4.8, -3.0)):  # team plates on the top deck
        p.box((x, TOP + 0.06, z), (2.6, 0.06, 2.6), "team", bevel=0.015)
    # turret ring
    p.cylinder("y", (0, TOP + 0.13, 1.0), 4.6, 0.3, 28, "steel")
    p.cylinder("y", (0, TOP + 0.31, 1.0), 4.5, 0.06, 28, "power")
    # two upright propellant tanks on the top deck (back right), a hose to the ring
    for x, z in ((4.6, 4.6), (2.2, 5.9)):
        p.cylinder("y", (x, TOP + 1.6, z), 0.9, 3.2, 14, "paint")
        p.cylinder("y", (x, TOP + 3.3, z), 0.6, 0.2, 12, "dark")
        p.box((x, TOP + 2.2, z - 0.92), (0.6, 1.6, 0.05), "hazard")
    cable(p, [(4.6, TOP + 0.6, 3.7), (3.6, TOP + 0.4, 2.6), (2.6, TOP + 0.35, 1.8)], r=0.16, kind="dark")
    # crate stack (back left)
    for dx, dy, dz in ((0, 0, 0), (0.3, 0.95, 0.2), (0, 0, 1.8)):
        p.box((-8.2 + dx, 2.1 + dy, 2.2 + dz), (1.8, 0.9, 1.6), "trim", bevel=0.05)
    p.box((-8.2, 2.1, 1.38), (1.2, 0.26, 0.05), "power")
    # lattice floodlight mast (back left corner), antenna (back right corner)
    mx, mz = -9.6, 9.6
    for sx, sz in CORNERS:
        beam(p, (mx + sx * 0.9, 0.4, mz + sz * 0.9), (mx + sx * 0.35, 7.0, mz + sz * 0.35), 0.18, "paint")
    for y, f in ((2.4, 0.73), (4.6, 0.55)):
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, (mx + sx * f, y, mz + sz * f), (mx + nx * f, y, mz + nz * f), 0.09, "steel")
    p.box((mx, 7.1, mz), (1.0, 0.2, 1.0), "trim")
    p.obox((mx + 0.3, 7.6, mz - 0.3), (1, 0, 1), (0.5, -0.3, -0.5), 1.0, 0.6, 0.4, "dark")
    p.obox((mx + 0.47, 7.5, mz - 0.47), (1, 0, 1), (0.5, -0.3, -0.5), 0.8, 0.4, 0.04, "head")
    antenna(p, (9.8, 0.4, 9.8), 6.0, r=0.07)
    for sx, sz in ((-1, -1), (1, -1)):
        p.box((sx * 10.0, 0.5, sz * 10.0), (0.4, 0.2, 0.4), "light")
    clamped_cable(p, [(-9.6, 0.5, 8.2), (-8.4, 1.5, 6.6), (-7.5, 1.7, 5.6)], r=0.08)


def details_base(p):
    band_round(p, 1.0, 10.0, segments=24)
    band_round(p, 5.0, TR + 0.02, segments=24)
    band_round(p, 12.0, TR + 0.02, segments=24)
    ring(p, (0, TOP + 0.29, 1.0), UP, 3.8)
    rivets(p, (-9.6, 0.42, -6.2), (-7.2, 0.42, -6.2), 5, UP)


def build_turret(p):
    p.cylinder("y", (0, 2.9, 1.0), 4.1, 2.0, 20, "paint", radius2=3.7, bevel=0.06)
    p.cylinder("y", (0, 4.15, 1.0), 3.7, 0.5, 20, "paint", radius2=2.9, bevel=0.04)
    p.box((0, 4.42, 2.4), (3.0, 0.05, 2.0), "team", bevel=0.015)
    # reactive slabs on the front quarters, a patch, a spotter lamp on a mast
    for sx in (-1, 1):
        a = math.radians(sx * 38)
        n = (math.sin(a) * 0.9, 0.3, -math.cos(a) * 0.9)
        p.obox((sx * 2.75, 2.9, -2.0), (math.cos(a), 0, math.sin(a)), n, 2.6, 1.7, 0.5, "team", bevel=0.05)
        p.obox(on((sx * 2.75, 2.5, -2.0), n, 0.26), (math.cos(a), 0, math.sin(a)), n, 1.8, 0.14, 0.05, "light")
    p.box((-3.6, 3.0, 2.4), (0.06, 1.2, 1.6), "steel", bevel=0.01)
    p.cylinder("y", (-2.4, 5.0, 3.2), 0.08, 1.6, 6, "steel")
    p.box((-2.4, 5.85, 3.2), (0.6, 0.4, 0.5), "dark")
    p.box((-2.4, 5.85, 2.94), (0.42, 0.24, 0.05), "light")
    # exposed cradle: cheek plates, trunnions, a cross brace
    for sx in (-1, 1):
        p.box((sx * 1.85, 4.7, -1.2), (0.45, 2.6, 3.4), "dark", bevel=0.05)
        p.cylinder("x", (sx * 2.15, GY, -1.2), 0.75, 0.3, 14, "trim")
        p.cylinder("x", (sx * 2.32, GY, -1.2), 0.4, 0.12, 10, "steel")
    p.box((0, 3.75, -1.2), (3.4, 0.5, 2.8), "dark", bevel=0.04)
    # breech block (raised with the barrel) and shell hoist at the back
    with unit.pitched(p, TRUNNION, ELEV):
        p.box((0, GY, 0.2), (2.6, 2.0, 1.6), "trim", bevel=0.08)
        p.box((0, GY + 1.03, 0.2), (2.0, 0.06, 1.2), "hazard")
    p.box((2.4, 5.3, 1.4), (1.0, 1.8, 1.4), "trim", bevel=0.05)
    p.box((2.4, 5.0, 0.68), (0.6, 0.24, 0.05), "power")
    cable(p, [(2.4, 6.2, 1.0), (1.8, 6.0, 0.6), (1.2, 5.6, 0.3)], r=0.12, kind="steel")
    louver(p, (0, 3.0, 4.82), (1, 0, 0), (0, 0, 1), 1.8, 0.8, slats=3)
    # the huge fat barrel, raised: jacket rings, the glowing breech band, a heavy lip
    with unit.pitched(p, TRUNNION, ELEV):
        p.ocyl((0, GY, -1.8), (0, 0, -1), 1.1, 9.9, 18, "steel")
        p.ocyl((0, GY, -3.0), (0, 0, -1), 1.22, 0.4, 18, "weapon")
        for z in (-2.2, -5.4, -8.6):
            p.ocyl((0, GY, z), (0, 0, -1), 1.28, 0.55, 18, "dark")
        p.ocyl((0, GY, -11.8), (0, 0, -1), 1.42, 0.85, 18, "dark")
        p.ocyl((0, GY, -12.66), (0, 0, -1), 0.7, 0.03, 14, "dark")


def details_turret(p):
    band_round(p, 3.2, 4.0, cx=0.0, cz=1.0)
    ring(p, (0, 4.45, 1.6), UP, 0.5)
    with unit.pitched(p, TRUNNION, ELEV):
        rivets(p, (-1.1, GY + 1.01, -0.45), (1.1, GY + 1.01, -0.45), 4, UP)
    for sx in (-1, 1):
        rivets(p, (sx * 2.08, 5.6, -2.6), (sx * 2.08, 5.6, 0.2), 4, (sx, 0, 0))
    with unit.pitched(p, TRUNNION, ELEV):
        for z in (-6.9, -10.2):
            ring(p, (0, GY, z), (0, 0, -1), 1.12, width=0.05, segments=16)


unit.run(__file__, "chs_cataclysm", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, unit.lifted(build_turret, LIFT), unit.lifted(details_turret, LIFT))],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-44, 40, -54), (0, 12.0, -3.0), 50),
                   ("80", (0, 66, 9), (0, 8, -3.0), 50),
                   ("close", (-18, 26, -22), (0, 17.0, -4.0), 38)])
