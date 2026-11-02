"""Preview renders of hand-made blockouts (the BAR roster's rule: a preview
for the user per unit): three views per blockout, flat palette colours, team
blue, on a plain ground.

    blender -b --factory-startup --python-exit-code 1 -P assets/models/tools/blockout_previews.py -- <blockouts.json> <out dir>

blockouts.json is a list of {id, faction, parts} (a dump of the Luau
blockouts with their legs built). Writes <out dir>/<id>_{threequarter,side,top}.png
(640 x 400). Sheets come after with contact_sheet.py.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib  # noqa: E402
import portraits  # noqa: E402

W, H = 640, 400
GROUND = (0.36, 0.42, 0.33)
SKY = (0.55, 0.6, 0.52)
# view direction from the unit to the camera, Roblox space (forward is -Z)
VIEWS = {
    "threequarter": Vector((-1.0, 0.75, -1.15)),
    "side": Vector((-1.0, 0.12, 0.0)),
    "top": Vector((0.0, 1.0, -0.12)),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    entries = json.load(open(args[0], encoding="utf-8"))
    out = args[1]
    os.makedirs(out, exist_ok=True)
    cam = portraits.setup()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (*SKY, 1)
    ground = bpy.data.objects["ground"]
    ground.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*GROUND, 1)
    col = scene.collection
    sensor_h = 36 * H / W
    fov_v = 2 * math.atan(sensor_h / 2 / cam.data.lens)
    for e in entries:
        portraits.clear_unit()
        objs = portraits.build_blockout(e, col)
        lo, hi = portraits.world_bounds(objs)
        center = (lo + hi) / 2
        radius = (hi - lo).length / 2
        for view, d_rb in VIEWS.items():
            d = lib.R(*d_rb.normalized())
            cam.location = center + d * (radius / math.sin(fov_v / 2) * 0.92)
            cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out, f"{e['id']}_{view}.png")
            bpy.ops.render.render(write_still=True)
        print(f"[blockout] {e['id']} {hi.z - lo.z:.1f} studs tall, {hi.x - lo.x:.1f} x {hi.y - lo.y:.1f}")


main()
