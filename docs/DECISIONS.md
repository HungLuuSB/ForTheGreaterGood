# Decisions log

Decisions made while working unattended. Each entry gives the date, the decision, the alternatives and the reason. Everything here is meant to be easy to change. Overrule any of them and I'll update the code, the guide and this file together.

## Summary

- D1–D51: first unattended session (M0, the M1 simulation side, the M2 combat core). The questions it raised were answered in round 3.
- D52–D54: round 3 (pathing fixes, duel reports).
- D55–D64: M3 economy and construction.
- D65–D72: M4 sensors and fog, NetOut, stress harness (tasks 11–14).
- D73–D78: M6 air and naval (tasks 15–16).
- D79–D82: M7 electronic warfare (task 17).

The open questions (D76, D80, D81, D82, the Commands peak) are listed in `docs/PROGRESS.md` → Summary.

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
