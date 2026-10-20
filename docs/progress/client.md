# Client progress

Progress of the client stream: `src/client`, `src/shared/Defs/Blockouts/`, Studio-only place content and `docs/contracts/`. Branch `m-client-foundation`, worktree `FTGG-client`. This stream is the only one using the Studio connection. The headless simulation (`src/server`, the rest of `src/shared`, `.lune/`) is the sim stream's area; see [`sim.md`](sim.md).

Decisions: `C-1`, `C-2`, ... in [`../decisions/client.md`](../decisions/client.md).

## Merge queue

- Ready to merge: `a2371cd` (CLAUDE.md: Studio is available to the client session only; the sim stays headless and is tested with `lune run test`).
- Ready to merge: `f815a5d` (task 1: Rojo live sync and the in-Studio test entry; touches `CLAUDE.md`, both project files and the skill).

## Tasks

1. Studio sync (`STUDIO_HANDOFF.md` step 1) and an in-Studio test entry for `RunAll`. **Done 2026-10-21**, see below.
2. Contracts: `docs/contracts/rig.md`, `docs/contracts/client-state.md`.
3. Blockout generator (guide 20.2), `ord_lancer` and `chs_ravager` first.
4. Client foundation (guide 15): world table from NetIn, interpolation, model pool, RTS camera.

## Task 1: Studio sync and in-Studio tests

- **Sync:** `lune run build` once, then three watchers in the repo root: `rojo sourcemap default.project.json -o sourcemap.json --watch`, `darklua process src build/src --watch`, `rojo serve build.project.json`; connect the Rojo plugin. Studio has 263 scripts (178 Shared, 43 Sim, 41 Tests, 1 Entry), the same as the offline build. No string requires left (two in comments).
- **Test entry:** `src/roblox/RunTests.luau` → `ServerScriptService.Entry.RunTests` (C-1, C-2). From `execute_luau` (Edit): `.start(filter?)`, then poll `.status()`.
- **Result in Studio:** 34 specs, 253 passed, 0 failed (31.8 s and 33.2 s; Lune 17.6 s). No warnings from our code in Output (the Defs loader is quiet).
- **Gotcha:** darklua's watcher deletes the output when a source file is replaced by rename (Claude's Edit/Write tools do this) and doesn't write it back. Fix: rewrite the file in place or restart the watcher (CLAUDE.md).
- **Not done (handoff step 2, left for later):** the cross-runtime hash check (D51), Script Analysis pass, and the `wait_for_child` question for client requires.

## Requests for the sim session

(None yet.)
