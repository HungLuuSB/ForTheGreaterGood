"""The shield's energy column and dome waves (the user's redesign
2026-10-24, docs/contracts/fx.md "Energy column" and "Dome waves"):

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/shield/waves/build.py

The user's reference: a column of vortex energy rising from the emitter to
the top of the dome (channelling energy into the shield; thinner as the
shield weakens, collapsing when it's down), and wide waves of energy
rolling down the dome rather than small rings.

- column_core.png, column_swirl.png, column_glow.png: Beam textures (white,
  the client tints; U across the beam, V along it, seamless along V). Core:
  a bright thin line with a soft glow; swirl: helical streaks crossing at
  two pitches (the near and far side of a twisting vortex), soft at the
  edges; glow: a wide soft halo.
- wave.png: the wave across a band (U round the dome, 4 repeats; V across
  the band from its top edge 0 to its lower edge 1): a broad hump of energy,
  brightest towards the lower side, faint filaments; alpha 0 at both edges.
- wave_1 .. wave_N: the dome surface (radius WAVE_R, just over the
  honeycomb shell) cut into N bands whose centres step evenly from the top
  (0) to the rim (90), each spanning two steps (50% overlap with its
  neighbours; clients-B's request): a wave between two band centres shows
  both, weighted (1 - f, f), so it moves smoothly. UV V runs across each
  band's full nominal width (the top band is clipped at the pole, the last
  at the rim), so the crest sits at the same place in every band.
Writes export/waves.fbx, the PNGs and export/waves.json (bands: polar range,
centre and size at radius 1 in Roblox space, +Y up).
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
WAVE_R = 1.005  # over the honeycomb shell (1.003)
N = 16  # bands
WIDTH = 2 * 90.0 / (N - 1)  # degrees: two centre spacings, 50% overlap
STEP = 2.0  # polar step of the mesh (degrees)
SEGMENTS = 72  # round
U_REPEAT = 4  # the wave texture's repeats round the dome


def periodic_noise(u, v, seed, octaves=3):
    """Smooth noise, periodic in u and v (sums of integer-frequency waves)."""
    rng = np.random.default_rng(seed)
    out = np.zeros_like(u)
    amp = 1.0
    for o in range(octaves):
        for _ in range(4):
            fu, fv = rng.integers(1, 3 + o * 3), rng.integers(1, 3 + o * 3)
            ph = rng.uniform(0, 2 * math.pi)
            out += amp * np.sin(2 * math.pi * (fu * u + fv * v) + ph)
        amp *= 0.5
    return out / np.abs(out).max()


def tex_core(w=128, h=512):
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, Vv = np.meshgrid(u, v)
    x = U - 0.5
    flicker = 0.85 + 0.15 * periodic_noise(U * 0 + 0.0, Vv, 3, 2)
    a = np.exp(-(x / 0.05) ** 2) + 0.45 * np.exp(-(x / 0.18) ** 2)
    return np.clip(a * flicker, 0, 1)


def tex_swirl(w=256, h=512):
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, Vv = np.meshgrid(u, v)
    warp = 0.06 * periodic_noise(U, Vv, 5)
    a = np.zeros_like(U)
    # two families of helical streaks: the near side (steep, bright) and the far side (opposite slope, dimmer)
    # the near side's streaks all twist one way (bright, broken along their length); the far side's, the
    # other way, faint: it reads as one twisting vortex, not a lattice
    for slope, k, bright, sharp, seed in ((2.2, 2, 1.0, 7.0, 21), (2.2, 3, 0.55, 12.0, 22), (-2.2, 2, 0.18, 9.0, 23)):
        phase = (k * (Vv + slope * (U - 0.5) / 4.0) + warp) % 1.0
        streak = np.exp(-((phase - 0.5) * sharp) ** 2)
        broken = np.clip(0.55 + 0.6 * periodic_noise(U, Vv * 2, seed), 0, 1)
        a = np.maximum(a, streak * bright * broken)
    x = (U - 0.5) * 2
    edge = np.clip(1 - x ** 6, 0, 1)  # soft at the beam's edges
    wisp = 0.75 + 0.25 * periodic_noise(U, Vv, 9)
    return np.clip(a * edge * wisp, 0, 1)


def tex_glow(w=128, h=128):
    u = (np.arange(w) + 0.5) / w
    U, _ = np.meshgrid(u, np.arange(h))
    return np.exp(-((U - 0.5) / 0.26) ** 2)


def tex_wave(w=1024, h=256):
    """A broad hump of energy filling most of the band, brightest towards its
    lower (leading) side, soft above; alpha 0 at both edges, so two
    overlapping bands weighted (1 - f, f) blend into one wide wave that
    slides smoothly (not two thin lines)."""
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, Vv = np.meshgrid(u, v)
    window = np.sin(np.pi * Vv) ** 1.2  # 0 at both edges
    glow = 0.32 * np.sin(np.pi * Vv ** 1.3) ** 2  # the soft body of the wave
    front = 0.85 * np.exp(-((Vv - 0.66) / 0.13) ** 2)  # the brighter leading side, wide enough to blend across bands
    filaments = 0.65 + 0.35 * periodic_noise(U, Vv * 0.3, 11)
    streaks = 0.16 * np.clip(periodic_noise(U * 2, Vv * 0.15, 13), 0, 1)
    a = ((glow + front) * filaments + streaks * glow * 3) * window
    return np.clip(a, 0, 1)


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
    """Blender space (Z up) on the wave shell; theta from the pole, radians."""
    s = math.sin(theta)
    return (WAVE_R * s * math.cos(phi), WAVE_R * s * math.sin(phi), WAVE_R * math.cos(theta))


def band(name, centre, col, mat):
    """The shell from centre - WIDTH/2 to centre + WIDTH/2 (degrees, clipped to 0..90)."""
    top = centre - WIDTH / 2
    t0, t1 = max(0.0, top), min(90.0, centre + WIDTH / 2)
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    n = max(1, round((t1 - t0) / STEP))
    thetas = [math.radians(t0 + (t1 - t0) * k / n) for k in range(n + 1)]
    phis = [2 * math.pi * j / SEGMENTS for j in range(SEGMENTS + 1)]

    def uv(t, p):
        return (p / (2 * math.pi) * U_REPEAT, 1.0 - (math.degrees(t) - top) / WIDTH)  # Blender's V runs up: texture V 0 at the top edge

    def face(corners):
        verts = [bm.verts.new(point(t, p)) for t, p in corners]
        f = bm.faces.new(verts)
        for loop, (t, p) in zip(f.loops, corners):
            loop[layer].uv = uv(t, p)

    for k in range(n):
        ta, tb = thetas[k], thetas[k + 1]
        for j in range(SEGMENTS):
            pa, pb = phis[j], phis[j + 1]
            if ta == 0:
                face([(0.0, (pa + pb) / 2), (tb, pa), (tb, pb)])
            else:
                face([(ta, pa), (tb, pa), (tb, pb), (ta, pb)])
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
    return obj, t0, t1


def main():
    lib.reset_scene()
    os.makedirs(OUT, exist_ok=True)
    col = bpy.context.scene.collection
    mat = bpy.data.materials.new("wave")
    for name, fn in (("column_core", tex_core), ("column_swirl", tex_swirl), ("column_glow", tex_glow)):
        save_png(name, fn())
    wave = save_png("wave", tex_wave())
    probe = lib.image_probe("tex_wave", wave, col, at=(3.0, 0.0, 0.0))
    bands, objs = [], []
    for k in range(N):
        centre = 90.0 * k / (N - 1)
        o, t0, t1 = band(f"wave_{k + 1}", centre, col, mat)
        objs.append(o)
        r_out = WAVE_R * math.sin(math.radians(min(t1, 90.0)))
        r_in = WAVE_R * math.sin(math.radians(t0))
        y_lo, y_hi = WAVE_R * math.cos(math.radians(t1)), WAVE_R * math.cos(math.radians(t0))
        bands.append({"name": o.name, "centre": round(centre, 4), "theta": [round(t0, 4), round(t1, 4)],
                      "triangles": lib.tris(o), "center": [0.0, round((y_lo + y_hi) / 2, 6), 0.0],
                      "size": [round(2 * max(r_out, r_in), 6), round(y_hi - y_lo, 6), round(2 * max(r_out, r_in), 6)]})
    lib.export_fbx(objs + [probe], os.path.join(OUT, "waves.fbx"))
    lib.write_json(os.path.join(OUT, "waves.json"), {
        "id": "shield_waves", "radius": WAVE_R, "width": WIDTH, "uRepeat": U_REPEAT, "bands": bands,
        "triangles": sum(b["triangles"] for b in bands),
    })
    print(f"[waves] {len(bands)} bands, {sum(b['triangles'] for b in bands)} triangles")


main()
