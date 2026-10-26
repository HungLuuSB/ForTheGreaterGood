"""Writes the mesh manifest src/shared/Defs/Meshes/Registry.luau from every
uploaded BAR-style mesh (docs/contracts/rig.md, section 7):

    python assets/models/tools/manifest.py [--skip id,id]

(--skip leaves out meshes or map grounds uploaded but not yet committed, so
each pair's or map's commit lists only its own.)

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
# the shield's energy look v4 (approved by the user 2026-10-24, fx.md "Shield energy"): the values of the
# reference module assets/fx/shield/waves/ShieldPreview.luau; sizes are fractions of the dome radius R unless noted
ENERGY_DIR = os.path.join(ROOT, "assets", "fx", "shield", "waves")
SHIELD_ENERGY = {
    "timing": {"pre": 0.22, "raise": 1.0, "collapse": 0.85, "off": 0.25, "waveCycle": 2.1, "pulsePeriod": 0.5,
               "jitterStep": 0.1, "hitLife": 0.42},  # hitLife 0.8 at first; the user: the spread was slow
    "counts": {"bands": 20, "streaks": 20, "waves": 3, "ringJoints": 12, "edgeArcs": 3, "edgeJoints": 6, "filaments": 2,
               "filamentSegments": 8, "hits": 4, "hitFrames": 16},
    "sizes": {"coreWidthStuds": 0.6, "glowWidth": 0.02, "filamentWidthStuds": 0.18, "filamentReach": 0.012, "flare": 0.15,
              "streakWidth": 0.02, "streakTile": 0.5, "waveGlowWidth": 0.223, "waveGlowTile": 0.255, "waveLineWidth": 0.035,
              "waveLineTile": 0.3, "edgeWidth": 0.03,
              "hitGlow": 1.6},  # the hit Decal's Color3 = tint x hitGlow (3 at first; the user: the hits were too much)
    "tints": {"order": [143, 232, 255], "chaos": [255, 180, 92]},
}


def shield_energy():
    spec = load(os.path.join(ENERGY_DIR, "export", "energy.json"))
    ids = load(os.path.join(ENERGY_DIR, "roblox_assets.json"))
    tex, meshes, parts = ids["textures"], ids["meshes"], spec["parts"]
    step = spec["bandDegrees"]

    def part(name):
        return {"mesh": meshes[name], "center": parts[name]["center"], "size": parts[name]["size"]}

    e = {"status": "approved" if "shieldEnergy" in APPROVED else "review",
         "textures": {"pulse": tex["pulse"], "glow": tex["glow"], "line": tex["line"], "spark": tex["spark"],
                      "flare": tex["flare"], "streak": tex["streak"], "field": tex["field"],
                      "waveGlow": [tex[f"wave_glow_{c}"] for c in "abc"], "waveLine": [tex[f"wave_line_{c}"] for c in "abc"],
                      "hit": [tex[f"hit_{k}"] for k in range(1, SHIELD_ENERGY["counts"]["hitFrames"] + 1)]},
         "bands": [{"name": f"Band_{k}", "theta": [round((k - 1) * step, 4), round(k * step, 4)], **part(f"Band_{k}")}
                   for k in range(1, spec["bands"] + 1)],
         "hitCap": {**part("HitCap"), "halfAngle": spec["capHalfAngle"]},
         **SHIELD_ENERGY}
    if e["status"] == "review":
        e["note"] = "shield energy v4, waiting for the user's review"
    return e


# key art with parallax layers (lobby contract docs/contracts/key-art.md, L-13): assets/keyart/keyart.json
# lists the arts; each one's tiles are in assets/keyart/<dir>/final/opencloud.json once uploaded
KEYART_DIR = os.path.join(ROOT, "assets", "keyart")
KEYART_DEPTHS = [("sky", 0.08), ("far", 0.3), ("mid", 0.6), ("near", 1.0)]


def key_arts():
    """The uploaded key arts whose image IDs are resolved, as the viewer reads them."""
    cfg = load(os.path.join(KEYART_DIR, "keyart.json"))
    out = {}
    for art, c in cfg.items():
        if art.startswith("_"):
            continue
        path = os.path.join(KEYART_DIR, art, "final", "opencloud.json")
        images = load(path).get("images", {}) if os.path.isfile(path) else {}
        if not all(len(images.get(name, [])) == 4 for name, _ in KEYART_DEPTHS):
            print(f"key art {art}: image IDs not resolved yet, left out")
            continue
        out[c["name"]] = {"status": c["status"], "title": c["title"], "size": [2048, 1152], "tiles": [2, 2],
                          "layers": [{"name": name, "depth": depth, "images": images[name]} for name, depth in KEYART_DEPTHS]}
        for name, _ in KEYART_DEPTHS:
            for v in images[name]:
                assert v.startswith("rbxassetid://"), (art, name, v)
    return out
# baked map ground (C-167, docs/contracts/map-ground.md): assets/maps/<name>/export/ground.json
# (the bake) and assets/maps/<name>/roblox_assets.json (mesh IDs); textures per ground material
# in assets/maps/materials/roblox_assets.json. Maps the user approved:
GROUND_APPROVED = {"lakelands"}  # 2026-10-26
GROUND_NOTE = "baked ground, waiting for the user's review (Studio: Invoke(\"groundanyway\", true))"
MAPS_DIR = os.path.join(ROOT, "assets", "maps")


def grounds(skip=()):
    out, used = {}, set()
    for name in sorted(os.listdir(MAPS_DIR)):
        if name in skip:
            continue
        rig_p = os.path.join(MAPS_DIR, name, "export", "ground.json")
        ids_p = os.path.join(MAPS_DIR, name, "roblox_assets.json")
        if not (os.path.isfile(rig_p) and os.path.isfile(ids_p)):
            continue
        rig, ids = load(rig_p), load(ids_p)["meshes"]
        e = {"status": "approved" if name in GROUND_APPROVED else "review", "tiles": [], "details": []}
        for m in rig["meshes"]:
            e[m["kind"]].append({"mesh": ids[m["name"]], "center": m["center"], "size": m["size"],
                                 "material": m["material"]})
            used.add(m["material"])
        if e["status"] == "review":
            e["note"] = GROUND_NOTE
        out[name] = e
    mats = load(os.path.join(MAPS_DIR, "materials", "roblox_assets.json")) if out else {}
    materials = {}
    for key in sorted(used):
        maps = mats[key]["maps"]
        for k in ("ALB", "NOR", "RGH", "MTL"):
            assert maps[k].startswith("rbxassetid://"), (key, k)
        materials[key] = {"maps": {k: maps[k] for k in ("ALB", "NOR", "RGH", "MTL")}}
    return out, materials


BEAM_NOTE = "beam shot textures and recommended values (fx.md \"Beam shot\"), waiting for the user's review"

# The user's approvals: only these are "approved" (the game draws them);
# every other mesh is "review" (the game keeps its blockout) until the user
# approves it. Add an ID here when the user does.
APPROVED = {
    # 2026-10-22: tanks, constructors, artillery, T1 pairs, the 10 structures
    "ord_lancer", "chs_ravager", "ord_mason", "chs_scrapper", "ord_verdict", "chs_hellmouth",
    "ord_herald", "chs_jackal", "ord_halo", "chs_hornet", "ord_oracle", "chs_watcher",
    "shield_emitter",
    # 2026-10-23: the BAR queue, pairs 1-26, and the missiles
    "chs_carapace", "chs_cyclops",  # chs_barracuda: back to review with the v2 hull (2026-10-24)
    "chs_forgemaster", "chs_gorgon", "chs_hailstorm", "chs_harpy", "chs_hydra", "chs_inferno",
    "chs_ir_sam", "chs_juggernaut", "chs_lamprey", "chs_locust", "chs_minotaur", "chs_nuke",
    "chs_plague", "chs_radar_sam", "chs_ragnarok", "chs_shroud", "chs_stalker",
    "chs_vulture", "chs_wasp", "ord_absolution",  # chs_wrecker: v2 hull, review
    "ord_arbiter", "ord_architect", "ord_barrier", "ord_citadel",
    "ord_falcon", "ord_guardian", "ord_ir_sam", "ord_judgement", "ord_lumen", "ord_nuke",
    "ord_paladin", "ord_phalanx", "ord_radar_sam", "ord_radiance", "ord_reckoning",  # ord_sentry: v2 hull, review
    "ord_seraph", "ord_silence", "ord_skywright", "ord_veil",  # ord_tidewright: v2 hull, review
    "ord_warden",
    # 2026-10-23: the second review: beam shot, deposits, interceptors, the
    # (the tracked Commanders were approved too, then replaced by the mechs, M-31: review)
    "beam", "deposit", "ord_interceptor", "chs_interceptor",
    "shieldEnergy",  # the user approved shield v4, 2026-10-24
    # 2026-10-23: the Commander mechs v3 and the extractor redesign (fp 2)
    "ord_sovereign", "chs_warlord", "ord_extractor", "chs_extractor",
    # 2026-10-23: every T1 structure redesigned at the size scale or newly
    # meshed (t1v2_*), with their wrecks
    "ord_generator", "chs_generator", "ord_solar", "chs_solar", "ord_windmill", "chs_windmill",
    "ord_depot", "chs_depot", "ord_vehplant", "chs_vehplant", "ord_airfield", "chs_airfield",
    "ord_shipyard", "chs_shipyard", "ord_converter", "chs_converter", "ord_tidal", "chs_tidal",
    "ord_airpad", "chs_airpad", "ord_bulwark", "chs_spike", "ord_watchtower", "chs_eye",
    "ord_vigil", "chs_thorn", "ord_ear", "chs_listener", "ord_curtain", "chs_smog",
    "ord_undertow", "chs_fang", "ord_moat", "chs_riptide",
    # 2026-10-24: the T2 batch (T2 aircraft, anti-nukes fixed and mobile,
    # missile batteries, amphibious tanks, air workers, ASW helicopters)
    "ord_archon", "chs_manticore", "ord_phantom", "chs_behemoth", "ord_archangel", "chs_banshee", "chs_wraith",
    "ord_providence", "chs_cerberus", "ord_custodian", "chs_chimera", "ord_sanction", "chs_scourge",
    "ord_tideguard", "chs_mire", "ord_zenith", "chs_condor", "ord_tidewatch", "chs_leech",
    # 2026-10-26: the F18 towers, the F6 advanced extractors (the T1's size) and the S-181 units, with wrecks
    "ord_bastion", "chs_maw", "ord_rampart", "chs_breaker", "ord_edict", "chs_cataclysm", "ord_sentry_tower", "chs_guard",
    "ord_overwatch", "chs_geryon", "ord_beamer", "chs_twin_guard", "ord_advextractor", "chs_advextractor", "ord_botlab", "chs_botlab",
    "ord_advbotlab", "chs_advbotlab", "ord_artisan", "chs_tinker", "ord_lazarus", "chs_graverobber", "ord_glint", "chs_skitter",
    "ord_mace", "chs_thug", "ord_kestrel", "chs_needle", "ord_fatboy", "chs_tzar", "chs_centurion", "chs_dragon",
    "ord_liche",
    # 2026-10-26: the rest (ships v2, T2 structures, defences, Shepherd / Griffin), with wrecks
    "chs_barracuda", "chs_wrecker", "ord_sentry", "ord_tidewright", "chs_talos", "ord_gauntlet", "chs_griffin", "ord_shepherd",
    "chs_corsair", "chs_kraken", "chs_leviathan", "chs_reaver", "chs_siren", "ord_crusader", "ord_dominion", "ord_harbormaster",
    "ord_sanctuary", "chs_advairfield", "chs_advshipyard", "chs_advvehplant", "chs_allseer", "chs_augur", "chs_basilisk", "chs_blackout",
    "chs_bulwark", "chs_deepear", "chs_fusion", "chs_seekerspire", "chs_wyvern", "ord_advairfield", "ord_advshipyard", "ord_advvehplant",
    "ord_aegis", "ord_beacon", "ord_choir", "ord_fusion", "ord_sanctum", "ord_tribunal", "ord_veilspire", "ord_witness",
}
REVIEW_NOTE = "new BAR mesh, waiting for the user's review"
DEPOSIT_NOTE = ("supply deposit (neutral terrain prop): pick a variant and a random yaw per deposit; "
                "tint the ground patch (teamPieces, alpha mask) to the terrain")
# fx entries that reuse another weapon's mesh (the client looks meshes up by weapon ID)
FX_ALIASES = {"ord_mobile_interceptor": "ord_interceptor", "chs_mobile_interceptor": "chs_interceptor"}
# wreck versions (M-24) the user approved; the rest are "review"
# Structures redesigned at the size scale (S-104) went back to "review" with
# their wrecks until the user approved the new designs (all T1: 2026-10-23).
APPROVED_WRECKS = {
    # 2026-10-23: the first 22 wrecks
    "ord_lancer", "chs_ravager", "ord_mason", "chs_scrapper", "ord_verdict", "chs_hellmouth",
    "ord_herald", "chs_jackal", "ord_halo", "chs_hornet", "ord_oracle", "chs_watcher",
    "ord_extractor", "chs_extractor",  # the fp-2 redesign's wrecks (2026-10-23)
    # 2026-10-23: the T1 structure redesigns and new T1 meshes (t1v2_*)
    "ord_generator", "chs_generator", "ord_solar", "chs_solar", "ord_windmill", "chs_windmill",
    "ord_depot", "chs_depot", "ord_vehplant", "chs_vehplant", "ord_airfield", "chs_airfield",
    "ord_shipyard", "chs_shipyard", "ord_converter", "chs_converter", "ord_tidal", "chs_tidal",
    "ord_airpad", "chs_airpad", "ord_bulwark", "chs_spike", "ord_watchtower", "chs_eye",
    "ord_vigil", "chs_thorn", "ord_ear", "chs_listener", "ord_curtain", "chs_smog",
    "ord_undertow", "chs_fang", "ord_moat", "chs_riptide",
    # 2026-10-24: the T2 batch's wrecks
    "ord_archon", "chs_manticore", "ord_phantom", "chs_behemoth", "ord_archangel", "chs_banshee", "chs_wraith",
    "ord_providence", "chs_cerberus", "ord_custodian", "chs_chimera", "ord_sanction", "chs_scourge",
    "ord_tideguard", "chs_mire",
    # 2026-10-26: the F18 towers, the F6 advanced extractors (the T1's size) and the S-181 units, with wrecks
    "ord_bastion", "chs_maw", "ord_rampart", "chs_breaker", "ord_edict", "chs_cataclysm", "ord_sentry_tower", "chs_guard",
    "ord_overwatch", "chs_geryon", "ord_beamer", "chs_twin_guard", "ord_advextractor", "chs_advextractor", "ord_botlab", "chs_botlab",
    "ord_advbotlab", "chs_advbotlab", "ord_artisan", "chs_tinker", "ord_lazarus", "chs_graverobber", "ord_glint", "chs_skitter",
    "ord_mace", "chs_thug", "ord_kestrel", "chs_needle", "ord_fatboy", "chs_tzar", "chs_centurion", "chs_dragon",
    "ord_liche",
    # 2026-10-26: the rest (ships v2, T2 structures, defences, Shepherd / Griffin), with wrecks
    "chs_barracuda", "chs_wrecker", "ord_sentry", "ord_tidewright", "chs_talos", "ord_gauntlet", "chs_griffin", "ord_shepherd",
    "chs_corsair", "chs_kraken", "chs_leviathan", "chs_reaver", "chs_siren", "ord_crusader", "ord_dominion", "ord_harbormaster",
    "ord_sanctuary", "chs_advairfield", "chs_advshipyard", "chs_advvehplant", "chs_allseer", "chs_augur", "chs_basilisk", "chs_blackout",
    "chs_bulwark", "chs_deepear", "chs_fusion", "chs_seekerspire", "chs_wyvern", "ord_advairfield", "ord_advshipyard", "ord_advvehplant",
    "ord_aegis", "ord_beacon", "ord_choir", "ord_fusion", "ord_sanctum", "ord_tribunal", "ord_veilspire", "ord_witness",
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
    ground, ground_materials = grounds(skip)
    body = lua({"units": units, "fx": fx, "beam": beam, "shieldShell": shell, "shieldEnergy": shield_energy(),
                "keyArt": key_arts(), "ground": ground, "groundMaterials": ground_materials}, 0)
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

-- the shield's energy look v4 (fx.md "Shield energy"): textures, the 20
-- raise/collapse bands and the hit cap (center and size
-- at dome radius 1, Roblox axes), timings in seconds, counts, sizes (fractions
-- of the dome radius unless named ...Studs) and the faction tints (RGB 0-255)
export type EnergyPart = {{ mesh: string, center: Vec3, size: Vec3 }}
export type ShieldEnergy = {{
	status: string,
	note: string?,
	textures: {{
		pulse: string,
		glow: string,
		line: string,
		spark: string,
		flare: string,
		streak: string,
		field: string,
		waveGlow: {{ string }},
		waveLine: {{ string }},
		hit: {{ string }},
	}},
	bands: {{ {{ name: string, mesh: string, theta: {{ number }}, center: Vec3, size: Vec3 }} }},
	hitCap: {{ mesh: string, center: Vec3, size: Vec3, halfAngle: number }},
	timing: {{ [string]: number }},
	counts: {{ [string]: number }},
	sizes: {{ [string]: number }},
	tints: {{ order: Vec3, chaos: Vec3 }},
}}
-- key art with parallax layers (lobby contract key-art.md, L-13): layers back
-- to front, each cut into tiles (columns, rows) listed row by row from the top left
export type KeyArt = {{
	status: string,
	title: string,
	size: {{ number }},
	tiles: {{ number }},
	layers: {{ {{ name: string, depth: number, images: {{ string }} }} }},
}}

-- baked map ground (C-167, map-ground.md): world-space tiles and rock detail per
-- map name, one material per mesh; the client turns each 180° about Y as the units
export type GroundPiece = {{ mesh: string, center: Vec3, size: Vec3, material: string }}
export type Ground = {{ status: string, note: string?, tiles: {{ GroundPiece }}, details: {{ GroundPiece }} }}

local manifest: {{ glowMask: string, textures: {{ [string]: string }}, units: {{ [string]: Entry }}, fx: {{ [string]: Entry }}, beam: BeamShot, shieldShell: ShieldShell, shieldEnergy: ShieldEnergy, keyArt: {{ [string]: KeyArt }}, ground: {{ [string]: Ground }}, groundMaterials: {{ [string]: {{ maps: {{ [string]: string }} }} }} }} = {{
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
