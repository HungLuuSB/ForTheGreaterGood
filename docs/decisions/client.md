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
| C-9 | Minimal Roblox server entry in `src/roblox`; identity and map ID as attributes until the protocol 6 handshake |
| C-10 | Playtest proof: Studio-only debug bindables and a top-down render from live instance data |
| C-11 | Order lines mirror the server's line-slot layout and greedy assignment (display only) |
| C-12 | The client joins with protocol 6's HELLO / WELCOME; C-9's attributes are gone |
| C-13 | Default controls: box / click / double-click select, smart right-click, right-drag line, Shift queue, Ctrl+1..9 groups, X stop |
| C-14 | The build ghost runs the server's placement rules on the client's knowledge, cell by cell in the server's order |
| C-15 | When Studio isn't available, `lune run client_demo` renders the real client's view headless (labelled as such) |
| C-16 | Effects play on the render clock; every projectile is followed, caps apply to what is drawn, by size over distance |

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

### C-9 — Minimal server entry until the join handshake (2026-10-21; the attributes part superseded by C-12)

**Decision:** `src/roblox/Main.server.luau` hosts one fixed match from `src/roblox/MatchConfig.luau` (seed, map, scenario, players, human slots). It steps the real `Sim` at 15 Hz from a Heartbeat accumulator (at most 3 steps per frame), fires each human player's outbox in net.md's channel order (one `RemoteEvent` / `UnreliableRemoteEvent` per `Schema.Channel` in `ReplicatedStorage.Remotes`), and passes `Cmd` buffers to `Sim.submit` behind a size cap (2 KB) and a token bucket (20/s, burst 40). Until protocol 6's HELLO / WELCOME, the map ID, protocol version and defs hash are attributes on `Remotes`, and each player's sim ID and team are attributes on the `Player`; the client refuses to start on a protocol or defs mismatch. `Players.CharacterAutoLoads` is set false at runtime (no avatars in an RTS). Placeholder: `demoOrders` sends both sides to the midpoint between them every 10 s, and the match restarts with the next seed 6 s after one side is gone.

**Alternatives:** wait for the sim stream's server entry (STUDIO_HANDOFF step 3 has no owner yet, and task 4 needs a running server); implement the protocol 6 handshake client-side now (its server half is the sim stream's, S-2).

**Why:** the smallest server that drives the real simulation and the real NetOut packets. When WELCOME lands, the attributes go and the client reads the handshake instead.

### C-10 — Playtest proof without Studio screenshots (2026-10-21)

**Decision:** Studio's `screen_capture` returns the 2D GUI but a black 3D view in this setup (Edit and Play). As proof, the playtest client exposes `ReplicatedStorage.FtggClientDebug` (Studio only): `Invoke()` returns counts (units per team and tier, models, render delay, camera), `Invoke("scene")` returns a compact scene (one line per unit model: def, team color, position, heading, turret aim; one per overlay disc or line). `lune run render_scene` rebuilds the units from their blockouts and draws a PNG under `debug_out/screens/`. The server has `ServerStorage.FtggDebug` for sim summaries. Both exist because `execute_luau` doesn't share the scripts' `shared` / `_G`.

**Alternatives:** keep retrying screenshots (they stay black); trust the numbers only.

**Why:** the PNG is drawn from the actual Instances the client created, so it shows piece placement, turret aim and positions as the playtest had them. A real screenshot is still wanted once the 3D view captures again.

### C-11 — Drawn order lines follow the server's slots (2026-10-21)

**Decision:** order queues aren't replicated (net.md 9), so the client draws what it sent (`Core/Waypoints`). For line moves it computes each unit's goal the way the server does (`Nav.slotsFor` and `Nav.assignSlots`): rows of slots spaced `2 x radius x 1.3` along the line, extra rows stepping back toward the group's centroid, deepest row first, each slot taking the closest unassigned unit (ties to the lower ID). The constants are copied from `Nav` until they're shared (request 3). A point counts as reached within a formation-sized radius (`spacing x sqrt(n)`, at least 10 studs), and a unit that stands still for 2 s drops its lines.

**Alternatives:** spread goals by the units' order along the line (first version: lines crossed, because the server assigns differently); replicate order queues (sim work, more bandwidth).

**Why:** lines that point where units actually go. `Orders.spec` checks every unit ends within 4 studs of its drawn slot.

### C-12 — Protocol 6 join (2026-10-21)

**Decision:** the client starts with an empty `World`, sends HELLO on the Snapshot remote and drops everything until WELCOME, which sets the player, team, ally team, map (loaded with `MapRegistry`) and the full sim tick (wire ticks unwrap from it). REJECT stops the client with a warning. The server entry answers HELLO with `NetOut.hello` / `NetOut.join`, sends nothing to a player before that, and re-joins everyone when a match restarts (a new WELCOME resets the client's view). The Eco record lands in `world.economy` and `Api.state.economy`. C-9's attributes (map ID, versions, player ID and team) are removed.

**Why:** the sim stream shipped protocol 6 (S-2); one source of truth for identity and map.

### C-13 — Default controls (2026-10-21)

**Decision:** left click / drag selects (Shift adds, Ctrl toggles), double-click selects that type on screen, right click gives the smart order (enemy: attack; own unfinished frame: repair; own unit: guard; ground: move), right-drag gives a line move, Shift queues, Ctrl+1..9 sets and 1..9 recalls a group (Shift+digit adds it, a double tap jumps the camera), X stops. Picking uses projected unit centers (18 px), because unit parts don't take raycasts (rig.md).

**Alternatives:** BAR's S for stop (S pans the camera here); raycast picking (needs `CanQuery` on every unit part).

**Why:** familiar RTS defaults; listed under "Needs my review" because they're a feel decision.

### C-14 — Client placement check (2026-10-21)

**Decision:** `Core/Placement.check` applies `Sim/Placement.check`'s rules to the client World: the same snapping, bounds, slope (from `Passability.build` on the WELCOME map's layers) and water depth by placement type, the extractor deposit rule and upgrade rule, occupied cells (known structures; strategic ghosts block their cell) and ground units in the way (known units). It walks the footprint cell by cell like the server (bounds, occupant, terrain), so the reason matches too. It uses only what the client knows, like the server's planning check (D101); the server re-checks when the builder starts the frame. The constants (`LAND_MAX_SLOPE`, `WATER_MIN_DEPTH`, the unit radius) are copies until shared (request 4).

**Alternatives:** no client check, only the server's verdict (the ghost couldn't turn red before a click); ask the server per hover (latency, bandwidth).

**Why:** `Placement.spec` compares 750 random spots (five defs, hills, lakes, structures, deposits) with the server's planning check: all agree, reasons included.

### C-15 — Headless client demos when Studio is away (2026-10-21)

**Decision:** `lune run client_demo <name> <out.txt>` runs the real Sim and the real client modules (World, NetIn, Api) in Lune, scripts a scene through the same API the input layer calls, and writes the client's view (units, selection, order lines, the build ghost) in the scene-dump format; `lune run render_scene` draws it. Images from it are named and labelled as headless, not as playtests.

**Why:** Studio closed its place during the night run, and per the rules it isn't repaired from here. The demos still exercise the real client logic end to end; the Roblox-only layer (Instances, input events) waits for a playtest.

### C-16 — Combat effects on the render clock, with caps (2026-10-21)

**Decision:** `Core/Effects` consumes combat events and deaths only when the render clock (2 ticks behind, Interp) reaches their tick, so shells burst where the interpolated tanks are drawn; the unit renderer likewise keeps a dead unit's model until then. Projectiles are stepped tick by tick with the server's math (`Shared/Combat/Ballistics`: steer for homing, then step; the step is exact for any time step, so drawing between ticks adds no error). IMPACT ends a projectile, DECOYED / LOST_LOCK snap it, homing corrections blend over 5 ticks (snap above 60 studs). Caps (guide 15.3): all projectiles are followed logically, at most 150 are drawn; at most 60 bursts and 100 tracers live at once. Over a cap the least important is dropped, importance = size (weapon AoE) / (1 + distance to the camera focus / 100). Bursts are a growing, fading flash plus one `ParticleEmitter:Emit` on a shared carrier part (never `Enabled`).

**Alternatives:** play events on arrival (effects 133 ms ahead of the units they belong to); cap the logical projectile set (a skipped projectile would miss its IMPACT bookkeeping).

**Why:** `Effects.spec`: client shells stay within 0.5 studs of the server's projectiles (wire quantization) for 240 ticks of the duel, IMPACT clears them, events and deaths wait for their tick, and 400 projectiles / 200 impacts respect the caps with the near ones kept.
