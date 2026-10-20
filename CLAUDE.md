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

Studio isn't available, so all code and tests run under [Lune](https://lune-org.github.io/docs) (version pinned in `rokit.toml`).

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
  - `lune run bench`: flow field benchmark (results in `docs/PROGRESS.md`).
  - `lune run debug_map`, `lune run debug_flowfield`: debug images in `debug_out/` (gitignored).
- `src/client` is Roblox-only and isn't covered by this rule.
- Roblox doesn't support custom require aliases yet (staff said in January 2026 it's in progress, with no date). Plan: keep the require style above unchanged. When Studio is available, add a darklua build step whose `convert_require` rule rewrites `@shared/...` and relative requires into Instance paths using the Rojo sourcemap (`rojo sourcemap -o sourcemap.json`). Rojo then serves darklua's output instead of `src/`.

## Current milestone

M1 — One tank moves. Simulation side done in Lune (passability, quadtree + flow fields, movement and avoidance). Still open, all needing Studio: map bake, tactical replication, interpolated rendering, debug overlays.
M2 (Combat) core and M3 (Economy & construction) are implemented headless ahead of M1's Studio work: targeting, aim model, weapons, projectiles, damage, wrecks; team economy with stall ratios, extractors and generators, construction with assist, factories with queues, reclaim, and a scripted T1 build order. See `docs/PROGRESS.md`.
M0 (Foundations) exit criteria met on 2026-10-20: defs validate, packets round-trip, and 1,000 headless ticks run deterministically and replay exactly.
Update this line when a milestone's exit criteria are met.
