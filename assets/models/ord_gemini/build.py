"""Gemini (Order twin rocket-launcher tank, T1; batch 1 of the BAR roster,
S-230): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_gemini/build.py

The twins: a tracked hull with skirts; on a low turntable (`turret`, the
def's only turning piece) two armoured rocket pods side by side, raked up,
each with a 2 x 3 grid of tube mouths (weapon channel) and a team side
plate, a sensor head between them. The def has no pitch piece, so the pods
are part of the turret (BAR style, M-15; Order, M-14). Our own design.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 1.9
TURRET = (0.0, DECK, 0.4)
RAKE = math.radians(14)
POD_Y = DECK + 1.25


def build_base(p):
    hulls.tracked(p, "order", length=7.0, width=5.0, deck=DECK)


def details_base(p):
    bolts(p, (-2.0, DECK + 0.001, 2.6), (2.0, DECK + 0.001, 2.6), 7, UP)


def pod(p, sx):
    """One rocket pod, raked up by RAKE about its rear foot."""
    x = sx * 1.05
    n = (0, math.sin(RAKE), -math.cos(RAKE))  # pod axis (forward, up)
    u = (1, 0, 0)
    c = (x, POD_Y, 0.2)
    p.obox(c, u, n, 1.4, 1.1, 2.8, "paint", bevel=0.05)
    face = tuple(c[i] + n[i] * 1.42 for i in range(3))
    p.obox(face, u, n, 1.2, 0.9, 0.05, "dark")
    up = (0, math.cos(RAKE), math.sin(RAKE))
    for i in range(3):
        for j in range(2):
            o = tuple(face[k] + u[k] * (-0.36 + i * 0.36) + up[k] * (-0.2 + j * 0.4) + n[k] * 0.02 for k in range(3))
            p.ocyl(o, n, 0.12, 0.05, 8, "weapon")
    p.obox((x + sx * 0.71, POD_Y, 0.3), (0, 0, 1), (sx, 0, 0), 1.6, 0.4, 0.04, "team")
    p.obox((x + sx * 0.5, POD_Y + 0.56, 0.2), u, (0, math.cos(RAKE), math.sin(RAKE)), 0.12, 2.2, 0.04, "light")


def build_turret(p):
    p.cylinder("y", (0, DECK + 0.25, 0.4), 1.5, 0.5, 16, "paint", cap_kinds=("dark", "paint"))
    p.box((0, DECK + 0.62, 0.5), (1.0, 0.3, 2.4), "trim", bevel=0.03)  # cradle
    for sx in (-1, 1):
        p.box((sx * 0.6, DECK + 0.85, 0.5), (0.2, 0.5, 1.2), "trim")
        pod(p, sx)
    p.box((0, DECK + 1.25, 0.7), (0.5, 0.5, 0.6), "trim", bevel=0.02)  # sensor head
    p.box((0, DECK + 1.3, 0.38), (0.36, 0.16, 0.04), "light")


def no_details(p):
    pass


unit.run(__file__, "ord_gemini", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details)],
         attachments={"muzzle": {"parent": "turret", "at": [-1.05, POD_Y + 0.35, -1.3]}})
