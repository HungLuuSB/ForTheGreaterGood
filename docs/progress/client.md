# Client progress

Progress of the client stream: `src/client`, `src/shared/Defs/Blockouts/`, Studio-only place content and `docs/contracts/`. Branch `m-client-foundation`, worktree `FTGG-client`. This stream is the only one using the Studio connection. The headless simulation (`src/server`, the rest of `src/shared`, `.lune/`) is the sim stream's area; see [`sim.md`](sim.md).

Decisions: `C-1`, `C-2`, ... in [`../decisions/client.md`](../decisions/client.md).

## Summary (night run, 2026-10-21)

**All nine queued tasks are done, committed, pushed and in the merge queue below.** Tasks 1–5 were verified in Studio playtests; Studio then closed its place (the instance reports "Place is not open"), so tasks 6–9 are verified headless only: Lune specs against the real sim, plus headless renders of the real client's view (C-15). Nothing was done to repair Studio.

| Task | What | Commit | Verified |
|---|---|---|---|
| 1 | Rojo live sync (`lune run serve` + `rojo serve serve.project.json`), in-Studio test entry | `f815a5d`, `7bbaa7b`, `89e7db1` | Studio: 34 specs, 253 passed |
| 2 | Contracts `rig.md`, `client-state.md` | `a96cca2` | — |
| 3 | Blockout generator; Lancer and Ravager; generic blockouts for all 123 defs | `2062b10` | Lune + Studio (Edit) |
| 4 | Client foundation: client World, NetIn, interpolation, model pool, RTS camera, minimal server entry | `df29a2d` | Studio playtest: tanks drive and fight from the real sim |
| 5 | Selection, control groups, smart right-click, Shift queue, line move; protocol 6 join | `f52bf53` | Studio playtest with real mouse / keyboard input |
| 6 | Build placement ghost: snapping, validity tint, rows | `47aaa63` | Lune (client check = server check on 750 spots) + headless render |
| 7 | Combat effects with guide 15.3's caps | `afe8aea` | Lune (shells within 0.5 studs of the server) + headless render |
| 8 | Strategic zoom icons | `b8405ff` | Lune + headless render |
| 9 | Placeholder minimap and resource bar | `508b215` | Lune + headless image (GUI not rendered) |

**Tests:** `lune run test_client`: **7 specs, 31 passed, 0 failed**. `lune run test` (sim): 36 specs, 270 passed. `lune run build`: 304 scripts compile, every require resolves.

**Images** (`debug_out/screens/`, gitignored): `task4_brawl_topdown.png`, `task5_selection_orders_topdown.png` (from live playtest dumps); `task6_build_ghost_valid.png`, `task6_build_ghost_invalid.png`, `task7_combat_effects_headless.png`, `task8_strategic_icons_headless.png`, `task9_minimap_resourcebar_headless.png` (headless). Studio's own `screen_capture` only ever showed the GUI over a black 3D view (`task4_studio_capture_black3d.jpg`), so no true screenshot exists yet.

**When Studio is back (first thing to do):** play the `duel`, `march` and `build` profiles in `src/roblox/MatchConfig.luau` (`ACTIVE`) and check what the headless runs can't: the build ghost's Instances and keys (B, R, Esc), particles and effect frame cost (guide 18.2), the icon layer and the zoom switch, the minimap and resource bar layout and clicks; then take real screenshots.

**Needs your review:** camera feel, controls, visual style, UI layout, effects look, strategic zoom (section below).

**Requests for the sim session:** 5 open (section at the end): bomber `bay` pieces; formation slots, placement rules and icon numbering in Shared (the client copies them, tested equal or close). Request 2 (unit state bits) was done by S-6.

## Merge queue

- Ready to merge: `a2371cd` (CLAUDE.md: Studio is available to the client session only; the sim stays headless and is tested with `lune run test`).
- Ready to merge: `f815a5d` (task 1: Rojo live sync and the in-Studio test entry; touches `CLAUDE.md`, both project files and the skill).
- Ready to merge: `7bbaa7b` (separate `build/serve` and `build/ci` folders, `lune run serve`; touches `.lune/`, `CLAUDE.md`, the project files and the skill; C-3).
- Ready to merge: `89e7db1` (Studio check of the serve sync; polling notes in `CLAUDE.md` and the skill).
- Ready to merge: `a96cca2` (task 2: `docs/contracts/rig.md`, `docs/contracts/client-state.md`; C-4..C-6).
- Ready to merge: `2062b10` (task 3: blockout data and generator, `lune run test_client`; adds a line to `CLAUDE.md`).
- Ready to merge: `df29a2d` (task 4: client foundation and minimal server entry; touches `CLAUDE.md`, `STUDIO_HANDOFF.md`, new `.lune/render_view.luau`).
- Ready to merge: `f52bf53` (task 5: selection, orders, protocol 6 join; touches `CLAUDE.md`, new `.lune/render_scene.luau` (replaces `render_view`)).
- Ready to merge: `47aaa63` (task 6: build ghost; adds `.lune/client_demo.luau`, a line in `CLAUDE.md`).
- Ready to merge: `afe8aea` (task 7: combat effects with caps; `.lune/client_demo.luau` and `render_scene.luau` updated).
- Ready to merge: `b8405ff` (task 8: strategic zoom icons; `.lune/client_demo.luau` and `render_scene.luau` updated).
- Ready to merge: `508b215` (task 9: placeholder minimap and resource bar; touches `STUDIO_HANDOFF.md`, `CLAUDE.md`).
- Ready to merge: `002cc39` (night run summary at the top of `docs/progress/client.md`).
- Ready to merge: `90c387d` (client uses Shared PlacementRules and Net/Icons).
- Ready to merge: `5563c15` (step 2: readable shells, effect diagnostics (C-18)).
- Ready to merge: `6cff90b` (line-move goals from Shared Formation).
- Ready to merge: `142b5c6` (step 3 and 5: range rings, target line, BAR controls; `.lune/render_scene.luau` draws ring arcs).
- Ready to merge: `3e2066b` (step 4: tasks 6-9 re-verified in Studio; Esc removed).
- Ready to merge: `b207ca1` (extractor placement on deposits (C-22)).
- Ready to merge: `486fc51` (queued builds (C-23); request 7: build ranges).
- Ready to merge: `2fa0039` (Health and build bars (C-24)).
- Ready to merge: `9abe9b0` (Exact target line from S-16 (C-25)).
- Ready to merge: `f5740e0` (Explosion delay after a hit (C-26)).
- Ready to merge: `a602502` (Shells from the barrel tip (C-27)).
- Ready to merge: `9254e74` (Task 1: terrain from the map layers (C-28)).
- Ready to merge: `f95efcc` (Smooth range rings (C-29)).
- Ready to merge: `49e983c` (Task 2: piece scripts and the Juggernaut (C-30)).
- Ready to merge: `e125dee` (Task 3: air and naval rendering (C-31)).
- Ready to merge: `dfdd0e7` (merge of `main` into this branch: resolves the `docs/progress/client.md` conflict with f5b8093 by keeping request 6 done and requests 7 and 8; test_client, test and build pass).
- Ready to merge: `4a98d03` (Task 4: fog of war in 3D (C-32)).
- Ready to merge: `9c6d2d1` (Juggernaut follows the server arm timing (C-33)).
- Ready to merge: `cc217a1` (merge of `main` with S-19 and S-20 into this branch; clean, test_client, test and build pass).
- Ready to merge: `6093f19` (Task 5: deaths and wrecks (C-34)).
- Ready to merge: `db75cf4` (Own team's Eco record (protocol 9)).
- Ready to merge: `b2d2095` (merge of `main` with S-21, protocol 9, into this branch; clean, test_client, test and build pass).
- Ready to merge: `ec6488d` (Playtest profiles (juggernaut, air, naval, radar)).
- Ready to merge: `7f38c53` (global sim speed for debugging, C-35; C-26 timing fix).
- Ready to merge: `89740cf` (smooth missile paths, C-36).
- Ready to merge: `6161783` (SAM test scene, slowed flight tests, fog darkening off, C-37).
- Ready to merge: `5d6c9e9` (curved missile paths, aircraft markers, clicking models, C-38).
- Ready to merge: `1b2866a` (merge of `main` with S-23, S-24 and the C-36, C-37 integrations; test_client 78, test 299, build passed).
- Ready to merge: `4a014e9` (missile sensor view, C-39).
- Ready to merge: `3671f2b` (recognizable missiles: model, smoke trail, exhaust glow, C-40).
- Ready to merge: `d8f67eb` (request 13 for the sim session: IR SAM misses; docs only).
- Ready to merge: `272b106` (merge of `main` with S-25 and the C-38 integration; test_client 81, test 299, build passed).
- Ready to merge: `486d468` (SAM scene reworked: bigger map, Thorns east, one Falcon flying in).
- Ready to merge: `b3c1d19` (range rings of known enemy defenses, C-41; request 13c).
- Ready to merge: `849486c` (merge of `main` with the final AI level report; test_client 82, test 299, build passed).
- Ready to merge: `f9cc4ed` (seeker cone in the missile sensor view, C-42).
- Ready to merge: `7c2180c` (SAM scene: the Falcon circles at x = 300).
- Ready to merge: `64472f6` (camera follow, C-43).
- Ready to merge: `d44e70c` (request 13d for the sim session: gradual decoy turn; docs only).
- Ready to merge: `7a7e2bd` (merge of `main` with S-26, S-27, S-28, protocol 11; with `8ca419a` test_client 85, test 304, build passed).
- Ready to merge: `8ca419a` (client missiles steer with the shared guidance, C-44; take it with `7a7e2bd`, or the client lags the server's guidance).
- Ready to merge: `4346a86` (move lines last until the unit arrives, C-45).
- Ready to merge: `2d244af` (missiles past the map's edge, C-46).
- Ready to merge: `d39ec8e` (SAM scene on flat:256).
- Ready to merge: `58187a7` (log C-45, C-46; requests 14-16 for the sim session).
- Ready to merge: `927a141` (detailed combat effects with ReplicatedStorage.Vfx templates, C-47).
- Ready to merge: `a8d794e` (merge of `main` with S-29..S-32) with `a9ef27b` (spec threshold); test_client 92, test 313, build passed.
- Ready to merge: `91a79a1` (aircraft crash, countermeasures by equipment, C-48; requests 17-19).
- Ready to merge: `37c6142` (airsam test profile: planes and helicopters against 5 SAMs).
- Ready to merge: `1ae6176` (health bars change on the hit's tick, C-49; airsam at normal health).
- Ready to merge: `073d5e7` (missiles keep their dying target until the hit is drawn, C-50).
- Ready to merge: `b66ff70` (merge of `main` with S-33..S-40, protocol 13) with `d69e3f8` (client follows requests 14-19, C-51); test_client 97, test 325, build passed.
- Ready to merge: `5c92bb0` (crashes leave their smoke, radar SAM missiles drawn big, C-52; request 20).
- Ready to merge: `d39244e` (merge of `main` with S-41, S-42) with `54f1532` (vertical-launch steering, C-53); test_client 98, test 326, build passed.
- Ready to merge: `ad0c3b1` (request 21 for the sim session: projectiles visible regardless of sight; docs only).

## Tasks

1. Studio sync (`STUDIO_HANDOFF.md` step 1) and an in-Studio test entry for `RunAll`. **Done 2026-10-21**, see below.
2. Contracts: `docs/contracts/rig.md`, `docs/contracts/client-state.md`. **Done 2026-10-21** (C-4, C-5, C-6).
3. Blockout generator (guide 20.2), `ord_lancer` and `chs_ravager` first. **Done 2026-10-21**: data in `src/shared/Defs/Blockouts/` (`Blockout`, `Registry`, `ord_lancer`, `chs_ravager`), builder `src/client/Render/BlockoutBuilder` + `Models` (C-6, C-8). `lune run test_client`: 5 tests pass, every def gets a valid blockout. In Studio (Edit): Lancer and Ravager build with 13 parts and 2 Motor6Ds each; turret, barrel and muzzle land exactly at their blockout positions (joint rest error 0). Screenshot pending: Studio's viewport renders black (window minimized or session locked?), retried in task 4.
4. Client foundation (guide 15): world table from NetIn, interpolation, model pool, RTS camera. **Done 2026-10-21**, see below.
5. Selection (box select, control groups) and commands (smart right-click, shift-queue, line move). **Done 2026-10-21**, see below.
6. Build placement ghost with snapping and validity tint. **Done 2026-10-21** (no Studio playtest: Studio was away), see below.
7. Combat visual effects from network events, with the caps from guide 15.3. **Done 2026-10-21** (no Studio playtest: Studio was away), see below.
8. Strategic zoom icons (15.4). **Done 2026-10-21** (no Studio playtest: Studio was away), see below.
9. A minimal minimap and resource bar, marked placeholder UI. **Done 2026-10-21** (no Studio playtest: Studio was away), see below.

## Task 1: Studio sync and in-Studio tests

- **Sync:** `lune run build` once, then three watchers in the repo root: `rojo sourcemap default.project.json -o sourcemap.json --watch`, `darklua process src build/src --watch`, `rojo serve build.project.json`; connect the Rojo plugin. Studio has 263 scripts (178 Shared, 43 Sim, 41 Tests, 1 Entry), the same as the offline build. No string requires left (two in comments).
- **Test entry:** `src/roblox/RunTests.luau` → `ServerScriptService.Entry.RunTests` (C-1, C-2). From `execute_luau` (Edit): `.start(filter?)`, then poll `.status()`.
- **Result in Studio:** 34 specs, 253 passed, 0 failed (31.8 s and 33.2 s; Lune 17.6 s). No warnings from our code in Output (the Defs loader is quiet).
- **Gotcha (fixed in the follow-up, C-3):** darklua's watcher deleted the output when a source file was replaced by rename (Claude's Edit/Write tools do this) and didn't write it back.

### Follow-up: separate serve and CI folders (C-3)

Rojo's serve crashed (`change_processor.rs` line 179, "The system cannot find the path specified") after `lune run build` wiped `build/src`, the folder it was serving (I ran the build while the sync was up).

- Live sync: `lune run serve` (new `.lune/serve.luau`) keeps `build/serve/src` converted; `rojo serve serve.project.json` serves it. Two terminals instead of three: the script replaces both `darklua --watch` and `rojo sourcemap --watch`. It only writes files and removes the output file of a deleted source; it never deletes a directory.
- Offline build: `lune run build` now wipes and rebuilds only `build/ci/` (`build.project.json`, `build/ci/place.rbxl`; `check_build`'s default follows).
- Tested with the watcher running: add, in-place edit, save by rename (shell and Claude's Edit tool), delete; each synced, no directory removed. `lune run build` alongside left `build/serve` untouched (19 directories before and after). Both trees check clean: 263 scripts, 787 requires.
- Verified in Studio (2026-10-21) with `lune run serve` + `rojo serve serve.project.json`: 263 scripts, no duplicate trees; a probe module added, edited (arrived in 1.3 s, its `@shared` require resolved) and deleted, each reaching Studio. Tests: **34 specs, 253 passed, 0 failed (32.6 s)**. A poll that waits inside `execute_luau` (20 s) was dropped; plain polls work, and one can be dropped while a long test runs.
- Touches `.lune/` (`build.luau`, `check_build.luau`, new `serve.luau`), the sim stream's area, at the user's request. Session A: `lune run build` output moved to `build/ci/`.
- **Not done (handoff step 2, left for later):** the cross-runtime hash check (D51), Script Analysis pass, and the `wait_for_child` question for client requires.

## Task 4: client foundation

- **Server** (`src/roblox`, C-9): `Main.server` runs the real Sim (duel_test on `flat:48`) at 15 Hz and sends NetOut's outboxes over `ReplicatedStorage.Remotes`; `MatchConfig` holds the match. Sim step in Studio: avg 0.14-0.40 ms, peak under 1 ms with 20 tanks.
- **Client, pure** (`src/client/Core`, Lune-tested): `World` (known units, both tiers, snapshot buffers, queues for the renderer), `NetIn` (decodes every channel; drops malformed, reordered and out-of-sync records), `Interp` (render clock 2 ticks behind, lerp, 1-tick extrapolation only while MOVING), `Commands` (CAMERA, point orders).
- **Client, Roblox**: `Main.client` (wiring, version check), `Render/Ground` (map layers as 64-stud checkered tiles), `Render/ModelPool` (pool per def, team colors), `Render/UnitRenderer` (one `BulkMoveTo` per frame, turret / barrel `Motor6D.Transform` from replicated aim), `Camera` (RTS camera, CAMERA command at most 5/s), `Debug/Hud` (F3).
- **Tests:** `lune run test_client`: 11 pass. `ClientWorld.spec` runs the real sim for 300 ticks and checks the client world against the reference receiver and the sim (positions within 1/32 stud), aim and READY states, dropping of reordered and malformed messages, interpolation and the render clock.
- **Playtest (Studio, 2026-10-21):** blockout Lancers and Ravagers drive at each other and fight from the real simulation. Client at tick 112: 11 tactical units, 11 models, render 2.0 ticks behind, 0 dropped; the sides lose tanks until one is gone, then the match restarts. Proof: `debug_out/screens/task4_brawl_topdown.png` (top-down render of the live client's parts, C-10). Studio's own capture shows only the GUI over a black 3D view (`task4_studio_capture_black3d.jpg`).
- **Found on the way:** edge scrolling dragged the camera to a map corner in Studio (mouse resting on the window edge): it's off in Studio, on in live games. Tanks that drive past each other beyond sight range vanish from the client: that's fog of war working, not a bug.

## Task 5: selection and orders

- **Protocol 6 adopted first** (C-12): HELLO / WELCOME join on the Snapshot channel, REJECT handling, Eco records; the server entry re-joins players on a match restart. `ClientWorld.spec` gained a late-join test (a client joining at tick 60 rebuilds the same view) and a REJECT test.
- **Pure** (`src/client/Core`, Lune-tested): `Selection` (box, click pick, same type on screen, groups, pruning), `Orders` (smart right-click, line slots as the server assigns them, chunks of 200), `Waypoints` (what each unit was sent, for the lines), `Signal`; `src/client/Api.luau` is the UI surface from `docs/contracts/client-state.md`.
- **Roblox:** `Input/Controls` (mouse and keys, C-13), `Render/Overlay` (selection rings, order lines and dots colored by kind, right-drag preview, order flashes).
- **Tests:** `lune run test_client`: 19 pass. `Orders.spec` against the real sim: box select takes own units only; add / toggle / groups / pruning on death; right-click on an enemy queues an ATTACK on the server, on an own unit GUARD, on the ground MOVE; three Shift-queued moves end at the last point; a line move ends with every unit within 4 studs of its drawn slot; 450 units split into 3 commands.
- **Studio playtest (march profile, real mouse and keyboard input through the MCP tools):** a left-drag box selected 10 Lancers (10 rings); right-click moved them; Shift+right-click queued a second point and all 10 ended there; Ctrl+1 saved them; clicking empty ground cleared the selection; a second box took the other 40; a right-drag line move spread them along x = -20 from z -70 to 69. Image: `debug_out/screens/task5_selection_orders_topdown.png` (from the last scene dump, C-10).
- **Studio went away** at the end of task 5: the instance now reports "Place is not open". Not repaired (your rules). Later tasks continue with Lune-tested logic and are checked in Studio when it's back.

## Task 6: build placement ghost

- **Pure** (Lune-tested): `Core/Placement` (snap, the server's placement rules on client knowledge, rows; C-14); `Api` gained `state.placement` and `beginPlacement`, `rotatePlacement`, `cancelPlacement`, `updatePlacement`, `place`, `placeRow` (BUILD to the selected builders that have the structure in `buildOptions`); `Orders` encodes BUILD; order lines show BUILD in yellow.
- **Roblox:** `Render/PlacementGhost` (translucent model copy over a footprint plate, Highlight tint green / red), `Input/Controls` (B = next build option of the selected builder, placeholder for the build menu; left click places, Shift queues and keeps placing, left drag places a row, R rotates, right click / Esc cancels), the F3 readout shows the ghost's state and reason.
- **Tests:** `lune run test_client`: 22 pass. `Placement.spec`: the client check agrees with the server's planning check on 750 random spots, reason included; placing sends one BUILD and the frame appears at the ghost's snapped spot with construction started; extractors need a deposit, invalid spots send nothing, Shift keeps placing, a Shift-dragged row of solars queues after the extractor.
- **Proof (headless, C-15):** `debug_out/screens/task6_build_ghost_valid.png` (green ghost, a generator frame, a queued row of solar frames) and `task6_build_ghost_invalid.png` (red over the Command Vehicle: units in the way), from `lune run client_demo build`.
- **Not verified in Studio:** the ghost's Instances, Highlight tint and the B / R / Esc keys. `MatchConfig` has a `build` profile (Command Vehicle on `start:48`) for that playtest.

## Task 7: combat effects

- **Pure** (Lune-tested): `Core/Effects` (C-16): projectiles from SPAWN_PROJ stepped with the shared Ballistics, IMPACT / DECOYED / LOST_LOCK / homing corrections, FIRE tracers from the drawn muzzle, death bursts sized by footprint and severity, all on the render clock; caps 150 / 60 / 100 by importance. Death records now carry their tick.
- **Roblox:** `Render/Effects` (pooled projectile parts moved with one `BulkMoveTo`, tracers, flashes, particle bursts with `Emit`); `Render/UnitRenderer` keeps a dead unit's model until its death plays; `Debug/SceneDump` includes effects (`E` records over the units).
- **Tests:** `lune run test_client`: 25 pass. `Effects.spec`: client shells within 0.5 studs of the server's for 240 ticks, IMPACT ends them; events and deaths wait for the render clock; caps hold with near effects kept.
- **Proof (headless, C-15):** `debug_out/screens/task7_combat_effects_headless.png` (`lune run client_demo combat`): shells in flight between the lines, impact bursts on the Lancers, turrets on target.
- **Not verified in Studio:** the Instances, particles and frame cost of the effects (guide 18.2: 2 ms).

## Task 8: strategic zoom icons

- **Pure** (Lune-tested): `Core/Icons` (C-17): the server's icon numbering, one shape family per role, blips / tracked contacts / ghosts, sizes, draws per frame with the selection on top, the zoom switch with hysteresis.
- **Roblox:** `Render/IconLayer` (pooled screen-space frames, a triangle glyph for aircraft), `ModelPool.setVisible` hides all models at strategic zoom, `UnitRenderer` keeps computing positions while hidden.
- **Tests:** `lune run test_client`: 29 pass. `Icons.spec`: numbering equals `NetOut.iconIndex`, every def has a family, strategic records map to the right family (seen, radar blip, tracked, ghost), all 20 units of a live duel get an icon.
- **Proof (headless, C-15):** `debug_out/screens/task8_strategic_icons_headless.png` (`lune run client_demo icons`, EW scenario): own structures framed, the selected units edged white, the enemy helicopter a triangle, its jammer vehicle a square, four SAM sites remembered as ghosts.
- **Not verified in Studio:** the GUI layer, the triangle glyph in Arial, and the zoom switch feel.

## Task 9: placeholder minimap and resource bar

- **Pure** (Lune-tested): `Core/Minimap`: map and minimap coordinates, terrain tiles (4 x 4 cells, merged along rows; water, height, deposits), unit dots (unit, structure, blip, ghost, selected), the camera box, resource-bar lines (stored / storage, +income, -demand, `STALL n%` when the stall ratio drops below 1).
- **Roblox:** `UI/Minimap` (bottom left, 200 px, labelled "PLACEHOLDER MINIMAP"; dots refresh at 3 Hz; left click moves the camera, right click orders the selection, Shift queues), `UI/ResourceBar` (top center, labelled "PLACEHOLDER RESOURCE BAR"; fills turn red in a stall). Both use only the client API (C-5). The F3 readout moved below the Roblox top bar.
- **Tests:** `lune run test_client`: 31 pass. `Minimap.spec`: coordinates round-trip, tiles cover a generated map exactly once (lakes shown), dots and camera box from a live match, a full bar at the start and a `STALL` line once three factories drain the economy.
- **Proof (headless, C-15):** `debug_out/screens/task9_minimap_resourcebar_headless.png` (`lune run client_demo minimap`): supply 392 / 1.0k (+1.0 -25.7), power 231 / 1.0k (+20.0 -51.4) while three factories go up; the minimap shows the deposits, the selected Command Vehicle, its frames and the camera box. The GUI (text, layout) needs a Studio playtest.

## 2026-10-22: shared modules and projectiles

- **Screenshot check (C-10):** `screen_capture` in Edit mode is still black (only Studio's view cube draws), although the place has daylight, a sky and the baseplate in front of the camera. Proof stays on scene dumps rendered with `lune run render_scene`.
- **Shared modules:** line-move goals and waypoint reach use `Shared/Grid/Formation` (S-12). The client uses `Shared/Grid/PlacementRules` (S-9) and `Shared/Net/Icons` (S-10); its copies are gone; the agreement tests still pass (`90c387d`). Formation slots stay a copy until the sim marks them ready.
- **Projectiles (C-18):** cause 1, a stale `MatchConfig` in Studio (`build` instead of `duel`: no enemy, no shots; re-synced by a real edit). Duel diagnostics: 92 SPAWN_PROJ / 92 IMPACT received and applied in 8 s, no FIRE (both tank guns are ballistic), up to 15 shell parts and 20 flashes at once; shells were 0.45 x 0.45 x 1.1 studs for 0.05–0.13 s (cause 2: too small for the RTS camera). Now Neon shells with a short Trail, bigger muzzle flashes and impacts. Mid-fight frame: `debug_out/screens/step2_shells_midfight.png` (scene dump of the live playtest).

## 2026-10-22: range rings, target line, BAR controls

- **Range rings (C-19):** `Core/Ranges` (union of same-kind circles as arcs, polylines on the terrain) and `Render/RangeOverlay` (pooled segments, rebuilt on change at most 4 Hz, V toggles, on by default; the build ghost of a turret or SAM shows its rings too). `Ranges.spec`: overlapping circles give one closed outline with no interior arcs, separate ones stay whole, nested and identical ones vanish, kinds don't merge. Studio, 50 Lancers selected: one merged red weapon outline and one white sight outline (`debug_out/screens/step3_ranges_50_selected.png`); cost in C-19 (0.024 ms per frame when nothing changes, rebuilds 3–5 ms at most 4 Hz while moving).
- **Target line (C-20):** one unit selected → red line to its target and a red ring on it (`debug_out/screens/step3_target_line_and_rings.png`, live duel). The target is guessed from the turret aim (99.6 % equal to the server's in `Targets.spec`) until request 6 puts it on the wire.
- **Controls (C-21):** arrows / edge scroll (live) / middle-drag pan, S stop, V rings; WASD free. Studio: S stopped 50 moving Lancers and cleared their lines without moving the camera; V hid and restored the rings (a first version didn't clear them: fixed).
- **Your fog question:** units drawn as models are always VISIBLE to your ally team; radar-only contacts only ever arrive as blips (`Fog.spec`: 596 radar-blip unit-ticks without a def, 0 of 416 enemy model unit-ticks not VISIBLE on the server). In the duel all Ravagers are inside the Lancers' white sight ring (200 studs), so full models are right; that profile has no radar.

## 2026-10-22: tasks 6–9 re-verified in Studio (step 4)

All with real mouse and keyboard input through the MCP tools.
- **Effects (task 7):** duel, 8 s of fight (83 shells, up to 15 drawn at once, 20 flashes, 92 particle bursts): effects 0.135 ms per frame on average, 0.47 ms worst (guide 18.2 budget 2 ms); whole client 0.29 ms average, 1.0 ms worst.
- **Icons and zoom switch (task 8):** seven wheel notches out to 585 studs: models hidden, 20 square icons for the 20 tanks; three notches back in (385): models back, icons gone.
- **Minimap and resource bar (task 9):** a left click at minimap (0.8, 0.2) moved the camera to exactly (115.2, -115.2); a right click with five Lancers selected ordered them to (-38, 0); the bar shows the live Eco values ("Supply 966 / 1.0k +1.0 -0.0", "Power 1.1k / 1.1k +40.0 -0.0" after a generator went up).
- **Build ghost (task 6):** click the Command Vehicle, B: extractor ghost tinted red ("no deposit"); B nine more times: Bulwark ghost, "ok", with its sight and weapon rings; R turned it to -90°; right click cancelled without moving the builder; B, B, click: a generator frame rose at the ghost's snapped spot and placing ended. **Fixed:** Esc didn't cancel. Roblox reserves it for its menu (it opened); right click is the cancel now (C-21).

## 2026-10-22: extractors on deposits (C-22)

- **Your report:** extractors couldn't be placed on the golden spots. Cause: the gold you saw was the minimap's 4 x 4-cell tile (32 studs) around each one-cell deposit; nothing marked the exact 8-stud cell in 3D, and the server (correctly) needs the extractor's center on it.
- **Fix:** gold plates on the deposit cells in 3D, cell-sized squares on the minimap, and the extractor ghost snaps onto a deposit within 12 studs. Tested against the server for every deposit; in Studio an off-center aim snapped, the extractor was built, supply income +1.0 → +3.0.

## 2026-10-22: queued builds and build range (C-23)

- **Line to the rest of the queue vanished:** the 2 s idle rule wiped a builder's queue while it stood still building. Now a queued build is done when its frame starts; builders with a build next aren't idle-cleared while a frame goes up (20 s fallback otherwise). Tested against the server's queue in Lune; in Studio the line stayed through all three queued generators.
- **Queued structures** show as translucent models over a yellow footprint until their frame starts (`debug_out/screens/queued_builds_and_line.png`). Factory unit queues have no map spot: not drawn.
- **Build range:** `buildRange` is in the unit defs (sim's files): request 7 asks for about 70 % (80 → 56, 64 → 45, 48 → 34).

## 2026-10-21: health and build bars (C-24)

- **Bars** over selected, damaged and unfinished units (own and enemy): health (green → yellow → red) and, while a frame is going up, a light-blue build bar under it; one bar once finished. `Bars.spec` checks it against the real sim, including a frame under fire whose health drops while its progress doesn't.
- **Studio:** two bars on a factory frame, health tracking progress; a 35 % hit lowered health only; finished with one bar (`debug_out/screens/health_bars.jpg`). 0.019 ms per frame. `FtggDebug:Invoke("damage", id, amount)` added for this (Studio only).

## 2026-10-21: exact target line (C-25)

- The target line now uses the server's targets (S-16) for your own units instead of guessing from the turret: equal to the server's on every tick of the duel in `Targets.spec`. Allies' units (no targets on the wire) keep the guess.

## 2026-10-21: explosion delay after a hit (C-26)

- **Your duel note:** a delay between the shot hitting and the explosion. Cause: during the tick a shell hit in, it was drawn on to the server's end-of-tick spot (up to ~23 studs past the tank) and burst only when that tick ended (33 ms later on average, 67 ms at worst). Now it bursts the frame its drawn path reaches the hit point (within 8 ms in `Effects.spec`); checked live in the Studio duel.

## 2026-10-21: shells from the barrel tip (C-27)

- **Your note:** shells spawned far from the barrels. They appeared a tick's travel (~23 studs) out, measured from the hull center: the server sends a shell after its first step and launches from the unit's center. Now each shell starts a tick earlier at the server's launch point, drawn from the shooter's barrel tip, and joins the server's path within 3 ticks. Tested in `Effects.spec`; Studio duel: 101 of 101 shells left a barrel tip (`debug_out/screens/shells_from_barrels.jpg`).

## 2026-10-21: task 1, terrain from the map layers (C-28)

- The client builds Roblox Terrain from the map's height and water layers: smooth slopes between cells, rock on steep ridges, sand on shores, water up to its surface. Units, rings, bars and effects use the same surface. The sim's procedural maps draw as they are (tried on `map:coastline`, MatchConfig profile `terrain`, now the ACTIVE one).
- Terrain vs parts measured in Studio: terrain builds in ~1.3 s (0.5 s CPU, spread over frames) and draws cheaper (GPU 2.7 vs 3.4 ms) with no instances; parts build in 0.08 s but need 8,980 parts and look stepped. Terrain is the default (`debug_out/screens/terrain_coastline.jpg`; parts: `terrain_coastline_parts.jpg`).
- Units stand on the drawn terrain within 0.02 stud; deposits stay visible (gold plates over the ground); the place's own Terrain stays empty (the client's terrain isn't saved).
- Not done: units don't tilt with the slope (they stay upright).
- **Next, task 4 (fog of war), the user's idea (2026-10-21):** light points in the grid cells that brighten what you see and darken the rest, with the Lighting adjusted to match.

## 2026-10-21: smooth range rings (C-29)

- **Your note:** the rings should update faster and smoothly. They now follow their units every frame (the merged outline is still recomputed 4 times a second). Costs about 1.3 ms more per frame while 50 selected units move, nothing when they stand still (`debug_out/screens/rings_follow.jpg`).
- **Later (your note):** order lines and other markers drawn on top of the terrain instead of being hidden by hills. Planned for a later pass: draw them as always-on-top adornments.

## 2026-10-21: task 2, piece animation (C-30)

- **Piece scripts** (guide 14): `Turn`, `Move`, `WaitForTurn`, `WaitForMove`, `Sleep`, `StartThread`, `Signal` / `SetSignalMask`, hooks from the replicated aim, weapon state, MOVING bit and shots, LOD near / mid / far. Every unit's turret and barrel now run through it (default script, with recoil).
- **Juggernaut:** hand-made blockout with a turning torso and two gun arms; its script raises the arms to aim, recoils them in turn, and lowers them 3 s after it stops aiming (`debug_out/screens/juggernaut_arms_down.jpg`, `juggernaut_arms_up.jpg`).
- **Cost:** 64 animated units in a fight, 0.13 ms per frame (`juggernaut_50.jpg`).
- **Not exact yet:** the server has no rest pose or restore delay, so the Juggernaut can fire before its arms are fully up (request 8 makes the client follow the server exactly).
- Studio-only helpers: `FtggDebug:Invoke("spawn", defId, player, x, z, heading, count, spacing)` on the server; `FtggClientDebug:Invoke("camera", x, z, distance)` and `Invoke("anim")` on the client.

## 2026-10-21: task 3, air and naval rendering (C-31)

- **Aircraft** fly at their replicated altitude; jets bank into turns, helicopters tilt and spin their rotors (wound down when landed) (`debug_out/screens/air_helicopters.jpg`, `air_jet_bank.jpg`).
- **Ships** sit in the water; **own submarines** are drawn just under the surface; **enemy submarines** appear only as sonar contacts, a hollow ring icon (`naval_ship_sub_sonar.jpg`).
- Playtested with the new `ew` MatchConfig profile (the sim's `ew_test`; its helicopters are shot down within ~30 s, so extra aircraft were spawned) and on Coastline's sea with spawned ships and submarines. MatchConfig is back on `terrain`.

## 2026-10-21: task 4, fog of war in 3D (C-32)

- **Light fog (your idea, as in Astra Force's write-up):** the scene is darkened and a point light per 32-stud cell lights what your units see, fading in and out (`debug_out/screens/fog_lights.jpg`).
- **The write-up's limit, measured:** Roblox stops rendering point lights a few hundred studs from the camera: lit at 320 studs of zoom, gone at 470 (`fog_lights_culled_470.jpg`). Our tactical zoom goes to 480, so beyond 330 the fog switches to dark plates over unseen ground with normal lighting (`fog_overlay_far.jpg`).
- **Radar contacts** pulse on the ground in the dark (`fog_radar_contact.jpg`); **ghost structures** stay drawn where last seen, faintly glowing (`fog_ghost.jpg`).
- The client works out what your team sees exactly like the server (tested cell for cell). Cost: 0.02 ms per frame for the fog code; GPU +1.6 ms with the light fog; 60 fps.
- **Known gaps:** units never seen in the camera use a typical sight range for their icon, and allies' units don't count yet (request 9).

## 2026-10-21: task 5, deaths and wrecks (C-34)

- **Deaths by severity:** a death that leaves a wreck shakes briefly and becomes a charred wreck of the unit (`debug_out/screens/deaths_wrecks.jpg`); a big overkill flings the turret and other pieces up and away under the explosion and leaves nothing (`deaths_fling.jpg`). Same rule as the server for when a wreck exists.
- **Gap:** the client only learns of wrecks from deaths it saw, and never of a wreck being reclaimed, so wrecks stay until the match restarts (request 10).

## 2026-10-21: global sim speed (C-35)

- In a Studio playtest: `-` slower, `=` faster (0.1×, 0.25×, 0.5×, 1×, 2×, 4×), `P` pause / resume; the F3 readout shows the speed. A profile can start at another speed with `speed = 0.25` in `MatchConfig`. Everything simulated slows together; camera and UI stay real-time; a pause freezes the picture exactly (`debug_out/screens/sim_speed_quarter.jpg`).
- Also fixed: a just-launched shell on a short shot could burst up to 0.9 tick late (C-26 timing with the C-27 barrel-tip offset).

## 2026-10-21: smooth missile paths (C-36)

- **Your note:** missiles bounced and zig-zagged. Causes: the client steered at the target's newest position without the server's lead, and every server correction (every 5 ticks) or decoy turned or moved the drawn missile at once. Now it steers like the server and eases from the old course to the new one. Worst jump in a frame: 27.7 studs before, 2.5 after (Lune), 5.3 in Studio.
- **Still:** missiles chasing a target you only see on radar drift between corrections (the client doesn't know where the target really is); request 11.

## 2026-10-21: SAM test scene, slowed flight tests, fog off (C-37)

- `ACTIVE = "sam"`: your radars cover the map, 4 Falcons (5× health) circle over 4 enemy IR SAM sites that keep firing (`debug_out/screens/sam_profile.jpg`). Missiles launch along the launcher's aim until the sim adds vertical launch (request 12).
- `sam`, `air` and `naval` start at 0.25× speed (`-` / `=` / `P` still change it).
- The fog-of-war darkening is off for now (`FogOfWar.ENABLED`); radar contacts and ghosts still show.

## 2026-10-21: curved missile paths, aircraft markers, clicking models (C-38)

- **Missile zig-zag:** missiles were drawn straight within each tick and turned at its end (up to 10.7° corners every tick), and frequently corrected missiles trailed an old course. They now follow a smooth curve through each tick and converge after corrections. At 0.25× in Studio: worst 2.2° of turn in a frame.
- **Aircraft icon, health bar, selection ring and lines** now sit at the aircraft, not at twice its altitude or on the ground under it (`debug_out/screens/air_select_ring_bar.jpg`).
- **Clicking a unit's model** selects it (right-click targets it), wherever it is drawn.

## 2026-10-21: missile sensor view (C-39)

- **N** shows what each homing missile is doing: its predicted path for the next second (green = it will hit, orange = it will miss), the point it steers at (yellow), its target's centre (red), the fuse zone around the target, the predicted closest approach (magenta), and a label with guidance, lock, target, distance, time to go and predicted miss vs fuse. Corrections and decoys flash as short fading lines (`debug_out/screens/c39_missile_view_sam.jpg`).
- Predictions run the client's copy of the server's guidance with the target flown straight on, so they are close for a second or so and spread when the target turns.

## 2026-10-21: recognizable missiles (C-40)

- Missiles are now small models (body, nose, fins) with a flickering exhaust glow, a short flame and a grey smoke trail that widens behind them and fades after the missile is gone. IR missiles have a dark seeker nose, radar missiles a white radome; radar SAM missiles are bigger with thicker, longer smoke (`debug_out/screens/c40_missile_model_closeup.jpg`, `c40_missile_smoke_launch.jpg`).

## 2026-10-21: SAM scene reworked

- `sam` is now on a bigger map (`flat:160`): the 4 Thorns stand on the east side, and one Falcon (5× health) starts on the west side out of their range and flies over them (spawn entries take `moveTo`). Your radars still cover the map (`debug_out/screens/sam_east_falcon_inbound.jpg`).
- Later the same day: the Falcon now flies to x = 300 instead of 420 and circles there, just west of the Thorns and inside the map (at 420 its circle ran past the east edge). Studio: it circles between x ≈ 110 and 500 (`debug_out/screens/sam_falcon_circles_300.jpg`).

## 2026-10-21: enemy defense ranges (C-41)

- Enemy defenses you have seen (or can identify on radar) show their weapon range: dark red for ground weapons, violet for anti-air. Seen-before ones keep the ring as ghosts. Factories don't get one, and unknown radar blips don't either (their type isn't known). V hides all rings (`debug_out/screens/c41_enemy_sam_rings.jpg`).

## 2026-10-21: seeker cones (C-42)

- The missile sensor view (N) now draws each guided missile's seeker cone out to its lock range: cyan while its target is inside the cone, red when it is outside (IR 60°, radar 70° off the nose; command-guided missiles have none). The label adds the target's angle off the nose, e.g. "34° / 60° off". In the `sam` scene most locked missiles turn out to have their target behind them after a miss, which is request 13c (`debug_out/screens/c42_seeker_cone.jpg`).

## 2026-10-21: camera follow (C-43)

- **T** (or the "Follow (T)" button next to the minimap) makes the camera follow the first selected unit, or with nothing selected the missile nearest the middle of the screen; press again to stop. Aircraft and missiles stay in the middle of the screen at their altitude, the camera never ends up below a climbing missile, and it may follow a missile up to 400 studs past the map's edge. Panning stops it, zooming doesn't; when the target dies or the missile ends, the camera stays there (`debug_out/screens/c43_follow_falcon.jpg`, `c43_follow_missile.jpg`).

## 2026-10-21: protocol 11, move lines, missiles past the edge, a longer SAM map (C-44 – C-46)

- Merged `main` with the sim's new missile guidance (S-27: proportional navigation, seeker cones), decoy bend (S-28) and sight / wreck records (S-26). The client's missiles now steer with the same shared code, so the drawn missiles stay within a few hundredths of a stud of the server's (C-44); in the `sam` scene Thorns now hit 90% of the time (`debug_out/screens/c44_pn_missiles_long_map.jpg`). Fog and wrecks don't use the new records yet.
- **Move lines** no longer vanish after 2 s: the server never sets the MOVING bit, so the client now tells from position updates whether a unit is moving; an aircraft's line lasts until it reaches its circle (C-45, `debug_out/screens/c45_falcon_move_line.jpg`). Asked the sim to set the bit (request 14).
- **Missiles past the map's edge** explode where they are instead of on the edge (C-46). Positions past the edge can't be sent yet (request 15).
- **`sam` scene** is now on the largest map (2048 studs): the Falcon starts far west and flies ~1,500 studs in. A longer Thorn range and bigger blast are request 16 (weapon defs are the sim's).

## 2026-10-21: detailed combat effects (C-47)

- **Explosions** now have a fireball, sparks, smoke, and on the ground a dust ring and a scorch mark; their size follows the weapon's blast radius, so the bigger Thorn blast (request 16) will show bigger. **Gunshots** flash at the muzzle with a puff of smoke, tracers fly as glowing streaks and spark on hits. **Missiles** leave in a launch cloud, trail billowing smoke, and decoyed ones show falling flares (`debug_out/screens/c47_*.jpg`).
- Effects slow down and freeze with the sim speed, so paused playtests can be inspected.
- **Your own effects:** save an effect as `ReplicatedStorage.Vfx.Impact` (or `Death`, `MuzzleFlash`, `Hit`, `Launch`, `Decoy`, `Flare`, `Chaff`) and it replaces the built-in one, e.g. one made with VFX Studio. Give each ParticleEmitter an `EmitCount` attribute (optional `EmitDelay`); C-47 lists the rest.

## 2026-10-21: aircraft crash, countermeasures, merge of S-29..S-32 (C-48)

- **Aircraft fall out of the sky** when they die in the air: jets dive and roll, helicopters spin down, burning and trailing smoke, and explode where they hit the ground; they leave no wreck (`debug_out/screens/c48_jet_falling.jpg`, `c48_crash_explosion.jpg`). Asked the sim not to make air wrecks at all (request 19).
- **Countermeasures follow what the aircraft carries:** a jammer laser for aircraft with DIRCM only (Falcon, Archon, Guardian), flares dropped from the aircraft for those with flares (Wasp, Manticore), chaff against radar missiles (`c48_dircm_laser.jpg`). Request 18 asks for the exact one on the wire.
- **Deaths and effects** now slow down and pause with the sim speed.
- **Moving an aircraft to a point inside its circle** still doesn't work: the server counts it as arrived and circles from where the jet is. That is request 17 (high priority); the client's line will follow the fix.

## 2026-10-21: air raid on a SAM belt (`airsam` profile)

- New test profile `airsam` (set `ACTIVE = "airsam"` in `src/roblox/MatchConfig.luau`): on the largest map (2048 studs, 0.25x), your 2 Falcon jets, 2 Archon fighters and 3 Guardian helicopters (3x health) start far west and fly east into 5 Chaos SAM systems: 3 Thorn IR sites in front, 2 Wyvern long-range radar SAM sites behind. 4 radars cover the map and a fusion reactor powers them and the aircraft's DIRCM jammers (without it power stalls at once and DIRCM never recharges). Studio: SAMs launch at the jets and helicopters across the belt, missiles get jammed (DIRCM) and aircraft go down (`debug_out/screens/airsam_engagement.jpg`, `airsam_dircm_jam.jpg`).

## 2026-10-21: health bars and hits (C-49)

- **Health drops with the hit now:** bars used to drop about 2 ticks before the missile or shell that caused it was drawn arriving (half a second at 0.25x); they now change on the hit's tick.
- **"The plane takes no damage":** it did, but `airsam` gave the aircraft 3x health and the wire can't show health above a unit's normal maximum, so bars stayed full until two-thirds of it was gone. `airsam` now uses normal health; the `sam` profile's Falcon still has 5x.
- A message asking sim-A to do requests 17 and 18 expired undelivered (that session holds cross-session messages); they stand in the request list below.

## 2026-10-21: missiles on dying aircraft (C-50)

- **"IR no lock" just before a kill:** the client learned of the aircraft's death about 2 ticks before it drew the missile arriving, removed the aircraft, and the missile lost its target and flew past; then the explosion and the death played. The dying aircraft now stays the missile's target until its death is drawn, so the missile flies into it and explodes there.
- **Missile damage varies on purpose:** SAM missiles burst next to the target, and the damage falls off with how close they got (a Thorn missile: 200 at the hull, 100 at 5 studs). Jammed or decoyed missiles do nothing.

## 2026-10-21: requests 14-19 done by the sim; client follows (C-51)

- Merged `main` with the sim's answers to requests 14-19 (S-33, S-38), move states, cancel, carriers, terrain types and amphibious units (S-34..S-40), protocol 13.
- **Moving a jet to a nearby point works now:** the server flies it to the point (or, for a point inside its turn circle, to its closest approach) and then circles it; the move line goes exactly then (`debug_out/screens/c51_jet_move_line.jpg`).
- **Flares, chaff or DIRCM** are now the one the server says won, not a guess.
- **Thorn SAMs** reach 420 studs with a 12-stud blast; the rings, seeker cones and explosions follow the new numbers.
- Missiles that reach the map's edge now burst there on the server, so the client's edge workaround (C-46) is gone.
- Not used yet: terrain types (ground colour by sand / rock / road), the CANCEL command, carriers, move-state buttons, the sight and wreck records.

## 2026-10-21: crashes leave their smoke, big radar SAM missiles (C-52)

- **Crashed aircraft** no longer vanish the moment they hit the ground: they explode and keep falling through it out of sight for 3 seconds, so their smoke trail fades in the air instead of disappearing with them (`debug_out/screens/c52_crash_smoke_stays.jpg`).
- **Radar SAM missiles** (Wyvern, Gorgon, Aegis, Seraph) are drawn about 2.3x the size of IR ones, with a heavier, longer plume, and their explosions are drawn 1.8x bigger (`c52_radar_sam_missile.jpg`).
- **Vertical launch for radar SAMs** and a bigger radar SAM blast radius are server changes: request 20 for the sim session.

## 2026-10-21: vertical-launch radar SAMs (C-53)

- Merged `main` with the sim's vertical-launch radar SAMs (S-42): Wyvern, Gorgon, Aegis and Seraph missiles now leave straight up, pitch over onto their target and dive in, with a 20-stud blast. The client steers its copies the same way, so they stay within a few hundredths of a stud of the server's (`debug_out/screens/c53_vertical_launch.jpg`).
- You only see a launch if your side can see the launcher: the server sends a missile once it's in your sight. In `airsam` the aircraft see the Wyverns only when they get close.

## Needs my review

- **Enemy defense rings (C-41):** dark red / violet, 0.5 studs wide, in `src/client/Render/RangeOverlay.luau`.

- **Missile look (C-40):** size 4.4 × 0.8 studs (1.3× for radar SAMs), smoke 1.1 s (1.8 s), 1 → 5 studs wide, exhaust light range 10. Values at the top of the missile section in `src/client/Render/Effects.luau`.
- **Missile sensor view look (C-39):** colors, sizes and label text in `src/client/Render/MissileView.luau` and `Core/MissileView.luau`; path length 1 s, at most 12 missiles, marks 2.5 s.

- **Camera feel:** pitch 55 degrees, zoom 30-900 studs (wheel x1.15), pan speed 1.1 screen heights/s, rotation Q/E limited to +-45 degrees, edge scroll off in Studio. Values in `src/client/Camera.luau`.
- **Controls (C-13, answered: C-21):** BAR style now: arrow keys, edge scroll (live), middle-drag, S stop, V range rings, WASD free. Earlier: WASD / arrows pan, middle-drag pan, wheel zoom, Q/E rotate; left click / drag select (Shift add, Ctrl toggle), double-click same type, right click smart order, right-drag line move, Shift queue, Ctrl+1..9 / 1..9 groups (double tap jumps), X stop, F3 debug readout. S can't be stop (camera pan).
- **Visual style:** blockout Lancer (low, light grey, blue glass) and Ravager (tall dark iron, rust, orange visor); faction palettes in `Blockouts/Blockout.luau`; team colors (blue, red, ...) in `Render/TeamColors.luau`; ground as a green 64-stud checkerboard. See `debug_out/screens/task4_brawl_topdown.png`.
- **UI layout (placeholder):** resource bar top center (440 x 48), minimap bottom left (200 px), F3 debug readout top left below the Roblox buttons; all labelled as placeholders.
- **Build ghost:** B cycles the selected builder's options as a stand-in for the build menu; Shift both queues and keeps placing (BAR style); the facing doesn't change square footprints but turns the model.
- **Effects look:** shells as small glowing slugs, impact and death flashes in orange with a particle puff, white tracers, muzzle flashes; colors and sizes in `src/client/Render/Effects.luau`.
- **Strategic zoom:** switches at 480 studs (back at 420); icon shapes and sizes in `src/client/Core/Icons.luau` and `Render/IconLayer.luau`. Answered: keep sending the camera (C-17).
- **Health and build bars (C-24):** 4 px health bar, 3 px light-blue build bar under it, 18–90 px wide, over the unit; shown for selected, damaged and unfinished units only. Sizes and colors in `src/client/Render/HealthBars.luau` and `Core/Bars.luau`.
- **Terrain colors and materials (C-28):** Roblox Grass on open ground, Rock where steeper than ~50°, Sand on shores and under water, default Terrain water color; no custom material colors (that would change the place's Terrain settings). Rules in `src/client/Core/Terrain.luau` (`STEEP`, `SHORE`), materials in `Render/Terrain.luau`.
- **Juggernaut's animation feel (C-30, C-33):** arms hang at -65°, rise at the server's 80°/s, hold 3 s after the target is gone, recoil 0.8 stud in turn; the timing is the server's (S-20, `chs_juggernaut_cannon`), the recoil and model are the client's (`src/client/Core/PieceScripts/chs_juggernaut.luau`, `src/shared/Defs/Blockouts/chs_juggernaut.luau`).
- **Aircraft and naval look (C-31):** jet bank up to 60°, helicopter bank 20° and nose-down 12°, rotor 4 turns a second; ships 0.8 stud into the water, own submarines 2.5 studs under it; sonar contacts as hollow rings. Values in `src/client/Core/Attitude.luau` and `Core/PieceScripts/Default.luau`.
- **How fog of war looks (C-32):** near (≤ 330 studs): darkened scene (ColorCorrection, Lighting brightness 0.6, darker ambient) with a point light per 32-stud cell (brightness 1.4, range 40, 12 studs up, 0.4 s fade); the light grid shows as a soft checker. Far: dark plates (8, 10, 18) at transparency 0.4 over unseen ground, faint seams. Radar contacts as pulsing team-colored discs, sonar contacts larger and paler; ghosts glowing blue-grey at 0.7 transparency. Values in `src/client/Render/FogOfWar.luau` and `Render/Contacts.luau`.
- **Deaths and wrecks (C-34):** shake 0.4 s; flung pieces 1 s, up to ~7–11 studs; wrecks charred (75 % to dark brown-black, corroded metal), turrets askew, tilted and sunk a little. Values in `src/client/Core/Deaths.luau` and `Render/Deaths.luau`.
- **Order feedback look:** green selection discs under units, order lines colored by kind (move green, attack red, guard blue, repair yellow, fight orange, patrol light blue), a fading disc where an order lands.

## Requests for the sim session

21. **Projectiles visible regardless of sight, without revealing the shooter (the user, 2026-10-21; high priority):** "Only render the projectile, not revealing the shooters; if the shooter is cloaked and they decide to shoot, they switch out of cloak mode and reveal themselves." Today SPAWN_PROJ, homing corrections and IMPACT reach a player only in its ally team's sight (D99, contract section 7), so missiles from a site you can't see appear mid-flight and vertical launches (S-42) are never seen leaving. Please:
    - **Projectiles:** send SPAWN_PROJ (at launch), homing corrections and IMPACT for every projectile in the player's camera area (+ the usual margin), whatever the ally team sees. These records carry no shooter, so the shooter stays hidden; it is revealed only by the normal sight rules. Keep the camera-area limit (bandwidth), and keep `targetId` as now (0 when the team doesn't know the target).
    - **Gun shots (FIRE):** a hitscan / beam shot from a shooter the player doesn't have carries `shooterId`, which would reveal it. For those, send the start point instead (e.g. `shooterId` 0 and a start `pos`, or a FIRE variant with both ends); the client draws the tracer from it. Shots of known shooters stay as they are.
    - **Cloak (for when it is built; the guide lists a `cloaked` state bit only):** a cloaked unit that fires drops its cloak and is revealed by normal sight, so firing never stays hidden; record that in the guide's cloak section.
    - This changes the guide's fog rule (section 2, rule 6, and D99): projectiles in the camera area are exempt; please update the guide and contract section 7 with it.
    The client needs nothing for projectiles (it draws them from SPAWN_PROJ alone); it will draw tracers from the FIRE start point once the format is set.

20. **Done (S-42): radar SAM weapons have `launch = "vertical"` and `aoe` 20; the client steers them with `Guidance.vertical` since C-53.** **Radar SAMs vertical-launch, and carry heavy warheads (the user, 2026-10-21; high priority):** "SAM system with RADAR should be the long range that cover large area, it does not need to turn its turret because they launch vertically like the IRIS-T SLM launching. Missile for RADAR SAM must be way bigger than IR (they carry a lot of TNT in real life)." This makes request 12 concrete:
    - **Vertical launch** for the radar SAM weapons (`chs_radar_sam`: Wyvern, Gorgon; `ord_radar_sam`: Aegis, Seraph): e.g. a weapon field `launch = "vertical"`. Weapons fires as soon as a target is in range and locked, with no turret aim (no yaw / pitch wait, no tolerance check; the turret can stay at rest); the missile spawns at the launcher pointing straight up at its speed (or a short boost), and Projectiles steers it over toward the target at its `turnRate` (PN once it points roughly at the target, or from the start), so it climbs, pitches over and dives in. IR sites (Thorn, Vigil) keep their trainable launchers. The client needs nothing: it draws missiles from SPAWN_PROJ and steers them with `Shared/Combat/Guidance` (C-44).
    - **Heavy warhead:** `chs_radar_sam` has `aoe` 8, now smaller than the IR Thorn's 12 (request 16), so its blast and explosions are the smaller ones. Suggest radar SAM `aoe` ~20 (both factions; `edgeEffectiveness` as is), keeping damage 400. The client already draws radar SAM missiles 2.3× the IR ones and scales `..._large` impact effects 1.8× (C-52); the explosion grows with `aoe` on its own.

19. **Done (S-38): aircraft shot down in flight leave no wreck (DEATH `wreckId` 0).** **No wrecks for aircraft (C-48, the user, 2026-10-21):** "HELI/AIR death should be: they fall off the sky, crash onto the ground and their wreck explode, so air won't leave wreck." `Damage` makes a wreck for any unit dying at severity ≤ `WRECK_MAX_SEVERITY`, aircraft included, at the spot under the aircraft. The client now plays the fall and the crash explosion itself and draws no wreck for aircraft (C-48), but the server's wreck still exists (reclaimable, and WRECK records will put it on the client's map once the client reads them). Please skip `Combat.addWreck` for units of the air domain that die airborne (a landed aircraft may keep one). Medium priority.

18. **Done (S-38, protocol 13): DECOYED ends with `countermeasure`; the client draws the one it names since C-51.** **Which countermeasure seduced a missile (C-48, 2026-10-21):** DECOYED doesn't say whether flares, DIRCM or chaff won, so the client guesses from the target's equipment and EW's order (radar → chaff; IR → DIRCM if it has no flares, else flares). An aircraft with both DIRCM and flares (none today, but the defs allow it) would be drawn wrong half the time. A `cm u8` in DECOYED (1 flares, 2 chaff, 3 DIRCM), e.g. in the top bits of `decoyTicks` (15 fits in 4 bits), would make it exact; a protocol bump. Low priority.

17. **Done (S-38): jets fly to the goal and arrive within `Air.ARRIVE_RADIUS` (40) or at the closest approach; the client's move line follows since C-51.** **A jet ordered to a point inside its loiter radius never goes there (the user, 2026-10-21):** "when you click move on air plane, if the move is inside the white range, it will disappear shortly after and the plane move following its current facing direction, not the pre-defined position." In `Air.steerJet` an order whose goal is within `Air.LOITER_RADIUS` (220 studs) of the jet counts as arrived at once (`Nav.clearOrder`), and the jet starts circling the goal at 220 studs, from wherever it is: it never flies to the point, and a close order looks like nothing happened. Suggest: a new move flies to the goal until it passes within a small arrival radius (e.g. 40 studs, or the closest approach once past it), then loiters around it; the loiter stays at 220 (wider than the turn circle). The client's move line uses the arrival radius (C-45 mirrors `LOITER_RADIUS` today), so please name it (e.g. `Air.ARRIVE_RADIUS`) and the client will follow. High priority (the user asked).

16. **Done (S-33): `chs_ir_sam` range / lockRange 420, aoe 12, projectileSpeed 500; Thorn airSight 420.** **Thorn SAM: longer range, bigger blast (the user, 2026-10-21):** "increase SAM range and the IR missile explosion" (blast radius, with a matching effect on the client). `chs_ir_sam` today: `range` / `lockRange` 280, `aoe` 5 (also its proximity fuse), `terminalRange` 30. Suggest `range` and `lockRange` 420 (1.5×) and `aoe` 12 (keep `edgeEffectiveness` 0.5, or add a separate `fuseRange` if 12 should not change the fuse), maybe `projectileSpeed` up so a 420-stud shot isn't slower to arrive than today's (420 → ~500 studs/s); `chs_thorn`'s turret and targeting follow `range`. The client reads all of these from the def (rings, seeker cone length, explosion size), so nothing changes on this side. The `sam` test scene is now 2048 studs long (`flat:256`), the Thorns at x 640–800, the Falcon circling at x = 600. Unit and weapon defs are yours; high priority (the user asked).

15. **Partly done (S-33): projectiles burst on the map's edge (C-46's workaround removed in C-51); aircraft still turn back at 60 studs and may be drawn on the edge for a moment, which the client accepts for now.** **Positions past the map's edge (C-46, 2026-10-21):** wire positions are clamped to the map (`Grid.encode`), so anything past the edge reaches the client on it. Jets turn back at `Air.EDGE_MARGIN` (60 studs) but their turn carries them up to ~14 studs out (a Falcon at moveTo 420 on `flat:160`: 10 ticks out, worst 14 studs), and missiles that miss fly hundreds of studs out and self-destruct there. The client now keeps its own prediction for a projectile record on the clamp (C-46), but a unit past the edge is drawn on it and a missile chasing it steers at the clamped point. Either keep aircraft inside (turn back earlier, by about the turn radius at speed, speed / turnRate in rad/s: 260 / 1.31 ≈ 200 studs for a Falcon), or let positions past the edge on the wire (a signed offset, protocol bump). Low to medium priority.

14. **Done (S-33): the server sets MOVING; the client also keeps its position-based fallback (C-45).** **The MOVING state bit is never set (C-45, 2026-10-21):** `Schema.UnitState.MOVING` (1) is in the schema and the contract, but nothing in `src/server` writes it, so every unit looks idle on the client. Its move lines vanished 2 s after an order (the user saw it on an airplane), piece scripts never got StartMoving, and Interp never extrapolated. The client now works it out from position records (C-45), which is late by up to 2 ticks and can't tell a stop from a lost record. Please set MOVING while a unit has a movement goal or nonzero speed (aircraft: while flying, loitering included; landed: off) and clear it when it stops; it rides on the State record's dirty bit. Medium priority.

13. **Done (S-27, S-28; reported in docs/progress/sim.md); the client steers with `Shared/Combat/Guidance` since the 7a7e2bd merge (C-44).** **IR SAMs miss most crossing shots (C-39, 2026-10-21):** in the `sam` scene (4 Thorns, `chs_ir_sam`, against 4 circling Falcons) only 57 of 183 missiles hit over 2 minutes (31 %; 5 decoyed, the rest missed); hits come almost only head-on or tail-on. The missile sensor view (N, C-39) shows why: crossing shots pass 5–9 studs from the hull against a 5-stud fuse. Two causes: (a) guidance is lead pursuit with a straight-line target prediction (Projectiles: aim at where the target would be after the straight-line time to go, at `turnRate` 160°/s); against a turning jet the lead is wrong and the missile ends in a tail chase or overshoots; (b) the proximity fuse is `aoe` (5 studs from the hull), which is small next to a missile's 28-stud step per tick. Suggestions: proportional navigation (commanded turn = N × closing speed × line-of-sight rate, N ≈ 3–4, capped by `turnRate`), which handles turning targets without predicting them; and a separate fuse radius for SAMs (e.g. `fuseRange = 10`) instead of reusing `aoe`, keeping the damage falloff on `aoe`. (c) No seeker field of view: a missile that misses keeps its lock, overshoots and turns back for another pass (160°/s, a full loop in ~2.3 s) until its fuel runs out; the user saw one "lose lock, fly off and come round again" at the Falcon. Suggest a seeker cone per guided weapon (e.g. `seekerAngle = 60`° off the nose for IR, wider for radar): in the midcourse check, a target outside it breaks the lock (LOST_LOCK, the missile flies on and self-destructs at its lifetime), and nothing re-acquires. (d) **Decoyed missiles "fling to a side, then continue"** (the user, 2026-10-21): on a successful flare / chaff roll the terminal check in `EW.guide` turns the velocity by `EW.DECOY_TURN` (±60°) in one tick and clears the target, so Projectiles never steers it again; a missile at 420 studs/s visibly kinks sideways (the client eases the kink over its 5-tick blend, C-36, and is otherwise in sync, so this is the server's path, not drawing). Suggest a gradual turn toward a decoy point instead: on DECOYED keep steering for a short time (e.g. `DECOY_SECONDS = 1`) at the weapon's `turnRate` toward a fixed point where the flare or chaff was dropped, behind and below the target (e.g. the target's position minus ~1 s of its velocity, 10–20 studs lower for flares; chaff could drift with the wind side, using the same ±side roll), then fly straight to the end of its lifetime as today. Seen from above, the missile then bends off the jet's tail toward the falling flare and goes on, like a real seeker seduced by a flare. The DECOYED event could carry that point (or the client derives it from the target's state at the event tick) so the client steers it like the server instead of easing a correction; until then corrections cover it. Your call on the weapon model (guide 10.4, 11.5) and on request 11c's G limit with it. The client mirrors the guidance in `Core/Effects` (`aimFrom`, `predict`) and would follow a change (better, request 11b: a shared aim function). Medium priority; the user asked.

12. **Superseded by request 20 (radar SAMs).** **Vertical-launch SAM, IRIS-T SLM style (the user, 2026-10-21):** "the enemy will have 4 SAM systems that launch missiles vertical ... to test missile flight path". Missiles leave the launcher straight up, then pitch over toward the target (at their turnRate, or after a short boost), so the launcher needs no turret aim. E.g. a weapon field `launch = "vertical"` (Weapons spawns at pitch 90°, ready to fire as soon as the target is in range and locked; Projectiles steers from there), and a Chaos (or Order) VLS SAM site using it; the client draws it with no change (it steers like the server, C-36, once request 11b shares the aim code; until then corrections cover it). The `sam` test profile would switch its Thorns to that unit. Medium priority.

11. **(b) done (S-27: `Guidance.pn` / `lead`, used by the client since C-44); (c) answered (turnRate is the G limit at constant speed); (a) open.** **Homing missiles on the wire (C-36, 2026-10-21):** (a) homing corrections more often than every 5 ticks (`NetOut.HOMING_SYNC_EVERY`), e.g. every 2, or every tick for missiles whose target the player only has as a radar contact: the client can't steer those like the server and drifts ~7 studs (up to 35) between corrections; a correction is ~14 bytes, a few dozen missiles at most. (b) The server's homing aim (`Combat.aimPoint` with `UNIT_HEIGHT`, `DRAFT`, `SUB_DEPTH`, and the lead in Projectiles) as a shared function, so the client calls it instead of mirroring it. (c) The user asked whether missiles should have a G limit: today a missile turns at most `turnRate` degrees per second; a G limit (turn rate = G × gravity / speed) would make fast missiles turn wider. Your call (weapon model, guide 10.4). Medium priority.

10. **Done (S-26, protocol 10; reported in docs/progress/sim.md); the client doesn't read WRECK / WRECK_GONE yet.** **Wrecks on the wire (task 5, 2026-10-21):** a wreck reaches the client only as `wreckId` in a DEATH of its tactical tier. It never hears of wrecks made outside that tier or before it joined, and never of a wreck being reclaimed (so drawn wrecks stay until the match restarts, C-34). Wreck records would fix both: e.g. WRECK `wreckId u16, cell, offX, offZ, heading u8, defIndex u16` when a wreck enters the camera area (and on join), WRECK_GONE `wreckId` when it is reclaimed or leaves; a reclaim's progress could show as a shrinking wreck later. Low to medium priority.

9. **Done (S-26, protocol 10; reported in docs/progress/sim.md); the client doesn't read SIGHT_ROWS / SIGHT_CELLS yet.** **The team's sight map on the wire (task 4, 2026-10-21):** the client rebuilds its team's sight from its own units (C-32: exact while it knows their defs), but own units never seen in the camera arrive as strategic records with only an icon (their sight range is a guess), and allied players' units can't be counted (the wire doesn't say who is allied). Sending the ally team's `los` map would make the fog exact and cover allies: e.g. on the Strategic channel at sensor rate, the sensor cells that turned seen / unseen since the last send (u16 cell indices; a few dozen per update while armies move; a full bitset on join: 64 × 64 cells = 512 bytes on a 128-cell map). Alternatively own units' strategic records could carry their def index. Medium priority.

8. **Done (S-20; reported in docs/progress/sim.md); the client follows it since C-33.** **Juggernaut arm timing on the server (the user, task 2, 2026-10-21):** "raises its arms to aim, fires, and lowers them after a delay, matching the server's aim timing". Today the heavy cannon rests at pitch 0 and reaches its firing pitch almost at once, so no arm raise exists in gameplay. Please give the Juggernaut's weapon (its own weapon def, or the heavy cannon if `chs_maw` may share it) a rest pose and a hold: `turret.restPitch = -65` (arms down; `minPitch` down to -65 so it can rest there), a `pitchRate` that makes the raise cost real time (e.g. 80°/s: ~0.85 s from rest to level), and `turret.restoreDelay = 3`: after losing its target the weapon keeps its aim for that long before turning back to rest. Weapons then rest at `restPitch` instead of 0. Also add `armL`, `armR` to `chs_juggernaut.pieces` (guide 14.2: piece names come from the def; the client lists them as visual pieces until then). The client script already reads `restPitch` / `restoreDelay` and switches to the server's rates when they exist (C-30). Medium priority.

7. **Done (S-19; reported in docs/progress/sim.md):** 56, 45 and 34; nothing to change on the client. **Shorter build ranges (the user, 2026-10-22):** "the build range of the unit is so far, reduce to around 70%". Today `buildRange` is 80 (`ord_sovereign`, `chs_warlord`), 64 (the constructors: `ord_mason`, `ord_architect`, `ord_harbormaster`, `ord_tidewright`, `chs_scrapper`, `chs_forgemaster`, `chs_reaver`, `chs_wrecker`) and 48 (aircraft builders: `ord_skywright`, `ord_zenith`, `chs_condor`, `chs_vulture`). About 70 %: 56, 45 and 34. Unit defs are yours; the client reads `buildRange` from the defs, so nothing changes on this side. High priority (the user asked).
6. **Done (S-16, protocol 8; marked by the sim session); the client uses it since C-25.** State records carry `targets` (mask bit 32) for the owner's units; contract section 6. **Own units' weapon target on the wire:** the target line (C-20) guesses the target from the turret aim (99.6 % right in the duel). A `target u16` per weapon slot in State records for the player's own units (the target is always a unit the team knows) would make it exact, including before the turret has turned. A protocol bump; medium priority (the user asked for the line).

1. **Done (S-3, S-11; marked by the sim session).** Bombs have no turret, so the bombers no longer name `turretPiece`; the muzzle is their only weapon piece, and `Defs` rejects turret pieces on turretless weapons. **Bomber weapon pieces:** `chs_behemoth`, `chs_plague` and `ord_absolution` name `turretPiece = "bay"`, which isn't in their `pieces`. Either add `bay` to `pieces` or drop `turretPiece`; and maybe have `Defs.validate` check that weapon pieces exist. The client works around it (muzzle on the hull).
2. **Done (S-6), thanks.** **Unit state bits in shared:** `World.State` (MOVING, TOGGLED_ON, SUBMERGED, LANDED) is in `src/server`, which clients can't require. Please mirror it in Schema (e.g. `Schema.UnitState`) so the client decodes ENTER/State `state` without a copy. (net.md lists the values; the client copies them in `Core/World`.)
5. **Done (S-10), client switched 2026-10-22.** **Icon numbering in shared:** `NetOut.iconIndex` is copied in `Core/Icons` (tested equal). A shared function would keep one copy. Low priority.
4. **Done (S-9), client switched 2026-10-22.** **Placement rules in shared:** the client copies `Placement.snap` and the constants `LAND_MAX_SLOPE`, `WATER_MIN_DEPTH`, `RADIUS_PER_FOOTPRINT` (C-14). A shared pure `snap` + terrain check would keep them in one place. Low priority.
3. **Done (S-12; marked by the sim session).** `Shared/Grid/Formation` (`layout`, `deepestFirst`, `assign`, `SLOT_SPACING`); `Formation.spec` checks a client prediction equals the server's goals. **Formation slots in shared:** the client mirrors `Nav.slotsFor` / `Nav.assignSlots` and the constants `SLOT_SPACING`, `RADIUS_PER_FOOTPRINT` to draw where line-moved units go (C-11). A pure function in `src/shared` (layout + greedy assignment, without the open-ground filter) would let both sides use one copy. Low priority.
