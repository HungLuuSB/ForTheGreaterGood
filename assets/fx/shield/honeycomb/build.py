"""Honeycomb shell over the shield dome (clients-B's request 2026-10-23,
docs/contracts/fx.md "Honeycomb shell"): white hex outlines the client tints
and fades with the shield's charge, visible on the top of the dome and gone
towards its base.

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/shield/honeycomb/build.py

Roblox meshes carry no per-vertex alpha, so the fade can't live in a tiling
texture. Instead:
- honeycomb_tile.png: one tileable rectangle of a pointy-top hex lattice
  (COLS columns by ROWS rows), white RGB, the outlines in alpha. Only
  scattered patches of cells are drawn (the user: "spread out like little
  patches"): seeded blobs, periodic over the tile, full in the middle and
  fading out at their edges, with a faint fill inside;
- shell_1 .. shell_N: the dome (radius SHELL, 0.3% over the dome) cut into
  bands, the top cap down to CAP and thin rings below it down to END, each
  with a recommended opacity (opaque at the top, fading to nothing). Their
  UVs are azimuthal equidistant (arc length from the pole) divided by the
  tile size, so the tile repeats evenly with the cells HEX studs across at
  the reference radius (they scale with the dome; the texture wraps, UVs run
  past 0..1).
Writes export/honeycomb.fbx, the PNG and export/shell.json (bands: polar
range, opacity, center and size at radius 1 in Roblox space, +Y up).
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "models", "tools"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import lib  # noqa: E402

OUT = os.path.join(HERE, "export")
SHELL = 1.003  # over the dome (radius 1)
REF_RADIUS = 120  # the Order dome's default radius
HEX = 5.0  # cell width across the flats, in studs at REF_RADIUS
CAP, END = 30.0, 72.0  # polar angles (degrees from the top): the opaque cap, where the fade ends
BANDS = 10  # rings between CAP and END
STEP = 1.5  # polar step of the mesh (degrees)
SEGMENTS = 120  # round
TILE_PX = 1024  # tile width in pixels
COLS, ROWS = 12, 10  # cells per tile (ROWS even: the lattice repeats every two rows)
PATCHES, SEED = 9, 7  # blobs per tile
FILL = 0.07  # faint fill inside patch cells
LINE = 0.055  # outline half-width as a fraction of the hex side
GLOW = 0.16  # soft halo half-width, same unit

SIDE = HEX / math.sqrt(3) / REF_RADIUS  # hex side on the unit sphere (arc length)
TILE_W, TILE_H = COLS * math.sqrt(3) * SIDE, ROWS * 1.5 * SIDE  # one tile


def hex_tile():
    """Alpha of one tile; x right, y down, both periodic."""
    import random
    w = TILE_PX
    h = round(TILE_PX * TILE_H / TILE_W)
    a = 1.0  # work in hex-side units
    W, H = COLS * math.sqrt(3) * a, ROWS * 1.5 * a
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    x, y = (xs + 0.5) / w * W, (ys + 0.5) / h * H
    best = np.full(x.shape, 1e9)
    bx, by = np.zeros(x.shape), np.zeros(x.shape)
    # lattice: centers at i * (sqrt3, 0) + j * (sqrt3 / 2, 1.5)
    for j in range(-1, ROWS + 2):
        for i in range(-(ROWS // 2) - 2, COLS + 2):
            cx, cy = i * math.sqrt(3) * a + j * math.sqrt(3) / 2 * a, j * 1.5 * a
            dx, dy = x - cx, y - cy
            # pointy-top hex: flat sides at 0, 60 and 120 degrees
            d = np.maximum.reduce([np.abs(dx), np.abs(dx * 0.5 + dy * math.sqrt(3) / 2),
                                   np.abs(-dx * 0.5 + dy * math.sqrt(3) / 2)])
            closer = d < best
            best = np.where(closer, d, best)
            bx, by = np.where(closer, cx, bx), np.where(closer, cy, by)
    edge = math.sqrt(3) / 2 * a - best  # distance to the cell's outline
    line = np.clip(1.0 - (edge - LINE) / 0.02, 0.0, 1.0)  # crisp core line
    halo = np.exp(-(edge / GLOW) ** 2) * 0.35
    # patches: each cell's weight from seeded blobs, measured periodically
    rng = random.Random(SEED)
    cx, cy = np.mod(bx, W), np.mod(by, H)
    weight = np.zeros(x.shape)
    for _ in range(PATCHES):
        px, py = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(1.6, 3.4) * math.sqrt(3) * a  # radius in cells
        dx = np.abs(cx - px)
        dx = np.minimum(dx, W - dx)
        dy = np.abs(cy - py)
        dy = np.minimum(dy, H - dy)
        k = np.clip(1.0 - np.hypot(dx, dy) / r, 0.0, 1.0)
        weight = np.maximum(weight, k * k * (3 - 2 * k) * rng.uniform(0.75, 1.0))
    weight = np.where(weight > 0.12, np.clip(weight * 1.6, 0.0, 1.0), 0.0)
    return np.clip(np.maximum(line, halo) * weight + FILL * weight, 0.0, 1.0)


def save_png(name, alpha):
    h, w = alpha.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[:, :, 3] = alpha
    img.pixels.foreach_set(px[::-1].ravel())
    path = os.path.join(HERE, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.source = "FILE"
    img.filepath = path
    img.reload()
    return img


def point(theta, phi):
    """Blender space (Z up) on the shell; theta from the pole, radians."""
    s = math.sin(theta)
    return (SHELL * s * math.cos(phi), SHELL * s * math.sin(phi), SHELL * math.cos(theta))


def uv(theta, phi):
    """Azimuthal equidistant: arc length from the pole, in tiles."""
    return (theta * math.cos(phi) / TILE_W, theta * math.sin(phi) / TILE_H)


def band(name, t0, t1, col, mat):
    """The shell between polar angles t0 and t1 (degrees); a cap when t0 = 0."""
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    n = max(1, round((t1 - t0) / STEP))
    thetas = [math.radians(t0 + (t1 - t0) * k / n) for k in range(n + 1)]
    phis = [2 * math.pi * j / SEGMENTS for j in range(SEGMENTS + 1)]

    def face(corners):
        verts = [bm.verts.new(point(t, p)) for t, p in corners]
        f = bm.faces.new(verts)
        for loop, (t, p) in zip(f.loops, corners):
            loop[layer].uv = uv(t, p)

    for k in range(n):
        ta, tb = thetas[k], thetas[k + 1]
        for j in range(SEGMENTS):
            pa, pb = phis[j], phis[j + 1]
            if ta == 0:  # the pole: one triangle per segment
                face([(0.0, (pa + pb) / 2), (tb, pa), (tb, pb)])
            else:
                face([(ta, pa), (tb, pa), (tb, pb), (ta, pb)])
    # weld the duplicated corners but keep the UVs (they're continuous)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def main():
    lib.reset_scene()
    os.makedirs(OUT, exist_ok=True)
    col = bpy.context.scene.collection
    mat = bpy.data.materials.new("honeycomb")
    tile = save_png("honeycomb_tile", hex_tile())
    probe = lib.image_probe("tex_honeycomb", tile, col, at=(3.0, 0.0, 0.0))
    edges = [0.0, CAP] + [CAP + (END - CAP) * (i + 1) / BANDS for i in range(BANDS)]
    bands, objs = [], []
    for i in range(len(edges) - 1):
        t0, t1 = edges[i], edges[i + 1]
        mid = (t0 + t1) / 2
        # opaque cap, then a smooth fall to nothing at END
        k = min(1.0, max(0.0, (mid - CAP) / (END - CAP)))
        opacity = 1.0 if i == 0 else round(1.0 - k * k * (3 - 2 * k), 3)
        o = band(f"shell_{i + 1}", t0, t1, col, mat)
        objs.append(o)
        # bounds in Roblox space (+Y up): x and z round, y from the band's low rim to its top
        r_out = SHELL * math.sin(math.radians(min(t1, 90.0)))
        y_lo, y_hi = SHELL * math.cos(math.radians(t1)), SHELL * math.cos(math.radians(t0))
        bands.append({"name": o.name, "theta": [t0, t1], "opacity": opacity, "triangles": lib.tris(o),
                      "center": [0.0, round((y_lo + y_hi) / 2, 6), 0.0],
                      "size": [round(2 * r_out, 6), round(y_hi - y_lo, 6), round(2 * r_out, 6)]})
    lib.export_fbx(objs + [probe], os.path.join(OUT, "honeycomb.fbx"))
    lib.write_json(os.path.join(OUT, "shell.json"), {
        "id": "shield_honeycomb", "radius": SHELL, "hex": HEX, "refRadius": REF_RADIUS,
        "tile": {"png": "honeycomb_tile.png", "size": list(tile.size), "studsAtRef": [TILE_W * REF_RADIUS, TILE_H * REF_RADIUS]},
        "cap": CAP, "end": END, "bands": bands,
        "triangles": sum(b["triangles"] for b in bands),
    })
    print(f"[honeycomb] {len(bands)} bands, {sum(b['triangles'] for b in bands)} triangles, tile {tile.size[:]}")


main()
