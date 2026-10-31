"""Shared runner for BAR-style unit and structure meshes (docs/art/pipeline.md,
M-15, M-18): the faction paints, the bake, the previews, the FBX and rig.json.
A unit's build.py describes only its geometry:

    import unit
    unit.run(__file__, "ord_extractor", "order", footprint=1,
             pieces=[unit.PieceSpec("base", None, (0, 0, 0), build_base, details_base)])

Faction looks follow the approved tanks (ord_lancer, chs_ravager): Order
sand-grey paint with cyan accents, Chaos gunmetal with orange accents; team
plates are a `team` kind under the color map's alpha (rig.md 6).
"""

import contextlib
import math
import os
from dataclasses import dataclass, field

import bpy

import anchors
import animate
import lib

KINDS = ["paint", "trim", "team", "seam", "era", "track", "steel", "rubber", "glass", "light", "grille", "dark",
         "head", "power", "weapon", "radome", "hazard"]

# Glow (the emissive pass, 2026-10-22; docs/contracts/fx.md "Unit glow"): every
# glowing face is one of four kinds, and each kind becomes its own small
# MeshPart per piece after the bake (`<piece>_glow_<channel>`), so the client
# can drive the channels apart. Glow faces are near-white in the color map;
# the color comes from the part's EmissiveTint. Never team-colored.
GLOW_KINDS = {"light": "running", "head": "head", "power": "power", "weapon": "weapon"}
GLOW_ALBEDO = (240, 240, 236)
GLOW_SPEC = {"base": GLOW_ALBEDO, "roughness": 0.25, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0}

FACTIONS = {
    "order": {
        "label": "BAR-style painted sand-grey (M-15)",
        "paint": (184, 178, 160),
        "accent": (90, 210, 255),
        "team_preview": (58, 120, 230),
        # cool cyan / white
        "glow": {"running": (90, 210, 255), "head": (255, 236, 205), "power": (130, 225, 255), "weapon": (190, 240, 255)},
        "variants": {"bar": {"type": "paint", "base": (184, 178, 160), "chip": (214, 210, 196), "grime": (184, 178, 160)}},
        "specs": {
            "paint": {"base": None, "roughness": 0.62, "metallic": 0.1, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.64},
            "trim": {"base": (112, 110, 102), "roughness": 0.5, "metallic": 0.35, "edge_mode": "highlight", "edge_wear": 0.35, "ao": 0.55},
            "team": {"base": (40, 40, 38), "roughness": 0.45, "metallic": 0.2, "mask": "team", "wash": 0.0,
                     "chip_reveal": 0.85, "crease": 0.3, "edge_mode": "highlight", "edge_wear": 0.0},
            "seam": {"base": None, "darken": 0.32, "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.45},
            "era": {"base": (150, 146, 134), "roughness": 0.55, "metallic": 0.2, "edge_mode": "highlight", "edge_wear": 0.4, "ao": 0.55},
            "track": {"base": (66, 66, 64), "roughness": 0.5, "metallic": 0.6, "edge_mode": "highlight", "edge_wear": 0.4, "bump": "tread"},
            "steel": {"base": (150, 150, 146), "roughness": 0.35, "metallic": 0.85, "edge_mode": "highlight", "edge_wear": 0.3},
            "rubber": {"base": (34, 34, 33), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0},
            "glass": {"base": (18, 26, 32), "roughness": 0.1, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.85},
            "light": GLOW_SPEC, "head": GLOW_SPEC, "power": GLOW_SPEC, "weapon": GLOW_SPEC,
            "grille": {"base": None, "darken": 0.55, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
            "dark": {"base": (50, 50, 48), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.3},
            "radome": {"base": (232, 230, 222), "roughness": 0.4, "metallic": 0.0, "edge_wear": 0.05, "ao": 0.85},  # missile radomes
            "hazard": {"base": (226, 182, 36), "roughness": 0.55, "metallic": 0.1, "edge_mode": "highlight", "edge_wear": 0.5, "ao": 0.7},  # warning yellow, every faction
        },
    },
    "chaos": {
        "label": "BAR-style gunmetal (M-15)",
        "paint": (96, 100, 106),
        "accent": (255, 140, 50),
        "team_preview": (214, 62, 48),
        # hot amber / orange
        "glow": {"running": (255, 150, 55), "head": (255, 236, 205), "power": (255, 125, 35), "weapon": (255, 175, 70)},
        "variants": {"bar": {"type": "paint", "base": (96, 100, 106), "chip": (172, 178, 184), "grime": (96, 100, 106)}},
        "specs": {
            "paint": {"base": None, "roughness": 0.45, "metallic": 0.12, "edge_mode": "highlight", "edge_wear": 0.7, "ao": 0.78},
            "trim": {"base": (46, 48, 52), "roughness": 0.5, "metallic": 0.35, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.6},
            "team": {"base": (24, 24, 26), "roughness": 0.45, "metallic": 0.2, "mask": "team", "wash": 0.0,
                     "chip_reveal": 0.85, "crease": 0.3, "edge_mode": "highlight", "edge_wear": 0.0},
            "seam": {"base": None, "darken": 0.5, "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.45},
            "era": {"base": (104, 108, 112), "roughness": 0.5, "metallic": 0.25, "edge_mode": "highlight", "edge_wear": 0.55, "ao": 0.55},
            "track": {"base": (58, 58, 58), "roughness": 0.5, "metallic": 0.6, "edge_mode": "highlight", "edge_wear": 0.45, "bump": "tread"},
            "steel": {"base": (140, 142, 144), "roughness": 0.35, "metallic": 0.85, "edge_mode": "highlight", "edge_wear": 0.3},
            "rubber": {"base": (30, 30, 30), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0},
            "glass": {"base": (22, 18, 16), "roughness": 0.1, "metallic": 0.1, "edge_wear": 0.0, "ao": 0.85},
            "light": GLOW_SPEC, "head": GLOW_SPEC, "power": GLOW_SPEC, "weapon": GLOW_SPEC,
            "grille": {"base": None, "darken": 0.5, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
            "dark": {"base": (34, 35, 38), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.35},
            "radome": {"base": (232, 230, 222), "roughness": 0.4, "metallic": 0.0, "edge_wear": 0.05, "ao": 0.85},  # missile radomes
            "hazard": {"base": (226, 182, 36), "roughness": 0.55, "metallic": 0.1, "edge_mode": "highlight", "edge_wear": 0.5, "ao": 0.7},  # warning yellow, every faction
        },
    },
}

# Neutral props (deposits, M-28): no faction, no glow. The `team` kind is the
# ground patch the client tints per terrain (alpha mask, like a team plate).
_NEUTRAL_GLOW = {"running": (200, 200, 200), "head": (200, 200, 200), "power": (200, 200, 200), "weapon": (200, 200, 200)}
FACTIONS["neutral"] = {
    "label": "BAR-style neutral terrain prop (M-28)",
    "paint": (92, 88, 80),
    "accent": (200, 200, 200),
    "team_preview": (78, 96, 58),  # grass, for the previews
    "glow": _NEUTRAL_GLOW,
    "variants": {"bar": {"type": "plain", "base": (92, 88, 80), "mottle": 0.25, "chip": (120, 116, 108), "grime": (60, 56, 50)}},
    "specs": {**FACTIONS["chaos"]["specs"],
              "paint": {"base": None, "roughness": 0.85, "metallic": 0.0, "edge_wear": 0.25, "ao": 0.6},  # stone
              "dark": {"base": (74, 68, 60), "roughness": 0.9, "metallic": 0.05, "edge_wear": 0.2, "ao": 0.6},  # rock, scraped soil
              "trim": {"base": (104, 98, 88), "roughness": 0.85, "metallic": 0.0, "edge_wear": 0.3, "ao": 0.6},  # loose stones
              "steel": {"base": (128, 118, 98), "roughness": 0.32, "metallic": 0.85, "edge_mode": "highlight", "edge_wear": 0.35, "ao": 0.7},  # ore sheen
              "team": {"base": (60, 56, 50), "roughness": 0.95, "metallic": 0.0, "mask": "team", "wash": 0.08,
                       "chip_reveal": 0.15, "crease": 0.35, "edge_wear": 0.0},  # scraped ground, tinted per terrain (lighter at night: B's check)
              },
}

# Scrap heaps (S-227, part 4 of the BAR roster plan): what a wreck becomes below 40% health
# (assets/fx/scrap/). Faction-neutral, no glow: `paint` soot-stained metal, `trim` rust,
# `steel` bare scraped steel, `dark` charred debris, `rubber` burnt rubber, `team` the
# scorched ground patch, tinted to the terrain like the deposits' scrape.
FACTIONS["scrap"] = {
    "label": "BAR-style scrap heap (S-227)",
    "paint": (84, 78, 70),
    "accent": (200, 200, 200),
    "team_preview": (78, 96, 58),
    "glow": _NEUTRAL_GLOW,
    "variants": {"bar": {"type": "plain", "base": (84, 78, 70), "mottle": 0.35, "chip": (112, 106, 98), "grime": (52, 47, 42)}},
    "specs": {**FACTIONS["neutral"]["specs"],
              "paint": {"base": None, "roughness": 0.7, "metallic": 0.55, "edge_wear": 0.4, "ao": 0.55},  # sooty metal
              "trim": {"base": (118, 66, 38), "roughness": 0.85, "metallic": 0.25, "edge_wear": 0.3, "ao": 0.55},  # rust
              "steel": {"base": (138, 134, 126), "roughness": 0.38, "metallic": 0.9, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.6},  # scraped steel
              "dark": {"base": (44, 40, 36), "roughness": 0.9, "metallic": 0.15, "edge_wear": 0.15, "ao": 0.5},  # charred debris
              "rubber": {"base": (34, 32, 30), "roughness": 0.95, "metallic": 0.0, "edge_wear": 0.05, "ao": 0.5},  # burnt rubber
              },
}

# Map features (S-197): trees and rocks, reclaimable scenery (assets/fx/features/). No
# faction, no glow, no team. Trees: `paint` bark, `trim` foliage, `dark` its shade, `era`
# its sunlit tips; rocks: `steel` stone (not metal here), `rubber` its shade, `radome` the
# yellow lichen of BAR's rocks.
FACTIONS["nature"] = {
    "label": "BAR-style map features (S-197)",
    "paint": (78, 60, 44),
    "accent": (200, 200, 200),
    "team_preview": (78, 96, 58),
    "glow": _NEUTRAL_GLOW,
    "variants": {"bar": {"type": "plain", "base": (78, 60, 44), "mottle": 0.3, "chip": (98, 80, 60), "grime": (52, 40, 30)}},
    "specs": {**FACTIONS["neutral"]["specs"],
              "paint": {"base": None, "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.15, "ao": 0.6},  # bark
              "trim": {"base": (46, 74, 34), "roughness": 0.85, "metallic": 0.0, "edge_wear": 0.1, "ao": 0.55},  # foliage
              "dark": {"base": (28, 46, 26), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0, "ao": 0.5},  # foliage in shade
              "era": {"base": (84, 110, 44), "roughness": 0.85, "metallic": 0.0, "edge_wear": 0.1, "ao": 0.65},  # sunlit tips
              "steel": {"base": (92, 88, 80), "roughness": 0.9, "metallic": 0.0, "edge_mode": "highlight", "edge_wear": 0.35, "ao": 0.6},  # stone
              "rubber": {"base": (60, 57, 52), "roughness": 0.92, "metallic": 0.0, "edge_wear": 0.2, "ao": 0.55},  # stone in shade
              "radome": {"base": (128, 120, 66), "roughness": 0.9, "metallic": 0.0, "edge_wear": 0.0, "ao": 0.7},  # lichen
              },
}

UP = (0, 1, 0)

# Wrecks (queue item 5, M-24; docs/contracts/fx.md "Wrecks"): FTGG_WRECK=1
# builds the same pieces battered (lib.WRECK), darkened and sooted, with the
# glow faces as dead sockets and the team panels scorched grey, into
# export_wreck/ as <id>_wreck. Same pieces and pivots as the live mesh.
# Soot is grey-brown, not black, so wrecks read on dark grass at night; big
# structures (footprint 2+) scorch along their edges (user review 2026-10-23).
SOOT = (62, 55, 48)


def _char(c, k):
    return tuple(int(c[i] * (1 - k) + SOOT[i] * k) for i in range(3))


def wreck_look(look, edges=False):
    specs = {}
    for kind, sp in look["specs"].items():
        if kind in GLOW_KINDS:
            sp = {"base": (30, 28, 26), "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.6}
        elif kind == "team":
            sp = {"base": (86, 84, 82), "roughness": 0.6, "metallic": 0.15, "edge_mode": "highlight",
                  "edge_wear": 0.25, "ao": 0.6}
        else:
            sp = dict(sp)
            if sp.get("base"):
                sp["base"] = _char(sp["base"], 0.4)
        sp["roughness"] = min(0.95, sp["roughness"] + 0.25)
        sp["metallic"] = sp["metallic"] * 0.6
        sp["scorch"], sp["soot"], sp["grime"] = 0.7, SOOT, 0.4
        sp["scorch_edges"] = edges
        specs[kind] = sp
    paint = _char(look["paint"], 0.4)
    return {**look, "label": "BAR-style wreck (M-24)", "specs": specs,
            "variants": {"bar": {"type": "paint", "base": paint, "chip": (112, 106, 98), "grime": SOOT}}}


@dataclass
class Rec:
    """A piece in rig order (specs and their animated sub-pieces)."""
    name: str
    parent: str | None
    pivot: tuple
    anim: dict | None
    sub: bool


@dataclass
class PieceSpec:
    name: str
    parent: str | None
    pivot: tuple
    build: object
    details: object


# ---------------------------------------------------------------------------
# Detail helpers (baked into the textures only)
# ---------------------------------------------------------------------------


def lifted(fn, dy):
    """`fn` (a build or details function) with everything it adds raised by
    `dy` studs: the F18 towers keep their turrets and stand them higher."""
    import bmesh
    from mathutils import Vector

    def g(p):
        before = set(p.bm.verts)
        fn(p)
        bmesh.ops.translate(p.bm, vec=Vector((0, 0, dy)), verts=[v for v in p.bm.verts if v not in before])
    return g


@contextlib.contextmanager
def pitched(p, pivot, deg):
    """Everything built inside the `with` block is tilted `deg` degrees
    about the X axis through `pivot` (Roblox space), the front (-Z) going up:
    a raised gun (the F18 artillery towers)."""
    import bmesh
    from mathutils import Matrix

    before = set(p.bm.verts)
    yield
    bmesh.ops.rotate(p.bm, cent=lib.R(*pivot), matrix=Matrix.Rotation(math.radians(deg), 3, "X"),
                     verts=[v for v in p.bm.verts if v not in before])


def pitched_point(at, pivot, deg):
    """Where `pitched` puts the Roblox-space point `at` (for a muzzle)."""
    a = math.radians(deg)
    dy, dz = at[1] - pivot[1], at[2] - pivot[2]
    return (at[0], pivot[1] + dy * math.cos(a) - dz * math.sin(a), pivot[2] + dy * math.sin(a) + dz * math.cos(a))


def bolt(p, at, n, r=0.04, h=0.03):
    p.ocyl(at, n, r, h, 6, "steel")


def bolts(p, a, b, count, n):
    a, b = lib.vec(a), lib.vec(b)
    for i in range(count):
        bolt(p, tuple(a + (b - a) * ((i + 0.5) / count)), n)


def seam(p, a, b, n, width=0.035, height=0.012):
    a, b = lib.vec(a), lib.vec(b)
    p.obox(tuple((a + b) / 2), tuple(b - a), n, (b - a).length, width, height * 2, "seam")


def ring(p, center, n, r, width=0.04, segments=12):
    c, n_ = lib.vec(center), lib.vec(n).normalized()
    a = lib.Vector((1, 0, 0)) if abs(n_.x) < 0.9 else lib.Vector((0, 1, 0))
    u = (a - n_ * a.dot(n_)).normalized()
    v = n_.cross(u)
    for i in range(segments):
        t0, t1 = 2 * math.pi * i / segments, 2 * math.pi * (i + 1) / segments
        seam(p, tuple(c + u * math.cos(t0) * r + v * math.sin(t0) * r),
             tuple(c + u * math.cos(t1) * r + v * math.sin(t1) * r), n, width)


def box_seams(p, center, size, y):
    """Panel lines round the top of a box at height y."""
    cx, _, cz = center
    hx, hz = size[0] / 2, size[2] / 2
    corners = [(cx - hx, y, cz - hz), (cx + hx, y, cz - hz), (cx + hx, y, cz + hz), (cx - hx, y, cz + hz)]
    for i in range(4):
        seam(p, corners[i], corners[(i + 1) % 4], UP, width=0.03)


def wheel(p, x, y, z, r, width, sides=10, hub="steel", name=None):
    """A road wheel along X: rubber tyre, a painted rim face, a steel hub.
    With `name` it is its own spinning sub-piece (M-27), pivot at the axle."""
    if name:
        with p.sub(name, (x, y, z), "spin", (1, 0, 0)):
            wheel(p, x, y, z, r, width, sides, hub)
        return
    p.cylinder("x", (x, y, z), r, width, sides, "rubber", cap_kinds=("trim", "trim"))
    p.cylinder("x", (x, y, z), r * 0.42, width + 0.08, 6, hub)


# ---------------------------------------------------------------------------


GLOW_STRENGTH = {"running": 2.0, "head": 2.5, "power": 2.5, "weapon": 1.5}


def split_glow(obj):
    """Moves the glow faces of `obj` into one new object per channel; returns
    [(object, channel)]. The glow shells are closed boxes and cylinders, so
    the piece keeps no holes."""
    import bmesh
    out = []
    names = [m.name for m in obj.data.materials]
    for kind, channel in GLOW_KINDS.items():
        if kind not in names:
            continue
        slot = names.index(kind)
        if not any(poly.material_index == slot for poly in obj.data.polygons):
            continue
        g = obj.copy()
        g.data = obj.data.copy()
        g.name = f"{obj.name}_glow_{channel}"
        bpy.context.scene.collection.objects.link(g)
        for o, keep in ((g, True), (obj, False)):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            doomed = [f for f in bm.faces if (f.material_index == slot) != keep]
            bmesh.ops.delete(bm, geom=doomed, context="FACES")
            bm.to_mesh(o.data)
            bm.free()
        out.append((g, channel))
    return out


def surface_stats(objs, glow_objs):
    """Glow area and visible area (faces not facing down), studs^2."""
    def area(o):
        m = o.matrix_world.to_3x3()
        return sum(poly.area for poly in o.data.polygons if (m @ poly.normal).z > -0.5)
    glow = sum(area(g) for g in glow_objs)
    return glow, sum(area(o) for o in objs) + glow


def run(build_file, unit_id, faction, footprint, pieces, attachments=None, team_pieces=None,
        budget=4000, tex=1024, samples=32, upload_rev=0, preview_size=None, scale=None,
        previews=None, glow_strength=None):
    lib.UPLOAD_REV = upload_rev
    here = os.path.dirname(os.path.abspath(build_file))
    out = os.path.join(here, "export")
    look = FACTIONS[faction]
    wreck = bool(os.environ.get("FTGG_WRECK"))
    live_id = unit_id
    lib.WRECK = None
    if wreck:
        out = os.path.join(here, "export_wreck")
        look = wreck_look(look, edges=footprint >= 2)
        lib.WRECK = {"size": footprint * 8, "seed": sum(ord(ch) * (i + 1) for i, ch in enumerate(unit_id)) % 9973}
        unit_id = f"{unit_id}_wreck"
    lib.reset_scene()
    col = bpy.context.scene.collection
    keys = list(look["variants"].keys())
    target = lib.new_image("bake_target", tex, "sRGB")
    materials = {k: lib.make_material(k, look["specs"][k], [look["variants"][v] for v in keys], target) for k in KINDS}

    # rig order: each spec, then its animated sub-pieces (lib.Piece.sub, M-27)
    order = []  # Rec(name, parent, pivot, anim)
    low, high = [], []
    piece_anim = animate.for_unit(live_id)
    for spec in pieces:
        p = lib.Piece(spec.name, KINDS, spec.pivot)
        spec.build(p)
        if scale:
            p.scale(scale)
        h = lib.Piece(spec.name + "_hi", KINDS, spec.pivot)
        spec.build(h)
        spec.details(h)
        if scale:
            h.scale(scale)
        order.append(Rec(spec.name, spec.parent, lib.scaled(spec.pivot, scale) if scale else spec.pivot,
                         piece_anim.get(spec.name), False))
        low.append(p.to_object(materials, col))
        high.append(h.to_object(materials, col))
        for name, child in p.subs.items():
            order.append(Rec(name, spec.name, child.pivot, child.anim, True))
            low.append(child.to_object(materials, col))
        for name, child in h.subs.items():
            high.append(child.to_object(materials, col, name=name + "_hi"))
    pivots = {r.name: r.pivot for r in order}
    if scale and attachments:
        attachments = {k: {**a, "at": list(lib.scaled(a["at"], scale))} for k, a in attachments.items()}

    if os.environ.get("FTGG_MEASURE"):
        # quick check without the bake: glow share per channel
        names = KINDS
        def area(o, slots):
            m = o.matrix_world.to_3x3()
            return sum(q.area for q in o.data.polygons if (m @ q.normal).z > -0.5 and q.material_index in slots)
        every = set(range(len(names)))
        visible = sum(area(o, every) for o in low)
        parts = []
        for kind, channel in GLOW_KINDS.items():
            a = sum(area(o, {names.index(kind)}) for o in low)
            if a:
                parts.append(f"{channel} {a / visible * 100:.1f}%")
        glow = sum(area(o, {names.index(k) for k in GLOW_KINDS}) for o in low)
        print(f"MEASURE {unit_id}: glow {glow / visible * 100:.1f}% of {visible:.0f} studs^2 ({', '.join(parts)})")
        return

    counts = {o.name: lib.tris(o) for o in low}
    total = sum(counts.values())
    print(f"[{unit_id}] triangles {counts} total {total}")
    if total > budget:
        raise SystemExit(f"[{unit_id}] over budget: {total} > {budget}")

    lib.unwrap(low)
    sets = lib.bake_all(low, high, list(materials.values()), tex, samples, out, unit_id, keys)
    for h in high:
        bpy.data.objects.remove(h, do_unlink=True)

    # split the glow into its channel parts (after the bake: same UVs, same maps)
    glow = []  # (object, piece name, channel)
    for r, o in zip(order, low):
        for g, channel in ([] if wreck else split_glow(o)):
            glow.append((g, r.name, channel))
    glow_area, visible = surface_stats(low, [g for g, _, _ in glow])
    share = glow_area / visible if visible else 0.0
    print(f"[{unit_id}] glow {glow_area:.2f} of {visible:.2f} visible studs^2 = {share * 100:.1f}% "
          f"({', '.join(sorted({c for _, _, c in glow}))})")

    # previews framed on the unit's size
    b = lib.bounds(low[0])
    size = preview_size or max(b["size"][0], b["size"][2], b["size"][1] * 1.5)
    cy = b["size"][1] / 2
    lib.preview_lighting()
    for key in keys:
        lib.assign_single_material(low, lib.textured_material(f"preview_{key}", sets[key], None if wreck else look["team_preview"], None))
        for g, _, channel in glow:
            lib.assign_single_material([g], lib.textured_material(f"preview_{key}_{channel}", sets[key], None, look["glow"][channel]))
        for name, cam, at, lens in previews or [
            ("35", (-1.55 * size, 1.25 * size, 1.9 * size), (0, cy, 0), 50),
            ("80", (0, 3.0 * size, 0.55 * size), (0, cy, 0), 50),
            ("close", (-0.8 * size, 0.75 * size, -0.95 * size), (0, cy, 0), 35),
        ]:
            lib.render_preview(os.path.join(out, f"preview_{key}_{name}.png"), cam, at, lens=lens)

    exported = []
    for key in keys:
        mat = lib.textured_material(f"{unit_id}_{key}", sets[key])
        for o in low + [g for g, _, _ in glow]:
            c = o.copy()
            c.data = o.data.copy()
            c.name = f"{o.name}_{key}"
            col.objects.link(c)
            lib.assign_single_material([c], mat)
            exported.append(c)
    exported.append(lib.image_probe("emissive_probe", sets[keys[0]]["EMI"], col))
    lib.export_fbx(exported, os.path.join(out, f"{unit_id}.fbx"))

    rig_pieces = {}
    for r, o in zip(order, low):
        entry = {"parent": r.parent, **lib.bounds(o)}
        if r.parent:
            entry["pivot"] = list(pivots[r.name])
        rig_pieces[r.name] = entry
    if team_pieces:  # a sub-piece carries its parent's team plates
        team_pieces = list(team_pieces) + [r.name for r in order if r.sub and r.parent in team_pieces]
    rig_glow = [{"name": g.name, "piece": piece, "channel": channel, "tint": list(look["glow"][channel]),
                 "strength": (glow_strength or {}).get(g.name, GLOW_STRENGTH[channel]), **lib.bounds(g)}
                for g, piece, channel in glow]
    lib.write_json(os.path.join(out, "rig.json"), {
        "id": unit_id,
        **({"wreckOf": live_id} if wreck else {}),
        "footprintStuds": footprint * 8,
        "variants": {"bar": look["label"]},
        "pieces": rig_pieces,
        "attachments": {**(attachments or {}), **anchors.for_unit(live_id)},  # + nanoframe anchors (M-25)
        "teamColorPieces": [] if wreck else (team_pieces or [r.name for r in order]),
        "visualPieces": [r.name for r in order if r.sub],
        "anim": {r.name: r.anim for r in order if r.anim},
        "emissive": {"probe": "emissive_probe", "tint": list(look["accent"]), "strength": 2.0},
        "glow": rig_glow,
        "glowShare": round(share, 4),
        "triangles": {**counts, "total": total},
        "textures": {"size": tex, "perVariant": ["ALB", "RGH"], "shared": ["NOR", "MTL", "EMI"]},
    })
    print(f"[{unit_id}] done: {out}")
