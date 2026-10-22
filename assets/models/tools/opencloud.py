"""Uploads a unit's export to Roblox through the Open Cloud Assets API
(docs/art/pipeline.md, "Open Cloud route"):

    python assets/models/tools/opencloud.py <export dir> <unit id> <creator user id>

Uploads the five maps (<id>_bar_ALB, _NOR, _RGH, _MTL, _EMI .png) as Decals
and <id>.fbx as a Model, waits for each operation, and writes
<export dir>/opencloud.json with the asset IDs.

In Studio (first test, ord_extractor, 2026-10-22): InsertService:LoadAsset
on the Model gives the MeshParts (x100 and turned like the 3D Importer's, so
rig_model.luau's normalize applies) with a SurfaceAppearance of the FBX's
own maps, which drew grey until a restart (HTTP 502 on a fresh map, as with
the importer); LoadAsset on each Decal gives its image ID, and a
SurfaceAppearance made from those images drew at once. So the rig step
replaces the FBX's SurfaceAppearance with the Decal images. The key comes from the
ROBLOX_API_KEY environment variable, or on Windows from the user
environment in the registry; it is never printed or written anywhere.
"""

import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1"


def api_key():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key and sys.platform == "win32":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            key = winreg.QueryValueEx(k, "ROBLOX_API_KEY")[0]
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")
    return key


def request(method, url, key, body=None, headers=None, retries=5):
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")[:300]
            if e.code == 429 or e.code >= 500:
                reset = e.headers.get("x-ratelimit-reset")
                wait = float(reset) if reset and reset.replace(".", "").isdigit() else 2 ** attempt
                print(f"  HTTP {e.code}, retrying in {wait:.0f} s")
                time.sleep(wait)
                continue
            raise SystemExit(f"HTTP {e.code} on {method} {url}: {text}")
    raise SystemExit(f"gave up on {method} {url}")


def upload(path, asset_type, name, description, creator, key):
    boundary = uuid.uuid4().hex
    meta = {
        "assetType": asset_type,
        "displayName": name,
        "description": description,
        "creationContext": {"creator": {"userId": str(creator)}},
    }
    ctype = "model/fbx" if path.endswith(".fbx") else (mimetypes.guess_type(path)[0] or "application/octet-stream")
    with open(path, "rb") as f:
        content = f.read()
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode(),
        json.dumps(meta).encode(), b"\r\n",
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\nContent-Type: {ctype}\r\n\r\n".encode(),
        content, b"\r\n", f"--{boundary}--\r\n".encode(),
    ])
    op = request("POST", f"{API}/assets", key, body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    path_op = op.get("path") or f"operations/{op.get('operationId')}"
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", f"{API}/{path_op}", key)
    if not op.get("done"):
        raise SystemExit(f"upload of {path} did not finish: {op}")
    if "error" in op:
        raise SystemExit(f"upload of {path} failed: {op['error']}")
    return op["response"]["assetId"]


def main():
    export, unit, creator = sys.argv[1], sys.argv[2], sys.argv[3]
    key = api_key()
    out = {"unit": unit, "decals": {}, "model": None}
    maps = {"ALB": f"{unit}_bar_ALB.png", "RGH": f"{unit}_bar_RGH.png", "NOR": f"{unit}_NOR.png",
            "MTL": f"{unit}_MTL.png", "EMI": f"{unit}_EMI.png"}
    for kind, name in maps.items():
        p = os.path.join(export, name)
        aid = upload(p, "Decal", f"{unit} {kind}", "For The Greater Good unit map", creator, key)
        out["decals"][kind] = aid
        print(f"  {kind}: decal {aid}")
    aid = upload(os.path.join(export, f"{unit}.fbx"), "Model", unit, "For The Greater Good unit mesh", creator, key)
    out["model"] = aid
    print(f"  model: {aid}")
    with open(os.path.join(export, "opencloud.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
