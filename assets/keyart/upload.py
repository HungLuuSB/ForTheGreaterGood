"""Uploads a key art's tiles to Roblox through the Open Cloud Assets API
(docs/contracts/key-art.md on m-lobby, section 3; only with the user's
approval):

    python assets/keyart/upload.py <art dir, e.g. ka2> <creator user id>

Uploads the 16 tiles (assets/keyart/<art>/final/<layer>_<row><col>.png,
4 layers x 2 x 2) as Decals and writes their IDs, in the viewer's order
(layers back to front, tiles row by row from the top left), to
assets/keyart/<art>/final/opencloud.json. The image IDs the viewer needs
come from loading each Decal in Studio (LoadAsset gives its Texture), which
fills in "images" in the same file; then the manifest generator lists the
art under `keyArt`. The key comes from ROBLOX_API_KEY as for the meshes.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "models", "tools"))
import opencloud  # noqa: E402

LAYERS = ["sky", "far", "mid", "near"]
TILES = ["00", "01", "10", "11"]


def main():
    art, creator = sys.argv[1], sys.argv[2]
    final = os.path.join(HERE, art, "final")
    path = os.path.join(final, "opencloud.json")
    out = json.load(open(path, encoding="utf-8")) if os.path.isfile(path) else {"art": art, "decals": {}}
    key = opencloud.api_key()
    for layer in LAYERS:
        ids = out["decals"].get(layer) or []
        for i, t in enumerate(TILES):
            if i < len(ids) and ids[i]:
                continue  # already up (a re-run after a failure)
            aid = opencloud.upload(os.path.join(final, f"{layer}_{t}.png"), "Decal", f"FTGG key art {art} {layer} {t}",
                                   "For The Greater Good key art layer tile", creator, key)
            ids = (ids + [None] * 4)[:4]
            ids[i] = aid
            out["decals"][layer] = ids
            with open(path, "w", encoding="utf-8") as f:
                json.dump(out, f, indent=2)
                f.write("\n")
            print(f"  {layer} {t}: decal {aid}", flush=True)
    print(f"[upload] {art}: {sum(len(v) for v in out['decals'].values())} decals -> {os.path.relpath(path)}")


if __name__ == "__main__":
    main()
