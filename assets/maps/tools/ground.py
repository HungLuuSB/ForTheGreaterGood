"""Bakes a named map's ground into mesh tiles and rock detail (C-167,
docs/contracts/map-ground.md), in Blender 5.2, headless:

    blender -b --factory-startup --python-exit-code 1 -P assets/maps/tools/ground.py -- <map name> [--no-preview]

Input: assets/maps/<name>/ground.json (`lune run export_ground map:<name>`).
Output in assets/maps/<name>/export/:
  - ground_<part>.fbx: the meshes, split so each upload stays under the size limit;
  - ground.json (rig): every mesh's name, world centre and size (Roblox axes), material and triangles;
  - preview_*.png: Blender renders (gitignored).

Tiles: the height samples as they are (every 4 studs), one mesh per TILE x TILE studs and
ground type, seams on cell edges, world-space UVs (u = x / 32, v = z / 32), normals from the
whole height field so tiles and ground types join without a shading seam.

Detail (the map's style, per map in STYLES): for the Canyon, each mesa's slopes are covered
by terraced strata traced up the real slope (a cliff band, then a talus slope, repeated, under
a caprock lip), which always lie on or above the drawn surface; boulders on the `boulder` cells
and talus at the mesa feet. Walls use `cliff` (u along the cliff, v = height / 32, so the strata
line up across mesas); slopes, lips and boulders `redrock`.
"""

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "models", "tools"))
import lib  # noqa: E402
from lib import R  # noqa: E402

sys.path.insert(0, HERE)
import textures  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TILE = 256  # studs per tile side (64 quads: 8,192 triangles at most per tile and type)
UV_REPEAT = 32.0
MAX_PART_TRIS = 120_000  # per FBX upload (Open Cloud: 20 MB a file)

STYLES = {
    "canyon": {"strata": True, "boulders": True, "wall": "cliff", "rock": "redrock", "aim": ("feature", "cliff")},
    # the generated maps: grass hills with grey rock ridges
    "ridgeline": {"crag": "rock", "boulders": True, "rock": "rock", "aim": ("material", "rock")},
    "coastline": {"crag": "rock", "boulders": True, "rock": "rock", "aim": ("material", "rock")},
    "twin_lakes": {"crag": "rock", "boulders": True, "rock": "rock", "aim": ("material", "rock")},
    "crossroads": {"crag": "rock", "boulders": True, "rock": "rock", "aim": ("material", "rock")},
    # the bocage: hedgerow foliage on the banks, crag on the bluffs
    "normandy": {"crag": "rock", "hedges": "leafy", "keep_cells": True, "boulders": True, "rock": "rock", "aim": ("feature", "hedge")},
}


# ---------------------------------------------------------------------------
# Height field
# ---------------------------------------------------------------------------


class Field:
    def __init__(self, g):
        self.ox, self.oz = g["origin"]
        self.sx, self.sz = g["size"]
        self.step = g["step"]
        self.nx, self.nz = g["vertices"]
        self.h = np.array(g["heights"], float).reshape(self.nz, self.nx)
        self.cw, self.cd = g["cells"]
        self.cell = g["cellSize"]
        self.mat_pal = g["materialPalette"]
        self.mat = np.array(g["materials"]).reshape(self.cd, self.cw)
        self.feat_pal = g["featurePalette"]
        self.feat = np.array(g["features"]).reshape(self.cd, self.cw)
        self.per_cell = self.cell // self.step
        gz, gx = np.gradient(self.h, self.step)
        self.gx, self.gz = gx, gz

    def at(self, x, z):
        """Bilinear height at world (x, z), clamped to the map."""
        fx = np.clip((x - self.ox) / self.step, 0, self.nx - 1.001)
        fz = np.clip((z - self.oz) / self.step, 0, self.nz - 1.001)
        i, j = int(fx), int(fz)
        tx, tz = fx - i, fz - j
        h = self.h
        return (h[j, i] * (1 - tx) * (1 - tz) + h[j, i + 1] * tx * (1 - tz)
                + h[j + 1, i] * (1 - tx) * tz + h[j + 1, i + 1] * tx * tz)

    def grad(self, x, z):
        e = 0.75
        return ((self.at(x + e, z) - self.at(x - e, z)) / (2 * e), (self.at(x, z + e) - self.at(x, z - e)) / (2 * e))

    def inside(self, x, z, pad=0.0):
        return self.ox - pad <= x <= self.ox + self.sx + pad and self.oz - pad <= z <= self.oz + self.sz + pad


# ---------------------------------------------------------------------------
# Mesh helpers
# ---------------------------------------------------------------------------


def make_object(name, verts, faces, uvs=None, normals=None, smooth=True):
    """verts in Roblox world space; uvs per face corner (list per face)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([R(*v) for v in verts], [], faces)
    if uvs is not None:
        layer = me.uv_layers.new(name="UVMap")
        flat = [c for f in uvs for uv in f for c in uv]
        layer.data.foreach_set("uv", flat)
    if smooth:
        me.shade_smooth()
    if normals is not None:
        me.normals_split_custom_set_from_vertices([R(*n) for n in normals])
    me.validate(clean_customdata=False)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def world_bounds(verts):
    a = np.array(verts)
    lo, hi = a.min(0), a.max(0)
    return [round(float(v), 4) for v in (lo + hi) / 2], [round(float(max(v, 0.01)), 4) for v in hi - lo]


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------


def blur2(a, sigma):
    """Separable gaussian blur (edge-clamped) of a 2D array, sigma in samples."""
    r = max(1, int(3 * sigma))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    for ax in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[ax] = (r, r)
        p = np.pad(a, pad, mode="edge")
        a = sum(k[i] * np.take(p, np.arange(i, i + a.shape[ax]), axis=ax) for i in range(2 * r + 1))
    return a


def smooth_noise(shape, rng, sigma):
    return blur2(rng.standard_normal(shape), sigma) * sigma * 1.8


def material_weights(f, rng, keep_cells=False):
    """Per height sample, a weight per ground type: the cell types spread to the samples,
    blurred and stirred with noise, so the border between two types is a smooth wavy line
    instead of the cell grid's staircase. Types on very few cells (the Canyon's `ground`
    under the deposits, which the deposit models cover) join their neighbours. `keep_cells`:
    every cell keeps its own type at its centre sample, so 1-cell features (Normandy's hedge
    banks, its 2-cell roads) aren't blurred away."""
    mats = f.mat.copy()
    counts = np.bincount(mats.ravel(), minlength=len(f.mat_pal))
    small = [m for m in range(len(f.mat_pal)) if 0 < counts[m] < 0.005 * mats.size]
    for m in small:
        zs, xs = np.where(mats == m)
        for z, x in zip(zs, xs):
            near = [mats[zz, xx] for zz, xx in ((z - 1, x), (z + 1, x), (z, x - 1), (z, x + 1))
                    if 0 <= zz < f.cd and 0 <= xx < f.cw and mats[zz, xx] not in small]
            if near:
                mats[z, x] = max(set(near), key=near.count)
    used = [m for m in range(len(f.mat_pal)) if (mats == m).any()]
    pc = f.per_cell
    w = np.zeros((len(used), f.nz, f.nx))
    for k, m in enumerate(used):
        ind = np.repeat(np.repeat((mats == m).astype(float), pc, 0), pc, 1)  # per quad
        q = np.pad(ind, 1, mode="edge")
        w[k] = (q[:-1, :-1] + q[1:, :-1] + q[:-1, 1:] + q[1:, 1:]) / 4  # per sample
        w[k] = blur2(w[k], 1.6) + 0.22 * smooth_noise(w[k].shape, rng, 3.0)
    if keep_cells:
        idx = {m: k for k, m in enumerate(used)}
        for cz in range(f.cd):
            for cx in range(f.cw):
                j, i = cz * pc + pc // 2, cx * pc + pc // 2
                k = idx[mats[cz, cx]]
                others = np.delete(w[:, j, i], k)
                w[k, j, i] = max(w[k, j, i], (others.max() if len(others) else 0) + 0.3)
    # rock features always stay rock (the strata stand on them)
    if "redrock" in [f.mat_pal[m] for m in used]:
        rock = [f.mat_pal[m] for m in used].index("redrock")
        feat = {n: i for i, n in enumerate(f.feat_pal)}
        hard = np.isin(f.feat, [feat[n] for n in ("cliff", "mesa") if n in feat])
        hs = np.repeat(np.repeat(hard, pc, 0), pc, 1)
        hs = np.pad(hs, ((0, 1), (0, 1)), mode="edge")
        w[rock] = np.where(hs, w[rock] + 2.0, w[rock])
    return [f.mat_pal[m] for m in used], w


def clip(poly, a, b):
    """Keeps the part of a polygon where weight a >= weight b (each vertex: dict with 'w')."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        dp, dq = p["w"][a] - p["w"][b], q["w"][a] - q["w"][b]
        if dp >= 0:
            out.append(p)
        if (dp >= 0) != (dq >= 0):
            t = dp / (dp - dq)
            out.append({k: p[k] + (q[k] - p[k]) * t for k in ("pos", "nor", "w")})
    return out


def build_tiles(f, records, rng, style=None):
    pc = f.per_cell
    names, w = material_weights(f, rng, (style or {}).get("keep_cells", False))
    nm = len(names)
    nxs, nzs = -f.gx, -f.gz
    ln = np.sqrt(nxs ** 2 + 1 + nzs ** 2)
    win = np.argmax(w, 0)
    tiles_x = math.ceil(f.sx / TILE)
    tiles_z = math.ceil(f.sz / TILE)
    q_per_tile = TILE // f.step
    nqx, nqz = f.nx - 1, f.nz - 1

    def corner(i, j):
        return {"pos": np.array([f.ox + i * f.step, f.h[j, i], f.oz + j * f.step]),
                "nor": np.array([nxs[j, i], 1.0, nzs[j, i]]) / ln[j, i], "w": w[:, j, i]}

    for tz in range(tiles_z):
        for tx in range(tiles_x):
            out = {m: {"index": {}, "verts": [], "normals": [], "faces": []} for m in range(nm)}

            def emit(m, pts):
                o = out[m]
                ids = []
                for p in pts:
                    key = (round(float(p["pos"][0]), 3), round(float(p["pos"][2]), 3))
                    if key not in o["index"]:
                        o["index"][key] = len(o["verts"])
                        o["verts"].append(tuple(float(v) for v in p["pos"]))
                        nn = p["nor"] / np.linalg.norm(p["nor"])
                        o["normals"].append(tuple(float(v) for v in nn))
                    ids.append(o["index"][key])
                for k in range(1, len(ids) - 1):
                    t = (ids[0], ids[k], ids[k + 1])
                    if len(set(t)) == 3:
                        o["faces"].append(t)

            for j in range(tz * q_per_tile, min((tz + 1) * q_per_tile, nqz)):
                for i in range(tx * q_per_tile, min((tx + 1) * q_per_tile, nqx)):
                    h = f.h
                    if abs(h[j, i] - h[j + 1, i + 1]) <= abs(h[j, i + 1] - h[j + 1, i]):
                        tris = [((i, j), (i + 1, j + 1), (i + 1, j)), ((i, j), (i, j + 1), (i + 1, j + 1))]
                    else:
                        tris = [((i, j), (i, j + 1), (i + 1, j)), ((i + 1, j), (i, j + 1), (i + 1, j + 1))]
                    for tri in tris:
                        ms = {int(win[jj, ii]) for ii, jj in tri}
                        if len(ms) == 1:
                            emit(ms.pop(), [corner(ii, jj) for ii, jj in tri])
                            continue
                        base = [corner(ii, jj) for ii, jj in tri]
                        for m in ms:
                            poly = base
                            for b in range(nm):
                                if b != m and poly:
                                    poly = clip(poly, m, b)
                            if len(poly) >= 3:
                                emit(m, poly)
            for m, o in out.items():
                if not o["faces"]:
                    continue
                key = names[m]
                uvs = [[(o["verts"][k][0] / UV_REPEAT, o["verts"][k][2] / UV_REPEAT) for k in t] for t in o["faces"]]
                name = f"t{tx}_{tz}_{key}"
                ob = make_object(name, o["verts"], o["faces"], uvs, o["normals"])
                center, size = world_bounds(o["verts"])
                records.append({"name": name, "kind": "tiles", "material": key, "center": center, "size": size,
                                "triangles": tri_count(ob), "object": ob})
    return names, w


# ---------------------------------------------------------------------------
# Canyon strata
# ---------------------------------------------------------------------------


def components(mask):
    """4-connected components of a boolean cell mask: list of (cz, cx) arrays."""
    seen = np.zeros_like(mask, bool)
    out = []
    d, w = mask.shape
    for z0 in range(d):
        for x0 in range(w):
            if not mask[z0, x0] or seen[z0, x0]:
                continue
            stack, cells = [(z0, x0)], []
            seen[z0, x0] = True
            while stack:
                z, x = stack.pop()
                cells.append((z, x))
                for dz, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    zz, xx = z + dz, x + dx
                    if 0 <= zz < d and 0 <= xx < w and mask[zz, xx] and not seen[zz, xx]:
                        seen[zz, xx] = True
                        stack.append((zz, xx))
            out.append(np.array(cells))
    return out


def contour_loops(field, level, valid):
    """Marching squares on `field` (samples, z rows) at `level`; squares where `valid` is
    False are skipped. Returns chained polylines in sample coordinates (x, z)."""
    nz, nx = field.shape
    segs = {}

    def interp(p, q, vp, vq):
        t = (level - vp) / (vq - vp)
        return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)

    edges_pts = {}

    def edge_point(e, p, q, vp, vq):
        if e not in edges_pts:
            edges_pts[e] = interp(p, q, vp, vq)
        return e

    adj = {}

    def link(e1, e2):
        adj.setdefault(e1, []).append(e2)
        adj.setdefault(e2, []).append(e1)

    above = field >= level
    for j in range(nz - 1):
        for i in range(nx - 1):
            if not valid[j, i]:
                continue
            c = (above[j, i], above[j, i + 1], above[j + 1, i + 1], above[j + 1, i])
            if all(c) or not any(c):
                continue
            v = (field[j, i], field[j, i + 1], field[j + 1, i + 1], field[j + 1, i])
            p = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
            # edges: 0 top (p0-p1), 1 right (p1-p2), 2 bottom (p2-p3), 3 left (p3-p0)
            keys = [("h", i, j), ("v", i + 1, j), ("h", i, j + 1), ("v", i, j)]
            crossing = []
            for e in range(4):
                a, b = e, (e + 1) % 4
                if c[a] != c[b]:
                    crossing.append(edge_point(keys[e], p[a], p[b], v[a], v[b]))
            if len(crossing) == 2:
                link(crossing[0], crossing[1])
            elif len(crossing) == 4:  # saddle: pair by the centre value
                centre = sum(v) / 4 >= level
                if centre == c[0]:
                    link(crossing[0], crossing[1])
                    link(crossing[2], crossing[3])
                else:
                    link(crossing[0], crossing[3])
                    link(crossing[1], crossing[2])
    loops, used = [], set()
    # open chains first (from their ends), then the closed loops
    starts = [e for e in adj if len(adj[e]) == 1] + [e for e in adj if len(adj[e]) == 2]
    for start in starts:
        if start in used:
            continue
        loop, prev, cur = [start], None, start
        used.add(start)
        closed = False
        while True:
            nxt = [e for e in adj[cur] if e != prev and (e not in used or e == start)]
            if not nxt:
                break
            n = nxt[0]
            if n == start:
                closed = len(loop) > 2
                break
            used.add(n)
            loop.append(n)
            prev, cur = cur, n
        pts = [edges_pts[e] for e in loop]
        if not closed and len(pts) > 8:
            gap = math.hypot(pts[0][0] - pts[-1][0], pts[0][1] - pts[-1][1])
            closed = gap < 2.0  # in samples: a loop cut by the mask, nearly closed
        loops.append((pts, closed))
    return loops


def resample(pts, closed, spacing):
    a = np.array(pts, float)
    if closed:
        a = np.vstack([a, a[:1]])
    seg = np.sqrt(((a[1:] - a[:-1]) ** 2).sum(1))
    total = seg.sum()
    n = max(int(round(total / spacing)), 8)
    s = np.concatenate([[0], np.cumsum(seg)])
    t = np.linspace(0, total, n, endpoint=not closed)
    return np.stack([np.interp(t, s, a[:, 0]), np.interp(t, s, a[:, 1])], 1), total


def smooth_ring(p, closed, passes=2):
    for _ in range(passes):
        if closed:
            p = (np.roll(p, 1, 0) + 2 * p + np.roll(p, -1, 0)) / 4
        else:
            q = p.copy()
            q[1:-1] = (p[:-2] + 2 * p[1:-1] + p[2:]) / 4
            p = q
    return p


def periodic_noise(n, rng, octaves, closed):
    """Smooth noise along a ring of n points (periodic when closed), about [-1, 1]."""
    t = np.arange(n) / n
    out = np.zeros(n)
    for k in range(1, octaves + 1):
        freq = int(rng.integers(2 + 3 * k, 6 + 8 * k)) if closed else (2 + 3 * k + rng.random() * 8 * k)
        out += np.sin(2 * np.pi * (freq * t + rng.random())) / k
    return out / np.abs(out).max()


def trace_levels(f, x, z, levels, max_len=120.0):
    """Walks uphill from (x, z) along the gradient; the position where the surface reaches
    each level (the last position when it never does) and the uphill direction there."""
    out = []
    k = 0
    step = 0.4
    px, pz = x, z
    h = f.at(px, pz)
    walked = 0.0
    last_dir = None
    while k < len(levels) and walked < max_len:
        while k < len(levels) and h >= levels[k]:
            out.append((px, pz, last_dir))
            k += 1
        if k >= len(levels):
            break
        gx, gz = f.grad(px, pz)
        g = math.hypot(gx, gz)
        if g < 1e-3:
            break
        dx, dz = gx / g, gz / g
        last_dir = (dx, dz)
        nx_, nz_ = px + dx * step, pz + dz * step
        nh = f.at(nx_, nz_)
        if nh <= h:  # flat or a local top
            break
        if nh >= levels[k] > h:  # crossing inside this step
            t = (levels[k] - h) / (nh - h)
            px, pz = px + dx * step * t, pz + dz * step * t
            h = levels[k]
        else:
            px, pz, h = nx_, nz_, nh
        walked += step
    while len(out) < len(levels):
        out.append((px, pz, last_dir))
    return out


class Builder:
    """Collects faces per material for one detail group."""

    def __init__(self):
        self.verts, self.faces, self.uvs = [], [], []

    def quad_strip(self, a, b, ua, ub, closed, ring_u=False):
        """Two rows of points (lists of (x, y, z)) with their UVs: faces between them. `ring_u`:
        U runs along the ring, so the closing quad continues it instead of reusing the first U."""
        base_a = len(self.verts)
        self.verts.extend(a)
        base_b = len(self.verts)
        self.verts.extend(b)
        n = len(a)
        last = n if closed else n - 1
        for i in range(last):
            j = (i + 1) % n
            q = (base_a + i, base_a + j, base_b + j, base_b + i)
            wrap = j == 0 and ring_u
            quv = (ua[i], ua_wrap(ua) if wrap else ua[j], ua_wrap(ub) if wrap else ub[j], ub[i])
            self.faces.append(q)
            self.uvs.append(list(quv))

    def obj(self, name, flip=False):
        if not self.faces:
            return None
        faces = [tuple(reversed(q)) for q in self.faces] if flip else self.faces
        uvs = [list(reversed(u)) for u in self.uvs] if flip else self.uvs
        return make_object(name, self.verts, faces, uvs, None)


def ua_wrap(u):
    """UV of the closing point of a ring: the first point's, one ring-length of U on."""
    return u[-1][0] + (u[-1][0] - u[-2][0]), u[0][1]


def mesa_rings(f, cells, feat):
    """The foot contour(s) of one mesa: (ring points, closed, foot height, top height)."""
    pc = f.per_cell
    cliff_cells = cells[f.feat[cells[:, 0], cells[:, 1]] == feat["cliff"]]
    if len(cliff_cells) == 0:
        return []
    z0, x0 = cells.min(0) - 2
    z1, x1 = cells.max(0) + 3
    z0, x0 = max(z0, 0), max(x0, 0)
    z1, x1 = min(z1, f.cd), min(x1, f.cw)
    cmask = np.zeros((f.cd, f.cw), bool)
    cmask[cells[:, 0], cells[:, 1]] = True
    dil = cmask.copy()
    for _ in range(1):
        d0 = dil.copy()
        dil[1:] |= d0[:-1]
        dil[:-1] |= d0[1:]
        dil[:, 1:] |= d0[:, :-1]
        dil[:, :-1] |= d0[:, 1:]
    valid = np.repeat(np.repeat(dil[z0:z1, x0:x1], pc, 0), pc, 1)
    win = f.h[z0 * pc:z1 * pc + 1, x0 * pc:x1 * pc + 1]
    ch = np.array([f.h[z * pc + pc // 2, x * pc + pc // 2] for z, x in cliff_cells])
    all_h = np.array([f.h[z * pc + pc // 2, x * pc + pc // 2] for z, x in cells])
    foot = float(np.percentile(ch, 3))
    top = float(np.percentile(all_h, 97))
    if top - foot < 8:
        return []
    rings = []
    for pts, closed in contour_loops(win, foot + 0.6, valid[:win.shape[0] - 1, :win.shape[1] - 1]):
        if len(pts) < 8:
            continue
        pts = [(f.ox + (x0 * pc + p[0]) * f.step, f.oz + (z0 * pc + p[1]) * f.step) for p in pts]
        ring, length = resample(pts, closed, 2.0)
        if length >= 24:
            rings.append((smooth_ring(ring, closed), closed, foot, top))
    return rings


def strata(f, rng, records, style):
    """Buttes: the real slope's lower part stays a talus apron (the tile surface, with boulders);
    above a talus line that wanders round the mesa, a sheer fluted cliff of stacked strata tiers
    (small setbacks and ledges) rises to a caprock lip that sinks into the mesa top. Every part
    stands on or above the drawn surface."""
    feat = {name: i for i, name in enumerate(f.feat_pal)}
    rock_mask = np.isin(f.feat, [feat["cliff"], feat["mesa"]])
    walls_all, ledges_all = [], []
    talus = []
    for cells in components(rock_mask):
        if len(cells) < 6:
            continue
        for ring, closed, foot, top in mesa_rings(f, cells, feat):
            n = len(ring)
            # talus line: 25-45% of the way up, wandering
            tau = 0.35 + 0.1 * periodic_noise(n, rng, 2, closed)
            # fluting: sharp ridges (buttresses) between soft gullies, the same on every tier
            fl = periodic_noise(n, rng, 4, closed) + 0.5 * periodic_noise(n, rng, 2, closed)
            fl /= np.abs(fl).max()
            flute = 1 - np.abs(fl) ** 0.5  # 0 in gullies, 1 on ridges
            base, up_end, out_dir = np.zeros((n, 2)), np.zeros((n, 2)), np.zeros((n, 2))
            lt = foot + tau * (top - foot)
            for i, (x, z) in enumerate(ring):
                tr = trace_levels(f, x, z, [lt[i], top - 0.5])
                base[i] = tr[0][:2]
                up_end[i] = tr[1][:2]
                d = tr[0][2]
                if d is None:
                    gx, gz = f.grad(*tr[0][:2])
                    g = math.hypot(gx, gz) or 1.0
                    d = (gx / g, gz / g)
                out_dir[i] = (-d[0], -d[1])
            # a ring round this mesa climbs to its top; one round some other rise doesn't
            reach = np.mean([f.at(*p) >= top - 1.5 for p in up_end])
            if reach < 0.6:
                continue
            out_dir = smooth_ring(out_dir, closed, 3)
            out_dir /= np.linalg.norm(out_dir, axis=1, keepdims=True) + 1e-9
            base = smooth_ring(base, closed, 2)
            up_end = smooth_ring(up_end, closed, 2)
            for i, (x, z) in enumerate(ring):
                talus.append((x, z, out_dir[i]))
            # tiers: 3 on tall mesas, 2 on low ones; boundaries the same height all round (strata)
            span = top - float(np.mean(lt))
            tiers = 3 if span > 18 else 2
            fr = np.sort(rng.random(tiers - 1)) * 0.6 + 0.2
            bounds = [None] + [float(np.mean(lt)) + span * x for x in fr] + [None]
            setback = np.cumsum([0.0] + [0.8 + 1.7 * rng.random() for _ in range(tiers - 1)])
            ledge_jit = [0.5 * periodic_noise(n, rng, 3, closed) for _ in range(tiers)]
            seg = np.linalg.norm(np.diff(np.vstack([ring, ring[:1]]) if closed else ring, axis=0), axis=1)
            u = np.concatenate([[0], np.cumsum(seg)])[:n]
            length = float(seg.sum())
            u = u / length * max(1, round(length / UV_REPEAT)) if closed else u / UV_REPEAT
            walls, ledges = Builder(), Builder()
            prev_top = None
            bot_prev = None
            for t in range(tiers):
                bot, topr, ub, ut = [], [], [], []
                for i in range(n):
                    o = 0.3 + 3.6 * flute[i]  # buttresses stand out, gullies cut in
                    y0 = lt[i] if t == 0 else bounds[t]
                    y1 = (f.at(*up_end[i]) + 0.5) if t == tiers - 1 else bounds[t + 1]
                    if t < tiers - 1:
                        y1 += ledge_jit[t][i]  # broken ledge edges
                    y1 = max(y1, y0 + 0.5)
                    # setback inward, but never into the surface: shrink until it's under y0
                    s = setback[t]
                    while s > 0 and f.at(*(base[i] + out_dir[i] * (o - s))) > y0 - 0.3:
                        s -= 0.25
                    pb = base[i] + out_dir[i] * (o - max(s, 0))
                    pt = pb - out_dir[i] * (0.35 + 0.25 * flute[i])  # batter: walls lean back a little
                    yb = (f.at(*pb) - 0.6) if t == 0 else bot_prev[i] - 0.1
                    if t == tiers - 1:
                        pt = pt + out_dir[i] * 0.45  # the caprock overhangs a touch
                    bot.append((pb[0], yb, pb[1]))
                    topr.append((pt[0], y1, pt[1]))
                    ub.append((u[i], yb / UV_REPEAT))
                    ut.append((u[i], y1 / UV_REPEAT))
                walls.quad_strip(bot, topr, ub, ut, closed, ring_u=True)
                bot_prev = [p[1] for p in topr]
                if prev_top is not None:  # the ledge from the tier below onto this tier's foot
                    ledges.quad_strip(prev_top, [(p[0], p[1] + 0.1, p[2]) for p in bot],
                                      [(p[0] / UV_REPEAT, p[2] / UV_REPEAT) for p in prev_top],
                                      [(p[0] / UV_REPEAT, p[2] / UV_REPEAT) for p in bot], closed)
                prev_top = topr
            # caprock lip: inward from the last wall's top edge, sinking under the mesa top
            inner = []
            for i in range(n):
                p = up_end[i] - out_dir[i] * 2.5
                inner.append((p[0], f.at(*p) - 0.25, p[1]))
            ledges.quad_strip(prev_top, inner, [(p[0] / UV_REPEAT, p[2] / UV_REPEAT) for p in prev_top],
                              [(p[0] / UV_REPEAT, p[2] / UV_REPEAT) for p in inner], closed)
            walls_all.append((walls, needs_flip(walls, out_dir[0])))
            ledges_all.append((ledges, needs_flip_up(ledges)))
    for kind, items, key in (("wall", walls_all, style["wall"]), ("ledge", ledges_all, style["rock"])):
        for idx, (b, flip) in enumerate(items):
            if not b.faces:
                continue
            ob = b.obj(f"d_{kind}{idx}_{key}", flip)
            center, size = world_bounds(b.verts)
            records.append({"name": ob.name, "kind": "details", "material": key, "center": center, "size": size,
                            "triangles": tri_count(ob), "object": ob})
    return talus


def needs_flip(b, outward):
    """True when the first wall quad's normal points inward (Roblox axes)."""
    q = b.faces[0]
    p = [np.array(b.verts[i]) for i in q[:3]]
    n = np.cross(p[1] - p[0], p[2] - p[0])
    return (n[0] * outward[0] + n[2] * outward[1]) < 0


def needs_flip_up(b):
    if not b.faces:
        return False
    votes = 0
    for q in b.faces[:: max(1, len(b.faces) // 50)]:
        p = [np.array(b.verts[i]) for i in q[:3]]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        votes += 1 if n[1] < 0 else -1
    return votes > 0


# ---------------------------------------------------------------------------
# Boulders
# ---------------------------------------------------------------------------


def rock_shell(rng, cx, cy, cz, r, flat):
    """A faceted boulder: an icosphere pushed about by noise, flattened, its base sunk."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    k = rng.random(3) * 10
    sx, sz = 0.8 + 0.5 * rng.random(), 0.8 + 0.5 * rng.random()
    verts, faces = [], []
    for v in bm.verts:
        x, y, z = v.co
        nse = 1 + 0.22 * math.sin(3.1 * x + k[0]) * math.sin(2.7 * y + k[1]) * math.sin(3.3 * z + k[2]) \
            + 0.12 * (rng.random() - 0.5)
        verts.append((cx + x * r * sx * nse, cy + max(y, -0.6) * r * flat * nse, cz + z * r * sz * nse))
    for fc in bm.faces:
        faces.append(tuple(v.index for v in fc.verts))
    bm.free()
    return verts, faces


def boulders(f, rng, records, style, talus):
    feat = {name: i for i, name in enumerate(f.feat_pal)}
    spots = []
    zs, xs = np.where(f.feat == feat["boulder"]) if "boulder" in feat else ((), ())
    for z, x in zip(zs, xs):
        cx = f.ox + (x + 0.5) * f.cell
        cz = f.oz + (z + 0.5) * f.cell
        spots.append((cx + (rng.random() - 0.5) * 3, cz + (rng.random() - 0.5) * 3, 2.6 + 1.6 * rng.random()))
        for _ in range(int(rng.integers(1, 4))):
            a = rng.random() * 2 * math.pi
            d = 2.5 + rng.random() * 2.5
            spots.append((cx + math.cos(a) * d, cz + math.sin(a) * d, 0.8 + 1.2 * rng.random()))
    for x, z, o in talus:
        if rng.random() < 0.3:
            d = -4 + rng.random() * 9  # on the apron and up the talus slope
            spots.append((x + o[0] * d, z + o[1] * d, 0.5 + 1.4 * rng.random() ** 2))
    by_tile = {}
    for x, z, r in spots:
        if not f.inside(x, z):
            continue
        y = f.at(x, z) - 0.25 * r
        v, fc = rock_shell(rng, x, y, z, r, 0.55 + 0.25 * rng.random())
        key = (int((x - f.ox) // TILE), int((z - f.oz) // TILE))
        b = by_tile.setdefault(key, Builder())
        base = len(b.verts)
        b.verts.extend(v)
        for face in fc:
            b.faces.append(tuple(base + i for i in face))
            # box projection: the face's dominant axis picks the plane
            pts = [np.array(v[i]) for i in face]
            n = np.abs(np.cross(pts[1] - pts[0], pts[2] - pts[0]))
            ax = int(np.argmax(n))
            uv = []
            for p in pts:
                a, c = [(p[2], p[1]), (p[0], p[2]), (p[0], p[1])][ax]
                uv.append((a / 8.0, c / 8.0))
            b.uvs.append(uv)
    key = style["rock"]
    for (tx, tz), b in sorted(by_tile.items()):
        ob = b.obj(f"d_rocks{tx}_{tz}_{key}")
        center, size = world_bounds(b.verts)
        records.append({"name": ob.name, "kind": "details", "material": key, "center": center, "size": size,
                        "triangles": tri_count(ob), "object": ob})


# ---------------------------------------------------------------------------
# Crag skin and hedgerows (the other maps)
# ---------------------------------------------------------------------------


class Periodic:
    """A periodic noise field over `period` studs, sampled bilinearly at any (x, z)."""

    def __init__(self, rng, period, beta, lo=1.0, hi=None, res=256):
        self.a = textures.noise(res, rng, beta, lo=lo, hi=hi)
        self.res, self.period = res, period

    def __call__(self, x, z):
        fx = (x / self.period * self.res) % self.res
        fz = (z / self.period * self.res) % self.res
        i, j = int(fx), int(fz)
        tx, tz = fx - i, fz - j
        a, r = self.a, self.res
        i1, j1 = (i + 1) % r, (j + 1) % r
        return (a[j, i] * (1 - tx) * (1 - tz) + a[j, i1] * tx * (1 - tz)
                + a[j1, i] * (1 - tx) * tz + a[j1, i1] * tx * tz)


def box_uv(pts, scale):
    """Box projection of one face: its dominant normal axis picks the plane."""
    n = np.abs(np.cross(pts[1] - pts[0], pts[2] - pts[0]))
    ax = int(np.argmax(n))
    out = []
    for p in pts:
        a, c = [(p[2], p[1]), (p[0], p[2]), (p[0], p[1])][ax]
        out.append((a / scale, c / scale))
    return out


def crag(f, rng, records, style, names, w):
    """A craggy rock skin over the rock ground: the surface at 2-stud steps, lifted
    0.15-2.4 studs by ridged noise (never below the drawn surface) and pushed a little
    downhill, fading to its edge where rock gives way to grass or sand. Faceted, box-
    mapped. Returns points along its edge (for boulders at the foot)."""
    key = style["crag"]
    if key not in names:
        return []
    k = names.index(key)
    others = np.delete(w, k, axis=0)
    dom = w[k] - (others.max(0) if len(others) else 0)  # > 0 where rock wins, per sample
    ridge = Periodic(rng, 64.0, 2.6, lo=2, hi=40)
    ridge2 = Periodic(rng, 23.0, 2.2, lo=2, hi=30)
    step = f.step / 2
    sub = 2  # vertices per sample step

    def dom_at(x, z):
        fx = np.clip((x - f.ox) / f.step, 0, f.nx - 1.001)
        fz = np.clip((z - f.oz) / f.step, 0, f.nz - 1.001)
        i, j = int(fx), int(fz)
        tx, tz = fx - i, fz - j
        return (dom[j, i] * (1 - tx) * (1 - tz) + dom[j, i + 1] * tx * (1 - tz)
                + dom[j + 1, i] * (1 - tx) * tz + dom[j + 1, i + 1] * tx * tz)

    edge_pts = []
    by_tile = {}
    vcache = {}

    def vert(ii, jj):
        kk = (ii, jj)
        if kk not in vcache:
            x, z = f.ox + ii * step, f.oz + jj * step
            d = dom_at(x, z)
            s = min(max(d / 0.5, 0.0), 1.0)
            s = s * s * (3 - 2 * s)
            r = 1 - abs(ridge(x, z))
            r2 = 1 - abs(ridge2(x, z))
            # the rim dives 0.4 under the ground (no slit under an overhang), the rest rises 0.15-2.4
            lift = -0.4 + 0.55 * min(max(d / 0.15, 0.0), 1.0) + s * (1.5 * r ** 2 + 0.9 * r2 ** 3)
            gx, gz = f.grad(x, z)
            g = math.hypot(gx, gz)
            push = s * min(g, 1.5) * lift * 0.5 / (g or 1)  # none at the edge: no folds there
            px, pz = x - gx * push, z - gz * push
            vcache[kk] = {"pos": np.array([px, f.at(x, z) + lift, pz]), "d": d}
        return vcache[kk]

    def clip_edge(poly):
        """The part of a polygon where rock wins (d >= 0), cut on the interpolated d = 0 line."""
        out = []
        for i in range(len(poly)):
            p, q = poly[i], poly[(i + 1) % len(poly)]
            if p["d"] >= 0:
                out.append(p)
            if (p["d"] >= 0) != (q["d"] >= 0):
                t = p["d"] / (p["d"] - q["d"])
                out.append({"pos": p["pos"] + (q["pos"] - p["pos"]) * t, "d": 0.0})
        return out

    nqx, nqz = (f.nx - 1) * sub, (f.nz - 1) * sub
    for jj in range(nqz):
        for ii in range(nqx):
            # cheap reject on the sample grid first
            si, sj = ii // sub, jj // sub
            if dom[sj:sj + 2, si:si + 2].max() <= 0:
                continue
            q = [vert(ii, jj), vert(ii + 1, jj), vert(ii + 1, jj + 1), vert(ii, jj + 1)]
            if max(v["d"] for v in q) <= 0:
                continue
            tile = (int((q[0]["pos"][0] - f.ox) // TILE), int((q[0]["pos"][2] - f.oz) // TILE))
            b = by_tile.setdefault(tile, Builder())
            for tri in ((0, 2, 1), (0, 3, 2)):  # up-facing in Roblox axes (see build_tiles)
                poly = [q[t] for t in tri]
                if min(v["d"] for v in poly) < 0:
                    poly = clip_edge(poly)
                    if len(poly) >= 3 and rng.random() < 0.15:
                        edge_pts.append((float(poly[0]["pos"][0]), float(poly[0]["pos"][2]), None))
                for k in range(1, len(poly) - 1):
                    pts = [poly[0]["pos"], poly[k]["pos"], poly[k + 1]["pos"]]
                    if np.linalg.norm(np.cross(pts[1] - pts[0], pts[2] - pts[0])) < 1e-6:
                        continue
                    base = len(b.verts)
                    b.verts.extend(tuple(float(c) for c in p) for p in pts)
                    b.faces.append((base, base + 1, base + 2))
                    b.uvs.append(box_uv(pts, 20.0))
    for (tx, tz), b in sorted(by_tile.items()):
        # split big tiles so no mesh passes the triangle limit
        for part in range(0, len(b.faces), 18000):
            sub_b = Builder()
            for fi in range(part, min(part + 18000, len(b.faces))):
                base = len(sub_b.verts)
                sub_b.verts.extend(b.verts[i] for i in b.faces[fi])
                sub_b.faces.append((base, base + 1, base + 2))
                sub_b.uvs.append(b.uvs[fi])
            name = f"d_crag{tx}_{tz}_{part // 18000}_{key}"
            me_ob = make_object(name, sub_b.verts, sub_b.faces, sub_b.uvs, None, smooth=False)
            center, size = world_bounds(sub_b.verts)
            records.append({"name": name, "kind": "details", "material": key, "center": center, "size": size,
                            "triangles": tri_count(me_ob), "object": me_ob})
    out = []
    for x, z, _ in edge_pts:
        gx, gz = f.grad(x, z)
        g = math.hypot(gx, gz) or 1.0
        out.append((x, z, (-gx / g, -gz / g)))
    return out


def hedges(f, rng, records, style):
    """Hedgerow foliage along the `hedge` cells: each straight run of hedge cells (rows and
    columns; corners belong to both) becomes one continuous lumpy half-round roll on top of
    the drawn bank, about 7 studs wide and 4 above it, its ends rounded down into the bank."""
    key = style["hedges"]
    feat = {name: i for i, name in enumerate(f.feat_pal)}
    if "hedge" not in feat:
        return
    hedge = f.feat == feat["hedge"]
    lump = Periodic(rng, 37.0, 2.4, lo=2, hi=30)
    lump2 = Periodic(rng, 11.0, 2.0, lo=2, hi=20)
    runs = []  # (first cell, last cell, axis)
    for z in range(f.cd):
        x = 0
        while x < f.cw:
            if hedge[z, x]:
                x1 = x
                while x1 + 1 < f.cw and hedge[z, x1 + 1]:
                    x1 += 1
                if x1 > x:
                    runs.append(((x, z), (x1, z), "x"))
                x = x1 + 1
            else:
                x += 1
    for x in range(f.cw):
        z = 0
        while z < f.cd:
            if hedge[z, x]:
                z1 = z
                while z1 + 1 < f.cd and hedge[z1 + 1, x]:
                    z1 += 1
                if z1 > z:
                    runs.append(((x, z), (x, z1), "z"))
                z = z1 + 1
            else:
                z += 1
    # single cells with no hedge neighbour: a short roll of their own
    for z, x in zip(*np.where(hedge)):
        n = sum(hedge[zz, xx] for zz, xx in ((z - 1, x), (z + 1, x), (z, x - 1), (z, x + 1))
                if 0 <= zz < f.cd and 0 <= xx < f.cw)
        if n == 0:
            runs.append(((x, z), (x, z), "x"))

    width, height, angles = 7.2, 4.2, 9
    by_tile = {}
    for (x0, z0), (x1, z1), axis in runs:
        d = np.array([1.0, 0.0]) if axis == "x" else np.array([0.0, 1.0])
        perp = np.array([-d[1], d[0]])
        a = np.array([f.ox + (x0 + 0.5) * f.cell, f.oz + (z0 + 0.5) * f.cell]) - d * 3.6
        b = np.array([f.ox + (x1 + 0.5) * f.cell, f.oz + (z1 + 0.5) * f.cell]) + d * 3.6
        length = float(np.linalg.norm(b - a))
        steps = max(int(length / 2.0), 2)
        rows = []
        for s in range(steps + 1):
            t = s / steps
            c = a + (b - a) * t
            end = min(t * length, (1 - t) * length)
            k_end = min(1.0, (end + 0.4) / 3.0) ** 0.5  # rounded ends
            top = f.at(c[0], c[1])
            row = []
            for i in range(angles):
                ang = math.pi * i / (angles - 1)
                lx = math.cos(ang) * width / 2 * k_end
                ly = math.sin(ang) * height * k_end
                px, pz = c[0] + perp[0] * lx, c[1] + perp[1] * lx
                k = 1 + 0.22 * lump(px, pz + ly) + 0.12 * lump2(px + ly, pz)
                row.append(np.array([c[0] + perp[0] * lx * k, top - 0.7 + ly * k, c[1] + perp[1] * lx * k]))
            rows.append((c, top, row))
        tile = (int(((a[0] + b[0]) / 2 - f.ox) // TILE), int(((a[1] + b[1]) / 2 - f.oz) // TILE))
        bld = by_tile.setdefault(tile, Builder())
        # winding: outward from the roll's axis
        c0, top0, r0 = rows[0]
        c1, _, r1 = rows[1]
        q = [r0[angles // 2], r0[angles // 2 + 1], r1[angles // 2 + 1]]
        nrm = np.cross(q[1] - q[0], q[2] - q[0])
        flip = nrm[1] < 0  # the top of the roll must face up
        for s in range(steps):
            ra, rb = rows[s][2], rows[s + 1][2]
            for i in range(angles - 1):
                quad = [ra[i], ra[i + 1], rb[i + 1], rb[i]]
                for tri in ((0, 1, 2), (0, 2, 3)):
                    pts = [quad[t] for t in tri]
                    if flip:
                        pts = pts[::-1]
                    base = len(bld.verts)
                    bld.verts.extend(tuple(float(v) for v in p) for p in pts)
                    bld.faces.append((base, base + 1, base + 2))
                    bld.uvs.append(box_uv(pts, 8.0))
    for (tx, tz), bld in sorted(by_tile.items()):
        for part in range(0, len(bld.faces), 18000):
            sub_b = Builder()
            for fi in range(part, min(part + 18000, len(bld.faces))):
                base = len(sub_b.verts)
                sub_b.verts.extend(bld.verts[i] for i in bld.faces[fi])
                sub_b.faces.append((base, base + 1, base + 2))
                sub_b.uvs.append(bld.uvs[fi])
            name = f"d_hedge{tx}_{tz}_{part // 18000}_{key}"
            ob = make_object(name, sub_b.verts, sub_b.faces, sub_b.uvs, None)
            center, size = world_bounds(sub_b.verts)
            records.append({"name": name, "kind": "details", "material": key, "center": center, "size": size,
                            "triangles": tri_count(ob), "object": ob})


# ---------------------------------------------------------------------------
# Preview materials (Blender only; the game uses the uploaded maps)
# ---------------------------------------------------------------------------


def preview_material(key):
    d = os.path.join(ROOT, "assets", "maps", "materials", key)
    mat = bpy.data.materials.new(f"ground_{key}")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    def img(kind, colour):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(d, f"{key}_{kind}.png"))
        n.image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        return n
    alb = img("ALB", True)
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    rgh = img("RGH", False)
    nt.links.new(rgh.outputs["Color"], bsdf.inputs["Roughness"])
    nor = img("NOR", False)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nor.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def previews(name, records, out, f, shots):
    scene = bpy.context.scene
    mats = {}
    for r in records:
        key = r["material"]
        if key not in mats:
            mats[key] = preview_material(key)
        r["object"].data.materials.clear()
        r["object"].data.materials.append(mats[key])
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.62, 0.68, 0.78, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    sun.angle = math.radians(2)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(so)
    scene.view_settings.view_transform = "AgX"
    for label, cam, look, lens in shots:
        lib.render_preview(os.path.join(out, f"preview_{label}.png"), cam, look, size=(1280, 720), samples=24, lens=lens)
        print(f"preview {label}", flush=True)


def shot(look, dist, pitch=55, yaw=0):
    """Camera at `dist` studs from `look`, pitched down `pitch` degrees, looking north (-Z) at yaw 0."""
    p, y = math.radians(pitch), math.radians(yaw)
    x = look[0] + math.sin(y) * math.cos(p) * dist
    z = look[2] + math.cos(y) * math.cos(p) * dist
    return (x, look[1] + math.sin(p) * dist, z), look


# ---------------------------------------------------------------------------


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    name = argv[0]
    no_preview = "--no-preview" in argv
    src = os.path.join(ROOT, "assets", "maps", name, "ground.json")
    out = os.path.join(ROOT, "assets", "maps", name, "export")
    os.makedirs(out, exist_ok=True)
    with open(src, encoding="utf-8") as fh:
        g = json.load(fh)
    lib.reset_scene()
    f = Field(g)
    style = STYLES.get(name, {})
    rng = np.random.default_rng(sum(map(ord, name)) * 104729)
    records = []
    names, w = build_tiles(f, records, rng, style)
    print(f"tiles: {sum(1 for r in records)} meshes, {sum(r['triangles'] for r in records):,} triangles", flush=True)
    talus = []
    if style.get("strata"):
        talus += strata(f, rng, records, style)
    if style.get("crag"):
        talus += crag(f, rng, records, style, names, w)
    if style.get("hedges"):
        hedges(f, rng, records, style)
    if style.get("boulders"):
        boulders(f, rng, records, style, talus)
    det = [r for r in records if r["kind"] == "details"]
    print(f"details: {len(det)} meshes, {sum(r['triangles'] for r in det):,} triangles", flush=True)
    for r in records:
        assert r["triangles"] <= 20000, (r["name"], r["triangles"])
    # FBX parts: whole meshes, at most MAX_PART_TRIS triangles each
    parts, cur, cur_tris = [], [], 0
    for r in records:
        if cur and cur_tris + r["triangles"] > MAX_PART_TRIS:
            parts.append(cur)
            cur, cur_tris = [], 0
        cur.append(r)
        cur_tris += r["triangles"]
    if cur:
        parts.append(cur)
    for old in os.listdir(out):
        if old.startswith("ground_") and old.endswith(".fbx"):
            os.remove(os.path.join(out, old))
    rig = {"map": name, "source": g.get("mapId"), "uvRepeat": UV_REPEAT, "tile": TILE, "parts": [], "meshes": []}
    for pi, part in enumerate(parts):
        fbx = f"ground_{pi + 1}.fbx"
        export_fbx([r["object"] for r in part], os.path.join(out, fbx))
        rig["parts"].append({"fbx": fbx, "meshes": [r["name"] for r in part],
                             "triangles": sum(r["triangles"] for r in part)})
    for r in records:
        rig["meshes"].append({k: r[k] for k in ("name", "kind", "material", "center", "size", "triangles")})
    rig["triangles"] = {"tiles": sum(r["triangles"] for r in records if r["kind"] == "tiles"),
                        "details": sum(r["triangles"] for r in det)}
    lib.write_json(os.path.join(out, "ground.json"), rig)
    print(f"{len(parts)} FBX parts -> {os.path.relpath(out, ROOT)}", flush=True)
    if not no_preview:
        # aim at the style's feature (or ground type) nearest the map's centre
        kind, what = style.get("aim", ("material", f.mat_pal[0]))
        zs, xs = np.where(f.feat == f.feat_pal.index(what)) if kind == "feature" else np.where(f.mat == f.mat_pal.index(what))
        cx, cz = f.ox + (xs + 0.5) * f.cell, f.oz + (zs + 0.5) * f.cell
        i = int(np.argmin(cx ** 2 + (cz - 60) ** 2))
        look = (float(cx[i]), 0.0, float(cz[i]) + 30)
        look = (look[0], f.at(look[0], look[2]), look[2])
        shots = [("55_close", *shot(look, 90), 50), ("55_220", *shot(look, 220), 50),
                 ("side", (look[0] - 45, look[1] + 8, look[2] + 95), (look[0] + 5, look[1] + 10, look[2] - 10), 35),
                 ("55_far", *shot((0, 20, 0), 900), 35)]
        previews(name, records, out, f, shots)


def export_fbx(objs, path):
    lib.select_only(objs, objs[0])
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z", axis_up="Y", use_mesh_modifiers=False,
        mesh_smooth_type="OFF", use_tspace=True, add_leaf_bones=False,
        path_mode="STRIP", embed_textures=False, bake_space_transform=True,
    )


if __name__ == "__main__":
    main()
