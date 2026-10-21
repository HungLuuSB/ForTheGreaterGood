"""Blender helpers for FTGG unit meshes (docs/art/pipeline.md, M-11).

Run inside Blender 5.2 (headless: blender -b --factory-startup -P <unit>/build.py).
Geometry is written in Roblox model space (docs/contracts/rig.md): +X right,
+Y up, forward = -Z, 1 unit = 1 stud. `R()` maps it to Blender (Z up); the
FBX export maps it back, so the file is in Roblox space.
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
        along `axis` ('x', 'y' or 'z'), centered on `center`."""
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
        kinds = [(cap_kinds or (kind, kind))[0], (cap_kinds or (kind, kind))[1]]
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
        # (outer faces point away from the loop center, side faces outward in X)
        bm.normal_update()
        center = Vector((0, 0, 0))
        for p in outer_zy:
            center += R((x0 + x1) / 2, p[1], p[0])
        center /= n
        for k, fc in enumerate(fs):
            role = k % 4
            c = fc.calc_center_median()
            nrm = fc.normal
            if role == 0:
                want = (c - Vector((c.x, center.y, center.z)))
                want.x = 0
            elif role == 1:
                want = (Vector((c.x, center.y, center.z)) - c)
                want.x = 0
            elif role == 2:
                want = Vector((-1 if x0 < x1 else 1, 0, 0))
            else:
                want = Vector((1 if x0 < x1 else -1, 0, 0))
            if nrm.dot(want) < 0:
                fc.normal_flip()
        return fs

    # -- object ----------------------------------------------------------------

    def to_object(self, materials, collection):
        mesh = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
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


# ---------------------------------------------------------------------------
# Materials: one per kind; each can show its color, roughness, metalness,
# team mask (alpha) or a lit preview, and carries the bake target image.
# ---------------------------------------------------------------------------

CHANNELS = ("color", "roughness", "metallic", "mask")


def srgb(c):
    """0..255 sRGB -> linear 0..1 tuple with alpha."""
    def lin(u):
        u = u / 255
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1.0)


def make_material(kind, spec, camo, target):
    """spec: dict(base=(r,g,b) | None for camo, roughness, metallic, mask,
    edge_wear, bump=('grille'|'tread'|None), ao)."""
    mat = bpy.data.materials.new(f"{kind}")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new

    out = N("ShaderNodeOutputMaterial")
    bsdf = N("ShaderNodeBsdfPrincipled")
    emit = N("ShaderNodeEmission")
    img = N("ShaderNodeTexImage")
    img.image = target
    img.name = "bake_target"
    nt.nodes.active = img

    geo = N("ShaderNodeNewGeometry")

    # base color
    if spec.get("base") is None:
        noise = N("ShaderNodeTexNoise")
        noise.noise_dimensions = "3D"
        noise.inputs["Scale"].default_value = camo["scale"]
        noise.inputs["Detail"].default_value = 1.5
        noise.inputs["Roughness"].default_value = 0.45
        noise.inputs["Distortion"].default_value = 0.4
        mapping = N("ShaderNodeMapping")
        mapping.inputs["Location"].default_value = (camo["seed"] * 7.3, camo["seed"] * 3.1, 0.0)
        L(geo.outputs["Position"], mapping.inputs["Vector"])
        L(mapping.outputs["Vector"], noise.inputs["Vector"])
        ramp = N("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        els = ramp.color_ramp.elements
        stops = camo["stops"]  # [(pos, rgb255), ...]
        els[0].position, els[0].color = stops[0][0], srgb(stops[0][1])
        els[1].position, els[1].color = stops[1][0], srgb(stops[1][1])
        for pos, col in stops[2:]:
            e = els.new(pos)
            e.color = srgb(col)
        L(noise.outputs["Fac"], ramp.inputs["Fac"])
        color_socket = ramp.outputs["Color"]
    else:
        rgb = N("ShaderNodeRGB")
        rgb.outputs[0].default_value = srgb(spec["base"])
        color_socket = rgb.outputs[0]

    # edge mask from a bevel normal vs the true normal
    bevel = N("ShaderNodeBevel")
    bevel.inputs["Radius"].default_value = 0.05
    bevel.samples = 8
    dot = N("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    L(bevel.outputs["Normal"], dot.inputs[0])
    L(geo.outputs["Normal"], dot.inputs[1])
    edge = N("ShaderNodeMath")
    edge.operation = "MULTIPLY_ADD"  # (1 - dot) * k  ==  dot * -k + k
    k = 7.0
    L(dot.outputs["Value"], edge.inputs[0])
    edge.inputs[1].default_value = -k
    edge.inputs[2].default_value = k
    edge.use_clamp = True

    # ambient occlusion
    ao = N("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.8
    ao.samples = 16
    ao_mix = N("ShaderNodeMapRange")
    ao_mix.inputs["To Min"].default_value = spec.get("ao", 0.55)
    ao_mix.inputs["To Max"].default_value = 1.0
    L(ao.outputs["AO"], ao_mix.inputs["Value"])

    # color = base, lightened on edges (worn paint), times AO
    wear = N("ShaderNodeMix")
    wear.data_type = "RGBA"
    wear.blend_type = "SCREEN"
    wear_amt = N("ShaderNodeMath")
    wear_amt.operation = "MULTIPLY"
    L(edge.outputs[0], wear_amt.inputs[0])
    wear_amt.inputs[1].default_value = spec.get("edge_wear", 0.35)
    L(wear_amt.outputs[0], wear.inputs[0])
    L(color_socket, wear.inputs[6])
    wear.inputs[7].default_value = (0.75, 0.72, 0.65, 1.0)
    shade = N("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.blend_type = "MULTIPLY"
    shade.inputs[0].default_value = 1.0
    L(wear.outputs[2], shade.inputs[6])
    comb = N("ShaderNodeCombineColor")
    L(ao_mix.outputs[0], comb.inputs[0])
    L(ao_mix.outputs[0], comb.inputs[1])
    L(ao_mix.outputs[0], comb.inputs[2])
    L(comb.outputs[0], shade.inputs[7])
    color_final = shade.outputs[2]

    # roughness: lower on worn edges
    rough = N("ShaderNodeMath")
    rough.operation = "MULTIPLY_ADD"
    L(edge.outputs[0], rough.inputs[0])
    rough.inputs[1].default_value = -0.25 * spec.get("edge_wear", 0.35) / 0.35
    rough.inputs[2].default_value = spec["roughness"]
    rough.use_clamp = True

    metal = N("ShaderNodeValue")
    metal.outputs[0].default_value = spec["metallic"]
    mask = N("ShaderNodeValue")
    mask.outputs[0].default_value = spec.get("mask", 1.0)

    # normal: bevel normal plus a pattern bump
    bump = N("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.02
    L(bevel.outputs["Normal"], bump.inputs["Normal"])
    pattern = spec.get("bump")
    if pattern in ("grille", "tread"):
        wave = N("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X" if pattern == "grille" else "Y"  # Blender X = Roblox X; Blender Y = Roblox -Z
        wave.inputs["Scale"].default_value = 1.2 if pattern == "grille" else 2.2
        wave.inputs["Distortion"].default_value = 0.0
        L(geo.outputs["Position"], wave.inputs["Vector"])
        L(wave.outputs["Fac"], bump.inputs["Height"])
        bump.inputs["Strength"].default_value = 0.8
    else:
        fine = N("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 9.0
        L(geo.outputs["Position"], fine.inputs["Vector"])
        L(fine.outputs["Fac"], bump.inputs["Height"])
        bump.inputs["Strength"].default_value = 0.05

    L(color_final, bsdf.inputs["Base Color"])
    L(rough.outputs[0], bsdf.inputs["Roughness"])
    L(metal.outputs[0], bsdf.inputs["Metallic"])
    L(bump.outputs["Normal"], bsdf.inputs["Normal"])
    L(bsdf.outputs[0], out.inputs["Surface"])

    mat["_sockets"] = 1
    mat_sockets[mat.name] = {
        "out": out, "bsdf": bsdf, "emit": emit,
        "color": color_final, "roughness": rough.outputs[0],
        "metallic": metal.outputs[0], "mask": mask.outputs[0],
    }
    return mat


mat_sockets = {}


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


def bake_all(objs, materials, size, samples, out_dir, prefix):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.render.bake.margin = 8
    scene.render.bake.use_clear = True
    select_only(objs, objs[0])
    paths = {}

    def emit_bake(channel, name, space):
        img = new_image(name, size, space)
        set_target(materials, img)
        show_channel(materials, channel)
        bpy.ops.object.bake(type="EMIT")
        return img

    color = emit_bake("color", f"{prefix}_color", "sRGB")
    mask = emit_bake("mask", f"{prefix}_mask", "Non-Color")
    rough = emit_bake("roughness", f"{prefix}_RGH", "Non-Color")
    metal = emit_bake("metallic", f"{prefix}_MTL", "Non-Color")

    nor = new_image(f"{prefix}_NOR", size, "Non-Color")
    set_target(materials, nor)
    show_channel(materials, None)
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")

    # color + team mask in alpha
    alb = bpy.data.images.new(f"{prefix}_ALB", size, size, alpha=True)
    alb.colorspace_settings.name = "sRGB"
    import numpy as np
    c = np.array(color.pixels[:], dtype=np.float32).reshape(-1, 4)
    m = np.array(mask.pixels[:], dtype=np.float32).reshape(-1, 4)
    c[:, 3] = m[:, 0]
    alb.pixels[:] = c.ravel()

    os.makedirs(out_dir, exist_ok=True)
    for img, mode in ((alb, "RGBA"), (nor, "RGB"), (rough, "BW"), (metal, "BW")):
        path = os.path.join(out_dir, f"{img.name}.png")
        save_png(img, path, mode)
        paths[img.name.split("_")[-1]] = path
    return paths, {"ALB": alb, "NOR": nor, "RGH": rough, "MTL": metal}


def save_png(img, path, mode):
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


def textured_material(name, imgs):
    """Material using the baked set, for the preview render and the FBX."""
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
    L(alb.outputs["Color"], bsdf.inputs["Base Color"])
    L(rgh.outputs["Color"], bsdf.inputs["Roughness"])
    L(mtl.outputs["Color"], bsdf.inputs["Metallic"])
    L(nor.outputs["Color"], nmap.inputs["Color"])
    L(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat, alb, bsdf


def preview_team_material(name, imgs, team_rgb):
    """Like textured_material, with the team color under the alpha mask
    (what SurfaceAppearance AlphaMode.Overlay draws)."""
    mat, alb, bsdf = textured_material(name, imgs)
    nt = mat.node_tree
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    team = nt.nodes.new("ShaderNodeRGB")
    team.outputs[0].default_value = srgb(team_rgb)
    nt.links.new(alb.outputs["Alpha"], mix.inputs[0])
    nt.links.new(team.outputs[0], mix.inputs[6])
    nt.links.new(alb.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return mat


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


def render_preview(path, cam_from_roblox, look_at_roblox, size=(1280, 720), samples=32):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.render.resolution_x, scene.render.resolution_y = size
    cam_data = bpy.data.cameras.get("preview_cam") or bpy.data.cameras.new("preview_cam")
    cam_data.lens = 50
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


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
