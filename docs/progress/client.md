# Client progress

Progress of the client stream: `src/client`, `src/shared/Defs/Blockouts/`, Studio-only place content and `docs/contracts/`. Branch `m-client-foundation`, worktree `FTGG-client`. This stream is the only one using the Studio connection. The headless simulation (`src/server`, the rest of `src/shared`, `.lune/`) is the sim stream's area; see [`sim.md`](sim.md).

Decisions: `C-1`, `C-2`, ... in [`../decisions/client.md`](../decisions/client.md).

## Merge queue

- Ready to merge: `a2371cd` (CLAUDE.md: Studio is available to the client session only; the sim stays headless and is tested with `lune run test`).

## Tasks

1. Studio sync (`STUDIO_HANDOFF.md` step 1) and an in-Studio test entry for `RunAll`. In progress.
2. Contracts: `docs/contracts/rig.md`, `docs/contracts/client-state.md`.
3. Blockout generator (guide 20.2), `ord_lancer` and `chs_ravager` first.
4. Client foundation (guide 15): world table from NetIn, interpolation, model pool, RTS camera.

## Requests for the sim session

(None yet.)
