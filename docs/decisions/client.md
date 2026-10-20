# Client decisions (C-)

Decisions of the client stream: `src/client`, `src/shared/Defs/Blockouts/`, Studio-only place content and `docs/contracts/`. Progress is in [`../progress/client.md`](../progress/client.md). Earlier decisions (D1–D109, both areas before the split) are in [`../DECISIONS.md`](../DECISIONS.md).

Each entry gives the date, the decision, the alternatives and the reason. Overrule any of them and the code, the guide and this file are updated together.

## Summary

| ID | Decision |
|---|---|
| C-1 | Roblox-only server code lives in `src/roblox`, synced to `ServerScriptService.Entry` |
| C-2 | The in-Studio test entry is a ModuleScript run through `execute_luau`, in the background, yielding once per test |
| C-3 | Live sync and offline build use separate folders (`build/serve`, `build/ci`); `lune run serve` replaces the darklua and sourcemap watchers |
| C-4 | Models face −Z; a unit's world rotation is `heading + π` about Y; turret yaw and barrel pitch are plain joint rotations |
| C-5 | UI reads one client state table and calls one actions table (`docs/contracts/client-state.md`) |
| C-6 | Blockouts are separate modules in `Defs/Blockouts/`, parts in model space, pieces jointed, decorations welded |
| C-7 | Client specs live in `tests/client/` and run with `lune run test_client`; client logic that can be pure is kept pure |
| C-8 | Units without a hand-made blockout get a generic one from their def (footprint, domain, pieces) |

---

### C-1 — `src/roblox` for Roblox-only server code (2026-10-21)

**Decision:** a new root `src/roblox`, mapped to `ServerScriptService.Entry` in both project files, holds server scripts that only run in Roblox (the test entry now; the server tick loop and remotes later, `STUDIO_HANDOFF` step 3). Like `src/client`, it's exempt from the dual-runtime rule and may use `game`, `task` and Instances.

**Alternatives:** put the entry under `src/server` (breaks the rule that `src/server` runs in Lune, and is the sim stream's area); keep it in the place file only (not versioned, and Rojo can't sync it).

**Why:** the handoff proposed this layout, and it keeps the boundary clear: `src/server` stays pure simulation, Roblox wiring sits next to it. `lune run build` and `check_build` already cover it (no `.lune/` change needed).

### C-2 — Test entry: background ModuleScript, one yield per test (2026-10-21)

**Decision:** `Entry.RunTests` is a ModuleScript. `run(filter?)` collects every `*.spec` ModuleScript under `ServerScriptService.Tests`, sorted by name at each level as in Lune, and passes them to the shared `RunAll`. Each registered test is wrapped to `task.wait()` once before it runs. `start(filter?)` runs it in a spawned thread and returns at once; `status()` returns `"running"` or the summary.

**Alternatives:** an auto-running `RunTests.server.luau` behind an attribute (the handoff's plan: it only runs on play, and the result can't be read back from MCP); calling `run()` directly from `execute_luau` (tried: the suite takes ~32 s in Studio, the call gave up with "Target is not reachable" while the run finished in the background); adding a yield hook to `RunAll` (it's in `src/server`, the sim stream's area).

**Why:** `RunAll` never yields, and one 30 s unyielding call freezes Studio and drops the MCP connection. The wrapper yields from inside `RunAll`'s `pcall`, which Luau allows, without changing `RunAll` or any spec. Module state survives between `execute_luau` calls, so `status()` can be polled.

### C-3 — Separate serve and CI folders; `lune run serve` (2026-10-21)

**Decision:** the live sync and the offline build never share an output folder. `lune run serve` (`.lune/serve.luau`) keeps `build/serve/src` converted for `rojo serve serve.project.json`; `lune run build` wipes and rebuilds only `build/ci/` (`build.project.json`). The serve script polls `src` every 0.25 s by modified time, converts a changed file with darklua on its own, and on an added or removed file regenerates `sourcemap.json` and converts everything. It only writes files and removes the output file of a deleted source (after 3 polls missing, so a save by rename isn't a delete); it never deletes a directory. Nothing may wipe `build/serve` while the sync runs (CLAUDE.md).

**Alternatives:** keep `darklua process --watch` into its own folder (it still deleted outputs on saves by rename and never wrote them back, and its behaviour on removed directories isn't ours to control); keep one folder and stop the sync before each build (easy to forget, and that is how Rojo crashed).

**Why:** Rojo's serve crashes (`change_processor.rs`, "The system cannot find the path specified") when a directory it watches disappears, which is what `lune run build`'s wipe of `build/src` did. Owning the watcher also folds the sourcemap watcher in: two terminals instead of three. `sourcemap.json` is still shared by both; both write the same content from the same sources.

### C-4 — Model axes (2026-10-21)

**Decision:** unit models face −Z (Roblox `LookVector`, what Studio's importer and most kits use). The sim's heading points along `(sin h, cos h)`, which is a rotation of +Z by `h` about +Y, so a unit is placed with `CFrame.Angles(0, h + π, 0)`. Turret yaw (relative to the hull, same sense) is `Motor6D.Transform = CFrame.Angles(0, yaw, 0)`; barrel pitch (up positive) is `CFrame.Angles(pitch, 0, 0)`, which raises a −Z barrel. Details in `docs/contracts/rig.md`.

**Alternatives:** models facing +Z (no `+ π`, but against Roblox convention and imported art); changing the sim's heading convention (sim area, and it would break replays).

**Why:** one fixed offset in one place (the client's unit placement) instead of fighting every imported model.

### C-5 — UI contract: state + actions (2026-10-21)

**Decision:** a future UI session reads `Client.state` (units, selection, groups, camera, hover, placement, economy, alerts), listens to `Client.changed` signals and calls `Client.actions`. The UI never sends remotes or edits state. Draft in `docs/contracts/client-state.md`.

**Alternatives:** UI reading the client modules directly (couples the UI to internals that change every task); a full reactive store (overkill before there is any UI).

**Why:** lets UI work start in parallel with a stable surface; placeholder fields (economy) are marked until the sim sends them.

### C-6 — Blockout format (2026-10-21)

**Decision:** one module per unit in `src/shared/Defs/Blockouts/<id>.luau`, separate from the unit def (the guide's 20.2 suggests a `blockout` table in the def; unit defs are the sim stream's files and feed the defs hash, and a model change must not change the hash). Parts are listed in model space (`at`, optional `pivot`, `rot`) with a `parent`; def pieces get `Motor6D`s, other parts are decorations welded with `WeldConstraint`s; attachments (`muzzle`) are listed separately. Colors are palette keys, the faction picks the palette. Format in `docs/contracts/rig.md` section 4.

**Alternatives:** a `blockout` table inside each unit def (guide 20.2 as written); parts relative to their parent piece (harder to read and edit by hand).

**Why:** ownership and hash stability, and model-space numbers can be checked against each other at a glance.

### C-7 — Client tests in Lune (2026-10-21)

**Decision:** client-stream specs live in `tests/client/*.spec.luau` and run with `lune run test_client [filter]` (new `.lune/test_client.luau`, same `RunAll` and output as `lune run test`). Client code that doesn't need Instances (blockout data, packet decoding into the client world, interpolation, selection math, command building, effect caps) is written without Roblox globals so these specs can cover it, including against the real `Sim` and `NetOut`.

**Alternatives:** specs in `src/client/Tests` (they would sync into every player's PlayerScripts); adding `tests/client` to `lune run test` (that's `.lune/test.luau`, the sim stream's entry; can be merged later on request).

**Why:** most client bugs are logic bugs; Studio playtests are slow and can't run unattended when Studio isn't rendering.

### C-8 — Generic blockouts for every unit (2026-10-21)

**Decision:** `Blockout.forDef(def)` returns the hand-made blockout if registered, else `Blockout.generic(def)`: a hull sized by footprint and shaped by domain (tracks for ground, wings and tail for air, a bow for naval, a block for structures) with every def piece in place and muzzles at the front of their weapon's piece. A spec checks that all 123 defs get a valid one.

**Alternatives:** an error or an invisible unit for defs without a blockout; hand-making all 123 now.

**Why:** the whole roster can appear in playtests from day one, with correct piece names, while hand-made blockouts replace generic ones unit by unit.
