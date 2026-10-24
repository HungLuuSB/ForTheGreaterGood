"""Ship hulls (the user's 2026-10-24 review of the T2 ships: "from the 55 degree camera
the hulls read as flat rectangular barges"). One lofted shell per hull: a pointed, raked
bow, flared sides, a tapered stern with a transom, a sheer line rising to the bow, a
rounded bilge and a dark boot-top below the waterline. Roblox model space, forward = -Z,
waterline at y = 0.

    deck_at(hull, z)        the deck height at z (the sheer), for placing deck fittings
    half_beam_at(hull, z)   the deck's half beam at z

Superstructure, barbettes and fittings stay in each ship's build.py.
"""

import math

from unit import UP, seam


class Hull:
    def __init__(self, length, beam, freeboard, depth, sheer_bow=1.2, sheer_stern=0.3, flare=0.22,
                 transom=0.62, rake=1.6, max_at=0.42, fine=2.2, z0=0.0):
        self.length, self.beam, self.freeboard, self.depth = length, beam, freeboard, depth
        self.sheer_bow, self.sheer_stern, self.flare, self.transom = sheer_bow, sheer_stern, flare, transom
        self.rake, self.max_at, self.fine, self.z0 = rake, max_at, fine, z0

    # t: 0 at the stern (z = z0 + L/2), 1 at the bow (z = z0 - L/2)
    def z(self, t):
        return self.z0 + self.length / 2 - t * self.length

    def t_of(self, z):
        return min(max((self.z0 + self.length / 2 - z) / self.length, 0.0), 1.0)

    def deck(self, t):
        """Sheer: the deck rises towards the bow (and a little at the stern)."""
        return self.freeboard + self.sheer_bow * max(t - 0.35, 0.0) ** 2 / 0.4225 + self.sheer_stern * max(0.25 - t, 0.0) / 0.25

    def half(self, t):
        """Deck half beam: full amidships, a transom aft, a fine pointed bow."""
        b = self.beam / 2
        m = self.max_at
        if t >= m:
            u = (t - m) / (1 - m)
            return b * max(1 - u ** self.fine, 0.0) ** 0.75
        u = (m - t) / m
        return b * (self.transom + (1 - self.transom) * (1 - u ** 2.4))


def deck_at(hull, z):
    return hull.deck(hull.t_of(z))


def half_beam_at(hull, z):
    return hull.half(hull.t_of(z))


def hull(p, h, stations=26, paint="paint", boot="dark", rail="trim", deck="trim", strake=True):
    """Builds the hull shell. Faces: deck `deck`, topsides `paint`, a sheer strake
    along the deck edge `rail`, the boot-top and bottom `boot`."""
    ts = [i / stations for i in range(stations + 1)]
    ts[-1] = 0.995  # a thin stem rather than a single point (keeps faces valid)
    rings, kinds_of_band = [], []
    for t in ts:
        bd = max(h.half(t), 0.04)  # deck half beam
        flare = h.flare * (0.6 + 0.8 * max(t - 0.5, 0.0))  # more flare forward
        bw = bd * (1 - flare)  # waterline half beam
        dk = h.deck(t)
        dep = h.depth * (0.55 + 0.45 * min(1.0, 4 * min(t, 1 - t) + 0.3))  # shallower at the ends
        # one side, keel to deck edge: (x, y, height fraction for the rake)
        side = [(0.0, -dep), (0.42 * bw, -dep * 0.93), (0.86 * bw, -dep * 0.55), (bw, -0.12),
                (bw + (bd - bw) * 0.55, dk * 0.5), (bd - 0.02, dk - 0.28), (bd, dk)]
        # the raked stem: near the bow the lower points sit further aft
        rk = h.rake * max(t - 0.78, 0.0) / 0.22
        ring = []
        for x, y in side:
            frac = (y + dep) / (dk + dep)
            ring.append((x, y, h.z(t) + rk * (1 - frac)))
        left = [(-x, y, z) for x, y, z in reversed(ring[1:])]
        rings.append(ring + left)
    n = len(rings[0])
    verts, faces, kinds = [], [], []
    for r in rings:
        verts.extend(r)
    # band kinds round the ring: side bands 0..5 (keel->deck edge), the deck, then mirrored
    half_kinds = [boot, boot, boot, paint, paint, rail if strake else paint]
    ring_kinds = half_kinds + [deck] + list(reversed(half_kinds))
    for s in range(len(rings) - 1):
        a, b = s * n, (s + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append([a + i, a + j, b + j, b + i])
            kinds.append(ring_kinds[i])
    # transom (stern) and stem caps
    faces.append(list(range(0, n)))
    kinds.append(paint)
    last = (len(rings) - 1) * n
    faces.append(list(range(last, last + n)))
    kinds.append(paint)
    p._shell(verts, faces, paint, kinds=kinds)
    return h


def hull_details(p, h, every=4.0):
    """Plating seams across the deck and down the topsides (baked into the normal map)."""
    z = h.z0 - h.length / 2 + every
    while z < h.z0 + h.length / 2 - 1.0:
        t = h.t_of(z)
        b, d = h.half(t), h.deck(t)
        if b > 0.6:
            seam(p, (-b + 0.15, d + 0.001, z), (b - 0.15, d + 0.001, z), UP)
            for sx in (-1, 1):
                seam(p, (sx * (b + 0.005), d - 0.35, z), (sx * (b * 0.9 + 0.005), 0.15, z), (sx, 0, 0))
        z += every


def barbette(p, at, h, top, r, sides=18, kind="trim", ring="dark"):
    """A round barbette from the deck at `at` (x, z) up to `top`, so a turret stands raised."""
    x, z = at
    base = deck_at(h, z) - 0.2
    p.cylinder("y", (x, (base + top) / 2, z), r, top - base, sides, kind, bevel=0.04)
    p.cylinder("y", (x, top - 0.04, z), r + 0.12, 0.08, sides, ring)


def deck_strip(p, h, z_from, z_to, inset, kind="light", y_off=0.04, width=0.12, step=1.5):
    """Running-light strip along both deck edges, following the sheer."""
    z = z_from
    while z < z_to - 0.01:
        z2 = min(z + step, z_to)
        for sx in (-1, 1):
            b1, b2 = half_beam_at(h, z) - inset, half_beam_at(h, z2) - inset
            y1, y2 = deck_at(h, z) + y_off, deck_at(h, z2) + y_off
            cx, cy, cz = sx * (b1 + b2) / 2, (y1 + y2) / 2, (z + z2) / 2
            dx, dy, dz = sx * (b2 - b1), y2 - y1, z2 - z
            ln = math.sqrt(dx * dx + dy * dy + dz * dz)
            p.obox((cx, cy, cz), (dx, dy, dz), UP, ln, width, 0.05, kind)
        z = z2
