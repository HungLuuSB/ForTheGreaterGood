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

import math
import os
from dataclasses import dataclass, field

import bpy

import lib

KINDS = ["paint", "trim", "team", "seam", "era", "track", "steel", "rubber", "glass", "light", "grille", "dark"]

FACTIONS = {
    "order": {
        "label": "BAR-style painted sand-grey (M-15)",
        "paint": (184, 178, 160),
        "accent": (90, 210, 255),
        "team_preview": (58, 120, 230),
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
            "light": {"base": (215, 240, 250), "roughness": 0.2, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0},
            "grille": {"base": None, "darken": 0.55, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
            "dark": {"base": (50, 50, 48), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.3},
        },
    },
    "chaos": {
        "label": "BAR-style gunmetal (M-15)",
        "paint": (96, 100, 106),
        "accent": (255, 140, 50),
        "team_preview": (214, 62, 48),
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
            "light": {"base": (255, 214, 170), "roughness": 0.2, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0},
            "grille": {"base": None, "darken": 0.5, "roughness": 0.6, "metallic": 0.3, "edge_wear": 0.0, "bump": "grille", "ao": 0.35},
            "dark": {"base": (34, 35, 38), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.35},
        },
    },
}

UP = (0, 1, 0)


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


# ---------------------------------------------------------------------------


def run(build_file, unit_id, faction, footprint, pieces, attachments=None, team_pieces=None,
        budget=4000, tex=1024, samples=32, upload_rev=0, preview_size=None):
    lib.UPLOAD_REV = upload_rev
    here = os.path.dirname(os.path.abspath(build_file))
    out = os.path.join(here, "export")
    look = FACTIONS[faction]
    lib.reset_scene()
    col = bpy.context.scene.collection
    keys = list(look["variants"].keys())
    target = lib.new_image("bake_target", tex, "sRGB")
    materials = {k: lib.make_material(k, look["specs"][k], [look["variants"][v] for v in keys], target) for k in KINDS}

    low, high = [], []
    for spec in pieces:
        p = lib.Piece(spec.name, KINDS, spec.pivot)
        spec.build(p)
        low.append(p.to_object(materials, col))
        h = lib.Piece(spec.name + "_hi", KINDS, spec.pivot)
        spec.build(h)
        spec.details(h)
        high.append(h.to_object(materials, col))

    counts = {o.name: lib.tris(o) for o in low}
    total = sum(counts.values())
    print(f"[{unit_id}] triangles {counts} total {total}")
    if total > budget:
        raise SystemExit(f"[{unit_id}] over budget: {total} > {budget}")

    lib.unwrap(low)
    sets = lib.bake_all(low, high, list(materials.values()), tex, samples, out, unit_id, keys)
    for h in high:
        bpy.data.objects.remove(h, do_unlink=True)

    # previews framed on the unit's size
    b = lib.bounds(low[0])
    size = preview_size or max(b["size"][0], b["size"][2], b["size"][1] * 1.5)
    cy = b["size"][1] / 2
    lib.preview_lighting()
    for key in keys:
        lib.assign_single_material(low, lib.textured_material(f"preview_{key}", sets[key], look["team_preview"], look["accent"]))
        for name, cam, at in [
            ("35", (-1.55 * size, 1.25 * size, 1.9 * size), (0, cy, 0)),
            ("80", (0, 3.0 * size, 0.55 * size), (0, cy, 0)),
            ("close", (-0.8 * size, 0.75 * size, -0.95 * size), (0, cy, 0)),
        ]:
            lib.render_preview(os.path.join(out, f"preview_{key}_{name}.png"), cam, at, lens=50 if name != "close" else 35)

    exported = []
    for key in keys:
        mat = lib.textured_material(f"{unit_id}_{key}", sets[key])
        for o in low:
            c = o.copy()
            c.data = o.data.copy()
            c.name = f"{o.name}_{key}"
            col.objects.link(c)
            lib.assign_single_material([c], mat)
            exported.append(c)
    exported.append(lib.image_probe("emissive_probe", sets[keys[0]]["EMI"], col))
    lib.export_fbx(exported, os.path.join(out, f"{unit_id}.fbx"))

    rig_pieces = {}
    for spec, o in zip(pieces, low):
        entry = {"parent": spec.parent, **lib.bounds(o)}
        if spec.parent:
            entry["pivot"] = list(spec.pivot)
        rig_pieces[spec.name] = entry
    lib.write_json(os.path.join(out, "rig.json"), {
        "id": unit_id,
        "footprintStuds": footprint * 8,
        "variants": {"bar": look["label"]},
        "pieces": rig_pieces,
        "attachments": attachments or {},
        "teamColorPieces": team_pieces or [s.name for s in pieces],
        "emissive": {"probe": "emissive_probe", "tint": list(look["accent"]), "strength": 2.0},
        "triangles": {**counts, "total": total},
        "textures": {"size": tex, "perVariant": ["ALB", "RGH"], "shared": ["NOR", "MTL", "EMI"]},
    })
    print(f"[{unit_id}] done: {out}")
