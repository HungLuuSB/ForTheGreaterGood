"""Liche (Order strategic bomber, T2 air, footprint 2; S-181; one
devastating bomb per sortie, a long rearm; fast but turns slowly): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_liche/build.py

From its approved blockout (2026-10-26): a big swept flying wing, about
23 studs across. Big shapes first: a blended centre body with a raised
spine, a glazed cockpit and a sharp nose, long swept wings with team
panels and lit trailing edges, four buried engines with cyan exhausts
along the trailing edge, two canted tail fins, and under the centre the
`bay` (the def's piece; the client opens it, tools/animate.py): the bomb-
bay doors over one huge striped bomb with a lit bay light (`muzzle` under
the bomb). Order reads clean and heavy (M-14). Writes export/ through
tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from mech import rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

BAY = (0.0, 0.4, 0.6)


def build_base(p):
    # the blended centre body and nose (side profile), a raised spine, the cockpit
    p.prism_x([(-8.2, 1.2), (-6.0, 0.6), (5.8, 0.6), (6.4, 1.2), (5.6, 1.9), (-4.0, 2.0), (-7.0, 1.7)], -2.5, 2.5, "paint", bevel=0.14)
    p.prism_x([(-3.0, 1.9), (5.0, 1.9), (4.2, 2.45), (-1.6, 2.45)], -1.2, 1.2, "paint", bevel=0.08)
    p.box((0, 2.48, 1.5), (1.6, 0.05, 4.0), "team", bevel=0.01)
    p.obox((0, 2.15, -4.4), (1, 0, 0), (0, 1, -0.7), 1.8, 1.6, 0.06, "glass")
    p.box((0, 1.0, -7.6), (0.6, 0.1, 0.2), "head")
    # swept wings: the planform, team panels, a lit trailing edge, wing tips
    for sx in (-1, 1):
        wing = [(sx * 2.4, -4.0), (sx * 11.6, 3.6), (sx * 11.6, 5.4), (sx * 9.0, 6.0), (sx * 2.4, 4.2)]
        if sx > 0:
            wing.reverse()
        p.prism_y(wing, 0.7, 1.3, "paint", bevel=0.08)
        p.obox((sx * 7.2, 1.33, 2.7), (sx * 0.85, 0, 0.53), (0, 1, 0), 4.0, 1.8, 0.05, "team", bevel=0.02)
        p.obox((sx * 6.0, 1.0, 5.2), (1, 0, 0), (0, 0, 1), 6.4, 0.1, 0.05, "light")
        p.box((sx * 11.6, 1.0, 4.5), (0.4, 0.8, 1.8), "trim", bevel=0.04)
        p.box((sx * 11.82, 1.0, 4.5), (0.05, 0.2, 1.2), "light")
        # buried engines with cyan exhausts
        for k, x in enumerate((3.4, 5.2)):
            z = 3.4 + k * 0.9
            p.ocyl((sx * x, 1.45, z - 2.2), (0, 0, 1), 0.62, 4.2, 12, "trim")
            p.ocyl((sx * x, 1.45, z + 2.0), (0, 0, 1), 0.48, 0.05, 12, "power")
        # canted tail fins
        p.obox((sx * 1.8, 2.9, 5.0), (0, 0, 1), (1, sx * 0.47, 0), 2.6, 2.4, 0.2, "paint", bevel=0.04)
        p.box((sx * 2.1, 3.9, 5.6), (0.08, 0.3, 0.8), "team")


def details_base(p):
    seam(p, (-2.4, 1.95, -2.0), (2.4, 1.95, -2.0), UP)
    for sx in (-1, 1):
        rivets(p, (sx * 2.51, 1.0, -5.0), (sx * 2.51, 1.0, 5.0), 10, (sx, 0, 0))


def build_bay(p):
    p.box((0, 0.5, 0.6), (2.8, 0.15, 4.6), "dark", bevel=0.02)
    p.cylinder("z", (0, -0.4, 0.6), 0.7, 3.4, 14, "steel")
    p.cylinder("z", (0, -0.4, -1.2), 0.7, 0.4, 14, "steel", radius2=0.2)
    p.cylinder("z", (0, -0.4, -0.4), 0.74, 0.3, 14, "hazard")
    p.box((0, 0.44, 2.5), (0.6, 0.05, 0.4), "weapon")


def no_details(p):
    pass


unit.run(__file__, "ord_liche", "order", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("bay", "base", BAY, build_bay, no_details)],
         attachments={"muzzle": {"parent": "bay", "at": [0.0, -1.3, 0.6]}},
         budget=6000,
         previews=[("35", (-28, 22, -32), (0, 1.5, 0), 50),
                   ("80", (0, 44, 8), (0, 1.5, 0), 50),
                   ("close", (-12, 9, -15), (0, 1.5, -2.0), 38)])
