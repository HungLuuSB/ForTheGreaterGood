"""Build-menu unit pictures (E-11, 2D session E's spec 2026-10-29): one small
diorama per unit def, its approved mesh standing in its own setting, the same
camera and light rig for every unit so the grid reads as a set.

    lune run assets/models/tools/pictures_defs.luau   (debug_out/pictures/defs.json)
    blender -b --factory-startup --python-exit-code 1 -P assets/models/tools/pictures.py -- [--masks] [--ids a,b,c] [first count]

Per def, a 256 x 256 PNG in debug_out/pictures/ (regenerable, not committed;
E packs them):
- <id>.png: the picture, opaque, glows on. The team paint is baked in the
  faction's colour, Order blue and Chaos red (the user, 2026-10-30), so the
  game shows it as is.
- <id>_mask.png, only with --masks (the first look, for a team tint in game):
  the team paint alone in lit white with its shading, the setting and
  everything else held out (alpha 0).

Settings (pictures_defs.luau): ground units and bots on a terrain patch with
track marks or footprints, structures on a gravel apron with props, ships in
water with a bow wave and a wake, sea structures in water with foam, subs and
seafloor structures under water, amphibious and hover units on a shoreline,
aircraft over clouds with the ground far below, banked. The setting stays
lower in contrast and saturation than the unit; a cool rim light separates the
silhouette from the warm key. Order's ground is temperate green, Chaos's ash.
"""

import colorsys
import json
import math
import os
import random
import sys
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib  # noqa: E402
import portraits  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "debug_out", "pictures")
SIZE = 256
LENS = 50
SAMPLES = 64
FILL = 0.76  # the unit's larger projected extent, as a share of the frame
# The team paint, baked in the faction's colour (the user, 2026-10-30: "keep the unit as their
# faction color ... Orders is blue, Chaos is red"): TeamColors.luau's first cold and warm entries.
FACTION_TEAM = {"order": (64, 132, 230), "chaos": (222, 70, 62)}
MASKS = False  # the team-mask pass (<id>_mask.png), off since the paint is baked; --masks turns it on
WATERLINE = 0.18  # PortraitStage.WATERLINE: the water surface, a share of the hull's height
VIEW = lib.R(-1.0, 0.75, -1.15).normalized()  # portraits.py's three-quarter view, front-left
# The user's approval note (2026-10-30, via E): "increase their glow and color".
UNIT_SATURATION = 2.1  # the unit's colours, through a Hue/Saturation node (the user: "push the color up too")
ENV_SATURATION = 1.2  # the setting's palettes: more colour, still under the unit's
# The user, 2026-10-30: "make them glow more"; and the distance haze off ("too blurry because of the fog").
GLOW = 3.5  # the glow parts' emission over a dark base (the FBX previews use 4)
BLOOM = 2.2  # the glow's soft halo, added after the render
FOG = False  # the distance haze (aerial perspective) over the far ground and water
GRADE_SATURATION = 1.3  # the whole picture's colour, after the render
GRADE_CONTRAST = 1.12  # and its contrast, about mid grey
MASK_EXPOSURE = 1.0  # the team mask's lit white, in stops: a stronger tint in game


def vivid(c, k):
    h, l, sat = colorsys.rgb_to_hls(*(v / 255 for v in c))
    r, g, b = colorsys.hls_to_rgb(h, l, min(1.0, sat * k))
    return (round(r * 255), round(g * 255), round(b * 255))


ENV = {
    "order": {"a": (88, 100, 66), "b": (116, 104, 84), "grit": (70, 66, 56), "rock": (118, 116, 110),
              "haze": (172, 186, 196), "water": (34, 66, 78), "tuft": (74, 92, 52), "sky": (150, 172, 196)},
    "chaos": {"a": (90, 86, 82), "b": (62, 56, 52), "grit": (44, 40, 38), "rock": (96, 92, 88),
              "haze": (150, 142, 136), "water": (34, 54, 58), "tuft": (70, 64, 52), "sky": (146, 142, 140)},
}
ENV = {f: {k: vivid(c, ENV_SATURATION) for k, c in pal.items()} for f, pal in ENV.items()}
SEA = (24, 62, 64)  # the murk under water
AIR_SKY = (92, 128, 172)  # a deeper blue behind aircraft, so a light hull reads at 66 px


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def tag(o):
    o["unit"] = True  # portraits.clear_unit removes everything tagged
    o["env"] = True
    bpy.context.scene.collection.objects.link(o)
    return o


def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    return m, nt.nodes.new, nt.links.new


def rgb(c, k=1.0):
    s = lib.srgb(c)
    return (s[0] * k, s[1] * k, s[2] * k, 1.0)


def mesh_object(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = False
    return tag(bpy.data.objects.new(name, me))


def quad(name, corners, mat, uv=((0, 0), (1, 0), (1, 1), (0, 1))):
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    f = bm.faces.new([bm.verts.new(c) for c in corners])
    for loop, t in zip(f.loops, uv):
        loop[layer].uv = t
    return mesh_object(name, bm, mat)


def haze_over(N, L, shader, haze_rgb, near, far, most=0.85):
    """Fades a surface into the haze with the distance from the camera, as
    light (aerial perspective), so the sun can't push the far ground to white.
    Off while FOG is False: the surface as it is."""
    if not FOG:
        return shader
    cam = N("ShaderNodeCameraData")
    rng = N("ShaderNodeMapRange")
    rng.interpolation_type = "SMOOTHSTEP"
    rng.inputs["From Min"].default_value = near
    rng.inputs["From Max"].default_value = far
    rng.inputs["To Max"].default_value = most
    L(cam.outputs["View Distance"], rng.inputs["Value"])
    glow = N("ShaderNodeEmission")
    glow.inputs["Color"].default_value = rgb(haze_rgb)
    glow.inputs["Strength"].default_value = 1.0
    mix = N("ShaderNodeMixShader")
    L(rng.outputs["Result"], mix.inputs[0])
    L(shader, mix.inputs[1])
    L(glow.outputs[0], mix.inputs[2])
    return mix.outputs[0]


def scaled_coords(N, L, r, space="Object"):
    tc = N("ShaderNodeTexCoord")
    mp = N("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / r, 1 / r, 1 / r)
    L(tc.outputs[space], mp.inputs["Vector"])
    return mp.outputs["Vector"]


# ---------------------------------------------------------------------------
# Materials of the setting
# ---------------------------------------------------------------------------


def ground_material(pal, r, near, far, scorch=False, most=0.85):
    m, N, L = new_mat("env_ground")
    out, b = N("ShaderNodeOutputMaterial"), N("ShaderNodeBsdfPrincipled")
    co = scaled_coords(N, L, r)
    patches = N("ShaderNodeTexNoise")
    patches.inputs["Scale"].default_value = 1.6
    patches.inputs["Detail"].default_value = 6.0
    patches.inputs["Roughness"].default_value = 0.62
    L(co, patches.inputs["Vector"])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.38, 0.62
    ramp.color_ramp.elements[0].color = rgb(pal["a"])
    ramp.color_ramp.elements[1].color = rgb(pal["b"])
    L(patches.outputs["Fac"], ramp.inputs["Fac"])
    grit = N("ShaderNodeTexNoise")
    grit.inputs["Scale"].default_value = 60.0
    grit.inputs["Detail"].default_value = 3.0
    L(co, grit.inputs["Vector"])
    gmix = N("ShaderNodeMix")
    gmix.data_type = "RGBA"
    gm = N("ShaderNodeMath")
    gm.operation = "MULTIPLY"
    gm.inputs[1].default_value = 0.35
    L(grit.outputs["Fac"], gm.inputs[0])
    L(gm.outputs[0], gmix.inputs[0])
    L(ramp.outputs["Color"], gmix.inputs[6])
    gmix.inputs[7].default_value = rgb(pal["grit"])
    color = gmix.outputs[2]
    if scorch:  # Chaos: dark scorched blotches
        sc = N("ShaderNodeTexNoise")
        sc.inputs["Scale"].default_value = 0.9
        sc.inputs["Detail"].default_value = 2.0
        L(co, sc.inputs["Vector"])
        sr = N("ShaderNodeMapRange")
        sr.inputs["From Min"].default_value, sr.inputs["From Max"].default_value = 0.56, 0.68
        sr.inputs["To Max"].default_value = 0.7
        L(sc.outputs["Fac"], sr.inputs["Value"])
        smix = N("ShaderNodeMix")
        smix.data_type = "RGBA"
        L(sr.outputs["Result"], smix.inputs[0])
        L(color, smix.inputs[6])
        smix.inputs[7].default_value = rgb((26, 24, 23))
        color = smix.outputs[2]
    L(color, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.95
    bump = N("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    L(grit.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs["Normal"], b.inputs["Normal"])
    L(haze_over(N, L, b.outputs[0], pal["haze"], near, far, most), out.inputs["Surface"])
    return m


def decal_material(name, rgb_c, r, fade="u", treads=False, alpha=0.85):
    """A dark decal on the ground: track marks (`fade` along U, tread bumps)
    or a footprint / scorch (`fade` radial)."""
    m, N, L = new_mat(name)
    out, b = N("ShaderNodeOutputMaterial"), N("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = rgb(rgb_c)
    b.inputs["Roughness"].default_value = 1.0
    uv = N("ShaderNodeTexCoord")
    sep = N("ShaderNodeSeparateXYZ")
    L(uv.outputs["UV"], sep.inputs["Vector"])
    if fade == "u":
        f = N("ShaderNodeMapRange")
        f.inputs["From Min"].default_value, f.inputs["From Max"].default_value = 1.0, 0.0
        f.interpolation_type = "SMOOTHSTEP"
        L(sep.outputs["X"], f.inputs["Value"])
        a = f.outputs["Result"]
    else:
        cen = N("ShaderNodeVectorMath")
        cen.operation = "DISTANCE"
        cen.inputs[1].default_value = (0.5, 0.5, 0.0)
        L(uv.outputs["UV"], cen.inputs[0])
        f = N("ShaderNodeMapRange")
        f.inputs["From Min"].default_value, f.inputs["From Max"].default_value = 0.5, 0.2
        f.interpolation_type = "SMOOTHSTEP"
        L(cen.outputs["Value"], f.inputs["Value"])
        a = f.outputs["Result"]
    k = N("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = alpha
    L(a, k.inputs[0])
    L(k.outputs[0], b.inputs["Alpha"])
    if treads:
        w = N("ShaderNodeTexWave")
        w.inputs["Scale"].default_value = 1.0
        w.wave_type = "BANDS"
        w.bands_direction = "X"
        L(scaled_coords(N, L, r * 0.06, "Object"), w.inputs["Vector"])
        bump = N("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.5
        L(w.outputs["Fac"], bump.inputs["Height"])
        L(bump.outputs["Normal"], b.inputs["Normal"])
    L(b.outputs[0], out.inputs["Surface"])
    return m


def flat(name, c, rough=0.8, metal=0.0):
    m, N, L = new_mat(name)
    out, b = N("ShaderNodeOutputMaterial"), N("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = rgb(c)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    L(b.outputs[0], out.inputs["Surface"])
    return m


def water_material(pal, r, near, far):
    m, N, L = new_mat("env_water")
    out, b = N("ShaderNodeOutputMaterial"), N("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = rgb(pal["water"])
    b.inputs["Roughness"].default_value = 0.06
    co = scaled_coords(N, L, r)
    waves = N("ShaderNodeTexNoise")
    waves.inputs["Scale"].default_value = 7.0
    waves.inputs["Detail"].default_value = 4.0
    L(co, waves.inputs["Vector"])
    bump = N("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    L(waves.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs["Normal"], b.inputs["Normal"])
    L(haze_over(N, L, b.outputs[0], pal["haze"], near, far), out.inputs["Surface"])
    return m


def foam_material(r):
    """White foam, clumped by noise, faded by the strip's U (0 = dense)."""
    m, N, L = new_mat("env_foam")
    out, b = N("ShaderNodeOutputMaterial"), N("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = rgb((196, 206, 208))
    b.inputs["Roughness"].default_value = 0.7
    uv = N("ShaderNodeTexCoord")
    sep = N("ShaderNodeSeparateXYZ")
    L(uv.outputs["UV"], sep.inputs["Vector"])
    fade = N("ShaderNodeMapRange")
    fade.inputs["From Min"].default_value, fade.inputs["From Max"].default_value = 1.0, 0.0
    fade.interpolation_type = "SMOOTHSTEP"
    L(sep.outputs["X"], fade.inputs["Value"])
    noise = N("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9.0
    noise.inputs["Detail"].default_value = 6.0
    L(scaled_coords(N, L, r, "Object"), noise.inputs["Vector"])
    clump = N("ShaderNodeMapRange")
    clump.inputs["From Min"].default_value, clump.inputs["From Max"].default_value = 0.42, 0.62
    L(noise.outputs["Fac"], clump.inputs["Value"])
    # dense foam where the strip starts, broken up by the noise further out
    thr = N("ShaderNodeMath")
    thr.operation = "SUBTRACT"
    L(clump.outputs["Result"], thr.inputs[0])
    inv = N("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    L(fade.outputs["Result"], inv.inputs[1])
    L(inv.outputs[0], thr.inputs[1])
    a = N("ShaderNodeMath")
    a.operation = "MULTIPLY"
    a.use_clamp = True
    a.inputs[1].default_value = 1.3
    L(thr.outputs[0], a.inputs[0])
    a2 = N("ShaderNodeMath")
    a2.operation = "MULTIPLY"
    a2.use_clamp = True
    L(a.outputs[0], a2.inputs[0])
    L(fade.outputs["Result"], a2.inputs[1])
    L(a2.outputs[0], b.inputs["Alpha"])
    L(b.outputs[0], out.inputs["Surface"])
    return m


def cloud_material():
    m, N, L = new_mat("env_cloud")
    out, v = N("ShaderNodeOutputMaterial"), N("ShaderNodeVolumePrincipled")
    v.inputs["Color"].default_value = (1, 1, 1, 1)
    tc = N("ShaderNodeTexCoord")
    noise = N("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.4
    noise.inputs["Detail"].default_value = 5.0
    L(tc.outputs["Object"], noise.inputs["Vector"])
    ln = N("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    L(tc.outputs["Object"], ln.inputs[0])
    fall = N("ShaderNodeMapRange")
    fall.inputs["From Min"].default_value, fall.inputs["From Max"].default_value = 1.0, 0.3
    fall.interpolation_type = "SMOOTHSTEP"
    L(ln.outputs["Value"], fall.inputs["Value"])
    sub = N("ShaderNodeMath")
    sub.operation = "SUBTRACT"
    L(noise.outputs["Fac"], sub.inputs[0])
    inv = N("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 0.85
    L(fall.outputs["Result"], inv.inputs[1])
    L(inv.outputs[0], sub.inputs[1])
    dens = N("ShaderNodeMath")
    dens.operation = "MULTIPLY"
    dens.use_clamp = True
    dens.inputs[1].default_value = 4.0
    L(sub.outputs[0], dens.inputs[0])
    L(dens.outputs[0], v.inputs["Density"])
    L(v.outputs[0], out.inputs["Volume"])
    return m


# ---------------------------------------------------------------------------
# Scene: one camera and one light rig for every unit
# ---------------------------------------------------------------------------


def setup():
    scene = lib.reset_scene()
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.volume_step_rate = 2.0
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.view_settings.view_transform = "Standard"
    s = scene.render.image_settings
    s.file_format, s.color_mode, s.color_depth = "PNG", "RGBA", "8"

    def sun(name, energy, color, rot, angle=8):
        d = bpy.data.lights.new(name, "SUN")
        d.energy, d.color, d.angle = energy, color, math.radians(angle)
        o = bpy.data.objects.new(name, d)
        o.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
        scene.collection.objects.link(o)

    sun("key", 3.2, (1.0, 0.93, 0.82), (50, 0, -35))  # warm, from front-left above (portraits.py)
    sun("rim", 4.5, (0.62, 0.76, 1.0), (68, 0, 160), angle=4)  # cool, from behind right: the silhouette
    sun("fill", 0.6, (0.85, 0.9, 1.0), (60, 0, 110))
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = LENS
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.clip_end = 20000
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def set_world(scene, sky_rgb, strength=0.7):
    w = bpy.data.worlds.new("world")
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    bg.inputs["Color"].default_value = rgb(sky_rgb)
    bg.inputs["Strength"].default_value = strength
    old = scene.world
    scene.world = w
    if old:
        bpy.data.worlds.remove(old)
    return w


def fit_camera(cam, objs):
    """Places the camera on the fixed view so the unit's larger projected
    extent fills FILL of the frame, centred. Returns the focus distance."""
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector(map(min, *pts)) if len(pts) > 1 else pts[0]
    hi = Vector(map(max, *pts)) if len(pts) > 1 else pts[0]
    target = (lo + hi) / 2
    rot = (-VIEW).to_track_quat("-Z", "Y").to_matrix()
    right, up, fwd = rot.col[0], rot.col[1], -rot.col[2]
    t = math.tan(math.atan(18 / LENS))
    span = (hi - lo).length

    def project(dist):
        loc = target + VIEW * dist
        xs, ys = [], []
        for p in pts:
            v = p - loc
            z = v.dot(fwd)
            xs.append(v.dot(right) / z / t)
            ys.append(v.dot(up) / z / t)
        return xs, ys

    dist = span
    for _ in range(3):
        a, b = span * 0.3, span * 20
        for _ in range(40):
            dist = (a + b) / 2
            xs, ys = project(dist)
            ext = max(max(xs) - min(xs), max(ys) - min(ys)) / 2
            a, b = (dist, b) if ext > FILL else (a, dist)
        xs, ys = project(dist)
        mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        target = target + right * mx * t * dist + up * my * t * dist
    cam.location = target + VIEW * dist
    cam.rotation_euler = rot.to_euler()
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = dist
    cam.data.dof.aperture_fstop = 4.0 / dist  # scale-free: the far ground blurs alike for every size
    return dist, lo, hi


# ---------------------------------------------------------------------------
# The settings
# ---------------------------------------------------------------------------


def stones(rng, pal, r, lo, hi, z, n=16, keep_clear=1.0):
    mat = flat("env_rock", pal["rock"], 0.9)
    cen = (lo + hi) / 2
    view_xy = Vector((VIEW.x, VIEW.y, 0)).normalized()
    for i in range(n):
        for _ in range(20):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0.75, 2.6) * r * keep_clear
            p = Vector((cen.x + math.cos(a) * d, cen.y + math.sin(a) * d, z))
            off = Vector((p.x - cen.x, p.y - cen.y, 0))
            inside = lo.x - 0.1 * r < p.x < hi.x + 0.1 * r and lo.y - 0.1 * r < p.y < hi.y + 0.1 * r
            if not inside and off.normalized().dot(view_xy) < 0.55:
                break
        s = rng.uniform(0.025, 0.07) * r
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * s * rng.uniform(0.8, 1.4), v.co.y * s * rng.uniform(0.8, 1.4), v.co.z * s * 0.6))
        o = mesh_object(f"env_stone{i}", bm, mat)
        o.location = p
        o.rotation_euler = (0, 0, rng.uniform(0, 6.3))


def tufts(rng, pal, r, lo, hi, n=40):
    mat = flat("env_tuft", pal["tuft"], 0.9)
    cen = (lo + hi) / 2
    view_xy = Vector((VIEW.x, VIEW.y, 0)).normalized()
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.7, 2.8) * r
        p = Vector((cen.x + math.cos(a) * d, cen.y + math.sin(a) * d, 0))
        if Vector((math.cos(a), math.sin(a), 0)).dot(view_xy) > 0.6 and d < 1.6 * r:
            continue
        h, w = rng.uniform(0.03, 0.06) * r, 0.006 * r
        bm = bmesh.new()
        for k in range(5):
            ang = k * 1.26 + rng.uniform(-0.3, 0.3)
            lean = Vector((math.cos(ang), math.sin(ang), 0)) * h * 0.45
            side = Vector((-math.sin(ang), math.cos(ang), 0)) * w
            v = [bm.verts.new(-side), bm.verts.new(side), bm.verts.new(lean + Vector((0, 0, h)))]
            bm.faces.new(v)
        o = mesh_object(f"env_tuft{i}", bm, mat)
        o.location = p


def ground_plane(name, mat, size, z=0.0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
    o = mesh_object(name, bm, mat)
    o.location.z = z
    return o


def track_marks(r, lo, hi, kind):
    """Behind the unit (its back is -Y in Blender): two tread lines for
    vehicles, alternating footprints for walkers."""
    w = hi.x - lo.x
    cx = (lo.x + hi.x) / 2
    back = lo.y
    if kind == "bot":
        mat = decal_material("env_print", (40, 36, 30), r, fade="radial", alpha=0.75)
        step = max((hi.y - lo.y) * 0.32, 0.05 * r)
        for i in range(10):
            sx = cx + (0.18 if i % 2 else -0.18) * w
            y = back - step * (i + 0.6)
            s = 0.07 * w + 0.02 * r
            quad(f"env_print{i}", [Vector((sx - s * 0.6, y - s, 0.02)), Vector((sx + s * 0.6, y - s, 0.02)),
                                   Vector((sx + s * 0.6, y + s, 0.02)), Vector((sx - s * 0.6, y + s, 0.02))], mat)
        return
    mat = decal_material("env_track", (46, 40, 32), r, treads=True, alpha=0.8)
    tw = max(0.16 * w, 0.03 * r)
    length = 3.5 * r
    for sx in (-1, 1):
        x = cx + sx * (0.5 * w - tw * 0.8)
        quad(f"env_track{sx}", [Vector((x - tw / 2, back + 0.05 * r, 0.015)), Vector((x - tw / 2, back - length, 0.015)),
                                Vector((x + tw / 2, back - length, 0.015)), Vector((x + tw / 2, back + 0.05 * r, 0.015))], mat,
             uv=((0, 0), (1, 0), (1, 1), (0, 1)))


def apron(r, lo, hi, pal):
    """A gravel apron round a structure's pad, faded at its edges."""
    m, N, L = new_mat("env_apron")
    out, b = N("ShaderNodeOutputMaterial"), N("ShaderNodeBsdfPrincipled")
    noise = N("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 40.0
    L(scaled_coords(N, L, r), noise.inputs["Vector"])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = rgb(pal["grit"])
    ramp.color_ramp.elements[1].color = rgb(pal["rock"], 0.85)
    L(noise.outputs["Fac"], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 1.0
    uv = N("ShaderNodeTexCoord")
    sep = N("ShaderNodeSeparateXYZ")
    L(uv.outputs["UV"], sep.inputs["Vector"])
    edge = []
    for axis in ("X", "Y"):
        a = N("ShaderNodeMath")
        a.operation = "PINGPONG"
        a.inputs[1].default_value = 0.5
        L(sep.outputs[axis], a.inputs[0])
        edge.append(a.outputs[0])
    mn = N("ShaderNodeMath")
    mn.operation = "MINIMUM"
    L(edge[0], mn.inputs[0])
    L(edge[1], mn.inputs[1])
    f = N("ShaderNodeMapRange")
    f.inputs["From Min"].default_value, f.inputs["From Max"].default_value = 0.0, 0.14
    f.interpolation_type = "SMOOTHSTEP"
    L(mn.outputs[0], f.inputs["Value"])
    L(f.outputs["Result"], b.inputs["Alpha"])
    L(b.outputs[0], out.inputs["Surface"])
    g = 0.14 * r
    quad("env_apron", [Vector((lo.x - g, lo.y - g, 0.01)), Vector((hi.x + g, lo.y - g, 0.01)),
                       Vector((hi.x + g, hi.y + g, 0.01)), Vector((lo.x - g, hi.y + g, 0.01))], m)


def props(rng, r, lo, hi):
    """A few crates and drums at the back edges of a structure."""
    crate, drum = flat("env_crate", (96, 92, 70), 0.85), flat("env_drum", (88, 60, 44), 0.6, 0.3)
    s = min(0.07 * r, 2.5)
    spots = [(hi.x + 0.6 * s, rng.uniform(lo.y, hi.y)), (rng.uniform(lo.x, hi.x), lo.y - 0.7 * s),
             (hi.x + 0.8 * s, lo.y - 0.8 * s), (lo.x - 0.7 * s, lo.y + rng.uniform(0, 0.4) * (hi.y - lo.y))]
    for i, (x, y) in enumerate(spots):
        if rng.random() < 0.5:
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            o = mesh_object(f"env_crate{i}", bm, crate)
            o.scale = (s, s * rng.uniform(0.8, 1.4), s * 0.8)
            o.location = (x, y, s * 0.4)
            o.rotation_euler = (0, 0, rng.uniform(0, 6.3))
        else:
            for k in range(rng.randint(1, 3)):
                bm = bmesh.new()
                bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.35 * s, radius2=0.35 * s, depth=0.9 * s)
                o = mesh_object(f"env_drum{i}_{k}", bm, drum)
                o.location = (x + k * 0.75 * s, y + (k % 2) * 0.4 * s, 0.45 * s)


def wake(r, lo, hi, kelvin=True):
    """Foam round the hull at the waterline, a bow wave, and (moving ships)
    the Kelvin arms and the propeller wash astern. U = 0 is dense foam."""
    mat = foam_material(r)
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    ax, ay = (hi.x - lo.x) / 2, (hi.y - lo.y) / 2
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    n = 48
    inner, outer = [], []
    for i in range(n):
        th = 2 * math.pi * i / n
        c, s = math.cos(th), math.sin(th)
        bow = max(0.0, s) ** 3 if kelvin else 0.0  # the bow is +Y
        k_out = 1.0 + 0.22 + 0.5 * bow
        inner.append(bm.verts.new((cx + c * ax * 0.98, cy + s * ay * 0.98, 0.03)))
        outer.append(bm.verts.new((cx + c * (ax * k_out + 0.05 * r), cy + s * (ay * k_out + 0.04 * r), 0.03)))
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new([inner[i], inner[j], outer[j], outer[i]])
        for loop, u in zip(f.loops, (0.0, 0.0, 1.0, 1.0)):
            loop[layer].uv = (u, 0.5)
    mesh_object("env_foam_ring", bm, mat)
    if not kelvin:
        return
    length = 3.2 * r
    for sx in (-1, 1):  # the Kelvin arms, 19.5 degrees off the course
        a = math.radians(19.5)
        p0 = Vector((cx + sx * ax * 0.8, lo.y + 0.1 * ay, 0.03))
        d = Vector((sx * math.sin(a), -math.cos(a), 0))
        side = Vector((-d.y, d.x, 0)) * sx
        w0, w1 = 0.04 * r, 0.22 * r
        quad(f"env_kelvin{sx}", [p0 - side * w0, p0 + d * length - side * w1, p0 + d * length + side * w1, p0 + side * w0], mat,
             uv=((0.1, 0), (1, 0), (1, 1), (0.1, 1)))
    hw = ax * 0.55  # the propeller wash
    quad("env_wash", [Vector((cx - hw, lo.y + 0.05 * ay, 0.031)), Vector((cx - hw * 1.8, lo.y - length, 0.031)),
                      Vector((cx + hw * 1.8, lo.y - length, 0.031)), Vector((cx + hw, lo.y + 0.05 * ay, 0.031))], mat,
         uv=((0, 0), (1, 0), (1, 1), (0, 1)))


def shoreline(rng, pal, r, lo, hi, near, far):
    """Ground under the unit's back half, falling away into water ahead (+Y)."""
    zw = -0.02 * r
    y0 = (lo.y + hi.y) / 2
    bm = bmesh.new()
    nx, ny = 24, 48
    size = 30 * r
    rows = []
    for j in range(ny + 1):
        y = y0 - size + 2 * size * (j / ny) ** 1.0
        row = []
        for i in range(nx + 1):
            x = -size + 2 * size * i / nx
            wob = 0.08 * r * math.sin(x / r * 2.1)
            z = 0.0 if y < y0 + wob else -(y - y0 - wob) * 0.25
            row.append(bm.verts.new((x, y, max(z, -3 * r))))
        rows.append(row)
    # denser rows near the shore
    for j in range(ny):
        for i in range(nx):
            bm.faces.new([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]])
    mesh_object("env_ground", bm, ground_material(pal, r, near, far, scorch=False))
    ground_plane("env_water", water_material(pal, r, near, far), 40 * r, zw)
    mat = foam_material(r)  # the surf line along the shore
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    prev = None
    for i in range(nx * 2 + 1):
        x = -6 * r + 12 * r * i / (nx * 2)
        wob = 0.08 * r * math.sin(x / r * 2.1)
        ys = y0 + wob + (-zw) / 0.25
        a = bm.verts.new((x, ys - 0.03 * r, zw + 0.01))
        b = bm.verts.new((x, ys + 0.12 * r, zw + 0.01))
        if prev:
            f = bm.faces.new([prev[0], a, b, prev[1]])
            for loop, u in zip(f.loops, (0.0, 0.0, 1.0, 1.0)):
                loop[layer].uv = (u, 0.5)
        prev = (a, b)
    mesh_object("env_surf", bm, mat)
    stones(rng, pal, r, lo, hi, 0.0, n=8)


def clouds(rng, r, lo, hi):
    mat = cloud_material()
    cen = (lo + hi) / 2
    for i in range(4):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        o = mesh_object(f"env_cloud{i}", bm, mat)
        o["volume"] = True
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(1.8, 3.4) * r  # off to the sides, so the ground shows under the aircraft
        o.location = (cen.x + math.cos(a) * d, cen.y + math.sin(a) * d - 0.8 * r, lo.z - rng.uniform(1.6, 3.2) * r)
        o.scale = (rng.uniform(1.2, 2.2) * r, rng.uniform(1.0, 1.6) * r, rng.uniform(0.35, 0.55) * r)
        o.rotation_euler = (0, 0, rng.uniform(0, 6.3))


def underwater(rng, r, lo, hi, z_bed):
    sand = {"a": (78, 86, 70), "b": (64, 72, 62), "grit": (40, 48, 44), "haze": SEA, "rock": (70, 78, 72)}
    ground_plane("env_seabed", ground_material(sand, r, 1e9, 2e9), 40 * r, z_bed)
    stones(rng, sand, r, lo, hi, z_bed, n=12)
    cen = (lo + hi) / 2
    top = hi.z + 2.5 * r  # the surface: a blue-green fog below it, the sun comes in from above
    m, N, L = new_mat("env_murk")
    vol = N("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = rgb((190, 235, 228))
    vol.inputs["Density"].default_value = 0.05 / r
    vol.inputs["Absorption Color"].default_value = rgb((90, 170, 165))
    L(vol.outputs[0], N("ShaderNodeOutputMaterial").inputs["Volume"])
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    box = mesh_object("env_murk", bm, m)
    box.location = (cen.x, cen.y, (z_bed - 0.5 * r + top) / 2)
    box.scale = (40 * r, 40 * r, top - z_bed + 0.5 * r)
    box["volume"] = True
    for i, (ox, oy) in enumerate(((-0.8, 0.6), (0.9, -0.4), (0.1, -1.4))):  # light shafts from the surface
        d = bpy.data.lights.new(f"env_shaft{i}", "SPOT")
        d.energy = 1500 * r * r
        d.color = (0.75, 0.95, 1.0)
        d.spot_size = math.radians(14)
        d.spot_blend = 0.6
        d.shadow_soft_size = 0.05 * r
        o = tag(bpy.data.objects.new(f"env_shaft{i}", d))
        o.location = (cen.x + ox * r, cen.y + oy * r, top + 1.0 * r)
        o.rotation_euler = (math.radians(rng.uniform(-8, 8)), math.radians(rng.uniform(-8, 8)), 0)


# ---------------------------------------------------------------------------
# The unit
# ---------------------------------------------------------------------------


def load_unit(e, col):
    portraits.TEAM = FACTION_TEAM.get(e["faction"], FACTION_TEAM["order"])
    objs = portraits.build_mesh({"id": e["model"], "faction": e["faction"]}, col)
    bpy.context.view_layer.update()
    lo, hi = portraits.world_bounds(objs)
    rig = bpy.data.objects.new("rig", None)
    rig["unit"] = True
    col.objects.link(rig)
    rig.location = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)
    bpy.context.view_layer.update()
    for o in objs:
        if o.parent is None or o.parent not in objs:
            mw = o.matrix_world.copy()
            o.parent = rig
            o.matrix_world = mw
    return objs, rig, lo, hi


def pose(e, rig, lo, hi):
    """Lifts aircraft and banks them; sets ships and sea structures into the water."""
    h = hi.z - lo.z
    s = e["setting"]
    if s == "jet":
        rig.location.z += max(h, 0.3 * (hi - lo).length)
        rig.rotation_euler = Euler((math.radians(4), math.radians(-16), 0))  # nose up a touch, banked
    elif s == "heli":
        rig.location.z += max(h, 0.3 * (hi - lo).length)
        rig.rotation_euler = Euler((math.radians(-7), math.radians(-9), 0))  # nose down, banked
    elif s in ("ship", "sea_structure"):
        rig.location.z -= WATERLINE * h
    elif s == "sub" and e["domain"] != "structure":
        rig.location.z += 0.6 * h
    bpy.context.view_layer.update()


def boost_unit(objs):
    """More colour on the unit, and brighter glows."""
    done = set()
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or m.name in done or not m.use_nodes:
                continue
            done.add(m.name)
            nt = m.node_tree
            if "_glow_" in o.name:  # the glow's colour from its emission alone, not the lit albedo under it
                bsdf = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
                for link in list(bsdf.inputs["Base Color"].links):
                    nt.links.remove(link)
                bsdf.inputs["Base Color"].default_value = (0.03, 0.03, 0.03, 1)
            for n in nt.nodes:
                if n.bl_idname == "ShaderNodeMath" and n.operation == "MULTIPLY" and abs(n.inputs[1].default_value - 4.0) < 1e-6:
                    n.inputs[1].default_value = GLOW
            bsdf = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"), None)
            if not (bsdf and bsdf.inputs["Base Color"].links):
                continue
            target = bsdf.inputs["Base Color"]
            mix = target.links[0].from_node
            if mix.bl_idname == "ShaderNodeMix" and mix.inputs[7].links:  # the team mix: saturate the paint (B), not the team colour (A)
                target = mix.inputs[7]
            src = target.links[0].from_socket
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.inputs["Saturation"].default_value = UNIT_SATURATION
            nt.links.new(src, hs.inputs["Color"])
            nt.links.new(hs.outputs["Color"], target)


def blur(a, radius):
    """Three box blurs along both axes: close to a gaussian."""
    for axis in (0, 1):
        for _ in range(3):
            pad = [(0, 0)] * a.ndim
            pad[axis] = (radius + 1, radius)
            c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
            hi = np.take(c, np.arange(2 * radius + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * radius - 1), axis=axis)
            a = (hi - lo) / (2 * radius + 1)
    return a


def bloom(path):
    """A soft halo round what renders near white or saturated bright (the
    glows), so they read at 66 px."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    rgb_ = px[:, :, :3]
    mx, mn = rgb_.max(axis=2, keepdims=True), rgb_.min(axis=2, keepdims=True)
    weight = np.clip((mx - 0.8) / 0.15, 0, 1) * np.clip((mx - mn - 0.2) / 0.2, 0, 1) + np.clip((mn - 0.97) / 0.03, 0, 1)
    bright = np.clip(weight, 0, 1) * rgb_
    halo = blur(bright, 3) * 0.55 + blur(bright, 10) * 0.45
    out = np.clip(rgb_ + halo * BLOOM, 0, 1)
    grey = out.mean(axis=2, keepdims=True)  # the grade: more colour and a little more contrast
    out = grey + (out - grey) * GRADE_SATURATION
    out = 0.5 + (out - 0.5) * GRADE_CONTRAST
    px[:, :, :3] = np.clip(out, 0, 1)
    img.pixels[:] = px.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def mask_materials(objs):
    """Team paint (where the ALB's alpha is 0) in lit white; everything else held out."""
    hold, _N, _L = new_mat("mask_hold")
    hold.node_tree.links.new(_N("ShaderNodeHoldout").outputs[0], _N("ShaderNodeOutputMaterial").inputs["Surface"])
    cache = {}
    for o in objs:
        if "_glow_" in o.name or not o.material_slots or not o.material_slots[0].material:
            o.data.materials.clear()
            o.data.materials.append(hold)
            continue
        src = o.material_slots[0].material
        if src.name not in cache:
            alb = next((n.image for n in src.node_tree.nodes if n.bl_idname == "ShaderNodeTexImage" and n.image and "_ALB" in n.image.name), None)
            m, N, L = new_mat(f"mask_{src.name}")
            out = N("ShaderNodeOutputMaterial")
            white = N("ShaderNodeBsdfDiffuse")
            white.inputs["Color"].default_value = (1, 1, 1, 1)
            mix = N("ShaderNodeMixShader")
            if alb is not None:
                tex = N("ShaderNodeTexImage")
                tex.image = alb
                L(tex.outputs["Alpha"], mix.inputs[0])  # alpha 1 = paint (held out), 0 = team
            L(white.outputs[0], mix.inputs[1])
            L(N("ShaderNodeHoldout").outputs[0], mix.inputs[2])
            L(mix.outputs[0], out.inputs["Surface"])
            cache[src.name] = m
        o.data.materials.clear()
        o.data.materials.append(cache[src.name])


def render(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def picture(scene, cam, e):
    portraits.clear_unit()
    for l in [l for l in bpy.data.lights if l.users == 0]:
        bpy.data.lights.remove(l)
    col = scene.collection
    objs, rig, lo0, hi0 = load_unit(e, col)
    pose(e, rig, lo0, hi0)
    boost_unit(objs)
    dist, lo, hi = fit_camera(cam, objs)
    r = max((hi - lo).length / 2, 1.0)
    pal = ENV[e["faction"]] if e["faction"] in ENV else ENV["order"]
    rng = random.Random(zlib.crc32(e["id"].encode()))
    near, far = dist + 0.8 * r, dist + 9 * r
    s = e["setting"]
    if s in ("ground", "bot", "structure"):
        ground_plane("env_ground", ground_material(pal, r, near, far, scorch=e["faction"] == "chaos"), 60 * r)
        stones(rng, pal, r, lo, hi, 0.0)
        if e["faction"] == "order":
            tufts(rng, pal, r, lo, hi)
        if s == "structure":
            apron(r, lo, hi, pal)
            props(rng, r, lo, hi)
        else:
            track_marks(r, lo, hi, s)
        set_world(scene, pal["sky"])
    elif s in ("ship", "sea_structure"):
        ground_plane("env_water", water_material(pal, r, near, far), 60 * r)
        wake(r, lo, hi, kelvin=(s == "ship"))
        set_world(scene, pal["sky"])
    elif s == "shore":
        shoreline(rng, pal, r, lo, hi, near, far)
        set_world(scene, pal["sky"])
    elif s in ("jet", "heli"):
        far_z = lo.z - 4 * r
        air = dict(pal, haze=AIR_SKY)
        ground_plane("env_ground", ground_material(air, r * 2, dist + 3 * r, dist + 18 * r, scorch=e["faction"] == "chaos", most=0.4), 200 * r, far_z)
        clouds(rng, r, lo, hi)
        set_world(scene, AIR_SKY, 0.8)
    elif s == "sub":
        z_bed = lo.z if e["domain"] == "structure" else lo.z - 1.2 * (hi.z - lo.z)
        underwater(rng, r, lo, hi, z_bed)
        set_world(scene, SEA, 0.6)
    scene.render.film_transparent = False
    render(scene, os.path.join(OUT, f"{e['id']}.png"))
    bloom(os.path.join(OUT, f"{e['id']}.png"))
    if not MASKS:
        return {"setting": s}
    # the mask: same camera, the setting held out, the team paint in white
    scene.render.film_transparent = True
    for o in bpy.data.objects:
        if o.get("env") and o.type == "MESH":
            if o.get("volume"):  # holdout doesn't cut volumes: leave them out
                o.hide_render = True
            else:
                o.is_holdout = True
    mask_materials(objs)
    scene.view_settings.exposure = MASK_EXPOSURE
    render(scene, os.path.join(OUT, f"{e['id']}_mask.png"))
    scene.view_settings.exposure = 0.0
    return {"setting": s}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    entries = json.load(open(os.path.join(OUT, "defs.json"), encoding="utf-8"))
    global MASKS
    if "--masks" in args:
        MASKS = True
        args.remove("--masks")
    if args and args[0] == "--ids":
        want = args[1].split(",")
        entries = [e for e in entries if e["id"] in want]
    elif args:
        first = int(args[0])
        count = int(args[1]) if len(args) > 1 else 10_000
        entries = entries[first:first + count]
    scene, cam = setup()
    for e in entries:
        picture(scene, cam, e)
        print(f"[picture] {e['id']} {e['setting']}")


main()
