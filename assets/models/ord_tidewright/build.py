"""Tidewright (Order naval worker, T1 ship): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_tidewright/build.py

A heavy work boat: an armored hull with a raked bow and a dark waterline
band, a team plate on the foredeck and on the bridge roof, a squared bridge
with a dark window band and a lit bridge strip, a cargo hatch forward, nav
lights port and starboard and a masthead light; the `nano` builder crane at
the stern (turns on its ring) with its emitter (power channel: brightens
while building), like the Mason (BAR style, M-15; Order reads heavy, M-14).
Model space, waterline at y = 0. Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

NANO = (0.0, 1.5, 2.8)
H = ships.Hull(length=11.00, beam=3.74, freeboard=1.30, depth=0.60, sheer_bow=0.50, sheer_stern=0.15, flare=0.2, transom=0.6, rake=1.4, max_at=0.42, fine=2.0, z0=-1.00)  # v2 hull (tools/ships.py)

def build_base(p):
    # hull: flat stern, raked bow, a dark band at the waterline
    ships.hull(p, H)
    p.box((0, 1.33, -2.7), (2.8, 0.05, 1.5), "team", bevel=0.012)
    p.box((0, 1.6, -2.6), (2.16, 0.6, 1.6), "trim", bevel=0.04)  # cargo hatch
    for sx in (-1, 1):  # hatch status lights
        p.box((sx * 1.09, 1.75, -2.6), (0.04, 0.16, 1.4), "light")
    p.box((0, 0.7, H.z(0.0) + 0.03), (ships.half_beam_at(H, H.z(0.0)) * 1.3, 0.2, 0.05), "light")  # stern light bar
    # bridge
    p.prism_y([(-1.35, -0.5), (1.35, -0.5), (1.35, 1.7), (-1.35, 1.7)], 1.3, 2.9, "paint", bevel=0.05, top_scale=0.94)
    p.box((0, 2.5, -0.52), (2.16, 0.3, 0.06), "glass")
    p.box((0, 2.2, -0.53), (2.0, 0.08, 0.04), "light")
    p.box((0, 2.94, 0.6), (1.89, 0.05, 1.32), "team", bevel=0.012)
    p.cylinder("y", (0, 3.4, 0.9), 0.08, 0.9, 6, "steel")  # mast
    p.box((0, 3.9, 0.9), (0.18, 0.12, 0.18), "light")
    for sx in (-1, 1):  # nav lights and gunwale strips
        p.box((sx * 1.37, 2.4, 0.2), (0.06, 0.16, 0.4), "light")
        if sx > 0:  # running strips along the sheer, both sides
            ships.deck_strip(p, H, H.z0 - 0.36 * H.length, H.z0 + 0.42 * H.length, 0.1)
        for z in (-4.0, 3.6):
            p.cylinder("y", (sx * 1.5, 1.45, z), 0.12, 0.3, 6, "steel")  # bollards


def details_base(p):
    ships.hull_details(p, H)
    seam(p, (-1.8, 1.301, -1.2), (1.8, 1.301, -1.2), UP)
    seam(p, (-1.8, 1.301, 2.0), (1.8, 1.301, 2.0), UP)
    bolts(p, (-1.6, 1.301, 4.2), (1.6, 1.301, 4.2), 6, UP)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 0.8, 0.4, 14, "trim")
    t = math.radians(30)
    p.obox((0, 2.6, 1.6), (1, 0, 0), (0, math.sin(t), -math.cos(t)), 0.4, 0.4, 3.4, "steel")
    p.cylinder("y", (0, 3.5, 0.1), 0.38, 0.6, 10, "power")  # emitter
    p.cylinder("y", (0, 3.85, 0.1), 0.42, 0.1, 10, "dark")


def no_details(p):
    pass


unit.run(__file__, "ord_tidewright", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)])
