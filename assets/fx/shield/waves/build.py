"""The shield's energy look, v4 (the user's v3 review 2026-10-24, with the
mock-up assets/reference/shield/shield_demo.html; docs/contracts/fx.md
"Shield energy"):

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/shield/waves/build.py

Every texture is white with the pattern in alpha (the client tints it:
Order cyan, Chaos amber). Beam textures run U across the beam and V along
it (V 0 at Attachment0), seamless along V (TextureMode Wrap) unless noted.
R is the dome radius; sizes in R units are what the client multiplies.

Textures:
- pulse (Beam, the channel's core): a thin constant line with one bright
  packet per tile. TextureLength = a third of the beam, so three packets
  are in flight; scrolled up, one arrives at the apex every 0.5 s.
- glow (Beam): the soft halo round the channel.
- line (Beam): the filaments' thin line (short straight segments).
- spark: the flicker at the emitter (BillboardGui).
- flare: the apex starburst (BillboardGui).
- streak (Beam, Wrap): one packet of light per tile, a head toward V 1 and
  a tail behind it, empty between packets: scrolled down the meridians.
- wave_glow_a / _b / _c (Beam lying on the dome, FaceCamera off): the wave's
  glow band. U across the band from the apex side (0) to the ground side
  (1): a soft tail above a bright leading line near the lower edge, with the
  dome's honeycomb cells (0.147 R across the flats, 0.255 R tile along V)
  lit inside it and a few cells filled; the three variants light different
  cells (swap them every few frames for the flicker).
- wave_line_a / _b / _c (Beam): the wave's thin crackling leading line, a
  zig-zag of short straight strokes; swap the variants for the crackle.
- hit_1 .. hit_8 (the HitCap mesh's TextureID, a flipbook): a patch of
  honeycomb cells lit round the impact and a bright ring spreading outward,
  fading; planar over the cap (2 sin 0.46 = 0.888 R across), cells 0.147 R.
- field: the dome's faint pattern for the ForceField material.

Meshes (export/energy.fbx, export/energy.json; radius 1, Y up in Roblox):
- HexGrid: the honeycomb over the hemisphere, even cells everywhere (the
  dual of a frequency-8 geodesic sphere: hexagons about 0.14 R across, a
  pentagon at the apex), as thin ribbons (0.0045 R) at radius 1.004.
- Band_1 .. Band_20: the dome surface (radius 1) in 20 bands of 4.5 degrees
  from the apex to the ground, for the sweeping raise and collapse.
- HitCap: a spherical cap of 0.46 rad round +Y at radius 1.006, UVs planar
  from above (U along X, V along Z); turned onto the hit point.
"""

import json
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
HEX = 1 / 0.147  # hex units per R: one unit = the cells' width across the flats (the mock-up's sc = 1.7 at R = 4)
BANDS = 20
CAP = 0.46  # HitCap half-angle, radians
GRID_R, GRID_W = 1.004, 0.0045


# ---------- textures ----------

def grid(w, h):
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    return np.meshgrid(u, v)


def hex_cell(x, y):
    """The mock-up's hexCell: (distance to the cell's border, cell id hash), x and y in hex units
    (period 1 along x, 1.732 along y)."""
    rx, ry = 1.0, 1.7320508
    ax, ay = np.mod(x, rx) - rx / 2, np.mod(y, ry) - ry / 2
    bx, by = np.mod(x - rx / 2, rx) - rx / 2, np.mod(y - ry / 2, ry) - ry / 2
    use_a = ax * ax + ay * ay < bx * bx + by * by
    gx, gy = np.where(use_a, ax, bx), np.where(use_a, ay, by)
    px, py = np.abs(gx), np.abs(gy)
    d = 0.5 - np.maximum(px * 0.5 + py * 0.8660254, px)
    idx, idy = np.round(x - gx, 3), np.round(y - gy, 3)  # the cell's centre, rounded so the hash is steady across it
    h = np.mod(np.sin(idx * 127.1 + idy * 311.7) * 43758.5453, 1.0)
    return d, h


def tex_pulse(w=64, h=256):
    U, V = grid(w, h)
    x = U - 0.5
    core = 0.5 * np.exp(-(x / 0.06) ** 2) + 0.12 * np.exp(-(x / 0.2) ** 2)
    d = V - 0.5
    packet = np.exp(-(d / 0.07) ** 2) * (np.exp(-(x / 0.1) ** 2) + 0.4 * np.exp(-(x / 0.3) ** 2))
    return np.clip(core + packet, 0, 1)


def tex_glow(w=64, h=128):
    U, _ = grid(w, h)
    return np.exp(-((U - 0.5) / 0.24) ** 2) * 0.8


def tex_line(w=64, h=128):
    U, _ = grid(w, h)
    x = U - 0.5
    return np.clip(np.exp(-(x / 0.08) ** 2) + 0.3 * np.exp(-(x / 0.25) ** 2), 0, 1)


def tex_spark(w=128, h=128):
    U, V = grid(w, h)
    x, y = U - 0.5, V - 0.5
    r = np.hypot(x, y)
    a = np.exp(-(r / 0.06) ** 2) + 0.35 * np.exp(-(r / 0.2) ** 2)
    a += 0.5 * np.exp(-(y / 0.012) ** 2) * np.exp(-(x / 0.3) ** 2) + 0.5 * np.exp(-(x / 0.012) ** 2) * np.exp(-(y / 0.3) ** 2)
    return np.clip(a * np.clip(1 - r * 2, 0, 1), 0, 1)


def tex_flare(w=512, h=512):
    """The mock-up's flare: a radial core and 16 tapering rays of different lengths."""
    U, V = grid(w, h)
    x, y = U - 0.5, V - 0.5
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    rng = np.random.default_rng(81)
    core = np.interp(r, [0, 0.06, 0.17, 0.5], [1.0, 0.85, 0.18, 0.0])
    rays = np.zeros_like(U)
    a0 = 0.0
    for _ in range(16):
        a0 += 2 * math.pi / 16 + rng.uniform(0, 0.1)
        length = (60 + rng.uniform(0, 64)) / 256
        da = np.abs((ang - a0 + math.pi) % (2 * math.pi) - math.pi)
        half = 2.5 / 256 * np.clip(1 - r / length, 0, 1)  # the ray's half-width tapers to its tip
        rays = np.maximum(rays, 0.9 * np.clip(1 - r / length, 0, 1) * (da * r < half + 0.002))
    return np.clip(core + rays, 0, 1)


def tex_streak(w=32, h=512):
    U, V = grid(w, h)
    x = U - 0.5
    d = 0.8 - V  # behind the head (V 0.8), toward V 0
    pack = np.where(d >= 0, np.clip(1 - d / 0.32, 0, 1) ** 2, np.exp(-(d / 0.015) ** 2))
    across = np.exp(-(x / 0.18) ** 2)
    return np.clip(pack * across, 0, 1)


def tex_wave_glow(seed, w=224, h=256):
    """Across (U, 0 = apex side): the band is 0.223 R wide, the leading line at U 0.78. Along (V): one
    tile is 0.255 R (one hex period)."""
    U, V = grid(w, h)
    across = U * 0.223  # R units from the band's top edge
    lead = 0.78 * 0.223
    d = across - lead
    band = np.exp(-(d / 0.016) ** 2) + np.where(d < 0, np.exp(d / 0.05) * 0.4, 0.0)
    edge = np.clip(U / 0.06, 0, 1) * np.clip((1 - U) / 0.06, 0, 1)
    x = across * HEX
    y = V * 1.7320508 + 0.37  # one period along the band
    dist, cid = hex_cell(x, y)
    line = 1 - np.clip(dist / 0.06, 0, 1)
    rng = np.random.default_rng(seed)
    lit = np.mod(cid + rng.uniform(), 1.0) > 0.8  # a few cells filled, different in each variant
    fill = lit * np.clip(dist / 0.08, 0, 1) * 0.35
    a = band * (0.35 + 0.9 * line + fill * 2.0)
    return np.clip(a * edge, 0, 1)


def tex_wave_line(seed, w=64, h=512):
    """A zig-zag of 12 short straight strokes per tile (periodic), a thin bright line with a glow."""
    U, V = grid(w, h)
    rng = np.random.default_rng(seed)
    n = 12
    knots = rng.uniform(-0.28, 0.28, n + 1)
    knots[-1] = knots[0]
    t = V * n
    i = np.floor(t).astype(int) % n
    f = t - np.floor(t)
    cx = knots[i] * (1 - f) + knots[i + 1] * f
    dx = (U - 0.5) - cx
    a = np.exp(-(dx / 0.035) ** 2) + 0.3 * np.exp(-(dx / 0.14) ** 2)
    return np.clip(a, 0, 1)


def tex_hit(k, n=8, w=256, h=256):
    """Frame k of n: the mock-up's hit glow over the cap's planar UVs."""
    U, V = grid(w, h)
    half = math.sin(CAP)
    px, pz = (U - 0.5) * 2 * half, (V - 0.5) * 2 * half  # R units in the tangent plane
    rho = np.hypot(px, pz)
    ang = np.arcsin(np.clip(rho, 0, 1))
    age = (k + 0.5) / n
    rad = 0.12 + age * 0.28
    hitg = np.exp(-(ang / rad) ** 2) * (1 - age) * (1 + 2 * np.exp(-((ang - rad) / 0.05) ** 2))
    dist, cid = hex_cell(px * HEX, pz * HEX)
    line = 1 - np.clip(dist / 0.06, 0, 1)
    flick = (np.mod(cid + k * 0.37, 1.0) > 0.82) * np.clip(dist / 0.08, 0, 1)
    a = line * hitg * 1.6 + hitg * 0.25 + flick * hitg * 0.5
    edge = np.clip((CAP - ang) / 0.06, 0, 1)
    return np.clip(a * edge, 0, 1)


def tex_field(w=512, h=512):
    """Faint slow latitude ripples (the mock-up's pat), seamless in U."""
    U, V = grid(w, h)
    rng = np.random.default_rng(91)
    warp = 0.03 * np.sin(2 * math.pi * (5 * U) + rng.uniform(0, 6)) + 0.015 * np.sin(2 * math.pi * (11 * U) + 1.3)
    lines = (0.5 + 0.5 * np.sin(2 * math.pi * 12 * (V + warp))) ** 10
    return np.clip(0.04 + 0.25 * lines, 0, 1)


def save_png(name, alpha):
    h, w = alpha.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[:, :, 3] = alpha
    img.pixels.foreach_set(px[::-1].ravel())  # row 0 of the array is the image's top (V 0)
    path = os.path.join(HERE, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


# ---------- meshes (Blender space, Z up: Roblox Y = Blender Z) ----------

def link(name, bm, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def hex_grid(mat):
    """Dual of a frequency-8 icosphere: each ico edge gives the cell border between its two faces'
    centres, kept where it lies on the upper half."""
    src = bmesh.new()
    bmesh.ops.create_icosphere(src, subdivisions=4, radius=1.0)  # 642 vertices: 630 hexagons, 12 pentagons
    src.faces.ensure_lookup_table()
    centre = {f.index: f.calc_center_median().normalized() for f in src.faces}
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    for e in src.edges:
        if len(e.link_faces) != 2:
            continue
        a, b = centre[e.link_faces[0].index], centre[e.link_faces[1].index]
        if a.z < -0.02 and b.z < -0.02:
            continue
        pts = [(a.lerp(b, s)).normalized() for s in (0.0, 0.5, 1.0)]  # two pieces follow the curve
        for p, q in zip(pts, pts[1:]):
            d = (q - p).normalized()
            side = d.cross(p).normalized() * (GRID_W / 2)
            corners = [p * GRID_R - side, q * GRID_R - side, q * GRID_R + side, p * GRID_R + side]
            vs = [bm.verts.new(c) for c in corners]
            f = bm.faces.new(vs)
            for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[layer].uv = uv
    src.free()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:  # outward, like the dome
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    return link("HexGrid", bm, mat)


def sphere_patch(name, t0, t1, mat, radius=1.0, segments=64, steps=3, uv=None):
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    thetas = [t0 + (t1 - t0) * k / steps for k in range(steps + 1)]
    phis = [2 * math.pi * j / segments for j in range(segments + 1)]

    def pt(t, p):
        s = math.sin(t)
        return (radius * s * math.cos(p), radius * s * math.sin(p), radius * math.cos(t))

    def face(corners):
        vs = [bm.verts.new(pt(t, p)) for t, p in corners]
        f = bm.faces.new(vs)
        for loop, (t, p) in zip(f.loops, corners):
            loop[layer].uv = uv(t, p) if uv else (p / (2 * math.pi), 1 - (t - t0) / max(t1 - t0, 1e-9))

    for k in range(steps):
        ta, tb = thetas[k], thetas[k + 1]
        for j in range(segments):
            pa, pb = phis[j], phis[j + 1]
            if ta == 0:
                face([(0.0, (pa + pb) / 2), (tb, pa), (tb, pb)])
            else:
                face([(ta, pa), (tb, pa), (tb, pb), (ta, pb)])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return link(name, bm, mat)


def extent(obj):
    xs = [v.co for v in obj.data.vertices]
    lo = [min(c[i] for c in xs) for i in range(3)]
    hi = [max(c[i] for c in xs) for i in range(3)]
    # Roblox (x, y, z) = Blender (x, z, -y)
    center = [(lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2, -(lo[1] + hi[1]) / 2]
    size = [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]]
    return [round(c, 6) for c in center], [round(s, 6) for s in size]


def main():
    lib.reset_scene()
    os.makedirs(OUT, exist_ok=True)
    textures = {
        "pulse": tex_pulse(), "glow": tex_glow(), "line": tex_line(), "spark": tex_spark(), "flare": tex_flare(),
        "streak": tex_streak(), "field": tex_field(),
    }
    for s, tag in zip((11, 12, 13), "abc"):
        textures[f"wave_glow_{tag}"] = tex_wave_glow(s)
        textures[f"wave_line_{tag}"] = tex_wave_line(s + 20)
    for k in range(8):
        textures[f"hit_{k + 1}"] = tex_hit(k)
    for name, a in textures.items():
        save_png(name, a)

    mat = bpy.data.materials.new("energy")
    objs, parts = [], {}
    g = hex_grid(mat)
    objs.append(g)
    step = math.pi / 2 / BANDS
    for k in range(BANDS):
        objs.append(sphere_patch(f"Band_{k + 1}", k * step, (k + 1) * step, mat, segments=64, steps=2))
    half = math.sin(CAP)
    objs.append(sphere_patch("HitCap", 0.0, CAP, mat, radius=1.006, segments=48, steps=8,
                             uv=lambda t, p: (0.5 + math.sin(t) * math.cos(p) / (2 * half),
                                              0.5 - math.sin(t) * math.sin(p) / (2 * half))))
    for o in objs:
        center, size = extent(o)
        parts[o.name] = {"center": center, "size": size, "triangles": lib.tris(o)}
    lib.export_fbx(objs, os.path.join(OUT, "energy.fbx"))
    lib.write_json(os.path.join(OUT, "energy.json"), {
        "id": "shield_energy", "bands": BANDS, "bandDegrees": 90 / BANDS, "capHalfAngle": CAP,
        "hexAcrossFlats": 0.147, "parts": parts, "textures": sorted(textures),
        "triangles": sum(p["triangles"] for p in parts.values()),
    })
    print(f"[energy] {len(textures)} textures, {len(objs)} meshes, {sum(p['triangles'] for p in parts.values())} triangles; "
          f"HexGrid {parts['HexGrid']['triangles']}")


main()
