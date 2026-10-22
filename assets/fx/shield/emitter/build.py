"""Shield emitter device (Order, FX): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/shield/emitter/build.py

A small Order shield projector: a squat hex plinth, a collar, three prongs
leaning in round a glowing core column (the `power` glow channel), sensor
lights (`running`) and team plates on the plinth. The `core` attachment is
where the shield's beam starts (docs/contracts/fx.md). Moved out of
../build.py for the glow pass (M-22); built through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "models", "tools"))

import unit  # noqa: E402

CORE_AT = (0.0, 2.75, 0.0)  # top of the glowing core: where the beam starts


# ---------------------------------------------------------------------------
# Emitter device: a squat hexagonal plinth, a collar, three prongs leaning in
# round a glowing core column; team plates on the plinth's top
# ---------------------------------------------------------------------------


def hexagon(r, rot=0.0):
    return [(r * math.cos(rot + i * math.pi / 3), r * math.sin(rot + i * math.pi / 3)) for i in range(6)]


def build_emitter(p):
    p.prism_y(hexagon(2.0, math.pi / 6), 0.0, 0.55, "paint", bevel=0.05, top_scale=0.92)
    p.prism_y(hexagon(1.45, math.pi / 6), 0.55, 1.05, "trim", bevel=0.04, top_scale=0.9)
    p.cylinder("y", (0, 1.15, 0), 0.75, 0.2, 12, "dark")
    p.cylinder("y", (0, 1.85, 0), 0.38, 1.3, 10, "power", radius2=0.3)
    p.cylinder("y", (0, 2.62, 0), 0.3, 0.26, 10, "power", radius2=0.12)
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        out = (math.cos(a), 0.0, math.sin(a))
        foot = (out[0] * 1.15, 1.0, out[2] * 1.15)
        top = (out[0] * 0.62, 2.7, out[2] * 0.62)
        axis = (top[0] - foot[0], top[1] - foot[1], top[2] - foot[2])
        mid = tuple((foot[k] + top[k]) / 2 for k in range(3))
        length = math.sqrt(sum(c * c for c in axis))
        p.obox(mid, axis, out, length, 0.5, 0.32, "paint", bevel=0.04)
        tip = (out[0] * 0.55, 2.78, out[2] * 0.55)
        p.obox(tip, (0, 1, 0), out, 0.18, 0.36, 0.42, "dark", bevel=0.02)
        # team plate on the plinth's top over a flat face, a sensor light below
        c = a - math.pi / 6
        p.obox((math.cos(c) * 1.48, 0.56, math.sin(c) * 1.48), (-math.sin(c), 0, math.cos(c)), (0, 1, 0),
               0.9, 0.26, 0.05, "team")
        p.obox((math.cos(c) * 1.73, 0.28, math.sin(c) * 1.73), (-math.sin(c), 0, math.cos(c)), (math.cos(c), 0, math.sin(c)),
               0.6, 0.1, 0.05, "light")


def details_emitter(p):
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3
        p.cylinder("y", (math.cos(a) * 1.3, 1.07, math.sin(a) * 1.3), 0.06, 0.04, 6, "dark")
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        out = (math.cos(a), 0.0, math.sin(a))
        p.obox((out[0] * 0.95, 1.6, out[2] * 0.95), (0, 1, 0), out, 0.04, 0.4, 0.34, "seam")


unit.run(__file__, "shield_emitter", "order", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_emitter, details_emitter)],
         attachments={"core": {"parent": "base", "at": list(CORE_AT)}}, tex=512,
         previews=[("35", (5.5, 5.0, 7.0), (0, 1.4, 0), 50)])
