"""Writes the "bar" entry of each unit's roblox_assets.json from the Studio
batch result (ServerStorage.ModelsTools.Batch in "FTGG Art" returns, per unit,
the rigged MeshIds and SurfaceAppearance images) and the unit's
export/opencloud.json and rig.json:

    python assets/models/tools/record_assets.py <batch result .json> <note>

An earlier "bar" entry is kept as "bar_<n>". Then run manifest.py.
"""

import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
NOTE = ("Uploaded through the Open Cloud Assets API (assets/models/tools/opencloud.py, creator hungluu344); "
        "the SurfaceAppearance uses the Decal images (pipeline.md, Open Cloud route). Glow parts "
        "(<piece>_glow_<channel>) are listed with the meshes (docs/contracts/fx.md, Unit glow).")


def rid(v):
    return v if str(v).startswith("rbxassetid://") else "rbxassetid://" + str(v)


def main():
    batch = json.load(open(sys.argv[1], encoding="utf-8"))
    note = sys.argv[2]
    for uid, b in sorted(batch.items()):
        if "error" in b:
            print(f"skip {uid}: {b['error']}")
            continue
        d = os.path.join(ROOT, "assets", "models", uid)
        oc = json.load(open(os.path.join(d, "export", "opencloud.json"), encoding="utf-8"))
        rig = json.load(open(os.path.join(d, "export", "rig.json"), encoding="utf-8"))
        path = os.path.join(d, "roblox_assets.json")
        old = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        bar = {
            "model": rid(oc["model"]),
            "meshes": {k: b["meshes"][k] for k in sorted(b["meshes"])},
            "decals": {k: rid(v) for k, v in oc["decals"].items()},
            "surfaceAppearance": {k: b["sa"][k] for k in ("ALB", "NOR", "RGH", "MTL", "EMI")},
            "modelPath": f"ReplicatedStorage.ModelReview.{uid}_bar in FTGG Art",
        }
        out = {
            "note": NOTE,
            "revision": f"{note}: {rig['triangles']['total']} triangles, glow share {rig['glowShare'] * 100:.1f}%",
            "bar": bar,
        }
        if "bar" in old:
            n = 1
            while f"bar_{n}" in old:
                n += 1
            prev = dict(old["bar"])
            prev.pop("modelPath", None)
            prev["note"] = old.get("revision", "")
            out[f"bar_{n}"] = prev
        for k, v in old.items():
            if k not in ("note", "revision", "bar"):
                out[k] = v
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps(out, indent=2) + "\n")
        print(f"ok {uid}")


if __name__ == "__main__":
    main()
