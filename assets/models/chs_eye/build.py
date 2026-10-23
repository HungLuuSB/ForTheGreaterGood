"""Eye (Chaos radar tower, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_eye/build.py

Redesigned in the size-scale style (S-104, M-26: footprint 1, 8 x 8 studs,
about 12 tall: thin and tall). Big shapes first: a patched skid slab with
large team plates and hazard striping, a generator box with a team roof
and a hot vent at the foot, an open lattice mast on four thick splayed
legs with heavy foot pads, braced rings and X bracing on every side, guy
cables to anchor blocks, amber beacons half way up; a grated platform with
rail posts, the amber "eye" sensor hung under it; and on a bearing the
client-turned `radar` (blockout visual piece): a flat phased-array panel
tilted back 15 degrees, never a dish, its face unlit with an amber edge and
cell lines, welded patches, a big team plate on its back and a hung
counterweight box. Chaos reads rugged, light and open (M-14). Writes
export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

RADAR_PIVOT = (0.0, 9.2, 0.0)
TILT = math.radians(15)
N = (0.0, math.sin(TILT), -math.cos(TILT))
V = (0.0, math.cos(TILT), math.sin(TILT))
U = (1.0, 0.0, 0.0)
PANEL = (0.0, 10.8, 0.0)
FOOT, TOP = 2.9, 0.95  # leg spread at the skid and at the top
Y0, Y1 = 0.5, 8.6
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]


def leg_at(sx, sz, y):
    t = (y - Y0) / (Y1 - Y0)
    r = FOOT + (TOP - FOOT) * t
    return (sx * r, y, sz * r)


def beam(p, a, b, w, kind, bevel=0.0):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)) if abs(n.y) < 0.9 else lib.vec((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(n), w, w, (b - a).length, kind, bevel=bevel)


def build_base(p):
    p.prism_y(octagon(3.85, 0.5), 0.0, 0.5, "dark", bevel=0.06, top_scale=0.985)
    for sz in (-1, 1):  # big team plates on the skid, front and back
        p.box((0, 0.53, sz * 2.9), (4.2, 0.05, 1.3), "team", bevel=0.012)
    hazard(p, (-2.9, 0.53, 0), (0, 0, 1), UP, 3.6, 0.5, stripes=8)
    p.box((2.4, 0.53, -0.4), (1.6, 0.04, 2.0), "steel", bevel=0.01)  # welded patch
    for sx in (-1, 1):
        p.box((sx * 3.82, 0.28, 0), (0.05, 0.14, 4.2), "light")
    # generator box at the foot (back right) with a team roof and a hot vent
    p.prism_y(rect(1.9, 1.7, 0.9, 0.75), 0.5, 1.9, "paint", bevel=0.06)
    p.box((1.9, 1.94, 1.7), (1.9, 0.05, 1.6), "team", bevel=0.012)
    p.box((1.9, 1.2, 0.93), (1.2, 0.35, 0.05), "power")
    p.ocyl((1.4, 1.9, 2.1), UP, 0.22, 0.9, 10, "steel")
    p.cylinder("y", (1.4, 2.82, 2.1), 0.2, 0.06, 10, "power")
    # the mast: thick splayed legs on foot pads, braced rings, X bracing
    for sx, sz in CORNERS:
        beam(p, leg_at(sx, sz, Y0), leg_at(sx, sz, Y1), 0.42, "paint", bevel=0.04)
        p.box((sx * FOOT, 0.7, sz * FOOT), (0.9, 0.4, 0.9), "trim", bevel=0.04)
    for y in (2.9, 5.2, 7.4):
        for i, (sx, sz) in enumerate(CORNERS):
            nx, nz = CORNERS[(i + 1) % 4]
            beam(p, leg_at(sx, sz, y), leg_at(nx, nz, y), 0.2, "steel")
    for i, (sx, sz) in enumerate(CORNERS):
        nx, nz = CORNERS[(i + 1) % 4]
        for ya, yb in ((Y0 + 0.4, 2.9), (2.9, 5.2)):
            beam(p, leg_at(sx, sz, ya), leg_at(nx, nz, yb), 0.12, "steel")
            beam(p, leg_at(nx, nz, ya), leg_at(sx, sz, yb), 0.12, "steel")
    for sx, sz in CORNERS:  # amber beacons half way up the legs
        x, y, z = leg_at(sx, sz, 5.2)
        p.box((x, y + 0.25, z), (0.5, 0.32, 0.5), "light")
    # guy cables from the upper ring to the skid's anchor blocks
    for sx, sz in ((1, -1), (-1, 1)):
        p.box((sx * 3.4, 0.7, sz * 3.4), (0.5, 0.4, 0.5), "trim")
        cable(p, [leg_at(sx, sz, 7.4), (sx * 3.4, 0.9, sz * 3.4)], r=0.05, kind="steel")
    # grated platform, rail posts, the bearing
    p.box((0, 8.75, 0), (2.6, 0.3, 2.6), "trim", bevel=0.04)
    p.box((0, 8.91, 0), (2.3, 0.03, 2.3), "grille")
    for sx, sz in CORNERS:
        p.box((sx * 1.2, 9.2, sz * 1.2), (0.1, 0.6, 0.1), "steel")
        p.box((sx * 1.2, 9.54, sz * 1.2), (0.24, 0.14, 0.24), "light")
    p.cylinder("y", (0, 9.05, 0), 0.65, 0.3, 12, "steel")
    # the eye: a housing hung under the platform, its amber lens forward
    p.box((0, 8.1, -0.7), (0.35, 0.9, 0.35), "steel")
    p.ocyl((0, 7.4, -0.6), (0, 0, -1), 0.75, 0.7, 16, "dark")
    p.ocyl((0, 7.4, -1.3), (0, 0, -1), 0.55, 0.06, 16, "light")


def details_base(p):
    rivets(p, (-3.0, 0.501, -3.6), (3.0, 0.501, -3.6), 8, UP)
    rivets(p, (1.65, 0.541, -1.3), (3.15, 0.541, -1.3), 4, UP)
    ring(p, (0, 7.4, -1.37), (0, 0, -1), 0.65)


def at(a, b, n=0.0):
    return tuple(PANEL[k] + U[k] * a + V[k] * b + N[k] * n for k in range(3))


def build_radar(p):
    p.cylinder("y", (0, 9.4, 0), 0.45, 0.45, 12, "trim")
    p.obox(at(0, -0.8, -0.42), U, N, 0.4, 1.7, 0.4, "steel")
    p.obox(PANEL, U, N, 5.8, 2.9, 0.34, "paint", bevel=0.04)
    p.obox(at(0, 0, 0.18), U, N, 5.3, 2.45, 0.03, "dark")
    for b in (-1.2, 1.2):  # amber edge
        p.obox(at(0, b, 0.2), U, N, 5.3, 0.09, 0.02, "light")
    for a in (-2.61, 2.61):
        p.obox(at(a, 0, 0.2), U, N, 0.09, 2.3, 0.02, "light")
    for a in (-1.3, 0.0, 1.3):  # three cell lines and one row
        p.obox(at(a, 0, 0.2), U, N, 0.04, 2.3, 0.02, "light")
    p.obox(at(0, 0.0, 0.2), U, N, 5.2, 0.04, 0.02, "light")
    p.obox(at(-1.9, 0.6, 0.22), U, N, 1.0, 0.8, 0.03, "steel")  # welded patch over the face
    p.obox(at(0, 0.3, -0.19), U, N, 5.0, 1.6, 0.03, "team")
    p.obox(at(2.4, -1.0, -0.6), U, N, 1.0, 0.9, 0.7, "trim", bevel=0.04)  # counterweight
    cable(p, [at(2.4, -0.6, -0.3), at(1.2, -1.2, -0.35), at(0, -1.3, -0.4)], r=0.07, kind="steel")


def details_radar(p):
    bolts(p, at(-2.6, 1.35, 0.17), at(2.6, 1.35, 0.17), 10, N)


unit.run(__file__, "chs_eye", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("radar", "base", RADAR_PIVOT, build_radar, details_radar)],
         budget=6000,
         previews=[("35", (-24, 19, -28), (0, 6.0, 0), 50),
                   ("80", (0, 42, 6), (0, 5, 0), 50),
                   ("close", (-11, 14, -13), (0, 8.0, 0), 45)])
