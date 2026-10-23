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
