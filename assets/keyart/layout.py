"""Key art layout options (docs/art/keyart.md, step 2): grey blockout renders
of a key art's composition, no VFX. Each option renders the real camera
(clay: Order light grey, Chaos dark grey, wrecks darker; white lines where
the SAM trails will run, dark posts where the smoke columns rise) with
guides drawn over it (the 5% bleed, the text bands, the thirds, the focal
point), next to a top-down plan of the camera, its field of view and the
units.

    blender -b --factory-startup --python-exit-code 1 -P assets/keyart/layout.py -- <option> [<option> ...]

Writes assets/keyart/layouts/<option>.png.
"""

import math
import os
import random
import sys

import bpy
import bmesh
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Matrix, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import keyart as K  # noqa: E402

OUT = os.path.join(HERE, "layouts")
LENS = 26.0  # the visible frame's lens (full-frame equivalent)
RENDER_LENS = LENS * 0.9  # the render covers the 5% bleed on each side
TAN = 18.0 / LENS  # tan of the visible half field of view
TOP_BAND = 0.12  # the loading screens' title band (visible frame)
BOTTOM_BAND = 0.25  # tip and bar

CLAY = {}
CLAY_MODE = True  # the lit scenes (ka1.py) place the same units with their real materials


def clay(kind):
    if kind not in CLAY:
        rgb = {"order": (206, 202, 192), "chaos": (64, 66, 70), "wreck": (40, 38, 36), "ground": (150, 146, 138),
               "sea": (66, 78, 86), "trail": (245, 245, 245), "smoke": (96, 92, 88), "crater": (96, 92, 86),
               "fov": (230, 60, 40)}[kind]
        CLAY[kind] = K.solid(f"clay_{kind}", rgb, 0.8)
    return CLAY[kind]


# ---------------------------------------------------------------------------
# Terrain: desert dunes running down to a coast
# ---------------------------------------------------------------------------

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


class Land:
    """Desert height field. `coast(x, y)` is the signed distance to the
    shoreline in studs (positive on land); `extra(x, y)` adds ridges."""

    def __init__(self, coast, extra=None, amp=1.8):
        self.coast, self.extra, self.amp = coast, extra or (lambda x, y: 0.0), amp

    def z(self, x, y):
        s = self.coast(x, y)
        dunes = self.amp * noise.fractal(Vector((x / 70.0, y / 70.0, 1.0)), 0.6, 2.0, 4) \
            + 0.5 * noise.noise(Vector((x / 16.0, y / 16.0, 2.0)))
        if s < 0:
            return s * 0.06 - 0.2
        return 0.4 + dunes * smooth(0, 90, s) + min(s, 50) * 0.03 + self.extra(x, y) * smooth(0, 40, s)

    def build(self, x0, x1, y0, y1, step):
        bm = bmesh.new()
        nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
        vs = [bm.verts.new((x0 + i * step, y0 + j * step, self.z(x0 + i * step, y0 + j * step))) for j in range(ny) for i in range(nx)]
        for j in range(ny - 1):
            for i in range(nx - 1):
                a = j * nx + i
                bm.faces.new((vs[a], vs[a + 1], vs[a + nx + 1], vs[a + nx]))
        me = bpy.data.meshes.new("land")
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new("land", me)
        me.materials.append(clay("ground"))
        K.link(o, "mid")
        sea = bpy.data.meshes.new("sea")
        bm = bmesh.new()
        for v in ((x0 - 3000, y0, 0), (x1 + 3000, y0, 0), (x1 + 3000, y1 + 6000, 0), (x0 - 3000, y1 + 6000, 0)):
            bm.verts.new(v)
        bm.faces.new(bm.verts)
        bm.to_mesh(sea)
        bm.free()
        so = bpy.data.objects.new("sea", sea)
        sea.materials.append(clay("sea"))
        K.link(so, "mid")
        # far dunes beyond the terrain patch, so the horizon isn't the edge of a mesh
        return o


# ---------------------------------------------------------------------------
# Units in clay, poses
# ---------------------------------------------------------------------------

POSES = {"ord_warden": {"base": (0, 0, 0, 0, -0.4, 0), "spades": (100, 0, 0), "jacks": (0, 0, 0, 0, -0.5, 0),
                        "shieldL": (0, 90, 0), "shieldR": (0, -90, 0), "barrel": (12, 0, 0)}}
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()  # model space (Roblox: Y up, -Z forward) to Blender


def apply_pose(root, uid, pose):
    """Applies a blockout pose (piece: rx, ry, rz degrees [, dx, dy, dz])
    to the imported mesh pieces, about the rig's pivots, parents first."""
    import json
    rig = json.load(open(os.path.join(K.ROOT, "assets", "models", uid, "export", "rig.json")))["pieces"]
    model = {}

    def mat(name):
        if name in model:
            return model[name]
        piece = rig[name]
        m = mat(piece["parent"]) if piece.get("parent") else Matrix.Identity(4)
        if name in pose:
            p = list(pose[name]) + [0, 0, 0]
            piv = Vector(piece.get("pivot", piece["center"]))
            r = Matrix.Rotation(math.radians(p[0]), 4, "X") @ Matrix.Rotation(math.radians(p[1]), 4, "Y") @ Matrix.Rotation(math.radians(p[2]), 4, "Z")
            local = Matrix.Translation(Vector(p[3:6])) @ Matrix.Translation(piv) @ r @ Matrix.Translation(-piv)
            m = m @ local
        model[name] = m
        return m

    names = sorted(rig, key=len, reverse=True)
    for o in root.children:
        piece = next((n for n in names if o.name.startswith(n + "_") or o.name == n), None)
        if piece:
            o.matrix_basis = C @ mat(piece) @ C.inverted() @ o.matrix_basis


def put(land, uid, x, y, heading=0.0, z=None, wreck=False, tilt=(0.0, 0.0), pose=None, layer="mid"):
    """Places a unit in clay on the land (or at z for aircraft and ships)."""
    zz = land.z(x, y) - 0.1 if z is None else z
    root = K.place(uid, layer, x, y, heading, z=zz, wreck=wreck, tilt=tilt)
    kind = "wreck" if wreck else K.FACTION[uid[:3]]
    for o in root.children:
        if o.type == "MESH" and CLAY_MODE:
            K.lib.assign_single_material([o], clay(kind))
    if pose or (not wreck and uid in POSES):
        apply_pose(root, uid, pose or POSES[uid])
    return root


def line(points, width, kind="trail", layer="mid"):
    pts = [Vector(p) for p in points]
    for a, b in zip(pts, pts[1:]):
        d = b - a
        if d.length < 1e-3:
            continue
        o = K.prim("cylinder", layer, vertices=6, radius=width, depth=d.length, location=(a + b) / 2)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        K.set_mat(o, clay(kind))


def sam_marker(land, start, target, vel, seed, cut=0.8, **kw):
    pts, _ = K.sam_path(Vector(start), Vector(target), Vector(vel), seed, cut=cut, **kw)
    line(pts, 0.5)


def smoke_post(land, x, y, h=60.0, r=2.0):
    z = land.z(x, y) if land else 0.0
    o = K.prim("cone", "mid", vertices=12, radius1=r * 0.5, radius2=r * 1.4, depth=h, location=(x, y, z + h / 2))
    K.set_mat(o, clay("smoke"))


def crater(land, x, y, r):
    o = K.prim("cylinder", "mid", vertices=16, radius=r, depth=0.3, location=(x, y, land.z(x, y) + 0.05))
    K.set_mat(o, clay("crater"))


def at_screen(sx, sy, dist, height_, horizon):
    """World point (camera at the origin, `height_` up, looking +Y, yaw 0)
    at visible-frame coords (sx, sy from the top left) and forward distance."""
    vfov_half = math.atan(TAN * 9 / 16)
    up = (horizon - sy) * 2 * math.tan(vfov_half)  # horizon is on screen row `horizon`; ignores the tiny pitch
    return Vector(((sx - 0.5) * 2 * TAN * dist, dist, height_ + up * dist))


# ---------------------------------------------------------------------------
# Render, plan, guides
# ---------------------------------------------------------------------------

def plain_world(scene):
    w = bpy.data.worlds.new("clay_sky")
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    grad = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(grad.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.5, K.lib.srgb((196, 192, 186))
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.7, K.lib.srgb((128, 134, 146))
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.7
    scene.world = w


def sun_disc(scene, az, el):
    d = Vector((math.sin(math.radians(az)) * math.cos(math.radians(el)), math.cos(math.radians(az)) * math.cos(math.radians(el)),
                math.sin(math.radians(el))))
    o = K.prim("uv_sphere", "mid", segments=24, ring_count=12, radius=60.0, location=d * 3000 + Vector((0, 0, 5)))
    K.set_mat(o, K.emissive("sun_disc", (255, 236, 200), 6.0))
    o.visible_shadow = False


def render(scene, path, w, h, samples):
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.cycles.samples = samples
    scene.render.film_transparent = False
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return K.load(path)


def guides(img, focal):
    """Guides over the eye render (rows bottom-up, RGBA floats): the bleed
    darkened, the text bands tinted, thirds lines, the focal ring."""
    h, w = img.shape[:2]
    out = img.copy()
    bx, by = int(w * 0.05), int(h * 0.05)
    vis = np.zeros((h, w, 1), dtype=bool)
    vis[by:h - by, bx:w - bx] = True
    out[..., :3] = np.where(vis, out[..., :3], out[..., :3] * 0.35)
    vh = h - 2 * by
    top0 = h - by - int(vh * TOP_BAND)  # rows bottom-up: the top band is near the top row
    bot1 = by + int(vh * BOTTOM_BAND)
    red = np.array([0.9, 0.25, 0.2], dtype=np.float32)
    for r0, r1 in ((top0, h - by), (by, bot1)):
        out[r0:r1, bx:w - bx, :3] = out[r0:r1, bx:w - bx, :3] * 0.8 + red * 0.2
    for f in (1 / 3, 2 / 3):
        x = bx + int((w - 2 * bx) * f)
        out[by:h - by, x:x + 1, :3] = out[by:h - by, x:x + 1, :3] * 0.4 + 0.6
        y = by + int(vh * f)
        out[y:y + 1, bx:w - bx, :3] = out[y:y + 1, bx:w - bx, :3] * 0.4 + 0.6
    if focal is not None:
        fx, fy = focal[0] * w, focal[1] * h
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.sqrt((xx - fx) ** 2 + (yy - fy) ** 2)
        ring = (np.abs(d - h * 0.09) < 2.0)[..., None]
        out[..., :3] = np.where(ring, np.array([1.0, 0.85, 0.1], dtype=np.float32), out[..., :3])
    return out


def run(name, build):
    scene = K.setup(True)
    for cache in (CLAY, K._PRIMS, K._imgs, K.TRAIL_MATS):  # the previous option's data blocks are gone
        cache.clear()
    K.CRATERS.clear()
    plain_world(scene)
    spec = build(scene)
    cam = scene.camera
    os.makedirs(OUT, exist_ok=True)
    eye = render(scene, os.path.join(OUT, f"_{name}_eye.png"), 1024, 576, 32)
    focal = None
    if spec.get("focal") is not None:
        p = world_to_camera_view(scene, cam, Vector(spec["focal"]))
        focal = (p.x, p.y)
    eye = guides(eye, focal)
    # plan view: an orthographic camera straight down, the field of view drawn in red
    x0, x1, y0, y1 = spec["plan"]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for side in (-1, 1):
        a = math.atan(TAN) * side
        line([(0, 0, 40), (math.sin(a) * 900, math.cos(a) * 900, 40)], 2.0, "fov")
    K.sun(70, 30, 3.0, (255, 255, 255), angle=5.0)
    pd = bpy.data.cameras.new("plan")
    pd.type = "ORTHO"
    pd.ortho_scale = max(x1 - x0, y1 - y0)
    pd.clip_end = 5000
    pc = bpy.data.objects.new("plan", pd)
    scene.collection.objects.link(pc)
    pc.location = (cx, cy, 1500)
    scene.camera = pc
    plan = render(scene, os.path.join(OUT, f"_{name}_plan.png"), 576, 576, 8)
    sheet = np.concatenate([eye, plan], axis=1)
    K.save(sheet, os.path.join(OUT, f"{name}.png"))
    for f in ("eye", "plan"):
        os.remove(os.path.join(OUT, f"_{name}_{f}.png"))
    print(f"[layout] {name} -> {os.path.join(OUT, name + '.png')}")


# ---------------------------------------------------------------------------
# Key art 1 options
# ---------------------------------------------------------------------------

ORDER_TANKS = ["ord_paladin", "ord_lancer"]
CHAOS_TANKS = ["chs_ravager", "chs_ravager", "chs_minotaur", "chs_goliath"]


def scatter(land, uids, region, count, heading, seed, spread=20, keep=(), layer="mid", screen=False):
    """Units drawn from `uids` in region (x0, x1, y0, y1) with spacing. With
    `screen`, x0 and x1 are fractions of the visible frame's width instead,
    so every unit lands in the picture."""
    rng = random.Random(seed)
    x0, x1, y0, y1 = region
    placed = list(keep)
    out = []
    tries = 0
    while len(out) < count and tries < 2000:
        tries += 1
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if screen:
            x = (x - 0.5) * 2 * TAN * y
        if any(math.hypot(x - px, y - py) < pr for px, py, pr in placed):
            continue
        uid = rng.choice(uids)
        root = put(land, uid, x, y, heading + rng.uniform(-spread, spread), layer=layer)
        placed.append((x, y, 14))
        out.append({"x": x, "y": y, "z": land.z(x, y) - 0.1, "root": root, "uid": uid})
    return out


def bank_to_cam(x, y, heading, deg):
    """A bank of `deg` that tips the aircraft's lift side toward the camera
    (at the origin): positive roll drops the right wing."""
    right = Vector((math.cos(math.radians(heading)), -math.sin(math.radians(heading))))
    return deg if Vector((-x, -y)).dot(right) > 0 else -deg


def sky_units(land, sams, kills, craft):
    """Aircraft (uid, x, y, z, heading, pitch, bank), SAM markers from
    launchers to aircraft, and hit aircraft as falling wrecks."""
    pos = []
    for uid, x, y, z, hd, pitch, bank in craft:
        put(land, uid, x, y, hd, z=z, tilt=(pitch, bank))
        pos.append((Vector((x, y, z)), K.forward(hd) * 3.5))
    for i, (start, ti, cut, kw) in enumerate(sams):
        p, v = pos[ti]
        sam_marker(land, start, p, v, 40 + i, cut=cut, **kw)
    for uid, x, y, z, hd in kills:
        put(land, uid, x, y, hd, z=z, wreck=True, tilt=(-35, 50))
        line([(x, y, z), (x - 8, y + 6, z + 14), (x - 20, y + 14, z + 22)], 1.6, "smoke")


def option_a(scene):
    """A: "Commander's stand". Camera low behind the Order line on open
    desert, the Commander on the right third; the Chaos line across the
    field backlit by the sun just above the horizon behind it; the sea a
    band along the horizon with the fleets; the close fighter sweeping in
    from the top left toward the Commander."""
    horizon = 0.56
    K.cam_rig(scene, 5.0, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    land = Land(lambda x, y: 250 + 18 * math.sin(x / 90) - y)
    land.build(-420, 420, -10, 420, 3.0)
    K.sun(5, -12, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.6, (200, 210, 230))
    sun_disc(scene, -12, 5)
    hero = Vector((10, 36, 0))
    hero.z = land.z(hero.x, hero.y)
    put(land, "ord_sovereign", hero.x, hero.y, 40)
    put(land, "ord_warden", -30, 64, 15)
    put(land, "ord_seraph", -56, 52, 10)
    put(land, "ord_vigil", -14, 86, 0)
    put(land, "ord_phalanx", -76, 92, 0)
    keep = [(hero.x, hero.y, 16), (-30, 64, 14), (-56, 52, 14), (-14, 86, 12), (-76, 92, 18)]
    scatter(land, ORDER_TANKS, (-90, 50, 20, 80), 9, 5, 1, keep=keep)
    put(land, "chs_cyclops", 30, 176, 185)
    put(land, "chs_thorn", -40, 168, 175)
    put(land, "chs_carapace", 74, 186, 180)
    put(land, "chs_hydra", -80, 158, 160)
    put(land, "chs_eye", 56, 138, 0, wreck=True, tilt=(0, 72))  # the toppled radar
    keep = [(30, 176, 14), (-40, 168, 12), (74, 186, 18), (-80, 158, 14), (56, 138, 14)]
    scatter(land, CHAOS_TANKS, (-110, 110, 100, 165), 11, 180, 2, keep=keep)
    for uid, x, y, hd in (("ord_dominion", -130, 320, 95), ("ord_crusader", -50, 360, 80), ("chs_kraken", 70, 330, -90),
                          ("chs_corsair", 150, 380, -100), ("chs_kraken", 210, 300, -85)):
        put(land, uid, x, y, hd, z=0.0)
    put(land, "chs_ravager", -12, 18, 210, wreck=True, tilt=(4, -8))
    put(land, "ord_lancer", 26, 24, 140, wreck=True, tilt=(-3, 5))
    put(land, "ord_bulwark", -48, 34, 30, wreck=True)
    close = at_screen(0.24, 0.3, 21.0, 5.0, horizon)
    craft = [("ord_falcon", close.x, close.y, close.z, 125, -8, bank_to_cam(close.x, close.y, 125, 30)),
             ("ord_falcon", -28, 66, 24, 110, -5, bank_to_cam(-28, 66, 110, 20)), ("chs_harpy", 26, 128, 36, -120, 0, -30),
             ("chs_plague", -30, 190, 48, 150, 0, 0), ("chs_wasp", 48, 104, 14, 200, 8, 0),
             ("ord_guardian", -40, 50, 13, 20, 8, 0), ("ord_absolution", 64, 220, 54, -80, 0, 10)]
    sams = [((-56, 52, 4), 2, 0.85, {"turn": 9}), ((-14, 86, 4), 3, 0.7, {"turn": 12}), ((-56, 52, 4), 4, 0.6, {"turn": 13}),
            ((-40, 168, 4), 1, 0.75, {"turn": 10}), ((-80, 158, 4), 6, 0.5, {})]
    sky_units(land, sams, [("chs_harpy", -6, 150, 34, -150)], craft)
    for x, y in ((30, 160), (-70, 170), (90, 210), (-50, 360), (-24, 60), (120, 390)):
        smoke_post(land if y < 250 else None, x, y)
    for x, y, r in ((-4, 54, 3), (16, 78, 2.5), (-30, 110, 3), (44, 122, 2.5), (-66, 130, 3)):
        crater(land, x, y, r)
    return {"focal": hero + Vector((0, 0, 6)), "plan": (-160, 220, -10, 410)}


def option_b(scene):
    """B: "Fighter pass". The close fighter is the focal point on the left
    third, banking toward the camera over a dune ridge; behind it the armies
    meet side-on (Order left, Chaos right, backlit by the sun right of
    centre); the coast runs across the frame with the fleets firing
    broadsides on a sea band; the Commander in the middle ground."""
    horizon = 0.52
    K.cam_rig(scene, 7.0, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    land = Land(lambda x, y: 150 + 10 * math.sin(x / 60) - y,
                extra=lambda x, y: 3.0 * math.exp(-((y - 16) / 8) ** 2))  # the dune ridge under the camera
    land.build(-320, 320, -10, 300, 3.0)
    K.sun(5, 22, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.6, (200, 210, 230))
    sun_disc(scene, 22, 5)
    hero = Vector((10, 58, 0))
    hero.z = land.z(hero.x, hero.y)
    put(land, "ord_sovereign", hero.x, hero.y, 70)
    put(land, "ord_warden", -46, 84, 85)
    put(land, "ord_seraph", -74, 64, 80)
    put(land, "ord_radiance", -90, 100, 0)
    keep = [(hero.x, hero.y, 16), (-46, 84, 14), (-74, 64, 14), (-90, 100, 18)]
    scatter(land, ORDER_TANKS, (-100, -8, 30, 105), 9, 80, 3, keep=keep)
    put(land, "chs_cyclops", 80, 112, -95)
    put(land, "chs_thorn", 100, 86, -90)
    put(land, "chs_inferno", 116, 118, 0)
    put(land, "chs_hydra", 66, 80, -100)
    keep = [(80, 112, 14), (100, 86, 12), (116, 118, 18), (66, 80, 14)]
    scatter(land, CHAOS_TANKS, (16, 110, 40, 120), 10, -95, 4, keep=keep)
    put(land, "chs_spike", 40, 100, 0, wreck=True)  # the broken turret
    for uid, x, y, hd in (("ord_dominion", -110, 200, 90), ("ord_crusader", -40, 230, 85), ("ord_crusader", -170, 250, 95),
                          ("chs_kraken", 80, 210, -90), ("chs_corsair", 150, 240, -95), ("chs_kraken", 30, 270, -85)):
        put(land, uid, x, y, hd, z=0.0)
    put(land, "chs_ravager", 22, 32, 250, wreck=True, tilt=(5, 6))
    put(land, "ord_lancer", -30, 40, 120, wreck=True)
    close = at_screen(0.3, 0.32, 16.0, 7.0, horizon)
    craft = [("ord_falcon", close.x, close.y, close.z, 130, -10, bank_to_cam(close.x, close.y, 130, 32)),
             ("ord_falcon", -34, 46, 20, 115, -6, bank_to_cam(-34, 46, 115, 25)), ("chs_harpy", 46, 98, 33, -110, 0, -35),
             ("chs_plague", 20, 150, 45, -95, 0, 0), ("chs_wasp", 72, 66, 15, -80, 8, 0),
             ("ord_guardian", -60, 52, 14, 80, 8, 0), ("ord_absolution", -80, 130, 50, 70, 0, 0)]
    sams = [((-74, 64, 4), 2, 0.85, {"turn": 10}), ((-74, 64, 4), 3, 0.65, {"turn": 8}), ((-90, 100, 6), 4, 0.6, {"turn": 12}),
            ((100, 86, 4), 1, 0.8, {"turn": 11}), ((100, 86, 4), 6, 0.55, {})]
    sky_units(land, sams, [("chs_harpy", 26, 80, 26, -140)], craft)
    for x, y in ((54, 104), (-20, 118), (92, 124), (-40, 230), (30, 270), (-66, 98)):
        smoke_post(land if y < 150 else None, x, y)
    for x, y, r in ((0, 72, 3), (40, 60, 2.5), (-26, 66, 3), (60, 92, 2.5)):
        crater(land, x, y, r)
    return {"focal": close, "plan": (-170, 170, -10, 300)}


def option_c(scene):
    """C: "Beachhead". Camera at the waterline looking along the coast, the
    sea filling the left third; the Commander wading ashore on the left
    third (the focal point) with the Order landing around it; Chaos holding
    the dunes on the right with the sun low behind them; ships firing from
    the sea; the close fighter passing top right."""
    horizon = 0.55
    K.cam_rig(scene, 4.5, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    land = Land(lambda x, y: x + 0.42 * y + 6,
                extra=lambda x, y: 9.0 * smooth(24, 80, x) * smooth(48, 104, y))  # the dunes Chaos holds
    land.build(-320, 320, -10, 360, 3.0)
    K.sun(4, 38, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.6, (200, 210, 230))
    sun_disc(scene, 38, 4)
    hero = Vector((-10, 34, 0))
    hero.z = max(land.z(hero.x, hero.y), -1.0)
    put(land, "ord_sovereign", hero.x, hero.y, 55, z=hero.z - 0.1)
    put(land, "ord_warden", 8, 66, 45)
    put(land, "ord_vigil", -6, 88, 30)
    put(land, "ord_phalanx", 18, 104, 0)
    keep = [(hero.x, hero.y, 16), (8, 66, 14), (-6, 88, 12), (18, 104, 18)]
    scatter(land, ORDER_TANKS + ["ord_tideguard"], (-45, 25, 22, 100), 10, 50, 5, keep=keep)
    put(land, "chs_cyclops", 84, 146, -120)
    put(land, "chs_thorn", 56, 118, -110)
    put(land, "chs_carapace", 104, 172, 0)
    put(land, "chs_hydra", 96, 112, -120)
    put(land, "chs_eye", 70, 166, 0, wreck=True, tilt=(68, 0))  # the toppled radar
    keep = [(84, 146, 14), (56, 118, 12), (104, 172, 18), (96, 112, 14), (70, 166, 14)]
    scatter(land, CHAOS_TANKS, (36, 120, 78, 168), 10, -125, 6, keep=keep)
    for uid, x, y, hd in (("ord_dominion", -110, 180, 30), ("ord_crusader", -80, 120, 25), ("ord_dominion", -170, 260, 20),
                          ("chs_kraken", -220, 380, -150), ("chs_corsair", -150, 420, -160)):
        put(land, uid, x, y, hd, z=0.0)
    put(land, "chs_ravager", 20, 22, 300, wreck=True, tilt=(6, 4))
    put(land, "ord_lancer", -22, 52, 80, wreck=True, z=-0.6)
    close = at_screen(0.74, 0.32, 21.0, 4.5, horizon)
    craft = [("ord_falcon", close.x, close.y, close.z, -130, -8, bank_to_cam(close.x, close.y, -130, 30)),
             ("ord_falcon", 36, 70, 22, -120, -5, bank_to_cam(36, 70, -120, 20)), ("chs_harpy", -14, 120, 30, 120, 0, 30),
             ("chs_plague", 44, 180, 46, -150, 0, 0), ("chs_wasp", 50, 84, 15, -140, 8, 0),
             ("ord_guardian", -22, 64, 12, 40, 8, 0), ("ord_absolution", -44, 170, 52, 60, 0, 0)]
    sams = [((-6, 88, 4), 2, 0.85, {"turn": 10}), ((-6, 88, 4), 3, 0.7, {"turn": 12}), ((56, 118, 8), 1, 0.75, {"turn": 9}),
            ((56, 118, 8), 6, 0.55, {}), ((96, 112, 9), 0, 0.4, {"tilt": 1.2})]
    sky_units(land, sams, [("chs_harpy", 20, 140, 32, 140)], craft)
    for x, y in ((64, 134), (92, 160), (-110, 180), (28, 106), (-20, 50), (112, 128)):
        smoke_post(land if land.coast(x, y) > 0 else None, x, y)
    for x, y, r in ((28, 50, 3), (50, 78, 3), (8, 42, 2.5), (78, 100, 3)):
        crater(land, x, y, r)
    return {"focal": hero + Vector((0, 0, 6)), "plan": (-200, 160, -10, 360)}


OPTIONS = {"ka1_a": option_a, "ka1_b": option_b, "ka1_c": option_c}

# ---------------------------------------------------------------------------
# Key art 2 options: an Order air-defence site on a rocky headland at dusk,
# a Chaos air raid coming in over the sea with the low sun behind it
# ---------------------------------------------------------------------------

def X(sx, y):
    """The world x at forward distance y that sits at `sx` across the visible frame."""
    return (sx - 0.5) * 2 * TAN * y


class CliffLand(Land):
    """A rocky plateau `top` studs over the sea, dropping in a cliff at the
    coast (the signed distance `coast(x, y)`, positive inland)."""

    def __init__(self, coast, top=22.0, extra=None, amp=1.2, fall=0.0):
        super().__init__(coast, extra, amp)
        self.top, self.fall = top, fall  # `fall`: the plateau sinks this much per stud forward (a headland tilting to the sea)

    def z(self, x, y):
        s = self.coast(x, y)
        top = max(4.0, self.top - self.fall * max(0.0, y))
        if s < 0:
            return min(-2.0, s * 0.5) if s < -6 else top * smooth(-6, 0, s) - 2.0 * (1 - smooth(-6, 0, s))
        rocks = self.amp * noise.fractal(Vector((x / 40.0, y / 40.0, 3.0)), 0.6, 2.0, 4) \
            + 0.7 * noise.noise(Vector((x / 9.0, y / 9.0, 4.0)))
        return top * smooth(0, 4, s) + rocks * smooth(0, 15, s) + self.extra(x, y)


def boulders(land, region, count, seed, size=(1.0, 3.5)):
    rng = random.Random(seed)
    x0, x1, y0, y1 = region
    for _ in range(count):
        y = rng.uniform(y0, y1)
        x = X(rng.uniform(x0, x1), y)
        s = rng.uniform(*size)
        o = K.prim("ico_sphere", "mid", subdivisions=1, radius=1.0, location=(x, y, land.z(x, y) + s * 0.2))
        o.scale = (s * rng.uniform(0.8, 1.5), s * rng.uniform(0.7, 1.2), s * rng.uniform(0.5, 0.9))
        o.rotation_euler = Euler((rng.random(), rng.random(), rng.random() * 6))
        K.set_mat(o, clay("ground"))


ORDER_AA = ["ord_halo", "ord_halo", "ord_lancer", "ord_paladin"]


def ka2_site(land, sites, extra_units, seed):
    """The site: (uid, sx, y, heading) placements by frame position, then mobile
    air defence and tanks scattered among them. Returns the launch rails."""
    keep = []
    rails = {}
    for uid, sx, y, hd in sites:
        x = X(sx, y)
        put(land, uid, x, y, hd)
        keep.append((x, y, 16))
        rails[uid + f"@{sx}"] = (x, y, land.z(x, y) + 4)
    for uids, region, count, hd in extra_units:
        scatter(land, uids, region, count, hd, seed, keep=keep, screen=True)
        seed += 1
    return rails


def raid(land, top, craft, sams, kills, rails):
    """Aircraft (uid, sx, y, z over the plateau, heading, pitch, bank),
    SAM markers (rail key, aircraft index, cut, kw), hit aircraft falling."""
    pos = []
    for uid, sx, y, z, hd, pitch, bank in craft:
        x = X(sx, y)
        put(land, uid, x, y, hd, z=z + top, tilt=(pitch, bank))
        pos.append((Vector((x, y, z + top)), K.forward(hd) * 3.5))
    for i, (rail, ti, cut, kw) in enumerate(sams):
        p, v = pos[ti]
        sam_marker(land, rails[rail], p, v, 60 + i, cut=cut, **kw)
    for uid, sx, y, z, hd in kills:
        x = X(sx, y)
        put(land, uid, x, y, hd, z=z + top, wreck=True, tilt=(-30, 40))
        line([(x, y, z + top), (x - 10, y + 8, z + top + 16), (x - 24, y + 18, z + top + 26)], 2.0, "smoke")
    return pos


def ka2_option_a(scene):
    """A: "Volley". Camera low among the launchers on the headland; the
    nearest Seraph firing on the left third is the focal point; trails fan
    up and converge on a Behemoth formation against the sun over the sea;
    a Manticore dives close on the right; the Commander directs the site."""
    top, horizon = 22.0, 0.5
    land = CliffLand(lambda x, y: 170 + 10 * math.sin(x / 70) - y, top=top)
    land.build(-380, 380, -10, 260, 3.0)
    cam_h = land.z(0, 0) + 4.0
    K.cam_rig(scene, cam_h, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    K.sun(5, -18, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.6, (200, 210, 230))
    sun_disc(scene, -18, 5)
    sites = [("ord_seraph", 0.3, 22, 20), ("ord_sanction", 0.06, 46, 30), ("ord_vigil", 0.52, 40, 0),
             ("ord_lumen", 0.74, 46, -20), ("ord_phalanx", 0.2, 80, 0), ("ord_citadel", 0.46, 96, 180),
             ("ord_oracle", 0.64, 78, 30), ("ord_watchtower", 0.9, 92, 0), ("ord_sovereign", 0.4, 60, 20)]
    rails = ka2_site(land, sites, [(ORDER_AA, (0.05, 0.95, 30, 120), 8, 10)], 11)
    for uid, sx, y, hd in (("ord_vigil", 0.12, 26, 120), ("ord_halo", 0.83, 30, 200)):
        put(land, uid, X(sx, y), y, hd, wreck=True)  # bomb damage
    for uid, sx, y, hd in (("chs_kraken", 0.25, 300, 80), ("chs_leviathan", 0.55, 330, 95), ("chs_siren", 0.8, 290, 100)):
        put(land, uid, X(sx, y), y, hd, z=0.0)
    craft = [("chs_behemoth", 0.42, 230, 58, 180, 0, 0), ("chs_behemoth", 0.56, 250, 64, 185, 0, 0),
             ("chs_behemoth", 0.33, 260, 70, 175, 0, 0), ("chs_plague", 0.66, 200, 46, 190, 0, 10),
             ("chs_banshee", 0.2, 180, 40, 160, 0, -20), ("chs_harpy", 0.86, 160, 34, 210, 0, 25)]
    close = at_screen(0.74, 0.3, 23.0, cam_h, horizon)
    put(land, "chs_manticore", close.x, close.y, 200, z=close.z, tilt=(-14, bank_to_cam(close.x, close.y, 200, 30)))
    sams = [("ord_seraph@0.3", 0, 0.8, {"turn": 9}), ("ord_seraph@0.3", 1, 0.65, {"turn": 11}),
            ("ord_vigil@0.52", 0, 0.75, {"turn": 12}), ("ord_sanction@0.06", 2, 0.7, {"turn": 8}),
            ("ord_vigil@0.52", 3, 0.6, {"turn": 13}), ("ord_sanction@0.06", 4, 0.85, {"turn": 10})]
    raid(land, top, craft, sams, [("chs_behemoth", 0.62, 220, 44, 200)], rails)
    boulders(land, (-0.05, 1.05, 12, 140), 40, 21)
    for sx, y in ((0.36, 70), (0.7, 104), (0.15, 60), (0.55, 120), (0.85, 260)):
        smoke_post(land if y < 160 else None, X(sx, y), y)
    for sx, y, r in ((0.6, 54, 3), (0.28, 88, 2.5), (0.8, 66, 3), (0.42, 110, 2.5)):
        crater(land, X(sx, y), y, r)
    return {"focal": Vector(rails["ord_seraph@0.3"]) - Vector((0, 0, 1.5)), "plan": (-200, 200, -10, 360)}


def ka2_option_b(scene):
    """B: "Bomber down". The camera low and tilted up; a Behemoth close
    overhead on the right third, hit and breaking up, is the focal point;
    the trails converge on it from the site below; the sun behind the raid
    over the sea; the site and the Commander along the bottom third."""
    top, horizon = 22.0, 0.66
    land = CliffLand(lambda x, y: 150 + 10 * math.sin(x / 70) - y, top=top)
    land.build(-380, 380, -10, 260, 3.0)
    cam_h = land.z(0, 0) + 3.0
    K.cam_rig(scene, cam_h, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    K.sun(5, 14, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.6, (200, 210, 230))
    sun_disc(scene, 14, 5)
    sites = [("ord_seraph", 0.12, 40, 20), ("ord_vigil", 0.3, 34, 0), ("ord_lumen", 0.52, 52, -20),
             ("ord_sanction", 0.82, 70, 0), ("ord_phalanx", 0.36, 90, 0), ("ord_oracle", 0.66, 96, 30),
             ("ord_sovereign", 0.22, 62, 40)]
    rails = ka2_site(land, sites, [(ORDER_AA, (0.02, 0.98, 30, 110), 7, 10)], 31)
    for uid, sx, y, hd in (("chs_kraken", 0.4, 260, 80), ("chs_siren", 0.75, 240, 100)):
        put(land, uid, X(sx, y), y, hd, z=0.0)
    close = at_screen(0.68, 0.28, 32.0, cam_h, horizon)
    put(land, "chs_behemoth", close.x, close.y, 190, z=close.z, wreck=True, tilt=(-18, 26))
    line([tuple(close), tuple(close + Vector((-10, 12, 8))), tuple(close + Vector((-26, 30, 16)))], 3.0, "smoke")
    craft = [("chs_behemoth", 0.3, 200, 70, 180, 0, 0), ("chs_behemoth", 0.48, 230, 76, 185, 0, 0),
             ("chs_plague", 0.14, 170, 52, 160, 0, -15), ("chs_wraith", 0.88, 150, 44, 220, 0, 30),
             ("chs_harpy", 0.56, 130, 36, 200, 0, 15)]
    craft_pos = raid(land, top, craft, [("ord_seraph@0.12", 0, 0.8, {"turn": 9}), ("ord_lumen@0.52", 1, 0.7, {"turn": 12}),
                                        ("ord_sanction@0.82", 3, 0.75, {"turn": 11}), ("ord_vigil@0.3", 4, 0.6, {"turn": 14})], [], rails)
    for i, rail in enumerate(("ord_seraph@0.12", "ord_vigil@0.3", "ord_sanction@0.82")):
        sam_marker(land, rails[rail], close, Vector((0, -3, 0)), 90 + i, cut=1.0, turn=10)
    boulders(land, (-0.05, 1.05, 10, 130), 36, 41)
    for sx, y in ((0.45, 70), (0.75, 110), (0.1, 90)):
        smoke_post(land, X(sx, y), y)
    return {"focal": close, "plan": (-200, 200, -10, 320)}


def ka2_option_c(scene):
    """C: "The ridge". The camera on the plateau behind the site, looking
    out over the cliff edge: the sea fills a big band of the frame; the
    Oracle radar and the Citadel on the cliff edge, silhouetted against the
    sun over the sea, are the focal point on the right third; the raid comes
    in over the water and the Chaos fleet fires from offshore."""
    top, horizon = 30.0, 0.36
    land = CliffLand(lambda x, y: 95 + 14 * math.sin(x / 60) - y, top=top, fall=0.22)  # the cliff is 9 studs at the edge
    land.build(-380, 380, -10, 200, 3.0)
    cam_h = land.z(0, 0) + 7.0
    K.cam_rig(scene, cam_h, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    K.sun(4, 22, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.6, (200, 210, 230))
    sun_disc(scene, 22, 4)
    sites = [("ord_oracle", 0.68, 74, 30), ("ord_citadel", 0.8, 86, 200), ("ord_seraph", 0.2, 34, 20),
             ("ord_vigil", 0.42, 44, 0), ("ord_lumen", 0.56, 30, -20), ("ord_phalanx", 0.3, 70, 0),
             ("ord_sanction", 0.08, 64, 30), ("ord_sovereign", 0.5, 56, 30)]
    rails = ka2_site(land, sites, [(ORDER_AA, (0.02, 0.98, 24, 76), 6, 10)], 51)
    for uid, sx, y, hd in (("chs_kraken", 0.2, 190, 70), ("chs_leviathan", 0.45, 230, 85), ("chs_siren", 0.62, 170, 95),
                           ("chs_kraken", 0.86, 210, 110), ("ord_dominion", 0.04, 160, 60)):
        put(land, uid, X(sx, y), y, hd, z=0.0)
    craft = [("chs_behemoth", 0.4, 180, 40, 180, 0, 0), ("chs_behemoth", 0.55, 210, 46, 185, 0, 0),
             ("chs_plague", 0.25, 150, 34, 165, 0, -10), ("chs_banshee", 0.7, 130, 30, 200, 0, 20),
             ("chs_harpy", 0.9, 110, 24, 215, 0, 25)]
    close = at_screen(0.24, 0.24, 24.0, cam_h, horizon)
    put(land, "chs_manticore", close.x, close.y, 150, z=close.z, tilt=(-12, bank_to_cam(close.x, close.y, 150, 30)))
    sams = [("ord_seraph@0.2", 0, 0.8, {"turn": 9}), ("ord_vigil@0.42", 1, 0.7, {"turn": 12}),
            ("ord_sanction@0.08", 2, 0.75, {"turn": 10}), ("ord_lumen@0.56", 3, 0.6, {"turn": 13}),
            ("ord_seraph@0.2", 4, 0.55, {"turn": 14})]
    raid(land, top, craft, sams, [("chs_plague", 0.34, 120, 28, 170)], rails)
    boulders(land, (-0.05, 1.05, 10, 90), 30, 61)
    for sx, y in ((0.3, 50), (0.62, 66), (0.86, 190)):
        smoke_post(land if y < 95 else None, X(sx, y), y)
    return {"focal": Vector((X(0.72, 78), 78, land.z(X(0.72, 78), 78) + 5)), "plan": (-180, 180, -10, 260)}


OPTIONS.update({"ka2_a": ka2_option_a, "ka2_b": ka2_option_b, "ka2_c": ka2_option_c})


# ---------------------------------------------------------------------------
# Key art 3 options: an Order SAM base holds off a Chaos air raid in daylight
# while a Chaos nuke comes in high and the base's anti-nuke fires at it
# (the user's brief, 2026-10-24). Green hills, sun about 50 degrees up.
# Aegis and Sanctum have no meshes yet: Seraph and Sanction stand in.
# ---------------------------------------------------------------------------

STAND_IN = {"ord_aegis": "ord_seraph", "ord_sanctum": "ord_sanction"}
PROVIDENCE_OPEN = {"hatch": (100, 0, 0)}  # Blockouts/Pending/Registry.luau, pose "open"


def green_land():
    """Rolling green ground rising into hills and a far ridge."""
    def hills(x, y):
        far = smooth(140, 520, y)
        return far * (26 + 18 * noise.noise(Vector((x / 160.0, y / 160.0, 5.0)))) + 3.0 * noise.noise(Vector((x / 50.0, y / 50.0, 6.0)))
    return Land(lambda x, y: 5000.0, extra=hills, amp=1.0)


def missile_mesh(mid, pos, direction, scale=1.0):
    """A missile from assets/fx/missiles in clay, pointing along `direction`."""
    fbx = os.path.join(K.ROOT, "assets", "fx", "missiles", mid, "export", f"{mid}.fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    objs = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(f"{mid}_root", None)
    K.link(root, "mid")
    for o in objs:
        for c in o.users_collection:
            c.objects.unlink(o)
        if o.type != "MESH" or o.name.startswith(("emissive_probe", "tex_")):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        K.link(o, "mid")
        K.lib.assign_single_material([o], clay("trail"))
        o.parent = root
    root.location = pos
    root.rotation_euler = Vector(direction).to_track_quat("Y", "Z").to_euler()
    root.scale = (scale, scale, scale)
    return root


def ka3_story(land, cam_h, horizon, prov, nuke_at, meet_at, seed):
    """The nuke (big, on a long thick trail from beyond the frame) and the
    interceptor (its curving trail from the Providence's open hatch), both
    heading for the meeting point; frame positions (sx, sy, distance)."""
    nuke = at_screen(*nuke_at[:2], nuke_at[2], cam_h, horizon)
    meet = at_screen(*meet_at[:2], meet_at[2], cam_h, horizon)
    d = (meet - nuke).normalized()
    line([tuple(nuke - d * 600), tuple(nuke)], 5.0)  # the nuke's long, thick white trail
    missile_mesh("chs_nuke", tuple(nuke), d, scale=8.0)
    hatch = Vector((prov.x, prov.y, land.z(prov.x, prov.y) + 6))
    # the interceptor: up out of the hatch, curving toward the meeting point; its head 70% of the way
    pts = []
    for i in range(16):
        t = i / 15 * 0.7
        a = hatch.lerp(meet, t)
        a.z += math.sin(t / 0.7 * math.pi * 0.5) * (meet - hatch).length * 0.18 * (1 - t)
        pts.append(a)
    line([tuple(q) for q in pts], 1.4)
    missile_mesh("ord_interceptor", tuple(pts[-1]), pts[-1] - pts[-2], scale=2.0)
    return meet


def ka3_base(land, placements):
    """(uid, sx, y, heading, pose) by frame position; stand-ins for the meshes not built yet."""
    keep, rails = [], {}
    for uid, sx, y, hd, pose in placements:
        x = X(sx, y)
        put(land, STAND_IN.get(uid, uid), x, y, hd, pose=pose)
        keep.append((x, y, 16))
        rails.setdefault(uid, []).append((x, y, land.z(x, y) + 4))
    return keep, rails


def ka3_air(land, cam_h, horizon, craft, sams, rails, hit):
    """Aircraft at frame positions (uid, sx, sy, distance, heading, pitch, bank),
    SAM markers (launcher uid, index, craft index, cut, kw), and one hit
    aircraft falling in a black smoke spiral."""
    pos = []
    for uid, sx, sy, dist, hd, pitch, bank in craft:
        p = at_screen(sx, sy, dist, cam_h, horizon)
        put(land, uid, p.x, p.y, hd, z=p.z, tilt=(pitch, bank_to_cam(p.x, p.y, hd, bank) if bank else 0))
        pos.append((p, K.forward(hd) * 3.5))
    for i, (uid, k, ci, cut, kw) in enumerate(sams):
        p, v = pos[ci]
        sam_marker(land, rails[uid][k], p, v, 70 + i, cut=cut, **kw)
    uid, sx, sy, dist, hd = hit
    p = at_screen(sx, sy, dist, cam_h, horizon)
    put(land, uid, p.x, p.y, hd, z=p.z, wreck=True, tilt=(-40, 60))
    line([tuple(p + Vector((math.cos(a) * 3, math.sin(a) * 3, 2.2 * a))) for a in [i * 0.6 for i in range(16)]], 1.2, "smoke")


def ka3_option_a(scene):
    """A: "Converging". The Providence left of centre fires; its
    interceptor curves up and right while the nuke comes down from the upper
    right; they meet high in the middle. A Vigil fires in the foreground on
    the left; a Manticore banks past close on the right."""
    horizon = 0.58
    land = green_land()
    land.build(-420, 420, -10, 560, 3.0)
    cam_h = land.z(0, 0) + 4.5
    K.cam_rig(scene, cam_h, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    K.sun(50, 80, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.8, (200, 210, 230))
    base = [("ord_vigil", 0.06, 26, 30, None), ("ord_providence", 0.38, 72, 200, PROVIDENCE_OPEN),
            ("ord_aegis", 0.2, 50, 20, None), ("ord_aegis", 0.62, 104, 0, None), ("ord_lumen", 0.55, 58, -20, None),
            ("ord_lumen", 0.88, 70, -40, None), ("ord_phalanx", 0.74, 96, 0, None), ("ord_sanctum", 0.92, 120, 0, None),
            ("ord_vigil", 0.46, 120, 0, None)]
    keep, rails = ka3_base(land, base)
    scatter(land, ["ord_halo", "ord_lancer"], (0.05, 0.95, 40, 140), 6, 10, 71, keep=keep, screen=True)
    prov = Vector((X(0.38, 72), 72, 0))
    meet = ka3_story(land, cam_h, horizon, prov, (0.68, 0.2, 380), (0.56, 0.25, 330), 1)
    line([rails["ord_vigil"][0], (rails["ord_vigil"][0][0] + 2, rails["ord_vigil"][0][1] + 4, rails["ord_vigil"][0][2] + 9)], 0.5)  # the foreground missile leaving the tube
    craft = [("chs_manticore", 0.82, 0.38, 20, 230, -10, 35), ("chs_harpy", 0.28, 0.36, 80, 120, 0, 25),
             ("chs_plague", 0.44, 0.32, 150, 160, 0, 0), ("chs_plague", 0.5, 0.3, 170, 165, 0, 0),
             ("chs_behemoth", 0.72, 0.27, 240, 190, 0, 0), ("chs_wasp", 0.16, 0.46, 60, 150, 8, 0),
             ("chs_wasp", 0.9, 0.48, 70, 210, 8, 0), ("chs_wraith", 0.86, 0.22, 200, 200, 0, 20)]
    sams = [("ord_aegis", 0, 1, 0.8, {"turn": 10}), ("ord_aegis", 1, 4, 0.6, {"turn": 9}), ("ord_vigil", 1, 2, 0.7, {"turn": 12}),
            ("ord_vigil", 0, 5, 0.5, {"turn": 13})]
    ka3_air(land, cam_h, horizon, craft, sams, rails, ("chs_harpy", 0.32, 0.3, 120, 140))
    for sx, y in ((0.3, 110), (0.8, 140)):
        smoke_post(land, X(sx, y), y, h=40, r=1.6)
    return {"focal": meet, "plan": (-220, 220, -10, 600)}


def ka3_option_b(scene):
    """B: "Up through the raid". The camera tilted up: the sky and the raid
    fill most of the frame; the Providence on the right fires, the nuke
    comes down from the upper left; a Harpy banks past close on the left; a
    Vigil fires in the foreground on the right."""
    horizon = 0.72
    land = green_land()
    land.build(-420, 420, -10, 560, 3.0)
    cam_h = land.z(0, 0) + 3.5
    K.cam_rig(scene, cam_h, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    K.sun(50, -70, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.8, (200, 210, 230))
    base = [("ord_vigil", 0.94, 26, -30, None), ("ord_providence", 0.66, 66, 160, PROVIDENCE_OPEN),
            ("ord_aegis", 0.36, 52, 10, None), ("ord_lumen", 0.18, 60, 20, None), ("ord_lumen", 0.5, 80, 0, None),
            ("ord_phalanx", 0.28, 100, 0, None), ("ord_sanctum", 0.84, 110, 0, None), ("ord_aegis", 0.08, 96, 30, None)]
    keep, rails = ka3_base(land, base)
    scatter(land, ["ord_halo", "ord_lancer"], (0.05, 0.95, 40, 140), 5, 10, 81, keep=keep, screen=True)
    prov = Vector((X(0.66, 66), 66, 0))
    meet = ka3_story(land, cam_h, horizon, prov, (0.3, 0.16, 380), (0.42, 0.22, 330), 2)
    line([rails["ord_vigil"][0], (rails["ord_vigil"][0][0] - 2, rails["ord_vigil"][0][1] + 4, rails["ord_vigil"][0][2] + 9)], 0.5)
    craft = [("chs_harpy", 0.18, 0.42, 18, 110, -10, 35), ("chs_manticore", 0.7, 0.4, 70, 220, 0, 25),
             ("chs_plague", 0.52, 0.34, 140, 200, 0, 0), ("chs_plague", 0.6, 0.31, 160, 195, 0, 0),
             ("chs_behemoth", 0.82, 0.24, 230, 200, 0, 0), ("chs_wasp", 0.92, 0.58, 50, 220, 8, 0),
             ("chs_wasp", 0.44, 0.6, 70, 180, 8, 0), ("chs_wraith", 0.12, 0.26, 190, 150, 0, 20)]
    sams = [("ord_aegis", 0, 2, 0.8, {"turn": 10}), ("ord_aegis", 1, 7, 0.6, {"turn": 9}), ("ord_vigil", 0, 1, 0.7, {"turn": 12}),
            ("ord_lumen", 0, 4, 0.5, {"turn": 13})]
    ka3_air(land, cam_h, horizon, craft, sams, rails, ("chs_harpy", 0.74, 0.3, 110, 220))
    for sx, y in ((0.3, 110), (0.6, 140)):
        smoke_post(land, X(sx, y), y, h=40, r=1.6)
    return {"focal": meet, "plan": (-220, 220, -10, 600)}


def ka3_option_c(scene):
    """C: "Vertical line". A slightly higher view over the base, the
    Providence in the centre: the nuke falls almost straight down toward it
    and the interceptor climbs straight up, one line up the middle; the
    shield dome left, the flak right, a Vigil firing in the foreground left,
    a Manticore banking past close on the right."""
    horizon = 0.5
    land = green_land()
    land.build(-420, 420, -10, 560, 3.0)
    cam_h = land.z(0, 0) + 8.0
    K.cam_rig(scene, cam_h, 0.05 + 0.9 * horizon, RENDER_LENS, y=0.0)
    K.sun(50, 75, 4.0, (255, 255, 255), angle=1.0)
    K.fill(0.8, (200, 210, 230))
    base = [("ord_vigil", 0.06, 28, 30, None), ("ord_providence", 0.5, 88, 180, PROVIDENCE_OPEN),
            ("ord_phalanx", 0.22, 80, 0, None), ("ord_aegis", 0.36, 60, 20, None), ("ord_aegis", 0.7, 66, -20, None),
            ("ord_lumen", 0.8, 50, -30, None), ("ord_lumen", 0.9, 96, -40, None), ("ord_sanctum", 0.64, 120, 0, None),
            ("ord_vigil", 0.3, 120, 0, None)]
    keep, rails = ka3_base(land, base)
    scatter(land, ["ord_halo", "ord_lancer"], (0.05, 0.95, 40, 150), 6, 10, 91, keep=keep, screen=True)
    prov = Vector((X(0.5, 88), 88, 0))
    meet = ka3_story(land, cam_h, horizon, prov, (0.53, 0.15, 380), (0.5, 0.22, 320), 3)
    line([rails["ord_vigil"][0], (rails["ord_vigil"][0][0] + 2, rails["ord_vigil"][0][1] + 4, rails["ord_vigil"][0][2] + 9)], 0.5)
    craft = [("chs_manticore", 0.82, 0.32, 22, 230, -10, 35), ("chs_harpy", 0.26, 0.3, 80, 120, 0, 25),
             ("chs_plague", 0.36, 0.26, 150, 160, 0, 0), ("chs_plague", 0.66, 0.24, 160, 195, 0, 0),
             ("chs_behemoth", 0.74, 0.18, 240, 200, 0, 0), ("chs_wasp", 0.12, 0.4, 60, 150, 8, 0),
             ("chs_wasp", 0.94, 0.42, 70, 210, 8, 0), ("chs_wraith", 0.1, 0.2, 200, 160, 0, 20)]
    sams = [("ord_aegis", 0, 1, 0.8, {"turn": 10}), ("ord_aegis", 1, 3, 0.6, {"turn": 9}), ("ord_vigil", 1, 2, 0.7, {"turn": 12}),
            ("ord_vigil", 0, 5, 0.5, {"turn": 13})]
    ka3_air(land, cam_h, horizon, craft, sams, rails, ("chs_harpy", 0.4, 0.26, 120, 140))
    for sx, y in ((0.4, 110), (0.82, 150)):
        smoke_post(land, X(sx, y), y, h=40, r=1.6)
    return {"focal": meet, "plan": (-220, 220, -10, 600)}


OPTIONS.update({"ka3_a": ka3_option_a, "ka3_b": ka3_option_b, "ka3_c": ka3_option_c})


if __name__ == "__main__":
    for name in sys.argv[sys.argv.index("--") + 1:]:
        run(name, OPTIONS[name])
