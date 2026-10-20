# Progress

Status of the unattended work session. A new session should be able to continue from this file alone.

## Summary (end of the second unattended session, 2026-10-20)

**Done: tasks 11–17, the M6 and M7 rules reviews, and `docs/STUDIO_HANDOFF.md`.** Branch `m0-foundations` is pushed; every task is its own commit. The headless simulation now covers M0–M7: everything except what needs Studio (map bake, client, rendering, live benchmarks).

| # | Task | Commit |
|---|---|---|
| 11 | Sensor maps, visibility levels, structure ghosts (M4) | `fb0d0df` |
| 12 | Radar wobble, jamming, stealth; fog-aware targeting (M4) | `f0e1a28` |
| 13 | Interest management and NetOut with a simulated client | `08e4ede` |
| 14 | Stress test with per-system timing and bandwidth report | `2e7925d` |
| 15 | Aircraft: jets, helicopters, ammo, rearm pads (M6) | `f0733e0` |
| 16 | Naval: ships, submarines, torpedoes (M6) | `8c6d6b2` |
| — | M6 rules review | `561d6b7` |
| 17 | Electronic warfare: guidance, burn-through, countermeasures (M7) | `2af0466` |
| — | M7 rules review (Movement regression fix) | `dccf50c` |
| — | Studio handoff checklist, final summary | (last commit) |

Earlier on this branch: M0 (`e1be1c4`–`6d79a93`), the M1 simulation side, the M2 combat core, the pathing fixes and duel reports (`bafe3b1`–`8878849`), and M3 economy and construction (`3c27b99`–`1b17519`).

**Tests:** `lune run test` gives **27 specs, 182 passed, 0 failed** (about 7 s). This session added Sensors, Fog, NetOut, Air, Naval and EW specs. Every new mechanism was mutation-checked: each deliberately broken version was caught.

**Benchmarks and bandwidth** (Lune; details under Benchmarks):
- **Stress test, 800 units:**
  - average tick 12.1 ms, p95 20.4, max 95, against a 66.7 ms tick;
  - no system over budget on average;
  - peak offenders: Sensors (17 ms against 5) and Movement (11.6 against 10). The 82 ms Commands spike on move orders was fixed in round 4 (D83): the worst move-order tick is now about 10 ms.
  - This PC got about 1.6× slower after the reset: the task-14 commit measures 12.2 ms here, against the 7.28 ms recorded at the time.
- **Bandwidth:** worst 21.5 KB/s per player at 800 units (tactical 6.6, strategic 6.9, state and events 8.0) against 35.
- **Flow fields** (after the bucket queue): open 28 ms, maze 18 ms, island 4.3 ms one-shot. Sliced at 36,000 work units per tick they finish in at most 4 ticks.

**Results:**
- **Fog:** artillery direct hits 87% with a spotter versus 20% on radar.
- **Air:** a Falcon kills an incoming Wasp in 22.9 s, never drops below minimum speed, circles, runs dry, rearms (120 ticks at full economy, more than 3× on a stall) and returns.
- **Naval:** ships and subs never leave the water. A sub is HIDDEN without sonar and never better than a SONAR contact with it. Only torpedoes engage subs, and torpedoes die at the shore. A Crusader sinks a Lamprey in 8.5 s and keeps 1960 / 2600 HP.
- **EW:**
  - an Aegis never launches at a jammed Wasp at 550 or 250 studs, though it sees it, but does at 150 (inside the 210-stud burn-through);
  - mid-flight jamming raises `LOST_LOCK`;
  - DIRCM decoys 25 of 40 single IR missiles but only 14 of 80 in salvos of 4 (66 hit);
  - a stalled DIRCM never recharges;
  - EW scenarios replay exactly.

**Decisions:** D65–D82 in `docs/DECISIONS.md` (this session). The ones that need your call are below.

**Round 4 (your answers to the six questions above): all done** (details under *Round 4* below).

| # | Answer applied | Commit |
|---|---|---|
| 1 | COMMAND guidance: live launcher + target VISIBLE, checked every tick; immune to jamming and countermeasures | `929b308` |
| 2 | Flare/chaff refills cost supply, spread over the rearm | `b10a701` |
| 3 | SAMs prefer lockable targets, 1.25× switch margin; jets now spawn flying (bug found by the test) | `6ba564e` |
| 4 | Naval units and ASW helis detect submerged subs within 40 studs; Tidewatch / Leech placeholders | `93df08e` |
| 5 | Move-order spike: profiled, planning sliced into the pathing budget; worst move-order tick 91 → 10 ms at 800 units | `0556c9e` |
| 6 | Offline Roblox build: darklua `convert_require`, `rojo build`, `lune run check_build` (482 requires resolve) | `8b62a50` |

Tests now: **27 specs, 188 passed, 0 failed**.

**Open points** (no decision needed now):
1. **Quadtree rebuilds after structure placement** (D83 follow-up): `Nav.terrainChanged` drops all quadtrees, so the next order rebuilds one in its tick (10–17 ms on 256×256). The fix is an incremental quadtree update.
2. **Sensors** is now the top per-tick peak (14–22 ms against 5 at 800 units: the first full stamp and all-pairs visibility), then Movement (10–13 against 10).
3. **Studio:** only the in-Studio run of step 1 remains; then step 2 (Roblox-only root and the in-Studio test entry).

---

## How to continue

- Branch: `m0-foundations` (pushed to `origin`). Run `lune run test` from the repo root; everything must pass before starting the next task.
- **Next:** wait for answers to the questions above. Everything left for the milestones needs Studio; follow `docs/STUDIO_HANDOFF.md` in order. Headless work that could still be done without Studio: M8 roster and balance (placeholder defs exist for guide 13's ground, air, naval and SAM roles), the Commands slot-assignment peak, and the guide 7.5 join/reconnect snapshot logic.
- Rules: `CLAUDE.md`, the `ftgg-roblox-dev` skill and the design guide (`docs/For_The_Greater_Good_Design_Guide.md`).
- Unattended-session rules (from the user):
  - After each task passes the tests: commit, push, and update this file.
  - When something is unclear, decide, log it in `docs/DECISIONS.md` and continue.
  - Stop only if a test can't be made to pass, or a change would delete or rewrite existing work.
  - Never weaken a test to make it pass.
  - Simulation code only: nothing that needs Studio.
  - Debug output goes in `debug_out/`, which is gitignored.

## Task list

| # | Task | Status |
|---|---|---|
| 1 | Packer/Schema follow-ups (8 weapon slots, PROTOCOL_VERSION, BUILD facing, tick wrap), guide 0.4 | ✅ done (`e1be1c4`) |
| 2 | Defs: loader, `extend`, validation (4.5), indices, hash, enums, `ord_lancer` / `chs_ravager` | ✅ done |
| 3 | Grid: cell math, position encode/decode, procedural test map (height + water) | ✅ done |
| 4 | World (SoA, u16 IDs with delayed reuse, dirty bits), `Sim.step` with stub systems, replay log, world hash | ✅ done (M0 exit criteria met) |
| 5 | Movement classes and passability: passMask + per-class clearance on the test map | ✅ done |
| 6 | Quadtree + coarse A* route + corridor | ✅ done |
| 7 | Flow field (integration + direction), LRU cache, time-slicing, PPM debug image | ✅ done |
| 8 | `lune run bench`: flow field timings on 256×256 (open, maze, island) vs 8 ms budget | ✅ done (over budget, see Benchmarks) |
| 9 | Movement and local avoidance: shared fields, separation, arrival, line-move spreading | ✅ done |
| 10 | Combat core: targeting, aim model, HITSCAN/BALLISTIC, projectiles, damage, AoE, deaths | ✅ done |
| — | Rules review (requires, determinism, no Instances, hot-loop allocation) | ✅ done |
| — | Round 3: direct-path shortcut, bucket-queue flow fields, duel reports | ✅ done (`bafe3b1`–`8878849`) |
| M3 | Economy and construction (headless), scripted T1 build order, M3 review | ✅ done (`3c27b99`–`1b17519`) |
| 11 | Sensor maps, visibility levels, ghosts (M4) | ✅ done |
| 12 | Wobble, jamming, stealth, fog-aware targeting (M4) | ✅ done |
| 13 | Interest management and NetOut, simulated client | ✅ done |
| 14 | Stress test and bandwidth report | ✅ done |
| 15 | Air: jets, helicopters, ammo, rearm pads (M6) | ✅ done |
| 16 | Naval: ships, subs, torpedoes (M6) + M6 review | ✅ done |
| 17 | Electronic warfare (M7) + M7 review | ✅ done |
| — | `docs/STUDIO_HANDOFF.md` | ✅ done |

## Done so far

### Task 2 — Defs

- `src/shared/Defs/`:
  - `Defs.luau`: validate, build, load, hash.
  - `Templates.luau`: `extend`, `Unit`, `TankT1`.
  - `Registry.luau`, plus `Categories`, `ArmorClasses` and `MoveClasses`.
  - `Units/ord_lancer`, `Units/chs_ravager`, `Weapons/ord_light_cannon`, `Weapons/chs_light_cannon`.
- `src/shared/Util/Hash.luau`: FNV-1a 32 plus a canonical value hash.
- Specs: `Defs.spec` (valid load, indices, derived values, extend, freeze, hash, missing damage logged, 28 broken-def cases, aggregated errors) and `Hash.spec`.
- Tests: **6 specs, 51 passed, 0 failed**.
- Decisions: D1–D7 in `docs/DECISIONS.md`.

### Task 3 — Grid

- `src/shared/Grid/`:
  - `Grid.luau`: 8-stud cells up to 256×256, centered on the origin; index/coords, cellAt, cellCenter, encode/decode (error in [0, 1/32) stud, clamped to the map), 16-stud sensor cells.
  - `Layers.luau`: height and waterDepth as i16 in 0.25-stud steps.
  - `TestMap.luau`: seeded 3-octave value-noise hills with water below sea level, plus `build()` for hand-made maps.
- `.lune/lib/Ppm.luau` (PPM and PNG writer) and `.lune/debug_map.luau`. `lune run debug_map [seed] [cells]` writes `debug_out/map_<seed>.png`.
- Specs: `Grid.spec` (sizes, index round-trip, boundaries, 15,000 random encode/decode round-trips within 1/32 stud, clamping, sensor cells) and `TestMap.spec` (quantization, determinism per seed, water consistency, 256×256).
- Tests: **8 specs, 64 passed, 0 failed**.
- Decisions: D8–D12.

### Task 4 — World, Sim, replay

- `src/server/Sim/`:
  - `World.luau`: SoA fields, dense `ids` list, fresh-first IDs with FIFO reuse after 150 ticks, dirty-bit setters, hash.
  - `Sim.luau`: `new`/`submit`/`step`/`hash`/`fromReplay`/`runReplay`; 11 systems in guide order with rates and Profiler labels; checkpoint every 300 ticks.
  - `Replay.luau`: binary log with header, COMMAND and CHECKPOINT entries.
  - `Scenarios.luau` (`empty`, `skirmish_test`), `Types.luau`.
  - `Systems/Commands.luau`: applies fire state, move state and toggle to the sender's own units. The other 10 systems are stubs.
- `Packer` gained `writeString`, `readString` and `readBuffer`.
- Specs:
  - `World.spec`: dense ids, delayed FIFO reuse after exhausting all 65,535 IDs, dirty bits, order-independent hash.
  - `Replay.spec`: round-trip, every truncated prefix, bad magic/format/kind.
  - `Sim.spec`: system order; 1,000 ticks twice give identical checkpoints and hash; a different seed differs; replay reproduces the run and re-records an identical log; an injected command and a corrupted checkpoint are both caught; protocol/defs mismatch refused; malformed submits dropped; ownership respected.
- Tests: **11 specs, 83 passed, 0 failed**.
- **M0 exit criteria met.** CLAUDE.md's milestone line now says M1.
- Decisions: D13–D20.

### Task 5 — Passability

- `src/shared/Grid/Passability.luau`: `build(layers)` produces:
  - the slope layer (u8);
  - passMask (u16, bit per move class: ford/slope for land, depth for ships and subs, any water for hover, slope only for amphib, air always);
  - per-class clearance (Chebyshev distance transform, map edge counts as blocked).

  Plus `canEnter`, `clearance`, `fits(moveClass, footprint, cell)` and `requiredClearance(F) = floor(F/2) + 1`.
- About 75 ms per 256×256 map in Lune (load time only).
- Specs (`Passability.spec`):
  - an exact slope value;
  - a depth table across all 9 classes (ships only on deep water, subs deeper, ford limits);
  - a 26.5° ramp that blocks HEAVY_TRACKED, WHEELED and HOVER but not TRACKED or AMPHIB;
  - exact clearance on a hand-built map;
  - a footprint-2 unit rejected in a 1-cell gap and accepted in a 3-cell gap;
  - generated-map invariants and the Lipschitz property of clearance.
- Tests: **12 specs, 92 passed, 0 failed**.
- Decisions: D21–D24. **D21 changes the guide's footprint formula. Please confirm.**

### Task 6 — Quadtree and coarse route

- `src/server/Sim/Path/`:
  - `Heap.luau`: deterministic (k1, k2, id) min-heap, reusable.
  - `Quadtree.luau`: per (move class, need); summed-area uniformity; edge-sharing neighbors; components.
  - `Route.luau`: A* over leaves with failure reasons, plus `corridor()` (route leaves + adjacent open leaves, mask buffer + bounding box).
- Measured on 256×256 hilly terrain: tree about 6 ms (4,285 leaves, 2,413 open); corner-to-corner route about 2.5 ms (40 leaves); corridor 0.15 ms (20,545 cells).
- Specs (`Route.spec`):
  - heap ordering;
  - flat 256² collapses to 1 leaf, 200×120 to ≤ 64 leaves, generated terrain < 1/4 of cells;
  - partition, symmetric neighbors, and components identical to cell flood-fill;
  - a route around a wall goes through the gap, with consecutive leaves touching and the goal reachable inside the corridor;
  - island, blocked goal and blocked start fail with the right reasons;
  - a 1-cell gap passes footprint 1 but not footprint 2;
  - a same-leaf route; determinism.
- Tests: **13 specs, 99 passed, 0 failed**.
- Decisions: D25–D28.

### Task 7 — Flow fields

- `src/server/Sim/Path/FlowField.luau`:
  - a job runs Dijkstra from the goal over corridor cells (8-connected, √2 diagonals, no corner cutting), then a direction pass (u8, 255 = none);
  - `run(job, budget)` is time-sliced in work units and resumes exactly;
  - plus `build`, `direction`, `covers`, `vector`.
- `src/server/Sim/Path/FieldCache.luau`: LRU (default 32) keyed by `moveClass:need:goal`; hit/miss/eviction stats; `invalidateCell`.
- `.lune/debug_flowfield.luau`: `lune run debug_flowfield [maze|hills] [seed]` writes `debug_out/flowfield_<kind>.png` (cost shading plus direction ticks).
- `src/server/Tests/Support/Maps.luau`: shared test map builders (flat with water, zig-zag maze, field from start to goal).
- Specs (`FlowField.spec`):
  - from every corridor cell, following the field reaches the goal without leaving the corridor or cutting corners (wall map, maze, generated terrain);
  - integration equals the octile distance on open ground;
  - the pinch-corner case;
  - sliced output equals one-shot for budgets 1, 7, 64 and 1000;
  - vectors; cache hits, LRU eviction and invalidation.
- Tests: **14 specs, 107 passed, 0 failed**.
- Decisions: D29–D32. **D29 (work-unit budgets) changes how guide 6.4's "8 ms" is enforced. Please confirm.**

### Task 8 — Benchmark

- `.lune/bench.luau`: `lune run bench [runs]` times passability, quadtree, route, corridor and flow field on 256×256 open/maze/island maps (west-to-east endpoints, TRACKED, footprint 1). It prints a table and writes `debug_out/bench.txt`.
- Results below. No optimization was done, as instructed.
- Tests: unchanged (**14 specs, 107 passed**).
- Decision: D33.

### Task 9 — Movement and local avoidance

- `src/shared/Grid/MapRegistry.luau`: `none`, `flat:<n>`, `wall:<n>`, `gen:<seed>:<n>`. The sim loads its map from `mapId` (D34).
- `src/server/Sim/Nav.luau`: movement profiles, lazy quadtrees, field cache, the job FIFO, move orders with group fields and per-unit slots (spiral formation or line), goal snapping, field extension, and line-of-sight checks.
- Systems:
  - `Pathing`: runs field jobs within 12,000 work units per tick.
  - `Movement`: steer, move with terrain sliding, overlap resolution, write-back with dirty bits.
  - `Commands`: MOVE/FIGHT/PATROL (with LINE) and STOP now have effects.
- `World` gained movement fields (speed, orderId, goal, direct, progress), all hashed. `Route.findMany` and `Route.mergeCorridors` were added. Scenario `march_test` places 50 Lancers on the west side.
- `.lune/debug_movement.luau`: `lune run debug_movement [mapId] [ticks]` writes `debug_out/movement_<map>.png` with tracks and prints arrival statistics.
- Specs (`Movement.spec`):
  - 50 units cross a lake map, and 50 units detour through a wall's gap: all finish within 2,000 ticks, end ≤ 24 studs from their slots on open ground, and overlap at most 0.5 stud;
  - one order shares one field with distinct slots;
  - same seed gives identical positions and hash, and the replay reproduces it;
  - line-move goals are evenly spaced end to end, and units reach them;
  - a water goal snaps to land;
  - STOP; out-of-map cells are ignored;
  - idle units stay clean (no dirty bits).
- Tests: **15 specs, 115 passed, 0 failed**.
- Bugs found and fixed: the job FIFO used `table.insert` on a queue with nil head slots, so extension jobs never ran. Arrived units were shoved away by later arrivals.
- Decisions: D34–D42.

Movement results (`lune run debug_movement`, 50 Lancers west → east, Lune on the dev PC):

| map | ticks to all arrived | sim ms/tick | fields built | units ≤ 2 studs from slot | worst distance from slot | closest pair gap at end |
|---|---|---|---|---|---|---|
| gen:7:96 | 461 | 0.18 | 2 | 34/50 | 13.7 | −0.00 |
| gen:3:96 | 404 | 0.18 | 1 | 47/50 | 6.3 | +0.07 |
| gen:11:128 | 532 | 0.17 | 1 | 45/50 | 5.3 | −0.00 |
| gen:21:128 | 628 | 0.17 | 2 | 33/50 | 11.7 | −0.20 |
| gen:5:96 | 477 | 0.17 | 1 | 27/50 | 7.3 | −0.00 |
| flat:64 | 312 | 0.14 | 1 | 45/50 | 14.0 | −0.00 |
| wall:64 | 431 | 0.18 | 5 | 25/50 | 5.8 | −0.00 |
| wall:96 | 597 | 0.20 | 5 | 32/50 | 16.5 | −0.00 |
| wall:128 | 757 | 0.24 | 6 | 26/50 | 14.8 | −0.00 |

Every unit arrives on every map and overlap is negligible. Formation precision is mediocre: about 70% of units end within 2 studs of their slot, and the rest stop up to about 17 studs short where the crowd blocks them (D38 give-up). Better slot assignment (e.g. Hungarian matching, or reserving the approach lane) is a possible follow-up.

### Task 10 — Combat core

- `src/server/Sim/Combat/`:
  - `Combat.luau`: per-def collision and weapon profiles, terrain height, damage queue, `explode` with AoE falloff and friendly fire, projectile pool (u16 IDs, cap 2,000), wrecks, per-tick events, hash.
  - `ContactGrid.luau`: 64-stud buckets, team-filtered queries.
  - `Ballistics.luau`: low-arc launch pitch, exact step, segment vs cylinder, distance to cylinder, falloff.
- Systems:
  - `Targeting`: per weapon, staggered, sticky, priority scoring, fire states.
  - `Weapons`: turret yaw/pitch rates, tolerance, ballistic pitch, reload, spread from `sim.rng`, hitscan resolution, projectile spawn.
  - `Projectiles`: exact flight, swept collision against enemy cylinders and terrain, impact explosions, ttl.
  - `Damage`: queued damage by armor class, lastAttacker, deaths with severity, wrecks, DEATH events, order cleanup.
- `World` has per-weapon state (yaw, pitch, reload, target) and lastAttacker, all hashed. `Sim/Spawn.luau` spawns from defs. Scenario `duel_test`. `Sim.hash` includes combat.
- `.lune/debug_duel.luau`: `lune run debug_duel [seeds]` prints the duel outcome, shots, hits, kills and cost.
- Specs:
  - `Ballistics.spec`: launch pitch lands on target; reach; exact step; segment/cylinder cases including no tunneling; distance; falloff.
  - `Combat.spec`:
    - 10 Lancers vs 10 Ravagers until one side is gone, deterministic across runs and replay;
    - a slow turret (30°/s) first fires ≥60 ticks after a fast one (180°/s);
    - exact AoE falloff for 5 units at known distances, and friendly fire off spares allies;
    - a shell blast damages 3 tanks with the exact falloff from the impact point;
    - hitscan damage lands the same tick;
    - a 3,000 stud/s rail doesn't tunnel, and an ally in the line of fire is untouched;
    - wreck vs. obliteration by overkill; armor classes;
    - Hold Fire stays silent; Return Fire shoots back only after being attacked.
  - Mutation checks: letting projectiles hit allies, ignoring aim tolerance, and dropping the swept test were each caught.
- `Sim.spec`: "20 units after 1,000 ticks" became "both runs end with the same survivors", since the skirmish tanks now fight. The determinism check is stricter, not weaker.
- Tests: **17 specs, 129 passed, 0 failed**.
- Duel results (`lune run debug_duel 10`): Chaos wins 10 of 10 seeds with 5 Ravagers left after 221–244 ticks (about 15 s). 96–97% of shells hit, 15 kills and 15 wrecks per fight, about 0.024 ms per tick for 20 units. Placeholder stats; see D50.
- Decisions: D43–D50.

### Rules review

Checked every file under `src/` against CLAUDE.md and the skill:

- `--!strict` everywhere. ✅
- Requires: only `@shared/...` across roots and relative paths within a root. ✅
- No Roblox globals, Instances, `Random`, `math.random`, `os.clock`/`tick`/`time` in sim code (clocks only via `Util/Profiler`). ✅
- No `pairs()`-order dependence: every loop over a hash-keyed table only builds a set or copy, or sorts its keys first. ✅
- Replicated fields are written only through World setters (dirty bits); turret aim sets STATE dirty explicitly. ✅
- No print spam in sim code. ✅

Fixes made during the review and while building the tasks:

1. **Hot-loop allocations removed:**
   - Targeting created a closure per weapon per tick; it's now a module-level function.
   - `Nav.tree` built a string key per call from Movement; the key is now precomputed per profile.
2. **Queue bugs fixed:** two FIFO queues used `table.insert` / `#` on tables with nil head slots: World's free-ID queue (caught in review before tests) and Nav's job queue (caught by the wall-map march). Both now use explicit head and tail indices.
3. **Unused require** (`World` in Scenarios) removed. Stale guide reference (line of fire is now 10.8) fixed. `Route.findMany` edge case simplified.
4. **Logged, not fixed:** D51 (libm trigonometry across platforms).

Remaining allocations per event (FIRE, IMPACT and DEATH event tables; command-time tables in Nav) are per discrete event, not per unit per tick.

### Round 3 — answers, pathing fixes, duel reports

- The answers were applied:
  - D21 is confirmed; guide 5.5 now requires chokepoints ≥ 3 cells and 6.2 prefers odd footprints.
  - Work-unit budgets are approved.
  - Same-platform re-simulation is accepted; guide 17.1 separates player-facing stream replays from dev-only command re-simulation.
  - Test audit: no hard-coded simulation hashes.
- **Fix (a), direct-path shortcut (D52):** each unit's line to its slot is checked once (same leaf is exact and free, otherwise sampled). Units with a clear line steer directly, and a field is built only for the rest, or not at all. All 9 movement maps still arrive. Open maps build 0 fields.
- **Duel reports (D54):** `lune run report_duels [seeds]`. At equal cost (13 Lancers vs 15 Ravagers): close range, Chaos wins 5/5 (10 Ravagers left, 13 s); long range with Lancer kiting, Order wins 3/5 (2 Lancers left, 89–125 s) and Chaos wins 2/5 (about 34 s). Report only; no rebalance.
- **Fix (b), bucket queue (D53):** flow field integration uses Dial buckets. The output is byte-identical to the heap version, about 2.8× faster overall and 3.9× on integration. The pathing budget was recalibrated from 12,000 to 36,000 units per tick (≈ 8 ms).

### M3 — Economy and construction ✅ (headless)

- **M3.7 — scripted T1 build order (D64):**
  - Scenario `standard_start`; `Tests/Support/BuildOrder.luau` driver; `BuildOrder.spec`: both factions build 2 extractors, 2 generators and a plant, then get 3 tanks; no step fails, stored never goes negative; deterministic across two runs and the replay.
  - `lune run report_buildorder` prints the timeline: plant at about 43 s, three tanks by 90–107 s, then power-bound.
  - Tests: **21 specs, 151 passed**.
- **M3 rules review:**
  - Every new file is `--!strict` and uses allowed require forms. There are no Roblox globals, clocks or `math.random`, and no prints in sim code.
  - Every loop in the new modules runs over an array.
  - Replicated fields are written only via setters (the new `buildProgress` included).
  - The intentional side-effect require `_Placement` in Sim registers its Lifecycle hook; hook order is fixed by require order.
  - Allocations: `Build.step` creates one closure per tick, and `approach` allocates only when sending an idle builder off. Nothing is allocated per unit per tick.
  - **No fixes needed.**

- **M3.4–M3.6 — construction, factories, reclaim (D61–D63):**
  - `Sim/Build.luau` and `Sim/BuildState.luau`: BUILD (approach, placement check, frame, assist), per-tick progress × effective ratio with the allowance cap, health growth, completion, demand reporting; factory queues, production and the exit roll-out; REPAIR as assist; RECLAIM; removal hook.
  - Construction system, commands BUILD / REPAIR / RECLAIM; MOVE and STOP cancel build work. `Combat.removeWreck`; build events.
  - `Build.spec`: the CV builds a generator in exactly 60 ticks, which then produces; assisting is faster; a starved team builds more than 2× slower and never overspends; a missing deposit fails with a reason; a factory queue produces in order (Lancer at tick 675) and units roll out; assisting a factory more than halves production time; reclaim returns exactly the wreck's supply; a frame destroyed mid-build frees footprint and builders; determinism.
  - One test was wrong first: its team had no power income, so production correctly stalled at 2/3 for lack of power. The test now funds the economy.
  - Tests: **20 specs, 149 passed**.
- **M3.3 — placement and passability (D59, D60):**
  - `Passability`: occupancy layer, capped clearance, exact `updateRect`, `setOccupied` / `clearOccupied`.
  - `Sim/Placement.luau`: snap, check, occupy, release (as a Lifecycle hook). `Nav.terrainChanged`.
  - `Spawn.unit` occupies the footprints of structures it spawns.
  - `Placement.spec`: snapping; bounds, terrain, deposit, occupancy and unit checks; clearance equals brute force after placing 3 plants; destroying them restores every layer byte for byte; routes avoid new structures.
  - Tests: **19 specs, 140 passed**.
- **M3.2 — team economy (D57, D58):** `Sim/Economy.luau`: accounts, producer list, settlement every 5th tick, stall ratio, two-pass effective ratio, window allowance, storage cap and waste, hash. `Sim/Lifecycle.luau`. `World.buildProgress` with a BUILD dirty bit. `Economy.spec`: settlement math, effective ratio, starting accounts, income from the CV, extractor (deposit value) and generator, storage bonus, producer death, hash. Tests: **18 specs, 136 passed**.
- **M3.1 — defs and map (D55, D56):** economy def fields and validation; Command Vehicle, worker, extractor, generator and vehicle plant per faction; supply deposit and start layers; `start:<n>` map. The Defs index test now checks sorted order against the registry instead of hard-coded indices. Tests: **17 specs, 130 passed**.

### Task 19 — Local quadtree invalidation ✅

- `Quadtree.update` re-decides only the nodes touching the flipped cells, then patches leaves, IDs, neighbors and components. `Nav.terrainChanged` calls it for every tree (rectangle padded by the clearance cap) and restarts stale route searches (D86).
- **Tests:**
  - 40 random placements and removals on `gen:3:128`; 230 tree comparisons against fresh builds (including TRACKED need 2);
  - 4 mutations caught;
  - `Placement.spec`'s tree-identity check replaced by a behavior check.
- **Stress test** (800 units, now also placing 14 structures mid-battle; the harness reports it):
  - worst tick with a placement: 42–43 → 24–27 ms (the ordinary tick peak); the placement itself is ≤ 5.7 ms;
  - Movement peak: 31–35 → 14 ms.
- Tests: **27 specs, 190 passed**.

### Task 18 — Sensors performance ✅ (branch `m-sim-polish`)

- **Profile:** stamping is about 95% of Sensors time (12–23 ms per sensor tick at 800 units); visibility 0.2–0.4 ms, lists 0.3–0.7 ms, ghosts about 0 (D85).
- **Fix:** one-cell circle shifts, row-span circles, a full-stamp budget of 200,000 cells per sensor tick.
- **Sensors average / peak ms, before → after:**

  | units | before | after |
  |---|---|---|
  | 200 | 1.46 / 6.10 | 0.18 / 1.39 |
  | 400 | 2.39 / 12.42 | 0.31 / 3.48 |
  | 600 | 3.42 / 14.18 | 0.40 / 2.06 |
  | 800 | 4.16 / 21.56 | 0.54 / 2.14 |

  Target ≤ 5 ms met. Average tick at 800 units: about 12.1 → 9.2 ms.
- **Tests:**
  - the existing full-recount test covers shifts;
  - new: a 300-radar mass spawn is stamped in ids order within budget and catches up after 18 ticks;
  - mutations caught: off-by-one leading edge, off-by-one trailing z edge, budget ignored.
- Tests: **27 specs, 189 passed**.

### Round 4 — answers to the task 11–17 questions

- **1. COMMAND guidance (D80, revised):**
  - needs only a live launcher and the target VISIBLE to the launcher's team, checked every tick of the flight;
  - jamming, flares, chaff and DIRCM have no effect;
  - guide 11.5 table updated.
  - New `EW.spec` test: a COMMAND missile hits a jammed target carrying certain-success flares, chaff and DIRCM, which spend nothing. Killing the launcher or the spotter mid-flight raises `LOST_LOCK` and the sidestepping target is missed.
  - Mutations caught: jamming blocking the lock, no sight check, countermeasures rolling against COMMAND.
  - Tests: 27 specs, 183 passed.
- **2. Refill costs (D81, revised):**
  - new required `refillSupply` per flare or chaff charge;
  - the restock is spread over the rearm's rounds (`Air.rearmStep`, `EW.missingCharges` / `EW.addCharge`) and hashed in `AirState`.
  - New test: a Harpy missing 5 flares and 3 chaff pays exactly 19 supply more than one with full charges, rearms in the same 135 ticks, has part of its charges back at 4 s, and is full on take-off.
  - Mutations caught: free refill; restock only at the end.
  - Tests: 27 specs, 184 passed.
- **3. SAM target choice (D82, revised):**
  - Targeting gives guided missiles a lock preference (×1,000), re-searches every 6 ticks while holding a target, and switches only on a 1.25× score margin.
  - Bug fixed: jets spawned without orders now start at minimum speed; before, they hung motionless.
  - New tests:
    - **escort:** a jammer aircraft flying 25 studs behind fighter A. The Aegis fires 0 missiles at A and 8 at B, and is aimed elsewhere only 38 ticks while B is lockable (bound: 6 ticks per time B becomes lockable, 7 times). Once B is gone it tracks a jammed aircraft 221 of 300 ticks without firing. Without the escort it engages both (7 and 7).
    - **hysteresis:** radar wobble swaps which of two Wasps (500 and 505 studs) looks closer 10 times; the SAM never switches.
  - Mutations caught: no lock preference (102 wasted ticks), no re-search (258), no hysteresis (switches).
  - Tests: 27 specs, 186 passed.
- **4. Close submarine detection (D76, revised):**
  - `Sensors.CLOSE_SONAR = 40`: naval units and ASW helis (HELI with a SUB-capable weapon) make a submerged sub a SONAR contact.
  - New placeholders: Tidewatch and Leech ASW helicopters.
  - New `Naval.spec` test:
    - a sonar-less corvette at 30 studs sees a SONAR contact; at 55, nothing;
    - a sonar-less ASW heli at 35: SONAR; at 50: nothing;
    - an attack heli at 20 and a tank on the beach: nothing;
    - the ASW heli then drops torpedoes on it, and it is never VISIBLE.
  - Mutations caught: helis excluded, range 400, everyone detecting.
  - Tests: 27 specs, 187 passed.
- **5. Move-order spike (D83):**
  - **Profile:** see D83. Quadratic slot assignment was ~1.3 ms per 200-unit command, not the main cost. The big costs were the lazy quadtree build (10–17 ms), the coarse route and corridor (5–12 ms) and the per-unit line checks (2–6 ms).
  - **Fix:**
    - quadtrees and the formation spiral are built at load;
    - line checks, route and corridor move into a work-unit-sliced plan job (resumable `Route` search);
    - exact bucketed greedy assignment;
    - issuing shares the tick's pathing budget.
  - New `Movement.spec` test: the bucketed assignment equals the brute-force greedy on 60 random cases with ties. Mutations caught: early stop, no tie rule.
  - The stress harness now reports the worst Commands + Pathing tick.

    | units | worst move-order tick before → after (ms) | Commands peak before → after | max tick before → after |
    |---|---|---|---|
    | 200 | 60.4 → 11.4 | 49.8 → 0.8 | 61.5 → 13.8 |
    | 400 | 68.9 → 12.8 | 59.1 → 2.4 | 70.9 → 16.6 |
    | 600 | 80.6 → 12.7 | 70.2 → 3.3 | 85.1 → 26.4 |
    | 800 | 91.4 → 10.2 | 81.9 → 6.5 | 95.3 → 28.6 |

    Repeated 800-unit runs give worst move-order ticks of 8.7–11.6 ms. The remaining max-tick peaks are Sensors (14–22 ms) and Movement (10–13 ms).
  - Tests: 27 specs, 188 passed.
- **6. Offline Roblox build (D84, STUDIO_HANDOFF step 1):**
  - darklua 0.19.0 via Rokit; `.darklua.json` (`convert_require` with the Rojo sourcemap); `build.project.json`;
  - `lune run build` (sourcemap → darklua → `rojo build` → check) and `lune run check_build`.
  - The built place: 143 scripts compile; 482 requires all resolve to ModuleScripts.
  - The checker fails, as it should, on an unconverted place, a missing child, a Folder target and a syntax error (exit code 1).
  - Only the in-Studio run (serve `build.project.json`, confirm runtime requires) remains.

### Task 17 — Electronic warfare (M7) ✅

- `Sim/EW.luau`, `Sim/EWState.luau`:
  - lock checks for IR, RADAR (burn-through, stealth) and COMMAND;
  - midcourse every 5 ticks (`LOST_LOCK`) and the terminal countermeasure roll (`DECOYED`, a 60° veer);
  - flares, chaff and DIRCM (cooldown; power drain at the stall ratio); refill on rearm;
  - all rolls through `sim.rng`.
- Integration:
  - Weapons won't launch without a lock; Projectiles calls `EW.guide` before steering.
  - Combat has `pFlags` (hashed) and the `DECOYED` / `LOST_LOCK` events.
  - Build runs DIRCM upkeep; Spawn initializes countermeasures; Air refills them on rearm; `Sim.hash` covers `EWState`.
- Defs: Vigil/Thorn IR SAM sites, Aegis/Wyvern radar SAM sites, IR and radar SAMs, the `burnThrough` field, countermeasures on the four aircraft (D81, D82). Scenario `ew_test`.
- `EW.spec`:
  - **jammer vs radar SAM:** unjammed at 550 studs the Aegis launches and hits (2/2). Jammed at 550 and at 250 it never launches, though the Wasp is VISIBLE 300 of 300 ticks. Jammed at 150 (inside the 210 burn-through) it launches and hits (2/2).
  - **mid-flight jamming:** a jammer arriving after launch makes the missile raise `LOST_LOCK` and miss.
  - **DIRCM:** 25 of 40 single IR missiles decoyed. In salvos of 4 at most one per salvo is decoyed (14 of 80); 66 of 80 hit.
  - **DIRCM power:** with power it recharges within 4 s; with the team's power gone it never recharges, and 10 of 10 later missiles hit.
  - **charges:** 2 flares decoy 2 IR missiles and the third hits; chaff is untouched by IR and decoys the radar missile; refill restores both.
  - **lock rules:** IR locks a jammed target that radar can't; stealth (0.3) cuts radar lock range to 180; IR needs VISIBLE (a radar-only contact can't be locked); a COMMAND missile hits while its launcher lives and loses lock when the launcher dies.
  - **replays:** the `ew_test` scenario replays exactly.
  - Mutation checks, each caught: no jam lock check, no DIRCM cooldown, recharge ignoring power, no midcourse, flares never spent, COMMAND ignoring the launcher, no stealth, IR without visibility, Weapons ignoring the lock.
- `Air.spec` intercept: the Wasp's flares are set to 0 in the setup (D82); assertions unchanged.
- Tests: **27 specs, 182 passed**.
- **M7 rules review** (task 17):
  - strict, require forms, no globals, clocks or random: clean; all rolls go through `sim.rng`;
  - no `pairs()`-order dependence: EW loops run over `w.ids` and `sensors.teams` (arrays); `EWState.hash` walks the ascending id list;
  - no unused requires;
  - no allocation in `EW.guide`, `EW.canLock` or `EW.drainStep` beyond the event tables every system emits;
  - **one fix, a performance regression found by re-running the stress test:** Movement sized its spatial-hash search from the largest radius *in the roster*. Task 16's footprint-3 destroyers widened every unit's search from 3×3 to 5×5 buckets, and Movement at 800 units went from 4.3 to 7.0 ms. It now uses the largest radius among the units present that tick. The results are bit-identical (same survivors and kills); Movement is back to 4.2 ms.

### Task 16 — Naval (M6) ✅

- Map `sea:<n>` (land on the west quarter, deep water elsewhere).
- Combat: ships' hulls hang from the water surface (draft 3); submerged subs 10 studs down; `Combat.surfaceHeight` and `Combat.waterDepth`.
- Spawn sets `SUBMERGED` on every SUB-class unit.
- Weapons: torpedoes launch level just under the surface. Projectiles: torpedoes are clamped to the water column and removed at the shore. Targeting: torpedoes may shoot SONAR contacts.
- Defs: Sentry/Barracuda corvettes, Silence/Lamprey subs, Crusader/Corsair destroyers; naval guns, torpedoes, ASW torpedoes; guidance `ACOUSTIC` (D76–D78).
- `Naval.spec`:
  - a corvette, a destroyer and a sub ordered 200 studs inland stop at the shore and never enter water shallower than their class's `minDepth`;
  - a sub 100 studs from an enemy corvette (sight 220, no sonar) stays HIDDEN with no known position, while a surface ship at the same range is VISIBLE; a destroyer's sonar then makes it a SONAR contact, never VISIBLE;
  - a tank on the beach and a corvette's gun never target a known sub; only torpedoes shoot at it;
  - a torpedo fired at a tank on land stays under the surface and is removed at the shore with no damage;
  - a Crusader sinks a Lamprey 200 studs away in 8.5 s with ASW torpedoes, keeping 1960 / 2600 HP, and never fires its gun at it;
  - determinism.
  - Mutation checks: no SUBMERGED on spawn, no shoreline removal, no SONAR targeting and no water-column clamp are each caught.
- Tests: **26 specs, 175 passed**.
- **M6 rules review** (tasks 15–16):
  - strict, require forms, no globals, clocks or random: clean;
  - no `pairs()`-order dependence: the new loops run over `w.ids` and def arrays; `AirState.hash` walks the ascending id list;
  - no unused requires;
  - one fix: rearming built an empty cost table per unit per tick when a def had no `ammoCost`; it now uses a frozen constant;
  - accepted: `Air.nearestPad` scans all units (only when an aircraft runs dry or its pad dies), and `Air.rearmStep` walks the unit list twice per Construction tick (O(n), no allocation).

### Task 15 — Air (M6) ✅

- `Sim/Air.luau`, `Sim/AirState.luau`:
  - jet steering (min speed, turn rate, loiter circling, chase, map edge);
  - altitude bands; ammo use; return to the nearest pad, landing, rearming through the economy, take-off and resume.
- Integration:
  - Movement has a jet branch, updates altitudes, and skips jets in overlap resolution.
  - Projectiles do homing steering and test collisions in each target's frame.
  - Targeting lets jets acquire outside their arc; Weapons spend ammo; Build runs rearming as a consumer; Spawn initializes aircraft.
  - Nav profiles have `jet` and `minSpeed`.
- Defs: Falcon and Harpy fighters, Guardian and Wasp helicopters, Aerie and Roost pads, missiles and rockets (D75).
- `Air.spec`:
  - a Falcon intercepts an incoming Wasp (killed at 22.9 s with 3 missiles, 3 hits), never drops below minimum speed, then circles its point (more than 2π of turning in 30 s);
  - an empty Falcon goes fly → return → rearm (landed on the pad, LANDED) → fly with full ammo and back out;
  - rearm takes 120 ticks at full economy versus more than 3× on a power stall;
  - a helicopter hovers at 35;
  - determinism.
  - Mutation checks: removing the min-speed clamp, ignoring the stall in rearm, and never spending ammo each fail their test.
- Tests: **25 specs, 169 passed**.

### Task 14 — Stress test and bandwidth report ✅

- `Sim.enableTiming` (D72) and `.lune/stress.luau`. `lune run stress 900 200 400 600 800` writes `debug_out/stress.txt`.
- Results: see **Stress test** under Benchmarks below.
- Tests unchanged: **24 specs, 164 passed**.

### Task 13 — Interest management and NetOut (headless) ✅

- `Schema`: Events records ENTER/LEAVE/DEATH, `PROTOCOL_VERSION` 2 (D70).
- `Sim/NetOut.luau`, `Sim/NetState.luau`, NetOut system, CAMERA command (D71).
- `Tests/Support/Client.luau`: decodes one player's packets into a world view.
- `NetOut.spec`:
  - 1,000-tick battle with radars, a jammer and structures: no client ever receives a unit its team can't know; tactical and state records only for seen units; radar blips only at their wobbled cell with icon 0; every message ≤ 900 bytes (largest 204); at the end each client's view equals server knowledge (tactical positions within 1/32 stud, health exact).
  - Camera hysteresis (+2 enter, +5 leave).
  - 400 movers split into ≥ 4 messages, each mover sent once.
  - Mutations caught: hidden units leaking into strategic records; radar contacts at true positions.
- Movement.spec's "idle units cost nothing" now checks packets (no tactical or state messages from idle units) instead of dirty bits, which NetOut clears every tick. This makes it stronger, not weaker.
- Tests: **24 specs, 164 passed**.

### Task 12 — Wobble, jamming, stealth (M4) ✅

- `Sensors`:
  - `radarDetects` (jam map of the target's team; stealth against each observer radar within range × signature);
  - per-team radar emitter list and best radar error;
  - `wobble` (stateless, smooth, per observer) and `knownPosition`.
- Targeting accepts only known targets (radar contacts and ghosts for `canTargetRadar`). Weapons aim at known positions; hitscan is judged against the truth.
- Defs: `sensors.radarError`; Veil and Shroud jammers; Verdict and Hellmouth artillery with radar-targetable guns. Tank sight now covers weapon range (D68).
- `Fog.spec`:
  - wobble is bounded, deterministic, smooth and per observer;
  - a jammed tank is off enemy radar but still visible to sight;
  - a stealth unit (signature 0.3) shows on radar exactly within 210 studs of a 700-stud radar, checked every sensor tick along a walk through all three bands;
  - a unit with 40-stud sight never fires at an in-range unseen enemy, and fires once a friendly spotter sees it;
  - radar-targeted artillery hits directly 20% of the time versus 87% spotted.
  - Mutation checks: removing the jam or stealth check fails the matching test.
- Three earlier tests read hard-coded sight and index values; they now read them from the defs.
- Tests: **23 specs, 160 passed**.
- **M4 rules review:**
  - strict, require forms, no globals, clocks or random: clean;
  - the only dictionary loop (visibility hash) sorts first;
  - no unused requires;
  - the sensor tick allocates nothing per unit (radar lists cleared and refilled, stateless wobble, cached radii).
  - No fixes needed.

### Task 11 — Sensors (M4)

- `Sim/Sensors.luau` + `Sim/SensorsState.luau`:
  - per-team u16 maps (los, airLos, radar, sonar, jam); cached circle offsets;
  - stamp and unstamp on sensor-cell change, with no allocation (radii cached per def);
  - visibility levels with structure ghosts; `Sensors.level(sim, team, id)`;
  - hash, and a Lifecycle unstamp hook.
- World state bits SUBMERGED and LANDED. Placeholder mobile radars Oracle and Watcher (D66). Def sensors gained `airSight` and `jam`.
- `Sensors.spec`:
  - 30 units moving and dying for 240 ticks: the maps always equal a recount of the stamped circles, and stamps never trail positions by more than one cell; after everyone dies, every map is zero;
  - a Ravager walking past an observer: HIDDEN → VISIBLE → HIDDEN, exactly matching the sight circle on every sensor tick;
  - ghosts persist out of sight and after death, and disappear once the spot is seen;
  - radar contact beyond sight; unfinished units don't emit.
- Tests: **22 specs, 155 passed**.

## Benchmarks

Lune 0.11 on the dev PC, 256×256, median over 7 runs (best in the second figure), ms:

| map | passability (load) | quadtree | route | corridor cells | **flow field** | of which integration | work units | units/ms |
|---|---|---|---|---|---|---|---|---|
| open | 77 | 1.4 | 0.00 (1 leaf) | 65,536 | **80.2** / 78.3 | 70.1 | 131,071 | 1,634 |
| maze (zig-zag, 16-cell spacing) | 76 | 12.0 | 9.1 (707 leaves) | 43,141 | **31.5** / 31.3 | 24.7 | 86,281 | 2,742 |
| island (r = 110, hills + lakes) | 76 | 5.5 | 1.3 (32 leaves) | 10,236 | **9.9** / 9.8 | 8.3 | 20,471 | 2,076 |

**Against the 8 ms Pathing budget (guide 18.1): every one-shot field is over budget.**

- Open: 10× over. Maze: 4× over. Island: 1.2× over.
- With deterministic slicing at 12,000 units per tick (D33), the fields complete in 11, 8 and 2 ticks (0.73 s, 0.53 s, 0.13 s). Units steer straight toward the goal until then, which guide 6.4 allows.
- Integration (Dijkstra with a binary heap) is about 85% of the cost.
- The open map is the worst case: the whole map is one leaf, so the corridor is all 65,536 cells.

### Stress test, re-run after task 17

Same harness (`lune run stress`) on 2026-10-20 after the PC reset. This PC now runs slower than when task 14 was recorded: the task-14 commit itself measures **12.2 ms** average at 800 units here, against the 7.28 ms in the table below. Compare rows within one table only.

| units | avg | p95 | max | Sensors avg / peak | Movement avg / peak | Commands peak | total KB/s (player 1) |
|---|---|---|---|---|---|---|---|
| 200 | 3.15 | 5.88 | 52.4 | 1.48 / 16.3 | 0.70 / 4.3 | 42.8 | 5.63 |
| 400 | 5.94 | 11.13 | 61.4 | 2.38 / 9.5 | 1.79 / 6.8 | 48.8 | 12.41 |
| 600 | 8.72 | 15.15 | 74.6 | 3.21 / 13.2 | 2.87 / 8.1 | 63.9 | 18.07 |
| 800 | 12.08 | 20.41 | 94.8 | 4.19 / 17.0 | 4.22 / 11.6 | 82.0 | **21.53** |

- No system is over budget on average. The peak offenders are unchanged: Commands (the O(n²) slot assignment for a 400-unit order) and Sensors.
- At equal footing (task-14 commit vs now, same PC, alternating runs) the tick is unchanged once the Movement fix is in: 12.2 vs 12.1 ms.
- The battle differs slightly from task 14's (355 vs 335 survivors at 800) because task 15 changed projectile collision to the target's frame.

### Stress test (task 14)

Lune on the dev PC, 60 s of game time per size, two mixed armies attack-moving into each other on `gen:4:256`. Each player watches a 40×30-cell camera over the middle.

**Tick time (ms):**

| units | avg | p95 | max | alive at end | kills |
|---|---|---|---|---|---|
| 200 | 1.68 | 4.21 | 47.7 | 97 | 103 |
| 400 | 3.31 | 7.80 | 52.0 | 170 | 230 |
| 600 | 5.35 | 12.23 | 65.7 | 256 | 344 |
| 800 | 7.28 | 16.54 | 71.0 | 312 | 488 |

**Per system at 800 units, ms per tick, average / peak against the budget:**

| system | avg | peak | budget |
|---|---|---|---|
| Commands | 0.07 | **59.25** | 1 |
| Economy | 0.00 | 0.02 | 1 |
| Sensors | 2.43 | **15.99** | 5 |
| Targeting | 0.56 | 3.00 | 8 |
| Pathing | 0.44 | **8.44** | 8 |
| Movement | 2.59 | 9.30 | 10 |
| Weapons | 0.30 | 1.15 | 5 |
| Projectiles + Damage | 0.10 | 0.60 | 8 |
| Construction | 0.03 | 0.07 | 2 |
| NetOut | 0.75 | 3.87 (7.85 at 600) | 6 |

**Bandwidth per player (KB/s), worst player:**

| units | tactical (≤ 15) | strategic (≤ 10) | state + events (≤ 10) | total (≤ 35) |
|---|---|---|---|---|
| 200 | 1.91 | 1.65 | 2.03 | 5.59 |
| 400 | 4.32 | 3.00 | 4.51 | 11.83 |
| 600 | 6.89 | 4.42 | 4.77 | 16.08 |
| 800 | 9.12 | 5.66 | 6.59 | **21.37** |

**Verdict:**
- **On average, nothing breaks budget up to 800 units** (7.3 ms of 66.7 ms per tick).
- **The first system to break budget is Commands, on its peak:** 38–59 ms in the tick a 400-unit attack-move is issued, making the worst tick 71 ms at 800 units.
  - Cause: `Nav.issueMove` does greedy slot assignment, which is O(n²) (160,000 distance checks for 400 units), plus one sampled line check per unit.
- **Sensors is next:** its peak (6–16 ms against 5) comes from the first full stamp and from all-pairs visibility. Its average grows linearly (2.4 ms at 800), so it would reach 5 ms around 1,600 units.
- **Pathing** peaks right at its sliced budget (8.4 ms), as designed.
- **Bandwidth** stays under every target; the worst total is 21.4 KB/s at 800 units.

**Suggested fixes (not done, as instructed):**

1. **Commands spike:**
   - Assign slots in O(n log n): sort units and slots along the approach axis, then pair in order.
   - Do line-of-sight checks with a quadtree-leaf walk instead of 2-stud sampling.
   - Spread very large orders over a few ticks (a queue with a per-tick unit budget, deterministic).
2. **Sensors:**
   - Event-driven visibility (guide 11.3): recompute only units whose sensor cell changed, plus those under changed map cells.
   - Stagger the per-team passes across the two sensor ticks.
   - Stamp circles as row spans.
3. **Re-measure on a live Roblox server** with `--!native` before optimizing further. Desktop Lune numbers are not server numbers.

**After fix (a), direct-path shortcut.** `lune run bench` now also times whole move orders (issue + jobs to completion), median ms:

| map | 1 unit | fields | 50-unit block | fields |
|---|---|---|---|---|
| open | **0.02** | 0 | **0.35** | 0 |
| maze | 44.7 | 1 | 45.1 | 1 |
| island | 14.0 | 1 | 17.6 | 1 |

The open-map worst case (one 80 ms field) is gone. Without the same-leaf test, sampling 50 long lines took 8.4 ms. Maze and island still need their fields; the order cost there adds the leaf route (about 9 ms in the maze) to the field.

**After fix (b), bucket queue** (same maps, median / best ms):

| map | flow field (was) | of which integration (was) | units/ms (was) | move order, 1 unit | move order, 50 units |
|---|---|---|---|---|---|
| open | **28.3** / 27.9 (80.2) | 18.1 (70.1) | 4,633 (1,634) | 0.02 (no field) | 0.45 (no field) |
| maze | **18.1** / 17.9 (31.5) | 11.2 (24.7) | 4,780 (2,742) | 27.6 | 28.2 |
| island | **4.3** / 4.3 (9.9) | 2.7 (8.3) | 4,770 (2,076) | 8.0 | 11.4 |

Against 8 ms: the island field is now **within budget**. Open and maze are still over as one-shot jobs (3.5× and 2.3×), but sliced at 36,000 units per tick they finish in 4 and 3 ticks (0.27 s and 0.2 s). On open ground the shortcut means the field is rarely needed. The maze's move order also pays about 9 ms for the leaf-level route (`Route.findMany`), which isn't time-sliced yet. That's the next main-thread cost to watch.

Suggested fixes, in order of value per effort (as listed before fix (a); 1 and 2 are now done):

1. **No field when start and goal share an open leaf.** A leaf is a passable square, so the straight line inside it is always clear. This removes the open-map worst case entirely and helps every route's last leaf. *Cheap; will be used in task 9.*
2. **Bucket queue instead of a binary heap.** Integer costs 10/14 with Dial's algorithm make queue operations O(1). Expect about 2× on integration.
3. **Tighter corridor on open terrain.** Clip huge padding leaves to the route's bounding box plus a margin (D28 option).
4. **`--!native` on the path modules.** Roblox servers run Luau native codegen; numeric loops like these typically gain 1.5–3×. Must be measured on a live server.
5. **Actors (guide 6.4).** Move integration off the main thread so the main-thread budget only covers dispatch and apply. Results must be applied at a deterministic tick (D29).
6. **Cache hits.** All units in one order share a field, and repeated orders to the same goal hit the LRU, so real per-tick load is far below one field per order.
