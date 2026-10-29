"""Writes the batch rig input for FTGG Art: the uploaded model, decals, rig and clamp
scale of each unit's live mesh and wreck, as the temporary src/shared/_ModelsBatch.luau
(listed in .git/info/exclude, never committed):

    python assets/models/tools/rig_batch.py [--live | --wreck] <unit>...

Both by default (a unit without export_wreck/ gets only its live entry). Run it after
opencloud.py has uploaded export/ (and export_wreck/), then:

1. Copy the file into the live sync tree, so Rojo sends it to FTGG Art:
   cp src/shared/_ModelsBatch.luau build/serve/src/shared/_ModelsBatch.luau
2. In FTGG Art (execute_luau), start the rig in the background:

       local c = game.ReplicatedStorage.Shared._ModelsBatch:Clone() c.Parent = game.ServerStorage
       local data = game:GetService("HttpService"):JSONDecode(require(c)) c:Destroy()
       local old = game.ServerStorage:FindFirstChild("batchT2b") if old then old:Destroy() end
       local sv = Instance.new("StringValue") sv.Name = "batchT2b" sv.Value = "running" sv.Parent = game.ServerStorage
       task.spawn(function()
         local b = game.ServerStorage.ModelsTools.Batch:Clone() b.Parent = game.ServerStorage.ModelsTools
         local Batch = require(b) b:Destroy()
         local ok, res = pcall(Batch.run, game:GetService("HttpService"):JSONEncode(data.units), data.scales)
         sv.Value = ok and res or ("ERR " .. tostring(res))
       end)
       return "started"

3. Poll with `task.wait(18) return game.ServerStorage.batchT2b.Value` until it is JSON,
   save that to a file and run record_assets.py on it, then manifest.py and
   `lune run mesh_materials`.

The clamp scale: an Open Cloud import clamps the largest single mesh to 2048 studs at
x100, so a unit whose largest piece is over 20.48 studs is rigged at largest / 2048.
"""

import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def unit_dir(u: str, sub: str) -> str:
    base = "assets/fx/features" if u.startswith("feature_") else "assets/models"
    return os.path.join(ROOT, base, u, sub)


def clamp_scale(rig: dict) -> float | None:
    largest = max(max(p["size"]) for p in list(rig["pieces"].values()) + list(rig.get("glow") or []))
    return largest / 2048 if largest > 20.48 else None


args = sys.argv[1:]
subs = [("export", "")] if "--live" in args else [("export_wreck", "_wreck")] if "--wreck" in args else [("export", ""), ("export_wreck", "_wreck")]
units = [a for a in args if not a.startswith("--")]
out: dict = {"units": {}, "scales": {}}
for u in units:
    for sub, suffix in subs:
        d = unit_dir(u, sub)
        if not os.path.isfile(os.path.join(d, "opencloud.json")):
            if sub == "export":
                sys.exit(f"{u}: no {sub}/opencloud.json (upload it with opencloud.py first)")
            continue
        oc = json.load(open(os.path.join(d, "opencloud.json")))
        rig = json.load(open(os.path.join(d, "rig.json")))
        key = u + suffix
        out["units"][key] = {"model": oc["model"], "decals": oc["decals"], "rig": rig}
        scale = clamp_scale(rig)
        if scale:
            out["scales"][key] = scale
src = json.dumps(out, separators=(",", ":"))
assert "]==]" not in src
with open(os.path.join(ROOT, "src/shared/_ModelsBatch.luau"), "w", newline="\n") as f:
    f.write("--!strict\n-- TEMPORARY (models stream): batch rig input passed to FTGG Art through the Rojo sync; never committed.\n")
    f.write("return [==[" + src + "]==]\n")
print("units", len(out["units"]), "scales", out["scales"], "bytes", len(src))
