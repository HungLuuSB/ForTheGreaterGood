"""Blender helpers for FTGG unit meshes (docs/art/pipeline.md, M-11).

Run inside Blender 5.2 (headless: blender -b --factory-startup -P <unit>/build.py).
Geometry is written in Roblox model space (docs/contracts/rig.md): +X right,
+Y up, forward = -Z, 1 unit = 1 stud. `R()` maps it to Blender (Z up); the
FBX export maps it back, so the file is in Roblox space.

A unit has a low-poly piece per rig piece (exported) and a detailed copy of
each (bolts, seams, hatches; never exported) that is baked into the
low-poly's textures: color (camouflage variants, wear, grime, ambient
occlusion), team mask (alpha), roughness, metalness and normal.
"""

import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------
# Space
# ---------------------------------------------------------------------------


def R(x, y, z):
    """Roblox model space -> Blender space."""
    return Vector((x, -z, y))


def to_roblox(v):
    """Blender space -> Roblox model space, as a list."""
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def vec(t):
    return Vector((float(t[0]), float(t[1]), float(t[2])))


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


# ---------------------------------------------------------------------------
# Mesh building: a Piece collects shells into one bmesh, one object per piece
# ---------------------------------------------------------------------------


# Wreck mode (queue item 5, M-24): unit.run sets this when FTGG_WRECK=1.
# Every shell is battered by rules that depend only on its own vertices and
# on position (never on build order), so the low and the detailed build of a
# piece break the same way and the bake still lines up:
#   - small shells (antennas, lamps, boxes, bolts) are knocked off or bent;
#   - medium shells are bent a little about their centre;
#   - every vertex is dented by a smooth noise field (to_object).
# {"size": unit size in studs, "seed": int}
WRECK = None


def _unit_hash(*xs):
    """Deterministic 0..1 from numbers (Python's hash() is salted per run)."""
    h = 2166136261
    for x in xs:
        h = ((h ^ (int(round(x * 1000)) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
        h ^= h >> 13
    return h / 0xFFFFFFFF


def _wreck_shell(verts):
    """The battered shell's vertices (Roblox space), or None to drop it."""
    n = len(verts)
    c = [sum(v[i] for v in verts) / n for i in range(3)]
    ext = max(max(v[i] for v in verts) - min(v[i] for v in verts) for i in range(3))
    size, seed = WRECK["size"], WRECK["seed"]
    r = [_unit_hash(seed, k, *c, ext) for k in range(5)]
    if ext < 0.09 * size:
        if r[0] < 0.4:
            return None  # blown off
        bend, sag = 22.0, 0.04 * ext
    elif ext < 0.35 * size:
        bend, sag = 9.0, 0.0
    else:
        return verts
    axis = Vector((r[1] - 0.5, r[2] - 0.5, r[3] - 0.5))
    if axis.length < 1e-3:
        return verts
    rot = Matrix.Rotation(math.radians((r[4] - 0.5) * 2 * bend), 3, axis.normalized())
    cv = Vector(c)
    out = []
    for v in verts:
        q = rot @ (Vector(v) - cv) + cv
        out.append((q.x, q.y - sag, q.z))
    return out


def _wreck_dent(mesh):
    """Dents every vertex (Blender space) along a smooth noise field."""
    from mathutils import noise
    size, seed = WRECK["size"], WRECK["seed"]
    amp, freq = 0.015 * size, 2.2 / size
    off = Vector((seed * 0.731, seed * 0.317, seed * 0.173))
    for v in mesh.vertices:
        v.co += noise.noise_vector(v.co * freq + off) * amp


class Piece:
    def __init__(self, name, kinds, pivot):
        self.name = name
        self.kinds = kinds  # material slot order
        self.pivot = pivot  # Roblox model space; becomes the object origin
        self.bm = bmesh.new()

    def _slot(self, kind):
        return self.kinds.index(kind)

    def _shell(self, verts, faces, kind, bevel=0.0, kinds=None):
        """Adds one closed shell. `verts` in Roblox space, `faces` as index
        lists (any winding: normals are recalculated per shell). `kinds`
        optionally gives a kind per face."""
        bm = self.bm
        if WRECK:
            verts = _wreck_shell(verts)
            if verts is None:
                return []
        vs = [bm.verts.new(R(*v)) for v in verts]
        fs = []
        for i, f in enumerate(faces):
            face = bm.faces.new([vs[j] for j in f])
            face.material_index = self._slot(kinds[i] if kinds else kind)
            fs.append(face)
        bmesh.ops.recalc_face_normals(bm, faces=fs)
        if bevel > 0:
            edges = list({e for f in fs for e in f.edges})
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET",
                            segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
        return fs

    # -- shapes --------------------------------------------------------------

    def box(self, center, size, kind, bevel=0.0):
        cx, cy, cz = center
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        v = [(cx + sx * hx, cy + sy * hy, cz + sz * hz)
             for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        return self._shell(v, f, kind, bevel)

    def obox(self, center, u, n, size_u, size_v, size_n, kind, bevel=0.0):
        """Box with its axes along u, n x u and n (Roblox vectors)."""
        c, u, n = vec(center), vec(u).normalized(), vec(n).normalized()
        v = n.cross(u).normalized()
        pts = [c + u * (a * size_u / 2) + v * (b * size_v / 2) + n * (d * size_n / 2)
               for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        return self._shell([tuple(p) for p in pts], f, kind, bevel)

    def ocyl(self, base, n, radius, height, sides, kind, radius2=None):
        """Closed cylinder standing on `base` along n (Roblox vectors)."""
        b, n = vec(base), vec(n).normalized()
        a = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
        u = (a - n * a.dot(n)).normalized()
        v = n.cross(u)
        r2 = radius if radius2 is None else radius2
        pts = []
        for h, r in ((0.0, radius), (height, r2)):
            for i in range(sides):
                t = 2 * math.pi * i / sides
                pts.append(tuple(b + n * h + u * (math.cos(t) * r) + v * (math.sin(t) * r)))
        m = sides
        f = [list(range(m)), list(range(2 * m - 1, m - 1, -1))]
        f += [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)]
        return self._shell(pts, f, kind)

    def prism_x(self, profile_zy, x0, x1, kind, bevel=0.0):
        """Side profile (z, y) points, extruded along X from x0 to x1."""
        n = len(profile_zy)
        v = [(x0, y, z) for z, y in profile_zy] + [(x1, y, z) for z, y in profile_zy]
        f = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
        f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        return self._shell(v, f, kind, bevel)

    def prism_y(self, profile_xz, y0, y1, kind, bevel=0.0, top_scale=1.0, top_center=None):
        """Top-view profile (x, z) points, extruded up from y0 to y1; the top
        outline is scaled by `top_scale` about `top_center` (sloped sides)."""
        n = len(profile_xz)
        if top_center is None:
            top_center = (sum(p[0] for p in profile_xz) / n, sum(p[1] for p in profile_xz) / n)
        tcx, tcz = top_center
        top = [(tcx + (x - tcx) * top_scale, tcz + (z - tcz) * top_scale) for x, z in profile_xz]
        v = [(x, y0, z) for x, z in profile_xz] + [(x, y1, z) for x, z in top]
        f = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
        f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        return self._shell(v, f, kind, bevel)

    def cylinder(self, axis, center, radius, length, sides, kind, cap_kinds=None,
                 radius2=None, bevel=0.0):
        """Closed cylinder (or cone frustum with `radius2` at the far end)
        along `axis` ('x', 'y' or 'z'), centered on `center`. The first cap
        is at the -axis end."""
        r2 = radius if radius2 is None else radius2
        cx, cy, cz = center
        h = length / 2
        v = []
        for end, r in ((-h, radius), (h, r2)):
            for i in range(sides):
                a = 2 * math.pi * i / sides
                c, s = math.cos(a) * r, math.sin(a) * r
                if axis == "x":
                    v.append((cx + end, cy + c, cz + s))
                elif axis == "y":
                    v.append((cx + c, cy + end, cz + s))
                else:
                    v.append((cx + c, cy + s, cz + end))
        n = sides
        f = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
        caps = cap_kinds or (kind, kind)
        kinds = [caps[0], caps[1]]
        f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        kinds += [kind] * n
        return self._shell(v, f, kind, bevel, kinds=kinds)

    def band_x(self, outer_zy, inner_zy, x0, x1, kind):
        """A closed loop (like a track) between two matching outlines,
        extruded along X: outer surface, inner surface and two side rings."""
        n = len(outer_zy)
        assert len(inner_zy) == n
        v = ([(x0, y, z) for z, y in outer_zy] + [(x1, y, z) for z, y in outer_zy]
             + [(x0, y, z) for z, y in inner_zy] + [(x1, y, z) for z, y in inner_zy])
        o0, o1, i0, i1 = 0, n, 2 * n, 3 * n
        f = []
        for i in range(n):
            j = (i + 1) % n
            f.append((o0 + i, o0 + j, o1 + j, o1 + i))  # outer
            f.append((i0 + i, i1 + i, i1 + j, i0 + j))  # inner
            f.append((o0 + i, i0 + i, i0 + j, o0 + j))  # side x0
            f.append((o1 + i, o1 + j, i1 + j, i1 + i))  # side x1
        bm = self.bm
        vs = [bm.verts.new(R(*p)) for p in v]
        fs = []
        for face in f:
            fc = bm.faces.new([vs[k] for k in face])
            fc.material_index = self._slot(kind)
            fs.append(fc)
        # a ring has an inside and an outside: orient by hand from the outline
        bm.normal_update()
        center = Vector((0, 0, 0))
        for p in outer_zy:
            center += R((x0 + x1) / 2, p[1], p[0])
        center /= n
        for k, fc in enumerate(fs):
            role = k % 4
            c = fc.calc_center_median()
            if role == 0:
                want = c - Vector((c.x, center.y, center.z))
                want.x = 0
            elif role == 1:
                want = Vector((c.x, center.y, center.z)) - c
                want.x = 0
            elif role == 2:
                want = Vector((-1 if x0 < x1 else 1, 0, 0))
            else:
                want = Vector((1 if x0 < x1 else -1, 0, 0))
            if fc.normal.dot(want) < 0:
                fc.normal_flip()
        return fs

    # -- object ----------------------------------------------------------------

    def scale(self, s):
        """Scales the piece and its pivot about the unit origin by (sx, sy, sz)
        in Roblox space (y = 0 stays on the ground)."""
        sx, sy, sz = s
        bmesh.ops.scale(self.bm, vec=Vector((sx, sz, sy)), verts=self.bm.verts)  # R(): Blender (x, -z, y)
        self.pivot = scaled(self.pivot, s)

    def to_object(self, materials, collection, name=None):
        mesh = bpy.data.meshes.new(name or self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.to_mesh(mesh)
        self.bm.free()
        if WRECK:
            _wreck_dent(mesh)
        obj = bpy.data.objects.new(name or self.name, mesh)
        for kind in self.kinds:
            mesh.materials.append(materials[kind])
        collection.objects.link(obj)
        # origin at the pivot (Roblox space), geometry kept in place
        piv = R(*self.pivot)
        mesh.transform(Matrix.Translation(-piv))
        obj.location = piv
        for poly in mesh.polygons:
            poly.use_smooth = False
        return obj


def scaled(v, s):
    """Roblox-space point `v` scaled about the origin by `s`."""
    return (v[0] * s[0], v[1] * s[1], v[2] * s[2])


def tris(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def outline_circle(cz, cy, r, a0, a1, steps):
    """Points (z, y) on a circle arc in the side profile, angles in degrees
    measured from +z toward +y."""
    out = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        out.append((cz + math.cos(a) * r, cy + math.sin(a) * r))
    return out


def offset_polygon(points, d):
    """Offsets a closed (z, y) outline by d (positive = inward)."""
    n = len(points)
    area = sum(points[i][0] * points[(i + 1) % n][1] - points[(i + 1) % n][0] * points[i][1] for i in range(n))
    sign = 1 if area > 0 else -1
    out = []
    for i in range(n):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
        nrm = []
        for a, b in ((p0, p1), (p1, p2)):
            dz, dy = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dz, dy) or 1
            nrm.append((-dy / length * sign, dz / length * sign))
        nz, ny = nrm[0][0] + nrm[1][0], nrm[0][1] + nrm[1][1]
        length = math.hypot(nz, ny) or 1
        nz, ny = nz / length, ny / length
        cos = nz * nrm[1][0] + ny * nrm[1][1]
        k = d / max(cos, 0.5)
        out.append((p1[0] + nz * k, p1[1] + ny * k))
    return out


# ---------------------------------------------------------------------------
# Materials: one per kind, shared by the low-poly and detailed pieces. Each
# can show color (per camouflage variant), roughness, metalness, team mask or
# a lit preview, and carries the bake target image.
# ---------------------------------------------------------------------------


def srgb(c):
    """0..255 sRGB -> linear 0..1 tuple with alpha."""
    def lin(u):
        u = u / 255
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1.0)


mat_sockets = {}


class _Nodes:
    def __init__(self, nt):
        self.nt = nt

    def new(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def rgb(self, c):
        n = self.new("ShaderNodeRGB")
        n.outputs[0].default_value = srgb(c)
        return n.outputs[0]

    def value(self, v):
        n = self.new("ShaderNodeValue")
        n.outputs[0].default_value = v
        return n.outputs[0]

    def math(self, op, a, b=None, clamp=False, c=None):
        n = self.new("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, x in enumerate((a, b, c)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                self.link(x, n.inputs[i])
        return n.outputs[0]

    def mix(self, fac, a, b, blend="MIX"):
        n = self.new("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        for sock, x in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
            if isinstance(x, (int, float)):
                sock.default_value = x
            elif isinstance(x, tuple):
                sock.default_value = srgb(x)
            else:
                self.link(x, sock)
        return n.outputs[2]

    def noise(self, vector, scale, detail=1.0, roughness=0.5, distortion=0.0, mapping_scale=None, offset=(0, 0, 0)):
        m = self.new("ShaderNodeMapping")
        m.inputs["Location"].default_value = offset
        if mapping_scale:
            m.inputs["Scale"].default_value = mapping_scale
        self.link(vector, m.inputs["Vector"])
        n = self.new("ShaderNodeTexNoise", noise_dimensions="3D")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = roughness
        n.inputs["Distortion"].default_value = distortion
        self.link(m.outputs["Vector"], n.inputs["Vector"])
        return n.outputs["Fac"]

    def map_range(self, x, a, b, c, d, clamp=True):
        n = self.new("ShaderNodeMapRange", clamp=clamp)
        self.link(x, n.inputs["Value"])
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.inputs["To Min"].default_value = c
        n.inputs["To Max"].default_value = d
        return n.outputs[0]


def camo_color(N, pos, camo):
    """Base color socket of one camouflage variant.
    camo: {"type": "paint", "base"} (BAR style, M-15: one paint, a faint
          top-light gradient), {"type": "plain", "base", "mottle"} or
          {"type": "disruptive", "base", "tones": [(rgb, scale, threshold, seed)]}"""
    if camo["type"] == "paint":
        sep = N.new("ShaderNodeSeparateXYZ")
        N.link(pos, sep.inputs[0])
        k = N.map_range(sep.outputs["Z"], 0.3, 3.2, 0.9, 1.04)  # Blender Z = Roblox Y
        comb = N.new("ShaderNodeCombineColor")
        for i in range(3):
            N.link(k, comb.inputs[i])
        return N.mix(1.0, N.rgb(camo["base"]), comb.outputs[0], blend="MULTIPLY")
    if camo["type"] == "plain":
        base = N.rgb(camo["base"])
        broad = N.map_range(N.noise(pos, 0.35, detail=2.0), 0.3, 0.7, 1.0 - camo["mottle"], 1.0 + camo["mottle"] * 0.4)
        # faint vertical rain streaks (Blender Z is up): stretched noise
        streak = N.map_range(N.noise(pos, 3.0, detail=1.0, mapping_scale=(6.0, 6.0, 0.4)), 0.55, 0.75, 1.0, 0.94)
        k = N.math("MULTIPLY", broad, streak)
        comb = N.new("ShaderNodeCombineColor")
        for i in range(3):
            N.link(k, comb.inputs[i])
        return N.mix(1.0, base, comb.outputs[0], blend="MULTIPLY")
    color = N.rgb(camo["base"])
    for rgb, scale, threshold, seed in camo["tones"]:
        f = N.noise(pos, scale, detail=0.0, distortion=0.15, offset=(seed * 7.3, seed * 3.1, seed * 1.7))
        step = N.math("GREATER_THAN", f, threshold)  # crisp edge
        color = N.mix(step, color, N.rgb(rgb))
    return color


def make_material(kind, spec, variants, target):
    """spec keys: base (rgb, or None for the camouflage), darken (multiplier
    on the camouflage), roughness, metallic, mask (number or "team"),
    edge_wear (0..1), grime (0..1), ao (min factor), bump ("grille" | "tread"
    | None). variants: list of camouflage dicts (see camo_color)."""
    mat = bpy.data.materials.new(kind)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N = _Nodes(nt)

    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    emit = N.new("ShaderNodeEmission")
    img = N.new("ShaderNodeTexImage")
    img.image = target
    img.name = "bake_target"
    nt.nodes.active = img
    geo = N.new("ShaderNodeNewGeometry")
    pos = geo.outputs["Position"]
    height = N.new("ShaderNodeSeparateXYZ")
    N.link(pos, height.inputs[0])
    y_up = height.outputs["Z"]  # Blender Z = Roblox Y

    # edges: bevel normal vs true normal, broken up into chips
    bevel = N.new("ShaderNodeBevel", samples=8)
    bevel.inputs["Radius"].default_value = 0.04
    dot = N.new("ShaderNodeVectorMath", operation="DOT_PRODUCT")
    N.link(bevel.outputs["Normal"], dot.inputs[0])
    N.link(geo.outputs["Normal"], dot.inputs[1])
    edge = N.math("MULTIPLY_ADD", dot.outputs["Value"], -8.0, clamp=True, c=8.0)
    if spec.get("edge_mode") == "highlight":
        chips = edge  # clean, even edge highlight (BAR style)
    else:
        chip_noise = N.noise(pos, 7.0, detail=3.0, roughness=0.7)
        chips = N.math("MULTIPLY", edge, N.map_range(chip_noise, 0.42, 0.62, 0.0, 1.0))
    wear = N.math("MULTIPLY", chips, spec.get("edge_wear", 0.5), clamp=True)

    # grime: low on the hull and in crevices (ambient occlusion)
    ao = N.new("ShaderNodeAmbientOcclusion", samples=16)
    ao.inputs["Distance"].default_value = 0.6
    ao_f = N.map_range(ao.outputs["AO"], 0.0, 1.0, spec.get("ao", 0.62), 1.0)
    low = N.map_range(y_up, 0.7, 1.7, 1.0, 0.0)
    grime_noise = N.map_range(N.noise(pos, 1.6, detail=4.0, mapping_scale=(1.0, 1.0, 2.5)), 0.35, 0.7, 0.4, 1.0)
    grime = N.math("MULTIPLY", N.math("MULTIPLY", low, grime_noise), spec.get("grime", 0.0), clamp=True)

    # one base color per camouflage variant; `variant` picks one (0, 1, ...)
    variant = N.value(0.0)
    colors = []
    for camo in variants:
        if spec.get("base") is None:
            c = camo_color(N, pos, camo)
            if spec.get("darken"):
                c = N.mix(1.0, c, (int(255 * spec["darken"]),) * 3, blend="MULTIPLY")
        else:
            c = N.rgb(spec["base"])
        c = N.mix(wear, c, camo.get("chip", (214, 204, 176)))
        c = N.mix(grime, c, camo.get("grime", (104, 94, 76)))
        if spec.get("scorch"):
            # wreck soot: broad burnt patches, blacker low and in creases
            burn = N.map_range(N.noise(pos, 0.45, detail=4.0, roughness=0.65), 0.38, 0.62, 0.0, 1.0)
            burn = N.math("MULTIPLY", N.math("ADD", burn, N.math("MULTIPLY", low, 0.5)), spec["scorch"], clamp=True)
            c = N.mix(burn, c, spec.get("soot", (20, 18, 17)))
        colors.append(c)
    color = colors[0]
    for i, c in enumerate(colors[1:], start=1):
        pick = N.math("GREATER_THAN", variant, i - 0.5)
        color = N.mix(pick, color, c)
    comb = N.new("ShaderNodeCombineColor")
    for i in range(3):
        N.link(ao_f, comb.inputs[i])
    color = N.mix(1.0, color, comb.outputs[0], blend="MULTIPLY")

    # team mask (alpha): painted panels show the team color through a thin
    # dark wash, chipped on the edges and darker in crevices
    if spec.get("mask") == "team":
        occl = N.math("SUBTRACT", 1.0, ao.outputs["AO"])
        mask = N.math("ADD", N.math("ADD", spec.get("wash", 0.3), N.math("MULTIPLY", chips, spec.get("chip_reveal", 0.9))),
                      N.math("MULTIPLY", occl, spec.get("crease", 0.5)), clamp=True)
    else:
        mask = N.value(spec.get("mask", 1.0))

    rough = N.math("ADD", N.math("MULTIPLY_ADD", wear, -0.2, c=spec["roughness"]),
                   N.math("MULTIPLY", grime, 0.1), clamp=True)
    metal = N.value(spec["metallic"])
    emission = N.value(spec.get("emit", 0.0))  # emissive mask (lights, sensors)

    bump = N.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.02
    N.link(bevel.outputs["Normal"], bump.inputs["Normal"])
    pattern = spec.get("bump")
    if pattern in ("grille", "tread"):
        wave = N.new("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X" if pattern == "grille" else "Y")
        wave.inputs["Scale"].default_value = 1.2 if pattern == "grille" else 2.2
        wave.inputs["Distortion"].default_value = 0.0
        N.link(pos, wave.inputs["Vector"])
        N.link(wave.outputs["Fac"], bump.inputs["Height"])
        bump.inputs["Strength"].default_value = 0.8
    else:
        N.link(N.noise(pos, 9.0), bump.inputs["Height"])
        bump.inputs["Strength"].default_value = 0.04

    N.link(color, bsdf.inputs["Base Color"])
    N.link(rough, bsdf.inputs["Roughness"])
    N.link(metal, bsdf.inputs["Metallic"])
    N.link(bump.outputs["Normal"], bsdf.inputs["Normal"])
    N.link(bsdf.outputs[0], out.inputs["Surface"])

    variant_node = variant.node
    mat_sockets[mat.name] = {
        "out": out, "bsdf": bsdf, "emit": emit, "variant": variant_node,
        "color": color, "roughness": rough, "metallic": metal, "mask": mask,
        "emission": emission,
    }
    return mat


def set_variant(materials, i):
    for mat in materials:
        mat_sockets[mat.name]["variant"].outputs[0].default_value = float(i)


def show_channel(materials, channel):
    """Routes every material's output to an emission of `channel`, or back to
    the lit BSDF when channel is None."""
    for mat in materials:
        s = mat_sockets[mat.name]
        nt = mat.node_tree
        for link in list(s["out"].inputs["Surface"].links):
            nt.links.remove(link)
        for link in list(s["emit"].inputs["Color"].links):
            nt.links.remove(link)
        if channel is None:
            nt.links.new(s["bsdf"].outputs[0], s["out"].inputs["Surface"])
        else:
            nt.links.new(s[channel], s["emit"].inputs["Color"])
            nt.links.new(s["emit"].outputs[0], s["out"].inputs["Surface"])


def set_target(materials, image):
    for mat in materials:
        node = mat.node_tree.nodes["bake_target"]
        node.image = image
        mat.node_tree.nodes.active = node


def new_image(name, size, color_space, alpha=False):
    img = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=False)
    img.colorspace_settings.name = color_space
    return img


# ---------------------------------------------------------------------------
# UVs, bakes, export
# ---------------------------------------------------------------------------


def select_only(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def unwrap(objs, margin=0.006):
    """One shared atlas for all pieces (multi-object edit), uniform density."""
    select_only(objs, objs[0])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin,
                             area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def joined_copy(objs, name):
    """One object joining copies of `objs` (world positions kept): the
    single active target a selected-to-active bake needs."""
    copies = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        copies.append(c)
    select_only(copies, copies[0])
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    return joined


def bake_all(low, high, materials, size, samples, out_dir, prefix, variants):
    """Bakes the detailed pieces onto the low-poly atlas. Returns the images
    per variant: {"a": {"ALB", "NOR", "RGH", "MTL", "EMI"}, ...}; the normal,
    metalness and emissive-mask maps are shared."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.render.bake.margin = 8
    target = joined_copy(low, f"{prefix}_bake_target")
    select_only(high + [target], target)

    def bake(kind, name, space, channel=None):
        img = new_image(name, size, space)
        set_target(materials, img)
        show_channel(materials, channel)
        bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.05,
                            max_ray_distance=0.2, use_clear=True, margin=8,
                            normal_space="TANGENT")
        return img

    import numpy as np
    os.makedirs(out_dir, exist_ok=True)
    nor = bake("NORMAL", f"{prefix}_NOR", "Non-Color")
    metal = bake("EMIT", f"{prefix}_MTL", "Non-Color", "metallic")
    mask = bake("EMIT", f"{prefix}_mask", "Non-Color", "mask")
    emi = bake("EMIT", f"{prefix}_EMI", "Non-Color", "emission")
    save_png(nor, os.path.join(out_dir, f"{nor.name}.png"), "RGB")
    save_png(metal, os.path.join(out_dir, f"{metal.name}.png"), "BW")
    save_png(emi, os.path.join(out_dir, f"{emi.name}.png"), "BW")
    m = np.array(mask.pixels[:], dtype=np.float32).reshape(-1, 4)

    result = {}
    for i, key in enumerate(variants):
        set_variant(materials, i)
        color = bake("EMIT", f"{prefix}_{key}_color", "sRGB", "color")
        rough = bake("EMIT", f"{prefix}_{key}_RGH", "Non-Color", "roughness")
        alb = bpy.data.images.new(f"{prefix}_{key}_ALB", size, size, alpha=True)
        alb.colorspace_settings.name = "sRGB"
        c = np.array(color.pixels[:], dtype=np.float32).reshape(-1, 4)
        c[:, 3] = m[:, 0]
        alb.pixels[:] = c.ravel()
        save_png(alb, os.path.join(out_dir, f"{alb.name}.png"), "RGBA")
        save_png(rough, os.path.join(out_dir, f"{rough.name}.png"), "BW")
        result[key] = {"ALB": alb, "NOR": nor, "RGH": rough, "MTL": metal, "EMI": emi}
    show_channel(materials, None)
    bpy.data.objects.remove(target, do_unlink=True)
    return result


# Upload revision (pipeline.md, import notes): Studio's 3D Importer reuses an
# image it has uploaded before when the file is identical, so a map whose
# upload broke stays broken on every re-import. Bumping a unit's UPLOAD_REV
# changes one corner pixel of every map so the importer uploads them anew.
UPLOAD_REV = 0


def save_png(img, path, mode):
    if UPLOAD_REV:
        v = (UPLOAD_REV * 37 % 255) / 255
        i = len(img.pixels) - img.channels  # last pixel: top-right corner
        img.pixels[i:i + 3] = (v, v, v)
    scene = bpy.context.scene
    s = scene.render.image_settings
    s.file_format = "PNG"
    s.color_mode = mode
    s.color_depth = "8"
    s.compression = 90
    img.save_render(path, scene=scene)
    # point the image at its file so the FBX export can embed it
    img.source = "FILE"
    img.filepath = path
    img.reload()


def textured_material(name, imgs, team_rgb=None, emissive_rgb=None):
    """Material using a baked set, for the FBX and (with `team_rgb`, the
    team color under the alpha mask as AlphaMode.Overlay draws it, and
    `emissive_rgb` through the emissive mask) the preview renders."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes.new, nt.links.new
    out = N("ShaderNodeOutputMaterial")
    bsdf = N("ShaderNodeBsdfPrincipled")
    alb = N("ShaderNodeTexImage"); alb.image = imgs["ALB"]
    nor = N("ShaderNodeTexImage"); nor.image = imgs["NOR"]
    rgh = N("ShaderNodeTexImage"); rgh.image = imgs["RGH"]
    mtl = N("ShaderNodeTexImage"); mtl.image = imgs["MTL"]
    nmap = N("ShaderNodeNormalMap")
    L(rgh.outputs["Color"], bsdf.inputs["Roughness"])
    L(mtl.outputs["Color"], bsdf.inputs["Metallic"])
    L(nor.outputs["Color"], nmap.inputs["Color"])
    L(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if team_rgb is None:
        L(alb.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        mix = N("ShaderNodeMix")
        mix.data_type = "RGBA"
        team = N("ShaderNodeRGB")
        team.outputs[0].default_value = srgb(team_rgb)
        L(alb.outputs["Alpha"], mix.inputs[0])
        L(team.outputs[0], mix.inputs[6])
        L(alb.outputs["Color"], mix.inputs[7])
        L(mix.outputs[2], bsdf.inputs["Base Color"])
    if emissive_rgb is not None and "EMI" in imgs:
        emi = N("ShaderNodeTexImage"); emi.image = imgs["EMI"]
        strength = N("ShaderNodeMath"); strength.operation = "MULTIPLY"
        strength.inputs[1].default_value = 4.0
        L(emi.outputs["Color"], strength.inputs[0])
        bsdf.inputs["Emission Color"].default_value = srgb(emissive_rgb)
        L(strength.outputs[0], bsdf.inputs["Emission Strength"])
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def image_probe(name, image, collection, at=(0.0, -2.0, 0.0)):
    """A tiny quad whose material's base color is `image`: the 3D Importer
    uploads only maps a material uses, so this carries a map with no PBR slot
    in the FBX (the emissive mask) up to Roblox. The rig step reads its asset
    ID and deletes the quad."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.1)
    for v in bm.verts:
        v.co += R(*at)
    bm.to_mesh(mesh)
    bm.free()
    mesh.uv_layers.new(name="UVMap")
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    mesh.materials.append(mat)
    return obj


def assign_single_material(objs, mat):
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.material_index = 0


def export_fbx(objs, path):
    select_only(objs, objs[0])
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True,
        mesh_smooth_type="FACE", use_tspace=True, add_leaf_bones=False,
        path_mode="COPY", embed_textures=True, bake_space_transform=True,
    )


def render_preview(path, cam_from_roblox, look_at_roblox, size=(1280, 720), samples=32, lens=50):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.render.resolution_x, scene.render.resolution_y = size
    cam_data = bpy.data.cameras.get("preview_cam") or bpy.data.cameras.new("preview_cam")
    cam_data.lens = lens
    cam = bpy.data.objects.get("preview_cam") or bpy.data.objects.new("preview_cam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam.location = R(*cam_from_roblox)
    direction = R(*look_at_roblox) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    s = scene.render.image_settings
    s.file_format = "PNG"
    s.color_mode = "RGB"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def preview_lighting():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.45, 0.5, 0.55, 1)
    bg.inputs["Strength"].default_value = 0.6
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.0
    sun_obj = bpy.data.objects.new("sun", sun)
    sun_obj.rotation_euler = (math.radians(40), math.radians(10), math.radians(30))
    scene.collection.objects.link(sun_obj)
    ground = bpy.data.meshes.new("ground")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=40)
    bm.to_mesh(ground)
    bm.free()
    g = bpy.data.objects.new("ground", ground)
    gm = bpy.data.materials.new("ground_mat")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb((92, 118, 70))
    ground.materials.append(gm)
    scene.collection.objects.link(g)


def bounds(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    rb = [to_roblox(v) for v in pts]
    lo = [min(v[i] for v in rb) for i in range(3)]
    hi = [max(v[i] for v in rb) for i in range(3)]
    return {"center": [round((lo[i] + hi[i]) / 2, 4) for i in range(3)],
            "size": [round(hi[i] - lo[i], 4) for i in range(3)]}


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
