"""Wraith (Chaos decoy drone, T2): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_wraith/build.py

New mesh (no blockout before it; the sim's S-109): a small unmanned flying
wing, about half a Behemoth's span, that shows as a strategic bomber on
enemy radar until seen. No canopy: a faceted sensor hump with an amber
eye, a sawtooth trailing edge, a single buried engine with a glowing
exhaust, glowing emitter strips on the wing tops (the radar signature it
fakes), a team stripe across the wing and a team tail plate, formation
strips along the leading edges. One piece (`base`). Chaos reads light and
improvised (M-14). Writes export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, seam  # noqa: E402


def build_base(p):
    wing = [(0.0, -2.6), (4.4, 1.2), (4.4, 1.7), (2.8, 1.4), (1.6, 2.2), (0.0, 1.6),
            (-1.6, 2.2), (-2.8, 1.4), (-4.4, 1.7), (-4.4, 1.2)]
    p.prism_y(wing, 0.3, 0.52, "paint", bevel=0.03)
    p.prism_x([(-2.4, 0.5), (1.8, 0.5), (2.0, 0.7), (-0.6, 1.05), (-1.8, 0.8)], -0.7, 0.7, "trim", bevel=0.05)  # sensor hump
    p.box((0, 0.62, -2.05), (0.5, 0.18, 0.06), "light")  # amber eye
    p.box((0, 0.6, 1.95), (0.8, 0.14, 0.2), "dark")  # buried engine exhaust
    p.box((0, 0.6, 2.06), (0.6, 0.06, 0.04), "light")
    p.box((0, 0.54, 0.6), (6.0, 0.04, 0.4), "team")
    p.prism_x([(1.0, 0.95), (1.9, 0.95), (2.0, 1.5), (1.5, 1.5)], -0.06, 0.06, "team", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * 2.2, 0.55, 0.9), (1.2, 0.03, 0.12), "power")  # emitter strips
        p.box((sx * 2.2, 0.55, 0.55), (0.9, 0.03, 0.1), "power")
        p.box((sx * 4.42, 0.42, 1.45), (0.05, 0.12, 0.4), "light")
        p.obox((sx * 2.2, 0.54, -0.7), (0.654, 0, -sx * 0.757), (0, 1, 0), 0.1, 5.6, 0.03, "light")


def details_base(p):
    seam(p, (-0.6, 0.95, -0.4), (0.6, 0.95, -0.4), UP)


unit.run(__file__, "chs_wraith", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         team_pieces=["base"])
