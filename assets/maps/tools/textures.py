"""Tileable ground textures for the baked map ground (C-167, docs/contracts/map-ground.md):

    <blender python> assets/maps/tools/textures.py <material ...> [--size 1024]

Writes assets/maps/materials/<material>/<material>_{ALB,NOR,RGH,MTL}.png. Each map
repeats every 32 studs on the tiles (u = x / 32, v = z / 32), so every pattern here is
periodic over the image (noise from a filtered random spectrum, ripples on integer wave
vectors) and nothing large or distinctive repeats visibly. Cliff strata (`cliff`) are
for the rock detail meshes: u runs along the cliff, v = height / 32.

Runs in Blender's Python (numpy, no PIL); png.py writes the files.
"""

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import png  # noqa: E402

OUT = os.path.join(HERE, "..", "materials")


def noise(n, rng, beta, lo=1.0, hi=None):
    """Periodic fractal noise, n x n, power ~ 1/f^beta, normalized to [-1, 1]."""
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.where(f >= lo, 1.0 / np.maximum(f, 1e-6) ** (beta / 2), 0.0)
    if hi:
        amp *= f <= hi
    spec = amp * np.exp(2j * np.pi * rng.random((n, n)))
    a = np.real(np.fft.ifft2(spec))
    a -= a.mean()
    return a / (np.abs(a).max() + 1e-9)


def aniso(n, rng, beta, sx, sy, lo=1.0):
    """Periodic noise stretched along x (sx < 1) or y."""
    fy = np.fft.fftfreq(n)[:, None] * n / sy
    fx = np.fft.fftfreq(n)[None, :] * n / sx
    f = np.sqrt(fx * fx + fy * fy)
    f0 = np.sqrt((np.fft.fftfreq(n)[:, None] * n) ** 2 + (np.fft.fftfreq(n)[None, :] * n) ** 2)
    amp = np.where(f0 >= lo, 1.0 / np.maximum(f, 1e-6) ** (beta / 2), 0.0)
    a = np.real(np.fft.ifft2(amp * np.exp(2j * np.pi * rng.random((n, n)))))
    a -= a.mean()
    return a / (np.abs(a).max() + 1e-9)


def grid(n):
    y, x = np.mgrid[0:n, 0:n] / n
    return x, y


def blur(a, r):
    """Periodic box blur (3 passes ~ gaussian), radius r pixels."""
    for _ in range(3):
        for ax in (0, 1):
            acc = np.zeros_like(a)
            for k in range(-r, r + 1):
                acc += np.roll(a, k, axis=ax)
            a = acc / (2 * r + 1)
    return a


def pebbles(n, rng, count, rmin, rmax):
    """Periodic field of small rounded stones: height (0..1) and an id map for tint."""
    h = np.zeros((n, n))
    tint = np.zeros((n, n))
    ys, xs = np.mgrid[0:n, 0:n]
    for _ in range(count):
        cx, cy = rng.random() * n, rng.random() * n
        r = rmin + (rmax - rmin) * rng.random() ** 2
        ex = 0.6 + 0.8 * rng.random()
        ang = rng.random() * np.pi
        x0, x1 = int(cx - r * 2) - 1, int(cx + r * 2) + 2
        y0, y1 = int(cy - r * 2) - 1, int(cy + r * 2) + 2
        xx = np.arange(x0, x1) % n
        yy = np.arange(y0, y1) % n
        dx = (np.arange(x0, x1) - cx)[None, :]
        dy = (np.arange(y0, y1) - cy)[:, None]
        u = (dx * np.cos(ang) + dy * np.sin(ang)) / (r * ex)
        v = (-dx * np.sin(ang) + dy * np.cos(ang)) / (r / ex)
        d = 1 - (u * u + v * v)
        bump = np.sqrt(np.clip(d, 0, 1)) * r
        sub = h[np.ix_(yy, xx)]
        h[np.ix_(yy, xx)] = np.maximum(sub, bump)
        t = tint[np.ix_(yy, xx)]
        tint[np.ix_(yy, xx)] = np.where(d > 0, rng.random() * 2 - 1, t)
    return h, tint


def worley(n, rng, count):
    """Periodic Worley noise: (F1, F2 - F1, cell id) in pixels; F2 - F1 is ~0 on the cell edges."""
    pts = rng.random((count, 2)) * n
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    cid = np.zeros((n, n), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xs - px)
        dx = np.minimum(dx, n - dx)
        dy = np.abs(ys - py)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, i, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2 - f1, cid


def normal_map(h, strength):
    """Tangent-space normal (OpenGL, +Y up in the image = +V) from a periodic height in px units."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    # image rows grow downward while v grows upward on the mesh: flip dy
    nx, ny, nz = -dx, dy, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5


def to8(a):
    return np.clip(np.round(a * 255), 0, 255).astype(np.uint8)


def srgb_mix(base, a):
    """base RGB (0-255) scaled by brightness field a (1 = base)."""
    return np.clip(np.asarray(base, float)[None, None, :] / 255 * a[..., None], 0, 1)


def desert(n, rng):
    """Pale sand: wind ripples, fine grain, a few scattered pebbles, soft tonal drift."""
    x, y = grid(n)
    warp = noise(n, rng, 3.2, lo=1, hi=12) * 0.9 + aniso(n, rng, 3.0, 1.0, 0.35) * 0.4
    # two ripple trains on integer wave vectors (periodic), crests bent by the warp
    r1 = np.sin(2 * np.pi * (11 * x + 3 * y) + warp * 3.0)
    r2 = np.sin(2 * np.pi * (7 * x - 9 * y) + warp * 2.4)
    ripple = 0.5 * (np.sign(r1) * np.abs(r1) ** 0.7) * (0.55 + 0.45 * noise(n, rng, 3.0, hi=6)) \
        + 0.25 * r2 * (0.5 + 0.5 * noise(n, rng, 3.0, hi=5))
    grain = noise(n, rng, 0.6, lo=n / 6)
    drift = noise(n, rng, 3.0, lo=2, hi=10)
    peb_h, peb_t = pebbles(n, rng, 70, 1.0, 3.6)
    height = ripple * 4.0 + grain * 0.35 + peb_h * 1.4 + drift * 1.5
    # crest faces catch the light, troughs hold a little shade and coarser grains
    crest = np.clip(ripple, 0, 1) ** 1.5
    light = 1.0 + 0.11 * ripple + 0.05 * crest + 0.025 * drift + 0.07 * grain + 0.03 * noise(n, rng, 1.6, lo=8)
    alb = srgb_mix((198, 162, 116), light)
    stones = peb_h > 0
    stone_col = np.stack([0.42 + 0.12 * peb_t, 0.32 + 0.08 * peb_t, 0.24 + 0.05 * peb_t], -1)
    alb = np.where(stones[..., None], stone_col * (0.8 + 0.2 * np.clip(peb_h / 2, 0, 1))[..., None], alb)
    rgh = 0.92 - 0.05 * np.clip(ripple, 0, 1) - 0.25 * stones
    return alb, normal_map(height, 0.9), rgh


def ground(n, rng):
    """Packed earth under the supply deposits: darker, crusted, a few cracks."""
    alb, nor, rgh = desert(n, rng)
    cell = noise(n, rng, 2.2, lo=3, hi=40)
    cracks = np.exp(-(np.abs(cell) / 0.035) ** 2) * (noise(n, rng, 3.0, hi=6) > -0.2)
    alb = alb * (0.86 - 0.18 * cracks)[..., None]
    return alb, nor, rgh + 0.03


def redrock(n, rng):
    """Red rock ground (aprons, badlands, mesa tops): weathered slabs split by cracks
    (Worley cell edges), grit, drifted sand in the cracks and hollows, pebbles."""
    f1, edge, cid = worley(n, rng, 120)
    warp = noise(n, rng, 2.6, lo=3, hi=40)
    edge = edge + 6 * warp
    cracks = np.exp(-(np.maximum(edge, 0) / 2.2) ** 2)
    _, edge2, _ = worley(n, rng, 380)
    cracks = np.maximum(cracks, 0.3 * np.exp(-(np.maximum(edge2 + 4 * warp, 0) / 1.4) ** 2))
    slab = (np.sin(cid * 12.9898) * 43758.5453) % 1.0  # per-slab tone and tilt
    tilt = blur(slab - 0.5, 6)
    big = noise(n, rng, 3.0, lo=2, hi=10)
    grit = noise(n, rng, 0.5, lo=n / 5)
    pits = np.clip(noise(n, rng, 1.2, lo=30) * 2 - 1.2, 0, 1)
    sand = np.clip(blur(cracks, 3) * 1.3 + noise(n, rng, 2.6, lo=4, hi=20) * 0.8 - 0.55, 0, 1)
    peb_h, peb_t = pebbles(n, rng, 60, 1.2, 4.0)
    height = big * 2.0 + tilt * 3 - cracks * 2.4 + grit * 0.6 - pits * 0.8 + peb_h * 1.3 - sand * 0.8
    light = 1.0 + 0.09 * big + 0.05 * (slab - 0.5) + 0.08 * grit - 0.11 * cracks - 0.10 * pits
    alb = srgb_mix((170, 92, 60), light)
    hue = blur(slab - 0.5, 3)
    alb = alb * np.stack([1 + 0.05 * hue, 1 + 0.10 * hue, 1 + 0.02 * hue], -1)
    alb = alb * (1 - sand[..., None]) + srgb_mix((196, 146, 104), 1 + 0.06 * grit) * sand[..., None]
    stones = peb_h > 0
    stone_col = np.stack([0.50 + 0.10 * peb_t, 0.27 + 0.06 * peb_t, 0.18 + 0.04 * peb_t], -1)
    alb = np.where(stones[..., None], stone_col * (0.8 + 0.2 * np.clip(peb_h / 2, 0, 1))[..., None], alb)
    rgh = 0.84 + 0.08 * cracks - 0.05 * stones + 0.05 * sand
    return alb, normal_map(height, 0.8), rgh


def cliff(n, rng):
    """Cliff strata for the rock detail meshes: horizontal bands (v = height / 32) in
    reds, orange and cream, vertical desert-varnish streaks, fractures, ledges."""
    x, y = grid(n)
    # band profile: a sum of periodic steps in v, slightly wavy along u
    wav = 0.012 * noise(n, rng, 3.4, hi=4)
    v = y + wav
    tones = np.array([[176, 92, 60], [196, 112, 70], [150, 74, 50], [214, 160, 112], [168, 84, 56],
                      [190, 104, 66], [140, 70, 48], [204, 132, 86]], float) / 255
    k = len(tones)
    edges = np.sort(rng.random(k - 1))
    edges = np.concatenate([[0.0], edges, [1.0]])
    idx = np.searchsorted(edges, v % 1.0, side="right") - 1
    idx = np.clip(idx, 0, k - 1)
    alb = tones[idx]
    # soft bevel at each band edge (ledges catch light at the top, shade below)
    dist = np.min(np.abs((v % 1.0)[..., None] - edges[None, None, :]), -1)
    ledge = np.exp(-(dist / 0.006) ** 2)
    streak = np.clip(aniso(n, rng, 2.4, 1.0, 0.1, lo=3) * 1.8 - 0.25, 0, 1)  # vertical (along v) varnish streaks
    frac = np.exp(-(np.abs(aniso(n, rng, 2.2, 1.0, 0.25, lo=3)) / 0.03) ** 2)
    grit = noise(n, rng, 0.5, lo=n / 5)
    big = noise(n, rng, 3.0, hi=6)
    light = 1.0 + 0.08 * big + 0.09 * grit - 0.38 * streak - 0.35 * frac - 0.22 * ledge
    alb = np.clip(alb * light[..., None], 0, 1)
    height = big * 2 + grit * 0.6 - frac * 2.5 - streak * 0.8 + np.take(np.linspace(0, 3, k), idx) + ledge * 1.5
    rgh = 0.85 + 0.05 * frac
    return alb, normal_map(height, 1.4), rgh


def blades(n, rng, count, length, width):
    """Periodic field of short straight strokes (grass blades, straw): coverage 0..1."""
    out = np.zeros((n, n))
    for _ in range(count):
        cx, cy = rng.random() * n, rng.random() * n
        ang = rng.random() * np.pi
        ln = length * (0.5 + rng.random())
        dx, dy = np.cos(ang), np.sin(ang)
        steps = int(ln * 1.5) + 1
        shade = 0.5 + 0.5 * rng.random()
        for s in range(steps):
            t = s / max(steps - 1, 1) - 0.5
            px, py = int(cx + dx * ln * t) % n, int(cy + dy * ln * t) % n
            r = max(1, int(width))
            ys = np.arange(py - r + 1, py + r) % n
            xs = np.arange(px - r + 1, px + r) % n
            out[np.ix_(ys, xs)] = np.maximum(out[np.ix_(ys, xs)], shade * (1 - abs(t)))
    return out


def grass(n, rng):
    """Meadow grass (the generated maps, Normandy's fields): clumps, blades in every
    direction, darker and yellower patches, a few bare spots; reads at night too."""
    clumps = noise(n, rng, 2.4, lo=4, hi=48)
    patch = noise(n, rng, 3.0, lo=2, hi=10)
    bl = blades(n, rng, 9000, 7, 1)
    fine = noise(n, rng, 0.6, lo=n / 6)
    bare = np.clip(noise(n, rng, 2.8, lo=3, hi=16) * 2.2 - 1.55, 0, 1)
    height = clumps * 2.5 + bl * 1.6 + fine * 0.4 - bare * 1.5
    light = 1.0 + 0.10 * clumps + 0.12 * (bl - 0.4) + 0.06 * fine
    green = srgb_mix((74, 96, 62), light)
    dry = srgb_mix((104, 106, 66), light)
    t = np.clip(patch * 0.8 + 0.35, 0, 1)[..., None] * 0.6
    alb = green * (1 - t) + dry * t
    alb = alb * (1 - bare[..., None]) + srgb_mix((104, 92, 72), 1 + 0.1 * fine) * bare[..., None]
    rgh = 0.9 - 0.08 * bl
    return alb, normal_map(height, 0.9), rgh


def rock(n, rng):
    """Grey crag (rock ridges, Normandy's bluffs, the crag skin): fractured blocks,
    sharp joints, lichen and grit."""
    f1, edge, cid = worley(n, rng, 70)
    warp = noise(n, rng, 2.4, lo=3, hi=40)
    joints = np.exp(-(np.maximum(edge + 5 * warp, 0) / 1.8) ** 2)
    _, edge2, _ = worley(n, rng, 260)
    joints = np.maximum(joints, 0.45 * np.exp(-(np.maximum(edge2 + 3 * warp, 0) / 1.2) ** 2))
    block = (np.sin(cid * 12.9898) * 43758.5453) % 1.0
    tilt = blur(block - 0.5, 5)
    big = noise(n, rng, 2.8, lo=2, hi=12)
    grit = noise(n, rng, 0.5, lo=n / 5)
    lichen = np.clip(noise(n, rng, 2.0, lo=8, hi=80) * 2.4 - 1.3, 0, 1)
    height = big * 2.5 + tilt * 4 - joints * 3.0 + grit * 0.7
    light = 1.0 + 0.12 * big + 0.08 * (block - 0.5) + 0.09 * grit - 0.2 * joints
    alb = srgb_mix((104, 106, 110), light)
    alb = alb * (1 - 0.6 * lichen[..., None]) + srgb_mix((112, 118, 84), light) * 0.6 * lichen[..., None]
    rgh = 0.86 + 0.06 * joints
    return alb, normal_map(height, 1.2), rgh


def sand(n, rng):
    """Beach and river-bed sand: finer and greyer than the desert, damp patches,
    shell grit, faint wave ripples."""
    x, y = grid(n)
    warp = noise(n, rng, 3.2, lo=1, hi=10)
    rip = np.sin(2 * np.pi * (5 * x + 13 * y) + 2.5 * warp)
    damp = np.clip(noise(n, rng, 3.0, lo=2, hi=10) * 1.4, -1, 1)
    grain = noise(n, rng, 0.5, lo=n / 5)
    peb_h, peb_t = pebbles(n, rng, 90, 0.8, 2.4)
    height = rip * 1.2 + grain * 0.4 + peb_h * 1.0
    light = 1.0 + 0.04 * rip + 0.07 * grain - 0.08 * np.clip(damp, 0, 1)
    alb = srgb_mix((168, 160, 134), light)
    stones = peb_h > 0
    shell = np.stack([0.75 + 0.1 * peb_t, 0.72 + 0.1 * peb_t, 0.66 + 0.08 * peb_t], -1)
    alb = np.where(stones[..., None], shell, alb)
    rgh = 0.88 - 0.12 * np.clip(damp, 0, 1)
    return alb, normal_map(height, 0.8), rgh


def road(n, rng):
    """Country road: worn dark tarmac with gravel, patched repairs and cracks."""
    grain = noise(n, rng, 0.4, lo=n / 4)
    gravel_h, gravel_t = pebbles(n, rng, 900, 0.6, 1.6)
    patch_cells = noise(n, rng, 2.6, lo=2, hi=12)
    patch = (patch_cells > 0.45).astype(float)
    _, edge, _ = worley(n, rng, 40)
    cracks = np.exp(-(np.maximum(edge + 6 * noise(n, rng, 2.4, lo=3, hi=40), 0) / 1.0) ** 2) * \
        (noise(n, rng, 3.0, hi=6) > 0.1)
    wear = noise(n, rng, 3.0, lo=1, hi=6)
    height = grain * 0.5 + gravel_h * 0.6 - cracks * 1.5 + patch * 0.3
    light = 1.0 + 0.10 * grain + 0.06 * wear - 0.25 * cracks - 0.05 * patch + 0.25 * (gravel_h > 0) * gravel_t
    alb = srgb_mix((70, 72, 74), light)
    rgh = 0.82 - 0.06 * patch + 0.08 * cracks
    return alb, normal_map(height, 0.8), rgh


def leafy(n, rng):
    """Hedgerow foliage: overlapping leaf clumps, deep shade between them, a few
    lighter young leaves."""
    f1, edge, cid = worley(n, rng, 420)
    size = n / np.sqrt(420)
    dome = np.clip(1 - f1 / (0.75 * size), 0, 1) ** 0.6  # each clump a rounded mound
    tone = (np.sin(cid * 78.233) * 43758.5453) % 1.0
    leaves = blades(n, rng, 6000, 4, 1)
    big = noise(n, rng, 2.8, lo=2, hi=12)
    height = dome * 5 + leaves * 0.8 + big * 1.5
    light = 0.55 + 0.55 * dome + 0.12 * (leaves - 0.3) + 0.06 * big
    alb = srgb_mix((70, 94, 52), light)
    alb = alb * (1 + 0.12 * (tone[..., None] - 0.5) * np.array([0.6, 1.0, 0.4]))
    rgh = 0.75 + 0.1 * (1 - dome)
    return alb, normal_map(height, 1.3), rgh


def bridge(n, rng):
    """Bridge deck: weathered planks across the deck (seams along z), nail rows, wear."""
    x, y = grid(n)
    planks = 24  # per 32 studs
    pid = np.floor(x * planks + 0.02 * noise(n, rng, 3.0, hi=4)).astype(int)
    frac_x = (x * planks) % 1.0
    seam = np.exp(-(np.minimum(frac_x, 1 - frac_x) / 0.05) ** 2)
    tone = (np.sin(pid * 12.9898) * 43758.5453) % 1.0
    grain = aniso(n, rng, 2.0, 1.0, 0.08, lo=4)  # along the plank (v)
    wear = noise(n, rng, 2.8, lo=2, hi=10)
    nails = np.exp(-((frac_x - 0.5) / 0.08) ** 2) * np.exp(-((((y * 4) % 1.0) - 0.5) / 0.03) ** 2)
    height = -seam * 2 + grain * 0.6 + tone * 0.5
    light = 1.0 + 0.16 * (tone - 0.5) + 0.12 * grain + 0.06 * wear - 0.45 * seam - 0.3 * nails
    alb = srgb_mix((122, 104, 80), light)
    rgh = 0.86 + 0.06 * seam
    return alb, normal_map(height, 1.0), rgh


MATERIALS = {"desert": desert, "redrock": redrock, "ground": ground, "cliff": cliff, "grass": grass, "rock": rock,
             "sand": sand, "road": road, "leafy": leafy, "bridge": bridge}


def main():
    args = sys.argv[1:]
    n = 1024
    if "--size" in args:
        i = args.index("--size")
        n = int(args[i + 1])
        del args[i:i + 2]
    contact = None
    if "--contact" in args:
        i = args.index("--contact")
        contact = args[i + 1]
        del args[i:i + 2]
    sheet = []
    for name in args or list(MATERIALS):
        rng = np.random.default_rng(sum(map(ord, name)) * 7919)  # fixed seed per material
        alb, nor, rgh = MATERIALS[name](n, rng)
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        png.write(os.path.join(d, f"{name}_ALB.png"), to8(alb))
        png.write(os.path.join(d, f"{name}_NOR.png"), to8(nor))
        png.write(os.path.join(d, f"{name}_RGH.png"), to8(np.clip(rgh, 0, 1)))
        png.write(os.path.join(d, f"{name}_MTL.png"), np.zeros((n, n), np.uint8))
        # 2 x 2 preview to check the tiling
        png.write(os.path.join(d, "preview_tile.png"), to8(np.tile(alb, (2, 2, 1))))
        print(f"{name}: {n} px -> {os.path.relpath(d)}")
        sheet.append(to8(np.tile(alb, (2, 2, 1))[::4, ::4]))
    if contact:  # the albedos side by side (2 x 2 tiles each, quarter size), to check them in one look
        png.write(contact, np.concatenate(sheet, 1))


if __name__ == "__main__":
    main()
