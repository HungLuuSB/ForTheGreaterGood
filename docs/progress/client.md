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

## Needs my review

- **Camera feel:** pitch 55 degrees, zoom 30-900 studs (wheel x1.15), pan speed 1.1 screen heights/s, rotation Q/E limited to +-45 degrees, edge scroll off in Studio. Values in `src/client/Camera.luau`.
- **Controls (C-13, answered: C-21):** BAR style now: arrow keys, edge scroll (live), middle-drag, S stop, V range rings, WASD free. Earlier: WASD / arrows pan, middle-drag pan, wheel zoom, Q/E rotate; left click / drag select (Shift add, Ctrl toggle), double-click same type, right click smart order, right-drag line move, Shift queue, Ctrl+1..9 / 1..9 groups (double tap jumps), X stop, F3 debug readout. S can't be stop (camera pan).
- **Visual style:** blockout Lancer (low, light grey, blue glass) and Ravager (tall dark iron, rust, orange visor); faction palettes in `Blockouts/Blockout.luau`; team colors (blue, red, ...) in `Render/TeamColors.luau`; ground as a green 64-stud checkerboard. See `debug_out/screens/task4_brawl_topdown.png`.
- **UI layout (placeholder):** resource bar top center (440 x 48), minimap bottom left (200 px), F3 debug readout top left below the Roblox buttons; all labelled as placeholders.
- **Build ghost:** B cycles the selected builder's options as a stand-in for the build menu; Shift both queues and keeps placing (BAR style); the facing doesn't change square footprints but turns the model.
- **Effects look:** shells as small glowing slugs, impact and death flashes in orange with a particle puff, white tracers, muzzle flashes; colors and sizes in `src/client/Render/Effects.luau`.
- **Strategic zoom:** switches at 480 studs (back at 420); icon shapes and sizes in `src/client/Core/Icons.luau` and `Render/IconLayer.luau`. Answered: keep sending the camera (C-17).
- **Health and build bars (C-24):** 4 px health bar, 3 px light-blue build bar under it, 18–90 px wide, over the unit; shown for selected, damaged and unfinished units only. Sizes and colors in `src/client/Render/HealthBars.luau` and `Core/Bars.luau`.
- **Order feedback look:** green selection discs under units, order lines colored by kind (move green, attack red, guard blue, repair yellow, fight orange, patrol light blue), a fading disc where an order lands.

## Requests for the sim session

7. **Shorter build ranges (the user, 2026-10-22):** "the build range of the unit is so far, reduce to around 70%". Today `buildRange` is 80 (`ord_sovereign`, `chs_warlord`), 64 (the constructors: `ord_mason`, `ord_architect`, `ord_harbormaster`, `ord_tidewright`, `chs_scrapper`, `chs_forgemaster`, `chs_reaver`, `chs_wrecker`) and 48 (aircraft builders: `ord_skywright`, `ord_zenith`, `chs_condor`, `chs_vulture`). About 70 %: 56, 45 and 34. Unit defs are yours; the client reads `buildRange` from the defs, so nothing changes on this side. High priority (the user asked).
6. **Done (S-16), thanks; the client still guesses until it switches the target line over.** **Own units' weapon target on the wire:** the target line (C-20) guesses the target from the turret aim (99.6 % right in the duel). A `target u16` per weapon slot in State records for the player's own units (the target is always a unit the team knows) would make it exact, including before the turret has turned. A protocol bump; medium priority (the user asked for the line).

1. **Done (S-3, S-11; marked by the sim session).** Bombs have no turret, so the bombers no longer name `turretPiece`; the muzzle is their only weapon piece, and `Defs` rejects turret pieces on turretless weapons. **Bomber weapon pieces:** `chs_behemoth`, `chs_plague` and `ord_absolution` name `turretPiece = "bay"`, which isn't in their `pieces`. Either add `bay` to `pieces` or drop `turretPiece`; and maybe have `Defs.validate` check that weapon pieces exist. The client works around it (muzzle on the hull).
2. **Done (S-6), thanks.** **Unit state bits in shared:** `World.State` (MOVING, TOGGLED_ON, SUBMERGED, LANDED) is in `src/server`, which clients can't require. Please mirror it in Schema (e.g. `Schema.UnitState`) so the client decodes ENTER/State `state` without a copy. (net.md lists the values; the client copies them in `Core/World`.)
5. **Done (S-10), client switched 2026-10-22.** **Icon numbering in shared:** `NetOut.iconIndex` is copied in `Core/Icons` (tested equal). A shared function would keep one copy. Low priority.
4. **Done (S-9), client switched 2026-10-22.** **Placement rules in shared:** the client copies `Placement.snap` and the constants `LAND_MAX_SLOPE`, `WATER_MIN_DEPTH`, `RADIUS_PER_FOOTPRINT` (C-14). A shared pure `snap` + terrain check would keep them in one place. Low priority.
3. **Done (S-12; marked by the sim session).** `Shared/Grid/Formation` (`layout`, `deepestFirst`, `assign`, `SLOT_SPACING`); `Formation.spec` checks a client prediction equals the server's goals. **Formation slots in shared:** the client mirrors `Nav.slotsFor` / `Nav.assignSlots` and the constants `SLOT_SPACING`, `RADIUS_PER_FOOTPRINT` to draw where line-moved units go (C-11). A pure function in `src/shared` (layout + greedy assignment, without the open-ground filter) would let both sides use one copy. Low priority.
