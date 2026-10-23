"""Writes the mesh manifest src/shared/Defs/Meshes/Registry.luau from every
uploaded BAR-style mesh (docs/contracts/rig.md, section 7):

    python assets/models/tools/manifest.py [--skip id,id]

(--skip leaves out meshes uploaded but not yet committed, so each pair's
commit lists only its own.)

Sources per unit: assets/models/<id>/export/rig.json (pieces, pivots,
attachments, team pieces, glow parts) and assets/models/<id>/roblox_assets.json
("bar": the current Open Cloud upload as rigged in "FTGG Art"). The shield
emitter comes from assets/fx/shield/. Run it after every upload and commit the
result with the mesh (M-23), together with `lune run mesh_materials`
(the client's place/MeshMaterials.model.json, built from this manifest; C-103).
"""

import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "src", "shared", "Defs", "Meshes", "Registry.luau")
GLOW_MASK = "rbxassetid://101169341901946"  # glow_mask.png, shared by every glow part
# effect textures for the client (M-27, fx.md "Effect textures")
TEXTURES = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fx", "textures",
                                       "roblox_assets.json"), encoding="utf-8"))["textures"]
# the beam towers' shot (M-29, fx.md "Beam shot"): textures and recommended values per faction
BEAM = json.load(open(os.path.join(ROOT, "assets", "fx", "beam", "roblox_assets.json"), encoding="utf-8"))
# the honeycomb shell over the shield dome (M-30, fx.md "Honeycomb shell")
SHELL_DIR = os.path.join(ROOT, "assets", "fx", "shield", "honeycomb")
SHELL_NOTE = "honeycomb shell bands, waiting for the user's review"
BEAM_NOTE = "beam shot textures and recommended values (fx.md \"Beam shot\"), waiting for the user's review"

# The user's approvals: only these are "approved" (the game draws them);
# every other mesh is "review" (the game keeps its blockout) until the user
# approves it. Add an ID here when the user does.
APPROVED = {
    # 2026-10-22: tanks, constructors, artillery, T1 pairs, the 10 structures
    "ord_lancer", "chs_ravager", "ord_mason", "chs_scrapper", "ord_verdict", "chs_hellmouth",
    "ord_herald", "chs_jackal", "ord_halo", "chs_hornet", "ord_oracle", "chs_watcher",
    "ord_generator", "chs_generator", "ord_solar", "chs_solar",
    "ord_vehplant", "chs_vehplant", "ord_bulwark", "chs_spike",
    "shield_emitter",
    # 2026-10-23: the BAR queue, pairs 1-26, and the missiles
    "chs_airfield", "chs_barracuda", "chs_carapace", "chs_cyclops", "chs_depot", "chs_eye",
    "chs_forgemaster", "chs_gorgon", "chs_hailstorm", "chs_harpy", "chs_hydra", "chs_inferno",
    "chs_ir_sam", "chs_juggernaut", "chs_lamprey", "chs_locust", "chs_minotaur", "chs_nuke",
    "chs_plague", "chs_radar_sam", "chs_ragnarok", "chs_shipyard", "chs_shroud", "chs_stalker",
    "chs_thorn", "chs_vulture", "chs_wasp", "chs_windmill", "chs_wrecker", "ord_absolution",
    "ord_airfield", "ord_arbiter", "ord_architect", "ord_barrier", "ord_citadel", "ord_depot",
    "ord_falcon", "ord_guardian", "ord_ir_sam", "ord_judgement", "ord_lumen", "ord_nuke",
    "ord_paladin", "ord_phalanx", "ord_radar_sam", "ord_radiance", "ord_reckoning", "ord_sentry",
    "ord_seraph", "ord_shipyard", "ord_silence", "ord_skywright", "ord_tidewright", "ord_veil",
    "ord_vigil", "ord_warden", "ord_watchtower", "ord_windmill",
    # 2026-10-23: the second review: beam shot, deposits, interceptors, the
    # (the tracked Commanders were approved too, then replaced by the mechs, M-31: review)
    "beam", "deposit", "ord_interceptor", "chs_interceptor",
}
REVIEW_NOTE = "new BAR mesh, waiting for the user's review"
DEPOSIT_NOTE = ("supply deposit (neutral terrain prop): pick a variant and a random yaw per deposit; "
                "tint the ground patch (teamPieces, alpha mask) to the terrain")
# fx entries that reuse another weapon's mesh (the client looks meshes up by weapon ID)
FX_ALIASES = {"ord_mobile_interceptor": "ord_interceptor", "chs_mobile_interceptor": "chs_interceptor"}
# wreck versions (M-24) the user approved; the rest are "review"
# Structures redesigned at the size scale (S-104) go back to "review" with
# their wrecks until the user approves the new designs; their earlier
# approvals: ord_extractor, chs_extractor (2026-10-23, fp 1).
APPROVED_WRECKS = {
    # 2026-10-23: the first 22 wrecks
    "ord_lancer", "chs_ravager", "ord_mason", "chs_scrapper", "ord_verdict", "chs_hellmouth",
    "ord_herald", "chs_jackal", "ord_halo", "chs_hornet", "ord_oracle", "chs_watcher",
    "ord_generator", "chs_generator", "ord_solar", "chs_solar",
    "ord_vehplant", "chs_vehplant", "ord_bulwark", "chs_spike",
}
WRECK_NOTE = "wreck version, waiting for the user's review"


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def lua(v, indent):
    pad = "\t" * indent
    if isinstance(v, dict):
        if not v:
            return "{}"
        rows = []
        for k in sorted(v):
            key = k if k.isidentifier() else f'["{k}"]'
            rows.append(f"{pad}\t{key} = {lua(v[k], indent + 1)},")
        return "{\n" + "\n".join(rows) + f"\n{pad}}}"
    if isinstance(v, list):
        if all(isinstance(x, (int, float)) for x in v):
            return "{ " + ", ".join(num(x) for x in v) + " }"
        return "{\n" + "\n".join(f"{pad}\t{lua(x, indent + 1)}," for x in v) + f"\n{pad}}}"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    return num(v)


def num(x):
    if isinstance(x, int):
        return str(x)
    s = f"{x:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def entry(rig, assets, status, note):
    bar = assets["bar"]
    pieces = {}
    for name, p in rig["pieces"].items():
        e = {"center": p["center"], "size": p["size"], "mesh": bar["meshes"][name]}
        if p.get("parent"):
            e["parent"] = p["parent"]
            e["pivot"] = p["pivot"]
        pieces[name] = e
    glow = []
    for g in sorted(rig.get("glow", []), key=lambda g: g["name"]):
        glow.append({"name": g["name"], "piece": g["piece"], "channel": g["channel"], "tint": g["tint"],
                     "strength": g["strength"], "center": g["center"], "size": g["size"],
                     "mesh": bar["meshes"][g["name"]]})
    e = {
        "status": status,
        "model": bar.get("model", ""),
        "pieces": pieces,
        "attachments": {k: {"parent": a["parent"], "at": a["at"]} for k, a in rig.get("attachments", {}).items()},
        "teamPieces": sorted(rig["teamColorPieces"]),
        "maps": {k: bar["surfaceAppearance"][k] for k in ("ALB", "NOR", "RGH", "MTL", "EMI")},
        "glow": glow,
        "glowShare": rig.get("glowShare", 0),
        "triangles": rig["triangles"]["total"],
    }
    if rig.get("visualPieces"):  # animated sub-pieces (M-27)
        e["visualPieces"] = list(rig["visualPieces"])
    if rig.get("anim"):
        e["anim"] = rig["anim"]
    if note:
        e["note"] = note
    return e


def head_rig(path):
    import subprocess
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    return json.loads(subprocess.run(["git", "show", f"HEAD:{rel}"], cwd=ROOT, capture_output=True, text=True, check=True).stdout)


def wreck_entry(uid, rig, assets):
    """The wreck version (M-24, fx.md "Wrecks"): the same pieces and pivots
    as the live mesh, its own meshes and maps, no glow and no team pieces."""
    w = assets["wreck"]
    status = "approved" if uid in APPROVED_WRECKS else "review"
    e = {
        "status": status,
        "model": w.get("model", ""),
        "pieces": {name: {"center": p["center"], "size": p["size"], "mesh": w["meshes"][name]}
                   for name, p in rig["pieces"].items()},
        "maps": {k: w["surfaceAppearance"][k] for k in ("ALB", "NOR", "RGH", "MTL")},
        "triangles": rig["triangles"]["total"],
    }
    if status == "review":
        e["note"] = WRECK_NOTE
    return e


def main():
    import sys
    skip = set()
    if "--skip" in sys.argv:
        skip = set(sys.argv[sys.argv.index("--skip") + 1].split(","))
    units = {}
    models = os.path.join(ROOT, "assets", "models")
    for uid in sorted(os.listdir(models)):
        rig_p = os.path.join(models, uid, "export", "rig.json")
        assets_p = os.path.join(models, uid, "roblox_assets.json")
        if uid in skip or not (os.path.exists(rig_p) and os.path.exists(assets_p)):
            continue
        assets = load(assets_p)
        if "bar" not in assets or "surfaceAppearance" not in assets["bar"]:
            continue
        status = "approved" if uid in APPROVED else "review"
        try:
            units[uid] = entry(load(rig_p), assets, status, None if status == "approved" else REVIEW_NOTE)
        except KeyError:  # rebuilt with new pieces, not uploaded yet: the committed rig matches the upload
            units[uid] = entry(head_rig(rig_p), assets, status, None if status == "approved" else REVIEW_NOTE)
            print(f"{uid}: export ahead of its upload, using the committed rig.json")
        wreck_p = os.path.join(models, uid, "export_wreck", "rig.json")
        if "wreck" in assets and os.path.exists(wreck_p):
            units[uid]["wreck"] = wreck_entry(uid, load(wreck_p), assets)

    shield = load(os.path.join(ROOT, "assets", "fx", "shield", "roblox_assets.json"))
    em_rig = load(os.path.join(ROOT, "assets", "fx", "shield", "emitter", "export", "rig.json"))
    em_assets = {"bar": {
        "model": shield["emitterGlow"]["model"],
        "meshes": {"base": shield["meshes"]["emitter"], **shield["emitterGlow"]["glowMeshes"]},
        "surfaceAppearance": shield["emitterSurfaceAppearance"],
    }}
    fx = {"shield_emitter": entry(em_rig, em_assets, "approved" if "shield_emitter" in APPROVED else "review", None)}
    # missiles, by weapon def ID (fx.md "Missiles")
    missiles = os.path.join(ROOT, "assets", "fx", "missiles")
    for wid in sorted(os.listdir(missiles)):
        rig_p = os.path.join(missiles, wid, "export", "rig.json")
        assets_p = os.path.join(missiles, wid, "roblox_assets.json")
        if wid in skip or not (os.path.exists(rig_p) and os.path.exists(assets_p)):
            continue
        status = "approved" if wid in APPROVED else "review"
        fx[wid] = entry(load(rig_p), load(assets_p), status, None if status == "approved" else REVIEW_NOTE)

    # supply deposits (M-28): one fx entry, variant 1's fields plus every variant
    deposits = os.path.join(ROOT, "assets", "fx", "deposit")
    variants = []
    for vid in sorted(os.listdir(deposits)):
        rig_p = os.path.join(deposits, vid, "export", "rig.json")
        assets_p = os.path.join(deposits, vid, "roblox_assets.json")
        if os.path.exists(rig_p) and os.path.exists(assets_p):
            variants.append(entry(load(rig_p), load(assets_p), "review", None))
    if variants:
        status = "approved" if "deposit" in APPROVED else "review"
        fx["deposit"] = {**variants[0], "status": status, "variants": variants}
        for v in variants:
            v["status"] = status
        if status == "review":
            fx["deposit"]["note"] = DEPOSIT_NOTE
    # weapons that reuse another weapon's mesh (S-111: the mobile interceptors)
    for alias, src in FX_ALIASES.items():
        if src in fx:
            fx[alias] = dict(fx[src])
    beam = {"status": "approved" if "beam" in APPROVED else "review", "textures": BEAM["textures"],
            "factions": BEAM["factions"]}
    if beam["status"] == "review":
        beam["note"] = BEAM_NOTE
    for k, v in beam["textures"].items():
        assert v.startswith("rbxassetid://"), k
    rig = load(os.path.join(SHELL_DIR, "export", "shell.json"))
    ids = load(os.path.join(SHELL_DIR, "roblox_assets.json"))
    shell = {"status": "approved" if "shieldShell" in APPROVED else "review", "texture": ids["texture"],
             "radius": rig["radius"], "refRadius": rig["refRadius"], "hex": rig["hex"],
             "bands": [{"name": b["name"], "mesh": ids["meshes"][b["name"]], "opacity": b["opacity"], "theta": b["theta"],
                        "center": b["center"], "size": b["size"]} for b in rig["bands"]]}
    if shell["status"] == "review":
        shell["note"] = SHELL_NOTE
    body = lua({"units": units, "fx": fx, "beam": beam, "shieldShell": shell}, 0)
    text = f"""--!strict
-- Mesh manifest (M-23, docs/contracts/rig.md section 7): every BAR-style mesh
-- by unit def ID, with its asset IDs, rig, team pieces and glow parts.
-- GENERATED by assets/models/tools/manifest.py from each mesh's rig.json and
-- roblox_assets.json; don't edit by hand. Owner: models stream.

export type Vec3 = {{ number }}
export type Piece = {{ mesh: string, center: Vec3, size: Vec3, parent: string?, pivot: Vec3? }}
export type Glow = {{
	name: string,
	piece: string,
	channel: string,
	tint: Vec3,
	strength: number,
	center: Vec3,
	size: Vec3,
	mesh: string,
}}
export type Entry = {{
	status: string,
	model: string,
	pieces: {{ [string]: Piece }},
	attachments: {{ [string]: {{ parent: string, at: Vec3 }} }},
	teamPieces: {{ string }},
	maps: {{ [string]: string }},
	glow: {{ Glow }},
	glowShare: number,
	triangles: number,
	note: string?,
	visualPieces: {{ string }}?, -- animated sub-pieces (M-27)
	anim: {{ [string]: {{ motion: string, axis: Vec3, range: number? }} }}?,
	wreck: any?, -- the wreck version (M-24)
}}
-- the beam towers' shot (M-29, fx.md "Beam shot"): white textures and the
-- recommended values per faction ("order" / "chaos"; colors are RGB 0-255)
export type BeamShot = {{
	status: string,
	note: string?,
	textures: {{ [string]: string }},
	factions: {{ [string]: {{ [string]: any }} }},
}}
-- the honeycomb shell over the shield dome (M-30, fx.md "Honeycomb shell"):
-- bands from the top cap down, each with its recommended opacity; center and
-- size at dome radius 1 (multiply by the dome's radius)
export type ShieldShell = {{
	status: string,
	note: string?,
	texture: string,
	radius: number,
	refRadius: number,
	hex: number,
	bands: {{ {{ name: string, mesh: string, opacity: number, theta: {{ number }}, center: Vec3, size: Vec3 }} }},
}}

local manifest: {{ glowMask: string, textures: {{ [string]: string }}, units: {{ [string]: Entry }}, fx: {{ [string]: Entry }}, beam: BeamShot, shieldShell: ShieldShell }} = {{
	glowMask = "{GLOW_MASK}",
	textures = {lua(TEXTURES, 1)},
{body[2:-2]}
}}

return manifest
"""
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"{len(units)} units, {len(fx)} fx -> {os.path.relpath(OUT, ROOT)}")
    print("next: lune run mesh_materials (place/MeshMaterials.model.json, client C-103), same commit")


if __name__ == "__main__":
    main()
