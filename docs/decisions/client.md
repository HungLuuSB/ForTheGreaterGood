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

### C-36 — Smooth missile paths (2026-10-21)

**Decision:** the client steers homing missiles the way the server does (Sim/Systems/Projectiles): at the target's interpolated position at the tick being stepped (not its newest one, two ticks ahead), at the centre of its collision cylinder (6 studs per footprint cell, on the cell's height plus altitude; ships 3 into the water, submerged submarines 10 under), led by the target's heading and speed over the straight-line time to go. Server corrections, decoys and lost locks no longer move the drawn missile at once: a ghost keeps flying the old course (position and velocity) and the drawn missile blends from it to the new state with smoothstep over 5 ticks, so position and direction both stay continuous. Launch offsets (C-27) ease out the same way. On a missile's spawn tick the client takes the server's state as is (a homing missile already steered in it).

**Why:** the user saw missiles bounce and zig-zag. Measured in `ew_test` (Lune, 60 fps): the drawn path jumped up to 27.7 studs in a frame (a decoy snapped the missile; corrections turned it at once, a corner every 5 ticks); now at most 2.5 studs off a straight continuation (a missile covers ~7 a frame), and `Effects.spec` checks ≤ 3 with a decoy in the run. Studio (`air` profile): worst 5.3 studs over 57 frames (uneven frame times). The prediction itself still drifts from the server by 7 studs on average between corrections, mostly for targets the client only knows as radar contacts (it can't steer at a position it doesn't have); request 11 asks for more frequent homing corrections. A missile that leaves the map draws up to ~20 studs off, because positions on the wire clamp to the edge cell (harmless).

### C-37 — SAM test scene, slowed flight tests, fog darkening off (2026-10-21)

**Decision:** a `sam` MatchConfig profile: 4 Order long-range radars (Beacon, radar 1,100) cover the flat 128-cell map, 4 Falcons with 5× health circle over the middle, and 4 Chaos Thorn IR SAM sites (the nearest unit to IRIS-T SLM: IR-guided, short range) keep firing at them. Spawn entries take `health` (a multiplier on the starting health, for test runs; the wire clamps it to a full bar until it drops below the normal maximum). Profiles for watching flight paths (`sam`, `air`, `naval`) start at `speed = 0.25` (the user's rule). The fog-of-war darkening (C-32) is off (`FogOfWar.ENABLED = false`): the user found it made things hard to see, to revisit later; vision, radar contacts and ghosts stay.

**Why / measured:** headless minute of `sam`: 94 missiles, 8 decoyed, 26 hits, all 4 Falcons (2,600 health) still flying. Studio: the match starts at 0.25×, normal lighting, missiles in the air within seconds. Vertical launch (IRIS-T style) needs the sim: request 12.

### C-38 — Curved missile paths, aircraft markers, clicking models (2026-10-21)

**Decision:**
- **Projectiles bend through each tick:** a frame draws a cubic Hermite curve between the projectile's state at this tick and its predicted state one tick on (`nextState`, the same steer-and-step the client advances with), each with its velocity, instead of a straight line that turns at the tick's end. The ghost blend (C-36) now grows its gap with the prediction's velocity after this tick's steering (no step at tick boundaries), estimates the drawn velocity at a correction including how fast the blend closes, and a correction during a blend with more than 30 % left keeps the blend's progress (only the ghost is re-aimed) instead of restarting it.
- **Aircraft markers:** icons, health bars, the selection ring, the target ring and line, and order lines start where an aircraft is drawn; they used to add its altitude again (bars and icons at twice the height) or sit on the ground under it.
- **Clicking units:** unit model parts are raycastable (set once when the pool makes a model; other raycasts include only the ground), and a click selects (or right-click targets) the unit whose model is under the cursor, before falling back to the unit whose projected position is nearest.

**Why:** the user still saw SAM missiles zig-zag, aircraft icons and health bars far off, and wanted clicks on a model to select it. Missile paths in the `sam` scene (Lune): the server's missiles hold their turn direction, but the drawn ones turned up to 10.7° in a corner at every tick (a Thorn missile turns 160°/s), and a missile corrected every tick or two trailed an ever older course (gap 4 → 9 → 16 studs); now at 8 frames a tick the worst bend is 1.05 studs a frame, tick boundaries bend like the rest of the curve (0.105 vs 0.077), and `Effects.spec` checks it. Studio at 0.25×: 719 missile frames, 19 turning more than 0.5° in a frame, worst 2.2°. Bars and icons: `Bars.spec` puts an aircraft at 110 studs' bar just over the model and its icon at the model. Studio: clicking a Falcon's model 110 studs up selected it; its ring and bar are at the aircraft.


### C-39 — Missile sensor view (2026-10-21)

**Decision:** N toggles a War Thunder–style missile sensor view (off by default). For the 12 most important homing missiles drawn this frame (`Core/MissileView.build`, pure): a dot where the missile is drawn; its predicted path for the next second, cut 2 ticks after its closest approach (green when the prediction sets off the proximity fuse, orange when it misses, grey without a lock); a yellow line to the point it steers at and the target's centre in red (`Effects.aim`, the server's lead); the fuse envelope (the target's hull grown by the weapon's `aoe`) as a translucent cylinder; the predicted closest approach as a magenta dot joined to the centre; and a label: guidance, LOCK / no lock, target, distance, time to the closest approach, predicted miss against the fuse ("HIT" when it fires). Corrections, decoys and lost locks leave marks for 2.5 s (at most 40): a line from where the missile was drawn to where the server had it, fading out.
- `Core/Effects`: `homingAim` is split into `Effects.aimFrom` (the aim from a target state) and a target sampler; `Effects.predict(fx, world, p, ticks)` runs the client's steer-and-step on a copy, with the target as drawn up to its last snapshot and flown straight on from there, and takes the closest approach along each tick's chord relative to the moving target, as the server's fuse does; `fx.marks` records corrections, decoys and lost locks.
- `Render/MissileView`: pooled always-on-top handle adornments on the Terrain with the default ZIndex (ZIndex 5 hid them all) and culling off (Automatic culled small dots at RTS distances); dots grow with camera distance beyond 120 studs; labels are screen-space TextLabels. `FtggClientDebug:Invoke("missiles", on?)` turns it on or off and returns the entries.

**Why / measured:** the user asked for a view that shows what each missile is doing (queued 2026-10-21). `MissileView.spec` on the `sam` scene: every drawn missile has its target, aim point, path, fuse (5) and label; predicted 5 ticks ahead the path is a median 2.2 studs off the server's missile (90th percentile 11, since the Falcons circle and the prediction flies them straight); called at most 2 ticks before the closest approach, HIT / miss matched the outcome 49 times out of 51; marks expire and stay under the cap. Studio (`sam`, 0.25×, N pressed): up to 4 missiles at once, 0.4 ms a frame (worst 1.9 ms), no errors; screenshot `debug_out/screens/c39_missile_view_sam.jpg` shows one missile predicted 7.9 studs off a Falcon's hull (fuse 5, a miss) and one predicted HIT.

**Known gap:** a target outside the camera's tactical rectangle is a strategic record with no def or altitude: the label calls it "contact #id" and the client's guidance (C-36) aims at it roughly until a correction arrives (request 11).

### C-40 — Recognizable missiles (2026-10-21)

**Decision:** homing missiles get their own pooled model in `Render/Effects` instead of the glowing slug shells keep: a light-grey cylinder body, an ellipsoid nose (dark for IR seekers, off-white radome for radar guidance), cross fins at the tail, and a Neon exhaust that flickers with a PointLight (at most 16 lit at once). Behind it a short flame trail (0.05 s) and a grey smoke trail that starts 1 stud wide and billows to 5. Sizes are for the RTS camera like the shells (C-18): 4.4 studs long, 0.8 thick; weapons with the `smoke_thick` trail fx (the radar SAMs) get a 1.3× missile and 1.8 s of smoke instead of 1.1 s. When a missile ends, its model hides and stays where it ended, so its smoke fades out instead of vanishing; the model is reused only after that. All parts are anchored and move in the same BulkMoveTo as the shells. The nose is the part named "Projectile" (the scene dump still shows missiles and their trails).

**Why / measured:** queued after C-39 (the user wants missiles that look like missiles). Studio (`sam`, 0.25× and 0.1×): up to 4 missiles at once, smoke plumes from launch to impact and lingering after, exhaust glow lighting the launcher at launch, no errors (`debug_out/screens/c40_missile_model_closeup.jpg`, `c40_missile_smoke_launch.jpg`). Smoke lasts in real time, so at slow sim speeds it covers fewer studs, and it fades while paused.

### C-41 — Range rings of known enemy defenses (2026-10-21)

**Decision:** enemy defenses the team knows of always show their weapon range rings (whatever is selected; V still hides all rings): dark red for ground weapons, violet for anti-air, 0.5 studs wide, merged per kind like own rings (C-19). A defense is a structure with weapons and no build options, so factories and other builders never get one. "Known" (`Ranges.enemyDefenses`):
- in sight inside the camera area (tactical): its def, where it stands;
- any other record (in sight elsewhere, a ghost, a radar contact) of a structure seen before at about the same place (within 24 studs: radar error and cell rounding): the remembered def and position (Core/Ghosts' memory);
- else a record with an icon (in sight, ghost, tracked contact): the icon's sample def at the record's cell.
A plain radar blip never seen up close carries no icon on the wire (icon 0), so its range is unknown and gets no ring. The list is looked up at most 4 times a second, and the outline rebuilds only when it changes.

**Why / measured:** the user asked for it (defenses only, not factories). `Ranges.spec`: a Thorn on radar only gets no ring; once a Lancer sees it, one anti-air ring of its range at its position; after the Lancer leaves, the ghost keeps the ring; a vehicle plant next to it never gets one. Studio (`sam`): no rings until the Falcon spots the Thorns, then one violet outline of the four (`debug_out/screens/c41_enemy_sam_rings.jpg`).

### C-42 — Seeker cone in the missile sensor view (2026-10-21)

**Decision:** the missile sensor view (N, C-39) draws each guided missile's seeker cone as a wireframe: apex at the missile, axis along its drawn flight direction (the tick's velocity eased toward the next, as the curve is drawn, C-38), slant length the weapon's `lockRange` (else `range`), half-angle `MissileView.SEEKER_ANGLE` by guidance, IR 60° and RADAR 70°, until the sim gives weapons a `seekerAngle` (request 13c; the client reads it first when it exists). COMMAND guidance has no seeker and gets no cone. Drawn with the pooled line adornments: a rim of 24 segments at `pos + f · range · cos a` with radius `range · sin a` (a capped at 85°) and 8 edges from the apex; cyan (110, 220, 255) while the target's centre is inside, red (255, 60, 60) when it is outside or there is no lock. `Core/MissileView` entries gain `fx`, `fy`, `fz`, `seekerAngle`, `seekerRange`, `offNose` (degrees from the nose to the target's centre), `inSeeker`, and the label's second line ends with "34° / 60° off". `Invoke("missiles")` returns them.

**Why / measured:** the user asked to see whether a missile's target is still in its seeker (request 13c: the server has no seeker field of view, so missiles that overshoot keep their lock and come round again). `MissileView.spec` (`sam` scene, Thorn IR): every entry has seekerAngle 60, seekerRange 280 and a unit flight direction; locked ones have offNose in 0..180, `inSeeker` = offNose ≤ 60 and the angle in the label. Of 1,077 locked entries only 345 have the target inside the cone: 732 are missiles that already passed their target and still steer at it, up to 700 studs away, which is exactly what request 13c describes. Studio (`sam`, 0.25×, paused): a missile closing on the Falcon with a cyan cone ("54° / 60° off") and two overshot ones with red cones ("132° / 60° off"); the view costs 0.3 ms a frame (worst 1.2 ms) with three cones, no errors (`debug_out/screens/c42_seeker_cone.jpg`).

### C-43 — Camera follow (2026-10-21)

**Decision:** T (free: the bound keys were B E Q R S V P N - = 1-9 F3, the arrows and WASD's S) or a placeholder button "Follow (T)" next to the minimap starts and stops a camera follow. With units selected it follows the first selected unit; with nothing selected, the homing missile drawn nearest the screen centre (on screen only). `Core/Follow` (pure, Lune-tested):
- `pick(world, selection, visible, project, cx, cy)` picks the target; `position(world, fx, visible, target, t)` is where it is drawn this frame (units: Interp at the render tick on the ground plus their altitude, as UnitRenderer draws them; missiles: their entry in Effects.visible) and nil once it has ended (a unit gone from the world; a missile whose Proj table is gone, since projectile IDs are reused);
- `focus(x, y, z, pitch, yaw, groundAt)` moves the ground focus alt / tan(pitch) away from the camera so an airborne target sits on the screen's centre line, and returns the least camera distance that keeps it in front: its slant alt / sin(pitch) plus `MIN_GAP` 40 studs. Without it a SAM missile climbing past ~450 studs ended up behind the camera at the default zoom and vanished off screen.
- `Camera.update` is split into `Camera.input` (pan, rotate, drag; returns whether the player panned) and `Camera.apply` (clamp, place, rectangle, CAMERA command), and Main runs the follow between them, after units and missiles have their drawn positions for the frame, so the target doesn't lag a frame. A manual pan (arrows, middle drag, edge scroll, a minimap or group jump) stops the follow; zooming and Q / E don't. When the target ends, the camera stops where it is and keeps the distance it had.
- A follow may take the focus up to `Camera.FOLLOW_MARGIN` (400 studs) past the map's edge, since the Thorns' missiles overshoot the east edge; afterwards the camera stays there and can only move back towards the map (no jump).
- `FtggClientDebug:Invoke("follow", "toggle" | "stop"?)` returns what is followed, where it is drawn and the camera focus; `Invoke("missiles")` entries now carry their position.

**Why / measured:** the user asked to follow units and missiles with the camera. `Follow.spec`: the focus puts a jet on the screen's centre line exactly on flat ground and within 0.5° on a slope at yaw 0, 30° and -45°; a ground unit is its own focus; T picks the first selected unit the world knows, else the homing missile nearest the screen point (292 frames with a missile to pick in the `sam` scene); a followed missile's position equals Effects' drawn one until it ends (18 followed to their end), a unit ends when it leaves the world, a reused projectile ID doesn't count as the missile. Studio (`sam`, 0.25×): following the Falcon kept it at the viewport centre (774, 317 of 1548 × 634) in six samples around its circle, zooming kept the follow, an arrow-key pan stopped it and left the camera where it was; following a Thorn missile kept it at the centre for 30 samples over its whole flight, including 55 studs past the map's east edge, with the camera at least 322 studs from it, and the camera stayed at (694, 150) after the missile ended; the button starts and stops it and reads "Stop follow (T): Falcon" / "missile"; frame 0.32 ms, no errors (`debug_out/screens/c43_follow_falcon.jpg`, `c43_follow_missile.jpg`).

### C-44 — Client missiles steer with the shared guidance (2026-10-21)

**Decision:** with the merge of S-27 / S-28 (protocol 11) the client's projectile step (`Core/Effects` `advance`, used for stepping, the drawn curve's next state and `predict`) steers homing weapons with `Shared/Combat/Guidance` as contract section 7 says: missiles `Guidance.pn` against the target's centre where it was when the tick's step starts (Interp at t − 1), with its velocity over the tick; torpedoes `Guidance.lead` against its end-of-tick position. A DECOYED record's decoy point and ticks make the missile follow the flare or chaff with `Guidance.decoy` (stopping when it leaves the seeker cone or the ticks run out), as the server does. The sensor view's seeker angle is `Guidance.seekerAngle(weapon)`. `Effects.predict` now extrapolates a target past its last snapshot along its turn (heading rate over its last two snapshots) instead of straight on, since proportional navigation reacts to the target's turn. The view's yellow aim point is still the straight-line intercept estimate (`Effects.aim`); PN has no single point it steers at.

**Why / measured:** the server switched to proportional navigation and the client's lead pursuit drifted (5-tick prediction median 10.2 studs, 3 client specs failing). Now, `sam` scene: the client's stepped missile is a median 0.04 studs from the server's (90th percentile 0.06, worst 0.39); 5-tick predictions median 1.27 studs, 90th percentile 3.3 (lead pursuit before S-27: 2.2 / 11); 298 of 298 locked entries keep the target inside the seeker cone (the server breaks the lock on an overshoot); missile curves bend 0.039 studs a frame on average, 0.074 at tick boundaries, worst 0.50 (the boundary test now accepts up to 0.1 studs: the mean halved, so the old 1.5× ratio was stricter than C-38 meant). SIGHT_ROWS / SIGHT_CELLS / WRECK / WRECK_GONE are decoded by Schema and ignored by the client for now (requests 9 and 10 are done on the server; adopting them is open).

### C-45 — Moving units without the MOVING bit (2026-10-21)

**Decision:** the server never sets `Schema.UnitState.MOVING` (nothing in `src/server` writes it), so every unit looked idle and `Waypoints` dropped each move line `IDLE_SECONDS` (2 s) after the order. The client now tells movement itself: NetIn stamps `movedTick` whenever a unit's position or heading changes (tactical records every tick it moves; strategic snapshots at cell precision, carried across snapshots and into ENTER), and `World.moving(world, u)` is the MOVING bit or a change within `World.MOVING_TICKS` (tactical 2 ticks, strategic 16). `Waypoints` and the piece scripts' StartMoving / StopMoving use it. Interp's one-tick extrapolation keeps the MOVING bit only: the server sends nothing when a unit stops, so extrapolating from `movedTick` would leave a stopped unit drawn a tick past where it stopped. Aircraft reach their point at `Waypoints.AIR_REACH` = the server's `Air.LOITER_RADIUS` (220 studs, tested equal): the server counts a jet as arrived there and circles from then on. Request 14 asks the sim to set the bit.

**Why / measured:** the user saw an airplane's green move line vanish after 2 seconds. `Moving.spec`: a Lancer driving 400 studs is moving on all 173 ticks of the way and keeps its line until it arrives (tick 178, line gone at 192); a Falcon flying 960 studs keeps its line for all 43 ticks until it arrives at the loiter radius (tick 48), longer than the old 2 s timeout; with the old MOVING check both cases fail. Studio (`sam`, 0.25×): a Falcon's line lasted 7 s until arrival (`debug_out/screens/c45_falcon_move_line.jpg`).

### C-46 — Missiles past the map's edge (2026-10-21)

**Decision:** wire positions are clamped to the map (`Grid.encode`), so a missile that ends past the edge (a self-destruct at the end of its life after a miss) got its IMPACT on the edge and exploded there, away from the drawn missile; a correction or DECOYED / LOST_LOCK record past the edge would likewise pull it back. `Effects.unclamp(world, p, x, z)`: on an axis where the record sits on the clamp and the client's prediction is already beyond it on that side, keep the prediction. Applied to IMPACT, DECOYED / LOST_LOCK and homing corrections. Units past the edge (a jet's turn can carry it ~14 studs out) are still drawn on it; request 15 asks the sim to keep jets inside or carry off-map positions.

**Why / measured:** the user saw missiles "bug out" when the jet flew off the map. Before S-27 missiles looped past the edge and were corrected back onto it (in a Lune run, server x = 673, client corrected to 640); since S-27 they lose their lock instead, and the server sends no corrections that far out, but their end-of-life IMPACTs still land on the edge. `OffMap.spec` (the old `sam` layout with moveTo 420): 156 missile ticks past the edge, at most 0.12 studs from the server, none drawn on the edge; 8 explosions past the edge all drawn there (without the fix all 8 were on the edge).

### C-47 — Detailed combat effects, with a hook for effects made in Studio (2026-10-21)

**Decision:** combat effects are rebuilt in a new `Render/Vfx` (the user asked for a bigger IR missile explosion and more detailed gunshot, explosion and missile-flight effects). Each burst plays a pooled rig: an invisible carrier with particle emitters (Studio's built-in particle textures, Emit only), a light and a few animated parts, reused once its longest particles are gone (at a pool's cap the oldest is taken).
- **Explosions** (impacts, deaths): a hot core flash, a fireball, sparks under gravity, rising grey smoke, a short orange light; ground bursts (within ~4 studs of the ground) add dust thrown out along the ground, an expanding dust ring and a scorch mark that fades over 14 s; air bursts add a spherical shockwave. Deaths add tumbling debris and long dark smoke. The size follows the weapon's blast radius (`aoe`): scale = burst diameter / 7, capped at 6, so a bigger `aoe` (request 16) gives a bigger explosion with no client change.
- **Gunshots:** a star flash, a short flame jet and a puff of smoke at the muzzle along the shot; tracers are glowing streaks that fly from the muzzle to the end point over the tracer's life, with sparks where a hit lands.
- **Missiles:** a launch flash, backblast and a smoke cloud (plus dust on the ground) when a homing weapon fires, and billowing smoke puffs (110 a second, growing 2 → 7 studs, lingering 2–3 s) on top of the smoke trail. A decoyed missile's flares (IR) fall burning with smoke trails at the decoy point the server sends (S-28); chaff (radar) is a glittering cloud.
- Effects run on the sim clock: particle `TimeScale` and the rigs' animations follow the global sim speed (C-35, at most 1), so a slowed or paused playtest slows or freezes explosions and smoke (trails still fade in real time). This also makes paused screenshots possible.
- **Templates:** an effect saved in the place as `ReplicatedStorage.Vfx.<Name>` replaces the built-in one: Impact, Death, MuzzleFlash, Hit, Launch, Decoy, Flare, Chaff (`Vfx.TEMPLATE_NAMES`). It may be an Attachment, a Part or Model, or a Folder of Attachments holding ParticleEmitters and PointLights; each emitter emits its `EmitCount` attribute (on it or on the template, default 10) after `EmitDelay` seconds, an emitter saved Enabled without EmitCount runs for `EmitDuration` (0.2 s), lights flash and fade over `LightSeconds` (0.25 s), sizes and speeds scale with the blast like the built-in effects, and it faces the shot or flight with its −Z. Templates are looked up on every burst, so an effect added during a playtest shows at once. Meant for effects the user builds with the VFX Studio plugin.
- `Core/Effects` bursts now carry `ground` and a facing (`dx, dy, dz`); a homing weapon's SPAWN_PROJ makes a `launch` burst instead of a muzzle flash, and a DECOYED with a decoy point adds a `flare` / `chaff` burst there. `Invoke("fx").vfx` reports spawns, template uses and stolen rigs.

**Why / measured:** `Effects.spec` (`ew_test`): launch, flare, impact, death and muzzle bursts all appear with their ground height and a unit facing, and the flares sit at the server's decoy point. Studio (`sam` and a 4-against-4 tank fight, paused for the shots): SAM launch clouds and a continuous smoke trail to a fireball on the Falcon (`debug_out/screens/c47_sam_launch_smoke_airburst.jpg`, `c47_airburst_closeup.jpg`), shell hits with fireballs, sparks and dust (`c47_shell_hits.jpg`), a tank death with debris and smoke (`c47_tank_death.jpg`), flares after a decoy (`c47_flares.jpg`); a temporary green `ReplicatedStorage.Vfx.Impact` made in the playtest replaced all 12 following impacts (`c47_template_hook_test.jpg`). Effects cost 0.06 ms a frame on average (5.4 ms worst, when the first rigs are built); no errors. The first smoke used `explosion01_smoke`, which renders as an opaque black blob; it now uses `smoke_main`. The scene dump no longer sees burst particles (only the flash ball, tracers and shells).

### C-48 — Aircraft crash, countermeasures by equipment, deaths on the sim clock (2026-10-21)

**Decision:**
- **Air deaths:** an aircraft that dies more than 3 studs up falls out of the sky (`Core/Deaths.crash` / `crashAt`): jets keep their momentum (velocity from the last two snapshots, now on `World.Death` with the altitude), dive nose-first under 45 studs/s² with drag and roll; helicopters drop under 35 studs/s², spinning (7 rad/s) and tipping. The path is fixed by the death record and the unit ID (Shared Prng), so the model (`Render/Deaths`, burning with flames and a smoke trail) and the ground explosion (`Core/Effects`, a death burst 1.3× bigger at the crash point when the fall ends) agree on where and when it hits. Aircraft leave no wreck on the client, whatever the DEATH's `wreckId` says (request 19 asks the server to stop making them). A landed aircraft dies like a ground unit.
- **Deaths on the render clock:** every death animation (shake, fling, crash) now runs on sim seconds (render tick / 15) instead of real time, so it slows down and pauses with the sim like the effects (C-47); the crash's ground burst is scheduled on the same clock. Crash flames and smoke take the sim speed's TimeScale.
- **Countermeasures by equipment:** the DECOYED record doesn't say what seduced the missile (request 18), so `Effects.countermeasure` follows the server's order (EW): radar missiles meet chaff (a cloud at the decoy point); IR missiles meet DIRCM first, then flares, so an aircraft with DIRCM and no flares (the Falcon, the Archon, the Guardian helicopter) is drawn jamming the missile with a red laser from the aircraft to the drawn missile and a glint on it (`dircm` burst, 0.45 s), and one with flares (Wasp and Manticore, with or without DIRCM) is drawn dropping flares from the aircraft that fan out toward the decoy point the missile went for, then fall burning. Before, every IR decoy drew flares at the decoy point, also on aircraft that carry none.
- Also merged `main` (S-29 overkill-aware targeting, S-30, S-31, S-32 line of fire): the SAM prediction spec now sees ~95 predictions instead of 100+ (fewer missiles at one jet), so its sample floor is 60.

**Why / measured:** the user saw air units leave wrecks and asked for them to fall, crash and explode; and asked about chaff / flares on helicopters. `Deaths.spec`: a Falcon dying 110 studs up at 200 studs/s falls for 1–4 s, hits the ground more than 100 studs ahead, nose down and rolling, the same way each time; a Wasp spins more than 3 radians on the way down and lands within 20 studs; ground units and landed aircraft don't fall; the ground explosion comes only when the fall ends, at the crash point. `Effects.spec`: Falcon / Guardian against IR → DIRCM, Wasp → flares, radar → chaff, unknown contact → flares; in `ew_test` the decoy is drawn as a DIRCM laser ending on the missile. Studio (`air` profile, 0.1–0.25×): an Archon's red jammer laser on an incoming missile (`debug_out/screens/c48_dircm_laser.jpg`); a killed Archon (a small overkill, so the server left a wreck) diving and rolling with a long smoke trail (`c48_jet_falling.jpg`), then exploding on the ground ~70 studs further on (`c48_crash_explosion.jpg`), no wreck drawn; a killed Guardian crashed the same way; no errors. Flares from a Chaos aircraft didn't come up in the playtest (the Order side fired few IR missiles at them); the flare path is covered by the Lune test.

### C-49 — Health bars change with the hit (2026-10-21)

**Decision:** a State record's health applied the moment it arrived, while the render clock (and so the drawn missile and its explosion) runs ~2 ticks behind the newest record: bars dropped before the hit was drawn, 0.5 s early at 0.25× (the user: "damage gets dealt before the projectile hits"). NetIn now keeps the latest health in `health` and logs each change with its tick (`healthLog`); `World.settle(world, renderTick)`, called each frame right after the render clock advances, moves `shownHealth` up to the render tick, and `Bars` draws `World.shownHealth` (the latest when a world never settles, as in the older Lune specs). Separately, the `airsam` profile drops its 3× health: the wire's health is a fraction of the def's maximum (u8), so a unit above it shows a full bar until it falls below it (the MatchConfig header says so), which looked like "the plane takes no damage". The `sam` profile's Falcon (5×) has the same caveat.

**Why / measured:** `HealthTiming.spec` (SAMs against four Falcons, rendering 2 ticks behind): 8 bar drops, none before its hit's tick and none more than a tick after one; with the old immediate update 4 of 8 dropped before their hit. A headless check of the old 3× Falcon: 5 hits took it from 1,560 to 560 HP with the bar at 1.00 throughout. Studio (`airsam`, normal health): the selected Falcons' bars read 23% and 38% after SAM hits; no errors.

### C-50 — A missile keeps its dying target until the hit is drawn (2026-10-21)

**Decision:** a DEATH record removed its unit from the client world the moment it arrived, ~2 ticks before the render clock reached the hit that killed it. A missile drawn on its way in then lost its target: the sensor view said "IR no lock", the client's guidance stopped steering, the missile flew straight past the jet, and only then the explosion and the death played (the user saw exactly that on low-health aircraft). NetIn now keeps the dead unit in `world.dying` with its death tick, `World.settle` drops it once the render clock passes that tick, and `World.unitOrDying(world, id)` is what missile guidance (`Effects.advance`, `predict`, `aim`, the DECOYED handler) and the missile sensor view use for a projectile's target.

**Missile damage spread (the user asked whether it is inconsistent):** by design (D97). A SAM missile's proximity fuse bursts at its closest approach and deals area damage falling off with distance (`Combat.explode`, the weapon's `edgeEffectiveness`): a Thorn missile does 200 at the hull and 100 at its 5-stud fuse edge, so hits land anywhere between (a headless run showed 200s and a 150). Missiles that are jammed or decoyed explode harmlessly at the end of their life.

**Why / measured:** `DyingTarget.spec` (four Falcons at 20 HP, so one hit kills, rendering 2 ticks behind): 4 kills, 16 frames of killing missiles still flying, none with the target gone; without the fix 8 of 16 were "no lock". Studio (`airsam`): kills and crash explosions, no errors.

### C-51 — Following the sim's answers to requests 14–19 (2026-10-21)

**Decision:** with the merge of S-33 and S-38 (protocol 13):
- **Jet arrival (request 17):** `Waypoints` mirrors `Air.steerJet`: an aircraft's move point is reached within `AIR_REACH` = `Air.ARRIVE_RADIUS` (40), or once the point, having been ahead of the aircraft, falls behind it within `AIR_PASS` = `Air.LOITER_RADIUS` (220); `approached` on the point remembers it was ahead. Both constants are tested equal to the server's.
- **Countermeasure (request 18):** `Effects.countermeasure` takes DECOYED's `countermeasure` (Schema.Countermeasure) first; the equipment guess (C-48) remains for records without it.
- **Edge (request 15, partly):** projectiles now burst on the map's edge on the server, so `Effects.unclamp` (C-46) is removed: it could only misplace an edge burst by the client's own prediction. Aircraft still turn back 60 studs inside and may be drawn on the edge for a few ticks; accepted for now.
- **MOVING (request 14):** the server sets the bit; `World.moving` keeps the position fallback (C-45), now redundant but harmless. Air wrecks (request 19) and the Thorn's numbers (request 16) need nothing: the client already ignored air wrecks and reads the defs.
- Specs follow the new numbers from the defs (fuse 12, lock range 420) instead of pinned values; the missile view's HIT / miss check leaves out missiles a countermeasure decided (all 12 of its "wrong" calls after the merge were decoys or jammed missiles; 59 right, 0 wrong without them).

**Why / measured:** `Moving.spec`: a jet ordered far ahead and one ordered to a point inside its turn circle both lose their line within a tick of the server ending the order (ticks 48 / 49 and 11 / 12); `OffMap.spec`: 10 missiles burst on the edge, none drawn more than a tick past it. Studio (`airsam`): a Falcon ordered to a point 117 studs off its nose turned to it, passed 93 studs away (the closest it can turn), the line went then, and it settled into a 225-stud circle around the point; a far order kept its line while flying (`debug_out/screens/c51_jet_move_line.jpg`).

### C-52 — Crashes leave their smoke; radar SAM missiles drawn big (2026-10-21)

**Decision:**
- A crashed aircraft (C-48) stays `Deaths.CRASH_LINGER` (3 sim seconds) after it hits: `crashAt` lets it go on falling under the ground out of sight, and Render/Deaths turns its flame and smoke emitters off at the hit instead of destroying them. Destroying them with the model had wiped the whole smoke trail at once (particles belong to their emitter). The ground explosion still comes at the hit.
- Radar SAM missiles (the `smoke_thick` trail style) are drawn at 2.3× an IR missile (was 1.3×), with a 2.6 s trail and 4.5 s puffs; their exhaust light grows with √scale so it doesn't wash the bigger body out. Weapons whose `fx.impact` is a `..._large` effect explode 1.8× bigger than their `aoe` alone gives (`Effects.impactSize`), since the radar SAM's `aoe` (8) is now below the IR Thorn's (12). Vertical launch and a bigger radar `aoe` are the sim's (request 20, replacing 12); the user chose to leave that to A.

**Why / measured:** the user asked for all three. `Deaths.spec`: a crashed jet is more than 5 studs under the ground a second after its hit; `Effects.spec`: a radar SAM's explosion is bigger than an IR one's. Studio (`airsam`): a Wyvern missile next to the Thorns' (`debug_out/screens/c52_radar_sam_missile.jpg`); a shot-down Archon's explosion with its smoke trail still in the air and the model gone under the ground (`c52_crash_smoke_stays.jpg`); no errors.

### C-53 — Steering vertical-launch missiles (2026-10-21)

**Decision:** with S-42 (request 20) the radar SAM weapons have `launch = "vertical"`: the missile spawns straight up and the server steers it with `Guidance.vertical` (turning toward the target at 3× its turnRate until the target is within 15° of the nose, then proportional navigation), keeping a per-missile `turned` flag. The client's `steer` (Core/Effects, used for stepping, the drawn curve's next state and `predict`) does the same for those weapons and keeps `turned` on the projectile. A homing correction doesn't carry the flag, so when one arrives with the target already within the 15° cone of its velocity the client marks the missile turned, since the server would have handed over by then.

**Why / measured:** `VerticalLaunch.spec` (two Wyverns against three Falcons, with a Lancer in sight of the sites, since projectiles only reach a client in its side's sight, D99): 10 launches, all going up when first drawn and all pitching over; the client's missiles are a median 0.04 studs from the server's (90th percentile 0.06); steering them with plain PN instead puts the 90th percentile at 15 studs. Studio (`airsam` with a temporary spotter tank next to the Wyverns): a Wyvern missile climbing out of its launcher in a column of smoke, starting its pitch-over (`debug_out/screens/c53_vertical_launch.jpg`).

### C-54 — Projectiles without line of sight; SHOT tracers (2026-10-21)

**Decision:** with S-43 (request 21, protocol 14) the server sends SPAWN_PROJ, homing corrections and IMPACT for every projectile in the player's camera area whatever its team sees, and a hitscan shot from a shooter the player doesn't have arrives as `SHOT` (`hit`, a start pos and an end pos; no shooter or target ID). The client needed nothing for projectiles (it draws them from SPAWN_PROJ alone, matching a launcher only if it has one). `Core/Effects` draws SHOT as a tracer from the start point to the end point, with hit sparks as usual but no muzzle flash, so a hidden gunner's position doesn't light up; only the tracer shows where the shot came from, as the user asked ("only render the projectile, not revealing the shooters").

**Why / measured:** `Shot.spec`: a gunner outside Order's sight shooting an Order tank gives the client one tracer from the gunner's position to the hit, no muzzle flash, and the gunner never in the client's world. `DyingTarget.spec` now sees out-of-sight missiles too, so it keys "the killing missile" by server events (a SPAWN_PROJ clears a reused ID): 8 frames, none with the target gone (8 of 8 without C-50). Studio (`airsam`, no spotter): a Wyvern's vertical launch drawn climbing out of its launcher while the Wyvern itself has no model (only the radar dot the team's long-range radars give it) (`debug_out/screens/c54_unseen_launch.jpg`), the check sim-A asked for.

### C-55 — The vertical launch's climb (2026-10-21)

**Decision:** with S-44 (request 22) a vertical launch flies straight up, unsteered, while it has no horizontal velocity and is less than the weapon's `climbHeight` above the ground (`Guidance.climbLeft` with `Layers.heightAt`, the cell height the server's `Combat.groundHeight` now uses), then pitches over as before. The client's `steer` passes the same `climbLeft`, computed on `Layers.heightAt` (not the smoothed `Terrain.groundY`, which would move the turn-over tick). S-45 (request 23: radar SAM range ×3) needs nothing on the client.

**Why / measured:** `VerticalLaunch.spec` (two Wyverns, three Falcons): 16 launches, none moving sideways below `climbHeight` less one tick's climb (the lowest turn started 130 studs up with `climbHeight` 100), client a median 0.04 studs from the server (90th percentile 0.06); without the client's climb the 90th percentile is 6.3 studs and it fails. Studio (`airsam`): a Wyvern missile still vertical at 98 studs above a straight smoke column (`debug_out/screens/c55_vertical_climb.jpg`).

### C-56 — Showing SAM missile stock (2026-10-21)

**Decision:** with S-47 (request 25, protocol 15) own units' State records carry STOCK (missiles in stock per stockpile slot). NetIn keeps it per slot on the unit (`stock`); `World.stockOf` sums it with the defs' derived `stockCapacity`. `Bars` carries `stock` / `stockMax` for own units and shows the bar of a unit that isn't full, so a refilling site stays visible; `HealthBars` draws one pip per missile above the health bar (amber in stock, dark spent), a single bar past 10. Stock applies on arrival: unlike health (C-49) it has no hit to line up with.

**Why / measured:** `Stock.spec` (an own Vigil under three enemy Harpies, an enemy Thorn in view): the client's count equals the server's on every tick over 60 s while it drops from 8 to 0 and refills three times, the Vigil's bar is listed on every tick it isn't full, and the enemy Thorn never carries a stock on the client. Studio (`airsam` plus two Vigils and two Harpies): 7 of 8 pips lit after a shot each, the economy showing the refill drain (`debug_out/screens/c56_sam_stock_pips.jpg`).

### C-57 — Nukes, interceptors and the attack order (2026-10-21)

**Decision:** with S-48 (request 26, protocol 16):
- **Interceptors** (INTERCEPTOR, the SPAWN_PROJ layout with the strategic missile's projId as target) chase the client's own copy of that missile (`chase`), steered by `Guidance.vertical` / `pn` against its state at the tick's start, as the server does. So `Core/Effects` now steps every projectile from the tick's start states first and applies the steps after. INTERCEPTED removes the missile with a small burst in the air; an interceptor whose missile is gone flies on to its lifetime.
- **Nukes** (strategic weapons) are drawn as a missile at 4.5× an IR one with a heavy trail (`smoke_huge`). Their IMPACT is a "nuke" burst the size of `aoe`: flash, fireball, a stem and a mushroom cap that climb for 6–10 s, dust thrown out along the ground, a shockwave ring out to ~3× the blast and a wide scorch (`Render/Vfx`, sizes for a 150-stud blast, scaled by aoe / 150). A detonation in view whites out the screen for 1.2 s.
- **Launch warning** (`Render/NukeWarning`): while a strategic missile flies, a blinking banner "NUCLEAR LAUNCH DETECTED - impact in N s", a red ring where it was launched and a pulsing red ring of its blast radius with a cross where it will land. The landing comes from the missile's own state (`Effects.landing`: gravity steps until it is under `Layers.heightAt`, interpolated along the last step). The warning is raised by LAUNCH_WARNING or by the missile's own SPAWN_PROJ (which every player gets), one per launch: LAUNCH_WARNING only comes on the launch tick, so a player who joins while a nuke flies would otherwise get none (seen in Studio: the `nuke` profile's silo fires before the playtest client has joined).
- **Attack order (BAR's A key):** press A with units selected, then left-click an enemy unit (ATTACK) or the ground (ATTACK_GROUND); Shift keeps the mode for more clicks, right click cancels; a hint shows while it is on. A silo fires its nuke on an attack-ground order (one launch per order). The silo's stock already shows as pips (C-56).
- **`nuke` test profile** (MatchConfig; spawns take `fireAt = { x, z }`, an attack-ground order at match start): the Chaos Ragnarok fires at your base as the match starts, against 2 Aegis; your Reckoning (2 nukes) against the Chaos base with 2 Wyverns.

**Why / measured:** `Nuke.spec`: an undefended nuke gets exactly one warning, the predicted landing is 0.9 studs from the detonation, and the "nuke" burst's radius is the weapon's aoe; with 2 Wyverns defending, 2 interceptors chase it for 92 frames a median 0.05 studs from the server's (90th percentile 0.07) and the nuke is intercepted, not detonated, as the server says. Studio (`nuke` profile): both Aegis interceptors meeting the climbing Chaos nuke and bursting it (`debug_out/screens/c57_chase.jpg`); A + left click on the Chaos base launched your nuke, with the banner counting down and the blast ring and cross over the Ravagers while the Wyverns' interceptors climb (`c57_warning.jpg`); it was intercepted too. No errors. **Not yet seen in Studio:** a detonation (the mushroom cloud and screen flash), since both nukes were shot down before the user needed Studio back.

### C-58 — Attack-mode arc preview; radar tracks on nukes (2026-10-21)

**Decision:**
- **Arc preview:** while the A key's attack mode is on, each selected unit with a lofted weapon (a silo, S-48; at most 4) shows the arc its shot would fly to the point under the cursor (dashed orange, grey out of range), the blast ring there and a label: flight time and stock, or "empty: fires when built" (an attack-ground order on an empty silo waits and launches as soon as the next nuke is built). `Core/AttackPreview` mirrors the server's lofted launch (Weapons.fire): from the unit's position at `Combat.MUZZLE_HEIGHT` (0.6) of its height, up at sqrt(2 g apex), across at the speed that lands it on the spot. The flight path is that physics arc, not a Bezier curve; its height is the weapon's `apex`, which is the sim's (request 27a asks for 300 with gravity 15, same 12.7 s flight, so it stays on screen).
- **Radar tracks (the user: "the missile is large and slow moving so the RADAR should have no trouble tracking it"):** the sensor view (N) draws, for each strategic missile in view, a line from every known radar SAM site of the other side that would engage it (an `intercepts` weapon with the missile within its range horizontally: Targeting's rule; these sites' radars reach that far) and labels it "NUKE  RADAR TRACK xN", the time to impact and the interceptors up. Tracks are never shown as lost. Interceptors show "RADAR LOCK NUKE" with distance, time to go at the closing speed and the seeker angle (they read "no lock" before: their target is a projectile). The launch banner adds "N radars tracking" (on your own nuke: the enemy radars you know of). Which side launched is not on the wire: a strategic missile is the local team's when one of its strategic launchers stands at the launch point (`Effects.ownLauncherAt`, 24 studs; the server launches from the silo's position and own units are always known). Enemy sites count only while the client knows them (in sight or the camera's tactical tier).
- **The silo "stopped building" (the user, after 3 launches):** headless with the `nuke` profile's economy it doesn't stop (6 launches, each rebuilt in 120 s), but at sim speed 0.25 a rebuild takes 8 real minutes and STOCK only carries whole missiles; request 27b asks for build progress on the wire so the pips can fill as a nuke is built.

**Why / measured:** `AttackPreview.spec`: the previewed arc against the server's nuke: 12.69 s vs 12.67 s in the air, apex 821 both, worst height gap 0.00 studs. `Nuke.spec` (2 Wyverns and a spotter): the client knows the nuke is its own, both Wyverns show as tracking it, and the interceptors read locked on it in 92 of 92 frames. Studio (`nuke` profile): the preview arc, blast ring and "impact in 12.7 s - 2 in stock" (`debug_out/screens/c58_attack_preview.jpg`; the arc leaves the top of the screen, request 27a); the Chaos nuke with "RADAR TRACK x2", track lines from both Aegis, two interceptors locked on it and the banner "2 radars tracking" (`c58_radar_tracks.jpg`). No errors.

### C-59 — The missile being built (2026-10-21)

**Decision:** with S-49 (request 27, protocol 17) each STOCK entry carries the next missile's build progress (u8), sent when a count changes or the progress crosses a sixteenth. NetIn keeps it per slot with the record's tick (`stockProgress`); `World.stockProgressOf` grows it at 1 / buildTime per second from there, capped at the next sixteenth so a stalled economy stops it within a step (the cap allows one u8 step of rounding: a record sent on crossing a sixteenth reads just under it, 31/255 < 2/16). The first stockpile slot that isn't full counts. The next pip fills from the left with it (or the single bar past 10 pips grows by it). S-49's lower nuke arc (apex 300, gravity 15, same 12.7 s) needs nothing on the client: flight, arc preview and landing read the def.

**Why / measured:** `StockProgress.spec` (a silo rebuilding a nuke with the `nuke` profile's economy, 60 s): 8 progress records, the client's progress within 0.003 of the server's on all 900 frames (0.0625 before the rounding allowance), and the silo's bar carries it. Studio: the silo's first pip half filled amber after a launch (`debug_out/screens/c59_stock_progress_pip.jpg`).

### C-60 — Test-only weapon overrides (2026-10-21)

**Decision:** a match profile may set `weaponOverrides` (MatchConfig): the server entry (`src/roblox/Main.server.luau`) runs a copy of the registry's defs with those weapon fields merged in. Only numbers no client simulates can be overridden: an existing stockpile's `buildTime` and `cost`, `intercepts.chance`, and `reload` (added later the same day: the user wanted silos to launch again 2 s after a launch; a silo fires with 1 nuke in stock, but the 10 s reload ran out together with the test's 10 s rebuild, so it looked as if it needed 2; Studio: two orders launched 31 ticks apart); anything else is an error at startup. The copy keeps the registry's defs hash so clients still join (their defs keep the registry's numbers, which only the stock pip's animation between records reads; the server's progress records correct it every sixteenth). Each override is printed at startup. The `nuke` profile uses it for the user's test: nukes cost 1 supply and 1 power and build in 10 s, radar SAM interceptors kill with chance 0.2 (0.5 in the defs). The defs themselves stay the sim's.

**Why / measured:** Studio (`nuke` profile): the four overrides printed at startup; with 2 nukes in stock fired 10 s apart, a third order 30 s later launched within 5 ticks (with the registry's 120 s the silo would have been empty for minutes); the economy showed the 0.1/s drain of a 1-supply nuke. No errors.

### C-61 — One launch notice (2026-10-21)

**Decision:** the warning banner says only "NUCLEAR LAUNCH DETECTED" while any nuke flies, however many (the user: "just a notice is fine, in case multiple nukes are present"). It no longer shows the time to impact (C-57) or the radars tracking (C-58); both stay in the sensor view (N). The launch markers and blast rings on the ground stay, one per nuke.

**Why / measured:** Studio (`nuke` profile): with the Chaos nuke and one of yours in the air, the banner text is exactly "NUCLEAR LAUNCH DETECTED". No errors.

### C-62 — Nukes climb, then turn (2026-10-21)

**Decision:** with S-51 (request 28, protocol 18) a strategic missile arrives as SPAWN_STRATEGIC with its goal (the ordered spot) and flies Shared/Combat/Lofted: straight up at `projectileSpeed` to `climbHeight`, a pitch-over at `turnRate` toward the lofted arc that peaks `apex` above the goal, then ballistic. `Core/Effects` keeps the goal on the projectile and steps it with `Lofted.step` (climb measured on `Layers.heightAt`, as the server); an early spawn is stepped back without gravity (its first tick is the boost). `Effects.landing` and the attack-mode preview (C-58) run the same steps forward: the preview now simulates the launch from the silo (boost, turn, arc) instead of the old parabola, drawing every third tick.

**Why / measured:** `AttackPreview.spec`: the previewed path against the server's nuke, 64 points every third tick, worst 0.00 studs; 12.82 s vs 12.80 s; apex 310 both; it leans over at 139 studs. `Nuke.spec`: the drawn nuke within 0.07 studs of the server's over 192 frames; the landing predicted 0.0 studs from the detonation; interceptors still in step (median 0.05) and locked. Studio (`nuke` profile): the Chaos nuke's trail rising straight out of its silo and hooking over toward your base (`debug_out/screens/c62_nuke_boost_turn.jpg`). No errors.

### C-63 — Radar facilities always show their range (2026-10-21)

**Decision:** the team's own radar facilities show their radar ring whether or not they are selected and whatever the V toggle (the user: "radar facility (unit or tower) must always show a green circle, selected or not"). A radar facility is a def with a radar and no weapons: radar towers, mobile radars, the AWACS; radar SAM sites have weapons and don't count. `Ranges.radarFacilities` lists them (tactical tier: units outside the camera's area carry no def); RangeOverlay looks them up every MIN_INTERVAL, adds their positions to its rebuild key and draws them as their own kind, `radarFacility`: radar green, 1.5 studs wide (selected rings are 0.3) so they read at the zoom a battle is watched from. Overlapping facilities merge into one outline; the rings follow mobile radars between rebuilds like any ring.

**Why / measured:** `Ranges.spec`: an own Beacon and Oracle give two rings with their radar radii; an own Aegis (radar SAM site), an own Lancer and an enemy radar tower in sight give none. Studio (`normandy`): with nothing selected, the overlay draws the `radarFacility` outline of the 4 radar facilities in view (2 Beacons, the Oracles), arcs across the bocage (`debug_out/screens/c63_radar_rings.jpg`). The range overlay's debug query now reports its lines by kind.

### C-64 — Radar rings on top (2026-10-21)

**Decision:** the always-on radar facility rings (C-63) are drawn by their own renderer, `Render/RadarRings`, with always-on-top line adornments on the Terrain (the user: "use the AlwaysOnTop for things like radar range"), instead of the range overlay's Neon parts laid on the ground: hills and hedgerows no longer hide them and they keep 6 px at any zoom (bright green, 0.1 transparency). Same outline as before (Ranges.radarFacilities, union, polylines), rebuilt at most 4 times a second when a facility appears, goes or moves 4 studs. The range overlay's selection rings are unchanged.

**Why / measured:** Studio (`normandy`, nothing selected): 115 segments, the merged outline of the radar facilities in view crossing the bocage over the hedgerows (`debug_out/screens/c64_radar_rings_on_top.jpg`); the 3 px / 0.3 first try was there but too faint against the pale ground. `Ranges.spec` unchanged (7 passing).

### C-65 — The server's sight map and wreck records (2026-10-22)

**Decision:** the client reads protocol 10's SIGHT_ROWS / SIGHT_CELLS and WRECK / WRECK_GONE (S-26, requests 9 and 10):
- **Sight:** NetIn keeps the ally team's sight (`world.sight`: a byte per sensor cell, rows wholesale or changed cells); `Core/Vision` takes it in as the fog's `seen` / `changed` / `version` and no longer stamps sight from the own units (C-32's rebuild, its remembered defs and held emitters are gone). Allied players' units count, and own units outside the camera no longer cost edge cells. The fog darkening itself stays off (`FogOfWar.ENABLED`, the user's earlier call); ghosts and contacts are unchanged.
- **Wrecks:** NetIn keeps the team's wrecks (`world.wrecks`, with WRECK / WRECK_GONE queues; a DEATH that left one marks it in `deathWrecks`). `Render/Deaths.syncWrecks` places a wreck the client didn't see die (on join, off camera) from its record (the unit renderer's root frame: ground, heading + π, the model's RootOffset), removes a reclaimed one, and leaves a recent death's wreck to its own animation (DEATH_WAIT 30 ticks). Wrecks no longer stay until the match restarts.

**Why / measured:** `Vision.spec`: the client's map equals the server's `los` on every sensor tick: 98 of 98 with the units in the camera, 85 of 85 after the camera moves away (was 90% exact, up to 60 cells off), and 98 of 98 with an allied player's scout adding its sight. `Wrecks.spec`: a wreck appears with its def and spot and is marked as its death's, a client joining after the death gets it with no DEATH of its own, and it goes when a Mason reclaims it. Studio (`normandy`, Order's tanks sent east): 122 sight updates in 15 s with the seen cells following the advance, then wrecks on the front (34 standing; `debug_out/screens/c65_wrecks.jpg`). The fog debug query now reports the sight version, seen cells and standing wrecks.

### C-66 — Terrain from the sim's terrain layer; Normandy's features (2026-10-22)

**Decision:** the drawn ground's material is the sim's terrain type of the cell (`Layers.terrain`, S-37: grass, rock, sand, road as Asphalt), so ground drawn as sand or road is where units slow down or speed up; the client's own rules (rock where steeper than ~50°, sand near water) are gone. A hand-made map can pass its feature function (`Core/Terrain.material(layers, x, z, feature)`): on `map:normandy`, `Normandy.feature` gives hedgerows LeafyGrass, roads Asphalt, bridges WoodPlanks, the beach sand, the bluffs rock and the draws Ground; house cells are Ground under brick houses with slate roofs built as parts (one block per connected group of house cells, as high as the cells, on the street level around them, with a two-wedge roof). Main passes the feature for `map:normandy` only.

**Why / measured:** `Terrain.spec`: on Normandy every cell's kind is its terrain type (47,586 grass, 1,830 rock, 13,320 sand, 2,800 road), and its features map to their materials. Studio (`normandy`): terrain built in 3.2 s (1.1 s of CPU), 24 houses; a village with asphalt streets, houses and leafy hedgerows (`debug_out/screens/c66_village.jpg`); a plank bridge carrying the road over the river (`c66_bridge.jpg`).

### C-67 — A unique icon per unit type (2026-10-22)

**Decision:** with S-58 (request 35, protocol 19) a strategic record's icon is its unit's def index, so the client knows every unit type behind an icon. Each type's icon (the user: "every type of unit needs its own unique icon") is its family's shape (structure frame, air triangle, naval diamond, builder circle, else square; unchanged) with a two-letter code inside, generated from its name and unique over all 126 unit types (`Icons.codes`: a two-word name's initials, else its first letter with a later one, else a digit; e.g. Ln Lancer, Rv Ravager, Pa Paladin, Ju Juggernaut, SC Supply Converter, FR Fusion Reactor, Rc Reckoning). Ghosts of known structures keep their code; unknown blips have none. Icons are 4 px larger to fit the code (13-30 px). No image assets yet; the look is for review.

**Why / measured:** `Icons.spec`: icon n is def n, every unit def has a two-letter code and no two share one, sizes 12-30. Studio (`normandy`, strategic zoom): Order's lines read as Pa, Ln, Jd, Vr, Sr, At, Ag, Bc, Rc, SC, FR, Ms, Ah and the Gu helicopters (`debug_out/screens/c67_unique_icons.jpg`).

### C-68 — Playable placeholder UI: build menu, command card, unit panel, alerts (2026-10-22)

**Decision:** functional placeholders (correct behaviour, plain look) that read and act only through the client API, for a UI session to restyle:
- **Build menu** (`UI/BuildMenu`, `Core/BuildMenu`): the selected own builders' `buildOptions` in tabs (Economy, Factories, Defense, Utility for structures; Units for factories' products). Mobile builders: a click starts the build ghost; factories: a click queues one (Shift: 5) through the new `actions.queueBuild`, a right click drops the last one (`actions.cancel(index)`), a badge shows the queued count. B arms the menu's keys / goes to the next tab; while armed, 1..0 pick the tab's items (taken before the control groups through `Controls.capture`). Replaces "B cycles the options".
- **Command card** (`UI/CommandCard`): move, fight, attack, patrol, guard (command modes: `actions.setCommandMode` / `actions.commandAt`, the next left click gives the order; Shift keeps the mode, right click cancels; the A attack mode of C-57 is now one of them), stop, fire state and move state (cycled; they show the last state sent: not replicated yet), factory repeat (`actions.setRepeat`), on / off (`toggle`), cancel (a factory's last queued item, else an unfinished frame), jump to the last alert. Hotkeys: M F A Z G S, L K, Y U X, J.
- **Unit panel** (`UI/UnitPanel`): one unit: code and name, health (bar and hp), build progress, weapons with range, stock and the next missile's progress, on / off and repeat, a factory's queue; several: a button per unit type with its count (a click keeps only that type). Ammo isn't on the wire (only stockpiles show).
- **Alerts** (`Core/Alerts`, `UI/AlertFeed`): "unit / structure under attack" (an own unit's health drops; once per 400-stud zone per 20 s), "structure lost: <name>", "power / supply stall" (economy ratio below 1; every 30 s), "nuclear launch detected"; the API lists them (`state.alerts`) and fires `changed.alert`; the feed shows the newest 5 at the top right (8 s, a click jumps there) and each pings the minimap (a growing ring); J jumps to the last one.
- **Factory queues** (`Core/FactoryQueue`): not replicated (request 36), so the client keeps what it queued: an item leaves when a new own unit of its type appears within 80 studs of the factory (back to the end on repeat) or on CANCEL. PLACEHOLDER.

**Why / measured:** `Ui.spec`: a Mason's menu has Economy / Factories / ... and a plant's only Units; `queueBuild` makes the plant produce a Lancer and the client's queue drops to 1, CANCEL clears it; fight / patrol / guard modes send FIGHT, PATROL, GUARD (Shift keeps the mode, guard needs a unit); alerts fire once per zone for an attack, once for a lost structure, for a power stall and for a launch. Studio (`normandy`): the masons' menu, the Vehicle Plant placed from it (B, B, 1, click) and queued Lancers x3 through B, 3 (`debug_out/screens/c68_build_menu.jpg`, `c68_factory_queue.jpg`); an attack's "Unit under attack" alert with its minimap ping (`c68_alerts.jpg`). Fixed on the way: Luau's 0 is truthy (the panel showed on / off for every unit with `radar = 0`).

### C-69 — Camera pitch (2026-10-22)

**Decision:** Alt + wheel tilts the camera, 4° per notch, between 35° and 80° (start 55°); the wheel alone still zooms. The camera keeps its pitch in its state (`Camera.State.pitch`; follow uses it). The rectangle sent to the server is the ground under the four screen corners with each corner at most `RECT_CAP` (1.8) camera distances from the focus horizontally (sky corners straight ahead at the cap): about where the far edge already is at 55°, so a low pitch never pulls the tactical tier out to the horizon; what lies beyond is drawn from strategic records as icons. Selection, rings and icons project through the camera and work at any pitch; the minimap outline shows the sent rectangle. Debug: `Invoke("camera", x, z, distance?, pitch?)` returns the rectangle; `Invoke("net")` returns bytes received per channel.

**Why / measured:** Studio (`normandy`, camera 400 studs out): the sent rectangle is 69 cells deep at 55°, 83 at 35° (the horizon without the cap) and 66 at 80°. During the battle at 35° the client received 8.4 KB/s (8.5 KB/s at 55°; the target is ≤ 35 KB/s) and its frame work averaged 1.7 ms (peak 5.9 ms). Real Alt + three wheel notches took the pitch from 80° to 68°; a box selection at 35° picked 3 units. Screenshots: `debug_out/screens/c69_pitch35.jpg`, `c69_pitch80.jpg`.

### C-70 — Match flow: lobby, match, results (2026-10-22)

**Decision:** a profile with `lobby = true` (MatchConfig `skirmish`) runs guide 16.3's flow for one human against the skirmish AI (S-17), all in `src/roblox` plus a client screen:
- **Lobby** (`src/roblox/Lobby.luau`, pure Luau): map (A's named maps and Normandy, with their start counts), mode (FFA / Team), win rule (Command Ends / Annihilation), faction (Order / Chaos: the human's team parity, Scenarios.standard_start), AI slots (Easy / Normal / Hard; at most starts − 1). Changes come from player 1 through the `Lobby` remote; the state goes to clients as the Remotes folder's `Lobby` attribute (JSON). While in the lobby an empty sim on the chosen map runs as a preview.
- **Match:** Start builds the Sim config (the human is player 1, AI players 2.., factions alternating so the first AI is the other faction; Team mode: the human and every second AI against the rest), the match rules from the lobby, `Skirmish.forMatch` brains ticked before each `Sim.step`, and re-WELCOMEs everyone.
- **End:** when the match is over, or when the human is out (in a free-for-all the AIs may fight on; the results don't wait): the results (victory / defeat / eliminated, length, each player's faction, ally team, end and units left) are published; Back to lobby returns to the preview.
- **Client** (`src/client/UI/Lobby.luau`): the lobby panel (buttons per option, AI rows with levels, Add / Remove, Start) and the results screen; hidden while playing.

**Why / measured:** `Lobby.spec`: settings are validated (bad values refused, AI slots capped by the map's starts, no changes during a match); every named map and mode gives a config the sim accepts, the brains match the AI slots, a Chaos pick gives the human an even team, and the AI builds within 150 ticks; destroying the human's Command Vehicle ends a 1v1 with the AI the winner and the results say so; Back to lobby returns. Studio (`skirmish`): the lobby over a live preview of Crossroads with 3 AIs (Normal, Hard, Easy), Start (a real click) began a 4-player FFA, the AIs building 12-13 units each within 15 s; with the human's Command Vehicle destroyed the results showed ELIMINATED while the AIs fought on (then, in a 1v1, DEFEAT after 0:31), and Back to lobby (a click) returned to the lobby with the settings kept (`debug_out/screens/c70_lobby.jpg`, `c70_results.jpg`).

### C-71 — BAR-style layout and icon glyphs (2026-10-22)

**Decision:** the user asked for BAR's UI and icon style (a BAR screenshot as reference). Layout: the minimap at the top left (280 px), the build menu as BAR's grid of tiles under it (5 columns of 52-px tiles, 3 rows visible then scrolling: the type's glyph, its name, the hotkey while the menu's keys are on, the queued count; tabs on top), the unit panel at the bottom left (a portrait tile with the glyph, name, role, health, and BAR's stat lines: DPS, weapon range, reload, speed, build power, LoS, air LoS, radar, jammer, stock, on / off, repeat, queue; several selected: a tile per type with its count), the command card next to it (small grey text buttons in BAR's order, colored state bars under fire state, move state, repeat and on / off, the hotkey on hover), the resource bar at the top center as BAR's two blocks (symbol, demand over income, stored large, storage, thin fill bar), alerts under it like BAR's messages, the F3 readout top right and the follow button bottom right. Icons: each unit type's glyph (`UI/Glyph`, `Core/Icons.glyphs`): its domain's shape in team color (the commander a star), a white role mark per icon family (Unicode symbols Roblox's fonts draw as plain glyphs: ◎ artillery, ◉ radar, △ / ▲ SAM, ⌂ factory, Ψ nuke ...; ⚡ ☢ ⚙ ✈ ⚓ are color emoji and aren't used), tier pips, a dark corner notch on Chaos types and variant dots where two types would still look alike, unique over all unit types; C-67's letter codes stay for UI labels only.

**BAR's own icons:** the user suggested taking them from the Beyond All Reason repository. Its `license_icons.txt` and `license_unitpics.txt` put the icons and unit pictures under CC BY-NC-ND (IceXuick, Floris, PtaQ): no commercial use and no derivatives, while uploading to Roblox grants Roblox a licence and team colors are a derivative. Not downloaded or used; the options (original BAR-style icon images uploaded to the user's account, or the authors' permission) are the user's call.

**Why / measured:** `Icons.spec`: every unit type's glyph (shape, mark, tier, faction, variant) is unique, at most 3 variant dots. Studio (`normandy`, a Mason selected, B): the BAR layout with the economy tiles, the Mason's panel (Speed 30, Buildpower 100, LoS 100, 650 / 650) and the command card's state bars (`debug_out/screens/c71_bar_layout.jpg`). Fixed on the way: a tile child named "Name" collided with the Instance's Name property.

### C-72 — Radar precision from Pinpointers (2026-10-22)

**Decision:** with S-59 (request 34: Witness / Augur Pinpointers, `Shared/Combat/Pinpoint`) the unit panel of a radar, radar SAM, fire-control unit or Pinpointer shows the team's radar precision as "Accuracy 50%" (the user's wording; first shown as "Radar precision 50% (3/6 Pinpointers)"). `Core/Precision` counts the own team's finished Pinpointers as the server's Sensors does (defs with `pinpointer = true`, built) and uses the shared formula; units outside the camera are identified by their icon (the def index since S-58) and count as finished. Only the own team: the wire doesn't say who is allied, while the server counts the ally team. Also: On / Off shows only for converters, the only units whose TOGGLED_ON bit does anything (Economy); the command card's On / Off button is dimmed otherwise.

**Why / measured:** `Precision.spec`: three finished Witnesses give 3 and 0.5, equal to the server's `Sensors.precision`; an unfinished one and an enemy Augur don't count. Studio (`normandy` plus three Witnesses): a Beacon's panel reads LoS 180, Radar 1100, Radar precision 50% (3/6 Pinpointers) (`debug_out/screens/c72_radar_precision.jpg`).

### C-73 — Client performance in the normandy battle (2026-10-22)

**Decision:** measured the client in the `normandy` battle (Order's armies sent into the Chaos lines; 171 own units, 149 models) at normal zoom (220 studs) and full zoom (900), 8 s each: Studio holds 60 fps at both (16.7 ms frames, worst 18-25 ms), and the client's own work per frame (Main's sections) is small: 0.8 ms at normal zoom, 2.25 ms at full zoom, where the icon layer was the biggest part (1.67 ms average, 3.6 ms worst) because every icon's whole glyph was restyled every frame. The icon layer now remembers each slot's style and pixel and writes only what changed (the draw list is sorted by unit ID, so slots keep their units). Nothing else needed changing: no section above 1 ms on average.

**Why / measured:** after the change, same battle: icons 0.36 ms at normal zoom and 0.66 ms at full zoom (from 1.67, −60%), the client's frame work 1.06 / 1.98 ms with the battle's effects heavier this run (effects 0.75 ms at full zoom), still 60 fps. The look is unchanged (same glyphs; only redundant writes skipped).

### C-74 — The user's icon set on one sprite sheet (2026-10-22)

**Decision:** the strategic icons come from the user's icon set, draft 2 (`docs/art/icons/ftgg-unit-icons.html`, BAR style: frame shape = unit type, dots under the frame = tech level, none for T1, white symbol = weapon or role). Its FR, SYM, CAT and iconSVG are the source of truth: `tools/icons/render.mjs` (Node + resvg) runs them straight from the HTML and exports every tile with its Copy SVG logic, `iconSVG(it, "#ffffff", ...)`, onto one 1024-px sheet, `assets/icons/ftgg-icons.png`: every icon white with a dark edge, tinted per team by ImageColor3. Tiles (100 x 117 px): one per catalogue entry, frame and tier (64), one contact per frame (dashed, no symbol or dots; 10). Ghosts are the unit tile at 45% opacity (ImageTransparency 0.55), as in the HTML. Each def maps to an entry by its id in the entry's ids, else by its icon family (structures named by kind: plants, extractors, generators, radar / jammer / sonar towers, converters, rearm pads, Pinpointers); a family entry draws the def's own tier, so advanced variants get two dots. Pinpointers use their own domain's frame (structure), as the user asked. The script writes `src/client/UI/IconAtlas.luau` (tile positions, def → tile, scale, frame; the asset id from `tools/icons/assets.json`) and fails when a def fits no entry.

**Why:** one sheet, one upload; the user dropped the two-layer plan (draft 1) since every draft 2 icon is white with a dark edge. Tinting the white tile matches the HTML drawn in team color to within 12/255 (the dark edge gets tinted too). `tests/client/IconAtlas.spec` fails when a def is added without rerunning the script. Wire icon numbers (Shared/Net/Icons) are unchanged.

**In the game:** the user imported the sheet (asset 96380571554418, in `tools/icons/assets.json`). `UI/Glyph` is now one ImageLabel cut from the sheet (ImageRectOffset), ImageColor3 = team color, lightened 55% toward white when selected; the icon layer, the build grid and the unit panel all draw it, replacing C-71's drawn glyphs. `Core/Icons.style` picks the tile: a unit its type's tile at 22 px wide × its tier scale (T1 22 × 26, T2 25 × 30, T3 29, the Command Vehicle 30); a ghost the same tile at 45% opacity; a radar contact that isn't tracked, or a sonar contact, the dashed frame of its type, or, when its type is unknown, the aircraft frame above 8 studs, the submarine frame for sonar, else the vehicle frame.

**Readability (normandy battle, strategic zoom, 22 px; `debug_out/screens/c74_*`):** every frame reads at a glance, and the team colors are clear on grass and sand; ghosts are faint but visible on both. Hard to tell apart at real size: Bomber vs Strategic Bomber (two vs three bombs blur into one blob, only the T2 dots and the size differ); Main Battle Tank vs MLRS (two shells vs two rockets, both two white bars in the diamond); Airfield vs Rearm Pad (the same triangle, the pad's base line is 1 px); Gun Turret vs Floating Turret (the wave under the shell is a thin line). Readable but close: Fighter vs Air Superiority, and the IR vs radar SAMs (one vs two chevrons). T1 vs T2 of the same building differ only by the dots, about 2 px and team-tinted, so hard to see.

### C-75 — Factory queues, fire / move states and ammo from the server (2026-10-22)

**Decision:** request 36 landed as S-61 (protocol 20, the State record's OWNER field, own units only). NetIn keeps each own unit's `queue` (def indices, the head in production), `queueProgress` (0..1), `fireState` / `moveState` and `ammo` / `maxAmmo` on the World unit. The client API's `factoryQueues` is now every own factory's server queue, and `fireState` / `moveState` the first selected unit's server states (nil when no selected unit has them). The client-side guesses are removed: `Core/FactoryQueue` (what the client queued, followed by watching new units appear) and the actions writing the last state they sent. The unit panel, build grid and command card read the same API fields, so they show the server's view with no change of their own beyond the panel's ammo line.

**Why:** the user asked for the server's truth in place of the guesses; a state button now changes when the server has taken the command (one tick later), not when it was sent. `tests/client/OwnerFields.spec` checks the client's view against the server's for each field: the queue on every tick through production and CANCEL (identical on all 1,350 ticks; the head's progress within the wire's sixteenths), fire and move states after each command and in the API, ammo as the server changes it.

### C-76 — Unit stats in the unit panel (2026-10-22)

**Decision:** `Core/UnitStats` (pure, Lune-tested) builds a unit's stat sheet from the shared defs plus what the client knows of it live, and formats it as compact lines; the unit panel shows them for one selected unit, or for a hovered unit (an enemy always, BAR style, since enemies can't be selected; an own unit when nothing is selected; picked ten times a second, not over UI panels).
- Formulas: DPS = damage per shot against the class × shots per reload (salvo count × projectiles) ÷ reload, against the weapon's main class: the first armor class in its target priority, else the class it hurts most (a Lancer: 120 × 1 ÷ 1.6 = 75 against armored). Spread is the weapon's `accuracy` (± degrees, as Combat uses it); it reads "±0.5°" so it doesn't clash with the team radar "Accuracy 50%" line the user named. Missiles add guidance, lock range, stockpile (count for own units) and seconds per missile. Income is `production` per second, upkeep `trackDrain + jamDrain`, plus conversion, extraction rate, wind maximum and storage.
- What the player may know: own team: everything, with S-61's owner fields; an enemy in sight or tracked (TRACKED): its type's stats and health; a ghost: its type's stats only; a radar or sonar contact that isn't tracked: its domain only, even when the icon number names the type.
- Countermeasures show the def's charges as "max" until live charges are on the wire (request 37).
- Layout: the panel is 460 px wide so a weapon line fits on one row; the build grid shows 2 rows (more scroll) so the two don't overlap in Studio's viewport; the command card sits right of the panel. Listed under "Needs my review".

### C-77 — Lobby seats for several humans; results with statistics (2026-10-22)

**Decision:** the lobby (`src/roblox/Lobby`) is a list of seats; seat i plays sim player i. A seat is a human (Roblox UserId and name), an AI (level) or open; each has a faction (its team's parity, Order odd, Chaos even) and an ally team for Teams. Roblox players take the first open seat as they join (`Lobby.seat`; a seated human rejoining gets the same seat, also mid-match); without a free seat they get nothing yet (spectators: next task). The human in seat 1 hosts: only they change the map, mode, win rule, seats and ally teams, start and go back to the lobby; each human sets their own faction, the host the AI and open seats' factions. Leaving in the lobby opens the seat and passes the host to the next human (moved to seat 1, re-joined as that sim player); leaving mid-match keeps the seat. At the start, open seats drop out and the others renumber; the server re-seats every player. The lobby preview runs with 8 sim players so any seated human can join it. Results come when the match is over or every human is out (`Lobby.done`); each client finds itself in the results by UserId. `src/roblox/MatchStats` counts per player from the sim after each step: units built (finished during the match), lost (finished units that died), supply / power gathered (income) and spent (construction's `spent`, across economy windows), damage taken (health lost, a dying unit's remainder included). Damage dealt and kills need the attacker: request 38 to the sim; shown as nothing until then. Profile `duo` starts with two open seats.

**Why:** the user asked for two humans in one match, faction choice, AI difficulty per slot and statistics on the results screen. Pure Luau so the lobby and the statistics are Lune-tested (`Lobby.spec`); `TwoPlayers.spec` drives two complete client stacks on one sim for joining, fog, commands, combat and the win. Studio's multi-client test can't be started from the Studio tools this session has; listed as not done.

### C-78 — A new WELCOME clears the client's own references (2026-10-22)

**Decision:** the client API counts WELCOMEs (`world.joins`); on a new one it clears the selection, control groups, waypoints, command mode and build placement, since unit IDs start over after a rejoin or a match restart and the old ones would name other units. The rest of the client already rebuilt itself on a WELCOME (World, renderer, effects, wrecks, map). A rejoin is a fresh client process joining as the same player (Roblox doesn't reconnect a client); the server keeps the camera (S-2).

**Why:** `tests/client/Robustness.spec` found the stale selection on a restart; it also pins the late-join, rejoin and restart views to the server's own (`tacticalList`, health, sight).

### C-79 — Spectators and the replay viewer (2026-10-22)

**Decision:** Roblox players without a seat become spectators: on their HELLO the server adds a spectator viewer (`NetOut.addSpectator`, S-18) and sends its outbox; a new match adds them again. In a lobby match the server records every human's outbox each tick into a PlayerReplay (S-18's format, with the protocol and defs hash), up to 32 MB for all recordings. A "Replay" remote serves the results screen: save (the serialized file kept per UserId for the server session; a DataStore copy on live servers only, since Studio refuses it without API access and logs an error), list, and watch (the file in 200 KB chunks). The client parses it, checks protocol and defs, and plays it with `Core/ReplayPlayer` (pure: advance at a speed, pause, seek; a seek back starts over from the first tick, whose WELCOME rebuilds the view) through NetIn into the same World, so the whole client draws it; live messages and orders are dropped meanwhile, and Exit sends a new HELLO for a fresh live view. The render clock follows the replay speed like the live sim speed (C-35). `UI/ReplayBar` draws the controls and the banner (replay or spectating).

**Why:** the user asked for spectators and for saving and replaying a match from the results screen with pause, speed and seeking. Replaying the recorded stream through the live code needs no re-simulation and survives balance changes (S-18). Seeking by replaying from the start is fast enough at these sizes (a 31 s match is 3 KB; `Replay.spec` checks every seek lands on exactly the live view); keyframes can come if long matches need them.

### C-80 — Requests 37 and 38 used; the faction pass followed (2026-10-22)

**Decision:** NetIn keeps the OWNER field's CHARGES (protocol 21, S-63) as each own unit's `flares` / `chaff`; UnitStats shows them as "left / max" for own units and the def's maximum for others. The results screen takes the sim's `Stats.report` (S-63: units built, lost and killed, damage dealt, resources gathered and spent from the team account), replacing C-77's MatchStats (removed). Core/Precision sums `Pinpoint.weight` over finished Pinpointers (S-62). Specs now read unit numbers from the defs instead of hard-coding them, so balance passes don't break them.

**Why:** sim-A shipped requests 37 and 38 and asked the client to follow S-62. The sim counts statistics where things happen (it knows the attacker for damage and kills), which C-77 couldn't.

### C-81 — Settings menu (2026-10-22)

**Decision:** `Core/Settings` (pure, Lune-tested) holds the settings, their limits and steps, three graphics presets and the key reference; `UI/SettingsMenu` (O, or a button bottom right) shows them and writes the values into the modules that read them each frame: Camera.PAN_SPEED / ZOOM_STEP / EDGE_SCROLL, Effects.MAX_EXPLOSIONS / MAX_TRACERS / MAX_PROJECTILES, Vfx.MAX_LIGHTS / TEMPLATE_CAP, PieceAnim.NEAR / MID (model detail distance), FogOfWar.ENABLED (fog lights), and a UIScale on the UI panel screens (not on overlays drawn at world positions, which would be misplaced, nor on Roblox's screens). High is today's numbers; fog lights default off. Settings last for the session (a client has no local storage; the server could keep them later).

**Why:** the user asked for a functional placeholder settings menu with these items. Writing the existing module constants keeps every renderer unchanged.

### C-82 — Nuke craters and water splashes (2026-10-22)

**Decision:** `Render/Crater` digs a crater where a nuke bursts within its blast radius of the ground, on Terrain ground (Ground's `ground` mode; "parts" mode gets nothing): FillCylinder for a mud ring and a basalt floor, a FillBall of air for a spherical-cap bowl (radius 0.45× the blast, 18–90 studs; depth 7% of it, at most 6 studs), and a rim of earth balls with a fixed pseudo-random size and spacing so every client digs the same. The nuke's scorch decal is dropped. The area is copied (CopyRegion) before digging and pasted back by `Crater.clear` on every new WELCOME (up to 8 craters remembered). Core/Effects marks an impact as a splash (`burst.water`, the surface height) when it ends within 4 studs above water at least 0.5 deep and no known unit's hull is under the point (IMPACT doesn't say what it hit); the renderer plays the new "splash" kind there (column, spray, mist, foam ring along the water).

**Why:** the user asked for a nuke look without the dark circle, and the VFX pass covers weapon types that had no look of their own. The crater stays shallow because the sim's height map doesn't change, so units would otherwise float over a deep bowl. A crater from a strategic weapon could become a sim feature (a height change units drive into); that would be the sim's call.

### C-83 — Atmosphere presets as options (2026-10-22)

**Decision:** `Render/Atmosphere` holds four lighting presets (Current, Clear day, Battlefield haze, Dusk) that set Lighting's clock, brightness, ambient, exposure and shadow softness, the Atmosphere, Bloom, a ColorCorrection (made if missing, off in Current) and SunRays on this client. The first apply remembers the place's values; Current puts them back. The settings menu's "Atmosphere" row picks one; Current is the default, as the user asked. Measured in the same normandy fight: the presets cost about 0.5 ms of GPU over Current (4.3 → 4.8–4.9 ms), no CPU. Dusk was tuned after the first try came out too dark to read a fight.

**Why:** the user asked for 2–3 atmosphere options to choose from, with before / after screenshots and frame cost, the current look staying the default. Lighting.Technology isn't scriptable, so "Future" lighting stays a place setting.

### C-84 — Deploy phases in piece scripts; the Warden and the Minotaur (2026-10-22)

**Decision:** PieceAnim calls a new hook `Deploy(u, phase, instant)` for defs with `deploy` when the phase read from the state bits changes: DEPLOYING after deployed is "packing", DEPLOYING otherwise "unpacking", DEPLOYED "deployed", neither "packed"; `instant` the first time (a unit entering view already deployed snaps). The Warden's script turns `spades` 55° down and lowers `base` 0.4 studs over the def's deploy time, and on packing locks `turret` and `barrel` forward (its AimWeapon is ignored while packing or packed, when it can't fire); the Minotaur's script drives `ram` 2.5 studs forward on a slot 2 shot (the demolition charge) and back at 2 studs/s, and aims and recoils its gun like the default script.

**Why:** the user asked for the faction-only units' visuals as they land (Warden deploying, Minotaur's charge). The timing follows the server's state bits, so the client never shows a deployed gun the server hasn't deployed. Piece names follow S-64's def (`pieces`) and the models request.

### C-85 — Alerts from the server; S-69 to S-73 followed (2026-10-23)

**Decision:** NetIn queues ALERT events (protocol 23, S-68) in `world.alertQueue` (cell decoded to its centre; stalls carry cell 0); Core/Alerts maps each kind to the feed's kind, text (with the unit's name when the event names one) and whether it has a place to jump to (`at`; stalls don't), and drains the queue each frame. The client's inference (health drops, deaths, the economy ratio, launch warnings) is removed; the server rate-limits. The strategic UNDER_ATTACK flag makes minimap dots and strategic icons blink red (4 Hz phase; the icon layer redraws only on a phase change). S-70: a def with `deathBlast` adds an impact burst of its `aoe` on its death. S-72: `sensors.radarDrain` counts in the stats' upkeep. S-73: the lobby has `friendlyFire` (default on) passed as `match.friendlyFire`.

**Why:** request 39 landed; the server knows who hit whom, sees through no fog it shouldn't, and limits alerts the same for every client. sim-A asked the client to draw the death blast.

### C-86 — Draft 3 icons wired in; units missing from the sheet show a plain frame (2026-10-23)

**Decision:** The atlas points at the imported draft 3 sheet (`87919807696998`). Units added after an import get a `STOPGAP` entry in `tools/icons/render.mjs` that reuses an existing tile, so the sheet stays the imported one until the catalogue lists them (S-75: Locust, Cyclops, Barrier, Citadel). As a backstop, `Icons.ofDef` gives a def with no atlas entry its domain's dashed frame (ground → vehicle, air, naval → ship, structure → struct) instead of erroring.

**Why:** in the user's 2-client test, the Locust (new in main) had no atlas entry and `Icons.ofDef` errored every frame in the build menu. Each new unit would otherwise need a re-import before the client works, and a missing icon must not break the UI.

### C-87 — Shield dome prototype: a repulsor field, team-coloured dome, plasma core and capacity bar (2026-10-23)

**Decision:** A client-only prototype, not wired to the sim.
- **`Core/Shield` (pure):**
  - **Hit patches:** hex rings walked along great circles so they wrap the dome. Strength sets 1–3 rings, outer rings light later and cooler and fade sooner, and centre plates dent. Young hits within 6 studs merge, up to 6 patches per dome. Idle flickers are 1-ring patches, up to 6.
  - **Repulsor field:** in a 50-stud band, an inbound shell's radial speed bleeds off (a constant part plus drag, stronger deeper in) until it turns, which is the hit. Then the same field throws it out.
  - **Force:** the charge over 50% (capped at 1), divided by mass^0.6. A shell still inbound at the surface is a breach.
  - **Charge:** drained by mass on each turn or breach. At 0% the dome collapses, and it rises again at 25%.
  - **Core colour:** green, then orange at 40%, then red at 0%.
- **`Render/ShieldFx`:**
  - **Field:** a 0.8-transparency team-coloured ball.
  - **Rim:** a ring of Neon segments on the sphere's silhouette from the camera, recomputed each frame (a circle facing the camera, R²/D towards it, of radius R·√(1 − R²/D²)), with a fainter, wider band inside it.
  - **Surface:** a sphere-surface ParticleEmitter of sparkles, and team-coloured idle hexes.
  - **Core:** a Neon ball, halo and short-range light in the core colour.
  - **Capacity bar:** in a ScreenGui with IgnoreGuiInset, placed at the projected top of the rim.
  - **Animations:** a collapse (flash, shrink to 85%, fade) and a rise (grow from 10%).
  - **Plates and shells:** hit plates on the heat ramp, Neon parts moved with BulkMoveTo from a pool capped at 400. Shells are coloured whiter as the field slows them.

**Why:** the user's rules for the deflector: slow to a stop, then throw back with growing speed; heavier shells take longer; full force at ≥50% and weaker below, so big shells get through; a capacity bar; a core from green to red; collapse at 0%, rise at 25%. Tried and dropped:
- the ForceField material read grey and didn't show the team colour;
- a Highlight outline vanished on a transparent ball, and only 31 can show at once;
- BillboardGuis don't render in the playtest, so the bar is a screen-space frame like the game's other overlays;
- plates cooling into team colour turned pink against the red.

### C-88 — Shield idle hexes keep clear of hit patches (2026-10-23)

**Decision:** `Shield.idle` starts no flicker near a live hit patch: within IDLE_CLEAR (14 studs) plus the patch's rings. `Shield.hit` removes idle flickers that close to a new hit. With EditableMesh now on in the experience, plates are the one-mesh hexagon prism. The three-rectangle fallback stays for places without the API.

**Why:** in the Studio re-check with the real hexagons, a pale blue idle flicker drew over a red-hot patch and read as a glitch.

### C-89 — Shield test scenario; neutral dome whose opacity follows charge; radius 120 (2026-10-23)

**Decision:**
- **`shield` match profile:** a defended spot under a 120-stud dome position, with units that don't shoot back (50× health). Attackers sit outside the dome and its field and cover every shell weight: Locust, Ravager, Juggernaut, Hellmouth and Hydra (on attack-ground), and Cyclops (with a Watcher spotting).
- **Dome colour:** `ShieldFx` draws the dome in a neutral white-grey (`DOME_COLOR`).
- **Opacity:** the field ball, the idle hexes and the rim follow `Shield.domeForce`: the charge over 50%, capped at 1, so invisible at 0% and full from 50%. The rim uses the square, since Neon blooms. A collapse still flashes out.
- **Size:** `ShieldFx.DEMO_RADIUS` = 120. Idle-hex rate and sparkles scale with the radius.

**Why:** the user asked for:
- a scenario to test the shield once the sim has it;
- a grey/white dome, not team colour, whose capacity sets its transparency (invisible at 0%, full at 50%);
- a bigger dome: ×3, then ×2. I read "×2" as replacing ×3, so 120 rather than 360.

### C-90 — ShieldFx: the shield dome renderer with fixed pools, one loop and strategic detail (2026-10-23)

**Decision:** `Render/ShieldFx` replaces the C-87 prototype's renderer. It keeps the hit plates and `Core/Shield`'s heat model, and adds the user's interface: `new(emitter, radius, teamColor)`, `deploy`, `setStrength`, `hit`, `collapse`, `destroy`.
- **Look:** neutral white, with opacity following strength (the user's C-89 rule over the brief's team colour). A tinted ball with a camera-facing edge ring, not the ForceField material.
- **Rings:** a fixed pool of 9 CylinderHandleAdornments per shield, resized each frame to the curve at their height and recycled at the top.
- **Pools:** ripples (4) and vortex arcs (3) per shield; one shared pool of 160 hexagon plates.
- **Loop and detail:** one RenderStepped loop for every shield. It skips domes off screen and draws only the dome and edge beyond 480 studs.
- **Timing:** `Core/ShieldLook` (pure) owns the timings and curves. Effects run on their own clock with a time scale (screenshots).
- **The mechanic demo** moved to `Render/ShieldDemo` and drives the new interface the way the sim will.
- **Review generators:** place content in `ReplicatedStorage.ShieldFxReview` (an Emitter attachment, Radius and Offset attributes), copied into the world by a debug call and placed on the raycast terrain surface.

**Why:** the user's brief and hard performance rules, with three changes:
- **White dome:** the user's answers today (white dome, generator structures only, a smaller Chaos dome) override the brief's team colour and Warden dome.
- **No ForceField:** it read grey with no edge in C-87.
- **Raycast placement:** the Order placeholder lay on its side and sank into the grass. The pivot came from its turned base cylinder, and the sim's ground height sits below the rendered terrain.

### C-91 — Shield domes from the server: SHIELD state, field stepping, hits; ShieldFx never yields (2026-10-23)

**Decision:**
- **NetIn:** keeps SHIELD records in `world.shields` (charge as 0..1).
- **Core/Effects:**
  - steps a projectile with `ShieldField.step` from its SHIELD_FIELD until the phase is DONE or FREE, the same function the server uses;
  - the frame curve (`nextState`) comes from the same step, so drawing between ticks follows the field;
  - SHIELD_HIT drops a turned missile's target and queues the hit.
- **`Render/ShieldDomes`:** one ShieldFx per known generator, driven by charge and the UP flag, standing at once when it comes into view already up.
- **ShieldFx.new never yields:** the hexagon pool builds in a spawned thread.
- **Stand-in removed:** the client-only preview domes (a profile list, crossings of drawn shells) were dropped once S-79 landed. The `shield` profile spawns a real Phalanx.

**Why:**
- S-79 answered request 40, and the client steps shells with the shared field so they bend where the server bends them; corrections cover the rest.
- The double dome came from a yield inside the frame loop.
- The user's three tuning points (10× capacity, deceleration, glancing deflection) are sim numbers, sent to sim-A with measurements.


### C-94 — ShieldFx on C's assets; meshes loaded at runtime; flowing rings stay adornments (2026-10-23)

**Decision:**
- **Assets:** `ShieldFx` uses C's shield assets by ID: the Dome hemisphere (Size 2R × R × 2R, centre half-way up), Ring for the foot ring, and the beam, swirl, speck and ripple textures.
- **Loading:** the meshes come from `AssetService:CreateMeshPartAsync` once, in a spawned thread. `ShieldFx.ready()` gates new domes in `ShieldDomes`. If loading fails, the dome is a ball with no foot ring.
- **Emitter:** `ShieldFx.new` takes an optional `base` (the dome centre), so the emitter can be the generator model's `beam` attachment. `setEmitter` follows the model as it streams in and out, and the core (the attachment's part) is tinted by charge and restored when released.
- **Look over the contract:** neutral white, opacity from charge, no ForceField: the user's rules (C-89, C-90) over fx.md's team colour.
- **Flowing rings:** they stay CylinderHandleAdornments.

**Why:**
- C's assets merged, and the user asked for them in place of the placeholders.
- The game place can't take copies from FTGG Art (my rule), so the meshes are built from their uploaded IDs.
- The Ring mesh's tube grows with its radius, a 2.4-stud ribbon at R=120, so it fits only the foot ring until a thinner ring comes.

### C-95 — Shield hits drawn on entry; white-grey plates; flowing rings from RingThin (2026-10-23)

**Decision:**
- **Entry hit:** `Core/Effects` queues an "enter" hit when SHIELD_FIELD arrives in phase BRAKING, at the shell's predicted position projected onto the dome radius, with mass `ShieldField.mass(weapon)`. `Render/ShieldDomes` lights the dome for entries and breaches, not for turns.
- **Plate colour:** `Shield.color` ramps grey (150, 154, 160) to white by heat.
- **Rings:** `ShieldFx` builds the flowing rings from C's RingThin (Size 2.004r × height × 2.004r) when it loads; adornments are the fallback.

**Why:**
- Since S-83 the turn happens deep inside the dome after braking, so the hit at the turn read as late. The user wants it as the shell enters.
- The user asked for the hexagons in white or grey, not red or orange.
- models-C made RingThin for C-94's request.

### C-96 — Shield ripple visible on its first frame; a one-attacker shield profile (2026-10-23)

**Decision:**
- **Ripple:** C's ripple particle starts at 35% of its size, opaque, reaches 70% at 15% of its life, then 100% while fading.
- **Turn hits:** `ShieldDomes` lights a SHIELD_HIT turn only for a shell it hasn't seen enter (tracked by projectile id).
- **`shield_one` profile:** one Phalanx, one Ravager, one target in the core.

**Why:**
- With S-83's inner band a light shell turns about 0.1 s after crossing. A ripple growing from 0 became visible only then, so the user read it as playing at the push-back.
- The user suggested testing with one unit.
- Light shots may soon be destroyed on contact (sent to sim-A), and those may never send a SHIELD_FIELD.

### C-97 — Force plumes on shells in a shield field; absorbed shells dropped (2026-10-23)

**Decision:**
- **Plumes:** `ShieldDomes.forces` draws a beam on each drawn shell that is in a field (up to 32, pooled on Terrain attachments), from the shell toward minus the field's force. The force is `nextState` velocity minus velocity, minus the weapon's gravity for a tick. Length is 0.2 studs per stud/s of change, from 2 to 14. C's beam texture flows into the shell; width is 2.5 + 0.8 × mass.
- **Absorbed shells:** a SHIELD_HIT with ABSORBED (protocol 25) removes the projectile and queues an "absorb" hit, which lights the dome.

**Why:**
- The user asked for a visible force on shells inside the dome, following the shot's direction and the shield's centre. The change of velocity is exactly the field's push, so the plume shows what the field does.
- S-85 destroys light shells at the surface with no IMPACT, so the client must drop them itself.

### C-98 — Shells in a field: a bow shock and a burning trail (2026-10-23)

**Decision:**
- **Pool:** `ShieldDomes.forces` keeps its pool of 32, each with a beam and a cap, a clone of C's dome mesh (`ShieldFx.cloneMesh`).
- **Cap:** Neon, (2r, 0.7r, 2r) with r = (1.3 + 0.5·mass)·(0.7 + 0.3·heat), its pole along minus the field's force, centred just ahead of the shell. Moved with BulkMoveTo.
- **Trail:** the beam runs from the shell along the force, white fading to orange, streaming backward.
- **Heat:** the force's share of the plume's maximum, setting opacity and size.

**Why:** the user drew a curved front ahead of the shell, "like when an asteroid enter the earth atmosphere". C-97's plume read as a beam, not as burning.

### C-99 — Shield field primed a tick early; absorbed shells end mid-tick; unfinished units see-through; minimap 10 Hz (2026-10-23)

**Decision:**
- **Field priming:** `Core/Effects.update` primes a SHIELD_FIELD due next tick. It gives the projectile its field in phase FREE, so the coming step uses ShieldField (which takes hold at the surface), and queues the "enter" hit once the frame's fraction passes the drawn path's crossing of the sphere. An absorbed SHIELD_HIT ends its projectile mid-tick, like IMPACT (C-26).
- **Shield clock:** ShieldFx's clock and particle TimeScale follow the sim speed.
- **Unfinished units:** `UnitRenderer` draws a unit with build < 1 at 0.6 transparency (parts' own transparency kept above that) and restores it when complete or released to the pool.
- **Minimap:** `Minimap.REFRESH` 1/3 → 1/10 s.

**Why:**
- The user saw the reflect effect late. Applied at the tick's end, the field and the hit came a tick late, with the shell flown a tick into the dome unbraked.
- The user asked that light shells vanish at once, and that units being built look unfinished.
- The user asked for a faster minimap.

### C-100 — Fog of war as a draped blanket with one live image (BAR style); the point-light fog removed (2026-10-23)

**Status:** approved by the user on 2026-10-23 after their own test; it is the default fog of war.

**Decision:**
- **Image:** `Core/FogBlanket` keeps one pixel per grid cell in three states from the team sight (visible, explored = seen once, never). It holds each sensor cell's state and blends each pixel's goal from its four nearest cells (bilinear). Pixels fade to their goal over 0.3 s, in a queue capped at 3,000 pixels per step, and only the changed rectangle is reported.
- **Mesh:** `Render/FogBlanket` shows the image as the TextureContent (UVs) of 4 EditableMesh chunks draped 1 stud over the highest ground within 8 studs of each vertex (one vertex per 16 studs). The parts are at Transparency 0.02 (so texture alpha blends), Fabric, at the world origin.
- **Updates:** at most every 1/15 s: Vision.update, apply, step, WritePixelsBuffer of the rectangle.
- **Minimap:** a Fog ImageLabel shows the same EditableImage.
- **Removed:** `Render/FogOfWar` and `Core/Fog`. The setting `fogLights` became `fog` (default on).

**Why:**
- The user's brief: the point-light fog read as night, blotched where lights overlapped, was capped by the light limit and didn't match the sim's cell vision.
- Measured choices:
  - SurfaceAppearance needs Plugin capability, and a Texture's projection didn't map.
  - The device editable-mesh budget forced the 16-stud vertex grid.
  - Roblox samples the texture without smoothing, so the blend is done in the image.
  - The pixel cap bounds the cost of a whole-map change.

### C-101 — A moonlit night is the default atmosphere; low environment specular; lighter explored fog (2026-10-23)

**Decision:**
- **Preset:** `Render/Atmosphere` gets a `night` preset, first in the order and the default (`Settings.ATMOSPHERES`, `atmosphere = "night"`).
  - ClockTime 0, Brightness 2.5, ambient (112, 118, 132), outdoor (140, 146, 162), exposure 1.1, shadow softness 0.6.
  - EnvironmentSpecularScale 0.15, EnvironmentDiffuseScale 0.6.
  - Atmosphere density 0.2 / offset 0.15 / haze 0.6; bloom 0.8 / 26 / 1.2; sun rays 0; colour contrast 0.1, saturation −0.18, cool tint.
- **New fields:** presets gain optional `specular` and `diffuse`, captured from the place.
- **Fog blanket:** the explored look becomes grey 40, alpha 0.4.

**Why:**
- The user: the maps have no sun (a dark battlefield), and lighting with less brightness and with shadow control should counter the fog blanket's "plastic wrapping".
- The glossy look came mostly from environment specular, so it is cut to 15%.
- The light levels keep units readable at every zoom; a thicker atmosphere flattened the strategic view.
- Under night light the old explored look read as never seen.
- Lighting.Technology isn't scriptable, so it stays a place setting (Realistic recommended: Roblox's unified technology, which replaced Future).

### C-102 — The environment: night sky, map-edge ground, terrain colours, ambient particles; a graded picture (zoom easing, blast flash, vignette); grey fog of war (2026-10-23)

**Decision:**
- **Presets:** `Render/Atmosphere` presets gain `sky` (skybox faces, stars, moon), `ground` (Terrain material colours) and `vignette`, all captured from the place. Night: procedural sky, cool dull terrain, vignette 0.55, grade b 0.05 / k 0.32 / s −0.02 / tint (196, 218, 255).
- **Grade:** `Core/Grade` + `Render/Grade` write the preset's ColorCorrection each frame.
  - Zoom easing (smoothstep 150 → 800 studs: contrast and saturation ×0.55, tint halfway to white, vignette ×0.6).
  - A warm flash for nukes and large deaths near the focus (`Vfx.onSpawn`; capped at 1, decay 0.3 s).
  - A vignette drawn once into an EditableImage.
- **Edge and particles:** `Core/Environment` + `Render/Environment`: 49 dark slabs (at most 2,048 studs) 6,000 studs round the map, just under the lowest edge; dust and mist in a box following the camera within 320 studs, off at Low.
- **Fog:** `Core/FogBlanket.LOOK` becomes grey: explored 80 at 0.38, never 56 at 0.7.

**Why:**
- The user asked for map edge, night sky, terrain colours and ambient particles, with the colour correction "the most impressive part", and then asked for grey fog so ghost structures stay visible.
- The void past the map showed the sky's blue.
- The grade must not cost readability at strategic zoom, and frequent impacts must not flicker the screen.
- Roblox's ColorGradingEffect only offers a tonemapper, so the grade is ColorCorrection.

### C-103 — BAR models built on the client from the mesh manifest, with Rojo-written materials; the unit glow driver; headlights (2026-10-23)

**Decision:**
- **Models:** `Render/MeshModels` builds every "approved" manifest entry at start (CreateMeshPartAsync, rig.md 1–2, glow parts per fx.md). `Render/Models` order: place model > mesh model > blockout. Stand-ins are swapped when the mesh is ready.
- **Materials:** SurfaceAppearances (maps, emissive mask) come from `place/MeshMaterials.model.json` (`lune run mesh_materials`, Rojo → `ReplicatedStorage.MeshMaterials`) and are cloned. RenderFidelity goes through CreateMeshPartAsync's options.
- **Glow:** `Core/Glow` + `Render/Glow` drive EmissiveStrength: power × stall ratio (floor 0.3), factory pulse 1.5–4 at 1 Hz, weapon flash 6 → rest over 0.3 s, dark while built; only changes are written.
- **Headlights:** pooled shadowless SpotLights on the nearest on-screen vehicles, capped by the light budget, at close zoom or night and dusk.

**Why:**
- The user's glow pass needed the models in game. C keeps to "FTGG Art" and gave a manifest.
- Game scripts lack the Plugin capability for SurfaceAppearance maps, the emissive mask and RenderFidelity, and emission needs the mask. Rojo has it and clones keep it, so the repo stays the source and nothing has to be saved into the place by hand.
- Measured at 200 units: 0.19 ms a frame.

### C-104 — A shield hit's hex patch: one bright centre, faint outer rings (2026-10-23)

**Decision:** in `Core/Shield.plateAt`, each ring's opacity is `RING_ALPHA` (0.3) to the power of its ring number, and its heat peak falls 40% a ring (floor 20%).

**Why:** the user saw one shell's touch as 5–6 shots. Events were one per shell (measured), but the 7 equally white Neon plates bloomed into separate blobs under the night grade.

### C-105 — One UI kit for every panel; settings, statistics and lobby rebuilt on it; statistics sampled on the server until the sim keeps them (2026-10-23)

**Decision:**
- **Kit:** `UI/Kit` holds the theme (colors, Montserrat, type and spacing scales, corners) and the components.
- **Panels:** settings, lobby and the new statistics panel (the results screen) are built from it, once, and shown or hidden.
- **HUD:** the older HUD screens take the kit's tokens and `Kit.skin`.
- **Charts:** `Core/Chart` downsamples to 120 points and rasterizes into one EditableImage per chart, one chart per frame.
- **Samples:** taken by `src/roblox/StatSeries` every 10 s until sim request 41.

**Why:**
- The user: the settings and results panels read as debug boxes, and the BAR statistics panel is the style target (style only).
- Montserrat is the closest built-in to its geometric sans.
- Charts: an EditableImage per chart is a fixed cost per redraw, against a Frame per segment per line (up to thousands of Frames) (measured: 4.6 ms per chart redraw and nothing standing, against 476 Frames a chart).

### C-106 — Modal panels with a scrim; panels fit their content; graphics options for detailed models, glow and headlights; mesh models load by priority; white glow on clashing team colors; factory pulse to 3 (2026-10-23)

**Decision:**
- **Modal:** kit panels are 95% opaque over a 55% black scrim, in guis above the HUD (100 / 110).
- **Layouts:** `setHeight` fits panels to content; statistics is a 3 × 2 scale grid of size-aware charts.
- **Settings:** `detailedModels`, `glow` (off / low / high), `headlights`.
- **Loading order:** mesh models load on screen > in the match > own faction > the rest.
- **Clashes:** Order team 7 and Chaos team 6 show running / power glow white (C's fx.md table).
- **Pulse:** `PULSE_HIGH` 3.

**Why:**
- The user's review: panels read through to the HUD, left empty space, missed graphics options, and models took ~21 s.
- The user also asked for white glow where the team color matches the faction glow, and a lower pulse if 4 blew out (it did, measured on the Order vehicle plant).

**C-106 addendum (2026-10-23):** the user confirmed the factory pulse peak at 3.

### C-107 — Build menu tiles with model portraits and a stats tooltip; On / Off only where it switches; piece turns take the short way (2026-10-23)

**Decision:**
- **Tiles:** model portraits in ViewportFrames (`UI/Portrait`), the icon bottom right, the cost bottom left, 4 × 66 px tiles.
- **Tooltip:** a hover tooltip from `UnitStats.ofDef` with build time at the builders' power.
- **On / Off:** neutral grey unless a converter is selected.
- **Turns:** `PieceAnim` turn goals wrap to the nearest equivalent angle, and `Interp` extrapolates heading by the wrapped step.

**Why:**
- The user: BAR-style unit pictures and stats on hover; factories read as "OFF"; units rotated the long way (the client's turn interpolation crossing ±180°).

### C-108 — Minimap 220 pixels; the materials file covers effect meshes (2026-10-23)

**Decision:**
- **Minimap:** 220 (was 280); the build menu starts under it.
- **Materials:** `mesh_materials` writes `fx_<id>` appearances for `Meshes.fx`.

**Why:** the user asked for a smaller minimap; models-C needed SurfaceAppearances for the missile meshes.

### C-109 — Per-unit command sets; factory orders kept; Roblox's top bar cleared and the HUD moved into the top strip (2026-10-23)

**Decision:**
- **Commands:** `Core/CommandSet` decides each type's commands and the card shows the selection's union; repair and reclaim are command modes.
- **Factory orders:** they stay drawn until replaced (full queues: sim request 44).
- **Top strip:** Roblox's core UI is off; resource bars, alerts and the debug overlay draw from the top; Settings sits right after Roblox's corner (`GuiService.TopbarInset`).

**Why:** the user's requests. Roblox keeps its menu button and the corner it needs whatever the game sets, so the minimap sits under it.

### C-112 — Beam weapons as held lines; retractable towers' piece script and on / off; stopgap icons for S-96's towers (2026-10-23)

**Decision:**
- **Beams:** a BEAM FIRE draws a held, fading Neon line in the faction's beam tint for 0.45 s, with a charge flash and an impact.
- **Retract:** `def.retract` units get a `Retract` hook from the TOGGLED_ON bit; `PieceScripts/BeamTower` plays models-C's retracted pose; the command card offers On / Off.
- **Icons:** stopgap tiles (Heavy Turret, IR SAM Site) until the icon catalogue has these towers.

**Why:** the user's Pulsar reference (a bright line from the barrel, retract when off); new defs must have icons, and existing tiles avoid a re-import.

### C-120 — The cheat command line sends the sim's CHEAT commands; results print in its log; "cheats used" on results and replay names (2026-10-23)

**Decision:**
- **Sending:** `Core/CheatInput.prepare` fills in unit ids and the cursor's "at"; `CheatText.parse` (S-102) builds the command; `Commands.encode` sends it on the Cmd channel (never during a replay). The console echoes the resolved line ("→ give ord_lancer 3 at 43,24"); parse errors print in red.
- **Results:** CHEAT_RESULT events queue in `world.cheatResults`; Main prints `CheatText.describe` lines, green when OK, red otherwise.
- **Speed:** the Roblox entry's tick driver takes `sim.cheats.speed` when it changes, and goes back to 1× for a match without one.
- **"Cheats used":** the statistics Overview adds "CHEATS USED (name ×n)" from `Stats.report`'s `cheats` and `Stats.series`' `cheated`; a saved replay's name ends in "· cheats used".
- **Log height:** the log shows only the newest lines that fit under the top HUD.
- **Permissions:** unchanged from C-119 (allow list AND Studio or the lobby's Cheats toggle; the server drops anyone else's CHEAT payloads).

**Why:** the user's brief. The player replay file has no cheat flag of its own, so the name carries it rather than changing the sim's file format.

### C-121 — Extractor upgrades in place: targets highlighted and snapped to, extractor drags as areas, an "Upgrade extractors" area command (2026-10-23)

**Decision:**
- **Rule:** `Core/Upgrades` follows S-108: `def.upgradesFrom` lists what a def replaces, on the player's own finished structure. Defs without the field fall back to D92 (a same-faction extractor with a lower rate) until S-108 merges. `Core/Placement.check` uses the same rule.
- **Site:** an upgrade's BUILD goes to the deposit under the old extractor, as the point the new footprint snaps from (S-104: T1 2×2, T2 3×3).
- **Ghost:** while the ghost upgrades (or in the Upgrade command), every target gets a pulsing disc. The ghost snaps onto a target within 16 studs (before deposits) and draws over it (highlight on top, plate raised).
- **Extractor drags** are circles: `Placement.area`, every valid spot in the circle (free deposits and upgrades), visited nearest the builders first. Other structures still place rows.
- **Upgrade extractors** (card button "Upgrade", T2 builders; `CommandSet` takes the def set): drag a circle, or click (16 studs), and `actions.upgradeArea` queues plain BUILDs nearest first.
- **Build menu:** a "▲ UPGRADE" badge and the tooltip line "Upgrades a T1 extractor in place".
- **Fixes:** the ghost moves its model with `PivotTo` (blockout parts are anchored, not welded). `Waypoints` no longer counts the extractor a build upgrades as that build's frame.

**Why:** the user's brief; sim-A's S-108 contract (no new command or wire: each queued BUILD is checked when started).

### C-122 — The minimap draws unit icons (2026-10-23)

**Decision:** minimap units are their strategic icons (`Core/Icons.style`, `UI/Glyph`) at `Minimap.ICON_SCALE` 0.5 (about 11 px). Ghosts, selection and under-attack look as on the icon layer; radar blips with no type stay dots. `Minimap.dots` carries each unit's id and sorts ghosts and structures first, the selection last.

**Why:** the user asked for the unit icons on the minimap (BAR's minimap shows them).

### C-123 — Deposits: C's models (or a dark patch) without glow, hidden under structures; a BAR-style overlay while placing extractors or on F4; minimap rings (2026-10-23)

**Decision:**
- **Data:** `Core/Deposits` lists deposits, finds their holders (known structures over the cell, ghosts as "remembered"), picks a variant and yaw from the cell, and formats the yield.
- **Ground:** `Render/Deposits` draws C's `fx.deposit` variant once approved (`MeshModels.deposit`; the TeamColor `base` tinted to the terrain colour; materials `fx_deposit_<i>`), else a dark patch and stones. A live structure on the cell hides it. `Render/Ground` no longer draws plates.
- **Overlay:** while placing an extractor (yield = rate × value) or toggled with F4 (the value). Free deposits get a ring and text, others' a dim marker, own nothing. It's a SurfaceGui on a flat part turned to face the camera; `AlwaysOnTop` stays false, since true hides a SurfaceGui under a Workspace part.
- **Minimap:** neutral rings, filled in the holder's team colour.

**Why:** the user's brief (no neon, no flat coloured squares; highlight only when it helps). models-C's `fx.deposit` contract.

### C-124 — Settings top right; the Follow button removed (T in developer mode); the F3 readout bottom right (2026-10-23)

**Decision:**
- **Settings (O):** top right (was top left, C-109).
- **Follow:** the on-screen button is gone; T follows only with `devMode` on. `devMode` is a new setting (Settings > Interface), on in Studio and off in a live game. `SettingsMenu.state` lets earlier key handlers read it.
- **Debug readout (F3):** bottom right.
- **Keys page:** a "Developer mode" group with T and F3.

**Why:** the user's layout request ("keybind available in the developer mode").

### C-125 — Unit panel: model portrait with the type icon; economy flow instead of HP numbers (2026-10-23)

**Decision:**
- **Portrait:** `UI/Portrait` (the build menu's) with the type glyph at 18 px bottom right; a contact keeps its icon alone. The health bar stays, the HP text is gone.
- **Flow:** `Core/UnitFlow` gives own units' supply / power per second from defs and client state (production, wind × the team's wind, extractor rate × deposits under it, converters while on, upkeep, factory / builder drain = cost × buildpower ÷ buildTime × the slower stall ratio; frames 0). It's drawn as "+5" / "−10" in the cost colours.
- A builder's target is the nearest own unfinished frame within its range + 16 studs, the Waypoints rule; the sim doesn't send it.

**Why:** the user ("show its current ore and energy usage, like +5 or −10").

### C-126 — The cheat line's arrow keys cycle suggestions first (2026-10-23)

**Decision:** while suggestions show, Up / Down move a highlight through them (Up from none: the bottom one, next to the bar), and Tab or Enter takes the highlighted one without sending. With no suggestions showing, they walk the history. WASD camera panning is not added (the user: middle-drag is enough for now; A / S stay Attack / Stop).

**Why:** the user's request, and their answer on the history.

### C-127 — Inferno's beam: green, then back to orange (2026-10-23)

**Decision:** Inferno's beam stays orange (255, 170, 70). It was made green in `0d6ca37`, then reverted the same day.

**Why:** the user asked for green, then said orange is fine. The towers' other differences (blip targeting, misses, a lingering beam, Inferno weaker) are sim request 47.

### C-128 — Radiance's ray: bluer, held 3 s, narrowing over its last second (2026-10-23)

**Decision:**
- `Core/Effects.beamSeconds(weapon)` = `weapon.beamDuration` (S-113), else BEAM_FALLBACK by id (Radiance 3, Inferno 1.5), else 0.45 s.
- `Effects.beamLook(age, life)`: full width and bright, then the last BEAM_FADE (1 s, at most half the life) narrows the ray to nothing as it fades.
- Radiance's colour is (120, 190, 255); Inferno stays orange.
- models-C will build the beam VFX; this ray is the placeholder.

**Why:** the user's description. The hit-ray damage and manual-target rules are sim request 49.

### C-129 — Beams glance off shield domes (drawn) (2026-10-23)

**Decision:** `Core/Effects.deflection` checks a missed BEAM FIRE that ends within 2 studs of a known dome's surface (generator position, `def.shield.radius`) and was fired from outside it. The ray is mirrored about the surface normal and tilted down at least 0.45, 8–90 studs long to the ground; `Render/Effects` draws that second leg from its own pool. It applies once the sim ends beams at domes (sim request 50).

**Why:** the user's sketch ("the shield can deflect incoming laser").

### C-130 — The fog blanket's vertex spacing grows with the map: at most 2 × 2 chunks (2026-10-23)

**Decision:** `FogBlanket.stepFor(cellsX, cellsZ)` = max(STEP, ceil(max side / (2 × CHUNK))): 2 cells on 128-cell maps, 4 on 256-cell maps. Every map needs at most 4 EditableMeshes.

**Why:** on Normandy, 16 chunks hit the device's editable memory budget (Studio: "Failed to create empty EditableMesh ... memory budget limits") and parts of the map lost their fog (the user's screenshot). The budget is shared with the shield fx, charts and vignette.

### C-131 — Shield hits: no ripple; a patch of fine outlined honeycomb cells (BAR's plasma deflector) (2026-10-23)

**Decision:**
- The ripple emitters are removed (ShieldFx's ripples, ShieldLook.RIPPLE_SCALES / rippleBucket).
- The plate mesh is a hexagon outline (OUTLINE 0.16 of its corner radius, both windings).
- Shield.PLATE 2.6, GAP 0: the outlines form a honeycomb. Rings: 3 + strength, clamped to 3..5 (MAX_RINGS 5).
- The plate pool is 560, with opacity 0.85 (thin lines don't bloom into a block).

**Why:** the user's reference GIF of BAR's plasma deflector: no ripple, a lit honeycomb patch where the shot lands. "The current ripple takes too much space, drop it and enhance the hexes."

### C-132 — Shield hits cave in: the wave runs inward, bigger centre cells, a bowl that bounces (2026-10-23)

**Decision:**
- **Timing:** `Shield.plateAt(age, ring, strength, rings)` delays a cell by (rings − ring) × RING_DELAY, so the rim lights first and the centre last. The centre stays hottest.
- **Sizes:** `Shield.cellScale` = 1.3 − 0.55 × ring / rings. The layout spreads the arc by (1 + 0.3 × (1 − d / reach)), so inner rings sit wider apart. Render sets each cell's Size from its scale.
- **Dent:** depth DENT (1.4) × strength × (1 − (ring / (rings + 1))²) × e^(−7t) × sin(16t): in first, then a small bounce past flat. `plateLook` keeps the largest |dent|.

**Why:** the user, from the reference GIF's later shots: "smaller outside, bigger inside... pushed back inward... curved in to repel the shot".

### C-133 — models-C's beam shot draws the beam towers' shots (after approval) (2026-10-23)

**Decision:**
- `Render/BeamShots` builds C's rig (core, glow, filaments, charge flipbook, impact, scorch) from `Meshes.beam`, pooled and capped at 8. It preloads the 8 textures.
- Timing follows the shot's duration (Core/Effects.beamSeconds): charge, then held, then the last BEAM_FADE narrows it.
- Widths go to BeamShots.TIP (0.08) at the target end (the user: a point at the tip). Filaments converge there.
- `Render/Effects` hides its placeholder ray while the rig draws.
- It's used once `Meshes.beam.status` is approved; `Invoke("beamsanyway", true)` previews it.

**Why:** the user asked models-C for the beam VFX; C's reference module `assets/fx/beam/BeamShot.luau`.

### C-134 — Shield hit cells move inward only (2026-10-23)

**Decision:** the dent is depth × x × e^(1 − x) with x = t / DENT_PEAK (0.12 s): pushed in, then eased back to the surface, never past it. C-132's damped swing went outward after its first half-cycle.

**Why:** the user saw the honeycomb moving outward instead of into the shield.

### C-135 — The beam shot follows models-C's update (tip, fan, muzzle star, flare offsets) and the game speed (2026-10-23)

**Decision:**
- Widths and filament convergence come from `Meshes.beam` (`tip` order 0.06 / chaos 0.08, `fan` 0.3), replacing my own constants.
- The muzzle star flare comes from `muzzleFlareSize`, and the charge, star and impact flares carry C's StudsOffsets.
- Rigs age by game time (dt × speed), so a slowed game slows the shot.

**Why:** models-C's beam update (0ccf6c3, ff6072d), from the user's notes to them, and the user's 0.25× test.

### C-136 — Larger shield hit patches (2026-10-23)

**Decision:** Shield.PLATE 3.2 (was 2.6); rings 4 + strength, clamped to 4..6 (61 / 91 / 127 cells); ShieldFx.PLATE_POOL 800.

**Why:** the user: "honeycomb effect is good, make it cover a larger part of the shield".

### C-137 — Client after S-104..S-116: stopgap icons, the extractor ghost on supplyUnder, specs on the new rules (2026-10-23)

**Decision:**
- **Icons:** stopgaps for ord_sanction / chs_scourge (Artillery Emplacement), chs_wraith (Strategic Bomber), ord_providence / chs_cerberus (Radar SAM Site) and ord_custodian / chs_chimera (Mobile Radar SAM). Same sheet, so no re-upload.
- **Placement:** `Placement.check` uses `PlacementRules.supplyUnder`, so an extractor works any deposit under its footprint, as the server does.
- **Specs:**
  - Nuke: a Cerberus intercepts, and radar SAMs no longer track the nuke.
  - Placement: the ghost covers the deposit.
  - ShieldWire: measured from the real dome centre, drawn a tick behind like the game.
  - Upgrades: builders kept clear of the 3×3 footprints.

**Why:** sim-A's merge 522ca80 (S-104 footprints, S-108 upgrades, S-111 anti-nukes) broke 8 client specs, as sim-A warned.

### C-138 — models-C's honeycomb shell on shield domes (after approval); the beam shot held for the sim's beamDuration (2026-10-23)

**Decision:**
- **Shell:** `Meshes.shieldShell` bands are loaded once (CreateMeshPartAsync), cloned per dome, and sized and placed each frame with the dome (band.size × R, band.center[2] × R above the base). Transparency = 1 − band.opacity × charge × the dome's opacity.
- **Shell look:** the "shieldShell" SurfaceAppearance (texture, AlphaMode Transparency) is written to MeshMaterials, because scripts can't set ColorMap; it's tinted where allowed. It's shown once approved; `Invoke("shellanyway", true)` previews it.
- **Beam shot:** BeamShots runs C's latest apply (on from the charge for the shot's duration, the sim's `beamDuration` with C's `duration` as fallback, C's taper at the end, the impact hot spot held, the embers and soot after).

**Why:** the user's honeycomb shell request (models-C's asset, 8fcf418), and their beamDuration note to models-C (8c1281a).

### C-139 — A beam held on a shield lights it every 0.2 s; bigger hit patches (2026-10-23)

**Decision:**
- **Pulses:** a BEAM tracer stopped by a dome (C-129's deflect) gets `pulseAt` and `pulseMass` (the weapon's shield mass, at most 3). `Effects.update` adds a "absorb" ShieldHit at the contact every SHIELD_PULSE (0.2 s) while the beam burns. ShieldDomes maps it to the nearest dome, and it adds a wave to the same patch.
- **Patches:** Shield.PLATE 4.8; rings 5 + strength, clamped to 5..7 (91 / 127 / 169 cells); pool 1000.

**Why:** the user: "do the reflect effect every 0.2s, and I did tell you to make the reflect patches bigger". The drain behind it is sim request 51 (S-117).

### C-140 — The `shield_beams` test profile (2026-10-23)

**Decision:** MatchConfig profile `shield_beams` on flat:128.
- **Yours:** a Phalanx, Fusion, Vehicle Plant and 3 Masons at 50× health.
- **The enemy:** Radiances east, west and south and an Inferno south-east, all on attack-ground at the dome's middle; Juggernauts and Ravagers shelling it; an Eye radar; 2 Fusions and 6 depots for beam power (startResources 20,000 power).

Until sim request 52 (the weapon on SHOT), beams from shooters you can't see draw as plain tracers, so play it with `/reveal on`.

**Why:** the user: "a scenario of a shield of mine against some radiance from different angles + some shots".

### C-141 — More, smaller rings in shield hit patches (2026-10-23)

**Decision:**
- Rings are 6 + strength, clamped to 6..9 (127 to 271 cells). Rim cells are a third of the centre's size (RIM_SHRINK 0.85).
- Each ring sits as far out as its cells are big (the arc is the integral of cellScale), so the centre cells spread and the rim cells pack tight. This replaces C-132's SPREAD.
- RING_DELAY 0.05 so the inward wave still reaches the centre quickly. Pool 1300.

**Why:** the user: "add more smaller rings to the honeycomb reflect".

### C-142 — Even more outer rings; models-C's review effects show in Studio (2026-10-23)

**Decision:**
- **Rings:** 8 + strength, clamped to 8..11 (217 to 397 cells). RIM_SHRINK 0.9, RING_DELAY 0.04, pool 2000.
- **Review effects:** `BeamShots.ANYWAY` and `ShieldFx.SHELL_ANYWAY` default to `RunService:IsStudio()`. Studio is where the user reviews, so they no longer need the debug commands there; live servers still wait for "approved".

**Why:** the user: "also add more rings of outer honeycombs. Where's the effect from C?"

### C-143 — Detailed models load fast (pieces built in parallel), the camera area leads a moving camera; hidden beams drawn as beams (2026-10-23)

**Decision:**
- **MeshModels:** a model's pieces and glow parts are created at once (`together`), and 8 models build at a time (was 4). All 74 Normandy types are ready in ~15 s, against ~70 s before (25 ready after 34 s) once models-C split meshes into many pieces.
- **Camera:** the area sent to the server is stretched up to 0.8 s / 400 studs ahead of the camera's motion, so units ahead become tactical (full models) before they scroll into view. The minimap box keeps the true view.
- **SHOT (protocol 28, S-118):** `weaponIndex` picks the weapon. A BEAM draws as its held beam in its faction's colour (from the weapon id), with the dome glance and pulses (a shared `shotTracer` with FIRE).

**Why:** the user: blockouts showing before detailed models when panning fast; and "in BAR, a Pulsar's beam renders even with no vision".

### C-144 — A beam continues past a dome that drops; thinner flowing rings on the dome (2026-10-23)

**Decision:**
- **Beam continuation:** `Effects.continueBeam`. A FIRE / SHOT from a beam weapon whose beam still burns, starting within 3 studs of it, moves that beam's end (new end, hit flag) and drops its glancing leg and dome pulses, keeping its start time. BeamShots follows the moved end. It's ready for sim request 54 (on the tick a dome drops, a new FIRE / SHOT to the target).
- **Flowing rings:** ShieldFx.RING_TUBE 0.0015 (was 0.004), at least 0.06 studs.
- **Not kept:** a 20 to 26 ring patch with a wide rim of tiny cells, tried as "C-145". The user: "too much"; it also cost ~25 ms a frame, with peaks over 300 ms, under shield_beams. The honeycomb stays as in C-142.

**Why:** the user: the beam should go through once the dome drops; "reduce the size of the ring flowing down the dome".

### C-145 — Shield domes drawn without vision (DOME / DOME_GONE, protocol 29, S-122) (2026-10-23)

**Decision:**
- **World:** `remoteDomes` keeps domes whose generator the player doesn't have (centre, radius, charge, flags). NetIn sets it from DOME and clears it on DOME_GONE; the branches are guarded until the event kinds exist.
- **ShieldDomes:** draws from both sources by generator ID (tactical SHIELD first). A dome carries over when its generator enters view: same ID, its ENTER and SHIELD take over and the DOME_GONE comes after.
- Hit patches already map to the nearest dome.

**Why:** the user: "the shield dome (only the dome) should be rendered regardless of vision like in BAR".

### C-146 — The Commander mechs walk (2026-10-23)

**Decision:** piece script `PieceScripts/Commander` for ord_sovereign and chs_warlord.
- **Moving:** models-C's stride pose (thighL +28 / shinL −18 / footL −10, thighR −22 / shinR −30 / footR +20) and its mirror alternate, one stride per 0.6 s. The arms swing ±18° against the legs, the torso twists ±6° and the pelvis dips 0.12 studs per step.
- **Stopped:** everything eases back to rest.
- Create, aim and fire come from Default.

**Why:** models-C's M-31 (the user's request); the meshes (2b4dc5b) are at review, so the blockout mechs walk until they're approved.

### C-147 — A continued beam that now ends on another dome glances and pulses there (2026-10-23)

**Decision:** `Effects.glance(world, weapon, tracer, now)` holds C-129's deflection and C-139's pulse setup, and now also includes unseen domes (`world.remoteDomes`, S-122). New beams run it, and so does `continueBeam` whenever a moved end falls short (hit = false), so the glance and pulses follow to the new dome.

**Why:** the user's overlapping-domes screenshot. The rule that a beam's line is re-checked against every dome each tick is sim request 56.

### C-148 — Mech stride re-tuned for the heroic mechs (2026-10-23)

**Decision:** Commander POSE follows models-C's M-32 stride: forward leg thigh +24 / shin −8 / foot −16, back leg thigh −18 / shin −22 / foot +30, pelvis dip 0.2. C-145's domes without vision are verified in Studio on main f3334c7 (S-122).

**Why:** the user rejected the first mechs (too small and blocky); models-C rebuilt them about 10 studs tall with a real knee bend.

### C-149 — Remembered buildings (ghosts) can be ordered attacked (2026-10-23)

**Decision:** no code change needed. Ghost structures arrive as strategic records under their real unit IDs, so `Selection.pick` picks them and `Orders.smart` / Attack mode send ATTACK with that targetId. A spec pins it down (Orders.spec).

**Why:** sim-A's S-127, from the user: units no longer auto-target ghosts, only on an attack order or manual target.

### C-150 — Allies told apart: right-click on an ally guards / assists (2026-10-23)

**Decision:** `World.welcome` keeps WELCOME's `teamAllies` (protocol 30, S-129; empty before it). `World.relation` returns "ally" when `teamAllies[team] == me.allyTeam`. `Orders.smart` sends GUARD (guard, or assist a builder, S-128) on allies and ATTACK only on enemies. Attack mode still targets anyone explicitly. Spec in Orders.spec. Without the list, other teams count as enemies as before.

**Why:** right-click on an ally's unit attacked it in team games; sim-A offered the ally list (S-129).

### C-151 — Radar blips glide instead of jumping (2026-10-23)

**Decision:** `World.smoothStrategic(world, dt)` runs once a frame: each strategic record's drawn spot (sx, sz) eases toward its latest reported spot (time constant 0.45 s) and snaps on a jump over 160 studs. NetIn carries sx / sz across snapshot rebuilds. Contact discs (Ghosts.list), icons, the minimap and picking (Selection.position) draw from sx / sz. Measured in Studio (the radar scene): blips moved on 1,202 of 1,210 frames, at most 1.2 studs a frame.

**Why:** the user asked for the jumping radar blips to move smoothly.

### C-152 — Factories show the unit in production on their pad (2026-10-23)

**Decision:** `Render/FactoryFrames` (logic in `Core/Nanoframe`, spec `Nanoframe.spec`) draws each drawn factory's current item, BAR-style:
- **Where:** the produced unit's pooled model stands on the factory's `buildpad` attachment (rig.md section 8), facing the factory's heading (the exit).
- **What it shows:** from the queue head and `queueProgress` (own factories) or PRODUCING (allies; NetIn now reads it into `producing` / `producingProgress`).
  - Parts below a rising build line show as built.
  - The rest are a team-colored ForceField nanoframe, with SurfaceAppearances detached while unbuilt.
  - A thin neon outline marks the line.
  - Every `nano1..N` emitter sprays a Beam at a point sweeping the line.
- **Progress:** the server sends it in sixteenths, so `Nanoframe.track` eases through each step at the measured step rate (at first the build time over the factory's build power). It never backs down within an item. It stops the spray after 2.5 step gaps with no step (a stalled economy).
- **Pool safety:** the frame's parts can't be picked (clicks on the pad hit the factory). Every look is restored before the model goes back to the pool.
- **When frames are dropped:** at strategic zoom, on rejoin and when models are rebuilt.
- **Checked in Studio** (the `build` profile with a spawned plant and airfield): `debug_out/screens/c152_factory_frame.jpg` and `c152_airfield_frame.jpg`.
- **Enemies' factories show nothing:** the server doesn't send them their production.

**Why:** the user couldn't see factories producing; the only sign was the pulsing factory lights.

### C-153 — The Canyon drawn as a desert, and listed in the lobby (2026-10-23)

**Decision:**
- `Main.mapFeature` gives `Canyon.feature` for `map:canyon`.
- Core/Terrain maps its floor to "desert" (Enum.Material.Limestone, tan 186, 148, 100). Badlands, aprons, cliffs, mesas and boulders map to "redrock" (Sandstone, 168, 88, 58).
- No other map or atmosphere preset uses those two materials, so Render/Terrain sets their colours freely.
- The skirmish lobby now lists every hand-made map (MapRegistry.HANDMADE: Normandy, The Canyon) after the generated ones.
- A committed `canyon` profile has both Commanders at their starts.
- Spec: Terrain.spec. Screens: `c153_canyon_*.jpg`.

**Why:** S-132 added The Canyon; sim-A asked for the floor drawn as pale desert and the rock reddish.

### C-154 — Radar blips circle their spot on the client (2026-10-23)

**Decision:** `World.smoothStrategic(world, dt, now)` keeps the glide (C-151) in gx / gz. Radar and sonar records are drawn 1.5 studs out on a circle round it, one turn in 6 s, with start angle and direction from the id. Other strategic records sit on their spot. Measured in Studio (`radar`): four Ravager blips at r 1.26–1.74. Spec: Minimap.spec.

**Why:** the user wanted BAR's 1–2 stud circle (request 60). S-131 put the orbit on the server, but strategic records carry only the cell, so it never showed: blips sat still or hopped cells. Sim-A has been told and may drop the server's drawn offset.

### C-155 — Each map has its own look; The Canyon is a desert day (2026-10-23)

**Decision:** `Core/MapLook` gives each map:
- its atmosphere preset (lighting, time of day, grade);
- the colour of the land past its edge;
- the dust and mist particles' colour and wind.

Maps without an entry get the moonlit night (C-101). Details:
- **The Canyon:** a new "desert" preset: clock 14.5, warm sun, light sandy haze (thicker washed the map out in Studio), crisp shadows, procedural day sky. Sand-coloured dust blows across a tan skirt.
- **Settings:** atmosphere gets "Map's own", the new default, which follows the map. The other presets still override it.
- **Applied:** `Atmosphere.setMap` on each new map.
- Spec: MapLook.spec. Screens: `c155_canyon_day_*.jpg`.

**Why:** the user: "Each map will have its own environment + lighting settings + effects + time of day. For Canyon, it should be during the day".

### C-156 — Animated pieces run by state: radars, drills, wheels, gantries (2026-10-23)

**Decision:**
- `Core/PieceMotion` lists each def's animated pieces: the blockout's part `anim`, overridden by the mesh manifest's `anim` on the same name. Axes are mapped to x / y / z with a sign.
- PieceAnim's driver re-plans them through `PieceScripts/Ambient` on every unit, whenever moving, power (off, stalled or unbuilt = 0; else the own team's power ratio in quarters, others count as powered), producing or landed changes.
- What Ambient does:
  - wheels roll while moving;
  - radars, dishes, arrays and sonar drums sweep at 60 / 40°/s × power;
  - drills turn at 160°/s × power;
  - jammer emitters spin;
  - cranes and jibs swing ±30°;
  - factory gantries and trolleys run their rail while producing;
  - windmill rotors always turn, and a helicopter's tail rotor runs with its main rotor;
  - track sets judder while moving (no texture scroll: no texture yet).
- Powered pieces wind up and down at 180°/s².
- `open`, `lower`, `pulse` and `swing` stay with their own scripts or the glow.
- Spec: Ambient.spec. Checked in Studio: the airfield radar turns 61° in 1 s; the Chaos plant's trolley slides 2 studs a second while producing. Screen: `c156_ambient_pieces.jpg`.

**Why:** the user's queue item 2: "Animation pass with C's animated pieces ... driven by power and on/off state".

**Not done:** a sonar "ping" effect and a jammer shimmer beyond the spinning emitter. Both would be new VFX, not pieces.

### C-157 — BAR's selection panel: tile clicks keep, drop or widen a type (2026-10-23)

**Decision:** with several units selected, the unit panel's type tiles (icon and count, C-71) now follow BAR (`Selection.tileClick`):
- a click keeps only that type;
- Shift-click drops it;
- Ctrl-click selects every own unit of that type on screen (`Selection.sameTypeOnScreen`, as a double-click).

Spec: SelectionTiles.spec. Screen: `c157_selection_tiles.jpg` (2 Masons and 3 Lancers).

**Testing note:** Studio MCP's simulated clicks reach the world under a GUI button: the click lands as an empty-ground click and clears the selection, and the Lobby Start button missed the same way. A real click is consumed by the button. So the tile logic is covered by the spec, not by an MCP click.

**Why:** the user's queue item 3.

### C-158 — Idle builders and factories: top-strip counts, I to cycle, IDLE tags (2026-10-23)

**Decision:**
- `Core/Idle` counts own idle builders and factories:
  - a factory with an empty queue, or none sent: the server sends one only once there's been a queue;
  - a builder that stood still 3 s with no orders still shown (Waypoints) and no own frame going up within its build range.
- `UI/IdleStrip`: "Idle builders (I): n" and "Idle factories: n", right of the resource bar, amber when non-zero. A click picks the next one.
- **I** selects the next idle builder and the camera follows it (`Idle.next` walks them by id and wraps).
- `Render/IdleMarks` puts a small IDLE tag over each idle builder. It's screen space, like HealthBars: a BillboardGui didn't render.
- Checked in Studio: 3 idle builders (2 Masons and the Commander) and 1 idle factory. Spec: Idle.spec. Screen: `c158_idle_marks.jpg`.

**Limits until sim request 62:** only units in the tactical tier count, and a builder repairing or assisting without a client-sent order can read as idle. Request 62 asks the server for an owner-only idle signal that covers off-camera units too.

**Why:** the user's queue item 4.

### C-159 — Rebindable keys in Settings > Keys, saved per player, with clash warnings (2026-10-23)

**Decision:**
- `Core/Keybinds` lists the 23 single-key actions with their defaults: orders, building, camera and views, the developer follow key.
- Keys that can't be bound: digits, arrows, modifiers, Enter / slash, Escape, the sim-speed keys, F3.
- `Keybinds.conflicts` reports actions that share a key; encode / decode save only what differs from the defaults.
- `SettingsMenu.applyKeys` writes the bindings into Controls, Camera, BuildMenu, RangeOverlay, MissileView and Deposits. Main reads the idle and follow keys through `SettingsMenu.key`.
- The command card's hover hint, the idle strip and the Settings button show the bound keys.
- **The Keys page:** a button per action. Click it, press the new key (Escape cancels); while it waits, the game ignores keys. A clash shows "also: …" in red on both rows. Reset to defaults. Then the fixed keys (mouse, groups, camera) as a table.
- **Saving:** the `Keybinds` RemoteFunction (src/roblox): "get" / "set". A live server keeps them in the FtggSettings DataStore. Studio refuses DataStores without API access, so there they last for the server session.
- **Defaults change:** camera turn right moves from E to C, because E was both reclaim (C-109, BAR's) and turn right.
- Checked in Studio: Stop rebound to A showed the clash on Stop and Attack, and the server returned "stop=A" (reset afterwards). Specs: Keybinds.spec, Settings.spec. Screen: `c159_keys_conflict.jpg`.

**Why:** the user's queue item 6.

### C-160 — The Commander walk on models-C's v3 mechs; a review-mesh preview switch (2026-10-23)

**Decision:**
- No change to the walk: the v3 meshes (M-33, merged) keep the pieces the Commander script drives (thighL / R, shinL / R, footL / R, armL / R, torso, base). The new hipL / hipR stay still.
- To see a review mesh in game there's now a Studio debug switch: `FtggClientDebug:Invoke("reviewmesh", defId)` builds that one review entry (`MeshModels.REVIEW`), and units of it redraw with the mesh.
- Checked on the `build` profile: the Sovereign v3 mesh built in 6 s. Walking to a move order, its left thigh swung −18° to +24°. Screen: `c160_mech_v3_walk.jpg`.
- The Warlord runs the same script on the same piece names.

**Why:** the user's queue item 7: "Commander walk animation once C's version-3 mechs merge". The mechs stay at "review" until the user approves them through models-C.

### C-161 — Own and seen units stay drawn and selectable out of the camera area (2026-10-23)

**Decision:**
- **Strategic records keep their type:** a record whose icon is a type (own, allied or seen; not radar, sonar or ghost) gets that type as its `defIndex`, since the icon is the def index (Shared/Net/Icons).
- **And the last tactical detail:** a unit that was tactical keeps heading, altitude, health, build, state, aim, queue, fire / move state, ammo and stock. It keeps its exact spot while the server's cell still holds it, so buildings and parked units don't shift.
- **UnitRenderer draws them:** at their gliding spot (C-151) with the last heading. Aircraft in the air are left to the icons.
- **No pop:** a unit leaving the camera area keeps its model, and on ENTER the same model carries on.
- **Panels:** a selected unit far away keeps its unit panel, build menu and command card, so you can keep giving a Mason build orders anywhere.
- Checked in Studio (`build` profile): 7 models before, while the camera was 800 studs away and after; all 7 the same instances on return. The Commander's panel and build menu stayed with the camera away. Spec: OffCamera.spec. Screen: `c161_panel_off_camera.jpg`.

**Limit:** off camera the server sends only cell, type and flags. So a far unit's health and a far frame's build progress show their last values until the camera comes back. Fixing that would need the server to send own units in full there (sim-side, a bandwidth question).

**Why:** the user: "I really dislike the way the map re-render when my camera go away and back, also I don't want my unit to be de-render when out of view. I was selecting targets for my mason to build far away and I move out of the view of it, the panel gone ?"

### C-162 — Camera.Focus on the ground point looked at (2026-10-23)

**Decision:** `Camera.apply` sets `cam.Focus` to the ground point the camera looks at. The engine prioritises some work (lighting and the like) round Focus.

**Not a fix for the terrain refinement:** after a long jump (a minimap click across The Canyon), Roblox's voxel terrain draws the new area coarse and sharpens it over about 4 s. That's the engine's terrain level of detail, driven by camera distance, and setting Focus didn't change it. Screens: `c162_jump_before.jpg` (just after the jump) and `c162_jump_after4s.jpg`. The options are the user's call.

**Why:** the user: "the map re-render with better quality" after a minimap jump.

### C-163 — Builders assist: right-click an own factory or frame (2026-10-23)

**Decision:** the smart right-click is split by unit (`Orders.smartFor`):
- on an own frame, finished factory or damaged unit, selected builders get REPAIR (build it, help the factory's production, heal it) and the other units GUARD it;
- on an own builder everyone GUARDs, which for builders is S-128's assist: they help whatever the leader builds, then follow it.

The command card's Guard button reads "Assist" when only builders are selected. Spec: Assist.spec. Through the real server, a Mason right-clicked onto a producing plant works on it with `assist` set.

**Why:** the user: "where is the 'Assist' of the workers that can help build unit/structure faster and follow the leading command?" A right-click on an own finished factory used to send GUARD, which only followed it.

### C-164 — Minimap: drag moves the camera; the view drawn as its ground trapezoid (2026-10-23)

**Decision:**
- A left press on the minimap moves the camera there and keeps moving it while the mouse drags; the release ends it.
- `Camera.apply` keeps the four ground corners of the screen (`state.corners`, passed through `api.state.camera.corners`). The minimap draws them as four 1-px lines (`Minimap.cameraShape`), so the view reads as the trapezoid it is. The cell box is the fallback until the camera has corners.
- Checked in Studio: a drag from the middle of the minimap to the lower right left the camera at the drag's end (140, 192). The trapezoid shows in `c164_c166_grid_trapezoid.jpg`.

**Why:** the user's items 1 and 2.

### C-165 — A placement can't overlap a build already queued (2026-10-23)

**Decision:** `Placement.planned` lists the footprints of the builds the player has queued and not started (Waypoints' BUILD points). `Placement.check` counts them as occupied for:
- the ghost's tint;
- a click;
- each spot of a dragged row (earlier spots of the same row included);
- extractor drags and Upgrade extractors.

Extractor drags also drop spots that share cells with an earlier spot of the same drag. Specs: Placement.spec (new case) and Upgrades.spec: a T2 drag no longer plans over the Mason's queued T1 spots.

**Why:** the user: "When placing preview model to build, you can place 2 model that violate each other hitboxes?"

### C-166 — The build grid round the placement ghost, a Settings toggle (2026-10-23)

**Decision:**
- While placing, the 8-stud build cells within 6 cells of the ghost are drawn as thin light lines on the ground: one segment per cell edge, so they follow slopes, fading toward the edge.
- They're laid again only when the ghost crosses a cell corner. They live outside the ghost's folder, so its Highlight doesn't tint them.
- Settings > Interface "Build grid", on by default.
- Checked in Studio: `c164_c166_grid_trapezoid.jpg`.

**Why:** the user's item 3: "Add grid box guidance (toggle in setting)".

### C-167 — Baked mesh ground for the named maps (with models-C); terrain keeps only the water (2026-10-23)

**Decision:** the named maps' ground will be uploaded mesh tiles, baked by the models stream from the client's own surface data. The contract is `docs/contracts/map-ground.md`.
- `lune run export_ground [mapId | all]` writes each map's ground.json:
  - heights every 4 studs from Core/Terrain.groundY, so the bake matches what units stand on;
  - the ground type per cell, and the Canyon / Normandy features (where rock detail goes);
  - water depth, deposits and starts.
- The tiles go in a `ground` table in the mesh manifest, their textures in `groundMaterials`. `lune run mesh_materials` writes the textures as `ground_<key>` SurfaceAppearances.
- `Core/GroundMeshes` picks a map's entry: approved, or review with `FtggClientDebug:Invoke("groundanyway", true)` in Studio. Until a texture exists, a tile gets a plain material and colour matching the voxel terrain.
- `Render/MeshGround` builds the tiles 12 at a time with CreateMeshPartAsync: Precise fidelity, anchored, queryable for ground clicks.
- `Ground.build` takes the map ID: with an entry, the terrain gets only the water (`RenderTerrain.build(..., waterOnly)`). Maps without one keep the voxel terrain as before.
- Spec: GroundMeshes.spec. Nothing to see in Studio until models-C's first tiles.

**Why EditableMesh isn't used:** the user rejected the terrain's coarse-then-sharp redraw after camera jumps (C-162). Ground built in game as an EditableMesh would need about 160,000 vertices on The Canyon, but the device's editable-memory budget ran out at about 7,600 (Render/FogBlanket's note). Uploaded meshes have no such budget and render at full detail at any distance.

### C-168 — A producing factory shows its item's progress bar (2026-10-23)

**Decision:** an own or allied factory that is producing gets a second bar under its health bar, always, selected or not. It's amber, the UI accent, so it reads apart from the blue construction bar. It shows the item's progress as the hologram draws it (FactoryFrames' eased value, `u.productionShown`), else the server's sixteenths. Spec: Bars.spec, through the real server.

**Why:** the user: "Still no progress bar for building", over a selected vehicle plant producing a tank.

### C-169 — Ctrl moves keep the group together (GROUP); idle counts from the server; queueing in a frame (2026-10-23)

**Decision:**
- **Ctrl + move:** right click, a line drag, a Move / Fight / Patrol command click and a minimap right click held with Ctrl send `Schema.CmdFlag.GROUP` (S-137, protocol 31). The selection's ground units then move no faster than the slowest one. `Orders.Intent.group`, only on MOVE, FIGHT and PATROL.
- **C-158 now counts from the server's IDLE events** (S-136): `world.idle`, cleared on a join and on a unit's death. Every idle builder and factory counts, on camera or not, and the I key jumps to one anywhere (its model stays drawn off camera, C-161). The client-side guess is gone.
- **S-138:** a factory frame takes the build menu's queue; the client needed nothing new.
- Specs: Idle.spec (through the real server, off camera included) and FrameQueue.spec (a frame's queue round trip; GROUP on the right commands).

**Why:** the user's queue item 5 (group speed), request 62 (idle) and request 63 (the user: "Still not replicate build command when the building is being built").

### C-170 — A recharge bar for long-reload weapons (Radiance, Inferno and others) (2026-10-23)

**Decision:**
- The client notes each weapon's last shot it sees (`World.noteShot`: a FIRE, or a projectile launch from a known shooter), with the sim tick.
- For own and allied units, every weapon with a reload of `World.RELOAD_BAR` (4 s) or more shows a thin pale-blue recharge bar under the health (and build) bar. The bar fills from the shot over the weapon's reload, the server's own timing (Sim/Weapons starts the reload at the shot), and goes when charged. With several such weapons, the least charged one shows.
- Spec: Bars.spec, a Radiance through the real server: the bar shows for most of its 9 s reload and fills from empty to full. Checked in Studio on `duel`: `c170_reload_bar.jpg`.

**Limit:** a shot the client didn't see (the unit off camera) starts no bar.

**Why:** the user: "Add recharge energy bar for the Radiance/Inferno too, any weapon reloads that long need to have that attack cooldown indicator".

### C-171 — The live server runs sim-A's tick-budget watchdog (2026-10-23)

**Decision:** `src/roblox/Main.server.luau` makes a `Watchdog.new(sim)` with every new sim (match, lobby preview, test profile) and calls `Watchdog.afterStep(dog)` after each live `Sim.step`. On a tick over 54 ms, or with a system over twice its guide 18.1 budget, it warns at most once a second; every 60 s it logs a summary. Checked in Studio: it loads and runs with no errors.

**Why:** sim-A's S-140, the user's queue item 5 there; src/roblox is the client stream's.

### C-172 — The Commander stops rotating: Ambient moves only the pieces it knows (2026-10-23)

**Decision:** PieceScripts/Ambient (C-156) now spins or turns only named pieces:
- wheels, rotors, tail rotors and jammer emitters (band, tip, spine);
- radars, dishes, arrays and sonar drums and rings;
- drills, and cranes (jib, jib1, jib2, deckJib, deckCrane).

Any other spin or turn piece is left to its unit's own script. The v3 Commander mechs mark their torso and head as `turn`, and the old catch-all spun them like radars. Checked in Studio: the Sovereign's torso and head hold at 0°. Spec: Ambient.spec (the Commanders' torso and head stay still). Also: the tidal rotor test reads its axis from the model, since models-C's new mesh turns it about X.

**Also checked:** with models-C's approved T1 batch merged here (m-models 671732b), all 31 meshes on the `build` profile built in 6 s with no failure (`c172_t1_meshes.jpg`).

**Why:** the user: "also why is my commander rotating around ?"

### C-173 — The match place's side of the lobby contract: boot from the stored config, loading screen, results record, return trip (2026-10-23)

**Decision:** the lobby stream's (session D's) requests B-1..B-3, following `docs/contracts/match.md` v1.
- **Match role.** A reserved server of this place (`PrivateServerId` set, no owner), or the Studio profile `contract`:
  - **finds its match:** `server/<PrivateServerId>` → matchId → `config/<matchId>` in MemoryStore `FtggMatch`;
  - **checks it** with `src/roblox/MatchContract.luau`'s copy of the lobby's `MatchConfig.validate`;
  - **builds the sim** from it (`MatchContract.toSim`: Order odd, Chaos even, ally teams, AI levels; `start == id`);
  - **reuses the skirmish plumbing:** a lobby-style seat list (`toLobby`) keeps `Lobby.results`, `Lobby.done` and the results screen working.
- **Admission.** Listed players take their seats (rejoin = join), listed spectators watch, anyone else is kicked. Studio's `contractAdmitAny` seats the playtester.
- **Loading.**
  - The match waits ("waiting") until every listed human's client has loaded, or 90 s after the first did.
  - The sim keeps stepping so clients get the map and the replay stays continuous; the AI is paused and players' commands are dropped until the start.
  - The client's `Render/Preload` measures real caching: joined, ground built, every approved unit mesh built, the SurfaceAppearances preloaded. It reports every 0.5 s.
  - `UI/MatchLoading` is the BAR-style screen: dark art placeholder, room and map, each player's progress, a tip line, a long olive bar.
- **Heartbeat** `alive/<matchId>` every 30 s, TTL 120.
- **Result.** `result/<matchId>` is written once when the match ends for the humans. `MatchContract.outcomeOf` decides:
  - the sim's own end: "finished" with the winner, or "draw";
  - otherwise "abandoned" when no human is left on the server;
  - otherwise from who still stands: one ally team → it won; else "draw" with a reason.
- **Record contents:** flat stats by the Stats.report names. If every player leaves early, the record is "abandoned". A refused config writes "abandoned" with the reason and sends players back.
- **Return.** The results panel shows "Return to lobby" for everyone, with a 30 s countdown (`Statistics` Actions `backLabel` / `returnAt`). Then the server teleports each player or the rest:
  - to `config.lobby.placeId` with `ServerInstanceId = config.lobby.jobId` and teleport data `{ matchId }`;
  - on failure, or on `TeleportInitFailed`, again without the server ID.
- **Player colours.** The server publishes each sim team's palette index (`TeamColors` attribute); `Render/TeamColors` now uses the lobby's 12-colour palette, entry n for team n without it.
- **Dev path unchanged:** test profiles and the in-match skirmish lobby work as before, not extended.
- **Checked:** spec MatchContract.spec, which plays a Teams match from a contract config through the real sim; the records pass the lobby's own `validateResult`. In Studio on `contract`: the config is read from the stand-in store, the playtester admitted, the loading screen held until loaded (about 15 s for the meshes), and the match played. Then the result was written, the countdown shown, and the return trip printed after 30 s. Screens: `c173_loading_screen.jpg`, `c173_return_countdown.jpg`.
- **Only a published test can check** the MemoryStore, reserved servers and teleports (contract section 10).
- **Why:** the user's alpha flow and session D's contract. Copying `validate` follows D's suggestion; it should move to `src/shared` (D owns it), then this copy goes.

### C-174 — Kit: filled action buttons and a text input (2026-10-23)

**Decision:** for the lobby stream (B-4), keeping the kit's API stable:
- `Kit.button(parent, text, kind, onClick, width, fill?)` takes kinds "go" / "stop" (`Kit.COLOR.go` / `stop`) or any `fill` colour: a filled button with a light hover.
- `Kit.input(parent, placeholder, width?, onEnter?)` is a text box in the control style, D's `Ui.input` signature.

Existing calls are unchanged.

### C-175 — Every human out while AI teams fight on: "finished" with no winner (2026-10-23)

**Decision:** `MatchContract.outcomeOf` now returns "finished" with no winner when every human is out and several AI teams still stand. Every player's `won` is then false, so the humans' profiles count a loss. "draw" stays for the sim's own draw and for no team standing. The copy of `validateResult` follows the lobby's: a winner only on "finished", optional there. Spec: MatchContract.spec.

**Why:** the lobby stream's decision in docs/contracts/match.md (m-lobby 287b99e, still v1), answering C-173's open question.

### C-176 — The match's loading screen shows the lobby's key art with the same parallax (2026-10-23)

**Decision:**
- `UI/KeyArt` is a copy of the lobby place's `src/lobby/client/KeyArt.luau` (session D; contract docs/contracts/key-art.md, L-13). It reads the models stream's layered art from the mesh manifest's `keyArt`: approved art everywhere, review art only in Studio.
- It covers the screen at 16:9 with 5% bleed. Each layer moves by mouse × 2.5% of the width × its depth, eased, with a slow idle drift. Dark bands sit behind the title and the bottom text, and the art fades in once preloaded.
- `UI/MatchLoading` shows it when the match starts waiting, under its text and bar (ZIndex 10+). Without approved art it keeps the dark gradient.
- So the lobby's pre-teleport screen and the match's look the same across the teleport.
- Checked in Studio on `contract`: no art in the manifest yet, the gradient shows as before.

**Why:** the user's key-art decision; D asked both screens to behave the same.

### C-177 — Fix: a crane or gantry loop froze the client when its unit went far from the camera (2026-10-23)

**Decision:** PieceScripts/Ambient's jib and gantry loops (C-156) now sleep each swing's time instead of waiting for the turn or move to finish.
- Far from the camera (LOD "far"), turns and moves land at once, so `WaitForTurn` / `WaitForMove` returned without yielding.
- A loop started while its factory was near then spun forever, and the client hit "Script timeout: exhausted allowed execution time" in PieceAnim.step (seen in the user's playtest console).
- Spec: Ambient.spec (a producing plant's loop started near, then far). It hangs with the old code and passes now.

**Why:** a client freeze in the user's playtest.

### C-178 — MatchContract and TeamColors use the shared MatchConfig (2026-10-23)

**Decision:** `src/roblox/MatchContract` now calls `@shared/Match/MatchConfig` (S-145, the module the lobby place uses too) for validate, validateResult, the version and the palette, instead of its copies. `Render/TeamColors` builds its palette from the same module's COLORS. Nothing else changed; MatchContract.spec passes. Checked in Studio only up to the build (the requires resolve); the contract path is unchanged.

**Why:** the user moved the validator to src/shared; lobby-D asked to drop the copies.

### C-179 — One key art viewer: the lobby mounts UI/KeyArt read-only (2026-10-23)

**Decision:** lobby-D deleted its copy (m-lobby 27b4ce0); the lobby place mounts `src/client/UI/KeyArt.luau` read-only as `ReplicatedStorage.ClientKit.UI.KeyArt`, like the Kit. Its header now says so and drops "keep the two in step". The API stays stable: `KeyArt.available()`, `KeyArt.new(parent, zIndex)` returning a view with `show(name?) -> boolean` and `hide()`.

**Why:** the two files were identical below the header; one viewer can't drift.

### C-180 — PieceAnim holds a spinning wait loop to the next frame (2026-10-23)

**Decision:** a piece-script thread that passes through `WaitForTurn` / `WaitForMove` 64 times in a row without yielding (`PieceAnim.SPIN_LIMIT`) is held to the next frame each time after that, with one warning. Any yield (a real wait or `Sleep`) resets the count. A new PieceAnim spec runs the C-177 loop (turn, wait, turn back, wait) far from the camera: it keeps swinging and every step returns. With the guard switched off the same spec hangs.

**Why:** the user's next playtest log still showed "Script timeout" in PieceAnim.step at about tick 16,000. That match most likely started before C-177 reached Studio (it ended at tick 18,970, about 21 minutes in, and was the match already running when C-177 was pushed), and every loop in the piece scripts now sleeps. But one more script written the old way would freeze the client again, so the scheduler itself now refuses to spin.

### C-181 — Lost radar missiles spiral down; radar accuracy in the sensor view (2026-10-23)

**Decision:**
- **Lost radar missiles (S-146):** on LOST_LOCK, a HOMING missile with RADAR guidance steps its velocity with `Guidance.lost(vx, vy, vz, k, projId, 1/15)` before the ballistic step, every tick until it ends. `k` starts at 1 on the first step after the event (`Effects.LOST_FIRST`), because the event carries the state after the server's own first lost tick (k = 0). Effects.spec kills a Wasp once an Aegis SAM has turned onto it: the drawn missile stays within 0.06 studs of the server (with k starting at 0 it drifts 13 studs). IR missiles still fly straight. A target that dies in the launch phase isn't steered at its last spot on the client; the homing corrections carry that path.
- **Radar accuracy (S-147, the user's request):** `Core/RadarAccuracy` reads the Eco record's `radarError`, `trackError` and `precision`. In the missile sensor view (N):
  - each radar blip gets a flat circle of the radius radar-fired shots miss by: amber at `radarError`, green at `trackError` on a tracked contact (TRACKED);
  - a readout under the resource bar: "Radar accuracy ±7.7 studs · tracked ±2.6 · Pinpointers 40%" ("no radar" without one);
  - at most 80 circles; sonar contacts and ghosts get none.
  - RadarAccuracy.spec checks the radius against the server's own, and that two Pinpointers shrink it (±12 → ±7.7 studs).
- Studio: `debug_out/screens/c181_radar_readout.jpg`, `c181_radar_rings.jpg`, `c181_tracked_rings.jpg`.
- **Follow-up (sim-A, S-147):** under a partial power stall a fire-control radar's reach shrinks, so `trackError` holds only for blips still TRACKED. The readout greys its "tracked" part while no blip is TRACKED (rich text, `RadarAccuracy.GREY`); circles already use trackError only on TRACKED blips.

**Why:** the user's report (SAMs flying into the sky when their target died) and request (show the missiles' radar accuracy), both through sim-A.

### C-182 — Point defence on the client: interceptions drawn, stopgap icons (2026-10-24)

**Decision:**
- S-149's interceptors use the anti-nuke path the client already had (INTERCEPTOR chases a projectile, INTERCEPTED drops it). A rocket or tactical missile shot down ends in a small puff (`Effects.INTERCEPT_PUFF`, 3 studs) instead of a nuke's 12.
- New PointDefence.spec: a Sanctum against an MLRS. 21 interceptors drawn chasing their rockets, 16 rockets shot down with 16 puffs, interceptors within ~1 stud of the server.
  - The remaining stud is in an interceptor's last tick or two. The server walks projectiles backwards in its swap-removal list, so an interceptor sometimes steers at its rocket's state after the rocket's own step; the client always uses the start of the tick (C-57). Asked of the sim stream.
  - Fixed by S-151 (the server snapshots chased projectiles at the start of the tick): worst 0.20 studs, and the spec now holds 0.5.
- Stopgap icons until the user's draft 4 sheet (C-183): `ord_sanctum` and `chs_basilisk` draw the Radar SAM Site tile, `ord_shepherd` and `chs_griffin` the Mobile Radar SAM, as the anti-nukes do. This fixes main's two failing icon specs.

**Why:** sim-A's S-149 (the user's point defence) and S-150; the icon specs failed on main.

### C-183 — Icon sheet draft 4: icons mapped from each item's defs; a second sheet when the first is full (2026-10-24)

**Decision:**
- `docs/art/icons/ftgg-unit-icons.html` is the user's draft 4. Every catalogue item lists its defs exactly. `tools/icons/render.mjs` maps each unit def from those lists alone; the families, stopgaps and name matching are gone. A def in no item, in two, or an id that is no def fails the run. All 150 defs map, from 75 items.
- Tile key `slug(name)_t<tier>`, one per item. The Commanders' radar frame is `walker`.
- New tiles for the defs that had none or the wrong one, including: anti-nuke and mobile anti-nuke, point defence and mobile point defence, shield generator, flak tower, missile battery, decoy drone, siege mortar.
- **Sheets:** tiles are fixed at 96 × 112 (90 per 1024-px sheet, 85 used). When a sheet is full the next one starts (`assets/icons/ftgg-icons-2.png` ...). Each tile is `{ x, y, sheet }`, and `IconAtlas.images` lists one asset per sheet (`tools/icons/assets.json`, `images`). `UI/Glyph` sets each icon's image from its tile's sheet. The run fails with a message past 4 sheets, and checks that no tile runs off its sheet.
  - Dry run at 128-px tiles: 2 sheets (48 + 37 tiles), the second listed as "upload it".
  - IconAtlas.spec fails while any sheet has no uploaded id.
- **Uploaded with the user's approval:** asset 83784263765889 (byte-identical to `assets/icons/ftgg-icons.png`). The atlas and the id are in the same commit, so Studio never runs a mismatched sheet.
- **Wraith (S-109), kept as is at the user's word:** its owner sees the Decoy Drone. An enemy's radar gets the spoof's def, so the blip draws a strategic bomber's air frame, like a bomber the enemy spotted earlier. Once seen, it's the Decoy Drone. Icons.spec checks all three.

- Studio (the Canyon): `debug_out/screens/c183_strategic_defenses.jpg` shows both teams' anti-nukes, point defences (fixed and mobile), shield generators, flak, beam towers, missile batteries and the Commanders at normal icon size. `c183_strategic_radar.jpg` is zoomed out on radar contacts: the tracked ones show their icons, and the untracked aircraft (a Wraith and a real bomber) the same dashed air frame. `FtggDebug:Invoke("hold", ids)` (Studio only) keeps spawned units from fighting for such shots.

**Why:** 11 defs drew blank contacts and several the wrong tile (the user's list); the user asked for the def lists, the split and the upload.

### C-184 — Smooth key art parallax: sub-pixel layers; no world drawn behind the loading screen (2026-10-24)

**Decision:**
- `UI/KeyArt` (lobby-D's measurements and fix, approved by the user): the layers' size and position are set in scale, not offset. UDim2 offsets are whole pixels, so the near layer moved on only 50 of 158 frames, in 1–1.4 px jumps. Each tile is 1 px larger (no hairline between tiles) and turned 0.001° (Roblox draws a rotated GUI object at sub-pixel positions). D measured 60 fps and 0.02 px steps on 239 of 240 frames. The API is unchanged; the lobby mounts the file read-only.
- `UI/MatchLoading`: while the loading screen shows (opaque: art or gradient), `RunService:Set3dRenderingEnabled(false)`. It's turned back on when the match starts.
- Checked in Studio with the contract profile: loading still reaches 100% with the world paused (90 meshes in 24 s), the match starts, and the world draws again.

**Why:** the user saw the parallax stutter in the lobby; the match's loading screen uses the same viewer.

### C-185 — A projectile destroyed on a shield dome bursts there with its explosion (2026-10-24)

**Decision:** on SHIELD_HIT with ABSORBED (S-85, S-93: every shell reaching an up dome is destroyed at its surface), the client now bursts the projectile's own impact effect there: its weapon's impact size, facing along its flight, and timed where its drawn path meets the honeycomb (C-99). Before, it was dropped with no burst and only the honeycomb lit up. Hitscan rounds stopped by a dome still show no burst, as on units; beams keep their glance (C-129).
- ShieldWire.spec: every autocannon round absorbed explodes on the shell (r = 120 ± 4), none inside.
- Studio (the Canyon): three Locusts on a Phalanx's dome, 55 rounds absorbed, an explosion on the honeycomb at each. `debug_out/screens/c185_shield_absorb_bursts.jpg`.

**Why:** the user: "Absorbed/Impact of projectiles on the shield honeycomb trigger their explosion vfx". This replaces S-85's "no burst" on the client.

### C-186 — Shield energy column and dome waves on models-C's assets (review) (2026-10-24)

**Decision:** the user's shield redesign, on models-C's `Meshes.shieldColumn` and `Meshes.shieldWave` (fx.md "Energy column", "Dome waves"; both status review, so they show in Studio only until approved; elsewhere the old beam and rings stay).
- **Column:** three straight Beams from the generator's `beam` attachment to the dome's top: glow, swirl, core (ZOffset 1–3). They use C's textures, widths × R, scroll speeds and brightness, tinted (150, 235, 255) as in C's reference. `ShieldLook.column` drives them:
  - every width × (weakest + (1 − weakest) × strength), down to a fifth at 0%;
  - deploy: the core shoots up in `deploy.shoot`, then the swirl and glow widen over `deploy.thicken`;
  - collapse: everything pinches to 5% in `collapse.pinch`, flashes (brightness × 3, widths × 1.5) for `collapse.flash`, then hides, before the dome is down.
- **Waves:** C's 16 dome bands, one MeshPart each per shield, with a `shieldWave` SurfaceAppearance (`Core/MeshMaterials`, regenerated `place/MeshMaterials.model.json`). `ShieldLook.waveBands` places C's 3 waves, evenly spaced in time, from the top to the rim. Each wave shows its two nearest bands at (1 − f, f), fading over the first and last 10°; waves on one band add. They take `seconds / max(0.3, strength)` to cross, at `opacity` × the dome's opacity. They replace the RingThin flow; the dome, edge, foot ring, top swirl, specks and hits stay.
- Hidden at strategic zoom and when down, like the rest of the detail; every instance is made once per shield.
- ShieldLook.spec: thinning, deploy order, pinch–flash–gone, the (1 − f, f) split, fades, three waves, no frame-to-frame jumps.
- Studio (the Canyon, a radius-120 review dome): 3 beams and 6 wave bands lit close up, none at strategic zoom; the shield loop 0.08 ms a frame. `debug_out/screens/c186_shield_full_side.jpg`, `_full_55`, `_weak20`, `_collapse_flash`, `_deploy`.

**Why:** the user found the thin beam and small rings "simple" and asked for a vortex column and wide waves; models-C made the assets to clients-B's layout.

**On hold (2026-10-24):** the user rejected this design before approving it; models-C is making a new reference. Not built on further; it stays Studio-only (review assets) until the new hand-off replaces it.

### C-187 — Shield energy look v4 in the game, ported from models-C's reference (2026-10-24)

**Decision:** the user's approved shield look (models-C's M-34, fx.md "Shield energy", `Meshes.shieldEnergy`) replaces the dome look and C-186.
- **Port:** `Render/ShieldEnergy` ports `assets/fx/shield/waves/ShieldPreview.luau`: the same instances, made once per shield, and the same per-frame logic. Jitter comes from a hash, not `Random`, so nothing is allocated per frame. `Core/ShieldEnergyLook` holds the pure parts: the state mapping, the envelope (beam, front, edge, flare), band reveal, the waves' motion, wobble and brightness, the packet arrival and the arc handles. ShieldEnergyLook.spec checks them against the manifest.
- **In ShieldFx:**
  - deploying = pre (0.22 s) then raise (1 s); up = idle; collapsing = collapse (0.85 s); down = the beam fading out (0.25 s).
  - Strength: the dome rule (invisible at 0, full from 50%, with the low-strength flicker) scales the dome, bands, honeycomb, waves, streaks, arcs and hits; the channel never drops below 40%.
  - Detail: full within 300 studs; beyond that, no streaks, filaments, edge crackle or honeycomb, and the waves move every other frame; at strategic zoom only the shell, plus the outline in the faction's tint.
  - Hits: the flipbook caps (4 per dome, the newest replacing the oldest), in place of the honeycomb plates.
  - The faction comes from the generator's def, else from the generator type with that dome radius (a remote dome carries neither); Order cyan, Chaos amber.
- **C-186 is taken out:** ShieldFx, ShieldLook, MeshMaterials and their spec are back to before it, and the client no longer reads `shieldColumn` or `shieldWave`. The old look stays only as the fallback if v4's meshes don't load.
- **Cost (Studio, a Phalanx and a Carapace up):** about 0.27 ms per dome at full detail, 0.25 at mid distance, about 0.08 at strategic zoom. The first port cost 0.5 ms per dome; caching brought it down: NumberSequences and textures written only when they change, filaments re-laid only each jitter step, streaks only when their end moves, and attachments set in their parent's space.
- Screenshots: `debug_out/screens/c187_shield_order_chaos.jpg`, `_250`, `_raise`, `_collapse`, `_hits`.
- **For review:** each hit patch covers about a quarter of the dome (hitCap's half-angle 0.46 rad) and glows at tint × 3, so four quick hits per dome light most of it (`c187_shield_hits.jpg`).

**Why:** the user approved v4 and asked for it in ShieldFx, through models-C.

### C-188 — Smaller, dimmer shield hit patches (2026-10-24)

**Decision:** the hit decal's glow is `tint × sizes.hitGlow` (models-C's new value, 1.6; 3 until it reaches main) instead of a fixed × 3. models-C's smaller `hitCap` (half-angle 0.28, from 0.46) and new flipbook come through the manifest with no client change.

**Why:** the user: "The hit patches are too much; ask models-C for smaller or dimmer ones."

### C-189 — No honeycomb over the shield dome; cells only where a shot hits (2026-10-24)

**Decision:** the v4 dome no longer shows models-C's `hexGrid` (Neon at 0.92 when up, fx.md); the client doesn't load or make it. Hex cells now appear only in the hit patches (C-188). Studio: `debug_out/screens/c189_shield_no_honeycomb.jpg`.

**Why:** the user: "turn off the honeycomb the shield, it should only be activate for the patch reflect shot on hit".

### C-190 — Shield hit patches crossfade frame to frame (2026-10-24)

**Decision:** each hit cap carries two Decals. Frame k fades out as frame k + 1 fades in, and the last frame fades out alone, so the 8-frame flipbook plays smoothly instead of stepping at 10 frames a second. Checked in Studio: neighbouring frames share the weight through the hit, and it ends faded. The speed is models-C's `timing.hitLife` (0.8 s); I've asked them for about 0.4–0.45 s, and more frames if they help. Both come through the manifest.

**Why:** the user: "why the honeycomb grid spread so slow, look chobby?"

### C-191 — Multi-select tiles: the type's portrait, its icon bottom right, the count top left (2026-10-24)

**Decision:** with several units selected, each type tile in the unit panel shows the type's model at an angle (`UI/Portrait`, as the one-unit tile and the build menu), its type icon small in the bottom right, and how many of that type are selected in the top left. Tiles are 50 px, up from 46. Clicks are unchanged (C-157: keep, Shift drop, Ctrl same type on screen). Studio (the Canyon, 5 Lancers, 3 Paladins, 2 Halos, a Mason): `debug_out/screens/c191_selection_tiles.jpg`.

**Why:** the user: "when selecting multiple units, the panel should show the image of the unit + its icon in the bottom right + number of that type of unit in the upper left corner".

### C-192 — Each unit on its terrain: in the world and in every portrait (2026-10-24)

**Decision:**
- **Portraits** (`UI/Portrait`, so the build menu, the unit panel and its type tiles): the unit stands on its terrain (`Core/PortraitStage`):
  - a disc of ground for land units and structures;
  - water over a darker bed for ships, submarines and water structures (the hull a little in the water);
  - a shore for amphibious and hover units (ground, water across the front);
  - ground well below an aircraft, with its shadow; the camera frames the unit and the ground.
- **In the world** (`World.floats`):
  - structures built on water (`placement = "water"`: shipyards, tidal generators, sonar) float on the surface, as their models are made to; they were drawn on the seabed;
  - amphibious and hover units ride the water surface instead of the bed;
  - ghosts and the placement preview of water structures follow the same rule;
  - an aircraft out of the camera area keeps its last height, or 35 studs if it was never seen close, instead of being drawn on the ground.
- PortraitStage.spec covers both rules. Studio (Coastline): a Crusader, a tidal generator and a Tideguard on the water, a Lancer on the shore, a Falcon above; the tiles show each on its terrain. `debug_out/screens/c192_terrain_portraits.jpg`.

**Why:** the user: "unit should be render with its accessible terrain, for example, tank on ground, amphibious is on ground + water, ship on water, air is hover above ground", then "apply to all portrait".

### C-193 — Commands audited per unit; builders-only box select; order lines last until done; builders spray (2026-10-24)

**Decision** (the user's batch; the server-side items went to sim-A):
- **Command sets audited, unit by unit** (`Core/CommandSet`):
  - Stop only on what has something to stop (mobile units, builders, factories, armed units, nuke silos). Generators, extractors, storage, sonar, pads, walls and Pinpointers offer nothing (the card shows Last alert only).
  - Shield generators get On / Off. The server still has to honour it (asked of sim-A: off = dome down, no upkeep).
  - Interceptors (anti-nukes, point defence) get the fire state only.
  - Stockpiled SAM sites are ordinary defences (fire state, attack, stop).
  - CommandSet.spec checks each case.
- **Orders go only to the units that have the command** (`Orders.able`, used by every issue): a turret in a selection given Move takes no move and draws no line.
- **Box select:** a box with a mobile builder in it (a Commander included) keeps only the builders (`Selection.filterBox`).
- **Order lines last until the order is done** (`Core/Waypoints`, replacing the 2 s idle drop):
  - a point line goes when the unit gets there, or that one point after 6 s stuck short of it;
  - attack, guard / assist and reclaim lines stay until the target is gone, repair until it's whole;
  - a build line stays until its frame is finished, not just started;
  - patrol stays until replaced;
  - a builder's lines go once the server has reported it idle for 1.5 s (IDLE events).
- **New units take their factory's order list**, as the server gives it (S-95). Factory lists stay until replaced (Repeat or not).
- **Builders' nano spray** (`Core/BuildTargets`, `Render/BuildSpray`): a team-coloured stream from a working builder to what it builds or repairs, sweeping over the frame at the height it has reached; violet and flowing back for reclaim.
  - The server doesn't send a builder's target, so it follows the builder's own order line: its build's frame, its repair or reclaim target, or the frame of the builder it assists. It sprays only while the builder stands within build range.
- **The shield's capacity bar** hovers just above the generator model, not over the dome.
- **Placement:** another builder's planned build counts as taken (it did already; the lines now stay until the frame is finished, so the plans stay counted).
- OrderLines.spec, through the real client and server:
  - both lines stay for the whole build (62 frames), where the old rule dropped them after 2 s still;
  - both builders spray the frame;
  - a factory's Lancer takes the factory's move line;
  - a turret gets no move;
  - another builder's plan blocks placement.
- Studio (the Canyon): the card, the bar and the spray checked. `debug_out/screens/c193_build_spray_lines.jpg`.

**Why:** the user's list: commands for all units ("why does the generator has a Stop command"), shields switching off, the bar, the box filter, no move arrow for turrets, assist and build lines persisting, factory orders persisting on their units, nano spray.

**Waiting on sim-A:** shields honouring On / Off (and starting on); building over mobile units (then the client drops its "units in the way" check); in-range attacks and builds without moving; scouts' range halved; resource priority.

### C-194 — Command line: Tab cycles choices; units by alias (2026-10-24)

**Decision:**
- **Tab:** the first Tab takes the first suggestion; each further Tab on what it completed takes the next one, wrapping; typing ends the cycle (`UI/CheatConsole`).
- **Choices for every command,** word by word (`CheatInput.CHOICES`): on / off (reveal, god, instabuild, cheat); supply / power / all, then amounts (res, income); selected, a team or at (kill); teams, then pause / resume (ai); speeds; counts after a unit.
- **Unit aliases** (`CheatInput.aliases` / `resolve`), from each unit's icon-sheet type with the faction's prefix, in full and short (generic last words like site, generator and tower dropped): `ord_shield` and `ord_shield-generator` name the Phalanx, `chs_ir-sam` the Chaos IR SAM site; the type alone names both factions' (Tab cycles them). Display names work as before. A give sends the id when the word names exactly one unit; suggestions match aliases and show the type ("Phalanx (ord_phalanx) - Shield Generator"). /help mentions both.
- CheatInput.spec covers the aliases, the ambiguity, the choices and counts. Studio: Tab on `/re`, `/reveal `, `/give ord_shi` and `/give shield` cycles as specified.

**Why:** the user: "Tab to complete suggestion/cycle choices (like reveal on/off, kill selected/...)" and "give command unit name should be also have the aliases (give ord_shield -> Phalanx, give ord_ir-sam,...)".

### C-195 — Place over own and allied units; shields switchable; S-157's units on the icon sheet; retired units hidden (2026-10-24)

**Decision:**
- **Placement:** the preview no longer counts own and allied ground units as in the way. They walk out of the footprint when the frame starts (S-155); enemy units still block. Placement.spec compares with the server's frame-start check (owner, no knower). OrderLines.spec: a solar placed over an own Lancer starts, and the Lancer walks off; an enemy Ravager in sight still blocks.
- **The card's On / Off** treats shield generators as switchable (S-154: off = dome down, no upkeep).
- **Icons for S-157's units, on existing tiles** (no new sheet, no upload): Sentry, Guard, Overwatch, Twin Guard and Geryon on the Gun Turret tile; Beamer and Chaos's Bulwark on the Beam Tower tile; Gauntlet and Talos on the Artillery Emplacement tile (T2 dots until they get their own). The sheet PNG is byte-identical. Dedicated icons need the user's design and a new upload.
- **Retired units** (`retired = true`: ord_bulwark, chs_spike, chs_inferno) aren't suggested or aliased by /give; their ids still work. Their models still preload (replays can show them).
- This branch merges sim-A's d41074e (S-152..S-157) so the new defs and their icon entries land on main together (the icon specs fail without entries).

**Why:** sim-A's S-154, S-155 and S-157; the user's requests.

### C-196 — Resource priority on the command card (2026-10-24)

**Decision:** a "Prio high" / "Prio low" state button (green high, amber low) on the units resource priority does something for (S-156, `CommandSet.consumer`): builders and factories, stockpiling launchers, aircraft (rearm), shields, radars, jammers, trackers and DIRCM units. A click with every selected unit high sets them all low; with any low, sets them all high (PRIORITY, value 1 high / 0 low). The button reads the LOW_PRIORITY state bit, which arrives for allies too. CommandSet.spec checks who gets it; OrderLines.spec runs the round trip.

**Why:** the user: "Introducing priority resources usage -> high priority unit take the resources first and the rest goes to low priority"; sim-A's S-156.

### C-197 — Icon sheet draft 5: the S-157 defences get their own icons (2026-10-24)

**Decision:** the user's draft 5 replaces `docs/art/icons/ftgg-unit-icons.html`: Laser Tower (Sentry, Guard), Twin Laser Tower (Overwatch, Twin Guard), Triple Laser Tower (Geryon), Ramping Beam Tower (Beamer, T1), Lobbing Gun (Gauntlet, Talos, T1); Chaos's Bulwark joins Radiance on Beam Tower; the retired ord_bulwark, chs_spike and chs_inferno stay mapped for old replays. render.mjs maps all 159 defs from 80 items: 90 tiles, exactly one full 1024-px sheet (the next item would start a second sheet). Uploaded with the user's approval as asset 107697270697313 (byte-identical to `assets/icons/ftgg-icons.png`), in the same commit as its atlas. The /give alias test follows the new type names (`ord_laser` is the Sentry).

**Why:** the user's draft 5 and approval.

### C-198 — The S-157 towers' visuals: coloured lasers, the Beamer's ramp, barrels in turn, the Geryon drum (2026-10-24)

**Decision:**
- **Lasers** (`fx.tracer = "laser"`, `fx.color = { r, g, b }`): the whole line at once in the weapon's colour for 0.12 s, fading. Red for Sentry, Guard and Twin Guard; green for Overwatch, Geryon and Bulwark's laser; blue for the Beamer.
- **The Beamer** (`ramp`): each bolt lasts one shot gap plus a little, so they join into one held beam. Its width and brightness grow with intensity, time on one target over `ramp.seconds` (4 s), as the server's damage ramps. A pause longer than 1.6 shot gaps (a target change or a loss) starts it over (`Effects.ramp`).
- **Barrels in turn** (`muzzles`): each shot starts at the next muzzle (`muzzleOf`), and the matching `barrelN` (or `laser_barrelN`) recoils (Default piece script). With a `drumPiece` (Geryon, Bulwark's laser), the cluster turns one barrel on (360° / barrels) after each shot.
- Gauntlet and Talos: the high-arc shells come with SPAWN_PROJ's velocity, no client change.
- Lasers.spec, through the real server: Sentry and Guard fire red, Overwatch green; the Beamer rises from 0 to full; a pause resets it; Geryon's three shots turn the drum a full circle and recoil each barrel. Studio (blockouts until models-C's models): the Beamer's held blue beam on a Juggernaut. `debug_out/screens/c198_beamer.jpg`.

**Why:** the user's T1 defences; sim-A's S-157 fields.


### C-199 — Laser looks from the user's references: the tapered bolt, the Beamer's thread (2026-10-24)

**Decision:** lasers draw in `Render/Lasers` (pooled Beams on Terrain attachments and Neon balls) instead of a Neon box, in two looks:
- **Bolt** (every laser without a `ramp`: Sentry, Guard, Twin Guard, Overwatch, Geryon, Bulwark's laser; the Overwatch / Warden reference): a core white at the muzzle turning to the weapon's colour, 0.55 studs wide at the muzzle tapering to 0.07 at the target, inside a soft glow of that colour (1.7 → 0.35); a white-tinted flare at the muzzle and a glowing orb with a halo at the target. Sized by the weapon (0.7..1.3); fades over the last 65 % of its 0.12 s.
- **Thread** (a weapon with a `ramp`: the Beamer reference): a thin core (0.14) the same width all the way, flickering white and colour along its length each frame, inside a thin coloured fringe; a small coloured flare at the muzzle; a cone of light opening at the target (mouth 1.8 studs, narrowing back along the beam) with a small orb. It widens up to 1.6× with the ramp and doesn't fade between bolts.
- Hit sparks stay in Render/Effects.
- Studio (blockouts): the Overwatch's green bolt on a Juggernaut and the Beamer's ramped thread. `debug_out/screens/c199-overwatch-laser.jpg`, `c199-beamer-ramped.jpg`.
- The Beamer's colour is the def's (70, 150, 255, sky blue); the reference is deeper blue-violet, so sim-A is asked to change `ord_beamer_beam.fx.color`.

**Why:** the user's two laser references.

### C-200 — Prefixed muzzles aren't flung on death (2026-10-24)

**Decision:** `Deaths`' attachment check matches `^%a+_muzzle%d*$` as well as `^muzzle%d*$`, as models-C's `Blockout.isAttachmentPiece` and `Mesh` now do, so Bulwark's `laser_muzzle1..3` are never picked as flung pieces. Deaths.spec: forty overkill deaths of a def with prefixed muzzles fling only real pieces.

**Why:** models-C's T1 defence blockouts (m-models ea3ae59) bring attachment muzzles with a prefix.

### C-201 — The match place logs the playtest flow (2026-10-24)

**Decision:** for the first live playtest (lobby → reserved match → lobby), the match server prints a `[Match]` line at every step, warnings for every failure:
- boot: the job id and the `server/<key>` lookup, the match id it found (and after how many reads), `config read` with map, mode, room and lobby server, then one line per seat (name, user or AI level, faction, ally team) and per spectator; `config refused: <why>` otherwise;
- each player: `admitted <name> (user <id>) to seat <n>` / `as a spectator`, or `refused <name> (user <id>): not listed, kicked` (or: no valid config); leaving, with the phase;
- the start: everyone loaded, or the 90 s wait over with the names not loaded;
- `heartbeat <n>: <phase>, tick, connected` every 30 s, and when it stops;
- `result: <outcome>, ally team <n> won (<reason>), <k> humans present; writing result/<id>`, then `stored result/<id>` once MemoryStore accepted it;
- store reads and writes: each failed attempt (n/3) and a final FAILED line;
- each teleport back: names → place and target server, started or failed, the fallback to any lobby server, and TeleportInitFailed retries with their own result.
The watchdog's WARN / INFO lines (S-140) stay on.

**Why:** the user's queue item 2: about four players will try the flow soon, and the console has to show where it breaks.

### C-202 — Settings in BAR's layout; the pieces in the Kit (2026-10-24)

**Decision:** the settings menu follows the user's BAR references 4–5, built from new Kit pieces the lobby can reuse:
- `Core/OptionTree` (pure, OptionTree.spec): sections → sub-sections → option rows; which rows show for a view: the chosen section's, or with a search every match from every section (all words, in label, help, keywords, section and sub-section names; folds and Advanced ignored); "Advanced" rows only with Advanced on; a folded parent hides its children unless Unfold all; children dimmed while an ancestor is off; a sub-section header shows when any of its rows does; the active sub-section for a scroll position.
- Kit: `Kit.search` (dark box, magnifier), `Kit.header` (amber on a lighter band, amber underline), `Kit.fold` (▾ / ▸), `Kit.treeNav` (sections with the pill; the chosen one's sub-sections under it, an amber bar on the one in view; a click scrolls to it), `Kit.helpFooter` (hovered option's name, help text, faint hint bottom right), and `Kit.options(panel, sections)`: a whole searchable body in a `Kit.panel` made without nav (search box across the top beside the title, Unfold all / Advanced switches top right, rows indented 20 px per level under fold arrows, controls right-aligned, a veil over a dimmed row's controls that lets clicks through).
- Kit look changes (all users, the lobby included): square slider knob (12×16) on a dark track; toggle corners squarer; dropdowns a dark box (`Kit.COLOR.box`); an open dropdown lifts its ancestors' ZIndex so its list draws over the rows after it.
- The menu: Graphics (Quality, with its caps as folded child rows · Models · Lighting), Interface (Scale · Building · Developer, Advanced), Control (Camera; zoom step Advanced), Keys (one sub-section per key group, Reset, the fixed-key tables), Audio. 940 × 620, fixed; the page scrolls. Every row has help text for the footer.
- Checked in Studio: search, Unfold all, Advanced, hover help, dimmed children, the sub-section jump and amber bar, an open dropdown. Fixes from that check: a Kit panel in a gui drawn under Roblox's top bar keeps clear of it (short windows); the sub-section jump uses screen pixels (CanvasPosition is in them); the dropdown lifts its ancestors only in a Sibling-order gui (the menu's gui is Global, where the list's own ZIndex already wins). Screenshots: `debug_out/screens/c202_settings_*.jpg`.

**Why:** the user's queue item 3, with the pieces in the Kit for the lobby stream (D).

### C-203 — The HUD after reference 3 (2026-10-24)

**Decision:**
- **Build categories are BAR's:** Economy, Combat (was Defense), Utility, Build (was Factories); a factory's menu stays Units. The tabs sit **under** the grid, each with a coloured diamond (Economy yellow, Combat red, Utility blue, Build green) and its key.
- **Tab keys Z / X / C / V** (Keybinds `tabEconomy` … `tabBuild`, group Building, rebindable): while a builder's structure menu shows they open the tab and arm the digits, like B. They are a key **layer** (`Action.layer = "build"`): conflicts count only within a layer, and while the layer is active Patrol (Z), Cancel (X), the camera's right turn (C) and range rings (V) stand aside (`BuildMenuUI.takes`, `Camera.keyTaken`). Without a builder selected those keys work as before.
- **Build tiles:** cost stacked at the bottom right (supply white, power yellow), the type icon at the bottom left, as in the reference.
- **Command card:** state buttons carry a short coloured underline (22 × 2 px; green on, red off, yellow for the middle fire / move states); Repeat reads "Repeat On" / "Repeat Off" on factories; priority "High prio" / "Low prio".
- **Unit panel:** the name in yellow-green (190, 228, 96).
- **Top-right menu:** a flat text strip ("Keys", "Settings (O)") replaces the Settings button; `SettingsMenu.addMenuItem(text, order, onClick)` adds items (Lobby, Statistics later: statistics need server data mid-match).
- Screenshots: `debug_out/screens/c203_hud_economy.jpg`, `c203_hud_combat_x.jpg`.

**Why:** the user's queue item 4 (reference 3).

### C-205 — Own units off camera stay live (OWN_STATUS, S-158) (2026-10-24)

**Decision:** the client keeps each `OWN_STATUS` (protocol 34) in `world.ownStatus` by unit ID and applies it (`World.applyStatus`: health, build progress, the factory queue and its head's progress) to the unit while it's outside the tactical tier: at once when the unit is known, and on every strategic snapshot that recreates it (so a status that came before the unit's first record waits for it). ENTER and DEATH drop it (ENTER / State win from then on). The queue is rebuilt from head and count (`World.statusQueue`): the queue the client last had from its head on, cut or padded with its last item; the head repeated when the old queue doesn't hold it. Health bars, build bars, the factory queue strip and idle counts therefore keep moving for own units off camera. `OwnStatus.spec`: a factory's progress, finished items and damage off camera through the real NetOut → NetIn path; a status before the strategic record; the queue rebuild.

**Why:** the user's queue item 6, with sim-A's S-158.

### C-206 — The factory facing arrow and "Buildings set to face …" (2026-10-24)

**Decision:** `Core/Facing`: a facing's sim heading (facing × 90°, S-133), its exit direction (0 → +Z, 1 → +X, 2 → −Z, 3 → −X) and its name as the player sees the map (the camera looks toward −Z at yaw 0, so up is North): 0 South (the default, toward the camera), 1 East, 2 North, 3 West. (Schema calls 0 NORTH; the names here follow the screen.) The placement ghost of a factory gets a green arrow (shaft and chevron, on the ground) on its exit side; turning it (R) shows "Buildings set to face East" over the ghost for 4 s, as a screen-space label (a BillboardGui in a Workspace folder doesn't draw here; the HUD's world labels are all screen-space). Fixed on the way: the ghost and queued-build markers turned by π − facing × 90°, flipped 180° from the built frame for South and North; they now turn by the sim's heading as the renderer does. `Facing.spec` checks the arrow's side against `Build.padPosition` for all four facings. Screenshots: `debug_out/screens/c206_*.jpg` (the built plant opens south like its ghost).

**Why:** the user's queue item 6 (reference 7); sim-A: BUILD's facing already works end to end.

### C-208 — Health bars under the unit (2026-10-24)

**Decision:** the bars sit under the unit (the user): centred on it, their top `Bars.GAP` (4 px) below the lowest on-screen corner of its footprint at its base (where the model is drawn, so an aircraft's bar stays at the aircraft). The stack is anchored by its top: health, then the build / production bar and the reload bar below it; missile stock pips stay just above the health bar. Bars.spec updated. Screenshot: `debug_out/screens/c208_health_bars_under.jpg`.

**Why:** the user, 2026-10-24.

### C-209 — The Canyon's baked ground wired: clicks march the sim's heights; cliff fallback (2026-10-24)

**Decision:** with models-C's Canyon ground (m-models 08b9889, merged in 13b9a3c; manifest `ground.canyon` at review, drawn with the Studio switch `groundanyway`), mesh tiles no longer take ground clicks (`CanQuery` off: a tile's box hit rays at mesa height). `Controls.groundAt` raycasts the map parts and water as before, then marches the ray down to `Controls.heightAt` (Main: `World.groundY`, water surface over water) in 4-stud steps from 400 studs, refined to a tenth of a stud. `GroundMeshes.FALLBACK.cliff` = Sandstone (150, 78, 52) for the strata walls.
- Studio, 2026-10-24 (`debug_out/screens/c209_canyon_*.jpg`): 236 tiles and details build in about 10 s; after a camera jump the mesh ground is there at once and sharp. **But their SurfaceAppearances draw flat white in the match place** (no load error): the textures need a look from models-C before the user's review; voxel shots for comparison.

**Why:** the user's queue item 8; models-C's notes 1 and 2.

### C-210 — State buttons show every state (2026-10-24)

**Decision:** state buttons in the command card carry one short segment per state under the label, the current one lit (the user): fire and move states three (red, yellow, green: hold, return / maneuver, at will / roam), repeat, on / off and priority two (off / low red on the left, on / high green on the right); unlit segments dark grey, all unlit when no selected unit has the state. Replaces C-203's single coloured underline. Screenshot: `debug_out/screens/c210_state_segments_x2.jpg` (UI at 2× for the shot).

**Why:** the user, 2026-10-24.

### C-207 — Radar coverage as a green fill with rings, on the minimap too (2026-10-24)

**Decision:** reference 6's radar view. `Core/RadarFill` turns the team's radar circles into one value per grid cell: 0 outside, FILL inside, up to RING on the lighter rings (each radar's own every RING_STEP 160 studs, and the coverage's outer edge; an edge deep inside another radar isn't drawn, so overlapping radars read as one area), softened over RING_WIDTH 12 studs. `Core/FogBlanket` composites it under the fog in the same image (green 70/225/110, fill alpha 0.13, rings up to 0.34; with fog of war shading off, the image holds the radar alone), so the minimap mirrors it. Shown while placing a radar structure (its own range added at the ghost), while a selected own unit has radar, or in the sensor view (N); circles are every finished own radar emitter, looked up 4 times a second. **The terrain cut waits for the sim:** Sensors stamps radar as a plain circle, so a client-side cut would show coverage the server doesn't count. sim-A will add a shared terrain-occluded radar function (request 66), and the layer will take its cells then. `RadarFill.spec`. Screenshots: `debug_out/screens/c207_radar_fill_*.jpg`.

**Why:** the user's queue item 5.

### C-211 — Sonar pings and jammer shimmer (2026-10-24)

**Decision:** `Core/SensorFx` (pure) picks the emitters drawn in the tactical tier and their timing; `Render/SensorFx` draws them, hidden at strategic zoom:
- **Sonar ping:** every finished own sonar emitter on camera sends a thin cyan ring (pooled CylinderHandleAdornments: a cylinder with an InnerRadius) across the water surface out to its sonar radius, PING_TIME 1.6 s every PING_PERIOD 3 s, staggered per unit (golden-ratio offset by id), clear at the start, clearest a quarter of the way out, faded at the radius. Enemy sonar doesn't ping on your screen.
- **Jammer shimmer:** every finished jammer on camera, own or a seen enemy's, wears a dome at its jam radius in Roblox's ForceField material (it shimmers by itself), breathing slowly (4 s, out of phase per unit), plus a thin purple ring on the ground at the radius. From inside the dome the shimmer is faint, so the ring shows the reach. The sim's jammers have no on/off switch (TOGGLED_ON is only for converters, beam towers and shields; Schema's comment calling it "radar / jammer switched on" is stale), so every finished jammer shimmers. The radius is the def's; the sim shrinks it in a power stall, which the client doesn't know.
- `SensorFx.spec`. Screenshot: `debug_out/screens/c211_sonar_ping_jammer.jpg` (two Crusaders pinging at sea, a Veil's dome and ring on land).

**Why:** the user's queue item 7.

### C-212 — S-166's units on existing icon tiles; radar fill off for now (2026-10-24)

**Decision:**
- **Icons:** Pharos and Scylla (naval SAM platforms) on the Radar SAM Site tile, Empyrean and Rookery (advanced rearm pads) on the Rearm Pad tile, until the user designs their own (as C-195). The sheet PNG is byte-identical; only IconAtlas's mapping changes. Fixes main's two failing icon specs after S-166.
- **The jammer's shimmering dome (C-211) is switched off** (the user): `SensorFx.JAM_DOME = false`; the purple ground ring at the jam radius stays.
- **Radar fill (C-207) is switched off** (the user): `RadarFill.ENABLED = false`, so Main passes no circles and nothing draws; the code, its spec and the fog composite stay for when it comes back (with sim-A's terrain-cut radar, request 66).
- **S-163's mid-beam FIREs** (a single-target beam's new end when an enemy steps into its line) take the existing continuation path (`Effects.continueBeam`, C-144): the burning beam's end and hit move; no change needed.

**Why:** sim-A's S-166 and S-163; the user, 2026-10-24.

### C-213 — Fog of war over a baked map's rock details (2026-10-24)

**Decision:** on the Canyon's mesh ground the fog blanket showed as grey squares on the mesa tops: the rock details (strata walls, caps, rims) stand ~6 studs above the sim's mesa height, so the blanket (at the sim's heights) passed under them and showed only over each top's flat middle. Now:
- `Render/MeshGround` builds details with a convex-decomposition collision (`CollisionFidelity.Default`, ~40 ms each, ~7 s for the Canyon's 190 in the background), `CanQuery` on, tagged `GroundDetail`; tiles keep their box and `CanQuery` off (C-209).
- `Render/FogBlanket`'s height samples raycast the voxel terrain and `workspace.Map` (the details), taking the higher of that and the sim's height; Main rebuilds the blanket once the mesh ground has finished loading (`Ground.last.mesh`).
- `Controls.groundAt` looks through `GroundDetail` hits (clicks still march the sim's heights).
- Kept: the blanket's vertex looks across half a vertex step (`FogBlanket.REACH` 1; a Studio query `fogreach` rebuilds it with another value: 0.5 let the rims poke through again). The blanket can't follow a mesa's outline closer than its vertex step (32 studs on the Canyon, set by the editable-memory budget), so a thin skirt drapes off the mesa edges.
- Screenshots: `debug_out/screens/c213_canyon_fog_before.jpg`, `c213_canyon_fog_over_mesas.jpg`. Contract `docs/contracts/map-ground.md` updated (and models-C's note 3: type borders are wavy lines, not cell edges).

**Why:** the user, 2026-10-24.

### C-214 — Kit survives an experience without EditableImage (2026-10-24)

**Decision:** `Kit`'s shared images (panel stripes, shadow) create, write and wrap the EditableImage inside one pcall; on failure the panel goes without them. A chart's image likewise: create and the per-draw write are guarded, and the chart says "charts need editable images" instead of throwing. Before, in an experience whose Game Settings > Security doesn't allow EditableImage, the create succeeded and the write threw, killing the client script at the first panel (the lobby stream's report from the published playtest).

- Follow-up the same day: the other EditableImage users too. `Render/Grade`'s vignette (made at startup) creates, writes and wraps in one pcall. `Render/FogBlanket` tests a first write when it makes its image, pcalls `CreateEditableMesh` for its chunks, and pcalls each frame's write: a refused write clears the blanket (`stats.mode` "image writes refused") instead of throwing inside the render step every frame. `Render/ShieldFx` was already guarded.

**Why:** lobby-D's crash report; the setting is per experience, and a missing setting should cost looks, not the game.

### C-216 — Wrecks' supply, resurrect and reclaim zones (2026-10-24, S-168, protocol 35)

**Decision:**
- **Wire:** `World.Wreck` keeps `supply`, `fullSupply` (from WRECK) and `rez` 0..1 (from WRECK_STATE, which also refreshes `supply`); out of sight the last values stay.
- **Bars** (`Bars.wreckList`, drawn by HealthBars under the wreck like units' bars, C-208): dark green = supply / fullSupply, only below full; purple = resurrect progress, only above 0; with both, green over purple.
- **Resurrect:** a command mode like Reclaim (the known wreck nearest the click, `Api` order kind "resurrect" → RESURRECT 19). On the card for units whose def has `canResurrect` (T1 workers), key D (rebindable, Settings > Keys). The server ignores it for Commanders' wrecks.
- **Hover and zones** (`Core/ReclaimZones`, `Render/WreckInfo`): the wreck within 24 studs of the ground under the mouse is named, e.g. "Lancer wreck · 45 supply · resurrect 40%". With only mobile builders selected, known wrecks with supply group into zones (two within 80 studs share one), each a thin green ring on the ground (supply-weighted centre, radius holding every wreck + 16) with "+N supply" over it; refreshed 4 times a second. The ring draws on top (AlwaysOnTop, like the radar rings: a flat ring at the centre's height hid under higher ground) and the label sits on its far (north) edge, clear of the wrecks inside.
- `ReclaimZones.spec` (WRECK / WRECK_STATE through the real path while one Mason reclaims and another resurrects; the bars; zones, hover and workers-only), CommandSet.spec (a Mason resurrects).
- Checked in Studio (Coastline skirmish): Lancers and Ravagers fought by the Commander; one Mason reclaimed (green bar under the wreck, the zone total falling), another resurrected (purple bar, power draining, then the Lancer back where its wreck lay with "Construction complete: Lancer"); the hover read "Ravager wreck · 65 supply · resurrect 77%"; the card shows Resurrect for Masons. Screenshots: `debug_out/screens/c216_*.jpg`.

**Why:** the user's resurrect / reclaim feature (S-168, via sim-A).

### C-217 — Colours by side, as the viewer sees them (2026-10-26, S-172)

- `Render/TeamColors` now draws from `Shared/Match/TeamColors.forViewer` (the lobby uses the same function): you are Blue, your allies cold colours, enemies warm ones; spectators see ally team 1 as the cold side. The lobby's colour picks no longer reach the match (the `TeamColors` attribute and `MatchContract.teamColors` are gone).
- The match server publishes every sim player as the Remotes folder's `Players` attribute, JSON `[{ id, team, allyTeam, name? }]`, on every path (lobby contract, the in-match lobby, Studio profiles); IDs are the contract's seat index, as in PREGAME events and the lobby's rooms (sim-A). Without it each team counts as one player (WELCOME's ally teams).
- The module is a table now: `TeamColors.of(team)`, `TeamColors.ofPlayer(player)`, `TeamColors.players()`, `TeamColors.setViewer(player, team, teamAllies)` (Main, on every WELCOME), `TeamColors.version`.

**Why:** the user, S-172: colours are assigned automatically.

### C-218 — The pre-game screen (2026-10-26, S-169, S-171, S-174, protocols 36-37)

- Every lobby match opens with the pre-game (`MatchContract.toSim`: `startMode = "choose"`, `host` = the host's seat (nil when the host spectates), the room's `startBoxes`; player i is seat i with team i and its own faction, S-174, which fixes the "team ... got 18" crash). The in-match lobby and profiles keep fixed starts unless the profile sets `startMode = "choose"` (then slot 1's human hosts). Results time the match from `sim.match.startTick`. MatchConfig v2 in the specs.
- `World.pregame` (NetIn): picks and flags (PREGAME, with CHAOS and HOST), PICK_CLOCK, START_BOXES, COUNTDOWN (3..1, 255 clears, 0 starts and stamps `startedTick`), PREBUILD (kept for later). `Core/Pregame`: boxes from START_BOXES (the map's StartAreas defaults until they arrive), hints, `canPick` (own box, spacing; the server also checks the ground), faction / host / all-ready, the pick clock's text, the camera's focus and fit, the landing fraction, START_POS / READY / FACTION / START.
- Laid out after BAR's start screen (the user's reference): the spawn areas filled on the ground (yours green, the others red; tiles laid on the ground under their corners), faint discs on the map's start hints, each pick showing that player's Commander (its faction's model, its colour) with the spacing disc and the name (✓ when ready), the cursor's spot green or red. No panel over the map (the user): a big Ready / Not ready right of centre, the host's Start under it (lit once everyone is ready), the pick clock; low in the middle the victory condition and what to do; "Starting in n" mid-screen; "Pick your faction" at the bottom with both Commanders' portraits (only while not ready). `/forcestart` (the host) forces the start.
- The landing (`Render/Landing`, `UnitRenderer.lift`): for Schema.LANDING_TICKS after the start each Commander falls from 260 studs, slowing to the ground, in a white-gold star flare with a light and a trail, flashing out on touchdown. The camera opens fitted to the own area and jumps to the own Commander at the start.
- Checked in Studio (FTGG Match, Coastline, you vs a Normal AI): click-pick, faction switch to Chaos, Ready, the host's Start, the 3 s countdown, the flare falling 240 → 25 studs over 1.4 s, /forcestart with an unplaced Commander (the game picked a spot). Simulated GUI clicks don't reach buttons in the Studio test harness, so Ready / Start / faction went through the same commands.
- `Pregame.spec` (the real Sim: boxes, picks, ready, countdown, the Commander on its pick, the landing window; faction and the host's Start; cancel; spectators), MatchContract.spec and Lobby.spec through the pre-game and factions per player.
- Not in yet: queued Commander builds before the match (PREBUILD ghosts, the build menu without a Commander).

**Why:** the published beta had neither start picking nor automatic colours (sim-A); the user's playtest feedback and BAR reference.

### C-219 — The build menu sits on the unit panel (2026-10-26)

- `UI/BuildMenu` is anchored to the bottom, 4 px over the unit panel (120 high), and grows up towards the minimap; on short screens it still scrolls in the room between them.

**Why:** the user: on a live server's tall screen it hung under the minimap with a gap down to the stats panel.

### C-220 — Commander name labels (2026-10-26)

- `Render/CommanderNames`: every drawn Commander shows its player's name (the `Players` attribute) in the player's colour, stacked over the idle tag; hidden at strategic zoom.

**Why:** the user's playtest feedback.

### C-221 — Match failures go back to the lobby with an error code (2026-10-26, F38)

- `MatchContract.ERROR`: the match side's codes from lobby-D's table (match.md section 11): 201 no setup, 202 bad setup (detail: the validator's reason), 203 version mismatch, 204 game version mismatch (REJECT), 205 not in this match, 206 full, 207 already over, 208 players didn't arrive, 209 everyone left, 210 match server error (detail: the error), 299 other. `MatchContract.error(code, detail?)` cuts the detail to 200 characters; `MatchContract.refusal(raw, why)` picks 201 / 203 / 202 for a config the server can't run.
- Every return teleport carries `{ matchId, error = { code, detail? } }` (`sendBack(list, err?)`; the match's own error otherwise; a retry after TeleportInitFailed sends the same). The result record has `error` for 201-203 and 208-210.
- Paths: a refused config (201 / 202 / 203: record and everyone who arrives); a player not listed is sent back with 205 instead of kicked; arriving after the result, 207 (or the match's error); a stale client gets its REJECT, then goes back with 204 three seconds later; every player leaving, 209 in the record; no listed human 120 s after the config was read (`ARRIVE_SECONDS`), 208 and the record; a lobby match's sim throwing, 210 with the error (the sim stops stepping, everyone goes back). Without a readable config there's no lobby to return to: still a kick, with the code in its message. 206 has no path yet (seats come from the list).
- MatchContract.spec: refusal codes, the detail cut, a record with `error` passing the lobby's check. Checked in Studio with the `contract` profile (FTGG Match): 203 (a v1 setup: "setup version 1, match place 2"), 204 (a HELLO with other defs: REJECT, then "match server: protocol 37, defs …"), 205 (not listed), 208 (no listed player in 120 s: the record and the return). 210 can't be forced from the Studio tool (its Luau runs in another VM); checked by review.
- The `contract` Studio profile is a v2 setup now (`host`), and `UI/MatchLoading` calls `RunService:Set3dRenderingEnabled` through pcall: game scripts lack the capability, and the error aborted the client's frame when the loading screen showed and when the match started (the world keeps drawing behind the screen).

**Why:** the user: "any failed attempt to connect to the game match must be displayed on the lobby when return with error code + description" (via sim-A and lobby-D's table).

### C-222 — Playtest phase 1: unit flow made / used, builders keep their queue off camera, aircraft at the edge (2026-10-26, F9, F13, F3)

- **F9:** the unit panel's flow is a line per resource with what the unit makes and what it uses apart (`UnitFlow.parts`): "■ +1.0 −26", "ϟ +20 −51", made green, used red (the user: green positive, red negative), a dim 0 for neither, instead of one net number per resource. `UnitFlow.of` stays the net.
- **F13:** off camera a structure's record carries only its cell, so its spot sits up to half a cell from the order point. `Waypoints.buildDone` matched an own frame only within 1 stud, fell through to the placement check ("occupied: another structure took the spot") and dropped the queued build; the builder then sprayed nothing, or its stale first entry. Records outside the tactical tier now match within `World.CELL_SLACK` (4.5 studs), in `BuildTargets.frameAt` too. Checked in Studio: two vehicle plants queued, the camera away while the first finished; back, the list still held the second and the spray ran to it.
- **F3:** in Studio (the air profile, Archons sent past the corner) no aircraft was drawn outside the map: 21 of 371 flying samples sat on the edge, 0.2 studs past it at most, the wire's clamp. Jets the sim lets overshoot while turning are sent at the edge cell and look pinned there. Handed to sim-A (keep flight inside by the turn radius); nothing to change in the client.

- **The camera opens on the own Commander** in every match (the user): the first frame after a join with an own Commander, outside the pre-game (which jumps on its own), centres on it. Checked in Studio: a fixed-start skirmish opened at the Commander (−348, −124) instead of the map's centre.

**Why:** the user's beta playtest (FTGG-FEEDBACK.txt items 3, 9, 13) and their camera request.

### C-223 — sim phase 2 merged: specs, icons and looks for the new units (2026-10-26, S-175..S-182)

- Merged m-sim-2 2b3ca0e (with ed06b01). Specs moved with the sim's balance: the shield's light-shell scene gives the Locust (55 studs since S-179) a target just inside the dome; the shell-timing and missile-view counts accept the smaller samples; the Wraith scene is on flat:128 with the spotter spawned where the drifting Wraith is; VerticalLaunch measures the climb only on missiles still guided (sim-A: a missile that loses its target in the boost corkscrews at once). Waiting: Effects' decoy scenes (sim-A retunes ew_test), Nanoframe's pads for the new labs (models-C).
- **Icons:** the 19 new units borrow the closest existing icons, listed in the catalogue (`docs/art/icons/ftgg-unit-icons.html`), so the sheet needs no new upload: bot labs the (Adv.) Vehicle Plant, Artisan / Tinker / Lazarus / Graverobber the Ground Worker, Glint / Skitter the Scout, Mace / Thug the Light Tank, Kestrel / Needle the Mobile IR SAM, Fatboy / Tzar / Centurion the Main Battle Tank, Dragon the Attack Helicopter, Liche the Strategic Bomber. Own bot icons can come with the next sheet.
- **Looks:** split weapon ids copy their originals' `fx`, and the client keys looks on `fx`, so they look as before. New: `fx.trail = "plasma"` shells are glowing balls in the weapon's colour (1.4..4.5 studs with the blast); `fx.trail = "flame"` hitscan shots are a thick flickering stream that widens and fades over 0.35 s with sparks where it lands (the Dragon); `fullLength` beams (the Centurion) are drawn on to the weapon's range past the target. Checked in Studio: Thug / Tzar plasma balls, the Dragon's flame drawn.

**Why:** sim-A's phase 2 and new units (the user's playtest).

### C-224 — Wind and tidal in the top bar (2026-10-26, S-177)

- Right of power, as in BAR: WIND, what one of the player's faction's turbines makes now (the Eco record's wind × its `wind.max`), large, with the map's range under it (`layers.wind`, else the sim's default 0.1..0.9, both × the turbine's max; no randomness since S-177), and TIDAL, a tidal generator's output. `UnitFlow.generatorOutputs(defs, faction)`, `UnitFlow.WIND_DEFAULT` (a spec checks it is the sim's). The idle counts sit right of the wider bar (`ResourceBar.WIDTH`).
- The wind box follows the user's sketch and correction: the current in the middle of a near-square box over a see-through three-bladed fan turning with the wind (`FAN_RPM` 40 at a turbine's max), the map's min top right and max bottom right.
- Checked in Studio (Coastline, Order): wind 21 (min 3, max 27), the fan turning; TIDAL 25.

**Why:** the user: "Wind should not be RNG … we have wind min/max current and tidal".

### C-225 — Bombers' carpet in the attack preview (2026-10-26, S-178, F33)

- Attack mode with bombers selected (a BOMB weapon with a salvo of 2+): a blast ring on each bomb's spot, joined along the run, the first on the cursor, the rest `salvo.delay` × the bomber's speed further along the line from the bomber through the spot (`AttackPreview.carpets`).
- AttackPreview.spec against the server's run (an Absolution, 3 bombs): the first bomb 7.5 studs from the spot (blast 14), the next 42.5 on (previewed 40). The server's bomber turns away during its salvo, so bombs 2-3 curve off the straight line; sim-A asked to hold the heading until the salvo is out (the user's "line of bombs"), then the spec checks every spot.

**Why:** the user's playtest F33.

### C-226 — Team panel and sharing; Smart Reclaim; 2 × 2 deposits; pre-game loading (2026-10-26, F23, F42, S-176, S-183, S-184)

- Merged m-sim-2 676ddca (allies' Eco records, AREA, 2 × 2 deposit patches, LOADING, the carpet holding its heading). Specs follow: deposits by patch, the heavy-shell shield scene with a target inside the dome's edge (Ravager 78 studs), the carpet spec checks all three bombs (worst 9.5 studs, blast 14).
- **Team panel** (`UI/TeamPanel`, bottom right; F23): every player by ally team in its colour, with two thin bars stacked, supply over power, each stored / storage (the user: bars for a clearer look); hovering them shows income, stored and storage by the cursor (found by position, not MouseEnter); on each ally's row Units (one click asks the allies for units, two give the selection), ■ and ϟ (one click asks; click and drag up: a slider over the bank, given on release); the last gifts and requests above it for 8 s (`Core/Share`: SHARE_UNITS / SHARE_RESOURCE / REQUEST, SHARE lines). `World.teamEco` keeps every Eco record by team (the own one still drives the top bar). Hidden in the pre-game and the in-match lobby. The debug HUD (F3) starts off outside Studio, over the panel when shown.
- **Smart Reclaim** (F42): in reclaim, repair or resurrect mode a drag is a zone (the area circle), a click the one target; the zone is one AREA command (`Api.actions.areaOrder`) for every selected unit that has the command, its order line ends in the circle until the server reports the builder idle.
- **2 × 2 deposits** (S-184): the extractor ghost snaps to the nearest patch centre within 16 studs (`PlacementRules.depositNear`), the advanced one centred on the T1's patch; extractor drags take each patch once; deposit markers are one per patch at twice the size.
- **Pre-game:** PICK_CLOCK's LOADING reads "Waiting for players to load".
- Checked in Studio (Crossroads, Teams: you and a Normal AI against an Easy AI): the panel with the ally's income and bank and its buttons, 300 supply given ("You gave AI (normal) 300 supply", the bank 1.0k → 701), a request ("You ask for power"); the panel hidden in the lobby. Specs: Share, SmartReclaim; Upgrades and Placement on patches. Nanoframe's pads for the new labs wait on models-C's registration after S-181 reaches main.

**Why:** the user's playtest (F23, F42) and sim-A's phase 2.

### C-227 — Playtest small items: Ctrl + wheel turns, rotation carries on, stock as a number, wider tower lasers (2026-10-26, F2, F14, F10, F11)

- **F2:** Ctrl + wheel turns the camera, 7.5° a notch, within the ±45° limit (Q / C still turn).
- **F14:** a placement's rotation carries on to every later placement (`Api` keeps the last facing; Facing.spec).
- **F10:** a stockpile's row above the health bar is its count as a number and one bar filling with the missile being made (full when stocked up), instead of a pip per missile. Checked in Studio: an anti-nuke at "3", bar full.
- **F11:** the Sentry, Guard, Overwatch and Twin Guard lasers draw 1.8× wider (`Lasers.WIDER`): in Studio core 0.69 / glow 2.14 studs (was 0.39 / 1.19).

**Why:** the user's playtest (F2, F10, F11, F14).

### C-228 — Tower lasers after the user's look; the camera turns all the way round (2026-10-26)

- **Where a hit ends:** a hitscan hit (lasers, beams, tracers) ends on the hit unit's drawn body: the line from the muzzle toward the middle of the nearest drawn model's box at the server's hit point, where it first meets that model (a raycast against it; `Effects.bodyAt`, set by Main). The server aims at its sim height's middle, near the top of most models, so tower lasers ran to the tanks' turrets (the user); ending at the box's middle then hid the burst inside the tank (the user again). Checked in Studio: an Overwatch's laser on a Juggernaut ends at (0.0, 0.3, −2.3) in the model's box (half sizes 3.2, 3.6, 4.3), its front surface; the start is the tower's muzzle attachment (28.7 vs 28.8).
- **The look:** F11's wider towers widen the glow 1.8× and the core only by its square root, the core wavers ±22 % as the bolt lives, the glow fades along the line (0.6 → 0.78 → 0.9 transparency) instead of a uniform rod, and the impact halo is smaller and fainter. At the muzzle a white-hot flash and a soft halo in the beam's colour 1.15× as wide as the glow leaving it (the user: without one the glow looked wider than its starting point).
- **Camera:** no rotation limit; Q / C and Ctrl + wheel turn it all the way round (the user).

**Why:** the user's look at the Overwatch's beam and their camera request (via sim-A).

### C-229 — AI levels, per-shot power, side splits, formation preview (2026-10-26, S-186, S-187, F34, F40)

- Merged m-sim-2 8713c298 (S-186, S-187). The shell-timing scene's count accepts 26.
- **AI levels:** the in-match lobby offers Easy, Normal, Hard - Balanced ("hard") and Hard - Aggressive ("hard_aggressive") in a dropdown (the names don't fit segments); AI names read "AI 1 (Hard - Aggressive)" (`Lobby.levelName`).
- **Per-shot power:** a weapon with `shotCost.power` shows "20 power/shot" on its stats line (unit panel, build menu tooltips); lasers hold fire without power (S-187).
- **F40:** the pre-game's fallback boxes (before START_BOXES) pass the map's `sideSplits` to `StartAreas.sides`.
- **F34, formation lines:** the right-drag line move (LINE flag; Ctrl adds GROUP) now previews each unit's slot along the line, as the order sends them (`Orders.lineSlots`), each with a tick facing across the line away from the group. Checked in Studio: six Lancers, the preview's six slots, the units spread into them. Units keep their travel heading at the end (asked sim-A about turning them to face).

**Why:** sim-A's S-186 / S-187 and the playtest's F34 / F40.

### C-230 — Everything loaded before the match; a readable loading screen (2026-10-26)

- **Preload** (the user: every player sees their models without waiting in game): a lobby match's first CAMERA waits until this client's preload is complete (ground, every approved unit mesh, their SurfaceAppearances and the icon sheets; `Render/Preload`), at most `LOAD_HOLD` (115 s, under the sim's Pregame.LOAD_WAIT of 120 since sim-A raised it): the pre-game's clocks start on every human's first command (S-182), so nobody's pick time runs while they still load. Behind the loading screen 16 meshes build at once (8 in game). Measured in Studio's `contract` match: 45.9 s with 8 at once, 24.5 s with 16 (a cold Studio cache; the published place will be slower to download). The pre-game's Commanders redraw as their meshes finish (they stayed blockouts).
- **Loading screen text** (the user: hard to see over the key art): a dark outline on the title, the players and the tip, the players larger and semibold, a strip behind the tip; no card behind the text (the user tried it: worse).

**Why:** the user's preload request (via sim-A) and their look at the loading screen.

### C-231 — The bots walk; the Dragon's fans turn (2026-10-26, S-181, models-C 4f6f268f)

- Merged m-models 4f6f268f (the 19 S-181 blockouts registered, the bots' legs renamed to the walker convention). Nanoframe.spec passes again: all client specs pass.
- `PieceScripts/Bot`: the eleven biped bots (Artisan, Tinker, Lazarus, Graverobber, Glint, Mace, Thug, Kestrel, Needle, Fatboy, Centurion) walk the Commander's stride on `thigh` / `shin` / `foot` L and R, without the torso twist (their torso is the weapon turret, aimed by Default) or arm swing (none), the pelvis dipping 5 % of the hip height. A stride covers 2.9 hip heights at the bot's top speed (0.25..1.2 s); the swing is scaled per bot (models-C: Fatboy ×0.5, Centurion ×1.15). Skitter walks a diagonal gait on its four splayed legs (FL with BR, FR with BL). Stopped, legs ease to rest.
- `Bot.Dragon`: the Dragon's ducted fans (`fanL` / `fanR`) turn all the time, faster while it moves.
- Ambient.spec: the bots stride and rest, the torso stays, Skitter's pairs swing together, the fans turn, Fatboy strides slower than Glint. Checked in Studio at a quarter speed: Glint, Mace, Fatboy, Centurion and Skitter walking.

**Why:** the new walking units (S-181) and models-C's leg kit.

### C-232 — Death blasts by unit (2026-10-26, F15, S-178)

- Every unit now has a `deathBlast` (sim-A's `Defs.defaultDeathBlast`, S-178), so every death adds a blast burst sized from its def: an ordinary one at 0.6 × its damage radius (`Effects.BLAST_SHOWN`), so small units don't white out the screen; a huge one (90 studs and up: Commanders 120, fusion reactors 120; `Effects.HUGE_BLAST`) plays the nuke's look scaled to its radius (0.8 of a nuke), held twice as long, without the nuke's crater (`Burst.noCrater`). Generator chains follow from the sim's blasts.
- Checked in Studio (Coastline): three Lancers' small blasts; a fusion reactor's big fireball and smoke column.

**Why:** the user's playtest F15 ("death explosions for every unit, by tier / energy stored; Commander a huge blast, smaller than a nuke").

### C-233 — Protocol 38 on the client (2026-10-26, S-189)

- Wire positions sit on a fixed 64-stud grid, independent of the map. Strategic records and ALERT decode their offsets: a strategic record gives the centre of the unit's 8-stud square. A known unit keeps its exact spot while it stays in that square, where before it kept it while it stayed in its map cell.
- SIGHT_CELLS entries are u24: the index is the entry below `Schema.SIGHT_SEEN`. `Commands.cameraRect` clamps only to the map (u16 on the wire, up to 1,024 cells).
- Aircraft and shots may go up to `Grid.OVERFLY` (512 studs) past the edge. The 3D view draws them there. The minimap pins their dots to its edge instead of clipping them.
- Specs:
  - wire precision is now a quarter stud;
  - missiles burst at the overfly margin;
  - the bomber carpet test starts the bomber far enough out to release on its first pass. A bomber that misses its window goes round and comes back on another line (D91), which no preview can predict. The old edge rule happened to bring it back straight.
- Checked in Studio on The Lakelands (512 cells):
  - camera cells up to 511, nothing dropped;
  - three off-camera Lancers at x 1901, 1915 and 1929 drawn at 1900, 1916 and 1932;
  - Falcons drawn out to x 2,344 on a map that ends at 2,048.

**Why:** S-189 (bigger maps, F3/F4).

### C-234 — Plasma without a blast looks like a tank shell (2026-10-26, S-190)

- A plasma shot with no aoe (the Thug's and the Mace's since S-190) is a ball as thick as a tank shell (0.9), in the weapon's colour. Bigger plasma keeps `1.4 + aoe × 0.08`.
- An `explosion_small` impact with no aoe bursts at `Effects.SMALL_HIT` (3, the Lancer shell's aoe) instead of falling to the smallest burst.
- Checked in Studio (The Plains): Thug and Mace balls 0.90 in (255, 225, 120), beside the Lancer's 0.9 × 0.9 × 2.6 shell in the same colour.

**Why:** the user, via sim-A: "Thug / Mace's plasma should be the same size as the tank, their shot explode like a small hit vfx of the tank because they should have no aoe damage to their shot at all."

### C-235 — Units stand on a coarser bake's surface (2026-10-26, models-C's `coarsen`)

- models-C bakes The Lakelands with a height sample every 8 studs, not 4: Field.coarsen keeps every other sample of the export. The kept samples sit on the sim's cell corners. Each one is the average of its four cells, so the mesh never passes through the cell-centre heights the client placed units on.
- Measured across the map from `ground.json`: off by 0.10 stud on average and under 0.56 for 99% of cells. But at the foot or top of a cliff the gap reaches about 2 studs on flat grass. 224 cells are like that, mirrored round the map. Steeper cells, up to 14.5 studs off, are impassable cliffs under C's rock details.
- Fix:
  - `Core/Terrain.drawnY(layers, x, z, step)` rebuilds the bake's surface from the sim's layers: the smooth height at each `step` corner, and two flat triangles per square split along the flatter diagonal, as `ground.py` builds them.
  - `World.welcome` sets `world.drawnStep` from `GroundMeshes.drawnStep(mapId)`: the manifest entry's `step`, which models-C writes for every bake coarser than 4 studs (the fallback table `GroundMeshes.COARSE` went once it did, main ae6356ad). It is nil for 4-stud bakes and for maps without mesh ground.
  - `World.groundY` uses the drawn surface when `drawnStep` is set, so units, wrecks, bars, rings, effects and the fog blanket all follow the mesh. Contacts and MissileView now read heights through `World.groundY` too.
- The contract (`docs/contracts/map-ground.md`) gains the entry's optional `step` and the triangle rule.
- Spec: on 4,003 spots on The Lakelands, including the flagged ridge-foot cells, `drawnY` is within 0.05 stud of a surface built independently from `ground.json`, where the cell-centre surface is up to 7.45 studs off. The hundredths come from squares whose two diagonals are almost equally flat, where the export's rounded heights tip the split.
- Studio: three Lancers at the ridge's foot (x −972 to −956, z −1580) sit on the drawn grass and slope; screenshot `debug_out/screens/2026-10-26-lakelands-ridge-foot.jpg`. The ground's 402 pieces took about 160 s to load on the first run of a session and about 55 s once cached. The first figure is past the loading screen's 115 s hold.

**Why:** models-C's note with the bake: on coarsened maps the mesh and Core/Terrain's heights differ on slopes.
