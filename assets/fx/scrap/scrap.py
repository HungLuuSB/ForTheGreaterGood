"""Scrap heap (S-227, part 4 of the BAR roster plan, the user's approval
2026-10-31): what a wreck becomes when its health falls below 40%. Shared
builder for the sizes in assets/fx/scrap/<scrap_heap_N>/build.py, one per
footprint (1, 2, 3, 4+; the client scales scrap_heap_4 up for bigger units).

Faction-neutral, our own design, no glow: a scorched ground patch (`team`,
tinted to the terrain like the deposits' scrape), a low mound of charred
debris, and on it a tangle of scattered metal bars: girders, square bars,
angle iron, pipes, bent bars and torn plates, some lying flat, some leaning
up out of the pile, in rust, sooty paint and bare scraped steel; small bits
spilled past the edge. Each size is a seeded layout; the client turns each
heap to a random yaw.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "models", "tools"))

import unit  # noqa: E402

UP = (0, 1, 0)
METALS = ["trim", "trim", "paint", "paint", "steel", "dark"]


def blob(rng, n, r0, r1):
    """Irregular closed outline (x, z) between radii r0 and r1."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * (i + rng.uniform(-0.25, 0.25)) / n
        r = rng.uniform(r0, r1)
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def norm(v):
    m = math.sqrt(sum(c * c for c in v))
    return tuple(c / m for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def frame(yaw, tilt):
    """A bar's axis n (yaw round Y, tilted up by `tilt`) and a side vector u
    across it, rolled a little so the bars don't all lie square."""
    n = (math.cos(yaw) * math.cos(tilt), math.sin(tilt), math.sin(yaw) * math.cos(tilt))
    side = norm(cross(UP, n)) if abs(tilt) < 1.4 else (1.0, 0.0, 0.0)
    return n, side


def bar(p, rng, c, n, side, length, w, kind):
    shape = rng.random()
    if shape < 0.3:  # girder: web and two flanges
        up = norm(cross(n, side))
        p.obox(c, side, n, w * 0.25, w, length, kind)
        for s in (-1, 1):
            p.obox(tuple(c[i] + up[i] * s * w * 0.45 for i in range(3)), side, n, w * 0.9, w * 0.14, length, kind)
    elif shape < 0.5:  # angle iron
        up = norm(cross(n, side))
        p.obox(c, side, n, w, w * 0.18, length, kind)
        p.obox(tuple(c[i] + side[i] * w * 0.45 + up[i] * w * 0.4 for i in range(3)), side, n, w * 0.18, w * 0.8, length, kind)
    elif shape < 0.75:  # pipe
        base = tuple(c[i] - n[i] * length / 2 for i in range(3))
        p.ocyl(base, n, w * 0.45, length, 7, kind)
    else:  # square bar
        p.obox(c, side, n, w * 0.7, w * 0.7, length, kind)


def build_for(footprint, seed):
    size = footprint * 8.0
    R = size * 0.4  # the pile's radius
    H = 0.55 + footprint * 0.42  # the mound's top

    def mound(d):  # the debris mound's surface: flat top to 0.25 R, sloping to the ground at 0.72 R
        return H * 0.55 * min(1.0, max(0.0, (0.72 * R - d) / (0.47 * R)))

    def build(p):
        rng = random.Random(seed)
        # scorched ground and the charred debris mound
        p.prism_y(blob(rng, 14, R * 0.95, R * 1.15), -0.05, 0.03, "team")
        p.prism_y(blob(rng, 11, R * 0.6, R * 0.82), -0.05, H * 0.55, "dark", top_scale=0.35)
        for i in range(2 + footprint):
            a, d = rng.uniform(0, 6.283), rng.uniform(0.25, 0.6) * R
            w = rng.uniform(0.18, 0.3) * R
            p.ocyl((math.cos(a) * d, -0.05, math.sin(a) * d), UP, w, rng.uniform(0.25, 0.45) * H, 6, "dark",
                   radius2=w * 0.4)
        # crushed chunks in the core, for mass under the bars
        for i in range(2 + footprint * 2):
            a, d = rng.uniform(0, 6.283), R * math.sqrt(rng.random()) * 0.55
            s = rng.uniform(0.6, 1.1) * (0.6 + 0.35 * footprint)
            n = norm((rng.uniform(-0.6, 0.6), 1.0, rng.uniform(-0.6, 0.6)))
            u = norm(cross(n, (math.cos(a), 0.0, math.sin(a))))
            p.obox((math.cos(a) * d, mound(d) + s * 0.2, math.sin(a) * d), u, n, s * 1.3, s, s * 0.6,
                   rng.choice(("paint", "paint", "trim", "dark")), bevel=0.04)
        # the bars: flat ones follow the mound, some lean up out of the pile
        count = int(10 + 9 * footprint ** 1.25)
        for i in range(count):
            a = rng.uniform(0, 6.283)
            d = R * math.sqrt(rng.random()) * 0.9
            x, z = math.cos(a) * d, math.sin(a) * d
            length = rng.uniform(0.18, 0.42) * size * 0.5 + 0.8
            w = rng.uniform(0.18, 0.34) * (0.75 + 0.25 * footprint)
            leaning = rng.random() < 0.2 and d < R * 0.7
            yaw = rng.uniform(0, 6.283)
            if leaning:
                tilt = rng.uniform(0.45, 0.95)
                y = mound(d) + w * 0.4 + math.sin(tilt) * length * 0.42
            else:
                dx, dz = math.cos(yaw) * length / 2, math.sin(yaw) * length / 2
                h1, h2 = mound(math.hypot(x - dx, z - dz)), mound(math.hypot(x + dx, z + dz))
                tilt = math.atan2(h2 - h1, length) + rng.uniform(-0.05, 0.05)
                y = (h1 + h2) / 2 + w * 0.4
            n, side = frame(yaw, tilt)
            kind = rng.choice(METALS)
            if rng.random() < 0.15:  # bent bar: two halves at an angle
                k = rng.uniform(0.35, 0.7)
                n2, side2 = frame(math.atan2(n[2], n[0]) + rng.choice((-1, 1)) * k, tilt * 0.3)
                h = length * 0.5
                p.obox((x - n[0] * h * 0.5, y, z - n[2] * h * 0.5), side, n, w * 0.6, w * 0.6, h, kind)
                p.obox((x + n2[0] * h * 0.5, y + n2[1] * h * 0.5, z + n2[2] * h * 0.5), side2, n2, w * 0.6, w * 0.6, h, kind)
            else:
                bar(p, rng, (x, y, z), n, side, length, w, kind)
        # torn plates on the pile
        for i in range(2 + footprint * 2):
            a, d = rng.uniform(0, 6.283), R * math.sqrt(rng.random()) * 0.8
            n = norm((rng.uniform(-0.5, 0.5), 1.0, rng.uniform(-0.5, 0.5)))
            u = norm(cross(n, (math.cos(a), 0.0, math.sin(a))))
            s = rng.uniform(0.5, 1.0) * (0.6 + 0.4 * footprint)
            p.obox((math.cos(a) * d, mound(d) + 0.1, math.sin(a) * d), u, n, s, s * rng.uniform(0.5, 0.9), 0.08,
                   rng.choice(("paint", "trim", "dark")))
        # bits spilled past the edge
        for i in range(6 + footprint * 5):
            a, d = rng.uniform(0, 6.283), rng.uniform(R * 0.75, R * 1.1)
            sz = rng.uniform(0.15, 0.4) * (0.7 + 0.3 * footprint)
            b = rng.uniform(0, 6.283)
            p.obox((math.cos(a) * d, sz * 0.3, math.sin(a) * d), (math.cos(b), 0, math.sin(b)), UP, sz * 1.6, sz,
                   sz * 0.7, rng.choice(("trim", "dark", "rubber", "steel")))

    return build


def no_details(p):
    pass


def run(build_file, scrap_id, footprint, seed):
    s = footprint * 8.0
    unit.run(build_file, scrap_id, "scrap", footprint=1,
             pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_for(footprint, seed), no_details)],
             budget=800 + 700 * footprint, tex=512 if footprint < 3 else 1024, preview_size=s,
             previews=[("35", (-0.75 * s, 0.6 * s, 0.85 * s), (0, 0.4, 0), 50),
                       ("side", (-1.25 * s, 0.22 * s, 0.2 * s), (0, 0.6, 0), 50),
                       ("80", (0, 1.25 * s, 0.25 * s), (0, 0, 0), 50)])
