"""Deployable shield effect assets (Order), for the client's shield effect.

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/shield/build.py

Writes assets/fx/shield/export/: shield_fx.fbx with
  dome         hemisphere, radius 1, open bottom, smooth normals, outward
  dome_inner   the same, radius 0.96, normals inward (the far wall seen
               through the dome)
  ring         thin torus, radius 1, tube 0.01, horizontal
  emitter      the shield projector device (BAR style, Order sand-grey, cyan
               emissive core), baked like the units (pipeline.md)
  tex_swirl, tex_beam, tex_speck, tex_ripple, emissive_probe
               small quads that carry the effect textures and the emitter's
               emissive mask, so the 3D Importer uploads them
plus the textures as PNGs (white / greyscale with alpha, generated here, so
the client tints them with the team color) and fx.json (sizes, pivots, the
emitter's `core` attachment). Usage: docs/contracts/fx.md.
Roblox model space for the emitter (docs/contracts/rig.md): +Y up, forward -Z.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "models", "tools"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import lib  # noqa: E402

OUT = os.path.join(HERE, "export")
UNIT = "shield_emitter"
TEX = 512  # emitter bake (a small device)
SAMPLES = 32

# dome: rings from the equator to the pole, segments round
DOME_RINGS, DOME_SEGMENTS = 12, 40  # 920 triangles
INNER_RADIUS = 0.96
RING_SEGMENTS, RING_SIDES, RING_TUBE = 34, 3, 0.01  # 204 triangles

KINDS = ["paint", "trim", "team", "seam", "dark", "light"]
PAINT = (174, 168, 150)  # Order sand-grey as the Lancer bakes it (M-16, M-18)
ACCENT = (90, 210, 255)  # Order cyan
VARIANTS = {"bar": {"type": "paint", "base": PAINT, "chip": (214, 210, 196), "grime": PAINT}}
SPECS = {
    "paint": {"base": None, "roughness": 0.62, "metallic": 0.1, "edge_mode": "highlight", "edge_wear": 0.45, "ao": 0.58},
    "trim": {"base": (112, 110, 102), "roughness": 0.5, "metallic": 0.35, "edge_mode": "highlight", "edge_wear": 0.35, "ao": 0.55},
    "team": {"base": (40, 40, 38), "roughness": 0.45, "metallic": 0.2, "mask": "team", "wash": 0.0,
             "chip_reveal": 0.85, "crease": 0.3, "edge_mode": "highlight", "edge_wear": 0.0},
    "seam": {"base": None, "darken": 0.32, "roughness": 0.6, "metallic": 0.2, "edge_wear": 0.0, "ao": 0.45},
    "dark": {"base": (50, 50, 48), "roughness": 0.55, "metallic": 0.3, "edge_mode": "highlight", "edge_wear": 0.3},
    "light": {"base": (215, 240, 250), "roughness": 0.2, "metallic": 0.0, "edge_wear": 0.0, "ao": 1.0, "emit": 1.0},
}
CORE_AT = (0.0, 2.75, 0.0)  # top of the glowing core: where the beam starts


# ---------------------------------------------------------------------------
# Dome and ring (built directly in Blender space: they are symmetric about
# the vertical axis, Blender Z = Roblox Y)
# ---------------------------------------------------------------------------


def smooth_object(name, bm, col):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj


def hemisphere(name, radius, inward, col):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = []
    for k in range(DOME_RINGS):
        phi = (math.pi / 2) * k / DOME_RINGS
        rings.append([bm.verts.new((radius * math.cos(phi) * math.cos(2 * math.pi * j / DOME_SEGMENTS),
                                    radius * math.cos(phi) * math.sin(2 * math.pi * j / DOME_SEGMENTS),
                                    radius * math.sin(phi))) for j in range(DOME_SEGMENTS)])
    pole = bm.verts.new((0, 0, radius))

    def face(verts, uvs):
        if inward:
            verts, uvs = verts[::-1], uvs[::-1]
        f = bm.faces.new(verts)
        for loop, t in zip(f.loops, uvs):
            loop[uv].uv = t

    m = DOME_SEGMENTS
    for k in range(DOME_RINGS - 1):
        v0, v1 = k / DOME_RINGS, (k + 1) / DOME_RINGS
        for j in range(m):
            u0, u1 = j / m, (j + 1) / m
            a, b = rings[k][j], rings[k][(j + 1) % m]
            c, d = rings[k + 1][(j + 1) % m], rings[k + 1][j]
            face([a, b, c, d], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    vt = (DOME_RINGS - 1) / DOME_RINGS
    for j in range(m):
        u0, u1 = j / m, (j + 1) / m
        face([rings[-1][j], rings[-1][(j + 1) % m], pole], [(u0, vt), (u1, vt), ((u0 + u1) / 2, 1.0)])
    return smooth_object(name, bm, col)


def torus(name, col):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    grid = []
    for i in range(RING_SEGMENTS):
        t = 2 * math.pi * i / RING_SEGMENTS
        row = []
        for j in range(RING_SIDES):
            s = 2 * math.pi * j / RING_SIDES
            r = 1.0 + RING_TUBE * math.cos(s)
            row.append(bm.verts.new((r * math.cos(t), r * math.sin(t), RING_TUBE * math.sin(s))))
        grid.append(row)
    n, k = RING_SEGMENTS, RING_SIDES
    for i in range(n):
        for j in range(k):
            f = bm.faces.new([grid[i][j], grid[(i + 1) % n][j], grid[(i + 1) % n][(j + 1) % k], grid[i][(j + 1) % k]])
            for loop, t in zip(f.loops, [(i / n, j / k), ((i + 1) / n, j / k), ((i + 1) / n, (j + 1) / k), (i / n, (j + 1) / k)]):
                loop[uv].uv = t
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return smooth_object(name, bm, col)


def white_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
    return mat


# ---------------------------------------------------------------------------
# Textures: white with an alpha shape (the client tints them)
# ---------------------------------------------------------------------------


def save_texture(name, alpha):
    """`alpha` is an (h, w) array, row 0 at the top of the image."""
    h, w = alpha.shape
    img = bpy.data.images.new(name, w, h, alpha=True, float_buffer=False)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[:, :, 3] = np.clip(alpha, 0.0, 1.0)
    img.pixels.foreach_set(px[::-1].ravel())  # Blender rows start at the bottom
    path = os.path.join(OUT, f"{name}.png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.source = "FILE"
    img.filepath = path
    img.reload()
    return img


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1  # -1..1, y down


def tex_swirl():
    """A vortex seen from above: five spiral arms winding into a bright eye,
    fading out at the rim (spins on a disc at the top of the dome)."""
    x, y = grid(512, 512)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    arms = 0.5 + 0.5 * np.cos(5 * (th + 2.6 * np.log(r + 0.05)))
    arms = arms ** 3
    body = arms * np.clip(1.0 - r, 0, 1) ** 0.8 * np.clip(r / 0.12, 0, 1)
    eye = np.exp(-(r / 0.1) ** 2)
    haze = 0.25 * np.clip(1.0 - r, 0, 1) ** 2
    return np.clip(body * 0.9 + eye + haze, 0, 1) * (r < 1)


def tex_beam():
    """A vertical light strip: a soft bright core and a wide halo across, a
    gentle flicker of streaks along that tiles vertically (scrolls)."""
    x, y = grid(256, 512)
    v = (y + 1) / 2  # 0..1 down the strip
    core = np.exp(-(x / 0.12) ** 2)
    halo = 0.45 * np.exp(-(x / 0.45) ** 2)
    rng = np.random.default_rng(7)
    streak = np.zeros_like(v)
    for f in (2, 3, 5, 8, 13):  # whole cycles per tile: seamless vertically
        streak += np.cos(2 * np.pi * (f * v + rng.random())) / f
    streak = 0.8 + 0.2 * streak / 1.2
    edge = np.clip(1 - np.abs(x), 0, 1) ** 0.5
    return np.clip((core + halo) * streak * edge, 0, 1)


def tex_speck():
    """A floating mote: a soft dot with a faint four-point glint."""
    x, y = grid(256, 256)
    r = np.sqrt(x * x + y * y)
    dot = np.exp(-(r / 0.18) ** 2)
    glow = 0.35 * np.exp(-(r / 0.5) ** 2)
    glint = 0.5 * (np.exp(-(x / 0.03) ** 2) + np.exp(-(y / 0.03) ** 2)) * np.clip(1 - r, 0, 1) ** 3
    return np.clip(dot + glow + glint, 0, 1) * (r < 1)


def tex_ripple():
    """A hit on the dome: a bright ring burst with two fainter echoes
    inside and a faint fill, nothing at the center."""
    x, y = grid(512, 512)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    wobble = 1 + 0.007 * np.cos(7 * th) + 0.005 * np.cos(11 * th + 1.3)
    rr = r * wobble
    ring = np.exp(-((rr - 0.82) / 0.035) ** 2)
    echo1 = 0.45 * np.exp(-((rr - 0.62) / 0.03) ** 2)
    echo2 = 0.22 * np.exp(-((rr - 0.44) / 0.03) ** 2)
    fill = 0.18 * np.clip(rr / 0.82, 0, 1) ** 2 * (rr < 0.82)
    return np.clip(ring + echo1 + echo2 + fill, 0, 1) * np.clip((0.98 - r) / 0.06, 0, 1)


# ---------------------------------------------------------------------------
# Emitter device: a squat hexagonal plinth, a collar, three prongs leaning in
# round a glowing core column; team plates on the plinth's top
# ---------------------------------------------------------------------------


def hexagon(r, rot=0.0):
    return [(r * math.cos(rot + i * math.pi / 3), r * math.sin(rot + i * math.pi / 3)) for i in range(6)]


def build_emitter(p):
    p.prism_y(hexagon(2.0, math.pi / 6), 0.0, 0.55, "paint", bevel=0.05, top_scale=0.92)
    p.prism_y(hexagon(1.45, math.pi / 6), 0.55, 1.05, "trim", bevel=0.04, top_scale=0.9)
    p.cylinder("y", (0, 1.15, 0), 0.75, 0.2, 12, "dark")
    p.cylinder("y", (0, 1.85, 0), 0.38, 1.3, 10, "light", radius2=0.3)
    p.cylinder("y", (0, 2.62, 0), 0.3, 0.26, 10, "light", radius2=0.12)
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        out = (math.cos(a), 0.0, math.sin(a))
        foot = (out[0] * 1.15, 1.0, out[2] * 1.15)
        top = (out[0] * 0.62, 2.7, out[2] * 0.62)
        axis = (top[0] - foot[0], top[1] - foot[1], top[2] - foot[2])
        mid = tuple((foot[k] + top[k]) / 2 for k in range(3))
        length = math.sqrt(sum(c * c for c in axis))
        p.obox(mid, axis, out, length, 0.5, 0.32, "paint", bevel=0.04)
        tip = (out[0] * 0.55, 2.78, out[2] * 0.55)
        p.obox(tip, (0, 1, 0), out, 0.18, 0.36, 0.42, "dark", bevel=0.02)
        # team plate on the plinth's top over a flat face, a sensor light below
        c = a - math.pi / 6
        p.obox((math.cos(c) * 1.48, 0.56, math.sin(c) * 1.48), (-math.sin(c), 0, math.cos(c)), (0, 1, 0),
               0.9, 0.26, 0.05, "team")
        p.obox((math.cos(c) * 1.73, 0.28, math.sin(c) * 1.73), (-math.sin(c), 0, math.cos(c)), (math.cos(c), 0, math.sin(c)),
               0.6, 0.1, 0.05, "light")


def details_emitter(p):
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3
        p.cylinder("y", (math.cos(a) * 1.3, 1.07, math.sin(a) * 1.3), 0.06, 0.04, 6, "dark")
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        out = (math.cos(a), 0.0, math.sin(a))
        p.obox((out[0] * 0.95, 1.6, out[2] * 0.95), (0, 1, 0), out, 0.04, 0.4, 0.34, "seam")


# ---------------------------------------------------------------------------


def main():
    lib.reset_scene()
    os.makedirs(OUT, exist_ok=True)
    col = bpy.context.scene.collection
    exported = []

    white = white_material("shield_white")
    dome = hemisphere("dome", 1.0, False, col)
    inner = hemisphere("dome_inner", INNER_RADIUS, True, col)
    ring = torus("ring", col)
    for o in (dome, inner, ring):
        o.data.materials.append(white)
    counts = {o.name: lib.tris(o) for o in (dome, inner, ring)}

    # emitter, baked like a unit
    keys = list(VARIANTS.keys())
    target = lib.new_image("bake_target", TEX, "sRGB")
    materials = {k: lib.make_material(k, SPECS[k], [VARIANTS[v] for v in keys], target) for k in KINDS}
    p = lib.Piece("emitter", KINDS, (0.0, 0.0, 0.0))
    build_emitter(p)
    low = p.to_object(materials, col)
    h = lib.Piece("emitter_hi", KINDS, (0.0, 0.0, 0.0))
    build_emitter(h)
    details_emitter(h)
    high = h.to_object(materials, col)
    counts["emitter"] = lib.tris(low)
    print(f"[shield] triangles {counts}")
    lib.unwrap([low])
    sets = lib.bake_all([low], [high], list(materials.values()), TEX, SAMPLES, OUT, UNIT, keys)
    bpy.data.objects.remove(high, do_unlink=True)
    lib.assign_single_material([low], lib.textured_material(f"{UNIT}_bar", sets["bar"]))

    textures = {
        "swirl": save_texture("fx_shield_swirl", tex_swirl()),
        "beam": save_texture("fx_shield_beam", tex_beam()),
        "speck": save_texture("fx_shield_speck", tex_speck()),
        "ripple": save_texture("fx_shield_ripple", tex_ripple()),
    }
    probes = [lib.image_probe(f"tex_{k}", img, col, at=(6.0 + 1.0 * i, -2.0, 0.0)) for i, (k, img) in enumerate(textures.items())]
    probes.append(lib.image_probe("emissive_probe", sets["bar"]["EMI"], col, at=(5.0, -2.0, 0.0)))

    # preview of the emitter alone (the dome and ring are plain white)
    lib.preview_lighting()
    for o in [dome, inner, ring] + probes:
        o.hide_render = True
    lib.assign_single_material([low], lib.textured_material("preview", sets["bar"], (58, 120, 230), ACCENT))
    lib.render_preview(os.path.join(OUT, "preview_emitter.png"), (5.5, 5.0, 7.0), (0, 1.4, 0), lens=50)
    lib.assign_single_material([low], lib.textured_material(f"{UNIT}_bar", sets["bar"]))
    exported = [dome, inner, ring, low] + probes
    lib.export_fbx(exported, os.path.join(OUT, "shield_fx.fbx"))

    lib.write_json(os.path.join(OUT, "fx.json"), {
        "id": "fx_shield",
        "meshes": {
            "dome": {"radius": 1.0, "pivot": "center of the open bottom", "triangles": counts["dome"], "normals": "outward"},
            "dome_inner": {"radius": INNER_RADIUS, "pivot": "center of the open bottom", "triangles": counts["dome_inner"], "normals": "inward"},
            "ring": {"radius": 1.0, "tube": RING_TUBE, "pivot": "center", "plane": "horizontal", "triangles": counts["ring"]},
            "emitter": {"pivot": "ground under its center", **lib.bounds(low), "triangles": counts["emitter"],
                        "attachments": {"core": {"at": list(CORE_AT)}}},
        },
        "emissive": {"probe": "emissive_probe", "tint": list(ACCENT), "strength": 2.0},
        "textures": {k: {"probe": f"tex_{k}", "size": list(img.size)} for k, img in textures.items()},
    })
    print(f"[shield] done: {OUT}")


main()
