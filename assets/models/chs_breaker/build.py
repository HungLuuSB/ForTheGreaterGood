"""Breaker (Chaos coastal battery, T2 structure, footprint 3): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_breaker/build.py

F18 (the user's beta feedback 2026-10-26, "turret should stand high,
proud, tower above others"): the approved turret stands LIFT studs higher
on a lattice gun tower over the platform: four splayed legs, two tiers of
X bracing on every face, an ammo hoist trunk, a railed top deck with team
plates and amber corner lamps, a ladder (top ~24 studs, the F18
blockout). First built from its blockout, at the size scale (S-104:
footprint 3): bigger and more elaborate than the T1 turrets, not a
rescale. Big shapes first: a dark pad, an open gun platform (a thin deck on
visible legs and girders, the gaps showing) round a concrete pedestal,
five reactive blocks hung on its sea face with amber strips, two big team
plates on the rear deck, grated walkways, a rail along the back, amber
beacons on the front corners (the blockout's lights) and a crate stack.
Everything on the deck stays under the long gun's sweep. The `turret`
(yaw, the def's piece; pivot as the blockout): a rounded drum with a
domed roof and a team plate, a leaning slab shield, an amber sensor box,
a twin missile box on a side bracket (radome caps), a shell box and a lamp
mast, and one very long gun with jacket rings, a ready ring (`weapon`) and
a muzzle brake (`muzzle` at its mouth). Chaos reads rugged and light
(M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from towers import antenna, band_round, clamped_cable, louver  # noqa: E402
from mech import cable, hazard, octagon, rivets  # noqa: E402
from unit import UP, ring  # noqa: E402

LIFT = 20.0 - 3.6  # F18: the gun at the blockout's 20.0
RING = 2.0 + LIFT  # 18.4, the turret ring on the tower's top deck
TURRET_PIVOT = (0.0, RING, 1.0)
GY = 3.6  # gun axis height before the lift (the turret is built there, then lifted)
MUZZLE = (0.0, GY + LIFT, -15.1)
LEG0, LEG1 = 5.8, 4.4  # the tower legs' offset from the ring's axis at the deck and at the top
D0, D1 = 1.5, 2.0  # deck plate bottom and top


def beam(p, a, b, w, kind):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind)


def build_tower(p):
    """F18: the lattice gun tower from the platform deck up to the ring."""
    top = RING - 0.6
    def corner(sx, sz, y):
        f = LEG0 + (LEG1 - LEG0) * (y - D1) / (top - D1)
        return (sx * f, y, 1.0 + sz * f)
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(p, corner(sx, sz, D1), corner(sx, sz, top), 1.1, "dark")
            p.box(corner(sx, sz, D1 + 0.3), (1.8, 0.6, 1.8), "trim", bevel=0.05)  # foot plates
    faces = [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]
    for y0, y1 in ((D1 + 0.6, 10.2), (10.2, top - 0.2)):
        for a, b in faces:
            beam(p, corner(*a, y0), corner(*b, y1), 0.32, "steel")
            beam(p, corner(*b, y0), corner(*a, y1), 0.32, "steel")
            beam(p, corner(*a, y1), corner(*b, y1), 0.4, "dark")
    # the ammo hoist trunk, its lit band and hatch
    p.cylinder("y", (0, (D1 + top) / 2, 1.0), 2.1, top - D1, 16, "paint", bevel=0.05)
    p.cylinder("y", (0, 10.2, 1.0), 2.25, 0.5, 16, "trim")
    p.box((0, 6.0, -1.12), (1.2, 1.6, 0.05), "dark")
    p.box((0, 6.9, -1.13), (1.2, 0.12, 0.05), "power")
    # the top deck: a plate, team plates on its sides, rails, amber corner lamps
    p.box((0, top + 0.3, 1.0), (13.6, 0.6, 13.6), "paint", bevel=0.06)
    for sx in (-1, 1):
        p.box((sx * 6.83, top + 0.3, 1.0), (0.06, 0.45, 5.0), "team", bevel=0.01)
        p.box((sx * 6.6, RING + 0.65, 1.0), (0.12, 0.12, 13.0), "steel")
    p.box((0, RING + 0.65, 7.6), (13.0, 0.12, 0.12), "steel")
    for x in (-6.6, -2.2, 2.2, 6.6):
        p.box((x, RING + 0.32, 7.6), (0.1, 0.65, 0.1), "steel")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 6.6, RING + 0.3, 1.0 + sz * 6.6), (0.5, 0.6, 0.5), "light")
    # a ladder up the back of the trunk
    for x in (-0.35, 0.35):
        p.box((x, (D1 + top) / 2, 3.25), (0.08, top - D1, 0.08), "steel")
    for k in range(int((top - D1) / 0.6)):
        p.box((0, D1 + 0.4 + k * 0.6, 3.25), (0.7, 0.06, 0.06), "steel")
    p.cylinder("y", (0, RING - 0.15, 1.0), 4.3, 0.3, 24, "dark")
    p.cylinder("y", (0, RING - 0.32, 1.0), 4.45, 0.06, 24, "power")


def build_base(p):
    p.prism_y(octagon(11.7, 1.6), 0.0, 0.4, "dark", bevel=0.08, top_scale=0.99)
    hazard(p, (0, 0.42, -11.25), (1, 0, 0), UP, 10.0, 0.45, stripes=18)
    p.box((7.8, 0.42, -8.6), (2.8, 0.04, 1.8), "steel", bevel=0.01)  # welded patch
    # concrete pedestal under the ring, through the deck
    p.cylinder("y", (0, 1.1, 1.0), 4.4, 1.9, 24, "trim", bevel=0.06)
    # open frame: legs, girders, a thin deck plate
    for x in (-9.0, -4.5, 4.5, 9.0):
        for z in (-5.2, 0.6, 5.0, 9.2):
            p.box((x, 0.95, z), (0.5, 1.1, 0.5), "dark")
    for z in (-5.2, 0.6, 5.0, 9.2):
        p.box((0, 1.3, z), (19.0, 0.4, 0.28), "steel")
    for x in (-9.0, -4.5, 4.5, 9.0):
        p.box((x, 1.3, 2.0), (0.28, 0.4, 15.4), "steel")
    p.box((0, (D0 + D1) / 2, 2.0), (20.0, D1 - D0, 16.0), "paint", bevel=0.05)
    # five reactive blocks hung on the sea face, amber strips
    for x in (-8.0, -4.0, 0.0, 4.0, 8.0):
        p.obox((x, 1.15, -6.35), (1, 0, 0), (0, 0.3, -1), 3.6, 1.5, 0.6, "era", bevel=0.05)
        p.obox((x, 1.25, -6.68), (1, 0, 0), (0, 0.3, -1), 2.4, 0.14, 0.04, "light")
    # two big team plates on the rear deck, grated walkways forward
    for sx in (-1, 1):
        p.box((sx * 7.0, D1 + 0.03, 6.2), (4.6, 0.06, 4.6), "team", bevel=0.015)
        p.box((sx * 7.6, D1 + 0.02, -2.4), (3.4, 0.03, 5.6), "grille")
    # rail along the back, amber beacons on the front corners
    for x in (-9.6, -4.8, 0.0, 4.8, 9.6):
        p.box((x, D1 + 0.4, 9.8), (0.12, 0.8, 0.12), "steel")
    p.box((0, D1 + 0.78, 9.8), (19.4, 0.1, 0.1), "steel")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 9.5, D1 + 0.3, -5.5), 0.12, 0.6, 6, "steel")
        p.box((sx * 9.5, D1 + 0.7, -5.5), (0.5, 0.36, 0.5), "light")
    # crate stack and a fuel drum (back, between the team plates)
    for dx, dy in ((0.0, 0.0), (1.9, 0.0), (0.9, 0.7)):
        p.box((-1.5 + dx, D1 + 0.35 + dy, 8.6), (1.7, 0.7, 1.4), "trim", bevel=0.04)
    p.box((-1.5, D1 + 0.35, 7.88), (0.9, 0.2, 0.04), "power")
    p.cylinder("y", (3.4, D1 + 0.4, 8.8), 0.55, 0.8, 12, "paint")
    p.box((3.4, D1 + 0.81, 8.8), (0.7, 0.03, 0.2), "hazard")
    clamped_cable(p, [(3.0, D1 + 0.5, 8.4), (2.4, D1 + 0.15, 7.0), (1.6, D1 + 0.1, 5.4)], r=0.1)
    # side vents into the pedestal room
    for sx in (-1, 1):
        louver(p, (sx * 10.02, 1.75, 2.0), (0, 0, 1), (sx, 0, 0), 4.0, 0.4, slats=2)
    build_tower(p)


def details_base(p):
    for sx in (-1, 1):
        rivets(p, (sx * 9.6, D1 + 0.01, -5.6), (sx * 9.6, D1 + 0.01, 9.4), 12, UP)
    rivets(p, (-9.4, D1 + 0.01, -5.7), (9.4, D1 + 0.01, -5.7), 16, UP)
    band_round(p, 0.8, 4.4, segments=16, cz=1.0)


def build_turret(p):
    p.cylinder("y", (0, 2.95, 1.0), 3.6, 1.9, 20, "paint", radius2=3.4, bevel=0.05)
    p.cylinder("y", (0, 4.2, 1.0), 3.4, 0.6, 20, "paint", radius2=2.6, bevel=0.04)
    p.cylinder("y", (0, 2.08, 1.0), 3.7, 0.16, 20, "power")
    p.box((0, 4.52, 1.8), (3.2, 0.05, 2.4), "team", bevel=0.015)
    # leaning slab shield round the gun
    p.obox((0, 3.3, -2.5), (1, 0, 0), (0, 0.35, -1), 4.4, 2.4, 0.4, "era", bevel=0.06)
    p.obox((0, 3.0, -2.45), (1, 0, 0), (0, 0.35, -1), 1.8, 1.3, 0.6, "dark", bevel=0.04)
    # amber sensor box (front left), lamp mast
    p.box((-2.3, 4.15, -1.7), (0.9, 0.7, 0.9), "trim", bevel=0.04)
    p.box((-2.3, 4.15, -2.17), (0.6, 0.3, 0.05), "light")
    p.cylinder("y", (-1.6, 5.2, 3.0), 0.07, 1.6, 6, "steel")
    p.box((-1.6, 6.05, 3.0), (0.5, 0.3, 0.4), "dark")
    p.box((-1.6, 6.05, 2.79), (0.36, 0.18, 0.04), "light")
    # twin missile box on a bracket (right side), radome caps forward
    p.box((3.2, 3.6, -0.3), (1.0, 0.5, 1.2), "dark", bevel=0.03)
    p.obox((3.7, 4.3, -0.5), (1, 0, 0), (0, 0.15, -1), 1.7, 1.4, 3.2, "trim", bevel=0.06)
    for dx in (-0.4, 0.4):
        p.ocyl((3.7 + dx, 4.54, -2.06), (0, 0.15, -1), 0.32, 0.1, 10, "radome")
    p.obox((4.56, 4.3, -0.5), (0, 0, 1), (1, 0, 0), 2.2, 0.16, 0.04, "light")
    # shell box at the back with a feed belt
    p.box((-2.2, 3.4, 3.6), (1.4, 1.3, 1.4), "trim", bevel=0.05)
    p.box((-2.2, 4.07, 3.6), (1.0, 0.03, 0.3), "hazard")
    cable(p, [(-1.6, 3.9, 3.0), (-1.0, 4.3, 1.6), (-0.6, 4.0, 0.2)], r=0.12, kind="dark")
    antenna(p, (2.0, 4.5, 3.4), 1.8)
    louver(p, (1.2, 3.0, 4.52), (1, 0, 0), (0, 0, 1), 1.6, 0.8, slats=3)
    # one very long gun: breech collar, jacket rings, ready ring, muzzle brake
    p.ocyl((0, GY, -2.0), (0, 0, -1), 0.95, 1.4, 16, "dark")
    p.ocyl((0, GY, -2.0), (0, 0, -1), 0.58, 12.4, 16, "steel")
    for z in (-5.6, -9.2):
        p.ocyl((0, GY, z), (0, 0, -1), 0.72, 0.5, 16, "dark")
    p.ocyl((0, GY, -12.6), (0, 0, -1), 0.64, 0.16, 16, "weapon")
    p.ocyl((0, GY, -14.0), (0, 0, -1), 0.78, 1.05, 16, "dark")
    for z in (-14.25, -14.75):
        p.box((0, GY, z), (1.9, 0.5, 0.22), "dark")
    p.ocyl((0, GY, -15.06), (0, 0, -1), 0.36, 0.03, 12, "dark")


def details_turret(p):
    band_round(p, 3.2, 3.55, cx=0.0, cz=1.0)
    ring(p, (0, 4.55, 1.8), UP, 0.5)
    rivets(p, (-1.9, 4.3, -2.86), (1.9, 4.3, -2.86), 6, (0, 0.35, -1))
    for z in (-3.6, -7.4, -11.0):
        ring(p, (0, GY, z), (0, 0, -1), 0.6, width=0.04, segments=14)


unit.run(__file__, "chs_breaker", "chaos", footprint=3,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, unit.lifted(build_turret, LIFT), unit.lifted(details_turret, LIFT))],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}},
         budget=6000,
         previews=[("35", (-44, 40, -54), (0, 12.0, -3.0), 50),
                   ("80", (0, 66, 9), (0, 8, -3.0), 50),
                   ("close", (-18, 26, -22), (0, 17.0, -4.0), 38)])
