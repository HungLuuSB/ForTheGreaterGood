# Models progress

Progress of the models stream: hand-made blockouts in `src/shared/Defs/Blockouts/<id>.luau` and everything under `assets/models/`. Branch `m-models`, worktree `FTGG-models`. Studio place: "FTGG Art" only (Rojo sync on port 34873). Unit defs, `src/client` and `src/server` belong to the other streams; what this stream needs from them is under "Requests" below.

Decisions: `M-1`, `M-2`, ... in [`../decisions/models.md`](../decisions/models.md). Rig and blockout format: [`../contracts/rig.md`](../contracts/rig.md).

## Summary (playtest-3 and handover, 2026-10-29)

**Start here.** This section is enough to carry on the models stream. The sections below are history.

**S-213 id swap (2026-10-29, sim-A's `748ddf25`, merged here):** the T3 bot `chs_korgoth` is now `chs_juggernaut`, and the old T2 tank `chs_juggernaut` is now `chs_goliath` (retired; it keeps its blockout and mesh).
- Renamed to match: the blockout files and `Blockouts/Registry.luau` keys, the `assets/models/<id>` folders and their export file names, and the ids inside `build.py`, `rig.json` and `opencloud.json`.
- Also updated: the `manifest.py` approval lists, `animate.py`, and the key-art tank lists.
- Regenerated: the Meshes registry and `MeshMaterials`.
- Unchanged: the asset IDs. The review rigs in FTGG Art keep their old names, as `modelPath` records.
- B's part (the icon and the piece-script swap) went in with it: on `main` as `b3992f45`, all suites passing.

**E-11 build-menu unit pictures (2026-10-30, for 2D session E):**
- **The look:** the user approved it, relayed by E, with one change: "increase their glow and color". It's built in.
- **The picture:** each unit stands in a small opaque scene of its own setting:
  - ground vehicles and walkers on terrain, with track marks or footprints;
  - structures on a gravel apron with props;
  - ships in water with a wake;
  - sea structures in water with foam;
  - subs and seafloor structures under water;
  - amphibious and hover units on a shoreline;
  - aircraft banked over clouds.
  Order's ground is green, Chaos's is ash.
- **Team paint:** baked in the faction colour, Order blue #4084E6 and Chaos red #DE463E (the user, 2026-10-30, via E). There is no mask pass now; `--masks` still renders `<id>_mask.png` (lit white team paint) if it's ever needed.
- **Tools:**
  - `assets/models/tools/pictures_defs.luau` writes `debug_out/pictures/defs.json`: the non-retired defs and each one's setting.
  - `assets/models/tools/pictures.py` (Blender) renders `debug_out/pictures/<id>.png` at 256×256, about 10 s per unit. Its docstring has the commands.
- **Output:** the PNGs are regenerable and not committed. E reads them from `debug_out/pictures/` and commits only the packed sheets, in `assets/2d/pictures/`.
- **When to re-render:** whenever a mesh changes or a unit is added.
- **Fix in passing:** `portraits.py` now strips the `_bar` suffix from glow-part names. Before, every glow rendered in the fallback grey instead of its channel colour.
- **Full re-render done (2026-10-30):** all 197 pictures are in `debug_out/pictures/` with the look below, and no masks. Contact sheet: `debug_out/screens/pictures_all_v3.png`. 2D session E repacks from them (request 13).
- **Later notes from the user (2026-10-30), all built in:** "too blurry because of the fog. Remove it" (the haze is off, the sub's murk halved, the depth of field eased); "Make them glow more" (glow 3.5, a stronger bloom); "push the color up too" (unit saturation 2.1, plus a whole-picture grade).

**Transports (S-219, 2026-10-30, sim-A's defs, the user approved the units):** `ord_courier` Courier, `chs_buzzard` Buzzard (T1, footprint 2), `ord_ark` Ark, `chs_charon` Charon (T2, footprint 3). Def pieces: `base` only.
- **Meshes and wrecks built**, not uploaded (`assets/models/<id>/build.py`; sheets `debug_out/screens/transports_v1.png`, `transports_wrecks_v1.png`):
  - Courier: an armored utility lifter a size up from the Skywright, sponsons, team door plates, tall skids, a cargo winch.
  - Buzzard: a skeletal lifter, bubble-nosed pod on an open lattice spine, exposed engine, tall legs, folded grapple talons with lit tips.
  - Ark: a tandem-rotor heavy lifter with sponsons, wheels, a ramp, twin engines on the aft pylon and two belly hooks.
  - Charon: a flying crane with four splayed legs, an open cradle with four lit chain hooks, and the ferryman's lantern on a bow arm.
- **Rig:** each has a `cargo` attachment (where the carried units hang), the client-spun `rotor` and a `tailRotor`. The Ark's aft rotor is its `tailRotor` with axis −Y, so the client's Ambient already runs it with the main rotor, counter-rotating; no client change.
- **Blockouts:** registered in `Blockouts/Registry.luau` after merging sim-A's defs commit `e7765af2` (sim-A's suggestion: it reaches `main` with B's merge, ours right after).
- **Uploaded** with the user's approval ("Yes, upload"): meshes and wrecks, rigged in FTGG Art, recorded in `roblox_assets.json`, in the Meshes registry and `MeshMaterials`. 
- **Studio check** (`Workspace.TransportReview`, with the Skywright and Wasp for comparison): sizes match Blender (Courier 17.7 studs long, Buzzard 15.8, Ark 26.2, Charon 28.8), every rig has its `cargo` attachment, and all 32 texture maps load through `CreateEditableImageAsync`. Some still draw untextured in this Studio session: grey cached from the first fetch, which a restart clears (as with earlier uploads).
- **Approved by the user (2026-10-30, "Approve all"):** meshes and wrecks in `APPROVED` / `APPROVED_WRECKS`. Build-menu pictures rendered (`debug_out/pictures/`, sheet `debug_out/screens/transports_pictures.png`); E packs them (request 14).

**BAR roster program (2026-10-31; sim-A's requests in `docs/progress/sim.md` "For the models stream (C)", the plan `docs/design/bar-roster-plan.md`).** The user's rule: every finished blockout, mesh or wreck gets a preview the user can open; they go to `previews/<batch>/` (git-ignored) and are sent to the user. BAR's pictures and models are look-only (CC BY-NC-ND).
- **Scrap heaps (S-227), `aca1dd48`:** `assets/fx/scrap/scrap.py` and `scrap_1`..`scrap_4` for footprints 1, 2, 3 and 4+ (the client scales `scrap_4` for bigger units). A scorched ground patch tinted to the terrain (`team`, like the deposits), a charred debris mound with crushed chunks, and scattered bars (girders, angle iron, pipes, square and bent bars, torn plates) in rust, sooty paint and bare steel; flat bars follow the mound, some lean up out of it. Faction-neutral, no glow, a new `scrap` look in `unit.py`. 1036 / 1444 / 2032 / 2524 tris. Previews: `previews/scrap/` (sheet `scrap_heaps_sheet.png`).
  - **Names (agreed with clients-B, `a0e7b315`):** `scrap_heap_1`..`scrap_heap_4`, registered as `Meshes.fx.scrap_heap` with `variants` 1..4 by footprint, like `feature_tree` / `feature_rock`; MeshMaterials `fx_scrap_heap_<i>`. B's C-278 draws them once approved, a stand-in until then, and tints the ground patch to the terrain like the deposits.
  - **Uploaded** with the user's approval ("Yes, upload", 2026-10-31), rigged in FTGG Art, recorded (`rig_batch.py` and `record_assets.py` now know `assets/fx/scrap`). Status "review" until the user approves.
  - **Studio check** (`Workspace.ScrapReview`): 6.8, 13.6, 21.1 and 27.3 studs across for footprints 1–4, flat on the ground; all 16 maps load. Size 4 still draws grey in this Studio session (cached before its maps were served; a restart clears it). Capture: `previews/scrap/scrap_heaps_studio.jpg`.
- **Batch 1 blockouts, `6c9268f2`:** `assets/models/tools/blockouts/gen_batch1.py` writes the 31 (17 Order, 14 Chaos) from the roles, ahead of the defs: tracked, amphibious (boat bow, floats, snorkel) and hover (skirt, lift fans) kits; gun turrets with a pitching `barrel`, rocket boxes (`launcher`), lightning coils, beam lenses, constructor arms (`nano`, `nano1`), two hover factories (`buildpad`, `nano1..3`). **Not registered** in `Blockouts/Registry.luau` until each def exists (the Blockouts spec); pieces and footprints get matched to the defs then. Previews: `previews/batch1/blockouts/<id>_{threequarter,side,top}.png`, sheets `previews/batch1/blockouts_{ord,chs}_sheet.png`.
  - **Registered, `2dc8b00f`**, after merging sim-A's defs `67a74543` (S-230). `gen_batch1.py <dir> <pieces.json>` fits each rig to its def (only def pieces pivot; decorations hang from the nearest piece; the Fulgur's `missile` and the Thunderer's `emp` are parts). The Fulgur and Thunderer coils stand on a pitching `barrel` mount. The hover factories keep `buildpad` / `nano1..3` as attachments like every factory (Nanoframe spec); their defs list them as pieces, which `Blockout.validate` reads as parts: sim-A drops them from those defs' `pieces`.

**Goliath re-model (S-224, 2026-10-30).** sim-A brought `chs_goliath` back as Chaos's T2 main battle tank, and the user asked for a new model ("Scrap the old model, start from something new"). The def is unchanged: footprint 2, pieces `base`, `turret`, `armL`, `armR`, `muzzle`; the arms rest at pitch −65 and raise to fire (`chs_goliath_cannon`, the client's `PieceScripts/chs_goliath`).
- **The design** (`assets/models/chs_goliath/build.py`, 4372 tris): a hunched giant.
  - Hull: wide and tracked with slat cages, a spiked ram with a hazard stripe, reactive-armour bricks on the glacis, exhaust stacks.
  - Torso: low and broad, a forward-thrust head with amber eye slits and two horns, bricks on the cheeks, a team roof, a cupola, a sensor mast, an ammo bustle with feed chutes to the shoulders.
  - Arms, on tall shoulder pylons (pivots ±4.0, 5.5, 0.2): a pauldron hood over the elbow drum, an armoured sleeve with bricks and a team stripe, a short heavy gun, a blocky muzzle brake with knuckle spikes. At rest they hang beside the tracks with the knuckles just off the ground, like a gorilla's; the hood rides with the arm, so nothing on the torso is in the way when they raise.
- **Blockout** redone to the same layout (`muzzle` on `armR` at 4.0, 5.5, −5.5).
- **Uploaded** with the user's approval ("Yes, upload"): mesh and wreck, rigged in FTGG Art, recorded in `roblox_assets.json` (the old upload kept as `bar_<n>`), in the Meshes registry and `MeshMaterials`. Back in review: out of `APPROVED` / `APPROVED_WRECKS` until the user approves the new look.
- **Studio check** (`Workspace.GoliathReview`): rest pose, raised pose and wreck on a floor part. Posing in edit mode needs the arm glow parts unwelded and re-seated, since Studio doesn't carry WeldConstraints along when a joint's C0 changes; at runtime they follow. Sheet: `debug_out/screens/goliath_review.png`.
- **Approved by the user (2026-10-30, "Approve"):** mesh and wreck back in `APPROVED` / `APPROVED_WRECKS`.
- **Build-menu picture** rendered for E: `debug_out/pictures/chs_goliath.png` (E packs it into sheet 4). The def is still `retired` on this branch until S-224 reaches `main`, so `pictures_defs.luau` skips it; the entry was added to `defs.json` by hand (the Minotaur's setting).

**D-Gun effects (2026-10-30, the user via clients-B: "make the VFX for D-gun too"):** four templates in `place/Vfx.model.json`, from `assets/fx/vfx/build_vfx.py`, next to F27's `Death`. The colour is fixed (255, 200, 90) for both factions. They're authored at real size: the bolt is about 7 studs across, for the 14-stud-wide path.
- **`DgunBolt`:** a Folder of two Attachments.
  - `Bolt` holds the core, plasma, halo, a world-space heat trail, sparks and a light that stays on.
  - `Ground`, 5 studs below, leaves fire, a burnt strip and smoke along the path.
  - Its emitters are saved Enabled with a `Rate`, and the Folder's `Continuous` attribute says they run while the client moves the bolt.
- **`DgunMuzzle`, `DgunHit`, `DgunEnd`:** emit-once bursts, facing `-Z`.
- **Review:** `Workspace.DgunReview` in FTGG Art, the Order Commander firing past three targets. Studio's edit mode doesn't run `Rate` emitters, so the review loop emits Rate × dt by hand.
- **B's part:** wiring the four names into `Render/Vfx` and Effects.
- **The user approved the D-Gun (2026-10-30).** A fix landed after: see "Two template bugs" below. Until it's merged, the shipped templates have no attributes.

**Explosions, missiles, ground marks (2026-10-30).** The user asked for explosions "more appealing to today's standards", "for unit death, structure, nuke", and gave references in `assets/reference/unit_explosion`. Then: "make some effect marker for ground when explosion happens instead of a black circle like in game" and "Missiles deserve enhancement too. They lack some key aspect (fire booster,...)". The work is `39aa66e8`, from `assets/fx/vfx/build_vfx.py` and `assets/fx/scorch/build.py`. Everything is our own; nothing is copied from the references.
- **`Death`** (a Folder): a `Blast` attachment and five `Arm` attachments.
  - The blast: pre-flash and rays, a soft glow halo, a shock sphere, hot blobs, and a fireball that cools into dark grey smoke. Along the ground, a shock ring and dust and fire rings. Also shrapnel, sparks, debris, secondary pops, flames left on the wreck, embers, and a one-second ground glow.
  - The arms: burning chunks flung out on tilted attachments, each leaving a line of smoke.
- **`StructureDeath`:** heavier. It adds a low dust cloud as the building collapses, three chain explosions at their own spots (`Chain1..3`), fires spread over the rubble, a smoke column and seven arms.
- **`Impact`:** stays cheap: flash and rays, halo, a fireball thrown upward, sparks, dirt and smoke.
- **`Nuke`** (scale 1 = a 150-stud blast): a flash with spikes, a condensation shell, a ground shockwave out to ~3× the blast, and a fireball that burns for 3–4 s, rising into a fire-lit stem and mushroom cap. Then dust, a glowing crater with burning spots, debris and embers.
- **`MissileExhaust`** (Continuous, like `DgunBolt`), on the nozzle while the missile flies:
  - a white-hot core, a long flame plume with a hotter inner cone, and four shock diamonds (`Diamond1..4`);
  - a wide glow that reads from the RTS camera, sparks, and a thick rocket-smoke trail lit orange at the nozzle;
  - a light.
- **`Launch`:** the booster lighting: a flash, a backblast of fire, sparks, and a launch-smoke cloud with billows.
- **Blast marks** (`assets/fx/scorch/`):
  - `blast_mark_a` / `blast_mark_b`: soot decals with a charred centre, fine blast streaks, a ragged edge, an ash ring and thrown flecks.
  - `blast_mark_glow`: molten centre, a network of glowing cracks and embers. White, so the client tints it hot orange and overbright (as BeamShots does), fading over the first seconds.
  - Previews: `debug_out/scorchfx/`.
  - Uploaded 2026-10-30 with the user's approval: `Meshes.textures.blastMarkA` / `blastMarkB` / `blastMarkGlow`. The Decal ids are in `assets/fx/scorch/opencloud.json`.
  - These replace Render/Vfx's flat dark disc. The particle scorch is now only a one-second ground glow.
- **Two template bugs, found in review, fixed here:**
  - The `ParticleOrientation` values were off by one (1 is `FacingCameraWorldUp`). "Flat" scorches stood upright like domes, and streaks weren't velocity-aligned. The D-Gun's too.
  - Rojo 7.7 silently drops a top-level `"Attributes"` in a `.model.json`. Every template, the D-Gun's included, reached Studio with no `EmitCount`, `EmitDelay` or `Continuous`. They're now written typed under `Properties.Attributes`. `tests/client/VfxTemplates.spec.luau` guards this.
- **Review** (FTGG Art, the desert at Y=18): a harness that plays a template like the client does, then slows time to near zero for a capture. `TimeScale = 0` renders particles wrongly. Pictures are in `debug_out/screens/vfx_*.jpg`.
- **B's part:** request 12.

**Where it stands:** `m-models` is at `main` `d8611b86`. Every piece of models work is integrated; the last merges were `34cbaf59` and `82bedb2a`. Checks there: `lune run test` 615/615, `lune run test_client` 335/335, `lune run build` (879 scripts, 2457 requires resolve). Nothing is in review: all 203 defs have an approved mesh and an approved wreck (status table below), and all nine named maps have an approved baked ground (`GROUND_APPROVED` in `assets/models/tools/manifest.py`).

**Done since the 10-24 queue:**
- **Grounds:** the user approved the six older named-map grounds on 2026-10-29: Ridgeline, Coastline, Twin Lakes, Crossroads, Normandy and The Canyon (rows 1 and 1b, `6bff49ab`).
- **Playtest-3 units (row P3, sim-A's S-209 defs):** 21 units, each with:
  - a hand-made blockout registered in `Blockouts/Registry.luau`;
  - a BAR-style mesh and a wreck, uploaded, rigged in FTGG Art and recorded in `roblox_assets.json`.
  The user approved them all with their wrecks on 2026-10-29 (the `2026-10-29: the playtest-3 units (S-209)` blocks in `APPROVED` / `APPROVED_WRECKS`).
  - The gantries `ord_gantry` / `chs_gantry` have a `buildpad` and the spray emitters `nano1..6` / `nano1..8`. These follow B's Nanoframe spec, which passes on `main`.
  - `ord_titan` / `chs_korgoth` use the bot leg kit (`Blockouts/Bots.luau`, `tools/bots.py`) at ×2.1 / ×2.15. Their muzzles are attachments, and `missile_pod` is a piece.
  - The Mammoth's muzzles are `muzzle1` / `muzzle2`, attachments on `barrels` (sim-A's def `2ef1569d`). The rename went into the blockout, `build.py` and both `rig.json` files; nothing was re-uploaded.
- **Rig notes to client-B:** wired in B's C-252 (`5d938f5e`):
  - Mammoth: the four-leg gait, diagonal pairs FL+BR / FR+BL.
  - Titan and Korgoth: the biped walk, hips 9.66 / 9.68.
  - `missile_pod`: fires from its joint.
  - Nano turrets: the NanoTurret piece script (`turret` yaws, `nano` pitches, positive x = up).
  - Glow: the `pulse` glow breathes 0.55–1.45× at 0.5 Hz.

**Open / waiting:**
- **B's Studio check of the C-252 rigs.** B said they would report if a pivot axis or a sign is off. How to fix each kind of problem:
  - A wrong pivot in the mesh: fix `assets/models/<id>/build.py`, rebuild, re-upload, re-rig and record (pipeline below).
  - Only an Attachment or an animation entry wrong: `tools/anchors.py` / `tools/animate.py` and the rig, with no re-upload.
  - A wrong blockout: `Blockouts/<id>.luau`.
  Then commit, add a Ready line, and tell sim-A and B.
- Nothing else is queued, and no request to this stream is open.
- The temporary `src/shared/_VfxProto.luau` (F27 iteration) was deleted on 2026-10-29. It was identical to the committed `place/Vfx.model.json`. To change the death explosion, edit `assets/fx/vfx/build_vfx.py`, which writes that file.

**How to continue:**
- **Ownership:**
  - This stream owns `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/`, `assets/models/`, `assets/fx/`, the map bakes (`assets/maps/<name>/export`, `assets/maps/tools/`), `place/MeshMaterials.model.json`, `place/Vfx.model.json`, this file and `docs/decisions/models.md`. Studio: the "FTGG Art" place only.
  - Never edit `src/client` (client-B), the unit defs or `src/server` (sim-A), or the lobby (lobby-D). Ask them under "Requests".
  - 2D assets (icon sheet source, unit pictures, command and resource icons, thumbnails) belong to session E (`C:\Workspace\Projects\FTGG-2d`, since 2026-10-29). B still owns `render.mjs`, IconAtlas and the UI wiring. Send 2D requests to E under "Requests".
- **Routine:**
  - Commit each finished piece, add `Ready to merge: <sha>` to the merge queue below, and message sim-A. Sim-A integrates and pushes; this stream never pushes.
  - After an integration, merge `main` into `m-models` and run the three checks.
  - Approvals come only from the user, never relayed by another session.
  - A new unit ID goes to B (icon), C (this stream: blockout and mesh) and D (Codex).
- **Mesh pipeline, per unit** (Blender 5.2, `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"`):
  1. Write `assets/models/<id>/build.py` (`unit.run` with its pieces, footprint, budget and previews), after the blockout and the BAR reference.
  2. Build headless: `blender -b --factory-startup --python-exit-code 1 -P assets/models/<id>/build.py`. Run it again with `FTGG_WRECK=1` for `export_wreck/`.
  3. Upload: `python assets/models/tools/opencloud.py assets/models/<id>/export <id> 11846985184`, and `.../export_wreck <id>_wreck`. The key comes from `ROBLOX_API_KEY`; never print it.
  4. Rig in FTGG Art: `python assets/models/tools/rig_batch.py <id>...`. Its docstring has the Rojo copy step, the `execute_luau` snippet and the poll.
  5. Record: save the batch result to a file and run `python assets/models/tools/record_assets.py <file> "<note>"`.
  6. Regenerate: `python assets/models/tools/manifest.py`, `lune run mesh_materials`, `lune run assets/models/tools/status_table.luau`.
  7. Add the unit to `APPROVED` / `APPROVED_WRECKS` only when the user approves it.
  - Review sheets: `blender -b --factory-startup -P assets/models/tools/contact_sheet.py -- <out.png> <cols> <png>...` over the `preview_bar_*.png` renders.
  - Fresh texture maps often fail to load for a few minutes after upload. Recheck with `AssetService:CreateEditableImageAsync` before re-uploading.
- **Ground bakes:**
  1. `lune run export_ground map:<name> assets/maps/<name>` (compare with the committed `ground.json`).
  2. `blender -b --factory-startup --python-exit-code 1 -P assets/maps/tools/ground.py -- <name>`.
  3. Upload: `python assets/maps/tools/upload.py <name> 11846985184`.
  4. Load the parts in FTGG Art to get the mesh IDs into `assets/maps/<name>/roblox_assets.json`, then run `manifest.py`. **Unchecked:** `upload.py`'s docstring names a `rig_ground.luau` that isn't in the repo. The nine grounds were recorded from a Studio-side tool in an earlier session, so look in FTGG Art's `ServerStorage.ModelsTools` before the next bake and record the route here.
  5. Add the map to `GROUND_APPROVED` only when the user approves it.
  The contract is `docs/contracts/map-ground.md`, the decision M-35.
- **Studio:**
  - Live sync to FTGG Art on port 34873: `lune run serve`, then `rojo serve serve.project.json`.
  - `src/shared/_ModelsBatch.luau` is the temporary batch input. It is in `.git/info/exclude`; never commit it.
  - Review rigs live in `ReplicatedStorage.ModelReview` and the review scenes in `Workspace.*Review`.
  - Don't change place settings. Save the place before closing Studio.

## Summary (third review queue, 2026-10-24)

Your reviews:
- **T2 batch approved:** T2 aircraft, anti-nukes (fixed and mobile), missile batteries, amphibious tanks, air workers and ASW helicopters are `approved` in the manifest, with the wrecks they have (the four helicopters have none yet: item 6).
- **Key art 1 "Commander's stand" uploaded** (16 tiles, image IDs resolved in FTGG Art) and in the manifest as `keyArt.commanders_stand`, approved.

Queue:

| # | Item | Status | Shots (`debug_out/screens/`) |
|---|---|---|---|
| 1 | **The Canyon's baked ground (C-167, M-35).** 68 tiles (323,632 triangles) from the game's heights, pale rippled sand floor and red rock slabs, the borders between them smooth wavy lines instead of the cell staircase. 190 rock detail meshes (94,236 triangles): every mesa a butte, its real slope's lower part a talus apron with boulders, above it a sheer fluted cliff of 2–3 strata tiers (reds, a cream band, dark varnish streaks; the bands line up across mesas) under a caprock lip; boulder clusters on the `boulder` cells. Materials `desert`, `redrock`, `cliff`. In the manifest as `ground.canyon`, `review` (the game draws it only with `Invoke("groundanyway", true)` in Studio); built in FTGG Art as `Workspace.GroundReview.canyon` (x +6000) with two Lancers and a Ravager | **approved** (2026-10-29) | `ground_canyon_55_close.jpg`, `ground_canyon_55_220.jpg`, `ground_canyon_side.jpg` |
| 1b | **The other named maps' ground (C-167, M-35)**, each in the manifest as `ground.<name>`, `review`, built in FTGG Art (`Workspace.GroundReview.<name>`) with two Lancers and a Ravager. New textures `grass`, `rock`, `sand`, `road`, `leafy`. **Coastline** (32 tiles, 137k triangles; 24 crag details, 49k): grey rock ridges under a craggy skin on grass, sand shore. **Ridgeline** (22 tiles, 133k; 12 details, 23k). **Twin Lakes** (80 tiles, 305k; 55 details, 65k). **Crossroads** (76 tiles, 306k; 56 details, 85k: rock-banked sandy river beds, water stays the client's). **Normandy** (165 tiles, 568k; 44 details, 97k): fields, tarmac roads, beach and sea bed, crag on the bluffs, continuous hedgerow rolls on the bocage banks, the village plots raised for the client's houses | **approved** (2026-10-29) | `ground_<map>_55_close.jpg`, `ground_<map>_55_220.jpg` |
| 1c | **The Lakelands' baked ground (S-189, `map:lakelands`, 512 × 512 cells, 4096 studs, the first big map)**, in the manifest as `ground.lakelands`, `review`. Baked at the full 4-stud sampling it came to 2.23M triangles (20 uploads), 3.4× the heaviest map so far (Normandy, 664k) and drawn at `RenderFidelity.Precise` with no LOD. So big maps can take every other height sample (`STYLES[name].coarsen`, `Field.coarsen` in `assets/maps/tools/ground.py`): the Lakelands at 8 studs is 557k triangles (533k tiles, 24k rock detail), 402 meshes in 5 uploads, about Normandy's cost for 4× the area; it is 98% gentle grass with small sandy lakes and mirrored rock ridges, so the coarser sampling loses nothing visible (a mesa map would need its 4-stud detail). The bake takes 1.5 min; the preview camera now sees whole big maps | **approved** (2026-10-26) | `lakelands_ground_far.png` (the whole map), `lakelands_ground_55_220.png` (a rock ridge); Blender previews |
| 1d | **The Plains' baked ground (S-192, `map:plains`, 256 × 256 cells, 2048 studs, the last named map without a bake)**, in the manifest as `ground.plains`, `review`. Flat grass with the road grid: 536,694 triangles, 104 meshes in 5 uploads, no rock detail, at the full 4-stud sampling. The `ground` material (a handful of cells, no texture of its own) now always merges into its neighbours in `assets/maps/tools/ground.py` | **approved** (2026-10-27) | Blender previews in `assets/maps/plains/export/` |
| 1e | **Supreme Strait's baked ground (S-196, `map:supreme_strait`, 320 × 320 cells, 2560 studs)**, `ground.supreme_strait`, re-baked from sim-A's BAR-pipeline layers (the S-195 bake of the old hand-shaped map was not approved). Dressed in its BAR texture's colours as per-map material variants (`STYLES.palette`, textures.py `VARIANTS`): `strait_sand` grey stone (sea floors, paths, the strait), `strait_grass` olive, `strait_rock` dark brown-grey. BAR's environment design guide (clean play areas, dark readable rock): the crag skin only on slopes (`crag_slope`), flat rock stays clean. Full 4-stud sampling, so the reef islets (12-16 studs across, ~20 studs high) stand up: 1,081,169 triangles (852k tiles, 229k crag and boulders), 335 meshes in 10 uploads. Re-baked once more after sim-A's compile flip (dcc4dc0f: BAR's north is now -z, the top of the game's screen), so the seas sit north-west and south-east as in BAR. Previews draw the water (`water_preview`, preview only) and a straight-down view as the game camera sees it | **approved** (2026-10-27) | `preview_top.png`, `preview_55_far.png` in `assets/maps/supreme_strait/export/` |
| P3 | **Playtest-3 units (sim-A's S-209 defs), blockouts and BAR-style meshes with wrecks**, after the BAR renders in `debug_out/refs/playtest3/`, all `review`. T1, fp 2: `ord_advsolar` (a ribbed generator drum under a big curved dish of cells, armadvsol) / `chs_advsolar` (a low armored bowl round a turbine, coradvsol); `ord_capacitor` (an octagonal stack of glowing cell bands between team-paneled pillars, armestor) / `chs_accumulator` (a stepped dome with glowing charge wedges, corestor); `ord_nano` / `chs_nano` construction turrets (`turret` yaws, `nano` pitches, the spray from a `nano1` attachment at a big glowing lens); `ord_seaextractor` / `chs_seaextractor` (seabed extractors, a turning `drill`). T2, fp 3: `ord_advconverter` (an arched coil tunnel, `coil` pulses) / `chs_advconverter` (an octagonal kiln, `crucible` pulses); `ord_advdepot` (a huge sealed drum) / `chs_advdepot` (four silos round a pump tower); `ord_advcapacitor` (twin cell towers, `cells` pulse) / `chs_advaccumulator` (an armored bunker of charge cells). `ord_advfusion` / `chs_advfusion` (fp 6: a stepped ziggurat / a squat block gripping a huge glowing sphere, `core` pulses, ~28 studs tall). `ord_gantry` / `chs_gantry` Experimental Gantries (fp 7: a 26 x 26 pad between emitter towers, nano1..6 / a raised split-door platform with a ramp, nano1..8). Walkers: `ord_titan` (armbanth: blue shoulder pads, tachyon beam arm, twin blasters, shoulder missile tube; ~22 studs) and `chs_korgoth` (corkorg: red slab chest, heat-ray head, two double-barrelled shotgun arms, VLS tube; ~23 studs), the bot leg kit at x2.1; `chs_mammoth` (an armored war elephant, pillar legs `legFL..legBR` swinging, a back turret with two laser barrels). 2,300-7,600 triangles; rigged in FTGG Art (`ReplicatedStorage.ModelReview.<id>_bar` / `_wreck_bar`), every map loads there | **approved** with wrecks (2026-10-29) | Blender previews `assets/models/<id>/export/preview_bar_*.png` |
| S-197 | **Map features: `feature_tree` and `feature_rock`** (sim-A's S-197 contract), fx entries like the deposits: one per family, every variant listed (`assets/fx/features/`, shared builder `features.py`, the new `nature` look in unit.py). Trees: two dark pines (15 / 12.5 studs, 144 / 126 triangles) and two broadleaf crowns (12 / 10.5 studs, 272 / 252), trunk and roots inside 4 studs; rocks: three faceted boulders 6.6-7.4 studs across in their 8-stud cell, sunk 0.6, with yellow lichen like BAR's (100-140 triangles). Supreme Strait's 398 trees and 170 rocks come to about 100k triangles. The client picks the variant and a +-15% scale from the wreck ID and turns it by the wire heading | **approved** (2026-10-27) | `preview_bar_35.png` per variant in `assets/fx/features/<id>/export/` |
| 2 | **S-157 tower meshes with wrecks** (your approved shapes, the `pair_*.png` builds, dressed in the mesh style): Order bodies in the sand paint (white-sand in Studio's light) with cyan strips, Chaos gunmetal with amber; added a chamfered bolted base skirt on every tower, panel lines round the columns and turrets (baked), louvred vents, clamped cable runs from base to turret, faction glow strips up the column fronts, an antenna on each turret (`tools/towers.py`). Laser emitters keep their `weapon` glow (lens or coil ring); Gauntlet / Talos (guns) have none. T1 at fp 2 (16 studs), Bulwark T2 at fp 3, larger. Wrecks for all nine. Status `review`, wrecks `review`. Triangles 2,184–3,256 (Bulwark 4,708); glow Order 2.7–10% (Overwatch's lit vent band), Chaos 1.1–2.8% | **approved** (2026-10-26) | `s157_towers_55_close_a.jpg` (Lancer, Sentry / Guard, Beamer / Geryon, Overwatch), `s157_towers_55_close_b.jpg` (Twin Guard, Gauntlet / Talos, Bulwark), `s157_towers_55_220.jpg` |
| 3 | **T2 ship hull redesign** (not a rescale): every hull is now one lofted shell from `tools/ships.py`: a pointed raked bow, flared sides, a sheer line rising to the bow, a rounded bilge, a tapered stern with a transom, a dark boot-top and a sheer strake, with running strips that follow the sheer. Destroyers lean and fast (`ord_crusader`: forward deckhouse, tall bridge with wraparound glass and wings, tower mast, raked funnel, hangar and helideck; `chs_corsair`: narrower, sharper bow, raised bridge with an amber slit, two raked funnels, tall lattice mast); cruisers bulkier with stacked decks (`ord_dominion`: armored belt, three-level superstructure, superfiring triples fore and aft on barbettes; `chs_kraken`: reactive slabs, raised bridge, two funnels); carriers keep the flat deck over a real hull and a hangar deck, with a taller three-level island (`ord_sanctuary`, `chs_leviathan`). Guns raised on barbettes. Same pieces and muzzles, new pivots. The T2 workers and jammer (`ord_harbormaster`, `chs_reaver`, `chs_siren`), the T1 corvettes (`ord_sentry` Envoy, `chs_barracuda`) and the naval workers (`ord_tidewright`, `chs_wrecker`) had the same barge hull and get the lofted one too (back to review). Wrecks rebuilt for all | **approved** (2026-10-26) | `ships_v2_55_close.jpg`, `ships_v2_55_220.jpg` |
| 4 | **Shepherd / Griffin** (mobile point defence, S-149), hand-made blockouts and meshes with wrecks: `ord_shepherd` (armored 6x6, sloped cab with wraparound glass, team skirts; the static `launcher` a vertical-launch module with a 2 x 4 grid of cell hatches and ready lights; a compact search panel on a mast, client-turned `radar`) / `chs_griffin` (lighter open 6x6, amber cab slit; the static `launcher` an open welded rack of twelve upright tubes with amber mouths, the deep stock; a lattice radar mast with a beacon). Both launch straight up from `muzzle` | **approved** (2026-10-26) | `pd_trucks_55_close.jpg`, `pd_trucks_55_220.jpg` |
| 5 | **T2 structures at the S-104 sizes** (new builds, not rescales; 26 meshes, Order sand with cyan, Chaos gunmetal with amber, panel lines, vents, cable runs, hazard edges and base skirts). Factories fp 6 (48 studs): `ord_advvehplant` (two-bay armored hall with a moving gantry and a radar) / `chs_advvehplant` (open lattice gantry yard with two trolleys and a saw-tooth shed), `ord_advairfield` (two armored hangars, runway, control tower, radome) / `chs_advairfield` (patched apron, open hangar, lattice radar mast, fuel tanks), `ord_advshipyard` (portal gantry over a slip) / `chs_advshipyard` (three lattice cranes on piers). Economy: `ord_advextractor` / `chs_advextractor` (fp 3), `ord_fusion` (glowing core in a portal frame) / `chs_fusion` (banded reactor in a cage) (fp 4). Sensors and jammers: `ord_beacon` / `chs_allseer`, `ord_witness` / `chs_augur`, `ord_choir` / `chs_deepear`, `ord_veilspire` / `chs_blackout`, `ord_tribunal` / `chs_seekerspire`. Defences fp 3: `ord_edict` / `chs_cataclysm`, `ord_rampart` / `chs_breaker`, `ord_bastion` / `chs_maw`. Same pieces, anchors and anims as the blockouts (factory nanos on their gantries / trolleys). Triangles 2,492–7,866; glow 1.6–5.5%. Their 26 wrecks are in the manifest too (row 6) | **approved** (2026-10-26) | `t2struct_a_55_close.jpg`, `t2struct_a_55_220.jpg` (factories, extractors, fusion), `t2struct_b_55_close_right.jpg` and `t2struct_b_55_close_left_before.jpg` (sensors, jammers, defences; the left one was taken before `ord_tribunal`'s fix, `t2struct_tribunal_fixed.jpg` shows it now); Studio, Order front row, Chaos behind, a Lancer front left. Blender previews: `t2struct_sheet_a/b/c.png`. Four uploads had a texture map Roblox wouldn't load (`chs_fusion`, `ord_advairfield`, `ord_advextractor`, `chs_cataclysm`) and `ord_tribunal` drew white: all five re-uploaded; every T2 structure's maps now load in FTGG Art |
| 6 | **Wrecks for every mesh that had none** (56 this round: the 26 T2 structures above and 30 more units: ord_silence, ord_barrier, chs_condor, chs_leech, ord_tidewatch, ord_zenith, chs_cyclops, chs_forgemaster, chs_gorgon, chs_hydra, chs_juggernaut, chs_minotaur, chs_shroud, chs_stalker, ord_arbiter, ord_architect, ord_judgement, ord_paladin, ord_seraph, ord_veil, ord_warden, chs_carapace, chs_hailstorm, chs_inferno, ord_lumen, ord_phalanx, ord_radiance, chs_ragnarok, ord_citadel, ord_reckoning). Each is its live mesh broken and burnt in Blender (`FTGG_WRECK=1`), rigged in FTGG Art with the clamp scale from its measured `base_bar`; every wreck's texture maps load there. Every meshed unit now has a wreck | **approved** (`145e7b32`) | Blender previews `assets/models/<id>/export_wreck/preview_bar_*.png` (local, gitignored); Studio: `ReplicatedStorage.ModelReview.<id>_wreck_bar` in FTGG Art |
| F18 | **Beta feedback F18: towers that stand high and proud** (blockouts first; meshes after your look review; footprints, pieces and build pads unchanged). T2 defences, fp 3, now real towers with the turret ring at 15–18 studs and tops at 23–25 (six Lancers; the old meshes were 6–15): `ord_bastion` (sloped plinth, slim square keep with four buttresses, team band, lit slits; broad wedge turret, twin guns, sensor mast) / `chs_maw` (scrap drum tower: fat lower drum with spikes, raking struts up a tall narrow drum; squat turret with the fat glowing maw), `ord_rampart` (sea-wall bunker, tall gun tower with four corner bartizans and a parapet; twin very long guns, rangefinder) / `chs_breaker` (lattice gun tower: four splayed legs, two tiers of X bracing, railed deck at 17.6; one very long gun, missile box), `ord_edict` (stepped three-tier fortress; casemate with a long gun raised 20°) / `chs_cataclysm` (tall round pit tower with struts and a spiked rim; fat mortar raised 40°). T1 laser towers, fp 2, your approved shapes kept but taller and heavier (wider skirts, taller columns, bigger heads and emitters with focus coils): `ord_sentry_tower` 16 → 20 studs / `chs_guard` 14 → 18, `ord_overwatch` 15 → 19 / `chs_geryon` (the green three-barrel drum) 16 → 20, `ord_beamer` 16 → 19 / `chs_twin_guard` 15 → 18. In game: all these towers' meshes are `review` (the S-157 laser tower meshes too), so the F18 blockouts draw in game since the merge; the rebuilt meshes follow for your review. **Meshes (approved blockouts, 2026-10-26):** each T2 defence keeps its approved turret, lifted onto a new tower body (`unit.lifted`), Edict's long gun raised 20° and Cataclysm's mortar 40° (`unit.pitched`); the six T1 laser / beam towers are their approved meshes scaled ×1.20–1.28 to their blockouts' heights; all with wrecks, every texture map loading in FTGG Art (`chs_advextractor` re-uploaded once) | **approved** (2026-10-26) | meshes: `f18_mesh_55_close_t2def.jpg`, `f18_mesh_55_close_lasers_extractors.jpg`, `f18_mesh_55_220.jpg` (Studio `Workspace.F18MeshReview`); blockouts: `f18_t2def_55_close.jpg`, `f18_t2def_55_220.jpg`, `f18_t2def_side.jpg` (new blockouts left, Order front / Chaos behind; old meshes and the T1 Sentry / Guard on the right; a Lancer front left), `f18_laser_55_close.jpg`, `f18_laser_side.jpg` (new Sentry / Guard, Overwatch / Geryon and Beamer / Twin Guard blockouts, Order front / Chaos behind, a new Bastion / Maw in the middle, the old meshes on the right). Studio: `Workspace.F18Review`, `Workspace.F18LaserReview` |
| S-181 | **New units from the playtest (sim-A's S-181), blockouts**, approved and registered (S-181 is in `main` at `7c933c5c`; the game draws them now). Bot factories with build pads and nano emitters: `ord_botlab` (armored hall, portal gantry over a lit pad, 3 emitters) / `chs_botlab` "Bot Pit" (round scrap-walled pit open at the front, two crane masts whose hooks spray), `ord_advbotlab` (the same grown to fp 5: heavy gantry, 4 emitters, radar) / `chs_advbotlab` (bigger spiked pit, tower crane over it, lamp masts, furnace stacks). T1 bots, fp 1, on two legs (the Commander walker legs, rig.md 10, without hip yokes: client pieces `thighL` / `shinL` / `footL` and R, swing X, from the new `Blockouts/Bots.luau`; the Skitter's four `thighFL`… / `shinFL`…): `ord_artisan` (constructor, emitter arm) / `chs_tinker` (hunched, crane boom with a claw), `ord_lazarus` (medic: glass dome, team cross, repair arm) / `chs_graverobber` (scavenger: scrap hopper, claw arm), `ord_glint` (slim runner, a laser on each arm) / `chs_skitter` (four-legged crawler, plasma snout), `ord_mace` (long plasma barrel over the shoulder) / `chs_thug` (stocky, spiked pads, cannon forearm), `ord_kestrel` (missile pod on the shoulder) / `chs_needle` (three bare tubes over the back). T2: `ord_fatboy` (fat body on thick legs, a huge plasma cannon turret on top) / `chs_tzar` (long heavy tank, fat plasma cannon), `chs_centurion` (12-stud armored knight, shield, red laser lance). Air: `ord_liche` (swept flying wing, four buried engines, bomb bay with one huge bomb) / `chs_dragon` (dragon-headed hull with horns and glowing eyes, spined back, fan wings, fire nozzle under the belly, green lasers at the wing tips; 32-stud span). **Meshes (2026-10-26):** all 19 with wrecks, every texture map loading in FTGG Art. Bots on the shared leg kit `tools/bots.py` (the blockouts' hip / knee / ankle points: armored Order legs with team stripes, bare Chaos struts with pistons and claw toes; `swing` X anims in `tools/animate.py`), labs with their build pads and emitters in `tools/anchors.py` | **approved** (2026-10-26) | meshes: `s181_mesh_bots.jpg`, `s181_mesh_air.jpg`, `s181_mesh_labs.jpg` (Studio `Workspace.S181MeshReview`); blockouts: `s181_units.jpg`, `s181_bots_close.jpg`, `s181_factories.jpg`, `s181_air.jpg` (Order front / Chaos behind; a Lancer and a Paladin for scale). Studio: `Workspace.S181Review` |
| F6 | **Advanced extractors: the T1's size, an upgraded T1** (your call 2026-10-26: "T2 of the T1 extractor must be the same size, they should look like an upgrade version"; asked sim-A to make both defs footprint 2, the T1's 2 × 2 deposit patch, instead of S-184's 4). `ord_advextractor`: the T1's slab and octagonal armored housing with its team deck, plus a second armored tier with a lit band and radiator fins, a taller turning drill tower with two glowing bands and a four-armed crown, twin pumps, hoppers, corner lights (11 studs to the T1's 6). `chs_advextractor`: the T1's four-legged pyramid derrick, taller with two tiers of bracing, armored feet with spikes, a heavier head with a lamp, a thicker turning drill with four glowing bands, two engine drums instead of one, fuel tanks (15 studs to the T1's 8). **Meshes:** each built from its T1's mesh code with the upgrade added (Order: the second armored tier, radiator fins, a taller drill tower with three bands and a four-armed crown; Chaos: the derrick nearly twice as tall, five brace rings, armored spiked feet, a second engine drum, fuel tanks), with wrecks | **approved** (2026-10-26) | meshes in `f18_mesh_55_close_lasers_extractors.jpg` (right: each T1 then its T2); `f6_advextractor_55_close.jpg` (left the T1 mesh, right the new T2 blockout; Order front, Chaos behind, a Lancer). Studio: `Workspace.F6Review` |
| F27 | **Unit death explosion** (the user's reference `assets/reference/unit_explosion`, via client-B): the template `ReplicatedStorage.Vfx.Death` that Render/Vfx plays for every death (C-232), written by `assets/fx/vfx/build_vfx.py` into `place/Vfx.model.json` (mapped in the three project files like MeshMaterials). A ground burst at scale 1 = a 7-stud explosion: a white-hot flash, a rolling orange fireball, a ring of fire racing out along the ground, fire burning on low in the middle, long streaking sparks (stretched solid streaks: the built-in spark texture vanishes at RTS range), dark debris thrown in arcs, lit brown-black smoke billowing up, glowing embers, a glowing scorch, an orange light (0.55 s). Built-in Studio textures only. Live sync: restart `rojo serve` once to pick up the new `Vfx` entry | **approved** (2026-10-26) | `vfx_death_035s_side.jpg`, `vfx_death_090s_side.jpg`, `vfx_death_030s_rts.jpg`, `vfx_death_070s_rts.jpg` (FTGG Art, scale 3 ≈ a T1 death, frozen at 0.3–0.9 s) |
| S | **sim-A's request (first in the queue):** pending blockouts under the sim's fixed IDs, in `Blockouts/Pending/` until the defs land. Naval SAM platforms, fp 3, floating at y = 0: `ord_pharos` (round armored caisson with a team deck ring and fenders, a lighthouse tower with a team band, gallery and glowing lantern, crowned by the `launcher`: a sensor head between two canister pods with ready-lit caps) / `chs_scylla` (a ruin afloat: drum floats under a tilted slab deck, ruined columns, one toppled, a crooked spiked pedestal with an amber eye slit; the `launcher` a slab skull with six missile tubes fanned out like necks, amber mouths). Advanced rearm pads, fp 4, two bays: `ord_empyrean` (armored apron, two team-ringed landing circles, a control tower with a glass cab and radar mast between the bays at the back, blast deflectors, rearm booms, fuel blocks) / `chs_rookery` (patched dark slab with a grate, two circles with amber lamps, a scrap barricade, fuel tanks and hose, a crane stub over a bay, a lattice light mast, crates). Meshes after your look review. **Blockouts approved and meshed (2026-10-26)**, with wrecks, every texture map loading in FTGG Art | **approved** (2026-10-26) | meshes: `last4_mesh_vs_blockout.jpg` (blockouts left, meshes right; Studio `Workspace.Last4Review`); blockouts: `t2_navalsam_pads_blockout_55_close.jpg`, `t2_navalsam_pads_blockout_55_220.jpg` (with a Lancer and the T1 pads) |

**Resume here (2026-10-26):**
- **Items 5 and 6 done:** the 26 T2 structures and 56 wrecks are in the manifest as `review`. Item 7 done. F18 blockouts in (row F18), waiting for your look review before the meshes. S-181 blockouts in `Pending/` (row S-181): register them once S-181 is in `main`. S-181 blockouts approved and registered; F18 towers and F6 extractors approved (2026-10-26); all their meshes, wrecks, the Lakelands ground and the F27 death explosion approved 2026-10-26.
- **Rig route:** the batch input goes to FTGG Art through the Rojo sync as a temporary `src/shared/_ModelsBatch.luau` (excluded from git); `ServerStorage.ModelsTools.Batch` rigs it (pass the clamp scale for meshes longer than 20.48 studs); the result is recorded with `record_assets.py`. The manifest must use the committed `export_wreck/rig.json` for any wreck rebuilt but not yet recorded (none now).
- **FTGG Art:** review folders added this session (`Workspace.GroundReview`, `TowerMeshReview`, `ShipV2Review`, `SmallShipV2Review`, `NewT2PadReview/Profile/Silhouette`); save the place before closing Studio.

**Canyon textures in the match place:** clients-B saw the tiles draw flat white there; every ground map loads in that place (fetch status Success, readable). Likely Studio's cached texture pack (a restart fixed the same symptom in FTGG Art); B rechecks after a Studio restart and tells me if they're still white.

**Notes for clients-B (C-167):**
- **Ground clicks:** `Render/MeshGround` makes the tiles with `CollisionFidelity.Box`, and `CanQuery` on. A raycast then hits each tile's bounding box, not its surface: over the Canyon's mesas a 256-stud tile's box top sits at the mesa height, so `Controls.groundAt` would land clicks up to 50 studs high. In FTGG Art every ray hit y = 18 on flat sand. Suggest `CanQuery` off on the tiles and ground clicks from Core/Terrain's heights (or `PreciseConvexDecomposition`, which costs more).
- **Seams:** the borders between ground types no longer fall on cell edges (M-35: wavy lines cut through the triangles, the surface unchanged). The contract's "seams fall on cell edges" line could say so.
- **New material key `cliff`** (the strata walls, details only): `GroundMeshes.FALLBACK` has no entry, so it would draw as grass if its SurfaceAppearance were missing. Suggest `cliff = { material = "Sandstone", color = { 150, 78, 52 } }`.
- The Canyon's `ground` cells (the 92 deposit cells) are drawn as the type around them; the deposit models cover them.

## Status table (queue item 7)

Every unit def: its blockout, mesh and wreck status in the mesh manifest (`review` = drawn as the blockout in game until you approve it).

<!-- status-table:begin -->
238 defs: 235 hand-made blockouts; 207 meshes (207 approved, 0 in review); 207 wrecks (207 approved). Generated by `lune run assets/models/tools/status_table.luau`.

| Def | Name | Tier | Domain | Blockout | Mesh | Wreck |
|---|---|---|---|---|---|---|
| `chs_warlord` | Warlord | 0 | ground | hand-made | approved | approved |
| `ord_sovereign` | Sovereign | 0 | ground | hand-made | approved | approved |
| `chs_cleaver` | Cleaver | 1 | ground | hand-made | – | – |
| `chs_dredger` | Dredger | 1 | ground | hand-made | – | – |
| `chs_drifter` | Drifter | 1 | ground | hand-made | – | – |
| `chs_glaive` | Glaive | 1 | ground | hand-made | – | – |
| `chs_gnat` | Gnat | 1 | ground | hand-made | – | – |
| `chs_graverobber` | Graverobber | 1 | ground | hand-made | approved | approved |
| `chs_hellmouth` | Hellmouth | 1 | ground | hand-made | approved | approved |
| `chs_hornet` | Gadfly | 1 | ground | hand-made | approved | approved |
| `chs_jackal` | Jackal | 1 | ground | hand-made | approved | approved |
| `chs_locust` | Locust | 1 | ground | hand-made | approved | approved |
| `chs_mudskipper` | Mudskipper | 1 | ground | hand-made | – | – |
| `chs_needle` | Needle | 1 | ground | hand-made | approved | approved |
| `chs_ravager` | Ravager | 1 | ground | hand-made | approved | approved |
| `chs_scrapper` | Scrapper | 1 | ground | hand-made | approved | approved |
| `chs_skitter` | Skitter | 1 | ground | hand-made | approved | approved |
| `chs_skua` | Skua | 1 | ground | hand-made | – | – |
| `chs_sling` | Sling | 1 | ground | hand-made | – | – |
| `chs_snapjaw` | Snapjaw | 1 | ground | hand-made | – | – |
| `chs_thug` | Thug | 1 | ground | hand-made | approved | approved |
| `chs_tinker` | Tinker | 1 | ground | hand-made | approved | approved |
| `chs_watcher` | Gazer | 1 | ground | hand-made | approved | approved |
| `ord_artisan` | Artisan | 1 | ground | hand-made | approved | approved |
| `ord_courser` | Courser | 1 | ground | hand-made | – | – |
| `ord_dart` | Dart | 1 | ground | hand-made | – | – |
| `ord_gemini` | Gemini | 1 | ground | hand-made | – | – |
| `ord_glint` | Glint | 1 | ground | hand-made | approved | approved |
| `ord_halcyon` | Halcyon | 1 | ground | hand-made | – | – |
| `ord_halo` | Halo | 1 | ground | hand-made | approved | approved |
| `ord_herald` | Herald | 1 | ground | hand-made | approved | approved |
| `ord_kestrel` | Kestrel | 1 | ground | hand-made | approved | approved |
| `ord_lancer` | Lancer | 1 | ground | hand-made | approved | approved |
| `ord_lazarus` | Lazarus | 1 | ground | hand-made | approved | approved |
| `ord_mace` | Mace | 1 | ground | hand-made | approved | approved |
| `ord_mason` | Mason | 1 | ground | hand-made | approved | approved |
| `ord_oracle` | Scryer | 1 | ground | hand-made | approved | approved |
| `ord_pontifex` | Pontifex | 1 | ground | hand-made | – | – |
| `ord_skimmer` | Skimmer | 1 | ground | hand-made | – | – |
| `ord_skimwright` | Skimwright | 1 | ground | hand-made | – | – |
| `ord_verdict` | Verdict | 1 | ground | hand-made | approved | approved |
| `ord_volley` | Volley | 1 | ground | hand-made | – | – |
| `ord_wader` | Wader | 1 | ground | hand-made | – | – |
| `chs_buzzard` | Buzzard | 1 | air | hand-made | approved | approved |
| `chs_harpy` | Harpy | 1 | air | hand-made | approved | approved |
| `chs_plague` | Plague | 1 | air | hand-made | approved | approved |
| `chs_vulture` | Vulture | 1 | air | hand-made | approved | approved |
| `chs_wasp` | Wasp | 1 | air | hand-made | approved | approved |
| `ord_absolution` | Absolution | 1 | air | hand-made | approved | approved |
| `ord_courier` | Courier | 1 | air | hand-made | approved | approved |
| `ord_falcon` | Falcon | 1 | air | hand-made | approved | approved |
| `ord_guardian` | Guardian | 1 | air | hand-made | approved | approved |
| `ord_skywright` | Skywright | 1 | air | hand-made | approved | approved |
| `chs_barracuda` | Piranha | 1 | naval | hand-made | approved | approved |
| `chs_lamprey` | Hagfish | 1 | naval | hand-made | approved | approved |
| `chs_wrecker` | Wrecker | 1 | naval | hand-made | approved | approved |
| `ord_sentry` | Envoy | 1 | naval | hand-made | approved | approved |
| `ord_silence` | Silence | 1 | naval | hand-made | approved | approved |
| `ord_tidewright` | Tidewright | 1 | naval | hand-made | approved | approved |
| `chs_accumulator` | Accumulator | 1 | structure | hand-made | approved | approved |
| `chs_advsolar` | Advanced Sun Trap | 1 | structure | hand-made | approved | approved |
| `chs_airfield` | Aerodrome | 1 | structure | hand-made | approved | approved |
| `chs_airpad` | Roost | 1 | structure | hand-made | approved | approved |
| `chs_botlab` | Bot Pit | 1 | structure | hand-made | approved | approved |
| `chs_converter` | Smelter | 1 | structure | hand-made | approved | approved |
| `chs_depot` | Hoard | 1 | structure | hand-made | approved | approved |
| `chs_extractor` | Excavator | 1 | structure | hand-made | approved | approved |
| `chs_eye` | Eye | 1 | structure | hand-made | approved | approved |
| `chs_fang` | Fang | 1 | structure | hand-made | approved | approved |
| `chs_generator` | Furnace | 1 | structure | hand-made | approved | approved |
| `chs_geryon` | Geryon | 1 | structure | hand-made | approved | approved |
| `chs_guard` | Guard | 1 | structure | hand-made | approved | approved |
| `chs_listener` | Listener | 1 | structure | hand-made | approved | approved |
| `chs_nano` | Construction Turret | 1 | structure | hand-made | approved | approved |
| `chs_riptide` | Whirlpool | 1 | structure | hand-made | approved | approved |
| `chs_seaextractor` | Sunken Excavator | 1 | structure | hand-made | approved | approved |
| `chs_shipyard` | Drydock | 1 | structure | hand-made | approved | approved |
| `chs_skimyard` | Skim Yard | 1 | structure | hand-made | – | – |
| `chs_smog` | Smog | 1 | structure | hand-made | approved | approved |
| `chs_solar` | Sun Trap | 1 | structure | hand-made | approved | approved |
| `chs_spike` | Spike | 1 | structure | hand-made | approved | approved |
| `chs_talos` | Talos | 1 | structure | hand-made | approved | approved |
| `chs_thorn` | Thorn | 1 | structure | hand-made | approved | approved |
| `chs_tidal` | Tide Mill | 1 | structure | hand-made | approved | approved |
| `chs_twin_guard` | Twin Guard | 1 | structure | hand-made | approved | approved |
| `chs_vehplant` | Vehicle Foundry | 1 | structure | hand-made | approved | approved |
| `chs_windmill` | Wind Pylon | 1 | structure | hand-made | approved | approved |
| `ord_advsolar` | Advanced Solar Collector | 1 | structure | hand-made | approved | approved |
| `ord_airfield` | Airfield | 1 | structure | hand-made | approved | approved |
| `ord_airpad` | Aerie | 1 | structure | hand-made | approved | approved |
| `ord_barrier` | Barrier | 1 | structure | hand-made | approved | approved |
| `ord_beamer` | Beamer | 1 | structure | hand-made | approved | approved |
| `ord_botlab` | Bot Lab | 1 | structure | hand-made | approved | approved |
| `ord_bulwark` | Bulwark | 1 | structure | hand-made | approved | approved |
| `ord_capacitor` | Capacitor Bank | 1 | structure | hand-made | approved | approved |
| `ord_converter` | Supply Converter | 1 | structure | hand-made | approved | approved |
| `ord_curtain` | Curtain | 1 | structure | hand-made | approved | approved |
| `ord_depot` | Depot | 1 | structure | hand-made | approved | approved |
| `ord_ear` | Ear | 1 | structure | hand-made | approved | approved |
| `ord_extractor` | Extractor | 1 | structure | hand-made | approved | approved |
| `ord_gauntlet` | Gauntlet | 1 | structure | hand-made | approved | approved |
| `ord_generator` | Generator | 1 | structure | hand-made | approved | approved |
| `ord_hoverdock` | Hover Dock | 1 | structure | hand-made | – | – |
| `ord_moat` | Moat | 1 | structure | hand-made | approved | approved |
| `ord_nano` | Construction Turret | 1 | structure | hand-made | approved | approved |
| `ord_overwatch` | Overwatch | 1 | structure | hand-made | approved | approved |
| `ord_seaextractor` | Offshore Extractor | 1 | structure | hand-made | approved | approved |
| `ord_sentry_tower` | Sentry | 1 | structure | hand-made | approved | approved |
| `ord_shipyard` | Shipyard | 1 | structure | hand-made | approved | approved |
| `ord_solar` | Solar Array | 1 | structure | hand-made | approved | approved |
| `ord_tidal` | Tidal Generator | 1 | structure | hand-made | approved | approved |
| `ord_undertow` | Undertow | 1 | structure | hand-made | approved | approved |
| `ord_vehplant` | Vehicle Plant | 1 | structure | hand-made | approved | approved |
| `ord_vigil` | Vigil | 1 | structure | hand-made | approved | approved |
| `ord_watchtower` | Watchtower | 1 | structure | hand-made | approved | approved |
| `ord_windmill` | Wind Turbine | 1 | structure | hand-made | approved | approved |
| `chs_centurion` | Sunder | 2 | ground | hand-made | approved | approved |
| `chs_chimera` | Chimera | 2 | ground | hand-made | approved | approved |
| `chs_cyclops` | Demolisher | 2 | ground | hand-made | approved | approved |
| `chs_forgemaster` | Forgemaster | 2 | ground | hand-made | approved | approved |
| `chs_goliath` | Goliath | 2 | ground | hand-made | approved | approved |
| `chs_gorgon` | Medusa | 2 | ground | hand-made | approved | approved |
| `chs_grendel` | Grendel | 2 | ground | hand-made | – | – |
| `chs_griffin` | Griffin | 2 | ground | hand-made | approved | approved |
| `chs_hellfire` | Hellfire | 2 | ground | hand-made | – | – |
| `chs_hurler` | Hurler | 2 | ground | hand-made | – | – |
| `chs_hydra` | Hydra | 2 | ground | hand-made | approved | approved |
| `chs_mammoth` | Mammoth | 2 | ground | hand-made | approved | approved |
| `chs_minotaur` | Minotaur | 2 | ground | hand-made | approved | approved |
| `chs_mire` | Mire | 2 | ground | hand-made | approved | approved |
| `chs_shroud` | Murk | 2 | ground | hand-made | approved | approved |
| `chs_stalker` | Stalker | 2 | ground | hand-made | approved | approved |
| `chs_tzar` | Tzar | 2 | ground | hand-made | approved | approved |
| `ord_arbiter` | Assessor | 2 | ground | hand-made | approved | approved |
| `ord_architect` | Architect | 2 | ground | hand-made | approved | approved |
| `ord_custodian` | Custodian | 2 | ground | hand-made | approved | approved |
| `ord_fatboy` | Fatboy | 2 | ground | hand-made | approved | approved |
| `ord_fulgur` | Fulgur | 2 | ground | hand-made | – | – |
| `ord_judgement` | Judgement | 2 | ground | hand-made | approved | approved |
| `ord_luminary` | Luminary | 2 | ground | hand-made | – | – |
| `ord_magistrate` | Magistrate | 2 | ground | hand-made | – | – |
| `ord_mandate` | Mandate | 2 | ground | hand-made | – | – |
| `ord_paladin` | Vindicator | 2 | ground | hand-made | approved | approved |
| `ord_seraph` | Seraph | 2 | ground | hand-made | approved | approved |
| `ord_shepherd` | Shepherd | 2 | ground | hand-made | approved | approved |
| `ord_tideguard` | Tideguard | 2 | ground | hand-made | approved | approved |
| `ord_veil` | Mantle | 2 | ground | hand-made | approved | approved |
| `ord_warden` | Steadfast | 2 | ground | hand-made | approved | approved |
| `ord_whisper` | Whisper | 2 | ground | hand-made | – | – |
| `chs_banshee` | Smother | 2 | air | hand-made | approved | approved |
| `chs_behemoth` | Hecatomb | 2 | air | hand-made | approved | approved |
| `chs_charon` | Charon | 2 | air | hand-made | approved | approved |
| `chs_condor` | Carrion | 2 | air | hand-made | approved | approved |
| `chs_dragon` | Dragon | 2 | air | hand-made | approved | approved |
| `chs_leech` | Leech | 2 | air | hand-made | approved | approved |
| `chs_manticore` | Strix | 2 | air | hand-made | approved | approved |
| `chs_wraith` | Wraith | 2 | air | generic | approved | approved |
| `ord_archangel` | Firmament | 2 | air | hand-made | approved | approved |
| `ord_archon` | Archon | 2 | air | hand-made | approved | approved |
| `ord_ark` | Ark | 2 | air | hand-made | approved | approved |
| `ord_liche` | Liche | 2 | air | hand-made | approved | approved |
| `ord_phantom` | Eclipse | 2 | air | hand-made | approved | approved |
| `ord_tidewatch` | Tidewatch | 2 | air | hand-made | approved | approved |
| `ord_zenith` | Zenith | 2 | air | hand-made | approved | approved |
| `chs_corsair` | Cutthroat | 2 | naval | hand-made | approved | approved |
| `chs_kraken` | Charybdis | 2 | naval | hand-made | approved | approved |
| `chs_leviathan` | Leviathan | 2 | naval | hand-made | approved | approved |
| `chs_reaver` | Reaver | 2 | naval | hand-made | approved | approved |
| `chs_siren` | Siren | 2 | naval | hand-made | approved | approved |
| `ord_crusader` | Crusader | 2 | naval | hand-made | approved | approved |
| `ord_dominion` | Dominion | 2 | naval | hand-made | approved | approved |
| `ord_harbormaster` | Harbormaster | 2 | naval | hand-made | approved | approved |
| `ord_sanctuary` | Sanctuary | 2 | naval | hand-made | approved | approved |
| `chs_advaccumulator` | Great Accumulator | 2 | structure | hand-made | approved | approved |
| `chs_advairfield` | Advanced Aerodrome | 2 | structure | hand-made | approved | approved |
| `chs_advbotlab` | Advanced Bot Pit | 2 | structure | hand-made | approved | approved |
| `chs_advconverter` | Great Smelter | 2 | structure | hand-made | approved | approved |
| `chs_advdepot` | Great Hoard | 2 | structure | hand-made | approved | approved |
| `chs_advextractor` | Deep Excavator | 2 | structure | hand-made | approved | approved |
| `chs_advfusion` | Great Hellforge | 2 | structure | hand-made | approved | approved |
| `chs_advshipyard` | Advanced Drydock | 2 | structure | hand-made | approved | approved |
| `chs_advvehplant` | Advanced Foundry | 2 | structure | hand-made | approved | approved |
| `chs_allseer` | All-Seer | 2 | structure | hand-made | approved | approved |
| `chs_augur` | Haruspex | 2 | structure | hand-made | approved | approved |
| `chs_basilisk` | Flytrap | 2 | structure | hand-made | approved | approved |
| `chs_blackout` | Blackout | 2 | structure | hand-made | approved | approved |
| `chs_breaker` | Breaker | 2 | structure | hand-made | approved | approved |
| `chs_bulwark` | Bulwark | 2 | structure | hand-made | approved | approved |
| `chs_carapace` | Carapace | 2 | structure | hand-made | approved | approved |
| `chs_cataclysm` | Cataclysm | 2 | structure | hand-made | approved | approved |
| `chs_cerberus` | Ladon | 2 | structure | hand-made | approved | approved |
| `chs_deepear` | Deepear | 2 | structure | hand-made | approved | approved |
| `chs_fusion` | Hellforge | 2 | structure | hand-made | approved | approved |
| `chs_hailstorm` | Sleet | 2 | structure | hand-made | approved | approved |
| `chs_inferno` | Inferno | 2 | structure | hand-made | approved | approved |
| `chs_maw` | Maw | 2 | structure | hand-made | approved | approved |
| `chs_rookery` | Rookery | 2 | structure | hand-made | approved | approved |
| `chs_scourge` | Scourge | 2 | structure | generic | approved | approved |
| `chs_scylla` | Scylla | 2 | structure | hand-made | approved | approved |
| `chs_seekerspire` | Seeker Spire | 2 | structure | hand-made | approved | approved |
| `chs_wyvern` | Wyvern | 2 | structure | hand-made | approved | approved |
| `ord_advairfield` | Advanced Airfield | 2 | structure | hand-made | approved | approved |
| `ord_advbotlab` | Advanced Bot Lab | 2 | structure | hand-made | approved | approved |
| `ord_advcapacitor` | Grid Reservoir | 2 | structure | hand-made | approved | approved |
| `ord_advconverter` | Advanced Supply Converter | 2 | structure | hand-made | approved | approved |
| `ord_advdepot` | Supply Vault | 2 | structure | hand-made | approved | approved |
| `ord_advextractor` | Advanced Extractor | 2 | structure | hand-made | approved | approved |
| `ord_advfusion` | Advanced Fusion Reactor | 2 | structure | hand-made | approved | approved |
| `ord_advshipyard` | Advanced Shipyard | 2 | structure | hand-made | approved | approved |
| `ord_advvehplant` | Advanced Vehicle Plant | 2 | structure | hand-made | approved | approved |
| `ord_aegis` | Aegis | 2 | structure | hand-made | approved | approved |
| `ord_bastion` | Bastion | 2 | structure | hand-made | approved | approved |
| `ord_beacon` | Beacon | 2 | structure | hand-made | approved | approved |
| `ord_choir` | Choir | 2 | structure | hand-made | approved | approved |
| `ord_edict` | Edict | 2 | structure | hand-made | approved | approved |
| `ord_empyrean` | Empyrean | 2 | structure | hand-made | approved | approved |
| `ord_fusion` | Fusion Reactor | 2 | structure | hand-made | approved | approved |
| `ord_lumen` | Lumen | 2 | structure | hand-made | approved | approved |
| `ord_phalanx` | Phalanx | 2 | structure | hand-made | approved | approved |
| `ord_pharos` | Pharos | 2 | structure | hand-made | approved | approved |
| `ord_providence` | Providence | 2 | structure | hand-made | approved | approved |
| `ord_radiance` | Radiance | 2 | structure | hand-made | approved | approved |
| `ord_rampart` | Rampart | 2 | structure | hand-made | approved | approved |
| `ord_sanction` | Sanction | 2 | structure | generic | approved | approved |
| `ord_sanctum` | Sanctum | 2 | structure | hand-made | approved | approved |
| `ord_tribunal` | Tribunal | 2 | structure | hand-made | approved | approved |
| `ord_veilspire` | Veilspire | 2 | structure | hand-made | approved | approved |
| `ord_witness` | Witness | 2 | structure | hand-made | approved | approved |
| `chs_juggernaut` | Juggernaut | 3 | ground | hand-made | approved | approved |
| `chs_typhon` | Typhon | 3 | ground | hand-made | – | – |
| `ord_tempest` | Tempest | 3 | ground | hand-made | – | – |
| `ord_thunderer` | Thunderer | 3 | ground | hand-made | – | – |
| `ord_titan` | Titan | 3 | ground | hand-made | approved | approved |
| `chs_gantry` | Experimental Gantry | 3 | structure | hand-made | approved | approved |
| `chs_ragnarok` | Doomsday | 3 | structure | hand-made | approved | approved |
| `ord_citadel` | Stronghold | 3 | structure | hand-made | approved | approved |
| `ord_gantry` | Experimental Gantry | 3 | structure | hand-made | approved | approved |
| `ord_reckoning` | Reckoning | 3 | structure | hand-made | approved | approved |
<!-- status-table:end -->

## Summary (second review queue, 2026-10-23)

Done so far:
- Approvals flipped: beam shot, deposits, interceptors.
- Approved by the user 2026-10-23: all T1 structure redesigns and new T1 meshes (`t1v2_*`, rows R1–R11 and N1–N7) and their wrecks; manifest flipped. The v3 Commander mechs were already approved (`7fbd495`); they have no wreck yet.
- Unit codex portraits: 146, in `debug_out/portraits/` with `portraits.json`; not committed, renderer in `tools/portraits.py`.
- Honeycomb: fewer, smaller patches.
- Commander mechs, blockouts and meshes, status `review`.
- T1 structure redesigns at the S-104 sizes (item 2): every T1 structure that had a mesh is redesigned in the style you approved on the extractors (rows R1–R11), wrecks rebuilt, all back to `review`.
- Blockout-only T1 structures (item 2, second part): all done as new meshes with wrecks, status `review` (N1–N7: converters, tidal generators, sonar buoys, jammer towers, torpedo launchers, floating turrets, rearm pads). Every T1 def now has a mesh.
- Item 3 (T2 meshes), done so far: air workers and ASW helicopters, amphibious tanks, anti-nukes (fixed and mobile), missile batteries, all T2 aircraft, all T2 ships, each with its wreck (rows T1–T5), status `review`.
- Key art (lobby-D's contract, L-13), style guide [`../art/keyart.md`](../art/keyart.md): key art 1 "Commander's stand" approved by the user 2026-10-24: four parallax layers (2048 x 1152, 2 x 2 tiles), composites and parallax test in `assets/keyart/ka1/final/`, made by `assets/keyart/ka1.py`. Not uploaded (uploads wait for the user's approval). Key art 2 "Volley" (an Order SAM site on a headland under a Chaos air raid at dusk) approved and uploaded 2026-10-24 with the user's approval: 16 tiles as Decals, image IDs resolved in FTGG Art, listed in the manifest as `keyArt.volley` (approved). Key art 3 "Converging" (daylight, an anti-nuke interception over an Order SAM base) approved and uploaded 2026-10-24 with the user's approval, in the manifest as `keyArt.converging`.
- Shield energy v4 approved by the user 2026-10-24 (fx.md "Shield energy", M-34): a straight beam with packets travelling up, a smaller apex flare, streaks lying on the dome, energy waves rolling down every 0.7 s, an even honeycomb, hit patches spreading in a ring, and a raise/collapse sweeping from the apex. In the manifest as `shieldEnergy` (approved); reference module `assets/fx/shield/waves/ShieldPreview.luau`, reference `Workspace.ShieldEnergyReference` in FTGG Art. clients-B ports it into ShieldFx; `shieldColumn` / `shieldWave` stay until then.
- Point defence and vertical-launch SAMs (2026-10-24): `ord_aegis` / `chs_wyvern` redesigned to launch straight up (the user), `ord_sanctum` / `chs_basilisk` new for S-149 (static `launcher`, client-turned `radar`); meshes, wrecks and blockouts, status `review`. Still to do from sim-A's request: the mobile pair `ord_shepherd` / `chs_griffin`.
- Then: the T2 structures at the new sizes (advanced factories, fusion, T2 extractors, sensors and defenses), item 4 (wrecks for the BAR meshes that still have none), item 5 (status table).

### Needs my review

- **Commander size (M-32):** now about 2.7x a Lancer's height and 10 studs across the pauldrons, so they out-mass the tanks from the game camera (`cmd_mech_55_close.jpg`). Footprint 2 is in the sim (S-124: collision radius 7.2, hit height 12, buildRange 60).
- **Walker move class (from the sim):** the mechs still move as TRACKED (30° slopes). A walker class (e.g. 40° slopes, BAR-bot style) is a sim change that alters where Commanders can go on every map; the sim asks you to decide.
- **Commander weapon (from the sim):** the Commanders have no weapon in the sim, so the weapon pod and its `muzzle` are decorative. A BAR-style D-gun would be a new sim feature.
- **Chaos colors:** the Warlord's gunmetal body is dark from above; its amber glow, stacks and team plates carry it at distance.

## Summary (BAR queue, 2026-10-22)

Your queue: BAR-style Order + Chaos pairs, each with glow channels, a team test in four colors, 55° close and 220-stud shots (220 at the `bar_7` distance, cropped to its 955 × 568 framing), and the manifest with `lune run mesh_materials` in the same commit. Each pair has its own Ready to merge line. **New meshes go into the manifest as `review`, so the game keeps their blockouts until you approve them** (`APPROVED` in `assets/models/tools/manifest.py`).

Before the queue: Oracle, Watcher and the Order vehicle plant were marked approved. The team-color clashes are documented in fx.md (team 7 cyan on Order and team 6 orange on Chaos: the client switches those units' `running` / `power` glow to white; yellow on Chaos is borderline). B's `mesh_materials` arrived with main.

| # | Pair | Tris | Glow | Status | Shots (`debug_out/screens/`) |
|---|---|---|---|---|---|
| 1 | Radar towers: `ord_watchtower` (armored square tower, cyan corner strips, unlit array with glowing edge and grid on the turning `radar`) / `chs_eye` (open lattice mast, amber eye sensor and leg beacons, unlit panel with amber edge) | 1,004 / 920 | 5.6% / 6.6% | review | `t1_radar_55_close.jpg`, `t1_radar_55_220.jpg` |
| 2 | IR SAM sites: `ord_vigil` (heavy base, launcher with sensor head and two canister pods, ice-white seeker and cap ready lights on `weapon`) / `chs_thorn` (round skid, bare post, six staggered tubes with ready-light mouths on `weapon`) | 1,000 / 936 | 5.2% / 5.7% | review | `t1_sam_55_close.jpg`, `t1_sam_55_220.jpg` |
| 3 | Wind turbines: `ord_windmill` (tapered round tower, armored nacelle with cyan generator vents on `power`, three broad blades with team tips on the client-spun `rotor`) / `chs_windmill` (lattice mast, boxy nacelle with an orange generator band, one long crooked two-ended blade) | 908 / 684 | 5.2% / 5.0% | review | `t1_wind_55_close.jpg`, `t1_wind_55_220.jpg` |
| 4 | Storage: `ord_depot` (low sloped bunker, roof team plate, back loading hatches, a cyan fill gauge on the front slope and charge strips on `power`) / `chs_depot` (salvaged drums with team caps and orange charge bands and gauges on `power`, a horizontal tank behind) | 496 / 780 | 5.2% / 5.1% | review | `t1_depot_55_close.jpg`, `t1_depot_55_220.jpg` |
| 5 | Airfields (footprint 5): `ord_airfield` (concrete apron, runway with team dashes and cyan edge and approach lights, armored hangar with door-frame and door build lights on `power`, control tower with lit cab and radar panel, team pad) / `chs_airfield` (patched dark apron, runway with team stripe, open hangar on posts with post and roof build lights, fuel tanks with gauges, lattice mast with radar and beacon) | 1,624 / 1,472 | 2.5% / 2.3% | review | `t1_airfield_order_55_close.jpg`, `t1_airfield_chaos_55_close.jpg`, `t1_airfield_55_220.jpg` |
| 6 | Shipyards (footprint 5, water): `ord_shipyard` (heavy quay and armored hall with door-frame and door build lights on `power`, two armored piers with team plates, edge and tip lights, gantry crane with team band and build lamps on `power`) / `chs_shipyard` (corrugated shed with door build lights, salvage tanks with gauges, narrow piers on piles with team plates, lattice tower crane with a long jib and a lit trolley) | 1,088 / 1,276 | 3.4% / 2.2% | review | `t1_shipyard_order_55_close.jpg`, `t1_shipyard_chaos_55_close.jpg`, `t1_shipyard_55_220.jpg` |
| 7 | Shield generators: `ord_phalanx` (sloped fortress base with team plates, deck sensor ring, four pylons with power bands, three prongs round the glowing core column) / `chs_carapace` (skid with a glowing coil ring, tanks piped in, tripod cage round a glowing faceted orb). `core` is the def piece; its `beam` attachment sits exactly where ShieldFx expects it (8.3 / 7.6 studs up, checked in Studio) | 1,732 / 1,036 | 5.5% / 5.6% | review | `t2_shieldgen_55_close.jpg`, `t2_shieldgen_55_220.jpg` |
| 8 | `ord_warden` (long gun on a low fortress hull, with the blockout's deploy pieces: `spades` with hazard stripes, `shieldL` / `shieldR` wings, `jacks`, all on the same pivots so the M-19 pose works unchanged) / `chs_minotaur` (wide slab hull on wide tracks, forward-leaning `ram` with crusher blocks, flat low turret, short fat barrel) | 3,036 / 1,932 | 5.0% / 5.1% | review | `t2_warden_minotaur_55_close.jpg` (deployed Warden on the right), `t2_warden_deployed_close.jpg`, `t2_warden_minotaur_55_220.jpg` |
| 9 | Air workers: `ord_skywright` (armored utility helicopter, four-blade client-spun `rotor` with team tips, `nano` emitter on `power`) / `chs_vulture` (boxy pod, bubble nose, exposed engine, two long blades) | 856 / 702 | 5.4% / 6.0% | review | `t1_airworker_55_close.jpg`, `t1_airworker_55_220.jpg` (lifted 3 studs) |
| M | Missiles (your extra request): `ord_ir_sam` / `chs_ir_sam` (slim, dark IR seeker, canards; Chaos three tail fins), `ord_radar_sam` / `chs_radar_sam` (white radome, mid-body strakes), `ord_nuke` / `chs_nuke` (dark re-entry cone over a warhead bus, stage rings; Chaos two strap-on boosters). One frame for all (4.4 studs, forward −Z), scaled by the client like its own parts (×1 / ×2.3 / ×4.5). In the manifest under `fx.<weapon id>`; fx.md "Missiles" | 364–584 | 9.0–10.6% | review | `missiles_55_close.jpg` (at game scale), `missiles_55_220.jpg` |
| 10 | Attack helicopters: `ord_guardian` (narrow armored gunship, stepped tandem canopy, chin sensor on `weapon`, stub wings with two rocket pods on the `pylon`, ready-lit tube mouths) / `chs_wasp` (boxy pod, exposed engine, open stub rail with two heavy rocket pods) | 1,248 / 742 | 5.1% / 5.1% | review | `t1_gunship_55_close.jpg`, `t1_gunship_55_220.jpg` |
| 11 | Fighters: `ord_falcon` (heavy twin-engine, canted team tails, formation strips, two missiles with ice-white seekers on the `pylon`) / `chs_harpy` (light delta, bubble canopy, tall team fin, engine pods, four cheap missiles, strips along the leading edges) | 792 / 710 | 8.9% / 5.9% | review | `t1_fighter_55_close.jpg`, `t1_fighter_55_220.jpg` (lifted 3 studs) |
| 12 | Bombers: `ord_absolution` (long twin-engine strike bomber, broad wings, canted team tails, `bay` with ajar doors and an ice-white bay light on `weapon`, `pylon` hard points) / `chs_plague` (stretched Harpy delta, racks of small bombs on the `pylon`, amber bay light) | 672 / 638 | 7.8% / 6.1% | review | `t1_bomber_55_close.jpg`, `t1_bomber_55_220.jpg` (lifted 3 studs) |
| 13 | Naval workers: `ord_tidewright` (armored work boat, raked bow, squared bridge, cargo hatch with status lights, stern `nano` crane with emitter on `power`) / `chs_wrecker` (narrow salvage tug, squat bridge with amber slit, funnel with heat band, stern crane) | 620 / 528 | 6.0% / 5.4% | review | `t1_navalworker_55_close.jpg`, `t1_navalworker_55_220.jpg` (waterline at the baseplate) |
| 14 | Corvettes: `ord_sentry` (armored corvette, wedge-fronted forward gun `turret1`, small aft `turret2`, mast with a sensor array and cyan band) / `chs_barracuda` (narrow gunboat, round open gun mounts, braced mast with a sensor panel and beacon, funnel) | 804 / 660 | 6.3% / 5.4% | review | `t1_corvette_55_close.jpg`, `t1_corvette_55_220.jpg` |
| 15 | Submarines: `ord_silence` (long round hull, tall armored sail, cross planes, team rudder, cyan hull strips, bow and aft torpedo blocks with tube lights on `weapon`) / `chs_lamprey` (crude diesel sub, long low sail, strapped salvage tanks, amber eye) | 472 / 540 | 5.0% / 6.2% | review | `t1_sub_55_close.jpg`, `t1_sub_55_220.jpg` (lifted 1.2 studs to show the hull) |
| 16 | T2 constructors: `ord_architect` (tracked hull with skirts and a dozer blade, raised cab, `nano` twin booms with two emitters on `power`, team counterweight) / `chs_forgemaster` (slat-caged hull, open cab, off-centre `nano` with a lattice crane arm, hook and emitter plus a short second arm). Built on the new shared hulls (`tools/hulls.py`) | 1,776 / 1,548 | 5.0% / 5.1% | review | `t2_constructor_55_close.jpg`, `t2_constructor_55_220.jpg` |
| 17 | Main battle tanks: `ord_paladin` (long skirted hull, big wedge turret with a very long gun on the turret piece: evacuator, muzzle brake, ring and rail on `weapon`) / `chs_juggernaut` (wide slat-caged hull, boxy turret, twin gun arms `armL` / `armR` on shoulder joints with muzzle rings, amber eye slits) | 1,920 / 1,844 | 5.0% / 5.0% | review | `t2_mbt_55_close.jpg`, `t2_mbt_55_220.jpg` |
| 18 | MLRS: `ord_judgement` (skirted hull, turntable `turret`, closed armored `launcher` box of 3 x 2 cells with ready-lit caps, team box sides) / `chs_hydra` (slat-caged hull, turntable, `launcher` rack of 12 bare tubes with ready-lit mouths) | 1,636 / 2,100 | 4.9% / 5.1% | review | `t2_mlrs_55_close.jpg`, `t2_mlrs_55_220.jpg` |
| 19 | Mobile radar SAMs: `ord_seraph` (6 x 6 truck, search array on the `turret` mast with an unlit face and glowing edge and grid, `launcher` with three closed canisters, white radome caps and ready lights) / `chs_gorgon` (light truck, lattice-mast `turret` with a small edge-lit panel, open rail `launcher` with four bare SAMs) | 1,316 / 1,144 | 4.9% / 5.1% | review | `t2_radarsam_55_close.jpg`, `t2_radarsam_55_220.jpg` |
| 20 | Fire-control radars: `ord_arbiter` (6 x 6 with a shelter, big `dish` array tilted back 20°, unlit face with glowing edge and fine grid) / `chs_stalker` (light truck, lattice mast, smaller `dish` panel with amber edge and cell lines, counterweight) | 1,116 / 1,044 | 4.8% / 5.3% | review | `t2_firecontrol_55_close.jpg`, `t2_firecontrol_55_220.jpg` |
| 21 | Mobile jammers: `ord_veil` (8 x 8 armored truck, compact `array` block with a team band and four emitter fins glowing on `power`) / `chs_shroud` (light truck with a generator, tall guyed telescoping mast `array` with two rings of emitter rods, tips on `power`, and a beacon). With this pair every T2 ground unit has a BAR mesh | 1,296 / 1,168 | 7.0% / 6.5% | review | `t2_jammer_55_close.jpg`, `t2_jammer_55_220.jpg` |
| 22 | Chaos faction units: `chs_locust` (tiny high swarm tank, small turret, long thin autocannon) / `chs_cyclops` (tall siege mortar: one huge tube fixed at 75° on the casemate `turret`, the short pitching cradle as `barrel` (M-19), muzzle at the tube mouth, amber eye on a mast, recoil spade) | 1,264 / 1,788 | 5.9% / 5.1% | review | `locust_cyclops_55_close.jpg`, `locust_cyclops_55_220.jpg` |
| 23 | Order faction structures: `ord_barrier` (armored wall segment with sloped faces, cap beam, team stripe, cap running lights and lit end caps; segments line up at 8 studs) / `ord_citadel` (T3 fortress: stepped octagonal blast walls with team plates, big `turret` with a long `barrel`, IR SAM `launcher` on a corner pedestal, static `radar` mast) | 412 / 1,612 | 7.1% / 4.0% | review | `barrier_citadel_55_close.jpg`, `barrier_citadel_55_220.jpg` |
| 24 | Nuke silos (T3): `ord_reckoning` (stepped armored bunker, two split blast doors `hatch` / `hatch2` on the blockout pivots, hazard ring, warning lights on `power`) / `chs_ragnarok` (round silo tube with reactive blocks, round `hatch` with a hazard ring, launch gantry and crane, fuel tanks, warning ring on `power`) | 1,100 / 1,512 | 3.3% / 3.2% | review | `silo_55_close.jpg`, `silo_55_220.jpg` |
| B | Beam towers (clients-B's request 2 from you, sim request 43): **pending blockouts** `ord_lucent` / `chs_basilisk` with the proposed IDs and pieces (`base`, `turret`, `barrel`, `muzzle`, client-only `shellL` / `shellR`) and a `retracted` pose (turret sinks into the drum, emitter folds down, shells close) in `Blockouts/Pending/Registry.luau`, so B can wire the piece script now. Meshes follow once the sim defines them | – | – | blockout | `beamtower_blockout_close.jpg` (deployed and retracted, each faction) |
| B2 | S-96 T2 defenses, blockouts under the sim's IDs: beam towers `ord_radiance` / `chs_inferno` (were the pending `ord_lucent` / `chs_basilisk`; the def's new `shell` piece is the armored collar round the pit, the client-only lids `shellL` / `shellR` hinge on it; `retracted` pose unchanged) and flak towers `ord_lumen` (twin flak guns either side, 35° up) / `chs_hailstorm` (three guns behind a slab, 40° up). Meshes next | – | – | blockout | `s96_beam_blockouts_close.jpg`, `s96_flak_blockouts_close.jpg` |
| 25 | Beam towers (T2, S-96): `ord_radiance` (octagonal armored drum, chamfer charge rails and a charge band on `power`, armored `shell` collar with hinge rods, two armored lids with team stripes that face up when closed, tall column with a glowing core band, heavy head, long emitter with focusing rings, charge rails and lens on `weapon`) / `chs_inferno` (low gunmetal drum with reactive blocks, two big open-framed charge coils on `power`, fuel tank, crude welded collar and lids, ribbed column with a glowing collar, head with a big amber eye, short forked emitter with glowing coil rings). Retracted pose checked on the meshes (right column) | 2,692 / 3,088 | 5.6% / 6.3% | review | `beam_55_close.jpg`, `beam_55_close2.jpg`, `t2def_55_220.jpg` |
| 26 | Flak towers (T2, S-96): `ord_lumen` (sloped emplacement with a glowing `power` band on the pedestal, angular gun house with a cyan fire-control sensor and a small search radar, a twin flak gun either side laid up 35° with jackets, flash hiders and `weapon` ready rings) / `chs_hailstorm` (octagonal plated base with reactive blocks and ammo crates, round turret with a forward-leaning slab shield, three guns in a row at 40°, side ammo drum, amber spotter eye) | 1,336 / 1,440 | 5.8% / 5.6% | review | `flak_55_close.jpg`, `t2def_55_220.jpg` |
| W | Wrecks (queue item 5, M-24) for all 22 approved meshes: the same build with `FTGG_WRECK=1`, so they keep the same pieces and pivots. Small fittings knocked off or bent, plates bent, dents; paint darkened toward soot with burnt patches; glow faces dead and dark (no glow parts); team panels scorched grey (alpha 1). Listed as `wreck` in each manifest entry (rig.md 7, fx.md "Wrecks"); shown beside the live mesh in `WreckReview` in FTGG Art | 320–3,448 | 0% | review (the live meshes stay approved) | `wreck_55_close.jpg`, `wreck_55_all.jpg`, `wreck_55_vehplants.jpg`, `wreck_55_220.jpg` |
| A | Nanoframe anchors (M-25, rig.md 8, the user's request for B): `buildpad` + `nano1..N` on all 12 factories (6 meshes, 6 advanced blockouts; their blockouts too), `nano1` (+ `nano2`) at the emitter of all 14 constructors' `nano` piece (meshes and blockouts). Mesh anchors in `tools/anchors.py`, merged into rig.json without a re-upload | – | – | – | – |
| F | Your review fixes (2026-10-23): Eye skid team plates bigger (two, front and back); Chaos runway matte; Chaos shipyard counter-jib inside the footprint (import clamp now 38.8/2048); bigger deck team plates on Tidewright, Wrecker, Sentry, Barracuda (subs unchanged); slightly larger flank (fin) plates on the four helicopters; no nozzle glow on the six missiles (only the running stripe). Re-uploaded, approved status kept. Skywright / Vulture NOR and Guardian ALB failed with HTTP 502 and were re-uploaded (reuploadNote) | – | – | approved | `fix_55_close.jpg` |
| 27 | Commanders (seen in every match: the most detailed units): `ord_sovereign` (long heavy tracked hull with four-panel skirts, raised glacis with a prow ridge and two big team plates, headlight clusters, command tower with a cyan command ring under a wraparound glass band, armored brow, smoke dischargers, satcom radome, antenna crown with a command beacon and a team pennant, stowage, rear grilles; `nano`: heavy boom on a yoke with a ram and a big build emitter) / `chs_warlord` (high-riding hull on four big exposed road wheels with spiked hubs, mudguards with team plates, spiked ram, slab cabin with an angled front slab, glowing slit, reactive blocks and roof spikes, lattice mast with a big team banner and beacon, twin exhaust stacks, fuel drums; `nano`: crane arm with power coils, claw and emitter). Both with `nano1` anchors | 4,040 / 3,214 | 7.0% / 5.1% | review | `cmd_55_close.jpg`, `cmd_55_220.jpg` (a Lancer row for scale) |
| S | Size scale (M-26, accepted as S-104): the 41 structure blockouts whose footprint grew are scaled to it as placeholders (`Blockouts/Scale.luau`, uniform, min of the footprint ratio and 95% of the new footprint), anchors and the beam towers' retract drop with them. Each gets its redesigned mesh next | – | – | blockout | – |
| AN | Anti-nukes (the user's request, sim S-111 accepted the IDs and pieces): pending blockouts `ord_providence` (armored launch bunker, heavy `hatch` hinged at its back, readiness lights round the silo, tracking radar on a tower) / `chs_cerberus` (reinforced pad with blast deflectors, twin-tube `launcher` hinged at its rear, readiness lights at the tube mouths, lattice radar mast). T2, footprint 3; client-only `radar` (turns); poses `open` (hatch +100°) and `raised` (launcher +75°). Interceptor weapons `ord_interceptor` / `chs_interceptor` | – | – | blockout | `antinuke_blockout_55_close.jpg`, `antinuke_blockout_55_220.jpg` |
| AV | Mobile anti-nukes (the user's request): pending blockouts `ord_custodian` (armored 8x8 carrier, one large canister `launcher` hinged at its rear, readiness ring at the mouth, compact radar on the cab) / `chs_chimera` (lighter 6x6 truck, exposed rail `launcher` with one slim interceptor, readiness light at its nose, lattice radar mast). T2 ground, footprint 1 (~1.3x a T1 truck); client-only `radar` (turns); pose `raised` (+80° / +75°) | – | – | blockout | `antinuke_vehicle_blockout_55_close.jpg`, `antinuke_vehicle_blockout_55_220.jpg` |
| M27 | Animation audit (the user's request for the client), part 1: blockouts. A part with `anim = { motion, axis, range? }` is now an animated jointed piece (`Blockout.pieceSet`, `Blockout.anims`, validated): 222 parts across the blockouts (wheels, track sets, rotors, tail rotors, radars / dishes / arrays, drills, jibs, sonars, cores, hatches, jammer emitters; Smog / Blackout rods ride on their spinning spine). Four white effect textures uploaded (radar pulse, sonar ping, jammer static, heat shimmer). Spec: rig.md 9, fx.md "Effect textures". Part 2 (the meshes split with `lib.Piece.sub`, manifest `anim` / `visualPieces` / `textures`) follows with the re-uploads | – | – | – | – |
| M27b | Animation audit part 2: meshes. 44 BAR meshes rebaked with their moving parts split into their own pieces (`lib.Piece.sub`; no geometry changes): track sets `trackL` / `trackR` (scroll X) on every tracked hull, wheels `wheelL{i}` / `wheelR{i}` (spin X) on every wheeled one, `tailRotor` on all 8 helicopters, `radar` on the airfields and the Sentry, `trolley` on the Order shipyard and the Chaos vehicle plant, `jib` on the Chaos shipyard. Re-uploaded, rigged in FTGG Art, recorded; the manifest lists each unit's `visualPieces` and `anim` ({motion, axis, range?}, rig.md 9). The 13 wrecks of split units rebuilt with the same pieces | – | – | – | – |
| BFX | Beam shot effect (M-29, the user's request): Radiance / Inferno shot, BAR Pulsar style, original. Eight white textures (core, glow, two crackling filament strips on different waves, a 2 × 2 charge flipbook, impact flare, grey scorch, ember rim), the timing sheet and recommended values per faction in fx.md "Beam shot", `Meshes.beam` in the manifest (`Mesh.validateBeam`). Reference build in FTGG Art (`Workspace.BeamFxReference`, module `BeamShot`, also `assets/fx/beam/BeamShot.luau`): each tower fires at a dummy target 100 studs away | – | – | review | `beamfx_order_mid.jpg`, `beamfx_order_late.jpg`, `beamfx_chaos_mid.jpg`, `beamfx_chaos_late.jpg`, `beamfx_order_charge.jpg`, `beamfx_scorch.jpg`, `beamfx_55_220.jpg`, `beamfx_order_frames.jpg` (t 0.04 / 0.09 / 0.22 / 0.34) |
| HEX | Shield honeycomb shell (M-30, clients-B's request; the user: little patches): scattered hex patches over the dome, opaque on the top and gone by 72° from it, in 11 bands (`Meshes.shieldShell`, `Mesh.validateShieldShell`), tinted by the client and scaled by charge; fx.md "Honeycomb shell". Reference in FTGG Art: `Workspace.ShieldHoneycomb` | 11,880 | 0% | review | `honeycomb_55_full.jpg`, `honeycomb_55_charge35.jpg`, `honeycomb_25_side.jpg` |
| MECH3 | Commander mechs v3 (M-33, the user's review of v2: the size is right, the look too blocky). Same size, fp 2, rig and pivots. Thick armored legs (tapered thigh plates, big rounded knee guards, team shin plates, wide feet with toe and heel plates) and arms (forearm armor, elbow guards); round shoulder housings and joint drums; tapered, angled, beveled plates over a dark under-frame; pistons behind knees and elbows; small helmets set into the shoulders (Order: narrow cyan visor; Chaos: low forward-thrust head, amber eye slits); team color on the arched pauldron shells, chest plates, shin plates and backpack / hump; hazard striping on joints; bigger weapons (Order long twin barrels, Chaos long gun with a muzzle brake); a clear emitter arm. v2 kept in `assets/models/<id>/v2/`. The Warlord's first maps failed in Studio (the HTTP 502 case); re-uploaded | 10,736 / 10,208 | 5.0% / 4.9% | review | `cmd_mech_front.jpg`, `cmd_mech_55_close.jpg` (with a Lancer and a Paladin), `cmd_mech_55_220.jpg`, `cmd_mech_side_stride.jpg`, `cmd_mech_team.jpg` (4 colors) |
| MECH2 | Heroic Commander mechs (M-32, the user's review of v1: too small and blocky). Original designs, BAR-level finish (bevels, cylinder joints and pistons, layered plates over a dark under-frame, vents, grilles, rivets, cables, lights). `ord_sovereign` 10.4 studs tall with its antennas, 10.0 wide: upright and noble, V chest with the cyan command core, big sloped pauldrons with team plates, sensor head on a neck under a brow, reactor backpack with turbine ends, emitter forearm, twin-barrel pod. `chs_warlord` 11.6 tall (stacks and banner), 10.4 wide: hunched and aggressive, reactive-block chest, head thrust forward with amber eye slits, slab pauldrons, exhaust stacks, banner, claw crane arm, heavy gun with a muzzle brake, splayed clawed feet; both with long bent legs (45%). fp 2 (the sim's S-124). v1 kept (`Blockouts/Review/*_mech_v1.luau`, `assets/models/<id>/v1/`) | 6,416 / 5,848 | 5.3% / 5.5% | review | `cmd_mech_55_close.jpg` (with a Lancer and a Paladin), `cmd_mech_55_220.jpg`, `cmd_mech_front.jpg`, `cmd_mech_side_stride.jpg` (the `stride` pose) |
| MECH | Commander mechs (M-31, the user's request): walker blockouts and BAR meshes, original designs. `ord_sovereign`: tall upright mech, clean sloped plates, broad chest with a cyan command core and team plates, big shoulder armor with team plates, sensor head under an armored brow, emitter forearm (`nano`, power), twin-barrel weapon pod (`muzzle`, weapon). `chs_warlord`: hunched heavier walker, slab and reactive armor, exposed pistons, amber eye slits, glowing exhaust stacks, a claw crane arm with the emitter, a heavy gun, a banner mast with the team banner. Walker rig (rig.md 10, motion `swing`), fp 1 and TRACKED (the sim's answer). The tracked designs are kept: `Blockouts/Review/*_tracked.luau`, `assets/models/<id>/tracked/` | 3,504 / 3,272 | 2.8% / 2.9% | review | `cmd_mech_55_close.jpg` (with a Lancer and a Paladin), `cmd_mech_55_220.jpg`, `cmd_mech_side_stride.jpg` (the `stride` pose), `cmd_mech_team.jpg`, `cmd_mech_scale_compare.jpg` (1.4x, back row) |
| R1 | Structure redesigns at the size scale (S-104, item 2), pair 1: extractors at footprint 2 (16 x 16), redesigned, not rescaled. `ord_extractor`: thick chamfered slab, armored octagonal housing with a large team deck, a turning drill crown (`drill`, turn Y) with power bands, two ore hoppers on inclined conveyors (team panels), pump drums with pipes and valves, corner anchors with lights, hazard striping. `chs_extractor`: slab with a raised grated platform and team plates, an open four-leg lattice derrick with X-bracing over a turning drill shaft (`drill`) with glowing bands, an engine house with twin hot stacks and a team roof, a strapped ore tank with a skip conveyor. Wrecks rebuilt. Back to review (their fp-1 approvals no longer apply) | 2,530 / 2,280 | 3.0% / 2.6% | review | `t1v2_extractor_55_close.jpg` (with a Lancer), `t1v2_extractor_55_220.jpg` |
| R2 | Pair 2, generators at fp 2, the bulkiest T1 economy buildings. `ord_generator`: thick chamfered slab, armored reactor housing with sloped upper walls and a large team roof, a stepped dome over the glowing core (`core`, pulse), two tall cooling stacks with glowing rims, finned transformer banks cabled to the housing. `chs_generator`: skid slab, three upright reactor tanks of different heights with hot bands and team caps, the big tank's glowing core band (`core`, pulse), pipe bridges, a tall exhaust stack with a hot rim, an open scaffold with a catwalk, a generator shed with a team roof. Wrecks rebuilt. Back to review | 2,502 / 2,544 | 4.0% / 6.9% | review | `t1v2_generator_55_close.jpg`, `t1v2_eco_55_220.jpg` |
| R3 | Pair 3, solar at fp 2, low collector fields. `ord_solar`: four big framed panels tilted 25° on armored pedestals, dark glass cell grids, team bands on the upper frames, a glowing strip on each low edge, a central inverter box, cable trays. `chs_solar`: five salvaged panels of different sizes at uneven tilts on rails, patched cells, team plates on the skid and a team band on the biggest panel, a junction box with a battery stack and an orange light, loose cables. Wrecks rebuilt. Back to review | 1,604 / 1,600 | 2.7% / 2.0% | review | `t1v2_solar_55_close.jpg` |
| R4 | Pair 4, wind turbines at fp 2, thin masts to about 18 studs. `ord_windmill`: armored octagonal footing with an inverter house, tall tapered ribbed tower with a ladder, armored nacelle with a team band and cyan generator vents, `rotor` with a spinner and three broad blades with team tips. `chs_windmill`: open lattice mast on four splayed legs with guy cables, a generator shed with a team roof and a hot vent, a boxy nacelle with an orange band, `rotor` with one long crooked two-ended salvage blade bar with team tips. New `rotor` hubs (0, 16.2, -2.2) / (0, 15.4, -1.8). Wrecks rebuilt. Back to review | 1,618 / 1,396 | 2.6% / 2.6% | review | `t1v2_windmill_55_close.jpg` |
| R5 | Pair 5, storage at fp 2. `ord_depot` (about 5 tall): a long armored vault with sloped sides and a large team roof, two loading hatches, a dock at the back, a fill gauge on the front slope (power), two capacitor cylinders along the flanks with team bands and glowing charge rings. `chs_depot` (about 6 tall): a salvage tank farm, two big upright drums with team caps and level gauges (power), a horizontal tank on cradles with a team band, a pipe bridge with valves, a loading shack with a team roof. Wrecks rebuilt. Back to review | 1,678 / 2,304 | 5.9% / 5.4% | review | `t1v2_depot_55_close.jpg` |
| R6 | Pair 6, vehicle plants at fp 4 (32 x 32, 11–12 tall, the tallest T1 buildings). `ord_vehplant`: open assembly bay with the build pad (team ring, hazard border; `buildpad` (0, 0.72, -3)), front exit ramp under a lit door frame, two armored side halls with large team roofs, a back assembly hall with a parts conveyor and stacks, a bridge `gantry` crane (slide Z, 7 studs) with a hook block, four wall emitter arms (`nano1..4`). `chs_vehplant`: patched slab and dark yard, open bay framed by four lattice columns and girders, a `trolley` (slide Z, 6) with a hook emitter (`nano3`), build pad with team stripes (`buildpad` (3, 0.72, -2)), corrugated workshop shed with a team roof and a forge vent, fuel tanks, two crane emitter arms (`nano1`, `nano2`). Wrecks rebuilt. Back to review | 3,152 / 3,052 | 2.1% / 2.5% | review | `t1v2_vehplant_55_close.jpg` |
| R7 | Pair 7, gun turrets at fp 2. `ord_bulwark` (about 6 tall): chamfered slab, armored casemate with sloped walls, team side plates and buttresses, ammo bunkers with a feed rail; heavy `turret` (pivot (0, 3.2, 0)) with a sloped front, large team roof, ammo drum, sensor head, long gun with evacuator and muzzle brake (`muzzle` (0, 4.5, -10.6)). `chs_spike` (about 5 tall): slab, round emplacement ringed with reactive blocks, team plates, ammo crates with a feed chute; squat `turret` (pivot (0, 2.6, 0)) with a slab gun shield, team roof, ammo box and belt, sensor mast, twin barrels (`muzzle` (0, 3.6, -8.6)). Wrecks rebuilt. Back to review | 1,902 / 2,364 | 2.7% / 5.5% | review | `t1v2_turret_55_close.jpg` |
| R8 | Pair 8, radar towers, kept at fp 1 (8 x 8), about 12 tall, redesigned in the new style. `ord_watchtower`: chamfered slab, armored plinth with team plates, a tapered square tower with lit corner ribs, sloped buttresses, an armored collar with a running band, large team plates on the upper faces, a back ladder, an equipment deck; `radar` (turn) a wide 15°-tilted panel (unlit face, glowing edge and grid), a framed back with a large team plate and a finned box. `chs_eye`: patched skid with big team plates and hazard, a generator box with a team roof and a hot vent, a lattice mast on four thick splayed legs with X bracing and guy cables, amber beacons, a grated platform, the amber eye; `radar` panel with an amber edge, a welded patch, a big team back and a counterweight. Wrecks rebuilt. Back to review | 2,224 / 1,940 | 6.4% / 4.1% | review | `t1v2_radar_55_close.jpg` |
| R9 | Pair 9, IR SAM sites, kept at fp 1, about 5 tall. `ord_vigil`: chamfered slab with hazard, an armored octagonal block with team side plates, a reload hatch and a rack of spare canisters, a glowing bearing ring; `launcher` (pivot (0, 2.7, 0)): an armored sensor head with an ice-white seeker and a mast, two heavy canister pods on yoke arms with large team tops, 2 x 3 caps with ready lights each (`muzzle` (-1.95, 3.97, -2.25)). `chs_thorn`: patched skid with team plates and hazard, a ring of reactive blocks with amber lights, a battery crate cabled to a gusseted post with a hot band; `launcher` (pivot (0, 2.8, 0)): sensor box with an amber seeker and a team roof, an open welded frame with six staggered tubes, ready lights at the mouths (`muzzle` (-2.4, 3.2, -1.95)), a cable mast and a spare canister. Wrecks rebuilt. Back to review | 2,734 / 2,080 | 4.1% / 3.4% | review | `t1v2_sam_55_close.jpg` |
| R10 | Pair 10, airfields, kept at fp 5 (40 x 40), the hangars 10–11 tall, the tower and mast 12–13. `ord_airfield`: chamfered slab, runway with team dashes and hazard thresholds, a big armored arched hangar with plate ribs, a team roof in three bays, armored pilasters, a lit door frame and build lights facing -Z, back vents; the build pad in front (team ring, hazard; `buildpad` (-10.4, 0.72, -8)), two emitter booms and a lintel head (`nano1..3`), a taxi line; a control tower with team plates, a glass cab and `radar` (turn); fuel tanks with team bands. `chs_airfield`: patched dark slab, matte runway, an open hangar (a sloped corrugated roof on braced lattice posts, a large team plate, a corrugated back wall), the pad under it (team stripes, hazard; `buildpad` (-10.8, 0.72, 6.8)) with a hoist girder and three hanging emitters (`nano1..3`), a lattice mast with `radar` (turn), salvage drums with team caps. New anchors. Wrecks rebuilt. Back to review | 4,800 / 4,596 | 1.7% / 1.4% | review | `t1v2_airfield_55_close.jpg`, `t1v2_factory_55_220.jpg` |
| R11 | Pair 11, shipyards, kept at fp 5, on water (y = 0). `ord_shipyard`: a chamfered armored quay with a construction hall (sloped roof walls, a large team roof, front buttresses, a big door with a lit frame and build lights, glowing vents), two armored piers with chamfered tips, large team decks, hazard slip edges, crane rails, rubber fenders, bollards; a heavy portal gantry on bogies with tapered legs, knee braces, a team band, a hazard edge, four lamps and the `trolley` (slide X) with its lamp. `nano5` now rides the `trolley`. `chs_shipyard`: patched quay, a corrugated shed with a large team roof and door build lights, a hot stack, salvage tanks with team caps; two narrow piers on piles with team plates, hazard edges, tyre fenders, an emitter arm over the slip (`nano2`, new); a braced lattice tower crane with an operator cab and the `jib` (turn) with a team band and hook trolley (`nano1` now rides the `jib`). Wrecks rebuilt. Back to review | 4,516 / 5,792 | 3.6% / 2.3% | review | `t1v2_shipyard_55_close.jpg`, `t1v2_factory_55_220.jpg` |
| N1 | Blockout-only T1 structures (item 2, second part), pair 1: converters, new meshes at fp 2. `ord_converter` (Supply Converter, about 7 tall): chamfered slab with hazard, an armored housing with sloped walls and a large team deck, a column of stacked armored rings with glowing coil bands under a heavy cap (`coil`, pulse), two intake drums on the flanks with team bands, pipes and valves, an output hopper with a team panel and a lit chute. `chs_converter` (Smelter, about 8 with its stack): patched skid with team plates and hazard, a squat riveted furnace with a glowing mouth and a team roof, a strapped crucible with a hot band and a team cap (`crucible`, pulse), a chimney with a hot rim, an ore skip on an inclined rail, pipework with a valve, slag ingots. Wrecks built. New, review | 3,006 / 1,544 | 5.8% / 4.3% | review | `t1v2_converter_55_close.jpg`, `t1v2_factory_55_220.jpg` |
| N2 | Tidal generators, new meshes at fp 2, on water (y = 0). `ord_tidal` (Tidal Generator): two armored pontoon hulls with chamfered bows, team plates and running strips, fore and aft decks with hazard edges, a ribbed open duct with the turbine `rotor` (spin Z) half out of the water, a walkway and shaft housing to an armored generator house on the aft deck (glowing band, team roof, vent). `chs_tidal` (Tide Mill): two strapped drum floats, a deck of patched plates with team plates and hazard, an exposed paddle wheel (`rotor`, spin X) on bearing blocks, a generator shed with a team roof, a hot band and a stack. Wrecks built. New, review | 1,828 / 2,064 | 1.9% / 1.1% | review | `t1v2_naval_55_close.jpg`, `t1v2_naval2_55_close.jpg` |
| N3 | Sonar buoys, new meshes at fp 1, on water. `ord_ear`: armored octagonal float with team plates, running strips and hazard, a squat armored sonar housing with the turning glowing `ring` (turn Y) and hydrophone blocks, a domed cap, a sonar dome below, a whip mast with a lamp. `chs_listener`: two strapped drum floats under an open deck with team plates and hazard, a sonar `drum` (turn Y) hung on a frame with a glowing band, a stub lattice post with an amber lamp, a battery crate. Wrecks built. New, review | 1,426 / 1,212 | 6.9% / 3.5% | review | `t1v2_naval_55_close.jpg`, `t1v2_naval2_55_close.jpg` |
| N4 | Jammer towers, new meshes at fp 1, about 6 tall. `ord_curtain`: chamfered slab with hazard, an armored block with sloped walls and team plates, a tapered post with two glowing fins on brackets, the spinning emitter `tip` (spin Y) with three dishes and a glowing crown. `chs_smog`: patched skid with team plates and hazard, a generator box with a hot vent, a lattice mast with amber beacons, the spinning `spine` (spin Y) with six glowing emitter rods on struts and a lamp. Wrecks built. New, review | 1,182 / 1,004 | 6.9% / 4.1% | review | `t1v2_sensor_55_close.jpg` |
| N5 | Torpedo launchers, new meshes at fp 1, on water; pieces `base`, `turret` (static turntable), `launcher` (turned by the def). `ord_undertow`: armored octagonal float with team plates and hazard, a turntable with a running ring, an armored launcher house with a sloped team roof over three tubes with ready lights (`muzzle` (0, 1.95, -3.25), pivot (0, 1.4, -0.4)), a sensor head; a sonar dome the client lowers (`sonar`, lower 8). `chs_fang`: pontoon raft of two drum floats, a plated deck with team plates and hazard, two bare tubes on a welded cradle with ready lights (`muzzle` (0, 2.05, -2.8), pivot (0, 1.5, -0.3)), a spare torpedo, a crane stub; a hydrophone the client lowers (`sonar`). Wrecks built. New, review | 1,486 / 1,420 | 7.9% / 0.7% | review | `t1v2_naval_55_close.jpg`, `t1v2_naval2_55_close.jpg` |
| N6 | Floating turrets, new meshes at fp 1, on water. `ord_moat`: an armored floating casemate with sloped walls, team flank plates, running strips, a hazard edge, a deck light and bollards; `turret` (pivot (0, 1.3, 0)): a twin gun house with a sloped front, a large team roof, a sensor head, two barrels with collars and muzzle rings (`muzzle` (0, 2.0, -6.2)). `chs_riptide`: a round float with a rubber buoyancy ring, a deck ringed with reactive blocks and amber lights, team plates, hazard, an ammo crate; `turret` (pivot (0, 0.9, 0)): an open single-gun mount with a slab shield and team plate, an ammo box and belt, a lamp mast, one barrel (`muzzle` (0, 1.75, -5.6)). Wrecks built. New, review | 1,072 / 1,576 | 1.5% / 1.1% | review | `t1v2_naval_55_close.jpg`, `t1v2_naval2_55_close.jpg` |
| N7 | Rearm pads, new meshes at fp 3 (24 x 24), low. `ord_airpad` (Aerie): chamfered slab, a raised octagonal landing pad with a team ring, marks, a hazard border and edge lights, an armored rearm pedestal with a jointed boom and a lit head over the pad, a fuel block with a team top, gauges and a hose, a control booth with a lit window. `chs_airpad` (Roost): patched dark slab with grated sections, a matte landing circle in a team ring with amber lights, hazard, two strapped fuel tanks with team caps and a hose, ammo crates and a crane stub, a lattice light mast. Wrecks built. New, review | 1,484 / 1,948 | 0.7% / 0.6% | review | `t1v2_airpad_55_close.jpg` |
| T1 | T2 meshes (item 3), pair 1–2: the advanced air workers and ASW helicopters, baked earlier and held out until shot, now in the manifest. `ord_zenith` (heavy-lift cabin, twin roof nacelles, five-blade `rotor`, ducted `tailRotor`, belly `nano` turret with fore and aft arms) / `chs_condor` (open frame on splayed legs, roof engines, four-blade rotor, lattice boom); `ord_tidewatch` / `chs_leech` (ASW helicopters with a dipping `sonar`). About 1.35x their T1 counterparts (size-scale.md). No wrecks yet (item 4). New, review | 1,692 / 1,294; 1,384 / 1,278 | 6.4% / 7.2%; 5.1% / 5.7% | review | `t2_airworker_asw_55_close.jpg` (with the Skywright, Vulture and a Lancer) |
| T2 | T2 meshes (item 3): amphibious tanks, new meshes at the T2 light size. `ord_tideguard`: a sealed boat-bowed hull with a splash board and hazard, sponsons over low tracks (`trackL` / `trackR`), a large team bow plate, two waterjets with glowing intakes, a snorkel; a compact sloped `turret` with a team roof and a short gun. `chs_mire`: a light open hull between strapped pontoon floats with team plates, three exposed wheels a side (`wheelL1..3` / `wheelR1..3`), a caged stern propeller, a tall snorkel, a cable reel; a small round `turret`. Wrecks built. New, review | 1,956 / 2,112 | 2.6% / 1.7% | review | `t2_batch2_55_close.jpg`, `t2_struct_55_close.jpg` |
| T3 | Anti-nukes and missile batteries (the sim's S-106, S-111), new meshes. `ord_providence` (fp 3): armored launch bunker with team plates, a silo collar with hazard and readiness lights (weapon), the heavy `hatch` (the def's piece) with a team plate, blast vents, a tracking `radar` on a tower. `chs_cerberus` (fp 3): patched pad with team plates, a blast deflector, concrete blocks, the hinged `launcher` (rail frame, two interceptor tubes with readiness rings), a lattice mast with a `radar` array, a fuel tank. `ord_custodian` (8x8 carrier, `wheelL1..4` / `wheelR1..4`): sloped armored cab, team skirts, the hinged `launcher` canister with a team band and readiness ring, a cab-roof `radar`. `chs_chimera` (6x6 truck): open-backed cab, flatbed with team plates, the hinged rail `launcher` with a slim interceptor and a glowing nose, a lattice mast with a `radar`. `ord_sanction` (fp 3): armored emplacement with team plates and buttresses, ammo bunkers, a glowing turret ring; the `launcher` house with a large team roof, two big missile cells, a fire-control head. `chs_scourge` (fp 3): patched pad, reactive-block ring with amber lights, crates, a lattice fire-control mast; the `launcher` frame with a slab shield and three exposed missiles with glowing nose rings. The four Pending blockouts moved into the main registry (their defs exist now). Wrecks built. New, review | 1,614 / 2,636; 1,836 / 1,310; 2,198 / 2,870 | 1.0% / 1.1%; 2.8% / 3.2%; 3.9% / 4.7% | review | `t2_batch2_55_close.jpg`, `t2_struct_55_close.jpg` |
| T4 | T2 aircraft, new meshes at about 1.35x their T1 counterparts (span 12–14). `ord_archon` (stealth-faceted fighter, chin sensor `turret`, `pylon` with four radar missiles) / `chs_manticore` (big delta, chin `turret`, `pylon` with four heavy missiles, flare boxes); `ord_phantom` (flying wing, sawtooth trailing edge, `bay` and `pylon`) / `chs_behemoth` (biggest delta, armored belly, four engine pods with chaff boxes, `bay`, `pylon`); `ord_archangel` (AWACS with the plank radar `dish` on struts, a panel glowing on both faces) / `chs_banshee` (jammer jet with the glowing `dish` box, wing-tip emitter pods); `chs_wraith` (decoy drone: a small flying wing with glowing emitter strips, one piece). Wrecks built. New, review | 1,004 / 988; 584 / 1,102; 972 / 744; 360 | 5.0% / 4.4%; 4.3% / 5.1%; 5.9% / 5.4%; 7.6% | review | `t2_air_55_close.jpg` |
| T5 | T2 ships, new meshes. Small (~14 long): `ord_harbormaster` / `chs_reaver` (the T1 workers' hulls at 1.3x with deck cranes and a two-arm `nano` turret; new anchors `nano1`, `nano2`), `chs_siren` (naval jammer: two turning emitter masts `turret1` / `turret2` with glowing rods). Capital (~29 long, fp 3): `ord_crusader` / `chs_corsair` (destroyers: gun `turret1`, ASW `turret2`, SAM / VLS `launcher`, a turning `radar`, a helideck or a lattice mast), `ord_dominion` / `chs_kraken` (cruisers: heavy triple `turret1`, flak `turret2`, a turning `radar`), `ord_sanctuary` / `chs_leviathan` (carriers: flight deck with three team rearm pads, island and turning `radar`, flak `turret1` / `turret2`). Wrecks built. New, review | 1,092 / 1,004; 1,276; 1,900 / 1,796; 2,016 / 1,992; 2,252 / 2,324 | 5.4% / 4.0%; 5.6%; 3.5% / 3.5%; 2.9% / 3.5%; 0.7% / 2.4% | review | `t2_naval_55_close.jpg` |
| DEP | Supply deposits (M-28, the user's request): `fx.deposit` with 3 variants (536–552 tris), BAR metal-spot style: ragged scraped patch tinted to the terrain through the alpha mask, darker soil core, ore outcrops with a metallic sheen (no glow), broken berm, loose stones; one cell wide, ≤ 0.7 tall, hidden under an extractor. Rebaked lighter (grey-brown neutral, less wash and crease) after B's note that bare deposit cells read nearly black at night | 536–552 | 0% | review | `deposit_55_close.jpg`, `deposit_55_220.jpg`, `deposit_grass_extractors.jpg`, `deposit_sand_close.jpg`, `deposit_rock_close.jpg` |
| INT | Interceptor missiles (anti-nuke, S-111): `ord_interceptor` / `chs_interceptor` (needle nose, booster, bright `weapon` throat at strength 3.0), aliased for `ord_mobile_interceptor` / `chs_mobile_interceptor` | 418 / 406 | 8.6% | review | – |

**Needs your review (queue):**
- **Studio cache:** in "FTGG Art" five of the fresh color maps (Chaos solar, both windmills, Chaos depot, Order vehicle plant) reported "Failure" and drew grey although the images load (checked with `AssetService:CreateEditableImageAsync`). For the shots I fed those maps to the clones through `ColorMapContent`; the rigged models in `ModelReview` are unchanged. A Studio restart should clear it; nothing to re-upload. Same again for the later batches; what works: prime each image with `CreateEditableImageAsync` once, then re-clone the models.
- **Chaos windmill:** one long crooked two-ended blade bar (salvage look) instead of three blades. It reads as a thin line from the game camera. Keep it, or give it three short blades?
- **Eye:** at 220 studs it reads as a dark lattice with amber points; its team color sits only on the skid stripe and the panel's back, so it's weak from the game camera. Bigger skid plates if you want more team color.
- **Radar panels:** both panels' glowing edges follow the approved Oracle rule (unlit face, edge and grid). The Eye's amber edge is thicker relative to its panel.
- Fresh uploads: the Thorn first drew white (Studio failed its maps with HTTP 502 and won't retry them). Re-uploading the four maps fixed it with no restart (pipeline.md). Its `roblox_assets.json` records the re-uploaded IDs.
- Airfields: glow 2.3–2.5%, the large-building range (style guide, like the vehicle plants), not 5–10%. On a 38-stud apron, 5% would be a lit carpet. The Chaos runway is bare steel and catches the sun as bright metal at some angles; a matte surface is a one-line change if you prefer it.
- Chaos shipyard: the tower crane's counter-jib sticks out about 4 studs past the 40-stud footprint on the left (as in its blockout). It could overlap a neighbor; I can shorten the counter-jib.
- Queue order: clients-B relayed a new request from you (T2 defence meshes, starting with a BAR-Pulsar-style beam tower per faction with a retract pose). I queued it after the T1 aircraft and before T1 naval. It needs the sim defs (request 43) before its meshes can go in the manifest; I proposed the pieces to B. Tell me if it should go first.
- Helicopters from the game camera: the rotor disc covers the roof, so team color shows on the fin, the blade tips and the flanks. Bigger flank plates if they should read more.
- Missiles: their glow share runs 9–10.6% (the Order nuke 10.6%): on a 4-stud body, one stripe and the nozzle are a big share. They read as small lit bands in flight. The client already lights the exhaust, so the nozzle glow could go if it doubles up.
- Chaos aircraft: the dark gunmetal reads low against the grey baseplate from above; over game terrain they read better (the ground is lighter and greener). The amber strips carry them at distance.
- Ships: team color sits on the foredeck or afterdeck plate and the bridge roof; at 220 studs the ships read mostly by their faction glow. Larger deck plates if they should read more.
- Submarines: team color sits on the rudder and the sail band. They are always submerged and mostly seen as contacts, so I kept it small.
- Citadel: glow 4.0%, between the unit range and the large-building range, about right for a 24-stud fortress; it reads as a fortress, not a silo, from above.
- Beam tower IDs `ord_lucent` / `chs_basilisk` are my proposal (Order virtue name, Chaos gaze-beast) for the sim's request 43; the sim picks the final IDs and I will rename the blockouts to match.
- Beam towers: the lids are client-only pieces (`shellL` / `shellR`, in the manifest as visual pieces); the retracted pose hides the turret completely. Should a retracted tower still show a faint glow (charge band on, lids shut), or go fully dark? Now the base `power` stays on unless the client dims it.
- Wrecks: on the big flat roofs (vehicle plants, Bulwark) the soot reads as cloudy patches rather than burn marks. Keep it, or switch the large structures to finer, edge-focused scorching? Also: the shield emitter (fx) has no wreck; it disappears with its shield generator.
- Approved by the user 2026-10-23: all 26 BAR pairs, the missiles and the 22 wrecks (manifest flipped). Fixes asked: Eye skid team plates bigger, Chaos runway matte, Chaos shipyard counter-jib inside the footprint, ship deck team plates bigger, helicopter flank plates slightly bigger, missile nozzle glow removed, wrecks lighter (grey-brown soot) with edge-focused scorching on big roofs.
- Size scale (M-26): proposal in `docs/art/size-scale.md`, sent to the sim stream; rescaling and the structure redesigns wait for its answer.
- Deposits read as darker ground on every terrain: the terrain tint mostly shows on the outer rim (the mask darkens it). Want them lighter / closer to the ground colour, or more ore?

## Earlier summary (glow review fixes and mesh manifest, 2026-10-22, M-23)

Your glow review (approved) and the mesh manifest. Commits touch only `src/shared/Defs/Meshes/`, `tests/client/Meshes.spec.luau`, `assets/` and docs.

| # | Review item | What changed | Shots (`debug_out/screens/`) |
|---|---|---|---|
| 1 | Order radar too bright; Chaos ring −30% | Oracle array face is now unlit, with a glowing edge and a thin 6 × 3 cell grid (glow share 7.5% → 2.1%); rebuilt and uploaded. Watcher dish ring strength 2.0 → 1.4 (`glow_strength` in `unit.py`, no re-upload needed) | `glow2_oracle_55_close[_dusk].jpg`, `glow2_watcher_55_close.jpg` |
| 2 | Order factory build lights | The Order vehicle plant already had five build strips and a lintel on `power`, but they never drew. The baked emissive mask didn't line up with the plant's glow part. **Every glow part now uses one shared white mask** (`assets/models/tools/glow_mask.png`, uploaded once) and `RenderFidelity.Precise`. Added door-frame jambs and chevron ticks on `power`, like the Chaos plant's slats (glow 3.0% → 3.4%); rebuilt and uploaded. The other Order factories are still blockouts: they get the same door frame when they're meshed (style guide, "Glow") | `glow2_vehplant_door_before.jpg`, `glow2_vehplant_door.jpg` |
| 3 | Team colors vs faction glows | All 8 lobby colors on Order (generator, Lancer) and Chaos (Ravager, generator), 55° close and 220 studs, normal and dusk. Two clashes, under "Needs my review" | `glow2_team_1to4_55_close.jpg`, `glow2_team_5to8_55_close.jpg`, `glow2_team_55_220[_dusk].jpg` |
| 4 | 220-stud shots looked farther | They were at the same distance (220 studs at 55°, as `bar_7` and `team_55_220`). Studio's viewport is now 1548 × 601 instead of 955 × 568: the same vertical field of view, so the units are the same pixel size, but the frame is much wider. The new 220 shots are cropped to the old 955 × 568 frame | `glow2_order_55_220[_dusk].jpg`, `glow2_chaos_55_220[_dusk].jpg` |
| 5 | Masks per model in fx.md | Confirmed: `docs/contracts/fx.md` "Unit glow" now has a table with every model's glow parts per channel (`running`, `head`, `power`, `weapon`), the non-default strengths and the glow share. B can drive `power` and `weapon` from it, or from the manifest | – |
| Manifest | Your request | `src/shared/Defs/Meshes/Registry.luau`, generated by `python assets/models/tools/manifest.py` from each mesh's `rig.json` and `roblox_assets.json`. Each entry has: model, piece and glow-part mesh IDs, maps, pieces with parents and pivots, attachments (muzzles), team pieces, glow parts per channel and a status. 22 units plus `fx.shield_emitter`. **Approved:** 19 units and the emitter. **Review:** Oracle, Watcher and the Order vehicle plant (the glow fixes above). The validator is `Meshes/Mesh.luau`; the test is `tests/client/Meshes.spec.luau` (every def piece has a mesh piece, muzzles are attachments, and every asset ID is present). Format in `docs/contracts/rig.md` section 7; decision M-23. From now on, every mesh upload regenerates the manifest in the same commit | – |

**Needs your review:**
- **Team colors that clash with a faction glow:**
  - Team 6 orange (238, 132, 40) on Chaos sits right on the amber running lights (255, 150, 55). Close up, the panels and the glow read as one color; at 220 studs the Chaos unit's accents vanish into the panel.
  - Team 7 cyan (60, 200, 210) on Order matches the cyan running lights (90, 210, 255). Its team panels read like a glow strip.
  - Team 4 yellow (232, 196, 52) on Chaos is close but still reads apart: yellow against orange, brighter.
  - Blue on Order and red on Chaos read apart (darker and more saturated than the glow).
  - **Suggestion:** shift the two team colors rather than the glows, so both factions keep their accent. Orange → a deep brown-red such as (150, 70, 40); cyan → teal-green such as (30, 150, 120), checked against green (64, 176, 84). The palette is `src/client/Render/TeamColors.luau` (client stream; marked placeholder). The alternative is shifting the clashing faction's glow toward white for that team only, a client-side choice.
- **Order plant door glow:** now the brightest thing on an Order base (strips, jambs, ticks and lintel at 2.5). B's pulse (1.5–4) will make it brighter still. Lower its resting strength if it outshines the generators.
- **Watcher ring at 1.4:** still clearly the Watcher's signature. Lower it further if you want it closer to the Oracle's thin grid.
- **The manifest's `review` items** (Oracle, Watcher, Order vehicle plant): flip them to `approved` when you OK the shots (a one-line change in `manifest.py`).

**Message to clients-B:** I didn't put the models into the game place ("FTGG Art" only). B can build them from the manifest; see the Requests section.

**Update (clients-B, C-103, `bdc88e8`, not yet in main):** the 19 approved models draw in the game place, built from the manifest, with glow and team paint; the three `review` ones stay blockouts. Game scripts can't set SurfaceAppearance maps, the emissive mask or `RenderFidelity`, so B generates `place/MeshMaterials.model.json` from the manifest with `lune run mesh_materials`. **New rule for this stream:** every manifest change (upload or status flip) runs `manifest.py` then `lune run mesh_materials`, in the same commit (rig.md 7, pipeline.md). `main` merged into `m-models`: the `chs_carapace` icon failures are gone.

## Earlier summary (glow pass, 2026-10-22, M-22)

Your glow pass is applied to every BAR-style mesh: 6 tanks / constructors / artillery, 6 T1 pairs, 10 structures (extractors, generators, solars, vehicle plants, Bulwark, Spike) and the shield emitter. All of them were rebuilt, uploaded through Open Cloud and rigged in "FTGG Art" (`ModelReview.*_bar`, `FX.Shield.Emitter`), each with its glow parts welded and tagged. Commits touch only `assets/` and docs.

- **Channels** (the masks are split as you asked):
  - `running`: always on, faction accent.
  - `head`: headlights, warm white on both factions.
  - `power`: structures, factories, builders' emitters.
  - `weapon`: the muzzle area.
- **How it's built:** each channel is its own small MeshPart per piece (`<piece>_glow_<channel>`) with its own tint and strength. B can drive each channel's `EmissiveStrength` on its own; the pieces don't glow. There are no Light objects, and glow is never team-colored.
- **Where it's documented:**
  - B's contract, with parts, attributes and intended states: `docs/contracts/fx.md`, "Unit glow".
  - The standard for new meshes: `docs/art/style-guide.md`, "Glow".
  - The decision: M-22.
- **Glow share** (measured per mesh, `glowShare` in each `rig.json`):

  | Group | Glow share |
  |---|---|
  | Vehicles | 3.3–7.5% |
  | Radar trucks | 7.5% and 8.8% |
  | Extractors, generators, solars | 3.4–8.9% |
  | Vehicle plants | 3.0% and 2.0% |
  | Bulwark and Spike | 3.2% and 2.1% |
  | Shield emitter | 9.9% |

- **Asset IDs:** in each `roblox_assets.json`. The previous upload is kept as `bar_preglow`; for the emitter, `emitterGlow` and `emitter_rev1`.
- **Fix:** the Open Cloud loader no longer leaves an empty import shell in Workspace (39 removed).

**Screenshots** (after the restart):
- 55° close and 220 studs, both factions, in Studio's normal light and in B's dusk preset (the place lighting was restored afterwards).
- Files in `debug_out/screens/`: `glow_<order|chaos>_55_close_veh[_dusk].jpg`, `glow_<order|chaos>_55_close_struct[_dusk].jpg` and `glow_<order|chaos>_55_220[_dusk].jpg`, with `_crop` versions of the 220-stud shots enlarged 4× around the row.
- Close up, Order's glow reads as cool cyan strips and Chaos's as amber. Headlights are warm white on both, and team panels stay clear.
- At 220 studs the glow reads as small faction-colored points (strongest at dusk) and doesn't wash out the panels. The Oracle and Watcher radar dishes are the brightest things on the field.

**Fix found in the shots:** the first rig left the glow faces' near-white albedo in the color map. Roblox multiplies emission by the albedo, so every glow clipped to white in daylight. Glow parts now drop the color map and take their tint as `BasePart.Color` and `EmissiveTint`; this is in `rig_model.luau`, all 130 glow parts in "FTGG Art", fx.md and M-22 (`glow_fix_before.jpg`, `glow_fix_after.jpg`). Nothing needed re-uploading.

**Still open:** two maps failed again with HTTP 502 after the restart: the Hellmouth's roughness map and the Jackal's normal map. The models draw, only without those maps. If they don't come back after the next restart, I'll re-upload the two images. The "Failure" status from `ContentProvider:PreloadAsync` in Edit mode is unreliable: it reported every map as failed although they draw.

**Needs your review:**
- **Below the 5–10% target:**
  - Factories (3.0% / 2.0%) and the Spike (2.1%). The glow sits on the doors, build lights and working parts, not on the big roofs, on purpose.
  - Chaos vehicles at 3.3–4.2%. Their glow is denser than Order's, but on smaller strips.
  - Raise them if the shots read too dark.
- **Channel choices:**
  - Builders' nano emitters (Mason, Scrapper) and the shield emitter's core are on `power` (brighten while building or charging).
  - The radar faces (Oracle, Watcher) are on `running`.
  - Missile seekers and ready lights are on `weapon`.
- **Radar dishes:** the Oracle and Watcher dishes are on `running` and are the brightest glow on the field (7.5% / 8.8%, a whole dish face). Dim them or keep them as the radar's signature.
- **Team color on barrels:** barrels and launchers are now in `teamColorPieces`. They carry little team paint, so it's harmless.

**Your steps:** save "FTGG Art" (the 130 glow parts were changed in place).

## Earlier summary (review batch, 2026-10-22)

Your review of the overnight batch: BAR style approved for both tanks (M-18), camouflage Lancers retired (their `ModelReview` copies removed; files kept). Every commit touches only `src/shared/Defs/Blockouts/`, `assets/`, `.gitignore` and docs. Tests at `74ef97b`: `test_client` 44 specs, 156 passed; `test` 62 specs, 386 passed; `build` 557 scripts compile, 1520 requires resolve.

| # | What | Commits | Status |
|---|---|---|---|
| 1 | Lancer color: measured side by side in Studio, then two passes (warmer, rougher paint, darker seams, more AO; then lighter) | `fe6c02a`, `1eca1d7` | Imported and drawing. Same hue as its blockout now (red/blue 0.94 vs 0.96, the blue cast is gone); on lit surfaces it still draws about 13% darker than the plain blockout parts (seams and AO, as asked, plus the blockout's bright SmoothPlastic). The brightness pass moved it less than expected: **your call whether to lighten it once more** (`debug_out/screens/bar_colormatch_2.jpg`) |
| 2 | Ravager: lighter gunmetal and edge highlight, 10% lower and narrower than the Lancer (`lib.Piece.scale`), orange accents unchanged | `fe6c02a`, `1eca1d7` | Done: within about 4% of its blockout on lit surfaces |
| 3 | Team color swap: runtime `BasePart.Color` on `TeamColor` parts under the color map's alpha (B's `ModelPool` already does this); method in `docs/contracts/rig.md` 6 | `fe6c02a`, `08d2da5` | Done: `debug_out/screens/team_55_close.jpg`, `team_55_220.jpg` (blue, red, green, yellow on both tanks; emissive unchanged) |
| 4 | Perf: 100 and 300 BAR tanks vs blockouts, render CPU per frame at close and normal zoom, appearance hitch | `08d2da5` | Done: no measurable render-CPU cost over blockouts; the appearance hitch is about half the blockouts' (pipeline.md). The cold first-load hitch (review 2: 320 ms) wasn't repeatable once the maps were loaded; preloading is the client's call |
| 5 | Warden packed vs deployed: jacks, shield wings, bigger hazard-striped spades, hull drop, gun raised (M-19) | `96800a0` (in main) | Done as blockout and review pose; **B's piece script needs to animate the new pieces (Request 6)**; at 220 studs the yellow spades and the front wall read, but the change is still small |
| 6 | Minotaur low, wide, front-heavy with a ram wider than the hull; Cyclops tall with a fixed 75° tube and the eye on a mast | `96800a0` (in main) | Done: `debug_out/screens/minotaur_cyclops_*.jpg` |
| 7 | Reckoning silo top: split blast doors and a hazard edge (palette key `hazard`) | `96800a0` (in main) | Done: `debug_out/screens/fix_overview_55_220.jpg` |
| Shield | Shield effect assets (Order): dome, inner dome, ring, emitter device, swirl / beam / speck / ripple textures, all white for team tint; `docs/contracts/fx.md`. After your reference: the swirl redrawn as a cloudy vortex with a bright eye and knots; the ground ring documented. Shield generators `ord_phalanx` / `chs_carapace` registered for the S-79 defs (request 8) | `200ac59`, `08d2da5`, `f4a6eac`, `b9d7e91` | Done: `ReplicatedStorage.FX.Shield` (new swirl and emitter); `debug_out/screens/shield_*.jpg` |
| 8 | T1 vs T2 per role: T2 structures that didn't read as the upgrade got a signature piece (Order radome and covered dock, Chaos ski jump and giant crane, raised Bastion and Maw, wider advanced extractors); T1 sonar and jammer made | `e993e36` | Done: `debug_out/screens/tier_*.jpg`; T2 ground units compared after item 9 (`ground_t1_t2_*.jpg`) |
| 9 | Blockouts for everything still generic: T2 ground units and both commanders, T1/T2 aircraft, T1/T2 ships, the last generic structures. **All 133 defs now have a hand-made blockout** | `7506eae`, `fcc05b9`, `74ef97b` | Done: `debug_out/screens/ground_*`, `air_*`, `naval_*.jpg` |
| 10 | BAR meshes for the rest of batch 1 T1 ground units, in build order (two normal AI matches, 20 min: Ravager 31, Scrapper 28, Mason 23, Lancer 21, Hellmouth 14, Verdict 8, Oracle 3, Watcher 2; scouts and mobile AA 0) | `c19023a`, `b9d7e91` | Mason, Scrapper, Verdict and Hellmouth imported and rigged (`ModelReview.*_bar`); team test in four colors passed for all four (`debug_out/screens/team_constructors_artillery_*.jpg`). The Hellmouth's team panels were too thin to read at 220 studs: enlarged, **needs one more import** of `chs_hellmouth.fbx`. Next pair: Oracle and Watcher (radar vehicles), then Herald / Jackal and Halo / Hornet |
| 11 | BAR meshes for the most-seen structures, both factions | `5b2999a`, `53e4a34` | Done: extractors, generators, solars, vehicle plants, Bulwark and Spike, plus the Hellmouth with bigger team panels, uploaded through Open Cloud (no clicks), rigged and drawing in "FTGG Art" (`ModelReview.*_bar`); team test in four colors passed for all of them (the Spike copies drew after the Studio restart). Shots: `debug_out/screens/structures_*.jpg`, `team_structures_55_close.jpg`. Next: the remaining T1 pairs (Oracle / Watcher, Herald / Jackal, Halo / Hornet) |
| 12 | BAR meshes for the remaining T1 ground pairs: Herald / Jackal (scouts, 976 / 836 triangles), Halo / Hornet (mobile IR SAM, 1,132 / 1,008), Oracle / Watcher (mobile radar, 912 / 908) | `5923128` | Built with `tools/unit.py` (new `wheel` helper), uploaded through Open Cloud and rigged (`ModelReview.*_bar`). All six draw after a Studio restart (four had failed to load fresh images, `NetFail` and one HTTP 502, which Studio caches until it restarts); team test in four colors passed for all six (`debug_out/screens/t1_pairs_*.jpg`, `team_t1_pairs.jpg`). Every batch-1 T1 ground unit now has a BAR mesh |

**Needs your review:**
- Shield vs your reference: the dome, rim, thin rings and beam match the approach; the swirl is redrawn as a cloudy vortex with a bright eye and knots (original, procedural); the ground ring is one more `Ring` at h = 0 (fx.md). The specks and hit ripple are textures for particles, not in the static shots.
- Shield emitter core glows Order cyan (M-16), not the team color; dome radius is B's choice (the check used R = 40). The emitter is about 4 studs across.
- Cyclops: the weapon pitches −5° to 60° from a level rest, so the tall tube is fixed and only a short cradle (`barrel`) pitches (M-19).
- `assets/reference/` wasn't gitignored before; now its images are (only `bar/README.md` stays tracked).
- Several T2 units' weapons turn `launcher` while their `turret` piece turns nothing (Seraph, Gorgon, Judgement, Hydra), like Halo/Hornet before S-64; the blockouts work either way (M-3). Your call whether to ask the sim session for `turretPiece = "turret", pitchPiece = "launcher"`.
- Aircraft and ships are blockouts in the same faction language; their proportions (fuselage 7–9 studs, footprint-3 ships 24 long) follow the generic sizes.

**Your steps:** none. Uploads go through Open Cloud; a Studio restart clears a fresh image that failed to load.

## Earlier summary (overnight 2026-10-22)

**All four tasks are done, committed, pushed and in the merge queue below.** Every commit touches only `src/shared/Defs/Blockouts/`, `assets/` and docs. Tests: `lune run test_client` 34 specs, 116 passed; `lune run build` 454 scripts compile, every require resolves.

| Task | What | Commit | Status |
|---|---|---|---|
| 0 | BAR-style Lancer (M-15): rebuilt, imported, rigged as `ReplicatedStorage.ModelReview.ord_lancer_bar` with its emissive mask | `9dd4913` | **Waiting for your review.** Blender previews only: in Studio its textures haven't drawn yet (the texture-pack quirk, pipeline.md step 3); a save and Studio restart should fix it |
| 1 | BAR-style Ravager: 3,696 triangles, gunmetal, Chaos light build (exposed wheels, slat cages, domed turret with reactive armor), orange emissive; exported up to the import step | `5d37c43` | **Waiting for your review** with the Lancer; the FBX is ready for your import |
| 2 | Silo blockouts registered (Reckoning, Ragnarok); pending blockouts for the six new units (Warden packed and deployed, Minotaur, Locust, Cyclops, Barrier, Citadel), with request 3 to the sim session for their defs (M-17); blockout palettes follow the style guide (M-16) | `e78eec0` | Done; pending ones register when the defs exist |
| 3 | 22 T1 structure blockouts, both factions, silhouette-tested | `afc6d73` | Done |
| 4 | 28 T2 structure blockouts, both factions | `442394f` | Done |

**Needs your review:**
- The two BAR-style tanks (previews in `assets/models/*/export/preview_bar_*.png`); the style isn't rolled out further until you approve both.
- Blockout palettes changed for every unit (M-16): Chaos lost its rust and dark-iron colors.
- Minotaur and Cyclops read alike as silhouettes at distance; the two radar towers per tier share an outline (same role).
- The new units' piece lists and footprints are my proposal (request 3).

**Merge fix (after the summary):** `main` merged in (conflicts in guide 2.1 and the Requests list resolved, both sides kept); Warden and Minotaur adapted to the S-64 defs and registered (Warden footprint 1 with one `spades` plate; Minotaur `ram` jointed); `debug_out/screens/s64_warden_minotaur.jpg`. Tests on the merged tree: `test_client` 42 specs, 141 passed; `test` 57 specs, 371 passed; `build` 476 scripts.

**Morning 2026-10-22, tank review: both BAR tanks draw in Studio and wait for your review.** Lineup `Workspace.TankTest` in FTGG Art (x 1176–1228, z −250), left to right: previous Lancer (review 2a), BAR Lancer, Lancer blockout, BAR Ravager, Ravager blockout. Rigged models: `ReplicatedStorage.ModelReview.ord_lancer_bar` and `chs_ravager_bar`; asset IDs in each unit's `roblox_assets.json`. Screenshots: `debug_out/screens/bar_1_lancer_closeup.jpg` … `bar_8_pitch80_dist220.jpg` (close-ups; pitch 35°, 55°, 80° at 50 and 220 studs).
- The Lancer's first upload never drew (a map failed with HTTP 502, and a re-import reused the broken upload). Fixed by an upload revision stamp in the Blender pipeline (`lib.UPLOAD_REV`, pipeline.md) and a fresh import, save and restart.
- Notes for the review: in Studio's lighting the Lancer's sand-grey reads cooler than in the Blender previews. The emissive accents are subtle in daylight. At 220 studs the factions read by paint (light with blue against dark with red) more than by mass.
- Terrain grass decoration shows in the close shots since the restart (a place setting; not changed by me).

## Plan

- **Phase 1:** hand-made blockouts (gameplay placeholders, M-9).
  - [x] T1 ground units (batch 1, M-1..M-5; colors updated by M-16).
  - [x] Silos and pending new units (overnight task 2).
  - [x] T1 structures (overnight task 3), T2 structures (overnight task 4).
  - [ ] T1/T2 air and naval units, T2 ground units: still generic.
- **Phase 2** (started early, M-9): detailed meshes with PBR textures.
  - [x] Style guide; Chaos base color: gunmetal (M-10). BAR model style (M-15).
  - [x] Lancer vertical slice (M-11..M-13), review 2 (camouflage), review 3 (BAR style).
  - [ ] Ravager in BAR style: imported and rigged; both BAR tanks waiting for review.

## Overnight 2026-10-22: T2 structures (task 4)

28 blockouts, every T2 structure for both factions, registered, same rules as T1:

| Role | Order | Chaos |
|---|---|---|
| Adv. vehicle plant (fp 5) | `ord_advvehplant`: two armored halls under one roof, two doors and ramps | `chs_advvehplant`: long shed plus two open gantry bays, row of tanks |
| Adv. airfield (fp 5) | `ord_advairfield`: wide runway, two armored hangars, tall tower | `chs_advairfield`: two open roof-on-posts hangars, tanks, tall lattice mast |
| Adv. shipyard (fp 5) | `ord_advshipyard`: armored piers, tall hall, two gantry cranes | `chs_advshipyard`: piers on pilings, two lattice tower cranes |
| Adv. extractor | `ord_advextractor`: taller housing, twin drills | `chs_advextractor`: taller derrick, thick drill, cage |
| Fusion (fp 3) | `ord_fusion`: stepped fortress round a glowing containment sphere | `chs_fusion` (Hellforge): round furnace stack with glowing bands in an open frame |
| Long-range radar (fp 3) | `ord_beacon`: tall armored tower, very wide array | `chs_allseer`: tall lattice mast, wide array, big eye |
| Radar SAM (fp 3) | `ord_aegis`: four-cell canister launcher, separate radar block | `chs_wyvern`: twelve bare tubes on a frame, lattice radar mast |
| Artillery (fp 3) | `ord_edict`: casemate turret, very long gun | `chs_cataclysm`: open pit with reactive blocks, fat barrel |
| Coastal battery (fp 3) | `ord_rampart`: sea-wall bunker, twin guns | `chs_breaker`: open platform, one long gun plus missile box |
| Heavy turret | `ord_bastion`: twin long guns | `chs_maw`: squat turret, fat short "maw" gun |
| Fire-control radar (fp 2) | `ord_tribunal`: block with twin back-to-back panels | `chs_seekerspire`: narrow lattice spire, panel, eye |
| Jammer tower | `ord_veilspire`: tapered pylon, emitter fins | `chs_blackout`: lattice mast, rings of emitter rods |
| Sonar station (fp 3) | `ord_choir`: floating armored platform, ring array | `chs_deepear`: pontoon floats, sonar drum |
| Pinpointer (fp 2) | `ord_witness`: block with a turning flat array (`dish`) | `chs_augur`: lattice mast with a flat array (`dish`) |

- Visual pieces: `radar` on the Beacon, All-Seer, Tribunal and Seeker Spire. The Pinpointers' `dish` piece is a flat array (no dishes, style guide).
- Screenshots: `debug_out/screens/struct2_*.jpg`; in "FTGG Art": `T2Big*` (x 600–900, z 1000–1180), `T2Mid*` (z 580–720), `T2Small*` (z 820–900).
- `lune run test_client`: 34 specs, 116 passed.

## Overnight 2026-10-22: T1 structures (task 3)

22 blockouts, every T1 structure role for both factions, registered (they replace the generic boxes):

| Role | Order (heavy, closed, sloped armor, cyan) | Chaos (light, open frames, tanks, orange) |
|---|---|---|
| Vehicle plant (fp 3) | `ord_vehplant`: closed armored hall, buttresses, door over a ramp, team roof | `chs_vehplant`: shed plus an open gantry bay with a crane beam, round tanks |
| Airfield (fp 5) | `ord_airfield`: runway with edge lights, armored hangar, control tower with radar panel | `chs_airfield`: runway, open roof-on-posts hangar, fuel tanks, lattice mast |
| Shipyard (fp 5) | `ord_shipyard`: armored piers, closed hall, gantry crane across the basin | `chs_shipyard`: piers on pilings, lattice tower crane with a jib, shed and tanks |
| Extractor | `ord_extractor`: armored sloped housing, drill head with a light ring | `chs_extractor`: open four-leg derrick, engine box |
| Generator | `ord_generator`: armored block with a domed reactor cap | `chs_generator`: two glowing combustion tanks on a frame |
| Solar | `ord_solar`: one large tilted panel on a pedestal | `chs_solar`: three small panels at uneven tilts on a frame |
| Wind | `ord_windmill`: tapered tower, three-blade rotor | `chs_windmill`: lattice tower, two-blade rotor |
| Storage | `ord_depot`: low sloped bunker with hatches | `chs_depot`: cluster of round tanks |
| Radar tower | `ord_watchtower`: square armored tower, flat array | `chs_eye`: lattice mast, flat array, orange eye |
| Gun turret | `ord_bulwark`: sloped armored base, wedge turret, long gun | `chs_spike`: round base with reactive blocks, rounded turret, twin guns |
| IR SAM site | `ord_vigil`: armored base, twin closed pods round a sensor | `chs_thorn`: post with six bare canister tubes on a frame |

- Pieces: as the defs (`base`, plus `turret` / `launcher` and `muzzle` on the turrets and SAM sites). Visual pieces for the client to animate: `rotor` on the wind turbines, `radar` on the radar towers.
- Silhouette test (`debug_out/screens/struct1_*.jpg`; in "FTGG Art": `StructBig*` at z 540–720, `StructSmall*` at z 820–900): every role pair reads apart, and Order vs Chaos differ as black shapes (solid and sloped vs frames and tanks). The two radar towers share an outline (same role, by design).
- `lune run test_client`: 34 specs, 116 passed.

## Overnight 2026-10-22: new units and silos (task 2)

- **Silos** (defs exist, registered): `ord_reckoning` (stepped square armored bunker, sloped blast walls, heavy hatch, team plates on the upper block) and `chs_ragnarok` (round silo tube on a pad ringed with reactive-armor blocks, open launch gantry with a crane arm, fuel tanks). Footprint 3; `hatch` hinged at its back edge; `muzzle` over the silo.
- **Pending** (no defs yet, M-17; `Blockouts/Pending/`): Warden (packed and deployed: rear spades fold down, a shield rises in front of the turret), Minotaur (ram plate with reactive blocks, short fat demolition gun), Locust (very small swarm tank), Cyclops (huge mortar tube and a big glowing sensor eye), Barrier (thick sloped wall segment, lines up per cell), Citadel (stepped fortress with a big turret, an IR SAM launcher and a radar array). All validate against the stub defs in `Pending/Registry.luau`.
- **Palettes** (M-16): blockouts now use the style guide paints (Order sand-grey and cyan, Chaos gunmetal and orange), so every part-built blockout changed color.
- **Screenshots** (`debug_out/screens/newunits_*.jpg`): 55° halves, Warden packed vs deployed, profile and silhouette rows. In "FTGG Art": folders `NewReview`, `NewProfile`, `NewSilhouette` (x 250–490, z 300–420); the review builder is `ServerStorage.ModelsTools.Lineup`.
- **Needs review:** Minotaur and Cyclops read alike as silhouettes at distance (both blocky hulls with a short fat gun); the Cyclops eye and the Minotaur ram only show at closer zoom.

## Lancer review 2 (2026-10-21/22, waiting for your review)

Your revisions: camouflage options (a) plain sand with weathering and low grime, (b) crisp three-tone disruptive; team color as a painted roof panel and side stripes; baked detail (bolts, seams, hatches, periscopes, ribs, wear, ambient occlusion); a new gun (two-part thermal sleeve with clamp bands, bore evacuator, muzzle with lip and bore).

- **Built and imported:** 3,704 triangles (base 2,012, turret 764, barrel 928), limit 4,000; textures 1024 × 1024, color and roughness per variant, normal and metalness shared. Both variants rigged as `ReplicatedStorage.ModelReview.ord_lancer_a` / `_b` in "FTGG Art"; asset IDs in `assets/models/ord_lancer/roblox_assets.json`.
- **100 tanks, render CPU per frame (close / normal zoom):** empty 4.7 / 4.7 ms, 100 blockouts 5.1 / 4.9 ms, 100 first-slice Lancers 4.3 / 4.1 ms, 100 review-2 Lancers 4.25 / 4.2 ms (warm; the first appearance had a one-off 320 ms load hitch).
- **Team paint:** the first wash (0.3) drew dark navy in Studio and nearly vanished at 220 studs; rebuilt with a 0.1 wash (imported, not yet seen in Studio).
- **Grey for one session:** after the first restart every PBR model in "FTGG Art" drew grey, the first slice included; the `TexturePack` assets failed to load ("Asset type does not match requested type"). After a second restart the next day the models draw correctly although the packs still report the same failure, so Studio falls back to the four maps.
- **Screenshots** (`debug_out/screens/lancer2_*.jpg`; order A, B, blockout): pitch 55°, 35° and 80° at 40 and 220 studs, and a ground-level close-up in Realistic lighting. The lighter team panel reads at 220 studs on both variants; B's dark patches turn the tank brown at 80°, A stays sand.
- **Still to decide:** the camouflage (A or B) and the budget standard.
- **Lighting:** "FTGG Art" already uses `LightingStyle.Realistic` with `PrioritizeLightingQuality` (the unified renderer replaced `Technology`/Future).

## Lancer mesh vertical slice (2026-10-21)

Workflow: [`../art/pipeline.md`](../art/pipeline.md). Built headless in Blender 5.2 (`assets/models/ord_lancer/build.py`), imported with the 3D Importer in "FTGG Art", rigged by `assets/models/tools/rig_model.luau`, saved as `ReplicatedStorage.Models.ord_lancer` in "FTGG Art" (uploaded IDs in `assets/models/ord_lancer/roblox_assets.json`).

- **Model:** Leopard 2 lines with near-future accents (arrowhead turret, panoramic and gunner's sights, remote gun, active-protection launchers, glass sensor strips, a rail along the gun); three-tone sand camouflage, worn edges, tread; team color on the turret roof and the hull top beside it (color-map alpha, AlphaMode Overlay).
- **Budget:** 3,016 triangles (base 2,036, turret 608, barrel 372) against the 4,000 cap (M-12), `RenderFidelity.Automatic`; one 1024 set of color, normal, roughness and metalness.
- **Rig:** `base` (anchored, primary), `turret` and `barrel` on Motor6Ds at the rig pivots, `muzzle` at (0, 2.3, −7.5) facing −Z, `TeamColor` on base and turret, `RootOffset` set; checked against `rig.json` (sizes within 5 %, offsets within 0.05 studs).
- **100 units, render CPU per frame** (three runs): 100 meshed Lancers cost no more than 100 blockouts (pipeline.md has the table); GPU time and real frame rate aren't measurable in Studio, phones untested.
- **Screenshots** (`debug_out/screens/`, gitignored), the mesh on the left of the blockout on the Coastline grass: `lancer_0_closeup.jpg`; pitch 55° at 40, 220 and 900 studs (`lancer_1`..`3`); 35° at 40 and 220 (`lancer_4`, `5`); 80° at 40 and 220 (`lancer_6`, `7`).
- **Import notes** (pipeline.md step 3): the FBX comes in at ×100 and turned 180° (the rig script undoes both); the importer's TexturePack broke on a transient download error and drew the model grey until Studio was restarted.

### Needs your review

- The look at close zoom and the readability at normal zoom: the camouflage works as camouflage, so the meshed Lancer is less eye-catching than the white blockout; the team panels carry the identity from above.
- In Roblox's lighting the dark camouflage patches turn bluish and the sand reads a bit darker than in Blender: warming the dark tone and lightening the ambient occlusion is a quick rebuild.
- Proposed per-class budgets and texture sizes (pipeline.md): heroes 6,000 / 1024, line units 3,000 / 512 or a shared faction set, structures 3,000–6,000 / shared set, wrecks 1,000.

## Style review: modern armies (2026-10-21)

The new direction (M-6) is in guide 2.1 and [`../art/style-guide.md`](../art/style-guide.md). Four candidates in `src/shared/Defs/Blockouts/Review/` (M-7), not used by the game yet:

| Variant | Lines | Base | What it has |
|---|---|---|---|
| Lancer A | Leopard 2A6 | grey | arrowhead turret front, five road wheels, panoramic and gunner's sights, bustle |
| Lancer B | Abrams | sand | steep glacis, six road wheels, wide flat slab turret, long bustle with rack, CITV, gunner's sight, remote gun |
| Ravager A | T-90M | olive | reactive-armor tiles on the glacis, skirts and turret brow, six road wheels, slat cage round the turret back, remote gun, sight, fume extractor |
| Ravager B | T-14 Armata | gunmetal | longer hull, seven road wheels, reactive-armor skirt panels, rear slat cage, tall faceted turret, flat protection radars, two sensor boxes, remote gun, active-protection launchers |

All four: long low hull, skirts with road wheels, turret toward the rear, long gun, team color only on skirt stripes, turret side panels and a roof panel (M-8). Same pieces as the def (`base`, `turret`, `barrel`, `muzzle`); each validates against its def.

- **Screenshots** (`debug_out/screens/`, gitignored), each with the current Lancer and Ravager for comparison (order: Lancer current, A, B, Ravager current, A, B):
  - `style_tanks_1_threequarter.jpg`: game camera (55°), three-quarter heading, about 40 studs.
  - `style_tanks_2_profile_camera.jpg`: game camera, units facing screen-left.
  - `style_tanks_3_side_order.jpg`, `style_tanks_4_side_chaos.jpg`: true side views at ground level.
  - `style_tanks_5_silhouette.jpg`: all black, game camera at about 100 studs.
  - In "FTGG Art": folders `StyleReview`, `StyleProfile`, `StyleSilhouette` around x = 300.
- **Budget:** 32–53 parts; estimated 1,350–2,000 triangles as primitives, so the Chaos variants go over 20.1's 1,500 until the phase 2 meshes (style guide 6).

### Needs your review

- Pick one variant per faction (or a mix), and grey or sand for Order, olive or gunmetal for Chaos.
- At 100 studs, the four variants share one tank silhouette (long hull, rear turret, long gun), as the shared rules ask; the factions then differ by base color and secondary shapes (tiles, cages, sensor boxes) more than by outline.
- The muzzles sit at 2.25–2.5 studs; the sim fires from 3.6 (`Combat.MUZZLE_HEIGHT`), so shells would start about 1.2 studs above the barrel. If the low hulls stay, I'll ask the sim session to lower it.
- Batch 1's `84ba52d` is still in the merge queue with the old style for the other 10 units (better than generic blockouts until they're redone). Say if you'd rather hold it.

## Batch 1: T1 ground units (2026-10-21)

Superseded style (M-2); kept until the redo.

Twelve units, six roles, both factions. Lancer and Ravager (from the client stream's C-6) are kept as they were; the other ten are new.

| Role | Order | Chaos | Silhouette cue |
|---|---|---|---|
| Scout | `ord_herald`: low 4-wheeler, sloped nose, glass cab, tiny rear turret | `chs_jackal`: open buggy, roll cage, exposed engine, big rear wheels, shielded gun offset right | smallest, wheeled |
| Light tank | `ord_lancer` (unchanged) | `chs_ravager` (unchanged) | turret and gun |
| Artillery | `ord_verdict`: rear-set sloped turret, 9-stud gun 5 studs past the nose | `chs_hellmouth`: open casemate, fat short tube, recoil spade, loader arm, crates | longest / fattest gun |
| IR SAM | `ord_halo`: 6-wheeler, twin pods on a pedestal around a glass sensor | `chs_hornet`: truck, offset cab, closed rack right, bare missiles left, counterweight | launcher raised on a pedestal |
| Radar | `ord_oracle`: 6-wheeler, shelter, wide flat array tilted back | `chs_watcher`: truck, generator and stack, braced mast, round dish with glowing feed | big panel / dish |
| Worker | `ord_mason`: dozer blade, glass cab, turntable crane with blue emitter | `chs_scrapper`: plow, offset cab, scrap hopper, claw arm with orange glow | arm rising forward |

- **Pieces:** every def piece is in place (`turret`, `barrel`, `launcher`, `dish`, `nano`, `muzzle`); turret pivots on the turret's center, barrel pivots at the trunnion, `dish` and `nano` turn about their mast or turntable. SAM rig: M-3.
- **Muzzles:** 2.4–2.5 studs (scouts), 2.6–3.3 (guns), 3.6–4.3 (SAMs); the sim fires from 3.6.
- **Size:** footprint 1 (about 6 × 8 studs). Heights: 3–4.6 studs; radars and worker arms reach 5.3–7.2 so the role reads from above.
- **Budget (guide 20.1, 300–1,500 triangles per unit):** 12–20 primitive parts per unit. Roblox doesn't report primitive triangle counts; counting a box as 12, a cylinder as about 100 and a ball as about 300, the heaviest (Hornet, 11 cylinders) is about 1,200. The budget mainly constrains the phase 2 meshes.
- **Screenshots** (`debug_out/screens/`, gitignored), game camera pitch 55°:
  - `models_batch1_threequarter.jpg`: team colors, three-quarter heading, about 50 studs.
  - `models_batch1_profile.jpg`: facing screen-left, about 50 studs.
  - `models_batch1_silhouette.jpg`: all black, about 100 studs.
  - In "FTGG Art": folders `BlockoutReview`, `BlockoutProfile`, `BlockoutSilhouette` around x = 100 (M-1).
- **Tests:** `lune run test_client`: 19 specs, 82 passed, 0 failed (`Blockouts.spec` 5 / 5). `lune run test`: 41 specs, 299 passed, 0 failed. `lune run build`: 349 scripts compile, every require resolves.

### Needs your review

- The style split (M-2): Order clean, symmetric and sloped; Chaos heavy, offset, exposed machinery.
- Weakest silhouettes at gameplay distance: Ravager vs Hellmouth (both blocky with a short gun; the Hellmouth's tube is fatter and it has a spade), and the scouts are small enough that their guns vanish.
- Radar and worker arms go above the 3–5 stud guideline of rig.md 3 on purpose.

## Merge queue

- Ready to merge: `84ba52d` (batch 1: T1 ground unit blockouts, both factions; new `docs/decisions/models.md` and `docs/progress/models.md`; touches only `src/shared/Defs/Blockouts/` and those two files).
- Ready to merge: `255dd9f` (new art direction: guide 2.1 and 20.3, `docs/art/style-guide.md`; style-review variants in `Blockouts/Review/`, not used by the game).
- Ready to merge: `8eee48c` (near-future art direction: guide 2.1, `docs/art/style-guide.md`, `docs/art/pipeline.md` proposal; docs only).
- Ready to merge: `8fb707a` (Lancer mesh vertical slice: `assets/models/` scripts and exports, `docs/art/pipeline.md` workflow and budgets; no code under `src/`).
- Ready to merge: `786d58b` (Lancer slice results: screenshots notes, third render run, import notes, asset IDs; docs and `assets/` only).
- Ready to merge: `f9f1022` (Lancer review 2: camouflage variants, baked detail, painted team color, new gun; `assets/` and docs only).
- Ready to merge: `561489b` (style guide: heavy Order, light Chaos, M-14; guide 2.1 Look row; docs only).
- Ready to merge: `9dd4913` (BAR model style M-15: style guide, guide 2.1, BAR Lancer build; `assets/` and docs only).
- Ready to merge: `5d37c43` (BAR-style Ravager build, up to import; `assets/` only).
- Ready to merge: `e78eec0` (blockouts: silos registered, pending new units, palettes M-16/M-17; `src/shared/Defs/Blockouts/` and docs only).
- Ready to merge: `afc6d73` (blockouts: every T1 structure, both factions; `src/shared/Defs/Blockouts/` and progress only).
- Ready to merge: `442394f` (blockouts: every T2 structure, both factions; `src/shared/Defs/Blockouts/` and progress only).
- Ready to merge: `a739890` (merge of `main` with conflicts resolved, both Requests lists kept; Warden and Minotaur blockouts on the S-64 defs, registered; includes every earlier entry above).
- Ready to merge: `a6193c4` (Ravager imported: asset IDs, pipeline note on re-importing when a restart doesn't fix grey textures, progress; `assets/` and docs only).
- Ready to merge: `cda7860` (Lancer re-uploaded with the upload revision stamp in `assets/models/tools/lib.py`, asset IDs, pipeline note, tank review status; `assets/` and docs only).
- Ready to merge: `96800a0` (review fixes: BAR tank rebuilds with `lib.Piece.scale`, team color method in rig.md 6, Warden / Minotaur / Cyclops / Reckoning blockouts, Locust / Cyclops / Barrier / Citadel registered, palette key `hazard`, M-18, M-19; includes `fe6c02a` and a merge of `main`; `src/shared/Defs/Blockouts/`, `assets/` and docs only).
- Ready to merge: `2543ee8` (shield effect assets and fx.md, BAR tank IDs and brightness pass, perf with 100 and 300 BAR tanks, T1 vs T2 structure signatures, hand-made blockouts for every remaining def (T2 ground, commanders, aircraft, ships, last structures), M-20, M-21; includes `200ac59` to `74ef97b`; `src/shared/Defs/Blockouts/`, `assets/`, `.gitignore` and docs only).
- Ready to merge: `baaf5bb` (shield generator blockouts ord_phalanx / chs_carapace for the S-79 defs (request 8), fx.md beam attachment and ground ring, cloudy shield swirl, BAR meshes for Mason, Scrapper, Verdict and Hellmouth with asset IDs, merge of `main`; includes `f4a6eac`; `src/shared/Defs/Blockouts/`, `assets/` and docs only).
- Ready to merge: `5b2999a` (structure meshes and the shared Blender runner; `assets/` and docs only).
- Ready to merge: `2f8e394` (shield thin ring and band meshes, fx.md; `assets/` and docs only).
- Ready to merge: `3522f82` (shield RingThin and Band mesh IDs, Open Cloud upload tool; `assets/` and docs only).
- Ready to merge: `53e4a34` (structure meshes and Hellmouth uploaded through Open Cloud: asset IDs, pipeline notes; `assets/` and docs only).
- Ready to merge: `5923128` (BAR meshes for the remaining T1 ground pairs with asset IDs; `assets/` and docs only).
- Ready to merge: `674e394` (glow pass M-22: four glow channels as welded glow parts in every BAR mesh, rebuilt and uploaded through Open Cloud; shield emitter in its own build; fx.md Unit glow, style guide Glow; `assets/` and docs only).
- Ready to merge: `113202b` (glow pass asset IDs in every `roblox_assets.json`, emitter IDs in fx.md, Open Cloud loader cleanup, progress summary; `assets/` and docs only).
- Ready to merge: `639d555` (glow parts take their tint as albedo, so the glow reads in daylight; rig_model.luau, fx.md, M-22, style guide; glow shots in the summary; `assets/` and docs only).
- Ready to merge: `cf819cc` (glow review fixes: Oracle, Watcher, Order vehicle plant, shared glow mask; mesh manifest `src/shared/Defs/Meshes/` with its test `tests/client/Meshes.spec.luau`, M-23, rig.md 7, fx.md glow parts per model; `src/shared/Defs/Meshes/`, `tests/client/`, `assets/` and docs only).
- Ready to merge: `0f911df` (merge of `main`; mesh_materials step for every manifest change in rig.md 7 and pipeline.md; includes `cf819cc`; `assets/` and docs only besides the merge).
- Ready to merge: `b41e955` (manifest: Oracle, Watcher, Order vehicle plant approved; fx.md team-color clashes; `src/shared/Defs/Meshes/` and docs only. `lune run mesh_materials` not run: the tool isn't in main yet).
- Ready to merge: `89753cc` (BAR pair 1: radar towers ord_watchtower / chs_eye as review, manifest + mesh_materials, merge of main; `assets/`, `src/shared/Defs/Meshes/`, `tests/client/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `7e21755` (BAR pair 2: IR SAM sites ord_vigil / chs_thorn as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `4654e72` (BAR pair 3: wind turbines ord_windmill / chs_windmill as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `246d2f0` (BAR pair 4: storage ord_depot / chs_depot as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `fa05a5f` (BAR pair 5: airfields ord_airfield / chs_airfield as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `0c824cd` (BAR pair 6: shipyards ord_shipyard / chs_shipyard as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `43cc013` (BAR pair 7: shield generators ord_phalanx / chs_carapace as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `9c0bc6f` (BAR pair 8: ord_warden / chs_minotaur as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `2f0c6f1` (BAR pair 9: air workers ord_skywright / chs_vulture as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `b282863` (missile meshes (IR / radar SAM, nuke per faction) as review in the manifest's fx, fx.md Missiles, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `3892b9e` (BAR pair 10: attack helicopters ord_guardian / chs_wasp as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `964bf9d` (BAR pair 11: fighters ord_falcon / chs_harpy as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `1e27511` (BAR pair 12: bombers ord_absolution / chs_plague as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `7b50962` (BAR pair 13: naval workers ord_tidewright / chs_wrecker as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `aa5ff27` (BAR pair 14: corvettes ord_sentry / chs_barracuda as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `4997c27` (BAR pair 15: submarines ord_silence / chs_lamprey as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `90fceea` (BAR pair 16: T2 constructors ord_architect / chs_forgemaster as review, tools/hulls.py, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `8280442` (BAR pair 17: MBTs ord_paladin / chs_juggernaut as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `34fb5f0` (BAR pair 18: MLRS ord_judgement / chs_hydra as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `a27b0c7` (BAR pair 19: radar SAM trucks ord_seraph / chs_gorgon as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `8114092` (BAR pair 20: fire-control radars ord_arbiter / chs_stalker as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `1e89c20` (BAR pair 21: jammers ord_veil / chs_shroud as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `f6387cd` (BAR pair 22: chs_locust / chs_cyclops as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `30b3e28` (BAR pair 23: ord_barrier / ord_citadel as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `0576073` (BAR pair 24: silos ord_reckoning / chs_ragnarok as review, pending beam tower blockouts with a retracted pose, manifest + mesh_materials; `assets/`, `src/shared/Defs/Blockouts/Pending/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `aafbf19` (S-96 T2 defense blockouts (ord_radiance, chs_inferno, ord_lumen, chs_hailstorm) under the sim's IDs, after merging main; `src/shared/Defs/Blockouts/` and docs only).
- Ready to merge: `1efc5e9` (BAR pair 25: beam towers ord_radiance / chs_inferno as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `1429976` (BAR pair 26: flak towers ord_lumen / chs_hailstorm as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json` and docs only).
- Ready to merge: `6b94586` (Wreck meshes for the 22 approved meshes (`wreck` in each manifest entry, M-24); `assets/`, `src/shared/Defs/Meshes/`, `tests/client/Meshes.spec.luau`, `.gitignore` and docs).
- Ready to merge: `69bbce2` (Wreck status field (`review` for all 22) in the mesh manifest; `src/shared/Defs/Meshes/`, `tests/client/Meshes.spec.luau`, tools and docs).
- Ready to merge: `73de0d7` (All BAR meshes, missiles and wrecks approved in the mesh manifest; `src/shared/Defs/Meshes/`, tools and docs only).
- Ready to merge: `9a5f486` (Nanoframe anchors on factories and constructors (blockouts + mesh manifest attachments, rig.md 8); `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/`, tools and docs).
- Ready to merge: `b02a62e` (Review fixes for 11 approved meshes and the 6 missiles (re-uploads, manifest + mesh_materials); `assets/`, `src/shared/Defs/Meshes/`, `place/` and docs).
- Ready to merge: `0f31945` (BAR pair 27: Commanders ord_sovereign / chs_warlord as review, manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/` and docs only).
- Ready to merge: `529d7bf` (Helicopter re-uploads after HTTP 502 (manifest + mesh_materials), size-scale status; `assets/`, `src/shared/Defs/Meshes/`, `place/` and docs).
- Ready to merge: `4912cd7` (Structure blockouts scaled to the S-104 footprints (placeholders until the redesigns); `src/shared/Defs/Blockouts/` and docs).
- Ready to merge: `5dd3f5a` (Anti-nuke pending blockouts ord_providence / chs_cerberus with open / raised poses; `src/shared/Defs/Blockouts/Pending/` and docs only).
- Ready to merge: `2f129da` (Mobile anti-nuke pending blockouts ord_custodian / chs_chimera with the raised pose; `src/shared/Defs/Blockouts/Pending/` and docs only).
- Ready to merge: `48a18fd` (Animated pieces in the blockouts (anim on parts) and the effect textures, rig.md 9 / fx.md; `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/Mesh.luau`, `assets/fx/textures/` and docs).
- Ready to merge: `be76af7` (Supply deposit variants (fx.deposit), interceptor missiles (+ mobile aliases), Meshes.textures; manifest + mesh_materials; `assets/`, `src/shared/Defs/Meshes/`, `place/`, tools and docs).
- Ready to merge: `6d79327` (Animation audit part 2: 44 meshes split into animated pieces (tracks, wheels, tail rotors, radars, trolleys, jib), re-uploaded and rigged; manifest `visualPieces` / `anim`; 13 wrecks rebuilt to match; deposits lighter; `assets/`, `src/shared/Defs/Meshes/`, `place/`, tools and docs).
- Ready to merge: `5aa87cd` (Beam shot effect M-29: beam textures, fx.md "Beam shot" timing sheet and per-faction values, `Meshes.beam` + `Mesh.validateBeam`, reference module; `assets/fx/beam/`, `src/shared/Defs/Meshes/`, tools and docs).
- Ready to merge: `0ccf6c3` (beam shot tapers to a point at the target: `tip` in `Meshes.beam`, filaments converge; fx.md values synced; `assets/fx/beam/`, `src/shared/Defs/Meshes/` and docs).
- Ready to merge: `ff6072d` (beam shot: muzzle widths within the emitter ball, impact flare 5 / 4 studs, `muzzleFlareSize` star while firing, flare `StudsOffset`; `assets/fx/beam/`, `src/shared/Defs/Meshes/` and docs).
- Ready to merge: `386e998` (beam shot: stars 6 / 8 and 4 / 5 studs, muzzle glow and filaments 1.6 / 0.9; `assets/fx/beam/`, manifest and docs).
- Ready to merge: `8fcf418` (shield honeycomb shell M-30: `assets/fx/shield/honeycomb/`, `Meshes.shieldShell`, `Mesh.validateShieldShell`, fx.md "Honeycomb shell", M-30).
- Ready to merge: `8c1281a` (beam shot holds for `beamDuration`, `Meshes.beam` `hold` replaced by `duration`; `assets/fx/beam/`, `src/shared/Defs/Meshes/` and docs).
- Ready to merge: `bb366c3` (merge of `main` cc8f02a; approvals from the user's second review: `beam`, `deposit`, the interceptors, `ord_sovereign` / `chs_warlord` (tracked, until the mech redesign); manifest only).
- Ready to merge: `f07b82f` (Commander mechs step 1: walker blockouts `ord_sovereign` / `chs_warlord`, `swing` motion in Blockout / Mesh, `stride` poses, rig.md 10, M-31; `tools/portraits.py`; `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/Mesh.luau`, tools and docs).
- Ready to merge: `f7b2654` (honeycomb shell: smaller patches, 22% of the cells, new tile ID in `Meshes.shieldShell`; `assets/fx/shield/honeycomb/`, manifest, fx.md).
- Ready to merge: `2b4dc5b` (Commander mechs step 2: meshes for `ord_sovereign` / `chs_warlord` (review; the tracked ones kept in `assets/models/<id>/tracked/`), WALKER anims, mech anchors, decorative muzzle allowed on unarmed defs (`Mesh.validate`); `assets/`, `src/shared/Defs/Meshes/`, `place/`, tools and docs).
- Ready to merge: `fb028ba` (heroic Commander mechs step 1: new blockouts, v1 moved to `Review/` and `assets/models/<id>/v1/`, the v1 meshes out of the manifest until the new ones; `src/shared/Defs/Blockouts/`, `assets/`, manifest, `place/` and docs).
- Ready to merge: `44101bf` (heroic Commander mechs step 2: meshes for `ord_sovereign` / `chs_warlord`, review, fp 2 per S-124; `assets/`, manifest, `place/`, tools and docs).
- Ready to merge: `e7f4570` (Commander mechs v3, M-33: new meshes for `ord_sovereign` / `chs_warlord` (review), v2 kept in `assets/models/<id>/v2/`, muzzles moved forward in the blockouts, `tools/mech.py`; `assets/`, `src/shared/Defs/`, `place/` and docs).
- Ready to merge: `8d8c995` (structure redesign pair 1: `ord_extractor` / `chs_extractor` at fp 2 with wrecks, back to review; `assets/`, manifest, Meshes spec sample, `place/` and docs).
- Ready to merge: `3b8c149` (structure redesign pairs 2–7: generators, solar, wind turbines, depots, Bulwark / Spike at fp 2, vehicle plants at fp 4, with wrecks, back to review; new pieces `core`, `gantry`, `trolley`, new anchors; `assets/`, manifest, `place/` and docs).
- Ready to merge: `14d7b46` (with `b515382`: structure redesign pairs 8–11, radar towers and IR SAM sites at fp 1, airfields and shipyards at fp 5, with wrecks, back to review; new converter meshes (review); new airfield anchors, shipyard nanos on their moving pieces, rig.md 8; `assets/`, manifest, `place/` and docs).
- Ready to merge: `813e5cd` (new meshes for the blockout-only T1 structures: tidal generators, sonar buoys, jammer towers, torpedo launchers, floating turrets, rearm pads, with wrecks, review; `assets/`, manifest, `place/` and docs). With it, every T1 def has a mesh.
- Ready to merge: `a7d0c1d` (the user approved every T1 structure mesh and its wreck: manifest flipped to approved; `src/shared/Defs/Meshes/`, tools and docs only).
- Ready to merge: `12009ea` (T2 air workers Zenith / Condor and ASW helicopters Tidewatch / Leech into the manifest as review; `assets/`, `src/shared/Defs/Meshes/`, `place/` and docs).
- Ready to merge: `4f87a62` (T2 meshes: amphibious tanks, anti-nukes, missile batteries, T2 aircraft, T2 ships, 24 meshes with wrecks, review; anti-nuke blockouts moved out of Pending; naval worker anchors; `assets/`, `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/`, `place/` and docs).
- Ready to merge: `37cfb7a` (key art 1 approved: the style guide `docs/art/keyart.md`, the layout and scene tools and the final layers in `assets/keyart/`; not uploaded, no manifest change; `assets/keyart/` and docs only).
- Ready to merge: `79c22b8` (key art 2 "Volley" uploaded and in the manifest as `keyArt.volley`, approved: the loading screens show it; `assets/keyart/`, `assets/models/tools/manifest.py`, `src/shared/Defs/Meshes/Registry.luau`, `tests/client/Meshes.spec.luau` and docs).
- Ready to merge: `014494d` (shield energy column and dome waves, review: `assets/fx/shield/waves/`, manifest `shieldColumn` / `shieldWave`, `Mesh.luau` validators, `tests/client/Meshes.spec.luau`, fx.md and docs; clients-B implements the look).
- Ready to merge: `81d46b2` (Aegis / Wyvern vertical-launch SAMs and Sanctum / Basilisk point defence: meshes, wrecks and blockouts, manifest `review`, MeshMaterials; `assets/models/`, `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/Registry.luau`, `place/MeshMaterials.model.json`, `.gitignore`).
- Ready to merge: `e9c6352` (shield energy v4, approved: `assets/fx/shield/waves/`, manifest `shieldEnergy`, `Mesh.validateShieldEnergy`, `tests/client/Meshes.spec.luau`, fx.md and M-34; `shieldColumn` / `shieldWave` unchanged for the client; clients-B ports v4).
- Ready to merge: `91fabf0` (shield hit patches v2, smaller and dimmer: new `hitCap` mesh and `hit` flipbook, `shieldEnergy.sizes.hitGlow` 1.6; `assets/fx/shield/waves/`, manifest, fx.md).
- Ready to merge: `05c4622` (Aegis launcher v2, six visible upright canisters, status `review`: mesh, wreck, blockout muzzle, manifest, MeshMaterials).
- Ready to merge: `1a685cd` (removes the manifest's `shieldColumn` / `shieldWave`, their validators and spec, fx.md's superseded sections, and with `f899384` their frozen data; the client reads `shieldEnergy` since C-187).
- Ready to merge: `7c71d43` (shield hits v3: 16-frame flipbook, `timing.hitLife` 0.42, the idle honeycomb off in fx.md and ShieldPreview; merge this tip, not `961fd00` alone: that commit dropped `hexGrid`, which the client spec still checks, so `hexGrid` stays for now).
- Ready to merge: `aca7bfa` (removes `shieldEnergy.hexGrid`: the idle honeycomb is off and the client spec no longer checks it).
- Ready to merge: `799407a` (key art 3 "Converging": final layers uploaded, `keyArt.converging` approved; `assets/keyart/`, `src/shared/Defs/Meshes/Registry.luau`).
- Ready to merge: `cc5ac3d` (T1 defence blockouts for S-157: `ord_sentry_tower`, `chs_guard`, `ord_beamer`, `ord_overwatch`, `chs_twin_guard`, `chs_geryon`, `ord_gauntlet`, `chs_talos`, `chs_bulwark` with a `retracted` pose; prefixed muzzles like `laser_muzzle1` are attachments; meshes after the user's look review).
- Ready to merge: `2f48424` (Bulwark blockout v2, a stacked tower after the user's reference; `retracted` pose updated, no `shellL` / `shellR` lids).
- Ready to merge: `fbe9923` (Bulwark blockout v3: the weapons stacked, laser ring under the beam head, each turning on its own; `retracted` pose updated).
- Ready to merge: `ef1237e` (T1 defence blockouts v2 after the user's references: tall laser towers, low twin-barrel batteries; pieces unchanged).
- Ready to merge: `72b72fd` (merge of sim-A's `a5c00e1` pitch pieces with the matching blockouts: Sentry / Guard `barrel`, Overwatch / Twin Guard / Geryon `mount`, Bulwark `laser_mount`; integrate this commit, not `a5c00e1` alone; also `2fd0e93`, the artillery `raised` poses).
- Ready to merge: `056e644` (the user's approvals: the T2 batch (aircraft, anti-nukes, missile batteries, amphibious tanks, air workers, ASW helicopters) and their wrecks; key art 1 uploaded as `keyArt.commanders_stand`, approved; `assets/keyart/`, `assets/models/tools/manifest.py`, `src/shared/Defs/Meshes/Registry.luau`).
- Ready to merge: `08b9889` (the Canyon's baked ground, C-167 / M-35: `ground.canyon` and `groundMaterials` in the manifest, review; `assets/maps/`, tools, manifest, `place/MeshMaterials.model.json`, docs).
- Ready to merge: `1e1e96b` (pending blockouts for sim-A's request: `ord_pharos`, `chs_scylla`, `ord_empyrean`, `chs_rookery`; `src/shared/Defs/Blockouts/Pending/` only). Moved into the main registry once the defs are in main.
- Ready to merge: `64c664a` (Coastline's baked ground, C-167 / M-35: `ground.coastline` in the manifest, review; `assets/maps/`, manifest, `place/MeshMaterials.model.json`, the ground tools for the other maps, `grass` / `rock` / `sand` textures, M-35).
- Ready to merge: `890e53a` (Ridgeline's baked ground, C-167 / M-35: `ground.ridgeline` in the manifest, review; `assets/maps/`, manifest, `place/MeshMaterials.model.json`).
- Ready to merge: `2fd756b` (Twin Lakes's baked ground, C-167 / M-35: `ground.twin_lakes` in the manifest, review; `assets/maps/`, manifest, `place/MeshMaterials.model.json`).
- Ready to merge: `f3410f8` (Crossroads's baked ground, C-167 / M-35: `ground.crossroads` in the manifest, review; `assets/maps/`, manifest, `place/MeshMaterials.model.json`).
- Ready to merge: `1c1fa3c` (Normandy's baked ground, C-167 / M-35: `ground.normandy` in the manifest, review; `assets/maps/`, manifest, `place/MeshMaterials.model.json`, `road` / `leafy` textures; merge after the four before it).
- Ready to merge: `5fd2a55` (S-157 tower meshes with wrecks, review: `ord_sentry_tower`, `chs_guard`, `ord_beamer`, `ord_overwatch`, `chs_twin_guard`, `chs_geryon`, `ord_gauntlet`, `chs_talos`, `chs_bulwark`; `assets/models/`, manifest, `place/MeshMaterials.model.json`).
- Ready to merge: `0305a40` (the S-166 blockouts registered now their defs are in main, and hand-made blockouts for `ord_shepherd` / `chs_griffin`; `src/shared/Defs/Blockouts/` only. The client's icon specs fail for the four S-166 defs until B's icon tiles land; not from this commit).
- Ready to merge: `6e07762` (T2 ship hull redesign with lofted hulls for all 9 T2 ships, the T1 corvettes Envoy / Barracuda and the naval workers Tidewright / Wrecker, those four back to review; Shepherd / Griffin meshes; wrecks for the six capital ships and the Commander mechs; the status table in models.md; `assets/models/`, manifest, `place/MeshMaterials.model.json`, docs). Nothing new draws in game: every changed unit is `review`.
- Ready to merge: `adfb7ec` (wrecks for ten more meshes, queue item 6, review; `assets/models/*/export_wreck`, manifest, `place/MeshMaterials.model.json`).
- Ready to merge: `55947ca` (wrecks for nine more meshes, queue item 6, review; `assets/models/*/export_wreck`, manifest, `place/MeshMaterials.model.json`). The WIP commits before it (59b4e0d, 089559e) only add unreviewed T2 build scripts, wreck exports and two tool tables that nothing in the game reads.
- Ready to merge: `eb247e1` (T2 structure meshes at the S-104 sizes, queue item 5: 26 new builds for the advanced factories, extractors, fusion plants, T2 sensors, jammers and defences, all `review` (nothing new draws in game); `assets/models/`, manifest, `place/MeshMaterials.model.json`, docs; includes the merge of `main` fb13cd4). Their wrecks follow.
- Ready to merge: `c79300b` (wrecks for every mesh that had none, queue items 5/6: the 26 T2 structures' and 30 more, all `review`; the regenerated status table, item 7; `assets/models/*/export_wreck`, manifest, `place/MeshMaterials.model.json`, docs). The WIP commit before it (7a1c5b1) only adds the T2 wreck exports.
- Ready to merge: `b59167b` (F18 blockouts, includes `f7de8cb`: the six T2 defences as real towers, the six T1 laser and beam towers (Sentry / Guard, Overwatch / Geryon, Beamer / Twin Guard) taller and heavier; `src/shared/Defs/Blockouts/`, docs. The T2 defences draw these in game at once, their meshes being `review`; footprints, pieces and build pads unchanged).
- Ready to merge: `3af3b38` (S-181 blockouts in `Blockouts/Pending/`, not registered, so nothing changes in game; `Blockout.isAttachmentPiece` takes `laser_l_muzzle`-style names; new `Blockouts/Bots.luau`). Safe to merge before or after S-181; the registration follows once S-181 is in `main`.
- Ready to merge: `6f40874d` (F6: `ord_advextractor` / `chs_advextractor` blockouts at the T1 extractor's size, 16 studs, as upgraded T1s, the user's call; supersedes `a506c48a`. Goes with sim-A's change of both defs to footprint 2).
- Ready to merge: `6c93cc9e` (the 19 S-181 blockouts registered: bot labs with build pads and nano emitters, bots, Fatboy, Tzar, Centurion, Dragon, Liche; includes the merge of `main` 7c933c5c).
- Ready to merge: `4f6f268f` (bot legs renamed to the Commander walker pieces `thighL` / `shinL` / `footL` + R, swing X, for client-B's walk; Skitter `thighFL`… / `shinFL`…; includes `6c93cc9e`).
- Ready to merge: `e97ce583` (F27: the unit death explosion template `ReplicatedStorage.Vfx.Death`, `place/Vfx.model.json` and its generator; adds a `Vfx` entry to default/serve/build.project.json — the live sync needs one `rojo serve` restart).
- Ready to merge: `1a586bf4` (F18 / F6 meshes: the six T2 defences as towers, the six T1 laser / beam towers taller, the advanced extractors at the T1's size, with wrecks; the four S-181 bot labs' meshes; all `review`, so nothing new draws in game; `assets/models/`, manifest, `place/MeshMaterials.model.json`, docs).
- Ready to merge: `19588182` (S-181 meshes: the 15 units' meshes and all 19 wrecks, `review`, so nothing new draws in game; includes `1a586bf4`; `Mesh.isAttachmentPiece` matches Blockout's; manifest, `place/MeshMaterials.model.json`, status table, docs).
- Ready to merge: `8e0c2db5` (the Lakelands' ground mesh, `ground.lakelands`, `review`, so the client keeps drawing it its own way until approved; `assets/maps/lakelands`, the bake's `coarsen` option, manifest, docs; includes the merge of `main` 9d7da230).
- Ready to merge: `641b3ee0` (the user approved the F18 towers, F6 advanced extractors and S-181 units with their wrecks, and the Lakelands ground: they now draw in game; manifest, docs; includes the merge of `main` e43b5726).
- Ready to merge: `11bdc65a` (the user approved the last 40 meshes in review with their wrecks: every mesh is approved, so no unit draws as a blockout any more; manifest, docs).
- Ready to merge: `145e7b32` (the user approved the 42 older wrecks: every wreck is approved; `ground.lakelands.step = 8` in the manifest for client-B's C-235; manifest, ground.py, docs).
- Ready to merge: `d0383a51` (the last four meshes with wrecks: ord_pharos, chs_scylla, ord_empyrean, chs_rookery, `review`, so their blockouts draw until approved; every def now has a mesh; `assets/models/`, manifest, `place/MeshMaterials.model.json`, docs).
- Ready to merge: `2ab88c4d` (the user approved the last four meshes and wrecks: all 182 units draw their approved meshes; manifest, docs; includes the merge of `main` ae6356ad).
- Ready to merge: `7f5e8ebe` (the playtest-3 and handover summary at the top of this file, for the move to another account; `assets/models/tools/rig_batch.py` and `contact_sheet.py` move in from the session scratchpad; status table refreshed (203 defs, all approved); `_VfxProto.luau` deleted, it was untracked and identical to `place/Vfx.model.json`. Docs and tools only, nothing in game changes).

## Requests

1. **Sim session (unit defs):** `ord_halo` and `chs_hornet` list a `turret` piece that nothing turns; their weapon turns `launcher` with no pitch. Suggest `turretPiece = "turret", pitchPiece = "launcher"` so the launcher turns on its pedestal and elevates. The blockouts already work either way (M-3). Low priority. **Done (sim, S-64): both now turn `turret` and pitch `launcher`.**
2. **Client session (after the Lancer is approved):** bring `ReplicatedStorage.Models.ord_lancer` from "FTGG Art" into the game place (copy the Model; its MeshParts and SurfaceAppearances reference uploaded assets, so it works in any place of the same creator). `Render/Models.luau` already prefers it over the blockout. Note for the model pool: the Lancer's pieces are turned 180° inside the model (rig script, M-13), which the pool doesn't see as long as it uses `RootOffset` and `Motor6D.Transform` only (rig.md 2, 5).
3. **Sim session → models (S-64, faction-only units; the user asked for blockouts):** two new T2 ground units, defs in `src/shared/Defs/Units/`:
   - `ord_warden` **Warden** (Order deployable gun): `HEAVY_TRACKED`, footprint 1; pieces `base`, `spades` (stabilizer spades / outriggers that lower when deployed), `turret`, `barrel`, `muzzle`. State bits DEPLOYED 32 / DEPLOYING 64 (4 s each way) say when to lower or raise the spades. Order style: a long gun on a low fortress-like hull.
   - `chs_minotaur` **Minotaur** (Chaos siege ram): `HEAVY_TRACKED`, footprint 2 (the biggest Chaos tank); pieces `base`, `ram` (a heavy front ram / demolition arm, the charge's muzzle), `turret`, `barrel`, `muzzle`. Chaos style: rugged, slab armor, a short heavy gun.
4. **Models → sim session (remaining faction units, M-17):** pending blockouts exist for `chs_locust` (T1 ground, footprint 1, pieces base / turret / barrel / muzzle), `chs_cyclops` (T2 ground, footprint 2, same pieces), `ord_barrier` (T1 structure, footprint 1, base) and `ord_citadel` (T3 structure, footprint 3, base / turret / barrel / muzzle / launcher / muzzle2 / radar), in `src/shared/Defs/Blockouts/Pending/`. When you add those defs, use these IDs, footprints and pieces or note what differs, and I will adapt and register them. (Warden and Minotaur: done against the S-64 defs, request 3.)
5. **Sim session → models (S-75, the user's task 10):** the defs for request 4 now exist with your IDs, footprints and pieces unchanged: `chs_locust` (vehicle plant), `chs_cyclops` (`HEAVY_TRACKED`, advanced vehicle plant), `ord_barrier` and `ord_citadel` (its gun turns `turret` / `barrel`, fires from `muzzle`; its IR SAM turns `launcher`, fires from `muzzle2`; `radar` is a static mast). Please move them up from `Blockouts/Pending/` and register them. Nothing deploys or animates beyond turret and barrel. **Done (models, 2026-10-22): moved up and registered, unchanged.**
6. **Models → client session (Warden deploy look, review 2026-10-22):** the user asked that packed and deployed read apart at 220 studs. The blockout `ord_warden` now has client-only pieces (`visualPieces`): `jacks` (four legs and pads), `shieldL` and `shieldR` (front shield wings hinged at the hull's front corners), and a bigger `spades` plate with hazard stripes that face up only when it lies on the ground. Please make `PieceScripts/ord_warden.luau` match the review pose in `Blockouts/Pending/Registry.luau` (`poses.ord_warden.deployed`): `spades` x +100° (was 55°), `base` y −0.4 (as now), `jacks` y −0.5 (pads to the ground), `shieldL` y +90° and `shieldR` y −90° (the wings close in front, leaving a slot for the gun), and the gun resting at +12° pitch while deployed and idle; packing reverses all of it.
7. **Models → client session (Reckoning, review 2026-10-22):** the silo top is now two split blast doors: `hatch` (the def's piece, left door, hinged at its outer edge, pivot x −6.05) and `hatch2` (client-only, right door, pivot x +6.05). To open for a launch they turn about Z: `hatch` z +110°, `hatch2` z −110° (nothing animates them yet; for whenever the silo gets a piece script).
8. **Sim session → models (S-79, client request 40; the user's shield decision):** two shield dome generators, T2 structures, footprint 2, pieces `base` and `core` (the field emitter; the client's ShieldFx draws the dome itself, radius 120 for Order and 80 for Chaos, round the generator's base): `ord_phalanx` **Phalanx** (Order: a fortress-like emitter, plates and a sensor ring) and `chs_carapace` **Carapace** (Chaos: rugged, slab armour round an exposed core). Nothing animates. **Done (models, 2026-10-22, `f4a6eac`): both registered with the def pieces unchanged; `core` is the glowing part, and an `Attachment` named `beam` on it marks where the shield beam starts (fx.md). The pending `ord_shieldgen` is removed. The Carapace is a skid platform with a tripod cage round an exposed glowing core (Chaos reads light, M-14) rather than slab armour.**
10. **Sim session → models (S-96, client request 43; the user asked for T2 defenses):** four T2 structures, footprints per def:
   - `ord_radiance` **Radiance** and `chs_inferno` **Inferno**: beam towers (BAR's Pulsar), footprint 2. Pieces `base`, `shell` (the armored housing the gun retracts into when switched off), `turret`, `barrel`, `muzzle`. Order's is a tall precise emitter; Chaos's a squatter, cruder one.
   - `ord_lumen` **Lumen** and `chs_hailstorm` **Hailstorm**: flak towers, footprint 1. Pieces `base`, `turret`, `muzzle`, `muzzle2`, and `muzzle3` on the Hailstorm (3 guns).
9. **Models → client session (BAR models in the game place, clients-B's question 2026-10-22):** this stream only works in "FTGG Art", so it doesn't edit the game place. Build the models at startup from the mesh manifest instead (`src/shared/Defs/Meshes/Registry.luau`, rig.md section 7), only for `status = "approved"` entries (the `review` ones keep their blockout):
   - `AssetService:CreateMeshPartAsync` for each piece and glow part `mesh`;
   - size, CFrame (turned 180° about Y), joints, `RootOffset`, `TeamColor` tags, `SurfaceAppearance`s and glow settings as in rig.md 7;
   - put the result in `ReplicatedStorage.Models.<id>`.
   `InsertService:LoadAsset` on the raw Open Cloud `model` gives unrigged MeshParts at 100× scale (`rig_model.luau` normalizes them in "FTGG Art"), so the manifest route is simpler. Alternatively the user can copy the rigged `ReplicatedStorage.ModelReview.<id>_bar` models from "FTGG Art" into the game place's `ReplicatedStorage.Models` (rename to `<id>`).
- Ready to merge: `b81fab52` (S-192: the Plains' ground mesh, `ground.plains`, `review`, so the client keeps drawing it its own way until approved; `assets/maps/plains`, ground.py's `ground` merge, manifest, docs).
- Ready to merge: `0602e909` (G5 / S-194: the Commanders' `torso` is a def piece in both blockouts; both meshes get an `emitter` Attachment at the build lens for the laser (`anchors.py`, no re-upload); `Mesh.validate` accepts an Attachment as a def piece; manifest).
- Ready to merge: `5dcbaa65` (G6: Supreme Strait's ground mesh, `ground.supreme_strait`, `step = 8`, `review`, so the client keeps drawing it its own way until approved; `assets/maps/supreme_strait`, ground.py's `crag_sub`, manifest, docs).
- Ready to merge: `413b45e1` (the user approved the Plains ground: `ground.plains` now draws in game; Supreme Strait stays `review`, not approved; manifest, docs).
- Ready to merge: `92e2a5f2` (Supreme Strait's ground re-baked from the S-196 layers in BAR's colours, approved by the user: `ground.supreme_strait` draws in game; three new ground materials `strait_sand` / `strait_grass` / `strait_rock` in the manifest and `place/MeshMaterials.model.json`; ground.py `palette` / `crag_slope` / water previews. Matches main's current, unflipped map; the flipped re-bake for dcc4dc0f follows).
- Ready to merge: `52bec9e9` (Supreme Strait's ground re-baked for sim-A's flipped compile, approved; includes the merge of m-sim-2 `dcc4dc0f`, so it needs protocol 40 (S-197 / S-198) and the flip on main first: integrate after them, and after `92e2a5f2`).
- Ready to merge: `d2399d26` (S-197 map features: `fx.feature_tree` (4 variants) and `fx.feature_rock` (3 variants) with `variants` lists like `fx.deposit`, `review`; `assets/fx/features/`, manifest, `place/MeshMaterials.model.json`; on top of `035eff8a`, so after protocol 40 too).
- Ready to merge: `e12e8660` (the user approved the S-197 map features: `fx.feature_tree` and `fx.feature_rock`, every variant, now draw in game; includes `d2399d26` and the merge of `main` 2c36d0da; manifest, docs).
- Ready to merge: `49251fea` (fresh colour maps for feature_tree_2 and feature_rock_1, which failed to load in FTGG Match (B's C-247 check); the new ones load in both places; manifest, `place/MeshMaterials.model.json`).
11. **Models → 2D session E (S-213 id swap, 2026-10-29):** the old T2 tank `chs_juggernaut` is now `chs_goliath` (retired), and the T3 bot `chs_korgoth` is now `chs_juggernaut`. Please swap the 2D sources to match: the icon sheet source and unit pictures for the old tank go under `chs_goliath`, and the bot's go under `chs_juggernaut`. Right now `chs_goliath` has no icon tile, so IconAtlas.spec and Icons.spec fail. B still owns `render.mjs`, IconAtlas and the UI wiring, and reruns the render.
- Ready to merge: `6bff49ab` (the user approved the six older grounds: `ground.ridgeline`, `ground.coastline`, `ground.twin_lakes`, `ground.crossroads`, `ground.normandy` and `ground.canyon` now draw in game, so every named map's ground is approved; manifest, docs).
- Ready to merge: `41fa7420` (the Experimental Gantry blockouts `ord_gantry` / `chs_gantry`, each with a `buildpad` and spray emitters (Order nano1..6, Chaos nano1..8), registered; contains the merges of m-sim-2 `94380002` and `8a111001`, so integrate after those. Unblocks B's Nanoframe spec; `src/shared/Defs/Blockouts/` only besides the merges).
- Ready to merge: `20b58b9b` (fix for `e0b61a1e`: registers `ord_gantry` / `chs_gantry` in `Blockouts/Registry.luau`; `41fa7420` added the blockout files but not the registry lines, so B's Nanoframe spec still failed. `src/shared/Defs/Blockouts/Registry.luau` only).
- Ready to merge: `fc1383d0` (playtest-3 units, S-209: 21 hand-made blockouts registered and BAR-style meshes with wrecks, all `review` in the manifest, so the game draws the blockouts until approved; contains `20b58b9b` and the m-sim-2 `94380002` / `8a111001` merges. `assets/models/`, `src/shared/Defs/Blockouts/`, `src/shared/Defs/Meshes/`, `place/MeshMaterials.model.json`, tools, docs).
- Ready to merge: `3f450b39` (the user approved the 21 playtest-3 meshes with their wrecks (`a54a4bdd`): they draw in game; the Mammoth's muzzles renamed `muzzle1` / `muzzle2` as attachments in its blockout and mesh, for sim-A's `2ef1569d` (merged here, so integrate after it); manifest, docs).
- Ready to merge: `a1030665` (S-213 id swap, for sim-A's `748ddf25` (merged here): `chs_korgoth` becomes `chs_juggernaut`, the old tank `chs_juggernaut` becomes `chs_goliath` in the Blockouts and Meshes registries, asset folders, manifest and MeshMaterials; asset IDs unchanged. `test_client` fails 3 tests until B adds the icon and piece-script swap, so integrate through B's tip).
- Ready to merge: `2174e58f` (E-11 build-menu unit pictures, contains `60527a80` and `e3e353bb`; team paint baked in the faction colour: `assets/models/tools/pictures.py` and `pictures_defs.luau` render each unit's picture and team mask into `debug_out/pictures/` for 2D session E; `portraits.py` importable, and its glow-colour lookup fixed. Tools and docs only, nothing under `src/`).
12. **Models → client session (explosions, missiles, ground marks, 2026-10-30; `39aa66e8`):**
   - **Done (clients-B, 2026-10-30): C-267 `5cfcd875` wires Nuke, StructureDeath and MissileExhaust (DgunBolt now held too), honours GroundOnly, and scales attachment positions and acceleration. C-268 `3c137805` draws the blast marks, templated ground bursts included. Checked in Studio on Coastline.**
   - **Re-check the D-Gun first.** Until now its templates reached the place with no `EmitCount` / `EmitDelay` / `Continuous` (a Rojo quirk, fixed here). Your `Vfx.follow` keyed on `Continuous` never saw it.
   - **New names:**
     - add `nuke = "Nuke"` to `Vfx.TEMPLATE_NAMES`, played at `b.radius / 150` as now;
     - play `StructureDeath` instead of `Death` for a structure's death;
     - hold `MissileExhaust` on the missile's exhaust with `Vfx.follow` / `Vfx.release`, at the style's scale (1 / 2.3 / 4.5). When it's there, hide the built-in `Flame` trail and `Puffs`; the `Smoke` trail can stay. `Launch` is already a name.
   - **Template handling:**
     - honour `GroundOnly` on template emitters (skip them for a burst in the air, like the built-in `ground` specs);
     - scale template Attachment positions by the burst's scale. The missile's shock diamonds, the structure's chain blasts and the debris arms are authored at scale 1.
     - Optional: scale template `Acceleration` by sqrt(s), like the built-in effects.
   - **Blast marks:** replace the dark `Scorch` disc with two Decals on its top face, the way BeamShots does: a soot decal (`blast_mark_a` or `blast_mark_b` at random, at a random yaw) and the glow decal on top (`Color3` about (1, 0.55, 0.18) × 2.2, fading over ~2 s).
     - The soot stays `SCORCH_SECONDS` as now. The size can stay 5.6 × scale, or a little more.
     - A nuke can lay one big mark over its crater too.
     - **Uploaded with the user's approval (2026-10-30):** `Meshes.textures.blastMarkA` / `blastMarkB` (soot) and `blastMarkGlow`.
     - Checked in FTGG Art (`debug_out/screens/vfx_blast_marks_studio.jpg`):
       - set the part's `CastShadow = false`, or the decals throw blob shadows;
       - lift the part about 0.6 stud over the ground height. At +0.08, Terrain's sand ripples hid it.
13. **Models → 2D session E (E-11 pictures, 2026-10-30):** the full set is re-rendered with the user's notes: no fog, more glow, more colour, and team paint in the faction colour. That's all 197 in `debug_out/pictures/` (contact sheet `debug_out/screens/pictures_all_v3.png`). Please repack the sheets from them. Uploading the repacked sheets needs the user's approval.
14. **Models → 2D session E (S-219 transport pictures, 2026-10-30):** the user approved the four transports' meshes and wrecks. Their build-menu pictures are rendered in the E-11 look: `debug_out/pictures/ord_courier.png`, `chs_buzzard.png`, `ord_ark.png`, `chs_charon.png` (contact sheet `debug_out/screens/transports_pictures.png`). Please add them to the packed sheets. Uploading the sheets needs the user's approval.
- Ready to merge: `39aa66e8` (explosions, missiles, blast marks: new `Death` / `StructureDeath` / `Impact` / `Nuke` / `MissileExhaust` / `Launch` templates in `place/Vfx.model.json`. It also fixes two template bugs: the orientation values, and attributes now typed so Rojo keeps them, which also fixes the D-Gun templates. Also the `assets/fx/scorch` blast-mark decals (not uploaded) and `tests/client/VfxTemplates.spec.luau`. `place/`, `assets/`, `tests/client/` and docs only; B wires the new names, request 12).
- Ready to merge: `51db9785` (D-Gun VFX templates `DgunBolt` / `DgunMuzzle` / `DgunHit` / `DgunEnd` in `place/Vfx.model.json`, built by `assets/fx/vfx/build_vfx.py`; contains `e958c1c8`, the E-11 pictures with no fog and more glow and colour. `place/`, `assets/` and docs only; B wires the names into Render/Vfx).
- Ready to merge: `2d0afbe4` (the user approved uploading the blast marks: `Meshes.textures.blastMarkA` / `blastMarkB` / `blastMarkGlow` in the manifest, for B's request 12; includes `39aa66e8`. `assets/fx/`, `src/shared/Defs/Meshes/Registry.luau`, docs).
- Ready to merge: `e1fac1fb` (S-219 transports Courier, Buzzard, Ark, Charon: blockouts registered, meshes and wrecks uploaded with the user's approval and in the Meshes registry and `MeshMaterials`, in review. Contains sim-A's defs `e7765af2`, so integrate it after B's merge that brings them with E's icons. Checks here: `lune run test` 625/625, build 894 scripts / 2509 requires; `lune run test_client` 343/345, the two failures being the missing icons for the new units (IconAtlas, Icons), which arrive with B's merge).
- Ready to merge: `005afd1f` (the user approved the S-219 transports and their wrecks: `APPROVED` / `APPROVED_WRECKS` in `manifest.py`, Meshes registry regenerated; includes `e1fac1fb`, so the same order: after B's merge with E's icons. Checks: test 625/625, build 894 / 2509; test_client 343/345, the same two icon tests until B's merge).
- Ready to merge: `fe4ed1d2` (S-224 Goliath re-modelled from scratch, approved by the user: new mesh and wreck uploaded, rigged and in the Meshes registry and `MeshMaterials`, new blockout with the same pieces and `muzzle`; includes `abf29eb2` and `a224cbb5`. Checks: test 627/627, test_client 352/352, build 898 scripts / 2524 requires).
- Ready to merge: `4f4edffb` (S-227 scrap heaps: `Meshes.fx.scrap_heap`, variants 1..4 by footprint 1, 2, 3, 4+, uploaded with the user's approval, status review until approved; for B's C-278. Also batch 1's 31 blockouts, unregistered until sim-A's defs (`6c9268f2`). Checks: test 634/634, test_client 352/352, build 933 scripts / 2545 requires).
- Ready to merge: `2dc8b00f` (S-230 batch 1: the 31 blockouts registered and fitted to sim-A's defs `67a74543`, which it contains; includes the heaps `4f4edffb`. Checks: build 997 scripts / 2707 requires; test_client 347/352: the hover factories' def pieces (sim-A's fix: drop buildpad / nano1..3 from their `pieces`, 2 tests) and B's icon codes for the new ids (3 tests). Fast suite 651/651 before the fit).
