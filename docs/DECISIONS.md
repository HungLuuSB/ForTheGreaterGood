# Decisions log

Decisions made while working unattended. Each entry gives the date, the decision, the alternatives and the reason. Everything here is meant to be easy to change. Overrule any of them and I'll update the code, the guide and this file together.

## Summary

- D1–D51: first unattended session (M0, the M1 simulation side, the M2 combat core). The questions it raised were answered in round 3.
- D52–D54: round 3 (pathing fixes, duel reports).
- D55–D64: M3 economy and construction.
- D65–D72: M4 sensors and fog, NetOut, stress harness (tasks 11–14).
- D73–D78: M6 air and naval (tasks 15–16).
- D79–D82: M7 electronic warfare (task 17). D76 and D80–D82 were revised by the user's round-4 answers (see each entry's "Revised" block).
- D83: move orders, profiled and sliced into the pathing budget.
- D84: offline Roblox build (darklua `convert_require` plus a place check).
- D85–D90: third queue: Sensors stamping, local quadtree updates, match rules, full roster, balance report, skirmish AI.
- D91–D94: round 5: bombing, wind / converters / extractor upgrades, match export and viewer, counter check.
- D95–D99: round 6: shared aim point, bombs on radar contacts and ghosts, destroyer SAM and missile guidance, same-role band, combat events on the wire.
- D100–D105: round 7: team knowledge (ghost targets, ATTACK_GROUND, audit), homing corrections, rearm airfields in balance fights, fire-control radar and its lock bonus.

Open points are listed in `docs/PROGRESS.md` → Summary.

---

## D1 — Unit modules require `Defs/Templates`, not `Defs` (2026-10-20)

- **Decision:** `Templates.luau` holds the templates and `extend()`. Unit modules use `local Templates = require("../Templates")` and `Templates.extend(Templates.TankT1, {...})`. `Defs.luau` re-exports `Defs.extend` and `Defs.Templates`.
- **Alternatives:**
  - The guide's literal `require("../Defs")`, which is a require cycle because Defs loads the registry and the registry loads the units.
  - Pure-data modules with an `extends = "TankT1"` field, resolved by the loader.
  - Lazy-loading the registry inside Defs.
- **Why:** this keeps the guide's `extend(template, overrides)` style with no cycle and no lazy tricks. Guide 4.2's example is updated to match.

## D2 — Defs are registered by hand in `Defs/Registry.luau` (2026-10-20)

- **Decision:** one module lists every unit and weapon module, keyed by file name. The loader checks each key against the def's `id`.
- **Alternatives:**
  - Enumerate folder children: Instances in Roblox, `@lune/fs` in Lune. That gives two code paths and breaks the "no runtime-specific code outside Util adapters" rule.
  - A Lune script that generates the registry.
- **Why:** it's the only portable option. A generator script can come later if the list gets long.

## D3 — Unknown def fields are errors (2026-10-20)

- **Decision:** any field not in the unit or weapon spec fails validation.
- **Alternatives:** warn only, or ignore.
- **Why:** a typo such as `maxspeed` would otherwise silently fall back to the template value. That is exactly the kind of bug that should "fail loudly in Studio, not mid-match" (guide 4.1). A new field means adding one line to the spec in `Defs.luau`.

## D4 — Separate 1-based index spaces for units and weapons (2026-10-20)

- **Decision:** `unit.index` runs 1..N over units sorted by id, and `weapon.index` runs 1..M over weapons sorted by id.
- **Alternatives:** one shared index space, or 0-based.
- **Why:** packets name the kind of def by context (`defIndex` in BUILD is always a unit, `weaponDefIndex` in SPAWN_PROJ is always a weapon). 1-based matches Luau arrays, and 0 is already reserved on the wire (Schema).

## D5 — Defs hash: FNV-1a 32-bit over a canonical serialization (2026-10-20)

- **Decision:** `Util/Hash.value` walks the built defs with sorted keys and hashes numbers by their IEEE-754 bytes (`string.pack("<d")`).
- **Alternatives:**
  - SHA-256: needs a pure-Luau implementation and is slower, with no security need here.
  - Hashing a formatted string: printf output can differ between platforms.
  - A 64-bit hash.
- **Why:** it's deterministic on every runtime and cheap. 32 bits is plenty to detect a stale client. If accidental collisions ever become a worry, two independent FNV passes give 64 bits.

## D6 — Wrecks deferred; Lancer and Ravager have no `wreck` yet (2026-10-20)

- **Decision:** `wreck` is optional and validated only if present. There are no `neu_wreck_*` defs yet.
- **Alternatives:** add minimal feature defs now.
- **Why:** wreck defs need a feature schema (supply value, footprint, model) that belongs with M2 (deaths and wrecks).

## D7 — Lancer and Ravager stats are placeholders (2026-10-20)

- **Decision:**
  - Both are T1 tracked tanks with armor class ARMORED.
  - Lancer: 1100 HP, cannon with 180 range and 0.5° spread.
  - Ravager: 1300 HP, cheaper, cannon with 160 range, 1.2° spread and more damage.
- **Alternatives:** the LIGHT armor class for light tanks.
- **Why:** they match the faction doctrines in guide 2.1. Balance happens in M8.

## D8 — Cell indices are 0-based, `index = cz * cellsX + cx` (2026-10-20)

- **Decision:** cells are addressed by 0-based `(cx, cz)` or by a 0-based row-major index. Layer buffers use the same index (`offset = index * bytesPerCell`).
- **Alternatives:** 1-based indices to match Luau arrays.
- **Why:** the index is the `u16` on the wire (0..65535 for 256×256), and buffers are 0-based. Converting once at the edges would invite off-by-one bugs.

## D9 — `Grid.encode` clamps out-of-map positions to the edge (2026-10-20)

- **Decision:** a world position outside the map encodes as the nearest edge cell (offset 0 or 255).
- **Alternatives:** raise an error.
- **Why:** the wire must never carry an invalid cell, and a unit sitting exactly on the far edge (x == maxX) is legitimate floating-point noise. Keeping units inside the map is Movement's job; that's tested there.

## D10 — Offsets truncate (floor); decode returns the step's low corner (2026-10-20)

- **Decision:** `off = floor(frac * 256)` and `decode` uses the guide's formula unchanged, so the error is in `[0, 1/32)` stud, always toward the cell origin.
- **Alternatives:** round to nearest (error ≤ 1/64, but 255.5 rounds to 256 and needs carry into the next cell), or decode at the step center.
- **Why:** it's simplest and never carries. 1/32 stud is far below anything visible.

## D11 — Map layers live in `Grid/Layers.luau`; test maps in `Grid/TestMap.luau` (2026-10-20)

- **Decision:**
  - `Layers` owns the terrain inputs (`height`, `waterDepth`: i16 in 0.25-stud steps, rounded to nearest). Derived layers (slope, passMask, clearance) are added by the passability builder.
  - `TestMap.generate` is 3-octave value noise (lattice spacings 32/8/4 cells) seeded by `Prng`.
  - Water fills everything below `seaLevel`.
  - `TestMap.build` makes hand-built maps from a per-cell callback.
- **Alternatives:** Perlin or simplex noise, or loading the guide's `MapData/` format.
- **Why:** value noise is enough for hills and lakes, and it's cheap and deterministic. Real maps come from the Studio bake in M1+.

## D12 — Debug images: PPM plus PNG written from Lune (2026-10-20)

- **Decision:** `.lune/lib/Ppm.luau` writes binary PPM and also PNG (zlib via `@lune/serde`, CRC-32 in Luau), so images open directly on Windows. Debug scripts are `.lune/debug_*.luau` and write to `debug_out/`.
- **Alternatives:** PPM only.
- **Why:** PPM isn't viewable without extra software, and PNG takes about 30 extra lines.

## D13 — Unit IDs: fresh first, then FIFO reuse after 150 ticks (2026-10-20)

- **Decision:** `World.spawn` hands out never-used IDs (1..65535) first. After that it reuses freed IDs oldest-first, and only once `REUSE_DELAY_TICKS = 150` (10 s) have passed since they were freed.
- **Alternatives:** reuse freed IDs as soon as their delay passes, even while fresh IDs remain.
- **Why:** fresh-first keeps IDs unique for as long as possible, which makes logs and replays easier to read. Both are deterministic.

## D14 — Heading is radians, 0 = +Z, counter-clockwise (2026-10-20)

- **Decision:** `World.heading` holds radians. The wire `heading u8` is quantized from it when NetOut exists.
- **Alternatives:** degrees.
- **Why:** sin/cos take radians directly, so the movement and aim math needs no conversions.

## D15 — Replay format: entry kinds and length-prefixed payloads (2026-10-20)

- **Decision:**
  - The header is `"FTGR"`, then format u8, protocol u16, defs hash u32, seed u32, map id, scenario, and players.
  - Each entry starts with a `kind u8`:
    - COMMAND: `[tick u32][player u8][len u16][payload]`.
    - CHECKPOINT: `[tick u32][hash u32]`, written every 300 ticks.
  - A command is recorded at the tick it is **applied**.
- **Alternatives:** the guide's bare `[tick u32][player u8][payload]` with checkpoints in a separate file.
- **Why:** a payload has no self-delimiting length (a command's length depends on its type), and checkpoints belong next to the commands they verify. Guide 17.1 is updated.

## D16 — Match start comes from a named scenario (2026-10-20)

- **Decision:** `Sim/Scenarios.luau` maps names to deterministic setup functions (`empty`, `skirmish_test`). The name is stored in the replay header.
- **Alternatives:** record initial spawns as replay entries.
- **Why:** a replay rebuilds the same start from seed + scenario + players. The real start (Command Vehicles at start positions) becomes another scenario once maps exist.

## D17 — Commands system: only state commands have effects yet (2026-10-20)

- **Decision:**
  - SET_FIRE_STATE, SET_MOVE_STATE and TOGGLE apply to the sender's own units. Other unit IDs are skipped silently.
  - MOVE, ATTACK, BUILD and the like are decoded, recorded and accepted, with no effect until their systems exist.
  - Malformed payloads, trailing bytes and unknown players are rejected in `Sim.submit` (counted in `sim.stats`) and never reach the queue.
- **Alternatives:** reject the whole command if any unit isn't owned.
- **Why:** with multi-select, some units may have died since the client sent the command. Applying to the valid ones is what players expect.

## D18 — The Heartbeat tick loop waits for the Roblox entry script (2026-10-20)

- **Decision:** `Sim.step` is a pure function of state. The accumulator loop (whole ticks only, at most 2 catch-up ticks per frame) belongs in `Main.server.luau`, which needs Studio.
- **Alternatives:** a runtime-agnostic loop driven by `Profiler.now()`.
- **Why:** the loop is about wall-clock time, which the headless sim must never read. Tests drive `Sim.step` directly.

## D19 — Sim hash = tick + PRNG state + world, units in ID order (2026-10-20)

- **Decision:** `Sim.hash` folds in the tick, the four PRNG state words, then `World.hash`. World.hash covers every gameplay field and the ID allocator, visiting units in ascending ID order.
- **Alternatives:** hash positions and health only (the guide's minimum).
- **Why:** desyncs in the PRNG or the allocator show up a checkpoint earlier. Sorting by ID makes the hash independent of swap-remove order.

## D20 — Server tests require Sim modules relatively (2026-10-20)

- **Decision:** `src/server/Tests/*.spec.luau` use `require("../Sim/World")`.
- **Alternatives:** a new `@server` alias.
- **Why:** Tests and Sim are both under `src/server`, so they share one root, and `../Sim/X` resolves identically in Roblox (`ServerScriptService.Tests` → `ServerScriptService.Sim`). This follows the "relative within a root" rule.

## D21 — Footprint rule: `clearance >= floor(F/2) + 1`, not `ceil(F/2)` (2026-10-20)

- **Decision:** clearance is the Chebyshev distance to the nearest blocked cell (blocked = 0, a free cell touching a blocked cell = 1). A footprint-F unit fits on a cell when `clearance >= floor(F/2) + 1`, i.e. the (2r+1)² square around the cell is free for r = floor(F/2).
- **Alternatives:**
  - The guide's `ceil(F/2)`, which gives 1 for F = 2, so a 2×2 unit would fit a 1-cell gap. That contradicts the requested test and the intent.
  - Corner-anchored "true clearance" (largest free square with the cell as its min corner), which is exact for even footprints but makes even-sized units asymmetric around their center.
- **Why:** it's symmetric and simple, and it's one distance transform per move class. Even footprints are treated like the next odd size, so a 2×2 unit needs a 3-wide passage. That's conservative by one cell; switch to corner-anchored clearance if 2-wide gaps must admit 2×2 units. Guide 6.2 is updated.
- **Confirmed by the user (2026-10-20):** keep this rule. Ground units should prefer odd footprints, and map chokepoints must be at least 3 cells wide (guide 5.5, 6.2).

## D22 — Slope = steepest climb to a 4-neighbor (2026-10-20)

- **Decision:** `slope[c] = atan(max |h(n) - h(c)| / 8)` over the 4-neighbors, stored as u8 (0..255 → 0..90°). Move-class limits compare against the same quantization (`degreesToSlope(maxSlope)`).
- **Alternatives:** 8-neighbors (diagonals over 8√2), a gradient vector magnitude, or the bake's per-cell raycast maximum (guide 5.4).
- **Why:** it's cheap and conservative at cliffs, and the cells on both sides of a step become steep. The Studio bake can replace the slope layer with raycast data without changing anything downstream.

## D23 — Outside the map counts as blocked for clearance (2026-10-20)

- **Decision:** border cells have clearance at most 1.
- **Alternatives:** ignore the map edge.
- **Why:** big units shouldn't hang off the map, and it keeps the footprint rule uniform at the edges.

## D24 — Surface rules per move class (2026-10-20)

- **Decision:**
  - Land classes need `water <= maxFord` and `slope <= maxSlope`.
  - SHIP/SUB need `water >= minDepth`.
  - HOVER: any water cell (the surface is flat), else the slope limit.
  - AMPHIB: the slope limit only (it drives on the sea floor).
  - Air: always.
- **Alternatives:** HOVER also checking shoreline slope; AMPHIB limited in depth.
- **Why:** this is a direct reading of guide 6.1. Edge cases (hover climbing steep beaches) can be tightened when real maps exist.

## D25 — Pathing algorithms live in `src/server/Sim/Path/` (2026-10-20)

- **Decision:** `Path/Heap.luau`, `Path/Quadtree.luau`, `Path/Route.luau`, with flow fields to follow. The `Systems/Pathing.luau` system (requests, budgets) will call into them.
- **Alternatives:** put everything in `Systems/Pathing.luau`; or put the algorithms under `src/shared` for client path previews.
- **Why:** the algorithms are pure functions over buffers, so they are testable alone and can be required from Actor workers (guide 6.4 Parallel Luau). The client doesn't need them yet.

## D26 — One quadtree per (move class, required clearance) (2026-10-20)

- **Decision:**
  - A cell is passable for the tree when `clearance[mc] >= need`.
  - The root is the next power of two over the map, and cells outside the map count as blocked.
  - Leaves are uniform squares found with a summed-area table.
  - Open leaves link to edge-sharing open leaves only (4-connectivity).
  - Each open leaf gets a connected-component ID.
- **Alternatives:** one tree per move class with footprints handled in A*; 8-connectivity at corners.
- **Why:**
  - Footprint changes which cells are passable, so it changes the decomposition.
  - Corner-only contact must not count as a connection, because flow fields never cut corners.
  - Component IDs reject unreachable goals in O(1).
  - Cost is about 6 ms per tree on 256×256 at load (trees are built lazily per class and need).

## D27 — A* over leaves: start/goal cells as endpoints, Euclidean costs (2026-10-20)

- **Decision:**
  - Node positions are leaf centers, except the start and goal leaves, which use the actual start and goal cells.
  - Edge cost is the Euclidean distance; the heuristic is the straight line to the goal (admissible and consistent).
  - Ties break on f, then h, then leaf ID.
  - It fails with `start_blocked`, `goal_blocked` or `unreachable`.
- **Alternatives:** costs from shared-edge midpoints (shorter, more accurate routes, more work per expansion).
- **Why:** it's simple, deterministic and fast (about 2.5 ms corner to corner on a 256×256 hilly map). The flow field inside the corridor does the fine routing anyway.

## D28 — Corridor = route leaves + all open leaves adjacent to them (2026-10-20)

- **Decision:** padding is "one neighbor ring" of leaves (guide 6.3), not one ring of cells.
- **Alternatives:** dilate the route leaves by one cell.
- **Why:**
  - Adjacent leaves give units room to spread and avoid each other without leaving the field.
  - On open terrain the corridor can cover most of the map (20,545 cells on a 256×256 hilly map, corner to corner). That makes the flow field as big as it gets, which task 8 measures.
  - If that's over budget, switch to cell dilation; it's one function.

## D29 — Pathing time-slices count work units, not milliseconds (2026-10-20)

- **Decision:** `FlowField.run(job, budget)` spends at most `budget` work units: one per settled cell (Dijkstra) and one per directed cell. The per-tick budget will be a work-unit count calibrated from the benchmark (task 8) to fit the 8 ms Pathing budget.
- **Alternatives:** a wall-clock budget (`Profiler.now()`), as guide 6.4's "8 ms" suggests literally.
- **Approved by the user (2026-10-20).**
- **Why:** with a clock budget, the tick on which a field completes, and therefore every unit's path, would depend on server CPU speed and load. That breaks the "deterministic on the server" rule and makes replays diverge. Work units keep slicing invisible to the outcome: a sliced job is byte-identical to a one-shot job (tested). The same concern applies to Actor workers later: their results must be applied at a deterministic tick.

## D30 — Flow field encoding and costs (2026-10-20)

- **Decision:**
  - Direction u8 runs 0..7 counter-clockwise from +X (0 = +X, 2 = +Z, 4 = −X, 6 = −Z; odd = diagonal). 255 = none, which covers the goal cell itself, cells outside the corridor, and cells the goal can't reach.
  - Straight steps cost 1 and diagonal steps √2. Diagonals never cut corners.
  - Terrain modifiers are 1 for now, since there is no terrainType layer yet.
  - Ties go to the lowest direction number.
- **Alternatives:** a separate "goal" value (254), or 4-connected fields.
- **Why:** it matches guide 6.3 ("255 = none"). Units at the goal cell compare their cell with `field.goalCell`. With 8-connected fields and no corner cutting, units move naturally and never clip wall corners.

## D31 — Field cache key includes the clearance need; recency is a counter (2026-10-20)

- **Decision:**
  - The key is `moveClass:need:goalCell` (the guide says `(moveClass, goalCell)`).
  - LRU recency is a use counter, not a clock.
  - `invalidateCell(cell)` drops every field whose corridor contains the cell, for when structures change passability.
- **Alternatives:** a key without need, which would mix fields for different footprints.
- **Why:** a footprint-2 field differs from a footprint-1 field to the same goal. A counter keeps eviction deterministic.
- **Open question for task 9:** a cached field was built inside one start's corridor. A unit starting outside that corridor needs a new route, merged into the cached corridor or replacing it.

## D32 — Direction fields are full-map buffers (2026-10-20)

- **Decision:** each field stores a `cellCount`-byte direction buffer (64 KB at 256×256) indexed by cell, even though only the corridor is filled.
- **Alternatives:** store only the corridor's bounding box.
- **Why:** indexing is trivial (`dir[cell]`), and 32 cached fields cost 2 MB, which is fine for a server. If memory matters, store the bbox and offset the index.

## D33 — Pathing budget: 12,000 work units per tick (2026-10-20)

- **Decision:** `Pathing` will spend at most 12,000 flow-field work units per tick. The benchmark measured 1,640–2,740 units/ms in Lune on this PC (task 8), so 8 ms ≈ 13,000 units at the slowest map, rounded down.
- **Alternatives:** a wall-clock budget (rejected in D29); a lower budget with Actors doing the heavy lifting.
- **Why:** it's deterministic and close to the guide's 8 ms on the measured hardware. Re-calibrate on a live Roblox server (`--!native` codegen and server CPUs differ from Lune on a desktop) and change the one constant.

## D34 — The sim loads terrain from a map ID (2026-10-20)

- **Decision:**
  - `Shared/Grid/MapRegistry` turns `mapId` into layers: `none`, `flat:<n>`, `wall:<n>` (a water wall with one gap), `gen:<seed>:<n>`.
  - `Sim.new` builds passability and `Nav` when there is a map. `"none"` runs without movement.
  - Unknown IDs are errors.
- **Alternatives:** pass layers directly in the config.
- **Why:** the map ID is in the replay header, so a replay rebuilds the same terrain. Baked maps become `baked:<name>` later.

## D35 — One shared field per group; each unit has its own slot and steers straight when it can (2026-10-20)

- **Decision:**
  - Units of one MOVE are grouped by (move class, clearance need). Each group gets one order and one flow field to the group goal.
  - Each unit gets its own goal (a formation slot).
  - A unit steers straight to its slot when its cell and the slot share an open quadtree leaf, or when a sampled line check (every 2 studs, within 96 studs) is clear. This is re-checked every 4 ticks, staggered by ID.
  - Otherwise it follows the field. With no field yet (job still running), it steers straight.
  - The group corridor comes from one leaf-level Dijkstra (`Route.findMany`) covering every member's start leaf.
- **Alternatives:** one field per unit goal (50× the cost); A* waypoints per unit.
- **Why:** guide 6.3/6.6 say "all units in one move order … share one field" and "each gets its own goal cell". The same-leaf shortcut is benchmark fix #1: open terrain needs no field near the goal.

## D36 — Spatial hash buckets are 16 studs, not 8 (2026-10-20)

- **Decision:** separation and overlap queries use 16-stud buckets, searching `ceil((2·maxRadius + 2) / 16)` rings (1 ring for footprint ≤ 2).
- **Alternatives:** the guide's 8-stud cells (6.5), searching two rings (5×5).
- **Why:** the separation reach for two footprint-1 units is 9.2 studs, more than one 8-stud cell. 16-stud buckets with a 3×3 search cover it with fewer bucket visits. The hash uses linked lists in reused arrays, so it doesn't allocate per tick.

## D37 — Collision radius = 0.45 × footprint × 8 studs; overlaps resolved by position (2026-10-20)

- **Decision:**
  - A footprint-1 unit has radius 3.6 studs.
  - After moving, overlapping pairs are pushed apart (2 passes): 50/50 when both are moving or both idle, 80/20 with the idle unit yielding (push priority, guide 6.5).
  - A push that would enter blocked terrain is skipped.
- **Alternatives:** velocity-only avoidance (RVO/ORCA).
- **Why:** it's simple and deterministic, and it guarantees near-zero overlap. Measured worst overlap at rest is 0.20 studs. RVO is worth revisiting if crowds jam in real maps.

## D38 — Arrival, give-up and holding position (2026-10-20)

- **Decision:**
  - Arrived means within 1.5 studs of the unit's own goal.
  - A unit within 24 studs whose distance hasn't improved by 0.5 stud in 45 ticks also ends its order (crowded goal), and its current spot becomes its goal.
  - Idle units hold their goal: one pushed more than its radius away walks back at 60% speed, unless it's within 6 studs and already stopped.
  - STOP sets the goal to the current position.
- **Alternatives:** exact arrival only (units jam forever on a crowded slot); never returning (arrived units get shoved 45 studs away by later arrivals, as observed).
- **Why:** guide 6.6: "units within a radius of the goal stop rather than pushing to the exact cell". Holding the spot keeps the formation after the crowd passes.

## D39 — Fields are extended for units that leave the corridor or stall (2026-10-20)

- **Decision:**
  - Each tick, units whose cell has no field direction, or with no progress for 90 ticks, are collected per order.
  - `Nav.extendField` routes them (`findMany`), merges the result into the current corridor and queues a new field job.
  - At most once per 15 ticks per order, and never while a job is pending.
- **Alternatives:** per-unit fallback fields; letting stuck units give up.
- **Why:** crowd pushes moved a unit against a wall outside the corridor, and steering straight then pinned it there forever (seen on `wall:96`). The extension fixed it in 3–5 extra fields on the wall maps.

## D40 — Formation slots: lattice around the goal, far side filled first (2026-10-20)

- **Decision:**
  - Slots are lattice points around the group goal, spaced 1.3 × the largest unit diameter, nearest first, keeping only open cells in the group's component.
  - A goal on blocked ground snaps to the nearest open cell (BFS).
  - Slots are filled far side first along the approach direction, each by the nearest unassigned unit.
  - Line moves: evenly spaced points from start to end. When the line is too short, extra rows step back toward the group's centroid.
- **Alternatives:** center-first filling. It measured worse: worst unit 27.8 studs from its slot versus 16.5, and 32 versus 35 of 50 within 2 studs on average across 9 maps.
- **Why:** units that arrive first take the deepest slots, so later arrivals don't have to squeeze past them.

## D41 — FIGHT and PATROL move like MOVE for now; the queue flag is ignored (2026-10-20)

- **Decision:** FIGHT (attack-move) and PATROL issue plain moves. A new order replaces the current one, even with the QUEUE flag.
- **Alternatives:** ignore them until their systems exist.
- **Why:** players expect units to move. Attack-move becomes "move, engage targets on the way" in task 10 or M2. Order queues (shift) need an order list per unit, which is a later task.

## D42 — Tracked-vehicle movement model (2026-10-20)

- **Decision:**
  - Units move only along their heading (forward = `(sin h, cos h)`). The heading turns toward the desired direction at `turnRate`.
  - Target speed is `min(maxSpeed, sqrt(2·brake·distance))` scaled by `max(0, cos(heading error))`, so a unit facing away turns in place.
  - Speed changes at `accel` / `brake`.
  - A blocked cell makes the unit slide along the free axis at half speed, or stop.
- **Alternatives:** holonomic movement (strafe freely).
- **Why:** it fits tanks. Turn rate becomes gameplay, consistent with the aim model's philosophy (guide 10.3). Jets and helis get their own models in M6.

## D43 — Full visibility until Sensors exist; one contact grid with team filtering (2026-10-20)

- **Decision:** `Combat/ContactGrid` is one 64-stud bucket grid of all live units, rebuilt in Targeting and again in Projectiles (after Movement). "Enemies of team T near P" is a query that skips T's units. Every enemy counts as known.
- **Alternatives:** separate grids per team, filled only with what that team can see.
- **Why:**
  - Sensors (LOS/radar maps, guide 11) are M4. Until then every enemy is visible anyway, so per-team grids would hold the same units.
  - When fog arrives, the visibility test goes into `ContactGrid.query`, or per-team grids get built from the sensor maps, without touching Targeting.

## D44 — Targeting: per weapon, staggered, sticky (2026-10-20)

- **Decision:**
  - Each weapon slot has its own target (`World.wTarget[id*8+slot-1]`).
  - A target stays while it remains valid (alive, an enemy, a hittable category, within range × 1.1 + its radius, in arc, and allowed by the fire state). Otherwise it's dropped at once.
  - Weapons without a target search only on their unit's stagger tick (`(id + tick) % 6 == 0`).
  - Score is `(1 + priority rank) / distance`; ties go to the lower ID.
  - Return Fire only engages `lastAttacker`.
  - There is no focus-fire bonus or overkill penalty yet.
- **Alternatives:** unit-level targets; re-scoring every tick.
- **Why:** guide 10.2 (staggering, hysteresis). Per-weapon targets are needed anyway for mixed AA/AG units. The optional heuristics can come with the M8 balance pass.

## D45 — Aim model details (2026-10-20)

- **Decision:**
  - Turret yaw is relative to the hull, and pitch is absolute; both rotate at the def rates.
  - Wanted pitch is the low-arc ballistic solution for BALLISTIC/BOMB weapons (nil when out of reach) and the straight line for HITSCAN/BEAM.
  - A weapon fires when both axes are within `tolerance`, the pitch is within [minPitch, maxPitch], the target is within range + its radius, and it's reloaded.
  - Without a target the turret returns to rest (0, 0).
  - Reload keeps a fractional carry of at most one tick while firing continuously.
  - Changing aim marks the unit's STATE dirty bit.
- **Alternatives:** world-frame turret yaw; target leading.
- **Why:** guide 10.3. A slow turret measurably fires later: 30°/s versus 180°/s gives first shots at tick ≥85 versus ≤25 (tested). Leading moving targets is left for M2 tuning.

## D46 — Spread, hitscan resolution and weapon-type gaps (2026-10-20)

- **Decision:**
  - Each shot draws yaw and pitch errors uniformly in ±`accuracy`° from `sim.rng`, in system order.
  - HITSCAN/BEAM hit when the total error (turret offset + spread) keeps the shot within the target's radius sideways and its half-height vertically at the target distance.
  - HOMING and TORPEDO currently fly as straight projectiles (guidance is M7).
  - `salvo.count > 1` isn't implemented; every def uses 1.
- **Alternatives:** Gaussian spread; ray tests against every unit along a hitscan line.
- **Why:** it's deterministic, cheap and good enough for the duel tests. Hitscan doesn't hit bystanders yet.

## D47 — Collision volumes and projectile flight (2026-10-20)

- **Decision:**
  - Units are vertical cylinders: radius 0.45 × footprint × 8 studs (same as movement), height 6 × footprint, standing on the terrain (plus altitude).
  - Projectiles use the exact ballistic step per tick, then a swept test of the tick's chord against enemy cylinders and the terrain (linear between the chord's ends). The earliest contact wins.
  - ttl = 2·range/speed + 1 s.
  - Pool cap 2,000: at the cap, a shot resolves like hitscan.
  - Projectile IDs are reused FIFO without delay (IMPACT is reliable and ordered).
- **Alternatives:** the guide's "oldest shells resolve at predicted impact" at the cap; sphere volumes.
- **Why:** guide 10.5. Tested: a 3,000 stud/s round (200 studs per tick) still hits a 7-stud tank. Resolving the new shot at the cap is simpler than predicting old shells' impacts and equally deterministic.

## D48 — AoE and friendly fire (2026-10-20)

- **Decision:**
  - AoE distance is measured from the blast to each unit's cylinder surface, so a tank touching the blast takes full damage.
  - The struck unit takes full damage.
  - Friendly fire for AoE is on by default (`sim.combat.friendlyFire`). Direct hits never strike allies; projectiles pass through them.
  - A hitscan miss with `aoe > 0` explodes on the ground at the target distance.
- **Alternatives:** center distance (big units would shrug off blasts at their edge); friendly fire off by default.
- **Why:** guide 10.6 says it's toggleable per match; on is the BAR-like default.

## D49 — Deaths, wrecks and events (2026-10-20)

- **Decision:**
  - Weapons and projectiles queue damage; the Damage system applies it in queue order, then removes the dead in the order they died.
  - Severity = overkill / max health (0..1, u8 in DEATH). A unit killed with severity ≤ 0.5 leaves a wreck worth 50% of its supply cost.
  - Wrecks live in `sim.combat` (position, def, supply) until a features system exists.
  - Each tick's events (FIRE, SPAWN_PROJ, IMPACT, DEATH) are in `sim.combat.events` for NetOut and tests.
- **Alternatives:** applying damage immediately (order-dependent within a tick); wreck defs (D6).
- **Why:** guide 10.6, 8.7, 7.3. Queued damage makes simultaneous kills symmetric within a tick.

## D50 — Placeholder stats make Ravagers win the close duel (2026-10-20)

- **Observation:** in `duel_test` (140 studs apart, inside both ranges) Chaos wins 10 of 10 seeds with 5 Ravagers left after about 15 s. The Ravager has more HP (1300 vs 1100), a faster reload (1.4 vs 1.6 s) and more damage (125 vs 120 vs ARMORED); the Lancer's longer range (180 vs 160) doesn't come into play.
- **Decision:** no stat changes; balance is M8 (guide 21).
- **Why:** this matches the faction doctrine (Chaos wins brawls, Order wins at range). A range-advantage scenario is the natural counter-test.

## D51 — Transcendental math may differ across platforms (risk logged, 2026-10-20)

- **Observation:** Movement and Weapons use `math.sin`, `cos`, `atan`, `atan2`, which come from the platform's C library. IEEE-754 guarantees exact results for `+ − × ÷ sqrt`, but not for these.
- **Consequence:** the sim is deterministic on one platform (all tests, and replays on the same server OS). A replay recorded on a Roblox server (Linux) and replayed in Studio on Windows *might* diverge in the last bits, and the checkpoint hashes would report it.
- **Decision (user, 2026-10-20):** accept same-platform re-simulation. Player-facing replays will store the server's sent stream; command-log re-simulation is a developer tool (guide 17.1).
- **Test audit:** no test hard-codes a simulation hash value. Every Sim/World hash check compares two runs, or a run and its replay. The only literal values are reference vectors for FNV-1a and xoshiro128**, and the Schema wire bytes, which test those functions and the wire format, not simulation state.
- **Alternatives:**
  - Pure-Luau trig (polynomial approximations using only exact operations).
  - Fixed-point angles with lookup tables.
  - Always replaying on the same platform as the recording.
- **Why not now:** it touches every angle computation, it's a design choice, and it only matters for cross-platform replay.

## D52 — Direct-path shortcut when a move is issued (2026-10-20, user-requested fix (a))

- **Decision:**
  - In `Nav.issueMove`, each ground unit's straight line to its slot is checked once, in full. The check is exact and free when unit and slot share an open quadtree leaf; otherwise `clearLine` samples every 2 studs.
  - Units with a clear line steer directly. Only the others are routed and covered by the group's field; if every line is clear, no field is built.
  - Movement trusts that check for field-less orders. A unit on such an order that stalls for 90 ticks triggers `Nav.extendField`, which now also builds a first field.
- **Alternatives:** check only near the goal (the previous behavior); per-tick line re-checks for every unit (costly over long distances).
- **Why:** open terrain needs no flow field at all. A 50-unit move across an open 256×256 map went from a 79 ms field to 0.35 ms (PROGRESS, Benchmarks).

## D53 — Bucket-queue integration; pathing budget recalibrated to 36,000 units (2026-10-20, user-requested fix (b))

- **Decision:**
  - Flow field integration uses a bucket queue (Dial's algorithm) with buckets one cost unit wide (floor of the cost). Entries are linked per bucket, LIFO within a bucket.
  - Because every step costs ≥ 1, cells in the current bucket are final, so the costs are exactly Dijkstra's. Verified byte-identical directions and costs against the heap version on four 256×256 maps.
  - The per-tick budget is re-measured: about 4,700 units/ms at the slowest map, so 8 ms ≈ 37,000 units. `Nav.PATHING_BUDGET` rounds down to 36,000.
- **Alternatives:** integer 10/14 costs with exact Dial buckets (changes the field values); a radix heap.
- **Why:** queue operations become O(1) with no change in output: integration is 3.9× faster on the open map. **Constraint for later:** terrain cost modifiers must keep the minimum step cost ≥ 1 (the bucket width), or the bucket width must shrink to match.

## D54 — Report-only duel scenarios; no rebalance (2026-10-20, user-requested)

- **Decision:** `.lune/report_duels.luau` prints outcomes with no pass/fail. Equal cost means equal supply: 13 Lancers (1,950) vs 15 Ravagers (1,950).
  - **close:** lines 100 studs apart, so every pair is inside both guns' range.
  - **kite:** open 256×256 map. Ravagers attack-move at the Lancers' centroid every 30 ticks. Every 10 ticks each Lancer keeps its nearest Ravager at 168–178 studs: back off below 168, close in above 178, otherwise stop and shoot.
- **Results (5 seeds):**
  - close: **Chaos wins 5/5** with 10 Ravagers left after 13 s, identical every seed because spread hardly matters at this range.
  - kite: **Order wins 3/5** with 2 Lancers left after 89–125 s; **Chaos wins 2/5** with 10–13 Ravagers left after about 34 s, when the kite breaks down.
- **Why no rebalance:** as instructed. Note that kiting quality depends on the scripted micro (band, re-command rate, turning tracked hulls around). A first version with a band of 170–185 parked Lancers just beyond their own 183.6-stud reach, and the fights stalled to timeout. That was a script bug, fixed before recording these numbers.

## D55 — Economy def fields and the M3 placeholder roster (2026-10-20)

- **Decision:**
  - New optional unit-def fields: `production {supply, power}` (per second while built), `extractor {rate}` (supply/s per deposit value; structures only), `storage {supply, power}` and `placement` (structures only).
  - Mobile builders must have `buildRange`.
  - New templates: `Templates.Structure` and `Templates.Builder`.
  - New defs, per faction:
    - Command Vehicle: `ord_sovereign` / `chs_warlord`, BP 300, range 80, +1 supply and +20 power per second.
    - Worker: `ord_mason` / `chs_scrapper`, BP 100.
    - Extractor (footprint 1, rate 0.5).
    - Generator (footprint 1, +20 power, +100 power storage).
    - Vehicle Plant (footprint 3, BP 100, builds the worker and the T1 tank).
  - Footprints are odd (user, D21).
  - Names follow guide 13 where it has them. Extractor, Generator and Plant names are placeholders (Extractor/Excavator, Generator/Furnace, Vehicle Plant/Vehicle Foundry).
- **Alternatives:** separate structure defs; factory flags.
- **Why:** a factory is simply a structure with `buildOptions` and `buildPower`. Costs follow guide 8.5 proportions and BAR-like magnitudes; balance is M8.

## D56 — Supply deposits as a map layer; `start:<n>` test map (2026-10-20)

- **Decision:** `Layers.supply` (u8 deposit value per cell, guide 5.2) and `Layers.starts` (start positions). `MapRegistry` `start:<n>` is flat, with west and east starts, 4 deposits of value 4 around each and 2 in the middle.
- **Why:** the build-order scenario needs deposits and starts. The Studio bake will fill the same layers from tagged parts (guide 5.4).

## D57 — Economy settlement: income from producers, charge actual spend (2026-10-20)

- **Decision:**
  - One account per ally team (`Sim.team`). Overflow above storage is wasted (counted), since allies already share the account.
  - Every 5th tick: income and storage are recomputed from the producer list. Then `stored := clamp(stored + income × window − spent + reclaimed, 0, storage)` and `ratio := min(1, (stored + income × window) / (demand × window))`.
  - Construction spends each tick at `rate × effective ratio`, charges only what it actually spent, and is capped by the window's allowance, so stored can't go negative even when demand rises mid-window.
  - The effective ratio of a consumer is the minimum over the resources it uses (two passes, guide 8.4).
- **Alternatives:** the guide's incremental running totals for income and demand (updated on every change); charging `demand × ratio` at the step.
- **Why:**
  - Recomputing income from the producer list at 3 Hz is O(producers) and can't drift. Demand is reported by Construction each tick from the actual active jobs.
  - Charging the actual spend makes the "refund the unused part" of guide 8.4 automatic.
  - If a producer dies mid-window, the window's income is credited at the new rate, and a tiny shortfall is forgiven (stored is floored at 0).

## D58 — `Lifecycle` is the single place units are added and removed (2026-10-20)

- **Decision:** `Sim/Lifecycle.luau`. `added` registers producers (complete units such as the Command Vehicle). `completed` registers finished structures. `remove` clears producers, the move order, and registered hooks (construction, placement), then despawns. `Spawn.unit` and the Damage system go through it.
- **Why:** every subsystem with per-unit state stays consistent. Modules above it in the require graph register removal hooks instead of creating require cycles.

## D59 — Clearance capped at 16; exact local updates when structures change (2026-10-20)

- **Decision:**
  - Clearance values are capped at `CLEARANCE_CAP = 16`, since no footprint needs more.
  - A structure's footprint is written to an `occupancy` layer (u16 structure ID per cell) and blocks every non-air class.
  - `Passability.updateRect` recomputes passMask for the changed cells, then reruns the distance transform on the change expanded by 2 × CAP, and writes back the inner band (change + CAP). That's exact for both placement and removal, because a capped clearance depends only on blocked cells within CAP.
  - Release clears only cells the structure itself occupies.
  - `Nav.terrainChanged` drops every quadtree (lazily rebuilt) and the cached fields that touch the change. Orders keep their field, and units it leads into a new structure stall and get an extended field (D39).
- **Alternatives:** an uncapped full-map recompute per change (about 75 ms on 256×256 for all classes); an exact uncapped local update (needs unbounded windows for removals).
- **Why:**
  - It's exact (verified against a brute-force Chebyshev clearance on every cell and class), and the window is small: (F + 64)² cells per class.
  - The map-load build uses the same transform, still about 77 ms on 256×256.

## D60 — Placement rules (2026-10-20)

- **Decision:**
  - Footprints snap to the grid: odd sizes center on a cell, even ones on a cell corner.
  - A placement is valid when every cell is in bounds, unoccupied, and fits the placement class: land = dry and slope ≤ 30°; water = depth ≥ 6 studs; either = one of the two.
  - Extractors need a deposit under their center.
  - No ground unit's collision circle may overlap the footprint.
  - `Spawn.unit` places complete structures without checks (scenarios and tests); construction always checks.
- **Alternatives:** push units out of the footprint (BAR does).
- **Why:** it's simple and deterministic. Pushing units aside can be added when construction AI needs it.

## D61 — Construction model (2026-10-20)

- **Decision:**
  - **BUILD to a mobile builder:** it drives until the site is within `buildRange + half the footprint`, then checks placement. If valid, it starts an unfinished frame (1% health, occupying its footprint). Another builder arriving at the same site with the same order assists that frame instead. An invalid site gives `BUILD_FAILED` with a reason.
  - **Progress:** per tick, `ΣBP / buildTime × effective ratio`, also capped so the spend never exceeds the window allowance. Health grows by `maxHealth × Δprogress`.
  - **Completion:** a finished frame starts producing (`Lifecycle.completed`), and its builders drop the target.
  - **Order:** targets are processed in the order their first builder appears in `world.ids`.
  - **Events:** `BUILD_START`, `BUILD_DONE`, `BUILD_FAILED`, `PRODUCED` and `RECLAIMED` are added to the per-tick event list.
- **Alternatives:** paying the full cost before building starts (explicitly ruled out by the guide); per-builder spending.
- **Why:** this is guide 8.2 and 9.3. Assisting is just more BP on the same target. Measured: a generator (1,200 units) takes 60 ticks at BP 300, exactly 4 s.

## D62 — Factories and assisting (2026-10-20)

- **Decision:**
  - BUILD sent to a complete factory appends to its queue (max 50). The head item advances with the factory's own BP plus assisting builders (REPAIR on the factory), at the same economy rates.
  - A finished unit spawns one cell outside the footprint on the factory's facing side and drives 24 studs further out.
  - REPAIR on an unfinished frame assists construction. Repairing damaged units is not done yet.
  - MOVE and STOP cancel a builder's work. Factories keep their queues; there is no cancel command yet.
- **Alternatives:** a nano-frame entity for the unit in production (BAR). Rally points.
- **Why:** it's simple and deterministic, and enough for the build-order test. Measured: a Lancer (4,500 units) at BP 100 takes 675 ticks = 45 s; a Command Vehicle assisting cuts it below half.

## D63 — Reclaim (2026-10-20)

- **Decision:** RECLAIM drives the builder in range of the wreck, then moves `buildPower × 0.1` supply per second from the wreck into the team account (settled at the next economy step, capped by storage). The wreck is removed when empty. Reclaim doesn't depend on the stall ratio.
- **Alternatives:** reclaim speed from a per-wreck reclaim time.
- **Why:** guide 8.7. Rate 0.1 makes a Mason (BP 100) reclaim a Ravager wreck (65 supply) in 6.5 s.

## D64 — Match start and the scripted build order (2026-10-20)

- **Decision:** scenario `standard_start` gives each player their faction's Command Vehicle (Order for odd teams, Chaos for even) at the map's start positions in player order, facing the center. The test driver (`Tests/Support/BuildOrder.luau`) plays only through `Sim.submit`, so its inputs are in the replay.
- **Observed** (`lune run report_buildorder`, both factions mirrored):
  - extractors at 6 and 12 s, generators at 16 and 20 s, vehicle plant at about 43 s;
  - three tanks by 107 s (Order) and 90 s (Chaos);
  - production then becomes power-bound (power ratio 0.45–0.5), the intended stall behavior for a build with too few generators.
- **Why:** M3 exit criterion "a full T1 build order is playable", proven headless and deterministic.

## D65 — Sensor maps and visibility (2026-10-20, task 11)

- **Decision:**
  - Per ally team, five maps on the 16-stud sensor grid (los, airLos, radar, sonar, jam), **u16** counts.
  - An emitter adds +1 to every sensor cell whose center is within its radius of the emitter's cell center (circle offsets cached per radius). It re-stamps only when its sensor cell changes; radii are cached per def, so a re-stamp allocates nothing.
  - Unfinished structures don't emit, and removal unstamps (Lifecycle hook).
  - `airSight` defaults to 1.5 × sight.
  - Visibility of every enemy unit for every team is recomputed on each sensor tick (every 2nd tick). Precedence: VISIBLE > GHOST (structures seen before) > RADAR / SONAR > HIDDEN. Submerged units are only SONAR or HIDDEN.
  - Ghosts keep def and position, outlive the structure, and are removed once the team's los covers the spot and the structure is gone.
  - `Sensors.radarDetects` is the hook for jamming and stealth (task 12).
- **Alternatives:** u8 counts (guide 11.2) could overflow under a few hundred stacked units; event-driven visibility (guide 11.3) is more complex.
- **Why:** visibility for all pairs is O(units × teams) buffer reads every 2 ticks, which is cheap and has no invalidation bugs. The stress test (task 14) will tell if it needs the event-driven version.

## D66 — Placeholder mobile radars (2026-10-20)

- **Decision:** `ord_oracle` "Oracle" (radar 700, wheeled, 380 HP) and `chs_watcher` "Watcher" (radar 600, 420 HP), per guide 13.2. Unarmed. Category `RADAR_EMITTER`.
- **Why:** radar contacts need an emitter. Order's radar is longer and more precise (wobble in task 12), per guide 11.6.

## D67 — Radar wobble, jamming, stealth, and fog-aware targeting (2026-10-20, task 12)

- **Decision:**
  - **Wobble:** a stateless hash of (unit, tick // 30, observing team) gives a point in the unit disc. The offset interpolates linearly to the next period's point, so blips drift smoothly. Its radius is the observing team's best `sensors.radarError` among its radar emitters (Oracle 20 studs, Watcher 45, default 40). It never touches `sim.rng`.
  - **Jamming:** a unit standing in its own team's jam map can't be a RADAR contact. Sight is unaffected.
  - **Stealth:** `radarSignature < 1` requires the unit to be within `radar × signature` of one of the observer's radar emitters (exact distance, emitter list rebuilt each sensor tick).
  - **Targeting** only accepts VISIBLE targets. RADAR contacts and ghosts of living structures are accepted only by `canTargetRadar` weapons, which aim at the wobbled (or ghost) position. Range is measured to the known position.
  - **Hitscan** hits are judged against the true position, so radar fire really misses.
- **Alternatives:** wobble from `sim.rng` (order-dependent); jamming that also blocks sight.
- **Why:** guide 11.4. Measured: Verdict howitzer direct-hit rate is 87% with a spotter versus 20% on radar.

## D68 — Tanks see as far as they shoot (2026-10-20)

- **Decision:** Lancer sight 110 → 200 and Ravager 100 → 180, so they can see the targets their guns reach (180 / 160).
- **Alternatives:** keep short sight and rely on spotters or radar.
- **Why:** with fog of war on, tanks that out-range their own sight never fire without a spotter, which isn't the intended design for line tanks. Artillery (Verdict, Hellmouth) keeps short sight and needs spotters or radar, as intended. Balance is M8.

## D69 — Placeholder jammers and artillery (2026-10-20)

- **Decision (guide 13.2):**
  - Jammers: `ord_veil` "Veil" (jam 300) and `chs_shroud` "Shroud" (jam 450), both T2 and unarmed.
  - Artillery: `ord_verdict` "Verdict" with `ord_howitzer` (range 450, 0.6° spread, canTargetRadar) and `chs_hellmouth` "Hellmouth" with `chs_mortar` (range 400, 1.6° spread, canTargetRadar).
  - Def field `sensors.radarError`.
- **Why:** needed for the jamming and radar-artillery tests. They follow the faction doctrine: short Order jammer, long Chaos jammer, precise Order artillery.

## D70 — Event records on the wire; PROTOCOL_VERSION 2 (2026-10-20, task 13)

- **Decision:** the Events channel gets Schema records:
  - ENTER (16 bytes: id, def index, team, position, heading, altitude, health, build, state);
  - LEAVE (3 bytes);
  - DEATH (6 bytes: id, severity, wreck).

  `PROTOCOL_VERSION` is now 2. The golden-byte test pins the new records; existing layouts are unchanged.
- **Why:** NetOut needs reliable tier changes and deaths. Our rule is to bump on any wire change.

## D71 — NetOut design (2026-10-20, task 13)

- **Decision:**
  - **Fog first:** a player's known units are its team's units plus enemies at RADAR, SONAR, VISIBLE or GHOST. Only own and VISIBLE units can be tactical; radar and sonar contacts are strategic-only blips with icon 0 at their wobbled cell.
  - **Tactical tier:** units within the camera rectangle; enter at +2 cells, leave beyond +5. The camera arrives via the CAMERA command; without one, there's no tactical tier.
  - **Tactical records** (unreliable): moved tactical units, every tick.
  - **State records** (reliable): tactical units with dirty HEALTH, STATE or BUILD. A STATE change sends every weapon slot's aim plus the weapon-state field: IDLE without a target, READY when reloaded, otherwise AIMING.
  - **Strategic snapshot** every 5th tick: all other known units, plus ghosts of dead structures. A strategic tick always sends at least a header-only message, so the client can drop stale entries.
  - **DEATH** goes only to players who had the unit tactical. Strategic-only units just vanish from the next snapshot. Removals without a death (reclaim) send LEAVE.
  - **Quantization:** heading u8 = round(h / 2π × 256) mod 256; health u8 = ceil(health / max × 255); build u8 = floor(progress × 255); aim angles u8 over [−π, π].
  - **Packing:** every channel goes through `Packer.chunk` with a tick header. Dirty bits are cleared at the end of NetOut.
  - Per-player outboxes plus cumulative bytes and messages per channel sit in `sim.net`, which is not hashed.
- **Alternatives:** radar contacts in the tactical tier; deltas for strategic records.
- **Why:** guide 7.2–7.3. Strategic snapshots are simple and self-healing over the unreliable channel.
- **Tests:** a simulated client (`Tests/Support/Client.luau`) rebuilds the view from packets only. Mutations leaking hidden units or true radar positions are caught.

## D72 — Stress harness and per-system timing (2026-10-20, task 14)

- **Decision:**
  - `Sim.enableTiming(sim)` makes `Sim.step` record per-system wall time (total and peak) via `Profiler.now()`. It only observes; nothing feeds back into the simulation.
  - `lune run stress [ticks] [sizes...]`:
    - mixed armies (75% tanks, 15% artillery, 5% radars, 5% jammers) on `gen:4:256`, sent at each other with FIGHT;
    - each player's camera is 40×30 cells over the middle;
    - reports average and peak ms per system against guide 18.1, and KB/s per player per channel against 7.6.
- **Why:** guide 17.5. **Numbers are from Lune on a desktop PC; repeat on a live server** (guide 17.5, STUDIO_HANDOFF).

## D73 — Aircraft flight model (2026-10-20, task 15)

- **Decision:**
  - **Jets** (`Air.steerJet`):
    - speed is clamped to [`movement.minSpeed`, `maxSpeed`] and heading turns at `turnRate`;
    - with no order they circle their goal clockwise at `LOITER_RADIUS = 220` studs (tangent plus radial correction), at 75% speed;
    - with a weapon target they chase its known position at full speed, overshoot and come around, which makes them circle the target;
    - a move order flies to the goal and switches to circling within the loiter radius;
    - near the map edge they turn back toward the center.
  - **Helicopters** use the normal ground steering without terrain collision, so they hover.
  - **Altitude bands** above ground: JET 100, HELI 35. Aircraft climb and descend at 40 studs/s and sit at 0 on a pad.
  - **Jets don't push each other** (no overlap resolution); helicopters separate like ground units.
  - **Jet targeting** ignores the firing arc (the jet turns to bring the target into it); firing still needs the arc.
  - **Swept collision:** projectile chords are tested in each unit's frame (the chord minus the unit's motion this tick), so fast jets can't slip between ticks.
  - **HOMING / TORPEDO** projectiles turn toward the target center at the weapon's `turnRate`. Lock rules and countermeasures come in task 17.
- **Alternatives:** a full 3-D flight model with banking and energy.
- **Why:** guide 6.7 at the level the sim needs. A 260 stud/s jet turning 75°/s has a turn radius of about 200 studs, hence the 220-stud loiter.

## D74 — Ammo, rearm pads, rearming through the economy (2026-10-20, task 15)

- **Decision:**
  - Units with `ammo` spend one round per shot and can't fire at 0.
  - At 0 they remember their goal, fly to the nearest friendly complete structure with `rearmPads`, and land when within reach (60 studs for jets, 12 for helicopters) and a pad slot is free. Landing snaps them onto the pad, sets speed and altitude to 0 and sets the LANDED state.
  - Rearming runs in the Construction system as an economy consumer: `1 / rearmTime` rounds per second × the effective stall ratio, paying `ammoCost` per round within the window allowance, and adding to demand.
  - When full they take off at minimum speed and fly back to the remembered goal. If the pad is destroyed, they look for another one.
- **Alternatives:** instant rearm; rearm costs paid upfront.
- **Why:** guide 8.6 and 12.2. Measured: a Falcon rearms 4 rounds in exactly 120 ticks (8 s) at full economy, and more than 3× longer on a 20-power-per-second stall.

## D75 — Placeholder aircraft and pads (2026-10-20, task 15)

- **Decision (guide 13.3):**
  - Fighters: `ord_falcon` "Falcon" (260/140 speed, 4 × `ord_aam`) and `chs_harpy` "Harpy" (6 × `chs_aam`, cheaper and less agile).
  - Attack helicopters: `ord_guardian` "Guardian" and `chs_wasp` "Wasp", with rockets against ground targets.
  - Rearm pads: `ord_airpad` "Aerie" and `chs_airpad` "Roost", footprint 3, 1 pad each (pad names are placeholders).
  - New def fields: `movement.minSpeed`, `ammo`, `ammoCost`, `rearmTime`, `rearmPads`.
- **Why:** needed for the air tests. Balance is M8.

## D76 — Naval hull volumes and submerged submarines (2026-10-20, task 16; close detection added by the user the same day)

- **Revised (user answer):**
  - Within 40 studs (`Sensors.CLOSE_SONAR`, exact distance), naval units and ASW helicopters detect submerged submarines as SONAR contacts: torpedo-targetable, never VISIBLE. Nothing else can.
  - An "ASW helicopter" is derived from the def, not a new category: a `HELI` with a weapon that can target `SUB`.
  - Sensors keeps a per-team list of these detectors each sensor tick and checks them only for submerged units outside sonar coverage.
  - Placeholders `ord_tidewatch` "Tidewatch" and `chs_leech` "Leech" (guide 13.3): dipping sonar 170 / 150, the side's ASW torpedo dropped into the water below, 4 rounds.
  - This replaces "close-sight detection is not implemented" below.

- **Decision:**
  - Units with `domain = "naval"` float: their collision cylinder starts `Combat.DRAFT = 3` studs below the water surface (terrain height + water depth), not at the terrain.
  - Submarines (move class `SUB`) get the `SUBMERGED` state bit on spawn and keep it (guide 12.3, "always submerged in v1"). Their hull starts `SUB_DEPTH = 10` studs below the surface minus the hull height, so only projectiles that travel in the water can reach them.
  - Detection needed no change: the Sensors module already reports submerged units only as SONAR or HIDDEN.
  - Submarines carry only the `SUB` category (not `NAVAL`), so every weapon whose `targets` list lacks `SUB` ignores them; only torpedoes list it.
- **Alternatives:** a surface/dive toggle; letting very close sight reveal subs (the guide allows it as an option).
- **Why:** smallest model that satisfies guide 12.3. Close-range sight detection is left out because it would make the sonar-only test meaningless; it can be added later as a short `sight` range against `SUBMERGED`.

## D77 — Torpedoes run in the water column (2026-10-20, task 16)

- **Decision:**
  - New guidance value `ACOUSTIC` (homing on sonar contacts).
  - TORPEDO weapons launch level (pitch 0, no ballistic pitch) from `TORPEDO_DEPTH = 1.5` studs below the surface at the shooter's position.
  - In flight their height is clamped between the sea floor + 0.5 and the surface − 0.5, so homing can dive toward a submarine but never leaves the water. They skip the terrain-contact test (the clamp replaces it).
  - A torpedo whose next position has no water is removed with a harmless IMPACT event (unit 0): torpedoes can't hit land units.
  - Targeting accepts SONAR-level contacts for TORPEDO weapons (other weapons still need VISIBLE, or RADAR/GHOST with `canTargetRadar`). Homing steers toward the true position; the launch aims at the known (wobbled) position.
- **Alternatives:** a separate 2-D underwater projectile type; torpedoes hitting the shore as a terrain impact with AoE.
- **Why:** reuses the existing homing projectile path (D73) with two checks. Shore impacts with AoE would let torpedoes splash coastal units, which guide 12.3 rules out ("restricted to water").

## D78 — Placeholder naval roster and the `sea:<n>` test map (2026-10-20, task 16)

- **Decision (guide 13.4):**
  - Corvettes `ord_sentry` "Sentry" / `chs_barracuda` "Barracuda" (naval gun).
  - Submarines `ord_silence` "Silence" / `chs_lamprey` "Lamprey" (torpedo, own sonar).
  - Destroyers `ord_crusader` "Crusader" / `chs_corsair` "Corsair": naval gun, anti-submarine torpedo, sonar 320 / 300. The guide's destroyer SAM is left out until missiles get guidance in task 17.
  - Weapons `*_naval_gun` (BALLISTIC, NAVAL/GROUND/STRUCTURE), `*_torpedo` (sub's anti-ship torpedo) and `*_asw_torpedo` (destroyer's, stronger against SUB).
  - Test map `sea:<n>`: land (height 10) on the west quarter, sea floor −10 with 20 studs of water elsewhere.
- **Why:** needed for the naval tests. Balance is M8. Measured: a Crusader sinks a Lamprey 200 studs away in 8.5 s and keeps 1960 / 2600 HP.

## D79 — Missile guidance checks (2026-10-20, task 17)

- **Decision** (`Sim/EW.luau`):
  - **Launch:** Weapons asks `EW.canLock` before firing a guided HOMING weapon. No lock means no launch, no ammo spent and the reload stays ready.
    - IR: target VISIBLE and within `lockRange`.
    - RADAR: VISIBLE or RADAR contact, within `lockRange × radarSignature`, and not jammed unless closer than `burnThrough × lockRange` (default `burnThrough` 0.35). "Jammed" means inside its own team's jam map (the same map that hides it from radar, guide 11.4).
    - `lockRange` defaults to the weapon's range.
  - **Midcourse:** every 5 ticks per missile, staggered by projectile id. A RADAR missile whose target is jammed and farther than burn-through *from the missile* raises `LOST_LOCK`: the target is cleared and it flies straight until its lifetime ends.
  - **Terminal:** once, when the missile could close to `terminalRange` within this tick (`terminalRange + (missile speed + target speed) × dt`, so fast closures can't skip the check; default 40). On a successful countermeasure roll: `DECOYED`, the target is cleared and the velocity turns 60° left or right (one Prng draw).
  - Missiles carry a flags field (`Combat.pFlags`: terminal rolled, lock lost), included in the world hash.
- **Alternatives:** burn-through measured from the launcher (semi-active homing); re-checking every tick; a proportional-navigation miss instead of a fixed veer.
- **Why:** guide 11.5 as written ("cheap, event-based"). Measuring from the missile models an active seeker and needs no launcher bookkeeping. The terminal window includes one tick of closing, because a 480 stud/s missile and a 260 stud/s jet close about 50 studs per tick, more than the 40-stud terminal range.

## D80 — COMMAND guidance (2026-10-20, task 17; revised by the user the same day)

- **Revised (user answer):**
  - COMMAND guidance needs the launcher alive and the target VISIBLE to the launcher's team for the whole flight. Losing either raises `LOST_LOCK`.
  - Jamming, chaff, flares and DIRCM don't affect it.
  - The check runs every tick for COMMAND missiles (every 5 ticks for RADAR).
  - The original decision below (launcher inside an enemy jam field breaks it) is superseded.

- **Decision:**
  - Lock: target VISIBLE to the launcher's team, within lock range, and the launcher *not inside an enemy jam field*. That is my reading of "breaks guidance if launcher's view is jammed".
  - Midcourse: `LOST_LOCK` if the launcher is dead, the team no longer sees the target, or the launcher is jammed.
  - No terminal countermeasures.
- **Alternatives:** treating COMMAND like RADAR for jamming (the target's jam field).
- **Why:** gives COMMAND its own counterplay (kill or jam the launcher) as the guide's table intends. No placeholder unit uses COMMAND yet; the tests use a test-only weapon.

## D81 — Countermeasure rolls and DIRCM upkeep (2026-10-20, task 17; refill cost added by the user the same day)

- **Revised (user answer):**
  - DIRCM keeps starting its cooldown on failed attempts.
  - Flare and chaff refills now cost supply: a per-charge `refillSupply` in the def (required). Placeholders: flares 2, chaff 3.
  - At landing, the missing charges and their total cost are spread evenly over the rounds still to rearm. Each tick's rearm step pays `ammoCost.supply + refill cost per round` at the stall ratio, and restocks charges (flares first, then chaff) as its progress crosses whole charges.
  - At full ammo any fraction left is topped up (already paid). The rearm takes no longer at full economy, and both slow together when supply stalls.

- **Decision** (`Sim/EWState.luau` holds charges and cooldowns per unit; hashed):
  - **vs IR:** DIRCM first if its cooldown is 0. Engaging starts the cooldown whether or not the roll succeeds, so it handles at most one missile per cooldown. Then flares if charges remain (one charge per roll).
  - **vs RADAR:** chaff, one charge per roll.
  - Jamming acts on locks, not as a terminal roll. COMMAND and ACOUSTIC have no countermeasures.
  - All rolls use `sim.rng` (`Prng.chance`) in projectile order inside the Projectiles system.
  - **DIRCM upkeep:** an economy consumer in the Construction system, next to rearming. It drains `powerDrain` per second continuously and recharges its cooldown at the team's power stall ratio, so with no power it never recharges and switches off in effect.
  - **Flares and chaff refill** when an aircraft finishes rearming. Their supply cost is not charged separately yet (guide 8.6 says it costs supply); it can be folded into `ammoCost` in M8.
  - **Placeholder loadouts** (guide 11.6 flavor): Guardian has DIRCM (0.7, 3 s, 15 power/s); Falcon has DIRCM plus 2 chaff; Wasp has 4 flares; Harpy has 6 flares and 6 chaff.
- **Alternatives:** DIRCM consuming its cooldown only on success; flares before DIRCM.
- **Why:** "defeats at most one IR missile per cooldown" reads as one engagement. Measured: DIRCM decoys 25 of 40 single missiles, but only 14 of 80 in salvos of 4 (66 of 80 hit).

## D82 — EW events stay in the sim; SAM placeholders (2026-10-20, task 17; target choice revised by the user the same day)

- **Revised (user answer), SAM target choice:**
  - Guided missiles prefer targets they can lock: a lockable target's score is multiplied by 1,000, so it outranks any unlockable one.
  - They re-search on their stagger tick (every 6 ticks) even while holding a target, and switch only when the new score is at least 1.25× the current one.
  - With nothing lockable they keep tracking the best target and hold fire.
  - Measured: with a jammer escort on fighter A, an Aegis fires 0 missiles at A and 8 at fighter B. It turns to B within one search interval each time B becomes lockable (38 ticks over 7 transitions). With radar wobble swapping which of two hovering Wasps looks closer 10 times in 60 s, it never switches.
  - Found while writing this test: jets spawned without a move order never started flying, because Movement saw nothing moving. Jets now spawn at minimum speed.

- **Decision:**
  - `DECOYED` and `LOST_LOCK` are sim events (`Combat.Event`), like `SPAWN_PROJ` and `IMPACT`. They are not on the wire yet: the Events channel carries only ENTER, LEAVE and DEATH, and projectile replication isn't built. `PROTOCOL_VERSION` stays 2.
  - Placeholder SAM sites (guide 13.5): IR sites `ord_vigil` "Vigil" and `chs_thorn` "Thorn"; long-range radar sites `ord_aegis` "Aegis" (own radar 650, error 20) and `chs_wyvern` "Wyvern" (radar 600, error 45). Missiles `*_ir_sam` and `*_radar_sam` (`canTargetRadar`, `burnThrough` 0.35). New weapon field `burnThrough`.
  - `Air.spec`'s interception test sets the Wasp's flares to 0: it tests flight, and with flares the Falcon's 4 missiles may all be decoyed. Its assertions are unchanged.
  - Targeting does not yet prefer lockable targets: a radar SAM keeps a jammed target and holds fire instead of switching to an unjammed one.
- **Why:** the wire format for projectiles and FX is a Studio/rendering milestone (guide 7). Retargeting on lock failure is a balance and AI question for M8.

## D83 — Move orders: profiled, planning deferred into the pathing budget (2026-10-20, user-requested)

- **Profile** (`Nav.issueMove`, the stress test's 200-unit commands on the 256×256 generated map; four arrive in the first tick at 800 units). Per command:
  - quadtree built on the first order for its move class: 10–17 ms;
  - coarse route (`Route.findMany`) plus corridor: 5–12 ms;
  - straight-line checks for every unit: 2–6 ms;
  - greedy slot assignment: about 1.3 ms. The O(n²) loop was **not** the main cost at 200 units (the per-command cap, guide 22.3).
  - The first order also built the formation spiral cache: about 5 ms.
- **Decision:**
  - Quadtrees for every ground profile are built when the map loads (`Nav.new`). They are still rebuilt lazily after terrain changes.
  - The formation spiral for 200 units (`Nav.MAX_COMMAND_UNITS`) is built at load.
  - `issueMove` now only groups units, snaps the goal, makes slots and assigns them. The rest is a **plan job** in the Pathing FIFO, sliced by work units with the flow fields:
    - each unit's straight-line check (1 unit, plus 1 per line sample);
    - the cache lookup;
    - the coarse route, now resumable (`Route.newSearch` / `runSearch` / `searchResult`; 1 unit per leaf popped and per edge);
    - the corridor (1 per 8 cells);
    - then the same entry becomes the flow field job.
    - Until the plan is done the order is pending and its units steer straight at their slots, as they already did while a field was pending. Pathing runs after Commands in the same tick, so a small order is planned before its units move.
  - **Exact bucketed greedy assignment** (`Nav.assignSlots`): units in a 32-stud bucket grid over their bounding box, ring search with a proven stopping bound, ties to the lower ID. A spec checks it against the brute force on 60 random cases with duplicate positions. For far formations it saves about 25% of distance checks; short moves save more.
  - **Shared budget:** issuing charges `10 × units + distance checks ÷ 4` work units to `nav.issueWork`. The next Pathing step runs with `PATHING_BUDGET − issueWork` (at least 0), so issuing and planning in one tick together stay within one budget, deterministically.
  - Work-unit rates measured: plan work 4,300–11,100 units/ms, flow fields about 4,200 units/ms on this PC, so a plan unit is never more expensive than a field unit.
- **Result** (stress test, same PC, before → after):
  - worst Commands + Pathing tick: 60 / 69 / 81 / 91 ms → 11.4 / 12.8 / 12.7 / 10.2 ms at 200 / 400 / 600 / 800 units;
  - Commands peak: 82 → 6.5 ms;
  - max tick at 800 units: 95 → 29 ms, the rest being Sensors' and Movement's own peaks.
- **Not done** (follow-ups):
  - `Nav.terrainChanged` still drops every quadtree, so the first order after a structure is placed rebuilds one in its tick (10–17 ms on 256×256). An incremental quadtree update would fix this.
  - `Nav.extendField` (stalled units) still runs its route synchronously in Movement, rate-limited per order.
- **Alternatives:** Hungarian or optimal assignment (not needed for the cost); deferring slot assignment too (units would wait for the plan job before they get goals).

## D84 — Offline Roblox build: darklua `convert_require` and a place check (2026-10-20, user-requested)

- **Decision:**
  - darklua 0.19.0 is pinned via Rokit (the tool had to be trusted with `rokit trust seaofvoices/darklua`).
  - `.darklua.json`: `convert_require` from path mode (`@shared` → `./src/shared`) to the roblox target with the Rojo sourcemap of `default.project.json` and `find_first_child` indexing. darklua's other rules are off, so code is otherwise unchanged.
  - Output goes to `build/src`; `build.project.json` maps the same DataModel tree from there.
  - `lune run build` runs sourcemap → darklua → `rojo build` → `lune run check_build`.
  - **The checker** loads the place with `@lune/roblox` and, for every Script, LocalScript and ModuleScript:
    - compiles the source with `@lune/luau`;
    - lexes it (skipping comments and strings) to find `require(...)` calls;
    - rejects string requires;
    - walks each Instance path (`script` / `game:GetService`, `.Parent`, `:FindFirstChild`, `:WaitForChild`, `.Name`, `["Name"]`) through the place and requires a ModuleScript at the end.
  - Result: 143 scripts, 482 requires, 0 problems.
- **Alternatives:**
  - A Roblox-side require shim (would break the "no `script`" rule in shared code).
  - `wait_for_child` everywhere (unneeded on the server, where Rojo builds the tree before scripts run).
- **Why:** the user's step 1 of STUDIO_HANDOFF, done without Studio. Only the in-Studio run remains.

## D85 — Sensor stamping: one-cell shifts, row spans, budgeted full stamps (2026-10-20, task 18)

- **Profile** (800-unit stress test, per sensor tick):
  - stamping and unstamping: 12–23 ms, about 95% of the time, writing 540k–1.27M map cells. Most restamps are moving units crossing one sensor cell: each erased and redrew whole circles (a radar is about 6,000 cells, an air-sight circle about 1,100);
  - visibility updates: 0.2–0.4 ms;
  - radar and close-sonar lists: 0.3–0.7 ms;
  - ghosts: about 0.
  - So recomputing visibility selectively, or staggering it, wouldn't help.
- **Decision** (`Sim/Sensors.luau`):
  - **Shift:** a unit whose new sensor cell is a neighbor of its stamped cell (same team and radii) shifts each circle: an x shift (each row loses its trailing end cell and gains the next leading one), then a z shift (each column likewise). That is O(radius), not O(radius²).
  - **Row spans:** circles are cached per radius as row spans, so a full stamp is a tight run along each row (same cell set as before).
  - **Stamp budget:** full stamps (new emitters, jumps of more than one cell, team or radius changes) are limited to `STAMP_BUDGET = 200,000` cells per sensor tick, in ids order. The first stamp over the budget still runs, so there is always progress. A unit over budget keeps its previous stamp, or has none if new, until a later sensor tick. Removals (death, unfinished frames) are never deferred.
  - The existing full-recount test validates the shifts. A new test covers the budget (300 radars: 35 in the first sensor tick, all within 18 ticks, maps always matching the stamps made).
  - Combining los and airLos stamping wasn't needed once shifts made moves cheap.
- **Result** (Sensors average / peak ms, stress test, same PC):

  | units | before | after |
  |---|---|---|
  | 200 | 1.46 / 6.10 | 0.18 / 1.39 |
  | 400 | 2.39 / 12.42 | 0.31 / 3.48 |
  | 600 | 3.42 / 14.18 | 0.40 / 2.06 |
  | 800 | 4.16 / 21.56 | 0.54 / 2.14 |

  The average tick at 800 units went from about 12.1 to 9.2 ms.
- **Trade-off:** in a mass spawn (the stress test's 800 units appearing in one tick), the last units start emitting up to about 1 s late. Normal play spawns a few units at a time, far below the budget.
- **Alternatives:** stamping at a coarser resolution (changes what is seen); spreading every restamp over ticks (would make moving units' sight lag).

## D86 — Local quadtree updates when structures change passability (2026-10-20, task 19)

- **Before:** `Nav.terrainChanged` dropped every quadtree. The next `Nav.tree` call rebuilt them lazily, usually in Movement in the same tick, at 2–11 ms per tree on a 256×256 map with 5 ground trees.
- **Decision:**
  - `Quadtree.update(tree, pm, rect)` (see its header) is called for every existing tree, in sorted key order. The rectangle is the footprint padded by `CLEARANCE_CAP` (16), the farthest clearance can change.
    1. Find the cells whose open/blocked state flipped. If none, return; for example, land structures don't touch ship trees.
    2. Re-decide nodes top-down, descending only into nodes touching the flipped box. Untouched nodes take their state from the old tree in O(1). The merge and split rule is the full build's, so the leaf set equals a rebuild's.
    3. New leaves replace the old leaves they cover. IDs come from removed and free IDs ascending, then appended; dead IDs have `leafSize = 0`.
    4. Neighbor lists are patched; components are recomputed (one BFS over open leaves).
  - Leaf IDs can differ from a fresh build's. They are deterministic for the same history; routes break ties by leaf ID, so a different history can give a different but equally short route.
  - Plan jobs with a route search in flight over a changed tree restart their search.
- **Tests** (`Placement.spec`):
  - after each of 40 random placements and removals on a generated 128×128 map, every tree (including a need-2 TRACKED tree, where clearance beyond the footprint matters) equals a fresh build: leaf rectangles, cell→leaf links, adjacency, component partition and counts;
  - mutations caught: no merging, no neighbor patch, no component recompute, no padding;
  - the old "the tree object was replaced" check now checks that the same tree blocks the new structure's cells.
- **Result** (stress test, 800 units, 14 structures placed mid-battle):
  - worst tick containing a placement: 42–43 ms → 24–27 ms, which is the ordinary tick peak; the placement itself costs ≤ 5.7 ms;
  - Movement peak: 31–35 → 14 ms.
- **Alternatives:**
  - renumbering every leaf to match a fresh build's IDs (O(map) per change);
  - rebuilding dirty trees as sliced jobs (stale trees in between).

## D87 — Teams, ally teams and match rules (2026-10-20, task 20)

- **Teams and ally teams** (guide 16.1, 8.3):
  - A player's `team` is their economy account and ownership, as before. New: `allyTeam` (default = `team`); every team belongs to exactly one ally team.
  - Units carry `w.ally`. Sight maps, visibility, ghosts and radar lists are per ally team, so allies share sight, radar and sonar.
  - Targeting, the contact grid, projectile friendliness and AoE friendly fire use the ally team, so allies never target or directly hit each other.
  - Economy accounts stay per team. Overflow above storage goes to allies with room, split evenly among those that still have room (repeated until placed), in fixed team order; the rest is wasted. Order per window: production and spending → overflow sharing → stall ratios (guide 8.4).
  - Giving units and resources to allies (guide 16.1) is a command, not done yet.
- **Match config** (`Sim.new{ match = { mode, win, unitCap? } }`, absent = no rules):
  - FFA: 2–8 players, each their own ally team.
  - TEAM: 2–4 ally teams of up to 4 players. I allow 1-player ally teams (uneven matches) where the guide says "2–4 players".
  - Unit cap default from guide 16.4: `clamp(300 − 25 × (players − 2), 150, 300)`: 300 in 1v1, 150 in an 8-player FFA.
- **Unit cap:** counts units and structures a player owns, frames included. At the cap, construction fails with `unit_cap` and a finished factory item waits at the exit until there is room.
- **Win conditions:**
  - A new `Sim.Match` system runs every tick after Construction (guide 3.3 order updated).
  - COMMAND_ENDS: a player with no COMMANDER-category unit left is out. ANNIHILATION: a player with nothing left is out.
  - Per-player counts come from Lifecycle hooks (`addedHooks` is new).
  - An eliminated player's units self-destruct: lethal overkill damage, so no wrecks, applied by the next Damage step.
  - An ally team is defeated when all its players are out. When ≤ 1 ally team remains, the match ends (winner 0 = nobody: a draw).
  - Sim events `ELIMINATED` and `MATCH_END` (not on the wire yet, like D82). `MatchState` is hashed.
- **Replay format 2:** the header stores each player's ally team and the match options.
- **Alternatives:** separate economies per player within one team (BAR-style comshare, not needed); removing an eliminated player's units instantly (self-destruct reads better and leaves death events).

## D88 — Full placeholder roster and tech tree (2026-10-20, task 21)

- **Decision:**
  - Every unit and structure in guide 13 now exists as a validated def: 79 new defs, 115 in total (57 Order, 58 Chaos). They are generated from role templates, so stats are consistent by role.
  - Order is slightly longer-ranged and more precise; Chaos has more health and damage and larger jam radii.
  - Move classes follow the roles:
    - scouts and SAM or radar trucks: WHEELED;
    - main battle tanks: HEAVY_TRACKED;
    - amphibious tanks: AMPHIB;
    - air workers and helicopters: HELI;
    - fighters, bombers and support aircraft: JET;
    - naval workers and ships: SHIP; submarines: SUB.
  - **Factories and economy** (guide 9.2, 8.5), which section 13 doesn't name:
    - Advanced Vehicle Plant, Airfield / Advanced Airfield (1 and 2 rearm pads), Shipyard / Advanced Shipyard (water);
    - Advanced Extractor (rate 1.75, about 3.5×), Solar Array, Tidal Generator (water), Fusion Reactor, Depot (+1,000 storage);
    - Chaos names are placeholders (Foundry, Aerodrome, Drydock, Sun Trap, Tide Mill, Hellforge, Hoard).
  - **Build tree** (guide 9.1–9.2): `Commander → T1 factories and economy → T1 workers → advanced factories → T2 workers, T2 units`. T1 builders reach T2 only through advanced factories. Ships come only from shipyards and aircraft only from airfields.
  - **Weapons:** 16 new: MG, heavy cannon, MLRS, bomb, heavy bomb, heavy naval gun, flak per faction; Archon's radar AAM; Manticore's heavy IR AAM.
  - **Bombs** are slow BALLISTIC drops (60 stud/s, gravity, pitch down to −90°), because the guide's BOMB type has no sim behavior yet. The balance report (task 22) will show how well bombers actually deliver.
  - **Carriers** may have `rearmPads`: validation now allows ships, per guide 12.3's "mobile airfield". An aircraft landing on a moving carrier stays where it landed while rearming (to refine with carriers).
  - **Left out for now:** Wind Turbine (needs a global wind value), Supply Converter (needs a converter step), naval SAM platform (not in section 13), and replacing a T1 extractor when its upgrade starts (guide 9.3).
- **Tests** (`TechTree.spec`):
  - every guide-13 unit exists and every faction def is reachable from its Command Vehicle;
  - tech gating, faction purity, move classes per role, ships only from water factories, water placement for naval structures, every weapon can damage something it targets;
  - in the sim: shipyard → Tidewright → tidal generator, and airfield → Skywright → solar array;
  - mutations caught: a T2 tank in the T1 plant, Tidewatch missing from the Advanced Airfield.
- **Changed test data:** `Defs.spec`'s "unknown build option" case used `ord_paladin`, which now exists; it uses `ord_no_such_unit`.

## D89 — Balance report method (2026-10-20, task 22)

- **Decision** (`lune run balance`, `docs/BALANCE.md`; report only):
  - Every Order combat unit against every Chaos combat unit where one can damage the other. Workers, commanders, unarmed support aircraft and ships, and structures are left out.
  - Equal value per side: about 3,000, with value = supply + power ÷ 10 (BAR's metal + energy ÷ 60 idea, rescaled to our costs); at most 20 units.
  - Two starts: close (120 studs) and long (600 studs, both attack-move at the enemy centroid every 2 s). 2 seeds; at most 120 s.
  - Map: flat 128 for land and air pairs; `sea:256` when a ship is involved (ships offshore, land units on the beach).
  - Score: value trade = enemy value destroyed ÷ own value lost, damage counted pro rata. Per-unit geometric means are over all matchups.
- **Caveats:**
  - Aircraft have no pads and run dry.
  - One-sided matchups (bombers vs units with no AA) give large trades without wins.
  - Equal value at a 3,000 budget rounds expensive units to 1–2 copies.
- **Why:** a cheap, deterministic first look for M8 balancing; the numbers aren't targets.

## D90 — Skirmish AI (2026-10-20, task 23)

- **Decision** (`Sim/AI/Skirmish.luau`):
  - The AI is a player. It reads its own units and economy, what its ally team knows (`Sensors.knownPosition`) and the map's start positions, and acts only through `Sim.submit`. Its games are therefore in the replay like anyone's, and a replay without the AI reproduces them exactly.
  - It thinks every 15 ticks (offset by player ID) and has its own Prng (seed × 31 + player × 7919), used only for the production mix (1 artillery piece in 4).
  - **Builders:**
    - the Command Vehicle stays within 260 studs of home;
    - priorities: a Vehicle Plant (a second one past 600 stored supply) → generators while power is short → extractors on the nearest free deposits (claims last 60 s) → assist a factory;
    - spots come from rings around home checked with `Placement.check`, like a client's placement ghost.
  - **Factories:** keep 2 items queued: workers up to 3, then T1 tanks and artillery.
  - **Army:**
    - new units gather at a rally point 160 studs toward the enemy;
    - enemies within 260 studs of home are attacked by everything at home;
    - at the wave size (8, growing by 2) the wave attack-moves at the best known target (structures and the Command Vehicle count 4× closer), else the enemy start, re-targeting every 5 s.
  - **Map:** a `skirmish:<cells>` test map: `start` plus two pairs of value-3 expansions per side and a rich value-6 pair in the middle.
- **Results** (192×192, Order AI vs Chaos AI, Command Ends):
  - seed 1: Chaos wins at 8.0 min, peak tick 10.3 ms, 9 / 8 extractors;
  - seeds 2–4: Chaos wins at 6.0, 7.8 and 6.3 min, peak ticks 8.7–9.3 ms, at most 60 units;
  - a full match takes about 1.4 s of wall time headless.
- **Alternatives:** a utility-scoring AI; AI inside the sim as a system (it would bypass the command path and the replay).

## D91 — Bombing: runs, lead point, egress, rearm (2026-10-20, user-requested)

- **Decision:**
  - Bomb weapons are the real `BOMB` type: no turret and no projectile speed; `gravity` is required, and `range` (now 800) is the acquisition radius.
  - Bombers (JETs carrying a BOMB) cruise at 130 studs (guide 6.7's 120–140 band).
  - **Release** (`Air.bombRelease`):
    - fall time t = √(2h ÷ g) from the drop height to the target's centre;
    - predicted impact = bomber position + velocity × t; predicted target position = known position + its velocity × t (velocity only while VISIBLE; radar contacts don't move in the prediction);
    - release in the tick when the impact point crosses the aim point along the track (within half a tick of travel) and lies within max(aoe ÷ 2, 3) + target radius across it.
    - The bomb leaves with the bomber's velocity plus the weapon's yaw spread, and falls under gravity.
  - **Run** (`Air.steerJet`, state in `AirState.run` / `egressUntil`, hashed):
    - "in": turn toward the aim point. If closer than 0.6 × the release distance, the window is missed: switch to "out";
    - after a release: fly straight for 3 s (egress), then "out";
    - "out": fly away from the target until release distance + 150 studs (about a turn radius), then "in" again;
    - when the target is lost the run state resets.
  - **Empty:** return to the nearest pad and rearm as before (D74), then resume.
- **Tests** (`Air.spec`):
  - 4 of 4 bombs land within the blast radius of parked targets;
  - a moving column is hit (1 of 2, versus 0 of 2 without motion prediction);
  - the heading is held during egress;
  - fly → return → rearm → fly, then bombing again;
  - determinism;
  - mutations caught: no lead, no target prediction, no egress.
- **Balance report re-run** (bomber value trade, before → after):
  - Absolution 3.57 → 1.93, Phantom 7.90 → 2.68, Plague 5.24 → 2.18, Behemoth 4.61 → 1.93; still 0 wins in 56 fights each.
  - The old "bomb" fired like a gun from 130 studs. A real run releases about 400 studs before the target, but bombers see only 200 studs, and the report's fights have no spotters, radar or pads. So bombers rarely hold a target long enough to line up, and they run dry. This is a mechanics finding for the counter check (task 27).
- **Alternatives:** carpet runs (several bombs per pass); letting bombs target radar contacts.

## D92 — Wind, converters and extractor upgrades (2026-10-20, user-requested)

- **Wind Turbine:**
  - New def field `wind = { max }`. Power income = max × the global wind.
  - Wind is a stateless hash of (match seed, tick ÷ 450) mapped to 0–1, so it changes every 30 s, never touches `sim.rng`, and replays exactly.
  - It is stepwise, not smoothed. `eco.wind` is hashed.
  - Placeholders: `ord_windmill` "Wind Turbine" (max 30), `chs_windmill` "Wind Pylon" (max 34); cost 35 supply. Average about 15 power per second, against the solar array's steady 8.
- **Supply Converter:**
  - New def field `converter = { power, supply }` per second. Converters run in the Economy step after production and before consumers (guide 8.4).
  - A converter burns only power above half the team's power storage (`CONVERTER_RESERVE`), up to its rate, and adds supply at the ratio.
  - Toggleable with the existing TOGGLE command (`TOGGLED_ON`); converters start switched on.
  - Placeholders: `ord_converter` "Supply Converter" (70 : 1), `chs_converter` "Smelter" (60 : 1).
- **Extractor upgrade** (guide 9.3):
  - `Placement.check` takes an optional builder team. An extractor may then go onto that team's own complete extractor with a lower rate; the check returns the unit it replaces.
  - Build removes it (`Lifecycle.remove`) in the tick the new frame starts.
  - Another team's extractor, or one of the same rate, still counts as "occupied".
- Wind turbines and converters are in every T1 economy build list.
- **Alternatives:** a seeded random walk for wind (would need state or `sim.rng` draws); converters with a player-set energy threshold (BAR's slider) instead of a fixed 50%.

## D93 — Match export for the viewer (2026-10-20, user-requested)

- **Decision:**
  - `lune run export <scene> [--player N] [--seed S] [--map M] [--ticks T] [--every K] [--out file]` writes `debug_out/match_<scene>_<view>.json`.
  - The core lives in pure Luau under `src/server/Tests/Support` (tests use it in both runtimes):
    - `Scenes`: sim setups with their command drivers: `ai`, `matchup:<a>:<b>[:close|long]` (the balance report's fight, which `lune run balance` now uses too), or any Sim scenario with an attack-move driver;
    - `MatchExport`: records frames;
    - `Json`: deterministic encoder (sorted keys), plus a decoder for tests.
  - **Views:**
    - spectator: the server's truth every frame: units, projectiles, combat events;
    - player: the headless client (`Support/Client`) decodes that player's real NetOut packets with a whole-map camera. The frame holds tactical units, strategic records (radar and sonar blips at their wobbled positions, ghosts) and the ally team's sight map as a 1-bit-per-sensor-cell fog bitmap (base64). Projectiles and events aren't on the wire yet (D82), so the player view has none.
  - **Format "ftgg-match" v1:** see the `MatchExport` header. Positions to 0.1 stud; one frame every 3 ticks by default. The 8-minute AI match is 4 MB as spectator and 5.8 MB as a player view, recorded in about 2 s.
- **Tests** (`Export.spec`):
  - JSON round trip and formatting; base64 vectors;
  - spectator frames equal the sim's units and projectiles at capture; map arrays, row shapes, bounds, events; an exact JSON round trip;
  - player view (radar matchup): tactical units are allied or VISIBLE, strategic records only ever-known units, radar blips present, fog equals the sight map, no projectiles;
  - determinism;
  - mutation caught: leaking units the client never received.
- **Alternatives:** a binary format (smaller, but needs a decoder in the page); recording the replay and re-simulating in the browser (would need the sim in JS).
- **Viewer** (`tools/viewer/index.html`, one self-contained file with no external scripts):
  - a file picker reads the export with `FileReader`, so it works when opened by double-click (file://);
  - draws terrain and water from the map layers, deposits, units as category shapes in team colours interpolated between frames, aircraft shadows, health bars, projectiles, impacts, deaths, decoys and lost locks;
  - in player view: radar and sonar blips (pulsing rings at their wobbled positions), ghosts (dashed), and fog from the sight bitmap;
  - minimap (click to jump); play / pause / speed 0.25–16× / scrub / step; wheel zoom and drag pan; click a unit for its def, health, build, position, heading, state bits and target;
  - checked in the browser pane against the AI match (spectator and player 1) and a radar matchup. `.claude/launch.json` has a "viewer" static server for that kind of check.

## D94 — Counter check against guide 12.4 (2026-10-20, user-requested; report only)

- **Method** (`lune run balance`, section "Counter check" in `docs/BALANCE.md`):
  - The 12.4 table is parsed from the guide, so the check follows guide edits.
  - Roles map to units: Tanks = Lancer, Ravager, Paladin, Juggernaut, Tideguard, Mire; Artillery = Verdict, Hellmouth, Judgement, Hydra; IR SAM = Halo, Hornet; Radar SAM = Seraph, Gorgon; Fighters = Falcon, Harpy, Archon, Manticore; Bombers = the four; Attack helis = Guardian, Wasp; Destroyers = Crusader, Corsair; Submarines = Silence, Lamprey.
  - Coastal batteries (Rampart, Breaker) are added from guide 13.5 ("heavy gun against ships": ●●●).
  - Target classes come from the defender's move class and domain.
  - **Fights:**
    - the existing equal-value duels;
    - new sieges (`Scenes.siege`: a group against an enemy plant, 3 generators and a radar tower) for the Structure column;
    - batteries against every enemy ship.
  - **Shortfall:**
    - "—" but can damage;
    - ● and destroys nothing;
    - ●● with a value trade below 1;
    - ●●● with a value trade below 2;
    - sieges: less than 2%, 30% or 60% of the base destroyed.
  - **Diagnosis** from per-fight records (ever knew a target its weapons accept, closest distance, shots, hits, ammo):
    - mechanic: can't target, can't see, can't reach (the shore), out of range, never fired, fired but never hit, ran dry, a bomber never lined up a run;
    - numbers: it saw, reached, fired and hit, but lost the trade.
- **Result:** 412 of 568 attacker / target pairs hold. 273 findings (one per pair and start): 157 mechanic, 116 numbers.
- **Mechanic findings** (by cause):
  1. **Ballistic fire at ships aims at the sea floor** (78 findings: tanks 39, artillery 24, coastal batteries 6, plus some destroyer and corvette guns). `Weapons` aims at `groundHeight + alt + height/2`, but a ship floats about 17 studs above the sea floor. MLRS (minimum pitch 0°) never fire; howitzers, mortars and tank and coastal guns fire low and never hit. The hitscan judgement already uses `Combat.unitBase`, so the aim point should too.
  2. **Bombers can't line up runs** (34): they see 190–200 studs but release about 400 studs out. Without spotters, radar or bombs on radar contacts, they never or rarely drop.
  3. **Destroyers can't hit aircraft** (13): their SAM was left out in D78 and never added.
  4. **Tanks and attack helicopters can't hit helicopters** (22): the matrix says weak (●), but no ground gun or rocket targets AIR.
  5. **Ran dry** (19): fighters against jets and attack helicopters against ships empty their ammo without pads. This is a property of the report's fights (no pads), not of the game.
- **Numbers findings:**
  - same-class mirrors (Tanks → Ground ●●● 59, Artillery → Ground ●● 35, Submarines → Sub 2, Destroyers → Ship 2): with equal value on both sides, one side's ●●● (trade ≥ 2) is the other side's trade ≤ 0.5, so a mirror can't satisfy both sides. These are artifacts of checking the matrix on same-role duels;
  - IR SAM → helicopters ●●● (3): Halo against Wasp trades 0.5–0.6, Hornet against Guardian 1.64;
  - Radar SAM → helicopters ●● (2); Destroyers → Sub ●● (4: 0.34–0.52); Fighters → jets ●●● (2); Silence against Corsair (1.91 < 2).
- **Nothing was changed.** The fixes (aim point, bomber spotting, destroyer SAM, anti-helicopter weapons) are questions for the user.

## D95 — One aim point for aiming and hit checks (2026-10-20, user-requested)

- **Decision:**
  - `Combat.aimPoint(c, w, id, x?, z?)` is the centre of the unit's collision cylinder, using the same base rules as `unitBase` (ships float with their draft, submarines sit below the surface, other units stand on terrain plus altitude).
  - It is evaluated at the true position, or at a believed position (a radar blip, a ghost) via the new `Combat.baseAt`.
  - Weapons aim (pitch to the believed position), the hitscan judgement (the true direction), homing steering, the EW terminal check, bomb solutions and hitscan explosions all use it.
  - Before this, weapon pitch used terrain + altitude: the sea floor for ships, about 17 studs under the hull.
- **Tests** (`Naval.spec`):
  - the aim point matches the hull for ships and submarines;
  - a Lancer on the beach hits a stationary ship with 19 of 19 shells;
  - a Judgement MLRS fires at a ship and hits 7 of 10 (with the old aim point both fail).
- **Counter check after the fix:**
  - 425 of 568 pairs hold (was 412); findings 273 → 248, with mechanic 157 → 84 and numbers 116 → 164;
  - all 78 "never fired / never hit" ship findings are gone;
  - what remains against ships is numbers (tanks 16, artillery 25, coastal batteries 3: they hit now but lose the trade).

## D96 — Bombs on radar contacts and ghost structures (2026-10-20, user-requested)

- **Decision:**
  - The four bomb weapons get `canTargetRadar = true`. Bombers may target radar contacts, aiming at the wobbled position the team sees (guide 11.4), and remembered structures (ghosts) at their last known position. Bomber sight is unchanged.
  - The bomb solution takes the impact height at the believed position too (`Combat.aimPoint` at `kx, kz`).
  - Ghosts of structures that died unseen are not targeted: a weapon's target must be a live unit. Bombing a remembered spot that may be empty would need an attack-ground order (a question for the user).
- **Tests** (`Air.spec`):
  - a Plague with only Chaos radar on a parked Lancer releases 5 bombs on the contact; they land 6.3 studs from the blip on average and 23.8 from the tank;
  - an Absolution bombs a plant that a spotter saw and left: 2 of 3 bombs are released on the ghost, both damage it.
  - Without `canTargetRadar` both tests fail (no releases).
- **Balance fights** (`Scenes`): bomber groups bring their faction's T1 radar tower (Watchtower / Eye), as a match's base radar would. The tower is not part of the trade. Attack-moves now aim at enemy units and fall back to structures only when no units are left (sieges).
- **Bomber rows** (`lune run balance 2`):
  - sieges, share of the base destroyed: Absolution 37% → 100%, Phantom 0% → 55% (ran dry), Behemoth 4% → 92%, Plague 85% → 100%;
  - mean trade: Absolution 1.93 → 2.90, Phantom 2.68 → 2.17, Behemoth 1.93 → 2.64, Plague 2.18 → 2.63;
  - bomber findings 34 → 33. None is "can't see" any more: 14 never lined up a run (shot down or out of time against SAMs and AA ships), 9 dropped only on radar contacts of small units and missed (radar error 20–45 studs, blast radius 14), 7 ran dry (no pads in these fights), 3 lost the trade.
  - Whole check: 425 of 568 pairs hold; 249 findings (82 mechanic, 167 numbers).
- **Revised (item 4, same day):**
  - The T1 tower beside the bombers' start died within seconds in close starts: the enemy group was 120 studs away. Bombers then had nothing to aim at.
  - Bomber groups now get the long-range radar (Beacon / Allseer) at the map edge behind them, with health × 100, standing in for a defended base radar. It is still not part of the trade.
  - With this and D98's "destroying nothing never holds" (bomber rows against units that can't shoot back used to hold with 0 ÷ 0 = ∞):
    - sieges: Absolution 100%, Phantom 8% (2 Phantoms, 4 bombs per seed: noisy), Behemoth 81%, Plague 100%;
    - 31 bomber findings are bombs dropped only on radar contacts of small units that missed. 17 never lined up a run.
  - A Behemoth traced against Lancers made about 6 runs on radar contacts for 1 release: the blip shifts up to 40 studs every 2 s, and radar contacts get no lead, so the impact point misses the ±10-stud release window. Whether to widen the window for radar contacts is a question for the user.

## D97 — Destroyer naval SAM; missile lead pursuit and proximity fuse; matrix edits (2026-10-20, user-requested)

- **Naval SAM (guide 12.3):**
  - Crusader and Corsair get a third weapon, `ord_naval_sam` / `chs_naval_sam`: radar-guided HOMING, `AIR` only.
  - Range 380 / 360, matching the destroyers' sight against aircraft (1.5 × sight).
  - 300 / 280 damage, reload 3.5 / 3 s, `canTargetRadar`, priority jets, then helicopters.
- **Guidance fix (found while testing the SAM):**
  - Homing used pure pursuit (steering at the target's current position) with contact fuses only. Against a circling jet, every SAM missed: the Gorgon, the Hornet and the new naval SAM launched 20–25 missiles each over 80 s, with no impact at all. Their turn radius (about 200 studs at 380 studs/s and 110°/s) is wider than the jet's loiter circle, so missiles orbit and expire.
  - The land SAM rows still "held" in the counter check: a fighter can't shoot back, so the trade was 0 ÷ 0 = ∞ (fixed in D98).
  - **Now:**
    - Lead pursuit: HOMING and TORPEDO projectiles steer at the target's position after the straight-line time to go, assuming it holds its heading and speed.
    - Proximity fuse: a HOMING missile bursts at its closest approach to its target when that is within its `aoe` of the target's hull (measured in the target's frame, like the contact test). The burst deals AoE damage only, and its IMPACT event names the target.
  - Measured against a Falcon circling 100 studs away: the Corsair downs it with 11 missiles, the Gorgon with 6, and an Absolution falls to the Corsair in 9. The Hornet IR SAM still misses the Falcon (21 launched, 6 decoyed by DIRCM or flares, the rest pass 6–15 studs from the hull with a 5-stud blast). That is a numbers question for M8.
- **Tests:**
  - `Naval.spec`: a Crusader downs a Wasp (tick 61, 2 missiles); a Corsair downs a circling Falcon (tick 596, 14 missiles).
  - `Air.spec`: a Seraph downs a circling Harpy (3 of 8 missiles on target).
  - Both fail with the old guidance.
- **Matrix (guide 12.4):** Tanks → Air (heli) and Attack helis → Air (heli) are now "—" (no ground gun or rocket targets `AIR`).
- **BALANCE.md:**
  - The new section "M8 balance items" lists, first, IR SAM vs helicopters (Halo vs Wasp 0.58 / 0.55, Hornet vs Guardian 1.36 / 2.01; 12.4 says ●●●).
  - Destroyers against aircraft: Crusader vs Wasp 0.00 → 1.10 / 1.02; the Corsair now beats the Guardian.
  - Counter check: 446 of 568 pairs hold (was 425); findings 249 → 223 (mechanic 82 → 57, numbers 166).

## D98 — Same-role cells on a soft band; destroying nothing never holds (2026-10-20, user-requested)

- **Same-role pairs** (`lune run balance`): a role against its own kind (Tanks → Ground against tanks, Destroyers → Ship against destroyers, Fighters → Air (jet) against fighters, and so on). Units map to roles by the counter check's role table.
  - Both sides must be able to damage each other, or it is a mechanic finding ("one-sided").
  - Each start's equal-cost trade must fall within the soft band 0.5–2.0. Outside, it is a numbers finding ("same role: trade outside the soft 0.5–2.0 band", plus "ran out of ammo" when aircraft ran dry). A fight where neither side destroyed anything is diagnosed as before.
  - A new table "Same-role pairs" in `BALANCE.md` lists every Order / Chaos pair with both trades and whether they are in the band.
- **Destroying nothing never holds:**
  - A cell with dots now also needs the attacker to destroy something.
  - Before, a fight where neither side lost anything gave a trade of 0 ÷ 0 = ∞ and held ●● and ●●● (e.g. bombers against tanks that can't shoot back, SAMs against fighters).
- **Result** (2 seeds):
  - 452 of 568 pairs hold (was 446); 201 findings (71 mechanic, 130 numbers);
  - same-role band: 32 of 38 fights inside. Outside: Archon against Harpy and Manticore (0.20–0.43) and Falcon against Harpy (0.32 close) (all ran dry), and Judgement against Hellmouth (0.43 long).
  - Tanks → Ground findings 59 → 23: the 36 tank mirrors were artifacts of ●●● (D94) and now sit in the band.
- **Guide 12.4** notes the band under the matrix.

## D99 — Combat events on the wire (2026-10-20, user-requested)

- **Records** (`Schema`, `PROTOCOL_VERSION` 3; layouts in guide 7.3; golden bytes in `Schema.spec`):
  - FIRE (10 B): shooter, slot, hit bit and the end point. There is no target ID, because the target may be hidden.
  - SPAWN_PROJ (19 B): projectile ID, weapon, position, velocity and homing target.
  - IMPACT (9 B).
  - DECOYED and LOST_LOCK (15 B each): position and the new velocity.
  - Positions are a cell plus offsets and `y` in eighth studs; velocities are eighth studs per second (i16).
  - LOST_LOCK was not on the user's list. It is added because without it the client keeps steering a missile the server flies straight.
- **NetOut** (per player, after the tick's ENTER records, in one batch):
  - FIRE only for shooters in the player's tactical tier.
  - SPAWN_PROJ once a projectile is in the ally team's sight and in the camera area (+2 cells), at launch or when it flies into view. The homing target is sent only if the ally team knows the unit.
  - DECOYED / LOST_LOCK only for projectiles the client has. They carry the state after the tick's step.
  - IMPACT for projectiles the client has, or anywhere in sight and camera.
  - `NetState` keeps each player's known projectile IDs (reset when an ID is reused) and cumulative counts per event kind.
- **Sim changes** (events only, no state):
  - FIRE events carry the shot's end point.
  - Projectiles at the end of their time to live emit an IMPACT with no unit and no damage (guide 10.5 "expired homing missiles self-destruct"), so clients drop them.
  - `Sensors.inSight(sim, team, x, z)` is new.
- **Client and export:**
  - The headless client steps the projectiles it knows (ballistic step; homing turns toward the target it has, in 3D, at the weapon's turn rate) and keeps effects (fire, impact, decoy, lost, death).
  - `MatchExport` version 2: the player view has projectiles and events rebuilt from the wire. Both views have `fire` tracers, and projectiles carry their weapon index. The viewer draws the tracers and reads versions 1 and 2.
- **Accuracy:**
  - Unguided projectiles match the server exactly (worst 0.08 studs in `NetOut.spec`, 0.00 in the export test).
  - Homing missiles drift. In the Seraph-vs-Harpy export the worst drift is about 600 studs, for missiles homing on radar contacts whose altitude and true position the client doesn't know. IMPACT corrects them at the end. A periodic correction for homing projectiles would fix this at about 15 B × 3 Hz per missile (a question for the user).
- **Tests:**
  - `Schema.spec`: golden bytes for every new kind, round trips at the edges, truncation, and reserved bits / slot / ID 0 rejected.
  - `NetOut.spec`:
    - 600 battle ticks: every combat event is allowed for its player, and the client's unguided projectiles follow the server's;
    - a hidden mortar's shells appear only once in sight (first seen 161 studs from the muzzle) and its ID never reaches the client;
    - flak FIRE only to the player that has the ship tactical, with end points on the target and one tracer per shot.
  - `Export.spec`: the player view has projectiles and impacts, and every unguided projectile drawn matches a server projectile.
  - Mutations (no sight / camera filter; FIRE without the tactical check) fail the NetOut tests.
- **Bandwidth** (`lune run stress`, per player, KB/s; the other channels are unchanged):

| units | Events before | Events after | total before | total after |
|---|---|---|---|---|
| 200 | 0.06 | 0.52 | 5.78 | 6.24 |
| 400 | 0.12 | 0.95 | 12.18 | 13.01 |
| 600 | 0.16 | 1.34 | 18.44 | 19.62 |
| 800 | 0.19 | 1.60 | 19.19 | 20.59 |

  At 800 units that is about 48 SPAWN_PROJ and 54 IMPACT records per second per player. The stress armies carry no hitscan weapons and no decoys, so FIRE and DECOYED don't show up there. NetOut's average time per tick went from 0.94 to 0.97 ms at 800 units.

## D100 — Targeting follows team knowledge; ghosts of dead structures; ATTACK_GROUND for bombers (2026-10-20, user-requested)

- **Rule:** every targeting decision uses what the shooter's ally team knows, never server truth.
- **Ghosts of dead structures:**
  - Before, a weapon target had to be alive, so bombers and artillery dropped a ghost the moment its structure died, even unseen. That told the owner something the team didn't know.
  - Now `Sensors.knownTarget(sim, team, id)` answers from the ghost record (position, def index), whether the structure lives or not. `Targeting` keeps such targets and also searches the team's dead ghosts (`canTargetRadar` weapons), scored like live ones.
  - `Combat.knownAimPoint` aims at a remembered structure from its def, or at the ground. Shots land on empty ground. The ghost, and with it the target, goes away only when the team sees the spot again (Sensors, unchanged).
- **ATTACK_GROUND** (`CmdType` 4, already on the wire):
  - Gives owned bombers an order in `AirState.groundX/Z` (hashed). The bomber makes bomb runs on the spot with the usual run logic (`Air.bombAim`); its bomb weapons don't auto-target meanwhile.
  - Any move-like order or STOP cancels it. It survives rearming. Other units ignore it for now.
- **Tests** (`Air.spec`):
  - a plant destroyed unseen is still bombed (bombs land on its empty spot), and bombing stops once a spotter sees the spot (the ghost is forgotten). Without the dead-ghost search the bomber never attacks;
  - ATTACK_GROUND: 2 of 3 bombs within 10 studs of the spot, a Lancer ignores the order, and a MOVE cancels it.
- **Known edge:** unit IDs are reused only after all 65,535 fresh IDs and a 10 s delay. A ghost whose ID is reused would follow the new unit. Not handled yet.

## D101 — Audit: decisions on server truth (2026-10-20, user-requested)

Every system was reviewed for decisions that read another team's units from server truth where the deciding team's knowledge should decide. The review covered every loop over all units, every contact-grid query, and every read of a target's position, type or state. Tests are in `Knowledge.spec`; each fails when its fix is undone.

**Fixed:**

| Where | Truth leak | Now |
|---|---|---|
| `Targeting` search | Candidates were gathered by true position within range + largest radius. A radar contact whose believed position was in range, but whose true one wasn't, was never considered. | The query reaches range + largest radius + largest radar error, and acceptance stays on the believed position. Test: a mortar fires at a blip that wobbles into range. |
| `Placement.check` (AI planning) | The AI skipped build sites and deposits taken by enemy structures or units it had never seen. | Optional `knower` (ally team): enemies the team doesn't see don't block, and remembered structures (ghosts, alive or not) do. The physical check, when a builder starts the frame, is unchanged. Tests: planner vs physical check; the AI keeps choosing a deposit an unseen enemy extractor took, and picks another once it sees it. |
| `Skirmish` targets | It read the true def of radar blips (structure or Command Vehicle?) to rank attack targets. Threats near home needed `w.slot` (alive), and dead ghosts were ignored. | `Skirmish.knownTargets`: types only for VISIBLE units and ghosts; dead ghosts count as targets and threats. Test: a nearer tank beats a radar-only generator, the generator wins once seen, and stays the target after dying unseen. |
| Weapons and bombers (D100) | Targets had to be alive. | Ghost targets follow team knowledge. |

**Reviewed and kept (physics or the unit's own senses, not a team decision):**
- Hit judgement, projectile collision, homing steering and the proximity fuse use true positions: that is where things physically are.
- `EW.canLock` (jamming, stealth signature) is the seeker's own physical result. Targeting preferring lockable targets uses that result, as a real fire-control system would.
- RETURN_FIRE uses the attacker recorded by Damage, but only through the knowledge check.
- Bomber lead and weapon pitch use the true heading, speed or altitude only for VISIBLE targets, or the altitude of a radar contact (radar measures it).
- The physical placement check when a frame starts, and movement avoidance, block on everything physically there.
- Win conditions, Sensors and NetOut work on truth by design (NetOut filters fog first).

**Open (questions for the user):**
- **Pathfinding uses true passability:** routes go around enemy structures the team never saw. Fixing it needs per-team passability (or treating unseen structures as passable until a unit bumps into them). That is a large change to Nav and the flow-field cache.
- **Radar contacts' categories:** weapons filter radar contacts by their true category (e.g. artillery ignores a blip that is an aircraft). Radar can tell air from surface, but finer categories (light vs armored) also come from truth in target priority.
- **Ghost IDs reused** after 65,535 spawns would follow the new unit (D100).

## D102 — Homing-projectile corrections (2026-10-20, user-requested)

- **Wire:**
  - New unreliable channel `Projectiles` (`PROTOCOL_VERSION` 4).
  - Record: projId u16, pos, vel = 14 B, after the tick header. Golden bytes and round trips are in `Schema.spec`.
- **NetOut:**
  - For each homing projectile (a weapon with `turnRate`) the client already has: every `HOMING_SYNC_EVERY` = 5 ticks (3 Hz, staggered by ID), and on the tick it comes (back) into view.
  - "In view" means inside the camera rectangle + LEAVE_MARGIN (the tactical area) and in the ally team's sight.
  - Never for unguided projectiles, projectiles out of view, or unknown ones. `HOMING_SYNC_EVERY = 0` turns corrections off, for measurements.
- **Client:**
  - On a correction it snaps its prediction (position, velocity) to the server's and keeps drawing where it was. The drawn offset decays to 0 over `BLEND_TICKS` = 5.
  - An error above `SNAP_STUDS` = 60 snaps: that only happens when a projectile comes back into view after flying uncorrected outside it.
  - Lost corrections just leave the prediction running longer.
- **Max visible drift** (drawn vs server position, while in the player's view; 1,200 ticks; player 1 / player 2):

| fight | before | after |
|---|---|---|
| Seraph vs Harpy (radar SAMs, AAMs) | 94 / 171 | 59 / 56 |
| Falcon vs Harpy (AAMs) | 517 / 517 | 67 / 65 |
| Halo vs Wasp (IR SAMs, short flights) | 12 / 12 | 12 / 12 |
| Crusader vs Lamprey (torpedoes) | 618 / 631 | 30 / 14 |

  Mean drift fell 2–10× (e.g. torpedoes 73 → 7 studs).
- **Bandwidth:**
  - About 45 B/s per homing projectile in view; 0.03–0.18 KB/s per player in these duels.
  - The stress-test armies carry no homing weapons, so their channels are unchanged (Projectiles 0.00).
  - At 800 units: total 22.9 / 23.1 KB/s per player. The battle itself changed with D101's targeting search, so the other channels differ from round 6's 20.6.
- **Test** (`NetOut.spec`), Crusader vs Lamprey:
  - corrections only for known homing projectiles in view;
  - visible drift 618 studs without corrections, 30 with them, 58 with every other correction message lost.
  - Sending regardless of view fails it.

## D103 — Rearm airfields in balance fights (2026-10-20, user-requested)

- **Setup** (`Scenes`): each aircraft group gets its faction's Advanced Airfield (two pads) at the map edge behind its start.
  - Like the bomber radar (D96, which now uses the same helper), it is durable (health × 100) and not part of the trade.
  - The team's account is kept full every tick, so rearming isn't throttled by an economy these fights don't model.
  - Aircraft fly home empty, rearm and come back, as in a match. Fights still end at 2 minutes.
- **Report** (`lune run balance`): "ran out of ammo (no rearm pads)" is no longer a diagnosis.
- **Air rows** (2 seeds; this run also includes D100–D101):
  - all 30 "ran out of ammo" findings are gone (20 mechanic, plus 10 fighter mirrors flagged as dry);
  - attack helicopters against ships now rearm and lose on numbers (7 findings);
  - Behemoth sieges 81% → 100%;
  - fighter mirrors: wins Falcon 4 → 17 of 44, Archon 6 → 13, Harpy 10 → 24; the same-role band is now 34 of 38 fights inside (was 32);
  - still outside the band: Archon vs Harpy (0.24 / 0.49), Falcon vs Manticore close (0.22), Judgement vs Hellmouth long (0.43).
  - Whole check: 456 of 568 pairs hold (was 452); 193 findings (50 mechanic, 143 numbers).
  - The remaining air mechanic findings are bombers: 31 bombed only small radar contacts and missed, 16 never lined up a run against AA, 1 couldn't see.

## D104 — Fire-control (tracking) radar (2026-10-20, user-requested)

- **Defs:** new optional sensor fields `track` (radius), `trackError` (wobble radius of tracked contacts) and `trackDrain` (power per second).
- **Sensors:**
  - A sixth map `track` per ally team, stamped like `radar` (moves shift circles, full stamps budgeted).
  - An enemy unit that the team's radar detects (radar map, not inside its own team's jam map, stealth check passed) and that lies in the `track` map is **tracked** (`sensors.tracked[team]`, `Sensors.isTracked`).
  - The level stays `RADAR`, so every radar-contact rule (`canTargetRadar`, radar locks, wire flags) still applies.
  - A tracked radar contact's believed position wobbles by the team's best `trackError` instead of its `radarError`.
- **Jamming:** hides from tracking radar with no burn-through, because a jammed unit isn't radar-detected at all.
- **Power:**
  - `Sensors.drainStep` (a Build.step economy consumer, next to DIRCM) drains `trackDrain` power per second at the team's power stall ratio. The share a radar gets (`trackScale`, hashed) scales its radius, rounded down to whole 16-stud sensor cells.
  - A radar re-stamps when its radius changes; radii tables are cached per (def, radius).
  - Jammer upkeep (guide 11.4) is still not implemented; it can reuse this mechanism.
- **Weapons:**
  - Artillery, MLRS and bombs aim at the believed position, hence the tracked one.
  - Bombers also lead tracked contacts (`Air.bombSolution`), as they lead visible ones: tracking radar measures motion.
- **Wire:** strategic flag `TRACKED` = bit 4 (`PROTOCOL_VERSION` 5). A tracked contact's record carries the real icon; plain radar contacts keep icon 0.
- **Defs** (T2 placeholders, balance in M8):

| | Order | Chaos |
|---|---|---|
| Structure | `ord_tribunal` Tribunal: track 700, error 4, drain 40, 220 / 3,200 | `chs_seekerspire` Seeker Spire: track 600, error 10, drain 25, 150 / 2,200 |
| Vehicle | `ord_arbiter` Arbiter: track 450, error 6, drain 25, 160 / 2,400 | `chs_stalker` Stalker: track 380, error 12, drain 18, 120 / 1,700 |

  The structures are built by the Advanced Ground Workers (Architect, Forgemaster), the vehicles by the Advanced Vehicle Plants. Tracking radars have no early-warning radar of their own.
- **Tests** (`Tracking.spec`):
  - a Verdict on a radar-only Ravager: 4 of 15 direct hits untracked, 11 of 15 tracked;
  - an Absolution against a radar-only tank driving back and forth: 0 of 9 untracked, 6 of 10 tracked;
  - wobble stays within the Tribunal's 4 and the Seeker Spire's 10, and Order's is smaller;
  - a Shroud jammer cancels the track (and the radar contact);
  - the client gets the real icon and TRACKED only for the tracked contact;
  - a power stall shrinks the radius until the tank isn't tracked, and power brings it back.
  - Mutations (no tracking wobble, no lead) fail.
- **Balance:** `lune run balance` has a new section "Fire-control radar". It runs `Scenes.radarDuel`: equal-value artillery groups 380 studs apart, beyond sight, each with its T1 radar tower, with no tracking, Order tracking or Chaos tracking.
  - In the first run, Order's Tribunal doubled the Verdicts' direct hits (4 → 9). The Hellmouths still won: their mortars kill a tight group by blast alone.
  - With MLRS, Order won faster with tracking (1,021 vs 1,468 ticks).
  - Final run (2 seeds), Order's trade (no tracking / Order tracks / Chaos tracks): Verdict vs Hellmouth 0.61 / 0.71 / 0.68; Judgement vs Hydra 1.64 / 1.90 / 1.68.
  - Chaos's tracking more than doubles its direct hits (2 → 5) but not its effect. Order's units even live longer (unit-ticks 1,097 → 1,617): precise blast shells pile onto the one unit they aim at, while wobbly ones spread damage over the group. A question for the user.

## D105 — Radar-guided lock range +10% against tracked targets (2026-10-20, user-requested option)

- `EW.canLock`: for `RADAR` guidance, the lock range is multiplied by `EW.TRACK_LOCK_BONUS` = 1.1 when the shooter's team tracks the target. The fire-control radar hands over its track. Stealth (× signature) and burn-through apply on top.
- Kept separate from D104 so it can be removed on its own.
- **Test** (`Tracking.spec`): a Seraph can't lock a Wasp radar contact at 105% of its lock range until a Tribunal tracks it.

## D106 — Pathfinding uses the real map (2026-10-20, user decision)

- **Decision:** routes are planned on true passability, enemy structures included, whether or not the team has seen them. This is treated as physics, like BAR.
- **Known minor info leak:** units visibly avoid enemy structures their team never saw, so a careful observer can infer an unseen building from a detour. Accepted. Per-team passability would cost a separate flow-field cache per team.
- Placement uses the same physics at frame start (D101); only planning (the AI) uses team knowledge.

## D107 — Untracked contacts reveal only their domain (2026-10-20, user decision)

- **Rule:** a team knows a unit's type (its categories) only when the unit is VISIBLE, a ghost (seen before), tracked by its fire-control radar (D104), or its own. Any other radar or sonar contact reveals only its domain:
  - air: AIR, HELI, JET;
  - surface: GROUND, NAVAL, STRUCTURE;
  - submerged: SUB.
- `Sensors.typeKnown` and `Sensors.knownCategories` implement it. `Sensors.DOMAIN_MASK` holds the three masks.
- **Weapons:**
  - Targeting filters untracked contacts by domain only.
  - Untracked contacts score with weight 1 (no type priority).
  - Their collision radius doesn't count toward range, and bomb release uses radius 0.
  - Every current radar-capable weapon targets whole domains, so acceptance is unchanged today. Priorities do change: a radar SAM no longer prefers an untracked jet over a nearer untracked helicopter.
- **AI:** structure / Command Vehicle weighting only for typed contacts (visible, ghost, tracked).
- **Tests** (`Knowledge.spec`):
  - untracked tank, helicopter and submarine show only surface, air and submerged; tracked, the tank shows its real categories;
  - a Seraph picks the nearer untracked blip, but the jet once both are tracked;
  - the AI prefers a tracked generator over a nearer tank.
  - The last two fail when the rule is undone.
- **Still from truth:** a radar contact's altitude (aim height), which radar measures, and the seeker's lock physics (D101).

## D108 — Jammer power upkeep (2026-10-20, user decision; guide 11.4)

- **Defs:** new sensor field `jamDrain` (power per second). Values: Curtain 15, Smog 18, Veil 20, Shroud 25, Banshee 25, Siren 25, Veilspire 30, Blackout 35. Placeholders for M8.
- **Mechanism:** the same as tracking radars (D104). `Sensors.drainStep` drains `trackDrain + jamDrain` per powered sensor at the team's power stall ratio. The share it gets (`sensors.powerScale`, renamed from `trackScale`, hashed) scales both the track and the jam radius, in whole sensor cells. A unit re-stamps when either radius changes; radii tables are cached per (def, track, jam).
- **Tests** (`Fog.spec`):
  - a Veil hides a Lancer 250 studs away while powered, and its upkeep shows in the team's power demand;
  - after a stall the jam shrinks and the Lancer is a radar contact; power back, it is jammed again.
  - Ignoring the drain fails the test.
  - The older jamming test now keeps the Veil powered, because it runs longer than 1,000 stored power lasts.

## D109 — Unit generations and ghost pins (2026-10-20, user decision)

- **Generation counter:** `World.gen[id]` counts the units that have had an ID. It is incremented at spawn, kept after despawn, and hashed. `World.isRef(w, id, gen)` is true only while that very unit lives.
- **Every remembered unit reference stores its generation**, and every check goes through `World.isRef`:
  - weapon targets: `wTargetGen` (`World.setTarget`), a ghost's generation for dead structures;
  - `lastAttackerGen` (RETURN_FIRE);
  - `AirState.padGen`;
  - `BuildState.targetGen`;
  - projectiles' `pOwnerGen` / `pTargetGen` (`Combat.spawnProjectile` now takes the world and the target's generation);
  - ghosts (`Ghost.gen`);
  - NetOut's tactical set (stores the generation).
- **Ghosts:** `Sensors.knownTarget(sim, team, id, gen)` answers for a remembered reference: the live unit if `(id, gen)` matches, else only a ghost of that very generation, else hidden. Targeting, the AI and Placement use the ghost's generation for dead ghosts.
- **Ghost pins:** an ID remembered as a ghost by any team is pinned (`World.pin` / `unpin`, counted per team), and the allocator sends pinned IDs to the back of the free queue. Why: the wire carries 16-bit IDs, so a ghost and a new unit must not share one in strategic records. The ID is free again once every team has forgotten the ghost (its spot seen).
- **Tests** (`IdReuse.spec`, reuse forced by using up the fresh IDs):
  - generations and pins in World;
  - RETURN_FIRE never answers a new unit that got its old attacker's ID;
  - a dead structure's ghost keeps its generation and its ID isn't reused until the ghost is forgotten;
  - a builder drops a stale frame target, and a jet a stale pad, after their IDs went to other units.
  - Ignoring generations fails three of the tests; ignoring pins fails two.
