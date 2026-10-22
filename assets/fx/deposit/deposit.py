"""Supply deposit (neutral terrain prop, M-28; the user's request 2026-10-23):
shared builder for the variants in assets/fx/deposit/<deposit_N>/build.py.

BAR metal-spot style: no neon, no glow, nothing that reads as UI. A shallow
scraped patch of darker ground (the `team` kind: under the alpha mask, so
the client tints it to the terrain like a team plate), a low broken rim, a
cluster of ore outcrops breaking the surface (dark rock with metallic ore
faces: roughness and metalness only) and loose stones at the edge so it
blends into the ground. Fits inside one 8-stud cell (the deposit cell), low
enough (< 0.5 studs) that an extractor's base slab hides it whichever of its
quadrants is over the deposit. Each variant is a seeded layout; the client
also turns each deposit to a random yaw.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "models", "tools"))

import unit  # noqa: E402

UP = (0, 1, 0)
R = 3.7  # patch radius: inside one 8-stud cell


def blob(rng, n, r0, r1):
    """Irregular closed outline (x, z) between radii r0 and r1."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * (i + rng.uniform(-0.25, 0.25)) / n
        r = rng.uniform(r0, r1)
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def outcrop(p, rng, x, z, h, w, lean, kind_side, kind_face):
    """A low faceted rock: a tilted hexagonal frustum, its top an ore face."""
    a = rng.uniform(0, 2 * math.pi)
    n = (math.cos(a) * lean, 1.0, math.sin(a) * lean)
    p.ocyl((x, -0.05, z), n, w, h * 0.75, 6, kind_side, radius2=w * 0.72)
    top = (x + n[0] * h * 0.75 / math.hypot(*n), -0.05 + h * 0.75 / math.hypot(*n), z + n[2] * h * 0.75 / math.hypot(*n))
    p.ocyl(top, n, w * 0.72, h * 0.3, 6, kind_face, radius2=w * 0.3)


def build_for(seed):
    def build(p):
        rng = random.Random(seed)
        cx, cz = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
        # the patch: a ragged outer edge tinted to the terrain, a darker
        # scraped-soil core under the ore cluster
        p.prism_y(blob(rng, 13, R * 0.72, R), -0.05, 0.03, "team")
        core = [(cx + x, cz + z) for x, z in blob(rng, 9, R * 0.38, R * 0.62)]
        p.prism_y(core, -0.05, 0.05, "dark")
        # a broken berm of low lumps round the scrape
        for i in range(rng.randint(6, 7)):
            a = 2 * math.pi * (i + rng.uniform(-0.3, 0.3)) / 7
            d = rng.uniform(R * 0.68, R * 0.9)
            w = rng.uniform(0.35, 0.65)
            p.ocyl((math.cos(a) * d, -0.05, math.sin(a) * d), UP, w, rng.uniform(0.14, 0.24), 5, "paint", radius2=w * 0.55)
        # ore outcrops: a cluster off-centre, the biggest ones metallic on top
        for i in range(rng.randint(7, 8)):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0.3, 1.9) if i else 0.0
            h = rng.uniform(0.3, 0.46) if i < 4 else rng.uniform(0.16, 0.3)
            w = rng.uniform(0.38, 0.72) if i < 4 else rng.uniform(0.2, 0.4)
            face = "steel" if i < 6 else "dark"
            outcrop(p, rng, cx + math.cos(a) * d, cz + math.sin(a) * d, h, w, rng.uniform(0.15, 0.5), "dark", face)
        # loose stones at and past the edge
        for i in range(rng.randint(7, 9)):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(R * 0.55, R * 1.02)
            sz = rng.uniform(0.1, 0.26)
            b = rng.uniform(0, 6.3)
            p.obox((math.cos(a) * d, sz * 0.3, math.sin(a) * d), (math.cos(b), 0, math.sin(b)), UP, sz * 1.4, sz, sz * 0.8, "trim")

    return build


def no_details(p):
    pass


def run(build_file, deposit_id, seed):
    unit.run(build_file, deposit_id, "neutral", footprint=1,
             pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_for(seed), no_details)],
             budget=600, tex=512, preview_size=9,
             previews=[("35", (-7, 6, 8), (0, 0, 0), 50), ("80", (0, 11, 2), (0, 0, 0), 50)])
