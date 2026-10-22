"""Lancer (Order light tank, T1): mesh, textures, rig data.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/ord_lancer/build.py

Writes assets/models/ord_lancer/export/: ord_lancer.fbx (base_bar, turret_bar,
barrel_bar and the emissive_probe quad), the textures (ord_lancer_bar_ALB /
_RGH, ord_lancer_NOR / _MTL / _EMI), rig.json and preview_*.png. Roblox model
space throughout (docs/contracts/rig.md): +X right, +Y up, forward = -Z, studs.
Look: docs/art/style-guide.md (M-15: BAR model style on Leopard 2 lines; Order
reads heavy, M-14): painted sand-grey metal, panel lines and edge highlights,
bold team plates on the turret roof, hull top and side plates, cyan emissive
sensors; turret and gun oversized for the RTS camera.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

import bpy  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402

UNIT = "ord_lancer"
OUT = os.path.join(HERE, "export")
TEX = 1024
BUDGET = 4000  # triangles, whole unit (M-12)
FOOTPRINT = 1  # cells of 8 studs (unit def)
SAMPLES = 32
# upload revisions: 1 = the first upload's metalness map broke (HTTP 502) and
# the importer reused it; 2 = review 2026-10-22 color fix; 3 = its brightness pass
lib.UPLOAD_REV = 3

KINDS = ["paint", "trim", "team", "seam", "track", "steel", "rubber", "glass", "light", "grille", "dark"]

# Order sand-grey (style guide, M-16 blockout hull (178, 174, 160)), a touch
# warmer so the rendered mesh matches the rendered blockout (review
# 2026-10-22: it read near-white with a blue tint). Measured side by side in
# Studio (M-18): (174, 168, 150) with ao 0.58 drew 16% darker than the
# blockout with the same hue, so the paint is a little lighter again.
PAINT = (184, 178, 160)
ACCENT = (90, 210, 255)  # Order emissive accent
VARIANTS = {
    "bar": {"type": "paint", "base": PAINT, "chip": (214, 210, 196), "grime": PAINT},
}

SPECS = {
    # painted metal: low metalness keeps the paint light (0.25 read mid-grey)
    "paint": {"base": None, "roughness": 0.62, "metallic": 0.1, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.64},
    "trim": {"base": (112, 110, 102), "roughness": 0.5, "metallic": 0.35, "edge_mode": "highlight", "edge_wear": 0.35, "ao": 0.55},
    # team plates: the team color at full strength, a dark outline on the bevel
    "team": {"base": (40, 40, 38), "roughness": 0.45, "metallic": 0.2, "mask": "team", "wash": 0.0,
             "chip_reveal": 0.85, "crease": 0.3, "edge_mode": "highlight", "edge_wear": 0.0},
    "seam": {"base": None, "darken": 0.32, "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.45},
    "track": {"base": (66, 66, 64), "roughness": 0.5, "metallic": 0.6, "edge_mode": "highlight", "edge_wear": 0.4, "bump": "tread"},
    "steel": {"base": (150, 150, 146), "roughness": 0.35, "metallic": 0.85, "edge_mode": "highlight", "edge_wear": 0.3},
    "rubber": {"base": (34, 34, 33), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0},
    "glass": {"base": (18, 26, 32), "roughness": 0.1, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.85},
    "light": {"base": (215, 240, 250), "roughness": 0.2, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0},
    "grille": {"base": None, "darken": 0.55, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
    "dark": {"base": (50, 50, 48), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.3},
}

# Joint pivots (rig.md 2) and the muzzle, Roblox model space
TURRET_PIVOT = (0.0, 1.85, 0.3)
BARREL_PIVOT = (0.0, 2.45, -1.8)
MUZZLE = (0.0, 2.45, -8.17)

UP = (0, 1, 0)
GLACIS_N = (0, 1.85, -0.4)  # upper glacis normal (up and forward)

SKIRTS = [(-3.75, -1.9), (-1.86, 0.0), (0.04, 1.9), (1.94, 3.7)]
WHEELS = (-2.75, -1.65, -0.55, 0.55, 1.65, 2.75)
SKIRT_IN, SKIRT_OUT = 2.86, 3.1  # thick skirts (Order reads heavy)
TURRET_BODY = [(-1.85, -1.9), (1.85, -1.9), (2.1, -1.4), (2.1, 2.0), (-2.1, 2.0), (-2.1, -1.4)]
TURRET_Y0, ROOF_Y = 1.85, 3.0
TOP_SCALE = 0.95


def turret_side_x(y):
    """x of the turret's sloped side at height y."""
    return 2.1 - 2.1 * (1 - TOP_SCALE) * (y - TURRET_Y0) / (ROOF_Y - TURRET_Y0)


def glacis_point(z, lift=0.0):
    """(y, z) on the upper glacis at z, lifted along its normal."""
    y = 1.85 + (z + 2.3) * (0.4 / 1.85)
    n = lib.vec(GLACIS_N).normalized()
    return (y + n.y * lift, z + n.z * lift)


# ---------------------------------------------------------------------------
# Low-poly pieces (exported)
# ---------------------------------------------------------------------------


def build_base(p):
    # lower hull between the tracks, front plate sloped
    p.prism_x([(-3.45, 0.45), (3.55, 0.45), (3.9, 0.85), (3.9, 1.3), (-4.15, 1.3)], -1.95, 1.95, "trim", bevel=0.03)
    # upper hull over the tracks, long shallow glacis
    p.prism_x([(-4.15, 1.3), (3.9, 1.3), (3.9, 1.72), (3.65, 1.85), (-2.3, 1.85), (-4.15, 1.45)], -2.85, 2.85, "paint", bevel=0.05)
    # add-on armor slab on the glacis, thick enough to read at its front edge
    a, b = glacis_point(-3.95), glacis_point(-2.45)
    a2, b2 = glacis_point(-3.95, 0.2), glacis_point(-2.45, 0.2)
    p.prism_x([(a[1], a[0]), (b[1], b[0]), (b2[1], b2[0]), (a2[1], a2[0])], -2.4, 2.4, "paint", bevel=0.05)
    # engine deck grille, rear exhaust grille
    p.box((0, 1.875, 2.7), (2.9, 0.05, 1.4), "grille")
    for z in (2.25, 2.7, 3.15):  # engine-deck exhaust slots
        p.box((0, 1.9, z), (2.6, 0.04, 0.22), "light")
    for sx in (-1, 1):  # running strips along the skirt tops
        p.box((sx * (SKIRT_OUT + 0.03), 1.72, 0.0), (0.05, 0.12, 7.2), "light")
    p.box((0, 1.05, 3.915), (2.6, 0.4, 0.05), "light")  # exhaust (engine heat)
    # team color: plates on the hull top either side of the turret
    for sx in (-1, 1):
        p.box((sx * 2.47, 1.88, 0.75), (0.62, 0.06, 5.2), "team", bevel=0.015)
    # driver's hatch, sensor strip, head and tail lights (emissive)
    p.cylinder("y", (0.75, 1.88, -2.05), 0.28, 0.06, 10, "trim")
    p.box((0, 1.33, -4.17), (3.4, 0.12, 0.06), "light")  # glacis light bar
    for sx in (-1, 1):
        p.box((sx * 2.3, 1.52, -3.96), (0.55, 0.2, 0.12), "head")
        p.box((sx * 2.45, 1.52, 3.925), (0.5, 0.16, 0.06), "light")
    # thick side skirts in four panels down over the wheels; the front one cut back
    for sx in (-1, 1):
        x0, x1 = (SKIRT_IN, SKIRT_OUT) if sx > 0 else (-SKIRT_OUT, -SKIRT_IN)
        for i, (z0, z1) in enumerate(SKIRTS):
            if i == 0:
                prof = [(z0 + 0.5, 0.55), (z1, 0.55), (z1, 1.8), (z0, 1.8), (z0, 1.1)]
            else:
                prof = [(z0, 0.55), (z1, 0.55), (z1, 1.8), (z0, 1.8)]
            p.prism_x(prof, x0, x1, "paint", bevel=0.04)
        # team side plate along the middle panels
        p.box((sx * (SKIRT_OUT + 0.025), 1.5, 0.0), (0.05, 0.36, 3.6), "team", bevel=0.012)
    # tracks: a band round the sprocket (rear) and the idler (front)
    outline = [(-3.15, 0.0), (3.45, 0.0)]
    outline += lib.outline_circle(3.45, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-3.5, 1.0)]
    outline += lib.outline_circle(-3.5, 0.6, 0.4, 90, 210, 5)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (2.1, 2.84) if sx > 0 else (-2.84, -2.1)
        p.band_x(outline, inner, x0, x1, "track")
        for z in WHEELS:
            p.cylinder("x", (sx * 2.47, 0.46, z), 0.4, 0.34, 12, "rubber", cap_kinds=("trim", "trim"))
            p.cylinder("x", (sx * 2.47, 0.46, z), 0.14, 0.42, 8, "steel")
        p.cylinder("x", (sx * 2.47, 0.5, 3.45), 0.42, 0.46, 12, "steel")
        p.cylinder("x", (sx * 2.47, 0.6, -3.5), 0.32, 0.46, 12, "steel")


def build_turret(p):
    p.prism_y(TURRET_BODY, TURRET_Y0, ROOF_Y, "paint", bevel=0.06, top_scale=TOP_SCALE)
    # armored bustle and its stowage rack
    p.prism_y([(-1.8, 2.0), (1.8, 2.0), (1.65, 3.15), (-1.65, 3.15)], 1.95, 2.88, "paint", bevel=0.05, top_scale=0.95)
    p.box((0, 2.32, 3.36), (2.9, 0.56, 0.42), "grille", bevel=0.02)
    # thick arrowhead add-on armor either side of the gun (Leopard 2A6 lines)
    for sx in (-1, 1):
        v = [(sx * 1.98, 1.9, -1.9), (sx * 0.52, 1.9, -1.9), (sx * 0.52, 1.9, -2.8),
             (sx * 1.98, 2.92, -1.9), (sx * 0.52, 2.92, -1.9), (sx * 0.52, 2.5, -2.8)]
        f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        p._shell(v, f, "paint", bevel=0.05)
    # team color: a big raised roof plate
    p.box((0, ROOF_Y + 0.03, 0.05), (3.2, 0.06, 2.9), "team", bevel=0.02)
    # commander's panoramic sight (emissive optics)
    p.cylinder("y", (-1.15, 3.15, 1.2), 0.13, 0.32, 8, "dark")
    p.box((-1.15, 3.42, 1.2), (0.52, 0.34, 0.46), "trim", bevel=0.03)
    p.box((-1.15, 3.44, 0.955), (0.44, 0.2, 0.04), "light")
    # gunner's sight
    p.box((1.15, 3.18, -1.3), (0.62, 0.36, 0.66), "trim", bevel=0.03)
    p.box((1.15, 3.2, -1.645), (0.5, 0.2, 0.04), "light")
    # remote weapon station
    p.box((0.9, 3.17, 1.55), (0.5, 0.3, 0.5), "trim", bevel=0.03)
    p.cylinder("z", (0.9, 3.24, 1.0), 0.06, 0.65, 6, "dark")
    # commander's hatch
    p.cylinder("y", (-1.1, ROOF_Y + 0.04, 1.75), 0.3, 0.08, 10, "trim")
    # sensor strips (emissive), active protection launchers, antennas
    for sx in (-1, 1):
        p.box((sx * (turret_side_x(2.55) + 0.015), 2.55, -0.3), (0.04, 0.16, 2.6), "light")
        p.box((sx * 2.25, 2.45, 1.45), (0.3, 0.46, 0.56), "trim", bevel=0.03)
        p.box((sx * 2.27, 2.52, 0.55), (0.24, 0.28, 0.5), "dark")
        p.cylinder("y", (sx * 1.45, 3.35, 2.75), 0.03, 0.7, 4, "dark")
    p.box((0, 2.45, 3.6), (2.2, 0.16, 0.05), "light")


def build_barrel(p):
    y = BARREL_PIVOT[1]
    p.box((0, y, -2.1), (1.05, 0.78, 0.62), "paint", bevel=0.06)  # mantlet
    # oversized thermal sleeve in two sections with clamp bands
    p.cylinder("z", (0, y, -3.3), 0.245, 1.8, 16, "paint")
    p.cylinder("z", (0, y, -6.25), 0.235, 2.5, 16, "paint")
    for z in (-2.55, -3.3, -4.05, -5.3, -6.25, -7.2):
        p.cylinder("z", (0, y, z), 0.262 if z > -4.2 else 0.252, 0.08, 16, "steel")
    # bore evacuator
    p.cylinder("z", (0, y, -4.29), 0.33, 0.18, 16, "paint", radius2=0.245)
    p.cylinder("z", (0, y, -4.7), 0.33, 0.64, 16, "paint")
    p.cylinder("z", (0, y, -4.7), 0.345, 0.09, 16, "steel")
    p.cylinder("z", (0, y, -5.11), 0.235, 0.18, 16, "paint", radius2=0.33)
    # muzzle: a thicker end, a chamfered lip and the bore
    p.cylinder("z", (0, y, -7.56), 0.26, 0.14, 16, "paint", radius2=0.235)
    p.cylinder("z", (0, y, -7.83), 0.265, 0.4, 16, "paint")
    p.cylinder("z", (0, y, -8.08), 0.22, 0.12, 16, "steel", cap_kinds=("dark", "steel"), radius2=0.265)
    p.cylinder("z", (0, y, -8.13), 0.13, 0.05, 12, "dark")
    p.cylinder("z", (0, y, -7.3), 0.272, 0.12, 16, "weapon")  # muzzle ring
    p.cylinder("z", (0, y, -4.7), 0.352, 0.14, 16, "weapon")  # evacuator band
    p.box((0, y + 0.3, -7.7), (0.14, 0.09, 0.24), "dark")  # muzzle reference sensor
    p.box((0, y + 0.25, -6.0), (0.09, 0.05, 3.4), "weapon")  # rail strip


# ---------------------------------------------------------------------------
# Details, baked into the textures only (never exported)
# ---------------------------------------------------------------------------


def bolt(p, at, n, r=0.04, h=0.03):
    p.ocyl(at, n, r, h, 6, "steel")


def bolts(p, a, b, count, n):
    a, b = lib.vec(a), lib.vec(b)
    for i in range(count):
        t = (i + 0.5) / count
        bolt(p, tuple(a + (b - a) * t), n)


def seam(p, a, b, n, width=0.035, height=0.012):
    a, b = lib.vec(a), lib.vec(b)
    c = (a + b) / 2
    p.obox(tuple(c), tuple(b - a), n, (b - a).length, width, height * 2, "seam")


def ring(p, center, n, r, width=0.04):
    c, n_ = lib.vec(center), lib.vec(n).normalized()
    a = lib.Vector((1, 0, 0)) if abs(n_.x) < 0.9 else lib.Vector((0, 1, 0))
    u = (a - n_ * a.dot(n_)).normalized()
    v = n_.cross(u)
    k = 12
    for i in range(k):
        t0, t1 = 2 * math.pi * i / k, 2 * math.pi * (i + 1) / k
        pa = c + u * math.cos(t0) * r + v * math.sin(t0) * r
        pb = c + u * math.cos(t1) * r + v * math.sin(t1) * r
        seam(p, tuple(pa), tuple(pb), n, width)


def details_base(p):
    # glacis add-on slab: bolts along its top face
    for z in (-3.75, -2.65):
        y, zz = glacis_point(z, 0.2)
        bolts(p, (-2.1, y, zz), (2.1, y, zz), 8, GLACIS_N)
    # driver's hatch seam, hinge and periscopes
    ring(p, (0.75, 1.851, -2.05), UP, 0.33)
    p.obox((0.75, 1.92, -1.77), (1, 0, 0), UP, 0.3, 0.08, 0.05, "steel")
    for dx in (-0.22, 0, 0.22):
        p.obox((0.75 + dx, 1.9, -2.43), (1, 0, 0), UP, 0.14, 0.06, 0.08, "glass")
    # panel lines across the deck and around the grille
    for z in (1.85, 3.5):
        seam(p, (-1.6, 1.851, z), (1.6, 1.851, z), UP)
    for sx in (-1, 1):
        seam(p, (sx * 1.6, 1.851, 1.85), (sx * 1.6, 1.851, 3.5), UP)
        p.ocyl((sx * 1.6, 0.8, 3.9), (0, 0, 1), 0.09, 0.12, 8, "steel")
    # skirts: bolts along the top, a stiffening rib along each panel
    for sx in (-1, 1):
        x = sx * SKIRT_OUT
        for z0, z1 in SKIRTS:
            bolts(p, (x, 1.7, z0), (x, 1.7, z1), 4, (sx, 0, 0))
            seam(p, (x, 0.85, z0 + 0.15), (x, 0.85, z1 - 0.15), (sx, 0, 0), width=0.05, height=0.015)


def details_turret(p):
    # roof edge weld line (outside the team plate) and corner bolts
    rx, rz0, rz1 = 1.85, -1.55, 1.75
    y = ROOF_Y + 0.001
    for a, b in (((-rx, y, rz0), (rx, y, rz0)), ((rx, y, rz0), (rx, y, rz1)),
                 ((rx, y, rz1), (-rx, y, rz1)), ((-rx, y, rz1), (-rx, y, rz0))):
        seam(p, a, b, UP, width=0.03)
    for corner in ((-rx, y, rz0), (rx, y, rz0), (rx, y, rz1), (-rx, y, rz1)):
        bolt(p, corner, UP)
    ring(p, (-1.1, ROOF_Y + 0.001, 1.75), UP, 0.35)
    # side armor modules: vertical seams with bolts
    for sx in (-1, 1):
        for z in (-1.0, 0.1, 1.2):
            a = (sx * turret_side_x(1.97), 1.97, z)
            b = (sx * turret_side_x(2.9), 2.9, z)
            seam(p, a, b, (sx, 0, 0))
            bolt(p, (sx * turret_side_x(2.05), 2.05, z + 0.12), (sx, 0, 0))
            bolt(p, (sx * turret_side_x(2.85), 2.85, z + 0.12), (sx, 0, 0))
    # cheek armor: bolts along the back edge of each top face
    for sx in (-1, 1):
        a = lib.vec((sx * 1.98, 2.92, -1.9))
        b = lib.vec((sx * 0.52, 2.92, -1.9))
        c = lib.vec((sx * 0.52, 2.5, -2.8))
        n = (b - a).cross(c - a)
        if n.y < 0:
            n = -n
        off = (c - b).normalized() * 0.15
        for t in (0.2, 0.5, 0.8):
            bolt(p, tuple(a + (b - a) * t + off), tuple(n))
    bolts(p, (-1.35, 2.881, 2.55), (1.35, 2.881, 2.55), 5, UP)


def details_barrel(p):
    y = BARREL_PIVOT[1]
    for dx in (-0.36, 0.36):
        for dy in (-0.26, 0.26):
            bolt(p, (dx, y + dy, -2.41), (0, 0, -1))


# ---------------------------------------------------------------------------


unit.run(
    __file__, UNIT, "order", footprint=FOOTPRINT,
        pieces=[
            unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
            unit.PieceSpec("turret", "base", TURRET_PIVOT, build_turret, details_turret),
            unit.PieceSpec("barrel", "turret", BARREL_PIVOT, build_barrel, details_barrel),
        ],
        attachments={"muzzle": {"parent": "barrel", "at": list(MUZZLE)}},
        previews=[
            ("35", (-14, 11, 17), (0, 1.5, -0.5), 50),
            ("side", (19, 3, -2.0), (0, 1.6, -2.0), 50),
            ("80", (0, 27, 4.8), (0, 1.5, 0), 50),
            ("close", (-5.8, 4.6, -7.0), (0, 2.1, -1.8), 35),
        ],
)
