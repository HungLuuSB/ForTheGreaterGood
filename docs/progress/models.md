# Models progress

Progress of the models stream: hand-made blockouts in `src/shared/Defs/Blockouts/<id>.luau` and everything under `assets/models/`. Branch `m-models`, worktree `FTGG-models`. Studio place: "FTGG Art" only (Rojo sync on port 34873). Unit defs, `src/client` and `src/server` belong to the other streams; what this stream needs from them is under "Requests" below.

Decisions: `M-1`, `M-2`, ... in [`../decisions/models.md`](../decisions/models.md). Rig and blockout format: [`../contracts/rig.md`](../contracts/rig.md).

## Summary (review batch, 2026-10-22)

Your review of the overnight batch: BAR style approved for both tanks (M-18), camouflage Lancers retired (their `ModelReview` copies removed; files kept). Every commit touches only `src/shared/Defs/Blockouts/`, `assets/`, `.gitignore` and docs. Tests at `74ef97b`: `test_client` 44 specs, 156 passed; `test` 62 specs, 386 passed; `build` 557 scripts compile, 1520 requires resolve.

| # | What | Commits | Status |
|---|---|---|---|
| 1 | Lancer color: measured side by side in Studio, then two passes (warmer, rougher paint, darker seams, more AO; then 8% lighter so it draws like its blockout) | `fe6c02a`, `1eca1d7` | The first pass is imported and draws (`debug_out/screens/bar_lancer_fix_closeup.jpg`). **The second (brightness) pass needs one more import** (`assets/models/ord_lancer/export/ord_lancer.fbx`) |
| 2 | Ravager: lighter gunmetal and edge highlight, 10% lower and narrower than the Lancer (`lib.Piece.scale`), orange accents unchanged | `fe6c02a`, `1eca1d7` | Same as 1: imported once, **its brightness pass needs an import** (`assets/models/chs_ravager/export/chs_ravager.fbx`) |
| 3 | Team color swap: runtime `BasePart.Color` on `TeamColor` parts under the color map's alpha (B's `ModelPool` already does this); method in `docs/contracts/rig.md` 6 | `fe6c02a`, `08d2da5` | Done: `debug_out/screens/team_55_close.jpg`, `team_55_220.jpg` (blue, red, green, yellow on both tanks; emissive unchanged) |
| 4 | Perf: 100 and 300 BAR tanks vs blockouts, render CPU per frame at close and normal zoom, appearance hitch | `08d2da5` | Done: no measurable render-CPU cost over blockouts; the appearance hitch is about half the blockouts' (pipeline.md). The cold first-load hitch (review 2: 320 ms) wasn't repeatable once the maps were loaded; preloading is the client's call |
| 5 | Warden packed vs deployed: jacks, shield wings, bigger hazard-striped spades, hull drop, gun raised (M-19) | `96800a0` (in main) | Done as blockout and review pose; **B's piece script needs to animate the new pieces (Request 6)**; at 220 studs the yellow spades and the front wall read, but the change is still small |
| 6 | Minotaur low, wide, front-heavy with a ram wider than the hull; Cyclops tall with a fixed 75° tube and the eye on a mast | `96800a0` (in main) | Done: `debug_out/screens/minotaur_cyclops_*.jpg` |
| 7 | Reckoning silo top: split blast doors and a hazard edge (palette key `hazard`) | `96800a0` (in main) | Done: `debug_out/screens/fix_overview_55_220.jpg` |
| Shield | Shield effect assets (Order): dome, inner dome, ring, emitter device, swirl / beam / speck / ripple textures, all white for team tint; pending `ord_shieldgen` blockout; `docs/contracts/fx.md` | `200ac59`, `08d2da5` | Done: in "FTGG Art" `ReplicatedStorage.FX.Shield`; `debug_out/screens/shield_*.jpg` |
| 8 | T1 vs T2 per role: T2 structures that didn't read as the upgrade got a signature piece (Order radome and covered dock, Chaos ski jump and giant crane, raised Bastion and Maw, wider advanced extractors); T1 sonar and jammer made | `e993e36` | Done: `debug_out/screens/tier_*.jpg`; T2 ground units compared after item 9 (`ground_t1_t2_*.jpg`) |
| 9 | Blockouts for everything still generic: T2 ground units and both commanders, T1/T2 aircraft, T1/T2 ships, the last generic structures. **All 133 defs now have a hand-made blockout** | `7506eae`, `fcc05b9`, `74ef97b` | Done: `debug_out/screens/ground_*`, `air_*`, `naval_*.jpg` |
| 10 | BAR meshes for the rest of batch 1 T1 ground units | — | Not started in this batch: next, constructors first (Mason, Scrapper) |
| 11 | BAR meshes for the most-seen structures | — | Not started |

**Needs your review:**
- No reference screenshot reached me with the shield request (not in the message or `assets/reference/`): the shield assets follow your written description.
- Shield emitter core glows Order cyan (M-16), not the team color; dome radius is B's choice (the check used R = 40). The emitter is about 4 studs across.
- Cyclops: the weapon pitches −5° to 60° from a level rest, so the tall tube is fixed and only a short cradle (`barrel`) pitches (M-19).
- `assets/reference/` wasn't gitignored before; now its images are (only `bar/README.md` stays tracked).
- Several T2 units' weapons turn `launcher` while their `turret` piece turns nothing (Seraph, Gorgon, Judgement, Hydra), like Halo/Hornet before S-64; the blockouts work either way (M-3). Your call whether to ask the sim session for `turretPiece = "turret", pitchPiece = "launcher"`.
- Aircraft and ships are blockouts in the same faction language; their proportions (fuselage 7–9 studs, footprint-3 ships 24 long) follow the generic sizes.

**Your steps:** import `ord_lancer.fbx` and `chs_ravager.fbx` (the brightness pass) so I can re-rig and re-measure them against their blockouts.

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
