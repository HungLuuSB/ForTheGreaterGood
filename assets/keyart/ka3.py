"""Key art 3, "Converging" (layout ka3_a with the user's fixes, 2026-10-24;
docs/art/keyart.md): an Order SAM base on green hills in broad daylight
under a massive Chaos air raid. A Chaos nuke comes in high from the upper
right and the Providence's interceptor climbs to meet it, frozen just before
the interception. Reuses key art 1's tools (ka1.py): the layer pipeline, the
grade, the effects and the dressing.

    blender -b --factory-startup --python-exit-code 1 -P assets/keyart/ka3.py -- light|test|final [--samples N] [--only layers]

Writes assets/keyart/ka3/light.png (step 3) or assets/keyart/ka3/<mode>/ (step 4).

The user's fixes to layout A:
1. The nuke is the hero: its glowing nose inside the safe area, about a
   third of the way from the meeting point toward the upper right corner,
   its trail running off the top right; biggest and brightest thing in the
   sky, nothing crossing its lane.
2. The close Manticore 30% smaller and lower, nose angled toward the
   centre, framing the right side clear of the nuke's path.
3. A dense raid at every depth: a bomber formation far back, gunships low
   over the base, the hit Harpy spiralling down.
4. The base staggered in depth, some structures close and big, some far;
   the Phalanx shield (the v4 look, fx.md "Shield energy") a large visible
   dome over part of the base.
5. The foreground Vigil up and left, only its base touching the bottom
   band; dust and backblast low; the band calm.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import keyart as K  # noqa: E402
import layout as L  # noqa: E402
import ka1 as A  # noqa: E402

OUT = os.path.join(HERE, "ka3")
HORIZON = 0.58
CAM_H = 4.5
SUN_AZ, SUN_EL = 50.0, 25.0  # low from the right, beyond the base: long hard shadows fall left and toward the camera
STAGE = 2  # the user's rebuild (2026-10-24): 1 = the story only (sky, ground, base, nuke, interceptor, jets, shield); 2 = the battle too
WIND = Vector((0.4, 0.3, 0.0))
SHIELD_TINT = (143, 232, 255)  # the Order shield (fx.md "Shield energy")
X = L.X


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------

def meadow_material(fade=None):
    """Green meadow in daylight: grass in broad patches of two greens, drier
    yellow-green streaks, bare earth here and there, burnt black where the
    bombs fell (the mesh's `scorch` attribute); optionally fading out (layers)."""
    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        coord = N("ShaderNodeTexCoord")

        def noise_tex(scale, detail=6.0, rough=0.6):
            t = N("ShaderNodeTexNoise")
            K.set_in(t, "Scale", scale)
            K.set_in(t, "Detail", detail)
            K.set_in(t, "Roughness", rough)
            Ln(coord.outputs["Object"], t.inputs["Vector"])
            return t

        def ramp(src, stops):
            r = N("ShaderNodeValToRGB")
            e = r.color_ramp.elements
            e[0].position, e[0].color = stops[0][0], K.lib.srgb(stops[0][1])
            e[1].position, e[1].color = stops[-1][0], K.lib.srgb(stops[-1][1])
            for pos, c in stops[1:-1]:
                n = e.new(pos)
                n.color = K.lib.srgb(c)
            Ln(src, r.inputs["Fac"])
            return r.outputs["Color"]

        def mix(a, b, fac):
            m = N("ShaderNodeMix")
            m.data_type = "RGBA"
            Ln(fac, m.inputs["Factor"])
            Ln(a, m.inputs["A"])
            Ln(b, m.inputs["B"])
            return m.outputs["Result"]

        def bw(col):
            c = N("ShaderNodeRGBToBW")
            Ln(col, c.inputs["Color"])
            return c.outputs["Val"]

        col = ramp(noise_tex(0.03, 5).outputs["Fac"], [(0.3, (58, 86, 36)), (0.55, (78, 106, 44)), (0.78, (64, 92, 40))])
        fine = ramp(noise_tex(1.6, 8).outputs["Fac"], [(0.3, (0, 0, 0)), (0.7, (255, 255, 255))])
        col = mix(col, ramp(noise_tex(1.1).outputs["Fac"], [(0.3, (50, 74, 30)), (0.7, (92, 118, 52))]), bw(fine))
        dry = ramp(noise_tex(0.05, 4).outputs["Fac"], [(0.5, (0, 0, 0)), (0.62, (255, 255, 255))])
        col = mix(col, ramp(noise_tex(0.9).outputs["Fac"], [(0.3, (112, 116, 58)), (0.7, (136, 132, 70))]), bw(dry))
        earth = ramp(noise_tex(0.08, 6).outputs["Fac"], [(0.6, (0, 0, 0)), (0.7, (255, 255, 255))])
        col = mix(col, ramp(noise_tex(1.3).outputs["Fac"], [(0.3, (88, 72, 54)), (0.7, (110, 92, 70))]), bw(earth))
        attr = N("ShaderNodeAttribute")
        attr.attribute_name = "scorch"
        c2 = N("ShaderNodeMapRange")
        c2.inputs["From Min"].default_value, c2.inputs["From Max"].default_value = 0.3, 0.85
        Ln(attr.outputs["Fac"], c2.inputs["Value"])
        col = mix(col, ramp(noise_tex(1.4).outputs["Fac"], [(0.3, (26, 24, 20)), (0.7, (48, 42, 34))]), c2.outputs["Result"])
        b = N("ShaderNodeBsdfPrincipled")
        Ln(col, b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.92
        b1 = N("ShaderNodeBump")
        K.set_in(b1, "Strength", 0.35)
        K.set_in(b1, "Distance", 0.2)
        Ln(noise_tex(0.5, 10, 0.65).outputs["Fac"], b1.inputs["Height"])
        b2 = N("ShaderNodeBump")
        K.set_in(b2, "Strength", 0.5)
        K.set_in(b2, "Distance", 0.05)
        Ln(noise_tex(6.0, 12, 0.75).outputs["Fac"], b2.inputs["Height"])
        Ln(b1.outputs["Normal"], b2.inputs["Normal"])
        Ln(b2.outputs["Normal"], b.inputs["Normal"])
        if fade:
            sep = N("ShaderNodeSeparateXYZ")
            Ln(coord.outputs["Object"], sep.inputs["Vector"])
            fr = N("ShaderNodeMapRange")
            fr.interpolation_type = "SMOOTHSTEP"
            fr.inputs["From Min"].default_value, fr.inputs["From Max"].default_value = fade
            Ln(sep.outputs["Y"], fr.inputs["Value"])
            tr = N("ShaderNodeBsdfTransparent")
            mx = N("ShaderNodeMixShader")
            Ln(fr.outputs["Result"], mx.inputs["Fac"])
            Ln(b.outputs["BSDF"], mx.inputs[1])
            Ln(tr.outputs["BSDF"], mx.inputs[2])
            Ln(mx.outputs["Shader"], out.inputs["Surface"])
        else:
            Ln(b.outputs["BSDF"], out.inputs["Surface"])
    return K.material(f"meadow_{fade}", build)


def dirt_material():
    """Worn earth for the paths: brown with darker ruts, its edges broken
    up by noise and fading into the grass (UV v across the strip)."""
    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        tc = N("ShaderNodeTexCoord")
        sep = N("ShaderNodeSeparateXYZ")
        Ln(tc.outputs["UV"], sep.inputs["Vector"])
        mid = N("ShaderNodeMath")
        mid.operation = "SUBTRACT"
        mid.inputs[1].default_value = 0.5
        Ln(sep.outputs["Y"], mid.inputs[0])
        ab = N("ShaderNodeMath")
        ab.operation = "ABSOLUTE"
        Ln(mid.outputs["Value"], ab.inputs[0])
        nz = N("ShaderNodeTexNoise")
        K.set_in(nz, "Scale", 0.6)
        K.set_in(nz, "Detail", 6.0)
        Ln(tc.outputs["Object"], nz.inputs["Vector"])
        jit = N("ShaderNodeMath")
        jit.operation = "MULTIPLY_ADD"
        jit.inputs[1].default_value = 0.35
        jit.inputs[2].default_value = -0.17
        Ln(nz.outputs["Fac"], jit.inputs[0])
        edge = N("ShaderNodeMath")
        edge.operation = "ADD"
        Ln(ab.outputs["Value"], edge.inputs[0])
        Ln(jit.outputs["Value"], edge.inputs[1])
        fac = N("ShaderNodeMapRange")
        fac.interpolation_type = "SMOOTHSTEP"
        fac.inputs["From Min"].default_value, fac.inputs["From Max"].default_value = 0.42, 0.22
        Ln(edge.outputs["Value"], fac.inputs["Value"])
        col = N("ShaderNodeValToRGB")
        e = col.color_ramp.elements
        e[0].position, e[0].color = 0.35, K.lib.srgb((84, 68, 50))
        e[1].position, e[1].color = 0.65, K.lib.srgb((122, 102, 78))
        n2 = N("ShaderNodeTexNoise")
        K.set_in(n2, "Scale", 2.5)
        Ln(tc.outputs["Object"], n2.inputs["Vector"])
        Ln(n2.outputs["Fac"], col.inputs["Fac"])
        b = N("ShaderNodeBsdfPrincipled")
        Ln(col.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.95
        tr = N("ShaderNodeBsdfTransparent")
        mx = N("ShaderNodeMixShader")
        Ln(fac.outputs["Result"], mx.inputs["Fac"])
        Ln(tr.outputs["BSDF"], mx.inputs[1])
        Ln(b.outputs["BSDF"], mx.inputs[2])
        Ln(mx.outputs["Shader"], out.inputs["Surface"])
    return K.material("dirt_path", build)


def dirt_path(layer, gz, pts, width, seed):
    """A worn earth path draped on the ground through `pts` (x, y), a
    little wavy."""
    rng = random.Random(seed)
    dense = []
    for a, b in zip(pts, pts[1:]):
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        n = max(2, int((b - a).length / 2.0))
        for k in range(n):
            dense.append(a.lerp(b, k / n))
    dense.append(Vector((pts[-1][0], pts[-1][1], 0)))
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    prev = None
    phase = rng.uniform(0, 6.3)
    for i, q in enumerate(dense):
        nxt = dense[min(i + 1, len(dense) - 1)] - dense[max(i - 1, 0)]
        side = Vector((nxt.y, -nxt.x, 0)).normalized()
        w = width * (0.8 + 0.3 * math.sin(i * 0.37 + phase))
        c = q + side * math.sin(i * 0.15 + phase) * 1.2
        lo, hi = c - side * w / 2, c + side * w / 2
        v0 = bm.verts.new((lo.x, lo.y, gz(lo.x, lo.y) + 0.06))
        v1 = bm.verts.new((hi.x, hi.y, gz(hi.x, hi.y) + 0.06))
        if prev:
            f = bm.faces.new((prev[0], v0, v1, prev[1]))
            for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[uvl].uv = uv
        prev = (v0, v1)
    me = bpy.data.meshes.new("path")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("path", me)
    me.materials.append(dirt_material())
    K.link(o, layer)
    o.visible_shadow = False
    return o


def blast(layer, pos, size, seed, fresh=False):
    """A bomb on grass: the explosion (fireball, soot, debris, light) and
    brown earth thrown up in columns."""
    rng = random.Random(seed)
    p = Vector(pos)
    K.explosion(layer, tuple(p), size, smoke=1.0, seed=seed)
    dirt = K.volume_material("earth_dust", (120, 104, 84), 1.4, scale=2.2, cut=0.34, soft=0.4, vary=0.4)
    for k in range(rng.randint(3, 5)):
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0))
        K.blob_dir(layer, p, d, size * rng.uniform(1.8, 3.2), size * rng.uniform(0.22, 0.38), dirt, seed + 200 + k)
    if fresh:
        core = K.prim("ico_sphere", layer, subdivisions=2, radius=size * 0.35, location=p + Vector((0, 0, size * 0.6)))
        K.set_mat(core, K.emissive("blast_core", (255, 240, 210), 18.0))
        K.point(p + Vector((0, 0, size)), (255, 190, 120), 12000 * size, radius=size * 0.8, layer=layer)


# ---------------------------------------------------------------------------
# The Phalanx's shield, the v4 look (fx.md "Shield energy")
# ---------------------------------------------------------------------------

def on_sphere(c, r, theta, phi):
    return c + Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta))) * r


def ribbons(name, layer, segs, width, mat, centre, r):
    """Thin ribbons lying on the sphere along each segment (a, b)."""
    bm = bmesh.new()
    for a, b in segs:
        d = (b - a)
        if d.length < 1e-4:
            continue
        n = ((a + b) / 2 - centre).normalized()
        side = d.normalized().cross(n) * (width / 2)
        vs = [bm.verts.new(v) for v in (a - side, b - side, b + side, a + side)]
        bm.faces.new(vs)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    me.materials.append(mat)
    K.link(o, layer)
    o.visible_shadow = False
    return o


def gradient_material(name, rgb, strength):
    """Emission fading across a strip: full at UV v 0, nothing at v 1, the
    vertex alpha (color attribute `a`) scaling it along the strip."""
    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        uv = N("ShaderNodeTexCoord")
        sep = N("ShaderNodeSeparateXYZ")
        Ln(uv.outputs["UV"], sep.inputs["Vector"])
        fall = N("ShaderNodeMapRange")
        fall.interpolation_type = "SMOOTHSTEP"
        fall.inputs["From Min"].default_value, fall.inputs["From Max"].default_value = 1.0, 0.0
        Ln(sep.outputs["Y"], fall.inputs["Value"])
        attr = N("ShaderNodeAttribute")
        attr.attribute_name = "a"
        mul = N("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        Ln(fall.outputs["Result"], mul.inputs[0])
        Ln(attr.outputs["Fac"], mul.inputs[1])
        em = N("ShaderNodeEmission")
        em.inputs["Color"].default_value = K.lib.srgb(rgb)
        em.inputs["Strength"].default_value = strength
        tr = N("ShaderNodeBsdfTransparent")
        mx = N("ShaderNodeMixShader")
        Ln(mul.outputs["Value"], mx.inputs["Fac"])
        Ln(tr.outputs["BSDF"], mx.inputs[1])
        Ln(em.outputs["Emission"], mx.inputs[2])
        Ln(mx.outputs["Shader"], out.inputs["Surface"])
    return K.material(name, build)


def band_strip(name, layer, rows, alphas, mat):
    """A strip through `rows` of (lower, upper) points, UV v 0 at the lower
    edge and 1 at the upper; `alphas` per row in the attribute `a`."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    al = bm.verts.layers.float.new("a")
    prev = None
    for (lo, up), a in zip(rows, alphas):
        v0, v1 = bm.verts.new(lo), bm.verts.new(up)
        v0[al] = v1[al] = a
        if prev:
            f = bm.faces.new((prev[0], v0, v1, prev[1]))
            for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[uvl].uv = uv
        prev = (v0, v1)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    me.materials.append(mat)
    K.link(o, layer)
    o.visible_shadow = False
    return o


def hex_edges(centre, r):
    """The honeycomb's cell borders over the upper half: the dual of a
    geodesic sphere (frequency 32, about 0.035 R cells: fine at the key
    art's distance)."""
    src = bmesh.new()
    bmesh.ops.create_icosphere(src, subdivisions=6, radius=1.0)
    src.faces.ensure_lookup_table()
    cen = {f.index: f.calc_center_median().normalized() for f in src.faces}
    segs = []
    for e in src.edges:
        if len(e.link_faces) != 2:
            continue
        a, b = cen[e.link_faces[0].index], cen[e.link_faces[1].index]
        if a.z < 0.0 and b.z < 0.0:
            continue
        segs.append((centre + a * r * 1.004, centre + b * r * 1.004, (a + b).normalized()))
    src.free()
    return segs


def shield_v4(layer, centre, r, beam_from, hits, seed):
    """The Phalanx's dome as the game draws it (v4, fx.md "Shield energy"):
    nearly clear with a bright outline, a faint fine honeycomb, wobbly
    energy waves rolling down (a crackling line under a soft glow that
    fades up toward the apex, the cells under them lit), subtle streaks
    down the meridians, a thin straight beam up to the apex with a small
    flare, and small hit patches of lit cells."""
    rng = random.Random(seed)
    c = Vector(centre)
    tint = SHIELD_TINT

    def shell_build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        lw = N("ShaderNodeLayerWeight")
        K.set_in(lw, "Blend", 0.35)
        em = N("ShaderNodeEmission")
        em.inputs["Color"].default_value = K.lib.srgb(tint)
        em.inputs["Strength"].default_value = 9.0
        tr = N("ShaderNodeBsdfTransparent")
        mx = N("ShaderNodeMixShader")
        rr = N("ShaderNodeMapRange")
        rr.interpolation_type = "SMOOTHSTEP"
        rr.inputs["From Min"].default_value, rr.inputs["From Max"].default_value = 0.4, 1.0
        rr.inputs["To Min"].default_value, rr.inputs["To Max"].default_value = 0.0, 0.85
        Ln(lw.outputs["Facing"], rr.inputs["Value"])
        Ln(rr.outputs["Result"], mx.inputs["Fac"])
        Ln(tr.outputs["BSDF"], mx.inputs[1])
        Ln(em.outputs["Emission"], mx.inputs[2])
        Ln(mx.outputs["Shader"], out.inputs["Surface"])
    o = K.prim("uv_sphere", layer, segments=96, ring_count=48, radius=r, location=c)
    K.set_mat(o, K.material("shield_v4", shell_build))
    o.visible_shadow = False

    # the waves: three wobbly rings rolling down (0 apex .. 1 ground), accelerating, fading near the ground
    waves = []
    for i, wp in enumerate((0.2, 0.47, 0.76)):
        phase = rng.uniform(0, 6.3)
        n = 120
        fade = min(1.0, 1.0 - max(0.0, (wp - 0.7) / 0.3)) * 0.9 + 0.1
        rows, alphas, segs_l = [], [], []
        prev = None
        for k in range(n + 1):
            phi = k / n * 2 * math.pi
            wob = 0.03 * math.sin(3 * phi + 2.1 * i + phase) + 0.017 * math.sin(7 * phi - phase + i)
            th = (wp + wob) * math.pi / 2
            gap = 0.08 if math.sin(phi * 6 + phase + i * 3) > 0.75 else 1.0
            a = fade * gap * (0.45 + 0.55 * max(0.0, math.sin(phi * 4 + 1.7 * i + phase)))
            rows.append((on_sphere(c, r * 1.008, th, phi), on_sphere(c, r * 1.008, th - 0.055, phi)))
            alphas.append(a)
            cur = on_sphere(c, r * 1.01, th + rng.uniform(-0.012, 0.012), phi)  # crackling
            if prev is not None and a > 0.3:
                segs_l.append((prev, cur))
            prev = cur
        waves.append(wp)
        band_strip(f"wave_glow_{i}", layer, rows, [a * 0.7 for a in alphas], gradient_material(f"wave_glow_{i}", tint, 3.0))
        ribbons(f"wave_line_{i}", layer, segs_l, r * 0.008, K.emissive(f"wave_line_{i}", (232, 250, 255), 24.0 * fade), c, r)

    # the honeycomb: faint and fine everywhere, lit under the waves and in the hit patches
    hit_dirs = []
    for _ in range(hits):
        a, e = rng.uniform(math.pi * 1.2, math.pi * 1.8), rng.uniform(0.4, 0.9)  # on the camera's side
        hit_dirs.append(Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))))
    faint, lit, hot = [], [], []
    for a, b, mid in hex_edges(c, r):
        th = math.acos(max(-1.0, min(1.0, mid.z))) / (math.pi / 2)
        if any(mid.angle(h) < 0.13 for h in hit_dirs):
            hot.append((a, b))
        elif any(-0.06 < wp - th < 0.0 for wp in waves):  # just above each wave's line
            lit.append((a, b))
        else:
            faint.append((a, b))
    # no idle honeycomb (the user, 2026-10-24: cells only in the hit patches)
    ribbons("hex_hot", layer, hot, r * 0.0018, K.emissive("hex_hot", (200, 240, 255), 5.0), c, r)
    for h in hit_dirs:
        q = c + h * r
        K.point(q, (150, 230, 255), 6000, radius=1.5, layer=layer)

    # streaks down the meridians, subtle, behind the waves
    segs = []
    for k in range(20):
        phi = k / 20 * 2 * math.pi + rng.uniform(-0.12, 0.12)
        top = rng.uniform(0.04, 0.3)
        length = rng.uniform(0.12, 0.3)
        n = 8
        for j in range(n):
            t0 = (top + length * j / n) * math.pi / 2
            t1 = (top + length * (j + 1) / n) * math.pi / 2
            segs.append((on_sphere(c, r * 1.006, t0, phi), on_sphere(c, r * 1.006, t1, phi)))
    ribbons("streaks", layer, segs, r * 0.005, K.emissive("streak", tint, 1.4), c, r)

    # the beam: thin and straight, a bright core in a narrow glow, up to the apex; a small flare there
    apex = c + Vector((0, 0, r))
    a = Vector(beam_from)
    d = apex - a
    core = K.prim("cylinder", layer, vertices=8, radius=0.1, depth=d.length, location=(a + apex) / 2)
    core.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    K.set_mat(core, K.emissive("beam_core", (235, 252, 255), 50.0))
    glow = K.prim("cylinder", layer, vertices=12, radius=0.32, depth=d.length, location=(a + apex) / 2)
    glow.rotation_euler = core.rotation_euler
    K.set_mat(glow, K.volume_material("beam_glow", tint, 0.0, tint, 5.0, scale=1.0))
    flare = K.prim("ico_sphere", layer, subdivisions=2, radius=0.45, location=apex)
    K.set_mat(flare, K.emissive("apex_flare", (235, 252, 255), 60.0))
    rays = K.emissive("apex_rays", (200, 244, 255), 24.0)
    for k in range(12):
        ang = k / 12 * 2 * math.pi + rng.uniform(0, 0.3)
        ln = rng.uniform(1.2, 3.0)
        dirv = Vector((math.cos(ang), 0.2 * math.sin(ang * 3), math.sin(ang))).normalized()
        ray = K.prim("cone", layer, vertices=4, radius1=0.06, radius2=0.0, depth=ln, location=apex + dirv * ln / 2)
        ray.rotation_euler = dirv.to_track_quat("Z", "Y").to_euler()
        K.set_mat(ray, rays)
    K.point(apex, tint, 12000, radius=1.0, layer=layer)


# ---------------------------------------------------------------------------
# The nuke and the interceptor
# ---------------------------------------------------------------------------

def missile(mid, layer, pos, direction, scale):
    """A missile from assets/fx/missiles with its own textures (like the
    units: the team plates, the faction glow)."""
    exp = os.path.join(K.ROOT, "assets", "fx", "missiles", mid, "export")
    imgs = {}
    for k, f in {"ALB": f"{mid}_bar_ALB.png", "RGH": f"{mid}_bar_RGH.png", "NOR": f"{mid}_NOR.png",
                 "MTL": f"{mid}_MTL.png", "EMI": f"{mid}_EMI.png"}.items():
        img = bpy.data.images.load(os.path.join(exp, f), check_existing=True)
        if k != "ALB":
            img.colorspace_settings.name = "Non-Color"
        imgs[k] = img
    faction = K.FACTION[mid[:3]]
    base = K.lib.textured_material(f"m_{mid}", imgs, K.TEAM[faction], None)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(exp, f"{mid}.fbx"))
    objs = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(f"{mid}_root", None)
    K.link(root, layer)
    for o in objs:
        for col in o.users_collection:
            col.objects.unlink(o)
        if o.type != "MESH" or o.name.startswith(("emissive_probe", "tex_")):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        K.link(o, layer)
        if "_glow_" in o.name:
            m = K.lib.textured_material(f"mg_{mid}", imgs, None, (255, 150, 60))  # the Chaos amber
            for nd in m.node_tree.nodes:
                if nd.type == "BSDF_PRINCIPLED":
                    nd.inputs["Emission Strength"].default_value *= 3.0
            K.lib.assign_single_material([o], m)
        else:
            K.lib.assign_single_material([o], base)
        o.parent = root
    root.location = pos
    root.rotation_euler = Vector(direction).to_track_quat("Y", "Z").to_euler()
    root.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    return root


def nuke(layer, nose, d, length, seed):
    """The hero: the warhead diving in, its nose glowing white-hot from
    re-entry in a sheath of fire, a long thick white trail behind it off
    the top right of the frame."""
    root = missile("chs_nuke", layer, nose, d, 1.0)
    own = (K.extreme(root, d) - K.extreme(root, -d)).length
    root.scale = (length / own,) * 3  # `length` studs nose to tail
    bpy.context.view_layer.update()
    tip = K.extreme(root, d)
    tail = K.extreme(root, -d)
    root.location += nose - tip  # the tip exactly at the nose point
    tip, tail = nose, tail + (nose - tip)
    body_r = length * 0.045  # the body's radius (the fins would spoil a measured one)
    # the heat shield glowing: a thin shell over the nose, white-hot at the tip fading to orange and then nothing
    def glow_build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        tc = N("ShaderNodeTexCoord")
        sep = N("ShaderNodeSeparateXYZ")
        Ln(tc.outputs["Generated"], sep.inputs["Vector"])
        ramp = N("ShaderNodeValToRGB")
        e = ramp.color_ramp.elements
        e[0].position, e[0].color = 0.0, (1.0, 0.25, 0.04, 0.0)
        e[1].position, e[1].color = 1.0, (1.0, 0.95, 0.85, 1.0)
        mid = e.new(0.6)
        mid.color = (1.0, 0.55, 0.15, 0.7)
        Ln(sep.outputs["Z"], ramp.inputs["Fac"])
        em = N("ShaderNodeEmission")
        Ln(ramp.outputs["Color"], em.inputs["Color"])
        em.inputs["Strength"].default_value = 30.0
        tr = N("ShaderNodeBsdfTransparent")
        mx = N("ShaderNodeMixShader")
        Ln(ramp.outputs["Alpha"], mx.inputs["Fac"])
        Ln(tr.outputs["BSDF"], mx.inputs[1])
        Ln(em.outputs["Emission"], mx.inputs[2])
        Ln(mx.outputs["Shader"], out.inputs["Surface"])
    cap_len = length * 0.2
    cap = K.prim("cone", layer, vertices=32, radius1=body_r * 1.12, radius2=body_r * 0.08, depth=cap_len, location=tip - d * cap_len * 0.48)
    cap.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    K.set_mat(cap, K.material("reentry_cap", glow_build))
    cap.visible_shadow = False
    # the plasma streaming back along the body, orange, thin
    sheath = K.fire_material("reentry_sheath", strength=14.0, scale=1.6, cut=0.38)
    K.blob_dir(layer, tip - d * length * 0.02, -d, length * 0.4, body_r * 1.25, sheath, seed)
    K.point(tip + d * body_r, (255, 190, 130), 4e6, radius=body_r, layer=layer)
    # a big exhaust flame from the motor, then the long thick trail
    flame = K.fire_material("nuke_exhaust", strength=110.0, scale=2.0, cut=0.24)
    K.blob_dir(layer, tail, -d, length * 0.9, length * 0.12, flame, seed + 3)
    K.blob_dir(layer, tail, -d, length * 0.5, length * 0.065, K.fire_material("nuke_exhaust_core", strength=260.0, scale=2.4, cut=0.2), seed + 4)
    K.point(tail - d * length * 0.2, (255, 170, 90), 3e6, radius=length * 0.08, layer=layer)
    start = tail - d * length * 0.85
    pts = [start - d * (k * 40.0) for k in range(18)]
    pts.reverse()
    K.trail(layer, [tuple(q) for q in pts], length * 0.17, seed=seed + 2, head_rgb=(255, 214, 160), flame=False)
    return root


def interceptor(layer, start, head, aim, seed):
    """The Providence's interceptor on a gravity turn: straight up out of
    the hatch, bending steadily over toward `aim` (the nuke's nose), its
    head at `head` pointing there (a cubic Bezier: vertical at the hatch,
    along head -> aim at the head). The smoke is thick and bright at the
    bottom, thinner and drifting downwind higher up."""
    span = (head - start).length
    p1 = start + Vector((0, 0, (head.z - start.z) * 0.5))
    p2 = head - (aim - head).normalized() * span * 0.35
    pts = []
    for i in range(200):
        t = i / 199
        pts.append(start * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + head * t ** 3)
    white = K.volume_material("interceptor_smoke", (255, 255, 255), 6.0, (255, 252, 246), 1.6, scale=2.4, cut=0.24,
                              anisotropy=0.5, soft=0.35, vary=0.25)
    rng = random.Random(seed)
    total = sum((b - a).length for a, b in zip(pts, pts[1:]))
    t, i = 0.0, 0
    smoke_end = total - 8.0  # the smoke starts a little behind the missile, so its flame shows
    while i < len(pts) - 1 and t < smoke_end:
        a, b = pts[i], pts[i + 1]
        seg = (b - a).length
        f = 0.0
        while f < seg:
            q = a.lerp(b, f / seg)
            age = 1.0 - (t + f) / total  # 1 at the hatch, 0 at the missile
            r = 1.5 + 3.4 * age ** 1.3  # thick at the bottom, thinning as it climbs
            drift = WIND * 14.0 * age ** 1.5 + Vector((0, 0, 1.5 * age))  # the older smoke has drifted downwind
            K.blob(layer, q + drift + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * r * 0.1,
                   (r, r * rng.uniform(0.85, 1.15), r * rng.uniform(0.85, 1.15)), white, seed * 100 + int(t + f))
            f += r * 0.35  # overlapping puffs: a smooth trail
        t += seg
        i += 1
    d = (pts[-1] - pts[-2]).normalized()
    K.blob_dir(layer, pts[-1] - d * 1.5, -d, 10.0, 1.5, K.fire_material("interceptor_flame", strength=140.0, scale=2.4, cut=0.24), seed + 3)
    K.fx_missile("ord_interceptor", layer, pts[-1] + d * 2.0, d, "order")
    head = K.prim("ico_sphere", layer, subdivisions=2, radius=1.5, location=pts[-1] - d * 1.0)
    K.set_mat(head, K.emissive("interceptor_motor", (255, 240, 210), 220.0))
    K.point(pts[-1], (255, 220, 170), 3e6, radius=1.5, layer=layer)
    return pts[-1]


def smoke_pillar(layer, base, height_, width, seed):
    """A column of smoke from a burning wreck, as real volume (Principled
    Volume, forward scattering): dense dark grey at the foot over a fire,
    widening and turning lighter grey as it climbs, leaning downwind,
    ragged at the edges. The sun lights one side; the other stays in shade."""
    rng = random.Random(seed)
    p = Vector(base)
    mats = [K.volume_material(f"pillar_{seed}_{k}", c, dens, scale=1.4 + 0.3 * k, cut=0.3 + 0.03 * k, anisotropy=0.45, soft=0.45, vary=0.5)
            for k, (c, dens) in enumerate((((46, 44, 42), 2.4), ((70, 68, 66), 1.8), ((104, 102, 100), 1.3), ((138, 136, 134), 0.9)))]
    steps = int(height_ / (width * 0.5))
    for k in range(steps):
        f = k / steps
        r = width * (0.7 + 2.4 * f ** 1.2) * rng.uniform(0.8, 1.2)
        c = p + Vector((WIND.x, WIND.y, 0)) * height_ * 0.6 * f ** 1.6 + Vector((0, 0, height_ * f))
        c += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * r * 0.35
        K.blob(layer, c, (r, r * rng.uniform(0.8, 1.1), r * rng.uniform(0.7, 1.0)), mats[min(3, int(f * 4))], seed * 100 + k)
    K.blob_dir(layer, p, Vector((0, 0, 1)), width * 1.6, width * 0.6, K.fire_material(f"pillar_fire_{seed}", strength=40.0, scale=1.8, cut=0.3), seed + 7)
    K.point(p + Vector((0, 0, width)), (255, 160, 80), 2e4 * width, radius=width * 0.5, layer=layer)


def flak_cluster(layer, centre, spread, count, seed):
    """Flak bursting around a formation: soft-edged dark grey puffs of mixed
    sizes and ages. Fresh ones are small, dense and dark with an orange
    flash in them; old ones are bigger, paler and thinner, drifted
    downwind and coming apart (the user's reference photos)."""
    rng = random.Random(seed)
    for k in range(count):
        age = rng.random() ** 0.8
        off = Vector((rng.uniform(-1, 1), rng.uniform(-0.6, 0.6), rng.uniform(-0.5, 0.7))) * spread
        q = Vector(centre) + off + WIND * spread * 0.8 * age + Vector((0, 0, spread * 0.1 * age))
        sz = spread * (0.08 + 0.16 * age) * rng.uniform(0.8, 1.3)
        shade = int(84 + 64 * age)  # a softer dark grey, never black
        puff = K.volume_material(f"flak_{seed}_{k}", (shade, shade - 2, shade - 5), 1.1 - 0.8 * age, scale=1.4, cut=0.26 + 0.1 * age,
                                 anisotropy=0.3, soft=0.75, vary=0.7)
        for j in range(rng.randint(3, 5)):  # lumpy and irregular: a few overlapping soft blobs
            o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 1))) * sz * (0.5 + 0.4 * age)
            K.blob(layer, q + o, (sz * rng.uniform(0.6, 1.0), sz * rng.uniform(0.6, 0.9), sz * rng.uniform(0.5, 0.8)), puff, seed * 50 + k * 5 + j)
        if age < 0.18:  # fresh: the flash still in it
            K.blob(layer, q, (sz * 0.28,) * 3, K.fire_material("flak_core", strength=60.0, scale=1.8, cut=0.38), seed * 50 + k)
            K.point(q, (255, 170, 90), 5000 * sz, radius=sz * 0.25, layer=layer)


def tracer_stream(layer, a, b, seed, rounds=14):
    """One gun's burst: bright yellow-white tracer rounds evenly spaced along
    the line of fire toward an aircraft, tight, all going one way."""
    rng = random.Random(seed)
    a, b = Vector(a), Vector(b)
    d = b - a
    u = d.normalized()
    for k in range(rounds):
        f = (k + rng.uniform(0.3, 0.7)) / rounds * 0.92
        q = a + d * f + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * f * 0.8
        K.tracer(layer, q, q + u * 3.2, (255, 240, 196), width=0.14 * (1.1 - 0.4 * f), strength=60.0 * (1.1 - 0.5 * f))


def cloud(layer, pos, size, seed):
    """A towering fair-weather cumulus far off, as volume: a few big soft
    cores, built up with many small cauliflower puffs over the sunlit top
    and flanks, on a flat grey-blue base. A soft white glow stands in for
    the light scattered many times inside a real cloud; the sun still
    shades the form, with forward scattering for the bright rim."""
    rng = random.Random(seed)
    # a soft white glow stands in for the light scattered many times inside a real cloud
    core = K.volume_material(f"cloud_core_{seed}", (255, 255, 255), 0.35, (255, 252, 246), 0.55, scale=1.4, cut=0.28, anisotropy=0.45, soft=0.55, vary=0.3)
    puff = K.volume_material(f"cloud_puff_{seed}", (255, 255, 255), 0.5, (255, 252, 244), 0.7, scale=2.4, cut=0.32, anisotropy=0.45, soft=0.45, vary=0.4)
    base = K.volume_material(f"cloud_base_{seed}", (214, 220, 232), 0.45, (168, 182, 210), 0.32, scale=1.6, cut=0.28, anisotropy=0.2, soft=0.6)
    p = Vector(pos)
    tops = []
    for k in range(rng.randint(8, 12)):  # the big cores, heaped higher in the middle
        ox = rng.uniform(-1, 1) * size * 0.85
        heap = 1.0 - abs(ox) / size * 0.75
        oz = rng.uniform(0.1, 1.0) ** 1.1 * size * 0.75 * heap
        r = size * rng.uniform(0.26, 0.42) * (0.6 + 0.5 * heap)
        c = p + Vector((ox, rng.uniform(-0.35, 0.35) * size, oz + r * 0.55))
        K.blob(layer, c, (r, r * 0.9, r * 0.8), core, seed * 100 + k)
        tops.append((c, r))
    for k in range(rng.randint(45, 65)):  # cauliflower puffs over the top and flanks of the cores
        c, r = tops[rng.randrange(len(tops))]
        d = Vector((rng.uniform(-1, 1), rng.uniform(-0.7, 0.7), rng.uniform(-0.1, 1))).normalized()
        q = c + d * r * rng.uniform(0.7, 0.95)
        rr = r * rng.uniform(0.18, 0.38)
        K.blob(layer, q, (rr, rr * 0.95, rr * 0.9), puff, seed * 100 + 20 + k)
    for k in range(rng.randint(8, 12)):  # the flat base, in shade
        ox = rng.uniform(-0.85, 0.85) * size
        r = size * rng.uniform(0.25, 0.4)
        K.blob(layer, p + Vector((ox, rng.uniform(-0.3, 0.3) * size, r * 0.18)), (r * 1.5, r, r * 0.3), base, seed * 100 + 90 + k)


def launch_dust(layer, pos, size, seed):
    """The backblast at the launcher: tan dust billowing low and wide (the
    user's reference photos), lit warm on top and shaded below."""
    rng = random.Random(seed)
    p = Vector(pos)
    dust = K.volume_material("launch_dust", (206, 188, 160), 1.6, scale=1.8, cut=0.32, anisotropy=0.35, soft=0.45, vary=0.35)
    for k in range(16):
        a = rng.uniform(0, 2 * math.pi)
        r = size * rng.uniform(0.6, 2.4)
        s_ = size * rng.uniform(0.7, 1.4)
        K.blob(layer, p + Vector((math.cos(a) * r, math.sin(a) * r * 0.7, s_ * 0.45)), (s_ * 1.3, s_ * 1.1, s_ * 0.8), dust, seed + k)


# ---------------------------------------------------------------------------
# The scene
# ---------------------------------------------------------------------------

def build(scene, rough=True):
    L.CLAY_MODE = False
    K.GLOW_SCALE = 0.5
    K.TRAIL_MATS.clear()  # thick bright white smoke with soft grey shading
    K.TRAIL_MATS["fresh"] = K.volume_material("trail_fresh_ka3", (255, 255, 255), 6.0, (255, 252, 246), 1.8, scale=2.4, cut=0.26,
                                              anisotropy=0.5, soft=0.4, vary=0.3)
    K.TRAIL_MATS["mid"] = K.volume_material("trail_mid_ka3", (255, 255, 255), 4.0, (255, 252, 246), 1.2, scale=2.2, cut=0.3,
                                            anisotropy=0.5, soft=0.5, vary=0.35)
    K.TRAIL_MATS["old"] = K.volume_material("trail_old_ka3", (250, 250, 252), 2.0, (255, 252, 246), 0.7, scale=1.8, cut=0.34,
                                            anisotropy=0.45, soft=0.6, vary=0.45)
    K.CRATERS.clear()
    K.AVOID.clear()
    A.EDGES = ((32.0, "near"), (150.0, "mid"), (330.0, "far"))  # beyond: the far hills and the sky
    A.GROUND_MATERIAL = meadow_material
    A.SEA_FROM = 8000.0  # no sea
    land = L.green_land()

    def gz(x, y):
        return land.z(x, y) + K.crater_z(x, y)
    cam_z = land.z(0, 0) + CAM_H
    K.height = lambda x, y, amp=0.0, seed=0.0: gz(x, y)
    K.cam_rig(scene, cam_z, 0.05 + 0.9 * HORIZON, L.RENDER_LENS, y=0.0)
    K.sky(scene, elevation=SUN_EL, azimuth=SUN_AZ, strength=0.17, sun_size=0.6, sun_intensity=0.05)
    for n in scene.world.node_tree.nodes:  # a clearer, deeper blue overhead
        for attr, val in (("aerosol_density", 1.5), ("dust_density", 1.5), ("air_density", 1.6)):
            if hasattr(n, attr):
                setattr(n, attr, val)
    K.sun(SUN_EL, SUN_AZ, 11.0, (255, 224, 182), angle=0.2)  # warm key, hard shadows
    K.fill(0.45, (120, 155, 240), azimuth=SUN_AZ + 180, elevation=55.0, angle=70.0)  # cool blue in the shadows, low
    with A.Group(400):
        A.haze_box(0.00022)

    bombs = [] if STAGE < 2 else [(0.55, 120, 3.0, True), (0.28, 150, 2.6, False), (0.84, 140, 2.4, False), (0.68, 200, 3.4, True),
             (0.12, 170, 2.2, False), (0.4, 230, 2.8, False)]
    bombs = [(X(sx, y), y, sz, fresh) for sx, y, sz, fresh in bombs]
    for x, y, sz, _ in bombs:
        K.CRATERS.append((x, y, sz))
    rng = random.Random(31)
    for _ in range(6):  # old scorch marks from earlier raids
        y = rng.uniform(40, 200)
        K.CRATERS.append((X(rng.uniform(0.05, 0.95), y), y, rng.uniform(1.4, 2.4)))
    for _ in range(24 if STAGE >= 2 else 0):
        y = rng.uniform(60, 260)
        K.CRATERS.append((X(rng.uniform(-0.05, 1.05), y), y, rng.uniform(1.0, 2.4)))
    ground = {"sky": A.terrain(land, "sky", -620, 620, -10, 620, 3.0)}

    # --- the base, staggered in depth (fix 4): close and big, middle, far ---
    base = [("ord_vigil", 0.08, 30, 30, None),  # the foreground launcher (fix 5): up and left, its base on the band's edge
            ("ord_aegis", 0.25, 60, 20, None), ("ord_sanctum", 0.88, 64, -15, None),
            ("ord_providence", 0.5, 94, 200, {"hatch": (150, 0, 0)}),  # the hatch swung right back ("ord_lumen", 0.67, 86, -20, None),
            ("ord_aegis", 0.97, 112, -30, None), ("ord_phalanx", 0.13, 132, 0, None), ("ord_lumen", 0.05, 146, 30, None),
            ("ord_oracle", 0.76, 140, 30, None),
            ("ord_vigil", 0.6, 180, 0, None), ("ord_sanctum", 0.36, 212, 10, None), ("ord_citadel", 0.86, 206, 180, None),
            ("ord_watchtower", 0.99, 178, 0, None), ("ord_aegis", 0.22, 255, 20, None),
            ("ord_lumen", 0.36, 104, 10, None), ("ord_vigil", 0.75, 116, -10, None), ("ord_aegis", 0.03, 92, 30, None),
            ("ord_lumen", 0.9, 160, -30, None), ("ord_vigil", 0.44, 150, 0, None)]
    keep, rails, roots = [], {}, []
    for uid, sx, y, hd, pose in base:
        x = X(sx, y)
        with A.Group(y):
            roots.append(L.put(land, uid, x, y, hd, pose=pose))
        keep.append((x, y, 18))
        top = {"ord_aegis": 11.0, "ord_sanctum": 4.7, "ord_vigil": 4.0, "ord_providence": 6.0}.get(uid, 4.0)
        rails.setdefault(uid, []).append((x, y, gz(x, y) + top))
    with A.Group(100):
        mobile = L.scatter(land, ["ord_halo", "ord_lancer", "ord_halo"], (0.05, 0.95, 60, 160), 9, 10, 71, keep=keep, screen=True)
    for root in roots + [u["root"] for u in mobile]:
        with A.Group(root.location.y):
            A.contact_shadow(root, land)
    for u in mobile:  # track marks behind the vehicles
        with A.Group(u["y"]):
            A.track_marks(land, u["x"], u["y"], -math.degrees(u["root"].rotation_euler.z), 14, int(u["x"] * 7 + u["y"]))
    # worn paths between the buildings: the service road through the base and spurs to the launchers
    pos = {}
    for uid, sx, y, hd, pose in base:
        pos.setdefault(uid, []).append((X(sx, y), y))
    roads = [[(X(0.5, 14), 14), (X(0.47, 50), 50), pos["ord_providence"][0], (X(0.45, 150), 150), (X(0.42, 260), 260)],
             [(X(0.47, 50), 50), pos["ord_aegis"][0], (X(0.05, 70), 70)],
             [pos["ord_providence"][0], pos["ord_lumen"][0], pos["ord_sanctum"][0], (X(1.05, 70), 70)],
             [(X(0.45, 150), 150), pos["ord_phalanx"][0]],
             [(X(0.45, 150), 150), pos["ord_oracle"][0], pos["ord_citadel"][0]]]
    for i, road in enumerate(roads):
        y = sum(q[1] for q in road) / len(road)
        with A.Group(y):
            dirt_path("mid", gz, road, 7.0 if i == 0 else 4.5, 800 + i)

    # --- the Phalanx's shield over the left of the base (fix 4, the v4 look) ---
    ph = rails["ord_phalanx"][0]
    with A.Group(ph[1]):
        shield_v4("mid", (ph[0], ph[1], gz(ph[0], ph[1])), 38.0, (ph[0], ph[1], gz(ph[0], ph[1]) + 8.3), 2, 300)

    # --- the bombs falling on the base, smoke rising behind it ---
    for i, (x, y, sz, fresh) in enumerate(bombs):
        with A.Group(y):
            blast("mid", (x, y, gz(x, y)), sz, 700 + i * 13, fresh=fresh)
    if STAGE >= 2:
        for i, (sx, y, h, w) in enumerate(((0.9, 190, 44, 3.4), (0.99, 280, 56, 4.2), (0.38, 330, 40, 3.6))):
            with A.Group(y):
                smoke_pillar("mid", (X(sx, y), y, gz(X(sx, y), y)), h, w, 770 + i)

    # --- clouds far off: white tops, grey bases; the left of the sky and low near the horizon, clear of the
    # interceptor-to-nuke stretch and the close jet
    for i, (sx, sy, dist, size) in enumerate(((0.12, 0.3, 1600, 420), (0.34, 0.22, 1900, 340), (0.3, 0.46, 1400, 260),
                                             (0.02, 0.1, 1700, 300), (1.0, 0.46, 1500, 220),
                                             (0.88, 0.16, 1900, 320))):  # the middle cloud, now behind the nuke (the user)
        q = L.at_screen(sx, sy, dist, cam_z, HORIZON)
        with A.Group(dist):
            cloud("mid", q, size, 860 + i)

    # --- the story: the nuke (fix 1) and the interceptor ---
    # by frame position (the user, 2026-10-24): the nose at (0.80, 0.12), the hatch at (0.50, 0.57), the interceptor's
    # head two-thirds of the way along that line at (0.70, 0.27), pointing at the nose; the nuke diving at it
    nose = L.at_screen(0.8, 0.12, 260.0, cam_z, HORIZON)
    head = L.at_screen(0.7, 0.27, 215.0, cam_z, HORIZON)
    meet = head
    d = (head - nose).normalized()
    NUKE_LEN = (L.at_screen(0.66, 0.24, 200.0, cam_z, HORIZON) - L.at_screen(0.8, 0.15, 260.0, cam_z, HORIZON)).length / 1.1 * 0.5  # the size approved at first, then halved (the user)
    with A.Group(360):
        nuke("mid", nose, d, NUKE_LEN, 500)
    prov = Vector(rails["ord_providence"][0])
    with A.Group((prov.y + meet.y) / 2):
        interceptor("mid", prov + Vector((0, 0, 1.5)), head, nose, 520)
        # the launch: a flash in the open hatch and the backblast dust thrown low and wide
        K.blob_dir("mid", prov + Vector((0, 0, 2.5)), Vector((0, 0, 1)), 7.0, 1.8, K.fire_material("launch_fire", strength=70.0, scale=2.0, cut=0.28), 525)
        K.blob("mid", prov + Vector((0, 0, 3.0)), (2.6, 2.6, 2.2), K.fire_material("launch_burst", strength=40.0, scale=1.6, cut=0.34), 526)
        K.point(prov + Vector((0, 0, 6)), (255, 210, 160), 6e4, radius=1.0, layer="mid")
    with A.Group(prov.y):
        launch_dust("mid", (prov.x, prov.y, prov.z - 6), 4.0, 531)
        rollers = K.trail_mats()["mid"]  # the exhaust smoke rolling out low along the ground
        rr = random.Random(533)
        for k in range(14):
            a = rr.uniform(math.pi * 0.6, math.pi * 1.6)  # mostly to the left and toward the camera, downwind of the blast
            dist = rr.uniform(5, 16)
            s_ = rr.uniform(2.5, 4.5)
            q = Vector((prov.x + math.cos(a) * dist, prov.y + math.sin(a) * dist * 0.6, 0))
            q.z = gz(q.x, q.y) + s_ * 0.4
            K.blob("mid", q, (s_ * 1.6, s_ * 1.2, s_ * 0.7), rollers, 540 + k)
    bpy.context.view_layer.update()
    for name, q in (("nose", nose), ("meet", meet), ("interceptor", head), ("providence", prov)):
        c = world_to_camera_view(scene, scene.camera, Vector(q))
        print(f"[ka3] {name} at screen ({c.x:.2f}, {1 - c.y:.2f})")

    # --- the raid at every depth (fix 3), clear of the nuke's lane ---
    # a small V of bombers far back near the horizon, a Behemoth, a few fighters and gunships at mid distance
    # spread across the sky, the mass in the left half and farther back; only the Manticore close
    craft = [("chs_behemoth", 0.27, 0.36, 430, 205, 0, 0), ("chs_behemoth", 0.215, 0.35, 450, 205, 0, 0),
             ("chs_behemoth", 0.325, 0.35, 450, 205, 0, 0), ("chs_behemoth", 0.16, 0.34, 470, 205, 0, 0),
             ("chs_behemoth", 0.38, 0.34, 470, 205, 0, 0),
             ("chs_behemoth", 0.04, 0.12, 260, 170, 0, -12),  # clear of the dome's outline
             ("chs_harpy", 0.15, 0.11, 230, 120, 0, 30), ("chs_manticore", 0.36, 0.19, 210, 160, 0, -25),
             ("chs_harpy", 0.44, 0.06, 260, 215, 0, 20), ("chs_wraith", 0.05, 0.41, 240, 140, 0, 12),
             ("chs_wasp", 0.3, 0.44, 145, 110, 8, -8), ("chs_wasp", 0.43, 0.45, 170, 150, 8, 10),
             ("chs_wasp", 0.71, 0.42, 190, 235, 8, -12)]
    if STAGE < 2:  # a few fighters in the mid sky, at believable size next to the buildings
        craft = [("chs_harpy", 0.22, 0.24, 150, 120, 0, 30), ("chs_manticore", 0.36, 0.14, 190, 160, 0, -25),
                 ("chs_harpy", 0.12, 0.12, 210, 140, 0, 20)]
    AIR_SCALE = 2.0  # the game's aircraft read small next to the structures at the key art's distances
    air = []
    for uid, sx, sy, dist, hd, pitch, bank in craft:
        p = L.at_screen(sx, sy, dist, cam_z, HORIZON)
        with A.Group(p.y):
            K.place(uid, "mid", p.x, p.y, hd, z=p.z, tilt=(pitch, L.bank_to_cam(p.x, p.y, hd, bank) if bank else 0),
                    scale=1.0 if dist > 400 else AIR_SCALE)  # the mid-distance aircraft twice their size; the far formation as it is
        air.append((p, K.forward(hd) * 3.5))
    # the close Manticore (fix 2): 30% smaller and lower than in the layout, its nose toward the centre
    close = L.at_screen(0.86, 0.44, 48.0, cam_z, HORIZON)  # body about y 0.40-0.48, its nose clear of the interceptor-to-nuke line
    with A.Group(close.y) as jet_group:
        glow_was = K.GLOW_SCALE
        K.GLOW_SCALE = 3.0  # its amber glow reads at this size
        jet = K.hero_jet("mid", "chs_manticore", tuple(close), 292, -8, L.bank_to_cam(close.x, close.y, 292, 40), 540)
        K.GLOW_SCALE = glow_was
    bpy.context.view_layer.update()
    for o in jet_group.new:
        if o is not jet and o.parent is None and o.type != "LIGHT":
            mw = o.matrix_world.copy()
            o.parent = jet
            o.matrix_world = mw
    v = K.forward(292) * 0.5  # a little motion blur
    for frame, dd in ((0, -1), (1, 0), (2, 1)):
        jet.location = close + v * dd
        jet.keyframe_insert("location", frame=frame)
    scene.frame_set(1)
    bpy.context.view_layer.update()
    with A.Group(close.y):  # warm rim light along the wing edges, from the sun's side
        sun_dir = K.forward(SUN_AZ)
        A.rim_light([o for o in jet.children_recursive if o.type == "MESH"], close + sun_dir * 10 + Vector((0, 8, 6)), close, 30000, rgb=(255, 196, 140))
    info = {"hero": nose, "close": close, "land": land, "ground": ground}
    if STAGE < 2:
        with A.Group(20):
            K.grass_tufts("mid", (X(-0.05, 26), X(1.05, 26), 12, 26), 26, 910, length=0.8)
        A.layer_ground(land, info)
        return info
    # the hit Harpy spiralling down in black smoke
    hp = L.at_screen(0.22, 0.3, 190.0, cam_z, HORIZON)
    with A.Group(hp.y):
        L.put(land, "chs_harpy", hp.x, hp.y, 140, z=hp.z, wreck=True, tilt=(-40, 60))
        K.explosion("mid", tuple(hp), 1.6, smoke=0.6, debris=True, seed=560)
        soot = K.volume_material("spiral_soot", (34, 32, 30), 2.2, scale=2.0, cut=0.3)
        pts = [hp + Vector((math.cos(a) * 4, math.sin(a) * 4, 2.6 * a)) for a in [i * 0.5 for i in range(18)]]
        pts.reverse()
        K.trail("mid", [tuple(q) for q in pts], 0.9, seed=561, smoke=soot, flame=False)

    # --- the SAMs: vertical launches turning onto the raid ---
    # SAMs only where their trails keep off the dome and the nuke's lane: the launchers in the middle of the base
    # firing at the bomber formation and the fighters over the centre (rails: Vigil 0 fg, 1 at 0.6, 2 at 0.75, 3 at 0.44)
    # more SAMs at the planes (the user): from the middle of the base bending left at the fighters over the dome,
    # and slanted launches from the right at the gunship there; none through the dome or the nuke's lane
    sams = [("ord_vigil", 3, 7, 0.85, {"turn": 10, "tilt": 1.3}), ("ord_vigil", 3, 6, 0.75, {"turn": 9, "tilt": 1.3}),
            ("ord_vigil", 3, 8, 0.7, {"turn": 11, "tilt": 1.1}), ("ord_vigil", 2, 12, 0.85, {"turn": 14, "tilt": 1.2}),
            ("ord_sanctum", 0, 12, 0.6, {"turn": 14, "tilt": 1.2})]  # slanted from the rail: no upright column beside the interceptor
    def in_lane(pts):
        """Whether a path crosses the nuke's lane on screen: from the meeting point past the nose
        to the top right corner (fix 1: nothing crosses it)."""
        a = Vector((0.5, 0.36))  # from below the interceptor's head, past the meeting point
        v = Vector((1.05, -0.05)) - a
        for q in pts[3:]:  # the first steps off the rail are low, in front of everything
            c = world_to_camera_view(scene, scene.camera, Vector(q))
            rel = Vector((c.x, 1 - c.y)) - a
            if c.z > 0 and ((rel.dot(v) > 0 and abs(v.x * rel.y - v.y * rel.x) / v.length < 0.15) or (c.x > 0.54 and 1 - c.y < 0.26)):
                return True
            if c.z > 0 and c.x < 0.38 and 0.22 < 1 - c.y < 0.56:  # the shield dome stays clear too
                return True
        return False

    bpy.context.view_layer.update()
    for i, (uid, k, ci, cut, kw) in enumerate(sams):
        r_ = rails[uid][k]
        while cut > 0.2 and in_lane(K.sam_path(Vector(r_), air[ci][0], air[ci][1], 600 + i, cut=cut, **{"tilt": 0.15, **kw})[0]):
            cut -= 0.05  # freeze it earlier, below the lane
        if in_lane(K.sam_path(Vector(r_), air[ci][0], air[ci][1], 600 + i, cut=cut, **{"tilt": 0.15, **kw})[0]):
            print(f"[ka3] SAM {i} left out: it would cross the nuke's lane")
            continue
        with A.Group((r_[1] + air[ci][0].y) / 2):
            K.sam("mid", r_, air[ci], 600 + i, "ord_radar_sam" if uid != "ord_vigil" else "ord_ir_sam", "order", width=1.7, cut=cut, **{"tilt": 0.15, **kw})
    # the foreground Vigil's missile just off the rail (fix 5): the backblast low and to the side
    vg = Vector(rails["ord_vigil"][0])
    with A.Group(vg.y):
        # (no missile: this close to the camera any climb would cover the dome; the backblast says it fired)
        A.launch_cloud("mid", (vg.x + 1.5, vg.y + 1.0, vg.z - 3.4), 0.9, 641)
    rng = random.Random(680)
    gunships = [i for i, c in enumerate(craft) if c[0] == "chs_wasp"]
    for li, lx in enumerate(rails["ord_lumen"]):  # each flak tower: two streams at the gunships low over the base
        if world_to_camera_view(scene, scene.camera, Vector(lx)).x < 0.38:
            continue  # its streams would cross in front of the dome
        with A.Group(lx[1]):
            for k in range(2):
                tgt = air[gunships[(li + k) % len(gunships)]][0]
                lead = tgt + K.forward(craft[gunships[(li + k) % len(gunships)]][4]) * rng.uniform(4, 10)
                tracer_stream("mid", (lx[0], lx[1], lx[2] + 2.5), lead, 690 + li * 10 + k)
    clusters = [(0, 5, 60.0, 12), (5, 6, 34.0, 6), (6, 7, 28.0, 5), (7, 8, 26.0, 4), (9, 10, 26.0, 4)]  # (first craft, last, spread, puffs)
    for ci, (a_, b_, spread, n) in enumerate(clusters):
        centre = sum((air[i][0] for i in range(a_, b_)), Vector()) / (b_ - a_)
        if in_lane([centre]):
            continue
        with A.Group(centre.y):
            flak_cluster("mid", centre + Vector((0, 0, -4)), spread, n, 720 + ci * 40)

    # --- the foreground: calm grass and a few stones (the bottom band) ---
    with A.Group(20):
        for i, (sx, y, s_) in enumerate(((0.03, 18, 1.8), (0.62, 15, 1.0), (0.78, 20, 1.4), (0.97, 23, 2.0))):
            A.rock("mid", (X(sx, y), y, gz(X(sx, y), y) - 0.3), s_, 900 + i)
        K.grass_tufts("mid", (X(-0.05, 26), X(1.05, 26), 12, 26), 26, 910, length=0.8)

    A.layer_ground(land, info)
    return info


def hide_lights_from_camera():
    """Cycles draws a point light with a radius as a glowing ball; the glow
    comes from the emissive shapes, the lights only light the scene."""
    for o in bpy.data.objects:
        if o.type == "LIGHT" and o.data.type != "SUN":
            o.visible_camera = False


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    mode = args[0]
    global STAGE
    STAGE = int(args[args.index("--stage") + 1]) if "--stage" in args else 2
    samples = int(args[args.index("--samples") + 1]) if "--samples" in args else 48
    scene = K.setup(True)
    scene.view_settings.exposure = -0.45
    for look in ("AgX - Medium High Contrast", "AgX - Punchy"):  # more contrast
        try:
            scene.view_settings.look = look
            break
        except TypeError:
            continue
    scene.render.motion_blur_shutter = 0.4
    info = build(scene, rough=(mode == "light"))
    hide_lights_from_camera()
    os.makedirs(OUT, exist_ok=True)
    if mode in ("final", "test"):
        res = (2048, 1152) if mode == "final" else (1024, 576)
        only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
        A.render_final(scene, info, res, samples, os.path.join(OUT, mode), only)
        print(f"[ka3] {mode} -> {os.path.join(OUT, mode)}")
        return
    for name, g in info["ground"].items():
        g.hide_render = name != "sky"
    scene.render.resolution_x, scene.render.resolution_y = 1024, 576
    scene.render.resolution_percentage = 100
    scene.cycles.samples = samples
    scene.render.film_transparent = False
    raw = os.path.join(OUT, f"_{mode}_raw.png")
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    K.save(A.grade(K.load(raw)), os.path.join(OUT, f"{mode}.png"))
    os.remove(raw)
    print(f"[ka3] {mode} -> {os.path.join(OUT, mode + '.png')}")


if __name__ == "__main__":
    main()
