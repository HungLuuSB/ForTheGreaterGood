# For The Greater Good — instructions for Claude

BAR-style modern-warfare RTS on Roblox. Factions: Order / Chaos. Domains: ground, air, naval.

## Source of truth

- `docs/For_The_Greater_Good_Design_Guide.md` — read the relevant section before designing or implementing a system. If a request conflicts with it, say so. When we change a decision, update the guide in the same change.
- Skill `ftgg-roblox-dev` — architecture rules, Studio MCP workflow, task recipes. Follow it.

## Repo layout (synced into Studio by Rojo)

| Folder | Studio location |
|---|---|
| `src/shared` | ReplicatedStorage.Shared |
| `src/server/Sim` | ServerScriptService.Sim |
| `src/server/Tests` | ServerScriptService.Tests |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client |
| `src/roblox` | ServerScriptService.Entry (Roblox-only server scripts, e.g. the in-Studio test entry `RunTests`) |
| `docs/` | design documents (not synced) |
| `.lune/` | Lune scripts: test entry, tooling (not synced) |
| `.luaurc` | require aliases (`@shared`) for Lune and tooling (not synced) |

Maps, terrain and unit models live in the place file, not in this repo.

## Working rules

- Edit code as `.luau` files under `src/`. Never edit Rojo-managed scripts inside Studio.
- When Studio is available: use the Roblox Studio MCP tools to playtest, read console output, take screenshots and work on place-only content.
- Every new file starts with `--!strict`.
- Work on one milestone task at a time (guide section 21). For anything touching more than ~3 files, propose a short plan first.
- After a change: run the tests (`lune run test` while in Lune mode), report the result, and suggest a commit message.
- Don't commit or push unless I ask.

## Lune mode (current)

Studio is now available to the client session only (`src/client`, `src/shared/Defs/Blockouts/`, place content), through the Roblox Studio MCP tools. The simulation stays headless: its code and tests run under [Lune](https://lune-org.github.io/docs) (version pinned in `rokit.toml`) and are still tested with `lune run test`.

- Run the tests from the project root with `lune run test` (entry: `.lune/test.luau`). It runs every `*.spec.luau` under `src/server/Tests`. `lune run test <filter>` runs only the specs whose path contains `<filter>`.
- All code in `src/shared` and `src/server` must run in **both** Lune and Roblox:
  - String requires in exactly two forms, never mixed with anything else:
    - **Across roots** (e.g. `src/server` → `src/shared`): always the alias, `require("@shared/Util/Prng")`.
    - **Within a root:** relative paths, `require("./Env")`, `require("../Defs")`.
    - Nothing else: no `require(script.Parent.X)`, no `game:GetService`, no other aliases, no relative path that climbs out of its root.
  - No Instances and no Roblox-only globals or libraries (`game`, `workspace`, `script`, `Instance`, `Random`, `Vector3`, `task`, `debug.profilebegin`…), and no `@lune/*` libraries.
  - Runtime-specific behavior lives only in the `Shared/Util` adapters (`Env`, `Profiler`, `Log`). Branch on `Env.isRoblox` / `Env.isLune` there, nowhere else.
  - Randomness comes only from `Shared/Util/Prng` (pure Luau, so both runtimes give bit-identical sequences), never `Random.new` or `math.random`.
- `.lune/` holds Lune-only scripts (test entry, tooling). They may use `@lune/*`.
  - `lune run test_client [filter]`: the client stream's Lune specs in `tests/client/` (pure client logic and blockout data; C-7).
  - `lune run render_scene <dump> <png>`: top-down PNG of a client scene dump (`ReplicatedStorage.FtggClientDebug:Invoke("scene")` in a Studio playtest; C-10).
  - `lune run bench`: flow field benchmark (results in `docs/progress/sim.md`).
  - `lune run debug_map`, `lune run debug_flowfield`: debug images in `debug_out/` (gitignored).
  - `lune run stress`: stress test and bandwidth report (results in `docs/progress/sim.md`).
  - `lune run balance [seeds] [filter]`: equal-value matchup report, written to `docs/BALANCE.md` (report only).
  - `lune run export <scene> [--player N]`: record a match for the viewer (`tools/viewer/index.html`) into `debug_out/`.
  - `lune run build`: offline Roblox build and check, in `build/ci/` (see below). `lune run check_build [place]` re-checks a built place.
  - `lune run serve`: live sync to Studio, into `build/serve/` (see below).
- `src/client` and `src/roblox` are Roblox-only and aren't covered by this rule.
- In Studio, run the same specs with `require(game.ServerScriptService.Entry.RunTests).run(filter?)`. Through `execute_luau` use `.start(filter?)`, then poll `.status()` with plain calls until it returns the summary (the full suite takes ~30 s; an `execute_luau` call gives up well before 20 s, even when it yields, so don't wait inside the call). A poll can fail with "Target is not reachable" while Studio is inside one long test; just poll again.
- Roblox doesn't support custom require aliases yet (staff said in January 2026 it's in progress, with no date). So the source keeps the require style above, and a build step converts it (DECISIONS D84):
  - `lune run build`:
    1. `rojo sourcemap default.project.json -o sourcemap.json`;
    2. `darklua process src build/ci/src`. `.darklua.json`'s `convert_require` rule turns `@shared/...` and relative requires into `game:GetService(...)` / `script.Parent` paths with `FindFirstChild`;
    3. `rojo build build.project.json -o build/ci/place.rbxl`;
    4. `lune run check_build` loads the place with `@lune/roblox` and checks that every script compiles and every require resolves to a ModuleScript.
    It wipes and rebuilds only `build/ci/`, so it's safe while the live sync runs.
  - Tools are pinned in `rokit.toml` (darklua 0.19.0). `build/` and `sourcemap.json` are gitignored.
  - Live sync to Studio, two terminals in the project root: `lune run serve`, then `rojo serve serve.project.json`; then connect the Rojo plugin. Never serve `default.project.json` (unconverted requires) or `build.project.json` (the CI tree, rebuilt from scratch).
    - `.lune/serve.luau` replaces `darklua --watch` and `rojo sourcemap --watch`: it polls `src`, converts each changed file with darklua (files saved by rename included), regenerates `sourcemap.json` and converts everything when a file is added or removed, and removes only the output file of a deleted source. It never deletes a directory.
    - **Never run anything that wipes or rebuilds `build/serve/` while the sync is running** (no `rm -r build`, no `darklua process` into it, no switching `lune run build` back to it). Rojo's serve crashes when a directory it watches disappears (`change_processor.rs`, "The system cannot find the path specified"). Stop both terminals first.
  - `default.project.json` stays the source tree for the sourcemap and tooling.

## Current milestone

M1 — One tank moves. Simulation side done in Lune (passability, quadtree + flow fields, movement and avoidance). Still open, all needing Studio: map bake, tactical replication, interpolated rendering, debug overlays.
M2 (Combat) core and M3 (Economy & construction) are implemented headless ahead of M1's Studio work: targeting, aim model, weapons, projectiles, damage, wrecks; team economy with stall ratios, extractors and generators, construction with assist, factories with queues, reclaim, and a scripted T1 build order.
M4 (sensors, fog, ghosts, NetOut interest management), the M5 stress harness, M6 (air, naval) and M7 (guidance, jamming, burn-through, countermeasures) are implemented headless too. So are match rules (FFA / Team, Command Ends / Annihilation, unit caps), the full placeholder roster and tech tree, a balance report and a skirmish AI (M8 groundwork). Their remaining exit criteria need Studio (minimap, live caps, playable matches). See `docs/progress/` (one file per work stream: `sim.md` for the headless simulation) and the ordered Studio checklist in `docs/STUDIO_HANDOFF.md`.
M0 (Foundations) exit criteria met on 2026-10-20: defs validate, packets round-trip, and 1,000 headless ticks run deterministically and replay exactly.
Update this line when a milestone's exit criteria are met.
