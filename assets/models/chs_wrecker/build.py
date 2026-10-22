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

import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

NANO = (0.0, 1.5, 2.8)


def build_base(p):
    p.prism_x([(-6.6, 1.3), (-4.6, -0.5), (4.6, -0.5), (4.6, 1.3)], -1.6, 1.6, "paint", bevel=0.05)
    p.prism_x([(-6.0, 0.0), (-4.4, -0.35), (4.65, -0.35), (4.65, 0.0)], -1.66, 1.66, "dark", bevel=0.02)
    p.box((0, 1.33, 3.55), (2.8, 0.05, 1.2), "team", bevel=0.01)
    p.box((0, 1.6, -2.6), (1.92, 0.6, 1.6), "trim", bevel=0.03)
    p.box((0, 0.7, 4.63), (2.6, 0.2, 0.05), "light")  # stern light bar
    p.box((0, 1.82, 0.6), (1.92, 1.04, 1.76), "paint", bevel=0.04)  # squat bridge
    p.box((0, 2.15, -0.3), (1.44, 0.22, 0.05), "light")  # slit window, lit
    p.box((0, 2.36, 0.6), (1.5, 0.05, 1.2), "team", bevel=0.01)
    p.cylinder("y", (0.48, 2.94, 1.7), 0.45, 1.6, 10, "trim")  # funnel
    p.cylinder("y", (0.48, 3.5, 1.7), 0.47, 0.16, 10, "light")  # funnel band (exhaust heat)
    for sx in (-1, 1):
        p.box((sx * 0.98, 2.0, 0.6), (0.06, 0.14, 0.4), "light")
        p.box((sx * 1.63, 1.1, 0.0), (0.05, 0.12, 6.0), "light")


def details_base(p):
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
