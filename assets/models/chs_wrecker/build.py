"""Wrecker (Chaos naval worker, T1 ship): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_wrecker/build.py

A rusty salvage tug: a narrow hull with a raked bow and a dark waterline,
a squat bridge with an amber slit window, a funnel offset to starboard, a
team plate on the afterdeck, a cargo hatch, amber nav lights; the `nano`
builder crane at the stern (turns on its ring) with its emitter (power
channel: brightens while building), like the Scrapper (BAR style, M-15;
Chaos reads light, M-14). Model space, waterline at y = 0. Writes export/
through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ships  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

NANO = (0.0, 1.5, 2.8)
H = ships.Hull(length=11.20, beam=3.33, freeboard=1.30, depth=0.60, sheer_bow=0.50, sheer_stern=0.15, flare=0.2, transom=0.6, rake=1.4, max_at=0.42, fine=2.0, z0=-1.00)  # v2 hull (tools/ships.py)

def build_base(p):
    ships.hull(p, H)
    p.box((0, 1.33, 3.55), (2.8, 0.05, 1.2), "team", bevel=0.01)
    p.box((0, 1.6, -2.6), (1.92, 0.6, 1.6), "trim", bevel=0.03)
    p.box((0, 0.7, H.z(0.0) + 0.03), (ships.half_beam_at(H, H.z(0.0)) * 1.3, 0.2, 0.05), "light")  # stern light bar
    p.box((0, 1.82, 0.6), (1.92, 1.04, 1.76), "paint", bevel=0.04)  # squat bridge
    p.box((0, 2.15, -0.3), (1.44, 0.22, 0.05), "light")  # slit window, lit
    p.box((0, 2.36, 0.6), (1.5, 0.05, 1.2), "team", bevel=0.01)
    p.cylinder("y", (0.48, 2.94, 1.7), 0.45, 1.6, 10, "trim")  # funnel
    p.cylinder("y", (0.48, 3.5, 1.7), 0.47, 0.16, 10, "light")  # funnel band (exhaust heat)
    for sx in (-1, 1):
        p.box((sx * 0.98, 2.0, 0.6), (0.06, 0.14, 0.4), "light")
        if sx > 0:  # running strips along the sheer, both sides
            ships.deck_strip(p, H, H.z0 - 0.36 * H.length, H.z0 + 0.42 * H.length, 0.1)


def details_base(p):
    ships.hull_details(p, H)
    bolts(p, (-1.4, 1.301, -4.0), (1.4, 1.301, -4.0), 6, UP)
    ring(p, (0.48, 3.741, 1.7), UP, 0.35)


def build_nano(p):
    x, y, z = NANO
    p.cylinder("y", (x, y, z), 0.8, 0.4, 10, "trim")
    t = math.radians(30)
    p.obox((0, 2.6, 1.6), (1, 0, 0), (0, math.sin(t), -math.cos(t)), 0.35, 0.35, 3.4, "steel")
    p.cylinder("y", (0, 3.5, 0.1), 0.38, 0.6, 10, "power")
    p.cylinder("y", (0, 3.85, 0.1), 0.42, 0.1, 10, "dark")


def no_details(p):
    pass


unit.run(__file__, "chs_wrecker", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("nano", "base", NANO, build_nano, no_details)])
