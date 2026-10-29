"""Blast marks: the ground decals an explosion leaves (the user, 2026-10-30:
"make some effect marker for ground when explosion happens instead of a black
circle like in game"). Original, procedural; drawn as Decals on a thin flat
part, like the beam scorch (assets/fx/beam):
- blast_mark_a.png / blast_mark_b.png: the soot, dark greyscale in RGB (not
  tinted), pattern in alpha: a charred centre, blast rays streaking out, a
  ragged edge, a lighter ash ring round the centre and flecks of thrown
  debris beyond the edge. Two variants; the client picks one and turns it to
  a random angle, so no two marks match.
- blast_mark_glow.png: white (tinted hot orange and overbright, as a Decal
  can't emit): a molten centre, a network of glowing cracks and scattered
  embers, laid over the soot and faded in the first seconds.
Previews over sand and grass go to debug_out/scorchfx/.

    blender -b --factory-startup --python-exit-code 1 -P assets/fx/scorch/build.py
"""

import math
import os
import random

import bpy
import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
PREVIEW = os.path.join(OUT, "..", "..", "..", "debug_out", "scorchfx")
N = 512


def save(path, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels[:] = np.clip(rgba[::-1], 0.0, 1.0).astype(np.float32).ravel()  # Blender rows start at the bottom
    s = bpy.context.scene.render.image_settings
    s.file_format, s.color_mode, s.color_depth = "PNG", "RGBA", "8"
    img.save_render(path, scene=bpy.context.scene)
    bpy.data.images.remove(img)
    print("wrote", path)


def value_noise(rng, cells):
    g = np.array([[rng.random() for _ in range(cells + 1)] for _ in range(cells + 1)], dtype=np.float32)
    t = np.arange(N, dtype=np.float32) / N * cells
    i = np.floor(t).astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i, i)] * (1 - f)[None, :] + g[np.ix_(i, i + 1)] * f[None, :]
    b = g[np.ix_(i + 1, i)] * (1 - f)[None, :] + g[np.ix_(i + 1, i + 1)] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def fbm(rng, octaves=(4, 9, 20, 48), weights=(0.45, 0.28, 0.17, 0.1)):
    return sum(value_noise(rng, c) * w for c, w in zip(octaves, weights))


def angular_noise(rng, th, knots, sharp):
    """Noise round the circle (wraps at 2 pi), for the ragged edge."""
    vals = [rng.uniform(-1, 1) for _ in range(knots)]
    t = (th % (2 * math.pi)) / (2 * math.pi) * knots
    i = np.floor(t).astype(int) % knots
    f = t - np.floor(t)
    if not sharp:
        f = f * f * (3 - 2 * f)
    v = np.array(vals + [vals[0]], dtype=np.float32)
    return v[i] * (1 - f) + v[i + 1] * f


def voronoi_edges(rng, cells):
    """Distance to the nearest Voronoi edge (0 on a crack), cells over the image."""
    pts = np.array([[rng.random() * N, rng.random() * N] for _ in range(cells)], dtype=np.float32)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d = np.stack([np.hypot(xx - p[0], yy - p[1]) for p in pts])
    d.sort(axis=0)
    return (d[1] - d[0]) / N


yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
X = (xx + 0.5) / N * 2 - 1
Y = (yy + 0.5) / N * 2 - 1
R = np.hypot(X, Y)
TH = np.arctan2(Y, X)


def rays(rng, count, width, reach):
    """Blast rays: thin wedges streaking out from the centre, of uneven length."""
    out = np.zeros_like(R)
    for _ in range(count):
        a = rng.uniform(-math.pi, math.pi)
        da = np.angle(np.exp(1j * (TH - a)))
        w = rng.uniform(width * 0.5, width * 1.5)
        length = rng.uniform(reach * 0.6, reach)
        fade = np.clip(1 - R / length, 0, 1) ** 0.8
        out = np.maximum(out, np.exp(-(da / w) ** 2) * fade * rng.uniform(0.5, 1.0))
    return out


def flecks(rng, count, r0, r1, size):
    """Thrown debris: small dark specks scattered in a band round the mark."""
    out = np.zeros_like(R)
    for _ in range(count):
        a = rng.uniform(-math.pi, math.pi)
        d = rng.uniform(r0, r1)
        s = rng.uniform(size * 0.4, size)
        cx, cy = math.cos(a) * d, math.sin(a) * d
        out = np.maximum(out, np.clip(1 - np.hypot(X - cx, Y - cy) / s, 0, 1) ** 0.7 * rng.uniform(0.5, 1))
    return out


def mark(seed):
    rng = random.Random(seed)
    n = fbm(rng)
    fine = value_noise(rng, 40) * 0.6 + value_noise(rng, 64) * 0.4
    edge = 0.6 + 0.1 * angular_noise(rng, TH, 7 + seed % 5, False) + 0.05 * angular_noise(rng, TH, 31, True)
    streak = rays(rng, 70, 0.022, 0.95)  # many fine streaks: a blast pattern, not spikes
    # the body: solid near the centre, broken up by noise towards a ragged edge that the rays push out
    reach = edge + 0.2 * streak + 0.08 * (n - 0.5)
    body = np.clip((reach - R) / 0.12, 0, 1) ** 1.1
    body *= 0.5 + 0.5 * np.clip(n * 1.8 - 0.25 + 0.3 * (fine - 0.5), 0, 1)
    core = np.clip(1 - R / 0.5, 0, 1) ** 0.45
    debris = flecks(rng, 90, 0.5, 0.95, 0.022) * (0.6 + 0.4 * fine)
    alpha = np.clip(np.maximum(np.maximum(body, core * 0.97), debris * 0.85), 0, 1)
    alpha *= np.clip((1.0 - R) / 0.06, 0, 1)  # nothing reaches the decal's border
    # shade: black char in the middle, a paler ash ring round it, brown-grey soot outwards
    ash = np.exp(-((R - 0.42 - 0.05 * (n - 0.5)) / 0.08) ** 2) * (0.4 + 0.6 * fine)
    shade = 0.05 + 0.08 * np.clip((R - 0.08) / 0.62, 0, 1) + 0.07 * ash + 0.08 * (n - 0.5) + 0.07 * (fine - 0.5)
    shade -= 0.04 * streak * np.clip(R / 0.3, 0, 1)
    px = np.zeros((N, N, 4), dtype=np.float32)
    shade = np.clip(shade, 0.01, 1)
    px[:, :, 0] = shade * 1.06
    px[:, :, 1] = shade
    px[:, :, 2] = shade * 0.92
    px[:, :, 3] = alpha
    return px


def glow(seed):
    rng = random.Random(seed)
    n = fbm(rng)
    cracks = np.minimum(voronoi_edges(rng, 90), voronoi_edges(rng, 30) * 1.4)
    crack_line = np.exp(-(cracks / (0.003 + 0.003 * n)) ** 2)
    # the cracks glow hottest towards the centre and break up outwards
    crack_line *= np.clip(1 - R / (0.48 + 0.1 * (n - 0.5)), 0, 1) ** 0.8 * np.clip((n - 0.2) * 2.5, 0, 1)
    molten = np.clip(1 - R / (0.16 + 0.05 * (n - 0.5)), 0, 1) ** 1.2
    embers = flecks(rng, 90, 0.1, 0.6, 0.012)
    streak = rays(rng, 24, 0.02, 0.4) * np.clip(1 - R / 0.4, 0, 1)
    a = np.clip(molten + crack_line * 0.9 + embers * 0.8 + streak * 0.25, 0, 1)
    px = np.ones((N, N, 4), dtype=np.float32)
    px[:, :, 3] = a
    return px


textures = {"blast_mark_a": mark(11), "blast_mark_b": mark(27), "blast_mark_glow": glow(5)}
for name, px in textures.items():
    save(os.path.join(OUT, name + ".png"), px)

# previews: each mark over sand and over grass, fresh (glow tinted hot orange, overbright) and cold
os.makedirs(PREVIEW, exist_ok=True)
tint = np.array([1.0, 0.55, 0.18], dtype=np.float32) * 2.2
g = textures["blast_mark_glow"]
for ground_name, ground_rgb in (("sand", (0.76, 0.66, 0.48)), ("grass", (0.32, 0.45, 0.22))):
    tiles = []
    for name in ("blast_mark_a", "blast_mark_b"):
        m = textures[name]
        for fresh in (True, False):
            out = np.ones((N, N, 4), dtype=np.float32)
            base = np.empty((N, N, 3), dtype=np.float32)
            base[:] = ground_rgb
            a = m[:, :, 3:4]
            col = base * (1 - a) + m[:, :, :3] * a
            if fresh:
                col = col + g[:, :, :3] * tint * g[:, :, 3:4]
            out[:, :, :3] = col
            tiles.append(out)
    save(os.path.join(PREVIEW, f"blast_marks_{ground_name}.png"), np.concatenate(tiles, axis=1))
