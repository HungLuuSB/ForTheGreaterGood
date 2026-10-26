"""Map features (S-197): the trees and rocks sim-A places per map, reclaimable
scenery the client draws as `feature_tree` / `feature_rock` (one fx entry per
family, every variant listed, like the deposits). Shared builder for the
variants in assets/fx/features/<feature_kind_N>/build.py.

BAR's look ("Lush Greens and Sandy", its environment design guide): dark
conifers and round broadleaf crowns in copses, faceted grey rocks with yellow
lichen. Low-poly and faceted, readable from the RTS camera, cheap enough for
hundreds on a map (Supreme Strait: 398 trees, 170 rocks).

- Tree: a point (units pass through); trunk and roots inside about 4 studs,
  the crown wider. Copses stand trees +-22 studs round a centre.
- Rock: blocks its one 8-stud cell; it fills most of it (6-7.5 studs) without
  overhanging the neighbours, sunk a little so it sits in the ground.

The origin is the ground at the feature's centre; the client turns each one
by its wire heading and picks the variant and a +-15% scale from its ID.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "models", "tools"))

import unit  # noqa: E402

_T = (1 + 5 ** 0.5) / 2
_ICO_V = [(-1, _T, 0), (1, _T, 0), (-1, -_T, 0), (1, -_T, 0), (0, -1, _T), (0, 1, _T), (0, -1, -_T), (0, 1, -_T),
          (_T, 0, -1), (_T, 0, 1), (-_T, 0, -1), (-_T, 0, 1)]
_ICO_F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
          (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
          (8, 6, 7), (9, 8, 1)]


def icosphere(sub):
    """Unit icosphere: (verts, faces), `sub` subdivisions (0: 20 faces, 1: 80)."""
    verts = [tuple(c / math.sqrt(1 + _T * _T) for c in v) for v in _ICO_V]
    faces = list(_ICO_F)
    for _ in range(sub):
        mid = {}

        def m(a, b):
            k = (min(a, b), max(a, b))
            if k not in mid:
                x, y, z = ((verts[a][i] + verts[b][i]) / 2 for i in range(3))
                ln = math.sqrt(x * x + y * y + z * z)
                verts.append((x / ln, y / ln, z / ln))
                mid[k] = len(verts) - 1
            return mid[k]
        nf = []
        for a, b, c in faces:
            ab, bc, ca = m(a, b), m(b, c), m(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = nf
    return verts, faces


def blob(p, rng, center, radii, sub, jitter, kind_of, flat_below=None):
    """A faceted lump: an icosphere stretched to `radii` (x, y, z), each vertex
    pushed in or out by up to `jitter`, flattened at `flat_below` (a sunk base).
    `kind_of(ny)` gives each face's kind from how far up it faces."""
    verts, faces = icosphere(sub)
    cx, cy, cz = center
    out = []
    for v in verts:
        k = 1 + rng.uniform(-jitter, jitter)
        x, y, z = cx + v[0] * radii[0] * k, cy + v[1] * radii[1] * k, cz + v[2] * radii[2] * k
        if flat_below is not None:
            y = max(y, flat_below)
        out.append((x, y, z))
    kinds = []
    for f in faces:
        d = [sum(out[i][c] for i in f) / 3 - (cx, cy, cz)[c] for c in range(3)]
        ln = math.sqrt(sum(c * c for c in d)) or 1
        kinds.append(kind_of(d[1] / ln))
    p._shell(out, faces, None, kinds=kinds)


# -- trees ---------------------------------------------------------------------

def foliage(light=0.45, shade=-0.35):
    return lambda ny: "era" if ny > light else "dark" if ny < shade else "trim"


def trunk(p, rng, h, r, lean=0.04):
    """A tapered trunk with three root flares (inside a 4-stud base)."""
    a = rng.uniform(0, 2 * math.pi)
    n = (math.cos(a) * lean, 1.0, math.sin(a) * lean)
    p.ocyl((0, -0.3, 0), n, r, h + 0.3, 7, "paint", radius2=r * 0.6)
    for i in range(3):
        b = a + 2 * math.pi * (i + rng.uniform(-0.15, 0.15)) / 3
        d = (math.cos(b), -0.25, math.sin(b))
        p.ocyl((math.cos(b) * r * 0.4, 0.55, math.sin(b) * r * 0.4), d, r * 0.45, r * 2.4, 5, "paint", radius2=r * 0.1)
    return n


def build_pine(seed, height, tiers):
    """A conifer: a straight trunk and stacked jagged cones, dark underneath,
    the top tiers catching the light."""
    def build(p):
        rng = random.Random(seed)
        trunk(p, rng, height * 0.45, 0.5, lean=0.02)
        y = height * 0.18
        sides = 9
        for i in range(tiers):
            t = i / max(1, tiers - 1)
            r = (3.4 - 2.1 * t) * rng.uniform(0.92, 1.08)
            h = height * (0.42 - 0.12 * t)
            bx, bz = rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15)
            pts, faces, kinds = [], [], []
            for k in range(sides):
                ang = 2 * math.pi * (k + rng.uniform(-0.2, 0.2)) / sides
                rr = r * rng.uniform(0.82, 1.08)
                pts.append((bx + math.cos(ang) * rr, y - rng.uniform(0.0, 0.5), bz + math.sin(ang) * rr))
            pts.append((bx, y + h, bz))  # apex
            pts.append((bx, y + 0.35, bz))  # the underside's centre
            apex, under = sides, sides + 1
            for k in range(sides):
                faces.append((k, (k + 1) % sides, apex))
                kinds.append("era" if t > 0.6 and k % 3 == 0 else "trim")
                faces.append(((k + 1) % sides, k, under))
                kinds.append("dark")
            p._shell(pts, faces, None, kinds=kinds)
            y += h * 0.55
    return build


def build_broadleaf(seed, height, crowns):
    """A broadleaf: a trunk splitting into two limbs under a crown of lumps."""
    def build(p):
        rng = random.Random(seed)
        n = trunk(p, rng, height * 0.42, 0.55)
        top = (n[0] * height * 0.42, height * 0.42, n[2] * height * 0.42)
        for i in range(2):
            a = rng.uniform(0, 2 * math.pi) + i * math.pi
            d = (math.cos(a) * 0.6, 1.0, math.sin(a) * 0.6)
            p.ocyl((top[0], top[1] - 0.4, top[2]), d, 0.32, height * 0.22, 6, "paint", radius2=0.16)
        cy = height * 0.66
        r0 = height * 0.3
        blob(p, rng, (top[0], cy, top[2]), (r0, r0 * 0.8, r0), 1, 0.16, foliage())
        for i in range(crowns):
            a = 2 * math.pi * (i + rng.uniform(-0.2, 0.2)) / crowns
            rr = r0 * rng.uniform(0.55, 0.75)
            c = (top[0] + math.cos(a) * r0 * 0.75, cy + rng.uniform(-0.25, 0.35) * r0, top[2] + math.sin(a) * r0 * 0.75)
            blob(p, rng, c, (rr, rr * 0.82, rr), 0, 0.18, foliage(0.35, -0.3))
    return build


# -- rocks ---------------------------------------------------------------------

def stone(rng, lichen):
    return lambda ny: "radome" if ny > 0.35 and rng.random() < lichen else "rubber" if ny < -0.1 else "steel"


def build_rock(seed, w, h, extras, lichen=0.35):
    """A faceted boulder filling most of its 8-stud cell, sunk 0.6 studs, with
    `extras` smaller stones at its foot (all inside +-3.8 studs)."""
    def build(p):
        rng = random.Random(seed)
        blob(p, rng, (0, h * 0.42, 0), (w / 2, h * 0.62, w / 2 * rng.uniform(0.8, 0.95)), 1, 0.28,
             stone(rng, lichen), flat_below=-0.6)
        for i in range(extras):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(0.7, 1.3)
            d = min(3.8 - r, w / 2 * 0.85)
            blob(p, rng, (math.cos(a) * d, r * 0.35, math.sin(a) * d), (r, r * 0.7, r * 0.85), 0, 0.22,
                 stone(rng, lichen * 0.6), flat_below=-0.4)
    return build


def none(p):
    pass


def run(build_file, feature_id, build, height):
    unit.run(build_file, feature_id, "nature", footprint=1,
             pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build, none)],
             budget=400, tex=512, preview_size=max(9, height * 1.1),
             previews=[("35", (-height * 1.5, height * 1.25, height * 1.8), (0, height * 0.42, 0), 50),
                       ("80", (0, height * 2.6, height * 0.5), (0, height * 0.3, 0), 50)])
