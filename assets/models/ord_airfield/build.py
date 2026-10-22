"""Airfield (Order air factory, T1 structure, footprint 5): mesh, textures,
rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_airfield/build.py

A 38-stud concrete apron with a runway (team centre stripe, cyan edge
lights), a heavy armored hangar with a sloped roof, a team plate on the roof
and door-frame build lights (power channel: pulses while producing), a
control tower with a lit cab and a static radar panel (unlit face, glowing
edge), and a landing pad with a team square and corner lights (BAR style,
M-15; Order reads heavy, M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import unit  # noqa: E402
from unit import UP, bolts, box_seams, seam  # noqa: E402

RX = 2.0  # runway centre line x


def build_base(p):
    p.prism_y([(-19, -19), (19, -19), (19, 19), (-19, 19)], 0.0, 0.4, "trim", bevel=0.08, top_scale=0.995)
    # runway: dark surface, team centre dashes, edge lights, threshold bars
    p.box((RX, 0.45, 0), (10, 0.1, 37), "dark")
    for i in range(8):
        p.box((RX, 0.51, -15 + i * 4.3), (0.6, 0.03, 2.4), "team")
    for i in range(6):
        z = -16 + i * 6.4
        for x in (RX - 5.4, RX + 5.4):
            p.box((x, 0.55, z), (0.4, 0.3, 0.4), "light")
    for z in (-17.8, 17.8):
        for k in range(6):
            p.box((RX - 3.75 + k * 1.5, 0.51, z), (0.9, 0.03, 0.8), "seam")
    # hangar: armored hall, sloped roof, team plate, door with build lights
    hx, hz = -12.0, 8.0
    p.prism_x([(hz - 6, 0.4), (hz + 6, 0.4), (hz + 6, 5.4), (hz - 4.6, 6.6), (hz - 6, 5.6)], hx - 6, hx + 6, "paint", bevel=0.08)
    p.obox((hx, 6.1, hz + 1.6), (1, 0, 0), (0, 0.993, 0.12), 9.0, 6.0, 0.05, "team")
    p.box((hx, 3.0, hz - 6.05), (9.0, 4.6, 0.12), "dark")
    for i in range(4):  # build lights through the door, like the vehicle plant
        p.box((hx, 1.2 + i * 1.1, hz - 6.14), (8.6, 0.14, 0.06), "power")
    p.box((hx, 5.5, hz - 6.15), (9.6, 0.3, 0.14), "power")  # lintel
    for sx in (-1, 1):
        p.box((hx + sx * 4.75, 2.95, hz - 6.15), (0.24, 5.0, 0.14), "power")  # door frame
    for sx in (-1, 1):
        p.box((hx + sx * 6.03, 2.0, hz), (0.06, 0.14, 10.0), "light")
        p.box((hx + sx * 6.0, 3.6, hz + 2.5), (0.06, 1.2, 4.0), "grille")
    # control tower, cab, radar panel
    tx, tz = 13.0, 12.0
    p.prism_y([(tx - 2, tz - 2), (tx + 2, tz - 2), (tx + 2, tz + 2), (tx - 2, tz + 2)], 0.4, 7.4, "paint", bevel=0.06, top_scale=0.9)
    p.prism_y([(tx - 2.3, tz - 2.3), (tx + 2.3, tz - 2.3), (tx + 2.3, tz + 2.3), (tx - 2.3, tz + 2.3)], 7.4, 8.8, "glass", bevel=0.04)
    p.prism_y([(tx - 2.5, tz - 2.5), (tx + 2.5, tz - 2.5), (tx + 2.5, tz + 2.5), (tx - 2.5, tz + 2.5)], 8.8, 9.2, "trim", bevel=0.04)
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):  # cab lights under the windows
        if sx:
            p.box((tx + sx * 2.32, 7.5, tz), (0.06, 0.14, 4.2), "light")
        else:
            p.box((tx, 7.5, tz + sz * 2.32), (4.2, 0.14, 0.06), "light")
    p.box((tx, 5.0, tz - 2.03), (2.4, 1.0, 0.06), "team")
    p.cylinder("y", (tx, 9.5, tz), 0.4, 0.6, 10, "steel")
    t = math.radians(20)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (tx, 10.5, tz)
    with p.sub("radar", (tx, 9.8, tz), "turn", (0, 1, 0)):  # M-27
        p.obox(c, (1, 0, 0), n, 3.0, 2.0, 0.3, "paint", bevel=0.03)
        p.obox(tuple(c[k] + n[k] * 0.16 for k in range(3)), (1, 0, 0), n, 2.7, 1.7, 0.03, "dark")
        for b in (-0.85, 0.85):
            p.obox(tuple(c[k] + n[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), n, 2.7, 0.08, 0.02, "light")
        for a in (-1.35, 1.35):
            p.obox((c[0] + a, c[1] + n[1] * 0.18, c[2] + n[2] * 0.18), (1, 0, 0), n, 0.08, 1.7, 0.02, "light")
    # landing pad: team square, corner lights
    px, pz = -12.0, -9.0
    p.box((px, 0.47, pz), (7, 0.15, 7), "steel", bevel=0.04)
    p.box((px, 0.56, pz), (4, 0.04, 4), "team")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((px + sx * 3.3, 0.62, pz + sz * 3.3), (0.4, 0.14, 0.4), "light")
    # fuel bowser and crates by the hangar
    p.cylinder("z", (-17.0, 1.2, -1.0), 0.8, 3.0, 10, "trim")
    p.box((-6.5, 0.9, 1.0), (1.4, 1.0, 1.4), "steel", bevel=0.04)

    # approach lights at both runway ends, apron edge lights
    for zs in (-1, 1):
        for k in range(5):
            p.box((RX - 3.2 + k * 1.6, 0.48, zs * 18.6), (0.9, 0.12, 0.4), "light")
    for i in range(7):
        t = -16.5 + i * 5.5
        for a, b in ((t, -18.85), (t, 18.85), (-18.85, t), (18.85, t)):
            p.box((a, 0.3, b), (0.5, 0.14, 0.5), "light")

def details_base(p):
    for z in (-12.0, 0.0, 12.0):
        seam(p, (-18.5, 0.401, z), (18.5, 0.401, z), UP)
    for x in (-8.0, 12.0):
        seam(p, (x, 0.401, -18.5), (x, 0.401, 18.5), UP)
    box_seams(p, (-12.0, 0, 8.6), (10.0, 0, 9.0), 6.0)
    bolts(p, (-18.4, 0.401, -18.4), (18.4, 0.401, -18.4), 20, UP)


unit.run(__file__, "ord_airfield", "order", footprint=5,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=6000, tex=2048, preview_size=40)
