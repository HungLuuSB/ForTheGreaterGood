"""Shared builder for the missile meshes (assets/fx/missiles/<weapon id>/build.py),
drawn by the client's Render/Effects in place of its primitive missile parts.

Frame (docs/contracts/fx.md, "Missiles"): forward = -Z, the missile's middle
at the origin, 4.4 studs from the tip (z = -2.2) to the nozzle (z = 2.2): the
client's 1x style frame. The client scales the model by the weapon's style
(IR SAMs 1x, radar SAMs 2.3x, strategic missiles 4.5x) and draws the flame,
light and smoke itself. Glow: a `running` stripe (faction accent) only; the
nozzle throat is dark (the client lights the exhaust; user review
2026-10-23). Team band on the body.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "models", "tools"))

import unit  # noqa: E402
from unit import ring  # noqa: E402

FWD = (0, 0, -1)


def fins(p, z, count, span, chord, kind, phase=0.0, sweep=0.0, r=0.0):
    """Flat fins round the body at z: `span` out from the axis, `chord` along Z."""
    for i in range(count):
        a = phase + i * 2 * math.pi / count
        d = (math.cos(a), math.sin(a), 0.0)
        mid = r + (span - r) / 2
        c = (d[0] * mid, d[1] * mid, z + sweep)
        u = (-math.sin(a), math.cos(a), 0.0)  # fin thickness across
        p.obox(c, u, (0, 0, 1), 0.05, span - r, chord, kind)


def ir_sam(faction):
    chaos = faction == "chaos"

    def build(p):
        r = 0.28
        p.cylinder("z", (0, 0, 0.35), r, 3.3, 12, "paint")
        p.ocyl((0, 0, -1.3), FWD, r, 0.55, 12, "paint", radius2=0.2)  # nose taper
        p.ocyl((0, 0, -1.85), FWD, 0.2, 0.3, 12, "glass", radius2=0.06)  # dark IR seeker dome
        p.cylinder("z", (0, 0, -0.55), r + 0.01, 0.35, 12, "team")
        p.cylinder("z", (0, 0, 0.9), r + 0.01, 0.12, 12, "light")  # accent stripe
        p.cylinder("z", (0, 0, 2.05), r * 0.9, 0.3, 12, "dark", radius2=r * 0.75)  # nozzle
        p.cylinder("z", (0, 0, 2.21), r * 0.55, 0.02, 10, "dark")
        fins(p, -0.95, 4, 0.48, 0.3, "trim", phase=math.pi / 4, r=r)  # canards
        fins(p, 1.75, 3 if chaos else 4, 0.62, 0.55, "trim", phase=math.pi / 4, r=r)

    return build


def radar_sam(faction):
    chaos = faction == "chaos"

    def build(p):
        r = 0.34
        p.cylinder("z", (0, 0, 0.45), r, 3.1, 12, "paint")
        p.ocyl((0, 0, -1.1), FWD, r, 1.05, 14, "radome", radius2=0.04)  # white radome
        p.cylinder("z", (0, 0, -0.75), r + 0.01, 0.3, 12, "team")
        p.cylinder("z", (0, 0, 0.6), r + 0.01, 0.12, 12, "light")
        p.cylinder("z", (0, 0, 2.05), r * 0.9, 0.3, 12, "dark", radius2=r * 0.72)
        p.cylinder("z", (0, 0, 2.21), r * 0.55, 0.02, 10, "dark")
        fins(p, -0.1, 4, 0.62, 1.0, "trim", phase=math.pi / 4, r=r)  # long mid-body strakes
        fins(p, 1.75, 4, 0.78, 0.6, "trim", phase=math.pi / 4 + (0.12 if chaos else 0.0), r=r)

    return build


def nuke(faction):
    chaos = faction == "chaos"

    def build(p):
        r = 0.42
        p.cylinder("z", (0, 0, 0.55), r, 3.3, 14, "paint")
        p.ocyl((0, 0, -1.1), FWD, r, 0.5, 14, "trim", radius2=0.36)  # warhead bus
        p.ocyl((0, 0, -1.6), FWD, 0.36, 0.6, 14, "dark", radius2=0.02)  # re-entry cone
        p.cylinder("z", (0, 0, -0.75), r + 0.01, 0.3, 14, "team")
        for z in (0.1, 1.0):  # stage rings, the upper one lit
            p.cylinder("z", (0, 0, z), r + 0.015, 0.08, 14, "steel")
        p.cylinder("z", (0, 0, 0.55), r + 0.012, 0.1, 14, "light")
        p.cylinder("z", (0, 0, 2.1), r * 0.95, 0.2, 14, "dark", radius2=r * 0.8)
        p.cylinder("z", (0, 0, 2.21), r * 0.6, 0.02, 12, "dark")
        if chaos:  # strap-on boosters, Chaos's crude lift
            for a in (0.0, math.pi):
                d = (math.cos(a) * (r + 0.14), math.sin(a) * (r + 0.14))
                p.cylinder("z", (d[0], d[1], 1.4), 0.14, 1.4, 8, "trim")
                p.ocyl((d[0], d[1], 0.7), FWD, 0.14, 0.25, 8, "trim", radius2=0.03)
        fins(p, 1.9, 4, 0.7, 0.45, "trim", phase=math.pi / 4, r=r)

    return build


def details(p):
    ring(p, (0, 0, -0.2), FWD, 0.3, width=0.02, segments=10)


KINDS = {"ir_sam": ir_sam, "radar_sam": radar_sam, "nuke": nuke}


def run(build_file, weapon_id):
    faction = "order" if weapon_id.startswith("ord_") else "chaos"
    kind = weapon_id[4:]
    unit.run(build_file, weapon_id, faction, footprint=1,
             pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), KINDS[kind](faction), details)],
             budget=1500, tex=256, preview_size=5,
             previews=[("side", (-4.0, 1.2, -1.0), (0, 0, 0), 50), ("rear", (2.5, 1.5, 4.5), (0, 0, 0), 50)])
