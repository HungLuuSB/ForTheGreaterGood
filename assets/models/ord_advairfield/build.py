"""Advanced Airfield (Order air factory, T2 structure, footprint 6): mesh,
textures, rig data. blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_advairfield/build.py

Designed at the size scale (S-104, M-26: footprint 6, 48 x 48 studs; the
hangars about 11 tall, the control tower about 16), bigger and busier than
the T1 Airfield rather than a rescale. Big shapes first:
- a chamfered slab;
- a wide runway along Z with team centre dashes, hazard thresholds, edge
  and approach lights;
- two armored arched hangars side by side on the left, their doors facing
  the runway, ribs and team roof bays; the front one is the assembly hangar
  (lit door frame, lintel and build lights: power, pulses while producing),
  the back one closed with a team-striped door; an armored link block with
  a team roof between them;
- the build pad on the apron in front of the assembly hangar (team ring,
  hazard border, `buildpad`), two emitter booms off the door pilasters and
  a head on the lintel (`nano1..3`);
- a big approach-radar radome on an armored block with team plates (the
  T2 signature, T1 vs T2 check 2026-10-22), two rearm pads (the def's
  `rearmPads`) and a tall control tower with team plates, a lit glass cab
  and the client-turned `radarPanel` (unlit face, glowing edge, M-27);
- a fuel farm with team bands at the back.
Order reads heavy and clean (M-14). Writes export/ through tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import lib  # noqa: E402
import unit  # noqa: E402
from mech import arch, cable, hazard, octagon, rect, rivets  # noqa: E402
from unit import UP, bolts, seam  # noqa: E402

V = lib.vec
RX = 8.0  # runway centre line x
HX0, HX1, HTOP = -23.0, -9.4, 10.8  # hangars: back and door x, height
HANGARS = (-11.0, 9.0)  # hangar centre z (front: assembly, back: closed)
HW = 7.0  # hangar half width (z)
PAD = (-3.0, -11.0)
TX, TZ = 19.0, 17.0  # control tower
DX, DZ = 19.0, -15.0  # radome
REARM = ((19.0, -4.4), (19.0, 4.8))


def hangar_profile(zc, grow=0.0):
    return arch(zc - HW - grow, zc + HW + grow, 0.5, HTOP + grow, steps=10, flat=0.3)


def boom(p, a, b):
    a, b = V(a), V(b)
    u = b - a
    p.obox(tuple((a + b) / 2), tuple(u), (0, 1, 0), u.length, 0.6, 0.6, "trim", bevel=0.04)
    p.ocyl(tuple(b), (0, -1, 0), 0.52, 0.45, 14, "dark")
    p.cylinder("y", (b.x, b.y - 0.47, b.z), 0.38, 0.06, 14, "power")


def dome(p, center, r, kind, rings=6, sides=18, y0=0.0):
    """A dome (radome) from stacked frustums: from height y0 (share of r
    below the centre, negative) over the top."""
    cx, cy, cz = center
    a0 = math.asin(max(-1.0, min(1.0, y0)))
    angles = [a0 + (math.pi / 2 - a0) * i / rings for i in range(rings + 1)]
    for a, b in zip(angles, angles[1:]):
        r1, r2 = r * math.cos(a), max(0.02, r * math.cos(b))
        p.ocyl((cx, cy + r * math.sin(a), cz), UP, r1, r * (math.sin(b) - math.sin(a)), sides, kind, radius2=r2)


def build_base(p):
    p.prism_y(octagon(23.6, 2.0), 0.0, 0.5, "trim", bevel=0.16, top_scale=0.995)
    # runway: dark surface, team centre dashes, hazard thresholds, lights
    p.box((RX, 0.56, 0), (11.0, 0.12, 45.0), "dark")
    for i in range(8):
        p.box((RX, 0.635, -19.25 + i * 5.5), (1.0, 0.03, 3.2), "team")
    for zs in (-1, 1):
        hazard(p, (RX, 0.63, zs * 20.6), (1, 0, 0), UP, 10.4, 1.1, stripes=15)
        for k in range(6):
            p.box((RX - 4.0 + k * 1.6, 0.6, zs * 22.7), (0.9, 0.16, 0.4), "light")
    for i in range(7):
        z = -18.0 + i * 6.0
        for x in (RX - 5.75, RX + 5.75):
            p.box((x, 0.68, z), (0.45, 0.3, 0.45), "light")
    # hangars: arched halls along X, doors facing the runway (+X), ribs
    for hz in HANGARS:
        p.prism_x(hangar_profile(hz), HX0, HX1, "paint", bevel=0.12)
        pts = hangar_profile(hz, 0.02)
        for x in (HX0 + 0.25, -18.4, -13.9, HX1 - 0.25):
            for (z1, y1), (z2, y2) in zip(pts, pts[1:]):
                d = V((0, y2 - y1, z2 - z1))
                n = V((0, z2 - z1, -(y2 - y1))).normalized()
                c = V((x, (y1 + y2) / 2, (z1 + z2) / 2)) + n * 0.12
                p.obox(tuple(c), (1, 0, 0), tuple(n), 0.6, d.length + 0.12, 0.3, "trim")
        for (z1, y1), (z2, y2) in zip(pts, pts[1:]):
            if min(y1, y2) < 8.4:
                continue
            d = V((0, y2 - y1, z2 - z1))
            n = V((0, z2 - z1, -(y2 - y1))).normalized()
            for xc, length in ((-20.7, 4.2), (-16.15, 4.2), (-11.65, 4.0)):
                c = V((xc, (y1 + y2) / 2, (z1 + z2) / 2)) + n * 0.03
                p.obox(tuple(c), (1, 0, 0), tuple(n), length, d.length * 1.02, 0.05, "team")
        # door pilasters, vents on the back
        for sz in (-1, 1):
            p.prism_y(rect(HX1 + 0.3, hz + sz * 7.0, 0.8, 1.1), 0.5, 7.8, "paint", bevel=0.1, top_scale=0.85)
        p.ocyl((-19.0, 9.7, hz), UP, 0.85, 1.8, 14, "trim", radius2=0.7)
        p.cylinder("y", (-19.0, 11.52, hz), 0.71, 0.08, 14, "power")
    # the assembly hangar's door: lit frame, lintel, build lights, sill hazard
    hz = HANGARS[0]
    p.box((HX1 + 0.07, 4.5, hz), (0.1, 8.0, 11.6), "dark")
    for sz in (-1, 1):
        p.box((HX1 + 0.45, 4.4, hz + sz * 6.05), (0.14, 7.8, 0.3), "power")
    p.box((HX1 + 0.45, 8.6, hz), (0.16, 0.36, 12.4), "power")
    for i in range(3):
        p.box((HX1 + 0.12, 2.0 + i * 2.0, hz), (0.06, 0.14, 11.0), "power")
    hazard(p, (HX1 + 0.6, 0.53, hz), (0, 0, 1), UP, 11.6, 0.6, stripes=18)
    # the closed back hangar: armored door panels, a team stripe, a light strip
    hz = HANGARS[1]
    for k in range(4):
        p.box((HX1 + 0.12, 4.2, hz - 4.35 + k * 2.9), (0.2, 7.4, 2.8), "trim", bevel=0.04)
    p.box((HX1 + 0.24, 6.0, hz), (0.05, 1.0, 11.4), "team")
    p.box((HX1 + 0.45, 8.6, hz), (0.16, 0.3, 12.4), "light")
    # armored link block between the hangars
    p.prism_x([(-4.6, 0.5), (2.6, 0.5), (2.6, 6.0), (1.6, 7.2), (-3.6, 7.2), (-4.6, 6.0)], -22.4, -10.4, "paint", bevel=0.12)
    p.box((-16.4, 7.24, -1.0), (10.6, 0.06, 4.4), "team", bevel=0.02)
    p.box((-10.37, 3.0, -1.0), (0.06, 2.4, 1.6), "dark")
    p.box((-10.37, 5.2, -1.0), (0.06, 0.16, 5.4), "light")
    p.box((-16.4, 7.3, -1.0), (2.0, 0.06, 2.0), "grille")
    # build pad on the apron: team ring, dark plate, hazard edges, lights
    p.prism_y(octagon(5.3, 1.3, *PAD), 0.5, 0.62, "team", bevel=0.02)
    p.prism_y(octagon(4.8, 1.1, *PAD), 0.5, 0.7, "dark", bevel=0.04)
    for sz in (-1, 1):
        hazard(p, (PAD[0], 0.72, PAD[1] + sz * 5.65), (1, 0, 0), UP, 10.2, 0.45, stripes=16)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((PAD[0] + sx * 5.0, 0.78, PAD[1] + sz * 5.0), (0.4, 0.16, 0.4), "light")
    # emitter booms from the door pilasters, a head on the lintel
    for sz in (-1, 1):
        boom(p, (HX1 + 0.6, 7.4, PAD[1] + sz * 7.0), (PAD[0] - 1.6, 6.0, PAD[1] + sz * 3.4))
    p.box((HX1 + 0.6, 9.15, PAD[1]), (1.4, 0.7, 1.4), "trim", bevel=0.04)
    p.ocyl((HX1 + 1.1, 8.9, PAD[1]), (0, -1, 0), 0.5, 0.45, 14, "dark")
    p.cylinder("y", (HX1 + 1.1, 8.43, PAD[1]), 0.36, 0.06, 14, "power")
    # taxi line from the back hangar to the runway
    for k in range(6):
        p.box((-7.8 + k * 1.5, 0.53, HANGARS[1]), (0.8, 0.03, 0.35), "hazard")
    # radome: armored block with team plates, a white dome, a beacon
    p.prism_y(rect(DX, DZ, 3.8, 3.8), 0.5, 4.6, "paint", bevel=0.12, top_scale=0.9)
    p.obox((DX, 2.8, DZ - 3.73), (1, 0, 0), (0, 0.05, -1), 5.4, 2.2, 0.05, "team", bevel=0.015)
    p.obox((DX - 3.73, 2.8, DZ), (0, 0, 1), (-1, 0.05, 0), 5.4, 2.2, 0.05, "team", bevel=0.015)
    p.cylinder("y", (DX, 4.85, DZ), 3.0, 0.5, 18, "trim")
    p.cylinder("y", (DX, 5.14, DZ), 3.06, 0.08, 18, "light")
    dome(p, (DX, 7.6, DZ), 4.2, "radome", rings=6, sides=20, y0=-0.62)
    p.box((DX, 11.95, DZ), (0.4, 0.3, 0.4), "light")
    p.box((DX + 3.83, 2.0, DZ), (0.06, 2.4, 1.2), "dark")  # door
    # rearm pads between the radome and the tower
    for x, z in REARM:
        p.prism_y(octagon(3.4, 0.9, x, z), 0.5, 0.6, "team", bevel=0.02)
        p.prism_y(octagon(3.0, 0.8, x, z), 0.5, 0.66, "dark", bevel=0.03)
        p.box((x, 0.68, z), (2.4, 0.03, 0.3), "hazard")
        p.box((x, 0.68, z), (0.3, 0.03, 2.4), "hazard")
        for sx in (-1, 1):
            p.box((x + sx * 3.3, 0.7, z), (0.3, 0.14, 0.3), "light")
        p.box((x + 3.9, 1.0, z), (0.8, 1.0, 1.2), "trim", bevel=0.04)  # fuel / ammo point
    # control tower: tapered shaft, team plates, glass cab, roof
    p.prism_y(rect(TX, TZ, 2.4, 2.4), 0.5, 11.0, "paint", bevel=0.12, top_scale=0.8)
    p.obox((TX - 2.25, 7.4, TZ), (0, 0, 1), (-1, 0.05, 0), 2.8, 3.4, 0.05, "team", bevel=0.015)
    p.obox((TX, 7.4, TZ - 2.25), (1, 0, 0), (0, 0.05, -1), 2.8, 3.4, 0.05, "team", bevel=0.015)
    p.box((TX - 2.43, 2.0, TZ), (0.06, 2.6, 1.2), "dark")  # door
    p.prism_y(rect(TX, TZ, 2.8, 2.8), 11.0, 12.8, "glass", bevel=0.05)
    p.prism_y(rect(TX, TZ, 3.1, 3.1), 12.8, 13.3, "trim", bevel=0.05)
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):  # cab lights under the windows
        if sx:
            p.box((TX + sx * 2.83, 11.1, TZ), (0.06, 0.14, 5.2), "light")
        else:
            p.box((TX, 11.1, TZ + sz * 2.83), (5.2, 0.14, 0.06), "light")
    p.cylinder("y", (TX, 13.55, TZ), 0.55, 0.5, 12, "steel")
    p.cylinder("y", (TX + 1.8, 14.6, TZ + 1.8), 0.06, 2.6, 6, "steel")  # whip antenna
    p.box((TX + 1.8, 15.95, TZ + 1.8), (0.26, 0.26, 0.26), "light")
    t = math.radians(20)
    n, v = (0, math.sin(t), -math.cos(t)), (0, math.cos(t), math.sin(t))
    c = (TX, 14.8, TZ)
    with p.sub("radarPanel", (TX, 13.8, TZ), "turn", (0, 1, 0)):  # M-27
        p.cylinder("y", (TX, 13.9, TZ), 0.42, 0.2, 10, "trim")
        p.obox(c, (1, 0, 0), n, 4.0, 2.4, 0.3, "paint", bevel=0.03)
        p.obox(tuple(c[k] + n[k] * 0.16 for k in range(3)), (1, 0, 0), n, 3.7, 2.1, 0.03, "dark")
        for b in (-1.05, 1.05):
            p.obox(tuple(c[k] + n[k] * 0.18 + v[k] * b for k in range(3)), (1, 0, 0), n, 3.7, 0.08, 0.02, "light")
        for a in (-1.85, 1.85):
            p.obox((c[0] + a, c[1] + n[1] * 0.18, c[2] + n[2] * 0.18), (1, 0, 0), n, 0.08, 2.1, 0.02, "light")
        p.obox(tuple(c[k] - n[k] * 0.17 for k in range(3)), (1, 0, 0), n, 3.2, 1.6, 0.03, "team")
    # fuel farm at the back left: tanks with team bands, gauges, a pipe
    for x in (-19.6, -14.8):
        p.cylinder("y", (x, 2.1, 19.8), 1.9, 3.2, 18, "paint", bevel=0.05)
        p.ocyl((x, 3.7, 19.8), UP, 1.9, 0.45, 18, "trim", radius2=1.4)
        p.cylinder("y", (x, 2.8, 19.8), 1.94, 0.6, 18, "team")
        p.box((x, 1.8, 17.88), (0.4, 1.4, 0.05), "power")
    cable(p, [(-12.9, 1.0, 19.8), (-9.6, 0.8, 19.8), (-8.0, 0.8, 16.4)], r=0.16, kind="steel")
    for x, z in ((-6.0, 20.4), (-4.6, 20.4), (-5.3, 18.9)):
        p.box((x, 1.1, z), (1.3, 1.2, 1.3), "trim", bevel=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box((sx * 22.9, 0.56, sz * 22.9), (0.6, 0.14, 0.6), "light")


def details_base(p):
    for z in (-21.0, -1.0, 21.0):
        seam(p, (-8.6, 0.501, z), (1.0, 0.501, z), UP)
    seam(p, (14.4, 0.501, -22.5), (14.4, 0.501, 22.5), UP)
    for hz in HANGARS:
        for sz in (-1, 1):
            rivets(p, (HX1 + 1.11, 1.4, hz + sz * 7.0 - 0.9), (HX1 + 1.11, 1.4, hz + sz * 7.0 + 0.9), 4, (1, 0, 0))
    rivets(p, (DX - 3.0, 1.0, DZ - 3.81), (DX + 3.0, 1.0, DZ - 3.81), 8, (0, 0, -1))
    bolts(p, (-21.5, 0.501, -23.1), (21.5, 0.501, -23.1), 24, UP)


unit.run(__file__, "ord_advairfield", "order", footprint=6,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base)],
         budget=8000, tex=2048,
         previews=[("35", (-56, 45, -67), (0, 5.0, 0), 50),
                   ("80", (0, 124, 22), (0, 4, 0), 50),
                   ("close", (14, 22, -36), (-6.0, 5.0, -8.0), 35),
                   ("back", (52, 42, 62), (0, 5.0, 0), 50)])
