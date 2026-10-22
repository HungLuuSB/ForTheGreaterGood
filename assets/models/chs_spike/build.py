"""Spike (Chaos gun turret, T1 structure, footprint 1): mesh, textures, rig
data. blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_spike/build.py

A round low base ringed with reactive-armor blocks and a short post; on it
the `turret`: a round open-backed gun mount with twin bare guns, an orange
sensor and an ammo box (the weapon turns the turret; no pitch piece). Team
plates on the turret roof and the base (BAR style, M-15; Chaos reads light,
M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, ring  # noqa: E402

TURRET_PIVOT = (0.0, 2.4, 0.0)
MUZZLE = (0.0, 3.0, -5.15)


def build_base(p):
    p.cylinder("y", (0, 0.3, 0), 3.2, 0.6, 16, "dark")
    p.cylinder("y", (0, 0.75, 0), 2.8, 0.3, 16, "paint")
    for i in range(6):
        a = math.radians(-90 + i * 60)
        c, s = math.cos(a), math.sin(a)
        p.obox((c * 2.85, 0.85, s * 2.85), (-s, 0, c), (c, 0, s), 1.4, 0.8, 0.28, "era", bevel=0.02)
    p.box((0, 0.93, 1.7), (2.4, 0.05, 1.0), "team", bevel=0.012)
    p.cylinder("y", (0, 1.65, 0), 1.0, 1.5, 12, "trim")
    p.cylinder("y", (0, 2.35, 0), 1.3, 0.1, 12, "steel")


def build_turret(p):
    p.cylinder("y", (0, 3.0, 0.2), 1.75, 1.2, 16, "paint", radius2=1.55)
    p.box((0, 3.63, 0.4), (2.2, 0.05, 1.8), "team", bevel=0.012)
    p.box((1.5, 3.0, 1.4), (0.8, 0.8, 1.0), "trim", bevel=0.03)  # ammo box
    p.box((-1.2, 3.35, -1.35), (0.5, 0.3, 0.3), "dark")
    p.box((-1.2, 3.35, -1.51), (0.36, 0.14, 0.03), "light")
    for sx in (-1, 1):
        x = sx * 0.45
        p.cylinder("z", (x, 3.0, -3.1), 0.2, 3.9, 10, "steel")
        p.cylinder("z", (x, 3.0, -1.5), 0.3, 0.6, 10, "trim")
        p.cylinder("z", (x, 3.0, -4.95), 0.24, 0.3, 10, "dark")


def details_base(p):
    ring(p, (0, 0.901, 0), UP, 2.4)
    bolts(p, (-2.0, 0.901, -0.4), (2.0, 0.901, -0.4), 5, UP)


def details_turret(p):
    ring(p, (0, 3.601, 0.2), UP, 1.2)
    bolts(p, (-1.2, 3.601, -0.6), (1.2, 3.601, -0.6), 4, UP)


unit.run(__file__, "chs_spike", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret)],
         attachments={"muzzle": {"parent": "turret", "at": list(MUZZLE)}})
