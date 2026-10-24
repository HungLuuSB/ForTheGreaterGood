"""Key art 1, "Commander's stand" (layout A, docs/art/keyart.md): the lit
scene. The units sit exactly where layout.py's option A put them (same
seeds); this file adds the materials, the dusk light, the haze, the sand
and the sea, and the effects.

    blender -b --factory-startup --python-exit-code 1 -P assets/keyart/ka1.py -- light [--samples N]

`light` is step 3 (the lighting pass): one render, low samples, the smoke
and fire as rough volumes. Writes assets/keyart/ka1/light.png.
"""

import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import keyart as K  # noqa: E402
import layout as L  # noqa: E402

OUT = os.path.join(HERE, "ka1")
HORIZON = 0.42  # visible frame, from the top: the Commander stays above the bottom text band
CAM_H = 9.0  # over the ground under the camera: low, but the armies sit below the horizon
SLOPE = 0.08  # the battlefield falls toward the beach, so the sea is a real band of the frame
WIND = Vector((0.55, 0.3, 0.0))  # smoke leans right and away


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

def sand_material(fade=None):
    """Desert sand: two tones in drifting patches, darker gravel flats, wind
    ripples (a bump), churned and burnt where the blasts were (the mesh's
    `scorch` attribute)."""
    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        coord = N("ShaderNodeTexCoord")

        def noise_tex(scale, detail=6.0, rough=0.55):
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

        col = ramp(noise_tex(0.02, 4).outputs["Fac"], [(0.3, (176, 150, 110)), (0.55, (198, 172, 128)), (0.75, (186, 160, 118))])
        grav = ramp(noise_tex(0.035, 5).outputs["Fac"], [(0.58, (0, 0, 0)), (0.68, (255, 255, 255))])
        gbw = N("ShaderNodeRGBToBW")
        Ln(grav, gbw.inputs["Color"])
        col = mix(col, ramp(noise_tex(1.5, 8).outputs["Fac"], [(0.35, (120, 104, 84)), (0.65, (150, 132, 104))]), gbw.outputs["Val"])
        attr = N("ShaderNodeAttribute")
        attr.attribute_name = "scorch"
        c1 = N("ShaderNodeMapRange")
        c1.inputs["From Min"].default_value, c1.inputs["From Max"].default_value = 0.05, 0.35
        Ln(attr.outputs["Fac"], c1.inputs["Value"])
        col = mix(col, ramp(noise_tex(0.8).outputs["Fac"], [(0.3, (110, 92, 70)), (0.7, (136, 114, 86))]), c1.outputs["Result"])
        c2 = N("ShaderNodeMapRange")
        c2.inputs["From Min"].default_value, c2.inputs["From Max"].default_value = 0.45, 0.9
        Ln(attr.outputs["Fac"], c2.inputs["Value"])
        col = mix(col, ramp(noise_tex(1.4).outputs["Fac"], [(0.3, (26, 22, 20)), (0.7, (48, 40, 34))]), c2.outputs["Result"])
        b = N("ShaderNodeBsdfPrincipled")
        Ln(col, b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.9
        # wind ripples: stretched bands, wavering
        mp = N("ShaderNodeMapping")
        mp.inputs["Rotation"].default_value = (0, 0, math.radians(25))
        Ln(coord.outputs["Object"], mp.inputs["Vector"])
        wave = N("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        K.set_in(wave, "Scale", 0.9)
        K.set_in(wave, "Distortion", 6.0)
        K.set_in(wave, "Detail", 2.0)
        Ln(mp.outputs["Vector"], wave.inputs["Vector"])
        b1 = N("ShaderNodeBump")
        K.set_in(b1, "Strength", 0.25)
        K.set_in(b1, "Distance", 0.08)
        Ln(wave.outputs["Fac"], b1.inputs["Height"])
        b2 = N("ShaderNodeBump")
        K.set_in(b2, "Strength", 0.4)
        K.set_in(b2, "Distance", 0.3)
        Ln(noise_tex(0.5, 8).outputs["Fac"], b2.inputs["Height"])
        Ln(b1.outputs["Normal"], b2.inputs["Normal"])
        Ln(b2.outputs["Normal"], b.inputs["Normal"])
        if fade:  # transparent past the layer's back edge, eased in over the fade band
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
    return K.material(f"sand_{fade}", build)


def sea_material():
    """Dark water, glossy enough to mirror the sun, the fires and the
    flashes, broken by two scales of waves."""
    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        b = N("ShaderNodeBsdfPrincipled")
        b.inputs["Base Color"].default_value = K.lib.srgb((20, 48, 60))
        b.inputs["Roughness"].default_value = 0.06
        coord = N("ShaderNodeTexCoord")
        mp = N("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0, 2.5, 1.0)
        Ln(coord.outputs["Object"], mp.inputs["Vector"])
        prev = None
        for scale, strength in ((0.12, 0.5), (0.9, 0.3), (4.0, 0.15)):
            t = N("ShaderNodeTexNoise")
            K.set_in(t, "Scale", scale)
            K.set_in(t, "Detail", 6.0)
            Ln(mp.outputs["Vector"], t.inputs["Vector"])
            bump = N("ShaderNodeBump")
            K.set_in(bump, "Strength", strength)
            Ln(t.outputs["Fac"], bump.inputs["Height"])
            if prev:
                Ln(prev.outputs["Normal"], bump.inputs["Normal"])
            prev = bump
        Ln(prev.outputs["Normal"], b.inputs["Normal"])
        Ln(b.outputs["BSDF"], out.inputs["Surface"])
    return K.material("ka1_sea", build)


def dry_grass_material():
    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        info = N("ShaderNodeHairInfo")
        r = N("ShaderNodeValToRGB")
        e = r.color_ramp.elements
        e[0].position, e[0].color = 0.0, K.lib.srgb((96, 80, 52))
        e[1].position, e[1].color = 1.0, K.lib.srgb((196, 170, 118))
        n = e.new(0.5)
        n.color = K.lib.srgb((150, 126, 82))
        Ln(info.outputs["Random"], r.inputs["Fac"])
        b = N("ShaderNodeBsdfPrincipled")
        Ln(r.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.6
        Ln(b.outputs["BSDF"], out.inputs["Surface"])
    return K.material("dry_grass", build)


def haze_box(density=0.00015):
    """The air: a homogeneous scattering volume over the battlefield, out to
    the horizon and 150 studs up. Forward scattering, so it glows toward
    the sun, thickens with distance and carries god rays through the
    smoke."""
    def build(nt, out):
        v = nt.nodes.new("ShaderNodeVolumePrincipled")
        v.inputs["Color"].default_value = K.lib.srgb((236, 224, 210))
        v.inputs["Density"].default_value = density
        v.inputs["Anisotropy"].default_value = 0.25
        nt.links.new(v.outputs["Volume"], out.inputs["Volume"])
    o = K.prim("cube", "mid", size=1.0, location=(0, 245 + 500, 75))  # from the sky layer's edge outward
    o.scale = (1800, 1000, 150)
    K.set_mat(o, K.material("haze", build))
    o.visible_shadow = False
    return o


# ---------------------------------------------------------------------------
# Terrain, foreground
# ---------------------------------------------------------------------------

def terrain(land, layer, x0, x1, y0, y1, step, fade=None, sea=True):
    """The land as one mesh with the sand material and the craters' scorch."""
    bm = bmesh.new()
    nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
    verts, scorch = [], []
    for j in range(ny):
        for i in range(nx):
            x, y = x0 + i * step, y0 + j * step
            verts.append(bm.verts.new((x, y, land.z(x, y) + K.crater_z(x, y))))
            scorch.append(K.scorch_at(x, y))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            bm.faces.new((verts[a], verts[a + 1], verts[a + nx + 1], verts[a + nx]))
    me = bpy.data.meshes.new("sand")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    at = me.attributes.new("scorch", "FLOAT", "POINT")
    at.data.foreach_set("value", scorch)
    o = bpy.data.objects.new("sand", me)
    me.materials.append(sand_material(fade))
    K.link(o, layer)
    if not sea:
        return o
    sea = bpy.data.meshes.new("sea")
    bm = bmesh.new()
    for v in ((-6000, 150, 0), (6000, 150, 0), (6000, 9000, 0), (-6000, 9000, 0)):
        bm.verts.new(v)
    bm.faces.new(bm.verts)
    bm.to_mesh(sea)
    bm.free()
    so = bpy.data.objects.new("sea", sea)
    sea.materials.append(sea_material())
    K.link(so, layer)
    return o


def rock(layer, pos, size, seed, squash=0.6):
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    off = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    for v in bm.verts:
        n = noise.fractal(v.co * 1.3 + off, 0.6, 2.0, 4)
        v.co *= 1.0 + 0.35 * n
        v.co.z *= squash
    me = bpy.data.meshes.new("rock")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new("rock", me)
    me.materials.append(K.solid("rock", (92, 80, 66), 0.85))
    K.link(o, layer)
    o.location = pos
    o.scale = (size * rng.uniform(0.8, 1.4), size * rng.uniform(0.7, 1.1), size)
    o.rotation_euler = Euler((0, 0, rng.uniform(0, 6.3)))
    return o


# ---------------------------------------------------------------------------
# Effects for the desert and the sea
# ---------------------------------------------------------------------------

def sand_blast(layer, pos, size, seed, fresh=False, smoke=1.0):
    """A blast in the desert: the explosion (core, fireball, soot, debris,
    light) plus sand thrown up in tall columns and a dust ring rolling out
    along the ground; `fresh` adds the white-hot core flash."""
    rng = random.Random(seed)
    p = Vector(pos)
    K.explosion(layer, tuple(p), size, smoke=smoke, seed=seed)
    sand = K.volume_material("sand_plume", (196, 170, 128), 1.6, scale=2.2, cut=0.34)
    for k in range(rng.randint(4, 7)):
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0))
        K.blob_dir(layer, p, d, size * rng.uniform(2.5, 4.5), size * rng.uniform(0.3, 0.5), sand, seed + 200 + k)
    ring = K.volume_material("dust_ring", (176, 152, 116), 0.9, scale=2.0, cut=0.38)
    n = 12
    for k in range(n):
        a = k / n * 2 * math.pi + rng.uniform(-0.1, 0.1)
        r = size * rng.uniform(2.2, 2.8)
        s = size * rng.uniform(0.5, 0.8)
        K.blob(layer, p + Vector((math.cos(a) * r, math.sin(a) * r, s * 0.35)), (s * 1.3, s, s * 0.55), ring, seed + 300 + k)
    if fresh:
        core = K.prim("ico_sphere", layer, subdivisions=2, radius=size * 0.35, location=p + Vector((0, 0, size * 0.6)))
        K.set_mat(core, K.emissive("blast_core", (255, 240, 210), 18.0))
        K.point(p + Vector((0, 0, size)), (255, 190, 120), 12000 * size, radius=size * 0.8, layer=layer)


def launch_cloud(layer, pos, width, seed):
    """The billow a SAM leaves at its launcher: wide, low, white."""
    rng = random.Random(seed)
    m = K.trail_mats()["mid"]
    p = Vector(pos)
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        r = width * rng.uniform(1.5, 3.0)
        K.blob(layer, p + Vector((math.cos(a) * r, math.sin(a) * r, width * rng.uniform(0.6, 1.6))),
               (width * rng.uniform(2.0, 3.0),) * 3, m, seed + k)


def wake(layer, pos, heading, length, seed):
    """A ship's wake: foam spreading in a V behind it, spray at the bow."""
    rng = random.Random(seed)
    foam = K.volume_material("foam", (236, 240, 244), 1.2, scale=2.4, cut=0.4)
    f = K.forward(heading)
    side = Vector((f.y, -f.x, 0))
    p = Vector(pos)
    for k in range(10):
        t = k / 9
        for sgn in (1, -1):
            q = p - f * (length * 0.45 + t * length * 1.6) + side * sgn * (2 + t * length * 0.35)
            s = 1.5 + t * 3.0
            K.blob(layer, (q.x, q.y, 0.2), (s * 1.6, s, 0.4), foam, seed + k * 2 + (sgn > 0))
    bow = p + f * length * 0.5
    K.blob(layer, (bow.x, bow.y, 1.2), (3.0, 3.0, 1.6), foam, seed + 99)


def broadside(layer, pos, heading, target, seed, guns=4, length=26.0):
    """Several guns flashing at once along the side facing the target, gun
    smoke rolling off, and shells on their arcs to the target."""
    rng = random.Random(seed)
    f = K.forward(heading)
    p = Vector(pos)
    tgt = Vector(target)
    smoke = K.volume_material("navalsmoke", (186, 180, 170), 0.6, scale=1.6, cut=0.4)
    for g in range(guns):
        along = (g / max(guns - 1, 1) - 0.5) * length * 0.7
        m = p + f * along + Vector((0, 0, rng.uniform(4.5, 6.5)))
        aim = tgt + Vector((rng.uniform(-14, 14), rng.uniform(-10, 10), 0))
        d = (aim - m)
        d.z = 0
        d = (d.normalized() + Vector((0, 0, 0.35))).normalized()
        K.flash(layer, m + d * 2.0, d, rng.uniform(3.0, 4.5), (255, 214, 150))
        for k in range(2):
            K.blob(layer, m + d * rng.uniform(4, 10) + Vector((0, 0, rng.uniform(0, 3))), (rng.uniform(3, 5),) * 3, smoke, seed + g * 5 + k)
        pts = K.arc(m, aim, rng.uniform(40, 80), 14)
        j = rng.randint(2, 11)
        K.shell(layer, pts[j], pts[j + 1], 0.5, (255, 214, 150), rng.uniform(0.6, 0.9), 50.0)


# ---------------------------------------------------------------------------
# Layers: every element is anchored at a distance and goes to one layer
# ---------------------------------------------------------------------------

EDGES = ((30.0, "near"), (135.0, "mid"), (245.0, "far"))  # forward distance (y) limits; beyond is "sky"
FADE = 14.0  # each layer's ground fades out over its last FADE studs


def layer_of(y):
    for edge, name in EDGES:
        if y < edge:
            return name
    return "sky"


class Group:
    """with Group(y): every object created inside goes to layer_of(y)."""

    def __init__(self, y):
        self.layer = layer_of(y)

    def __enter__(self):
        self.before = set(bpy.data.objects)
        return self

    def __exit__(self, *exc):
        self.new = set(bpy.data.objects) - self.before
        for o in self.new:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            K.coll(self.layer).objects.link(o)
        return False


# ---------------------------------------------------------------------------
# Unit dressing: contact shadows, track marks, the Commander's pose
# ---------------------------------------------------------------------------

def contact_shadow(root, land):
    """A soft dark pool under a ground unit, where the sky light can't reach."""
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in root.children_recursive if o.type == "MESH" for c in o.bound_box]
    if not pts:
        return
    x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        coord = N("ShaderNodeTexCoord")
        g = N("ShaderNodeTexGradient")
        g.gradient_type = "SPHERICAL"
        Ln(coord.outputs["Object"], g.inputs["Vector"])
        sq = N("ShaderNodeMath")
        sq.operation = "POWER"
        sq.inputs[1].default_value = 0.6
        Ln(g.outputs["Fac"], sq.inputs[0])
        k = N("ShaderNodeMath")
        k.operation = "MULTIPLY"
        k.inputs[1].default_value = 0.75
        Ln(sq.outputs["Value"], k.inputs[0])
        dark = N("ShaderNodeBsdfDiffuse")
        dark.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
        tr = N("ShaderNodeBsdfTransparent")
        mx = N("ShaderNodeMixShader")
        Ln(k.outputs["Value"], mx.inputs["Fac"])
        Ln(tr.outputs["BSDF"], mx.inputs[1])
        Ln(dark.outputs["BSDF"], mx.inputs[2])
        Ln(mx.outputs["Shader"], out.inputs["Surface"])
    o = K.prim("cylinder", "mid", vertices=24, radius=1.0, depth=0.02,
               location=(cx, cy, land.z(cx, cy) + K.crater_z(cx, cy) + 0.06))
    o.scale = ((x1 - x0) * 0.62, (y1 - y0) * 0.62, 1.0)
    K.set_mat(o, K.material("contact", build))
    o.visible_shadow = False


def track_marks(land, x, y, heading, length, seed):
    """Two dark churned tracks behind a vehicle, following the ground."""
    rng = random.Random(seed)
    f = K.forward(heading)
    side = Vector((f.y, -f.x, 0))
    mat = K.solid("tracks", (104, 86, 66), 0.95)
    for sgn in (1, -1):
        for k in range(int(length / 2)):
            c = Vector((x, y, 0)) - f * (4 + k * 2.0) + side * sgn * 2.2 + side * rng.uniform(-0.1, 0.1)
            o = K.prim("cube", "mid", size=1.0, location=(c.x, c.y, land.z(c.x, c.y) + K.crater_z(c.x, c.y) + 0.03))
            o.scale = (1.0, 2.1, 0.04)
            o.rotation_euler = Euler((0, 0, math.radians(-heading)))
            K.set_mat(o, mat)
            o.visible_shadow = False


# mid-stride (Blockouts/Pending/Registry.luau), firing as it walks
COMMANDER_POSE = {"base": (0, 0, 0, 0, -0.2, 0), "torso": (0, -6, 0), "thighL": (24, 0, 0), "shinL": (-8, 0, 0),
                  "footL": (-16, 0, 0), "thighR": (-18, 0, 0), "shinR": (-22, 0, 0), "footR": (30, 0, 0),
                  "armL": (-16, 0, 0), "armR": (6, 0, 0)}  # the weapon arm points forward at rest


def commander(land, x, y, heading):
    root = L.put(land, "ord_sovereign", x, y, heading, pose=COMMANDER_POSE)
    bpy.context.view_layer.update()
    arm = [o for o in root.children if o.name.startswith("forearmR")]
    aim = K.forward(heading)
    pts = [o.matrix_world @ v.co for o in arm for v in o.data.vertices]
    tip = max(pts, key=lambda q: q.dot(aim)) if pts else Vector((x, y, land.z(x, y) + 6))
    K.muzzle_flash("mid", tip, (aim + Vector((0, 0, 0.05))).normalized(), 1.5, (190, 240, 255), 950)
    return root


# ---------------------------------------------------------------------------
# The scene
# ---------------------------------------------------------------------------

SUN_AZ, SUN_EL = 26.0, 4.0  # low behind the Chaos side, right of centre
COAST = 232.0  # the shoreline's mean distance
HERO_Y, HERO_HILL = 36.0, 4.0  # the Commander on a dune crest: big against the sky, above the bottom text band


def X(sx, y):
    """The world x at forward distance y that sits at `sx` across the visible frame."""
    return (sx - 0.5) * 2 * L.TAN * y


def rim_light(target_objs, pos, aim, energy, size=6.0, rgb=(255, 186, 120)):
    """A warm area light behind a hero, linked to light only the hero
    (Cycles light linking): the sun's rim, strengthened on the focal units."""
    ld = bpy.data.lights.new("rim", "AREA")
    ld.energy = energy
    ld.size = size
    ld.color = K.lib.srgb(rgb)[:3]
    lo = bpy.data.objects.new("rim", ld)
    K.link(lo, "lights")
    lo.location = pos
    lo.rotation_euler = (Vector(aim) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    recv = bpy.data.collections.new(f"rim_receivers_{len(bpy.data.collections)}")
    for o in target_objs:
        recv.objects.link(o)
    lo.light_linking.receiver_collection = recv
    print(f"[ka1] rim light linked to {len(recv.objects)} objects", flush=True)
    return lo


def broadside_arcs(layer, pos, heading, target, seed, guns=4, length=26.0):
    """A ship's broadside: big flashes along the side, gun smoke, and the
    shells' arcs to the target drawn as faint glowing streaks with a hot
    head, landing near the beach."""
    rng = random.Random(seed)
    f = K.forward(heading)
    p = Vector(pos)
    tgt = Vector(target)
    smoke = K.volume_material("navalsmoke", (186, 180, 170), 0.6, scale=1.6, cut=0.36, soft=0.5, vary=0.4)
    for g in range(guns):
        along = (g / max(guns - 1, 1) - 0.5) * length * 0.7
        m = p + f * along + Vector((0, 0, rng.uniform(4.5, 6.5)))
        aim = tgt + Vector((rng.uniform(-18, 18), rng.uniform(-10, 10), 0))
        d = aim - m
        d.z = 0
        d = (d.normalized() + Vector((0, 0, 0.35))).normalized()
        K.flash(layer, m + d * 2.5, d, rng.uniform(6.0, 8.0), (255, 206, 140))
        for k in range(2):
            K.blob(layer, m + d * rng.uniform(5, 12) + Vector((0, 0, rng.uniform(0, 4))), (rng.uniform(4, 7),) * 3, smoke, seed + g * 5 + k)
        pts = [Vector(q) for q in K.arc(m, aim, rng.uniform(30, 60), 24)]
        j = rng.randint(6, 20)
        if g == 0:  # one faint streak per ship marks the arc
            for a, b in zip(pts[max(0, j - 6):j], pts[max(1, j - 5):j + 1]):
                K.tracer(layer, a, b, (255, 170, 90), width=0.18, strength=3.0)
        K.shell(layer, tuple(pts[j]), tuple(pts[j + 1]), 0.5, (255, 214, 150), 1.4, 60.0)


def build(scene, rough=True):
    L.CLAY_MODE = False
    K.GLOW_SCALE = 0.5
    K.CRATERS.clear()
    K.AVOID.clear()
    hx, hy = X(0.68, HERO_Y), HERO_Y

    def crest(x, y):  # the dune the Commander stands on
        return HERO_HILL * math.exp(-((x - hx) ** 2 + (y - hy) ** 2) / 10.0 ** 2)
    land = L.Land(lambda x, y: COAST + 12 * math.sin(x / 90) - y, extra=lambda x, y: SLOPE * max(0.0, COAST - y) + crest(x, y))

    def up(x, y, h):  # h studs over the slope (aircraft)
        return h + SLOPE * max(0.0, COAST - y)

    def gz(x, y):
        return land.z(x, y) + K.crater_z(x, y)
    cam_z = land.z(0, 0) + CAM_H
    K.height = lambda x, y, amp=0.0, seed=0.0: gz(x, y)  # the K effects sit on this land
    K.cam_rig(scene, cam_z, 0.05 + 0.9 * HORIZON, L.RENDER_LENS, y=0.0)
    # light: the low sun behind the Chaos side (rim light), the sky's cool soft light from above; no frontal fill
    K.sky(scene, elevation=SUN_EL, azimuth=SUN_AZ, strength=0.11, sun_size=0.8, sun_intensity=0.02)
    K.sun(SUN_EL, SUN_AZ, 3.0, (255, 170, 96), angle=1.0)
    K.fill(0.35, (120, 150, 215), azimuth=SUN_AZ + 180, elevation=70.0, angle=70.0)
    with Group(400):
        haze_box()

    # blasts (sx across the frame, y, size, fresh); one huge, the rest small to medium
    blasts = [(0.76, 176, 7.5, True), (0.46, 120, 2.6, False), (0.62, 96, 3.0, True), (0.26, 132, 3.4, True),
              (0.82, 128, 2.6, False), (0.55, 64, 1.6, False), (0.2, 46, 1.4, False), (0.84, 72, 2.0, False),
              (0.7, 110, 1.8, False), (0.06, 112, 2.2, False)]
    blasts = [(X(sx, y), y, sz, fresh) for sx, y, sz, fresh in blasts]
    beach_hits = [(X(sx, y), y, sz) for sx, y, sz in ((0.2, 210, 2.4), (0.43, 218, 2.0), (0.68, 208, 2.6), (0.84, 200, 2.2), (0.95, 214, 2.0))]
    for x, y, sz, _ in blasts:
        K.CRATERS.append((x, y, sz * 0.9))
    for x, y, sz in beach_hits:
        K.CRATERS.append((x, y, sz))
    rng = random.Random(77)
    for _ in range(45):
        y = rng.uniform(14, 220)
        K.CRATERS.append((X(rng.uniform(-0.05, 1.05), y), y, rng.uniform(1.2, 3.2)))
    ground = {"sky": terrain(land, "sky", -480, 480, -10, 270, 2.0)}  # the whole land and the sea, behind everything

    # --- Order pushing in from the left; the Commander at the front of the push ---
    hero = Vector((hx, hy, 0))
    with Group(hero.y):
        hero_root = commander(land, hero.x, hero.y, 92)
    heavies = [("ord_warden", 0.14, 66, 70), ("ord_seraph", 0.06, 50, 60), ("ord_vigil", 0.3, 96, 50), ("ord_phalanx", 0.17, 112, 0)]
    keep = [(hero.x, hero.y, 22)]
    for uid, sx, y, hd in heavies:
        with Group(y):
            L.put(land, uid, X(sx, y), y, hd)
        keep.append((X(sx, y), y, 14))
    keep += [(X(0.08, 24), 24, 10), (X(0.83, 26), 26, 10)]
    with Group(60):
        order = L.scatter(land, L.ORDER_TANKS, (0.02, 0.6, 40, 110), 10, 75, 1, keep=keep, screen=True)
    # --- Chaos holding the right, facing them ---
    cheavy = [("chs_cyclops", 0.64, 150, -110, False, (0, 0)), ("chs_thorn", 0.86, 128, -105, False, (0, 0)),
              ("chs_carapace", 0.57, 175, 0, False, (0, 0)), ("chs_hydra", 0.93, 150, -115, False, (0, 0)),
              ("chs_eye", 0.78, 104, 30, True, (0, 72))]  # the toppled radar
    keep = [(hero.x, hero.y, 20)]
    for uid, sx, y, hd, wreck, tilt in cheavy:
        with Group(y):
            L.put(land, uid, X(sx, y), y, hd, wreck=wreck, tilt=tilt)
        keep.append((X(sx, y), y, 14))
    keep.append((blasts[0][0], blasts[0][1], 10))
    with Group(100):
        chaos = L.scatter(land, L.CHAOS_TANKS, (0.74, 1.0, 44, 150), 11, -100, 2, keep=keep, screen=True)
    for u in order + chaos:  # contact shadows and tracks go with their unit
        with Group(u["y"]):
            contact_shadow(u["root"], land)
            track_marks(land, u["x"], u["y"], -math.degrees(u["root"].rotation_euler.z), 14, int(u["x"] * 13 + u["y"]))
    with Group(hero.y):
        contact_shadow(hero_root, land)
    for uid, sx, y, hd, tilt in (("chs_ravager", 0.08, 24, 210, (4, -8)), ("ord_lancer", 0.83, 26, 140, (-3, 5)),
                                 ("ord_bulwark", 0.14, 40, 30, (0, 0))):
        with Group(y):
            L.put(land, uid, X(sx, y), y, hd, wreck=True, tilt=tilt)

    # --- the fight on the ground ---
    with Group(80):
        K.firefight("mid", order, chaos, seed=700, shells=12, flashes=9, burning=3)
    for i, (x, y, sz, fresh) in enumerate(blasts):
        with Group(y):
            sand_blast("mid", (x, y, gz(x, y)), sz, 710 + i * 13, fresh=fresh, smoke=1.3 if sz > 5 else 1.0)
    for i, (sx, y, h, w) in enumerate(((0.78, 180, 50, 4.5), (0.21, 150, 34, 3.2), (0.87, 175, 28, 2.8), (0.47, 126, 22, 2.2),
                                       (0.85, 230, 40, 3.6))):
        with Group(y):
            K.smoke_column("mid", (X(sx, y), y, gz(X(sx, y), y)), h, w, 760 + i, drift=(WIND.x, WIND.y))
    for sx, y in ((0.08, 24), (0.83, 26)):  # the wrecks burning
        x = X(sx, y)
        with Group(y):
            K.explosion("mid", (x, y, gz(x, y) + 1.2), 1.3, smoke=0.7, debris=False, seed=int(x * 7 + y))
            K.smoke_column("mid", (x, y, gz(x, y) + 1.5), 14 + y * 0.3, 1.6, 780 + int(y), drift=(WIND.x, WIND.y))
    for y0, y1 in ((14, 30), (30, 135), (135, 230)):
        with Group((y0 + y1) / 2):
            K.battlefield_debris("mid", (X(-0.05, y1), X(1.05, y1), y0, y1), int((y1 - y0) * 0.8), seed=790 + y0)

    # --- the air ---
    close = L.at_screen(0.27, 0.3, 20.0, cam_z, HORIZON)
    with Group(close.y) as jet_group:
        jet = K.hero_jet("mid", "ord_falcon", tuple(close), 70, 6, L.bank_to_cam(close.x, close.y, 70, 40), 500)
    bpy.context.view_layer.update()
    for o in jet_group.new:  # the afterburner, vapour and missiles move with the jet (and blur with it)
        if o is not jet and o.parent is None and o.type != "LIGHT":
            mw = o.matrix_world.copy()
            o.parent = jet
            o.matrix_world = mw
    v = K.forward(70) * 0.2  # a little motion blur
    for frame, d in ((0, -1), (1, 0), (2, 1)):
        jet.location = close + v * d
        jet.keyframe_insert("location", frame=frame)
    scene.frame_set(1)
    craft = [("ord_falcon", 0.04, 62, 24, 75, 4, None), ("chs_harpy", 0.86, 120, 36, -100, 0, -30),
             ("chs_plague", 0.64, 200, 50, -110, 0, 0), ("chs_wasp", 0.88, 96, 15, -120, 8, 0),
             ("ord_guardian", 0.18, 58, 13, 70, 8, 0), ("ord_absolution", 0.2, 170, 52, 80, 0, 10)]
    air = []
    for uid, sx, y, z, hd, pitch, bank in craft:
        x = X(sx, y)
        z = up(x, y, z)
        if bank is None:
            bank = L.bank_to_cam(x, y, hd, 22)
        with Group(y):
            L.put(land, uid, x, y, hd, z=z, tilt=(pitch, bank))
        air.append((Vector((x, y, z)), K.forward(hd) * 3.5))

    def rail(sx, y):
        x = X(sx, y)
        return (x, y, gz(x, y) + 4)
    seraph, vigil, thorn = rail(0.06, 50), rail(0.3, 96), rail(0.86, 128)
    sams = [(seraph, air[1], 0.85, {"turn": 9}), (vigil, air[1], 0.7, {"turn": 13}),
            (seraph, air[2], 0.75, {"turn": 11}), (vigil, air[3], 0.6, {"turn": 14}),
            (thorn, air[0], 0.75, {"turn": 10}), (thorn, air[5], 0.5, {})]
    for i, (start, tgt, cut, kw) in enumerate(sams):
        team = "order" if start is not thorn else "chaos"
        with Group((start[1] + tgt[0].y) / 2):
            K.sam("mid", start, tgt, 600 + i, f"{'ord' if team == 'order' else 'chs'}_ir_sam", team, width=2.2, cut=cut, **kw)
    for i, start in enumerate((seraph, vigil, thorn)):
        with Group(start[1]):
            launch_cloud("mid", (start[0], start[1], start[2] - 2), 1.5, 650 + i)
    with Group(118):
        K.burst("mid", (X(0.8, 116), 116, up(X(0.8, 116), 116, 38)), 4.0, seed=660)  # a near miss on the Harpy
    with Group(140):
        kx = X(0.6, 140)
        K.kill("mid", vigil, ("chs_harpy", kx, 140, up(kx, 140, 34), -120, 0, 3.5), 670, "order", turn=11.0, tilt=0.9)

    # --- the navy: broadsides from just off the beach, shells landing on it ---
    ships = [("ord_dominion", 0.16, 252, 95), ("ord_crusader", 0.36, 262, 85), ("chs_kraken", 0.62, 254, -90),
             ("chs_corsair", 0.8, 266, -95), ("chs_kraken", 0.95, 250, -85)]
    ships = [(uid, X(sx, y), y, hd) for uid, sx, y, hd in ships]
    with Group(300):
        for uid, x, y, hd in ships:
            L.put(land, uid, x, y, hd, z=0.0)
        for i, (uid, x, y, hd) in enumerate(ships):
            wake("mid", (x, y, 0), hd, 30, 800 + i)
        broadside_arcs("mid", (ships[0][1], ships[0][2], 0), 95, (beach_hits[2][0], beach_hits[2][1], 0), 810, guns=4)
        broadside_arcs("mid", (ships[1][1], ships[1][2], 0), 85, (beach_hits[3][0], beach_hits[3][1], 0), 811, guns=4)
        broadside_arcs("mid", (ships[2][1], ships[2][2], 0), -90, (beach_hits[0][0], beach_hits[0][1], 0), 812, guns=3)
        broadside_arcs("mid", (ships[3][1], ships[3][2], 0), -95, (beach_hits[1][0], beach_hits[1][1], 0), 813, guns=3)
        bx, by = ships[4][1], ships[4][2]
        K.explosion("mid", (bx, by, 7), 4.0, smoke=1.4, debris=False, seed=820)  # the burning Kraken
        K.smoke_column("mid", (bx, by, 6), 46, 5.0, 821, drift=(WIND.x, WIND.y))
        for k in range(8):
            y = rng.uniform(234, 248)
            K.splash("mid", (X(rng.uniform(0.05, 0.95), y), y, 0), rng.uniform(2.5, 5.0), seed=830 + k)
    for i, (x, y, sz) in enumerate(beach_hits):  # shells landing on the beach
        with Group(y):
            sand_blast("mid", (x, y, gz(x, y)), sz, 860 + i * 7, smoke=0.8)

    # --- the foreground ---
    with Group(20):
        for i, (sx, y, s_) in enumerate(((0.02, 22, 1.8), (0.16, 19, 1.0), (0.62, 18, 1.4), (0.95, 22, 2.2), (0.3, 26, 1.2), (0.45, 17, 0.8))):
            rock("mid", (X(sx, y), y, gz(X(sx, y), y) - 0.2), s_, 900 + i)
        tufts = K.grass_tufts("mid", (X(-0.05, 27), X(1.05, 27), 15, 27), 30, 910, length=1.2)
        tufts.data.materials[1] = dry_grass_material()
        K.ember_field("mid", (X(0, 29), X(1, 29), 16, 29, 0, 10), 120, 920)
    with Group(60):
        K.ember_field("mid", (X(0, 130), X(1, 130), 30, 130, 0, 20), 160, 921)

    # --- rim light on the two heroes ---
    bpy.context.view_layer.update()
    jet_meshes = [o for o in jet.children_recursive if o.type == "MESH"]
    hero_meshes = [o for o in hero_root.children_recursive if o.type == "MESH"]
    sun_dir = K.forward(SUN_AZ)
    with Group(close.y):
        behind = (close - scene.camera.location).normalized()  # straight behind it from the camera: edges catch the light
        rim_light(jet_meshes, close + behind * 12 + sun_dir * 4 + Vector((0, 0, 5)), close, 40000)
    hz = gz(hero.x, hero.y)
    with Group(hero.y):
        rim_light(hero_meshes, hero + Vector((0, 0, hz + 6)) + sun_dir * 16 + Vector((0, 0, 4)), hero + Vector((0, 0, hz + 5)), 30000, size=8)
    info = {"hero": hero, "close": close, "land": land, "ground": ground}
    layer_ground(land, info)
    return info


def grade(arr):
    """The film look: a soft shoulder on the highlights (nothing clips to a
    flat white blob), then a light bloom on what is still bright."""
    rgb, a = arr[..., :3], arr[..., 3:4]
    knee = 0.72
    over = np.clip(rgb - knee, 0, None)
    rgb = np.where(rgb > knee, knee + over / (1.0 + over / 0.22), rgb)
    h = arr.shape[0]
    bright = np.clip(rgb.max(axis=2, keepdims=True) - 0.82, 0, None) * 4.0
    glow = K.blur(rgb * bright, max(2, h // 160))
    rgb = rgb + glow * 0.15
    return np.concatenate([np.clip(rgb, 0, 1), a], axis=2)


def grade_layer(arr, opaque):
    """grade() for one layer: the same highlight shoulder, then bloom from
    the premultiplied colour so a glow can spill past an object's edge as
    soft alpha (straight alpha out, no dark halos)."""
    rgb, a = arr[..., :3], arr[..., 3:4]
    knee = 0.72
    over = np.clip(rgb - knee, 0, None)
    rgb = np.where(rgb > knee, knee + over / (1.0 + over / 0.22), rgb)
    prem = rgb * a
    h = arr.shape[0]
    bright = np.clip(prem.max(axis=2, keepdims=True) - 0.82, 0, None) * 4.0
    glow = K.blur(prem * bright, max(2, h // 160))
    prem = prem + glow * 0.15
    a2 = np.ones_like(a) if opaque else np.clip(np.maximum(a, glow.max(axis=2, keepdims=True)), 0, 1)
    straight = np.where(a2 > 1e-4, prem / np.maximum(a2, 1e-4), 0)
    return np.concatenate([np.clip(straight, 0, 1), a2], axis=2).astype(np.float32)


def over(stack, layer):
    a = layer[..., 3:4]
    return layer[..., :3] * a + stack * (1 - a)


def half(arr):
    h, w = arr.shape[:2]
    return arr.reshape(h // 2, 2, w // 2, 2, arr.shape[2]).mean(axis=(1, 3))


def shift(arr, dx, dy):
    """Moves a layer by whole pixels (rows run bottom-up), repeating the
    edge pixels into the uncovered strip (the bleed is wider than any shift)."""
    h, w = arr.shape[:2]
    ys = np.clip(np.arange(h) + dy, 0, h - 1)
    xs = np.clip(np.arange(w) - dx, 0, w - 1)
    return arr[ys][:, xs]


def visible(arr):
    """The middle 90%: what the viewer shows at rest."""
    h, w = arr.shape[:2]
    return arr[int(h * 0.05):h - int(h * 0.05), int(w * 0.05):w - int(w * 0.05)]


def opaque_png(rgb):
    return np.concatenate([rgb, np.ones(rgb.shape[:2] + (1,), dtype=np.float32)], axis=2)


def layer_ground(land, info):
    """Each layer's own ground: the same terrain and material from in front
    of the camera to the layer's back edge, fading out over the last FADE
    studs where the next layer's ground (identical) carries on."""
    for edge, name in EDGES:
        reach = L.TAN * edge * 1.25 + 30
        o = terrain(land, name, -reach, reach, -10, edge, 2.0, fade=(edge - FADE, edge), sea=False)
        info["ground"][name] = o


LUT_N = 33
LUT_LO, LUT_HI = -12.0, 7.0  # log2 range of linear values the table covers


def view_lut(scene, out):
    """The scene's view transform (AgX, its look and exposure) sampled into
    a 3D table: a grid of linear colours saved through Blender's own colour
    management. Lets the layers be converted from straight linear colour,
    so thin smoke isn't brightened the way premultiplied colour is."""
    n = LUT_N
    v = 2.0 ** np.linspace(LUT_LO, LUT_HI, n)
    b, g, r = np.meshgrid(v, v, v, indexing="ij")  # r varies fastest
    px = np.stack([r.ravel(), g.ravel(), b.ravel(), np.ones(n ** 3)], axis=1).astype(np.float32)
    img = bpy.data.images.new("lut_in", n ** 3, 1, alpha=True, float_buffer=True)
    img.pixels.foreach_set(px.ravel())
    s = scene.render.image_settings
    keep = (s.file_format, s.color_mode, s.color_depth)
    s.file_format, s.color_mode, s.color_depth = "PNG", "RGB", "16"
    path = os.path.join(out, "_lut.png")
    img.save_render(path, scene=scene)
    s.file_format, s.color_mode, s.color_depth = keep
    bpy.data.images.remove(img)
    res = K.load(path)[0, :, :3]
    os.remove(path)
    return res.reshape(n, n, n, 3)  # [b, g, r]


def apply_lut(lut, rgb):
    n = LUT_N
    t = (np.log2(np.maximum(rgb, 2.0 ** LUT_LO)) - LUT_LO) / (LUT_HI - LUT_LO) * (n - 1)
    t = np.clip(t, 0, n - 1 - 1e-6)
    i = np.floor(t).astype(np.int32)
    f = (t - i).astype(np.float32)
    out = np.zeros(rgb.shape[:-1] + (3,), dtype=np.float32)
    for db in (0, 1):
        for dg in (0, 1):
            for dr in (0, 1):
                w = (f[..., 2] if db else 1 - f[..., 2]) * (f[..., 1] if dg else 1 - f[..., 1]) * (f[..., 0] if dr else 1 - f[..., 0])
                out += w[..., None] * lut[i[..., 2] + db, i[..., 1] + dg, i[..., 0] + dr]
    return out


def to_display(lut, prem):
    """Linear premultiplied RGBA (an EXR layer) to display-space straight RGBA."""
    a = prem[..., 3:4]
    straight = np.where(a > 1e-5, prem[..., :3] / np.maximum(a, 1e-5), 0)
    return np.concatenate([apply_lut(lut, straight), a], axis=2).astype(np.float32)


def over_linear(stack, prem):
    return prem[..., :3] + stack * (1 - prem[..., 3:4])


def solve_alpha(layer, back, target, alpha):
    """The opacity that makes a display-space "over" of `layer` (straight
    display colour) on `back` give `target`, the display of the true linear
    blend. Keeps the layer's own colour, so it still looks right when the
    layers shift apart; only translucent pixels (thin smoke, glows) change."""
    d = layer - back
    num = (d * (target - back)).sum(axis=2, keepdims=True)
    den = (d * d).sum(axis=2, keepdims=True)
    solved = np.clip(np.where(den > 4e-4, num / np.maximum(den, 1e-6), alpha), 0, 1)
    keep = (alpha < 1e-3) | (alpha > 0.999)
    return np.where(keep, alpha, solved).astype(np.float32)


def render_final(scene, info, res, samples, out, only=None):
    """The four layers from one camera: for each, only that layer's objects
    are visible to the camera, everything else still casts light, shadow
    and reflections, and only that layer's ground is on (the copies would
    shadow each other). Rendered linear (EXR), converted to display through
    the scene's own view transform from straight colour, graded, tiled,
    composited; then checked against a single render and shifted for the
    parallax frames."""
    os.makedirs(out, exist_ok=True)
    w, h = res
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.cycles.samples = samples
    lut = view_lut(scene, out)
    s = scene.render.image_settings
    s.file_format, s.color_mode, s.color_depth, s.exr_codec = "OPEN_EXR", "RGBA", "32", "ZIP"
    members = {name: set(K.coll(name).all_objects) for name in K.LAYERS}
    cam = scene.camera
    hero = Vector(info["hero"])
    cam.data.dof.focus_distance = (Vector(info["close"]) - cam.location).length  # the close jet sharp, the nearer rocks and grass soft
    cam.data.dof.aperture_fstop = 1.6
    grounds = info["ground"]

    cache = os.path.join(out, "linear")
    os.makedirs(cache, exist_ok=True)

    def render(name):
        """A layer's linear render, kept in out/linear/ so a later run can
        re-render only some layers (`--only near`)."""
        raw = os.path.join(cache, f"{name}.exr")
        if not (only and name not in only and os.path.isfile(raw)):
            scene.render.filepath = raw
            bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(raw, check_existing=False)
        iw, ih = img.size
        arr = np.empty(iw * ih * 4, dtype=np.float32)
        img.pixels.foreach_get(arr)
        bpy.data.images.remove(img)
        return arr.reshape(ih, iw, 4)  # linear, premultiplied

    linear, layers = {}, {}
    back_lin = None
    for name in K.LAYERS:
        for o in scene.objects:
            if o.type in ("LIGHT", "CAMERA"):
                continue
            o.visible_camera = o in members[name]
        for gname, g in grounds.items():
            g.hide_render = gname != name
        scene.render.film_transparent = name != "sky"
        cam.data.dof.use_dof = name == "near"
        scene.render.use_motion_blur = name == "near"
        linear[name] = render(name)
        disp = to_display(lut, linear[name])
        if back_lin is not None:  # match the true blend over what lies behind this layer at rest
            front_lin = over_linear(back_lin, linear[name])
            disp[..., 3:4] = solve_alpha(disp[..., :3], apply_lut(lut, back_lin), apply_lut(lut, front_lin), disp[..., 3:4])
            back_lin = front_lin
        else:
            back_lin = linear[name][..., :3]
        layers[name] = grade_layer(disp, opaque=(name == "sky"))
        K.save(layers[name], os.path.join(out, f"{name}.png"))
        for r in range(2):
            for c in range(2):  # tiles row by row from the top left (pixel rows run bottom-up)
                K.save(layers[name][(1 - r) * h // 2:(2 - r) * h // 2, c * w // 2:(c + 1) * w // 2],
                       os.path.join(out, f"{name}_{r}{c}.png"))
        print(f"[ka1] layer {name} rendered", flush=True)
    stack = layers["sky"][..., :3]
    for name in K.LAYERS[1:]:
        stack = over(stack, layers[name])
    K.save(opaque_png(stack), os.path.join(out, f"composite_{w}.png"))
    K.save(opaque_png(half(stack)), os.path.join(out, f"composite_{w // 2}.png"))
    # the same scene as one render (no depth of field or motion blur, which only the foreground layer has)
    for o in scene.objects:
        if o.type in ("LIGHT", "CAMERA"):
            continue
        o.visible_camera = True
    for gname, g in grounds.items():
        g.hide_render = gname != "sky"
    scene.render.film_transparent = False
    cam.data.dof.use_dof = False
    scene.render.use_motion_blur = False
    scene.render.resolution_x, scene.render.resolution_y = w // 2, h // 2
    single_lin = render("single")[..., :3]
    single = grade_layer(to_display(lut, np.concatenate([single_lin, np.ones(single_lin.shape[:2] + (1,), np.float32)], 2)), True)[..., :3]
    lin = linear["sky"][..., :3]
    for name in K.LAYERS[1:]:
        lin = over_linear(lin, linear[name])
    lin_disp = grade_layer(to_display(lut, np.concatenate([half(lin), np.ones((h // 2, w // 2, 1), np.float32)], 2)), True)[..., :3]
    comp = half(stack)
    for label, a in (("layer split (linear composite)", lin_disp), ("as the viewer shows it (display composite)", comp)):
        diff = np.abs(K.blur(a, 2) - K.blur(single, 2)).mean(axis=2)
        print(f"[ka1] single render vs {label}, blurred 2 px: mean {diff.mean():.4f}, p99 {np.percentile(diff, 99):.4f}", flush=True)
    diff = np.abs(K.blur(comp, 2) - K.blur(single, 2)).mean(axis=2)
    K.save(opaque_png(np.concatenate([single, comp, np.repeat(np.clip(diff * 4, 0, 1)[..., None], 3, axis=2)], axis=1)),
           os.path.join(out, "check_single_vs_composite.png"))
    # parallax: each layer moves mouse x 2.5% of the width x its depth
    depth = {"sky": 0.08, "far": 0.3, "mid": 0.6, "near": 1.0}
    frames = []
    for mx, my in ((-1, 0), (0, 0), (1, 0), (0, -1), (0, 1)):
        st = shift(layers["sky"], round(mx * 0.025 * w * depth["sky"]), round(my * 0.025 * w * depth["sky"]))[..., :3]
        for name in K.LAYERS[1:]:
            st = over(st, shift(layers[name], round(mx * 0.025 * w * depth[name]), round(my * 0.025 * w * depth[name])))
        frame = visible(st)
        frame = half(frame) if w > 1024 else frame
        K.save(opaque_png(frame), os.path.join(out, f"parallax_{mx:+d}_{my:+d}.png"))
        frames.append(frame)
    K.save(opaque_png(np.concatenate(frames[:3], axis=1)), os.path.join(out, "parallax_strip.png"))


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    mode = args[0]
    samples = int(args[args.index("--samples") + 1]) if "--samples" in args else 48
    scene = K.setup(True)
    scene.view_settings.exposure = -0.6
    scene.render.motion_blur_shutter = 0.4
    info = build(scene, rough=(mode == "light"))
    os.makedirs(OUT, exist_ok=True)
    if mode in ("final", "test"):
        res = (2048, 1152) if mode == "final" else (1024, 576)
        only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
        render_final(scene, info, res, samples, os.path.join(OUT, mode), only)
        print(f"[ka1] {mode} -> {os.path.join(OUT, mode)}")
        return
    for name, g in info["ground"].items():  # one render: only the full ground
        g.hide_render = name != "sky"
    scene.render.resolution_x, scene.render.resolution_y = 1024, 576
    scene.render.resolution_percentage = 100
    scene.cycles.samples = samples
    scene.render.film_transparent = False
    raw = os.path.join(OUT, f"_{mode}_raw.png")
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    K.save(grade(K.load(raw)), os.path.join(OUT, f"{mode}.png"))
    os.remove(raw)
    print(f"[ka1] {mode} -> {os.path.join(OUT, mode + '.png')}")


if __name__ == "__main__":
    main()
