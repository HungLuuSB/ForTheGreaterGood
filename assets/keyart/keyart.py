"""Key art with parallax layers (docs/contracts/key-art.md on m-lobby, L-13):
three scenes built from the game's own meshes, rendered as four layers
(sky, far, mid, near) from one camera, 2048 x 1152 with 5% bleed, cut into
2 x 2 tiles of 1024 x 576.

    blender -b --factory-startup --python-exit-code 1 -P assets/keyart/keyart.py -- <scene> [--preview] [--layers sky,far]

Writes assets/keyart/<scene>/<layer>.png, the tiles <layer>_<row><col>.png
and a flattened review image composite.jpg. Everything is original: the
game's meshes and procedural terrain, sky, smoke and fire.
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
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "assets", "models", "tools"))
import lib  # noqa: E402
import unit  # noqa: E402

W, H = 2048, 1152
LAYERS = ["sky", "far", "mid", "near"]
GLOW_SCALE = 1.0  # multiplies the faction glow parts' emission
TEAM = {"order": (64, 132, 230), "chaos": (222, 70, 62)}
FACTION = {"ord": "order", "chs": "chaos"}


# ---------------------------------------------------------------------------
# Scene plumbing
# ---------------------------------------------------------------------------

def setup(preview):
    lib.reset_scene()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = t
            prefs.get_devices()
            for d in prefs.devices:
                d.use = d.type == t
            scene.cycles.device = "GPU"
            break
        except Exception:
            continue
    scene.cycles.samples = 48 if preview else 160
    scene.cycles.use_denoising = True
    scene.cycles.volume_bounces = 1
    scene.cycles.volume_biased = True
    scene.cycles.volume_max_steps = 256
    scene.cycles.max_bounces = 6
    scene.cycles.volume_step_rate = 2.0 if preview else 1.0
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.resolution_percentage = 50 if preview else 100
    scene.view_settings.exposure = -0.2
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        scene.view_settings.view_transform = "Filmic"
    s = scene.render.image_settings
    s.file_format, s.color_mode, s.color_depth = "PNG", "RGBA", "16"
    for name in LAYERS + ["lights"]:
        c = bpy.data.collections.new(name)
        scene.collection.children.link(c)
    return scene


def coll(name):
    return bpy.data.collections[name]


def link(obj, layer):
    coll(layer).objects.link(obj)
    return obj


def material(name, build):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    build(nt, out)
    return m


def set_in(node, key, value):
    if key in node.inputs:
        node.inputs[key].default_value = value


# ---------------------------------------------------------------------------
# Units from the game's meshes
# ---------------------------------------------------------------------------

_imgs = {}


def unit_images(uid, wreck):
    key = (uid, wreck)
    if key in _imgs:
        return _imgs[key]
    exp = os.path.join(ROOT, "assets", "models", uid, "export_wreck" if wreck else "export")
    name = f"{uid}_wreck" if wreck else uid
    imgs = {}
    for k, f in {"ALB": f"{name}_bar_ALB.png", "RGH": f"{name}_bar_RGH.png", "NOR": f"{name}_NOR.png",
                 "MTL": f"{name}_MTL.png", "EMI": f"{name}_EMI.png"}.items():
        img = bpy.data.images.load(os.path.join(exp, f), check_existing=True)
        if k != "ALB":
            img.colorspace_settings.name = "Non-Color"
        imgs[k] = img
    _imgs[key] = imgs
    return imgs


def place(uid, layer, x, y, heading=0.0, z=0.0, wreck=False, tilt=(0.0, 0.0), scale=1.0, glow=1.0):
    """Imports a unit (Blender space: forward +Y, up +Z, 1 unit = 1 stud) and
    places it at (x, y, z), turned `heading` degrees (0 faces +Y, away from
    the camera; 180 faces the camera)."""
    faction = FACTION[uid[:3]]
    exp = os.path.join(ROOT, "assets", "models", uid, "export_wreck" if wreck else "export")
    fbx = os.path.join(exp, f"{uid}_wreck.fbx" if wreck else f"{uid}.fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    objs = [o for o in bpy.data.objects if o not in before]
    imgs = unit_images(uid, wreck)
    glows = unit.FACTIONS[faction]["glow"]
    team = None if wreck else TEAM[faction]
    base = lib.textured_material(f"u_{uid}_{wreck}", imgs, team, None)
    root = bpy.data.objects.new(f"{uid}_root", None)
    link(root, layer)
    for o in objs:
        for c in o.users_collection:
            c.objects.unlink(o)
        if o.type != "MESH" or o.name.startswith(("emissive_probe", "tex_")):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        link(o, layer)
        if "_glow_" in o.name:
            channel = o.name.split("_glow_")[1].split("_")[0].split(".")[0]
            rgb = glows.get(channel, (220, 220, 220))
            m = lib.textured_material(f"g_{uid}_{channel}", imgs, None, rgb)
            lib.assign_single_material([o], m)
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Emission Strength"].default_value *= 2.2 * glow * GLOW_SCALE
        else:
            lib.assign_single_material([o], base)
        o.parent = root
    root.location = (x, y, z)
    root.rotation_euler = Euler((math.radians(tilt[0]), math.radians(tilt[1]), math.radians(-heading)))
    root.scale = (scale, scale, scale)
    return root


# ---------------------------------------------------------------------------
# Terrain, sea, sky
# ---------------------------------------------------------------------------

def sea(layer, y0, color=(18, 40, 52), y1=None):
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        bsdf = N("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = lib.srgb(color)
        bsdf.inputs["Roughness"].default_value = 0.08
        set_in(bsdf, "Specular IOR Level", 0.6)
        tex = N("ShaderNodeTexNoise")
        set_in(tex, "Scale", 0.35)
        set_in(tex, "Detail", 10.0)
        mapping = N("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0, 3.0, 1.0)
        coord = N("ShaderNodeTexCoord")
        L(coord.outputs["Object"], mapping.inputs["Vector"])
        L(mapping.outputs["Vector"], tex.inputs["Vector"])
        bump = N("ShaderNodeBump")
        set_in(bump, "Strength", 0.45)
        L(tex.outputs["Fac"], bump.inputs["Height"])
        chop = N("ShaderNodeTexNoise")
        set_in(chop, "Scale", 2.5)
        set_in(chop, "Detail", 8.0)
        L(mapping.outputs["Vector"], chop.inputs["Vector"])
        bump2 = N("ShaderNodeBump")
        set_in(bump2, "Strength", 0.3)
        L(chop.outputs["Fac"], bump2.inputs["Height"])
        L(bump.outputs["Normal"], bump2.inputs["Normal"])
        L(bump2.outputs["Normal"], bsdf.inputs["Normal"])
        # whitecaps where the two noises peak together
        caps = N("ShaderNodeMath")
        caps.operation = "MULTIPLY"
        L(tex.outputs["Fac"], caps.inputs[0])
        L(chop.outputs["Fac"], caps.inputs[1])
        cr = N("ShaderNodeMapRange")
        cr.inputs["From Min"].default_value = 0.36
        cr.inputs["From Max"].default_value = 0.44
        L(caps.outputs["Value"], cr.inputs["Value"])
        foam = N("ShaderNodeMix")
        foam.data_type = "RGBA"
        L(cr.outputs["Result"], foam.inputs["Factor"])
        foam.inputs["A"].default_value = lib.srgb(color)
        foam.inputs["B"].default_value = (0.85, 0.88, 0.9, 1)
        L(foam.outputs["Result"], bsdf.inputs["Base Color"])
        rough = N("ShaderNodeMapRange")
        rough.inputs["To Min"].default_value = 0.16
        rough.inputs["To Max"].default_value = 0.7
        L(cr.outputs["Result"], rough.inputs["Value"])
        L(rough.outputs["Result"], bsdf.inputs["Roughness"])
        L(bsdf.outputs["BSDF"], out.inputs["Surface"])
    me = bpy.data.meshes.new("sea")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0)
    for v in bm.verts:
        v.co = Vector(((v.co.x) * 6000.0, y0 + (v.co.y + 1.0) * ((y1 - y0) / 2 if y1 else 3000.0), -0.6))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("sea", me)
    me.materials.append(material(f"sea_{color}", build))
    return link(o, layer)


def sky(scene, elevation, azimuth, strength=1.0, night=False, dusty=False, sun_size=2.0, sun_intensity=0.6):
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    if night:
        grad = nt.nodes.new("ShaderNodeTexGradient")
        coord = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(coord.outputs["Generated"], sep.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
        ramp.color_ramp.elements[0].position = 0.48
        ramp.color_ramp.elements[0].color = lib.srgb((40, 46, 64))
        ramp.color_ramp.elements[1].position = 0.62
        ramp.color_ramp.elements[1].color = lib.srgb((6, 8, 16))
        # stars: tiny bright voronoi cells above the horizon
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = 700.0
        nt.links.new(coord.outputs["Generated"], vor.inputs["Vector"])
        st = nt.nodes.new("ShaderNodeMapRange")
        st.inputs["From Min"].default_value = 0.06
        st.inputs["From Max"].default_value = 0.0
        st.inputs["To Max"].default_value = 3.0
        nt.links.new(vor.outputs["Distance"], st.inputs["Value"])
        above = nt.nodes.new("ShaderNodeMapRange")
        above.inputs["From Min"].default_value = 0.52
        above.inputs["From Max"].default_value = 0.6
        nt.links.new(sep.outputs["Z"], above.inputs["Value"])
        m1 = nt.nodes.new("ShaderNodeMath")
        m1.operation = "MULTIPLY"
        nt.links.new(st.outputs["Result"], m1.inputs[0])
        nt.links.new(above.outputs["Result"], m1.inputs[1])
        add = nt.nodes.new("ShaderNodeMix")
        add.data_type = "RGBA"
        add.blend_type = "ADD"
        add.inputs["Factor"].default_value = 1.0
        nt.links.new(ramp.outputs["Color"], add.inputs["A"])
        nt.links.new(m1.outputs["Value"], add.inputs["B"])
        nt.links.new(add.outputs["Result"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = strength
    else:
        sky_node = nt.nodes.new("ShaderNodeTexSky")
        for t in ("MULTIPLE_SCATTERING", "NISHITA", "SINGLE_SCATTERING"):
            try:
                sky_node.sky_type = t
                break
            except Exception:
                continue
        for attr, val in (("sun_elevation", math.radians(elevation)), ("sun_rotation", math.radians(azimuth)),
                          ("altitude", 200.0), ("air_density", 1.2), ("dust_density", 10.0 if dusty else 6.0),
                          ("aerosol_density", 10.0 if dusty else 6.0), ("ozone_density", 1.0), ("sun_size", math.radians(sun_size)),
                          ("sun_intensity", sun_intensity)):
            if hasattr(sky_node, attr):
                try:
                    setattr(sky_node, attr, val)
                except Exception:
                    pass
        nt.links.new(sky_node.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = strength
    scene.world = world


def sun(elevation, azimuth, energy, rgb, angle=1.5):
    s = bpy.data.lights.new("sun", "SUN")
    s.energy = energy
    s.color = lib.srgb(rgb)[:3]
    s.angle = math.radians(angle)
    o = bpy.data.objects.new("sun", s)
    # the light shines along its -Z: tilt it from the zenith, then turn it so it
    # shines away from the sun (azimuth: from +Y toward +X, as the sky texture)
    o.rotation_euler = Euler((math.radians(90 - elevation), 0, math.radians(180 - azimuth)))
    return link(o, "lights")


def point(pos, rgb, energy, radius=1.0, layer="lights"):
    p = bpy.data.lights.new("pt", "POINT")
    p.energy = energy
    p.color = lib.srgb(rgb)[:3]
    p.shadow_soft_size = radius
    o = bpy.data.objects.new("pt", p)
    o.location = pos
    return link(o, layer)


# ---------------------------------------------------------------------------
# Effects: fire, smoke, flashes, tracers, missiles, embers
# ---------------------------------------------------------------------------

def volume_material(name, color, density, emission=None, emit_strength=0.0, blackbody=0.0, scale=0.4, temp=1400, cut=0.0,
                    anisotropy=0.0, soft=0.0, vary=0.0):
    """A puff of smoke, dust or spray: noise inside a soft sphere. `soft`
    widens the fade at the edges (translucent rims the light shines
    through), `vary` modulates the density in big patches (thick and thin
    parts), `anisotropy` > 0 scatters forward (a bright rim against the
    sun)."""
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        vol = N("ShaderNodeVolumePrincipled")
        vol.inputs["Color"].default_value = lib.srgb(color)
        vol.inputs["Anisotropy"].default_value = anisotropy
        coord = N("ShaderNodeTexCoord")
        tex = N("ShaderNodeTexNoise")
        set_in(tex, "Scale", scale)
        set_in(tex, "Detail", 10.0)
        set_in(tex, "Roughness", 0.65)
        L(coord.outputs["Object"], tex.inputs["Vector"])
        # density: noise, faded toward the object's edge (a soft sphere)
        grad = N("ShaderNodeTexGradient")
        grad.gradient_type = "SPHERICAL"
        L(coord.outputs["Object"], grad.inputs["Vector"])
        prod = N("ShaderNodeMath")
        prod.operation = "MULTIPLY"
        L(tex.outputs["Fac"], prod.inputs[0])
        L(grad.outputs["Fac"], prod.inputs[1])
        # noise x falloff below `cut` is empty: ragged, billowy edges inside the sphere
        mul = N("ShaderNodeMapRange")
        mul.inputs["From Min"].default_value = cut * 0.6
        mul.inputs["From Max"].default_value = max(cut * 0.6 + 0.25 + 0.35 * soft, 0.3)
        L(prod.outputs["Value"], mul.inputs["Value"])
        dens = mul.outputs["Result"]
        if soft:  # ease the fade so the rims thin out gradually
            sq = N("ShaderNodeMath")
            sq.operation = "POWER"
            sq.inputs[1].default_value = 1.0 + soft
            L(dens, sq.inputs[0])
            dens = sq.outputs["Value"]
        if vary:
            big = N("ShaderNodeTexNoise")
            set_in(big, "Scale", 0.6)
            set_in(big, "Detail", 2.0)
            L(coord.outputs["Object"], big.inputs["Vector"])
            vr = N("ShaderNodeMapRange")
            vr.inputs["From Min"].default_value, vr.inputs["From Max"].default_value = 0.3, 0.7
            vr.inputs["To Min"].default_value, vr.inputs["To Max"].default_value = 1.0 - vary, 1.0 + vary
            L(big.outputs["Fac"], vr.inputs["Value"])
            vm = N("ShaderNodeMath")
            vm.operation = "MULTIPLY"
            L(dens, vm.inputs[0])
            L(vr.outputs["Result"], vm.inputs[1])
            dens = vm.outputs["Value"]
        ramp = N("ShaderNodeMath")
        ramp.operation = "MULTIPLY"
        ramp.inputs[1].default_value = density
        L(dens, ramp.inputs[0])
        L(ramp.outputs["Value"], vol.inputs["Density"])
        if emission:
            vol.inputs["Emission Color"].default_value = lib.srgb(emission)
            em = N("ShaderNodeMath")
            em.operation = "MULTIPLY"
            em.inputs[1].default_value = emit_strength
            L(mul.outputs["Result"], em.inputs[0])
            L(em.outputs["Value"], vol.inputs["Emission Strength"])
        if blackbody:
            vol.inputs["Blackbody Intensity"].default_value = blackbody
            vol.inputs["Temperature"].default_value = temp
        L(vol.outputs["Volume"], out.inputs["Volume"])
    return material(name, build)


_PRIMS = {}


def prim(kind, layer, location=(0, 0, 0), radius=1.0, size=1.0, depth=1.0, radius1=1.0, radius2=0.0,
         vertices=8, segments=16, ring_count=8, subdivisions=1):
    """A primitive as an object over a shared unit mesh (bpy.ops adds get
    slower with every object in the scene; thousands of smoke puffs made the
    scene build take minutes). Takes the same sizes as the bpy.ops adds; the
    material goes on the object (set_mat)."""
    r2 = radius2 / radius1 if kind == "cone" and radius1 else (1.0 if kind == "cylinder" else 0.0)
    key = (kind, vertices, segments, ring_count, subdivisions, round(r2, 3))
    me = _PRIMS.get(key)
    if me is None:
        bm = bmesh.new()
        if kind == "uv_sphere":
            bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=ring_count, radius=1.0)
        elif kind == "ico_sphere":
            bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
        elif kind == "cube":
            bmesh.ops.create_cube(bm, size=1.0)
        else:
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices, radius1=1.0, radius2=r2, depth=1.0)
        me = bpy.data.meshes.new(f"prim_{kind}")
        bm.to_mesh(me)
        bm.free()
        if kind.endswith("sphere"):
            for poly in me.polygons:
                poly.use_smooth = True
        me.materials.append(None)
        _PRIMS[key] = me
    o = bpy.data.objects.new(kind, me)
    link(o, layer)
    o.location = location
    o.scale = {"uv_sphere": (radius,) * 3, "ico_sphere": (radius,) * 3, "cube": (size,) * 3,
               "cone": (radius1, radius1, depth), "cylinder": (radius, radius, depth)}[kind]
    return o


def set_mat(o, m):
    o.material_slots[0].link = "OBJECT"
    o.material_slots[0].material = m


def blob(layer, pos, size, mat, seed=0):
    o = prim("uv_sphere", layer, segments=16, ring_count=8, radius=1.0, location=pos)
    o.scale = size
    o.rotation_euler = Euler((seed * 0.7, seed * 1.3, seed * 2.1))
    set_mat(o, mat)
    return o


def emissive(name, rgb, strength):
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        em = N("ShaderNodeEmission")
        em.inputs["Color"].default_value = lib.srgb(rgb)
        em.inputs["Strength"].default_value = strength
        L(em.outputs["Emission"], out.inputs["Surface"])
    return material(name, build)


def solid(name, rgb, rough=0.9):
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        b = N("ShaderNodeBsdfPrincipled")
        b.inputs["Base Color"].default_value = lib.srgb(rgb)
        b.inputs["Roughness"].default_value = rough
        L(b.outputs["BSDF"], out.inputs["Surface"])
    return material(name, build)


def smoke_plume(layer, pos, size, dark=40, seed=0):
    smk = volume_material(f"plume_{dark}", (dark, dark - 6, dark - 12), 0.9, scale=1.6, cut=0.34, anisotropy=0.45, soft=0.6, vary=0.5)
    x, y, z = pos
    for k in range(4):
        s = size * (1.0 + 0.45 * k)
        blob(layer, (x + k * size * 0.8, y + k * size * 0.4, z + size * (0.8 + 1.4 * k)), (s, s, s * 0.85), smk, seed + k)


def flash(layer, pos, direction, size, rgb=(255, 200, 120)):
    """A muzzle flash: a bright star cone along `direction` and a light."""
    d = Vector(direction).normalized()
    m = emissive(f"flash_{rgb}", rgb, 60.0)
    o = prim("cone", layer, vertices=8, radius1=size * 0.45, radius2=0.0, depth=size * 2.2, location=Vector(pos) + d * size * 1.1)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    set_mat(o, m)
    blob(layer, pos, (size * 0.5,) * 3, volume_material(f"flashvol_{rgb}", rgb, 4.0, rgb, 40.0, scale=1.0))
    point(pos, rgb, 2500 * size, radius=size * 0.4, layer=layer)


def tracer(layer, a, b, rgb, width=0.12, strength=40.0):
    a, b = Vector(a), Vector(b)
    d = b - a
    o = prim("cylinder", layer, vertices=6, radius=width, depth=d.length, location=(a + b) / 2)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    set_mat(o, emissive(f"tracer_{rgb}_{strength}", rgb, strength))
    return o


TRAIL_MATS = {}
WIND = Vector((0.6, 0.25, 0.08))  # the drift of old smoke, per unit of trail length (scaled below)


def trail_mats():
    """Rocket smoke by age: fresh smoke dense and bright white, mid-age
    lumpy and softer, old smoke thin, broken up and greyer."""
    if not TRAIL_MATS:
        TRAIL_MATS["fresh"] = volume_material("trail_fresh", (255, 255, 255), 5.0, (255, 250, 242), 0.6, scale=2.4, cut=0.26,
                                              anisotropy=0.55, soft=0.4, vary=0.3)
        TRAIL_MATS["mid"] = volume_material("trail_mid", (255, 255, 255), 3.0, (255, 250, 242), 0.4, scale=2.2, cut=0.3,
                                            anisotropy=0.55, soft=0.5, vary=0.4)
        TRAIL_MATS["old"] = volume_material("trail_old", (248, 248, 250), 1.2, (255, 250, 242), 0.2, scale=1.8, cut=0.36,
                                            anisotropy=0.5, soft=0.6, vary=0.5)
    return TRAIL_MATS


def trail(layer, pts, width, seed=0, head_rgb=(255, 210, 150), missile=None, team=None, smoke=None, flame=True):
    """A missile on a smoke trail along the polyline `pts` (tail to head):
    a tight bright line at the missile with the exhaust glowing in it,
    swelling into lumpy puffs, the oldest smoke wide, thin and broken,
    drifting downwind and wavering; a flame and a light at the head, and
    optionally the missile mesh. `smoke` replaces the aged white smoke with
    one material (debris and wreck trails)."""
    rng = random.Random(seed)
    path = [Vector(p) for p in pts]
    lengths = [0.0]
    for i in range(1, len(path)):
        lengths.append(lengths[-1] + (path[i] - path[i - 1]).length)
    total = lengths[-1]
    if total <= 0:
        return
    mats = trail_mats()
    drift = WIND * min(total, 300.0) * 0.12
    phase = rng.uniform(0, 100)
    t = 0.0
    while t < total:
        i = max(k for k in range(len(lengths)) if lengths[k] <= t)
        i = min(i, len(path) - 2)
        f = (t - lengths[i]) / max(lengths[i + 1] - lengths[i], 1e-6)
        p = path[i].lerp(path[i + 1], f)
        age = 1.0 - t / total  # 1 at the tail, 0 at the head
        r = width * (0.3 + 3.2 * age ** 1.3) * rng.uniform(0.8, 1.25)
        # downwind drift and a slow waver, both growing with age
        wav = Vector((noise.noise(Vector((t * 0.02 + phase, 0, 0))), noise.noise(Vector((0, t * 0.02 + phase, 0))),
                      noise.noise(Vector((0, 0, t * 0.02 + phase)))))
        q = p + drift * age ** 1.6 + wav * width * 3.0 * age
        q += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * r * 0.3 * (0.3 + age)
        if smoke is not None:
            mat = smoke
        else:
            mat = mats["fresh"] if age < 0.15 else mats["mid"] if age < 0.55 else mats["old"]
        if smoke is not None or age < 0.85 or rng.random() < 0.85:  # the oldest smoke breaks up
            blob(layer, q, (r, r * rng.uniform(0.85, 1.15), r * rng.uniform(0.8, 1.1)), mat, seed * 1000 + int(t * 7))
        t += max(width * 0.35, r * (0.5 - 0.1 * age))
    if flame and smoke is None:  # the exhaust glowing in the fresh smoke behind the motor
        head, prev = path[-1], path[-2]
        d = (head - prev).normalized()
        for k in range(3):
            blob(layer, head - d * width * (1.2 + k * 1.3), (width * (0.7 - k * 0.15),) * 3,
                 fire_material("exhaust", strength=40.0 - k * 12, scale=2.6, cut=0.3), seed + k)
    if not flame:
        return
    head, prev = path[-1], path[-2]
    d = (head - prev).normalized()
    m = emissive("flame", head_rgb, 80.0)
    fl = prim("cone", layer, vertices=8, radius1=width * 0.45, radius2=0.0, depth=width * 4, location=head - d * width * 2)
    fl.rotation_euler = (-d).to_track_quat("Z", "Y").to_euler()
    set_mat(fl, m)
    point(head - d * width, head_rgb, 1500 * width, radius=width * 0.5, layer=layer)
    if missile:
        fx_missile(missile, layer, head, d, team)


def fx_missile(mid, layer, pos, direction, team):
    exp = os.path.join(ROOT, "assets", "fx", "missiles", mid, "export")
    fbx = os.path.join(exp, f"{mid}.fbx")
    if not os.path.isfile(fbx):
        return
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    objs = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(f"{mid}_root", None)
    link(root, layer)
    body = solid(f"missile_{team}", (150, 150, 146), 0.5)
    for o in objs:
        for c in o.users_collection:
            c.objects.unlink(o)
        if o.type != "MESH" or o.name.startswith(("emissive_probe", "tex_")):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        link(o, layer)
        lib.assign_single_material([o], body if "_glow_" not in o.name else emissive("mglow", (255, 220, 170), 30.0))
        o.parent = root
    root.location = pos
    root.rotation_euler = Vector(direction).to_track_quat("Y", "Z").to_euler()
    root.scale = (1.0, 1.0, 1.0)


def embers(layer, center, spread, count, seed=0):
    rng = random.Random(seed)
    m = emissive("ember", (255, 130, 50), 14.0)
    for _ in range(count):
        p = Vector(center) + Vector((rng.uniform(-spread[0], spread[0]), rng.uniform(-spread[1], spread[1]),
                                     rng.uniform(0, spread[2])))
        o = prim("ico_sphere", layer, subdivisions=1, radius=rng.uniform(0.04, 0.12), location=p)
        set_mat(o, m)


def rubble(layer, center, spread, count, seed=0, rgb=(38, 34, 30)):
    rng = random.Random(seed)
    m = solid(f"rubble_{rgb}", rgb)
    for _ in range(count):
        p = Vector(center) + Vector((rng.uniform(-spread[0], spread[0]), rng.uniform(-spread[1], spread[1]), 0))
        s = rng.uniform(0.3, 1.4)
        o = prim("ico_sphere", layer, subdivisions=1, radius=s, location=(p.x, p.y, p.z + s * 0.2))
        o.scale = (s * rng.uniform(0.8, 1.6), s * rng.uniform(0.8, 1.6), s * rng.uniform(0.4, 0.9))
        o.rotation_euler = Euler((rng.random(), rng.random(), rng.random() * 6))
        set_mat(o, m)


def camera(scene, pos, target, lens):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    cd.sensor_width = 36
    cd.clip_end = 20000
    cam = bpy.data.objects.new("cam", cd)
    scene.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    return cam


# ---------------------------------------------------------------------------
# Scenes
# ---------------------------------------------------------------------------

def fill(energy, rgb=(120, 150, 200), azimuth=180.0, elevation=25.0, angle=20.0):
    """A second, softer sun: by default from behind the camera, so the units
    read against a low sun ahead."""
    s = bpy.data.lights.new("fill", "SUN")
    s.energy = energy
    s.color = lib.srgb(rgb)[:3]
    s.angle = math.radians(angle)
    o = bpy.data.objects.new("fill", s)
    o.rotation_euler = Euler((math.radians(90 - elevation), 0, math.radians(180 - azimuth)))
    return link(o, "lights")


def cam_rig(scene, height, horizon_from_top, lens, x=0.0, y=-20.0, yaw=0.0):
    """A camera `height` studs up whose horizon sits `horizon_from_top` (0..1)
    down the frame; yaw turns it from +Y toward +X (degrees)."""
    vfov = 2 * math.atan((36 * H / W) / 2 / lens)
    pitch = -(0.5 - horizon_from_top) * vfov
    d = Vector((math.sin(math.radians(yaw)) * math.cos(pitch), math.cos(math.radians(yaw)) * math.cos(pitch), math.sin(pitch)))
    pos = Vector((x, y, height))
    return camera(scene, pos, pos + d * 100, lens)


def shell(layer, a, b, frac, rgb, size=0.5, strength=40.0):
    """A round in flight from a to b, `frac` of the way, as a camera sees a
    tracer: a small white-hot head and a short streak behind it tapering
    to nothing (motion blur), in the tracer's warm colour."""
    a, b = Vector(a), Vector(b)
    p = a.lerp(b, frac)
    d = (b - a).normalized()
    length = size * 7.0
    o = prim("cone", layer, vertices=8, radius1=size * 0.16, radius2=0.0, depth=length, location=p - d * length / 2)
    o.rotation_euler = (-d).to_track_quat("Z", "Y").to_euler()
    set_mat(o, emissive(f"shellstreak_{rgb}", rgb, strength * 0.5))
    h = prim("ico_sphere", layer, subdivisions=1, radius=size * 0.2, location=p)
    set_mat(h, emissive("shellhead_hot", (255, 240, 210), strength * 1.5))


def arc(a, b, apex, n=10):
    """Points on a quadratic arc from a to b through a raised middle."""
    a, b = Vector(a), Vector(b)
    m = (a + b) / 2 + Vector((0, 0, apex))
    return [tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * m + t * t * b) for t in (i / (n - 1) for i in range(n))]


def splash(layer, pos, size, seed=0):
    """A shell splash in the water: a white column of spray and a ring."""
    spray = volume_material("spray", (235, 240, 245), 1.6, scale=1.2, cut=0.35)
    x, y, z = pos
    blob(layer, (x, y, z + size * 1.4), (size * 0.6, size * 0.6, size * 1.6), spray, seed)
    blob(layer, (x, y, z + size * 0.3), (size * 1.4, size * 1.4, size * 0.35), spray, seed + 1)


def searchlight(layer, pos, direction, length, rgb=(200, 220, 255)):
    """A faint emissive cone standing in for a searchlight beam."""
    d = Vector(direction).normalized()

    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        em = N("ShaderNodeEmission")
        em.inputs["Color"].default_value = lib.srgb(rgb)
        em.inputs["Strength"].default_value = 0.6
        tr = N("ShaderNodeBsdfTransparent")
        lw = N("ShaderNodeLayerWeight")
        set_in(lw, "Blend", 0.3)
        mix = N("ShaderNodeMixShader")
        L(lw.outputs["Facing"], mix.inputs["Fac"])
        L(em.outputs["Emission"], mix.inputs[1])
        L(tr.outputs["BSDF"], mix.inputs[2])
        L(mix.outputs["Shader"], out.inputs["Surface"])
    m = material(f"beam_{rgb}", build)
    o = prim("cone", layer, vertices=24, radius1=length * 0.06, radius2=0.4, depth=length, location=Vector(pos) + d * length / 2)
    o.rotation_euler = (-d).to_track_quat("Z", "Y").to_euler()
    set_mat(o, m)
    point(pos, rgb, 300, radius=0.3, layer=layer)


def fire_material(name, strength=60.0, density=8.0, scale=1.5, cut=0.3):
    strength *= 3.0
    """A fireball volume: ragged noise inside a soft sphere; the thick parts
    burn white-yellow, thinning through orange to a dull red edge, and the
    smoke it scatters is soot-dark."""
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        vol = N("ShaderNodeVolumePrincipled")
        vol.inputs["Color"].default_value = lib.srgb((46, 36, 30))
        coord = N("ShaderNodeTexCoord")
        tex = N("ShaderNodeTexNoise")
        set_in(tex, "Scale", scale)
        set_in(tex, "Detail", 12.0)
        set_in(tex, "Roughness", 0.7)
        L(coord.outputs["Object"], tex.inputs["Vector"])
        grad = N("ShaderNodeTexGradient")
        grad.gradient_type = "SPHERICAL"
        L(coord.outputs["Object"], grad.inputs["Vector"])
        prod = N("ShaderNodeMath")
        prod.operation = "MULTIPLY"
        L(tex.outputs["Fac"], prod.inputs[0])
        L(grad.outputs["Fac"], prod.inputs[1])
        d = N("ShaderNodeMapRange")
        d.inputs["From Min"].default_value = cut * 0.6
        d.inputs["From Max"].default_value = cut * 0.6 + 0.3
        L(prod.outputs["Value"], d.inputs["Value"])
        dens = N("ShaderNodeMath")
        dens.operation = "MULTIPLY"
        dens.inputs[1].default_value = density
        L(d.outputs["Result"], dens.inputs[0])
        L(dens.outputs["Value"], vol.inputs["Density"])
        ramp = N("ShaderNodeValToRGB")
        els = ramp.color_ramp.elements
        els[0].position, els[0].color = 0.0, lib.srgb((90, 14, 4))
        els[1].position, els[1].color = 1.0, lib.srgb((255, 246, 214))
        for pos, c in ((0.35, (220, 64, 12)), (0.6, (255, 128, 30)), (0.82, (255, 196, 90))):
            e = els.new(pos)
            e.color = lib.srgb(c)
        L(d.outputs["Result"], ramp.inputs["Fac"])
        L(ramp.outputs["Color"], vol.inputs["Emission Color"])
        hot = N("ShaderNodeMath")
        hot.operation = "POWER"
        hot.inputs[1].default_value = 1.5
        L(d.outputs["Result"], hot.inputs[0])
        em = N("ShaderNodeMath")
        em.operation = "MULTIPLY"
        em.inputs[1].default_value = strength
        L(hot.outputs["Value"], em.inputs[0])
        L(em.outputs["Value"], vol.inputs["Emission Strength"])
        L(vol.outputs["Volume"], out.inputs["Volume"])
    return material(name, build)


def blob_dir(layer, pos, direction, length, radius, mat, seed=0):
    """An elongated puff along `direction` (dirt jets, streaks)."""
    d = Vector(direction).normalized()
    o = prim("uv_sphere", layer, segments=12, ring_count=6, radius=1.0, location=Vector(pos) + d * length * 0.5)
    o.scale = (radius, radius, length * 0.5)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    set_mat(o, mat)
    return o


def sparks(layer, pos, size, count, seed, rgb=(255, 190, 110), up=0.2):
    rng = random.Random(seed)
    for k in range(count):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 1) + up)).normalized()
        r0 = size * rng.uniform(0.5, 1.4)
        tracer(layer, Vector(pos) + d * r0, Vector(pos) + d * (r0 + size * rng.uniform(0.15, 0.6)), rgb,
               width=size * rng.uniform(0.006, 0.015), strength=rng.uniform(6.0, 14.0))


def shard(layer, pos, size, rng, mat):
    """An irregular fragment: a squashed, skewed lump rather than a cube."""
    o = prim("ico_sphere", layer, subdivisions=1, radius=size, location=pos)
    o.scale = (size * rng.uniform(0.6, 1.6), size * rng.uniform(0.25, 0.9), size * rng.uniform(0.15, 0.6))
    o.rotation_euler = Euler((rng.random() * 3, rng.random() * 3, rng.random() * 6))
    set_mat(o, mat)
    return o


def explosion(layer, pos, size, smoke=1.0, debris=True, seed=0, light=True):
    """A ground blast as filmed: an orange fireball heaped up out of the
    ground inside a rolling cloud of brown dust and black smoke that climbs
    above it, dark dirt jets thrown up at angles, fragments in the air, a
    few sparks, and the firelight on everything near."""
    rng = random.Random(seed)
    x, y, z = pos
    base = Vector((x, y, z))
    # emission adds up along the path through the volume, so big fireballs burn lower per unit
    fire = fire_material("fireball", strength=rng.uniform(45, 75) * min(1.0, 2.5 / size), scale=rng.uniform(1.3, 2.0))
    soot = volume_material("soot", (40, 33, 28), 2.0, scale=2.2, cut=0.32, anisotropy=0.45, soft=0.6, vary=0.5)
    dust = volume_material("dust", (128, 110, 88), 1.2, scale=2.0, cut=0.38)
    dirt = volume_material("dirt_jet", (70, 58, 44), 2.4, scale=2.4, cut=0.34)
    for k in range(rng.randint(5, 8)):  # the fireball, heaped
        a = rng.uniform(0, 2 * math.pi)
        off = Vector((math.cos(a), math.sin(a), 0)) * size * rng.uniform(0.0, 0.7)
        s = size * rng.uniform(0.5, 0.95)
        blob(layer, base + off + Vector((0, 0, size * rng.uniform(0.3, 1.3))), (s, s * rng.uniform(0.8, 1.2), s * rng.uniform(0.8, 1.2)),
             fire, seed + 20 + k)
    for k in range(rng.randint(6, 9)):  # dust rolling out low around it
        a = rng.uniform(0, 2 * math.pi)
        off = Vector((math.cos(a), math.sin(a), 0)) * size * rng.uniform(0.8, 1.8)
        s = size * rng.uniform(0.7, 1.2)
        blob(layer, base + off + Vector((0, 0, s * 0.45)), (s, s, s * 0.7), dust, seed + 30 + k)
    for k in range(rng.randint(5, 8)):  # black smoke wrapping and climbing above
        a = rng.uniform(0, 2 * math.pi)
        h = rng.uniform(1.2, 2.8) * smoke
        off = Vector((math.cos(a) * size * 0.7, math.sin(a) * size * 0.5, size * h))
        s = size * rng.uniform(0.7, 1.15) * (0.8 + 0.25 * h)
        blob(layer, base + off, (s, s, s * 0.85), soot, seed + 40 + k)
    for k in range(rng.randint(6, 10)):  # dirt jets
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), rng.uniform(1.0, 3.0)))
        blob_dir(layer, base, d, size * rng.uniform(1.8, 3.6), size * rng.uniform(0.16, 0.28), dirt, seed + 60 + k)
    sparks(layer, base + Vector((0, 0, size * 0.6)), size, 8, seed + 80)
    if debris:
        chunk = solid("debris", (36, 32, 28))
        for k in range(rng.randint(8, 14)):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(0.6, 3.0) * size
            h = rng.uniform(0.3, 3.2) * size
            shard(layer, (x + math.cos(a) * r, y + math.sin(a) * r, z + h), rng.uniform(0.06, 0.2) * size ** 0.7, rng, chunk)
    if light:
        point((x, y, z + size * 1.0), (255, 140, 60), 12000 * size, radius=size * 0.9, layer=layer)


def burst(layer, pos, size, seed=0):
    """An air burst (a proximity-fused warhead): a ragged fireball with a
    soot shell, a ring of sparks and fragments, a light."""
    rng = random.Random(seed)
    p = Vector(pos)
    fire = fire_material("airburst", strength=70.0, scale=1.8, cut=0.4)
    for k in range(3):
        o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.5, 0.8))) * size * 0.35
        s = size * rng.uniform(0.5, 0.8)
        blob(layer, p + o, (s,) * 3, fire, seed + k)
    blob(layer, p + Vector((size * 0.3, 0, size * 0.5)), (size * 1.3,) * 3, volume_material("airsoot", (44, 40, 38), 1.0, scale=1.0, cut=0.4), seed + 5)
    sparks(layer, p, size, 18, seed + 9, up=0.0)
    for k in range(rng.randint(2, 4)):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.0, 0.8))).normalized()
        debris_trail(layer, p, d * size * rng.uniform(1.0, 1.6), seed + 40 + k, steps=rng.randint(2, 4),
                     width=size * rng.uniform(0.2, 0.3), fire=False)
    point(p, (255, 190, 120), 30000 * size, radius=size, layer=layer)


def debris_trail(layer, start, vel, seed, steps=8, width=0.5, fire=True):
    """A burning fragment falling on a ballistic arc with a thin smoke trail."""
    rng = random.Random(seed)
    p, v = Vector(start), Vector(vel)
    pts = [p.copy()]
    for _ in range(steps):
        v = v * 0.9 + Vector((0, 0, -1.2))
        p = p + v
        pts.append(p.copy())
    smoke = volume_material("debris_smoke", (60, 56, 52), 1.4, scale=1.0, cut=0.35)
    trail(layer, [tuple(q) for q in pts], width, seed=seed, smoke=smoke, flame=False)
    head = pts[-1]
    if fire:
        blob(layer, head, (width * 1.4,) * 3, fire_material("debris_fire", strength=60.0, scale=2.0, cut=0.35), seed)
    shard(layer, head, width * 0.8, rng, solid("debris", (30, 26, 22)))


def plane_kill(layer, uid, pos, vel, seed, size=7.0):
    """An aircraft just hit: a big fireball where it was, the burning wreck
    falling out of it nose-down under a thick black smoke trail, burning
    fragments arcing away, sparks, and a strong light."""
    rng = random.Random(seed)
    p, v = Vector(pos), Vector(vel)
    fire = fire_material("killfire", strength=80.0, scale=1.6, cut=0.38)
    for k in range(6):
        o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 0.8))) * size * 0.45
        s = size * rng.uniform(0.45, 0.8)
        blob(layer, p + o, (s, s * rng.uniform(0.8, 1.2), s * 0.85), fire, seed + k)
    soot = volume_material("killsoot", (38, 32, 28), 1.6, scale=1.8, cut=0.34, anisotropy=0.45, soft=0.6, vary=0.5)
    for k in range(4):
        o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.2, 1.0))) * size * 0.8
        s = size * rng.uniform(0.7, 1.1)
        blob(layer, p + o, (s,) * 3, soot, seed + 10 + k)
    # the wreck carries on along its course, dropping
    fall = [p.copy()]
    q, w = p.copy(), v.copy()
    for _ in range(6):
        w = w * 0.92 + Vector((0, 0, -0.9))
        q = q + w * 1.6
        fall.append(q.copy())
    heading = math.degrees(math.atan2(v.x, v.y))
    pitch = math.degrees(math.atan2(-(fall[-1] - fall[-2]).z, (fall[-1] - fall[-2]).xy.length))
    place(uid, layer, fall[-1].x, fall[-1].y, heading, z=fall[-1].z, wreck=True, tilt=(-pitch, rng.uniform(-60, 60)))
    trail(layer, [tuple(q) for q in fall], 2.6, seed=seed * 7,
          smoke=volume_material("killtrail", (36, 33, 30), 1.8, scale=1.4, cut=0.32), flame=False)
    blob(layer, fall[-1] - (fall[-1] - fall[-2]).normalized() * 2.0, (2.6, 2.6, 3.2), fire_material("wreckfire", 70.0, scale=2.0, cut=0.36), seed + 30)
    point(fall[-1], (255, 150, 70), 40000, radius=2.0, layer=layer)
    for k in range(rng.randint(5, 8)):  # burning fragments
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1.0))).normalized()
        debris_trail(layer, p, v * 0.4 + d * rng.uniform(2.0, 4.5), seed + 100 + k, steps=rng.randint(4, 8),
                     width=rng.uniform(0.35, 0.7), fire=rng.random() < 0.7)
    sparks(layer, p, size, 14, seed + 200, up=0.0)
    point(p, (255, 170, 90), 120000, radius=size, layer=layer)


def fleet(layer, ships, seed, targets=None, flash_rgb=((255, 214, 140), (255, 110, 50))):
    """Ships trading fire, each different: how many guns fire, where each
    shell is aimed (an enemy ship, or the given target points), how high it
    arcs and how far it has flown; flashes and gun smoke only on the guns
    that just fired, splashes of different sizes around the targets, some
    ships hit and burning, the odd missile launch."""
    rng = random.Random(seed)
    gun_smoke = volume_material("navalsmoke", (180, 174, 166), 0.5, scale=0.9, cut=0.42)
    placed = []
    for uid, x, y, hd in ships:
        place(uid, layer, x, y, hd)
        placed.append((uid, Vector((x, y, 0)), hd))
    for uid, pos, hd in placed:
        side = 0 if uid.startswith("ord") else 1
        enemies = [q for u, q, _ in placed if u.startswith("ord") != uid.startswith("ord")]
        pool = targets if targets else enemies
        if not pool:
            continue
        for g in range(rng.choice((0, 1, 2, 2, 3, 4))):
            tgt = Vector(rng.choice(pool)) + Vector((rng.uniform(-14, 14), rng.uniform(-14, 14), 0))
            fwd = forward(hd)
            muzzle = pos + fwd * rng.uniform(-10, 14) + Vector((0, 0, rng.uniform(4.0, 6.0)))
            pts = arc(muzzle, tgt, rng.uniform(15, 70), 14)
            frac = rng.uniform(0.02, 0.98)
            i = min(int(frac * 13), 12)
            c = tuple(min(255, int(ch * rng.uniform(0.85, 1.1))) for ch in flash_rgb[side])
            shell(layer, pts[i], pts[i + 1], 0.6, c, rng.uniform(0.6, 1.1), rng.uniform(35.0, 70.0))
            if frac < 0.25:
                d = (Vector(pts[1]) - Vector(pts[0])).normalized()
                flash(layer, muzzle + d * 2.0, d, rng.uniform(1.8, 4.0), c)
                for k in range(rng.randint(1, 3)):
                    blob(layer, muzzle + d * rng.uniform(3, 9) + Vector((0, 0, rng.uniform(0, 2))), (rng.uniform(2.0, 4.5),) * 3,
                         gun_smoke, seed + g * 7 + k)
        if rng.random() < 0.35:  # a vertical missile launch
            t = pos + Vector((rng.uniform(-60, 60), rng.uniform(-60, 60), 0))
            sam(layer, pos + Vector((0, 0, 5)), (t + Vector((0, 0, rng.uniform(40, 70))), Vector((0, 0, 0))), seed + 31 * len(uid),
                None, None, width=1.0, cut=rng.uniform(0.3, 0.7), turn=rng.uniform(5, 10), tilt=0.1)
    for uid, pos, hd in placed:  # near misses and hits
        for k in range(rng.randint(0, 3)):
            o = Vector((rng.uniform(-22, 22), rng.uniform(-22, 22), 0))
            splash(layer, tuple(pos + o), rng.uniform(2.5, 6.5), seed=rng.randint(0, 999))
        if rng.random() < 0.3:
            explosion(layer, tuple(pos + forward(hd) * rng.uniform(-8, 8) + Vector((0, 0, 4))), rng.uniform(2.0, 3.5),
                      smoke=1.6, debris=False, seed=rng.randint(0, 999))
    return placed


def forward(heading, pitch=0.0):
    h, p = math.radians(heading), math.radians(pitch)
    return Vector((math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p)))


def flyers(layer, craft):
    """Places aircraft (uid, x, y, z, heading, bank, speed per step) and
    returns each one's position and velocity, for the SAMs chasing them."""
    out = []
    for uid, x, y, z, hd, bank, speed in craft:
        place(uid, layer, x, y, hd, z=z, tilt=(4 if speed < 4 else 0, bank))
        out.append((Vector((x, y, z)), forward(hd) * speed))
    return out


def sam_path(start, target, tvel, seed, speed=8.0, turn=10.0, boost=3, cut=1.0, weave=0.0, tilt=0.8, steps=None):
    """A missile's flight, simulated: it leaves the rail near-vertical, then
    turns at most `turn` degrees a step toward a lead point on a moving
    target. `cut` < 1 freezes it partway (still chasing); `weave` adds a
    corkscrew as it fights the target's flares. Returns the points and
    whether it reached the target."""
    rng = random.Random(seed)
    p = Vector(start)
    target, tvel = Vector(target), Vector(tvel)
    to = (target - p)
    lean = Vector((to.x, to.y, 0)).normalized() * tilt if to.length > 0 else Vector()
    v = (Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 1.0)) + lean).normalized()
    est = int(to.length / speed * 1.5) + boost + 4
    exact = steps is not None
    steps = steps if exact else max(boost + 3, int(est * cut))
    pts = [p.copy()]
    for k in range(steps):
        tpos = target - tvel * (steps - k)
        if k >= boost:
            tgo = (tpos - p).length / speed
            aim = (tpos + tvel * tgo - p).normalized()
            if weave:
                side = v.cross(Vector((0, 0, 1))).normalized()
                up = side.cross(v).normalized()
                aim = (aim + (side * math.sin(k * 0.9) + up * math.cos(k * 0.9)) * weave).normalized()
            ang = v.angle(aim, 0.0)
            v = v.slerp(aim, min(1.0, math.radians(turn) / ang)) if ang > 1e-4 else aim
        p = p + v * speed * (0.6 if k < boost else 1.0)
        pts.append(p.copy())
        if not exact and (tpos - p).length < speed * 0.8:
            return pts, True
    return pts, False


def sam(layer, start, craft, seed, missile, team, width=2.2, cut=1.0, **kw):
    """A SAM on a smoke trail chasing `craft` (position, velocity); if it
    reaches the target, a burst there."""
    pos, vel = craft
    pts, hit = sam_path(start, pos, vel, seed, cut=cut, **kw)
    trail(layer, [tuple(q) for q in pts], width, seed=seed, missile=None if hit else missile, team=team)
    if hit:
        burst(layer, tuple(pos + Vector((0, 0, 1))), 3.5, seed=seed + 7)
    return pts


def kill(layer, site, spec, seed, team, **kw):
    """A SAM that has just reached its target: the trail from the launcher
    to the aircraft's position at this moment, and the aircraft blowing
    apart there (spec as for flyers())."""
    uid, x, y, z, hd, bank, speed = spec
    pos, vel = Vector((x, y, z)), forward(hd) * speed
    best = None
    for n in range(6, 140):
        pts, _ = sam_path(site, pos, vel, seed, steps=n, **kw)
        d = (pts[-1] - pos).length
        if best is None or d < best[0]:
            best = (d, pts)
        if d < 8.0:
            break
    trail(layer, [tuple(q) for q in best[1]], 2.2, seed=seed, team=team)
    plane_kill(layer, uid, pos, vel, seed + 1)


CRATERS = []  # (x, y, r) for the current scene: shell holes and the blasts in them


def crater_z(x, y):
    z = 0.0
    for cx, cy, r in CRATERS:
        d = math.hypot(x - cx, y - cy) / r
        if d < 1.6:
            if d < 1.0:
                z -= r * 0.32 * (1 - d * d)
            z += r * 0.12 * math.exp(-((d - 1.05) / 0.22) ** 2)
    return z


def scorch_at(x, y):
    s = 0.0
    for cx, cy, r in CRATERS:
        d = math.hypot(x - cx, y - cy) / (r * 2.2)
        if d < 1:
            s = max(s, (1 - d) ** 0.7)
    return s


def height(x, y, amp=1.6, seed=0.0):
    p = Vector((x / 60.0 + seed, y / 60.0, 0.0))
    return (amp * noise.fractal(p, 0.6, 2.0, 4) + 0.35 * amp * noise.noise(Vector((x / 14.0, y / 14.0, seed)))
            + 0.12 * noise.fractal(Vector((x / 3.0, y / 3.0, 7.0)), 0.6, 2.0, 3) + crater_z(x, y))


def ground_material(kind):
    """Photographic ground: grass and dry grass over earth in large and small
    patches, bare and churned earth where vehicles and blasts have been
    (the mesh's `scorch` attribute), burnt black at the blast centres; three
    scales of bump."""
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        bsdf = N("ShaderNodeBsdfPrincipled")
        coord = N("ShaderNodeTexCoord")

        def noise_tex(scale, detail=8.0, rough=0.6):
            t = N("ShaderNodeTexNoise")
            set_in(t, "Scale", scale)
            set_in(t, "Detail", detail)
            set_in(t, "Roughness", rough)
            L(coord.outputs["Object"], t.inputs["Vector"])
            return t

        def ramp(src, stops):
            r = N("ShaderNodeValToRGB")
            els = r.color_ramp.elements
            els[0].position, els[0].color = stops[0][0], lib.srgb(stops[0][1])
            els[1].position, els[1].color = stops[-1][0], lib.srgb(stops[-1][1])
            for pos, c in stops[1:-1]:
                e = els.new(pos)
                e.color = lib.srgb(c)
            L(src, r.inputs["Fac"])
            return r

        def mix(a, b, fac):
            m = N("ShaderNodeMix")
            m.data_type = "RGBA"
            L(fac, m.inputs["Factor"])
            L(a, m.inputs["A"])
            L(b, m.inputs["B"])
            return m.outputs["Result"]

        if kind == "beach":
            base = ramp(noise_tex(0.3).outputs["Fac"], [(0.3, (150, 132, 100)), (0.55, (176, 158, 122)), (0.75, (138, 120, 92))]).outputs["Color"]
            wet = ramp(noise_tex(0.02, 3).outputs["Fac"], [(0.45, (0, 0, 0)), (0.6, (255, 255, 255))]).outputs["Color"]
            bw = N("ShaderNodeRGBToBW")
            L(wet, bw.inputs["Color"])
            col = mix(base, ramp(noise_tex(0.4).outputs["Fac"], [(0.3, (100, 90, 72)), (0.7, (116, 104, 82))]).outputs["Color"], bw.outputs["Val"])
            rough_v = 0.85
        else:
            grass = ramp(noise_tex(0.35, 10).outputs["Fac"], [(0.25, (58, 72, 34)), (0.45, (82, 92, 44)), (0.65, (110, 106, 58)), (0.8, (72, 84, 40))]).outputs["Color"]
            dry = ramp(noise_tex(0.02, 4).outputs["Fac"], [(0.4, (0, 0, 0)), (0.62, (255, 255, 255))])
            drybw = N("ShaderNodeRGBToBW")
            L(dry.outputs["Color"], drybw.inputs["Color"])
            straw = ramp(noise_tex(0.5).outputs["Fac"], [(0.3, (120, 108, 66)), (0.7, (146, 128, 80))]).outputs["Color"]
            col = mix(grass, straw, drybw.outputs["Val"])
            earth = ramp(noise_tex(0.25).outputs["Fac"], [(0.3, (74, 60, 46)), (0.7, (98, 80, 60))]).outputs["Color"]
            bare = ramp(noise_tex(0.05, 6).outputs["Fac"], [(0.55, (0, 0, 0)), (0.7, (255, 255, 255))])
            barebw = N("ShaderNodeRGBToBW")
            L(bare.outputs["Color"], barebw.inputs["Color"])
            col = mix(col, earth, barebw.outputs["Val"])
            rough_v = 0.92
        # blast-churned earth, then burnt black at the centres
        attr = N("ShaderNodeAttribute")
        attr.attribute_name = "scorch"
        churn = ramp(noise_tex(0.6).outputs["Fac"], [(0.3, (70, 58, 46)), (0.7, (92, 76, 58))]).outputs["Color"]
        sc1 = N("ShaderNodeMapRange")
        sc1.inputs["From Min"].default_value = 0.05
        sc1.inputs["From Max"].default_value = 0.35
        L(attr.outputs["Fac"], sc1.inputs["Value"])
        col = mix(col, churn, sc1.outputs["Result"])
        sc2 = N("ShaderNodeMapRange")
        sc2.inputs["From Min"].default_value = 0.45
        sc2.inputs["From Max"].default_value = 0.9
        L(attr.outputs["Fac"], sc2.inputs["Value"])
        burnt = ramp(noise_tex(1.2).outputs["Fac"], [(0.3, (18, 16, 14)), (0.7, (40, 34, 28))]).outputs["Color"]
        col = mix(col, burnt, sc2.outputs["Result"])
        L(col, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough_v
        b1 = N("ShaderNodeBump")
        set_in(b1, "Strength", 0.5)
        set_in(b1, "Distance", 0.3)
        L(noise_tex(0.6, 10).outputs["Fac"], b1.inputs["Height"])
        b2 = N("ShaderNodeBump")
        set_in(b2, "Strength", 0.35)
        set_in(b2, "Distance", 0.05)
        L(noise_tex(6.0, 12, 0.7).outputs["Fac"], b2.inputs["Height"])
        L(b1.outputs["Normal"], b2.inputs["Normal"])
        L(b2.outputs["Normal"], bsdf.inputs["Normal"])
        L(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return material(f"ground_{kind}", build)


def grass_material():
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        info = N("ShaderNodeHairInfo")
        r = N("ShaderNodeValToRGB")
        els = r.color_ramp.elements
        els[0].position, els[0].color = 0.0, lib.srgb((52, 70, 28))
        els[1].position, els[1].color = 1.0, lib.srgb((150, 136, 82))
        for pos, c in ((0.4, (76, 96, 40)), (0.7, (104, 112, 56))):
            e = els.new(pos)
            e.color = lib.srgb(c)
        L(info.outputs["Random"], r.inputs["Fac"])
        # darker at the root
        root = N("ShaderNodeMix")
        root.data_type = "RGBA"
        root.blend_type = "MULTIPLY"
        inv = N("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        L(info.outputs["Intercept"], inv.inputs[1])
        L(inv.outputs["Value"], root.inputs["Factor"])
        L(r.outputs["Color"], root.inputs["A"])
        root.inputs["B"].default_value = (0.45, 0.45, 0.4, 1)
        b = N("ShaderNodeBsdfPrincipled")
        L(root.outputs["Result"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.7
        L(b.outputs["BSDF"], out.inputs["Surface"])
    return material("grass", build)


def ground(layer, x0, x1, y0, y1, step, kind="field", amp=1.6, flat=None, grass=0, catcher=False):
    """A displaced ground strip with the scene's craters; `grass` = hair
    strands per square stud (parents; each grows children); `catcher`
    makes it a shadow catcher (the near layer's ground: only the shadows of
    what stands on it show, over the mid layer's ground)."""
    bm = bmesh.new()
    nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
    verts, scorch = [], []
    for j in range(ny):
        for i in range(nx):
            x, y = x0 + i * step, y0 + j * step
            z = height(x, y, amp)
            for fx, fy, fr in flat or []:
                d = math.hypot(x - fx, y - fy)
                if d < fr:
                    z *= (d / fr) ** 2
            verts.append(bm.verts.new((x, y, z - 0.15)))
            scorch.append(scorch_at(x, y))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            bm.faces.new((verts[a], verts[a + 1], verts[a + nx + 1], verts[a + nx]))
    me = bpy.data.meshes.new(f"ground_{layer}")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    at = me.attributes.new("scorch", "FLOAT", "POINT")
    at.data.foreach_set("value", scorch)
    o = bpy.data.objects.new(f"ground_{layer}", me)
    me.materials.append(ground_material(kind))
    link(o, layer)
    if catcher:
        o.is_shadow_catcher = True
    if grass and kind == "field":
        me.materials.append(grass_material())
        vg = o.vertex_groups.new(name="grass")
        for k, v in enumerate(me.vertices):
            patch = 0.5 + 0.5 * noise.noise(Vector((v.co.x / 9.0, v.co.y / 9.0, 3.0)))
            vg.add([k], max(0.0, min(1.0, patch * 1.6 - 0.2)) * (1 - min(1.0, scorch[k] * 1.6)), "REPLACE")
        mod = o.modifiers.new("grass", "PARTICLE_SYSTEM")
        ps = mod.particle_system
        ps.vertex_group_density = "grass"
        st = ps.settings
        st.type = "HAIR"
        st.count = int(grass * (x1 - x0) * (y1 - y0))
        st.hair_length = 0.3
        st.hair_step = 3
        st.render_step = 3
        st.display_step = 2
        st.use_advanced_hair = False
        st.factor_random = 0.4
        st.brownian_factor = 0.04
        st.child_type = "INTERPOLATED"
        st.rendered_child_count = 12
        st.child_length = 1.0
        st.child_length_threshold = 0.4
        st.child_radius = 0.6
        st.roughness_1 = 0.05
        st.roughness_endpoint = 0.12
        st.radius_scale = 0.025
        st.root_radius = 1.0
        st.tip_radius = 0.0
        st.material = 2
        st.use_rotations = True
        st.normal_factor = 1.0
        st.tangent_factor = 0.2
        st.object_align_factor = (0.0, 0.0, 0.0)
        st.hair_length = 0.3
    return o


def army(layer, faction, units, region, count, heading, seed, spread_heading=25, amp=0.0):
    """`count` units drawn from `units`, scattered in region (x0, x1, y0, y1)
    with a minimum spacing, facing about `heading`. Returns them as dicts
    (x, y, root) so firefight() can turn shooters onto their targets."""
    rng = random.Random(seed)
    x0, x1, y0, y1 = region
    placed = []
    tries = 0
    while len(placed) < count and tries < count * 60:
        tries += 1
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if any(math.hypot(x - u["x"], y - u["y"]) < 13 for u in placed) or any(math.hypot(x - ax, y - ay) < ar for ax, ay, ar in AVOID):
            continue
        uid = rng.choice(units)
        z = height(x, y, amp) - 0.15 if amp else 0.0
        root = place(uid, layer, x, y, heading + rng.uniform(-spread_heading, spread_heading), z=z)
        placed.append({"x": x, "y": y, "z": z, "root": root, "uid": uid})
    return placed


def muzzle_tip(unit, heading):
    """Turns the unit onto `heading` and returns its barrel tip: the vertex
    furthest forward among the upper half of the model (the gun overhangs
    the hull on every tank)."""
    root = unit["root"]
    root.rotation_euler.z = math.radians(-heading)
    bpy.context.view_layer.update()
    fwd = forward(heading)
    best, best_d = None, -1e9
    zs = []
    kids = [o for o in root.children if o.type == "MESH"]
    for o in kids:
        for v in o.data.vertices:
            zs.append((o.matrix_world @ v.co).z)
    if not zs:
        return Vector((unit["x"], unit["y"], unit["z"] + 3.0))
    zmid = (min(zs) + max(zs)) / 2
    for o in kids:
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co
            if w.z < zmid:
                continue
            d = w.dot(fwd)
            if d > best_d:
                best, best_d = w, d
    return best


def muzzle_flash(layer, tip, d, size, rgb, seed):
    """A tank gun firing: a white-hot flash ball at the muzzle, a forward
    tongue of flame, side jets from the muzzle brake, a strong light, and
    the blast kicking dust off the ground ahead."""
    rng = random.Random(seed)
    d = Vector(d).normalized()
    fire = fire_material("muzzlefire", strength=60.0, scale=2.2, cut=0.3)
    blob(layer, tip + d * size * 0.4, (size * 0.55,) * 3, fire, seed)
    blob_dir(layer, tip, d, size * rng.uniform(2.2, 3.4), size * 0.38, fire, seed + 1)
    side = d.cross(Vector((0, 0, 1))).normalized()
    for sgn in (1, -1):
        blob_dir(layer, tip + d * size * 0.2, side * sgn + d * 0.3, size * 1.3, size * 0.2, fire, seed + 2)
    core = prim("ico_sphere", layer, subdivisions=2, radius=size * 0.22, location=tip + d * size * 0.3)
    set_mat(core, emissive("muzzlecore", (255, 236, 200), 90.0))
    point(tip + d * size * 0.6, (255, 190, 120), 9000 * size, radius=size * 0.5, layer=layer)
    dust = volume_material("muzzledust", (168, 150, 120), 0.8, scale=1.2, cut=0.42)
    g = tip + d * size * 2.5
    blob(layer, (g.x, g.y, g.z - 2.0), (size * 2.2, size * 2.2, size * 0.7), dust, seed + 3)
    blob(layer, tip + d * size * 1.8 + Vector((0, 0, 0.5)), (size * 1.2,) * 3,
         volume_material("muzzlesmoke", (190, 184, 174), 0.6, scale=1.2, cut=0.42), seed + 4)


def firefight(layer, left, right, seed, colors=((255, 214, 140), (255, 110, 50)), shells=14, flashes=6, gun_z=3.0, burning=2):
    """Fire crossing between two groups, every shot different. A unit that
    has just fired is turned onto its target with a muzzle flash on its
    barrel tip; older rounds are shells in flight at random points of their
    flight with their own size and brightness; a few strike home in sparks;
    a few units already burn."""
    rng = random.Random(seed)
    fired = set()
    for k in range(shells):
        side = 0 if rng.random() < 0.5 else 1
        src = rng.choice(left if side == 0 else right)
        dst = rng.choice(right if side == 0 else left)
        c = tuple(min(255, int(ch * rng.uniform(0.85, 1.1))) for ch in colors[side])
        b = Vector((dst["x"] + rng.uniform(-6, 6), dst["y"] + rng.uniform(-6, 6), dst["z"] + gun_z * rng.uniform(0.2, 0.9)))
        just_fired = id(src) not in fired and len(fired) < flashes and rng.random() < 0.7
        if just_fired:
            fired.add(id(src))
            hd = math.degrees(math.atan2(dst["x"] - src["x"], dst["y"] - src["y"]))
            a = muzzle_tip(src, hd)
            d = (b - a).normalized()
            muzzle_flash(layer, a, d, rng.uniform(1.0, 1.6), c, seed + 300 + k)
            shell(layer, a, b, rng.uniform(0.08, 0.2), c, rng.uniform(0.5, 0.75), rng.uniform(40.0, 60.0))
            continue
        a = Vector((src["x"], src["y"], src["z"] + gun_z * rng.uniform(0.8, 1.2)))
        frac = rng.uniform(0.2, 1.0)
        if frac > 0.92:  # striking home
            sparks(layer, b, rng.uniform(1.2, 2.2), rng.randint(8, 14), seed + 500 + k, rgb=(255, 210, 140))
            point(b, (255, 180, 100), 8000, radius=0.6, layer=layer)
        else:
            shell(layer, a, b, frac, c, rng.uniform(0.35, 0.75), rng.uniform(25.0, 60.0))
    for k in range(burning):
        u = rng.choice(left + right)
        explosion(layer, (u["x"] + rng.uniform(-1, 1), u["y"] + rng.uniform(-1, 1), u["z"] + 1.2), rng.uniform(1.0, 1.6), smoke=1.2,
                  debris=False, seed=seed + 900 + k)


def battlefield_debris(layer, region, count, seed, amp=0.9):
    """Scattered wreckage: torn metal plates and chunks, some still burning
    and smoking, across the ground."""
    rng = random.Random(seed)
    x0, x1, y0, y1 = region
    metal = solid("scrap", (52, 50, 48), 0.6)
    dark = solid("scrap_dark", (26, 24, 22), 0.8)
    for k in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        z = height(x, y, amp) - 0.1
        s = rng.uniform(0.3, 1.2)
        o = shard(layer, (x, y, z + s * 0.1), s * 0.6, rng, metal if rng.random() < 0.5 else dark)
        o.rotation_euler = Euler((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.random() * 6.3))
        if rng.random() < 0.12:
            blob(layer, (x, y, z + 0.6), (0.7,) * 3, fire_material("smallfire", 60.0, scale=2.4, cut=0.35), seed + k)
            smoke_plume(layer, (x, y, z + 1.0), 0.9, dark=70, seed=seed + 50 + k)
            point((x, y, z + 1.0), (255, 140, 60), 1500, radius=0.4, layer=layer)


def blasts(layer, spots, seed, amp=0.9, old=0.0):
    """Ground explosions at `spots` (x, y, size), each sitting in its crater
    (added to CRATERS before the ground is built)."""
    rng = random.Random(seed)
    for k, (x, y, sz) in enumerate(spots):
        explosion(layer, (x, y, height(x, y, amp) - 0.2), sz, smoke=rng.uniform(0.7, 1.3), seed=seed + k * 13)


def add_craters(spots, extra, region, seed):
    """Craters under the blasts plus `extra` older shell holes in region."""
    rng = random.Random(seed)
    for x, y, sz in spots:
        CRATERS.append((x, y, sz * 0.9))
    x0, x1, y0, y1 = region
    for _ in range(extra):
        CRATERS.append((rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(1.2, 3.5)))


def cloud_deck(layer, z, y0, y1, cover=0.5, scale=0.0035, seed=0.0, tint=(246, 214, 176), shade=(96, 80, 76)):
    """A broken cloud layer: a huge plane at height z whose alpha is
    stretched fractal noise (cumulus clumps), white on top shading to a
    blue-grey underside where it is thick; translucent, so the sun glows
    through the thin edges."""
    def build(nt, out):
        N, L = nt.nodes.new, nt.links.new
        coord = N("ShaderNodeTexCoord")
        mp = N("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0, 2.2, 1.0)
        mp.inputs["Location"].default_value = (seed * 97.0, seed * 31.0, 0.0)
        L(coord.outputs["Object"], mp.inputs["Vector"])
        tex = N("ShaderNodeTexNoise")
        set_in(tex, "Scale", scale)
        set_in(tex, "Detail", 14.0)
        set_in(tex, "Roughness", 0.62)
        set_in(tex, "Lacunarity", 2.2)
        L(mp.outputs["Vector"], tex.inputs["Vector"])
        a = N("ShaderNodeMapRange")
        a.inputs["From Min"].default_value = 0.62 - cover * 0.2
        a.inputs["From Max"].default_value = 0.72 - cover * 0.2
        L(tex.outputs["Fac"], a.inputs["Value"])
        col = N("ShaderNodeValToRGB")
        e = col.color_ramp.elements
        e[0].position, e[0].color = 0.0, lib.srgb(tint)
        e[1].position, e[1].color = 1.0, lib.srgb(shade)
        L(a.outputs["Result"], col.inputs["Fac"])
        diff = N("ShaderNodeBsdfDiffuse")
        L(col.outputs["Color"], diff.inputs["Color"])
        tl = N("ShaderNodeBsdfTranslucent")
        tl.inputs["Color"].default_value = lib.srgb(tint)
        mixc = N("ShaderNodeMixShader")
        mixc.inputs["Fac"].default_value = 0.35
        L(diff.outputs["BSDF"], mixc.inputs[1])
        L(tl.outputs["BSDF"], mixc.inputs[2])
        tr = N("ShaderNodeBsdfTransparent")
        mixa = N("ShaderNodeMixShader")
        L(a.outputs["Result"], mixa.inputs["Fac"])
        L(tr.outputs["BSDF"], mixa.inputs[1])
        L(mixc.outputs["Shader"], mixa.inputs[2])
        L(mixa.outputs["Shader"], out.inputs["Surface"])
    me = bpy.data.meshes.new("clouds")
    bm = bmesh.new()
    for v in [(-6000, y0, z), (6000, y0, z), (6000, y1, z), (-6000, y1, z)]:
        bm.verts.new(v)
    bm.faces.new(bm.verts)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("clouds", me)
    me.materials.append(material(f"clouds_{z}_{seed}", build))
    o.visible_shadow = False
    return link(o, layer)


def cumulus(layer, pos, size, seed, density=0.12):
    """A towering cumulus: a cluster of soft white volumes, flat-bottomed,
    heaped higher in the middle."""
    rng = random.Random(seed)
    mat = volume_material("cumulus", (250, 226, 200), density, scale=2.6, cut=0.48)
    p = Vector(pos)
    for k in range(rng.randint(14, 22)):
        ox = rng.uniform(-1, 1) * size * 0.9
        heap = 1.0 - abs(ox) / size  # taller toward the middle
        oz = rng.uniform(0, 1) ** 1.5 * size * 0.9 * heap
        s = size * rng.uniform(0.18, 0.34) * (0.6 + 0.6 * heap)
        blob(layer, p + Vector((ox, rng.uniform(-0.3, 0.3) * size, oz + s * 0.6)), (s, s * 0.9, s * 0.8), mat, seed * 10 + k)


def smoke_column(layer, base, height_, width, seed, drift=(0.25, 0.1), dark=None, light=None):
    """A smoke column from a big fire, each one its own: how fast it widens,
    how hard and which way it leans (around `drift`), a slow sway, whether it
    spreads into a flattened top, sooty black or browner and greyer; the
    fire at its foot."""
    rng = random.Random(seed)
    p = Vector(base)
    shade = rng.uniform(0.0, 1.0)
    dark = dark or tuple(int(c + 22 * shade) for c in (24, 21, 19))
    light = light or tuple(int(c + 40 * shade) for c in (84, 78, 72))
    mats = [volume_material(f"column_{k}_{dark}", tuple(int(dark[i] + (light[i] - dark[i]) * k / 3) for i in range(3)),
                            (1.9 - 0.3 * k) * rng.uniform(0.75, 1.1), scale=rng.uniform(1.8, 2.6), cut=0.28,
                            anisotropy=0.5, soft=0.7, vary=0.55) for k in range(4)]
    grow = rng.uniform(1.2, 2.8)
    lean = rng.uniform(0.6, 1.4)
    turn = rng.uniform(-0.5, 0.5)  # radians off the wind
    dx = drift[0] * math.cos(turn) - drift[1] * math.sin(turn)
    dy = drift[0] * math.sin(turn) + drift[1] * math.cos(turn)
    anvil = rng.random() < 0.4
    phase = rng.uniform(0, 100)
    fs, f = [], 0.0
    while f < 1.0:
        fs.append(f)
        f += width * (0.6 + grow * f) * 0.35 / height_
    for k, f in enumerate(fs):
        r = width * (0.6 + grow * f)
        sway = Vector((noise.noise(Vector((f * 2.5 + phase, 0, 0))), noise.noise(Vector((0, f * 2.5 + phase, 0))), 0)) * width * 2.5 * f
        c = p + Vector((dx * lean * height_ * f * f, dy * lean * height_ * f * f, height_ * f)) + sway
        c += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.5, 0.5))) * r * 0.45
        flat = 0.85
        if anvil and f > 0.75:  # the top spreading out
            r *= 1.0 + (f - 0.75) * 2.4
            flat = 0.55
        blob(layer, c, (r, r * rng.uniform(0.85, 1.1), r * flat), mats[min(3, int(f * 4))], seed * 100 + k)
    blob(layer, p + Vector((0, 0, width * 0.4)), (width * 0.8, width * 0.8, width * 0.6),
         fire_material("columnfire", 70.0, scale=2.0 / max(width / 4.0, 0.5), cut=0.36), seed)
    point(p + Vector((0, 0, width)), (255, 140, 60), 6000 * width, radius=width * 0.5, layer=layer)


def ground_fire(layer, center, spread, count, seed, amp=0.9):
    """Burning grass and fuel: low, wide tongues of flame scattered over the
    ground, wisps of smoke, a few lights."""
    rng = random.Random(seed)
    fire = fire_material("grassfire", 22.0, scale=2.6, cut=0.38)
    wisp = volume_material("wisp", (120, 114, 108), 0.5, scale=1.4, cut=0.42)
    cx, cy = center
    for k in range(count):
        x, y = cx + rng.uniform(-spread[0], spread[0]), cy + rng.uniform(-spread[1], spread[1])
        z = height(x, y, amp) - 0.1
        r = rng.uniform(0.5, 1.4)
        blob(layer, (x, y, z + r * 0.5), (r * rng.uniform(1.0, 1.8), r, r * rng.uniform(0.8, 1.6)), fire, seed + k)
        if rng.random() < 0.5:
            blob(layer, (x + rng.uniform(0, 2), y, z + r * 2.5), (r * 1.8,) * 3, wisp, seed + 50 + k)
        if k % 3 == 0:
            point((x, y, z + 1.0), (255, 140, 60), 1500 * r, radius=r, layer=layer)
    embers(layer, (cx, cy, height(cx, cy, amp) + 1.5), (spread[0], spread[1], 5), count * 3, seed=seed + 99)


def ember_field(layer, region, count, seed):
    """Embers and sparks drifting through the air across the scene, some
    streaked by motion."""
    rng = random.Random(seed)
    x0, x1, y0, y1, z0, z1 = region
    m = [emissive(f"ember{k}", c, s) for k, (c, s) in enumerate((((255, 120, 40), 8.0), ((255, 160, 70), 12.0), ((240, 90, 30), 5.0)))]
    for k in range(count):
        p = Vector((rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(z0, z1)))
        if rng.random() < 0.3:
            d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 1.5))).normalized()
            tracer(layer, p, p + d * rng.uniform(0.3, 0.9), (255, 140, 60), width=rng.uniform(0.012, 0.03), strength=10.0)
        else:
            o = prim("ico_sphere", layer, subdivisions=1, radius=rng.uniform(0.02, 0.07), location=p)
            set_mat(o, m[k % 3])


def grass_tufts(layer, region, count, seed, amp=0.9, length=0.9):
    """Tall grass tufts for the foreground: clumps of long strands on
    invisible discs, to frame the bottom of the picture."""
    rng = random.Random(seed)
    x0, x1, y0, y1 = region
    bm = bmesh.new()
    for _ in range(count):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(0.8, 2.6)
        ring = []
        for k in range(10):
            a = k / 10 * 2 * math.pi
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            ring.append(bm.verts.new((x, y, height(x, y, amp) - 0.12)))
        c = bm.verts.new((cx, cy, height(cx, cy, amp) - 0.12))
        for k in range(10):
            bm.faces.new((c, ring[k], ring[(k + 1) % 10]))
    me = bpy.data.meshes.new("tufts")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("tufts", me)
    clear = material("tuft_clear", lambda nt, out: nt.links.new(nt.nodes.new("ShaderNodeBsdfTransparent").outputs["BSDF"], out.inputs["Surface"]))
    me.materials.append(clear)
    me.materials.append(grass_material())
    link(o, layer)
    mod = o.modifiers.new("tufts", "PARTICLE_SYSTEM")
    st = mod.particle_system.settings
    st.type = "HAIR"
    st.count = count * 120
    st.hair_length = length
    st.hair_step = 4
    st.render_step = 4
    st.use_advanced_hair = False
    st.factor_random = 0.5
    st.brownian_factor = 0.06
    st.child_type = "INTERPOLATED"
    st.rendered_child_count = 10
    st.child_radius = 0.4
    st.roughness_1 = 0.08
    st.roughness_endpoint = 0.25
    st.radius_scale = 0.03
    st.root_radius = 1.0
    st.tip_radius = 0.0
    st.material = 2
    st.normal_factor = 1.0
    st.tangent_factor = 0.35
    st.use_rotations = True
    st.rotation_factor_random = 0.3
    st.hair_length = length
    return o


AVOID = []  # (x, y, r): spots army() keeps clear (set pieces: exploding tanks)


def extreme(root, direction, upper=None):
    """The model's vertex furthest along `direction` (world), optionally
    only from the upper (True) or lower (False) half of the model."""
    bpy.context.view_layer.update()
    d = Vector(direction).normalized()
    kids = [o for o in root.children_recursive if o.type == "MESH"]
    pts = [o.matrix_world @ v.co for o in kids for v in o.data.vertices]
    if not pts:
        return root.location.copy()
    if upper is not None:
        zs = [q.z for q in pts]
        zmid = (min(zs) + max(zs)) / 2
        pts = [q for q in pts if (q.z >= zmid) == upper] or pts
    return max(pts, key=lambda q: q.dot(d))


def flak_stream(layer, a, b, seed, rgb=(255, 170, 90)):
    """A burst of tracer rounds from a gun: short glowing dashes spaced
    along the line of fire, fading and thinning with distance, with a
    slight spread."""
    rng = random.Random(seed)
    a, b = Vector(a), Vector(b)
    d = b - a
    n = rng.randint(6, 10)
    for k in range(n):
        f = (k + rng.uniform(0.2, 0.8)) / n
        p = a + d * f + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * f * 2.0
        tracer(layer, p, p + d.normalized() * rng.uniform(1.5, 2.6), rgb, width=0.09 * (1.2 - 0.5 * f), strength=36.0 * (1.1 - 0.6 * f))


def ground_haze(layer, region, count, seed, amp=0.9, rgb=(196, 186, 172), density=0.14, size=(14, 34)):
    """Low banks of drifting battlefield smoke and dust hugging the ground,
    soft and thin, wider than tall, half-hiding what stands in them."""
    rng = random.Random(seed)
    mat = volume_material(f"haze_{rgb}_{density}", rgb, density, scale=1.4, cut=0.3)
    x0, x1, y0, y1 = region
    for k in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        sx = rng.uniform(*size)
        blob(layer, (x, y, height(x, y, amp) + sx * 0.08), (sx, sx * rng.uniform(0.35, 0.6), sx * rng.uniform(0.1, 0.18)), mat, seed + k)


def hero_jet(layer, uid, pos, heading, pitch, bank, seed, missiles=None):
    """An aircraft close to the camera, banking and diving at an angle:
    afterburner flames and glow at the engines, white vapour streaming from
    the wingtips, and optionally missiles just fired from under it
    (list of (target, team, mesh id))."""
    p = Vector(pos)
    root = place(uid, layer, p.x, p.y, heading, z=p.z, tilt=(pitch, bank))
    bpy.context.view_layer.update()
    rot = root.matrix_world.to_3x3().normalized()
    fwd, right = rot @ Vector((0, 1, 0)), rot @ Vector((1, 0, 0))
    tail = extreme(root, -fwd)
    fire = fire_material("afterburner", strength=90.0, scale=2.6, cut=0.26)
    for k in range(3):
        blob_dir(layer, tail - fwd * k * 0.6, -fwd, 2.6 - k * 0.5, 0.45 - k * 0.08, fire, seed + k)
    core = prim("ico_sphere", layer, subdivisions=2, radius=0.35, location=tail - fwd * 0.3)
    set_mat(core, emissive("burner_core", (255, 236, 200), 120.0))
    point(tail - fwd * 1.5, (255, 170, 90), 9000, radius=0.6, layer=layer)
    vapour = volume_material("vapour", (246, 248, 252), 0.9, scale=2.4, cut=0.3)
    for side in (1, -1):
        tip = extreme(root, right * side)
        pts = [tip - fwd * (k * 3.0) + Vector((0, 0, -0.02 * k * k)) for k in range(12)]
        pts.reverse()
        trail(layer, [tuple(q) for q in pts], 0.18, seed=seed + 10 + side, smoke=vapour, flame=False)
    for k, (target, team, mid) in enumerate(missiles or []):
        start = p - Vector((0, 0, 1.0)) + right * (1.6 if k % 2 else -1.6)
        tgt = Vector(target)
        pts = [start.lerp(tgt, f) + Vector((0, 0, -4 * f * (1 - f))) for f in [i / 10 * 0.35 for i in range(11)]]
        trail(layer, [tuple(q) for q in pts], 0.5, seed=seed + 20 + k, missile=mid, team=team)
    return root


def tank_explode(layer, uid, x, y, heading, seed, amp=0.9, size=3.4):
    """A tank's catastrophic kill: the turret blown off and tumbling up out
    of the fireball, an ammunition fire jetting from the open turret ring,
    burning fragments flying, black smoke boiling up."""
    rng = random.Random(seed)
    AVOID.append((x, y, 14.0))
    z = height(x, y, amp) - 0.15
    root = place(uid, layer, x, y, heading, z=z)
    bpy.context.view_layer.update()
    kids = [o for o in root.children if o.type == "MESH"]
    top = [o for o in kids if any(k in o.name.lower() for k in ("turret", "barrel", "gun", "cannon", "mantlet", "sleeve"))]
    ring = Vector((x, y, z + 2.5))
    if top:
        pts = [o.matrix_world @ Vector(c) for o in top for c in o.bound_box]
        piv = sum(pts, Vector()) / len(pts)
        ring = Vector((piv.x, piv.y, min(q.z for q in pts)))
        toss = bpy.data.objects.new("turret_toss", None)
        link(toss, layer)
        toss.location = piv
        bpy.context.view_layer.update()
        for o in top:
            mw = o.matrix_world.copy()
            o.parent = toss
            o.matrix_world = mw
        lift = Vector((rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5), rng.uniform(6.0, 9.0)))
        toss.location = piv + lift
        toss.rotation_euler = Euler((rng.uniform(-0.9, 0.9), rng.choice((-1, 1)) * rng.uniform(0.5, 1.1), rng.uniform(-0.8, 0.8)))
        trail(layer, [tuple(piv), tuple(piv + lift * 0.9)], 0.9, seed=seed + 1,
              smoke=volume_material("toss_smoke", (40, 36, 32), 1.6, scale=2.0, cut=0.32), flame=False)
        blob(layer, piv + lift - Vector((0, 0, 0.8)), (1.0, 1.0, 1.0), fire_material("toss_fire", 70.0, scale=2.4, cut=0.3), seed + 2)
    fire = fire_material("cookoff", strength=110.0, scale=2.2, cut=0.26)
    for k in range(rng.randint(3, 5)):  # ammunition fire jetting up from the turret ring
        d = Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 1.0))
        blob_dir(layer, ring, d, size * rng.uniform(1.6, 2.8), size * rng.uniform(0.18, 0.3), fire, seed + 10 + k)
    explosion(layer, (x, y, z + 0.8), size, smoke=1.6, debris=True, seed=seed + 20)
    for k in range(rng.randint(6, 10)):  # burning fragments
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.4, 1.4))).normalized()
        debris_trail(layer, ring, d * rng.uniform(2.0, 4.0), seed + 40 + k, steps=rng.randint(3, 6),
                     width=rng.uniform(0.25, 0.45), fire=rng.random() < 0.8)
    sparks(layer, ring, size, 16, seed + 60)
    point(ring + Vector((0, 0, 2.0)), (255, 160, 80), 60000, radius=size, layer=layer)
    smoke_column(layer, (x, y, z + 1.0), 45.0, 3.0, seed + 70)


LAND_ORDER = ["ord_paladin", "ord_lancer", "ord_lancer", "ord_warden", "ord_verdict", "ord_herald"]
LAND_CHAOS = ["chs_minotaur", "chs_ravager", "chs_ravager", "chs_juggernaut", "chs_hellmouth", "chs_jackal"]


def daylight(scene, elevation, azimuth, sky_strength=0.3, sun_energy=4.5):
    """Afternoon over a battle: the sun lower, warm through the dust and
    smoke, from the side and behind the camera so the units' near faces
    are lit and the team colours read; a cooler fill from the other side.
    The sky itself is dust-laden and graded to orange in post."""
    elevation = min(elevation, 20.0)
    sky(scene, elevation=elevation, azimuth=azimuth, strength=sky_strength, dusty=True)
    sun(elevation, azimuth, sun_energy, (255, 206, 150), angle=1.5)
    fill(0.7, (160, 168, 200), azimuth=azimuth + 160, elevation=40.0)


def land_battle(scene):
    AVOID.clear()
    """1. A daytime land battle by the coast: tank armies trading fire across
    cratered fields, an air battle above with SAMs from both sides chasing
    aircraft and helicopters (some just hit), the fleets fighting offshore.
    Camera 20 up at y = -38: near layer y < 22 (shadow-catcher ground over
    the mid layer's), mid 22-152, far 150-268, sky beyond (coast ~255-290,
    fleets 340-560)."""
    CRATERS.clear()
    daylight(scene, 30.0, 118.0)
    cam_rig(scene, 20.0, 0.34, 30, y=-38.0)
    mid_blasts = [(-4, 68, 3.6), (30, 84, 2.8), (-52, 104, 3.2), (60, 70, 3.0), (-30, 52, 2.4), (14, 120, 3.4),
                  (-84, 76, 2.6), (88, 112, 3.2), (-18, 140, 2.8), (46, 40, 2.2), (-66, 36, 2.0)]
    far_blasts = [(-80, 220, 4.5), (120, 250, 5.0), (10, 245, 4.0), (-150, 240, 3.5), (60, 200, 3.8), (-30, 190, 3.2),
                  (180, 215, 4.0)]
    add_craters(mid_blasts, 40, (-140, 140, -10, 150), seed=1)
    add_craters(far_blasts, 30, (-260, 260, 152, 265), seed=2)
    # sky: the coast, the sea, the naval battle
    sea("sky", 262.0, (30, 66, 86))
    ground("sky", -500, 500, 250, 292, 4, "beach", amp=0.6)
    fleet("sky", [("ord_dominion", -210, 360, 80), ("ord_crusader", -130, 430, 70), ("ord_sanctuary", -40, 500, 85),
                  ("ord_crusader", -260, 450, 75), ("ord_harbormaster", -320, 380, 95), ("chs_kraken", 110, 380, -95),
                  ("chs_corsair", 190, 450, -110), ("chs_leviathan", 60, 540, -90), ("chs_kraken", 280, 410, -100),
                  ("chs_corsair", 20, 420, -80)], seed=7)
    cloud_deck("sky", 520.0, 300.0, 9000.0, cover=0.75, seed=8.0)
    cloud_deck("sky", 300.0, 300.0, 6000.0, cover=0.45, scale=0.006, seed=8.5)
    smoke_column("sky", (-206, 360, 3), 260, 12, 810)  # burning ships and the coast
    smoke_column("sky", (110, 380, 3), 300, 14, 811)
    smoke_column("sky", (-360, 275, 1), 220, 10, 812, drift=(0.35, 0.05))
    smoke_column("sky", (330, 268, 1), 240, 11, 813)
    # far: far fields with tanks, the air battle, SAMs chasing
    ground("far", -300, 300, 150, 268, 2.0, "field", amp=1.4)
    lf = army("far", "order", LAND_ORDER, (-220, -30, 170, 255), 8, 60, seed=101, amp=1.4)
    rf = army("far", "chaos", LAND_CHAOS, (30, 220, 170, 255), 8, -120, seed=102, amp=1.4)
    firefight("far", lf, rf, seed=103, shells=8, flashes=5, burning=2)
    for k, u in enumerate((lf[1], rf[2], rf[5])):
        smoke_column("far", (u["x"], u["y"], u["z"] + 1), 110, 6, 820 + k)
    rng = random.Random(825)
    for k in range(6):  # flak in the sky
        burst("far", (rng.uniform(-200, 200), rng.uniform(180, 300), rng.uniform(50, 90)), rng.uniform(1.5, 2.5), seed=826 + k)
    blasts("far", far_blasts, 300, amp=1.4)
    tank_explode("far", "chs_ravager", 90, 230, -110, 852, amp=1.4, size=4.0)
    ground_haze("far", (-300, 300, 160, 265), 12, 853, amp=1.4, size=(30, 60))
    battlefield_debris("far", (-260, 260, 155, 262), 40, seed=104, amp=1.4)
    order_craft = [("ord_falcon", 60, 250, 62, 70, -30, 4.0), ("ord_archon", 120, 210, 48, 40, 25, 3.5),
                   ("ord_absolution", 20, 300, 74, 100, 0, 3.0), ("ord_guardian", 90, 175, 22, 110, 0, 1.4),
                   ("ord_guardian", 150, 195, 28, 80, 0, 1.4)]
    chaos_craft = [("chs_harpy", -60, 240, 58, -110, 35, 4.0), ("chs_manticore", -140, 280, 66, -70, -20, 3.5),
                   ("chs_plague", -20, 310, 76, -95, 0, 3.0), ("chs_wasp", -110, 180, 20, -140, 0, 1.4),
                   ("chs_wasp", -170, 205, 26, -100, 0, 1.4)]
    order_air = flyers("far", order_craft)
    chaos_air = flyers("far", chaos_craft)
    o_sites = [(-150, 200, 2), (-90, 190, 2), (-40, 230, 2), (-180, 250, 2), (-70, 255, 2), (-120, 170, 2)]
    c_sites = [(150, 210, 2), (100, 200, 2), (60, 250, 2), (190, 240, 2), (120, 255, 2), (170, 175, 2)]
    for i, (site, tgt, cut, kw) in enumerate([
            (o_sites[0], chaos_air[0], 0.75, {"turn": 8.0}), (o_sites[1], chaos_air[1], 0.6, {"weave": 0.5, "turn": 12.0}),
            (o_sites[2], chaos_air[2], 0.85, {"turn": 14.0, "tilt": 1.2}), (o_sites[3], chaos_air[3], 0.7, {"turn": 7.0, "tilt": 0.5}),
            (o_sites[4], chaos_air[1], 0.4, {"tilt": 1.0})]):
        sam("far", site, tgt, 200 + i, "ord_ir_sam" if i % 2 else "ord_radar_sam", "order", cut=cut, **kw)
    for i, (site, tgt, cut, kw) in enumerate([
            (c_sites[0], order_air[0], 0.7, {"turn": 9.0, "weave": 0.4}), (c_sites[1], order_air[1], 0.8, {"tilt": 1.1, "turn": 12.0}),
            (c_sites[2], order_air[2], 0.55, {"turn": 7.0}), (c_sites[3], order_air[4], 0.75, {"turn": 13.0}),
            (c_sites[4], order_air[0], 0.35, {"tilt": 0.5})]):
        sam("far", site, tgt, 220 + i, "chs_ir_sam" if i % 2 else "chs_radar_sam", "chaos", cut=cut, **kw)
    # two aircraft blowing apart this instant
    kill("far", o_sites[5], ("chs_harpy", -40, 200, 46, -120, 40, 4.0), 260, "order", turn=11.0, tilt=0.9)
    kill("far", c_sites[5], ("ord_falcon", 110, 230, 56, 60, -30, 4.0), 270, "chaos", turn=10.0, tilt=1.0)
    rng = random.Random(9)
    for i in range(6):  # artillery rounds on their arcs, each at its own moment
        a = (rng.choice((-1, 1)) * rng.uniform(150, 280), rng.uniform(240, 300), 2)
        b = (rng.uniform(-120, 120), rng.uniform(40, 220), 0)
        pts = arc(a, b, rng.uniform(60, 120), 16)
        j = rng.randint(3, 13)
        shell("far", pts[j], pts[j + 1], 0.5, (255, 200, 140), rng.uniform(0.7, 1.1), rng.uniform(40.0, 60.0))
    # mid: the main tank fight
    ground("mid", -160, 160, -12, 152, 0.8, "field", amp=0.9, grass=0.5)
    tank_explode("mid", "chs_minotaur", 26, 62, -130, 850)
    tank_explode("mid", "ord_paladin", -58, 96, 50, 851)
    lm = army("mid", "order", LAND_ORDER, (-115, -12, 34, 145), 11, 55, seed=111, amp=0.9)
    rm = army("mid", "chaos", LAND_CHAOS, (12, 115, 38, 145), 11, -125, seed=112, amp=0.9)
    place("ord_seraph", "mid", -60, 140, 20, z=height(-60, 140, 0.9) - 0.15)
    place("chs_gorgon", "mid", 70, 146, -30, z=height(70, 146, 0.9) - 0.15)
    firefight("mid", lm, rm, seed=113, shells=16, flashes=10, burning=3)
    blasts("mid", mid_blasts, 400, amp=0.9)
    battlefield_debris("mid", (-140, 140, 20, 150), 90, seed=114, amp=0.9)
    ground_fire("mid", (-40, 60), (10, 6), 10, 830)
    ground_fire("mid", (40, 96), (8, 5), 8, 831)
    ground_fire("mid", (-80, 120), (10, 5), 8, 832)
    smoke_column("mid", (rm[0]["x"], rm[0]["y"], rm[0]["z"] + 1), 70, 4, 833)
    ember_field("mid", (-120, 120, 20, 140, 0, 25), 300, 834)
    ground_haze("mid", (-160, 160, 30, 150), 16, 835)
    hero_jet("mid", "ord_falcon", (-22, 24, 24), 160, -14, -38, 836,
             missiles=[((40, 140, 2), "order", "ord_ir_sam")])
    smoke_plume("mid", (52, 134, height(52, 134, 0.9)), 4.0, dark=110, seed=13)
    # near: burning wrecks, debris, a blast close by, smoke, embers
    ground("near", -80, 80, -12, 24, 0.8, "field", amp=0.9, catcher=True)
    place("chs_ravager", "near", -15, 14, 200, z=height(-15, 14, 0.9) + 0.1, wreck=True, tilt=(5, -10))
    place("ord_lancer", "near", 19, 17, 150, z=height(19, 17, 0.9), wreck=True, tilt=(-4, 6))
    battlefield_debris("near", (-40, 40, 6, 22), 40, seed=115, amp=0.9)
    smoke_plume("near", (-15, 17, height(-15, 17, 0.9) + 1), 3.0, dark=70, seed=21)
    explosion("near", (-14, 15, height(-14, 15, 0.9) + 1.4), 1.2, smoke=0.5, debris=False, seed=22)
    explosion("near", (34, 21, height(34, 21, 0.9)), 3.0, smoke=1.0, seed=24)
    embers("near", (-12, 15, 2), (6, 4, 7), 30, seed=23)
    ground_fire("near", (-28, 12), (6, 3), 8, 840)
    grass_tufts("near", (-45, 45, 4, 14), 26, 841)
    ember_field("near", (-35, 35, 6, 26, 0, 14), 220, 842)


def sam_site(scene):
    AVOID.clear()
    """2. An Order SAM site under a Chaos air raid in daylight: the camera
    low so the sky fills most of the frame, every launcher's missile on its
    own curving chase after a different bomber, fighter or helicopter, three
    aircraft blowing apart, bombs bursting across the site."""
    CRATERS.clear()
    daylight(scene, 34.0, 125.0, sky_strength=0.28)
    cam_rig(scene, 7.0, 0.58, 26)
    site_blasts = [(-22, 80, 3.6), (24, 112, 4.2), (52, 90, 3.0), (-70, 130, 3.4), (80, 140, 3.8), (-4, 144, 3.0),
                   (-44, 60, 2.6), (36, 48, 2.2), (110, 90, 3.0), (-110, 96, 3.2)]
    add_craters(site_blasts, 30, (-160, 160, 10, 160), seed=3)
    # sky: hills with smoke rising from earlier strikes
    ground("sky", -520, 520, 300, 520, 10, "field", amp=12.0)
    cloud_deck("sky", 520.0, 300.0, 9000.0, cover=0.75, seed=9.0)
    cloud_deck("sky", 300.0, 300.0, 6000.0, cover=0.45, scale=0.006, seed=9.5)
    for i, (x, y) in enumerate(((-170, 360), (190, 400))):
        smoke_column("sky", (x, y, height(x, y, 12.0)), 240, 11, 900 + i)
    ground("far", -400, 400, 155, 315, 3.0, "field", amp=3.0)
    # far: the raid
    raid = flyers("far", [("chs_plague", -40, 210, 70, 170, 10, 3.0), ("chs_behemoth", 50, 240, 88, 200, -12, 2.6),
                          ("chs_plague", 130, 230, 76, 190, 15, 3.0), ("chs_behemoth", -140, 250, 84, 160, -10, 2.6),
                          ("chs_harpy", 95, 170, 52, 130, 35, 4.2), ("chs_harpy", -110, 190, 60, 220, -30, 4.2),
                          ("chs_manticore", 20, 160, 46, 250, 40, 3.8), ("chs_banshee", -60, 280, 96, 180, 0, 3.0),
                          ("chs_wasp", -70, 140, 24, 175, 0, 1.4), ("chs_wasp", 70, 130, 20, 200, 0, 1.4),
                          ("chs_wasp", 150, 160, 28, 210, 0, 1.4)])
    launchers = [(-14, 92, 4), (14, 100, 4), (30, 96, 4), (-30, 104, 4), (-60, 100, 4), (46, 106, 4), (0, 118, 5), (90, 96, 4)]
    shots = [  # launcher, target, how far along, flight character
        (0, 0, 0.8, {"turn": 8.0}), (1, 1, 0.65, {"tilt": 1.1}), (2, 4, 0.9, {"turn": 14.0}),
        (3, 5, 0.75, {"turn": 11.0}), (4, 3, 0.55, {"tilt": 1.2, "turn": 7.0}), (5, 2, 0.7, {"turn": 9.0}),
        (7, 10, 0.85, {"turn": 12.0}), (5, 6, 0.95, {"turn": 14.0, "weave": 0.35})]
    for i, (li, ti, cut, kw) in enumerate(shots):
        sam("far", launchers[li], raid[ti], 300 + i, "ord_radar_sam" if i % 3 == 1 else "ord_ir_sam", "order",
            width=2.4, cut=cut, **kw)
    kill("far", launchers[1], ("chs_harpy", -20, 150, 50, 200, -40, 4.2), 330, "order", turn=12.0, tilt=0.9)
    kill("far", launchers[6], ("chs_plague", 90, 210, 72, 180, 10, 3.0), 340, "order", turn=9.0, tilt=0.7)
    kill("far", launchers[4], ("chs_wasp", -110, 150, 26, 160, 0, 1.4), 350, "order", turn=12.0, tilt=1.2)
    rng = random.Random(360)
    for k in range(10):  # flak from the gun towers: streams of tracer rounds
        x0, y0 = rng.uniform(-60, 60), rng.uniform(88, 112)
        flak_stream("far", (x0, y0, 3), (x0 + rng.uniform(-50, 50), y0 + rng.uniform(40, 90), rng.uniform(40, 90)), 600 + k)
    for k in range(7):  # flak bursts
        burst("far", (rng.uniform(-140, 140), rng.uniform(150, 280), rng.uniform(45, 95)), rng.uniform(1.4, 2.4), seed=600 + k)
    # mid: the SAM site, bombs bursting across it
    ground("mid", -180, 180, -6, 160, 0.8, "field", amp=0.6, grass=0.5)
    site = [("ord_vigil", -14, 92, 160), ("ord_halo", 14, 100, 200), ("ord_seraph", 30, 96, 230), ("ord_vigil", -30, 104, 140),
            ("ord_seraph", -60, 100, 150), ("ord_halo", 46, 106, 210), ("ord_citadel", 0, 124, 180),
            ("ord_vigil", 90, 96, 210), ("ord_watchtower", -46, 128, 170), ("ord_bulwark", 70, 120, 200),
            ("ord_lancer", 110, 116, 230), ("ord_lancer", -90, 116, 140), ("ord_paladin", -120, 130, 120)]
    for uid, x, y, hd in site:
        place(uid, "mid", x, y, hd, z=height(x, y, 0.6) - 0.15)
    blasts("mid", site_blasts, 380, amp=0.6)
    tank_explode("mid", "ord_lancer", 64, 72, 220, 950, amp=0.6)
    ground_haze("mid", (-170, 170, 20, 160), 14, 951, amp=0.6)
    hero_jet("mid", "chs_manticore", (-26, 30, 20), 150, -22, 34, 952,
             missiles=[((-10, 110, 2), "chaos", "chs_ir_sam"), ((10, 120, 2), "chaos", "chs_ir_sam")])
    battlefield_debris("mid", (-150, 150, 20, 150), 80, seed=381, amp=0.6)
    ground_fire("mid", (-30, 70), (10, 6), 10, 910, amp=0.6)
    ground_fire("mid", (60, 84), (8, 5), 8, 911, amp=0.6)
    for i, (x, y) in enumerate(((24, 112), (-70, 130))):
        smoke_column("mid", (x, y, height(x, y, 0.6)), 80, 4, 912 + i)
    ember_field("mid", (-120, 120, 10, 140, 0, 30), 300, 914)
    for li in (0, 2, 5, 7):
        x, y, z = launchers[li]
        muzzle_flash("mid", Vector((x, y, z)), (0, 0.3, 1), 1.4, (255, 220, 170), 390 + li)
    # near: a downed Chaos helicopter burning, debris, embers
    ground("near", -60, 60, -6, 30, 0.8, "field", amp=0.6, catcher=True)
    place("chs_wasp", "near", -14, 22, 120, z=height(-14, 22, 0.6), wreck=True, tilt=(8, 18))
    explosion("near", (-14, 22, height(-14, 22, 0.6) + 1.0), 1.6, smoke=0.6, debris=False, seed=50)
    battlefield_debris("near", (-30, 30, 4, 28), 30, seed=51, amp=0.6)
    embers("near", (-12, 22, 2), (6, 4, 8), 34, seed=52)
    ground_fire("near", (22, 12), (6, 3), 8, 920, amp=0.6)
    grass_tufts("near", (-40, 40, 0, 9), 26, 921, amp=0.6)
    ember_field("near", (-30, 30, 2, 28, 0, 12), 220, 922)


def beach_assault(scene):
    AVOID.clear()
    """3. A daytime beach assault: the Order fleet shelling the Chaos beach
    line and landing amphibious tanks, the defenders firing back, aircraft
    and SAMs overhead; the sun high to the left behind the camera."""
    CRATERS.clear()
    daylight(scene, 36.0, -128.0)
    cam_rig(scene, 14.0, 0.38, 30)
    beach_blasts = [(-16, 66, 3.4), (30, 62, 2.8), (-70, 56, 3.0), (80, 70, 2.6), (4, 44, 2.4), (-40, 40, 2.8),
                    (56, 46, 3.2), (-100, 70, 2.6), (110, 50, 2.8), (-6, 30, 2.0)]
    add_craters(beach_blasts, 30, (-150, 150, 14, 90), seed=4)
    # sky: the fleet offshore, every gun firing at its own time and target
    sea("sky", 92.0, (26, 66, 82))
    beach_targets = [(x, y, 0) for x, y, _ in beach_blasts]
    fleet("sky", [("ord_dominion", -150, 330, 190), ("ord_sanctuary", 30, 420, 185), ("ord_crusader", 150, 300, 170),
                  ("ord_dominion", 260, 380, 175), ("ord_crusader", -60, 360, 195), ("ord_crusader", 90, 360, 180),
                  ("ord_harbormaster", -240, 300, 200)], seed=8, targets=beach_targets)
    cloud_deck("sky", 520.0, 300.0, 9000.0, cover=0.75, seed=10.0)
    cloud_deck("sky", 300.0, 300.0, 6000.0, cover=0.45, scale=0.006, seed=10.5)
    smoke_column("sky", (30, 420, 3), 260, 12, 1010)  # a hit ship
    smoke_column("sky", (-300, 220, 1), 220, 10, 1011, drift=(0.3, 0.05))
    # far: landing craft and amphibious tanks in the surf, aircraft, SAMs
    for uid, x, y, hd in (("ord_tidewright", -70, 150, 190), ("ord_harbormaster", 60, 168, 175), ("ord_tidewright", 120, 140, 185),
                          ("ord_tideguard", -110, 120, 195), ("ord_tideguard", -20, 115, 180), ("ord_tideguard", 30, 125, 185),
                          ("ord_tideguard", 90, 112, 190)):
        place(uid, "far", x, y, hd, z=-0.6)
    order_air = flyers("far", [("ord_archon", -40, 140, 46, 160, 30, 3.6), ("ord_falcon", 70, 120, 36, 200, -20, 4.0),
                               ("ord_falcon", -120, 180, 50, 170, 15, 4.0), ("ord_guardian", -150, 140, 22, 190, 0, 1.4),
                               ("ord_guardian", 140, 160, 26, 175, 0, 1.4)])
    chaos_air = flyers("far", [("chs_manticore", 10, 170, 60, 20, 40, 3.8), ("chs_harpy", 120, 200, 54, 10, -30, 4.2),
                               ("chs_wasp", 40, 90, 16, 10, 0, 1.4)])
    chaos_sites = [(20, 60, 4), (-30, 56, 4), (50, 52, 4), (-60, 60, 4), (100, 58, 4), (-90, 54, 4)]
    for i, (si, tgt, cut, kw) in enumerate([(0, order_air[0], 0.8, {"turn": 9.0}), (1, order_air[1], 0.65, {"weave": 0.45, "turn": 12.0}),
                                            (2, order_air[2], 0.7, {"turn": 7.0, "tilt": 1.1}),
                                            (3, order_air[3], 0.85, {"turn": 13.0}), (4, order_air[4], 0.6, {"turn": 10.0, "tilt": 0.5})]):
        sam("far", chaos_sites[si], tgt, 500 + i, "chs_ir_sam" if i % 2 else "chs_radar_sam", "chaos", cut=cut, **kw)
    for i, (start, tgt, cut, kw) in enumerate([((-20, 150, 1), chaos_air[0], 0.75, {"turn": 9.0}),
                                               ((70, 160, 2), chaos_air[1], 0.6, {"tilt": 1.1}),
                                               ((-60, 360, 3), chaos_air[0], 0.4, {"turn": 7.0})]):
        sam("far", start, tgt, 520 + i, "ord_ir_sam" if i % 2 else "ord_radar_sam", "order", cut=cut, **kw)
    kill("far", chaos_sites[5], ("ord_falcon", -80, 130, 40, 150, 25, 4.0), 540, "chaos", turn=11.0, tilt=0.8)
    kill("far", (0, 140, 2), ("chs_harpy", 60, 190, 50, 30, -35, 4.2), 550, "order", turn=12.0, tilt=1.0)
    rng = random.Random(63)
    for k in range(9):  # a rocket salvo from the ships, each rocket at its own point of flight
        x = rng.uniform(-110, 110)
        pts = arc((x - rng.uniform(10, 40), rng.uniform(240, 300), 20), (x, rng.uniform(30, 80), 0), rng.uniform(30, 70), 8)
        j = rng.randint(3, 6)
        trail("far", pts[:j + 1], rng.uniform(0.5, 0.8), seed=63 + k)
    for k in range(8):
        splash("far", (rng.uniform(-140, 140), rng.uniform(100, 170), 0), rng.uniform(2.0, 4.0), seed=70 + k)
    ground_haze("far", (-200, 200, 100, 170), 8, 1053, amp=0.0, rgb=(214, 214, 210), size=(30, 60))
    # mid: the beach: tanks wading ashore, the Chaos line firing back
    ground("mid", -170, 170, 6, 96, 0.8, "beach", amp=0.6)
    tank_explode("mid", "chs_ravager", -46, 48, 20, 1050, amp=0.6)
    lo = army("mid", "order", ["ord_tideguard", "ord_tideguard", "ord_paladin", "ord_lancer"], (-120, 120, 70, 94), 10, 190, seed=611, amp=0.6)
    hi = army("mid", "chaos", ["chs_mire", "chs_spike", "chs_ravager", "chs_jackal", "chs_hellmouth"], (-130, 130, 32, 62), 10, 10, seed=612, amp=0.6)
    firefight("mid", hi, lo, seed=613, colors=((255, 110, 50), (255, 214, 140)), shells=14, flashes=9, burning=3)
    blasts("mid", beach_blasts, 80, amp=0.6)
    ground_haze("mid", (-170, 170, 20, 96), 12, 1051, amp=0.6, rgb=(206, 196, 182))
    hero_jet("mid", "ord_archon", (24, 30, 20), 200, -12, 40, 1052,
             missiles=[((-20, 40, 2), "order", "ord_radar_sam")])
    battlefield_debris("mid", (-150, 150, 16, 92), 70, seed=614, amp=0.6)
    ground_fire("mid", (-40, 44), (10, 5), 10, 1020, amp=0.6)
    ground_fire("mid", (70, 52), (8, 4), 8, 1021, amp=0.6)
    for k, u in enumerate((hi[0], hi[3])):
        smoke_column("mid", (u["x"], u["y"], u["z"] + 1), 80, 4, 1022 + k)
    ember_field("mid", (-120, 120, 14, 90, 0, 25), 300, 1024)
    for k in range(6):
        splash("mid", (rng.uniform(-120, 120), rng.uniform(88, 96), 0), rng.uniform(1.8, 3.4), seed=90 + k)
    # near: the defending dune: a wreck, debris, smoke, embers
    ground("near", -70, 70, 6, 28, 0.8, "beach", amp=0.6, catcher=True)
    place("chs_ravager", "near", 18, 20, 340, z=height(18, 20, 0.6) + 0.3, wreck=True, tilt=(-6, 8))
    battlefield_debris("near", (-40, 40, 14, 28), 30, seed=91, amp=0.6)
    smoke_plume("near", (18, 24, 1), 3.0, dark=70, seed=91)
    explosion("near", (16, 22, height(16, 22, 0.6) + 1.4), 1.2, smoke=0.5, debris=False, seed=92)
    explosion("near", (-30, 24, height(-30, 24, 0.6)), 2.6, smoke=1.0, seed=94)
    embers("near", (16, 22, 2), (5, 3, 6), 24, seed=93)
    grass_tufts("near", (-45, 45, 12, 20), 30, 1030, amp=0.6)
    ground_fire("near", (-8, 18), (5, 2), 6, 1031, amp=0.6)
    ember_field("near", (-30, 30, 14, 30, 0, 12), 200, 1032)


def lookdev(scene):
    """Effects test bed: one of each effect near the camera."""
    CRATERS.clear()
    CRATERS.extend([(-8, 30, 3.0), (10, 36, 3.0)])
    daylight(scene, 30.0, 118.0)
    cam_rig(scene, 9.0, 0.4, 30, y=-10.0)
    sea("sky", 400.0, (30, 66, 86))
    cloud_deck("sky", 420.0, 300.0, 7000.0, cover=0.5, seed=1.0)
    ground("mid", -60, 60, -4, 120, 0.6, "field", amp=0.6, grass=0.5)
    explosion("mid", (-8, 30, height(-8, 30, 0.6) - 0.2), 3.0, seed=1)
    explosion("mid", (10, 36, height(10, 36, 0.6) - 0.2), 2.4, seed=2)
    tank = army("mid", "order", ["ord_paladin"], (-20, -18, 20, 22), 1, 30, seed=3, amp=0.6)
    tip = muzzle_tip(tank[0], 40)
    muzzle_flash("mid", tip, forward(40), 1.4, (170, 225, 255), 4)
    shell("mid", tip, tip + forward(40) * 60, 0.15, (170, 225, 255), 0.6, 50.0)
    burst("mid", (-6, 60, 16), 2.2, seed=5)
    plane_kill("mid", "chs_harpy", Vector((14, 70, 20)), forward(-120) * 4.0, 6)
    smoke_column("mid", (24, 90, height(24, 90, 0.6)), 40, 3.0, 7)
    sam("mid", (-30, 40, 1), (Vector((10, 110, 30)), forward(90) * 3.0), 8, "ord_ir_sam", "order", cut=0.8)
    ground_fire("mid", (0, 22), (5, 2), 6, 9, amp=0.6)
    grass_tufts("near", (-12, 12, 0, 6), 10, 10, amp=0.6)
    ember_field("near", (-12, 12, 2, 16, 0, 6), 80, 11)



SCENES = {"land_battle": land_battle, "sam_site": sam_site, "beach_assault": beach_assault, "lookdev": lookdev}
DAY_HAZE = (214, 168, 128)  # dust-laden afternoon air
HORIZON = {"land_battle": 0.34, "sam_site": 0.58, "beach_assault": 0.38, "lookdev": 0.4}
HAZE = {"land_battle": {"rgb": DAY_HAZE, "far": 0.18, "mid": 0.06, "near": 0.02},
        "sam_site": {"rgb": DAY_HAZE, "far": 0.14, "mid": 0.05, "near": 0.0},
        "beach_assault": {"rgb": DAY_HAZE, "far": 0.16, "mid": 0.06, "near": 0.02},
        "lookdev": {"rgb": DAY_HAZE, "mid": 0.03}}


# ---------------------------------------------------------------------------
# Render and post (haze, bloom, tiles)
# ---------------------------------------------------------------------------

def render_layers(scene, name, layers, out):
    os.makedirs(out, exist_ok=True)
    paths = {}
    for layer in layers:
        for l in LAYERS:
            coll(l).hide_render = l != layer
        scene.render.film_transparent = layer != "sky"
        scene.render.filepath = os.path.join(out, f"_raw_{layer}.png")
        bpy.ops.render.render(write_still=True)
        paths[layer] = scene.render.filepath
        print(f"[keyart] {name} {layer} rendered")
    return paths


def load(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)


def save(arr, path):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("out", w, h, alpha=True, float_buffer=False)
    img.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def blur(a, r):
    """A cheap separable box blur (three passes approximate a gaussian)."""
    for _ in range(3):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode="edge"), axis=axis)
            hi = np.take(c, range(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, range(0, c.shape[axis] - 2 * r - 1), axis=axis)
            a = (hi - lo) / (2 * r + 1)
    return a


def post(name, layer, arr):
    """Haze toward the horizon colour (aerial perspective, stronger for the
    far layer), then bloom on the bright parts. Pixels are straight alpha,
    sRGB-encoded (Blender's PNG save), rows bottom-up."""
    cfg = HAZE[name]
    rgb, alpha = arr[..., :3], arr[..., 3:4]
    h = arr.shape[0]
    if layer in cfg:
        haze = np.array([c / 255 for c in cfg["rgb"]], dtype=np.float32)
        rows = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]  # 0 at the bottom
        f = cfg[layer] * (0.6 + 0.8 * np.clip((rows - 0.2) / 0.5, 0, 1))
        rgb = rgb * (1 - f) + haze * f
    if layer == "sky":
        # war sky: orange-amber at the horizon, smoky rust above, a darker top
        rows = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
        hz = 1 - HORIZON.get(name, 0.36)  # the horizon row, counted bottom-up
        above = np.clip((rows - hz) / (1 - hz), 0, 1)
        warm = np.array([1.0, 0.56, 0.24], dtype=np.float32)
        rust = np.array([0.55, 0.36, 0.28], dtype=np.float32)
        tint = warm * (1 - above) + rust * above
        k = (0.55 - 0.25 * above) * (rows > hz - 0.04)
        lumi = rgb.mean(axis=2, keepdims=True)
        rgb = rgb * (1 - k) + (lumi * 1.25 * tint) * k
        rgb = rgb * (1 - 0.35 * above ** 1.5)
    lum = rgb.max(axis=2, keepdims=True) * alpha
    bright = np.clip(lum - 0.82, 0, None) * 4.0
    glow = blur(rgb * alpha * bright, max(2, h // 160))
    out_rgb = rgb * alpha + glow * 0.9
    out_a = np.clip(np.maximum(alpha, glow.max(axis=2, keepdims=True)), 0, 1)
    if layer == "sky":
        out_a[:] = 1.0
    straight = np.where(out_a > 1e-4, out_rgb / np.maximum(out_a, 1e-4), 0)
    return np.concatenate([np.clip(straight, 0, 1), out_a], axis=2)


def finish(name, raws, out):
    stack = None
    for layer in LAYERS:
        p = os.path.join(out, f"{layer}.png")
        if layer in raws:
            arr = post(name, layer, load(raws[layer]))
            save(arr, p)
            os.remove(raws[layer])
        elif os.path.isfile(p):
            arr = load(p)
        else:
            continue
        h, w = arr.shape[:2]
        for r in range(2):
            for c in range(2):
                # rows run bottom-up in Blender's pixel buffer; tiles run row by row from the top left
                tile = arr[(1 - r) * h // 2:(2 - r) * h // 2, c * w // 2:(c + 1) * w // 2]
                save(tile, os.path.join(out, f"{layer}_{r}{c}.png"))
        a = arr[..., 3:4]
        stack = arr[..., :3] if stack is None else arr[..., :3] * a + stack * (1 - a)
    if stack is not None:
        flat = np.concatenate([stack, np.ones(stack.shape[:2] + (1,), dtype=np.float32)], axis=2)
        save(flat, os.path.join(out, "composite.png"))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    name = args[0]
    preview = "--preview" in args
    layers = LAYERS
    if "--layers" in args:
        layers = args[args.index("--layers") + 1].split(",")
    out = os.path.join(HERE, name + ("_preview" if preview else ""))
    scene = setup(preview)
    if "--fast" in args:  # composition checks: few samples, a third of the size
        scene.cycles.samples = 12
        scene.render.resolution_percentage = 33
    t0 = __import__("time").time()
    SCENES[name](scene)
    print(f"[keyart] {name} built in {__import__('time').time() - t0:.0f} s, {len(bpy.data.objects)} objects", flush=True)
    if "--stats" in args:
        for l in LAYERS:
            objs = coll(l).objects
            kinds = {}
            for o in objs:
                kinds[o.name.split(".")[0][:14]] = kinds.get(o.name.split(".")[0][:14], 0) + 1
            top = sorted(kinds.items(), key=lambda kv: -kv[1])[:8]
            print(f"[stats] {l}: {len(objs)} objects, {sum(len(o.data.vertices) for o in objs if o.type == 'MESH')} verts; {top}", flush=True)
        print(f"[stats] lights {sum(1 for o in bpy.data.objects if o.type == 'LIGHT')}, materials {len(bpy.data.materials)}", flush=True)
        return
    raws = render_layers(scene, name, layers, out)
    finish(name, raws, out)
    print(f"[keyart] {name} done -> {out}")


if __name__ == "__main__":
    main()
