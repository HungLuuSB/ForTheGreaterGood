"""Warlord (Chaos Commander, footprint 1): the walking battle mech (M-31).
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_warlord/build.py

The user (2026-10-23): a hunched, heavier walker, BAR-commander silhouette
but an original design, clearly the most imposing ground unit (about 1.5x a
Lancer's height). Exposed pistons and hydraulics on the legs, slab and
reactive armor, amber eye slits, twin exhaust stacks, a crane-like claw arm
with the build emitter (`nano`, power) on the left, a short heavy gun on the
right (`muzzle`, weapon), and a banner mast with the team banner on its
back. Rigged as a walker on the blockout's pivots (rig.md 10). The tracked
design is kept in tracked/. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

FWD = (0, 0, -1)
X = (1, 0, 0)
TILT = math.radians(12)  # the torso leans forward


def lean(y, z, y0=2.8, z0=0.0):
    """A torso point (y, z) leaned forward by TILT about (y0, z0)."""
    dy, dz = y - y0, z - z0
    return (y0 + dy * math.cos(TILT) + dz * math.sin(TILT), z0 - dy * math.sin(TILT) + dz * math.cos(TILT))


def lean_profile(pts):
    return [tuple(reversed(lean(y, z))) for z, y in pts]  # prism_x takes (z, y)


def lp(x, y, z):
    ly, lz = lean(y, z)
    return (x, ly, lz)


def lean_dir(dy, dz):
    return (0, dy * math.cos(TILT) + dz * math.sin(TILT), -dy * math.sin(TILT) + dz * math.cos(TILT))


# ---------------------------------------------------------------- pelvis


def build_base(p):
    p.prism_x([(-0.75, 1.9), (0.9, 1.9), (0.95, 2.6), (0.7, 2.85), (-0.6, 2.85), (-0.85, 2.55)], -1.3, 1.3, "dark", bevel=0.05)
    p.cylinder("x", (0, 2.3, 0.1), 0.34, 2.8, 12, "steel")
    p.box((0, 2.35, -0.9), (1.6, 0.6, 0.18), "era", bevel=0.02)  # front slab
    p.cylinder("y", (0, 2.85, 0), 0.7, 0.12, 14, "steel")


def details_base(p):
    bolts(p, (-0.7, 2.6, -1.0), (0.7, 2.6, -1.0), 4, FWD)


# ---------------------------------------------------------------- torso


def build_torso(p):
    # leaning body: a slab chest over a heavy hump, reactive blocks on the front
    p.prism_x(lean_profile([(-1.15, 2.85), (1.0, 2.85), (1.15, 3.7), (0.95, 4.35), (-0.9, 4.35), (-1.25, 3.7)]),
              -1.45, 1.45, "trim", bevel=0.05)
    n = lean_dir(0.25, -1)
    for sx in (-1, 0, 1):
        for y in (3.2, 3.75):
            p.obox(lp(sx * 0.82, y, -1.33), X, n, 0.7, 0.45, 0.22, "era", bevel=0.02)
    p.obox(lp(0, 2.95, -1.22), X, n, 1.5, 0.16, 0.04, "power")  # core slit
    for sx in (-1, 1):
        p.obox(lp(sx * 1.3, 3.45, -1.2), lean_dir(1, 0.25), n, 0.7, 0.08, 0.04, "light")  # chest edge strips
    p.obox(lp(0, 4.45, 1.38), X, lean_dir(0, 1), 1.6, 0.4, 0.04, "power")  # reactor vent at the back
    # the hump: reactor housing with a team plate, exhaust stacks with hot rings
    p.prism_x(lean_profile([(-0.3, 4.2), (1.3, 4.2), (1.2, 4.95), (0.2, 5.0), (-0.25, 4.7)]), -1.2, 1.2, "dark", bevel=0.05)
    p.obox(lp(0, 5.0, 0.7), X, lean_dir(1, 0), 1.3, 0.8, 0.04, "team")
    for sx in (-1, 1):
        b = lp(sx * 0.8, 4.6, 1.2)
        p.cylinder("y", (b[0], b[1] + 0.7, b[2] + 0.1), 0.24, 1.6, 10, "steel")
        p.cylinder("y", (b[0], b[1] + 1.52, b[2] + 0.1), 0.27, 0.08, 10, "power")
        p.cylinder("y", (b[0], b[1] + 1.25, b[2] + 0.1), 0.28, 0.1, 10, "dark")
    # banner mast with the team banner, a beacon on top
    m = lp(1.25, 4.6, 1.15)
    p.cylinder("y", (m[0], m[1] + 1.4, m[2]), 0.07, 2.8, 6, "steel")
    p.box((m[0], m[1] + 2.25, m[2] + 0.55), (0.04, 1.3, 1.0), "team")
    p.box((m[0], m[1] + 2.88, m[2] + 0.55), (0.05, 0.06, 1.05), "dark")
    p.box((m[0], m[1] + 2.85, m[2]), (0.14, 0.12, 0.14), "light")
    # shoulders: heavy slabs, a team plate on the right one, piping
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 1.5, sx * 2.8))
        p.prism_x(lean_profile([(-1.05, 3.45), (0.95, 3.45), (0.95, 4.35), (0.65, 4.6), (-0.8, 4.6), (-1.05, 4.3)]),
                  x0, x1, "dark", bevel=0.06)
        p.obox(lp(sx * 2.15, 4.08, -1.08), X, lean_dir(0, -1), 1.1, 0.45, 0.2, "era", bevel=0.02)
        p.box((sx * 2.81, 3.95, -0.1), (0.04, 0.12, 1.2), "light")
    p.obox(lp(2.15, 4.62, -0.1), X, lean_dir(1, 0), 0.9, 1.2, 0.04, "team")
    p.obox(lp(-1.3, 3.2, 0.8), lean_dir(0, 1), X, 1.3, 0.16, 0.16, "steel")  # pipe


def details_torso(p):
    for sx in (-1, 1):
        bolts(p, lp(sx * 1.6, 4.62, -0.6), lp(sx * 2.6, 4.62, -0.6), 4, lean_dir(1, 0))
    seam(p, lp(-1.2, 3.5, -1.2), lp(1.2, 3.5, -1.2), lean_dir(0.25, -1))


# ---------------------------------------------------------------- head


def build_head(p):
    p.cylinder("z", (0, 4.0, -1.05), 0.35, 0.4, 10, "steel")
    p.prism_y([(-0.5, -1.95), (0.5, -1.95), (0.55, -1.55), (0.45, -1.05), (-0.45, -1.05), (-0.55, -1.55)],
              3.75, 4.45, "dark", bevel=0.04, top_scale=0.82)
    for sx in (-1, 1):
        p.obox((sx * 0.24, 4.15, -1.96), (sx * 1, 0, 0.15), FWD, 0.36, 0.11, 0.04, "light")  # eye slits
        p.box((sx * 0.56, 4.0, -1.5), (0.04, 0.4, 0.5), "era")
    p.box((0, 4.47, -1.5), (0.6, 0.06, 0.5), "trim")
    p.box((0, 3.8, -1.98), (0.6, 0.2, 0.04), "grille")  # jaw vent


def details_head(p):
    seam(p, (-0.45, 4.3, -1.92), (0.45, 4.3, -1.92), FWD)


# ---------------------------------------------------------------- arms


def upper_arm(p, sx):
    x = sx * 2.25
    p.cylinder("x", (x, 3.9, -0.1), 0.4, 0.7, 12, "steel")
    p.box((x, 3.2, -0.2), (0.62, 1.2, 0.72), "trim", bevel=0.04)
    p.cylinder("y", (x + sx * 0.38, 3.2, 0.1), 0.08, 1.1, 6, "steel")  # exposed piston
    p.cylinder("x", (x, 2.55, -0.2), 0.3, 0.8, 10, "steel")


def build_armL(p):
    upper_arm(p, -1)


def build_armR(p):
    upper_arm(p, 1)


def details_arm(sx):
    def d(p):
        bolts(p, (sx * 2.57, 2.9, -0.5), (sx * 2.57, 3.5, -0.5), 3, (sx, 0, 0))
    return d


def build_nano(p):
    x = -2.25
    # crane boom: lattice-ish box beam with a piston, a claw and the emitter
    p.box((x, 2.45, -1.05), (0.42, 0.42, 2.3), "dark", bevel=0.03)
    p.box((x, 2.68, -1.05), (0.46, 0.06, 2.0), "steel")
    p.cylinder("z", (x, 2.85, -0.7), 0.1, 1.5, 8, "steel")
    p.cylinder("z", (x, 2.85, -0.35), 0.15, 0.6, 8, "trim")
    p.box((x, 2.45, -0.4), (0.44, 0.1, 0.5), "team")
    for sx in (-1, 1):  # claw fingers round the emitter
        p.obox((x + sx * 0.24, 2.4, -2.35), (0, 0, -1), (sx * 0.95, 0, -0.3), 0.6, 0.6, 0.12, "steel")
        p.obox((x + sx * 0.18, 2.4, -2.68), (-sx * 0.5, 0, -1), (sx, 0, 0), 0.32, 0.5, 0.1, "trim")
    p.ocyl((x, 2.45, -2.2), FWD, 0.24, 0.3, 10, "dark")
    p.ocyl((x, 2.45, -2.5), FWD, 0.17, 0.12, 10, "power")  # emitter


def details_nano(p):
    bolts(p, (-2.47, 2.45, -0.5), (-2.47, 2.45, -1.9), 5, (-1, 0, 0))


def build_forearmR(p):
    x = 2.35
    p.box((x, 2.45, -0.75), (1.05, 0.95, 1.7), "dark", bevel=0.05)
    p.box((x + 0.53, 2.5, -0.75), (0.04, 0.5, 1.0), "era")
    p.cylinder("z", (x, 2.4, -1.95), 0.32, 0.9, 12, "steel")
    p.cylinder("z", (x, 2.4, -2.1), 0.36, 0.3, 12, "dark")  # muzzle brake
    p.cylinder("z", (x, 2.4, -2.42), 0.24, 0.06, 12, "weapon")
    p.box((x, 2.95, -1.66), (0.25, 0.08, 0.04), "weapon")
    p.box((x + 0.54, 2.75, -1.3), (0.03, 0.1, 0.5), "weapon")
    p.cylinder("x", (x - 0.55, 2.3, -0.55), 0.28, 0.2, 10, "steel")  # ammo drum
    p.box((x, 2.3, 0.1), (0.7, 0.4, 0.06), "grille")


def details_forearmR(p):
    bolts(p, (2.88, 2.2, -1.4), (2.88, 2.2, -0.2), 4, X)


# ---------------------------------------------------------------- legs


def leg_specs(sx):
    n = "L" if sx < 0 else "R"
    x = sx * 1.6

    def hip(p):
        p.cylinder("x", (sx * 1.55, 2.3, 0.1), 0.4, 0.7, 12, "steel")
        p.box((sx * 1.95, 2.3, 0.1), (0.12, 0.9, 1.0), "era", bevel=0.02)

    def thigh(p):
        # angled back, a thick slab with an exposed piston down the outside
        p.obox((x, 1.65, -0.15), (0, 0.97, 0.26), X, 1.15, 0.9, 0.8, "dark", bevel=0.05)
        p.cylinder("x", (x, 1.15, -0.35), 0.33, 1.0, 12, "steel")
        p.cylinder("y", (x + sx * 0.48, 1.55, 0.15), 0.1, 1.3, 8, "steel")
        p.cylinder("y", (x + sx * 0.48, 1.9, 0.15), 0.14, 0.5, 8, "trim")
        p.box((x + sx * 0.42, 1.95, -0.3), (0.03, 0.4, 0.06), "light")

    def shin(p):
        p.box((x, 0.8, -0.05), (0.95, 0.9, 1.0), "trim", bevel=0.05)
        p.obox((x, 0.85, -0.6), X, (0, 0.3, -1), 0.8, 0.7, 0.18, "era", bevel=0.02)
        p.cylinder("y", (x, 0.85, 0.62), 0.09, 0.9, 8, "steel")
        for s2 in (-1, 1):
            p.box((x + s2 * 0.49, 0.8, -0.2), (0.03, 0.5, 0.08), "light")
        p.cylinder("y", (x, 1.05, 0.62), 0.13, 0.4, 8, "trim")

    def foot(p):
        p.prism_x([(-1.2, 0.0), (0.75, 0.0), (0.8, 0.25), (0.45, 0.4), (-0.75, 0.42), (-1.15, 0.2)], x - 0.65, x + 0.65, "dark", bevel=0.04)
        for dx in (-0.4, 0.0, 0.4):  # splayed toes
            p.obox((x + dx * 1.2, 0.12, -1.3), (dx * 0.6, 0, -1), UP, 0.4, 0.28, 0.24, "steel")
        p.cylinder("x", (x, 0.38, 0), 0.26, 0.8, 10, "steel")

    def det_shin(p):
        bolts(p, (x - 0.3, 1.18, -0.6), (x + 0.3, 1.18, -0.6), 3, (0, 0.3, -1))

    none = lambda p: None  # noqa: E731
    return [
        unit.PieceSpec(f"hip{n}", "base", (sx * 1.4, 2.3, 0.1), hip, none),
        unit.PieceSpec(f"thigh{n}", f"hip{n}", (x, 2.15, 0.1), thigh, none),
        unit.PieceSpec(f"shin{n}", f"thigh{n}", (x, 1.15, -0.35), shin, det_shin),
        unit.PieceSpec(f"foot{n}", f"shin{n}", (x, 0.35, 0.0), foot, none),
    ]


unit.run(__file__, "chs_warlord", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", (0.0, 2.8, 0.0), build_torso, details_torso),
                 unit.PieceSpec("head", "torso", (0.0, 4.0, -1.0), build_head, details_head),
                 unit.PieceSpec("armL", "torso", (-2.2, 3.9, -0.1), build_armL, details_arm(-1)),
                 unit.PieceSpec("nano", "armL", (-2.25, 2.5, 0.0), build_nano, details_nano),
                 unit.PieceSpec("armR", "torso", (2.25, 3.9, -0.1), build_armR, details_arm(1)),
                 unit.PieceSpec("forearmR", "armR", (2.3, 2.7, -0.2), build_forearmR, details_forearmR)]
         + leg_specs(-1) + leg_specs(1),
         attachments={"muzzle": {"parent": "forearmR", "at": [2.35, 2.4, -2.47]}},
         budget=6000,
         previews=[("35", (-11, 9, -13), (0, 2.9, 0), 50),
                   ("side", (14, 3.5, 0), (0, 2.9, 0), 50),
                   ("80", (0, 22, 3), (0, 2.8, 0), 50),
                   ("close", (-5.0, 5.0, -6.5), (0, 3.6, -0.5), 35)])
