"""Warden (Order deployable gun, T2 ground, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_warden/build.py

A long gun on a low fortress-like tracked hull. Pieces and pivots follow
the blockout (rig.md 4; poses in Blockouts/Pending/Registry.luau, M-19) so
the piece script deploys it unchanged: `spades` (one wide plate hinged at
the hull's back, hazard stripes on its front face, team plate on its back),
`shieldL` / `shieldR` (front shield wings hinged at the hull's front
corners, hazard stripes inside), `jacks` (four legs with pads beside the
tracks), `turret`, `barrel` with a big muzzle brake (BAR style, M-15; Order
reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

TURRET_PIVOT = (0.0, 2.1, 0.9)
BARREL_PIVOT = (0.0, 2.95, -1.7)
SPADES_PIVOT = (0.0, 0.8, 4.05)
JACKS_PIVOT = (-3.9, 1.525, -0.6)
WHEELS = (-2.7, -1.5, -0.3, 0.9, 2.1, 3.1)


def build_base(p):
    p.prism_x([(-3.6, 0.45), (3.5, 0.45), (3.8, 0.85), (3.8, 1.4), (-4.2, 1.4)], -2.1, 2.1, "trim", bevel=0.03)
    p.prism_x([(-4.45, 1.2), (3.8, 1.2), (3.8, 2.1), (-3.2, 2.1), (-4.45, 1.45)], -2.75, 2.75, "paint", bevel=0.05)
    for sx in (-1, 1):  # thick skirts, team strip, running strip
        x0, x1 = (3.15, 3.5) if sx > 0 else (-3.5, -3.15)
        p.prism_x([(-3.7, 0.6), (3.7, 0.6), (3.7, 1.8), (-3.4, 1.8), (-3.7, 1.4)], x0, x1, "paint", bevel=0.04)
        p.box((sx * 3.525, 1.5, 0.4), (0.05, 0.34, 3.4), "team", bevel=0.012)
        p.box((sx * 3.525, 1.72, 0.0), (0.05, 0.2, 6.6), "light")
        p.box((sx * 2.3, 1.55, -4.25), (0.55, 0.2, 0.12), "head")
        p.box((sx * 2.4, 1.6, 3.83), (0.5, 0.16, 0.06), "light")
    p.box((0, 1.25, -4.42), (3.2, 0.2, 0.08), "light")  # glacis light bar
    for sx in (-1, 1):
        p.box((sx * 2.2, 2.13, 1.0), (0.6, 0.05, 3.6), "team", bevel=0.012)
    p.box((0, 2.12, 3.1), (2.6, 0.05, 1.0), "grille")
    for z in (2.75, 3.1, 3.45):  # engine-deck exhaust slots
        p.box((0, 2.14, z), (2.4, 0.04, 0.2), "light")
    p.box((0, 1.1, 3.82), (2.6, 0.4, 0.05), "light")  # rear exhaust
    # tracks: a band round the sprocket and idler, road wheels
    outline = [(-3.4, 0.0), (3.5, 0.0)]
    outline += lib.outline_circle(3.5, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-3.6, 1.0)]
    outline += lib.outline_circle(-3.6, 0.6, 0.4, 90, 210, 5)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.15, 3.12) if sx > 0 else (-3.12, -2.15)
        p.band_x(outline, inner, x0, x1, "track")
        for z in WHEELS:
            p.cylinder("x", (sx * 2.63, 0.46, z), 0.4, 0.42, 12, "rubber", cap_kinds=("trim", "trim"))


def details_base(p):
    seam(p, (-2.7, 2.101, -1.2), (2.7, 2.101, -1.2), UP)
    bolts(p, (-2.6, 2.101, 3.6), (2.6, 2.101, 3.6), 8, UP)


def build_turret(p):
    p.prism_y([(-2.1, -1.3), (2.1, -1.3), (2.1, 3.1), (-2.1, 3.1)], 2.1, 3.6, "paint", bevel=0.06, top_scale=0.92)
    p.prism_x([(-2.5, 2.1), (-1.3, 2.1), (-1.3, 3.6), (-1.9, 3.6)], -2.0, 2.0, "paint", bevel=0.05)  # sloped front
    p.box((0, 3.63, 1.0), (3.2, 0.06, 3.0), "team", bevel=0.015)
    p.box((1.4, 3.8, -0.2), (0.6, 0.4, 0.6), "trim", bevel=0.03)  # sight
    p.box((1.4, 3.8, -0.52), (0.45, 0.18, 0.04), "light")
    p.cylinder("y", (-1.0, 3.66, 1.8), 0.32, 0.08, 10, "trim")
    for sx in (-1, 1):
        p.box((sx * 2.05, 3.0, 1.0), (0.05, 0.22, 3.6), "light")
        p.box((sx * 2.18, 2.8, 2.2), (0.3, 0.6, 1.2), "trim", bevel=0.03)
    p.box((0, 3.0, 3.12), (3.0, 0.2, 0.05), "light")  # turret rear light bar


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.box((0, y, -1.95), (1.1, 0.9, 0.7), "paint", bevel=0.06)  # mantlet
    p.cylinder("z", (0, y, -5.3), 0.3, 6.6, 16, "paint")
    for z in (-2.6, -4.5, -6.6):
        p.cylinder("z", (0, y, z), 0.33, 0.1, 16, "steel")
    p.cylinder("z", (0, y, -3.6), 0.38, 0.6, 16, "paint")  # evacuator
    p.box((0, y, -9.0), (0.9, 0.7, 0.75), "dark", bevel=0.05)  # muzzle brake
    for sx in (-1, 1):
        p.box((sx * 0.46, y, -9.0), (0.04, 0.4, 0.5), "steel")
    p.cylinder("z", (0, y, -8.45), 0.34, 0.12, 16, "weapon")
    p.box((0, y + 0.31, -6.0), (0.09, 0.05, 3.2), "weapon")


def build_spades(p):
    p.box((0, 2.4, 4.05), (5.8, 3.2, 0.35), "paint", bevel=0.05)
    p.box((0, 3.85, 4.05), (5.8, 0.3, 0.6), "steel", bevel=0.03)  # teeth bar (the plate's free edge)
    for i in range(5):
        p.box((-2.4 + i * 1.2, 4.05, 4.05), (0.5, 0.2, 0.5), "steel")
    p.box((0, 3.6, 4.24), (5.0, 0.24, 0.04), "light")  # warning strip along the free edge
    p.box((0, 2.5, 4.25), (3.6, 0.5, 0.05), "team", bevel=0.01)
    for i in range(4):  # hazard stripes on the front face
        p.box((-2.16 + i * 1.44, 1.975, 3.86), (0.72, 2.05, 0.04), "hazard")
    for sx in (-1, 1):  # hinge blocks
        p.box((sx * 2.4, 0.95, 4.05), (0.6, 0.4, 0.6), "dark")


def build_shield(sx):
    def build(p):
        x = sx * 3.85
        p.box((x, 2.0, -2.9), (0.3, 2.8, 3.2), "paint", bevel=0.04)
        p.box((x + sx * 0.18, 2.9, -2.9), (0.05, 0.5, 2.4), "team", bevel=0.01)
        for z in (-4.0, -2.9, -1.8):
            p.box((x - sx * 0.17, 1.35, z), (0.04, 1.3, 0.7), "hazard")
        p.cylinder("y", (x, 2.0, -4.5), 0.18, 2.8, 8, "steel")  # hinge
        p.box((x + sx * 0.18, 3.25, -2.9), (0.05, 0.14, 3.0), "light")  # wing edge light
    return build


def build_jacks(p):
    for x in (-3.9, 3.9):
        for z in (-0.6, 2.9):
            p.box((x, 1.525, z), (0.3, 0.95, 0.3), "dark")
            p.box((x, 0.975, z), (0.8, 0.15, 0.8), "steel", bevel=0.02)
            p.box((x, 2.05, z), (0.5, 0.2, 0.5), "trim")


def no_details(p):
    pass


unit.run(__file__, "ord_warden", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("spades", "base", SPADES_PIVOT, build_spades, no_details),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, no_details),
                 unit.PieceSpec("barrel", "turret", BARREL_PIVOT, build_barrel, no_details),
                 unit.PieceSpec("shieldL", "base", (-3.85, 2.0, -4.5), build_shield(-1), no_details),
                 unit.PieceSpec("shieldR", "base", (3.85, 2.0, -4.5), build_shield(1), no_details),
                 unit.PieceSpec("jacks", "base", JACKS_PIVOT, build_jacks, no_details)],
         attachments={"muzzle": {"parent": "barrel", "at": [0, 2.95, -9.4]}},
         team_pieces=["base", "spades", "turret", "shieldL", "shieldR"])
