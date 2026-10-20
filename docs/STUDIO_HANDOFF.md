# Studio handoff

Everything that needs Roblox Studio, in the order to do it. The headless simulation (M0–M7 sim side) was built and tested in Lune. Step 1 is done offline except its in-Studio run; nothing else below has been done yet.

State at handoff (2026-10-20, updated after round 4):
- Branch `m0-foundations`.
- `lune run test`: **30 specs, 207 passed** (branch `m-sim-polish`).
- `lune run build`: 245 scripts compile; 701 requires resolve to ModuleScripts.
- `src/client` is empty.
- No Roblox-only server code exists yet.

Read first: `CLAUDE.md` (Lune mode rules), `docs/progress/sim.md` (what exists in the simulation), `docs/DECISIONS.md` (why, D1–D109; new client decisions go in `docs/decisions/client.md`, prefix `C-`). The design guide sections are named in each step.

---

## 1. Toolchain and require conversion (blocks everything else)

Roblox can't resolve `@shared/...` aliases or relative string requires yet (see CLAUDE.md). The source keeps them, and a build step converts them (DECISIONS D84).

- [x] darklua 0.19.0 pinned in `rokit.toml`.
- [x] `lune run build` regenerates `sourcemap.json` (gitignored) from `default.project.json`.
- [x] `.darklua.json`'s `convert_require` rule:
  - `current`: path mode with `sources = { "@shared" = "./src/shared" }`, matching `.luaurc`;
  - `target`: roblox, using the Rojo sourcemap, `indexing_style = "find_first_child"`.
- [x] `darklua process src build/ci/src`, and `build.project.json` maps the same tree from `build/ci/src`. `build/` is gitignored. (The live sync uses its own copy, `build/serve/src` and `serve.project.json`; C-3.)
- [x] `rojo build build.project.json -o build/ci/place.rbxl`, then `lune run check_build` (`@lune/roblox`) checks the built place:
  - every script compiles (`@lune/luau`);
  - no string require is left (comments and strings are skipped);
  - every require expression resolves to an existing ModuleScript.
  - Verified to fail on an unconverted place (482 problems), a missing child, a require pointing at a Folder, and a syntax error.
- [x] CLAUDE.md and the skill document the build and serve commands. Keep `default.project.json` as the source tree.
- [x] **In Studio:** run `darklua process src build/src --watch` and `rojo serve build.project.json`, connect the plugin, and confirm modules require each other at runtime (step 2's test entry does that for every spec). Done 2026-10-21 (client stream): 263 scripts synced, all specs load and pass in Studio. Now `lune run serve` + `rojo serve serve.project.json` (C-3, CLAUDE.md).
- [ ] If the client gets string requires, consider `indexing_style = "wait_for_child"` for client code (replication order); the server tree is fine with `find_first_child`.

## 2. Roblox-only server root and in-Studio tests

`src/server` must stay runnable in Lune, so Roblox-only scripts need their own root, like `src/client`.

- [x] Add `src/roblox` (or a similar name), mapped to e.g. `ServerScriptService.Entry`. Exempt it from the dual-runtime rule in CLAUDE.md, as `src/client` is. (C-1)
- [x] **Test entry**: done as a ModuleScript, `src/roblox/RunTests.luau`, run through `execute_luau` (`start()` / `status()`) rather than an auto-running Script (C-2). Original plan, `RunTests.server.luau`:
  - only in Studio (`RunService:IsStudio()`), behind an attribute or a toggle;
  - collect every ModuleScript under `ServerScriptService.Tests` whose name ends in `.spec`, sorted by full name (Lune sorts paths too);
  - `require` them and pass them to `RunAll` the same way `.lune/test.luau` does;
  - print the same summary line.
- [x] Run it. Expect **27 specs, 182 passed**. 2026-10-21: **34 specs, 253 passed, 0 failed** in Studio (31.8 s; Lune 17.7 s), the same as `lune run test`.
  - `Env.isRoblox` should be true: `Profiler` then uses `debug.profilebegin`, and `Log` uses `warn` for warnings.
  - Some specs print measurements (direct-hit rates, the naval duel, EW tallies). Compare them with the Lune output in `docs/progress/sim.md`.
- [ ] **Cross-runtime hash check** (informational, DECISIONS D51): print `Sim.hash` after the `Sim.spec` 1,000-tick run and after `ew_test` at tick 600, in Lune and in Studio. Prng is pure Luau and identical; `sin`, `cos` and `atan2` come from each platform's libm and may differ. We accepted same-platform replays (guide 17.1), so a mismatch is expected and fine. Record the result in `docs/decisions/client.md`.
- [ ] Clean Output: no warnings from the Defs loader, no strict-mode type errors in Script Analysis for `src/shared` and `src/server`.

## 3. Server tick loop and network wiring (guide 3.3, 7.1, 19)

- [x] (minimal, client stream C-9: `src/roblox/Main.server.luau`) Server entry: build the `Sim` (`Sim.new` with the match seed, players, map ID and scenario) and drive it from a Heartbeat accumulator at 15 Hz. Cap catch-up (at most 2–3 steps per frame, guide 3.3). `Sim.step` never reads a clock; the entry script does.
- [x] (C-9) RemoteEvents per `Schema.Channel` (Cmd, Tactical, State, Strategic, Events, Eco, Snapshot). After each tick, send `NetOut`'s per-player outbox; messages are already chunked to ≤ 900 bytes (`Packer.chunk`).
- [x] (C-9: size cap and rate limit only) Commands from clients go to `Sim.submit(sim, playerId, payload)`. Add rate limits and size caps (guide 19) in the entry script, not in the sim.
- [ ] Player join and leave: guide 7.5 (join, reconnect, spectate) isn't implemented in the sim yet. A late joiner needs a full tactical and strategic snapshot (NetOut's `ENTER` path covers tactical units).
- [ ] Replay recording: `sim.replay` is already filled. Save `Replay.serialize` at match end. Player-facing replays store the server's sent stream (guide 17.1), so record the outbox too.

## 4. M1: map bake (guide 5.4)

- [ ] Studio bake plugin or command-bar script (not at runtime):
  - raycast each 8-stud cell for height, water depth, slope and material;
  - read supply deposits and start positions from tagged parts;
  - fill a `Layers`.
- [ ] Serialize the layers (base64 of the buffers) into a ModuleScript under `MapData/`. Add a `baked:<name>` form to `MapRegistry` that decodes it into `Layers`.
- [ ] Build `Passability` on the baked map. Check it against guide 5.5: chokepoints at least 3 cells; naval maps have connected water. Port `.lune/debug_map.luau`'s image to an in-Studio overlay or export, and compare with the place visually.
- [ ] Re-run the march tests' idea on the real map: 50 Lancers ordered across it arrive (M1 exit criterion).

## 5. M1: client (guide 7.4, 15, 17.3)

- [x] (client task 4: `src/client/Core/World`, `NetIn`) Client mirror of the tactical, strategic and state records. `src/server/Tests/Support/Client.luau` is a working reference: it decodes everything NetOut sends and keeps a view.
- [x] (client task 4: `Core/Interp`, `Render/UnitRenderer`) Interpolated rendering with a 2-tick delay (guide 7.4). Units are placeholder blockouts with the guide 14.2 piece names.
- [ ] Debug overlays, toggled by a key (guide 17.3): passability and clearance per class, quadtree leaves, flow-field arrows, sensor maps (LOS, radar, jam), unit goals and formation slots.
- [ ] **M1 exit:** 50 tanks path smoothly across the baked map; overlays show the fields.

## 6. Wire format additions (protocol bump to 3)

Projectiles and FX aren't replicated yet (D82). The sim already emits `SPAWN_PROJ`, `IMPACT`, `FIRE`, `DECOYED` and `LOST_LOCK` events.

- [ ] Add records for projectiles and impacts (guide 7.3 and 10.5's table), fire flashes, `DECOYED` and `LOST_LOCK`. Bump `PROTOCOL_VERSION` and regenerate the golden bytes in `Schema.spec`.
- [ ] Measure bandwidth again with `lune run stress` (it uses the same NetOut) before trusting it live.

## 7. Rendering, animation and UI milestones

In guide order. Each is client-only and builds on step 5.

- [ ] **M2 combat visuals:** projectiles (client-simulated from spawn records, guide 10.5), impacts, wrecks and deaths (guide 14.6), turret aim from the state records (`wYaw` / `wPitch`). *Client stream: projectiles, impacts, tracers, death bursts and turret aim done (tasks 4, 7); wrecks and death animations open.*
- [ ] **Animation system (guide 14):** piece scripts in the BAR style, the scheduler and LOD.
- [ ] **M3 economy and build UI:** *(client stream: placement ghost done in task 6, placeholder resource bar in task 9; build menu and factory queues open)*
  - resource bar with stall ratio;
  - build menu and placement ghost (validated against `Placement`);
  - factory queues;
  - reclaim cursor.
- [ ] **M4 fog and minimap:** *(client stream: camera interest sent (task 4), strategic icons with blips and ghosts (task 8), placeholder minimap (task 9))* fog rendering from the client view (VISIBLE, RADAR blips at wobbled positions, ghosts); minimap from strategic snapshots; camera interest sent as the camera command so the server's tactical tier follows it.
- [ ] **M6 air and naval visuals:**
  - aircraft altitude bands, landing on pads, rearm progress;
  - water rendering;
  - ships at the surface, submarines hidden unless a sonar contact;
  - torpedo wakes.
- [ ] **M7 EW visuals:** jam-field overlay, radar blips' wobble, flare, chaff and DIRCM effects, missile trails that veer when `DECOYED`.
- [ ] **M9 polish** (later): real models, audio, UI pass, lobby, matchmaking, tutorial, results screen.

## 8. Live-server benchmarks to repeat (M5, guide 18)

Lune numbers are in `docs/progress/sim.md` → Benchmarks. Repeat the same scenarios on a live server (not only Studio play-solo), with the MicroProfiler open (Profiler labels are `Sim.<System>`).

- [ ] **Flow fields** (`lune run bench` scenarios: open, maze, island at 256×256): one-shot time and work units per ms. Check that `Nav.PATHING_BUDGET` (36,000 units per tick) still fits the 8 ms pathing budget at Roblox speed; re-derive it if not.
- [ ] **Stress test** (`.lune/stress.luau`) at 200, 400, 600 and 800 units:
  - per-system averages and peaks against guide 18.1;
  - known peak offenders: Sensors (first full stamp, all-pairs visibility, about 21 ms against 5 in Lune) and Movement (about 13 ms against 10). Move orders were fixed in Lune (D83: worst Commands + Pathing tick about 10–13 ms); confirm live.
  - Quadtree rebuilds after structure placement still land in the next order's tick (D83 follow-up).
- [ ] **Bandwidth** per player with real clients (Lune: 21.5 KB/s total at 800 units against 35).
- [ ] Try `--!native` on hot modules (FlowField, Movement, Sensors, Passability) and Actors for pathing (guide 6, M5). Both need live measurements and couldn't be judged in Lune.
- [ ] Choose unit caps from the results (M5 exit criterion: a known cap at a stable 15 Hz on live servers).

## 9. Open items carried over

- Questions for the user are listed in the summary of each `docs/progress/` file.
- Guide 7.5 (join, reconnect, spectate) and guide 19 (anti-exploit) are server-entry work for step 3.
- Missile reload costs (guide 8.6) and flare/chaff refill costs aren't charged yet (D81). Balance is M8.
