# Decisions log

Decisions made while working unattended. Each entry gives the date, the decision, the alternatives and the reason. Everything here is meant to be easy to change. Overrule any of them and I'll update the code, the guide and this file together.

## Summary

_Written when the unattended session ends. See `docs/PROGRESS.md` for the full status._

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
