---
name: ftgg-roblox-dev
description: Use when building, debugging, testing or extending the "For The Greater Good" RTS in Roblox Studio, especially through the Roblox Studio MCP tools — adding units/weapons, writing sim systems, networking, playtests and stress tests.
---

# For The Greater Good — Roblox Studio Development

This skill guides work on **For The Greater Good**, a BAR-style modern-warfare RTS on Roblox (factions: Order / Chaos; domains: ground, air, naval). It covers the project's non-negotiable architecture rules, a safe workflow for the Roblox Studio MCP tools, and recipes for common tasks.

If the design guide (`For_The_Greater_Good_Design_Guide.md`) is available in the project or conversation, it is the **source of truth**. Read the relevant section before designing anything new, and point out (don't silently ignore) any request that conflicts with it.

---

## 1. Architecture rules (never break these)

1. **Server-authoritative simulation.** Clients send commands; the server simulates; clients render. Never let client code decide damage, hits, economy or visibility.
2. **The simulation is pure data.** No Instances, Parts, Humanoids, physics or `workspace:Raycast` for units on the server. Units live in struct-of-arrays tables in `World.luau`, keyed by `u16` unit IDs.
3. **Deterministic on the server.** Fixed tick (15 Hz), fixed system order, the seeded `@shared/Util/Prng` module only.
   - Never use `math.random`, `Random.new`, `os.clock()`, `tick()` or `time()` in gameplay logic. For profiling timings use `Profiler.now()`.
   - Never let `pairs()` iteration order affect outcomes — iterate arrays of IDs.
   - No `task.wait`/yielding inside sim systems.
4. **Defs are data.** One ModuleScript per unit/weapon returning a table; shared by server and client; validated at startup. IDs use prefixes `ord_`, `chs_`, `neu_`, are lowercase `snake_case`, and are never renamed once used.
5. **Networking:** payloads are `buffer`s written via `Net/Packer.luau` following `Net/Schema.luau`. Continuous values (position/heading) → UnreliableRemoteEvent; discrete changes → reliable RemoteEvent. Keep unreliable messages under ~900 bytes (split them).
6. **Fog of war is applied before anything is sent.** Camera position changes level of detail only, never what a player can see. Radar contacts are sent with their wobbled position, never the true one.
7. **Animation is visual only.** The server's aim model (yaw/pitch numbers with turn rates) decides when weapons can fire; client piece scripts only display it.
8. **Pay for what changes.** Idle units cost no CPU and no bandwidth. Expensive per-unit work is staggered (`id % N`).

### Key numbers

| Parameter | Value |
|---|---|
| Sim rate | 15 Hz (66.7 ms per tick) |
| Grid cell | 8 studs; max map 256 × 256 cells |
| Sensor cell | 16 studs |
| Position on the wire | cell `u16` + offsetX `u8` + offsetZ `u8` |
| Economy / strategic rate | 3 Hz / 2–4 Hz |
| Bandwidth target | ≤ 35 KB/s per player at peak |

### System order per tick

Commands → Economy (every 5th tick) → Sensors (every 2nd) → Targeting (staggered) → Pathing (time-sliced) → Movement → Weapons → Projectiles → Damage & Lifecycle → Construction → NetOut.

### Where code lives

```
ReplicatedStorage/Shared/   Defs/ (Units, Weapons, MoveClasses, ArmorClasses, Categories, Defs.luau)
                            Net/ (Schema, Packer, Remotes)  Grid/  Util/
ReplicatedStorage/Models/   unit models by def ID
ServerScriptService/Sim/    Main.server.luau, World.luau, Systems/*, Workers/ (Actors), Replay/
ServerScriptService/Tests/  test modules + RunAll
StarterPlayerScripts/Client/ World, NetIn, Interp, Render/*, Camera, Input/*, UI/*, Debug/*
```

If the actual place differs from this layout, follow the place and mention the difference once.

### Rojo mode (default)

Code is synced from the repository into Studio by Rojo:

| Repo folder | Studio location |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server/Sim` | `ServerScriptService.Sim` |
| `src/server/Tests` | `ServerScriptService.Tests` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

- **Edit code as files under `src/`**, never with Studio `multi_edit`; Rojo would overwrite edits made in Studio.
- Use the Studio MCP tools for what lives only in the place file (maps, terrain, models, `ReplicatedStorage.Models`) and for running code, inspecting instances, playtesting and reading console output.
- File naming: `Name.server.luau` = Script, `Name.client.luau` = LocalScript, `Name.luau` = ModuleScript, a folder with `init.luau` = ModuleScript with children.
- Before testing in Studio, confirm Rojo is syncing (the changed module exists in Studio with the new content). If it isn't, ask the user to run `lune run serve` and `rojo serve serve.project.json` in two terminals (the converted tree in `build/serve/`; `default.project.json` serves unconverted string requires that Roblox can't resolve), then connect the Studio plugin. `lune run build` builds and checks a place file offline in `build/ci/` and is safe alongside. Never wipe `build/serve/` while the sync runs: Rojo's serve crashes.
- After each working, verified step, suggest a git commit with a clear message.

---

## 2. Studio MCP workflow

### Before touching anything

1. Call `list_roblox_studios` and pick the right `studio_id`. If several instances are open and it's unclear which one, ask.
2. Call `get_studio_state`. **Never edit scripts while a playtest is running** — stop it first or wait.
3. Find the code before changing it: `search_game_tree`, `script_search` (max 10 results), `script_grep` (max 50 results), then `script_read` the whole script you will edit.

### Making changes

- Rojo-managed code: edit the files under `src/` (see Rojo mode). Only scripts that are **not** managed by Rojo get edited in Studio with `multi_edit` (`datamodel_type = "Edit"`).
- Keep each edit focused; don't rewrite whole scripts when a targeted change works.
- Start new scripts with `--!strict` and type annotations.
- After edits, re-read the changed region to confirm it applied as intended.

### Ask before

- Deleting instances or scripts, or renaming anything other scripts reference.
- Edits touching more than ~5 scripts at once, or changing `Schema.luau` / packet formats (they break replays and clients).
- Inserting Toolbox assets (`insert_asset`) — confirm the asset and its license first.
- Generating meshes/materials that will replace existing art.

Suggest the user saves or commits (Rojo + git) before large changes.

### Verifying

- **Logic:** from the project root run `lune run test` (`lune run test <filter>` for matching specs only) and report pass/fail. It runs every `*.spec.luau` under `src/server/Tests` through `Tests/RunAll`. In Studio (client session only), `execute_luau` (Edit) runs `require(game.ServerScriptService.Entry.RunTests).start(filter?)`, then polls `.status()` until it returns the summary (`specs`, `passed`, `failed`, `failures`); the per-test lines go to the Output.
- **Runtime:** `start_stop_play` → `get_console_output` → `screen_capture` if visual → `start_stop_play` to stop.
- Read errors from console output before guessing at fixes. Fix the cause, then re-run the same check.

---

## 3. Task recipes

### Add a new unit

1. Pick role, faction, tier, domain, move class. ID = `ord_<name>` or `chs_<name>`; display name follows the faction style (Order: Latin/virtue/heraldic; Chaos: myth beasts/ruin).
2. Create `Defs/Units/<id>.luau` by extending a template (`local Templates = require("../Templates")`, then `Templates.extend(Templates.X, {...})`) and register it in `Defs/Registry.luau`.
3. Create or reuse WeaponDefs; fill every armor class in `damage`.
4. Add the ID to the right factory's or builder's `buildOptions`.
5. Model: if no art yet, add a `blockout` table so the placeholder generator builds it. Piece names must match `pieces` and the animation script.
6. Pick an icon and an animation script.
7. Run def validation and the test suite; add a test that the unit can be built, moves, and fights its intended counter.

### Add a weapon

Set `type` (HITSCAN / BALLISTIC / HOMING / BEAM / TORPEDO / BOMB), range, reload, damage per armor class, `targets` categories, turret rates. Missiles also need `guidance` (IR / RADAR / COMMAND), `lockRange`, `terminalRange`. Check how it replicates: hitscan/beam → `FIRE` event only; projectiles → `SPAWN_PROJ` once + `IMPACT`/`DECOYED`.

### Add or change a packet field

1. Update `Schema.luau` (field, width, which channel).
2. Update writer (server NetOut) and reader (client NetIn) together.
3. Add/extend the pack→unpack round-trip test with edge values (0, max, negative where signed).
4. Recalculate bytes per record and the bandwidth impact; state it in the summary.

### Write or modify a sim system

- Pure functions over `World` data; no Instances, no yields.
- Wrap the system in `Profiler.begin("Sim.<System>")` / `Profiler.finish()` (`@shared/Util/Profiler`; MicroProfiler labels in Roblox, no-ops in Lune).
- Respect its time budget (Targeting 8 ms, Movement 10 ms, Pathing 8 ms, Sensors 5 ms, NetOut 6 ms…). Use staggering or time-slicing rather than doing all units every tick.
- Any field that replicates must set its `dirty` bit when written.
- Reuse tables and buffers; don't allocate per unit per tick.

### Debug a problem

1. Reproduce it: ideally from a replay (command log + seed); otherwise a minimal test scenario via `execute_luau`.
2. Inspect state: use `execute_luau` (`Server` datamodel during playtest) to print the relevant `World` fields for the unit IDs involved.
3. Check console output and the debug overlays (pathing, sensors, lock lines).
4. Fix, then add a test that would have caught it.

### Stress test

1. Start a playtest (`start_stop_play`).
2. Via `execute_luau` (`Server`), call the harness to spawn N units per team with attack-move orders.
3. After ~30 seconds, read `get_console_output` for per-system tick timings and bandwidth logs.
4. Stop the playtest. Report: N, average/peak tick time per system, which system broke budget first.
5. Remind the user that final numbers must come from a **live server**, not Studio.

---

## 4. Luau conventions

- `--!strict` at the top; export types for shared structures (`UnitDef`, `WeaponDef`, packet records).
- ModuleScripts return a table; no globals; `local` everything.
- PascalCase for modules and types, camelCase for locals and functions, UPPER_SNAKE for constants.
- Cache hot globals as locals in hot paths (`local band = bit32.band`, `local readu16 = buffer.readu16`).
- Short comments explaining *why*, not *what*.
- Never leave `print` spam in sim systems; use a debug flag.

---

## 5. Reporting back

After each task, give a short summary:

- **Changed:** which scripts/defs were created or edited (paths in the Explorer).
- **Verified:** what was run (tests, playtest) and the result.
- **Impact:** any effect on tick budget, bandwidth or packet formats.
- **Next:** one natural next step, if there is one.

If something couldn't be verified (playtest tools disabled, Studio not connected), say so plainly instead of claiming success.

---

## 6. Gotchas

- Every MCP tool call needs the right `studio_id`.
- `execute_luau` and `multi_edit` need a `datamodel_type` (Edit, Client or Server).
- Playtest tools can be switched off in the Assistant settings; if they're unavailable, ask the user to enable them.
- `script_search` caps at 10 results and `script_grep` at 50 — narrow the query rather than assuming nothing else exists.
- Changes made in the `Server`/`Client` datamodel during a playtest are lost when it stops; permanent edits go to `Edit`.
