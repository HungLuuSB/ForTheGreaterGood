"""Shared shapes for the walking mechs (the Commanders, M-32): plates and
under-frame along a limb segment, pistons, joints and cable runs. Points are
Roblox model space (+Y up, forward -Z), as lib.Piece takes them."""

import lib
from unit import bolts

X = (1, 0, 0)


def v(t):
    return lib.vec(t)


def seg(p, a, b, width, depth, kind, offset=0.0, pad=0.0, bevel=0.05):
    """A box along a -> b (a limb segment in a plane of constant x): `width`
    across X, `depth` across the limb, pushed `offset` towards its front
    (the side facing -Z for a downward limb); `pad` lengthens both ends."""
    a, b = v(a), v(b)
    u = b - a
    front = v(X).cross(u.normalized())
    if front.z > 0:
        front = -front
    c = (a + b) / 2 + front * offset
    p.obox(tuple(c), tuple(u), X, u.length + pad * 2, depth, width, kind, bevel=bevel)
    return front


def plate_on(p, a, b, t0, t1, width, kind, front_offset, thickness=0.05, x_off=0.0):
    """A thin plate on a segment's front between shares t0..t1 of its length."""
    a, b = v(a), v(b)
    u = b - a
    front = v(X).cross(u.normalized())
    if front.z > 0:
        front = -front
    c = a + u * ((t0 + t1) / 2) + front * front_offset + v((x_off, 0, 0))
    p.obox(tuple(c), tuple(u), tuple(front), u.length * (t1 - t0), width, thickness, kind, bevel=0.01)


def piston(p, a, b, r=0.09, sleeve="trim", rod="steel"):
    """A hydraulic piston: a thick sleeve over the first half, a rod over
    the rest, small eyes at both ends."""
    a, b = v(a), v(b)
    u = b - a
    p.ocyl(tuple(a), tuple(u), r * 1.6, u.length * 0.55, 8, sleeve)
    p.ocyl(tuple(a + u * 0.5), tuple(u), r, u.length * 0.5, 6, rod)
    for e in (a, b):
        p.cylinder("x", tuple(e), r * 1.4, r * 2.4, 6, "steel")


def joint(p, center, r, length, kind="steel", cap="trim"):
    """A joint along X: a steel drum with trim caps."""
    p.cylinder("x", center, r, length, 12, kind, cap_kinds=(cap, cap))


def cable(p, pts, r=0.045, kind="dark"):
    """A cable run through points (thin boxes)."""
    for a, b in zip(pts, pts[1:]):
        a, b = v(a), v(b)
        u = b - a
        n = u.cross(v((0, 1, 0)))
        if n.length < 1e-4:
            n = v(X)
        p.obox(tuple((a + b) / 2), tuple(u), tuple(n), u.length, r * 2, r * 2, kind)


def rivets(p, a, b, count, n):
    bolts(p, a, b, count, n)


BOX_FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


def tseg(p, a, b, w0, d0, w1, d1, kind, off0=0.0, off1=0.0, pad=0.0, bevel=0.08):
    """A tapered box along a -> b: w0 x d0 at a, w1 x d1 at b (width across
    X, depth across the limb), pushed off0 / off1 towards the limb's front
    (-Z side); `pad` lengthens both ends. The v3 mechs' armor plates."""
    a, b = v(a), v(b)
    u = b - a
    un = u.normalized()
    a, b = a - un * pad, b + un * pad
    xv = v(X)
    front = xv.cross(un)
    if front.z > 0:
        front = -front
    pts = []
    for s in (-1, 1):  # bit 2: along the limb
        c = a if s < 0 else b
        w, d, o = (w0, d0, off0) if s < 0 else (w1, d1, off1)
        for t in (-1, 1):  # bit 1: across X
            for q in (-1, 1):  # bit 0: depth
                pts.append(tuple(c + xv * (t * w / 2) + front * (o + q * d / 2)))
    return p._shell(pts, BOX_FACES, kind, bevel)


def drum(p, center, r, length, kind="steel", cap="trim", sides=18, axis="x"):
    """A round joint housing along `axis` with chamfered (rounded) ends."""
    c = v(center)
    ax = v({"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis])
    p.ocyl(tuple(c - ax * (length / 2 - r * 0.18)), tuple(ax), r, length - r * 0.36, sides, kind)
    for s in (-1, 1):
        base = c + ax * s * (length / 2 - r * 0.18)
        p.ocyl(tuple(base), tuple(ax * s), r, r * 0.18, sides, cap, radius2=r * 0.72)


def hazard(p, center, u, n, length, width, stripes=5, t=0.03):
    """Hazard striping: a dark plate with slanted warning-yellow stripes."""
    c, u_, n_ = v(center), v(u).normalized(), v(n).normalized()
    w_ = n_.cross(u_).normalized()
    p.obox(tuple(c), tuple(u_), tuple(n_), length, width, t, "dark")
    d = (u_ + w_).normalized()
    step = length / stripes
    for i in range(stripes):
        sc = c + u_ * (-length / 2 + step * (i + 0.5)) + n_ * (t * 0.6)
        p.obox(tuple(sc), tuple(d), tuple(n_), width * 1.2, step * 0.42, t, "hazard")


def arch(z0, z1, y_base, y_top, steps=7, flat=0.35):
    """A side profile (z, y): an arched shell from z0 to z1, base at y_base,
    rising to y_top; `flat` is the share of the top kept flat."""
    pts = [(z0, y_base)]
    for i in range(steps + 1):
        t = i / steps
        z = z0 + (z1 - z0) * t
        k = abs(2 * t - 1)
        k = max(0.0, (k - flat) / (1 - flat))
        pts.append((z, y_base + (y_top - y_base) * (1 - k * k) ** 0.5 if k < 1 else y_base + (y_top - y_base) * 0.0))
    pts.append((z1, y_base))
    # drop duplicate end points
    out = []
    for q in pts:
        if not out or abs(out[-1][0] - q[0]) > 1e-6 or abs(out[-1][1] - q[1]) > 1e-6:
            out.append(q)
    return out


def octagon(r, cut, cx=0.0, cz=0.0):
    """Top-view octagon (x, z): a square of half-size r with corners cut by
    `cut` (structure slabs and housings at the size scale, S-104)."""
    pts = [(-r + cut, -r), (r - cut, -r), (r, -r + cut), (r, r - cut), (r - cut, r), (-r + cut, r), (-r, r - cut), (-r, -r + cut)]
    return [(cx + x, cz + z) for x, z in pts]


def rect(cx, cz, hx, hz):
    """Top-view rectangle (x, z) centred on (cx, cz)."""
    return [(cx - hx, cz - hz), (cx + hx, cz - hz), (cx + hx, cz + hz), (cx - hx, cz + hz)]
