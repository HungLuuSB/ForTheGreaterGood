"""Detail kit for the defence towers (S-157 meshes, the user's 2026-10-24 review:
"more detail than the blockouts: panel lines, vents, cable runs, base skirts").
Small helpers on top of lib.Piece, mech and unit, all in Roblox model space."""

import math

import lib
from mech import cable, octagon, rect
from unit import UP, bolt, seam


def skirt_round(p, r, sides=24, kind="trim", h=0.35, flare=0.55, bolts=12):
    """A low chamfered skirt ring round a round footing at ground level, bolted."""
    p.cylinder("y", (0, h / 2, 0), r + flare, h, sides, kind, radius2=r + 0.1)
    for i in range(bolts):
        a = 2 * math.pi * (i + 0.5) / bolts
        rr = r + flare * 0.55
        n = (math.sin(a) * 0.6, 0.8, math.cos(a) * 0.6)
        bolt(p, (math.sin(a) * rr, h * 0.55, math.cos(a) * rr), n, r=0.06, h=0.04)


def skirt_square(p, half, kind="trim", h=0.35, flare=0.5, bolts=6):
    """A low chamfered skirt round a square footing at ground level, bolted along each side."""
    p.prism_y(rect(0, 0, half + flare, half + flare), 0.0, h, kind, bevel=0.04, top_scale=(half + 0.1) / (half + flare))
    s = half + flare * 0.5
    for side in range(4):
        for i in range(bolts):
            t = -s + 2 * s * (i + 0.5) / bolts
            x, z, n = [(t, -s, (0, 0.8, -0.6)), (t, s, (0, 0.8, 0.6)), (-s, t, (-0.6, 0.8, 0)), (s, t, (0.6, 0.8, 0))][side]
            bolt(p, (x, h * 0.6, z), n, r=0.06, h=0.04)


def band_round(p, y, r, segments=16, cx=0.0, cz=0.0):
    """A panel line round the side of a round column at height y."""
    for i in range(segments):
        a0, a1 = 2 * math.pi * i / segments, 2 * math.pi * (i + 1) / segments
        am = (a0 + a1) / 2
        seam(p, (cx + math.sin(a0) * r, y, cz + math.cos(a0) * r), (cx + math.sin(a1) * r, y, cz + math.cos(a1) * r),
             (math.sin(am), 0, math.cos(am)))


def band_box(p, y, cx, cz, hx, hz):
    """A panel line round the sides of a box column (half sizes hx, hz) at height y."""
    seam(p, (cx - hx, y, cz - hz - 0.01), (cx + hx, y, cz - hz - 0.01), (0, 0, -1))
    seam(p, (cx - hx, y, cz + hz + 0.01), (cx + hx, y, cz + hz + 0.01), (0, 0, 1))
    seam(p, (cx - hx - 0.01, y, cz - hz), (cx - hx - 0.01, y, cz + hz), (-1, 0, 0))
    seam(p, (cx + hx + 0.01, y, cz - hz), (cx + hx + 0.01, y, cz + hz), (1, 0, 0))


def band_octagon(p, y, r, cut):
    """A panel line round the sides of a mech.octagon(r, cut) column at height y."""
    for (mx, mz), n, w in octagon_faces(r, cut):
        t = (-n[2], 0.0, n[0])
        seam(p, (mx - t[0] * w / 2 + n[0] * 0.01, y, mz - t[2] * w / 2 + n[2] * 0.01),
             (mx + t[0] * w / 2 + n[0] * 0.01, y, mz + t[2] * w / 2 + n[2] * 0.01), n)


def vertical_seam(p, a, b, n):
    seam(p, a, b, n)


def louver(p, center, u, n, w, h, slats=4):
    """A vent: a dark recess with angled slats across it."""
    c, u_, n_ = lib.vec(center), lib.vec(u).normalized(), lib.vec(n).normalized()
    up = n_.cross(u_)
    p.obox(tuple(c), tuple(u_), tuple(n_), w, h, 0.05, "grille")
    for i in range(slats):
        y = -h / 2 + h * (i + 0.5) / slats
        sc = c + up * y + n_ * 0.05
        tilt = (n_ * 0.7 - up * 0.7).normalized()
        p.obox(tuple(sc), tuple(u_), tuple(tilt), w * 0.92, 0.04, h / slats * 0.9, "dark")


def clamped_cable(p, pts, r=0.09, kind="dark", clamp="steel"):
    """A cable run with a clamp at each inner point."""
    cable(p, pts, r=r, kind=kind)
    for q in pts[1:-1]:
        p.box(q, (r * 3.2, r * 3.2, r * 3.2), clamp, bevel=0.01)


def glow_strip(p, a, b, n, width=0.12):
    """A running-light strip from a to b on a surface facing n (faction glow, `light`)."""
    a_, b_ = lib.vec(a), lib.vec(b)
    p.obox(tuple((a_ + b_) / 2), tuple(b_ - a_), n, (b_ - a_).length, width, 0.05, "light")


def antenna(p, base, height, r=0.05, tip="light"):
    x, y, z = base
    p.cylinder("y", (x, y + height / 2, z), r, height, 6, "steel")
    p.box((x, y + height + 0.08, z), (0.16, 0.16, 0.16), tip)


def octagon_faces(r, cut):
    """Outward normals and face centres (x, z) of mech.octagon(r, cut)'s eight faces."""
    pts = octagon(r, cut)
    out = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        ln = math.hypot(mx, mz) or 1.0
        out.append(((mx, mz), (mx / ln, 0.0, mz / ln), math.hypot(b[0] - a[0], b[1] - a[1])))
    return out


__all__ = ["skirt_round", "skirt_square", "band_round", "band_box", "band_octagon", "vertical_seam", "louver", "clamped_cable",
           "glow_strip", "antenna", "octagon_faces", "UP"]
