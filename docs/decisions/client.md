# Client decisions (C-)

Decisions of the client stream: `src/client`, `src/shared/Defs/Blockouts/`, Studio-only place content and `docs/contracts/`. Progress is in [`../progress/client.md`](../progress/client.md). Earlier decisions (D1–D109, both areas before the split) are in [`../DECISIONS.md`](../DECISIONS.md).

Each entry gives the date, the decision, the alternatives and the reason. Overrule any of them and the code, the guide and this file are updated together.

## Summary

| ID | Decision |
|---|---|
| C-1 | Roblox-only server code lives in `src/roblox`, synced to `ServerScriptService.Entry` |
| C-2 | The in-Studio test entry is a ModuleScript run through `execute_luau`, in the background, yielding once per test |
| C-3 | Live sync and offline build use separate folders (`build/serve`, `build/ci`); `lune run serve` replaces the darklua and sourcemap watchers |

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
