"""Tideguard (Order amphibious tank, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_tideguard/build.py

New mesh from its blockout, at the T2 light size (size-scale.md: 9-10 x
6.5 x ~5, fits one cell). A sealed, smooth armored hull with a raked boat
bow and a splash board, sponsons over low tracks (`trackL` / `trackR`,
scroll), a large team plate on the bow deck, two waterjet housings at the
stern with glowing intakes, a snorkel with a cap light, headlights and
running strips; a compact sloped turret (`turret`, the def turns it) with a
team roof, a sight and a short gun with a muzzle ring (`muzzle`). Order
reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, hazard  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

TURRET = (0.0, 2.3, 0.9)
GUN_Y = 2.95
HL, TX, TW = 4.2, 2.75, 0.9  # track half length, track centre x, track width


def tracks(p):
    outline = [(-HL + 0.7, 0.0), (HL - 0.5, 0.0)]
    outline += lib.outline_circle(HL - 0.5, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-HL + 0.4, 1.0)]
    outline += lib.outline_circle(-HL + 0.4, 0.6, 0.4, 90, 210, 5)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (TX - TW / 2), sx * (TX + TW / 2)))
        with p.sub("trackL" if sx < 0 else "trackR", (sx * TX, 0.46, 0.0), "scroll", (1, 0, 0)):  # M-27
            p.band_x(outline, inner, x0, x1, "track")
            for i in range(5):
                z = -HL + 1.0 + i * (2 * HL - 2.0) / 4
                p.cylinder("x", (sx * TX, 0.46, z), 0.4, TW * 0.5, 10, "rubber", cap_kinds=("trim", "trim"))


def build_base(p):
    tracks(p)
    # sealed boat hull between the tracks, raked bow
    p.prism_x([(4.4, 0.5), (-3.2, 0.5), (-4.9, 1.45), (-5.15, 1.95), (-4.5, 2.15), (4.4, 2.15)], -2.25, 2.25, "trim", bevel=0.08)
    # sponsons over the tracks, smooth and sealed
    p.prism_x([(4.5, 1.35), (-3.7, 1.35), (-4.8, 1.9), (-4.3, 2.3), (4.5, 2.3)], -3.25, 3.25, "paint", bevel=0.1)
    p.obox((0, 2.0, -4.95), (1, 0, 0), (0, 0.55, -1.0), 4.2, 0.8, 0.1, "paint", bevel=0.03)  # splash board
    hazard(p, (0, 2.06, -4.97), (1, 0, 0), (0, 0.55, -1.0), 3.6, 0.3, stripes=8)
    p.box((0, 2.34, -2.6), (3.6, 0.05, 2.2), "team", bevel=0.015)
    for sx in (-1, 1):
        p.box((sx * 3.27, 1.85, 0.2), (0.04, 0.14, 6.6), "light")
        p.box((sx * 1.6, 1.75, -4.75), (0.6, 0.2, 0.08), "head")
        # waterjet housings at the stern with glowing intakes
        drum(p, (sx * 1.5, 1.25, 4.6), 0.55, 1.2, "paint", "trim", sides=14, axis="z")
        p.cylinder("z", (sx * 1.5, 1.25, 5.22), 0.38, 0.05, 14, "dark")
        p.cylinder("z", (sx * 1.5, 1.25, 5.25), 0.22, 0.04, 12, "light")
    # snorkel with a cap light
    p.cylinder("y", (-2.3, 3.2, 3.2), 0.18, 1.9, 10, "trim")
    p.box((-2.3, 4.25, 3.2), (0.5, 0.3, 0.5), "paint", bevel=0.03)
    p.box((-2.3, 4.45, 3.2), (0.22, 0.1, 0.22), "light")
    p.box((0, 2.33, 3.4), (2.6, 0.04, 1.0), "grille")


def details_base(p):
    seam(p, (-3.0, 2.301, -1.2), (3.0, 2.301, -1.2), UP)
    bolts(p, (-2.8, 2.301, 2.2), (2.8, 2.301, 2.2), 8, UP)


def build_turret(p):
    p.prism_y([(-1.4, -1.2), (1.4, -1.2), (1.8, -0.4), (1.8, 2.2), (-1.8, 2.2), (-1.8, -0.4)], 2.3, 3.5, "paint",
              bevel=0.08, top_scale=0.86)
    p.prism_x([(-1.8, 2.35), (-1.1, 2.35), (-1.1, 3.45), (-1.45, 3.45)], -1.3, 1.3, "paint", bevel=0.05)
    p.box((0, 3.53, 0.6), (2.4, 0.05, 2.0), "team", bevel=0.015)
    p.box((1.05, 3.72, -0.4), (0.45, 0.35, 0.5), "trim", bevel=0.03)  # sight
    p.box((1.05, 3.74, -0.67), (0.35, 0.16, 0.04), "light")
    for sx in (-1, 1):
        p.box((sx * 1.82, 2.9, 0.8), (0.04, 0.14, 2.4), "light")
    p.box((0, 2.95, -1.75), (0.9, 0.7, 0.5), "paint", bevel=0.05)  # mantlet
    p.cylinder("z", (0, GUN_Y, -3.6), 0.22, 3.6, 12, "paint")
    p.cylinder("z", (0, GUN_Y, -5.25), 0.28, 0.4, 12, "dark")
    p.cylinder("z", (0, GUN_Y, -5.0), 0.27, 0.08, 12, "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_tideguard", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [0, GUN_Y, -5.5]}})
