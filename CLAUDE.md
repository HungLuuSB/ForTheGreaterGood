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

Maps, terrain and unit models live in the place file, not in this repo.

## Working rules

- Edit code as `.luau` files under `src/`. Never edit Rojo-managed scripts inside Studio.
- Use the Roblox Studio MCP tools to run tests, playtest, read console output, take screenshots and work on place-only content.
- Every new file starts with `--!strict`.
- Work on one milestone task at a time (guide section 21). For anything touching more than ~3 files, propose a short plan first.
- After a change: run the tests with `require(game.ServerScriptService.Tests.RunAll)()` through `execute_luau` (Edit datamodel), report the result, and suggest a commit message.
- Don't commit or push unless I ask.

## Current milestone

M0 — Foundations (defs loader + validation, grid, Packer, tick loop, World storage, replay log).
Update this line when a milestone's exit criteria are met.
