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
| C-17 | Strategic zoom: screen-space shape icons (no image assets), on beyond 480 studs, off below 420; units without a model always get one |
| C-18 | Effects sized for the RTS camera: Neon shells 2.6 studs with a 0.06 s Trail, muzzle flashes >= 4 studs, impacts >= 7 studs |
| C-19 | Range rings: merged same-kind outlines on the terrain, own units and the build ghost, V toggles, rebuilt on change at most 4 Hz |
| C-20 | Target line for one selected unit: the attack order sent, else the known enemy on the turret's aim line (until targets are on the wire) |
| C-21 | BAR-style controls: camera on the arrow keys, edge scroll (live) and middle-drag; S = stop; WASD free |
| C-22 | Deposits are drawn on their exact cells (3D and minimap); the extractor ghost snaps onto a deposit within 12 studs |
| C-23 | A queued build is done when its frame stands on its spot; queued structures show translucent until then |

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

**Decision:** order queues aren't replicated (net.md 9), so the client draws what it sent (`Core/Waypoints`). For line moves it computes each unit's goal the way the server does (`Nav.slotsFor` and `Nav.assignSlots`): rows of slots spaced `2 x radius x 1.3` along the line, extra rows stepping back toward the group's centroid, deepest row first, each slot taking the closest unassigned unit (ties to the lower ID). Since 2026-10-22 these are `Shared/Grid/Formation`'s own `layout`, `deepestFirst` and `assign` (S-12); the client has no copy. A point counts as reached within a formation-sized radius (`spacing x sqrt(n)`, at least 10 studs), and a unit that stands still for 2 s drops its lines.

**Alternatives:** spread goals by the units' order along the line (first version: lines crossed, because the server assigns differently); replicate order queues (sim work, more bandwidth).

**Why:** lines that point where units actually go. `Orders.spec` checks every unit ends within 4 studs of its drawn slot.

### C-12 — Protocol 6 join (2026-10-21)

**Decision:** the client starts with an empty `World`, sends HELLO on the Snapshot remote and drops everything until WELCOME, which sets the player, team, ally team, map (loaded with `MapRegistry`) and the full sim tick (wire ticks unwrap from it). REJECT stops the client with a warning. The server entry answers HELLO with `NetOut.hello` / `NetOut.join`, sends nothing to a player before that, and re-joins everyone when a match restarts (a new WELCOME resets the client's view). The Eco record lands in `world.economy` and `Api.state.economy`. C-9's attributes (map ID, versions, player ID and team) are removed.

**Why:** the sim stream shipped protocol 6 (S-2); one source of truth for identity and map.

### C-13 — Default controls (2026-10-21)

**Decision:** left click / drag selects (Shift adds, Ctrl toggles), double-click selects that type on screen, right click gives the smart order (enemy: attack; own unfinished frame: repair; own unit: guard; ground: move), right-drag gives a line move, Shift queues, Ctrl+1..9 sets and 1..9 recalls a group (Shift+digit adds it, a double tap jumps the camera), X stops (S since C-21). Picking uses projected unit centers (18 px), because unit parts don't take raycasts (rig.md).

**Alternatives:** BAR's S for stop (S pans the camera here); raycast picking (needs `CanQuery` on every unit part).

**Why:** familiar RTS defaults; listed under "Needs my review" because they're a feel decision.

### C-14 — Client placement check (2026-10-21)

**Decision:** `Core/Placement.check` applies `Sim/Placement.check`'s rules to the client World: the same snapping, bounds, slope (from `Passability.build` on the WELCOME map's layers) and water depth by placement type, the extractor deposit rule and upgrade rule, occupied cells (known structures; strategic ghosts block their cell) and ground units in the way (known units). It walks the footprint cell by cell like the server (bounds, occupant, terrain), so the reason matches too. It uses only what the client knows, like the server's planning check (D101); the server re-checks when the builder starts the frame. Since 2026-10-22 the snap, the terrain rule and the unit radius come from `Shared/Grid/PlacementRules` (S-9); the client keeps only the knowledge-based parts (occupancy, units in the way).

**Alternatives:** no client check, only the server's verdict (the ghost couldn't turn red before a click); ask the server per hover (latency, bandwidth).

**Why:** `Placement.spec` compares 750 random spots (five defs, hills, lakes, structures, deposits) with the server's planning check: all agree, reasons included.

### C-15 — Headless client demos when Studio is away (2026-10-21)

**Decision:** `lune run client_demo <name> <out.txt>` runs the real Sim and the real client modules (World, NetIn, Api) in Lune, scripts a scene through the same API the input layer calls, and writes the client's view (units, selection, order lines, the build ghost) in the scene-dump format; `lune run render_scene` draws it. Images from it are named and labelled as headless, not as playtests.

**Why:** Studio closed its place during the night run, and per the rules it isn't repaired from here. The demos still exercise the real client logic end to end; the Roblox-only layer (Instances, input events) waits for a playtest.

### C-16 — Combat effects on the render clock, with caps (2026-10-21)

**Decision:** `Core/Effects` consumes combat events and deaths only when the render clock (2 ticks behind, Interp) reaches their tick, so shells burst where the interpolated tanks are drawn; the unit renderer likewise keeps a dead unit's model until then. Projectiles are stepped tick by tick with the server's math (`Shared/Combat/Ballistics`: steer for homing, then step; the step is exact for any time step, so drawing between ticks adds no error). IMPACT ends a projectile, DECOYED / LOST_LOCK snap it, homing corrections blend over 5 ticks (snap above 60 studs). Caps (guide 15.3): all projectiles are followed logically, at most 150 are drawn; at most 60 bursts and 100 tracers live at once. Over a cap the least important is dropped, importance = size (weapon AoE) / (1 + distance to the camera focus / 100). Bursts are a growing, fading flash plus one `ParticleEmitter:Emit` on a shared carrier part (never `Enabled`).

**Alternatives:** play events on arrival (effects 133 ms ahead of the units they belong to); cap the logical projectile set (a skipped projectile would miss its IMPACT bookkeeping).

**Why:** `Effects.spec`: client shells stay within 0.5 studs of the server's projectiles (wire quantization) for 240 ticks of the duel, IMPACT clears them, events and deaths wait for their tick, and 400 projectiles / 200 impacts respect the caps with the near ones kept.

### C-17 — Strategic zoom icons (2026-10-21)

**Decision:** past a camera distance of 480 studs (back below 420) the unit models are hidden (`ModelPool.setVisible`, one folder unparented) and every known unit is drawn as an icon in a screen-space layer of pooled frames: ground units squares, builders circles, aircraft triangles, ships diamonds, structures framed squares; radar and sonar blips faint dots (tracked contacts show their real icon, D104), ghosts hollow squares; size by tier and footprint; team colors; selected units white-edged and on top. Units without a model (strategic records, blips, ghosts in view) get an icon at any zoom. Strategic records map back from the icon number with the shared numbering `Shared/Net/Icons` (S-10; a client copy until 2026-10-22), still checked equal to `NetOut.iconIndex` in `Icons.spec`. The camera rectangle is still sent at strategic zoom.

**Alternatives:** BillboardGuis per unit (guide 15.7 warns against hundreds); image icons (need uploaded assets: later, with the art pass); stop sending the camera at strategic zoom (smaller tactical tier, less bandwidth, but icons would then move at 3 Hz cell steps: left for review).

**Why:** readable large battles and cheap rendering (guide 15.4) without assets.

### C-18 — Readable shots at RTS zoom (2026-10-22)

**Decision:** at the default camera (220 studs away) one stud is about two pixels, so effects are sized for that: ballistic shells are bright Neon 0.9 x 0.9 x 2.6 studs with a short Trail (0.06 s, about 20 studs behind a 340–380 stud/s tank shell, fading and narrowing); each projectile keeps its pooled part while it flies, and a reused part's trail is cleared and held back one frame so it never streaks across the map. Muzzle flashes are at least 4 studs across, impacts at least 7 (AoE x 1.6 x 2), deaths at least 12; particle bursts use bigger particles (2.6 studs). Counters for diagnosis stay in: events received per kind (`World.eventCounts`), applied (`Effects.applied`), drawn (`RenderEffects.stats`), read with `FtggClientDebug:Invoke("fx")`.

**Alternatives:** keep model-scale sizes (0.45-stud shells: about one pixel at RTS zoom); scale effects with camera distance (later, if the near view looks too big).

**Why:** the user saw no projectiles. The first cause was a stale script, not the effects: Studio's `Entry.MatchConfig` said `ACTIVE = "build"` (no enemy, so no shots) while the file said `duel`, and Rojo only pushes a file when its content changes; a real edit re-synced it. In the actual duel the client received and applied 92 SPAWN_PROJ and 92 IMPACT in 8 s, but drew 0.45-stud shells for 0.05–0.13 s: invisible from the RTS camera.

### C-19 — Range rings (2026-10-22)

**Decision:** for the selected own units (own team: the wire doesn't say which other teams are allied) and for the build ghost, `Core/Ranges` makes one circle per weapon (anti-air-only weapons as their own kind) and per sensor (sight, radar, tracking, jammer). Circles of the same kind merge: each circle keeps only the arcs not inside another circle of that kind (overlap intervals of half-angle acos((r² + d² - r'²) / 2rd) around the direction to the neighbour; nested and identical circles drop out; near neighbours are checked first so interior circles of a dense group stop early). Arcs become polylines (at most 6 studs apart, 24–96 points per circle) on the terrain height + 0.35 studs, drawn as pooled thin Neon segments (`Render/RangeOverlay`). Colors: weapon red, anti-air pink, sight white, radar and tracking green, jammer yellow. A rebuild happens only when the selection, the ghost or a selected unit's position (2-stud steps) changes, at most 4 times a second. V toggles the rings; on by default.

**Alternatives:** draw every circle (unreadable for groups); exact union every frame (3–4 ms for 50 tightly packed units in Lune); a raster (texture) overlay (needs EditableImage).

**Why:** `Ranges.spec`: two overlapping circles give one closed outline (every arc end meets another) with no arc point inside the other circle; separate circles stay whole; nested and identical ones vanish; kinds don't cut each other; an outer arc across angle 0 stays one arc. Cost (Studio playtest, 50 Lancers selected): nothing when nothing changes (0.024 ms per frame); a rebuild while the group moves 3.1 ms on average, 4.7 ms at worst (union 1.6–2.6 ms, the rest part writes), at most 4 per second, so 0.21 ms per frame on average; the first build after selecting 4.7 ms. Made cheaper by an allocation-free interval sweep (sorted starts and ends), near neighbours first, segments kept parented and hidden by Transparency, Size written only when it changes by > 0.3 stud, one BulkMoveTo, and a 256-segment pool pre-made on idle frames. A further step, if the spikes matter: split a rebuild over two frames.

### C-20 — Target line (2026-10-22)

**Decision:** with one unit selected, a red line runs from it to its current target, with a red ring around the target. Targets aren't on the wire yet (request 6), so `Core/Targets` uses the attack order this client sent if there is one, else, while the first weapon is AIMING or READY, the known enemy within 1.1 x its range closest to the turret's aim line (hull heading + replicated turret yaw, within 12°).

**Why:** `Targets.spec`: over 200 ticks of the duel the guess equals the server's `wTarget` 1,393 times in 1,398 (99.6 %); an attack order is exact. A wire field makes it exact always and also covers targets the turret hasn't turned to yet.

### C-21 — BAR-style controls (2026-10-22, the user's answer)

**Decision:** the camera pans with the arrow keys, screen-edge scroll (live games, off in Studio) and middle-drag; Q / E rotate as before; S stops; WASD is free for later hotkeys; V toggles range rings. Everything else in C-13 stays. Placing is cancelled with a right click only: Esc is Roblox's menu key, arrives as already processed and opens the menu (found in the step 4 playtest). Strategic zoom keeps sending the camera rectangle (answer to C-17).

### C-22 — Placing extractors (2026-10-22)

**Decision:** supply deposits are one cell (8 studs), and an extractor is valid only with its center on that cell (the server's rule, unchanged). The client now draws a gold Neon plate on each deposit cell in the 3D ground (brighter for richer deposits) and a small gold square per deposit on the minimap, instead of tinting the minimap's whole 4 x 4-cell tile. The extractor ghost snaps onto the nearest deposit within 12 studs of the cursor (`Placement.assist`: the cell's center for odd footprints, its min corner for even ones).

**Why:** the user couldn't place extractors on "the golden spots": the gold the client showed was the minimap's 32-stud tile, the real target was an unmarked 8-stud cell, and the server (correctly) refused spots a few studs off. `Placement.spec` checks every deposit of the start map from five cursor offsets up to 10 studs away: the ghost lands on the deposit and the server's check accepts it. Studio: an aim point 5–6 studs off a deposit snapped onto it, the extractor was built there and supply income went from +1.0 to +3.0.

### C-23 — Queued builds (2026-10-22)

**Decision:** a BUILD the client sent stays in that builder's queue (`Core/Waypoints`) until a structure stands on its spot: its own frame started (or another structure took the spot, which the server skips). The 2 s idle rule no longer applies to a builder whose next order is a build, because builders stand still while they build; it expires only after 20 s idle with no own frame going up within its build range (a fallback for a build the server dropped). Every queued build of your own builders shows as a translucent copy of the structure over a faint yellow footprint (`Render/QueuedBuilds`, rebuilt only when the queue changes), and the yellow order line keeps running through the remaining ones.

**Why:** the user saw the yellow line to the rest of the queue vanish after the first building: the idle rule (C-11) wiped the whole queue once the builder had stood still for 2 s while building. `Placement.spec` follows a generator plus a Shift-queued row of solars against the server's own order queue: the client's list is never more than one item off (the frame just started) and empties as the last frame starts. Studio: three Shift-queued generators showed two translucent models and the line through them while the first went up; each went away as its frame started. Units queued in a factory have no spot on the map, so they aren't drawn (a factory queue UI is later).

### C-24 — Health and build bars (2026-10-21)

**Decision:** bars show for selected units, damaged units (health under 99.9 %) and frames under construction, own or enemy, while they are tactical (the only tier whose health is on the wire). A healthy, finished, unselected unit has none. A frame shows two bars: health on top (green at full, yellow at half, red when low) and build progress under it (light blue, 0 → 100 %); when it finishes, the build bar goes and only health remains (and only while selected or damaged). The client just displays the two wire values: the sim starts a frame at 1 % health, adds health as it builds and damage never lowers progress (`Sim/Build`). `Core/Bars` picks the units and the screen spot (above the unit by 0.6 x its footprint + 3 studs, as wide as the footprint looks, 18–90 px); `Render/HealthBars` is a pooled screen-space layer like the icons (no BillboardGuis, guide 15.7), hidden at strategic zoom.

**Why:** the user's request. `Bars.spec` against the real sim: a generator frame keeps two bars while it builds, its health follows 1 % + 99 % x progress, then no bar once finished (one when selected); a factory frame under a tank's fire loses health but its progress never drops. Studio (`build` profile): a factory frame showed two bars with health tracking progress (0.04/0.03 … 0.39/0.38), a Studio-only 35 % hit (`FtggDebug:Invoke("damage", id, amount)`, through the sim's own damage step) took health to 0.65 while build stayed at 0.99, then it finished with one yellow-green bar. Cost 0.019 ms per frame (2 bars).

### C-25 — Exact target line (2026-10-21)

**Decision:** the target line (C-20) uses the server's targets for own units (State TARGET field, S-16, protocol 8): the client keeps `targets[slot]` per unit and the line goes to the first weapon slot's target that the client knows. A target the client has dropped (it died) shows no line. The aim guess and the attack-order shortcut stay only for units whose targets the server doesn't send (an ally's units in a team game; "own" on the client is the team, the wire doesn't say which player owns a unit).

**Why:** `Targets.spec`: over 200 ticks of the duel, the line's target equals the server's (first slot with a live target) for every own unit on every tick; the guess without wire targets still agrees 1,393 times in 1,398.

### C-26 — Shells burst where they hit, when they hit (2026-10-21)

**Decision:** when a shell's IMPACT is due in the coming sim tick (events arrive ahead of the render clock, which runs two ticks behind), `Core/Effects` works out how far into that tick the drawn shell reaches the impact point (distance left / distance per tick) and plays the IMPACT as soon as the render clock passes that point, instead of at the tick's end. The shell is never drawn past the point. `Invoke("fx")` now also reports `late`: how many render ticks after its tick each event played.

**Why:** the user saw a delay between the shell hitting and the explosion in the duel. Events were on time (Studio: played 0.19 tick after their tick on average). The gap was drawing: through the tick it hit in, the shell kept flying to the server's end-of-tick position, up to a tick's travel (~23 studs for a tank shell) past the target, and burst back at the hit point when the tick ended: 33 ms after reaching it on average, 67 ms at worst. `Effects.spec` now renders the duel at 8 frames per tick: the worst gap is one frame (8.3 ms; 66.7 ms with the fix switched off). Studio duel: 103 shells, 103 impacts, none left over or doubled.

### C-27 — Shells leave from the barrel tip (2026-10-21)

**Decision:** a SPAWN_PROJ due in the coming tick is played one tick early, stepped back one tick (inverse `Ballistics.step`) to where the server launched it, so it flies the server's exact path from launch. It is drawn from the shooter's drawn barrel tip: the nearest tactical unit within 12 studs of the launch point that has that weapon (`muzzleOf`, the weapon's muzzle attachment), and the gap to the server's path blends away over 3 ticks, shrinking smoothly through each tick. A shell flying into view (no shooter near) starts where the server says. The impact timing of C-26 measures from the drawn position. `Invoke("fx")` reports `launches` (from a barrel, average tip-to-launch-point distance).

**Why:** the user saw shells appear far from the tanks' barrels. Two causes: SPAWN_PROJ carries the shell after the server's first step (Weapons and Projectiles run in the same tick), a tick's travel (~23 studs for a tank shell) out; and the server launches from the unit's center at muzzle height, not the barrel tip. `Effects.spec`: in the duel at 8 frames per tick all 159 shells are first drawn at the (stand-in) barrel tip (none with the change switched off), and once blended the drawn shell is exactly the server's. Studio duel: 101 of 101 launches started at a drawn barrel tip, on average 5.6 studs from the server's launch point (the barrel's reach).

### C-28 — Terrain from the map layers (2026-10-21)

**Decision:** the client draws a map's ground as Roblox Terrain built from its layers, for every map without baked place terrain (all maps today, including the sim's procedural maps, S-15). One smooth surface (`Core/Terrain`) serves the 3D terrain and everything standing on it (`World.groundY`: units, bars, rings, effects): bilinear between cell centers, so flat ground (start plateaus, deposits) stays exact and a step between cells becomes an 8-stud-wide slope. Water is flat at each water cell's surface (height + depth). `Render/Terrain` writes 4-stud voxels chunk by chunk (8 ms per frame, then it yields) with `WriteVoxelChannels`: solid occupancy puts the surface at the computed height (written 2 studs low: Roblox draws a solid occupancy surface half a voxel above the fraction; liquid occupancy has no such offset), liquid occupancy fills water up to its surface so it meets sloped shores. Materials (placeholders): grass, rock where steeper than ~50°, sand on shores and under water. Deposit plates float 0.35 stud over the cell's height (the surface tilts up to 0.28 stud under deposits on gentle slopes). The cursor raycast hits the Terrain and its water. The client only builds when the place has no terrain of its own and only clears terrain it built; nothing is saved to the place. The parts way (`Ground.build(layers, "parts")`, `Invoke("ground", "parts")`) stays for comparison.

**Measured (Studio, `map:coastline`, 128 × 128 cells, same camera):** terrain: 1.2–1.4 s to build (0.45–0.53 s of it CPU, spread over frames), 1.77 M voxels, render GPU 2.72 ms and CPU 3.65 ms per frame, no extra instances. Parts (columns merged inside 8 × 8-cell blocks): 0.08 s, 8,980 parts, render GPU 3.43 ms and CPU 3.62 ms, +30 MB, a stepped look with seam lines. Both hold 60 fps; terrain is cheaper to draw, looks right and needs no instances, so it is the default. Drawn vs computed ground at 600 random spots: median 0.02 stud, 95th percentile 0.53; up to 7.5 studs only on the ridge faces (41-stud cliffs that Roblox smooths); water at exactly 8. Every unit's model stood on the drawn terrain within 0.02 stud. `Terrain.spec`: on the four named maps the surface equals the layers at cell centers, has no step at cell seams, stays within 0.35 stud under every deposit and is flat around the starts; water is one level; starts are on grass, ridges rock, shores sand.

### C-29 — Range rings follow their units every frame (2026-10-21)

**Decision:** circles, arcs and polylines carry the unit they are centered on (`owner`; none for the build ghost). The merged outline is still rebuilt at most 4 times a second (C-19), but between rebuilds each line is shifted every frame by how far its unit's drawn position has moved since the rebuild, and laid on the terrain again; only lines whose unit moved are redrawn. Where merged outlines cross, the shape is fixed at the next rebuild.

**Why:** the user wanted the rings to update faster and smoothly; they jumped every 0.25 s / 2 studs. Cost (Studio, 50 Lancers selected and moving, 252 segments): 1.54 ms per frame on average (following 1.34 ms, rebuilds up to 5 ms, still at most 4 per second), against 0.21 ms before; nothing while the selected units stand still. 3 Lancers on the terrain map: 1.25 ms (200 segments, mostly sight rings). `Ranges.spec` checks that arcs and lines keep their owner.

### C-30 — Piece scripts (task 2, 2026-10-21)

**Decision:** `Core/PieceAnim` is the client's piece-script system (guide 14.3–14.5): one scheduler, stepped once per frame, advances every `Turn` / `Move` (degrees or studs per second; 0 = instant) and resumes script threads (coroutines) waiting in `Sleep`, `WaitForTurn` or `WaitForMove`; `Signal(mask)` kills the unit's other threads sharing a bit with `mask`, `StartThread` inherits the caller's mask (BAR semantics). Hooks run in new threads: `Create`; `StartMoving` / `StopMoving` from the MOVING state bit; `AimWeapon(u, slot, yaw, pitch, active)` when the replicated aim changes and every 0.5 s while the weapon is AIMING / READY (BAR calls AimWeapon repeatedly while engaged, so a restore countdown starts only once it stops); `FireWeapon(u, slot)` from FIRE events and from shell launches (Core/Effects now reports which unit and slot fired). LOD by camera distance: near (≤ 300 studs) everything, mid (≤ 600) aim only, far no hooks and every turn snaps; nothing runs at strategic zoom. `Render/UnitRenderer` writes `Motor6D.Transform = Angles(rot) * CFrame.new(pos)` only for pieces that changed (recoil moves along the turned barrel) and resets joints when a model goes back to the pool.

Every unit runs `PieceScripts/Default` unless it has its own: turret and pitch pieces follow the replicated aim at 1.25 × the weapon's turret rates, the barrel recoils 0.5 stud on each shot. This replaces the old exponential aim follow. The Juggernaut has a hand-made blockout (tracked hull, turning torso = the def's `turret`, two gun arms `armL` / `armR`) and the guide 14.4 script: torso to the target, arms up to the firing pitch, recoil in turn, arms down `RESTORE_DELAY` (3 s) after the weapon stops aiming. Blockouts may declare `visualPieces` (jointed pieces the def doesn't list yet; validated) for the arms.

**Timing against the server:** the server has no rest pose or restore delay (the Juggernaut's gun rests at 0° and reaches its firing pitch almost at once), so until request 8 the arms rise at a visual 120°/s from -65° and the first shot can leave before they are fully up. With `turret.restPitch` / `turret.restoreDelay` in the weapon def the script uses them and the server's pitch rate, i.e. exactly the server's timing.

**Why / measured:** `PieceAnim.spec`: turn and move durations, waits and sleeps to the frame; Signal cancels only older threads of its mask; far LOD snaps; removing a unit ends its threads; in a 200-tick duel the default script keeps every turret within 0.09 of a tick's turret travel of the server's `wYaw`; the Juggernaut's arms rise in (3 + 65) / 120 s, stay up while engaged, recoil left then right, and start down ~3 s after the last aim. Studio (`terrain` profile, Juggernauts added with `FtggDebug:Invoke("spawn", ...)`): arms -65° at rest, up to +1° in ~0.55 s when Ravagers came into range, down again after the fight; 64 animated units in a fight (58 near, 6 mid, 51 threads): 0.134 ms per frame on average, 0.41 ms at worst.

### C-31 — Air and naval rendering (task 3, 2026-10-21)

**Decision:** aircraft are drawn at their replicated altitude (as before) and `Core/Attitude` adds what the server doesn't model: jets roll into their turns (0.7 radian of roll per radian/second of the drawn heading's turn rate, at most 60°), helicopters roll a little (at most 20°) and dip their nose up to 12° at full speed; both close on their targets at 5/s. Generic helicopter blockouts get a tail boom, mast and two-blade rotor (a visual piece); the default piece script spins it at 4 turns a second, winds it down when the LANDED bit is set and spins it up again on take-off (`Spin` / `StopSpin` with acceleration, and `Land` / `TakeOff` hooks, added to PieceAnim). Ships sit 0.8 stud into the water; the player's own (and allied) submarines are drawn with their top 2.5 studs under the surface, shallower than the server's 10, so the owner sees them through the water. Enemy submarines are never drawn: the server only ever sends them as sonar contacts (strategic records with SONAR_ONLY; Sensors gives submerged units no other level), and sonar contacts now show as a hollow ring icon in the team color instead of a radar blip. A MatchConfig `ew` profile runs the sim's `ew_test` scenario.

**Why:** the user's task 3. `AirNaval.spec`: a jet at its full turn rate banks 40–60° into a left turn and levels within 2 s of flying straight; a helicopter at full speed has its nose 12° down and no roll; ground units stay upright; ship and submarine offsets; a helicopter blockout validates with a rotor that turns 1,440°/s, stops after landing and spins up again; in `ew_test` (real sim) the helicopters arrive with altitude; on `sea:64` an enemy submarine near an own ship arrives only as a SONAR_ONLY record (a sonar ring) and never as a model, while the own submarine is tactical and SUBMERGED. Studio: two helicopters hovering at 45.7 studs with turning rotors, a Falcon at 110 studs banked 50–52° while circling (`ew` profile plus spawned aircraft); on Coastline's sea a ship 0.8 stud into the water, an own submarine 2.5 studs under it, and an enemy submarine shown only as a sonar ring.

### C-32 — Fog of war in 3D (task 4, 2026-10-21)

**Decision:** `Core/Vision` stamps the player's team's sight on the server's 16-stud sensor grid with the server's rule (a cell is seen when dx² + dz² ≤ (sight / 16)² from the unit's sensor cell; unfinished structures don't see; no terrain blocking), from the own units' latest positions. Own units outside the camera are strategic records: their def is remembered from when they were tactical (else the icon's sample def), and a unit that drops out without dying keeps its sight for 8 ticks (until the next strategic snapshot). Drawing, by zoom:
- **Camera within 330 studs (back at 300): light fog**, the user's idea and Astra Force's write-up. A ColorCorrection and dimmer Lighting (client-side, restored when it ends) darken the scene, and a PointLight per 32-stud light cell (range 40, 12 studs up) lights what the team sees, its brightness fading (0.4 s) toward the share of the cell's sensor cells in sight. Lights are made the first time a cell is lit.
- **Farther: overlay.** Roblox stops rendering point lights a few hundred studs from the camera (in Studio: lit at 320, gone at 470 — the write-up's "lights unrendering when the camera is too far away"), so the Lighting goes back to normal and dark translucent plates cover the unseen sensor cells: a plane through each cell's corners on the drawn terrain, lifted over its highest point, neighbors in a row with nearly the same plane merged, rebuilt per 8 × 8-cell block that changed (2 ms per frame budget).
Radar and sonar contacts are pulsing discs on the ground or water (`Render/Contacts`); ghost structures are faintly glowing blue-grey copies drawn from the client's memory of the structure (def, position, heading while it was tactical), else the icon's sample def at the record's cell. Contacts and ghost models hide at strategic zoom (icons there).

**Why:** the user's task 4 and light-fog suggestion. `Vision.spec`: the client's map equals the server's `los` map on every sensor tick of the live duel, 98 / 98 with the units in the camera and 85 / 85 after the camera has moved away. `FogOfWar.spec`: on Coastline the plates' area is exactly the unseen cells' and no drawn ground pokes through (3,779 unseen cells in 1,549 plates); light levels; a generator seen and then left behind comes back as a ghost of that generator where it stands; radar contacts are listed and never drawn as units. Studio (`terrain` profile): light fog at 240 studs (201 lights lit), overlay at 440 (1,404–1,478 plates), a ghost in the dark, a radar contact disc from a spawned watchtower. Costs: fog code 0.022 ms per frame (lights) / 0.024 ms (overlay); GPU 4.30 ms with the light fog, 3.57 ms with the overlay (terrain alone 2.72 ms, C-28); 1,024 extra lights across the map changed nothing measurable (Roblox renders only the lights near the camera); 60 fps throughout.

**Known gaps:** own units never seen in the camera use their icon's sample def (sight differs), and allied players' units aren't known as allies yet: request 9 asks for the team's sight map on the wire. The light grid shows as a soft checker; plates show faint seams (placeholders under "Needs my review").

### C-33 — The Juggernaut follows the server's arm timing (2026-10-21, after S-20)

**Decision:** with request 8 done (S-20: `chs_juggernaut_cannon` rests at -65°, raises at 80°/s, holds 3 s after losing its target; `armL` / `armR` in the def's pieces), the Juggernaut's script no longer times anything itself: the torso and both arms turn toward each replicated yaw and pitch at 1.25 × the weapon's rates, from the rest pitch at Create, and recoil in turn on each shot. The blockout drops its `visualPieces` (the arms are def pieces now); `visualPieces` stays for generic helicopter rotors.

**Why:** C-30's visual timing could show a shot before the arms were up and lower them up to 0.5 s early. `PieceAnim.spec` now runs the real sim: the arms rest, rise when a Ravager comes in range, hold, and come down after it is gone, never more than 0.10 of a tick's travel off the server's pitch, and every shot leaves with the arms up.

### C-34 — Deaths and wrecks (task 5, 2026-10-21)

**Decision:** a dead unit's model stays where it was drawn until the render clock reaches its death (as before), then `Render/Deaths` plays the death that `Core/Deaths` plans from the DEATH event, following the server's wreck rule (a wreck only when overkill ≤ 50 % of max health): with a wreck, the hull shakes for 0.4 s (0.35 stud, easing out) and the wreck takes its place; without one, 1–3 jointed pieces (turret first) fly off on ballistic arcs (22–36 studs/s up, 6–16 out, spinning, gravity 60) for 1 s while the hull sinks under the death burst, and nothing is left. Velocities come from the shared Prng seeded by the unit ID (the same death plays the same way). Pieces move through their `Motor6D.Transform`, so the pooled model is reset and returned afterwards. Wrecks are darkened copies of the unit's own model (colors 75 % toward charred brown-black, CorrodedMetal, turrets and barrels knocked askew, tilted up to 4°, sunk 0.35 stud), pooled per def, hidden at strategic zoom, at most 300 (oldest goes). A guide 14.6 "shared generic wreck per size" isn't needed: every unit has a blockout to darken.

**Why:** the user's task 5. `Deaths.spec`: the plan follows the wreck rule; flung pieces are real jointed pieces, each once, rising then falling; the same death plans the same; the shake eases out; all 15 deaths of a duel get the plan their DEATH event calls for (all small overkills: 15 wrecks). Studio: a fight on Coastline left a row of six Lancer wrecks and a Juggernaut wreck; a 99,999 hit on a Ravager (`FtggDebug` damage) flung its turret and barrel up to +7.2 studs and back down within 1 s, no wreck.

**Known gap:** wrecks reach the client only in the DEATH events of its tactical tier; it never hears of a wreck made elsewhere (or before it joined) or of one reclaimed, so its wrecks stay until the match restarts: request 10.

### C-35 — Global sim speed for debugging (2026-10-21)

**Decision:** the server entry's tick loop accumulates real time × `speed` (0 pauses), so at 0.25× the sim steps 15 times every 4 real seconds and the sim itself is untouched. The speed starts at the profile's `speed` (MatchConfig, default 1), is published as the Remotes folder's `SimSpeed` attribute, and changes through a `SimSpeed` RemoteEvent that the server honors only in Studio (steps 0.1, 0.25, 0.5, 1, 2, 4). Client keys (BAR's game-speed keys): `-` slower, `=` faster, `P` pause / resume; the F3 readout shows the speed when it isn't 1×. The client's render clock (`Interp.advance`) runs at 15 × speed and freezes where it is while paused (no pull back toward the target); piece scripts and aircraft attitude step in sim time (frame time × speed). Camera, UI, range rings and explosion flashes stay in real time.

Also: C-26's timing now measures along the drawn shell's actual move over the tick (the server's step plus the barrel-tip offset still closing after a C-27 launch); before, a just-launched shell on a short shot could burst up to 0.9 tick after reaching the impact point. Its test now pairs each shell with the server's own SPAWN_PROJ / IMPACT events, since projectile IDs are reused (more misses after the light cannon's accuracy went from 1.2 to 2.0 exposed both).

**Why:** the user wants to slow things down for debugging. `SimSpeed.spec`: at 0.1–2× the render clock moves 15 × speed ticks a second (each frame within 25 %), stays about 2 ticks behind the newest tick, freezes exactly when paused and moves on without a jump when resumed. Studio: 15.0 ticks a second at 1×, 3.65 at 0.25×, 0 paused (render clock and units still to the stud), 14.4 after resuming; the readout shows "sim speed 0.25x". `Effects.spec`: worst burst delay one frame (8.3 ms) again.

