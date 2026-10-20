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
  - String requires only (`require("./Foo")`, `require("../Util/Log")`). Cross-tree requires use the `.luaurc` aliases, e.g. `require("@shared/Util/Prng")`. Never `require(script.Parent.X)` or `game:GetService`.
  - No Instances and no Roblox-only globals or libraries (`game`, `workspace`, `script`, `Instance`, `Random`, `Vector3`, `task`, `debug.profilebegin`…), and no `@lune/*` libraries.
  - Runtime-specific behavior lives only in the `Shared/Util` adapters (`Env`, `Profiler`, `Log`). Branch on `Env.isRoblox` / `Env.isLune` there, nowhere else.
  - Randomness comes only from `Shared/Util/Prng` (pure Luau, so both runtimes give bit-identical sequences), never `Random.new` or `math.random`.
- `.lune/` holds Lune-only scripts (test entry, tooling). They may use `@lune/*`.
- `src/client` is Roblox-only and isn't covered by this rule.
- When Studio becomes available, check that Roblox resolves the `.luaurc` aliases before relying on them there.

## Current milestone

M0 — Foundations (defs loader + validation, grid, Packer, tick loop, World storage, replay log). Map bake is in M1.
Exit: defs validate; packets round-trip; 1,000 headless ticks run under `lune run test`.
Update this line when a milestone's exit criteria are met.
