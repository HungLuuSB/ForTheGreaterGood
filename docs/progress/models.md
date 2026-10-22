# Models progress

Progress of the models stream: hand-made blockouts in `src/shared/Defs/Blockouts/<id>.luau` and everything under `assets/models/`. Branch `m-models`, worktree `FTGG-models`. Studio place: "FTGG Art" only (Rojo sync on port 34873). Unit defs, `src/client` and `src/server` belong to the other streams; what this stream needs from them is under "Requests" below.

Decisions: `M-1`, `M-2`, ... in [`../decisions/models.md`](../decisions/models.md). Rig and blockout format: [`../contracts/rig.md`](../contracts/rig.md).

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

**Needs your review (queue):**
- **Eye:** at 220 studs it reads as a dark lattice with amber points; its team color sits only on the skid stripe and the panel's back, so it's weak from the game camera. Bigger skid plates if you want more team color.
- **Radar panels:** both panels' glowing edges follow the approved Oracle rule (unlit face, edge and grid). The Eye's amber edge is thicker relative to its panel.
- Fresh uploads: the Thorn first drew white (Studio failed its maps with HTTP 502 and won't retry them). Re-uploading the four maps fixed it with no restart (pipeline.md). Its `roblox_assets.json` records the re-uploaded IDs.
- Airfields: glow 2.3–2.5%, the large-building range (style guide, like the vehicle plants), not 5–10%. On a 38-stud apron, 5% would be a lit carpet. The Chaos runway is bare steel and catches the sun as bright metal at some angles; a matte surface is a one-line change if you prefer it.
- Chaos shipyard: the tower crane's counter-jib sticks out about 4 studs past the 40-stud footprint on the left (as in its blockout). It could overlap a neighbor; I can shorten the counter-jib.

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
9. **Models → client session (BAR models in the game place, clients-B's question 2026-10-22):** this stream only works in "FTGG Art", so it doesn't edit the game place. Build the models at startup from the mesh manifest instead (`src/shared/Defs/Meshes/Registry.luau`, rig.md section 7), only for `status = "approved"` entries (the `review` ones keep their blockout):
   - `AssetService:CreateMeshPartAsync` for each piece and glow part `mesh`;
   - size, CFrame (turned 180° about Y), joints, `RootOffset`, `TeamColor` tags, `SurfaceAppearance`s and glow settings as in rig.md 7;
   - put the result in `ReplicatedStorage.Models.<id>`.
   `InsertService:LoadAsset` on the raw Open Cloud `model` gives unrigged MeshParts at 100× scale (`rig_model.luau` normalizes them in "FTGG Art"), so the manifest route is simpler. Alternatively the user can copy the rigged `ReplicatedStorage.ModelReview.<id>_bar` models from "FTGG Art" into the game place's `ReplicatedStorage.Models` (rename to `<id>`).
