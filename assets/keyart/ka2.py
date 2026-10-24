"""Key art 2, "Volley" (layout ka2_a, docs/art/keyart.md): an Order
air-defence site on a rocky headland at dusk, firing into a Chaos air raid
that comes in over the sea with the low sun behind it. Reuses key art 1's
tools (ka1.py): the layer pipeline, the grade, the effects and the dressing.

    blender -b --factory-startup --python-exit-code 1 -P assets/keyart/ka2.py -- light|test|final [--samples N] [--only layers]

Writes assets/keyart/ka2/light.png (step 3) or assets/keyart/ka2/<mode>/ (step 4).
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import keyart as K  # noqa: E402
import layout as L  # noqa: E402
import ka1 as A  # noqa: E402

OUT = os.path.join(HERE, "ka2")
TOP = 22.0  # the plateau over the sea
HORIZON = 0.5
CAM_H = 4.0
SUN_AZ, SUN_EL = -18.0, 5.0  # low over the sea, behind the raid, left of centre
WIND = Vector((0.5, 0.35, 0.0))
X = L.X


def rock_material(fade=None):
    """Weathered headland rock: grey-brown stone in big patches, darker
    cracks, dry grass and lichen in the hollows, burnt black where the bombs
    fell (the mesh's `scorch` attribute); optionally fading out (layers)."""
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

        stone = ramp(noise_tex(0.04, 5).outputs["Fac"], [(0.3, (104, 96, 86)), (0.55, (132, 122, 108)), (0.78, (96, 90, 82))])
        crack = ramp(noise_tex(0.9, 10, 0.7).outputs["Fac"], [(0.28, (255, 255, 255)), (0.34, (0, 0, 0)), (0.4, (255, 255, 255))])
        col = mix(ramp(noise_tex(1.2).outputs["Fac"], [(0.3, (48, 44, 40)), (0.7, (62, 56, 50))]), stone, bw(crack))
        grass = ramp(noise_tex(0.06, 4).outputs["Fac"], [(0.55, (0, 0, 0)), (0.66, (255, 255, 255))])
        col = mix(col, ramp(noise_tex(0.8).outputs["Fac"], [(0.3, (112, 100, 66)), (0.7, (140, 124, 80))]), bw(grass))
        attr = N("ShaderNodeAttribute")
        attr.attribute_name = "scorch"
        c2 = N("ShaderNodeMapRange")
        c2.inputs["From Min"].default_value, c2.inputs["From Max"].default_value = 0.3, 0.85
        Ln(attr.outputs["Fac"], c2.inputs["Value"])
        col = mix(col, ramp(noise_tex(1.4).outputs["Fac"], [(0.3, (24, 22, 20)), (0.7, (44, 40, 36))]), c2.outputs["Result"])
        b = N("ShaderNodeBsdfPrincipled")
        Ln(col, b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.88
        b1 = N("ShaderNodeBump")
        K.set_in(b1, "Strength", 0.6)
        K.set_in(b1, "Distance", 0.4)
        Ln(noise_tex(0.35, 10, 0.65).outputs["Fac"], b1.inputs["Height"])
        b2 = N("ShaderNodeBump")
        K.set_in(b2, "Strength", 0.4)
        K.set_in(b2, "Distance", 0.06)
        Ln(noise_tex(4.0, 12, 0.7).outputs["Fac"], b2.inputs["Height"])
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
    return K.material(f"rock_{fade}", build)


def rock_blast(layer, pos, size, seed, fresh=False):
    """A bomb on rock: the explosion (fireball, soot, debris, light) plus
    grey rock dust thrown up in columns and a dust ring, and stone chips."""
    rng = random.Random(seed)
    p = Vector(pos)
    K.explosion(layer, tuple(p), size, smoke=1.1, seed=seed)
    dust = K.volume_material("rock_dust", (150, 140, 128), 1.4, scale=2.2, cut=0.34, soft=0.4, vary=0.4)
    for k in range(rng.randint(4, 6)):
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0))
        K.blob_dir(layer, p, d, size * rng.uniform(2.0, 3.6), size * rng.uniform(0.25, 0.42), dust, seed + 200 + k)
    ring = K.volume_material("rock_ring", (136, 128, 116), 0.8, scale=2.0, cut=0.38, soft=0.4)
    for k in range(10):
        a = k / 10 * 2 * math.pi
        r = size * rng.uniform(2.0, 2.6)
        s = size * rng.uniform(0.5, 0.75)
        K.blob(layer, p + Vector((math.cos(a) * r, math.sin(a) * r, s * 0.35)), (s * 1.3, s, s * 0.5), ring, seed + 300 + k)
    if fresh:
        core = K.prim("ico_sphere", layer, subdivisions=2, radius=size * 0.35, location=p + Vector((0, 0, size * 0.6)))
        K.set_mat(core, K.emissive("blast_core", (255, 240, 210), 18.0))
        K.point(p + Vector((0, 0, size)), (255, 190, 120), 12000 * size, radius=size * 0.8, layer=layer)


def shield_dome(layer, center, radius, hits, seed):
    """The Phalanx's shield: a faint cyan bubble, brighter at its rim, with
    bomb hits flaring on its surface."""
    rng = random.Random(seed)

    def build(nt, out):
        N, Ln = nt.nodes.new, nt.links.new
        lw = N("ShaderNodeLayerWeight")
        K.set_in(lw, "Blend", 0.15)
        em = N("ShaderNodeEmission")
        em.inputs["Color"].default_value = K.lib.srgb((90, 210, 255))
        em.inputs["Strength"].default_value = 1.6
        tr = N("ShaderNodeBsdfTransparent")
        mx = N("ShaderNodeMixShader")
        ramp = N("ShaderNodeMapRange")
        ramp.inputs["To Min"].default_value, ramp.inputs["To Max"].default_value = 0.0, 0.5
        Ln(lw.outputs["Facing"], ramp.inputs["Value"])
        Ln(ramp.outputs["Result"], mx.inputs["Fac"])
        Ln(tr.outputs["BSDF"], mx.inputs[1])
        Ln(em.outputs["Emission"], mx.inputs[2])
        Ln(mx.outputs["Shader"], out.inputs["Surface"])
    c = Vector(center)
    o = K.prim("uv_sphere", layer, segments=48, ring_count=24, radius=radius, location=c)
    o.scale = (radius, radius, radius * 0.8)
    K.set_mat(o, K.material("shield", build))
    o.visible_shadow = False
    for k in range(hits):
        a, e = rng.uniform(0, 2 * math.pi), rng.uniform(0.35, 1.2)
        q = c + Vector((math.cos(a) * math.cos(e) * radius, math.sin(a) * math.cos(e) * radius, math.sin(e) * radius * 0.8))
        K.explosion(layer, tuple(q), rng.uniform(1.2, 2.2), smoke=0.6, debris=False, seed=seed + k)
        K.point(q, (120, 220, 255), 5000, radius=1.0, layer=layer)


def build(scene, rough=True):
    L.CLAY_MODE = False
    K.GLOW_SCALE = 0.5
    K.CRATERS.clear()
    K.AVOID.clear()
    A.EDGES = ((30.0, "near"), (140.0, "mid"), (285.0, "far"))  # beyond: the sea, the fleet, the sky
    A.GROUND_MATERIAL = rock_material
    A.SEA_FROM = 120.0
    land = L.CliffLand(lambda x, y: 170 + 10 * math.sin(x / 70) - y, top=TOP)

    def gz(x, y):
        return land.z(x, y) + K.crater_z(x, y)
    cam_z = land.z(0, 0) + CAM_H
    K.height = lambda x, y, amp=0.0, seed=0.0: gz(x, y)
    K.cam_rig(scene, cam_z, 0.05 + 0.9 * HORIZON, L.RENDER_LENS, y=0.0)
    K.sky(scene, elevation=SUN_EL, azimuth=SUN_AZ, strength=0.11, sun_size=0.8, sun_intensity=0.02)
    K.sun(SUN_EL, SUN_AZ, 3.0, (255, 170, 96), angle=1.0)
    K.fill(0.75, (120, 150, 215), azimuth=SUN_AZ + 180, elevation=70.0, angle=70.0)  # cool sky light: shadows blue, not black
    with A.Group(400):
        A.haze_box()

    bombs = [(0.62, 54, 3.0, True), (0.3, 90, 2.6, False), (0.82, 68, 2.4, False), (0.46, 112, 3.4, True),
             (0.14, 64, 2.0, False), (0.7, 126, 2.8, False), (0.92, 104, 2.2, False), (0.38, 36, 1.6, False)]
    bombs = [(X(sx, y), y, sz, fresh) for sx, y, sz, fresh in bombs]
    for x, y, sz, _ in bombs:
        K.CRATERS.append((x, y, sz))
    rng = random.Random(81)
    for _ in range(30):
        y = rng.uniform(12, 160)
        K.CRATERS.append((X(rng.uniform(-0.05, 1.05), y), y, rng.uniform(1.0, 2.6)))
    ground = {"sky": A.terrain(land, "sky", -480, 480, -10, 300, 2.0)}

    # --- the site: layout ka2_a's placements ---
    sites = [("ord_seraph", 0.3, 22, 20), ("ord_sanction", 0.06, 46, 30), ("ord_vigil", 0.52, 40, 0),
             ("ord_lumen", 0.74, 46, -20), ("ord_phalanx", 0.2, 80, 0), ("ord_citadel", 0.46, 96, 180),
             ("ord_oracle", 0.64, 78, 30), ("ord_watchtower", 0.9, 92, 0)]
    keep, rails, roots = [], {}, []
    for uid, sx, y, hd in sites:
        x = X(sx, y)
        with A.Group(y):
            roots.append(L.put(land, uid, x, y, hd))
        keep.append((x, y, 16))
        rails[uid] = (x, y, gz(x, y) + 4)
    hero = Vector((X(0.4, 60), 60, 0))
    with A.Group(hero.y):
        hero_root = A.commander(land, hero.x, hero.y, 95)  # in profile: no round lights facing the camera
    keep.append((hero.x, hero.y, 16))
    with A.Group(80):
        mobile = L.scatter(land, L.ORDER_AA, (0.05, 0.95, 30, 120), 8, 10, 11, keep=keep, screen=True)
    for root in roots + [u["root"] for u in mobile] + [hero_root]:
        with A.Group(root.location.y):
            A.contact_shadow(root, land)
    for uid, sx, y, hd in (("ord_vigil", 0.12, 26, 120), ("ord_halo", 0.83, 30, 200)):  # bomb damage
        x = X(sx, y)
        with A.Group(y):
            L.put(land, uid, x, y, hd, wreck=True)
            K.explosion("mid", (x, y, gz(x, y) + 1.2), 1.3, smoke=0.7, debris=False, seed=int(x * 7 + y))
            K.smoke_column("mid", (x, y, gz(x, y) + 1.5), 12, 1.4, 900 + int(y), drift=(WIND.x, WIND.y))

    # --- the bombs falling on it, the shield taking hits ---
    for i, (x, y, sz, fresh) in enumerate(bombs):
        with A.Group(y):
            rock_blast("mid", (x, y, gz(x, y)), sz, 700 + i * 13, fresh=fresh)
    px, py = X(0.2, 80), 80
    with A.Group(py):
        shield_dome("mid", (px, py, gz(px, py)), 24.0, 4, 760)
    for i, (sx, y, h, w) in enumerate(((0.7, 104, 26, 2.6), (0.92, 128, 22, 2.4))):
        with A.Group(y):
            K.smoke_column("mid", (X(sx, y), y, gz(X(sx, y), y)), h, w, 770 + i, drift=(WIND.x, WIND.y))
    for y0, y1 in ((12, 30), (30, 140)):
        with A.Group((y0 + y1) / 2):
            K.battlefield_debris("mid", (X(-0.05, y1), X(1.05, y1), y0, y1), int((y1 - y0) * 0.6), seed=790 + y0)

    # --- the raid ---
    craft = [("chs_behemoth", 0.4, 170, 26, 180, 0, 0), ("chs_behemoth", 0.55, 186, 29, 185, 0, 0),
             ("chs_behemoth", 0.28, 196, 32, 175, 0, 0), ("chs_plague", 0.66, 150, 22, 190, 0, 10),
             ("chs_banshee", 0.16, 180, 26, 160, 0, -20), ("chs_harpy", 0.86, 160, 22, 210, 0, 25)]
    air = []
    for uid, sx, y, z, hd, pitch, bank in craft:
        x = X(sx, y)
        with A.Group(y):
            L.put(land, uid, x, y, hd, z=z + TOP, tilt=(pitch, bank))
        air.append((Vector((x, y, z + TOP)), K.forward(hd) * 3.5))
    close = L.at_screen(0.74, 0.3, 23.0, cam_z, HORIZON)
    with A.Group(close.y) as jet_group:
        jet = K.hero_jet("mid", "chs_manticore", tuple(close), 200, -14, L.bank_to_cam(close.x, close.y, 200, 35), 500)
    bpy.context.view_layer.update()
    for o in jet_group.new:
        if o is not jet and o.parent is None and o.type != "LIGHT":
            mw = o.matrix_world.copy()
            o.parent = jet
            o.matrix_world = mw
    v = K.forward(200) * 0.2
    for frame, d in ((0, -1), (1, 0), (2, 1)):
        jet.location = close + v * d
        jet.keyframe_insert("location", frame=frame)
    scene.frame_set(1)
    sams = [("ord_seraph", 0, 0.8, {"turn": 9}), ("ord_seraph", 1, 0.65, {"turn": 11}), ("ord_sanction", 2, 0.7, {"turn": 8}),
            ("ord_vigil", 3, 0.6, {"turn": 13}), ("ord_sanction", 4, 0.85, {"turn": 10})]
    for i, (rail, ti, cut, kw) in enumerate(sams):
        with A.Group((rails[rail][1] + air[ti][0].y) / 2):
            K.sam("mid", rails[rail], air[ti], 600 + i, "ord_radar_sam" if i % 2 else "ord_ir_sam", "order", width=1.9, cut=cut, **kw)
    for i, rail in enumerate(("ord_seraph", "ord_sanction")):
        with A.Group(rails[rail][1]):
            A.launch_cloud("mid", (rails[rail][0], rails[rail][1], rails[rail][2] - 2), 1.2, 650 + i)
    kx = X(0.6, 165)
    with A.Group(165):
        K.kill("mid", rails["ord_seraph"], ("chs_behemoth", kx, 165, 22 + TOP, 200, 0, 3.0), 670, "order", turn=10.0, tilt=0.8)
    lx = rails["ord_lumen"]
    rng = random.Random(680)
    with A.Group(lx[1]):
        for k in range(8):  # the flak tower's streams of tracer
            K.flak_stream("mid", (lx[0], lx[1], lx[2] + 2), (lx[0] + rng.uniform(-60, 20), lx[1] + rng.uniform(80, 160), lx[2] + rng.uniform(40, 70)), 690 + k)
    for k in range(10):  # flak bursting among the bombers
        y = rng.uniform(160, 260)
        with A.Group(y):
            K.burst("mid", (X(rng.uniform(0.2, 0.75), y), y, TOP + rng.uniform(22, 48)), rng.uniform(1.6, 2.6), seed=700 + k)

    # --- the Chaos fleet offshore, firing on the headland ---
    ships = [("chs_kraken", 0.25, 300, 80), ("chs_leviathan", 0.55, 330, 95), ("chs_siren", 0.8, 300, 100)]
    with A.Group(320):
        for i, (uid, sx, y, hd) in enumerate(ships):
            x = X(sx, y)
            L.put(land, uid, x, y, hd, z=0.0)
            A.wake("mid", (x, y, 0), hd, 30, 800 + i)
            tx, ty = bombs[i * 2][0], bombs[i * 2][1]
            A.broadside_arcs("mid", (x, y, 0), hd, (tx, ty, gz(tx, ty)), 810 + i, guns=3)

    # --- the foreground ---
    with A.Group(20):
        for i, (sx, y, s_) in enumerate(((0.04, 20, 2.2), (0.55, 16, 1.2), (0.7, 19, 1.8), (0.97, 24, 2.6), (0.42, 22, 1.0))):
            A.rock("mid", (X(sx, y), y, gz(X(sx, y), y) - 0.3), s_, 900 + i)
        tufts = K.grass_tufts("mid", (X(-0.05, 27), X(1.05, 27), 14, 27), 26, 910, length=1.0)
        tufts.data.materials[1] = A.dry_grass_material()
        K.ember_field("mid", (X(0, 29), X(1, 29), 15, 29, 0, 10), 100, 920)
    with A.Group(80):
        K.ember_field("mid", (X(0, 130), X(1, 130), 30, 130, 0, 20), 140, 921)

    # --- rim light on the heroes: the firing Seraph and the close jet ---
    bpy.context.view_layer.update()
    sun_dir = K.forward(SUN_AZ)
    seraph = roots[0]
    with A.Group(close.y):
        behind = (close - scene.camera.location).normalized()
        A.rim_light([o for o in jet.children_recursive if o.type == "MESH"], close + behind * 12 + sun_dir * 4 + Vector((0, 0, 5)), close, 40000)
    sp = Vector(rails["ord_seraph"])
    with A.Group(sp.y):
        A.rim_light([o for o in seraph.children_recursive if o.type == "MESH"], sp + sun_dir * 14 + Vector((0, 0, 5)), sp, 20000, size=6)
    info = {"hero": hero, "close": close, "land": land, "ground": ground}
    A.layer_ground(land, info)
    return info


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
        A.render_final(scene, info, res, samples, os.path.join(OUT, mode), only)
        print(f"[ka2] {mode} -> {os.path.join(OUT, mode)}")
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
    print(f"[ka2] {mode} -> {os.path.join(OUT, mode + '.png')}")


if __name__ == "__main__":
    main()
