# For The Greater Good — Game Design & Technical Guidelines

**Genre:** Real-time strategy (BAR-style streaming economy, modern warfare)
**Platform:** Roblox (Luau), PC-first
**Modes:** Team (2v2 – 4v4) and Free-For-All (up to 8 players)
**Factions:** Order / Chaos
**Document version:** 0.5 — living document; update it whenever a decision changes.

> **Naming note.** "For The Greater Good" plus *Order* and *Chaos* will remind many players of Warhammer 40K / Age of Sigmar. The words themselves are generic, but before committing, search Roblox for existing experiences with the same name and keep the visual identity clearly your own.

---

## Table of Contents

1. [Vision & Design Pillars](#1-vision--design-pillars)
2. [Factions & Naming Conventions](#2-factions--naming-conventions)
3. [Core Architecture](#3-core-architecture)
4. [Unit & Weapon Definitions](#4-unit--weapon-definitions)
5. [Map & Grid](#5-map--grid)
6. [Movement Classes & Pathfinding](#6-movement-classes--pathfinding)
7. [Networking](#7-networking)
8. [Economy](#8-economy)
9. [Construction & Tech Tree](#9-construction--tech-tree)
10. [Combat: Targeting, Weapons, Projectiles, Damage](#10-combat-targeting-weapons-projectiles-damage)
11. [Sensors & Information Warfare](#11-sensors--information-warfare)
12. [Domains: Ground, Air, Naval](#12-domains-ground-air-naval)
13. [Starter Unit Roster](#13-starter-unit-roster)
14. [Animation System](#14-animation-system)
15. [Client Rendering, Camera & UI](#15-client-rendering-camera--ui)
16. [Game Modes & Match Flow](#16-game-modes--match-flow)
17. [Debugging & Tooling](#17-debugging--tooling)
18. [Performance Budgets](#18-performance-budgets)
19. [Security & Anti-Exploit](#19-security--anti-exploit)
20. [Art Pipeline (Free Modeling Workflow)](#20-art-pipeline-free-modeling-workflow)
21. [Roadmap & Milestones](#21-roadmap--milestones)
22. [Appendices](#22-appendices)

---

## 1. Vision & Design Pillars

**One sentence:** A large-scale, modern-warfare RTS where two ideologies fight across land, sea and air, and where *information* — what you can see, detect and lock onto — matters as much as firepower.

### Pillars

| Pillar | What it means | What it rules out |
|---|---|---|
| **Scale over micro** | Armies of dozens to hundreds; macro decisions matter more than clicking speed. | Hero units, per-unit abilities with long cooldowns. |
| **Streaming economy** | Income and spending are rates. Nothing is paid upfront; shortages slow things down. | "Not enough resources" errors, upfront costs. |
| **Information warfare** | Radar, jamming, stealth and countermeasures decide engagements. | Full map vision, perfect-accuracy missiles. |
| **Combined arms** | Ground, air and naval units counter each other; no single domain wins alone. | One dominant unit type. |
| **Readable at a distance** | The camera is high; silhouettes, icons and colors must read clearly. | Tiny detail that only shows up close. |
| **Roblox-sized sessions** | Matches of 15–25 minutes. | BAR-length 45+ minute games as the norm. |

### Technical pillars

- **The server owns the simulation.** Clients send commands and render state. Clients never decide outcomes.
- **Simulation is pure data.** No Instances on the server for units. Everything is tables and buffers.
- **Pay for what changes.** Idle units cost (almost) nothing — no CPU, no bandwidth.
- **Measure before optimizing.** Every system has a time budget and a profiler label.

---

## 2. Factions & Naming Conventions

### 2.1 Faction identity

| | **Order** | **Chaos** |
|---|---|---|
| Ideology | Discipline, precision, control | Freedom, force, disruption |
| Palette | White / steel blue / gold accents | Gunmetal / crimson / rust accents |
| Shapes | Clean, angular, symmetric, sloped armor | Heavy, asymmetric, exposed machinery, spikes kept subtle |
| Doctrine | Better sensors, stealth, precision long range, DIRCM | Strong jamming, missile saturation, cheap mass, heavy armor |
| Strength | Wins information fights; strong at range | Wins brawls and attrition; blinds enemy sensors |
| Weakness | Expensive, fragile when cornered | Less accurate, weaker sensors, limited stealth |

Both factions have the **same roles** (scout, MBT, SAM, fighter, etc.) so balancing stays manageable. They differ in stats and in which information-warfare tools they get.

### 2.2 Naming conventions

**Internal IDs** (used in code, defs, models, replays) — short prefix, like BAR's `arm`/`cor`:

| Faction | ID prefix | Example IDs |
|---|---|---|
| Order | `ord_` | `ord_paladin`, `ord_seraph`, `ord_vehplant_t2` |
| Chaos | `chs_` | `chs_juggernaut`, `chs_gorgon`, `chs_vehplant_t2` |
| Shared / neutral | `neu_` | `neu_wreck_small`, `neu_supply_deposit` |

Rules for IDs: lowercase, `snake_case`, never renamed after release (replays and saved settings reference them). Change the **display name**, not the ID.

**Display names** — the name itself carries the faction, no visible prefix needed:

- **Order:** Latin, virtues, heraldry, angels, law. *Paladin, Bastion, Vigil, Seraph, Verdict, Sovereign.*
- **Chaos:** Myth beasts, predators, plague, ruin. *Juggernaut, Hydra, Gorgon, Ravager, Maw, Warlord.*

Optional tooltip designation for flavor: `ORD-T2 Paladin` / `CHS-T2 Juggernaut`.

---

## 3. Core Architecture

### 3.1 The model: commands in, state out

```
   Client A ──commands──▶ ┌──────────────────────────┐ ──state/events──▶ Client A
   Client B ──commands──▶ │  SERVER SIMULATION       │ ──state/events──▶ Client B
   Client C ──commands──▶ │  (authoritative, data)   │ ──state/events──▶ Client C
                          └──────────────────────────┘
```

- BAR/Spring uses **deterministic lockstep** (every client simulates, only commands travel). That doesn't work on Roblox: clients can't talk to each other, can't be trusted, and math functions aren't guaranteed identical across devices.
- Instead: the **server simulates**, clients **render**. Each client receives only what its team may know (fog of war), at a level of detail based on where it is looking.
- The server simulation must still be **deterministic on the server** (fixed tick, seeded RNG, fixed system order). That makes replays and bug reproduction possible.

### 3.2 Project structure

File extension is `.luau` everywhere. Rojo maps `Name.luau` to a ModuleScript, `Name.server.luau` to a Script and `Name.client.luau` to a LocalScript.

```
ReplicatedStorage/
  Shared/
    Defs/
      Units/            ord_*.luau, chs_*.luau, neu_*.luau   (one ModuleScript per unit)
      Weapons/          one ModuleScript per weapon
      MoveClasses.luau
      ArmorClasses.luau
      Categories.luau
      Defs.luau         loader + validation + derived values + defs hash
      Templates.luau    templates + extend() (unit modules require this, not Defs)
      Registry.luau     every def module by file name (no portable folder listing)
    Net/
      Schema.luau       packet layouts, field widths
      Packer.luau       buffer read/write helpers (bit packing)
      Remotes.luau      creates/gets RemoteEvents
    Grid/
      Grid.luau         cell math, coordinate encode/decode
      Layers.luau       per-cell layer buffers (height, waterDepth, ...)
      TestMap.luau      procedural test maps for headless tests (until baked maps exist)
      MapData/          baked map layers per map
    Util/
      Env.luau          detects the runtime (Roblox / Lune)
      Profiler.luau     profilebegin/end wrapper (no-op outside Roblox), clock for timings
      Log.luau          tagged, levelled logging
      Prng.luau         seeded deterministic PRNG (pure Luau, same output on every runtime)
      Hash.luau         FNV-1a 32-bit + canonical value hash (defs hash, world hash)
                        later: Fixed math, RingBuffer, Pool
  Models/               unit models by ID (client clones these)
  Icons/                strategic icons

ServerScriptService/
  Sim/
    Main.server.luau    Heartbeat tick loop (Roblox only; drives Sim.step)
    Sim.luau            Sim.new / submit / step / hash / runReplay, fixed system order
    Types.luau          shared Sim types (systems require this, not Sim)
    Scenarios.luau      named, deterministic match-start setups
    World.luau          unit storage (struct-of-arrays), ID allocator
    Replay.luau         replay log: header, commands, checkpoints
    Systems/
      Commands.luau     validation + command queues
      Economy.luau
      Sensors.luau      LOS / radar / sonar / jamming maps
      Targeting.luau
      Pathing.luau      requests, caching, corridor builder
      Movement.luau     steering, local avoidance
      Weapons.luau      aim model, fire control, countermeasures
      Projectiles.luau
      Damage.luau
      Construction.luau
      Lifecycle.luau    spawn, death, wrecks
      NetOut.luau       per-player interest + packet building
    Workers/            Actor scripts for flow fields (Parallel Luau)
  Tests/
    RunAll.luau         headless test runner
    *.spec.luau         test specs (section 17.2)

StarterPlayer/StarterPlayerScripts/
  Client/
    Main.client.luau
    World.luau          client-side table of known units
    NetIn.luau          packet decoding
    Interp.luau         snapshot buffer + interpolation
    Render/
      ModelPool.luau
      Animator.luau     piece scripts scheduler
      Effects.luau
      Projectiles.luau
    Camera.luau
    Input/
      Selection.luau
      Commands.luau
      BuildPlacement.luau
    UI/                 resource bar, build menu, unit panel, minimap, alerts
    Debug/              overlays, packet inspector

(repo only, not synced)
.lune/test.luau         Lune entry: `lune run test` runs every *.spec.luau
.luaurc                 require aliases (@shared)
```

**Runs in Lune and Roblox.** Everything under `Shared/` and `ServerScriptService/` must run unchanged in both Roblox and [Lune](https://lune-org.github.io/docs), so the simulation can be tested headless outside Studio. It uses string requires only (cross-tree via `.luaurc` aliases such as `@shared/Util/Prng`), and no Instances or Roblox-only globals. Runtime-specific behavior is confined to the `Util/Env`, `Util/Profiler` and `Util/Log` adapters. `Client/` is Roblox-only.

### 3.3 The simulation tick

- **Sim rate:** 15 Hz (one tick ≈ 66.7 ms). Tune between 10 and 20 Hz after stress tests.
- Run the loop from `RunService.Heartbeat` with a time accumulator; run whole ticks only, never partial ones.
- If the server falls behind, run at most 2 catch-up ticks per frame, then drop time (log a warning). Never spiral.

**System order per tick (fixed, never changes at runtime):**

| # | System | Rate | Notes |
|---|---|---|---|
| 1 | Commands | every tick | Validate and apply queued player commands |
| 2 | Economy | every 5th tick (3 Hz) | Team accounts, stall ratios |
| 3 | Sensors | every 2nd tick | Re-stamp emitters that changed sensor cell |
| 4 | Targeting | staggered | Each unit re-evaluates every N ticks, offset by `id % N` |
| 5 | Pathing | time-sliced | Fixed ms budget per tick; rest continues next tick |
| 6 | Movement | every tick | Steering, avoidance, position update |
| 7 | Weapons | every tick | Aim model, fire, countermeasures |
| 8 | Projectiles | every tick | Step, collide, impact |
| 9 | Damage & Lifecycle | every tick | Apply damage, deaths, wrecks |
| 10 | Construction | every tick | Build progress × economy ratio |
| 11 | NetOut | every tick | Interest management, build packets per player |

**Staggering** is the single biggest CPU saver: expensive per-unit decisions (targeting, re-path checks, idle behavior) run for only `1/N` of units each tick.

### 3.4 World storage

Use **struct-of-arrays** keyed by a numeric unit ID rather than one table per unit with many fields:

```lua
-- World.luau (server)
local World = {
	alive    = {},  -- [id] = true
	defId    = {},  -- [id] = "ord_paladin"
	team     = {},  -- [id] = 1..8
	posX     = {}, posZ = {}, alt = {},
	heading  = {},
	health   = {},
	state    = {},  -- bit flags (moving, building, firing, ...)
	dirty    = {},  -- bit flags of fields changed this tick (for NetOut)
}
```

- Unit IDs are `u16` (1–65535). **Delay reuse** of freed IDs (e.g., 10 seconds) so late packets never apply to the wrong unit.
- Every write to a replicated field also sets the matching `dirty` bit. NetOut reads and clears dirty bits.

---

## 4. Unit & Weapon Definitions

### 4.1 Principles

- One ModuleScript per unit returning a plain table (`return { ... }`), shared by server and client.
- Server uses gameplay fields; client uses visual fields (model, pieces, icon, script). Keep both in the same def so they never drift apart.
- Defs are **data only**: no functions except the optional animation script reference.
- Use **templates** to avoid copy-paste: `Defs.extend(baseTemplate, overrides)`.
- **Validate everything at startup** (see 4.5). A broken def must fail loudly in Studio, not mid-match.

### 4.2 UnitDef schema

```lua
-- ReplicatedStorage/Shared/Defs/Units/ord_paladin.luau
local Templates = require("../Templates")

return Templates.extend(Templates.TankT2, {
	id          = "ord_paladin",
	name        = "Paladin",
	description = "Main battle tank. Long-range rail cannon.",
	faction     = "order",
	tier        = 2,
	domain      = "ground",                 -- ground | air | naval | structure
	categories  = { "GROUND", "ARMORED" },  -- bitmask built at load time

	cost = { supply = 450, power = 6000, buildTime = 18000 }, -- buildTime in work units
	health     = 4200,
	armorClass = "ARMORED",

	moveClass = "HEAVY_TRACKED",
	movement  = { maxSpeed = 22, accel = 8, brake = 16, turnRate = 90 }, -- studs/s, deg/s
	footprint = 2,                           -- in cells (2 = 2x2 cells)

	sensors = {
		sight = 120,          -- studs
		radar = 0,
		sonar = 0,
		radarSignature = 1.0, -- 1 = normal; < 1 = stealthy
	},

	weapons = {
		{ def = "ord_railcannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	countermeasures = nil,  -- see section 11.6

	-- builders only
	buildPower   = nil,
	buildOptions = nil,
	buildRange   = nil,

	-- visuals (client)
	model  = "ord_paladin",
	pieces = { "base", "turret", "barrel", "muzzle" },
	script = "TankScript",   -- animation script module (section 14)
	icon   = "tank_heavy",   -- strategic icon (minimap + far zoom)
	wreck  = "neu_wreck_medium",
})
```

### 4.3 WeaponDef schema

```lua
-- ReplicatedStorage/Shared/Defs/Weapons/ord_railcannon.luau
return {
	id    = "ord_railcannon",
	type  = "BALLISTIC",  -- HITSCAN | BALLISTIC | HOMING | BEAM | TORPEDO | BOMB
	range = 260,          -- studs
	reload = 2.4,         -- seconds
	salvo  = { count = 1, delay = 0 },
	projectileSpeed = 400,
	gravity = 60,         -- BALLISTIC only
	accuracy = 0.6,       -- degrees of random spread

	damage = { LIGHT = 300, ARMORED = 420, STRUCTURE = 380, SHIP = 300, AIR = 0, SUB = 0 },
	aoe = 6, edgeEffectiveness = 0.3,

	targets   = { "GROUND", "NAVAL", "STRUCTURE" },  -- what it CAN hit
	priority  = { "ARMORED", "GROUND", "STRUCTURE" }, -- what it PREFERS

	turret = { yawRate = 90, pitchRate = 45, tolerance = 2, minPitch = -10, maxPitch = 20,
	           arc = 360 },  -- arc < 360 for fixed-mount weapons

	-- missiles only (section 11.5)
	guidance       = nil,  -- "IR" | "RADAR" | "COMMAND"
	turnRate       = nil,
	lockRange      = nil,
	terminalRange  = nil,
	canTargetRadar = false,

	-- visuals
	fx = { muzzle = "flash_large", trail = nil, impact = "explosion_medium", sound = "rail_fire" },
}
```

### 4.4 Shared enums

```lua
-- Categories.luau  (bitmask; max 32 for bit32)
GROUND=1, AIR=2, NAVAL=4, SUB=8, STRUCTURE=16, WORKER=32, COMMANDER=64,
ARMORED=128, LIGHT=256, HELI=512, JET=1024, ANTIAIR=2048, ARTILLERY=4096,
STEALTH=8192, RADAR_EMITTER=16384, JAMMER=32768

-- ArmorClasses.luau
LIGHT, ARMORED, STRUCTURE, AIR, SHIP, SUB
```

### 4.5 Startup validation (`Defs.luau`)

At load, for every def, assert:

- Required fields exist and have the right types; IDs match file names.
- `weapons[i].def`, `buildOptions[i]`, `wreck`, `moveClass`, `armorClass` reference things that exist.
- Every damage table covers every armor class (missing = 0, but log it).
- `pieces` listed in the def exist in the model (client-side check in Studio).
- Builders have `buildPower > 0`; non-builders have none.
- At most 8 entries in `weapons`: the state record's aim slot mask is one byte and its weapon field holds 2 bits per slot in a `u16` (section 7.3).
- Compute and cache derived values (category bitmasks, max weapon range, numeric def index for packets).

Assign each def a **numeric index** (sorted by ID) so packets send `u16 defIndex` instead of strings. Units and weapons have separate index spaces, both 1-based (0 is reserved on the wire). Hash the full def set; server and client compare the hash on join.

How `Defs.luau` does it:

- Defs are registered by hand in `Defs/Registry.luau`, keyed by file name. Neither runtime can list a folder portably, and the key is what "IDs match file names" is checked against.
- Unit modules `require("../Templates")` and call `Templates.extend(...)`. `Defs.luau` requires the registry, so a unit module requiring `Defs` would be a cycle. `Defs.extend` and `Defs.Templates` are re-exported for everything else.
- `extend` deep-merges records (`cost`, `movement`, `sensors`…) and replaces lists (`categories`, `weapons`, `pieces`…) whole.
- **Unknown fields are errors**, so a typo such as `maxspeed` fails loudly instead of silently using a template value.
- Validation collects **every** problem and fails once, listing them all (`Defs: 3 problem(s): …`), each prefixed with the def and field path.
- Built defs are deep-frozen. Derived fields: unit `index`, `categoryMask`, `maxRange`, `weapons[i].weaponIndex`; weapon `index`, `targetMask`, `priorityMasks`.
- The defs hash is FNV-1a 32-bit over a canonical serialization (sorted keys, numbers by their IEEE-754 bits), so it is identical on every runtime.
- The `pieces`-exist-in-model check runs client-side once models exist; it can't run headless.

---

## 5. Map & Grid

### 5.1 Grid basics

- **Cell size:** 8 × 8 studs.
- **Max map:** 256 × 256 cells = 2048 × 2048 studs (cell index fits in `u16`).
- Center maps on the world origin; float precision drops far from it.
- Bigger maps later: either 16-stud cells for the strategic tier, or `u32` cell indices. Decide once, before shipping.

**Recommended sizes**

| Mode | Cells | Studs |
|---|---|---|
| 1v1 | 128 × 128 | 1024 |
| 2v2 / 3-4 FFA | 192 × 192 | 1536 |
| 3v3 – 4v4 / 8 FFA | 256 × 256 | 2048 |

### 5.2 Cell data layers

Store each layer as its own `buffer` (flat, cache-friendly, cheap to send to Actors):

| Layer | Type | Purpose |
|---|---|---|
| `height` | i16 (×0.25 stud) | Ground height; client uses it to place ground units |
| `waterDepth` | i16 (×0.25 stud) | 0 = dry land |
| `slope` | u8 | Max slope inside the cell, 0–255 → 0–90° |
| `terrainType` | u8 | Grass, rock, sand, road (speed modifiers) |
| `passMask` | u16 | Bit per move class: can this class enter this cell |
| `clearance[mc]` | u8 per move class | Distance (cells) to nearest blocked cell; used for big footprints |
| `occupancy` | u16 | Structure ID occupying cell (0 = free) |
| `supply` | u8 | Supply deposit value (extractor spots) |

### 5.3 Coordinates on the wire

```
position = cellIndex (u16) + offsetX (u8) + offsetZ (u8)     → 32 bits
offset   = 0..255 → 0..8 studs  (1/32 stud ≈ 0.031 precision)
worldX   = (cellX + offsetX/256) * 8 + mapOriginX
```

Cell index = `cz * cellsX + cx` with 0-based cell coordinates (`Grid.index`). Encoding truncates, so the decoded position is within `[0, 1/32)` stud of the true one. Positions outside the map clamp to the edge cell, so an invalid cell never goes on the wire.

Ground units don't send height: the client looks it up from its own copy of the `height` layer. Air units send altitude above ground (`u8`, 1 stud steps, 0–255).

### 5.4 Map authoring pipeline

1. Build the map with Roblox Terrain + structure props in Studio.
2. Run a **bake plugin/script in Studio** (not at runtime): raycast each cell for height, water, slope and material; mark supply deposits and start positions from tagged parts.
3. Compute `passMask` and `clearance` for every move class.
4. Serialize the layers into a compact string (e.g., base64) inside a ModuleScript under `MapData/`.
5. At server and client startup, decode into buffers.

### 5.5 Map layout guidelines

- **Symmetry:** mirrored or rotational for fair team play. FFA maps: rotational for 3–8 starts.
- **Supply deposits:** 3–4 safe ones near each start, contested ones in the middle, a few rich ones in exposed spots.
- **Water:** every naval-enabled map needs a connected sea reachable from at least some starts; give non-coastal starts a land path to the coast.
- **Chokepoints and open ground:** both, so artillery, tanks and air each have a place to shine.
- **Elevation:** hills give sight range bonus (optional); slopes limit wheeled units.
- **Air lanes:** keep some areas without SAM-friendly terrain so air play is viable.
- Tag maps with supported modes (`Team`, `FFA`, `Naval`).

---

## 6. Movement Classes & Pathfinding

### 6.1 Movement classes

| Move class | Used by | Allowed cells | Max slope | Water | Footprint | Pathing |
|---|---|---|---|---|---|---|
| `WHEELED` | scouts, SAM trucks, light workers | land | 20° | ford ≤ 1 stud | 1 | flow field |
| `TRACKED` | light/medium tanks, artillery | land | 30° | ford ≤ 2 studs | 1–2 | flow field |
| `HEAVY_TRACKED` | T2 MBTs, heavies | land | 25° | ford ≤ 2 studs | 2 | flow field |
| `HOVER` | hover workers, hover tanks | land + water surface | 18° | any (on surface) | 1–2 | flow field |
| `AMPHIB` | amphibious tanks | land + sea floor | 30° | any (submerged) | 1–2 | flow field |
| `SHIP` | surface ships, carriers | water | — | depth ≥ 6 studs | 2–4 | flow field |
| `SUB` | submarines | water | — | depth ≥ 12 studs | 2 | flow field |
| `HELI` | helicopters, air workers | anywhere | — | — | — | steering |
| `JET` | fighters, bombers | anywhere | — | — | — | steering |

Each move class gets one bit in `passMask` and its own `clearance` layer.

### 6.2 Footprints and clearance

A unit with footprint `F` cells can stand in a cell only if `clearance[mc][cell] ≥ floor(F / 2) + 1`. Clearance is the Chebyshev distance to the nearest cell the class can't enter (a blocked cell is 0; outside the map counts as blocked). It is computed with a two-pass distance transform at map load, and updated locally when a structure is placed or destroyed.

The rule requires the (2r+1)² square around the cell to be free, with r = floor(F/2). Even footprints count as the next odd size, so a 2×2 unit needs a 3-wide gap. The earlier `ceil(F/2)` let a 2×2 unit into a 1-cell gap (DECISIONS D21).

Slope is the steepest climb to a 4-neighbor, stored as u8 (0..255 = 0..90°). `Shared/Grid/Passability.luau` builds slope, passMask and clearance from the height and water layers: about 75 ms for a 256×256 map in Lune.

### 6.3 Hierarchical pathfinding: quadtree + flow field

**Step 1 — Coarse route (quadtree).** For each move class, build a quadtree over passability: a leaf is a square region that is entirely passable or entirely blocked. Run A* over adjacent passable leaves. This is fast because open terrain becomes a few big leaves.

**Step 2 — Corridor.** Take the leaves along the coarse route, plus one neighbor ring as padding. That's the corridor.

Implementation (`Sim/Path/Quadtree.luau`, `Sim/Path/Route.luau`):
- One tree per (move class, required clearance); see DECISIONS D26–D28.
- Leaves link by shared edges only, and connected components make unreachable goals an O(1) rejection.
- A* runs over leaf centers with the start and goal cells as endpoints.
- The padding ring is made of whole adjacent open leaves.
- Measured on 256×256 hilly terrain: tree build about 6 ms (load time), route about 2.5 ms corner to corner.

**Step 3 — Flow field inside the corridor only.**
- Integration field: Dijkstra/BFS from the goal cell over corridor cells (cost = 1 × terrain modifier).
- Direction field: `u8` per cell (0–7 = eight directions, 255 = none).
- All units in one move order with the same move class **share one field**.

**Step 4 — Steering.** Each tick, a unit reads the direction for its cell, blends it with local avoidance, and moves.

### 6.4 Caching and budgets

- Cache fields by `(moveClass, clearance need, goalCell)`. LRU with ~32 entries (a 256×256 direction field is 64 KB). Recency is a use counter, so eviction is deterministic (`Sim/Path/FieldCache.luau`).
- **Time-slice:** the Pathing system has a fixed budget per tick (e.g., 8 ms). Unfinished work continues next tick. Units start moving toward the goal in a straight line until their field is ready.
  - The budget is counted in **work units** (cells settled + cells directed), calibrated so it takes about 8 ms on a live server. A wall-clock budget would make the tick a path completes on, and therefore the whole simulation, depend on CPU speed (DECISIONS D29).
  - A sliced job gives byte-identical output to a one-shot job (`Sim/Path/FlowField.luau`).
- **Parallel Luau:** run field generation in Actors. Each Actor keeps its own copy of the static grid layers; the main sim sends requests and receives finished direction buffers.
- **Invalidation:** when a structure changes passability, mark the affected quadtree nodes dirty and drop cached fields that cover them.

### 6.5 Local avoidance

- Units do not path around each other. They use **separation steering** against nearby units found through a dynamic spatial hash (rebuilt or updated each tick, same 8-stud cells).
- Idle units nudge aside for moving friendly units (push priority: moving > idle; larger > smaller).
- Structures are static obstacles in the grid, never in the spatial hash.
- Implementation notes (`Sim/Systems/Movement.luau`, DECISIONS D36–D38, D42):
  - The hash uses 16-stud buckets (3×3 search).
  - Separation steering acts within radius sum + 2 studs. After moving, overlaps are resolved by position, with idle units yielding 80/20.
  - Tanks move along their heading at a limited turn rate, with an accel/brake speed curve.
  - Idle units return to their spot when pushed off it.

### 6.6 Group movement & formations

- **Line move (BAR-style):** dragging a right-click line spreads selected units evenly along it; each gets its own goal cell but units sharing a move class and nearby goals can share a field.
- **Speed matching (optional toggle):** group moves at the slowest member's speed.
- Arrival: units within a radius of the goal stop rather than pushing to the exact cell.
- Implementation notes (`Sim/Nav.luau`, DECISIONS D35, D38–D40):
  - Each (move class, footprint) group shares one field to the group goal, and each unit gets its own formation slot.
  - Slots fill far side first along the approach direction.
  - A unit steers straight to its slot when it shares an open leaf with it or the line is clear.
  - Arrival is within 1.5 studs. A unit gives up within 24 studs after 45 ticks without progress.
  - Units pushed out of the corridor, or stalled, trigger a merged-corridor field extension.

### 6.7 Air movement

- **No pathfinding.** Air units steer directly toward their goal.
- **JET:** minimum speed (can't stop), limited turn rate, circles when idle or attacking. Collision checks use the swept path each tick because jets move 15–25 studs per tick.
- **HELI:** can hover, slower turns, separation steering against other helis.
- Altitude bands (above ground): helicopters 30–40, jets 90–120, bombers 120–140. Altitude follows terrain smoothly.

---

## 7. Networking

### 7.1 Channels

| Channel | Direction | Remote type | Content |
|---|---|---|---|
| `Cmd` | C → S | RemoteEvent (reliable) | Player commands, camera area |
| `Tactical` | S → C | UnreliableRemoteEvent | Positions/headings of units in camera area |
| `State` | S → C | RemoteEvent (reliable) | Discrete changes: state bits, health, aim, build progress |
| `Strategic` | S → C | UnreliableRemoteEvent | Minimap data for all known units |
| `Events` | S → C | RemoteEvent (reliable) | Enter/leave tactical tier, fire, impact, death, alerts |
| `Eco` | S → C | RemoteEvent (reliable) | Own team's economy |
| `Snapshot` | S → C | RemoteEvent (reliable) | Full world for join/reconnect |

**Rule of thumb:** continuous values where only the latest matters (position, heading) go **unreliable**. Discrete changes that must not be lost (died, started building, health changed) go **reliable**.

All payloads are `buffer`s written with `Packer.luau`. UnreliableRemoteEvent has a small per-message size limit (around 900 bytes; check the current docs), so `NetOut` splits large updates into several messages.

### 7.2 Interest management (per player, every tick)

```
for each player P:
    knownUnits = units visible or on radar/sonar to P's ally team   ← fog of war, always first
    for each unit U in knownUnits:
        if U in P.cameraArea (+ margin):  tactical tier
        else:                             strategic tier
```

- **Fog of war is applied first and never depends on the camera.** A client lying about its camera area only changes detail level, never what it can see.
- **Hysteresis:** a unit enters the tactical tier when inside `area + 2 cells`, leaves when outside `area + 5 cells`. Prevents flickering at the edges.
- Fast jets owned by or near the player's team: larger margin, or always tactical while in allied airspace.
- **Entering tactical:** server sends one reliable `Enter` event with the unit's full state. After that, only changes.
- **Leaving tactical:** reliable `Leave` event; client returns the model to the pool but keeps the unit in its strategic table.

### 7.3 Packet layouts

Implemented in `Shared/Net/Schema.luau` on top of `Shared/Net/Packer.luau`; `Tests/Schema.spec.luau` locks the exact bytes.

**Wire rules (all records)**

- Little-endian multi-byte values. Bit fields are packed LSB-first (first field in the lowest bits) and zero-padded to a whole byte.
- Schema fields are wire units: integers already quantized by the caller (health 0..255, heading 0..255, …).
- Unit, target and def IDs are 1-based; **0 is reserved** and rejected.
- Decoders accept only what the schema defines: unknown enum values, reserved flag bits, empty masks and out-of-range counts are errors, and so is truncated input. Callers decoding client data wrap the decode in `pcall` and drop the packet (section 19).
- A message is a run of records of one type, optionally preceded by a header. `Packer.chunk` splits a record list into messages of at most 900 bytes, never splitting a record. Tactical and Strategic messages start with a **tick header**: `tick u16`.
- **`Schema.PROTOCOL_VERSION`** (currently 1) identifies the wire format. Bump it on any change to a layout, enum value or validation rule. It is checked on join (section 7.5) and written into replay headers (section 17.1). `Schema.spec` pins hand-computed golden bytes to it, so an unbumped format change fails the tests.
- **Wire ticks wrap.** Ticks on the wire are `u16` (sim tick mod 65,536), which wraps every ~72.8 min at 15 Hz. Never compare them with `<`/`>`. `Shared/Net/Tick.luau` compares by signed shortest distance (`Tick.diff`, `Tick.isNewer`) and rebuilds full ticks near a reference (`Tick.unwrap`). That is correct while the two ticks are under 32,768 ticks (~36 min) apart, which always holds for live packets. Sim and replay ticks are full integers and never wrap.

**Command (C → S)**

```
cmdType   u8      1 MOVE, 2 FIGHT, 3 ATTACK, 4 ATTACK_GROUND, 5 PATROL, 6 GUARD, 7 STOP,
                  8 BUILD, 9 REPAIR, 10 RECLAIM, 11 SET_FIRE_STATE, 12 SET_MOVE_STATE,
                  13 TOGGLE, 14 CAMERA   (0 is invalid)
flags     u8      bit0 = queue (shift), bit1 = line formation; other bits reserved
count     u16     number of unit IDs: 1..200 (CAMERA: 0)
unitIds   u16 × count
params    by cmdType:
  MOVE, FIGHT, ATTACK_GROUND, PATROL   cell u16, offX u8, offZ u8
                                       + line end cell2 u16, offX2 u8, offZ2 u8 if the line flag is set
  ATTACK, GUARD, REPAIR, RECLAIM       targetId u16 (unit, or wreck for RECLAIM)
  BUILD                                defIndex u16, cell u16, offX u8, offZ u8,
                                       facing u8: 0..3 = 0/90/180/270° (bits 2–7 reserved)
  SET_FIRE_STATE / SET_MOVE_STATE      value u8: 0 hold, 1 return fire / maneuver, 2 fire at will / roam
  TOGGLE                               value u8: 0 off, 1 on
  CAMERA                               minX u8, minZ u8, maxX u8, maxZ u8  (camera area as a cell rectangle)
  STOP                                 none
```

The line flag is only valid on position commands. Largest command: 4 + 400 + 8 = 412 bytes.

**Tactical record (S → C, unreliable), only for units that moved this tick**

```
unitId    u16
cell      u16
offX      u8
offZ      u8
heading   u8      0..255 → 0..360°
flags     u8      bit0 = has altitude; other bits reserved
[alt]     u8      only if flag set (air units)
                  = 8 bytes, 9 with altitude
```

**State record (S → C, reliable), only changed fields**

```
unitId    u16
mask      u8      which fields follow: bit0 health, bit1 state, bit2 aim, bit3 weapon, bit4 build
                  (never 0; bits 5–7 reserved)
[health]  u8      fraction 0..255
[state]   u16     bit flags (moving, building, stunned, submerged, landed, cloaked...)
[aim]     u8      slot mask: bit i-1 = weapon slot i (1..8) follows; never 0
          u8 ×2   yaw, pitch for each set slot, in slot order
[weapon]  u16     2 bits per slot (slot 1 = bits 0–1): 0 IDLE, 1 AIMING, 2 READY, 3 RESTORING
[build]   u8      build progress 0..255
```

Units have at most **8 weapon slots**; defs validation must enforce it. The aim slot mask means only weapons whose aim changed are sent, and the record can be decoded without knowing the unit's def. The 2-byte weapon field is sent only when a weapon state changes.

**Strategic record (S → C, unreliable, 2–4 Hz)**

```
unitId    u16
cell      u16
icon      6 bits  bits 0–5   (radar-only contacts send icon 0 = unknown blip)
team      3 bits  bits 6–8   team - 1 (teams 1..8)
flags     7 bits  bits 9–15  bit0 radarOnly, bit1 sonarOnly, bit2 underAttack, bit3 ghost; bits 4–6 reserved
                  = 6 bytes per unit
```

**Event examples (reliable)**

```
FIRE      tick u16, shooterId u16, weaponSlot u8, targetCell u16 + off u8 u8 | targetId u16
SPAWN_PROJ projId u16, weaponDefIndex u16, origin(pos), velocity(i16×3), targetId u16, tick u16
IMPACT    projId u16, pos
DEATH     unitId u16, severity u8, wreckId u16
ALERT     type u8, cell u16    (unit under attack, structure lost, ...)
```

### 7.4 Client interpolation

- Each tactical message carries its server tick in the tick header (section 7.3; compare wire ticks with `Net/Tick`, never `<`). The client keeps a small buffer per unit (3–4 snapshots).
- Render time = latest tick − 2 ticks (≈ 133 ms at 15 Hz). Interpolate position and heading between the two surrounding snapshots.
- If a snapshot is missing, extrapolate up to 1 tick, then hold.
- A unit that hasn't moved sends nothing, and the client simply keeps its last position.

### 7.5 Join, reconnect, spectate

- On join: check **protocol version** (`Schema.PROTOCOL_VERSION`) and **defs hash** first; on a mismatch, refuse with a clear message (stale client) before sending anything else. Then send map ID, full snapshot of everything the player's team knows, current economy.
- Reconnect = join. Spectators get every team's knowledge (or full world in replays).

### 7.6 Bandwidth budget

Targets per player (measure on real servers):

| Stream | Typical | Peak target |
|---|---|---|
| Tactical (≈ 80 moving units × 9 B × 15 Hz) | 5–10 KB/s | 15 KB/s |
| Strategic (500 units × 6 B × 3 Hz) | 3–9 KB/s | 10 KB/s |
| State + Events | 2–5 KB/s | 10 KB/s |
| **Total** | **10–25 KB/s** | **≤ 35 KB/s** |

If over budget: reduce tactical rate for distant-but-in-view units, drop strategic to 2 Hz, merge events per tick.

---

## 8. Economy

### 8.1 Resources

| Resource | BAR equivalent | Sources | Main uses |
|---|---|---|---|
| **Supply** | Metal | Extractors on deposits, converters, reclaiming wrecks | Building everything, rearming aircraft, reloading missiles |
| **Power** | Energy | Generators, solar, wind, tidal, fusion | Building, radar/jammer upkeep, DIRCM, energy weapons |

### 8.2 Streaming model

- Costs are **spent over time while building**, never upfront.
- A builder with build power `BP` working on a unit with cost `C` and build time `T` (work units):
  - progress per second = `BP / T`
  - supply drain per second = `C.supply × BP / T`
  - power drain per second = `C.power × BP / T`
- Several builders on one project simply add their BP together (assisting).

### 8.3 Team account (per team)

```lua
eco = {
	supply = { stored = 0, storage = 1000, income = 0, demand = 0, ratio = 1 },
	power  = { stored = 0, storage = 1000, income = 0, demand = 0, ratio = 1 },
}
```

- **Income and demand are running totals**, updated only when something changes (structure built/destroyed/toggled, builder starts/stops/switches target).
- Variable sources become one multiplication: `windIncome = windGenCount × currentWind`.

### 8.4 Economy step (3 Hz)

```lua
local function econStep(r, dt)          -- r = eco.supply or eco.power
	local available = r.stored + r.income * dt
	local wanted    = r.demand * dt
	r.ratio  = wanted > 0 and math.min(1, available / wanted) or 1
	r.stored = available - wanted * r.ratio
	if r.stored > r.storage then
		r.overflow = r.stored - r.storage   -- shared to allies, or wasted
		r.stored   = r.storage
	end
end
```

**Two resources at once:** a consumer that needs both progresses at `min(supplyRatio, powerRatio)` and actually uses less of the other resource. Do two passes: compute both ratios, then let each consumer advance at its effective ratio while summing what it actually used. Refund the unused part.

**Fixed order:** production → converters (power → supply) → consumers → overflow sharing.

Optionally store values as integers in thousandths so rounding never drifts over long matches.

### 8.5 Economy structures

| Structure | Tier | Effect |
|---|---|---|
| Supply Extractor | T1 | Supply income on a deposit (scales with deposit value) |
| Advanced Extractor | T2 | ~3–4× extractor output, same deposit (upgrade replaces T1) |
| Power Generator (fuel) | T1 | Steady power |
| Solar Array | T1 | Low steady power, cheap |
| Wind Turbine | T1 | Variable power (global wind value changes every ~30 s) |
| Tidal Generator | T1 naval | Steady power, water only |
| Fusion Reactor | T2 | Large power; big explosion on death |
| Supply Converter | T1/T2 | Converts power → supply at a fixed rate (toggleable) |
| Supply Depot / Power Bank | T1 | +Storage |

### 8.6 Logistics (modern-warfare layer)

Route these through the same team account so shortages affect them naturally:

- **Aircraft rearm/repair** at airfield pads or carriers: drains supply + power while rearming.
- **Missile reloads** for SAM sites and launchers: each reload costs supply over the reload time.
- **Sensor upkeep:** radars, jammers and DIRCM drain power continuously. If power stalls, they lose range or switch off.

### 8.7 Reclaim

- Destroyed units leave **wrecks** with a supply value (e.g., 50% of cost). Workers reclaim them over time.
- Wrecks are static features stored in grid cells. They appear on the minimap and are rendered in the tactical tier.

### 8.8 Networking

Own team only, 3 Hz, reliable: stored, storage, income, demand for both resources (`u32` or quantized `u16`). Client smoothly animates the resource bars. Enemies never receive it.

---

## 9. Construction & Tech Tree

### 9.1 Builders

Every domain has a **T1 worker** and an **advanced (T2) worker**. Workers build structures of their domain plus shared economy and sensor structures.

| Builder | Comes from | Builds |
|---|---|---|
| **Command Vehicle** | Start of match | T1 economy, all T1 factories (Shipyard only near water), light turret, radar tower |
| **Ground Worker** | Vehicle Plant | T1 economy, Vehicle Plant, **Advanced Vehicle Plant**, T1 land defenses (gun turret, IR SAM site), radar tower, T1 jammer |
| **Advanced Ground Worker** | Advanced Vehicle Plant | T2 economy (advanced extractor, fusion), T2 land defenses (heavy turret, long-range radar SAM, artillery emplacement), long-range radar, T2 jammer |
| **Air Worker** | Airfield | T1 economy, Airfield, **Advanced Airfield**, rearm pads, IR SAM site, radar tower |
| **Advanced Air Worker** | Advanced Airfield | T2 economy, advanced rearm pads, long-range radar, T2 SAM site |
| **Naval Worker** | Shipyard | T1 economy incl. tidal, Shipyard, **Advanced Shipyard**, floating turret, torpedo launcher, sonar buoy |
| **Advanced Naval Worker** | Advanced Shipyard | T2 naval economy, coastal battery, naval SAM platform, sonar station |

### 9.2 Factories

| Factory | Tier | Produces |
|---|---|---|
| Vehicle Plant | T1 | Ground Worker, T1 ground units |
| Advanced Vehicle Plant | T2 | Advanced Ground Worker, T2 ground units |
| Airfield | T1 | Air Worker, T1 aircraft (rearm pads included) |
| Advanced Airfield | T2 | Advanced Air Worker, T2 aircraft |
| Shipyard | T1 | Naval Worker, T1 ships, submarine |
| Advanced Shipyard | T2 | Advanced Naval Worker, T2 ships, carrier |

Factories have build power and an optional rally point and repeat queue. Workers can assist factories.

### 9.3 Build rules

- Placement: footprint must be on cells passable for the structure's placement class (land / water / either), not occupied, within builder range when construction starts.
- **Facing:** every BUILD order carries a facing of 0/90/180/270° (section 7.3). Footprints rotate with facing: a non-square W×D footprint occupies D×W cells at 90°/270°. Placement checks, occupancy and passability updates all use the rotated footprint. Square footprints are unaffected.
- The client shows a placement ghost using its own grid copy; the server re-validates.
- Unfinished structures exist from the first tick with low health (they can be attacked).
- Cancelling refunds what was spent (optional: 100% refund like BAR).
- Upgrading a T1 extractor into T2: build the T2 on the same spot; the T1 is removed when construction starts.

### 9.4 Tech progression

```
Command Vehicle ─▶ T1 Factories ─▶ T1 Workers ─▶ Advanced Factories (expensive) ─▶ T2 Workers ─▶ T2 defenses & economy
                                                └─▶ T2 combat units
```

A T2 factory should cost roughly as much as a strong T1 army so players choose between "tech up" and "push now."

---

## 10. Combat: Targeting, Weapons, Projectiles, Damage

### 10.1 Unit behavior states (BAR-style)

| Fire state | Behavior |
|---|---|
| Hold Fire | Never fires on its own |
| Return Fire | Fires only at attackers |
| Fire at Will | Fires at any valid target (default) |

| Move state | Behavior |
|---|---|
| Hold Position | Never moves on its own |
| Maneuver | Chases a little, returns (default) |
| Roam | Chases freely |

### 10.2 Target acquisition

- Runs **staggered**: each unit re-evaluates every 4–8 ticks (offset by `id % N`). Keep the current target while it stays valid (hysteresis).
- **Candidate search:** query cells within weapon range from the per-team **contact grid** (a coarse 64-stud bucket grid of enemies this team can see or detect), not from all units.
- **Filter:** `bit32.band(target.categories, weapon.targetMask) ~= 0`, target known to the team (visible, or radar contact if `canTargetRadar`), within arc and range.
- **Score:** priority category weight ÷ distance, bonus for units already being shot by allies (focus fire, optional), penalty for overkill.
- Long-range weapons (SAM sites, artillery): use the coarse bucket grid only, and re-evaluate less often.

### 10.3 Aim model (server)

Each weapon has numeric `yaw` and `pitch` that rotate toward the target at `yawRate`/`pitchRate`. A weapon fires only when within `tolerance` degrees and reloaded. This makes turret speed and "arm raising" real gameplay without any animation on the server (see section 14).

### 10.4 Weapon types & how they replicate

| Type | Examples | Server | Network | Client |
|---|---|---|---|---|
| `HITSCAN` | MG, autocannon, CIWS | Instant hit roll | `FIRE` event | Tracer/flash |
| `BEAM` | Laser defense | Instant hit, damage over duration | `FIRE` event | Beam for duration |
| `BALLISTIC` | Tank shells, artillery, flak | Simulated arc | `SPAWN_PROJ` once, `IMPACT` | Simulates same arc |
| `HOMING` | SAMs, AAMs, ATGMs | Simulated steering + EW checks | `SPAWN_PROJ`, `IMPACT` or `DECOYED` | Steers with same algorithm |
| `TORPEDO` | Subs, ASW | Homing, restricted to water | Same as homing | Underwater trail |
| `BOMB` | Bombers | Ballistic with zero launch speed | Same as ballistic | Falls |

### 10.5 Projectiles (server)

- Stored in their own struct-of-arrays pool with `u16` IDs.
- Collision against **unit collision volumes** (sphere or cylinder per def), found through the dynamic spatial hash. No Roblox raycasts against Parts.
- Fast projectiles and jets: test the segment travelled this tick (swept test), not just the end point.
- Ground impact: compare projectile height to the `height` layer.
- Lifetime cap per weapon; expired homing missiles self-destruct.
- Hard cap on live projectiles (e.g., 2,000). If exceeded, oldest ballistic shells resolve instantly at their predicted impact point.

### 10.6 Damage

- `damage = weapon.damage[target.armorClass]`.
- AoE falloff: `dmg × (1 − (d / aoe) × (1 − edgeEffectiveness))`.
- Friendly fire: AoE only (direct hits never hit allies). Toggleable per match.
- Structures under construction take full damage.
- Death severity (overkill amount) chooses the death effect and whether a wreck is left.

### 10.7 Implementation notes (M2 core, headless)

- Code: `Sim/Combat/` (`Combat.luau` state, `ContactGrid.luau`, `Ballistics.luau`) and `Sim/Systems/` (`Targeting`, `Weapons`, `Projectiles`, `Damage`). See DECISIONS D43–D50.
- Targets are per weapon slot and staggered (6 ticks). Every enemy is visible until Sensors (M4).
- Collision volumes are cylinders (radius 0.45 × footprint × 8, height 6 × footprint).
- Projectile flight is exact, with a swept chord test. AoE is measured to the cylinder surface.
- Damage is queued and applied in order. Deaths leave a wreck worth 50% of supply when overkill ≤ 50% of max health.
- Per-tick events are in `sim.combat.events`.
- Not yet: line-of-fire checks (10.8), target leading, salvos, guidance (M7), focus-fire and overkill heuristics.

### 10.8 Line of fire

- Ballistic and homing: no line check (they arc or steer).
- Hitscan/beam/direct shells: sample the `height` layer along the line every cell; if terrain blocks, don't fire and try repositioning (Maneuver/Roam) or retarget.

---

## 11. Sensors & Information Warfare

### 11.1 Detection levels

For each enemy unit and each ally team:

| Level | Meaning | What the observer gets |
|---|---|---|
| `HIDDEN` | Not detected | Nothing |
| `RADAR` | Radar contact | Blip, position with error, no type (unless previously identified) |
| `SONAR` | Sonar contact | Blip for naval/submerged units |
| `VISIBLE` | In sight (LOS) | Full information |
| `GHOST` | Structure seen earlier, now out of sight | Last known position & type (minimap + map) |

### 11.2 Sensor maps

Per ally team, on a **sensor grid of 16-stud cells** (2×2 grid cells; 128×128 for a full map):

| Map | Type | Stamped by |
|---|---|---|
| `los` | u8 counts | Every unit's sight radius |
| `airLos` | u8 counts | Sight against aircraft (ignores terrain, usually larger) |
| `radar` | u8 counts | Radar emitters |
| `sonar` | u8 counts | Sonar emitters |
| `jam` | u8 counts | This team's jammers (hides this team's units from enemy radar) |

**Stamping:** precompute circle offset lists per radius. When an emitter crosses into a new sensor cell, subtract its old circle and add the new one. Units that don't change sensor cell cost nothing. Large moving radars (AWACS) re-stamp at most every few ticks.

Optional later: terrain-occluded LOS (sample height along rays at stamp time). Start without it.

### 11.3 Visibility rule

```
for enemy unit U, observer team T:
    cell = sensorCell(U)
    if U.submerged:
        if T.sonar[cell] > 0 then SONAR (or VISIBLE within close sonar range) else HIDDEN
    elseif (U.isAir and T.airLos[cell] > 0) or T.los[cell] > 0:
        VISIBLE
    elseif T.radar[cell] > 0
       and U.team.jam[cell] == 0                 -- not covered by its own team's jammer
       and passesStealthCheck(U, T):
        RADAR
    elseif U.isNaval and T.sonar[cell] > 0:
        SONAR
    else:
        HIDDEN (or GHOST for previously seen structures)
```

Compute this when a unit changes sensor cell or when the maps change around it, not every tick for every pair.

### 11.4 Radar error, jamming, stealth

- **Radar error ("wobble"):** a radar blip's position is offset by a pseudo-random amount that changes slowly (e.g., seeded by `unitId` and `tick // 30`). The **server sends the wobbled position**, never the true one — clients can't cheat it. Order radars have smaller error than Chaos radars.
- **Jamming:** a jammer hides its own team's units inside its radius from enemy radar. It does not affect sight (LOS). Jammers drain power continuously; if power stalls, their radius shrinks.
- **Stealth (low observable):** `radarSignature < 1` reduces the distance at which radar can detect the unit to `radarRange × signature`. Radar emitters are few, so check stealth units against the list of nearby enemy radars directly. Stealth never prevents visual detection.
- **Radar targeting:** weapons with `canTargetRadar = true` (mostly artillery and long-range missiles) can fire at radar blips. They aim at the wobbled position, so they miss more — that's intended.

### 11.5 Missile guidance & electronic warfare

Missiles have a guidance type. Each type has different rules for **locking**, **staying locked**, and **being defeated**:

| Guidance | Can lock when | Jamming | Stealth | Defeated by |
|---|---|---|---|---|
| `IR` (heat-seeking) | Target VISIBLE and within `lockRange` (short) | No effect | No effect | Flares, DIRCM |
| `RADAR` | Target VISIBLE or RADAR contact | Blocks lock outside burn-through range; can break lock mid-flight | Lock range × signature | Chaff, jamming |
| `COMMAND` | Target VISIBLE from launcher | Breaks guidance if launcher's view is jammed | — | Killing the launcher |

**Burn-through:** a jammed target can still be locked by a radar-guided launcher when it is closer than `burnThrough × lockRange` (e.g., 35%). This makes jamming strong at long range and weaker up close, which creates interesting positioning.

**Missile flight checks (cheap, event-based):**

1. **Launch:** lock check per the table. No lock → no launch.
2. **Midcourse:** every ~5 ticks, re-check. Radar missile whose target entered an enemy jam field beyond burn-through → `LOST_LOCK` (flies straight, self-destructs at lifetime).
3. **Terminal:** once, when within `terminalRange`, roll countermeasures (11.6). Success → `DECOYED` event; the missile veers off. Failure → it hits.

### 11.6 Countermeasures

Defined per unit:

```lua
countermeasures = {
	flares = { charges = 4, chance = 0.55 },                   -- vs IR
	chaff  = { charges = 4, chance = 0.50 },                   -- vs RADAR
	dircm  = { chance = 0.70, cooldown = 3.0, powerDrain = 15 }, -- vs IR, no charges
}
```

- **Flares/chaff** use charges, refilled when rearming (costs supply).
- **DIRCM** (Directional Infrared Counter-Measures) has no charges but a cooldown and power drain. It defeats at most one IR missile per cooldown. **A salvo overwhelms it** — that's the counterplay.
- All rolls use the match's seeded PRNG in fixed system order, so replays stay identical.

**Faction flavor**

| | Order | Chaos |
|---|---|---|
| Radar quality | Low error, long range | Higher error |
| Jammers | Short range | Long range, ground + air + naval jammers |
| Stealth | Stealth bomber, stealth fighter (signature 0.2–0.35) | None or minimal |
| Countermeasures | DIRCM on high-value aircraft | Many flares/chaff charges |
| Missile doctrine | Precise, long-range, few | Cheap salvos to saturate defenses |

### 11.7 Structures and units for the info war

| Role | Structure / unit | Notes |
|---|---|---|
| Radar | Radar Tower (T1), Long-Range Radar (T2), mobile radar truck, AWACS aircraft | Power upkeep |
| Jammer | Jammer Tower (T1/T2), mobile jammer, EW aircraft, EW ship | Power upkeep |
| Sonar | Sonar Buoy (T1), Sonar Station (T2), ships with sonar | |
| Short-range AA | IR SAM site, mobile IR SAM, flak | Unaffected by jamming |
| Long-range AA | Radar SAM site, mobile radar SAM, SAM ships | Affected by jamming/stealth |

---

## 12. Domains: Ground, Air, Naval

### 12.1 Ground

- Roles: scout, light tank, MBT, artillery (radar-targetable), MLRS (saturation), mobile IR SAM, mobile radar SAM, mobile radar, mobile jammer, workers.
- Defenses: gun turret, heavy turret, IR SAM site, long-range radar SAM site, artillery emplacement, coastal battery.
- Terrain matters: slopes block wheeled units; heavies are slow on sand (terrain modifiers).

### 12.2 Air

- **Fighters** (`JET`): target `AIR` only. Patrol/intercept orders. Carry limited missiles; return to rearm when empty.
- **Bombers** (`JET`): bomb runs over a target area; stealth bomber for Order.
- **Attack helicopters** (`HELI`): hover and engage ground/naval targets; vulnerable to IR SAMs.
- **ASW helicopter** (`HELI`): drops torpedoes on submerged contacts.
- **Support aircraft:** AWACS (Order), EW jammer aircraft (Chaos).
- **Air workers** (`HELI`): build air structures; fragile.
- **Ammo & rearm:** aircraft have `ammo` (missiles/bombs). Empty → return to the nearest free rearm pad (airfield or carrier). Rearm costs supply + power over time.
- **Landing:** landed aircraft are `landed` state: no LOS bonus, easy targets.

### 12.3 Naval

- **Surface ships** (`SHIP`): corvette (fast, cheap), destroyer (SAM + gun + sonar), cruiser/battleship (T2 heavy), carrier (T2).
- **Submarines** (`SUB`): always submerged in v1. Only detected by sonar (or very close sight). Only `TORPEDO` weapons and ASW can target `SUB`.
- **Carriers:** mobile airfield: N rearm pads, radar, light point defense. Aircraft can be assigned a carrier as home base.
- **Amphibious/hover units** bridge land and sea.
- Naval structures: floating turret, torpedo launcher, sonar buoy, naval SAM platform, tidal generator.

### 12.4 Counter matrix (design target)

| ↓ attacker / target → | Ground | Air (jet) | Air (heli) | Ship | Sub | Structure |
|---|---|---|---|---|---|---|
| Tanks | ●●● | — | ● | ●● | — | ●● |
| Artillery | ●● | — | — | ●● | — | ●●● |
| IR SAM | — | ●● | ●●● | — | — | — |
| Radar SAM | — | ●●● | ●● | — | — | — |
| Fighters | — | ●●● | ●● | — | — | — |
| Bombers | ●● | — | — | ●● | — | ●●● |
| Attack helis | ●●● | — | ● | ●● | — | ●● |
| Destroyers | ● | ●● | ●● | ●● | ●● | ●● |
| Submarines | — | — | — | ●●● | ●● | — |

● weak · ●● good · ●●● strong · — cannot target

---

## 13. Starter Unit Roster

Names are placeholders; roles are what matter for the first playable build.

### 13.1 Command & workers

| Role | Tier | Order | Chaos |
|---|---|---|---|
| Command Vehicle | — | `ord_sovereign` **Sovereign** | `chs_warlord` **Warlord** |
| Ground Worker | T1 | `ord_mason` **Mason** | `chs_scrapper` **Scrapper** |
| Advanced Ground Worker | T2 | `ord_architect` **Architect** | `chs_forgemaster` **Forgemaster** |
| Air Worker | T1 | `ord_skywright` **Skywright** | `chs_vulture` **Vulture** |
| Advanced Air Worker | T2 | `ord_zenith` **Zenith** | `chs_condor` **Condor** |
| Naval Worker | T1 | `ord_tidewright` **Tidewright** | `chs_wrecker` **Wrecker** |
| Advanced Naval Worker | T2 | `ord_harbormaster` **Harbormaster** | `chs_reaver` **Reaver** |

### 13.2 Ground units

| Role | Tier | Order | Chaos |
|---|---|---|---|
| Scout | T1 | **Herald** (wheeled) | **Jackal** (wheeled) |
| Light tank | T1 | **Lancer** | **Ravager** |
| Self-propelled artillery | T1 | **Verdict** | **Hellmouth** |
| Mobile IR SAM | T1 | **Halo** | **Hornet** |
| Mobile radar | T1 | **Oracle** | **Watcher** |
| Main battle tank | T2 | **Paladin** | **Juggernaut** (raises arms to fire) |
| MLRS | T2 | **Judgement** (precise) | **Hydra** (large salvo) |
| Mobile radar SAM | T2 | **Seraph** | **Gorgon** |
| Mobile jammer | T2 | **Veil** (short range) | **Shroud** (long range) |
| Amphibious tank | T2 | **Tideguard** | **Mire** |

### 13.3 Air units

| Role | Tier | Order | Chaos |
|---|---|---|---|
| Fighter | T1 | **Falcon** | **Harpy** |
| Attack helicopter | T1 | **Guardian** | **Wasp** |
| Bomber | T1 | **Absolution** | **Plague** |
| Air superiority fighter | T2 | **Archon** (stealth 0.35, DIRCM) | **Manticore** (heavy missiles, many flares) |
| Strategic bomber | T2 | **Phantom** (stealth 0.2) | **Behemoth** (armored, chaff) |
| ASW helicopter | T2 | **Tidewatch** | **Leech** |
| Support aircraft | T2 | **Archangel** (AWACS radar) | **Banshee** (EW jammer) |

### 13.4 Naval units

| Role | Tier | Order | Chaos |
|---|---|---|---|
| Corvette | T1 | **Sentry** | **Barracuda** |
| Submarine | T1 | **Silence** | **Lamprey** |
| Destroyer (SAM + sonar) | T2 | **Crusader** | **Corsair** |
| Cruiser / battleship | T2 | **Dominion** | **Kraken** |
| Carrier | T2 | **Sanctuary** | **Leviathan** |
| EW ship | T2 | — | **Siren** (naval jammer) |

### 13.5 Structures

| Role | Tier | Order | Chaos | Built by |
|---|---|---|---|---|
| Gun turret | T1 | **Bulwark** | **Spike** | Command, Ground |
| Heavy turret | T2 | **Bastion** | **Maw** | Adv. Ground |
| IR SAM site | T1 | **Vigil** | **Thorn** | Ground, Air |
| Radar SAM site (long range) | T2 | **Aegis** | **Wyvern** | Adv. Ground, Adv. Air |
| Artillery emplacement | T2 | **Edict** | **Cataclysm** | Adv. Ground |
| Radar tower / long-range radar | T1 / T2 | **Watchtower / Beacon** | **Eye / All-Seer** | All workers |
| Jammer tower | T1 / T2 | **Curtain / Veilspire** | **Smog / Blackout** | Ground / Adv. Ground |
| Floating turret | T1 | **Moat** | **Riptide** | Naval |
| Torpedo launcher | T1 | **Undertow** | **Fang** | Naval |
| Coastal battery | T2 | **Rampart** | **Breaker** | Adv. Naval |
| Sonar buoy / station | T1 / T2 | **Ear / Choir** | **Listener / Deepear** | Naval / Adv. Naval |

---

## 14. Animation System

### 14.1 Split responsibility

| | Server | Client |
|---|---|---|
| Owns | Aim angles as numbers, weapon state, "ready to fire" | Visual piece rotations, recoil, effects |
| Runs | Every tick for every armed unit | Only for units in the tactical tier, by LOD |
| Affects gameplay | Yes | **Never** |

The server's aim model (section 10.3) already makes slow turrets and arm-raising cost real time. The client just shows it.

### 14.2 Model rig convention

- Each unit model = an anchored **root part** (`base`) + **MeshParts** for each piece, connected with **Motor6D** joints. No skinned meshes needed.
- Piece names in the model must match `pieces` in the UnitDef: `base`, `turret`, `barrel`, `sleeve`, `armL`, `armR`, `rotor`, `muzzle` (an Attachment).
- Joints rotate through `Motor6D.Transform` only. Never move pieces with physics.
- All parts: `CanCollide`, `CanQuery`, `CanTouch` = false; non-root parts unanchored and welded through the Motor6Ds.

### 14.3 Piece scripts (BAR unit-script style)

Each def points to a script module. The client calls these hooks:

```lua
local Script = {}

function Script.Create(u)              end  -- unit appears in tactical tier
function Script.StartMoving(u)         end  -- treads, rotor spin-up
function Script.StopMoving(u)          end
function Script.AimWeapon(u, w, yaw, pitch) end  -- replicated aim changed
function Script.FireWeapon(u, w)       end  -- FIRE event: recoil, flash
function Script.Killed(u, severity)    end  -- death animation, then wreck

return Script
```

Helpers available on `u` (all animate over time, driven by one client scheduler):

```lua
u:Turn(piece, axis, angle, speed)   -- rotate toward angle at speed (deg/s)
u:Move(piece, axis, offset, speed)
u:WaitForTurn(piece, axis)          -- yields until the turn finishes
u:Sleep(seconds)
u:StartThread(fn)                   -- run fn(u) as a scheduler thread
u:Signal(mask) / u:SetSignalMask(mask)  -- cancel older threads (like BAR)
```

### 14.4 Example: Juggernaut (body + arms aim, restore after delay)

```lua
local SIG_AIM = 1
local RESTORE_DELAY = 3

local function restoreAfterDelay(u)
	u:Sleep(RESTORE_DELAY)
	u:Turn("torso", "y", 0, 60)
	u:Turn("armL", "x", 0, 45)
	u:Turn("armR", "x", 0, 45)
end

function Script.AimWeapon(u, w, yaw, pitch)
	u:Signal(SIG_AIM)          -- kill previous aim/restore threads
	u:SetSignalMask(SIG_AIM)
	u:Turn("torso", "y", yaw, 90)
	u:Turn("armL", "x", -pitch - 70, 120) -- raise arms
	u:Turn("armR", "x", -pitch - 70, 120)
	u:WaitForTurn("torso", "y")
	u:WaitForTurn("armL", "x")
	u:StartThread(restoreAfterDelay)  -- inherits SIG_AIM, so the next aim cancels it
end

function Script.FireWeapon(u, w)
	u:Move("barrelL", "z", -0.6, 40)  -- recoil
	u:Move("barrelL", "z", 0, 6)
end
```

On the server, the Juggernaut's weapon simply has a slow `pitchRate` and a large `minPitch → firing pitch` distance, so raising the arms takes the same time in gameplay.

### 14.5 Scheduler & LOD

- One `RenderStepped` loop advances all active turns/moves and resumes sleeping script threads. No per-unit connections.
- Write `Motor6D.Transform` only when the value changed.
- **LOD by camera distance:**
  - Near: full scripts, recoil, treads, rotors.
  - Mid: turret/arm aim only.
  - Far: no animation; snap pieces to final aim.
  - Strategic zoom: model replaced by icon (section 15.4).

### 14.6 Deaths & wrecks

- Severity low: short shake, then swap to wreck model.
- Severity high: fling 1–3 pieces with a short tween, explosion effect, then wreck.
- Wreck models: darkened, simplified versions; shared generic wrecks per size (`neu_wreck_small/medium/large`) are fine for v1.

---

## 15. Client Rendering, Camera & UI

### 15.1 Client world table

- The client keeps every known unit (both tiers) in a table: def, team, last positions, state, detection level.
- **Models exist only for tactical-tier units.** Strategic-only units live in the table and on the minimap.

### 15.2 Model pool

- Pool per def ID. On `Enter`: take a model from the pool (or clone), set team colors, place it, run `Script.Create`. On `Leave`/death: reset pieces, park it in `ReplicatedStorage` or a hidden folder.
- Move all visible unit roots in one call per frame with `workspace:BulkMoveTo` (root parts carry welded pieces with them).
- Team color: parts tagged `TeamColor` get the team's color when taken from the pool.

### 15.3 Effects & projectiles

- Pool ParticleEmitters and use `:Emit(n)` rather than toggling `Enabled`.
- Hard caps: e.g., 150 active projectiles visuals, 60 explosions, 100 tracers. Over the cap, skip the least important (far away, small).
- Client projectiles are visual only and follow the same math as the server (ballistic arc, homing steer). The `IMPACT` / `DECOYED` event always wins.

### 15.4 Strategic zoom (BAR's icon view)

When the camera is zoomed far out, hide models and draw icons (flat billboards or a screen-space layer). This saves a lot of rendering and makes large battles readable. It also means distant art can be simple.

### 15.5 Camera

- RTS camera: pan (WASD, edge scroll, middle drag), zoom (wheel), limited rotation, clamped to the map.
- Camera area = ground hits of the four screen corners via `Camera:ViewportPointToRay`. Send to the server (rounded to cells) when it changes, at most ~5 times per second.

### 15.6 Input & commands

- Box select (project unit positions to screen), double-click selects all of type on screen, control groups (Ctrl+1–9).
- Right-click **smart command**: enemy → attack, ally → guard, wreck → reclaim, unfinished structure → repair, ground → move.
- Shift queues commands; queued paths draw as lines for selected units.
- Line formation by right-click drag.
- Build placement ghost with grid snapping, validity tint (green/red), shift for multiple, drag for rows.

### 15.7 UI checklist

- Resource bar: stored / storage, +income, −demand, stall warning per resource.
- Build menu: generated from the selected builder's `buildOptions`, grouped by category tabs.
- Command card: fire state, move state, toggles (radar/jammer on-off), stop, patrol, guard.
- Unit panel: health, state, weapons, ammo/charges for aircraft.
- Minimap: terrain image, unit dots by team, radar blips, ghosts, camera outline, alert pings, click to move camera, right-click to command.
- Alerts: "unit under attack," "structure lost," "power stall," with a ping on the minimap.
- Health bars: only for selected or damaged units in view, pooled. Avoid hundreds of BillboardGuis.

### 15.8 Minimap rendering

- Pre-render the terrain once into an image at map load (or ship one per map).
- Units: pooled small `ImageLabel`s updated at the strategic rate (2–4 Hz), or draw pixels into an `EditableImage` if available for your experience and unit counts are high.

### 15.9 Platform

PC first. RTS controls on touch screens need a separate design (tap-select, command buttons); plan it after the core game works.

---

## 16. Game Modes & Match Flow

### 16.1 Teams

- Players belong to **ally teams**. Allies share sight, radar and sonar; can give units and resources; receive economy overflow.
- **Team mode:** 2–4 ally teams of 2–4 players.
- **FFA:** each player is their own ally team, up to 8.

### 16.2 Win conditions (match option)

| Option | Rule |
|---|---|
| **Command Ends** (default) | A player is eliminated when their Command Vehicle dies |
| **Annihilation** | Eliminated when no units or structures remain |
| **Time limit** (optional) | Highest score (unit value destroyed + held deposits) wins |

### 16.3 Match flow

1. **Lobby:** map vote, mode, teams, faction pick. Use reserved servers via TeleportService for matches.
2. **Loading:** def hash check, map data decode, model preload.
3. **Start:** each player gets a Command Vehicle and starting resources (e.g., 1000 supply, 1000 power).
4. **Play.**
5. **End:** results screen (units built/lost, resources, damage dealt), replay save option, return to lobby.

### 16.4 Limits (tune from stress tests)

- Unit cap per player: e.g., 150 (FFA 8) to 300 (1v1), with a global cap around what the server handles.
- Factory queue limit, max command size (200 units).

---

## 17. Debugging & Tooling

Build these **before** adding lots of content.

### 17.1 Replay system

- Log: header (`"FTGR"`, format version, **protocol version**, defs hash, RNG seed, map ID, scenario, players), then entries, each starting with a kind byte:
  - COMMAND `[tick u32][player u8][len u16][payload]`, recorded at the tick the command is applied. Payloads are Schema command records, so a replay plays back only with the protocol version and defs hash it was recorded with.
  - CHECKPOINT `[tick u32][hash u32]`, written every 300 ticks.
- `Sim.runReplay` rebuilds the sim from the header, feeds the commands at their ticks and reports the first checkpoint whose hash differs.
- Because the server simulation is deterministic, replaying the commands reproduces the match exactly. Every bug report should come with a replay.
- Add a desync check: every 300 ticks, log a hash of the simulation state (`Sim.hash`: tick, PRNG state, every unit field in ID order, ID allocator). A replay that produces a different hash means non-determinism crept in (unordered `pairs`, `os.clock` in logic, unseeded random).

### 17.2 Headless simulation tests

- The simulation runs without any Instances, so you can run 1,000 ticks in a test script and assert results ("tank reaches goal in < N ticks," "SAM kills fighter," "stall ratio correct").
- Pack/unpack round-trip tests for every packet type with random values at field extremes.

### 17.3 Debug overlays (client, toggle with a key)

- Grid cells, passability per move class, clearance values.
- Quadtree leaves, coarse route, corridor, flow field arrows.
- Sensor maps (LOS, radar, jam) per team, as colored tiles.
- Unit labels: ID, state, target, weapon state, detection level.
- Projectile paths and lock lines (green locked, yellow midcourse, red lost lock).

### 17.4 Packet inspector

Debug flag that decodes every incoming/outgoing packet into readable text and logs bytes per channel per second.

### 17.5 Stress test harness

- Spawn N units per team with scripted attack-move orders on a test map.
- Log per-system tick time (`os.clock`) and wrap systems in `debug.profilebegin/profileend` for the MicroProfiler.
- Increase N until the tick time breaks budget. Record the number. **Test on a live server**, not just Studio.

---

## 18. Performance Budgets

### 18.1 Server tick budget at 15 Hz (66.7 ms)

| System | Budget |
|---|---|
| Commands | 1 ms |
| Economy | 1 ms |
| Sensors | 5 ms |
| Targeting | 8 ms |
| Pathing (main thread part) | 8 ms |
| Movement + avoidance | 10 ms |
| Weapons | 5 ms |
| Projectiles + damage | 8 ms |
| Construction + lifecycle | 2 ms |
| NetOut | 6 ms |
| **Headroom** | **~12 ms** |

If a system goes over budget repeatedly: stagger more, lower its rate, move work to Actors, or lower unit caps.

### 18.2 Client frame budget (60 FPS = 16.7 ms)

| Work | Budget |
|---|---|
| Decode + interpolation | 1.5 ms |
| BulkMoveTo + animation | 3 ms |
| Effects | 2 ms |
| UI + minimap | 2 ms |
| Rest (Roblox rendering) | remainder |

### 18.3 Rules that keep it fast

- Idle units: no movement update, no packets, rare targeting.
- No `Instance` work on the server for units.
- No per-unit connections or per-unit loops on the client; one loop per system.
- Reuse tables and buffers; avoid creating garbage every tick.
- Prefer buffers and numeric IDs over strings in hot paths.

---

## 19. Security & Anti-Exploit

- **Never trust the client.** It only sends intentions; the server checks everything.
- Command validation: units exist, are alive and owned by the sender (or shared), the command fits the unit (a non-builder can't build), targets are valid, build sites are legal, IDs are in range.
- Rate limits: e.g., 30 commands per second, 200 units per command, camera updates ≤ 5 per second. Kick on repeated abuse.
- Decode defensively: check buffer length before every read; wrap decoding in `pcall`; drop malformed packets.
- Fog of war is server-side: clients never receive hidden enemies, true radar positions or enemy economy.
- Don't put gameplay secrets (hidden stats, AI logic) in client-readable modules if they would give an advantage.

---

## 20. Art Pipeline (Free Modeling Workflow)

Modeling is the slowest part, so design the pipeline to need as little of it as possible.

### 20.1 Pick a cheap, readable style

- **Low-poly, flat-shaded "tabletop military"** look. Readable from a high camera, fast to make, ages well.
- **One palette texture** (a small image of color swatches) for all units; UV faces onto swatches. One material, no texture painting.
- **Team color panels** as separate parts tagged `TeamColor`.
- **Silhouette first:** each role must be recognizable as a black shape from the game camera.
- Budgets: units 300–1,500 triangles, structures ≤ 3,000, wrecks ≤ 500.

### 20.2 Stage 1 — Blockout (zero modeling)

Add an optional `blockout` table to UnitDefs (boxes, wedges, cylinders with sizes and piece names) and generate placeholder models from Roblox Parts automatically. The whole game becomes playable before any real art exists, and piece names are already correct for animation.

### 20.3 Stage 2 — Modular kit in Blender (free)

- Make a **kit of 30–40 parts**: hulls (3 sizes), tracks, wheels, turrets (4 types), barrels, missile pods, radar dishes, jammer arrays, wings, tails, rotors, ship hulls, deck pieces, structure bases.
- Assemble each unit from kit parts, then add 1–2 unique pieces. T2 versions = T1 + extra kit parts.
- Keep each animated piece as its own object named after its piece (`turret`, `barrel`, `armL`).
- Export, import with Studio's 3D Importer as MeshParts, rig with Motor6Ds. Script the rigging: a Studio plugin that creates Motor6Ds from piece names saves hours.
- Make Order and Chaos kits different (clean slopes vs heavy blocks) so the factions read apart even at low detail.

### 20.4 Free asset libraries (check every asset's license)

- **Kenney**, **Quaternius** and **KayKit** publish large CC0 low-poly packs (vehicles, props, environment). Good for props, terrain decoration and kit parts.
- **Poly Haven:** CC0 textures and models (realistic; use for terrain materials or skyboxes).
- **OpenGameArt:** has some CC0 low-poly tanks; licenses vary per upload.
- **Poly Pizza:** mostly CC-BY (requires credit).
- Keep a `CREDITS.md` with every external asset, its source and license.
- Don't copy BAR's models directly; their licenses vary, and your own kit keeps a consistent style anyway.

### 20.5 AI-assisted generation

- **Roblox Cube 3D:** Roblox's mesh generation from text prompts, available in Studio (through the Assistant) and as a Luau API, launched in beta in 2025; there's also an open-source version of the model.
- Best for **static** things: structures, props, rocks, wrecks. Generated meshes come as one piece, so animated units need splitting in Blender (turret, barrel, arms) — often more work than the kit approach.
- External AI generators: check free-tier licenses carefully before using outputs commercially.

### 20.6 Recommended order

1. Blockouts for every unit (game playable).
2. Kit + final models for the units you show in thumbnails and trailers (MBTs, fighters, carriers).
3. Replace the rest gradually; strategic icons cover distant views anyway.

---

## 21. Roadmap & Milestones

Each milestone has **exit criteria**. Don't move on until they're met.

| # | Milestone | Scope | Exit criteria |
|---|---|---|---|
| M0 | Foundations | Runtime utils (Env, Profiler, Log, Prng) + test runner, defs loader + validation, grid, Packer, tick loop, World storage, replay log | Defs validate; packets round-trip; 1,000 headless ticks run (all under `lune run test`) |
| M1 | One tank moves | Map bake (section 5.4), move command → quadtree + flow field → movement → tactical replication → interpolated render; debug overlays | 50 tanks path across a map smoothly; overlays show fields |
| M2 | Combat | Targeting, aim model, hitscan + ballistic weapons, projectiles, damage, death, wrecks | Two groups fight to the end; replay reproduces it exactly |
| M3 | Economy & building | Team accounts, extractors, generators, Command Vehicle, workers, factories, placement, assist, reclaim | A full T1 build order is playable |
| M4 | Sensors & minimap | LOS/radar maps, fog of war, strategic tier, camera interest, minimap, ghosts | Enemies hidden correctly; bandwidth within budget |
| M5 | Stress test & caps | Harness, profiling, Actors for pathing, unit caps chosen | Known unit cap at stable 15 Hz on live servers |
| M6 | Air & naval | Jets, helis, rearm, ships, subs, sonar, torpedoes, carriers | Combined-arms match playable |
| M7 | Info warfare | Jammers, stealth, guidance types, burn-through, countermeasures, radar targeting | SAM vs jammer vs DIRCM scenarios behave as designed |
| M8 | Factions & T2 | Full roster for both factions, T2 tech, balance pass | Both factions win roughly equally in tests |
| M9 | Polish & launch | Real models, effects, audio, UI pass, lobby, matchmaking, tutorial, results screen | Public playtest |

---

## 22. Appendices

### 22.1 Adding a new unit — checklist

1. Create `Defs/Units/<id>.luau` (extend a template) and register it in `Defs/Registry.luau`.
2. Create or reuse WeaponDefs.
3. Add to a builder's or factory's `buildOptions`.
4. Add a `blockout` (or model) with correct piece names.
5. Choose an icon and an animation script.
6. Run validation and tests: `lune run test` must pass (and Studio output must be clean once Studio is available).
7. Add a headless test (`Tests/<Name>.spec.luau`): it can be built, move, and fight its intended counter.
8. Balance pass: cost vs. power compared with units of the same role.

### 22.2 Glossary

| Term | Meaning |
|---|---|
| Ally team | Group of players sharing vision and resources |
| Build power (BP) | Work units per second a builder contributes |
| Burn-through | Distance inside which radar defeats jamming |
| Clearance | Distance from a cell to the nearest blocked cell |
| DIRCM | Directional Infrared Counter-Measures: beams that confuse heat-seeking missiles |
| Flow field | Grid of directions leading every cell toward one goal |
| Ghost | Last known position of an enemy structure |
| Interest management | Choosing what each player receives |
| Stall ratio | Fraction of demand a team can currently afford |
| Strategic / tactical tier | Minimap-level vs. full-detail replication |
| Wobble | Deliberate position error on radar contacts |

### 22.3 Key numbers (starting values — tune in testing)

| Parameter | Value |
|---|---|
| Sim rate | 15 Hz |
| Cell size | 8 studs |
| Sensor cell size | 16 studs |
| Max map | 256 × 256 cells |
| Economy rate | 3 Hz |
| Strategic replication | 2–4 Hz |
| Interpolation delay | 2 ticks |
| Tactical margin enter / leave | 2 / 5 cells |
| Bandwidth target | ≤ 35 KB/s per player peak |
| Burn-through | 35% of lock range |
| Max projectiles | 2,000 |
| Max units per command | 200 |
