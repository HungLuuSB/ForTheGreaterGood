"""Uploads a baked map ground through the Open Cloud Assets API (C-167,
docs/contracts/map-ground.md; the user's go-ahead as for unit meshes):

    python assets/maps/tools/upload.py <map name> <creator user id>

Uploads each FBX part of assets/maps/<name>/export/ (as a Model) and the maps of
every ground material it uses (assets/maps/materials/<key>/, as Decals, once per
material: a material already in assets/maps/materials/roblox_assets.json is kept)
and writes the IDs to assets/maps/<name>/export/opencloud.json. A re-run skips
what's already up. The mesh IDs come from loading each part in "FTGG Art"
(rig_ground.luau), which fills assets/maps/<name>/roblox_assets.json; the image
IDs from loading the Decals. Then manifest.py lists the map under `ground`.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "models", "tools"))
import opencloud  # noqa: E402

MAPS = ("ALB", "NOR", "RGH", "MTL")


def save(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def main():
    name, creator = sys.argv[1], sys.argv[2]
    key = opencloud.api_key()
    export = os.path.join(HERE, "..", name, "export")
    rig = json.load(open(os.path.join(export, "ground.json"), encoding="utf-8"))
    path = os.path.join(export, "opencloud.json")
    out = json.load(open(path, encoding="utf-8")) if os.path.isfile(path) else {"map": name, "parts": {}}
    for part in rig["parts"]:
        fbx = part["fbx"]
        if fbx in out["parts"]:
            continue
        aid = opencloud.upload(os.path.join(export, fbx), "Model", f"FTGG ground {name} {fbx[:-4]}",
                               "For The Greater Good baked map ground", creator, key)
        out["parts"][fbx] = aid
        save(path, out)
        print(f"  {fbx}: model {aid}", flush=True)
    mats_path = os.path.join(HERE, "..", "materials", "roblox_assets.json")
    mats = json.load(open(mats_path, encoding="utf-8")) if os.path.isfile(mats_path) else {}
    for m in sorted({r["material"] for r in rig["meshes"]}):
        entry = mats.setdefault(m, {"decals": {}})
        for kind in MAPS:
            if kind in entry["decals"]:
                continue
            aid = opencloud.upload(os.path.join(HERE, "..", "materials", m, f"{m}_{kind}.png"), "Decal",
                                   f"FTGG ground {m} {kind}", "For The Greater Good ground texture", creator, key)
            entry["decals"][kind] = aid
            save(mats_path, mats)
            print(f"  {m} {kind}: decal {aid}", flush=True)
    print(f"[upload] {name}: {len(out['parts'])} parts; materials {sorted(mats)}")


if __name__ == "__main__":
    main()
