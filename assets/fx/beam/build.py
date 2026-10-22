"""Beam shot textures for the beam towers (Radiance / Inferno), BAR Pulsar
style but original (docs/contracts/fx.md "Beam shot"): white RGB with the
pattern in alpha, so the client tints them (Order ice-white / cyan, Chaos hot
orange).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/beam/build.py

Beam strips run along X (the beam's length; Roblox Beams lay a texture's
width along the beam) and tile in X; V (Y) runs across the beam:
- beam_core.png: soft-edged bright core with a hot centre line;
- beam_glow.png: wide, faint haze round the core;
- beam_filament_a.png / beam_filament_b.png: thin jagged energy filaments
  with gaps and flicker (three in A, two in B, different waves and seeds) to
  scroll fast along the beam;
Sprites:
- beam_charge.png: charge-up flare, a 2 x 2 flipbook (Grid2x2, frames in
  reading order): a tight glint opening into a four-ray star;
- beam_impact.png: impact flare, a hot core, uneven rays and a ring;
- beam_scorch.png: scorch decal, dark greyscale soot in RGB (not tinted);
- beam_scorch_glow.png: the glowing rim of fresh burns, white (tinted), to
  fade over the scorch in the first second.
Previews of all of them on a dark ground go to debug_out/beamfx/.
"""

import math
import os
import random

import bpy
import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
PREVIEW = os.path.join(OUT, "..", "..", "..", "debug_out", "beamfx")


def save(path, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    # Blender images start at the bottom row
    img.pixels[:] = np.clip(rgba[::-1], 0.0, 1.0).astype(np.float32).ravel()
    s = bpy.context.scene.render.image_settings
    s.file_format, s.color_mode, s.color_depth = "PNG", "RGBA", "8"
    img.save_render(path, scene=bpy.context.scene)
    bpy.data.images.remove(img)
    print("wrote", path)


def white(alpha):
    px = np.ones(alpha.shape + (4,), dtype=np.float32)
    px[:, :, 3] = np.clip(alpha, 0.0, 1.0)
    return px


def periodic_noise(rng, n, knots, smooth=False):
    """n samples of a 1-D noise that wraps (tiles) over n: random values at
    `knots` evenly spaced points, linear (jagged) or cosine (smooth) between."""
    vals = np.array([rng.uniform(-1, 1) for _ in range(knots)] + [0.0], dtype=np.float32)
    vals[-1] = vals[0]
    t = np.arange(n, dtype=np.float32) / n * knots
    i = np.floor(t).astype(int)
    f = t - i
    if smooth:
        f = (1 - np.cos(f * math.pi)) / 2
    return vals[i] * (1 - f) + vals[i + 1] * f


textures = {}

# --- beam strips: x along the beam (tiles), v across it (-1..1) ---------------
W, H = 512, 64
x = np.arange(W, dtype=np.float32)
v = (np.arange(H, dtype=np.float32) + 0.5) / H * 2 - 1
V = np.repeat(v[:, None], W, axis=1)

# core: flat-topped soft core plus a hot centre line; a faint ripple along X
rng = random.Random(11)
ripple = 1.0 + 0.05 * periodic_noise(rng, W, 8, smooth=True)
core = np.exp(-(np.abs(V) / 0.42) ** 2.6) * 0.9 + np.exp(-(V / 0.09) ** 2) * 0.35
textures["beam_core"] = white(core * ripple[None, :] * (1 - V ** 2))

# glow: wide faint haze, zero at the strip's edges
glow = 0.42 * np.exp(-(V / 0.5) ** 2) * (1 - V ** 2) ** 1.5
textures["beam_glow"] = white(glow)

# filaments: thin jagged lines that wander across the strip, with gaps
FW, FH = 1024, 128
fx_ = np.arange(FW, dtype=np.float32)
fv = (np.arange(FH, dtype=np.float32) + 0.5) / FH * 2 - 1
FV = np.repeat(fv[:, None], FW, axis=1)


def filaments(seed, specs):
    rng = random.Random(seed)
    a = np.zeros((FH, FW), dtype=np.float32)
    for off, amp, periods, crackle, width, gap_knots in specs:
        # the wave: whole periods so it tiles, plus jagged crackle
        ph = rng.uniform(0, 2 * math.pi)
        centre = (off + amp * np.sin(2 * math.pi * periods * fx_ / FW + ph)
                  + 0.45 * amp * np.sin(2 * math.pi * (periods * 2 + 1) * fx_ / FW + ph * 1.7)
                  + crackle * periodic_noise(rng, FW, 26)
                  + 0.55 * crackle * periodic_noise(rng, FW, 63))
        d = FV - centre[None, :]
        line = np.exp(-(d / width) ** 2) + 0.14 * np.exp(-(d / (width * 3.5)) ** 2)
        # gaps and flicker along the length: on segments, off gaps
        g = periodic_noise(rng, FW, gap_knots)
        mask = np.clip((g + 0.35) * 2.2, 0.0, 1.0) * (0.75 + 0.25 * periodic_noise(rng, FW, 40))
        a = np.maximum(a, line * mask[None, :])
    return a * (1 - FV ** 2) ** 0.5


textures["beam_filament_a"] = white(filaments(21, [
    (0.0, 0.22, 2, 0.16, 0.036, 9),
    (0.18, 0.3, 3, 0.18, 0.032, 7),
    (-0.22, 0.28, 1, 0.17, 0.03, 11),
]))
textures["beam_filament_b"] = white(filaments(57, [
    (0.08, 0.32, 3, 0.19, 0.034, 8),
    (-0.12, 0.25, 4, 0.16, 0.03, 10),
]))

# --- sprites --------------------------------------------------------------------
S = 256


def polar(n):
    c = (np.arange(n, dtype=np.float32) + 0.5) / n * 2 - 1
    X, Y = np.meshgrid(c, c)
    return np.sqrt(X * X + Y * Y), np.arctan2(Y, X)


def star(r, th, size, rays, ray_len, ray_w, rot, core_r, rng):
    """A glint: soft core plus `rays` thin tapered rays of uneven length."""
    a = np.exp(-(r / (core_r * size)) ** 2) * 1.2
    for k in range(rays):
        ang = rot + 2 * math.pi * k / rays + rng.uniform(-0.06, 0.06)
        ln = ray_len * size * rng.uniform(0.75, 1.0) * (1.0 if k % 2 == 0 else 0.55)
        da = np.angle(np.exp(1j * (th - ang)))
        across = np.abs(np.sin(da)) * r
        along = np.cos(da) * r
        a += (np.exp(-(across / (ray_w * (1 - np.clip(along / ln, 0, 1)) + 1e-4)) ** 2)
              * np.clip(1 - along / ln, 0, 1) ** 1.5 * (along > 0))
    a += 0.25 * np.exp(-(r / (0.45 * size)) ** 2)
    return a


r, th = polar(S)
rng = random.Random(5)
frames = []
for i, (size, rot) in enumerate([(0.35, 0.0), (0.6, 0.12), (0.85, 0.22), (1.0, 0.3)]):
    frames.append(star(r, th, size, 8, 0.95, 0.035, rot, 0.13 + 0.03 * i, random.Random(5 + i)))
sheet = np.zeros((2 * S, 2 * S), dtype=np.float32)
for i, f in enumerate(frames):
    sheet[(i // 2) * S:(i // 2 + 1) * S, (i % 2) * S:(i % 2 + 1) * S] = f * np.clip((1 - r) * 4, 0, 1)
textures["beam_charge"] = white(sheet)

# impact: hot core, many uneven rays, a soft shock ring
IS = 512
r, th = polar(IS)
rng = random.Random(9)
imp = np.exp(-(r / 0.1) ** 2) * 1.3 + 0.35 * np.exp(-(r / 0.32) ** 2)
for k in range(14):
    ang = rng.uniform(0, 2 * math.pi)
    ln = rng.uniform(0.45, 0.95)
    da = np.angle(np.exp(1j * (th - ang)))
    across = np.abs(np.sin(da)) * r
    along = np.cos(da) * r
    imp += (np.exp(-(across / (0.02 * (1 - np.clip(along / ln, 0, 1)) + 1e-4)) ** 2)
            * np.clip(1 - along / ln, 0, 1) ** 2 * (along > 0) * rng.uniform(0.5, 1.0))
imp += 0.3 * np.exp(-((r - 0.62) / 0.05) ** 2) * (0.7 + 0.3 * np.cos(th * 5 + 1))
textures["beam_impact"] = white(imp * np.clip((1 - r) * 5, 0, 1))


def value_noise_2d(rng, n, cells):
    g = np.array([[rng.random() for _ in range(cells + 1)] for _ in range(cells + 1)], dtype=np.float32)
    t = np.arange(n, dtype=np.float32) / n * cells
    i = np.floor(t).astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i, i)] * (1 - f)[None, :] + g[np.ix_(i, i + 1)] * f[None, :]
    b = g[np.ix_(i + 1, i)] * (1 - f)[None, :] + g[np.ix_(i + 1, i + 1)] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


# scorch: ragged blotch, streaks radiating out, darkest in the middle
rng = random.Random(3)
n = (value_noise_2d(rng, IS, 6) * 0.55 + value_noise_2d(rng, IS, 18) * 0.3 + value_noise_2d(rng, IS, 48) * 0.15)
streak = np.zeros_like(r)
for k in range(22):
    ang = rng.uniform(0, 2 * math.pi)
    da = np.angle(np.exp(1j * (th - ang)))
    streak = np.maximum(streak, np.exp(-(da / rng.uniform(0.04, 0.1)) ** 2) * rng.uniform(0.3, 0.8))
edge = 0.5 + 0.22 * (n - 0.5) * 2 + 0.25 * streak
alpha = np.clip((edge - r) / 0.18, 0, 1) ** 1.3 * (0.65 + 0.35 * n)
alpha = np.maximum(alpha, np.clip(1 - r / 0.25, 0, 1) * 0.95)
shade = 0.06 + 0.16 * np.clip(r / 0.6, 0, 1) + 0.08 * (n - 0.5)
sc = np.zeros((IS, IS, 4), dtype=np.float32)
sc[:, :, 0] = sc[:, :, 1] = sc[:, :, 2] = np.clip(shade, 0, 1)
sc[:, :, 3] = np.clip(alpha, 0, 1)
textures["beam_scorch"] = sc

# fresh-burn glow: a broken ember rim and a hot centre, white for tinting
rim = np.exp(-((r - 0.2 - 0.06 * (n - 0.5) * 2) / 0.05) ** 2) * np.clip((n - 0.35) * 3, 0, 1)
hot = np.exp(-(r / 0.12) ** 2) * 0.9
textures["beam_scorch_glow"] = white(np.clip(rim + hot + 0.4 * streak * np.exp(-(r / 0.35) ** 2), 0, 1))

for name, px in textures.items():
    save(os.path.join(OUT, name + ".png"), px)

# previews: tinted (Order ice-cyan) and composited over a dark ground; strips tiled twice
os.makedirs(PREVIEW, exist_ok=True)
tint = np.array([0.7, 0.92, 1.0], dtype=np.float32)
for name, px in textures.items():
    if name.startswith("beam_") and px.shape[1] in (W, FW):
        px = np.concatenate([px, px], axis=1)
    ground = np.full(px.shape[:2] + (3,), 0.12, dtype=np.float32)
    col = px[:, :, :3] * (tint if name != "beam_scorch" else 1.0)
    out = np.ones(px.shape, dtype=np.float32)
    a = px[:, :, 3:4]
    out[:, :, :3] = ground * (1 - a) + col * a if name == "beam_scorch" else ground + col * a
    save(os.path.join(PREVIEW, name + "_preview.png"), out)
