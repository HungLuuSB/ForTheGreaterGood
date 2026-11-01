"""Shared parts for the batch 2 bots' meshes (the BAR roster, 2026-11-01):
the spider leg kit at the same points as Blockouts/Bots.luau `Bots.spider`
(so the client swings both alike), and the small pieces every bot reuses:
guns, tube grids, visors, shoulder pads, builder arms. The biped legs are
tools/bots.py.

    import botkit as k
    pieces = [...] + k.spider(6, hip_r=0.9, hip_y=2.2, knee_r=2.3, knee_y=3.7, foot_r=3.4, thick=0.3, faction="order")
"""

import math

import bots
import lib
import unit
from mech import drum, piston, rivets
from unit import seam

FWD = (0, 0, -1)
UP = (0, 1, 0)
V = lib.vec

SPIDER_YAWS = {
    4: [("FL", 225), ("FR", 135), ("BL", 315), ("BR", 45)],
    6: [("FL", 215), ("ML", 270), ("BL", 325), ("FR", 145), ("MR", 90), ("BR", 35)],
}


def at(yaw, r, y):
    a = math.radians(yaw)
    return (math.sin(a) * r, y, math.cos(a) * r)


def beam(p, a, b, w, d, kind, bevel=0.03):
    """A box from a to b, w wide (horizontal, across) and d deep."""
    a, b = V(a), V(b)
    n = (b - a).normalized()
    u = V(UP).cross(n)
    if u.length < 1e-6:
        u = V((1, 0, 0))
    u = u.normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(u.cross(n)), w, (b - a).length, d, kind, bevel=bevel)


def spider_points(hip_r, hip_y, knee_r, knee_y, foot_r):
    ankle_r = knee_r + (foot_r - knee_r) * 0.8
    return ankle_r, knee_y * 0.3


def spider(legs, hip_r, hip_y, knee_r, knee_y, foot_r, thick, faction, team=True):
    """PieceSpecs `thigh<tag>` (hip to the high knee) and `shin<tag>` (knee
    down to the ankle and a claw to the ground), Bots.spider's points.
    Order legs are armoured with a team stripe and lit edges; Chaos legs
    bare struts with a piston and a hooked claw (M-14)."""
    t = thick
    ankle_r, ankle_y = spider_points(hip_r, hip_y, knee_r, knee_y, foot_r)
    specs = []
    for tag, yaw in SPIDER_YAWS[legs]:
        hip, knee = at(yaw, hip_r, hip_y), at(yaw, knee_r, knee_y)
        ankle, foot = at(yaw, ankle_r, ankle_y), at(yaw, foot_r, 0.02)

        def thigh(p, hip=hip, knee=knee, yaw=yaw):
            drum(p, hip, t * 0.75, t * 1.1, "steel", "trim", sides=12, axis="y")
            if faction == "order":
                beam(p, hip, knee, t * 1.1, t * 1.2, "paint", bevel=0.05)
                if team:
                    beam(p, at(yaw, hip_r + 0.15, hip_y + t * 0.62), at(yaw, knee_r - 0.2, knee_y + t * 0.62), t * 0.6, 0.06, "team", bevel=0.01)
                beam(p, at(yaw, hip_r + 0.3, hip_y - t * 0.62), at(yaw, knee_r - 0.3, knee_y - t * 0.62), 0.06, 0.05, "light", bevel=0.0)
            else:
                beam(p, hip, knee, t * 0.8, t * 0.95, "trim", bevel=0.04)
                beam(p, at(yaw, hip_r + 0.1, hip_y + t * 0.5), at(yaw, knee_r - 0.15, knee_y + t * 0.5), t * 0.55, t * 0.3, "paint", bevel=0.03)
                piston(p, at(yaw, hip_r + 0.3, hip_y - t * 0.55), at(yaw, knee_r - 0.4, knee_y - t * 0.4), r=t * 0.16)
            drum(p, knee, t * 0.62, t * 1.15, "steel", "trim", sides=12, axis="y")

        def shin(p, knee=knee, ankle=ankle, foot=foot, yaw=yaw):
            if faction == "order":
                beam(p, knee, ankle, t * 0.95, t * 1.05, "paint", bevel=0.05)
                beam(p, at(yaw, knee_r + 0.12, knee_y - 0.35), at(yaw, ankle_r - 0.05, ankle_y + 0.5), 0.06, t * 0.5, "trim", bevel=0.0)
            else:
                beam(p, knee, ankle, t * 0.7, t * 0.85, "paint", bevel=0.04)
                p.ocyl(at(yaw, knee_r, knee_y + t * 0.5), UP, t * 0.28, t * 1.1, 6, "steel", radius2=0.02)  # a knee spike
                p.box(at(yaw, knee_r + 0.1, knee_y - 0.6), (0.1, 0.07, 0.1), "light")
            drum(p, ankle, t * 0.42, t * 0.9, "steel", "trim", sides=10, axis="y")
            a, f = V(ankle), V(foot)
            p.ocyl(tuple(a), tuple((f - a).normalized()), t * 0.36, (f - a).length, 8, "dark" if faction == "order" else "steel",
                   radius2=0.03)  # the claw

        none = lambda p: None  # noqa: E731
        specs += [unit.PieceSpec(f"thigh{tag}", "base", hip, thigh, none),
                  unit.PieceSpec(f"shin{tag}", f"thigh{tag}", knee, shin, none)]
    return specs


def biped(hip_y, hip_x, thick, faction, team=True, foot_scale=1.0):
    return bots.legs(hip_y, hip_x, thick, faction, team=team, foot_scale=foot_scale)


def gun(p, x, y, z0, length, r, kind="steel", mouth="trim", glow=True, sides=12):
    """A barrel along -Z from z0, a muzzle collar and (glow) a lit bore; returns the mouth's z."""
    p.ocyl((x, y, z0), FWD, r, length, sides, kind)
    z = z0 - length
    p.ocyl((x, y, z + 0.2), FWD, r * 1.3, 0.24, sides, mouth)
    if glow:
        p.ocyl((x, y, z - 0.03), FWD, r * 0.7, 0.03, sides, "weapon")
    return z - 0.1


def tubes(p, cx, cy, z, cols, rows, pitch, r, kind="weapon", rim="dark", sides=10):
    """A grid of tube mouths on a face at depth z, facing -Z."""
    for i in range(cols):
        for j in range(rows):
            x = cx + (i - (cols - 1) / 2) * pitch
            y = cy + (j - (rows - 1) / 2) * pitch
            p.ocyl((x, y, z + 0.06), FWD, r * 1.15, 0.06, sides, rim)
            p.ocyl((x, y, z + 0.04), FWD, r, 0.05, sides, kind)


def tilted_tubes(p, center, n, u, cols, rows, pitch, r, kind="weapon", rim="dark"):
    """Tube mouths on a face with normal n, rows along u (both unit vectors)."""
    c, n, u = V(center), V(n).normalized(), V(u).normalized()
    v = n.cross(u).normalized()
    for i in range(cols):
        for j in range(rows):
            q = c + u * ((i - (cols - 1) / 2) * pitch) + v * ((j - (rows - 1) / 2) * pitch)
            p.ocyl(tuple(q - n * 0.06), tuple(n), r * 1.15, 0.06, 10, rim)
            p.ocyl(tuple(q - n * 0.04), tuple(n), r, 0.05, 10, kind)


def visor(p, center, w, h, kind="head", frame="dark"):
    x, y, z = center
    p.box((x, y, z + 0.01), (w + 0.12, h + 0.12, 0.03), frame)
    p.box((x, y, z - 0.01), (w, h, 0.03), kind)


def head(p, center, size, faction, visor_w=None):
    """A sensor head: Order a bevelled box with a lit visor band; Chaos a
    low wedge with an eye slit."""
    x, y, z = center
    w, h, d = size
    if faction == "order":
        p.box(center, size, "paint", bevel=min(w, h, d) * 0.12)
        p.box((x, y + h / 2 + 0.02, z + d * 0.1), (w * 0.6, 0.04, d * 0.5), "team")
        visor(p, (x, y + h * 0.08, z - d / 2 - 0.02), visor_w or w * 0.72, h * 0.26)
    else:
        p.prism_x([(z - d / 2, y - h / 2), (z + d / 2, y - h / 2), (z + d / 2, y + h / 2), (z - d * 0.15, y + h / 2),
                   (z - d / 2, y + h * 0.1)], x - w / 2, x + w / 2, "paint", bevel=0.04)
        visor(p, (x, y - h * 0.05, z - d / 2 - 0.02), visor_w or w * 0.6, h * 0.16)


def shell(p, center, size, faction, team_face=None):
    """The main armoured box: bevelled (Order) or chamfered with a raised
    plate (Chaos), seams on its sides."""
    x, y, z = center
    w, h, d = size
    if faction == "order":
        p.box(center, size, "paint", bevel=min(w, h, d) * 0.1)
        p.box((x, y - h / 2 + 0.06, z), (w * 0.92, 0.12, d * 0.92), "trim")
    else:
        p.prism_x([(z - d / 2, y - h / 2), (z + d / 2, y - h / 2), (z + d / 2, y + h * 0.3), (z + d * 0.3, y + h / 2),
                   (z - d * 0.3, y + h / 2), (z - d / 2, y + h * 0.3)], x - w / 2, x + w / 2, "paint", bevel=0.05)
        p.box((x, y + h / 2 - 0.02, z), (w * 0.7, 0.06, d * 0.5), "trim", bevel=0.02)
    if team_face:
        tw, th, ty = team_face
        p.box((x, ty, z - d / 2 - 0.02), (tw, th, 0.04), "team", bevel=0.01)


def shell_details(p, center, size):
    x, y, z = center
    w, h, d = size
    for sx in (-1, 1):
        seam(p, (x + sx * (w / 2 + 0.005), y + h * 0.2, z - d * 0.4), (x + sx * (w / 2 + 0.005), y + h * 0.2, z + d * 0.4), (sx, 0, 0))
    rivets(p, (x - w * 0.35, y - h * 0.3, z - d / 2 - 0.01), (x + w * 0.35, y - h * 0.3, z - d / 2 - 0.01), 4, FWD)


def pad(p, center, size, faction):
    """A shoulder pad: Order a team-topped slab, Chaos a spiked wedge."""
    x, y, z = center
    w, h, d = size
    if faction == "order":
        p.box(center, size, "paint", bevel=0.08)
        p.box((x, y + h / 2 + 0.02, z), (w * 0.8, 0.04, d * 0.8), "team")
    else:
        sx = 1 if x >= 0 else -1
        p.box(center, size, "trim", bevel=0.05)
        p.box((x, y + h / 2 + 0.03, z), (w * 0.85, 0.06, d * 0.85), "paint", bevel=0.02)
        p.ocyl((x + sx * w * 0.15, y + h / 2, z), UP, w * 0.2, h * 1.1, 6, "steel", radius2=0.02)


def nano_arm(p, x, y, z, length, faction, rise=0.0):
    """A builder arm from (x, y, z) forward (and up by rise); returns the tip."""
    a, b = (x, y, z), (x, y + rise, z - length)
    drum(p, a, 0.3, 0.6, "steel", "trim")
    beam(p, a, b, 0.42, 0.42, "paint" if faction == "order" else "trim", bevel=0.05)
    if faction == "order":
        beam(p, (x, y + 0.23, z - 0.3), (x, y + rise + 0.23, z - length + 0.4), 0.22, 0.04, "team", bevel=0.0)
        p.ocyl((b[0], b[1], b[2] + 0.1), FWD, 0.3, 0.4, 12, "trim")
        p.ocyl((b[0], b[1], b[2] - 0.28), FWD, 0.22, 0.1, 12, "power")
    else:
        piston(p, (x, y - 0.3, z - 0.2), (x, y + rise - 0.25, z - length * 0.7), r=0.07)
        for s in (-1, 1):
            p.prism_x([(b[2] + 0.1, b[1] - 0.25), (b[2] - 0.55, b[1] - 0.05), (b[2] - 0.55, b[1] + 0.05), (b[2] + 0.1, b[1] + 0.25)],
                      b[0] + s * 0.2 - 0.06, b[0] + s * 0.2 + 0.06, "steel", bevel=0.01)
        p.ocyl((b[0], b[1], b[2] - 0.15), FWD, 0.15, 0.08, 10, "power")
    return (b[0], b[1], b[2] - 0.4)


def blob(p, center, r, length, kind, slices=8, sides=16):
    """A rounded sac along Z: stacked frustums following an ellipse, radius r,
    `length` long (the crawling bombs' charges)."""
    x, y, z = center
    half = length / 2
    zs = [-half + length * i / slices for i in range(slices + 1)]

    def rad(zz):
        return r * math.sqrt(max(1 - (zz / half) ** 2, 0.004))

    for z0, z1 in zip(zs, zs[1:]):
        p.ocyl((x, y, z + z0), (0, 0, 1), rad(z0), z1 - z0, sides, kind, radius2=rad(z1))


def previews(height, width=None):
    """bots.previews framed on the bigger of the bot's height and (for the
    wide spiders) its spread."""
    return bots.previews(max(height, (width or 0) * 0.65))
