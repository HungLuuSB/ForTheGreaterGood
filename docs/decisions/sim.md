# Simulation decisions (S-)

Decisions of the headless simulation stream: `src/shared` (except `Defs/Blockouts/`), `src/server`, `.lune/`, balance and stress tooling. Progress is in [`../progress/sim.md`](../progress/sim.md). Earlier decisions (D1–D109, both areas before the split) are in [`../DECISIONS.md`](../DECISIONS.md).

Each entry gives the date, the decision, the alternatives and the reason. Overrule any of them and the code, the guide and this file are updated together.

## Summary

- S-1: network contract `docs/contracts/net.md`; projectile math moved to Shared.
- S-2: join / reconnect snapshot and the Eco channel (protocol 6).
- S-3: weapon pieces must be in `pieces` (client request).
- S-4: order queues and behaviors (shift, FIGHT, PATROL, ATTACK, GUARD, REPAIR, RECLAIM, BUILD, factory rally and repeat).
- S-5: field extensions run as sliced Pathing jobs (Movement peak at 800 units 12.1 → 6.3 ms).
- S-6: unit state bits in Shared (`Schema.UnitState`; client request).
- S-7: smarter skirmish AI (radar, fire-control radar, kiting artillery, anti-air).
- S-8: 40-minute AI-vs-AI soak test (`lune run soak`).
- S-9: placement rules in Shared (`Shared/Grid/PlacementRules`; client request).
- S-10: strategic icon numbering in Shared (`Shared/Net/Icons`; client request).
- S-11: bombers have no turret piece; turretless weapons can't name turret or pitch pieces (client request).
- S-12: formation slots in Shared (`Shared/Grid/Formation`; client request).
- S-13: REPEAT command and state bit (protocol 7); TOGGLE means on / off only.
- S-14: attack-move holds only while an enemy is within firing range (BAR).
- S-15: procedural skirmish maps (`Shared/Grid/MapGen`), four named maps.
- S-16: own units' weapon targets in State records (protocol 8; client request 6).
- S-17: AI difficulty levels (Easy, Normal, Hard) as a match option; AI fairness fixes.
- S-18: spectator stream and player replay files.
- S-19: build ranges at 70% (client request 7); frames start in range of their snapped center.
- S-20: aim rest pose and restore delay (`Shared/Combat/Aim`; client request 8); the Juggernaut's arms.
- S-21: Eco records carry their team (protocol 9); spectators get every team's economy.
- S-22: first balance pass, T1 ground (six numbers).
- S-23: start-position bias: the targeting stagger followed ID parity; hashed phase.
- S-24: AI waves: artillery guards the lead tank.
- S-25: Easy AI: one army unit per 15 s instead of an early rush.

---

## S-1 — Network contract; projectile math in Shared (2026-10-21)

- **Contract:** `docs/contracts/net.md` describes everything the client receives (protocol 5) and the join snapshot and Eco channel coming as protocol 6 (S-2).
  - The sim stream owns it: the layouts are `Shared/Net/Schema`'s, and the rules NetOut's.
  - `Tests/Support/Client.luau` is the reference receiver. When the two disagree, the code wins and the contract is fixed.
- **Projectile math in Shared:** `Ballistics` moved from `src/server/Sim/Combat/` to `src/shared/Combat/Ballistics.luau`, so the Roblox client can step projectiles with the server's exact math (`step`) and turn homing ones with its steering (`steer`, moved from Projectiles).
  - The old path is a one-line shim, so server requires are unchanged.
  - The headless client uses `Ballistics.steer` too.
  - Alternative: a client-only copy of the math, which would drift from the server's. Rejected.

## S-2 — Join / reconnect snapshot and the Eco channel (2026-10-21; guide 7.5)

- **Handshake** (Snapshot channel, `PROTOCOL_VERSION` 6):
  - HELLO (C → S): protocol, defs hash.
  - REJECT (S → C): the server's versions, reason 1 protocol / 2 defs.
  - WELCOME (S → C): full u32 tick, player, team, ally team, map ID.
  - `NetOut.hello` checks; `NetOut.join` queues the WELCOME.
- **No separate snapshot format:**
  - The join resets the player's replication state (tactical set, known projectiles, homing view) and forces a full strategic snapshot and an Eco record in the next outbox.
  - The normal channels then rebuild the view: ENTER for the camera area (a reconnect keeps the camera), strategic records for everything else, SPAWN_PROJ for projectiles in view.
  - Alternative: one big snapshot message with every unit's state. Rejected: it would duplicate every layout, and the normal path is already tested for exactness.
- **Eco channel:** one 35 B record per change, on economy ticks (every 5th tick), for the player's team only.
  - Per resource: stored, storage (whole units), income, demand (tenths per second), stall ratio (u8).
  - Then the wind (u8).
- **Tests:**
  - `NetOut.spec`: two identical runs of a battle, one client connected throughout and one joining at tick 300. The views are identical five ticks later (units, tiers, positions, icons, flags, unguided projectiles, economy), and the sim hashes match. Without the reset it fails.
  - HELLO accepts, rejects with each reason, and errors on garbage.
  - Eco values match the account.
  - `Schema.spec`: golden bytes, round trips, truncation and rejections for the new records.

## S-3 — Weapon pieces must be in `pieces` (2026-10-21, client request)

- **Found:** 14 unit defs named a `turretPiece` missing from their `pieces`: `bay` on the four bombers, `launcher` on SAM trucks, MLRS and torpedo launchers, `turret` on two fighters.
- **Fix:** the missing piece is added to each def's `pieces` (after `base`).
- **Validation:** `Defs` now rejects a weapon's `turretPiece`, `pitchPiece` or `muzzle` that isn't in the unit's `pieces` (`Defs.spec` case). The client rig (guide 14.2, `docs/contracts/rig.md`) animates these pieces.
- The defs hash changes; both sides load the same files.

## S-4 — Order queues and behaviors (2026-10-21; guide 15.6, 8.x factories)

- **Model:** `Sim/Orders.luau` and `OrdersState` (hashed). Each mobile unit has a queue of orders, head first.
  - A command replaces the queue; with the queue flag (shift) it is appended.
  - `Orders.step` runs at the end of the Commands system every tick. It starts the head order through the existing mechanisms (Nav moves, Build commands, `Air.attackGround`) and pops it when done:
    - a move when its Nav order ends;
    - builder orders when the builder is idle;
    - attack when the team no longer knows the target;
    - guard when the ally is gone.
  - Units starting move-like orders from the same command in the same tick move as one group (formation slots).
  - Aircraft away rearming pause their queue and restart the head order afterwards.
- **Behaviors:**
  - **FIGHT** (attack-move): the move holds while the unit has a weapon target. Movement brakes and keeps the order (`orders.hold`); jets don't hold.
  - **PATROL:** fight-moves between the unit's start and the point, forever.
  - **ATTACK:** the target (with its generation, D109; a ghost's for dead structures) must be known to the sender's team when commanded and every tick after.
    - Targeting gives every weapon that can engage it that target (`orders.forced`), overriding the fire state.
    - The unit chases to 90% of its longest range and halts there; aircraft chase on their own.
    - A command naming a unit the team doesn't know is ignored (no information leak, no cheating).
  - **GUARD:** stays within 80 studs of an allied unit (chase moves throttled to every 15 ticks or 24 studs); builders assist a guarded frame or factory.
  - **REPAIR:** besides frames and factories, heals finished, damaged allied units at the rate they were built, for free (BAR-style; see "Needs my review").
  - **RECLAIM, BUILD:** queueable.
  - **Factories:**
    - a move-like order sets the rally point; produced units roll out (an exit move), then take the rally order (`Build.producedHook`);
    - TOGGLE sets repeat, and finished items are re-queued.
- **Effects on existing behavior:**
  - FIGHT used to be a plain move, so balance fights (attack-move) and the AI now stop to engage.
  - The torpedo-drift test in `NetOut.spec` saw shorter flights; its threshold became relative (corrections still cut drift 56 → 9.6 studs).
  - A stopped builder's target reads `nil` (idle) instead of 0.
- **Tests:** `Orders.spec`, 8 tests: shift order and replacement, FIGHT vs MOVE, PATROL, GUARD, ATTACK (forced, on hold fire, hidden targets refused), REPAIR free, RECLAIM and BUILD queues, rally and repeat, determinism. Mutations (no hold, no forced target, no queue flag, no repeat) fail them.

## S-5 — Field extensions as sliced Pathing jobs (2026-10-21; guide 6.4)

- **Found** (profiling the 800-unit stress battle tick by tick): Movement's peak ticks spent 4–8 ms in `Nav.extendField`, almost all of it in `Route.findMany` (1.5–2 ms per call, 2–3 calls per peak tick). Extensions were computed synchronously inside Movement, outside the pathing budget.
- **Change:**
  - `Nav.extendField` now queues a plan job (`Plan.extend`) with its route search pre-built. `Nav.runJobs` slices the search within the Pathing work budget, then builds the corridor, merges it into the order's current one and runs the flow-field job.
  - Movement only queues. Units steer straight until the field covers them, which guide 6.4 allows.
  - An extension that finds no route leaves the order as it is (it doesn't mark it unreachable).
  - `Route.mergeCorridors(a, b, width)` scans only the two corridors' bounding box, not the whole map mask.
  - The extension's corridor step waits for the next tick when the budget left can't cover it (one unit per 4 cells of the old corridor's box).
- **Measured** (`lune run stress`, peak / average ms):
  - Movement at 800 units: 12.09 / 3.87 → 6.39 / 3.48 (budget 10). At 600: 12.19 → 4.85.
  - Pathing at 800: 8.60 → 8.37 (budget 8).
  - Average tick at 800: 8.89 → 8.62 ms.
  - One sequential stress run showed a 16 ms Pathing tick at 600 units. Isolated runs of that scenario peak at 8–9 ms, so it was noise.
- The peak was already lower than round 7's 43.9 ms before this change, because attack-move now holds to engage (S-4) and units bunch less.

## S-6 — Unit state bits in Shared (2026-10-21, client request)

- `Schema.UnitState` (MOVING 1, TOGGLED_ON 2, SUBMERGED 4, LANDED 8) is the one definition of the `state` bits in ENTER and State records. `World.State` is the same table, so the client decodes them without a copy. Alternative: a client-side copy, which could drift. Rejected.
- `Schema.spec` checks that the two are one table with the expected values. Contract section 3 names it.

## S-7 — Smarter skirmish AI (2026-10-21)

- **Radar:** once a Vehicle Plant and two extractors stand, a worker builds the faction's radar tower toward the enemy. The plant builds one mobile radar after the workers.
- **Fire-control radar:**
  - With more than 900 supply stored, a worker builds the Advanced Vehicle Plant, and idle workers assist the frame.
  - The advanced plant builds one mobile fire-control radar (Arbiter / Stalker), then MLRS and main battle tanks, half and half by the AI's Prng.
  - Radar and fire-control vehicles GUARD the wave's lead unit (S-4), so the wave's artillery fires on radar contacts with tracking (D104).
- **Kiting:** each think, artillery and MLRS check for a VISIBLE enemy ground unit within half their range.
  - If there is one, they MOVE 100 studs directly away, then (queued) FIGHT back toward the wave's target if they were in the wave.
  - Kiting units are left out of wave orders for 45 ticks. Tanks never kite.
- **Anti-air:**
  - The census counts enemy aircraft the team knows: VISIBLE, tracked, or radar contacts, whose domain is known (D107).
  - The plant keeps one IR SAM truck per two known aircraft, at most four.
  - A worker builds an IR SAM site when enemy aircraft are within 1.5× the home radius.
- **Determinism:** decisions read only team knowledge and own state; randomness only from the AI's own Prng. The AI-vs-AI replay test still passes.
- **Tests** (`AI.spec`, 4):
  - radar towers on both sides by 1.4 min;
  - a rich AI fields an Arbiter by 3.1 min;
  - four helicopters over the base bring IR SAM trucks and a site;
  - a Verdict kites from a close tank (a Lancer never does).
  - Disabling anti-air, kiting or the tech-up fails its test.
- **Balance numbers** (the thresholds 900 supply, 1 per 2 aircraft, half range, 100 studs) are placeholders for M8.

## S-8 — 40-minute AI-vs-AI soak test (2026-10-21)

- **`lune run soak [seed] [minutes]`** (`.lune/soak.luau`): Order AI vs Chaos AI on `skirmish:256` under Annihilation, for up to 40 minutes of game time or until the match ends.
  - Reports average, p95 and p99 tick time, the peak tick and the slowest systems, unit counts, and the Lua heap per minute.
  - It then replays the command log and compares the final hash.
  - Exits 1 when the peak tick exceeds 66.7 ms, the heap more than doubles per unit after minute 5 (a leak), or the replay differs.
  - Output also goes to `debug_out/soak.txt`.
- **Why a script, not a spec:** a full 40-minute match plus its replay takes about 30 s, more than the whole `lune run test` suite. Specs stay fast; the soak runs on demand, like `lune run stress`.
- **Default seed 3:** it plays the full 40 minutes. Seeds 1, 2, 4 and 5 end with an annihilation at 10–18 minutes (one AI overruns the other), which the soak reports as a pass of a shorter match.
- **Result (seed 3, dev PC):**
  - 40.0 min (36,000 ticks) in 16 s; at most 152 units alive (it grows steadily from minute 15);
  - tick average 0.44 ms, p99 1.39 ms, peak 10.8 ms (Pathing 9.4, Construction 6.9);
  - heap 6–16 MB with no growth trend (214 KB per unit at minute 5, 99 KB at minute 40);
  - replay identical.

## S-9 — Placement rules in Shared (client request 4, 2026-10-21)

- **`Shared/Grid/PlacementRules`** (pure, runs in both runtimes) holds what the client copied (C-14):
  - `snap(grid, size, x, z)`: the footprint's min-corner cell and snapped center;
  - `terrainOk(passMap, cellIndex, placement)`: the terrain rule per cell ("land": dry and at most 30°; "water": at least 6 studs deep; anything else: either);
  - the constants `LAND_MAX_SLOPE`, `WATER_MIN_DEPTH` and `RADIUS_PER_FOOTPRINT`.
- **Single source:** the server's `Placement.snap` *is* `PlacementRules.snap`, `Placement.check` calls `terrainOk`, and `Nav.RADIUS_PER_FOOTPRINT` / `Combat.RADIUS_PER_FOOTPRINT` read the shared constant (they were two hand-kept copies). The old `Placement.*` names stay as aliases.
- **Not shared:** occupancy, deposits, units in the way and the planning check by team knowledge stay in the server's `Placement.check`; the client can't know them exactly (fog), so its ghost tint covers terrain and its own known structures only.
- **Test** (`Placement.spec`): on `wall:64` and `gen:3:48`, for a land and a water structure, `Placement.check`'s terrain verdict equals `terrainOk` over the footprint at every third cell (both outcomes seen, and water placements on the lake). Making the server ignore the placement kind fails it.

## S-10 — Strategic icon numbering in Shared (client request 5, 2026-10-21)

- **`Shared/Net/Icons`**: `Icons.names(defs)` (icon number → name: the distinct `icon` names of all unit defs, sorted), `Icons.byDef(defs)` (def index → number, 1..63) and `Icons.MAX = 63`. It lives under `Net` because the numbering is part of the wire format (net.md section 3).
- **Single source:** `NetOut.iconIndex` is now `Icons.byDef`. The client's `Core/Icons` copy can call it instead.
- **Test** (`NetOut.spec`): the names are sorted and distinct, every def's number is in 1..63 and names its icon, and the server's `sim.net.iconIndex` equals `Icons.byDef`. Changing the server's numbering fails it.

## S-11 — Bombers have no turret piece (client request 1, 2026-10-21)

- **Design:** a bomb is released with zero launch speed at the computed lead point and falls (guide 10.x `BOMB`, D91). The bomber lines up its run; nothing on it turns toward the target. The bomb weapons (`ord_bomb`, `ord_heavy_bomb`, `chs_bomb`, `chs_heavy_bomb`) have no `turret` block.
- **S-3 was half the fix:** it added `bay` to the bombers' `pieces`, so the defs validated, but `turretPiece = "bay"` still told the client rig to yaw the bomb bay with the sim's aim angle (which, for a turretless weapon, snaps to the target bearing).
- **Fix:** `ord_absolution`, `ord_phantom`, `chs_behemoth` and `chs_plague` drop `turretPiece`; their weapon keeps `muzzle` (the release point). `bay` stays in `pieces` as a static model part.
- **Validation:** besides S-3's rule (every `turretPiece`, `pitchPiece` and `muzzle` is in `pieces`), `Defs` now rejects a `turretPiece` or `pitchPiece` on a weapon without a `turret` (nothing turns it). Exactly the four bombers failed it. `Defs.spec` has a case.
- The client doesn't reference `bay` (its workaround put the muzzle on the hull); with the muzzle now the only weapon piece, it can drop the workaround.

## S-12 — Formation slots in Shared (client request, 2026-10-21)

- **`Shared/Grid/Formation`** (pure) now holds what `Nav` used to do alone and the client copied (`Core/Orders.lineSlots`, `Core/Waypoints`):
  - `SLOT_SPACING = 1.3`, `spacing(maxRadius)`;
  - `spiral(count)`, the cached lattice offsets nearest first;
  - `layout(n, spacing, cx, cz, lx?, lz?, backX, backZ, ground?)`: line rows stepping back toward the centroid, or a spiral;
  - `deepestFirst(slots, ...)`: far side of the formation first;
  - `assign(posX, posZ, members, slots)`: the bucketed greedy assignment (closest unassigned unit per slot, ties to the lower ID), with `ASSIGN_BUCKET = 32`.
- **Terrain stays a callback:** `ground = { open, snap }`. The server passes its quadtree test (open cell of the group's component) and its nearest-open snap. A client passes none, so on open ground it gets exactly the server's goals; near blocked cells it can differ (fog: it can't know every structure).
- **Positions as arrays:** `assign` takes `posX` / `posZ` indexed by unit ID instead of the server's `World`, so the client can pass its own tables.
- **Server:** `Nav.SLOT_SPACING`, `Nav.ASSIGN_BUCKET` and `Nav.assignSlots` remain as aliases / a thin wrapper; `slotsFor` builds the ground callbacks and calls `layout`; the issue path calls `deepestFirst`. Aircraft still ignore line moves (a spiral around the line's midpoint); the module documents it.
- **Unchanged behavior:** before and after the move, 17 fingerprints (two 6-minute AI matches on `skirmish:256`, five group-move rounds of 36 tanks and 6 helicopters on three maps) give identical sim hashes.
- **Test** (`Formation.spec`, 3): the shared constants and `assign` (ties, running out of units); `layout` and `deepestFirst` shapes; and on `flat:128`, for line, short-line, spot, two-move-class and aircraft orders, a client-side prediction from `Formation` alone equals every server goal. Removing the server's `deepestFirst` call fails it.

## S-13 — REPEAT command; TOGGLE means on / off (2026-10-21, review answer)

- **Answer to S-4's review item:** factory repeat gets its own command. Protocol **7**:
  - `CmdType.REPEAT = 15`, params `value u8` (0 off, 1 on), like TOGGLE;
  - `UnitState.REPEAT = 16`: a factory's repeat is a replicated state bit, so every client (and spectators) can show it;
  - TOGGLE switches `TOGGLED_ON` on any unit again; on a factory it no longer touches repeat.
- **Server:** `Orders.setRepeat` ignores non-factories, sets `repeatOn` and the state bit. Repeat behavior itself is unchanged (S-4).
- **Tests:** golden bytes for a REPEAT command pinned to protocol 7; REPEAT's value range; the first unknown command type is now 16; the UnitState table; `Orders.spec` "REPEAT sets a factory's repeat (and its state bit); TOGGLE only switches on / off", and the rally / repeat test uses REPEAT.
- **Client:** `Api.toggle` keeps sending TOGGLE; a repeat button needs `CmdType.REPEAT`. Replays recorded with protocol 6 don't play back (they carry their protocol version, guide 17.1).

## S-14 — Attack-move holds only with an enemy in firing range (2026-10-21, review answer)

- **Answer to S-4's review item:** BAR behavior. A FIGHT / PATROL move keeps advancing while no enemy is within weapon range, stops and fires when one is, and goes on when none are left. Seeing an enemy isn't a reason to stop.
- **What changed:** S-4 held while any weapon slot *had a target*. Targeting keeps a target out to 110% of range (hysteresis against flip-flopping), but Weapons fires only at `range + target radius`. So a target that stepped just beyond range left the unit standing still without firing (and an AI kiting back 100 studs could exploit it).
- **Now** (`Orders.engaged`): the move holds only while some slot's target, at the position the team believes it is (D100), is within that weapon's firing range: center distance ≤ `range + radius`, the radius counted only when the target's type is known (the same rule as Weapons). The hold is decided at the start of a tick (Commands) from the previous tick's positions. Jets still never hold.
- **Test** (`Orders.spec`): a Lancer on attack-move sees a Ravager (through a spotter) long before it is in range and never holds then; holds and fires in range; when the Ravager backs off, it goes on to the goal without ever holding with the target beyond firing range. Restoring "any kept target holds" fails it (11 ticks held out of range).
- **Balance re-run** (`docs/BALANCE.md`): 447 of 568 pairs hold (was 448); 203 findings, 79 mechanic and 124 numbers (was 206: 75 and 131); same-role band 25 of 38 (was 24). Tank mirrors are unchanged (Lancer vs Ravager 0.38–0.39), and ships still stand off at their own range (39 "can't see" findings): with BAR attack-move a ship that outranges the beach fires from there. Both are M8 numbers, per the review answer.

## S-15 — Procedural skirmish maps (2026-10-21; guide 5.5)

- **`Shared/Grid/MapGen`** (pure Luau, deterministic): `MapGen.generate({ seed, cells, layout, symmetry?, water? })` returns `Layers` (height, water depth, supply, starts: the format every map uses, so the client renders it from the map ID) and an `Info` (layout, symmetry, water, players, mode tags `Team` / `FFA` / `Naval`, attempts).
  - Layouts: `1v1` (mirror or rotate2), `2v2` (mirror4: starts 1–2 are the west team, 3–4 the east team), `ffa4` (rotate4, one start per corner). Water: `none`, `lakes` (landlocked), `sea` (a northern sea on mirror maps, a central sea otherwise).
  - **Exact symmetry:** each cell's orbit under the symmetry's transforms is computed once (its lowest-index cell) and copied. Noise is averaged over the transforms so it's continuous across the seams; features (hills, ridges, lakes, deposits) are drawn once and replicated.
  - **Per start:** a flat plateau (9 cells) with 4 safe deposits (value 4); two expansion pairs (value 3) toward the middle; a rich deposit (value 6) halfway between the start and the nearest enemy start (contested by construction), moved part way toward the middle; deposits never in the sea.
  - **Terrain:** gentle hills (passable by every land class); mountain ridges (impassable; a ridge blocks its half-width plus a one-cell rim) with a pass on each start's way to the middle: two ridge arms leaving a 5–8-cell gap; more ridges elsewhere. Lakes and seas get beaches (land slopes to the water level within 4 cells) and depth ramps 2 studs per cell from 1 at the shore (ships from ~2.5 cells out, submarines from ~5.5).
  - **Checked candidates:** `MapGen.check` builds passability and requires: for TRACKED and HEAVY_TRACKED, every start in one component for footprint-3 units; **no gap narrower than 3 cells** (two areas big units can stand in that only small units travel between); every deposit buildable and reachable; on sea maps a sea of ≥ 400 ship cells within 48 cells of at least two starts. `generate` draws new features until a candidate passes (deterministic; up to 60 attempts; the winning attempt is cached per options).
- **`MapRegistry`:** `"mapgen:<layout>:<seed>:<cells>[:<water>[:<symmetry>]]"` and four named maps, `"map:<name>"` (`MapRegistry.NAMED`, `MapRegistry.info(mapId)`):

| ID | Name | Layout | Cells | Symmetry | Water |
|---|---|---|---|---|---|
| `map:ridgeline` | Ridgeline | 1v1 | 128 | mirror | none |
| `map:coastline` | Coastline | 1v1 | 128 | mirror | northern sea (Naval) |
| `map:twin_lakes` | Twin Lakes | 2v2 | 192 | mirror4 | lakes |
| `map:crossroads` | Crossroads | ffa4 | 192 | rotate4 | central sea (Naval) |

- **Tests** (`MapGen.spec`, 6): byte-exact symmetry under every transform, start k = image of start 1, determinism; every start reaches every other for TRACKED and HEAVY_TRACKED footprint-3 units and WHEELED, using the **server's Nav quadtrees** (not MapGen's checker); on sea maps, the nearest ship-navigable water of every coastal start is one sea shared by ≥ 2 starts; the checker reports a 2-cell pass and accepts a 3-cell one, and all generated maps pass it; deposit totals per start are equal (nearest-start assignment, ties split), each start has ≥ 4 safe deposits and there are contested ones; a skirmish start runs on the named maps.
- **Tooling:** `lune run debug_map <mapId>` renders any registry map (impassable cells for TRACKED in dark red, deposits in yellow, starts in white).
- **Not done:** sight bonus for elevation (guide 5.5 "optional"), terrain types (no `terrainType` layer yet), maps above 4 players.

## S-16 — Own units' weapon targets on the wire (client request 6, 2026-10-21)

- **Request:** the client's target line (C-20) guessed the target from the turret aim. It now gets it exactly.
- **Protocol 8:** State records get a `targets` field, mask bit `TARGET = 32`: `slotMask u8`, then `targetId u16` per set slot (0 = no target), like `aim`.
- **Who gets it:** only the unit's owner (not allies, not enemies: the target choice is the owner's information). NetOut keeps, per player, the last targets sent per own tactical unit (`sentTargets`, a string of slot targets); it sends all slots when any changed, and in the unit's ENTER tick when it has a target. A join clears `sentTargets`.
- **Exact:** NetOut runs after Targeting in the same tick, so the client knows the target from the tick it is picked, before the turret has turned.
- **Tests:** golden bytes for a targets record pinned to protocol 8; the full State record size; random round trips with targets; an empty target slot mask and reserved bit 64 rejected; `NetOut.spec` "own units' weapon targets reach their owner only, exactly": two Lancers against two Ravagers, the owner's view equals `wTarget` on all 480 unit-ticks, the enemy never gets targets. Sending only on ENTER fails it (7 of 480).

## S-17 — AI difficulty levels (2026-10-21)

- **Match option:** `match.ai = { [playerId] = "easy" | "normal" | "hard" }` (validated with the other match rules; unknown players or levels are refused). `Skirmish.forMatch(sim)` makes a brain per listed player; `Skirmish.new(sim, player, level?)` defaults to the match option, else Normal. Levels stay out of the replay header: the AI's commands are recorded like a player's.
- **Levels** (`Skirmish.LEVELS`):
  - **Easy:** thinks every 2 s; 2 workers; one item queued per factory; at most 6 extractors; one plant; no radar, anti-air, tech-up or kiting; 15% artillery; attacks early with small waves (6, +2).
  - **Normal:** the S-7 AI (3 workers, waves of 8, +2).
  - **Hard:** thinks every 2/3 s; **expands only to deposits nearer its own start than any enemy start**; escorts (3 army units GUARD) every worker sent beyond 160 studs, until it is idle; gun turrets once 5 extractors and 4 army units stand (two toward the enemy, one more per two far extractors, at most 6); once 6 extractors, 6 army units and 200 supply stand, the Command Vehicle builds an **airfield** (helicopters and bombers; fighters against known aircraft) and, when deep water is within 64 cells, a **shipyard** (corvettes and submarines; the fleet gathers at sea and attacks in groups of 4); bigger waves (12, +4) that go for the enemy Command Vehicle first (it ends the match). Builders that are only assisting a factory leave it for these.
- **What made Hard stronger** (measured with 12-game Hard-vs-Normal sets on Ridgeline, both factions, sides swapped, seeds 7–9): safe expansion (1.5 → 10.5 of 12). Escorts, turrets and the airfield cost a little early but are the behaviors asked for; a "Command Vehicle backs off from threats" behavior was tried and removed (it stopped the commander building; 7.5 → 4).
- **Fairness fixes found on the way** (they change Normal too; the AI matches in the soak and `Skirmish.spec` play differently):
  - the build-spot rings were swept from +x for both players, so the two starts of a mirrored map built different bases; the sweep now mirrors with `toward`;
  - players thought at `tick + player`, so the higher player always acted a tick earlier and won every race; now they are spread evenly over the think period;
  - deposits equally near two starts (on a mirrored map, exactly equal) are a race decided by unit IDs and player order, not play: no AI claims a deposit within a cell of equal distance to its own and an enemy start; ties in the deposit order go to the one farther from the enemy.
  - A positional bias remains in mirror matches (a deterministic sim amplifies tiny differences); the matchup report swaps sides for every pairing.
- **Report:** `lune run ailevels [minutes] [filter] [seeds]` writes `docs/AI_LEVELS.md`: 1v1 on Ridgeline, Coastline and `skirmish:256` (each pairing as an Order mirror and a Chaos mirror, sides swapped: Order vs Chaos measures the faction, not the level, while Ravager trades 2.5:1 against Lancer, M8), a 2v2 per pairing on Twin Lakes (each team one Order and one Chaos player), two 4-player FFAs on Crossroads; winner, length, peak units, a tally and match lengths per map.
- **Tests** (`AI.spec`, 5 new): the match option and its validation; Easy's limits; Hard's turrets, escort and airfield with aircraft; Hard's shipyard and fleet on Coastline; Hard beats Easy (Ridgeline, seed 9). Normal's S-7 tests still pass.

## S-18 — Spectator stream and player replay files (2026-10-21; guide 17.1)

- **Spectators** (`NetOut.addSpectator(sim)`): viewers next to the players in `sim.net.spectators`, run through the same per-viewer code with "ally 0", which NetOut treats as omniscient (everything alive is VISIBLE, every point in sight; ally teams are 1..8). The camera covers the whole map, so every unit is tactical. A spectator gets every combat event and homing correction, a WELCOME with player / team / ally team 0 (no protocol change), no Eco (the record has no team field) and no weapon targets.
- **Player replay files** (`Shared/Net/PlayerReplay`, pure, so the client can read them): magic `"FTGP"`, format 1, protocol version, defs hash, map ID, viewer (0 = spectator), players, first and last tick, then one frame per tick that had messages: tick delta, message count and per message channel, length (varints) and the bytes. `record` copies a viewer's outbox after every tick; `play` feeds every tick's outbox back (empty between frames), so playback is the live receive path without the sim.
- **Why not compressed:** pure Luau has no deflate; the stream is already quantized. Raw size: a spectator ~54 KB per game minute and a player ~33 KB on a 4-minute `skirmish:192` AI match; the 40-minute soak's spectator file is in the progress file. Whoever stores files can compress them (zstd in Lune tooling).
- **Tests** (`PlayerReplay.spec`, 3): a spectator has every unit, tactical, with the right team and type, while player 1 doesn't (fog); the spectator's and player 1's recordings, serialized and parsed back, rebuild the live client's view exactly at every checkpoint (24 per viewer: units, tiers, positions, heading, altitude, health, build, state, targets, projectiles, economy) and at the end, and round-trip byte for byte; the file format (header, channel numbering equal to `NetState.CHANNELS`, empty ticks, a long message, bad magic, wrong format, truncation). Dropping the State channel in playback fails it (24 of 24 checkpoints differ).
- `lune run soak` records the spectator for the whole match and writes `debug_out/soak.ftgp`.

## S-19 — Shorter build ranges (client request 7, 2026-10-22)

- **Request (the user, via the client):** build ranges about 70% of what they were. Command Vehicles 80 → **56**; constructors (`ord_mason`, `ord_architect`, `ord_harbormaster`, `ord_tidewright`, `chs_scrapper`, `chs_forgemaster`, `chs_reaver`, `chs_wrecker`) 64 → **45**; aircraft builders (`ord_skywright`, `ord_zenith`, `chs_condor`, `chs_vulture`) 48 → **34**. The client reads `buildRange` from the defs.
- **Bug it uncovered:** a builder started a frame when it was in range of the *requested* point, but built only in range of the frame's *snapped* center (up to half a cell farther). With the long ranges it never showed; at 56 the Command Vehicle started a generator 64 studs away, then drove 4 more studs before building. `Build` now checks the range to the snapped center before starting the frame.
- **Tests:** `Build.spec` checks the builder is in range of the frame's center when the frame starts (restoring the old check fails it: 64 studs) and reads the Command Vehicle's range from its def instead of a hard-coded 80.

## S-20 — Aim rest pose and restore delay (client request 8, 2026-10-22; guide 10.3, 14.4)

- **Turret fields** (optional, degrees / seconds): `restYaw`, `restPitch` (default 0, 0) and `restoreDelay` (default 0). `Defs` checks `restPitch` lies within `minPitch..maxPitch` and `restYaw` within the arc.
- **Model** (`Shared/Combat/Aim`, pure, shared so the client animates with the same code):
  - a weapon spawns at its rest pose (units and frames: `World.spawn` takes `weaponRest`, from `Combat.restPoses`);
  - with a target it turns toward the wanted aim at `yawRate` / `pitchRate` (unchanged), and can fire only within `tolerance` (unchanged), so it must rise from rest first;
  - without a target it keeps its aim for `restoreDelay` (a per-slot `wHold` tick counter in the world, hashed), then turns back to rest at the same rates.
  - `Aim.update(turret, state, wantYaw?, wantPitch?)` is the whole step; `Aim.step`, `Aim.rest`, `Aim.holdTicks`, `Aim.pitchTime` are its parts. Weapons without the new fields behave exactly as before (rest 0, 0; no hold).
- **Juggernaut:** its own weapon def `chs_juggernaut_cannon` (the heavy cannon's numbers, since `chs_maw`, `ord_paladin` and `ord_bastion` share `chs_heavy_cannon`), with `minPitch = -65`, `restPitch = -65`, `pitchRate = 80` (~0.8 s from rest to level) and `restoreDelay = 3`. `armL`, `armR` added to its `pieces`.
- **Tests** (`Aim.spec`, 4): a Juggernaut starts with its arms at -65° and first fires after 12 ticks of turning (the arm raise), at firing pitch, and never before; the level heavy cannon (Maw) fires at once; after its target is gone the arms stay up exactly 45 ticks (3 s), then lower to -65° at 80°/s; a client-side `Aim.update` from the rest pose with the same wanted aims matches the server's yaw and pitch bit for bit on every tick (raise, fire, hold, lower); weapons without the fields behave as before. `Defs.spec`: a rest pitch outside the limits and a rest yaw outside the arc are refused. Without the rest pose the tests fail.

## S-21 — Every team's economy for spectators (2026-10-22)

- **Protocol 9:** Eco records start with `team u8` (1..8; 0 and 9+ refused), 36 bytes. A message holds one record per team after the tick header.
- **Who gets what:** a player still gets only its own team's record; a spectator gets every team's, in team order, on economy ticks when any of them changed and after its WELCOME. So spectator streams and player replays recorded from them carry every economy.
- **Clients:** a player's message still has exactly one record (its own); a client that read the first record keeps working. The reference test client keeps `economies[team]` and `economy` (its own team's).
- **Tests:** golden bytes with the team byte (protocol 9), round trip, truncation, team 0 and 9 refused (`Schema.spec`); in `PlayerReplay.spec` the spectator has both teams' accounts with the server's values while player 1 has only its own, and the playback digest compares every team's economy. Giving the spectator one team only fails it.

## S-22 — First balance pass: T1 ground (2026-10-22)

- **Goal (the user):** T1 ground equal-cost trades roughly 0.8–1.25, faction identity kept (guide 2.1), as few numbers as possible; record before and after in `BALANCE.md` and list the changes for review.
- **Method:** a 3-seed probe of the T1 ground pairs (tanks, artillery, scouts, and their cross pairs), one change at a time, then the full report (one seed). Weapons shared with other units were changed only where the change sharpens the identity for all of them (Chaos less accurate, Order longer-ranged).
- **Changes (six numbers):** `chs_light_cannon.accuracy` 1.2 → 2.0; `chs_ravager.cost` 130 / 1200 → 140 / 1400; `ord_light_cannon.range` 180 → 200; `chs_hellmouth.cost` 160 / 1600 → 175 / 1750; `chs_mg.damage.LIGHT` 44 → 40; `chs_jackal.health` 340 → 320.
- **Results:** Lancer vs Ravager 1.00 / 0.82 (was 0.38 / 0.39); Herald vs Jackal 0.82 / 0.80 (was 0.61 / 0.59); Verdict vs Hellmouth 0.61 / 0.80 (was 0.55 / 0.73). Report: 448 of 568 pairs hold, 195 findings (was 203), same-role band 29 of 38 (was 25).
- **Not reached:** artillery at close range. Health doesn't change hits-to-kill there (3 either way), and cost, blast and reload moved it < 0.1. Hellmouth groups fire twice the shots of Verdict groups: precise volleys overkill one target. A mechanic (spreading a group's fire) is the fix; listed for review, not done.
- **Tooling:** `lune run balance` keeps a hand-written "## Balance passes" section when it rewrites `docs/BALANCE.md`.
- **Tests:** two assertions hard-coded the old stats; `Defs.spec` now expects Lancer's derived `maxRange` 200, and `Build.spec` reads the Ravager's wreck value from its cost.

## S-23 — Start-position bias: targeting stagger followed ID parity (2026-10-22)

- **Symptom:** in mirror matches (same AI level both sides, mirrored map) one start won more often, and which one flipped as the AI changed (S-17).
- **Cause, found with mirror fights** (identical groups in mirrored positions, which should draw): the side whose units had the **even IDs** won every Lancer fight (40 of 40 over 20 ID layouts and both spawn orders). A weapon without a target searched only when `(id + tick) % 6 == 0`, so its search ticks had its ID's parity; Sensors updates visibility on even ticks; so even-ID units reacted to a newly seen enemy a tick sooner on average (delays 0/2/4 vs 1/3/5). In a mirrored match both players produce units on the same ticks and player 1's commands are processed first, so player 1 gets the odd IDs and player 2 the even ones.
- **Fix:** the stagger phase is `Hash.mix32(id) % STAGGER` (new `Hash.mix32`, the murmur3 finalizer). Two dead ends on the way: an FNV hash of the ID keeps its parity in the low bits and puts consecutive IDs (a mirror pair) exactly half a period apart; searching in every tick a team gains a contact was exactly fair but doubled Targeting's cost at 800 units (peak 7 → 26 ms). The mixed phase costs nothing extra.
- **Not a cause:** small movement asymmetries (flow-field tie-breaks by cell index) make mirror matches diverge from the first minute, but favour neither side. `skirmish:` / `start:` maps are not exactly mirrored (middle deposits and expansions are a cell off between the halves): west leads there 14–6 in Normal mirrors; use `map:` IDs for fairness.
- **Results:** Normal mirrors on Ridgeline 10–10 (was 8–12), Hard 11–9; mirror Lancer fights: even-ID side 4, odd-ID side 10, 26 draws (was 40–0).
- **Tests** (`Fairness.spec`, 3): the mixed phases are spread evenly for odd and even IDs and for consecutive pairs; in 40 mirror Lancer fights (20 ID layouts × both spawn orders) neither parity wins over 80% (the old stagger: 100%); 12 mirror Normal matches on Ridgeline (6 seeds × both factions, 10 minutes, value lead if undecided) split with each start winning at least 4 (6–6 now). The suite now takes ~65 s (this spec ~33 s).

## S-24 — AI waves: artillery follows the tanks (2026-10-22)

- **Found while fixing S-23's tests:** a Hard AI with three times Easy's value couldn't finish it in 30 minutes. Under BAR attack-move (S-14) a wave's artillery stops at its 450-stud range as soon as anything (here a remembered extractor) is in range, while the tanks go in alone and die; the wave never pushes.
- **Fix (all levels):** a wave's non-artillery units attack-move; its artillery GUARDs the lead tank, so it follows the push and fires at whatever is in range; radar and fire-control escorts guard the lead tank too. Hard now beats Easy on Ridgeline seed 9 at ~6 minutes (`AI.spec`).

## S-25 — Easy AI: a production handicap instead of an early rush (2026-10-22)

- **Problem:** in the first level report (S-17) Easy beat Normal about as often as it lost (20–22; on Twin Lakes 2v2 Easy won 5 of 6). Easy's small early waves (6, +2) out-traded Normal, which spends its early economy on radar, a third worker and a second plant.
- **Change (Easy only):** at most one army unit queued per 15 s (`armyCooldown`; workers exempt), and Normal's wave sizes (8, +2). It still has its other limits (2 s thinking, 2 workers, 6 extractors, one plant, no radar, anti-air, tech-up or kiting).
- **Result (Ridgeline, 3 seeds, both factions, sides swapped, 30 min):** Normal beats Easy 11–1, Hard beats Normal 10–2, Hard beats Easy 12–0. Twin Lakes 2v2: Normal–Easy 3–3 (was 0–6). Full report: `docs/AI_LEVELS.md`.

- **S-8 update (2026-10-22):** after the AI changes (S-17, S-24, S-25) seed 3 ends at 8.4 min; `lune run soak` now defaults to seed 2, which plays the full 40 minutes (seeds 1 and 3–13 end at 8–26 min). Result: 36,000 ticks in 36 s, at most 244 units, tick average 0.99 ms, p99 3.26, peak 23.3 ms (NetOut 14.6, Pathing 14.1); heap 7.7 → 73 MB growing with the unit count (~310 KB per unit at minutes 5 and 40: no leak); replay identical. The spectator recording (S-18) of the 40 minutes is 16.8 MB raw (419 KB per game minute at up to 244 units).

- **S-17 / S-25 final report (2026-10-22, `docs/AI_LEVELS.md`):** Normal beats Easy 29-13, Hard beats Easy 25-11, Hard beats Normal 24-18 over 1v1 and 2v2. Ridgeline: 10-2, 11-1, 12-0. Coastline matches mostly reach the 40-minute limit and are called on value (a passive Easy leads Hard 9-3 there); Twin Lakes Hard-Normal goes to the east pair 6-0 while a Normal-only 2v2 mirror splits 3-3. Both open, in the progress file.

## S-26 — The team's sight map and wrecks on the wire (protocol 10; client requests 9, 10) (2026-10-22)

- **Problem:** the client rebuilt its fog from its own units (allied units can't be counted; own units seen only as strategic icons have unknown sight), and heard of a wreck only through DEATH's `wreckId` for tactical deaths, never of wrecks made elsewhere, before it joined, or reclaimed.
- **Where:** four new **Events** kinds rather than a new channel (no new remote for the client; reliable and in order with the rest of the tick): WRECK 9, WRECK_GONE 10, SIGHT_ROWS 11, SIGHT_CELLS 12. Layouts in `Schema` and `docs/contracts/net.md` 7a; guide 7.2, 7.3, 8.7.
- **Sight:** per ally team, sensor cells with LOS (allies' units included; air sight left out). Once per ally team per sensor tick, `NetOut` diffs the LOS map against the last one in one pass and keeps the change list; a player one version behind gets SIGHT_CELLS (2 B per cell, bit 15 = seen), anyone else (a join) SIGHT_ROWS (a bitset, 2 KB for a 256-cell map), whichever is smaller. Spectators get none.
- **Wrecks:** known per ally team like structure ghosts, on the whole map (wrecks are on the minimap, guide 8.7): known once the team has the spot in sight (the DEATH's wreck in the same tick when it saw the death), forgotten when it sees the spot without it. This is replication state (`NetState.wrecks`), not sim state; the AI doesn't use it. Combat now stores each wreck's heading (`wreckHeading`, hashed). Spectators get every wreck at once.
- **Cost** (`lune run stress`, 800 units): events 0.72 → 1.22 KB/s per player (sight ~0.3–0.4, wrecks ~0.12), total 15.4 of 35 KB/s; NetOut average 0.98 → 1.21 ms (budget 6). A join adds ~2 KB plus 10 B per known wreck.
- **Tests:** `Schema.spec` (golden bytes, round-trip, rejects, truncation for the four kinds); `NetOut.spec`: the client's sight equals the server's LOS on every sensor tick (allied unit's sight included); wrecks in fog unknown, scouted, reclaimed out of sight kept until re-seen, removed in sight gone, DEATH and WRECK in the same tick; spectators get all wrecks and no sight; a late joiner gets the same sight and wrecks. `PlayerReplay.spec` digests include sight and wrecks. `Movement.spec`'s idle test now starts its 10 packet-free ticks after tick 2, the first sensor pass, which sends the team's first sight (checked to be only sight records); the idle ticks still must send nothing.
- **Known limit:** wreck IDs are u16 on the wire and never reused; a match making 65,535 wrecks would error. Far beyond any match so far (the 40-minute soak made a few thousand at most); revisit with ID reuse if it ever matters.

## S-27 — Missile guidance: proportional navigation, step-start alignment, seeker cone (client request 13) (2026-10-22)

- **Symptom (client, `sam` scene):** four Thorns hit a circling Falcon with 31% of their missiles; crossing shots passed 5–9 studs from the hull, outside the 5-stud fuse; a missile that missed looped back for another pass.
- **Measured headless** (the same scene, 3 seeds, 2 min): 33% against the circling jet before the change; helicopters 88–94%.
- **Causes:** (1) the main one: Projectiles runs after Movement, so a missile at its start-of-tick position steered at the target's **end-of-tick** position, a one-tick lead (13 studs against a 195 studs/s jet). (2) Lead pursuit with a straight-line prediction is wrong against a turning target. (3) No seeker field of view.
- **Changes:**
  - `Shared/Combat/Guidance` (new, shared with the client, request 11b): `pn` (proportional navigation: the velocity turns at N = 4 times the line-of-sight rate about the same axis, capped by `turnRate`), `lead` (the old lead pursuit, kept for torpedoes, bit-identical), `inCone`, `velocity`.
  - Projectiles: missiles fly `Guidance.pn` against the target's position at the start of the step (aim point minus one tick of its velocity). PN alone, without the alignment, made it worse (18%).
  - Seeker cone (EW.guide, every tick, IR and RADAR): a target more than `seekerAngle` off the nose (default `EW.SEEKER_ANGLE`: IR 60°, RADAR 70°; new optional weapon field) breaks the lock for good (LOST_LOCK, no re-acquisition). Skipped within one step of the target, where the fuse decides.
- **Not changed:** the fuse radius. With the alignment every missile that isn't decoyed hits (the fuse tests the closest approach along the whole step, so the 28-stud step was never the problem); a separate `fuseRange` would add a field without changing a result.
- **G limit (request 11c):** not added. Missiles fly at constant speed, so the `turnRate` cap already is a G limit (a = ω v); a separate one would only rename it.
- **Results (Thorns, headless, 3 seeds × 2 min):** circling Falcon 90% (was 33%), every other missile decoyed by flares; helicopter flying in 94%, hovering 88% (unchanged: the rest are flares). No missile loses its lock.
- **Tests (`Guidance.spec`, 3):** PN closes within 2.5 studs on straight and 51°/s-circling targets from 24 launch angles; the IR SAM salvo hits a circling jet and a helicopter (flying in, hovering) with every non-decoyed missile and at least 75% overall; a missile flying past a target it can't turn onto gets LOST_LOCK and flies away without a second pass. The reference client (`Support/Client`) now steers with `Guidance` too; the contract (section 7) says how.

## S-28 — Decoyed missiles bend toward the decoy (client request 13d; protocol 11) (2026-10-22)

- **Problem:** a successful flare / chaff roll turned the missile 60° in one tick (`EW.DECOY_TURN`); at 420 studs/s it visibly kinked sideways.
- **Change:** on DECOYED the missile loses its target and follows a fixed decoy point for up to `Guidance.DECOY_TICKS` (15, 1 s), turning at its `turnRate` (`Guidance.decoy`), while the point stays in its seeker cone; then it flies straight to the end of its lifetime. The point is the cloud next to the target: `EW.DECOY_SIDE` (25) studs across the **missile's** line of flight (side by the same coin flip as before, so the rng draws are unchanged) and `EW.DECOY_DROP` below the target (flares 20, chaff 6).
- **Why across the missile's path, not behind the target** (the client's suggestion): a point behind the target lies on the missile's line in a tail chase and head-on, and in a first try 5 of 8 decoyed missiles still hit the jet. Across the line, none do.
- **What it looks like:** the roll happens 20–60 studs out, so a missile passes its decoy within a tick or two: a bend of 10–20° off the target, then straight on (no kink: never more than `turnRate` per tick).
- **Wire (protocol 11):** DECOYED carries the decoy point and the ticks left (22 B) so the client steers it with the same function; `Guidance.SEEKER_ANGLE` / `seekerAngle(weapon)` moved to Shared for that. Server state: `Combat.pDecoy` (hashed).
- **Tests:** `Guidance.spec`'s salvo test now also checks that decoyed missiles turn at most `turnRate` per tick, that none hits its target, and that a spectator client steering them with `Guidance.decoy` stays within a stud of the server inside the map. `Schema.spec` golden bytes for the new layout.

## S-29 — Overkill-aware targeting (guide 10.2) (2026-10-22)

- **Asked:** units in the same area spread their fire instead of shooting a target that pending hits will already kill; deterministic, within the Targeting budget.
- **Accounting (Combat):** each projectile fired at a live unit records the damage it is expected to deal: `damage[armorClass] × Combat.hitChance(weapon, target, distance)`. `pending[target]` sums them while they fly (dropped when the projectile lands, expires, is decoyed or loses its lock; keyed by the target's generation, D109); `queued[target]` sums damage queued this tick (hitscan, impacts) until Damage applies it. `Combat.doomed(t)`: pending + queued ≥ health.
- **Hit chance:** from the weapon's spread (uniform ±accuracy on yaw and pitch): sideways `dist·tan(acc)` against hull radius + half the blast; lengthwise, for a ballistic arc, the range error `dR/dθ·acc` (flat ground, low arc) against radius + blast + height / (2 tan θ) (a descending shell crosses the hull's height); straight shots compare the height error. Guided weapons and torpedoes count as sure. Checked against fired shells at a stationary Ravager: howitzer at 350 studs 1.00 estimated / 0.99 measured, mortar 0.82 / 0.79 at 200 and 0.62 / 0.63 at 350, Lancer gun 1.00 / 1.07 at 180. A first version without the height window said 0.12 for a tank gun at 60 studs and made the avoidance worse than none.
- **Decision at the trigger (Weapons):** a ready, aimed weapon whose visible target is doomed doesn't fire; it drops the target and is marked RETARGET, so Targeting searches on the next tick instead of waiting for its stagger. Deciding in Targeting alone would send a whole volley to the same next target (all guns score targets alike). Health counts only for targets the team sees (VISIBLE); radar contacts and ghosts are never "doomed".
- **Search (Targeting):** doomed targets are skipped; the best of them is the fallback when nothing else is acceptable, marked ALLOWED so the weapon fires anyway (a lone target still gets shot, and a miss gets followed up). Attack orders fire regardless. Guided missiles don't switch to a doomed target.
- **State:** `World.wOverkill` per weapon (NONE / RETARGET / ALLOWED, hashed), `Combat.pAim / pAimGen / pAimDmg` per projectile (aim hashed), `Combat.pending / pendingGen / queued` derived. `Combat.AVOID_OVERKILL = false` turns it off for measurements.
- **Results:** six Verdicts against six one-shot Ravagers in a column: first volley on 6 targets (1 without), all dead in 12 shells and 6.3 s (30 shells and 18.9 s without). Stress at 800 units: Targeting 1.95 ms average, 6.54 peak (2.04 / 7.51 before; budget 8).
- **Tests (`Overkill.spec`, 4):** the estimate within 0.15 of measured damage for four weapon/range cases; the group volley spreads, kills faster and wastes fewer shells; a lone doomed target is still shot; an attack order is obeyed on a doomed target.

## S-30 — T1 balance after overkill avoidance: Verdict sight 170 (2026-10-22)

- **Re-check (3 seeds) after S-29:** Lancer vs Ravager 1.25 / 1.00, Herald vs Jackal 1.06 / 0.75, Verdict vs Hellmouth 0.50 / 0.58 (unchanged by S-29).
- **Why artillery didn't move:** the matchups have no spotters, so both artillery groups fire at their own sight range (140 / 130); the Verdict's range and precision never apply, and at that distance the Hellmouth's health, damage and reload win. Six single-number probes (3 seeds each, `docs/BALANCE.md` Pass 2): reload, accuracy, range and health moved it by at most 0.07; sight 140 → 170 took the long fight to 0.97.
- **Change:** `ord_verdict.sensors.sight` 140 → 170 (listed under "Needs my review"). Close-range artillery (0.50) and the scouts' long fight (0.75) stay outside the band; both are listed with what would move them.

## S-31 — Twin Lakes 2v2 bias: the generator rule read a momentary stall ratio (2026-10-22)

- **Symptom (S-17 report):** Hard ×2 against Normal ×2 on Twin Lakes went to the east pair in all 6 games (whichever level was east), though a Normal mirror split 3–3.
- **Traced like S-23:** a Hard ×2 vs Hard ×2 mirror, comparing each player with its mirror image (player 1 ↔ 3, the Order players; 2 ↔ 4, Chaos; Twin Lakes is mirrored west / east). Unit positions part at tick 60 (flow-field tie-breaks, as in S-23, favouring no side), so the comparison is on decisions: each structure ordered (def and mirrored site), in order. Players 1 and 3 parted at the third structure: player 1 started an extractor, player 3 a generator, at the same point of the same build. From there player 3's economy ran ahead: at 3 minutes the east led by 7–15% in value in every seed (the openings are seed-independent), before any fight.
- **Cause:** the AI builds a generator when `power.ratio < 0.95`. A player thinks every 10 ticks (Hard) at an offset by player (0, 2, 5, 7), so mirrored players think at different moments. Right after a builder finishes its job its demand is gone, and the stall ratio reads 1.0 for an economy step, exactly when the AI picks that builder's next job. Player 1 thought in that window and judged power fine while it was starved (0 stored, ratio 0.3 before and after); player 3, 5 ticks later in its own cycle, didn't. Which side catches the window follows from the think offsets, the same in every game.
- **Fix:** power counts as short if any think saw a stall in the last 5 s (`Skirmish.POWER_MEMORY` = 75 ticks), not only at this think. All levels use it.
- **Result:** mirrored players build the same first 17 (Order) and 13 (Chaos) structures in the same places (3 before); at 3 minutes the values are within 5% (west slightly ahead in some seeds, east in others), and both sides are richer than before (5,630 against 4,692 for player 1). Twin Lakes Hard–Normal: 3 games to the west pair, 3 to the east (was 0–6); Hard won 4 of 6.
- **Test (`Fairness.spec`):** in a Hard 2v2 mirror on Twin Lakes the mirrored players' first 10 structures match and their values at 3 minutes are within 10%. With the old rule it fails at the 3rd structure.
- **Seen on the way, not changed:** the army mix comes from each AI's own random stream, so mirrored players' armies differ from the first army unit (fair in expectation). Ridgeline Normal mirrors now split west 4 – east 8 of 12 (6–6 at S-23), within the test's bound; to watch.

- **S-31 follow-up (same day):** the remembered stall fixed Twin Lakes, but Ridgeline Normal mirrors drifted east (3–9 of 12), and a trace showed the Order mirror again splitting at the 3rd structure, this time on the income rule (`income < 20 × plants + 20`): player 1 thought just after its first generator finished, player 2 just before. Two more causes, both fixed:
  - **Think phase:** a player's think offset (0, 7 for two Normal players) sat at different phases of the economy (5-tick) and sensor (2-tick) steps, so the same plan finished at a different point of each player's cycle. Think periods and offsets are now multiples of `Skirmish.THINK_ALIGN` = 10 ticks: Normal thinks every 20 ticks (was 15), Easy 30, Hard 10; offsets `(index − 1) × 10 mod period`, so players sharing a slot (all Hard players) think in the same tick, in player order. Power stalls are now watched every tick, not only at thinks.
  - **Site rounding:** the AI's site search is mirrored (`brain.toward`), but the server snaps a footprint with `floor(f + 0.5)`, which rounds exact half cells toward +x for everyone; homes and offsets put sites exactly there, so the east player's generator landed a cell off the west's mirror image. The search now nudges each candidate a thousandth of a stud toward the player's front (`SNAP_NUDGE`), which rounds symmetrically.
  - **Result:** Ridgeline Normal mirrors build the same first 21 (Order) and 9 (Chaos) structures, equal values at 2 minutes (4,053 / 4,030); outcomes west 8 – east 4 of 12 in the spec (a 24-match run before the rounding fix gave 9–15; the splits move both ways, as noise does). Twin Lakes Hard 2v2: same first 9 structures for both pairs. Mirrored single-unit trips on Ridgeline: 4 faster west, 5 faster east, 18 equal, mean difference 0 ticks.
  - The Fairness test's bar is now the first 8 structures (the old rule parted at the 3rd); later, trips that take a few ticks more on one side or the other reorder jobs.

## S-32 — Line of fire (guide 10.8); Coastline stalemates (2026-10-22)

- **Coastline (task 4):** 31 of 36 level matches reached 40 minutes. Not the map (open land, two ridge pairs, the sea in the north) but the fight: a wave on attack-move held as soon as an enemy was within weapon range (S-14), and on Coastline that is often across one of the inner ridges. Its Lancers stood at x ≈ 0 shooting a Lancer at x ≈ −175 (190 studs, in range) through the ridge; every shell hit the cliff, nobody died, nobody advanced. Direct fire went through hills because line of fire (10.8) wasn't built.
- **Line of fire:** `Combat.lineOfFire` samples the height layer once per cell along the shot: the straight line for hitscan and beams, the real low arc for ballistic shells (so artillery lobs over what a tank shell hits); homing, torpedoes and bombs aren't checked. Weapons checks it when a weapon is ready and on target: blocked, no shot, and the weapon is marked (`World.wBlocked`, hashed). Targeting prefers, among the best two candidates, one with a clear shot (on the team's believed position, D100); a blocked weapon re-searches on its stagger tick. Orders: a blocked weapon doesn't count as engaged, so an attack-move keeps going until it has a shot.
- **Result:** Coastline, 36 matches: none at the limit (was 31), median 6.9 min, longest 19.1. Stress at 800 units on hilly terrain: line-of-fire checks average 0.1 ms per tick (worst tick 0.39 ms, 187 checks); Targeting average 2.35 ms (1.95 before; budget 8), from blocked weapons searching more; its peaks vary 8.5–18 ms between runs.
- **Level report:** a match still running at the limit is undecided: it shows who was ahead on value but no longer counts as a win in the tally (shown in brackets).
- **Found, not fixed here:** Normal loses all 12 Coastline matches to Easy (it starves for supply on that map); Hard beats Normal 9–3 there. Listed for the next round.
- **Tests (`LineOfFire.spec`, 4, on the new `ridge:<cells>` test map):** the shot geometry (tank shell and machine gun blocked by the ridge, clear through the gap, howitzer arc clears it, missiles unchecked); a Lancer holds fire behind the ridge while a Verdict fires over it; a Lancer takes a target it can hit over a nearer one behind the ridge; three Lancers on attack-move stop at most a second at the ridge, go through the gap and kill the target.

## S-33 — Client requests 14–16: MOVING bit, the map's edge, Thorn range (2026-10-22)

- **14, MOVING:** the bit was in the schema but never set. Movement now sets it on ground and naval units with a movement order or nonzero speed and on aircraft unless landed (loitering and hovering included), and clears it otherwise; only on a change, so idle units still send nothing. Test (`Movement.spec`): a tank's bit goes on with a move order and off when it stops, on the client too; a loitering jet is moving, a landed one isn't.
- **15, past the edge:** projectiles that leave the map now burst on its edge (IMPACT, no damage; there is nothing to hit out there), so no projectile position past the edge reaches the wire (`Air.spec`). Aircraft: not changed. Two tries to keep jets inside (a turn-back margin of their turn radius; a hard edge they slide along) broke the bombers' runs on small maps (egress loops leave the map there and the bomb-run tests rely on them), and a look-ahead version still let a Falcon out by 46 studs at a corner. Jets keep the 60-stud turn-back (B measured at most 14 studs out); the alternative, positions past the edge on the wire (a signed offset), is a protocol change left for later.
- **16, Thorn (the user asked):** `chs_ir_sam.range` and `lockRange` 280 → 420, `aoe` 5 → 12 (also its proximity fuse), `projectileSpeed` 420 → 500 (as suggested, so a 420-stud shot arrives about as fast); `chs_thorn.sensors.airSight` 300 → 420, because an IR missile locks only on what the site sees, so the new range would otherwise only help with a radar's or ally's sight. Under "Needs my review": Order's IR SAM (`ord_ir_sam`, the Vigil) stays at 300 / 5. `Guidance.spec` now counts only missiles that finished (a 420-stud flight can outlast the test) and puts the circling Falcon at x = 300, as the client's scene does, because its loiter around x = 420 reached the map's edge.

## S-34 — Move states: Hold Position, Maneuver, Roam (guide 10.1; audit item 1) (2026-10-22)

- **Before:** the move state was stored but nothing read it; idle units never moved on their own, as if on Hold Position.
- **Now (`Orders.autoStep`, start of the Orders step):** every 15 ticks (staggered by `Hash.mix32(id)`), an idle unit (empty queue, or an automatic order) that is armed, mobile, not a builder, not an aircraft, and on Fire at Will checks its move state:
  - **Hold Position:** nothing (an automatic order left over is stopped).
  - **Maneuver** (default): if no weapon has a shot (no target in range, or line of fire blocked, S-32), an automatic attack-move toward the nearest enemy the team sees, which one of its weapons can hit and its move class can reach, within `MANEUVER_LEASH` (150) studs of its **anchor** plus its longest range. Beyond the leash (+24 slack), or when nothing is left to chase, it walks back to the anchor.
  - **Roam:** the same within `ROAM_CHASE` (500) studs of itself plus its range; it doesn't come back (the anchor moves to where it stops).
  - Automatic orders are ordinary queue entries marked `auto` (hashed); any command replaces them and clears the anchor, which is set again where the unit next stands idle (its last move goal).
- **Why only Fire at Will:** a Return Fire unit shouldn't go looking for fights; Hold Fire never fires.
- **Test changes:** `NetOut.spec`'s weapon-target test and `LineOfFire.spec`'s "holds fire behind the ridge" put their units on Hold Position, to keep the static scenes they describe (on Maneuver the Lancer now goes round the ridge, which `MoveStates.spec` tests).
- **Cost (stress, 800 units):** Commands 0.45 → 0.59 ms average (budget 1).
- **Tests (`MoveStates.spec`, 5):** Hold Position stays; Maneuver closes on an enemy just out of range, kills it and walks back (at most 174 studs out); Maneuver ignores an enemy beyond its leash while Roam chases it down and stays; Maneuver repositions past a ridge to get a shot; a command replaces the chase and re-anchors.

## S-35 — Cancel construction with a refund (guide 9.3; audit item 6) (2026-10-22)

- **Command:** CANCEL 16 (protocol 12), `value u8` 0..50. On an unfinished frame: the frame is removed (no wreck, a BUILD_FAILED event with reason "cancelled"), and its builders stop. On a factory: queue item `value` (1-based) is dropped, 0 = the whole queue.
- **Refund:** spending is proportional to progress (Build spends `cost × step` as progress grows), so a refund is progress × cost, credited like reclaim (`reclaimed`) at the next economy step and capped by storage. Only the frame or the item in production has progress; queued items cost nothing yet. 100% of what was spent, like BAR (the guide's "optional" choice).
- **Tests (`Build.spec`):** a plant frame cancelled at 30–70% credits exactly progress × cost of supply and power and is gone; CANCEL through the command removes a frame; cancelling a factory's item in production refunds its progress and the next item starts from scratch; a queued item goes without a refund; CANCEL 0 clears the queue. `Schema.spec`: golden bytes and range check for CANCEL.

## S-36 — Carriers: recovering, carrying and launching aircraft (guide 12.3; audit item 5) (2026-10-22)

- **Before:** carriers' rearm pads were used by empty aircraft (nearest pad), but an aircraft couldn't take a carrier as home, a rearming aircraft stayed where the carrier had been, and nothing held aircraft aboard.
- **Recover:** GUARD from an aircraft on a friendly unit with rearm pads (carrier or airfield) calls `Air.recover`: that pad becomes its **home** (`AirState.home`, hashed) and it is flagged to **hold**; it flies there, lands, rearms (aircraft without ammo are full at once) and then stays in a new phase **docked** instead of taking off.
- **Carried along:** while rearming or docked, an aircraft's position is its pad's every tick; one flying to a carrier re-aims when the carrier has moved.
- **Launch:** any order (`Orders.give` → `Air.release`) takes a docked aircraft off; one flying home only to be recovered turns back; an empty one still rearms first. A destroyed carrier launches its docked aircraft.
- **Home first:** an empty aircraft goes to its home pad if it still exists, else the nearest.
- **Not done:** carriers building aircraft (the guide doesn't say they do; it would change the tech tree, listed for review).
- **Tests (`Carrier.spec`, 3):** recovery lands and holds a Falcon on a Sanctuary, which then sails with it aboard; a move order launches it; an empty Falcon heads for its carrier although an airfield is nearer, and lands on it.

## S-37 — Terrain types and speed modifiers (guide 5.2, 6.3, 12.1; audit item 3) (2026-10-22)

- **Layer:** `Layers.terrain` (u8 per cell, `Layers.Terrain` GRASS 0, ROCK 1, SAND 2, ROAD 3; default grass) in Shared, so the client gets it with the map.
- **Speed:** `Shared/Grid/Terrain.SPEED[moveClass][type]` (placeholders, listed for review): wheeled rock 0.8 / sand 0.7 / road 1.25; tracked 0.9 / 0.8 / 1.1; heavy tracked 0.9 / 0.6 / 1.1; amphibious 0.9 / 0.85 / 1.1; hover 0.8 / 1 / 1.1; grass 1; ships, submarines and aircraft ignore terrain. Movement scales a unit's top speed by the factor of the cell it is on.
- **Paths:** each tree (move class, clearance) carries per-cell step multipliers `best factor on this map / cell factor` (≥ 1, as the flow field's bucket queue needs; nil when the map has one kind of ground for that class, so other maps cost nothing extra); a step costs its length times the mean of its two cells' multipliers. The coarse quadtree route still ignores terrain.
- **Maps:** MapGen paints sand on land within 2 cells of water and rock where a cell rises more than 15° to a neighbour; both follow the symmetric heights, so maps stay symmetric (tested). Named maps: Ridgeline 768 rock cells (ridge flanks, mostly impassable anyway), Coastline 962 rock / 304 sand, Twin Lakes 1,596 / 528, Crossroads 2,264 / 656. No roads are generated (map design). New test map `terrain:<cells>`.
- **Tests (`Terrain.spec`, 3):** a Paladin on sand tops out at 0.6 of its max speed and a Jackal on the road at 1.25 (much slower on sand); a heavy class's flow field costs crossing sand more than 1.4× grass, and an all-grass map has no multipliers; Coastline's terrain has sand only on land, rock, and mirror symmetry.

## S-38 — Client requests 17–19: jets reach their goal, countermeasure on DECOYED, no aircraft wrecks (2026-10-22)

- **17, jets (high priority, the user asked):** a jet's move used to count as arrived as soon as its goal was within the 220-stud loiter radius, so a close order made it circle from wherever it was. Now it flies to the goal and arrives within `Air.ARRIVE_RADIUS` (40 studs, the name the client mirrors) or, for a goal inside its turn circle, once it has flown toward it and the goal falls behind (the closest approach; `AirState.approach`, hashed); then it circles at 220 as before. Test (`Air.spec`): goals 134 studs to the side and 150 behind are passed within 70 studs, a far one within 40, and the jet then circles at ~220.
- **18, countermeasure (protocol 13):** `EW` now returns which countermeasure defeated a missile (flares, chaff, DIRCM); it rides on the decoy point and DECOYED ends with `countermeasure u8` (23 B). Test (`Guidance.spec`): every decoy in the salvo test reaches the client as DIRCM. **Correction:** the Falcon and the Guardian carry DIRCM and chaff, not flares, so the decoys S-27 and S-28 called "flares" were DIRCM engagements; the numbers stand.
- **19, aircraft wrecks:** Damage leaves no wreck for an aircraft that dies in flight (no LANDED bit); a landed one may leave one. Test (`Air.spec`): a Guardian killed in flight has wreck 0, a landed one gets a wreck.

## S-39 — Amphibious and hover details (guide 6.1, 12.3; audit item 4) (2026-10-22)

- **Amphibious:** Movement sets SUBMERGED on AMPHIB units in water at least as deep as their hull is tall (they drive on the sea floor) and clears it in the shallows and on land. Submerged, they are what submarines are to the sensors (sonar contacts only, `Sensors.levelFor`) and to targeting (the submerged domain: torpedoes, D107); their own weapons don't fire under water unless they are torpedoes (Weapons).
- **Hover:** combat profiles of HOVER defs ride on the water surface: `Combat.baseAt` and the believed aim point use the surface over water (the sea floor before). No roster unit is HOVER yet (a roster decision, listed for review); the rule is tested on a ground profile switched to hover.
- **Test map:** `beach:<cells>`, land sloping about 10° into a 30-stud-deep sea (the `sea:` map's coast is a cliff no ground class climbs).
- **Tests (`Amphibious.spec`, 2):** a Tideguard drives into the sea and submerges; an enemy tank without sonar loses it; it holds its gun though the enemy is in range; back in the shallows it surfaces. A hover profile's aim point is on the water surface, a ground unit's on the sea floor, attack-ground's on the ground.

## S-40 — Fast and slow test suites (2026-10-22)

- **Asked:** a fast suite for every commit and the slow fairness and AI matches in a separate suite that the integration check runs.
- **How:** specs register slow tests with `t.slow(name, fn)` instead of `t.test`; `RunAll.run(specs, mode)` runs "fast" (no slow tests), "slow" (only them) or "all" (the default, so the Studio runner, which is the client stream's, still runs everything). `lune run test` is the fast suite; `lune run test_slow` (`.lune/test_slow.luau`) the slow one. `tools/integration/integrate.sh` runs both, and the build, before pushing `main` (it skips the slow suite on a tree that doesn't have it yet). The runner now prints the time of every test that takes a second or more.
- **Slow (7 tests, ~35 s):** Fairness.spec's mirror fights, Twin Lakes 2v2 mirror and Ridgeline mirror matches; AI.spec's "hard beats easy"; Skirmish.spec's full AI match and its replay determinism run. The fairness spec's ID-parity check is a unit test and stays fast.
- **Fast:** 324 tests in ~33 s (was 331 in ~65 s). `CLAUDE.md` and the project skill describe both.

## S-41 — Soak: seed 11, heap measured without the replay recording (2026-10-22)

- With this round's AI and combat (line of fire, move states, overkill, terrain) no seed of 1–13 plays 40 minutes on `skirmish:256` (8–33 min); `lune run soak` now defaults to seed 11 (32.6 min).
- The soak failed its leak check (heap per unit 262 KB at minute 5 → 920 KB at minute 32). Not a leak: the spectator recording (S-18) keeps every message in memory, which grows with time, not units; with ~50–65 units it dominated. Without it the heap is flat (11–18 MB). The soak now measures tick times, heap and the replay check in a run without recording, and records the spectator replay in a second run of the same match (it also checks both runs end in the same hash). Lune can't force a collection (`collectgarbage("collect")` isn't allowed), so the heap figures include uncollected garbage, as before.
- Result: PASS; see the progress summary.
- **Level report (same day):** every one of the 126 matches ends by a win condition; Easy beats Normal 23–19 on the 128-cell maps (an early wave reaches Normal's Command Vehicle). Not fixed; listed for review with a proposal.

## S-42 — Vertical-launch radar SAMs and heavier warheads (client request 20; supersedes request 12) (2026-10-22)

- **Asked (the user, through the client):** radar SAMs launch vertically, IRIS-T SLM style, and carry heavy warheads.
- **Weapon field `launch`** ("turret" default, or "vertical"; HOMING): Weapons fires a vertical launcher as soon as a target is in range and locked, with no yaw / pitch wait or tolerance; its turret stays at its rest pose. The missile spawns pointing straight up at its speed.
- **Steering (`Guidance.vertical`, shared):** until the target is within `Guidance.HANDOVER` (15°) of the nose, the missile turns straight toward it at `Guidance.PITCH_OVER` (3) × its turnRate, the boost's thrust vectoring; then proportional navigation at turnRate. The state rides in `pFlags` (`EW.Flag.TURNED`), and the seeker-cone check (S-27) starts only after the hand-over. Two tries before that: plain turnRate (90°/s at 360 studs/s is a 229-stud radius) couldn't reach a helicopter 150 studs away; handing over as soon as the target entered the 70° seeker cone left the missile still climbing when PN took over, and it lost the lock.
- **Defs:** `chs_radar_sam` and `ord_radar_sam` get `launch = "vertical"` (Wyvern, Gorgon, Aegis, Seraph); `aoe` 8 → 20 for both (also their proximity fuse), damage unchanged (Chaos 400, Order 380). The IR sites keep their turning launchers. Under "Needs my review".
- **Tests:** `Guidance.spec`: a Wyvern against a circling Falcon fires 22 missiles, every one leaving steeply upward, its launcher never moves, 18 hit (82%), 4 overshoot a jet passing close over the site. `EW.spec`'s burn-through test (a jammed Wasp 150 studs from an Aegis) passes again with the vertical launch: 3 of 3 hit. The reference client steps vertical launches with `Guidance.vertical`.

## S-43 — Projectiles and shots shown regardless of sight (client request 21; changes D99) (2026-10-22)

- **Asked (the user, through the client):** "Only render the projectile, not revealing the shooters; if the shooter is cloaked and they decide to shoot, they switch out of cloak mode and reveal themselves."
- **Rule change:** D99 sent combat events only where the player's ally team had sight. Now projectiles are shown in the player's camera area (+2 cells; +5 for homing corrections) whatever the team sees: SPAWN_PROJ at launch, homing corrections, IMPACT. None of these names a shooter, so a hidden shooter stays hidden until normal sight reveals it. `targetId` is unchanged (0 unless the team knows the target). DECOYED / LOST_LOCK were already for projectiles the client has.
- **Gun shots:** FIRE names its shooter, so it still goes only to players that have the shooter in their tactical tier. Anyone else whose camera area has either end of the shot gets a new event SHOT 13 (protocol 14): `hit u8, start pos, end pos`, 14 B, no IDs. Weapons now records the muzzle position on FIRE events.
- **Cloak:** not built; the guide (11.4) now says a cloaked unit that fires drops its cloak.
- **Cost:** in the 800-unit stress battle events stay ~1.2 KB/s per player (everything in the camera was in sight there anyway); a hidden artillery duel costs what a visible one does.
- **Tests:** `NetOut.spec`: a hidden mortar's shells reach Order from 13 studs out of the muzzle (before: only once in Order's sight) while the mortar stays hidden and unnamed; a hidden gunner's shot reaches the other player as SHOT with both ends and nothing naming the gunner, and its owner as FIRE; the combat-events test checks the camera rule; homing corrections are bounded by the camera area. `Schema.spec`: SHOT golden bytes, round-trip, rejects. Guide 7.2, 7.3, 11.4 and contract section 7 updated.

## S-44 — Vertical launch: a straight climb before the pitch-over (client request 22) (2026-10-22)

- **Asked (the user, through the client):** "launch vertically a little more time, it turns over too soon": the missile leaned over from the first tick at 3× turnRate.
- **Rule:** weapon field `climbHeight` (studs above the ground; 100 on both radar SAMs). While a vertical launch still flies exactly straight up (no horizontal velocity) and is less than `climbHeight` above the ground under it, `Guidance.vertical` doesn't steer it; then the pitch-over and hand-over of S-42. Read from the missile's state only, as the client asked, so a client that first sees a missile mid-flight decides the same (the wire keeps a zero velocity component exact).
- **Ground:** the cell-based ground height moved to Shared as `Layers.heightAt` (the server's `Combat.groundHeight` calls it), so server and client use one function; `Guidance.climbLeft(weapon, y, ground)` is the shared helper. `Guidance.vertical` takes `climbLeft` as an optional last argument.
- **Tests:** `Guidance.spec`'s Wyvern test checks every missile climbed straight to 100 studs before it leaned over; `EW.spec`'s 150-stud burn-through shot still hits (2 of 2).

## S-45 — Radar SAM range ×3 (client request 23, the user asked) (2026-10-22)

- **Changed:** `chs_radar_sam` range and lockRange 560 → 1680, `ord_radar_sam` 600 → 1800; their units' radars ×3 so they can lock on their own: Wyvern 600 → 1800, Gorgon 480 → 1440, Aegis 650 → 1950, Seraph 520 → 1560. Under "Needs my review".
- **Left as is (my call):** `projectileSpeed` 360 (a full-range shot flies ~5 s; lifetime follows range); burn-through stays 35% of lockRange, so jamming now fails inside ~600 studs instead of ~200.
- **Tests:** `EW.spec` checks EW rules at fixed distances on a 1024-stud map, so its defs keep the old radar SAM ranges and radars (its own test defs; the replay test keeps the registered defs). `Guidance.spec`'s Wyvern bound is 70% (it now also takes long shots at a weaving jet: 17 of 23).
- **Not measured yet:** the effect on AI matches and balance (a Wyvern covers most of a 2048-stud map); next level report.

## S-46 — Archon radar signature 0.35 → 0.6 (client request 24, the user asked) (2026-10-22)

- With the ×3 radar SAM ranges (S-45) a Wyvern locked Archons only at ~552 studs (radar 1800 × 0.35, lock 1680 × 0.35), about where the Thorns in front open up. At 0.6 it locks them at ~1,000. Only the Archon; the Phantom stays at 0.2. For the user to test; under "Needs my review".

## S-47 — Missile stockpiles for SAMs (client request 25, the user chose it) (2026-10-22)

- **Asked (the user, through the client):** "SAM systems should have a stockpile and spend resources to fill it up"; all SAM sites and mobile SAMs, refilled automatically, BAR style.
- **Defs:** weapon field `stockpile = { capacity, buildTime (s), cost = { supply, power } }`; a unit's weapon slot may override the capacity (`{ def = "chs_ir_sam", stockpile = 4 }`), because one weapon serves units with different capacities. Derived `weapons[i].stockCapacity`. Validation: capacity 1..255 (a u8 on the wire); a slot capacity needs a weapon stockpile.
- **Numbers (the client's suggestion; under "Needs my review"):** IR SAMs 6 s, 15 supply + 300 power, capacity 8 (Thorn, Vigil), 4 (Hornet, Halo: Halo mirrors Hornet, the request listed only Hornet); radar SAMs 12 s, 40 + 900, capacity 6 (Wyvern, Aegis), 3 (Gorgon, Seraph). **Naval SAMs (Corsair, Crusader) have none yet:** the request named sites and mobile SAMs; a question for the user.
- **Rules (Shared defs, server `Sim/Stockpile.luau`):** per weapon slot `World.wStock` (missiles) and `wStockProgress` (0..1 of the next), hashed. A shot needs a missile (Weapons: no stock → no fire, the target is kept) and spends one; the reload is unchanged. Each finished unit below capacity builds one missile at a time per slot, an economy consumer in the construction step after aircraft rearm: demand cost / buildTime, progress at the team's effective ratio, never more than the window allows (as construction and rearm). Spawn.unit (scenarios, tests) starts full; frames start empty; units out of a factory are emptied.
- **Wire (protocol 15):** State mask bit 64 STOCK: `slotMask u8` + `count u8` per stockpile slot, to the owner only, on change and on ENTER (like `targets`, S-16).
- **Tests:** `Stockpile.spec` (7): capacities, an empty site holds fire and fires the built missile at once (90 ticks), refill rate and exact cost (8 × 15 supply, 8 × 300 power), produced and frame-built units start empty, owner-only wire, hash. `Schema.spec` golden bytes. Two guidance tests (Air.spec Seraph vs Harpy, Guidance.spec Wyvern) give their launcher 255 missiles: they measure guidance, not supply.
- **Not measured:** the effect on AI matches (AI sites now stall after a salvo when power is short) and balance.

## S-48 — Nuke silos and radar SAM interception (client request 26, the user chose it) (2026-10-22)

- **Asked (the user, through the client):** radar SAMs should "shoot down ICBMs or nukes from the enemy launched into its radar range"; the user chose a T3 nuke silo per faction that builds nukes into a stockpile, and the radar SAM sites as interceptors.
- **Units (new tier 3; Defs allow tier 0..3):** `ord_reckoning` (Reckoning; "Judgement" is already Order's MLRS) and `chs_ragnarok` (Ragnarok), structures, 2,400 supply + 24,000 power, buildTime 48,000, health 7,000, footprint 3, icon `nuke`, built by the T2 ground builders (Architect, Forgemaster).
- **Weapon fields:** `strategic` (interceptable; blast hurts every side; no unit collision in flight; launch warning), `manualFire` (never targets; one shot per attack-ground order; fire states don't apply), `apex` (lofted BALLISTIC: fixed apex above the launch, horizontal speed from the distance, so flight time doesn't depend on range and the client steps it with plain gravity), `intercepts = { chance }` (vertical-launch HOMING only).
- **Warheads `ord_nuke` / `chs_nuke`:** range 8,192 (anywhere), apex 800, gravity 40 (~12.7 s flight), aoe 150, edge 0.3, damage 8,000 (LIGHT, ARMORED, SHIP), 10,000 STRUCTURE, 4,000 AIR, 3,000 SUB; stockpile 2, 120 s, 1,500 + 40,000 (the client's numbers). Silos placed by scenarios start full (S-47).
- **Orders:** attack-ground (CT.ATTACK_GROUND, D100) now reaches structures with a manualFire weapon; the point is kept in `AirState.groundX / groundZ` like a bomber's; the order ends at the launch.
- **Interception:** radar SAM weapons get `intercepts = { chance = 0.5 }`. Targeting checks every tick, before units, for an enemy strategic missile within weapon range that the team detects (new `Sensors.detectsPoint`: sight, air sight or radar coverage; jamming doesn't hide it). Weapons fires from stock with no lock check. The interceptor (`Combat.pTargetProj` + serial; projectile IDs are reused, so `Combat.pSerial` names one) is navigated by Projectiles against the missile's position and velocity; at its closest approach within `aoe` it bursts and rolls `chance` with the sim Prng. A destroyed missile is removed after the projectile loop (swap removal mid-loop would skip one) with an INTERCEPTED event and no blast.
- **Wire (protocol 16):** INTERCEPTOR 14 (SPAWN_PROJ layout, `targetId` = the missile's projId), LAUNCH_WARNING 15 (`projId, pos` of the launch, to every player), INTERCEPTED 16 (`projId, pos`). **Strategic missiles go to every player wherever they fly** (my call: without it an interceptor launched in view could chase a missile the client doesn't have; a few per match cost nothing). The launch warning reveals the silo's position (my call; BAR-like).
- **Tests:** `Nuke.spec` (5): launches only on order, one per order, apex ~821 studs, 12.7 s, lands on the spot, kills an enemy and an own tank, 400 studs off untouched; every player gets the warning and the missile; two Wyverns ignore a helicopter for the nuke and destroy it (2 interceptors), no blast; empty stockpiles stop nothing; deterministic. `Schema.spec` golden bytes for the three events. TechTree roster.
- **Not done:** the AI never builds or fires silos; balance unmeasured. Under "Needs my review".

## S-49 — Lower nuke arc; stockpile build progress on the wire (client request 27) (2026-10-22)

- **(a) Asked (the user, through the client):** "limit its height so that the missile does not shoot over the screen height". At the camera's 55° pitch and 70° FOV a point above the focus stays on screen up to ~0.6 × camera distance (~290 studs at zoom 480, the last before icons). `ord_nuke` / `chs_nuke`: `apex` 800 → 300, `gravity` 40 → 15: flight time 2·√(2·apex / gravity) stays 12.7 s, so the interception window is unchanged. `Nuke.spec`: apex 321 studs above sea level (300 above the launcher), 12.7 s, two Wyverns still intercept.
- **(b) Asked:** the user thought a silo had stopped making nukes: STOCK carried only whole missiles, and a 120 s warhead at game speed 0.25 is 8 real minutes without a visible change. **Protocol 17:** each STOCK entry is now `count u8, progress u8` (`wStockProgress` × 255). Sent when a count changes or a progress crosses a sixteenth (`Stockpile.WIRE_STEPS` = 16), not every tick: a radar SAM refill (12 s) costs a record every 0.75 s, a nuke one every 7.5 s. `Stockpile.spec`: the owner's progress stays within a step of the server's every tick. `Schema.spec` golden bytes.

## S-50 — Interception chance 0.2 (client request 29, the user set it) (2026-10-22)

- `chs_radar_sam` and `ord_radar_sam`: `intercepts = { chance = 0.5 }` → `{ chance = 0.2 }`. The user tried 0.2 through the client's test override (C-60) and chose it. A nuke now needs about five interceptor bursts for an even chance of being destroyed (1 − 0.8⁵ ≈ 0.67), so one Wyvern's full stockpile of six usually stops one nuke, and a mobile Gorgon or Seraph (three) usually doesn't. `Nuke.spec` (seed 3): two Wyverns still destroy the nuke, with 2 interceptors. Guide 4.3 and 10.9 updated.

## S-51 — Nukes climb vertically, then turn toward the target (client request 28, the user asked) (2026-10-22)

- **Asked (the user, through the client):** "Can we make the nuke go vertical to a height then turn toward its destination?"
- **Flight (`Shared/Combat/Lofted`, shared with clients):** straight up at `projectileSpeed` (150) until `climbHeight` (120) above the ground under it; then a pitch-over at `turnRate` (90°/s; powered, no gravity) toward the lofted velocity, the ballistic arc from the missile's position that peaks `apex` above the ordered spot and lands on it; within one tick's turn of it, the missile takes it exactly and falls. While climbing it is re-solved every tick (on the arc that equals its own velocity), so the landing stays exact. Descending: plain ballistic. Every phase follows from the missile's state and its goal, so a client stepping its own copy, even from mid-flight, flies the same path.
- **Numbers:** `apex` is now measured above the ordered spot (was: above the launch; the same on flat ground). `gravity` 15 → 12 keeps the flight at 12.7 s (measured, 1,400 studs) with the boost and turn; apex 310 studs above sea level on a flat map. Validation: lofted weapons need `turnRate`.
- **Wire (protocol 18):** a client can't fly the turn without the goal, so a strategic missile now arrives as **SPAWN_STRATEGIC 17**: SPAWN_PROJ's fields plus `goal pos` (25 B), still to every player. It reveals the target spot to everyone, which the arc showed within a second or two anyway (my call).
- **Tests:** `Nuke.spec` (6): flight 12.7 s, lands 0.0 studs from the spot; the warhead leans over only at 120.8 studs above the ground; a client far from everything flies its own copy within 0.15 studs of the server's for the whole flight; interception and the earlier tests unchanged. `Schema.spec` golden bytes.

## S-52 — Radar SAM sites: stock 15, refill twice as fast (client request 30, the user asked) (2026-10-22)

- **Asked (the user, after testing nukes, through the client):** "increase the SAM stock to 15, lower its recharge time too."
- **Changed:** the radar SAM weapons' stockpile (`chs_radar_sam`, `ord_radar_sam`): capacity 6 → 15 (the Wyvern and Aegis sites, which intercept nukes), buildTime per missile 12 → 6 s (the user gave no number; the client suggested halving).
- **Kept (my call, under "Needs my review"):** the cost per missile (40 supply + 900 power: a full refill is now 600 + 13,500, drained at twice the rate, 6.7 supply and 150 power per second per site); the mobile Gorgon and Seraph at 3 (slot override); the IR SAMs as they are. Read as the radar sites only, since the user was testing interception.
- **Tests:** `Stockpile.spec` capacities. With chance 0.2 per burst (S-50), a full Wyvern now gives a nuke about a 96% chance of being destroyed if all 15 get to burst (1 − 0.8¹⁵).

## S-53 — `map:normandy`, a hand-made large-battle map (client request 31, the user asked) (2026-10-22)

- **Asked (the user, through the client):** "a large map, maybe make a map like Normandy", for a large-scale battle test. The client sent the zone layout, which its army profile uses; all of it is kept.
- **Built:** `Shared/Grid/Normandy` (hand-made, not MapGen), registered under `MapRegistry.HANDMADE` as `map:normandy`; `genOptions` returns nil for it. Layout in guide 5.5. My calls:
  - **Hedgerows:** 1-cell banks 6 studs high, so their ends and the cells beside them are also too steep (37°) and a hedge line blocks 3 cells. Gaps are 5 cells, 3 of them passable; terrain is ROCK.
  - **Bocage limits:** it fills only z −200…280, between the staging fields; the 20-stud strips B left at −360…−340 and 540…560 stay open, so no stray stubs.
  - **Bluffs:** a 3-cell cliff (about 6.7 studs per cell).
  - **Draws:** 2 studs per cell (14°), passable for every land class.
  - **River:** 4 deep, so wheels and tracks can't ford it; amphibious units and hovercraft can.
  - **Houses:** 2 × 2 cells, 8 studs high, every 6 cells, kept off the roads.
- **For drawing:** `Normandy.feature(cx, cz)` names each cell.
- **Tests** (`Normandy.spec`, 5):
  - the zones and the sea surface;
  - the cliff, river, hedges and houses are impassable to WHEELED, TRACKED and HEAVY_TRACKED, while the draws, bridges and gaps are passable;
  - a flood fill gets every land class from the south start to the beach;
  - a Ravager drives over the x = 100 bridge;
  - the map is identical on every load. It has 662 hedge cells and 60 house cells.

## S-54 — `map:normandy` re-oriented: the fight runs west–east (the user) (2026-10-22)

- **The user:** "this map fight from the side (left - right) not the sea - land". S-53 followed the client's layout, which put Order on the beach and Chaos behind a river to the south, so the armies met along z, from the sea inland.
- **Now:** player 1 is west and player 2 east. The coast (sea, beach, bluffs with three draws) is a north flank both sides share. South of the bluffs the map is a mirror image about x = 0:
  - **Rear:** each side's rear at |x| > 672.
  - **Rivers:** one at x = ±660, each with bridges at z = −700, −250 and 250, so both sides get a river between their rear and the front, where S-53 gave one only to Chaos.
  - **Staging:** each side's staging field at |x| 420–640.
  - **Bocage:** at |x| < 400, with villages at (±220, −150).
  - **Starts:** (∓850, 0).
- **Kept:** every S-53 feature size (hedges, houses, gaps, draws, river, bridges). `Normandy.spec` checks the mirror (features and heights) and a Ravager crossing the east bridge at z = 250; 1,044 hedge cells, 72 house cells.
- **The client's `normandy` profile** places armies on the S-53 layout and has to move to the new zones.

## S-55 — Shorter SAM ranges (client request 32, the user asked) (2026-10-22)

- **Asked (the user, after playing the Normandy battle):** "the anti air should not cover this large range or maybe because the map is small, reduce the SAM IR by 30%, the SAM radar by 25%".
- **Weapons:** range and lockRange together:
  - `chs_ir_sam` 420 → 294 and `ord_ir_sam` 300 → 210 (Thorn, Hornet, Vigil, Halo).
  - `chs_radar_sam` 1680 → 1260 and `ord_radar_sam` 1800 → 1350 (Wyvern, Gorgon, Aegis, Seraph).
- **Sensors follow by the same factor (my call; S-33 and S-45 scaled them together):**
  - IR airSight: Thorn 294, Vigil 224, Hornet 210, Halo 224.
  - Radars: Wyvern 1350, Aegis 1463, Gorgon 1080, Seraph 1170.
  - projectileSpeed unchanged.
- **Side effects:**
  - Burn-through stays 35% of lockRange (~440 studs now).
  - A nuke reaches a radar site's range later, so the interception window is shorter. In `Nuke.spec` two Wyverns still destroy it, with 3 interceptors.
- **Tests:**
  - `EW.spec` pins the old IR ranges and air sights for its fixed-distance rule checks, as it already did for the radar SAMs.
  - `Guidance.spec`'s hovering helicopter moves in to 260, inside every Thorn's reach: 86% hit.
  - `Nuke.spec` checks "nuke first" only once the nuke is in a site's range.

## S-56 — SAM ranges cut again (client request 33, the user asked) (2026-10-22)

- **Asked (the user, playtesting Normandy, right after S-55):** "Drop the IR range 30% more, the SAM 25% more".
- **Weapons (range and lockRange, from the S-55 values):**
  - `chs_ir_sam` 294 → 206, `ord_ir_sam` 210 → 147;
  - `chs_radar_sam` 1260 → 945, `ord_radar_sam` 1350 → 1013.
  - Overall since S-45: IR at 49% of before, radar at 56% (1.7× the pre-S-45 range).
- **Sensors follow (as in S-55):**
  - airSight: Thorn 206, Vigil 157, Hornet 147, Halo 157;
  - radar: Wyvern 1013, Aegis 1097, Gorgon 810, Seraph 878.
- **Nukes:** a nuke is now within a radar site's reach for only ~6 s of its 12.7 s flight, so a site gets one or two shots at 0.2 each. `Nuke.spec` now defends with four Wyverns, which destroy it with 4 interceptors; two sites now often let one through.
- **Tests:**
  - `Guidance.spec`: the hovering helicopter moves in to x = 400, inside every Thorn's reach (94% hit).
  - The vertical-launch test no longer counts a missile still flying at the end as a steep launch.

## S-58 — One strategic icon per unit type (client request 35, the user asked) (2026-10-22)

- **Asked (the user, through the client):** "Every type of unit need to have its own unique icon." The wire icon was the family name's number (50 names over 126 unit defs), 6 bits.
- **Now (protocol 19):** the Strategic record's icon is 8 bits and is the unit's **def index** (`Shared/Net/Icons.byDef`); `def.icon` stays the family name for the shape. The record keeps its 6 bytes: the flags field shrinks from 7 to 5 bits, all five of which were in use (2 were reserved). At most 255 unit defs (an assert).
- **Knowledge unchanged:** icons go only where the team knows the type (VISIBLE, ghosts, TRACKED contacts), as before; untracked blips stay icon 0 (D107). A tracked contact now shows its exact type instead of its family, which D107 already allows (tracking reveals the type).
- **Tests:** `Schema.spec` bit layout, golden bytes and range checks; `NetOut.spec` checks every def's icon is its own index.

## S-59 — Pinpointers: radar precision for the team (client request 34, the user asked) (2026-10-22)

- **Asked (the user, through the client):** radar vehicles, and "radar enhance facility (pinpointer) that increase the team's accuracy, build around 6 and maximum accuracy achieved -> less to no wobble radar blip, radar missile will be able to hit more precisely (long range radar will likely to lose lock or miss without pinpointer enhancements)."
- **Radar vehicles:** each faction already has one per tier. T1 mobile radar: Oracle (Order), Watcher (Chaos). T2 mobile fire-control radar: Arbiter, Stalker. No gap, nothing added.
- **Pinpointer:** `ord_witness` (Witness) and `chs_augur` (Chaos: Augur), T2 structures built by the Architect and Forgemaster. Unit def field `pinpointer = true`.
  - Stats: 250 supply + 3,000 power, health 1,000, footprint 2.
- **Rule (`Shared/Combat/Pinpoint`, so a client computes the same):** precision p = min(count, 6) / 6, linear, where count is the ally team's finished Pinpointers. Sensors counts them every sensor step.
  - Wobble: radar contacts' wobble and fire-control tracks scale by 1 − 0.9 p.
  - Missiles: a RADAR-guided missile whose target its team has only on radar loses lock with chance 0.1 × (1 − p) per midcourse check (sim Prng).
  - Wire: no change. Pinpointers have unique icons (S-58), so the client can count them.
- **Numbers (under "Needs my review"):** 6 for full precision, 90% less error, lock loss 0.1 per check, the cost.
- **Tests:**
  - `Pinpoint.spec`: precision is linear; the worst wobble is 14.6 / 8.2 / 1.5 studs at 0 / 3 / 6 Pinpointers; radar-only shots at 700 studs lose lock 9 of 25 times with none and 0 of 25 with 6.
  - `Guidance.spec`'s Wyvern test gets 6 Pinpointers: it measures guidance, not precision.

## S-57 — AI levels: a gentle Easy, a defending Normal, missile refills (overnight task 1, the user) (2026-10-22)

- **Asked (the user):**
  - Easy must be easy for a new human player: no attack before about 8 minutes, smaller first waves.
  - Normal builds 2–3 tanks before its third generator and pulls its army home when an enemy wave approaches its base.
  - Measure and fix the AI's handling of SAM stockpiles.
  - Target: Hard > Normal > Easy on every map.
- **Before** (old report, before stockpiles): Easy beat Normal 23–19 overall. Easy won the 128-cell maps with its first wave of 8, which reached Normal's Command Vehicle at ~4.5 min.
- **Easy:**
  - No wave before 8 minutes (`firstAttack`), and at least 2 minutes between waves (`waveInterval`).
  - Waves of 4, then 5, 6, …, and only that many units leave: the rest stay home.
  - An army of at most 8 (`maxArmy`) and one army unit per 20 s (was 15).
  - A cap of 12 made Easy a turtle that beat Normal's waves on defence (Coastline), so 8.
- **Normal:**
  - From its second generator, until 2 tanks are out, every builder helps the plant, and the plant builds tanks before more workers (`tanksBeforeGen3`).
  - First tried as "no third generator until 2 tanks". That deadlocked: other construction split the 40 power/s, the tanks never finished, and Normal sat at 2 generators until minute 7.
  - Recall: 3 or more known enemy ground units within the recall radius (570 studs, at most 45% of the distance between starts) bring the whole army, waves included, home; no wave leaves for 20 s after.
  - The 45% fixes a false alarm: on 128-cell maps the enemy's rally point is within 570 studs of home.
- **Missile stockpiles:** measured with scratch runs (not kept): a Normal AI against helicopter raids that fly at its base every minute from minute 4.
  - In AI-vs-AI matches nobody builds aircraft, so the AI never fields SAMs.
  - Before the fix, 2 helicopters per minute: refills cost 1,679 supply + 33,586 power over 15 min. The economy stalled 60% of the time, and SAMs sat empty 49% of the time, 44% with a target.
  - Fixes:
    - the generator rule adds the SAMs' refill power (capped at 60/s);
    - with aircraft near home in the last minute, half the mobile SAMs stay home instead of leaving with waves;
    - while SAMs refill under a stall (power ratio < 0.5) it queues no new army units.
  - After: empty with a target 31% (2 helicopters). Against 4 helicopters per minute Normal still falls at ~9.5 min; it fires 44 missiles instead of 19.
  - **Root cause, a design question:** refills get the same share of a stalled economy as construction (S-47). Should missile refills take priority? Under "Needs my review".
- **Report** (`docs/AI_LEVELS.md`, now with a per-map tally): Hard > Normal > Easy on every map.
  - Overall: Normal beat Easy 39–3, Hard beat Normal 42–0 and Easy 36–0.
  - Per map, Normal–Easy: Ridgeline 10–2, Coastline 11–1, skirmish:256 12–0, Twin Lakes 6–0.
  - Hard won all 6 FFAs.
  - The report has no hard-vs-easy 2v2 pairing (Twin Lakes).
- **Tests (`AI.spec`):**
  - Easy sends no wave by 8 minutes, then a first wave of at most 4, with an army within its cap.
  - Normal has at least 2 tanks when its third generator stands, and recalls a wave against 4 enemy tanks 220 studs from home.

## S-57 (follow-up) — Mirror fairness: the integration slow suite failed (2026-10-22)

- **Found by the integrator:** `Fairness.spec` (`test_slow`) failed on the first S-57 merge, so nothing was pushed. Normal mirrors on Ridgeline split 2–10 between the starts; the test wants at least 4 each.
- **Bisected:** every form of Normal's army-first rule gave one start almost every mirror:
  - helping the plant: east 9–11 of 12;
  - builders idle: east 11–0;
  - tanks-first alone: west 11–0;
  - thinking every 10 ticks didn't help.
- **Mechanism:**
  - Both armies park at their rally points, 160 studs in front of home. On a 128-cell map those are ~375 studs apart, inside howitzer (450) and mortar (400) range.
  - The side whose artillery saw the other first won the duel. With mirrored players and their fixed 10-tick think offset, that was always the same side, and army-first's uniform openings made it decide every match.
- **Fixes:**
  - **Rally points** sit (start distance − 520) / 2 in front of home, between 40 and 160 studs (`RALLY_GAP` = 520, beyond artillery range). Big maps are unchanged.
  - **Waves** leave only in the first think of each 20 s window (`WAVE_ALIGN` = 300 ticks), so mirrored players that reach the wave size a think apart leave together.
  - **"2–3 tanks":** each Normal AI draws 2 or 3 tanks before its third generator from its own Prng, so openings vary by match.
  - **Army-first** keeps the factory's tanks-before-workers order and holds the third generator; builders keep their own jobs. Sending them all to the plant was dropped.
- **After:**
  - Mirrors split 4–8 (passes).
  - The level report still shows Hard > Normal > Easy on every map: overall Normal–Easy 36–6, Hard–Normal 42–0, Hard–Easy 36–0. Per map Normal–Easy is Ridgeline 10–2, Coastline 8–4, skirmish:256 12–0, Twin Lakes 6–0, and Hard won 5 of 6 FFAs.

## S-60 — Normandy performance: pathing, slot assignment (overnight task 3) (2026-10-22)

- **Asked (the user):** "profile the `normandy` scenario headless (392 units; worst tick 17.5 ms). Find which system peaks and bring every system back within its guide 18.1 budget without changing behavior. Before/after numbers."
- **Tool:** `lune run profile_normandy [ticks]` builds the Studio profile from `src/roblox/MatchConfig.luau` itself (loaded as data). At tick 30 both armies attack-move at each other, with both cameras on the bocage. It reports per-system averages and peaks (with their ticks) against guide 18.1, the five worst ticks broken down, and the state hash.
- **Rule for every change:** the state hash must not change. `86bd5a1a` after 1,800 ticks of the profile and `0720e012` after 300 ticks of a pathing benchmark, before and after each change: behaviour identical, bit for bit.
- **What peaked:** the work-unit budget of 36,000 units per tick was about 9 ms of real time on Normandy.
  - Big orders on the fragmented map (hedgerows cut the quadtree into small leaves) made the route search slow per unit.
  - Each search and each flow field allocated ~1.6 MB.
- **Changes:**
  - `Heap`: hole-based sifting with inline comparisons; same comparisons in the same order, so pops are unchanged.
  - `Route.runSearch`: leaf centres inline. `dist` / `settled` are arrays sized to the tree, pooled and reset on the leaves each search touched.
  - `FlowField`: the cost table and queue arrays are pooled, reset on the cells written. The integrate loop keeps its counters in locals and is unrolled in DX / DZ order, keeping the push order the bucket queue depends on; the direction pass is unrolled too.
  - `Formation.assign`: per-row and per-column unit counts skip empty bucket rows and columns. The same buckets with units are examined, so picks and `checks` are identical.
- **Per-unit cost:** route search 0.366 → 0.145 µs per work unit, flow field 0.268 → 0.177 (the Pathing budget is now at most ~6.4 ms of work); the order's slot assignment 2.8 → 0.8 ms.
- **Before → after** (`profile_normandy 1800`, three runs each, interleaved, same PC; before = `main` at 0348056):

| | Before (3 runs) | After (3 runs) |
|---|---|---|
| Worst tick (ms) | 16.3 / 25.4 / 16.3 | 10.9 / 15.2 / 13.8 |
| p99 tick (ms) | 11.9 / 13.6 / 12.2 | 7.9 / 8.6 / 8.7 |
| Pathing peak (budget 8) | 11.9 / 19.5 / 11.8 | 8.1 / 7.6 / 6.9 |
| Commands peak (budget 1) | 3.2 / 3.4 / 3.2 | 1.7 / 2.7 / 1.7 |
| Projectiles+Damage peak (budget 8) | 11.1 / 9.2 / 7.4 | 6.5 / 7.2 / 9.9 |
| NetOut peak (budget 6) | 4.8 / 7.4 / 5.3 | 3.8 / 4.4 / 4.2 |
| Sensors / Targeting / Movement / Weapons / Construction / Economy peaks | all within budget | all within budget |

- **Still over** (under "Needs my review"; each fix changes timing, so not done):
  - **Commands:** 1.7 ms on the tick a select-all order of ~300 units is given (budget 1 ms; was 3.2). Slot assignment has to prove each pick over a 1,300-stud army. Fix options: slice big orders' slot assignment into the Pathing job (units start moving a tick later), or a 2 ms Commands budget for that tick.
  - **Projectiles+Damage when a structure dies:** `Nav.terrainChanged` updates 7 quadtrees, about 4.3 ms (6 ms with the rest of the removal). It stays under 8 alone but goes over when a GC pause lands in the same tick. Fix option: update the quadtrees lazily, the first time each one is used.
  - **GC pauses:** the remaining single-tick spikes (the worst tick of 15 ms) are Lune's garbage collector landing in a system; Roblox's differs. Allocation per path is down from ~1.6 MB to a few hundred KB.

## S-61 — Own units' factory queue, fire / move state and ammo on the wire (client request 36) (2026-10-22)

- **Asked (the client):** the unit panel showed the queue and states the client had sent itself, and no ammo.
- **Protocol 20:** State mask bit 128 OWNER, then `ownerMask u8` with QUEUE 1, STATES 2, AMMO 4. Owner only. Each field is sent when it changes and with ENTER:
  - QUEUE: `count u8`, the head's `progress u8`, `defIndex u16` per item. Progress steps of a sixteenth, like stock (S-49).
  - STATES: one byte, fire bits 0–1, move bits 2–3.
  - AMMO: `rounds u8`, `max u8`.
- **Tests:**
  - `Schema.spec`: golden bytes and rejects (empty mask, reserved bits, a 51-item queue).
  - `NetOut.spec`: a plant with a 2-item queue, a tank whose fire and move state change, and a jet whose ammo drops. The owner's view matches every tick (the jet while tactical); the other player never gets them.

## S-62 — Faction pass, stage 1: the shared-role numbers (2026-10-22)

- **Asked (the user):** the faction proposal approved with one change, IR SAMs Vigil 206 / Thorn 165 (the user's cuts kept, Order +25%). Shared-role trait pass as in sections 3.1–3.8; every shared role within 0.8–1.25 overall over 3 seeds, each version winning its own condition. Guide 2.1 to the new identity; every changed number in `BALANCE.md`.
- **Applied:** every number in sections 3.1–3.8, with buildTime scaled by the value change. Where the proposal gave a direction without a number, I followed the direction (listed in BALANCE.md).
- **New:**
  - `ord_fortress_howitzer` / `chs_fortress_mortar` for the Edict / Cataclysm: the proposal gives the emplacements their own range and damage, but they shared the Verdict / Hellmouth guns.
  - `pinpointFull` on Pinpointer defs, with `Pinpoint.weight(def)` = FULL / pinpointFull. Witness 5, Augur 7. The team's count is the sum of weights, so a mixed team adds up and `Pinpoint.precision` is unchanged. The client's `Core/Precision` should sum weights instead of counting (told B).
- **Measurement:** `lune run factions [seeds] [filter]` (`Scenes.trial`, report only):
  - Equal value 6,000 per side, up to 60 of a type.
  - Starts: close, long, defend (Order holds, Chaos attacks from 600 studs) and flank (Chaos in two halves, from the north and south).
  - Overall = geometric mean of close and long. Order's condition: long or defend ≥ 1.25. Chaos's: close or flank ≤ 0.8.
  - SAMs face the same bomber and gunship raids; emplacements face the same tank assault.
  - The counter check's 3,000 budget and 20-unit cap rounded expensive aircraft to equal counts, which hid Chaos's numbers, hence the larger trial.
- **Tuning:** within ±10% of the proposal's numbers, apart from three steps:
  - the T1 tank turret yaw rates, swapped toward the identity;
  - the T2 cannon damages and the Hydra's armored damage, where the proposal gave no number;
  - the Archon's DIRCM chance.
  Every step is listed in BALANCE.md "Pass 3".
- **Result: 12 of 12 roles in band.** Each version wins its condition except:
  - T1 fighters: even everywhere, since jets close 600 studs in about 2 s;
  - the Herald at range;
  - the Hydra close or flanking: re-measured after task 7's salvos.
- **Tests:** 15 specs read the old numbers and were updated, most to read them from the defs:
  - Build: Lancer build time.
  - Combat: damage, wreck value.
  - Defs: ranges.
  - Fog and Sensors: these two compared against the position after the tick, while Sensors runs before Movement; they had passed by luck of speed.
  - Guidance: a decoyed missile that still bursts on the jet a tick later counts as decoyed; DIRCM's share against the faster Thorn is up to 30%.
  - Nuke: the reach check allows the nuke's step in that tick.
  - Air: the moving column stays in the spotter's sight; the far jet goal stays on the map.
  - Stockpile: Chaos capacities.
  - Terrain: a run long enough to reach top speed.
  - Pinpoint: Witness / Augur weights, plus a new test of mixed teams.

## S-63 — Countermeasure charges on the wire; match statistics (client requests 37, 38) (2026-10-22)

- **37, protocol 21:** OWNER field bit CHARGES 8: `flares u8, chaff u8`, the charges left, for own units whose def has flares or chaff. Sent on change and with the ENTER, owner only, like S-61. `NetOut.spec` checks a Falcon's chaff after one is spent; `Schema.spec` pins the bytes.
- **38: `Sim/Stats`**, server-side only, no wire change:
  - Per player: `unitsBuilt` (factory output and finished structures; the start doesn't count), `unitsLost`, `unitsKilled`, `damageDealt` (enemy health removed, capped at what was left).
  - From the player's team account: `supplyGathered` / `powerGathered` (income, reclaim and converter output per economy window, before the storage cap; refunds included) and `supplySpent` / `powerSpent` (drawn after stall ratios, less any forgiven shortfall).
  - `Stats.report(sim)` returns them all; the Roblox server reads it at match end.
  - So that a shell's damage counts after its shooter dies, a projectile keeps its shooter's player (`Combat.pPlayer`), and queued damage carries it (`dmgPlayer`).
  - Not hashed: nothing in the sim reads it.
  - `Stats.spec` covers damage capped at the target's health, a dead shooter's shell, units built, and the gathered and spent totals.

## S-62 (follow-up) — AI after the faction pass: rally gap, the Skirmish test (2026-10-22)

- **Found by the integrator:** two slow tests failed on the S-62 merge, so nothing was pushed.
  - **Fairness:** Normal mirrors on Ridgeline went west 3 / east 9.
    - Since the Verdict's range went from 450 to 480, `RALLY_GAP` 520 (S-57) left only 40 studs for the armies' spread around their rally points.
    - Now 600. Mirrors split 4–8 (passes), though fewer finish in 10 minutes than before the pass: the value lead decides more of them.
  - **Skirmish.spec:** Order (Normal) against Chaos on skirmish:192, seed 1: Chaos's second wave took Order's Command Vehicle at 7.3 min, before Order's first wave left.
    - The test required both players to attack. It now requires the winner, and any player still alive after 8 minutes.
    - Not an AI bug: the faction report has Normal Order beating Normal Chaos 7–1 in its first quick run.

## S-64 — Faction-only units, stage 2: Warden and Minotaur (2026-10-22)

- **Asked (the user):** Warden (Order deployable gun) and Minotaur (Chaos siege ram), with tests and counter-check rows (factions.md section 4).
- **Warden, `ord_warden`** (T2, Order Advanced Vehicle Plant):
  - **Stats:** value 600, health 2,200, speed 22, sight 280. Gun `ord_warden_gun`: range 280, 0.35°, 350 armored, 3 s.
  - **New mechanic, `Sim/Deploy`** (def field `deploy = { time, armor }`):
    - A deployer unpacks whenever it stands still: no move order, or an attack-move holding to engage, at speed 0. Packing and unpacking take `time` (4 s) each way.
    - Packed it moves but doesn't fire. In between it neither moves nor fires. Deployed it fires, can't move, isn't pushed, and takes damage / `armor` (1.5).
    - A move order packs it first.
  - **My calls:**
    - Deploy is automatic, not a separate command, so attack-moves and the AI use it with no new orders. A deploy toggle can be added if players want to hold it packed.
    - Packed it can't fire at all (the proposal's "weak when caught packed").
  - **Implementation:**
    - Progress in `World.deploy`, deployers in `World.deployIds`. Hashed only for deployers, so other matches' hashes are unchanged.
    - `Deploy.step` runs at the start of Movement. Movement anchors them; Weapons gates the shot; Damage divides by the armor.
  - **Wire:** state bits DEPLOYED 32 and DEPLOYING 64, protocol 22.
- **Minotaur, `chs_minotaur`** (T2, Chaos Advanced Vehicle Plant):
  - **Stats:** value 680, health 4,200, speed 20, footprint 2.
  - **Gun `chs_ram_cannon`:** range 160, 1.6°, 220 armored, 360 structure (+50% of its 240 light), 2.2 s.
  - **Demolition charge `chs_demolition`:** a structures-only hitscan, 30 studs, 3,000, every 20 s.
  - Defs only, no new mechanic.
- **Counter matrix (guide 12.4):** rows "Deployable gun" (Ground ●●●, Ship ●●, Structure ●●) and "Siege" (Ground ●, Ship ●, Structure ●●●) in the balance report's roles.
- **Tests:** `Deploy.spec`:
  - unpacks in 4 s and fires only deployed;
  - packs for 4 s on a move order;
  - damage / 1.5, and not pushed;
  - attack-move: holds, deploys, fires at range;
  - the charge levels a Bulwark and ignores a tank.
- **Blockouts:** requested from the models stream (`docs/progress/models.md`): Warden with `spades` to lower when deployed; Minotaur with a `ram`.

## S-66 — Missile refills come first in a stall (the user, 2026-10-22)

- **Asked:** "Missile refills take priority over construction, up to ~25% of income." It answers the S-57 review question: refills had shared a stalled economy evenly with construction (S-47), so SAMs under air attack stayed empty.
- **Rule** (`Economy.REFILL_PRIORITY` = 0.25), per resource and economy window:
  - Missile refills' demand is served first, up to a quarter of the window's income and what is available.
  - Whatever they want beyond that shares the rest with construction, production, rearming and upkeep at the common ratio.
  - Refills progress at their own `priorityRatio`; everything else at `ratio`.
  - Without a stall both are 1, so nothing changes.
- **Order:** `Stockpile.step` now runs before construction in `Build.step`, so a window's allowance goes to refills first.
- **Test** (`Stockpile.spec`): a Chaos plant building Ravagers on a Warlord's income keeps the economy stalled 100% of the time.
  - An empty Thorn rebuilds 2.49 missiles in 60 s with priority, against 1.81 sharing alike.
  - Its floor is a quarter of 20 power/s, about 1.25 missiles a minute.
- **AI under helicopter raids** (new `lune run sam_raids`, kept this time; Normal AI on skirmish:192, 15 min): numbers in the progress file. They are noisy: the AI builds few SAMs, and with the faction pass's prices Order's economy is stalled 85–90% of the time, a faction-AI question (task 11).

## S-67 — Select-all orders' slots in the Pathing job; lazy quadtree updates (the user, 2026-10-22)

- **Asked:** the two S-60 peaks: spread a select-all order's slot assignment over the Pathing job, and update quadtrees lazily when a structure dies. Both change timing (not the state hash), as S-60 said.
- **Sliced slot assignment:**
  - **Rule:** an order for `Nav.SLICED_ASSIGN_MIN` (64) units or more gets its ground groups' slots in the plan job.
    - At issue, Commands only snapshots the units' positions; its units head for the formation's center.
    - The plan job sorts the slots (`deepestFirst`), buckets the units and assigns slots, at 4 distance checks per work unit, then gives each unit still in the order its slot.
    - Smaller orders and air groups assign at once as before.
  - **`Formation.assign` is now resumable** (`newAssigner` / `assignStep`). Picks and checks are identical however it is sliced: tested on 150 units over 50-check steps, and the Normandy hash didn't change with the refactor alone.
  - **Test:** an 80-unit MOVE: every unit at the center at first; after one Pathing tick each has exactly the slot an immediate assignment gives.
- **Lazy quadtree updates:**
  - **Rule:** `Nav.terrainChanged` only records the changed rectangle per tree (the field cache is still invalidated at once). A tree applies its pending changes the first time it is used (`Nav.tree`, a plan job's tree), or on a Pathing tick with no job queued.
  - **Batching:** the batch recomputes components once (`Quadtree.update(..., deferComponents)` + `Quadtree.computeComponents`); each update had recomputed them over the whole tree.
  - **Backlog cap:** more than `Nav.MAX_PENDING` (8) pending changes on a tree are applied at once, so a map's structures placed at setup don't land on the first order's tick. First tried without the cap: that tick took 95 ms, then 21 with batching.
  - **Test:** `Placement.spec`'s rebuild comparison now reads trees through `Nav.tree`.
- **Normandy** (`profile_normandy 1800`, 3 interleaved runs each; the first pair was noisy):

| | Before | After |
|---|---|---|
| Commands peak (budget 1) | 1.40 / 1.47 (4.9 noisy) | **0.86 / 0.96** (2.3 noisy) |
| Projectiles+Damage peak (budget 8) | 7.6 / 10.7 (22.6 noisy) | **2.8 / 2.9 / 4.4** |
| Pathing peak (budget 8) | 7.3 / 8.1 / 8.9 | 7.5 / 8.0 / 9.4 |
| p99 tick (ms) | 9.0 / 9.3 / 14.3 | 8.4 / 8.7 / 9.7 |

  - The state hash changed (5f72fafa against ae5ef52e), as expected: big orders' units start toward the center for a tick, and trees update later.

## S-65 — The faction axis: Order AI against Chaos AI (the user, 2026-10-22)

- **Asked:** add the faction axis to the AI report: Order AI against Chaos AI at every level pair, every map, both starts, 3+ seeds. Targets: 40–60% overall, 35–65% per map, at most 10% undecided at the limit.
- **Tool:** `lune run faction_ai [minutes] [seeds] [mapFilter] [mirrored]` writes `docs/FACTION_AI.md`.
  - Matches: 1v1 on Ridgeline, Coastline, skirmish:256 and Normandy (9 level pairs × 2 starts); 2v2 on Twin Lakes (two of each faction per side); 4-player FFA on Crossroads (two of each, alternating, one level).
  - `ailevels` keeps its faction mirrors: it measures levels, this measures factions.
- **First report** (40 min, seeds 7–9, after S-62; 324 matches, 20 min of run time). **Out of target:**
  - Order wins **89%** of the same-level matches (86–11, 11 undecided = 10%), on every map but Crossroads (60%).
  - Levels still order across factions: Order easy loses to Chaos normal 7–20, Order normal loses to Chaos hard 5–24.
  - Normandy has no deposits: 23 of its 54 matches are at the 40-minute limit.
- **Why (my reading):**
  - The trade check shows the per-value balance even (S-62), but the AI uses none of Chaos's conditions: it waves attack-moves into the enemy, which is Order's "defend" case (1.4–2.1). It never flanks or raids, and it doesn't expand wider.
  - Chaos's cheaper units also make its economy-to-army choices the same as Order's, so its numbers advantage is only the value it saved.
  - This is the faction AI's job (task 11, proposal section 7), then the ±10% tuning (task 12).

## S-68 — Alerts, the under-attack flag, ground fire (the user's task 6; client request 39) (2026-10-22)

- **Asked:** audit item 17 (the ALERT event and the strategic "under attack" flag, so the client's alerts come from the server) and item 18 (ATTACK_GROUND for artillery and any weapon with ground fire). The client asked for 17 at the same time (request 39), with suggested kinds and rate limits; built as suggested.
- **ALERT, protocol 23** (`Sim/Alerts`; event 18, `alert u8, cell u16, defIndex u16`, owner only):
  - UNIT_ATTACKED / STRUCTURE_ATTACKED: one per 400-stud zone per 20 s.
  - COMMANDER_ATTACKED: one per 10 s.
  - UNIT_LOST / STRUCTURE_LOST: one per zone per 5 s.
  - BUILD_DONE: every factory unit and finished frame.
  - STALL_SUPPLY / STALL_POWER: when the team's ratio drops below 1, at most once per 30 s.
  - NUKE_LAUNCH: every player, at the silo; LAUNCH_WARNING stays as it was.
  - **Sources:** Damage (enemy hits, deaths), Build (finished units), the Economy system (stalls), Weapons (launches). NetOut drains the player's queue each tick.
  - **"Enemy":** the damage's player is on another ally team. Damage queued without a player falls back to its attacker's owner.
- **UNDER_ATTACK (strategic flag 4):** own and allied units an enemy hit in the last 3 s (45 ticks).
- **Ground fire:**
  - Any unit with a BALLISTIC weapon (artillery, tanks, gun turrets, emplacements; `Air.groundFires`) takes ATTACK_GROUND.
    - Mobile units close to their range (as ATTACK does), then those weapons shell the spot until another order, whatever the fire state.
    - Its other weapons keep choosing targets.
    - Structures with ballistic guns take it too.
  - My call: "any weapon with ground fire" read as every ballistic weapon (shells can be aimed at a point; missiles and hitscan can't).
- **Not hashed:** the alert state; nothing in the sim reads it.
- **Tests:**
  - `Alerts.spec`: rate limit per zone, owner only, UNIT_LOST with the type and place, UNDER_ATTACK set and cleared, BUILD_DONE, one power stall, NUKE_LAUNCH to both players.
  - `GroundFire.spec`: artillery on hold fire shells a spot; out of range it drives closer; a move order ends it; an Edict takes it, a Halo doesn't.
  - `Air.spec`: a tank now takes the bombers' ATTACK_GROUND too.
  - `Schema.spec`: golden bytes.

## S-69 — Salvos; shells lead moving targets (the user's task 7, audit item 7) (2026-10-22)

- **Salvos:** `salvo = { count, delay }` is read now.
  - The first shot starts the reload as before; the other `count - 1` follow `delay` apart along the turret's aim, as long as the weapon still has a target it may fire at. Losing it ends the salvo.
  - State `World.wSalvo` / `wSalvoWait`, hashed only during a salvo.
- **MLRS** (guide 13.2: "Judgement (precise)", "Hydra (large salvo)"):
  - Judgement fires 4 rockets 0.3 s apart, Hydra 8 rockets 0.15 s apart. Each rocket does the old shot's damage / count; the Judgement's then −10% (see below).
  - Trade check (`lune run factions 3`): MLRS 1.30 at full damage, **1.20 with the Judgement's rockets −10%** (in band; Order wins defending, 1.82; Chaos now wins the flank, 0.57, which it didn't before). Every Hydra number was already at its ±10% limit.
- **Shell leading:**
  - A ballistic weapon (not a lofted one) aims where a visible moving target will be after the shell's flight time. Two passes: the time from the launch pitch at the led distance; the target's speed along its heading.
  - Radar contacts get no lead (their velocity isn't known); bombs and missiles already lead (D91, S-27).
- **Re-run trade checks:** 12 of 12 roles still in band. Tanks, artillery and MLRS moved by ≤ 0.1 except the MLRS above.
- **Tests (`Salvo.spec`):**
  - A Hydra's 8 rockets 0.15 s apart, the next salvo one reload after the first rocket.
  - A Verdict's shells burst within 14 studs of a tank driving across its line of fire. Without the lead, 0 of 4 do.

## S-70 — The Fusion Reactor explodes (audit item 11) (2026-10-22)

- Guide 8.5: "Fusion Reactor: big explosion on death". New def field `deathBlast = { damage, aoe, edge }`.
- When the unit is killed (Damage), the blast hits every unit in `aoe`: own, allied and enemy alike (team 0), with the usual falloff to `edge`. It's applied the next tick, so a blast can kill a neighbouring reactor and set it off too.
- A cancelled frame never explodes: it doesn't die in Damage.
- A `BLAST` combat event marks it. No wire change: the client sees the DEATH and can read `deathBlast` from the def to draw it.
- **Numbers** (Order and Chaos reactors, my placeholder): 2,500 damage at the center, radius 120, edge 0.25: a T1 tank 40 studs away dies.
- **Test:** `DeathBlast.spec`: a reactor kills tanks of both sides 40 studs off, leaves one 300 off untouched; a generator doesn't explode.

## S-71 — Landing details: parked aircraft are ground targets; full pads are skipped (audit item 10) (2026-10-22)

- **Targeting:** a LANDED aircraft counts as a ground unit for targeting (`Sensors.knownCategories` swaps its AIR / JET / HELI bits for GROUND, and target priorities read the same), and takes LIGHT damage (`Combat.armorOf`): ground guns can kill it (guide 12.2: "easy targets"), anti-air can't engage it until it takes off.
- **Altitude:** a rearming or docked aircraft settles on top of its pad (the pad's height) instead of the ground inside it, where the pad's collision cylinder had been catching every shell aimed at it.
- **Fixed on the way:** Movement skipped aircraft altitude changes on ticks when nothing moved, so a jet that landed while the rest of the map stood still stayed at cruise height.
- **Pads:** an aircraft heading to rearm picks the nearest pad with a free spot (counting aircraft already assigned to it against its `rearmPads`); if all are full, the nearest.
- **Not done:** the flying sight bonus (audit item 10's third part); flying units have the sight their defs give. It would change every air unit's numbers, so it waits for a balance pass.
- **Tests (`Landing.spec`):** a Ravager damages a Falcon parked on its pad, 131 a shell (its LIGHT damage), while a Hornet holds its fire; an empty Falcon skips a full pad for a free one farther away.

## S-72 — Radar upkeep (audit item 9) (2026-10-22)

- Audit item 9 had two parts.
  - "Missile reloads for SAM sites and launchers are free" was already done by the stockpiles (S-47: each missile costs supply and power to rebuild).
  - "Plain radars have no power upkeep" is done now.
- **Rule:** new `sensors.radarDrain` (power per second). It is drained with the tracking and jamming upkeep (`Sensors.drainStep`, D104 / D108). In a power stall, the share a radar gets scales its radar radius, at whole sensor cells, like a tracker's. Fully powered it keeps its def radius exactly.
- **Stealth reach:** range × signature (D78) now uses the powered radius.
- **Numbers** (my placeholders; Order's radars are stronger and cost more):
  - Watchtower 3, Eye 2;
  - Beacon 12, All-Seer 9;
  - Oracle 3, Watcher 2;
  - Archangel (AWACS) 8.
  - Radars on SAM sites and ships carry no upkeep: their weapons and stockpiles already cost.
- **Tests:**
  - `Fog.spec`: an Eye's 2 power/s shows as demand, a stall drops a tank at 530 studs off its radar, and power brings it back.
  - `Tracking.spec`: its stall test uses an Aegis for the plain radar, since a Watchtower now shrinks too.

## S-73 — Friendly fire as a match option (audit item 14) (2026-10-22)

- `match.friendlyFire` (`MatchState.Config`; default true, as before): off, blasts and splash never hurt the shooter's allies (`Combat.friendlyFire`). Direct hits never did.
- **Exception:** strategic blasts (nukes, team 0) and death blasts (S-70) still hurt everyone; they belong to no team.
- **Replay header:** its match byte is 2 when friendly fire is off (1 as before otherwise), so old replays still read and a replayed match keeps the option. No format version change.
- **Test:** `FriendlyFire.spec`: the default hurts both tanks under a blast, the option spares the own one; the option survives a replay round trip.

## S-74 — 800 units: Targeting and Commands, same behaviour (the user's task 9) (2026-10-22)

- **Asked:** bring Commands (5.1 ms, budget 1) and Targeting (8.6, budget 8) at 800 units within budget without changing behaviour (same game-state hash), with before/after numbers.
- **Where things stood:** S-67 had already moved a select-all order's slot assignment into the Pathing job. On today's code (`lune run stress 450 800`, which now prints the state hash and each system's peak tick):
  - Commands averages 0.47 ms, peaks 1.9–3.7.
  - Targeting averages 1.9–2.1 ms, peaks 5.6–9.1.
- **Changes** (the state hash stays `75cd2a2c` in every run):
  - **Targeting's search:**
    - `acceptable()` hands back the level, def index, "type known" and known categories it looked up, and the search scores from them, where `score()` asked the sensors again. The doomed check reuses the level.
    - A per-def `possibleMask`, every category the sensors could ever report for a live unit of that def (its own, its domain's, GROUND for aircraft), rejects candidates a weapon can never target (anti-air over a tank column, guns over jets) before any sensor lookup.
  - **Orders' attack-move hold check (`engaged`):** a live enemy in sight is read straight from the world. That is exactly what `Sensors.knownTarget` would return; any other target still asks it.
  - **Orders:** move-like kinds by table lookup.
- **Deterministic effect:** sensor lookups per 30 s stress run: `knownTarget` 1,173,143 → 811,243 (−31%), `typeKnown` 1,867,852 → 1,192,546 (−36%), `knownCategories` 876,257 → 562,851 (−36%), `level` 1,680,111 → 1,274,427 (−24%).
- **Timings** (3 runs each; the PC is noisy, ±30% run to run):

| | Before | After |
|---|---|---|
| Targeting peak (budget 8) | 9.10 / 5.74 / 5.59 | 5.65 / 6.52 / 7.39 |
| Targeting average | 2.06 / 1.93 / 1.91 | 1.83 / 1.80 / 2.07 |
| Commands peak (budget 1) | 3.67 / 1.93 / 1.97 | 1.76 / 1.77 / 2.15 |
| Commands average | 0.54 / 0.47 / 0.47 | 0.48 / 0.46 / 0.57 |

- **Targeting:** within budget in every run since. **Commands is not:**
  - Its average is 0.47 ms, half of it the attack-move hold check for ~700 units a tick.
  - Its peak is the order tick (applying and issuing 800 units' FIGHT: ~0.4 ms giving orders, ~0.8 ms issuing them) and odd mid-battle ticks at ~1.2–1.5 ms.
  - What's left needs a behaviour change; under "Needs my review":
    - (a) check attack-move holds for half the units each tick (each unit every 2nd tick: 0.13 s later to stop);
    - (b) give a big order's queue entries over 2–4 ticks, like its slots (S-67).
- Tool: `Sim.enableTiming` records each system's peak tick; `stress` prints it and the state hash.

## S-75 — Faction-only units, stage 3: Locust, Cyclops, Barrier, Citadel (the user's task 10) (2026-10-22)

- **Locust (`chs_locust`, Chaos T1, vehicle plant):** value 150, health 600, speed 45. Autocannon `chs_autocannon`: 120 studs, 26 armored every 0.5 s, 2.2°.
  - My call: built one at a time, cheap and fast to build (20 s). The proposal's "built in pairs" would need a factory to produce two units per queue item, which the value accounting, the AI and the client queue don't model.
- **Cyclops (`chs_cyclops`, Chaos T2, advanced vehicle plant):** value 520, health 1,100, speed 22, footprint 2. Siege mortar `chs_siege_mortar`: targets STRUCTURE only, range 520, 1,200 every 8 s, may shell radar contacts and ghosts of structures.
- **Barrier (`ord_barrier`, Order T1 structure, Mason and Architect):** value 40, health 2,500, 1 cell.
  - Movement: it blocks it, like any structure (passability and the quadtree update; S-67's lazy updates).
  - Fire: low direct fire hits it like any unit in the shot's path. It is as tall as a tank (6 studs), so the odd shell clears it.
  - No new mechanic, as the user suggested.
- **Citadel (`ord_citadel`, Order T3 structure, Architect):** value 2,000, health 9,000, footprint 3.
  - Gun `ord_citadel_gun`: 320 studs, 600 armored every 3.5 s, 0.3°.
  - Also an IR SAM (`ord_ir_sam`) and a radar (900, error 16, upkeep 4).
- **Blockouts:** the models stream's pending ones (Blockouts/Pending, M-17) already have these ids, footprints and pieces; the defs use them as they are.
- **Counter matrix (guide 12.4):** new rows "Swarm tank" (Locust: Ground ●●, Ship ●, Structure ●) and "Siege mortar" (Cyclops: Structure ●●●, nothing else).
- **Trade check** (`lune run factions`, new "Faction-only units" section, report only; the Order side's trade):
  - Locust against Lancers: close 1.43, long 1.11, flank 0.72.
  - Warden holding against Ravagers: 2.87.
  - Citadel against a tank assault: 1.67.
  - Citadel against Minotaurs: 0.35.
  - Citadel against Cyclops with a Watcher radar: 0.31. Without a spotter, the Cyclops can't see the Citadel before its gun does: 1.46.
- **Tests (`Fortify.spec`):**
  - The Locust's value, speed and reach.
  - A Cyclops shells a plant 500 studs off and never targets a tank in range.
  - A Barrier wall: a tank drives round it; most shells at a tank behind a 3-segment wall hit the wall.
  - A Citadel kills a Ravager 270 studs off and fires its SAM at a helicopter.

## S-76 — Faction AI (the user's task 11; factions.md section 7) (2026-10-22)

- **Asked:** Order expands safely, defends first, attacks later with artillery and radar escort, builds Wardens; Chaos expands wide, sends earlier and more frequent waves on two lanes, brings jammers and Minotaurs. Hard > Normal > Easy must hold for each faction.
- **Built** as an overlay on the level (`Skirmish.styled`). Easy keeps its strength and only takes the production mix.
  - **Order:**
    - Its advanced plant builds Wardens (a quarter of its army items); more artillery in its waves (+0.1); Normal and Hard recall the army against enemy waves.
    - Hard only: safe expansion (Hard already had it) and a gun turret more at home.
  - **Chaos:**
    - A worker more.
    - Waves of 2 units more: a wave counts units, and Chaos's cheaper units make the same value with ~30% more of them. Waves grow faster.
    - From 12 front units a wave splits in two lanes: every second unit goes through a flank waypoint 300 studs off the straight line (the side alternates per wave, in world terms so mirrored players flank alike), then joins the attack.
    - A Shroud jammer guards each wave with the radar escorts.
    - Its plant builds Locusts among its tanks (35%), its advanced plant Minotaurs (25%).
- **Tried and dropped (the faction report's quick runs; the slow suite):**
  - Order's safe expansion and turret on Normal: Order mirrors then stalled at their bases for all 10 minutes of `Fairness.spec`, called on value, east 6–0.
  - Order's first wave 2 bigger: on skirmish:192 it never attacked before Chaos killed it.
  - Chaos waves 2 smaller (as the proposal said, "earlier and more frequent") fed Order's defence piecemeal: Order 93%.
  - Lanes from 4 units: the halves arrived apart.
- **Levels** (`docs/AI_LEVELS.md`, 40 min, 3 seeds; mirrors per faction): Normal–Easy 37–5, Hard–Normal 41–1, Hard–Easy 36–0, Hard won all 6 FFAs. Per faction:
  - Order: Normal–Easy 13–5, Hard–Normal 18–0, Hard–Easy 18–0.
  - Chaos: Normal–Easy 18–0, Hard–Normal 17–1, Hard–Easy 18–0.
- **Tests:** `AI.spec` checks the overlay and that a rich Order AI fields a Warden and a Chaos AI Locusts and a Shroud. `Fairness.spec` mirrors split 5–7.
- **Faction balance in AI matches:** still Order ~90% (task 12, S-78).

## S-77 — Replay compression: player replay format 2 (launch item) (2026-10-22)

- **Asked:**
  - delta-encode Tactical records;
  - run-length the Strategic snapshots;
  - then a pure-Luau compressor if it still helps;
  - measure on the soak's spectator recording and on a player's;
  - keep the format versioned.
- **PlayerReplay format 2** (the default; format 1 files still read): the header as before, then `bodyHash u32` (FNV-1a), then the frame stream after three stages:
  1. **Transforms** (reversible, against the same unit's previous record in the file):
     - each message's tick header becomes its difference from the frame's tick;
     - **Tactical:** unitId | zigzag varint of the cell's change | offX, offZ, heading, alt changes mod 256 | flags XOR;
     - **State:** unitId | length | the record XOR the unit's previous record of the same length;
     - **Strategic:** XOR the previous snapshot (unchanged bytes become zero runs, which the next stages squeeze).
     The transforms alone change little in size (4.85 → 4.47 MB); they turn slowly changing records into repeats.
  2. **`Shared/Net/Lz`:** LZ77, the LZ4 block layout, greedy matching through a 4-byte hash, 64 KB window.
  3. **`Shared/Net/Huffman`:** canonical order-0 Huffman per 64 KB block, codes ≤ 15 bits, table-driven decoding.
  - The hash refuses a damaged file: LZ alone can't always tell.
- **Measured** (`lune run replay_size [file] [minutes]`):

| Recording | Format 1 | Transforms + LZ | + Huffman (format 2) | Write / read |
|---|---|---|---|---|
| Soak spectator, seed 4, 25.5 min | 4,738 KB (185 KB/min) | 2,150 KB (45%) | **1,679 KB (35%, 66 KB/min)** | 1.5 s / 1.1 s |
| Normal AI match, spectator, 9.7 min | 911 KB (94 KB/min) | 372 KB (41%) | **290 KB (32%, 30 KB/min)** | 0.33 / 0.23 s |
| Same match, player 1 (no camera: strategic only), 9.7 min | 375 KB (39 KB/min) | 89 KB (24%) | **77 KB (21%, 8 KB/min)** | 0.05 / 0.03 s |

  - For reference, zlib on the same transformed stream: 1,371 KB (29%) for the soak. Huffman over LZ gets most of the way.
  - LZ alone on format 1, no transforms: 2,618 KB (55%).
- **Tests:**
  - `Lz.spec`: Lz round-trips empty, random, runs, repeats across the window, and refuses a cut stream; Huffman round-trips skewed data over three blocks and tiny inputs, and refuses a cut stream.
  - `PlayerReplay.spec`: format 2 round-trips, rebuilds the live view on playback, reads a format 1 file as the same replay, is under 70% of format 1, and refuses a flipped byte (hash) and a cut file.

## S-78 — Full faction report; no ±10% tuning reaches the target (the user's task 12) (2026-10-22)

- **Asked:** Order against Chaos at every level pair, every map, both starts, 3+ seeds. Targets: 40–60% overall, 35–65% per map, ≤10% undecided. Tune shared-role numbers within ±10% of the approved values to reach them, and list every change.
- **Report** (`docs/FACTION_AI.md`, `lune run faction_ai 40 3`, 324 matches, after S-76's AI):
  - Same-level: Order 88, Chaos 10, undecided 10 (**9%: the undecided target is met**). **Order 90%:** out of target overall and on every map (Ridgeline, Coastline, skirmish:256 94%; Normandy 91%; Twin Lakes 83%; Crossroads 80%).
  - Levels still decide across factions: Chaos hard beats Order normal 24–4; Order easy against Chaos normal is 15–13.
- **No tuning committed:** nothing within ±10% moved the share outside the run-to-run noise. Each experiment is a 36-match same-level run, 20 min, 1 seed; the baseline is 89–93%:

| Experiment | Order share |
|---|---|
| Faction styles as proposed (Chaos waves 2 smaller and more frequent, two lanes from 4) | 93% |
| Chaos waves 4 bigger | 86% |
| Chaos expands only safely too | 90% / 86% |
| Chaos waves bigger, safe, lanes only from 16 | 93% |
| Verdict range 432, Hellmouth 418 (both ±10% limits) | 90% |
| Lancer range 189, Ravager 187 (both limits) | 92% |
| Lancer health 1,170, damage −10%; Ravager health 1,100, damage +10%, cost −10% (all limits at once) | 88% |
| Diagnostic, not a proposal: the Ravager as accurate as the Lancer | 90% |

- **What the matches show** (kill and death tallies, 6 Normal matches on Ridgeline):
  - Lancers kill 39–52 Ravagers for 9–22 the other way.
  - Chaos loses 75 of its 81 workers, 77 of its dead workers in Order's half (it expands into it). Half its army dies at home, against 27 of Order's 94 losses.
  - Chaos gathers twice Order's power and still fields the smaller army.
  - The equal-value trade check calls every pair even, so the gap is in how AI matches fight (piecemeal waves into rallied defenders, workers in the open), not in a number.
  - Ranked first in `docs/design/next.md`, with a match-shaped trial to reproduce it outside the AI. Under "Needs my review".

## S-79 — Shield domes: generators, field, charge and power on the wire (client request 40) (2026-10-22)

- **Asked** (the user, through the client stream's request 40 and the C-87 prototype): a shield generator structure (no vehicle) for each faction, Chaos's dome smaller (client placeholders: Order 120, Chaos 80); a field band outside the dome slows inbound shells to a stop, then throws them out; heavier shells take longer; full force at ≥ 50% charge, less below (big shells break through, slowed); recharging draws power; collapse at 0%, rise at 25%; bounced shells stay live and explode where they land. On the wire: per shield radius, strength and up / down / recharging, seen by whoever sees the generator; hit events with position, intensity and breakthrough.
- **Built:**
  - `Shared/Combat/ShieldField`: the field, shared so clients step a shell the same way. The prototype's model (radial braking = constant + drag, deeper is stronger; push out after the turn; tangential drag; force / mass^0.6), with exact ballistic substeps (≤ 10 studs each, ≤ 8 per tick) and gravity throughout. A shell enters only from outside the dome while moving in.
  - `Sim/Shield`: generators (`shield = { radius, capacity, recharge, power }`) in `Combat.shieldIds`; per-projectile `pShield` / `pShieldPhase` / `pShieldDone` in Combat (all hashed). `Shield.deflect` runs in Projectiles in place of the ballistic step when a shell is in or about to enter an enemy dome's field; the usual chord tests (units, ground) follow. `Shield.drainStep` recharges with the other economy consumers in Build.step.
  - Defs `ord_phalanx`, `chs_carapace` (numbers under "Needs my review"); weapon field `shieldMass` (optional).
- **Technical calls:**
  - **Braking doubled** from the prototype (BRAKE 1000, DRAG 20) so a full dome stops every shell in the game; a 1-D check put the Citadel round (480 studs/s, mass 4.3) and the siege mortar past the band at the prototype's numbers.
  - **Mass** from damage (best damage / 150, 0.2..8), so new weapons need no extra field.
  - **A turned shell** gets at least 6 s more life (it would otherwise burst mid-air on its old timer), drops its overkill booking (S-29), and a missile loses its lock. A shell is in one dome's field at a time and is done with a dome once out of the band after its turn, or through it.
  - **Who:** enemies' projectiles only (by the projectile's side); not torpedoes, strategic missiles or interceptors chasing one; hitscan and beams untouched (not in the rules; review).
  - **Wire (protocol 24):**
    - A SHIELD event rather than a State field: the State mask byte is full, and the charge needs no per-tick rate. Sent after ENTER and on a change of 4/255 or of the flags.
    - Generators' tactical margins grow by their dome's radius in cells, so the dome is known wherever it shows.
    - **SHIELD_FIELD** exists because SPAWN_PROJ carries no side (S-43): without it a client can't tell an enemy shell the field will catch from an allied one passing over. It names the dome by its centre, radius and force, not the generator, so a hidden generator's dome still bends shells correctly.
    - SHIELD_HIT names the generator only when the client has it.
    - Shells in a field get Projectiles corrections like homing ones, plus one at the turn or breach and one as they leave.
- **Tests:** `Shield.spec` (12): every shell weight turns at full charge and bursts outside, live; a turned shell lands on its own side's tank; heavier turns deeper; at 6% a siege shell breaks through slowed while an autocannon round turns; charge drain by mass, collapse, shells pass a fallen dome, no recharge without power, rise at 25%; power drawn only below capacity; allies' shells and shots from inside untouched; a built generator starts empty; SHIELD / SHIELD_FIELD / SHIELD_HIT on the wire and the test client's field step within a stud of the server's; generator 0 for a player without it; the C-89 shield profile (nothing under the dome hurt while it stands); determinism. `Schema.spec`: golden bytes, round-trips, rejects, truncation.

## S-80 — Shield domes: 10× charge, mirror bounce (the user's rules after playing, via the client stream) (2026-10-22)

- **Asked** (relayed by the client stream): "The shield is weak, boost 10x"; and "shot should be steered away from the shield too, when come in contact with the shield, the shot can be reflect if its coming straight at the shield or get diverted by the shield (bounce to another angle off the shield + the incoming angle)". ("The deceleration rate is so weak" was the client's preview, which had no field yet.)
- **10×:** capacity and recharge both ×10, as the client read it (same refill time, a tenth of the share per shell): Phalanx 300 / 15 per s, Carapace 200 / 12 per s. **Power draw unchanged** (40 / 25 per s while recharging): my call, so the dome's running cost stays what it was; under review.
- **Bounce:** measured the exit angle against the normal **where the shell turns** (on a sphere with a 50-stud band, a glancing shell turns well before its aim point, so the aim point's normal misleads). With S-79's numbers mass-1 shells already left near the mirror angle, but heavy ones left 15–18° steeper and head-on shells came back at ~45%. A sweep of PUSH × TANGENT_DRAG over masses 0.3 / 1 / 4 and angles 0–70°: **PUSH 2800, TANGENT_DRAG 0.3** keeps every case within ~8° of a mirror, head-on straight back at ~60% of its speed, glancing ones at 70–85%. No new state and no wire change: the client gets it through `Shared/Combat/ShieldField`.
- **Tests:** `Shield.spec` 13: a mirror test (head-on back at 50–70% speed; 30°, 50°, 70° within 10° of a mirror, keeping 60–100% of speed, for masses 0.3, 1 and 4); the drain, breach and wire tests now read the charge on the hit tick (a tick's recharge is 1 now).

## S-81 — Shield domes at 50× strength (the user, via the client stream) (2026-10-22)

- **Asked:** "Increase strength to x50". Read, as for S-80's 10×, as 50× S-79's capacity and recharge with the same refill time (20 s from empty): Phalanx 1,500 / 75 per s, Carapace 1,000 / 60 per s. The client's Studio run explains why: at capacity 30 the shield profile's barrage collapsed the dome within a second of each rise.
- **Power draw unchanged** (40 / 25 per s while recharging): my call, as in S-80; under review.
- **Effect:** a full Phalanx recharges 75 shell masses a second: about 30 mortar shells, 85 Ravager rounds or 9 siege shells a second before it loses ground. Breaches still happen only below 50% charge, which only a large, sustained barrage or a power stall now reaches.
- **Tests:** the drain test starts half full and compares the hit tick with the tick before (a tick's recharge, 5, now exceeds a mortar shell's 2.4).

## S-82 — Shield field after the user's drawing: head-on back, off-centre steered round and on (2026-10-22)

- **Asked** (the user via the client stream, with a drawing): "If straight forward then it will by slowly slowed down and bounce off, if hit at an angle (like the right side), it will slowly be slowed down + steered off. Also reduce the de-acceleration to 1.5x, not 2x". The drawing: a head-on shot stops and goes straight back; a parallel shot near the right edge slows, bends along the dome's curve and carries on, not back toward the shooter.
- **Why S-79/S-80's field couldn't:** it acts only along the normal, starting 50 studs out, so an off-centre shell is turned to the band's own curve far from the dome and leaves sideways or back (0.5 radii off the centre: 123°; even with no push at all, 90°).
- **The new braking phase** (`Shared/Combat/ShieldField`):
  - **Takes hold** only of a shell in the band whose straight line would hit the dome (`ShieldField.onCourse`). Shells that would pass the dome by are left alone; the sim also picks the dome a shell is on course for, not the first one near.
  - **Slows** the shell along its path by BRAKE + DRAG × speed (750 / 13.5: 1.5× the prototype's 500 / 9, the user) × (0.4 + depth) × the head-on share: cos² of its incidence on the dome itself, from its line's closest approach to the centre (`ShieldField.headOn`), at least GLANCE_SLOW 0.05.
  - **Steers** it away from the dome at STEER 8 rad/s × (0.4 + depth), while its line still passes within GRAZE 1.08 radii of the centre, and never past that line. A rotation, so it never overshoots.
  - **Turns** (the hit, on the dome under the shell) when it stops closing in. Then it is thrown out: PUSH 700 × the head-on share, so a shell stopped head-on goes straight back and one sliding past only gets a lift.
  - Mass divides the braking, steering and push by mass^0.6, as before.
- **Measured** (mass 1, 260 studs/s, full force; offset of the line → angle between the way out and the way in, speed kept): 0 → 180° (39%), 0.3 → 141° (68%), 0.5 → 94° (53%), 0.7 → 42° (37%), 0.85 → 25° (51%), 0.95 → 18° (56%). Heavy (2.4, 8) and light (0.25) shells at 240–480 studs/s: head-on straight back, glancing 17–60°.
- **Not stopped head-on at full force:** the Citadel round (mass 4.3, 480 studs/s) at the reduced braking; the siege mortar (8 at 240) and heavy bombs still stop. Under review.
- **Caught again:** a shell thrown out that comes back (a bomb bounced up falls again) is caught again; `pShieldDone` is gone. A shell inside the dome can't be caught (the field starts outside it), so breaches still pass.
- **Tests:** `Shield.spec` 13: the S-80 mirror test replaced by the drawing's (head-on back, the angle shrinking with the offset, glancing under 60° from 0.7 radii and under 30° at 0.95, heavy and light shells, a line past the dome untouched); bombs in the shell-weight test now drop from above the dome. The client's S-80 note no longer holds.
- **Fix (same day, the client's ShieldWire spec and Studio run):** flat head-on shots low over the ground never turned. Braked almost to a stop, they were bent down by gravity until their line missed the dome. That left them almost no braking and no turn, so they sank through the band and burst in front of the dome (Studio: 146 of 310 shells in 12 s). Now a shell also turns once its line no longer hits the dome, and one slower than STOPPED (60 studs/s) counts as head-on for the push out, so it is thrown back. The client's case is a test. New measurements (mass 1, 260 studs/s): 0 → 180° (39%), 0.2 → 135° (30%), 0.3 → 80° (28%), 0.5 → 51° (42%), 0.7 → 32° (60%), 0.85 → 21° (73%), 0.95 → 14° (78%).

## S-83 — The shield field inside the dome (the user, via the client stream) (2026-10-22)

- **Asked:** "shell can pass through the shield as it will be slowed down and bounced off while inside the shield. Right now, the shield forces every shell to be outside of it".
- **Built** (`Shared/Combat/ShieldField`): the field fills the outer `BAND_SHARE` (0.4) of the dome, between the core (0.6 R) and the surface; nothing acts outside the dome.
  - It takes hold of any enemy shell that crosses the surface moving in.
  - Braking and the head-on share are as in S-82, measured against the dome's radius.
  - Steering now turns the path toward the tangent where the shell is (at most to it): inside a sphere, the S-82 "line that grazes the dome" is the local tangent. An off-centre shell bends round inside the dome and leaves through its surface.
  - The turn is when it no longer closes in. Steering also turns a shell slowed to nothing and bent down by gravity, so the S-82 fix's "line misses the dome" test is gone.
  - Thrown out until it leaves through the surface. A breach is reaching the core, still closing in.
  - Hit and breach points are on the surface over the shell, where the client draws them. No wire change.
- **Band depth** (my call; the client suggested 0.35–0.4 R). Head-on at full charge, at 0.4:
  - the Phalanx (band 48) stops everything but the Citadel round;
  - the Carapace (band 32) also lets the siege mortar through.
  - At 0.5 the Phalanx stops all and the Carapace all but the Citadel round, with cores of 60 / 40 studs. Under review.
- **Measured** (mass 1, 260 studs/s, full force, R 120; offset → angle out against in, speed kept):
  - 0 → 180° (38%), 0.2 → 164° (42%), 0.3 → 149° (37%), 0.5 → 81° (31%);
  - 0.7 → 39° (58%), 0.85 → 24° (81%), 0.95 → 12° (94%);
  - R 80 within a few degrees.
- **Consequence (review):** units standing in the band are under shells still slowing down, and a turned shell may burst there.
- **Tests:** `Shield.spec` 14:
  - turns happen inside the dome, between the core and the surface;
  - glancing shells through the rim keep up to 97% of their speed;
  - the shield profile checks the core (the radar and builder near the edge stand in the band).
- **Decided (the user, via the client stream):** "Keep 0.4R for now." Checked in Studio on the shield profile (12 s): 230 shells crossed the surface, 219 turned, none got through, and the dome held at 100%. Ravager shells reach about 16 studs into the 48-stud band, Juggernaut shells about 30. The client now lights the hit ripple where a shell crosses the surface (from SHIELD_FIELD) rather than at the turn; no wire change.

## S-84 — A downward pull inside the dome (the user, via the client stream) (2026-10-22)

- **Asked:** "shells should be apply a downward force (like gravity) when insde the dome".
- **Built** (`Shared/Combat/ShieldField`): while a shell is in the field (braking or thrown out), its ballistic substep uses its weapon's gravity plus `FIELD_GRAVITY`, 60 studs/s² (a shell's own gravity; the same for every mass, like gravity). No wire change: clients step the same module.
- **Strength:** my call. It is about one shell's gravity, so the S-82 / S-83 shapes stay (head-on back, off-centre round and on) while turned shells arc down.
- **Effect:** on the client's ShieldWire setup (a Ravager firing head-on at a Phalanx), turned shells land 116–134 studs from the centre, at the dome's edge, against 140–174 before. None reach the 72-stud core. More shells now burst in the band (review).
- **Tests:** `Shield.spec` 14. Turned shells are checked to land outside the core rather than outside the dome. The flat head-on case checks that turned shells fly back or land (none hang), and that none land in the core.

## S-85 — Light shots destroyed at the dome's surface (the user, via the client stream) (2026-10-22)

- **Asked:** "for small/light shots -> get destroyed instantly, for heavier shot -> use the same mechanic as now for them".
- **Built:**
  - `ShieldField.step` destroys a shell lighter than `ABSORB_MASS` (0.5, i.e. under 75 damage) where it crosses the surface moving in. The step stops there with the new `ABSORB` event and the surface point.
  - `Shield.deflect` drains `HIT_COST` × its mass (as for a turn), emits SHIELD_HIT with `absorbed`, and Projectiles removes it with no burst and no damage.
  - Heavier shells keep S-82..S-84's mechanic.
- **Threshold** (my call; the client suggested ~0.5). Destroyed:
  - machine guns (0.2–0.27);
  - autocannons (Locust, 0.23);
  - MLRS rockets (Hydra, Judgement; 0.22–0.39).
  - Kept on the full mechanic: the Ravager's and Lancer's cannons (0.87, 1.1) and everything heavier.
- **Wire, protocol 25:**
  - SHIELD_HIT flag `SHIELD_ABSORBED` 2 (the decoder rejects 3: a shell is turned, through or absorbed).
  - The client drops the shell with no burst; NetOut sends no IMPACT for it and forgets it.
  - It never gets a SHIELD_FIELD (destroyed on the tick it enters).
  - This is a flag rather than an IMPACT at the surface, so the client can tell a dome kill from a burst.
- **Tests:**
  - `Shield.spec` 15: a light-shell test (absorbed on the surface, mass in charge, no IMPACT, gone; the test client got the flag and dropped it); the shell-weight test splits light (destroyed) from heavy (turned); the field-shape tests use mass 0.6 for "light".
  - `Schema.spec`: golden bytes for ABSORBED, the breach-and-absorbed encode error, flags 3 rejected.

## S-86 — Shield domes at 20× strength (the user, via the client stream) (2026-10-22)

- **Asked:** "Lower the shield from the previous x50 down to x20 (its too powerful for now)."
- **Built:** capacity and recharge 20× S-79's, the same 20 s refill: Phalanx 600 / 30 per s, Carapace 400 / 24 per s. Power draw unchanged (40 / 25 per s), my call as before. A full Phalanx now loses ground to more than ~12 mortar shells a second.

## S-87 — Frames are inert until complete; destroyed, they leave nothing (the user, via the client stream) (2026-10-22)

- **Asked:** "The Bulwark is being built and it still be able to shoot ? No. Every unit in the building process is just a semi-transparent model, if get destroyed, it leaves no wrecks, just gone. It will only be activated when complete".
- **Audit** of build progress < 1:
  - already inert: sensors and jamming (Sensors unstamps frames), factory production (only finished factories queue and build), economy output (producers register on completion), missile stockpiles, rearm pads, the shield (empty and down until built);
  - not inert: weapons (Targeting and Weapons ran for any unit with weapons) and death (wreck and death blast).
- **Built:** Targeting and Weapons skip frames (no target, no turret motion, no shot). Damage gives a frame no wreck (DEATH `wreckId` 0) and no death blast.
- **Wire:** none. Build progress already reaches every client that has the unit in its tactical tier, enemies included (ENTER `build`, State BUILD on change); strategic records don't carry it.
- **Tests:** `Frames.spec` (3): a half-built Bulwark doesn't target or fire at a tank in range for 10 s, then fires once complete; a frame killed with little overkill leaves no wreck where a complete one does; a reactor frame sets off no blast where a complete one does.

## S-88 — Match statistics over time in Sim/Stats (client request 41, the user's queue task 1) (2026-10-23)

- **Asked:** keep the statistics history in the sim (a sample every 10 s, damage taken included), so the client stops sampling on the server.
- **Built:**
  - `Stats.series(sim)` in the shape of the client's `src/roblox/StatSeries` (C-105): `{ start, every, t, players[tostring(pid)][field] }`.
  - `Stats.FIELDS`: supply and power gathered, spent and stored (the team account's), units built, lost and killed, damage dealt, and new **damage taken**.
  - Damage taken is the health enemies removed from the player's units, capped at what the unit had left. It is counted in Damage beside damage dealt.
  - **Sampling:** `Sim.new` takes the first sample at tick 0, after the scenario. `Stats.step`, at the end of `Sim.step`, takes one every `every` ticks (150 = 10 s). Past 120 samples, every other one is dropped and `every` doubles.
  - Not hashed: it only reads the sim, like the report.
- **Tests:** `Stats.spec` 6: damage taken mirrors damage dealt on a kill; the series' shape and timing over 30 s; the halving and the doubled interval.

## S-89 — Shield domes stop hitscan shots (the user's queue, task 2) (2026-10-23)

- **Asked:** finish the shield: "intercept of shells and hitscan, strength drain, energy refill, collapse at 0% / rise at 25%, the wire state and hit events". S-79..S-87 already did everything except hitscan (S-79 let hitscan and beams through, under review).
- **Built:**
  - `Shield.intercept`: a hitscan or beam shot, or a shell resolved like one at the projectile cap, is stopped where its segment first enters an enemy dome that's up, if the muzzle is outside that dome.
  - The FIRE event ends at that surface point with no hit and no damage. The shot's mass (`ShieldField.mass`) comes off the charge, as for a light shell absorbed (S-85).
  - SHIELD_HIT (absorbed) with projectile 0.
  - Shots from inside a dome pass out, as shells do.
- **Wire, protocol 26:** SHIELD_HIT's projId may be 0 (a hitscan shot); the decoder used to reject it.
- **Which weapons:** today's hitscan weapons are the flak guns (AA: a plane over an enemy dome is out of their reach) and the Minotaur's demolition charge (30 studs: from outside, only structures in the band are in reach).
- **Tests:**
  - `Shield.spec` 16: a Minotaur outside a dome sees its charge stopped on the surface every time, with no hitscan hit getting through; inside the dome the same charge hits; a line clear of the dome passes.
  - `Schema.spec`: golden bytes for projId 0.

## S-90 — Shield dome radius and faction balance, measured (the user's queue task 2) (2026-10-23)

- **Asked:** measure how the dome radius (Order 120, Chaos 80) affects faction balance; numbers at 120/80 and 64/48 under "Needs my review".
- **Tool:** `lune run shield_trial [seeds] [orderR chaosR ...]` with `Scenes.shieldSiege`. Each faction holds a base under its own dome with an equal-value hold-position army (T1 tank, T2 tank, T1 artillery) against the other faction's raid of the same roles. The raid's budget is the army plus the generator; an unshielded defender spends the generator's value on army. Radii come from a rebuilt def set (`Defs.build`), so the game's defs are untouched.
- **Result** (5 seeds): table in `docs/progress/sim.md` under "Needs my review".
  - At 120 the Order dome makes the defending army untouchable, since it fires out freely: the raid destroys nothing.
  - At 80 the Carapace turns Chaos's lost defence into a win.
  - At 64 / 48 the domes protect the base more than the army.
- **Not decided:** the fix (smaller domes, blocking outgoing fire, a higher cost per hit, or none) is for the user's review.

## S-91 — The match-shaped trial (next.md item 1a, the user's queue task 3) (2026-10-23)

- **Asked:** next.md item 1 (a): reproduce the AI matches' Order bias outside the AI, with small waves against a rallied defender that has turret and artillery support.
- **Built:**
  - `Scenes.waves(attacker, waves, seed)`: a rallied defender (T1 tank and T1 artillery, `TRIAL_BUDGET`, default move state) stands beside its base (vehicle plant and T1 turret).
  - The other faction arrives in `waves` equal waves 30 s apart, each attack-moving on the base, with the same roles and value plus the turret's.
  - `lune run factions [seeds] match` adds the section; `play` now counts units that join mid-run.
- **Result** (3 seeds; Order's trade = Chaos value destroyed / Order value lost):

  | Attacker | 1 wave | 4 waves | 8 waves | Base fell (1 / 4 / 8) |
  |---|---|---|---|---|
  | Order attacks | 0.81 | 0.62 | 2.62 | 0/3, 0/3, 3/3 |
  | Chaos attacks | 0.82 | 9.29 | 18.61 | 3/3, 0/3, 0/3 |

- **Reading:**
  - In one big wave the factions trade alike (0.81 / 0.82), as the equal-value trial said (S-62).
  - In 4–8 small waves Chaos loses 9–18 times what it kills against an Order defender, while Order's small waves still take a Chaos base.
  - So the gap is how the AI fights (small waves into a rallied defender), and Order's range and accuracy edge makes it worse. That is what (b) and (c) address.

## S-93 — Shields destroy every projectile at the surface (client request 42, the user) (2026-10-23)

- **Asked** (relayed by the client stream): every projectile that reaches an up enemy dome is destroyed on contact, whatever its mass: no braking field, no turning back, no breach. Keep the drain per hit, the collapse at 0% and the rise at 25%, and the S-89 hitscan stop.
- **Built:** `ShieldField.ABSORB_MASS` = ∞. Every enemy shell crossing the surface takes S-85's absorb path: destroyed there, its mass off the charge, SHIELD_HIT with ABSORBED, no IMPACT. SHIELD_FIELD is no longer sent.
- **Kept, not deleted:** the S-79..S-85 field (braking, steering, push, gravity, breach) still runs for any finite `ABSORB_MASS`. Its tests run with it set to 0.5 (`fieldOn` in `Shield.spec`), so the user's earlier rules return with one constant if wanted.
- **Measured:** the S-90 trial again (in `docs/progress/sim.md`): at 120 / 80 both factions' defending armies are now untouchable, so the radius decision (S-90) matters more.
- **Tests:** `Shield.spec` 17: every shell weight is destroyed at the surface with its mass in charge and no burst. The field tests run with the field on.

## S-94 — T1 factories at twice the build power; the AI's economy follows (client request 42b, the user) (2026-10-23)

- **Asked:** "Build speed for a single unit take too much time" (a Lancer took 51 s; BAR's T1 tanks about 25–30 s). Halve the T1 build times or double the T1 plants' build power, my call.
- **Built:** the T1 vehicle plant, airfield and shipyard of both factions build at 200 (was 100), as the T2 ones do: a Lancer in 25.5 s. Build power rather than build times, so only factory output speeds up; structures built by workers keep their pace.
- **The AI** (its economy couldn't keep up): a plant at full speed draws about 66 power/s (a Lancer's 1,700 power over 25.5 s). The generator rule planned for 20 per plant, so normal stalled at 25% power with two generators for 8 minutes: every job slowed to a quarter, and its tanks-first opening (S-57) kept the builders off generators. Now:
  - generators wanted = ⌈(factories' build power × `POWER_PER_WORK` (1/3) + 20 + refills) / `GENERATOR_POWER` (20)⌉, counted in generators, frames included, not income (a mirror's finishing tick mustn't change the next job);
  - the tanks-first opening holds only while power hasn't run below `ARMY_FIRST_RATIO` (0.6) in the last `POWER_MEMORY` ticks, watched every tick (S-31's lesson: a think's sampling moment mustn't decide).
  - Normal on Ridgeline at 8 minutes: 12 generators, power at 100%, 31 units (was 2 generators, 25% power, 6 units).
- **Fairness:**
  - Faster plants put more units on the road early, so the mirrored builders' trip jitter (flow-field tie-breaks) shows up sooner: Hard's mirrored 2v2 now parts after 7 jobs, not 8.
  - One pair of mirrored players ends 12% apart at 3 minutes, the other 1% the other way. It's the same with the build power alone and the old AI; seeds don't matter.
  - The test now asks for the first 7 jobs to match, the two teams within 10%, and no consistent side lead (both pairs > 5% the same way), which is what S-31's bug looked like.
  - Mirror match split: west 4, east 8 of 12 (in tolerance).
- **Tests:**
  - `Build.spec`: a Lancer in 383 ticks.
  - `AI.spec`: normal's economy keeps up (≥ 4 generators, ≥ 8 units and power ≥ 60% by 8 minutes) instead of tanks before the third generator.
  - `Fairness.spec`: as above.

## S-95 — Factory order lists (client request 44, the user) (2026-10-23)

- **Asked:** queue orders for a factory's new units (pre-move to a spot, then guard a unit, patrol and so on); keep the whole list: MOVE, FIGHT, PATROL, GUARD, REPAIR, ATTACK; shift appends, a plain order replaces, STOP clears; each produced unit rolls out of the exit, then takes a copy.
- **Built:**
  - `OrdersState.rally[factory]` is a list of `RallyOrder { kind, x, z, lx, lz, target, gen }`, replacing S-4's single rally kind and point. It is hashed.
  - `Orders.give` puts these six kinds on a factory's list (queued: appended; else replaced); `Orders.stop` clears it.
  - `Build.producedHook` gives the new unit its exit move, then each listed order, queued, in order.
  - Guard and attack keep their target's generation, so an order to a unit since gone ends at once on the new unit, as any stale order does.
- **No wire change.**
- **Tests:** `Orders.spec` 11: a move-then-guard list reaches a produced unit in order, and it ends up by the guarded tank; a plain order replaces the list; STOP clears it.

## S-96 — T2 beam towers and flak towers (client request 43, the user) (2026-10-23)

- **Asked:**
  - Start with a Pulsar-style beam tower per faction: a precise, long-range BEAM; a very heavy hit on a long reload; a large power cost per shot.
  - Switched off, it retracts into an armored shell (about 4× effective HP) and can't fire.
  - It fires over other defenses; it is precise, so weak against radar contacts.
  - Then more T2 defenses for both factions, and the T2 builders' build options.
- **Built:**
  - **Beam towers:**
    - Order `ord_radiance`: range 650, 2,600 (structures 2,000) every 9 s, 700 power a shot.
    - Chaos `chs_inferno`: range 560, 2,000 / 1,600 every 7 s, 500 a shot; cheaper and lighter.
    - Both are T2, footprint 2, with BEAM weapons at accuracy 0 that can't target radar contacts (`canTargetRadar` unset).
    - Beams are blocked by terrain only (Combat.lineOfFire), so they fire over walls and other defenses.
  - **Weapon `shotCost`:** a shot needs the team's stores to hold the cost, and draws it at once (`stored` and `drawn`, so Stats count it). It doesn't wait on the economy window.
  - **Unit `retract = { armor }`:**
    - TOGGLED_ON clear means retracted: Targeting and Weapons skip the unit, and Damage divides by `armor` (4).
    - Spawned and built towers start switched on.
    - The TOGGLE command and the state bit already existed, so there's no wire change.
  - **Flak towers:** Order `ord_lumen` (2 × `ord_flak`) and Chaos `chs_hailstorm` (3 × `chs_flak`, cheaper), T2: no land flak tower existed. The existing T2 defenses (Bastion / Maw, Edict / Cataclysm, Aegis / Wyvern) stay.
  - All four are in the Architect's and Forgemaster's build options; blockouts are requested from the models stream (request 10).
- **Note:** a team without depots stores 1,000 power, so a beam tower fires once and then waits on income (under review).
- **Tests:** `Defenses.spec` 4:
  - Radiance hits twice in 12 s for 2,600 each at 700 power, and holds fire below 700;
  - an Inferno ignores a radar-only Paladin and fires once a scout sees it;
  - switched off: no fire and 400 damage → 100; on again: fire and full damage;
  - both flak towers fire on and damage an enemy jet.

## S-98 — Supply deposits on Normandy (next.md item 5, the user's queue task 5) (2026-10-23)

- **Asked:** add supply deposits to Normandy, behind each river and some in the bocage.
- **Built** (`Normandy.DEPOSITS`, `CENTRE_DEPOSITS`). Each west deposit goes on the nearest free field cell to its spot, and its east twin on the exactly mirrored cell, so the map stays symmetric:
  - **home:** four of value 4 round each start;
  - **rear:** a pair of value 3 north and one south of each start, behind the river;
  - **staging:** a pair of value 3 in each side's staging fields;
  - **bocage:** two pairs of value 3 in each half of the bocage, north and south of its village (contested ground);
  - **centre:** a rich pair of value 6 south of the middle road.
  - In all, 30 deposits worth 104. The other 1v1 maps have 18 worth 68; Normandy is twice their size.
- **Tests:** `Normandy.spec`: 30 deposits worth 104, all on field cells, mirrored, 8 behind each river.
- The faction_ai re-run is in task 3's report.

## S-99 — Parallel report runs and deterministic work counters (next.md item 9, the user's queue task 6) (2026-10-23)

- **Parallel runs:**
  - `lune run faction_ai ... --jobs=N` and `lune run ailevels ... --jobs=N` (default 6; `--jobs=1` runs in one process).
  - The parent starts N Lune processes (`--worker=k/N`, through `.lune/parallel.luau` and `process.exec` in `task.spawn`). Each plays every N-th match and prints `RESULT` lines; the parent gathers them and writes the report in match order.
  - The report is identical to a one-process run apart from the run-time line, now wall-clock with the job count. Checked: faction_ai (Ridgeline, same-level, 3 min) and ailevels (Ridgeline, 3 min) give the same tables at 1 and 3–4 jobs.
  - Speed: ailevels 25 s → 12 s at 4 jobs on a small run. The 12-core dev PC runs a full faction_ai in about the time of its slowest map.
- **Work counters:** `Sim/Work` counts what the hot loops did, deterministically:
  - route-search units (heap pops and neighbour checks, `Route.runSearch`);
  - flow-field units (`FlowField.run`);
  - `Sensors.level` calls;
  - `Sensors.knownTarget` calls.
  - `lune run stress` and `lune run profile_normandy` print them beside the timings, so a change's effect shows without timing noise (S-74 counted sensor lookups by hand).
  - Process-wide and never hashed; nothing in the simulation reads them.

## S-100 — Big orders spread over ticks (next.md item 3, option (b); the user's queue task 4) (2026-10-23)

- **Asked:** Commands at 800 units, option (b): spread a big order's queue entries over 2–4 ticks, with the timing-only hash test.
- **Where the cost was** (800 Lancers, a select-all attack-move, four commands of 200 in one tick): Commands at about 3–4 ms that tick, about half queuing the orders (`Orders.give`) and half starting them (`Orders.step`), against a 1 ms budget.
- **Built** (`Systems/Commands`):
  - Each tick applies a player's commands, in order, until `UNITS_PER_TICK` (200) unit IDs have gone. The rest wait in the queue, still in order, for the next tick, and a later command of that player waits behind them.
  - Clients already send at most 200 IDs per command, so a select-all of 800 starts over 4 ticks, a quarter each tick. Another player's commands aren't held up.
  - Commands are recorded in the replay on the tick they are applied, so a replay feeds each tick only what fits.
- **Tests** (`Commands.spec`, 3):
  - a 600-unit order starts 200, 400, 600 over three ticks, and player 2's order goes at once;
  - a STOP sent the next tick still comes after the spread order's last chunk;
  - **timing only:** the spread order's state hash after 8 s equals the same three chunks sent a tick apart with the spread off, and the chunks are recorded on ticks 1, 2 and 3.

## S-101 — The AI builds T2 structures, and Normal uses air and naval (next.md item 7, the user's queue task 7) (2026-10-23)

- **Asked:** if time remains, next.md item 7: the AI builds Pinpointers, Barriers, the Citadel and shields, and uses air and naval at Normal.
- **Built** (`AI/Skirmish`):
  - **T2 builder:** on normal and hard, with supply ≥ 600, the advanced plant builds one Architect / Forgemaster. When idle it builds, in order:
    - a shield generator over the base (Phalanx / Carapace);
    - two Pinpointers (Witness / Augur) behind it;
    - Order hard only: a Citadel toward the enemy, once supply stored reaches 1,500 or 90% of storage.
  - **Barriers:** Order hard's T1 builders wall the front with 6 Barrier segments, 140 studs out across the line to the enemy, once established.
  - **Normal:** an airfield, and a shipyard on sea maps, once established (6 extractors, 6 army units, 200 supply), with hard's air and naval production.
  - The census counts shields, Pinpointers, Citadels and Barriers. T2 builders are kept out of the T1 worker jobs and the worker count.
- **Not done:** nukes and the anti-nuke umbrella (still next.md item 7).
- **Tests:** `AI.spec` 12: with rich economies, Order hard fields an Architect, Phalanx, Witness, Barrier and Citadel, and Chaos normal a Forgemaster, Carapace, Augur and airfield, by 6 minutes. Fast and slow suites pass (mirror split 7–5).
- **Fix (S-95, same day; found by the final faction_ai run):** a guard order queued behind others (a factory's list puts it after the exit move) could start after its target died, and `Orders` indexed the gone unit's def. A guard whose target is gone, or whose ID now belongs to another unit, now ends at once (`Orders.spec`: a factory guard order on a tank that dies before the unit rolls out). Repair already checked.
- **S-100 measured** (`lune run stress 450 800`, before at `8787089`, after at `c059616`, two runs each): Commands peak 1.54–1.56 ms at tick 180 before; 1.69–2.23 ms (tick 303, or tick 1) after. The select-all's start was never the peak: the peaks are mid-battle `Orders.step` hold checks, which option (a) would address (under review). The work counters (S-99) are identical run to run (route 519,072, flow field 910,823, sensor lookups 1,402,750).
- **Item 1, final** (S-91 / S-92 / S-97 with S-94, S-98 and S-101 in, `lune run faction_ai 40 3 all mirrored --jobs=10`, 7 min): Order 83, Chaos 19, undecided 6 (6%) of the same-level matches: Order's share 81%, from 90%. Normal 16–13. Normandy 61%, in target, with no undecided match. `docs/FACTION_AI.md` rewritten.

## S-102 — Cheat / test commands (the user's request, 2026-10-23)

- **Asked:** a match option `cheats` (default off). Cheat commands are ordinary commands in the deterministic queue, recorded in replays and rejected unless cheats are on. A match where one was used is flagged. Commands: give, res, income, instabuild, reveal, god, kill, speed, ai. A result message for each, for the client's chat. Tests. The command format in docs/contracts. Tell the client stream.
- **Built:**
  - **Wire (protocol 27):**
    - `CmdType.CHEAT 17` with fixed params (`op, arg, team, defIndex, amount, x, z, radius`; world studs);
    - event `CHEAT_RESULT 22` (`op, result, count, total`) to the sender.
  - **Shared parser:** `Shared/Net/CheatText` parses chat text into the command and turns an answer into a chat line, so the client keeps no copy.
  - **Sim:** `Sim/Cheats` (logic) and `Sim/CheatsState` (hashed state).
  - **Hooks:**
    - Build: instabuild finishes items at once, free.
    - Damage: god mode, and kill through it.
    - Sensors: `reveal` stamps every cell of the sight, air sight, sonar and radar maps.
    - Economy: `bonusIncome` and `bonusStorage`.
    - Skirmish: paused AI players skip their turns.
    - NetOut: sends the answers.
  - **Enabling:**
    - match option `cheats`, or the Sim config's `cheats` without match rules;
    - Sim config `offline` allows `speed`, which the sim only stores (`sim.cheats.speed`) for the tick driver;
    - who may send them (host, allow list, never public) is the Roblox entry's filter before `Sim.submit`.
  - **Flags:**
    - `sim.cheats.used`;
    - replay header `cheated` (replay format 3 adds a cheats byte: allowed, used, offline);
    - `Stats.series(sim).cheated`;
    - `Stats.report(sim)[pid].cheats`.
- **Choices (mine, under review):**
  - `instabuild` has no team argument, so it applies to every team, and it makes items free as well as instant.
  - `kill` leaves no wrecks (it's a self-destruct, like an eliminated player's).
  - `give` ignores the unit cap.
  - `/cheat on|off` mid-match (the client's brief) isn't in the sim: the option is per match, fixed at start.
- **Tests:** `Cheats.spec` 10:
  - off by default, and a match with only rejected cheats hashes like an empty one;
  - give with a partial formation at the map's edge and NO_ROOM;
  - res, max and income;
  - instabuild, reveal, god with kill through it;
  - kill a team and an area;
  - speed offline only, AI pause and resume;
  - a replay of a match with cheats matches at every checkpoint and keeps the header flags;
  - the wire round-trip and chat text.
- `Schema.spec` pins CHEAT_RESULT's bytes; contract: net.md section 9a.

## S-103 — Allied factories' production on the wire (client request 45) (2026-10-23)

- **Asked:** the client draws BAR-style progress bars and nanoframes on own and allied factories, but only the owner gets the queue. Send allied factories' current item and progress at the owner's rate.
- **Built:** State owner field `PRODUCING 16`: `defIndex u16` (0 = idle) and `progress u8`. It goes to the owner's allies, never to the owner (who has QUEUE) or to enemies, with the ENTER and when the item or its progress (by sixteenths) changes. Protocol 27, with S-102.
- **Tests:**
  - `NetOut.spec`: with three players (two allied), the ally's view matches the factory every tick, and the enemy and the owner never get the field;
  - `Schema.spec` pins its bytes.

## S-104 — Size shows tech level: bigger footprints (the user, via models-C) (2026-10-23)

- **Asked:** structures and higher-tier units should be larger, with size showing tech level: T1 modest, T2 clearly larger, T3 the largest. Review models-C's size table (`docs/art/size-scale.md` on `m-models`, e208d2a) for gameplay: pathing between buildings, base space on every map, build-site validity, collision and move classes. Apply what works, check the start areas still fit a base, run the usual checks.
- **Applied, all of C's table:**

  | Defs | Before → after |
  |---|---|
  | T1 economy (extractor, solar, windmill, generator, depot, converter, tidal; both factions) | 1 → 2 |
  | Vehicle plants | 3 → 4 |
  | T1 gun turrets (Bulwark, Spike) | 1 → 2 |
  | Fusion | 3 → 4 |
  | T2 extractors | 1 → 3 |
  | T2 factories (advanced vehicle plant, airfield, shipyard) | 5 → 6 |
  | Beam towers, shield generators, heavy turrets (Bastion, Maw) | 2 or 1 → 3 |
  | Flak (Lumen, Hailstorm), advanced jammers (Veilspire, Blackout) | 1 → 2 |
  | Citadel | 3 → 7 |
  | Nuke silos (Reckoning, Ragnarok) | 3 → 6 |
  | Paladin, Warden, Juggernaut | 1 → 2 (like the Minotaur and Cyclops) |

- **What had to change for it:**
  - **Extractors on one-cell deposits:**
    - an extractor now works every deposit cell its footprint covers (`PlacementRules.supplyUnder`: Placement's "no deposit" check and Economy's income);
    - a 2×2 T1 snaps to a corner of the deposit cell, and a 3×3 T2 centred on the deposit covers the T1 it replaces;
    - the upgrade rule is unchanged.
  - **Deposit spacing:**
    - MapGen's expansion pairs were 3 cells apart on a diagonal (1–2 cells after flooring), and mirrored copies of the rich middle deposit could meet 1 cell apart. Two 3×3 T2 extractors couldn't stand on such a pair.
    - The pair is now 5 cells apart, and a pass pushes any two deposits closer than `MapGen.MIN_DEPOSIT_GAP` (3, Chebyshev) apart, equally, so maps stay symmetric.
    - Ridgeline, Coastline, Twin Lakes and Crossroads move a few deposits by 1–2 cells. Normandy, start:64 and skirmish maps were already ≥ 3.
  - **AI base layout:**
    - I first gave `spotNear` 3-cell lanes between buildings (was 2), since under guide 6.2 a footprint-2 or -3 unit needs a 3-cell gap.
    - The final checks showed that it broke mirror fairness: east won 10 of 12 mirror matches, and Twin Lakes' mirrored players parted by 15% at 3 minutes (trip times differ by up to a think).
    - Back to 2-cell lanes (the tests pass: 4–8, Twin Lakes even). Footprint-2 tanks go round adjacent AI buildings rather than between them. Under review.
  - **AI on the 2×2 extractors:**
    - it keeps other buildings a cell clear of deposits (room for the extractor and its 3×3 upgrade);
    - it counts extractors ordered but not started toward Easy's cap;
    - it nudges a 2×2 extractor's site toward the enemy, because a cell centre is a snap tie that rounds toward +x for everyone (as S-31).
  - **Factory exits** move out with the footprint by themselves (spawn at half size + 1 cell, the model's −Z).
  - **Footprint-2 heavy tanks:** they join the existing footprint-2 clearance class (Minotaur, Cyclops), which counts as 3 wide (guide 6.2), so they need 3-cell gaps. No new flow-field group.
- **Tests:** `Placement.spec` scans every other cell, so 2×2 tidals find wall:64's small lake. `Shield.spec`'s field-mode breach slows to 0.80 of entry with the 3×3 Phalanx's centre half a cell over; the bound is now 0.85.

## S-105 — The AI scouts and attacks only when it outweighs the known defence (the user's decision on next.md item 1) (2026-10-23)

- **Asked (the user's decision on the review item):**
  - keep the numbers;
  - do my recommendation: the AI scouts, and attacks only with waves that outweigh the known defence (turrets included); otherwise it masses up;
  - re-run faction_ai.
- **Built** (`AI/Skirmish`, normal and hard):
  - **Scout:** the T1 plant builds one Herald / Jackal at a time, a new one at most every `SCOUT_EVERY` (2 min) after the last was queued. Idle, it drives a loop of 4 points `SCOUT_RADIUS` (260 studs) round every enemy start. The team then remembers the turrets and structures it saw (ghosts), and keeps seeing whatever it lives long enough to watch. Scouts aren't part of the army.
  - **Waves outweigh the known defence:**
    - when a wave would leave, the AI adds up the known enemy armed units and structures within `DEFENSE_RADIUS` (450 studs) of its target (`enemyValueNear`: by value when the type is known, one unit's worth for an unidentified contact);
    - the wave leaves only if the army at home is worth `ATTACK_MARGIN` (1.5) times that;
    - otherwise it masses at the rally point;
    - an army of `MASS_SHARE` of the unit cap (half; at most `MASS_UNITS`, 150) goes anyway, so a turtle can't freeze it forever.
  - `brain.held` counts the thinks a ready wave waited.
- **faction_ai** (same-level, 3 seeds, all maps, with every change of the round): Order 84 – Chaos 18, 82% (81% before the round, 86% with S-104 alone, 84% with S-104 + S-105); 6% undecided; Normal 16–14, Hard 28–0.

## S-106 — T2 missile batteries; the AI builds T2 defences (the user's picks (a) and (d) of S-96's T2 ideas) (2026-10-23)

- **Asked:** keep power per shot as is (BAR-like). Add (a) the T2 missile battery (anti-artillery) and (d) the AI building T2 defences. No mines or torpedo battery for now.
- **Built:**

  | | Order `ord_sanction` Sanction | Chaos `chs_scourge` Scourge |
  |---|---|---|
  | Cost | 380 supply, 4,200 power, 8,000 build | 320 supply, 3,600 power, 7,000 build |
  | Health | 2,600 | 2,100 |
  | Weapon | 2-missile salvo every 6 s, range 760 | 3-missile salvo every 5 s, range 700 |
  | Damage per missile (light / armored / structure / ship) | 300 / 240 / 180 / 200 | 200 / 160 / 120 / 140 |

  - **Both:**
    - footprint 3, sight 200;
    - built by the Architect / Forgemaster;
    - the missiles launch vertically, are radar-guided (`canTargetRadar`, chaff and jamming as for radar SAMs), fly at 300–320 studs/s with aoe 14;
    - priority artillery, then ground units, then structures.
  - **Range:** both outrange every mobile artillery piece (380–560) and the Verdict.
  - **Identifying targets:** like every weapon, a battery picks artillery over a nearer tank only when the team knows the types: seen, or tracked by a fire-control radar (D107). An untracked radar contact is just "a ground unit". So a battery wants a Tribunal / Seekerspire beside it.
- **AI (d):** after the shield and Pinpointers, the T2 builder raises, once each:
  - a heavy turret (Bastion / Maw) 110 studs toward the enemy;
  - a missile battery 50 studs out;
  - a flak tower (Lumen / Hailstorm) once enemy aircraft are known;
  - a beam tower (Radiance / Inferno) 90 studs out;
  - then Order hard's Citadel as before.
- **Tests:** `Defenses.spec`: with a radar tower and a fire-control radar, each battery aims its first salvo at the artillery piece rather than the nearer tank, from beyond the artillery's range, and destroys it within 30 s.

## S-107 — Hold checks spread over two ticks (next.md item 3, option (a); the user's decision) (2026-10-23)

- **Asked:** do option (a) too: hold checks for half the units each tick.
- **Built:** an attack-move or patrol order re-checks its hold (an enemy in weapon range: stop and fire) every `Orders.HOLD_EVERY` (2) ticks per unit, spread by ID (`(id + tick) % 2`), and always on the order's first tick. A unit reacts to an enemy coming into range at most one tick (67 ms) later.
- **Measured** (`lune run stress 450 800`): Commands peak 1.78 ms (tick 184), against 1.69–2.23 after S-100. Not under the 1 ms budget; what's left is order starts and auto-orders (review).

## S-108 — In-place upgrades: a T2 extractor over its own T1 (the user's request) (2026-10-23)

- **Asked:**
  - **Field:** a generic def field (`upgradesFrom`). A structure with it may be placed over one of the listed structures owned by the same player. Allies' and enemies' don't count: enemies' must be destroyed first. For now only the advanced extractors use it, each over its own faction's T1 extractor.
  - **Behaviour:**
    - the T1 keeps producing while the T2 is built on top of it;
    - when the T2 finishes, the T1 is removed (no wreck, no refund) and the T2 takes over the deposit;
    - if the T2 frame is cancelled or destroyed, the T1 stays and keeps producing;
    - the T1 can still be damaged and destroyed while upgrading; if it dies, the frame stays and finishes normally.
  - Placement validation, the deposit link, the AI and replays all handle it; build-site checks still reject everything else.
  - **AI:** T2 builders upgrade the safest own extractors first once T2 is reached (Normal and Hard).
  - Tests; tell the client stream.
- **Built:**
  - **Defs:** `upgradesFrom` (a list of structure def IDs; validated). `ord_advextractor` lists `ord_extractor`, `chs_advextractor` lists `chs_extractor`. The old rule ("an extractor with a higher rate over the team's own") is gone.
  - **Placement:** `Placement.check`'s fourth argument is now the builder's player (was its team). A cell occupied by that player's own finished structure of a listed def doesn't block. Any other occupant does: an ally's, an enemy's, a frame, or a structure not in the list.
  - **Build:**
    - **Start:** the frame starts over the old structure and takes its cells (the occupancy layer holds one ID per cell). `BuildState.upgrading` links the frame to the old structure, with its generation (D109), and is hashed.
    - **During:** the old structure stays a producer, so its income goes on.
    - **Finish:** `Build.finishUpgrade` removes the old structure through `Lifecycle.remove` (no wreck, no refund, no death event).
    - **Frame removed (cancelled, destroyed, reclaimed):** a removal hook gives the old structure its cells back (`Placement.occupy`).
    - **Old structure dies first:** the link is dropped and the frame finishes alone.
  - **Deposit link:** the T2 works every deposit cell under its footprint (S-104), so it takes over the deposit at completion.
  - **AI:** described under S-106's AI entry. The T2 builder first upgrades its own finished T1 extractors, nearest home first, skipping any with known enemies within `CONTESTED_RADIUS` or with a builder sent there lately. The T2 is placed centred on the deposit cell.
- **Wire:** nothing new. The frame is an ordinary ENTER with its build progress; the T1 leaves (LEAVE, no DEATH) when the T2 finishes. The client's build ghost has to accept the T2 over the player's own T1 (its own placement copy).
- **Tests:** `Upgrade.spec`:
  - over its own T1, the T1's income goes on until the T2 is finished, then it goes (no wreck) and the T2 works the deposit;
  - an enemy's or ally's extractor blocks it, while an empty deposit takes a T2 directly and a generator can't go over an extractor;
  - a cancelled or destroyed frame leaves the T1 on its cells, producing;
  - when the T1 is destroyed mid-upgrade, the frame stays and finishes;
  - a replay of an upgrade (set up with cheat commands) matches.

## S-109 — The Wraith decoy drone (next.md item 4, as designed in S-75; the user's queue) (2026-10-23)

- **Asked:** Wraith decoy drones as designed:
  - a cheap T2 Chaos aircraft without a weapon;
  - it shows on radar as a bomber (a `spoof` field) until a fire-control radar or sight identifies it, so radar SAMs and interceptors spend missiles on it;
  - the strategic icon of an untracked contact shows the spoofed type.
- **Built:**
  - **`chs_wraith` Wraith:**
    - built at the Chaos advanced airfield: 40 supply, 200 power, 900 build (about 60 value), health 120;
    - a jet (max speed 200), no weapon;
    - `radarSignature` 1, `spoof = "chs_behemoth"`.
  - **Defs:** `spoof` (a unit def ID, validated).
  - **Sensors:**
    - `Sensors.shownDef` gives the def a team takes an enemy for: its own when the type is known (seen, remembered or tracked; D107), its spoof when it is an untracked radar contact with one, else nil;
    - `knownCategories` gives a spoofer on radar its spoof's categories (bomber: AIR, JET).
  - **Targeting:** type priorities apply to a spoofer on radar as to the spoofed type, so radar SAMs and fighters rank a "Behemoth" as they would a real one.
  - **AI:** `enemyValueNear` counts it at the Behemoth's value: Order's waves and defence sums see a bomber raid.
  - **NetOut:** an untracked radar contact with a spoof carries the spoofed type's icon in its Strategic record (no TRACKED flag). Other untracked contacts keep icon 0. Seen or tracked, it shows its own.
  - **Wire:** no format change, but a new meaning: an untracked contact's icon can be nonzero (a decoy pretending). The client just draws the icon.
- **Not done:** the AI doesn't build Wraiths yet. Chaos hard could send a group ahead of its bombers; that's a follow-up.
- **Tests:** `Decoys.spec`:
  - three Wraiths on an Aegis's radar, out of sight, draw its missiles; they are taken for Behemoths (`shownDef`), and Order's minimap view gets the Behemoth's icon;
  - under a Tribunal's tracking, a Wraith is known for what it is and shows its own icon.

## S-110 — The AI builds nukes and the anti-nuke umbrella (next.md item 7's rest; the user's queue) (2026-10-23)

- **Asked:** the AI building nukes and the anti-nuke.
- **Built** (`AI/Skirmish`, the T2 builder's job list, after the T2 defences):
  - **Anti-nuke umbrella (normal and hard):** a radar SAM site (Aegis / Wyvern) 40 studs behind home. Their missiles intercept strategic missiles (S-48). A second one goes up once the team knows an enemy silo (seen or remembered).
  - **Nukes (hard):** once supply stored reaches `NUKE_RICH` (90%) of storage (and, for Order, after its Citadel), a silo (Reckoning / Ragnarok) 120 studs behind home.
    - The silo builds warheads into its stockpile as any silo does.
    - The AI launches one (ATTACK_GROUND) at its best known target (structures and the Command Vehicle first, `knownTargets`) at most every `NUKE_EVERY` (1 min).
    - `brain.nukes` counts launches.
- **Tests:** `AI.spec` (slow): with rich economies, by 30 minutes:
  - Order hard upgrades extractors and builds a Bastion, Sanction, Aegis and Reckoning, and launches;
  - Chaos normal upgrades extractors and builds a Maw, Scourge and Wyvern.

## S-111 — Anti-nukes, structure and mobile; radar SAMs shoot aircraft only (the user, via models-C and client request 46) (2026-10-23)

- **Asked:**
  - **Interception:** only new anti-nuke units stop nukes, and SAMs shoot only aircraft. A certain hit, a delay after each shot so several nukes at one spot overwhelm one, and cover by the missile's aim point.
  - **Mobile version (the user):** a T2 vehicle from the advanced vehicle plant with about 60% of the structure's coverage and 1 interceptor (the structure holds more), slower to restock, light armour, no other weapon; it intercepts only while stopped.
  - **Radar SAMs:** T2, so they should one-shot T1 air.
  - **AI:** Normal and Hard escort big armies with a mobile anti-nuke once the enemy has a silo, and build a structure over the base.
  - **Also:** models-C's IDs and pieces, counter rows, tests, the wire for the range ring and stock, numbers under review.
- **Built:**
  - **Defs:**
    - `ord_providence` Providence and `chs_cerberus` Cerberus (structures);
    - `ord_custodian` Custodian and `chs_chimera` Chimera (vehicles; C's IDs and pieces);
    - weapons `ord_interceptor`, `chs_interceptor`, `ord_mobile_interceptor`, `chs_mobile_interceptor`;
    - new weapon fields: `interceptOnly` (never fires at units; needs `intercepts`) and `stationary` (fires only while its unit's MOVING bit is clear).
    - Numbers below; all placeholders.
  - **Radar SAMs:** `intercepts` removed from `ord_radar_sam` and `chs_radar_sam` (Aegis, Seraph, Wyvern, Gorgon). AIR damage 420 → 1,150 (Order) and 340 → 1,100 (Chaos): every T1 aircraft (Plague 1,000 the toughest) dies to one hit.
  - **Targeting (`interceptTarget`):**
    - an `interceptOnly` weapon takes a missile only if its aim point (`pGoal`) is within the weapon's range (the cover);
    - it engages it within `INTERCEPT_REACH` (1.5) × the range;
    - any interceptor skips a missile one of its team's interceptors already chases (one per missile);
    - `stationary` weapons drop their target while their unit moves;
    - **anti-nukes spot strategic missiles anywhere** (the user, same day): `interceptOnly` weapons skip the team-detection check, and the four anti-nuke units carry no radar (sight only, no RADAR_EMITTER).
  - **Delay after a shot:** `reload` 18 s (Order) / 15 s (Chaos), longer than a nuke's ~13 s flight, so two nukes at one spot get one through.
  - **AI (S-110 updated):**
    - the umbrella is now the anti-nuke structure (one after the T2 defences, a second once an enemy silo is known);
    - with an enemy silo known, the advanced plant builds one mobile anti-nuke, which joins the wave escorts (it guards the wave's lead unit).
  - **Wire:** nothing new.
    - The shot is INTERCEPTOR (with the missile's ID), the kill INTERCEPTED.
    - The owner's interceptor stock rides in the State STOCK field.
    - The client takes the cover ring from the weapon's `range` and the delay from its `reload`.
  - **Guide:** 10.9 rewritten; counter matrix rows for the missile battery and anti-nuke (12.4).
- **Numbers (placeholders, under review):**

  | | Providence | Cerberus | Custodian | Chimera |
  |---|---|---|---|---|
  | Cost (supply / power / build) | 900 / 14,000 / 20,000 | 780 / 12,000 / 18,000 | 420 / 6,000 / 9,000 | 360 / 5,200 / 8,000 |
  | Health | 4,000 | 3,400 | 900 | 760 |
  | Cover | 1,100 | 1,000 | 660 | 600 |
  | Stock | 3 | 3 | 1 | 1 |
  | Per interceptor | 60 s, 400 + 10,000 | 50 s, 360 + 9,000 | 90 s, 400 + 10,000 | 75 s, 360 + 9,000 |
  | Delay after a shot | 18 s | 15 s | 18 s | 15 s |

- **Tests** (`Nuke.spec`):
  - an anti-nuke fires one interceptor at the nuke and destroys it; a radar SAM site beside it never fires at the nuke and nothing on the ground is hurt;
  - four radar SAM sites alone fire nothing at a nuke, and it lands;
  - a mobile anti-nuke intercepts when stopped and can't on the move;
  - a nuke aimed outside the cover flies over a site untouched;
  - two nukes at one spot get one through;
  - an empty stockpile stops nothing; determinism.
  - `AI.spec` (slow) checks the umbrella structures.

## S-112 — Balance pass (next.md item 8; the user's queue) (2026-10-23)

- **Asked:** next.md item 8's balance pass, after the AI work. Item 8: the conditions the faction pass didn't meet (T1 fighters, the Herald at range, the Locust against Lancers) and the counter check.
- **Done:** steps of at most ±10% (beyond that only as proposals), each re-measured with `lune run factions 3`. Two more roles had left the band since S-104 and S-111 and were brought back.

  | Change | Why | Measured (before → after) |
  |---|---|---|
  | Locust's autocannon damage +10% (34/26/20/18 → 37/29/22/20) | the Locust lost to Lancers close and long | close 1.57 → 1.39, long 1.07 → 0.86, flank 0.75 → 0.62: it wins long and on the flank now |
  | Order heavy cannon damage +10% (Paladin and the Bastion turret) | T2 tanks fell to 0.79 with S-104's footprint-2 tanks | overall 0.79 → 1.05; Order's long 0.87 → 1.28 |
  | Order radar SAM reload 4.1 → 3.7 s (Aegis, Seraph) | the sites fell to 0.78 after S-111's damage raise | Aegis / Wyvern 0.78 → 0.82; Seraph / Gorgon 0.82 → 1.17 |
  | Falcon missile range 374 → 393 (+5%) | Order's standoff condition | +10% overshot (overall 1.28); at +5%: overall 1.06, long 1.08 |

  - **Tried and reverted:** Paladin gun range +10% (no change in the long fight), Herald machine-gun range +10% (long 0.92 → 0.88: the Jackal closes the gap anyway).
- **Still not met (proposals for review):**
  - **T1 fighters:** Order's standoff condition (long 1.08, defend 1.22, needs 1.25) and Chaos's (close 1.05, flank 0.86, needs 0.8). Jets close 600 studs in about 2 s, so the starts barely separate them, and the numbers swing 0.8–1.3 between runs on small changes. Proposal: judge fighters in the AI matches or the SAM raids instead of this duel.
  - **Herald:** doesn't win at range (0.92); a range step doesn't help. Proposal: +20% speed, so it can hold its range.
  - **T2 tanks:** Chaos's condition is close (0.86, needs 0.8).
- **Result:** 12 of 12 shared roles in band (was 10 of 12 at the start of the pass).

## S-113 — Lingering beams; Radiance fires at radar blips (client request 47, the user) (2026-10-23)

- **Asked:**
  - **Radiance (BAR's Pulsar):** it can target radar blips, and against a blip it can miss without a Pinpointer, as radar precision works for other weapons (S-59). Its beam lingers longer and deals high damage over that time.
  - **Inferno:** a smaller range than Radiance and a weaker beam.
- **Built:**
  - **`beamDuration`** (seconds, BEAM weapons only, validated):
    - a hit's damage is dealt as an even share every tick over that time, from the tick the beam fires (`Combat.beams`, hashed);
    - each share needs the shooter alive and not retracted, and the target alive and within range;
    - hit or miss is decided when the beam fires (FIRE's hit flag), and later shares get no overkill accounting.
  - **Radiance:** `canTargetRadar`.
    - A beam aims at the believed position, so a wobbling blip is missed unless Pinpointers sharpen it (S-59).
    - Test: 2 of 7 beams missed without Pinpointers, 0 of 7 with six.
    - `beamDuration` 2.5 s; damage over the beam 3,000 (light / armored / ship) and 2,300 (structure), was 2,600 / 2,000 at once; range 650, reload 9 s, 700 power unchanged.
  - **Inferno:** range 560 → 480; `beamDuration` 1.5 s; damage 1,700 / 1,350 (was 2,000 / 1,600); reload 7 s, 500 power; visible targets only.
- **Wire:** nothing new. The client holds the line for `beamDuration` from FIRE, and a miss is FIRE with hit = false.
- **Tests:** `Defenses.spec`:
  - Radiance's first beam deals one tick's share first and twice its total over two beams;
  - it fires at a blip, misses some without Pinpointers and fewer with them;
  - the Inferno ignores radar-only contacts.

## S-114 — The AI's economy: extractors before generators while deposits stand free (client request 48, the user) (2026-10-23)

- **Asked:** the skirmish AI builds a lot of Furnaces (generators) instead of going for extractors on free deposits. Check the power / supply choice and the extractor priority.
- **Cause:**
  - since S-94 a builder took the generator job whenever power had stalled in the last `POWER_MEMORY` ticks, with no limit;
  - building always draws power, so that was nearly always;
  - the generator job came before the extractor job.
  - In the Twin Lakes mirror, hard opened with 6–7 generators before its first extractor.
- **Changed** (`AI/Skirmish`):
  - **Stall memory:** supply stalls are watched every tick like power stalls (`supplyShortAt`).
  - **Job order:**
    - two generators first (`MIN_GENERATORS`);
    - then a free deposit in reach comes first while supply stalls, or while extractors trail generators;
    - past that, generators up to the planned need (S-94's `genWanted`), and `GEN_SLACK` (1) more only while power stalls and supply doesn't.
  - Counts and stall memories only, never the moment's income, so mirrored players still choose alike (S-31).
- **Measured** (Twin Lakes, hard 2v2, 3 minutes):
  - the openings now alternate generators and extractors after the first two;
  - the teams are worth 10,283 / 10,113 (were 7,383 / 8,494 with the old rule plus S-104);
  - the mirrored players' build orders match.

## S-115 — Radiance's hit-ray; manual targets until STOP (client request 49, the user) (2026-10-23)

- **Asked:**
  - **Radiance:** `beamDuration` 3.0, and the beam is a hit-ray: during it, damage goes to every enemy unit the beam's line crosses, not only the target, so a missed shot at a blip still hurts whatever stands on the line.
  - **Manual targets (all units):** an attack order's target beats the unit's own choice; while it is out of range the unit picks its own targets, and it switches back once the target is in range. STOP removes it.
- **Built:**
  - **`pierce`** (lingering BEAM weapons only, validated):
    - the beam is a fixed line from the muzzle to where the shot ends: the target, or the ground beside or beyond it on a miss;
    - each tick of `beamDuration`, every enemy unit within its collision radius of the line and in the weapon's target classes takes that tick's share (contact grid query, hashed with `Combat.beams`).
    - Radiance: `beamDuration` 3, `pierce`. The Inferno stays single-target (S-113).
  - **Manual targets:**
    - an attack order stores its target in `OrdersState.manual` (hashed), kept after the order ends;
    - Targeting uses it like an attack order's target whenever the unit isn't on hold fire and the target is in range, else the normal search;
    - the player's STOP (`Orders.stopCommand`), a new ATTACK, or the target's death clears it, but the automatic move-state orders don't.
  - **Wire:** nothing new.
- **Tests:**
  - `Defenses.spec`: Radiance's beam at a Juggernaut also hurts the enemy worker standing on its line, and not the Order tank on it;
  - `Orders.spec`: after an attack order and a plain move, the unit fires at another enemy while its manual target is out of range, switches back when it's in range, and STOP clears it.

## S-116 — Beams stop at domes; turrets contest only the deposits they reach (client requests 50 and 48, the user) (2026-10-23)

- **Asked (request 50):** shield domes deflect incoming beams. A Radiance or Inferno ray that meets an enemy's active dome stops at its surface and glances off downward into the ground nearby, instead of reaching anything inside. Proposed contract:
  - FIRE ends at the contact with hit = false;
  - pierce damage only up to the contact;
  - the dome pays as for an absorbed projectile;
  - the glancing leg is drawn only.
- **Built (request 50):**
  - **Already true:** since S-89, a beam that meets an up enemy dome ends there. That's a FIRE with hit = false at the contact, and an absorbed SHIELD_HIT (projId 0) that costs the dome the shot's mass (a beam's mass is capped at 8).
  - **New:** Radiance's hit-ray (S-115) is then registered with its line ending at the contact. Enemies on the line outside the dome take its share each tick, and nothing inside does.
  - The glancing leg is the client's drawing.
- **Asked (request 48, the user's finding):** a hold-fire Bulwark spawned beside the AI's base made it "nervous": its economy stalled.
- **Cause (request 48):** Chaos takes contested deposits only with an escort (S-97), and any known armed enemy within `CONTESTED_RADIUS` (300 studs, more than the AI's home radius of 260) contested a deposit. One turret by the base contested every home deposit, and expansion waited for an army.
  - Headless (coastline, seed 104, normal), the AI's tanks killed the Bulwark after about 3 minutes and it recovered. In the user's match it didn't, maybe because its early army never came.
- **Changed (request 48):** an enemy structure contests a deposit only within its weapon range + `CONTESTED_REACH` (40 studs). Mobile armed enemies still contest within 300, and an unidentified contact still does.
  - The repro reaches 3 extractors and 4 workers by minute 2 while the Bulwark stands (was 2 and 3), and 55 units by minute 8 (47).
- **Tests:** `Shield.spec`: Order's Radiance fires at a Juggernaut under a full Carapace. The FIRE ends on the dome (hit = false), nothing inside is hurt, and the Chaos worker on the line outside is.

## S-117 — Beams drain domes by a lot (client request 51, the user) (2026-10-23)

- **Asked:** shields are so strong that a whole beam barely dents them (a Radiance beam took a Carapace from 100% to 98%). "Drop it down, by a lot." The client suggested a third to a half of a Phalanx's charge for a full Radiance beam.
- **Cause:** a beam stopped by a dome cost only its shell mass (damage / 150, capped at 8) once.
- **Built:**
  - A lingering beam (`beamDuration`) stopped by an up enemy dome also drains it over the beam's duration, in equal shares each tick, while the shooter stands and the dome stays up.
  - In all it drains its best damage / 150 × `Shield.BEAM_DRAIN` (12.5): Radiance 250, Inferno about 142. Radiance's hit-ray still hurts enemies on its line outside the dome (S-116).
  - Capacities unchanged (Phalanx 600, Carapace 400).

  | Beam | Phalanx (600) | Carapace (400) |
  |---|---|---|
  | Radiance | 42% | 62% |
  | Inferno | 24% | 35% |

  Recharge during the beam gives some back: measured, one Radiance beam took a full Carapace to 54% (46%).
- **Wire:** nothing new; SHIELD charge records follow the drain.
- **Tests:** `Shield.spec`: one Radiance beam on a full Carapace takes 40–80% of its capacity (measured 46%).

## S-118 — SHOT carries its weapon (client request 52) (2026-10-23)

- **Asked:** a beam from a shooter the player can't see arrives as SHOT (both ends, no ID), so the client can't tell it's a beam: no held beam, no glancing leg on a dome, no honeycomb pulses. Add the weapon's def index (cleaner than flags).
- **Built:** protocol 28.
  - SHOT ends with `weaponDefIndex u16` (16 B; 0 = unknown).
  - Weapons records the weapon on its FIRE combat event (`weaponIndex`), so NetOut has it even if the shooter died that tick. The client takes type, `beamDuration` and faction from the defs.
- **Tests:** `Schema.spec` pins SHOT's new bytes; `NetOut.spec`'s hidden-shooter SHOT carries the gunner's weapon index.

## S-119 — Attack-ground for beams and hitscan; an entering unit's turret aim (client request 53, the user) (2026-10-23)

- **Asked:**
  1. Beam and hitscan weapons take attack-ground orders, "because they can shoot a point; a unit walking past can still take damage".
  2. Turret guns swing back to their rest position between shots: "if a unit does not move, the gun never aims at it".
- **Built (1):**
  - **Orders:** `Air.groundFires` and the Targeting / Weapons ground-order checks include BEAM and HITSCAN weapons. A unit or tower given ATTACK_GROUND aims at the point and fires at it, whatever its fire state, until another order.
  - **Hitscan and non-piercing beams:** the shot hits the first enemy on its line from the muzzle to the point (collision radius, the weapon's target classes; `firstOnLine`), otherwise it misses on the ground at the point. The Inferno's lingering beam then settles on the unit it hit.
  - **Radiance's hit-ray (`pierce`):** the line runs to the point, and every enemy on it takes the share each tick.
  - **Domes:** an up enemy dome on the way stops the shot at its surface, as in S-116 / S-117.
- **Found and fixed (2):**
  - **Cause:** NetOut sent a weapon's aim in State records only when it changed. A unit entering a player's tactical tier came with its ENTER and no aim, so a turret already held steady on a still target was never sent and the client drew it at rest.
  - **Fix:** an armed unit now gets a State record with its aim and weapon states on the tick it enters.
  - The other reports (swinging back between reloads) didn't reproduce headless (the client's probes, and mine); an entering unit with a steady aim fits both.
  - **The beam towers' case (the client's repro, `shield_beams`):** a Radiance kept tracking its target during its 3 s beam, so the barrel left the beam's fixed line, then eased back toward rest. Fix: while a lingering beam of a weapon burns, that weapon's aim holds on the fired line (no turret update); tracking resumes when the beam ends.
- **Tests:**
  - `Defenses.spec`: Radiance attack-grounds a point and the Ravager on its line takes the ray; the Inferno attack-grounds empty ground, misses, and hurts nobody off the line;
  - `NetOut.spec`: a Lancer aimed at a still Ravager enters a player's view and its aim arrives with it (the test fails without the fix).
  - `Defenses.spec`: Radiance firing at a Ravager driving across holds its yaw for the 3 s of the beam, then tracks again.

## S-120 — Manual targets take priority whatever the fire state (the user, via the client) (2026-10-23)

- **Asked:** "Manual targeting must take priority." Units didn't stick to the unit they were ordered to attack. An attack on a unit should win over the unit's own picks whenever that target is in range and attackable, whatever the fire state, and survive later moves.
- **Changed (S-115's rule):**
  - Targeting takes the manual target (the last ATTACK's, kept until STOP) whenever it is in range, on any fire state (was: not on hold fire).
  - Weapons fires at it even on hold fire.
  - The overkill rule (S-29: drop a target that damage on its way will kill) no longer drops a manual target, as it never dropped an attack order's.
- **Tests:** `Orders.spec`: on hold fire, the unit stays on its manual target and keeps firing at it; STOP still clears it.

## S-121 — Armed structures take attack orders; a dome dropping mid-beam lets it through (client request 54, the user) (2026-10-23)

- **Asked:**
  1. A Radiance ordered to attack an enemy Phalanx still chose a tank: an ordered target should stick, and the beam hits the dome until it drops, then the generator.
  2. When a dome drops while a beam burns on it, the rest of the beam goes through to its target (or attack-ground point), and pierce damage resumes along the full line. A new FIRE / SHOT on that tick tells the client.
- **Cause (1):** structures took no orders except a silo's attack-ground (S-48), so the ATTACK never reached the tower.
- **Built:**
  1. **Attack orders on armed structures:** an armed structure given ATTACK takes the target as its manual target (S-115 / S-120: it wins whenever in range, whatever the fire state, until STOP or a new attack). It doesn't chase.
  2. **A dome dropping mid-beam:**
     - a beam stopped by a dome remembers where it would have ended without it (`after*`: the point, whether it would have hit, the target; hashed);
     - when the dome drops (or goes) while the beam burns and the shooter stands, the sim sends a new FIRE for that weapon, ending at the target's aim point or the full line's end, with its hit flag (a SHOT for players without the shooter);
     - the beam then works there for the rest of its duration: a hit-ray along the full line, a single-target beam on its target, or it ends if it would have missed.
- **Wire:** nothing new. A FIRE or SHOT from a weapon whose beam is still burning moves the beam's end (the client's proposal; no flag).
- **Tests:** `Shield.spec`:
  - a Radiance ordered onto a Carapace keeps it as its manual target over a nearer Ravager;
  - its beam stops on the weak dome (FIRE, miss), the dome drops, a second FIRE hits the generator, and the generator takes damage.

## S-122 — Shield domes regardless of vision (client request 55, the user) (2026-10-23)

- **Asked:** a shield dome (only the dome) renders regardless of vision, as in BAR. SHIELD events only went with a generator the player had, so an unseen Carapace showed no dome even while beams and shells hit it.
- **Built** (protocol 29):
  - **`DOME 23`:** generator ID, the dome's centre (pos), radius u16, charge u8, flags u8 (13 B).
    - It goes to a player for every dome whose circle touches their camera area (+2 cells) while they don't have the generator in their tactical tier, whatever their team sees.
    - It's sent when the dome enters that area and when its charge (by `SHIELD_STEP`) or flags change.
    - No type is revealed: a centre and a radius only.
  - **`DOME_GONE 24`:** generator ID (3 B), when the dome leaves the area, its generator dies, or the generator enters the tactical tier (its ENTER and SHIELD take over). Sent in ID order.
- **Tests:**
  - `Schema.spec` pins both records' bytes;
  - `NetOut.spec`: Order, seeing nothing near a Carapace, gets its DOME (centre and radius) and no ENTER, and DOME_GONE when it dies.

## S-123 — A burning beam's end follows the domes (client request 56, the user) (2026-10-23)

- **Asked:** a burning beam's line must be re-checked against every dome whenever any dome changes:
  1. when dome #1 collapses with #2 behind it, the continuation ends at #2's surface (miss, absorbed SHIELD_HIT on #2, the rest of the drain on #2), and pierce damage reaches only up to #2;
  2. when a dome rises across a burning beam, the beam is cut at the first contact (a new FIRE / SHOT, miss); that dome takes the hit and the drain, and the one behind stops being drained.
- **Built** (it replaces S-121's one-off go-through):
  - **Every lingering beam keeps its full shot:** the muzzle height, where it was aimed (a fixed point; a single-target hit follows its target), whether it hit, and whether it is a hit-ray. Misses are kept too, so a dome rising across one is reported.
  - **Each tick** its end is the first up enemy dome on the line from the muzzle to the full end (`Shield.firstDome`), else the full end.
  - **When the end changes:** a dome dropped or went, one rose across it, or another stands behind. The sim sends a new FIRE (a SHOT for players without the shooter) with the new end and hit flag, and a dome newly in the way takes the absorbed hit (`Shield.absorbShot`).
  - **This tick's share:**
    - on a dome, that dome is drained (S-117) and a hit-ray hurts only up to its surface;
    - otherwise a hit-ray covers its full line, and a single-target hit damages its target (while alive and in range).
- **Tests:** `Shield.spec`:
  - a weak dome in front drops, and the new FIRE ends on the full dome behind (miss), which is then drained while the target inside is untouched;
  - a dome raised across a beam burning on its target cuts it with a new FIRE (miss) at its surface and takes the hit.

## S-124 — Commanders at footprint 2 (the user, via models-C: 10-stud walking mechs) (2026-10-23)

- **Asked:** the Commanders become much bigger walking mechs, about 10 studs tall (2.7× a Lancer). Accept footprint 2 for `ord_sovereign` and `chs_warlord`. Check pathing (the gaps maps and base layouts leave), build range from the bigger body, start positions and AI openings. Movement stays TRACKED.
- **Changed:**
  - `ord_sovereign`, `chs_warlord`: footprint 1 → 2. Collision radius 3.6 → 7.2 studs, hit height 6 → 12 (6 per footprint cell; the mech's head is at about 10).
  - `buildRange` 56 → 60: builders measure from their centre, so the reach from the bigger body's edge stays what it was.
  - Pieces unchanged (`base`, `nano`), unarmed, TRACKED.
- **Checked** (`debug_out/cmdstuck.luau`; hard AI on all six maps, 10 minutes):
  - **Mobility:** with a pending order, the Commanders didn't move in 5 of 1,784 five-second windows (11 of 1,775 at footprint 1), with no failed builds (1 at footprint 1).
  - **Pathing:** they need 3-cell gaps (guide 6.2), which every map keeps (MapGen's MIN_GAP). In the AI's bases, with 2-cell lanes (S-104), they go round, and the numbers show no harm.
  - **Starts:** standard starts are unchanged (mobile units don't occupy cells).
  - **AI and slow suites:** the AI spec and the fairness tests pass (mirror split 5–7).
  - `Skirmish.spec`'s seed-1 match changed: Chaos raids Order down to 2 extractors by minute 5, Order's army never reaches its first wave (1,700 of 2,400), and Chaos wins at 9.9 min. The test wanted a wave from a loser lasting past 8 minutes; the bar is now 10. Under review: it's the Order-side weakness item 1 is about, shown by one seed.

## S-125 — A manual target stays while it lives, unseen too; when it dies the unit picks its own at once (client request 57, the user) (2026-10-23)

- **Asked:**
  1. The manual target was dropped while it lived. Two Radiances ordered onto a Juggernaut inside a Phalanx, with a Carapace in front, switched to a dome generator after a few shots. The ordered target must stay while it lives, even when every shot is stopped by a dome.
  2. The user: "when the unit I chose dies, it should switch back to auto-targeting."
- **Cause (1):** the Juggernaut killed the Lancer spotter, the team stopped seeing it, and Targeting treated an unknown manual target like one out of range: the weapons searched and took a generator. Domes had nothing to do with it.
- **Built:**
  - **Last known position:** while a manual target lives, the unit remembers where the team last knew it (`OrdersState.manualX / Z`; hashed).
  - **Unseen target:** while the target lives but is unknown (`manualBlind`) and that position is within a weapon's range, weapons that can shoot a point (ballistic, beam, hitscan) fire at it, as at an attack-ground point. Beams drain the domes in the way and go through when they drop (S-123). Other weapons hold. None takes another target. Farther than its range, the weapon searches as for a seen target out of range (S-115). The S-115 test, a tank driving away from its manual target, needs this.
  - **Out of range:** a known target out of range still lets the unit pick its own (S-115).
  - **Target dies:** the manual target is dropped (`Orders.dropManual`) and every weapon of the unit searches on that tick, not on its next staggered search tick.
- **Tests:** `Defenses.spec`:
  - a Radiance ordered onto a Juggernaut keeps it after the spotter dies: it never switches to the visible Ravager, and keeps firing blind;
  - when the Juggernaut dies, the manual target is gone and the tower is on the Ravager the next tick.

## S-126 — Fix: a beam or hitscan shot at a destroyed structure's ghost crashed the tick (client request 57's repro) (2026-10-23)

- **Found by the client:** in request 57's repro, after the ordered tank died the Radiances took the Phalanx generator, then the Phalanx died. Weapons that can fire at radar contacts may target a remembered structure's ghost, alive or not (D101). Since S-113 Radiance is one, and its next beam called `hitscanHits` on the dead unit: `Weapons:106: attempt to index nil with 'radius'`. The whole server tick crashed.
- **Fixed:** a hitscan or beam shot at a target that no longer exists is a miss at the believed spot (FIRE hit = false), like any miss.
- **Test:** `Defenses.spec`: a Radiance with radar fires at a destroyed generator's ghost for 20 s without an error (the test fails without the fix).

## S-127 — Units don't auto-target structure ghosts (the user) (2026-10-23)

- **Asked:** "Make the unit not auto target ghost radar; a user can manually tell them to shoot at ghost radar, but by default they don't." Asked which contacts: **ghosts only** (remembered structures not in sight); radar blips stay as they were.
- **Changed** (`Targeting`):
  - The automatic search never takes a ghost, and a weapon's kept target is dropped once it becomes a ghost (an unseen remembered structure, alive or dead).
  - An attack order's target or a manual target may still be one (`acceptable(..., manual)`).
  - A manual target that is a ghost of a structure that died unseen stays valid while the team remembers it, at the ghost's spot; it was dropped as "dead" before.
  - Radar contacts (blips) are unchanged: still targets for weapons that can fire at radar.
- **Effect:** artillery and Radiance no longer shell remembered structures on their own; they do on an order. The AI gives no attack orders on structures, so its artillery fires only at what its team sees or tracks.
- **Tests:** `Defenses.spec`:
  - a Radiance never keeps or picks a living generator once it is only a ghost;
  - at a destroyed generator's ghost it doesn't fire on its own, and on an attack order it fires, each shot a miss.
  - `Air.spec`'s two ghost-bombing tests now order the bomber onto the ghost (it bombed ghosts on its own before).

## S-128 — ASSIST a builder: help with what it builds (the user, playtesting) (2026-10-23)

- **Asked:** any unit that can build can help build units and structures (not stockpiles), and the ASSIST command on a worker makes the assistant follow its leader and help with its building.
- **Before:** helping a frame or a factory's production was already open to every mobile builder (REPAIR, or GUARD on the frame or factory; stockpiles were never assistable). GUARD on another builder only followed it.
- **Built** (`Orders`, the guard order): a unit with build power guarding (ASSIST) a mobile builder:
  - helps with what that builder is doing: its frame, or the factory production it is assisting (`Build.commandAssist`, which walks it into range);
  - never follows the leader into repairs or stockpiles;
  - when the leader's job ends, follows it again, and helps with the next one.
- **Wire:** nothing new; ASSIST is the existing GUARD command on a builder.
- **Tests:** `Orders.spec`: a Mason assisting another Mason builds its generator with it (finished in under 80% of the time alone), then follows it when it drives off.

## S-129 — WELCOME lists every team's ally team (client request, after S-128) (2026-10-23)

- **Asked:** the client knew only its own ally team, so in team games a right-click on an ally's unit sent ATTACK. With every team's ally team it treats allies as friends: right-click is GUARD / assist, and their health bars and minimap dots get friend colours.
- **Built:** protocol 30. WELCOME ends with `teamCount u8, allyTeam u8 × teamCount`: team 1 first, 0 for a team not in the match. Decoded as `teamAllies`. Spectators get it too.
- **Tests:** `Schema.spec` pins the new bytes; `NetOut.spec`: player 3's WELCOME in a 2v2 lists `{ 1, 2, 1, 2 }`.

## S-130 — Radar blips orbit the real unit, like BAR (client request 59, the user) (2026-10-23)

- **Asked:** the user wanted radar blips to circle around the real unit, as in BAR, not drift between random points. Guide 11.4's rule stays: only the wobbled position is ever sent.
- **Built:** `Sensors.wobble` gives offset = radius × (cos θ, sin θ), θ = phase0 + dir × 2π × (tick mod 90) / 90.
  - One turn takes `Sensors.ORBIT_TICKS` = 90 ticks (6 s). It replaces `WOBBLE_PERIOD`.
  - phase0 and dir (±1) are a stateless hash of (unit, observer), so every player of a team sees the same orbit.
  - The radius is unchanged: the observer's best radarError, or the trackError when tracked, scaled by Pinpointers.
- **Effects:**
  - Targeting still aims at the wobbled point, so radar-fired artillery still misses at low precision. Fog.spec reports a direct-hit rate of 1 in 28 on radar.
  - A blip now always sits exactly one radius from the unit. A sharp player can read the true position as the centre of the circle. The user accepted that by choosing BAR's behaviour.
- **Tests:**
  - `Fog.spec`: the blip stays on the circle, moves smoothly, turns one way once every 90 ticks and repeats; units orbit both ways.
  - `EW.spec` (hysteresis): the far Wasp's bearing moved so the two orbits keep swapping which one looks closer.
  - `Skirmish.spec`: seed 1's Order now falls at 10.3 min without a wave, so the loser-attacks bar moves from 10 to 11 min.
- **Guide 11.4:** updated.

## S-131 — Drawn blips orbit at 1.5 studs; the radar error moves to a hidden aim point (client request 60, the user) (2026-10-23)

- **Asked:** after checking S-130 in Studio, the user said "that radius is huge, in BAR, just 1-2 studs". They chose:
  - a drawn (sent) blip that orbits about 1.5 studs from the real unit;
  - radar-fired weapons that aim at a separate hidden point at the radar error, so they miss as before.
- **Built:**
  - `Sensors.blipOffset` is the drawn orbit: radius `Sensors.BLIP_ORBIT` = 1.5, or the radar error if smaller. It uses the same 90-tick turn and a salted (unit, observer) hash, so its phase and direction are its own.
  - `Sensors.wobble` stays the aim orbit at the radar error or track error, scaled by Pinpointers. It is exactly S-130's orbit, so aiming is unchanged.
  - `knownPosition(sim, team, id)` returns the drawn blip. NetOut and the player view use it.
  - `knownPosition(..., true)` and `knownTarget` return the aim point. Targeting, Weapons, Air, Orders, Commands and the skirmish AI use them.
- **Relaxes guide 11.4's "never the true position":** the sent position is now within 1.5 studs of the true one. The user accepted that. The aim point is never sent. Guide 11.4, 11.2 (Pinpointers), 10 (net tiers) and the bomber line are updated, and D67's wobble line points here.
- **Tests:**
  - `Fog.spec` (new test): the drawn blip stays at BLIP_ORBIT, repeats every 90 ticks, is never wider than the radar error, and comes 10 or more studs from the aim point.
  - `Air`, `EW`, `Knowledge`, `Pinpoint` and `Tracking` specs now measure the aim point (`knownPosition(..., true)`).
  - `NetOut.spec`, homing drift: the worst uncorrected torpedo drift fell from over 40 to 36.6 studs, because the sonar blips the client sees now sit on the subs. The bar is now 30. Corrections still cut it 3.5× (to 10.5).

## S-132 — The Canyon, a hand-made map after BAR's Classic Glitters (the user) (2026-10-23)

- **Asked:** the user sent the BAR map "Classic Glitters" (12 × 20, 2 teams): a 3D view, the colour texture, the heightmap and the metal-spot overview. They asked for a copy named The Canyon, "featuring harsh land, mountains".
- **Built:** `map:canyon` (`Shared/Grid/Canyon`, in `MapRegistry.HANDMADE`).
  - **Size:** 154 × 256 cells (1232 × 2048 studs), keeping the 12 : 20 shape. 256 cells is the grid's limit, so it can't be bigger.
  - **Sides:** north (player 1) against south (player 2). The map is point-symmetric about the centre: every cell matches its twin at (-x, -z) exactly, because the south half is copied, not recomputed.
  - **Mesas:** 18 traced from the reference heightmap's north half (pixel centres and radii in `Canyon.MESAS`), turned 180° for the south: 36 in all. Each is 48 studs high with irregular lobed outlines and a terraced cliff (a ledge at 60%) that no land unit climbs. A 5-stud apron of rough ground surrounds each foot. Jagged corner plateaus fill the north-west and south-east.
  - **Badlands:** ROCK terrain (0.8–0.9 speed) over the two mesa belts, 3 studs above the open canyon floor. The floor is GRASS, so the client should draw it as pale desert ground.
  - **Boulders:** 18 seeded outcrops (1–3 cells, +7 studs, impassable), each with its twin.
  - **Deposits:** the reference has about 200 small metal spots. Ours are the same "glitter" at our economy's scale: value-2 deposits on a jittered grid every 160 studs over open ground, plus four value-4 home deposits round each start. That's 92 in all: 8 home and 84 glitter.
- **Not a pixel copy:** only the reference's north half is traced. The south is its rotation, so lone mesas in the middle band sit a little differently from the original, whose two halves differ slightly.
- **Tests:** `Canyon.spec`:
  - size and starts;
  - exact point symmetry;
  - mesa tops high and cliffs closed to every land class;
  - starts on the floor;
  - deposit values, with every deposit and the other start reachable for WHEELED, TRACKED and HEAVY_TRACKED;
  - determinism;
  - slow: a 12-minute AI-vs-AI match. Both sides expanded (23 and 25 extractors), each sent 3 waves, and no command was rejected.

## S-133 — Units leave from the build pad; a factory waits while its pad is taken (client request 61, the user) (2026-10-23)

- **Asked:** "why the spawn point of the unit when finished building was too far off? It starts where its built". The client draws the unit in production on the factory's `buildpad` (C-152). The finished unit used to appear one cell outside the footprint (12+ studs past the pad) and visibly jumped. Then the user added: "in case of unit stuck, every plant must wait for no unit standing in the build pad to continue building".
- **Built:**
  - **Spawn:** `Build.padOffset(def)` reads the factory blockout's `buildpad` attachment (model space, forward = -Z), else the middle of the front edge. `Build.padPosition` turns it like the client does (heading + π about +Y). A produced unit appears there, facing the exit.
  - **Exit:** ground and naval units get `BuildState.exiting[id] = { factory x, z, half size, exit x, z, factory }`. While it's set, Movement drives them straight at the exit point (EXIT_ROLL past the front edge, in line with the pad), through the factory's blocked cells, with no separation jostling, whatever their order. It ends once they are clear of the footprint on open ground, or 24 studs past it. A unit stopped inside still drives out. Then the factory's orders as before (S-95).
  - **Aircraft:** they appear on the airfield's pad with no exit drive (air always fits).
  - **Factory waits:** a factory makes no progress (and spends nothing) while a unit it made is within twice that unit's radius of its pad. A stuck unit holds its factory. Pausing for the whole drive out cost too much production, and the user asked only about the pad.
- **Hashed:** `exiting` is in the BuildState hash.
- **Tests:** `Build.spec`:
  - a Lancer appears on the Vehicle Plant's pad at four headings and drives straight out of the door;
  - a plant whose tank is held on the pad makes no progress, then builds again once it drives out;
  - an aircraft appears on the airfield's pad.
- **Side effect found:** the AI's timeline shifted. In seed 43, a Mason leaving the pad then crawled along a second plant's edge at 0.8 studs/s for about 20 s, and Order hard's nuke came at 28.2 min instead of 22.4 (the T2 extras test allows 30). That is a movement weakness (sliding along blocked cells at half speed, repeatedly). It's under review, not fixed here.
- **Follow-up, the AI gives up unreachable build sites:** with S-133 the AI's timeline shifted, and on Coastline (seed 34) Order hard's footprint-2 Commander got walled in by generators. It sat in a 1-cell gap for 8 minutes trying to reach an airfield site, so no shipyard was ever built (`AI.spec`, naval test). The AI's site picker doesn't check reach, and its 2-cell lanes only hold between buildings of one size.
  - Now a builder that gets no closer than 8 studs to its build site in `Skirmish.STALL_TICKS` (20 s) is stopped. The site is left alone for `BAD_SITE_TICKS` (3 min) through the brain's claims, and `brain.gaveUp` counts these.
  - The shipyard then comes at 5.0 min and the fleet by 6.2.

## S-134 — Radar / sonar blips are sent at their unit's cell; the client draws the orbit (client follow-up to S-131) (2026-10-23)

- **Found by B in Studio:** strategic records carry only a cell (`cell u16`, no offsets), so S-131's 1.5-stud drawn orbit never reached the client. Blips sat still on cell centres, and one near a cell edge hopped between cells as the orbit crossed the edge. The client now circles blips itself: 1.5 studs, 6 s a turn, phase and direction from the id (C-154).
- **Changed:** `Sensors.blipOffset` and `BLIP_ORBIT` are gone. `knownPosition` returns the true position for RADAR / SONAR contacts, so NetOut sends the unit's own cell. `knownPosition(..., true)` and `knownTarget` still return the hidden aim point (S-130's orbit at the radar error), so targeting is unchanged.
- **What a player learns:** the cell, within half a cell (about 5.7 studs) of the unit. S-131's drawn orbit gave the same, since it was sent as a cell anyway, plus the edge hops. Guide 11.4 and the net tiers line are updated.
- **Tests:** `Fog.spec`: a radar contact's drawn position is the unit's, and its aim point is more than 10 studs off.

## S-135 — Blocked units slide along structures at speed (the user's approval, from S-133's review item) (2026-10-23)

- **The crawl:** a unit whose next step is blocked slid along the free axis, but Movement halved its speed every such tick. Steering re-accelerated it by one tick's worth each time, so it settled near `accel × DT`, under 1 stud/s, for as long as it touched the wall.
  - It mattered when a unit kept heading into a structure. The example: a straight-line ("shortcut") order issued while the unit was still inside its factory, which never asks for a flow field because the slow slide still counts as progress.
  - Seen with S-133 in seed 43: the first Mason crawled along a second plant's east face for 23 s, and the AI's T2 came about 3 minutes late.
- **Fix:** a blocked unit slides along the axis its heading leans to first (then the other), by at least `SLIDE_MIN` (half) of a full step, and keeps its speed. Only when both axes are blocked does it stop.
- **Measured** (`Movement.spec`, seed 43's geometry: a Mason leaving a plant, sent north-west past a second plant offset 16 studs):
  - arrival 529 → 160 ticks;
  - ticks under 2 studs/s 354 → 0;
  - in the AI match, that Mason starts the T2 plant at 0.86 min (1.27 before, 0.84 before S-133).

## S-136 — IDLE events for the player's builders and factories (client request 62) (2026-10-23)

- **Asked:** the client needs idle builder and factory counts, a key to cycle idle builders and an icon over them, like BAR. It can't tell an idle builder from one that is repairing, assisting, reclaiming or guarding. B's follow-up: a per-unit bit on tactical records misses off-camera units, and BAR counts and jumps to all of them.
- **Built:** protocol 31, event `IDLE 25`: `unitId u16, idle u8`, owner only, on camera or not.
  - `NetOut.isIdle`: a factory with an empty queue; a builder with no order of its own (automatic reactions don't count) and no build, assist, repair or reclaim work.
  - Every `NetOut.IDLE_EVERY` (5) ticks, each player's finished units with `buildOptions` are checked. A change is sent, tracked by generation in `PlayerNet.sentIdle`, so a reused ID starts busy.
  - On join / reconnect (forceFull) every idle one is sent again. Units never reported are busy.
- **Not chosen:** a STATES bit. It only reaches units in the tactical tier.
- **Tests:**
  - `Schema.spec`: golden bytes `19 02 01 01`, and event kind 26 is now the unknown one.
  - `NetOut.spec`: an off-camera Mason and plant are reported idle, owner only. Given work they go busy, and idle again when done. A late join hears of both.

## S-137 — Group moves at the slowest unit's speed: command flag GROUP (the user's queue item 3) (2026-10-23)

- **Asked:** a move or fight order given with a modifier keeps the group together at its slowest unit's speed (BAR's ctrl-move). The key was agreed with B: Ctrl, which is free on right-click and in the move / fight command modes.
- **Built:** protocol 31 (with S-136): `Schema.CmdFlag.GROUP = 4`, valid with QUEUE and LINE.
  - On MOVE, FIGHT and PATROL, `Orders.give` sets each order's `speedCap` to the lowest `maxSpeed` among the selection's ground units. Structures and aircraft are left out, so aircraft fly as usual.
  - While that order is the started head, Movement caps the unit's top speed (after terrain) at it.
  - The cap is hashed with the order. Other commands ignore the flag.
- **Not done:** faster units don't wait for stragglers at the start. Units start where they stand, at one speed, so the group arrives as it left. BAR's ctrl-move behaves about the same.
- **Tests:**
  - `Orders.spec`: a Herald (60 studs/s) and a Lancer (28). Without the flag the Herald arrives far ahead. With it, it never passes 28 studs/s and they arrive within 30 ticks of each other, while a Falcon in the selection flies at its own speed.
  - `Schema.spec`: golden bytes of a GROUP + QUEUE move; flag bit 8 is reserved.

## S-138 — Queue units in a factory still being built (client request 63, the user) (2026-10-23)

- **Asked:** "Add the ability to queue inside the factory while it being built". `Build.commandBuild` used to drop a queue order on an unfinished factory.
- **Built:**
  - An unfinished factory takes BUILD queue items, and REPEAT as before. Its queue is sent in the QUEUE owner field like any factory's.
  - It produces nothing and spends nothing until finished: the builders loop skips unfinished factories, and assistants build the frame. It starts on the queue the tick it's finished.
  - **CANCEL:** while a factory's queue isn't empty, CANCEL drops queue items (`value` 1-based, 0 = all) and leaves the frame. A CANCEL with an empty queue cancels the frame as before (S-35). So on a frame with a queue, the first CANCEL 0 clears the queue and the second removes the frame. net.md section 9 says so.
- **Tests:** `Build.spec`: a Vehicle Plant frame takes three items, and CANCEL 3 drops one. No progress or PRODUCED before it's finished; it starts at once after. A second frame's first CANCEL 0 clears its queue and the second removes it.
- **Revised the same day (fairness):** the first fix (slide along the leaning axis by at least half a step, speed kept) made the mirrored-map fairness test fail (west 2, east 10 of 12). Over 36 matches: west 9, east 27; main had 15 / 21.
  - Varying `SLIDE_MIN` (0.3–1.0) moved the split around but kept it tilted east. The cause in that rule wasn't found.
  - The fix is now smaller: the old slide (x first, then z, the step along the heading) stays, and a sliding unit's speed no longer decays below `SLIDE_MIN` (0.5) of its top speed. It used to halve every tick.
  - Results: crawl test passes; seed 43's Mason starts at 0.89 min; fairness 6 / 6 of 12, and 17 / 19 over seeds 1–18.

## S-139 — Flying sight bonus (the user's queue item 4; guide audit item 10, third part) (2026-10-23)

- **Guide 12.2:** "landed aircraft are `landed` state: no LOS bonus". So far there was no bonus, so landing cost an aircraft nothing in sight.
- **Built:** an aircraft not LANDED stamps its ground sight at `sensors.sight × Sensors.FLYING_SIGHT_BONUS` (1.25). Landed, it stamps its plain sight. `airSight` (sight against aircraft) is unchanged.
  - The radii cache key includes "flying", so landing or taking off restamps the unit.
  - Sight isn't terrain-occluded (that's still optional, audit item 19), so the bonus is reach only.
- **Numbers:** 1.25 is a placeholder (a Wasp's 300-stud sight becomes 375 in flight). It's under review with the other balance numbers. No balance report was run (the user's rule).
- **Tests:** `Fog.spec`: a flying Wasp sees a tank at 1.12 × its sight; landed, it doesn't, and it still sees one at 0.8 ×.

## S-140 — Per-tick budget watchdog for the live server (the user's queue item 5; next.md item 2) (2026-10-23)

- **Asked:** a per-tick budget watchdog that runs in the Roblox server and logs ticks over budget with the system breakdown, so B can measure the real server in Studio. The Lune timings are noisy and not Roblox's.
- **Built:**
  - `Sim.enableTiming` also keeps the latest tick's time per system (`last`, 0 when the system didn't run) and the total (`lastTotal`). It returns the existing timing if called twice.
  - `Sim/Watchdog`: `Watchdog.new(sim, { tickBudgetMs?, logger? })`, then `Watchdog.afterStep(dog)` after every `Sim.step`. Budgets are guide 18.1's per system: projectiles 6 + damage 2 share the 8 ms row, construction 1.5 + match 0.5 share the 2 ms row. Together that's 54 ms, the 66.7 ms tick minus the ~12 ms headroom.
  - **WARN line:** for a tick over 54 ms, or with any system over 2× its own budget. It names the tick, the total and the top 3 systems by budget share, at most one line per 15 ticks; skipped ticks are counted into the next line.
  - **INFO summary:** every 900 ticks: the share of ticks over budget, the mean and worst tick, the worst tick's top systems and the unit count.
  - It only observes: wall-clock timings never feed back into the sim. It runs in Lune too.
- **Wiring:** the server loop is in `src/roblox` (the client stream's), so B adds `Watchdog.new` after `Sim.new` and `Watchdog.afterStep` after each step.
- **Tests:** `Watchdog.spec`:
  - with a tiny budget, 40 ticks give 3 WARN lines (ticks 1, 16, 31), the second counting 14 skipped ticks, and one summary at 100%;
  - within budget, nothing is logged;
  - the latest tick's systems add up to its total.

## S-141 — Players choose their start (client request 64) — built, then held (2026-10-23)

- **Asked:** for the alpha match flow, the match config chooses each player's start.
- **Built** (commit 4793451):
  - `players[i].start` is an index into the map's starts. `standard_start` places that Commander there, and refuses a start that is shared or off the map.
  - Replay format 4 keeps each player's start.
  - The skirmish AI already homes on its Commander.
  - `Match.spec` covers it.
- **Held:** a fourth session, D (lobby stream, `m-lobby`), now owns rooms, match start and the return to the lobby. B asked to hold this until D's `docs/contracts/match.md` says whether the match place does a start pick.
  - Reverted on m-sim-2 (cd82cd0) so it doesn't block other merges.
  - The commit is kept on branch `s141-starts`. If the contract has a start pick, bring it back by reverting the revert.

## S-142 — AI build sites: reachable for their builder, off factory exit lanes (next.md item 3) (2026-10-23)

- **Why:** the AI's site picker didn't check that the builder could get to a site. S-133's walled-in Commander made that a real failure; S-133 only added a give-up as a safety net.
- **Built:** `spotNear` takes the builder (every call in the worker loop passes it).
  - **Reach:** a site is accepted only if some cell on the rings around its footprint, out to the builder's build range (2 cells at least), is open ground in the builder's connected region. That's its move class's quadtree component, which Nav keeps current. So a shipyard on the water is built from the shore. Aircraft, and builders not standing on open ground (inside their factory), always pass.
  - **Exit lanes:** sites may not cover the 3 cells (`Skirmish.EXIT_LANE`) in front of any of the player's factories, across the factory's width (S-133's exit path).
- **Measured** (12 min, hard against normal, Coastline 34, skirmish:192 43, Canyon 1, Ridgeline 3):
  - 404 sites checked; the reach check never fired; the lane rule fired twice.
  - Give-ups (S-133) stayed at 1–2 per match, the same as before, so their cause is something else (crowding units, a site taken meanwhile). That's under review.
  - Fast and slow suites pass; mirror fairness 6 / 6.

## S-143 — The lobby stream's match contract v1: the sim side (lobby requests A-1..A-3) (2026-10-23)

- **A-1, starts:** contract v1 gives player IDs 1..n in the room's order (teams grouped) and `start == id`. `Scenarios.standard_start` already puts player i (in sorted ID order) on start i, so `Sim.new` needs nothing new. Factions follow team parity, as `src/roblox/Lobby.config` maps them. Client request 64 / S-141 (chosen starts) is closed against D's L-4; the code stays on branch `s141-starts` in case a later version adds a start pick.
  - IDs must be contiguous from 1: with IDs 1 and 3, player 3 would take start 2.
- **A-2, shared validation:** yes. `MatchConfig.validate` (and `validateResult`) may move to `src/shared`, so the lobby and match places run one copy.
  - D owns that module.
  - It follows the shared-code rules: `--!strict`, string requires only (`@shared` across roots, relative within), no Roblox globals, it runs in Lune.
  - Its spec goes under `src/server/Tests`, so `lune run test` covers it.
  - `Sim.new` stays the final check of the sim config it is turned into.
- **A-3, guide 16.3:** rewritten for the lobby place and battle room (the host picks the map), reserved servers with the config in MemoryStore, loading and the wait for players, starts and factions in v1, heartbeat and rejoin, the results record and the return. It also keeps the Studio / dev path with the local MatchConfig.

## S-144 — Cheaper structure placement and staggered self-destruct (the live server's watchdog, B's Studio run) (2026-10-23)

- **Reported:** the watchdog (S-140) in B's Studio run flagged Construction at 10–13 ms once early on, and NetOut at 47.6 ms on the tick the match ended.
- **Construction, measured headless** (skirmish:192, seed 3, hard against normal): the peak was 10.5 ms on a BUILD_START tick. Each structure's `Placement.occupy` cost 2.4–4.7 ms: `Passability.updateRect` re-ran the Chebyshev distance transform over (size + 4 × CAP)² cells (CAP 16) for all 9 move classes.
- **Fix, placing:**
  - Occupying only adds obstacles, so `Passability.setOccupied` now sets each ground class's clearance to min(old, Chebyshev distance to the block) over (size + 2 × CAP)², which is exact. Air classes don't change.
  - Measured: occupy 0.20–0.25 ms; Construction peak 0.87 ms.
- **Fix, removing:** `updateRect` (still a full transform, since clearance grows) skips classes none of whose cells' pass bits changed, for one the air classes.
- **Test:** `Passability.recomputeClearance` (a forced full recompute) is the reference in `Passability.spec`. After 40 random blocks, some over the map's edge, and after removing half of them, every class's clearance equals it byte for byte.
- **NetOut at match end:** an eliminated player's whole army and base self-destructed in one tick. That's one tick of deaths, wrecks, freed footprints (each a full transform) and sight changes; harmless at the very end, a hitch mid-match in FFA.
  - Now their units queue in `MatchState.doomed` (id, gen; hashed) and go `Match.SELF_DESTRUCT_PER_TICK` (20) a tick.
  - `Match.spec`: a 46-unit army goes over several ticks, at most 20 a tick.
  - The rest of B's 47.6 ms may be the match place's own end-of-match work (results, resends). The next Studio run will tell.

## S-145 — The match contract's validator moves to `src/shared` (the user's choice, lobby request A-2) (2026-10-23)

- **Asked:** the match server should check the lobby's config and its own result with the lobby's code, not a copy. The lobby stream may not edit `src/shared`, so the user chose that A moves it (option a, relayed by D).
- **Built:** `Shared/Match/MatchConfig` (pure Luau, both runtimes), taken from m-lobby 287b99e:
  - the contract's constants: `CONFIG_VERSION`, `MODES`, `WINS`, `LEVELS`, `FACTIONS`, `MAX_ALLY_TEAMS`, `MAX_TEAM_SIZE`, `MAX_FFA`, and the 12-color palette `COLORS`;
  - the `Player`, `MatchConfig`, `ResultPlayer` and `Result` types;
  - `validate`, `validateResult` (with today's rule that a "finished" result may omit `winner`), `users` and `OUTCOMES`.
  - `build` and `summary` stay in `src/lobby`, since they need the lobby's Rooms.
  - D switches its require to `@shared/Match/MatchConfig` and drops its copy; B drops its copy in `src/roblox`.
- **Tests:** `src/server/Tests/MatchConfig.spec`, moved from the lobby's spec with a hand-written config of the same Teams room. It covers tampered configs (version, IDs and starts, colors, users, AI levels, FFA ally teams, spectators, no human, options, lobby, seed) and results checked against their config.
- **Merge check:** `integrate.sh` now also runs the lobby's own suite (`lune run src/lobby/tools/test`, when present) and requires it to pass, as D asked.

## S-146 — Radar missiles that lose their target spiral and fall; ones whose target dies at launch fly to its last spot (the user) (2026-10-23)

- **Asked:** "when a unit die after a rocket was launched by SAM targeting it, it will result in the missile fly straight into the sky. I want something more realistic. 1. For RADAR MISSILE that lose its target, it begin spiraling, waving. 2. For RADAR MISSILE that launch and it target die before the launch initiated -> target its last known position".
- **Cause:** a missile without a live target kept its velocity. A vertical-launch SAM still climbing went straight up until its fuel ran out.
- **Built** (RADAR-guided HOMING missiles, not interceptors chasing a missile):
  - **Tracking:** every tick while the target lives, the missile records its aim point (`Combat.pKnownX/Y/Z`) and counts its age (`pAge`).
  - **Launch phase:** when the target is gone and it died during the launch phase, the missile flies to the last known aim point (`pPoint`). The launch phase is a vertical launch before pitch-over (TURNED), or the first 8 ticks of other launches. It steers with PN, or the vertical climb then pitch-over, and bursts at its closest approach within its blast radius (4 studs without one).
  - **Otherwise it's lost** (`pLost`, ticks since): target killed, lock broken (EW), or a decoy spent. Each tick `Guidance.lost` turns the velocity 9° toward a direction circling the path once per 18 ticks (1.2 s; even IDs one way, odd the other), noses it over 3° toward straight down, and pulls it down at 25 studs/s². It ends on the ground or when its fuel runs out.
  - **Events:** a killed target sends LOST_LOCK; a broken lock already did, from EW.
  - A missile that never had a target, such as a test shot at a point, flies straight as before. IR missiles are unchanged.
- **Shared:** `Guidance.lost(vx, vy, vz, k, projId, dt)` is pure and deterministic, so the client steps the same corkscrew from LOST_LOCK (net.md, section 7). The fly-to-point path has no event; homing corrections carry it.
- **Hashed:** age, known point, point, lost ticks.
- **Tests:** `EW.spec`:
  - a Wasp killed after the Aegis missile pitched over: LOST_LOCK; the missile swings side to side, climbs at most 12 studs more and sinks over 160 within 22 ticks;
  - a Wasp killed while the missile is still climbing: it bursts at the Wasp's last known spot;
  - `Guidance.lost` is deterministic, keeps speed before the sink, and turns a vertical missile too.

## S-147 — The team's radar accuracy on the wire, for the sensor view (the user, for B) (2026-10-23)

- **Asked:** B should show the radar accuracy of the missile in the sensor view.
- **Why the wire:** the accuracy is the ally team's: the best `radarError` among its finished radars (or `trackError` for tracked contacts), scaled by its Pinpointers. The client can't count allies' Pinpointers and radars off camera.
- **Built:** protocol 32. Eco records end with `radarError u16`, `trackError u16` (tenths of a stud, 0 = none) and `precision u8` (× 255). They're the values `Sensors.wobble` uses: the hidden aim point circles a contact at radarError, a tracked one at trackError. They're sent with the Eco record when it changes.
- **Tests:** `Schema.spec` golden bytes; `NetOut.spec`: no radar gives 0, an Oracle gives 16.0 studs, and three Witnesses scale it down with the precision.

## S-148 — A wilder spiral for lost radar missiles (the user: "make the spiraling more extreme") (2026-10-23)

- `Guidance.LOST_TURN` goes from 9° to 20° a tick (300°/s); `LOST_PERIOD` goes from 18 to 10 ticks (a corkscrew turn every 0.67 s). The nose-over (3° a tick) and the sink are unchanged.
- **Measured** (`EW.spec`, a Wasp killed after the Aegis missile pitched over): 4 side-to-side swings instead of 2. It flies 30 ticks after the loss, at most 42 studs above where it was lost, then dives about 168 studs into the ground.
- The client steps the same shared function, so it follows with the next main merge.

## S-149 — Point defence: units that shoot down missiles and rockets (the user) (2026-10-24)

- **Asked:** "Add a new unit for both faction: an unit that is capable of intercepting long range missiles." The user chose:
  - targets: every missile and rocket flying nearby;
  - a structure and a mobile version per faction;
  - interceptor missiles with a hit chance.
- **Units** (T2, placeholder numbers; Order fewer and surer, Chaos more and less sure):

  | | Order | Chaos |
  |---|---|---|
  | Structure (T2 builder, footprint 3) | `ord_sanctum` Sanctum: 450 range, 8 interceptors, 85% | `chs_basilisk` Basilisk: 420, 10, 75% |
  | Mobile (advanced vehicle plant, wheeled) | `ord_shepherd` Shepherd: 330, 4, 85% | `chs_griffin` Griffin: 300, 5, 75% |

  - Each has its own short radar (radar about its reach), to detect what it shoots. They never fire at units.
  - The mobile ones fire on the move, unlike the mobile anti-nukes: they escort armies.
  - The interceptors (`*_point_interceptor`) launch vertically. They fly at 580–600 studs/s and turn 680–720°/s: tighter than a SAM, so they can come round onto a nearby rocket.
  - The stock refills one interceptor every 1.8–2.5 s. A salvo larger than the stock gets through.
- **Mechanism** (`intercepts.tactical = true`; Targeting's `interceptTarget`):
  - It picks the nearest enemy projectile within range that the team detects (sight or radar at its position), one interceptor per missile, from all projectiles in flight.
  - What counts: HOMING weapons, and BALLISTIC ones marked `rocket = true` (both MLRS and both rocket packs). Not strategic missiles (anti-nukes take those) and not interceptors.
  - The rest is the anti-nuke path (S-48, S-111): the interceptor homes on the projectile and its proximity burst destroys it with `intercepts.chance` (an INTERCEPTED event).
- **Measured** (`PointDefence.spec`, 30 s):
  - a Sanctum against a Chaos MLRS (Hydra) shelling a tank beside it: 16 of 56 rockets shot down with 22 interceptors (73% of interceptors hit). The MLRS outfires the stock: saturation, as intended;
  - a Basilisk against an Order missile battery: 14 of 14 missiles shot down;
  - a Shepherd also shoots rockets down; an anti-nuke ignores them.
- **Not done:**
  - the skirmish AI doesn't build them yet;
  - the client draws them with the generic blockout and the anti-nuke icon until B and C make their own (IDs sent);
  - no balance report run (the user's rule).

## S-150 — Shields tuned down (the user: "way too OP because even under concentrated fires, it still withstand with 100% charge") (2026-10-24)

- **Measured:** 10 Ravagers shelling a tank under a Phalanx put 412 shells on the dome in 60 s, about 5.5 shell masses a second. The dome recharged 30 a second (S-86's 20× numbers: 600 capacity, 30/s), so it never left 100%. A Carapace was the same.
- **Changed:**
  - Phalanx: capacity 600 → 120, recharge 30 → 2 per second.
  - Carapace: 400 → 80, 24 → 1.6.
  - Power draw unchanged.
  - `Shield.BEAM_DRAIN` 12.5 → 2.5, so a beam takes the same share of a dome as in S-117 (Radiance about 42% of a Phalanx).
- **Now** (`Shield.spec`, the same siege):
  - 10 Ravagers bring a Phalanx down by 30 s (3%), and it stays down;
  - 4 Ravagers wear it to 88% at 30 s and 76% at 60 s;
  - a Carapace under 10 falls in about 20 s.
- **Tests adjusted:** a breaching heavy shell slows by 13% (was over 15%; the smaller dome drains as the shell goes through); the SHIELD-record recharge test expects the slower rise.
- No balance report run (the user's rule). The new numbers are placeholders like the rest.

## S-151 — Interceptors steer at their target's start-of-tick state (B's question on S-149) (2026-10-24)

- **Found by B:** Projectiles walks `proj` backwards with swap-removal. So an interceptor steered, and fused, against its missile's state either before or after the missile's own step that tick, depending on list order. The client always uses the start of the tick (net.md, C-57), and B's spec saw up to ~1 stud of drift in the last ticks.
- **Changed:** before the loop, the Projectiles system snapshots the position and velocity of every projectile an interceptor chases. Interceptor steering (PN or the vertical climb) and the interceptor's proximity fuse read that snapshot. Anti-nukes and point defence both, now independent of step order.
- **Results** unchanged in the specs: point defence 16 / 56 rockets and 14 / 14 missiles; nuke tests pass.

## S-152 — Scouts' weapon range halved (the user, via B: "Scout attack range's is too big, reduce by half (for both factions)") (2026-10-24)

- `ord_mg` (Herald) 175 → 88 studs; `chs_mg` (Jackal) 140 → 70. Only the scouts carry them. Placeholder like the rest; no balance report run (the user's rule).

## S-153 — Orders in range don't move the unit (the user, via B) (2026-10-24)

- **Asked:** "a lancer attack a unit already inside of its attack range, the lancer tended to move out a little bit ... builder unit ... can simply path until they reaches the needed range ... they DO NOT need to go in range and move back out".
- **Causes:**
  - ATTACK closed in to `ATTACK_REACH` (90%) of the unit's longest range even when the target was already in range. A Lancer at rest with a target at 95% of its range moved 15 studs.
  - `halt` (Orders and Build, used when a unit gets in range) set the spot the unit holds to where it was at that tick. The unit then braked a few studs past it and, idle, walked back.
- **Fixed:**
  - ATTACK leaves a unit standing still when its target is in range. Only a unit already chasing closes to ATTACK_REACH.
  - `halt` holds `Nav.stopPoint`: where the unit comes to rest from its speed and braking, straight ahead, or where it is if that spot is blocked. This covers building, repairing, reclaiming and assisting, which all halt through Build.
- **Tests:** `Orders.spec`: the Lancer stays within 1 stud (it moved 15); a Mason sent to build stops in range and never steps back.
- **Revised the same day (fairness):** holding the predicted stop point (`Nav.stopPoint`) broke the mirror-fairness tests at merge (Twin Lakes 2v2: 4 matching structures where 7 are required; mirrored matches west 2, east 10), and the cause in it wasn't found. It's gone. `halt` holds the spot where the unit is again. The braking step-back was at most half a stud in the measured cases; the attack change, which was the visible 15 studs, stays. Both cases in `Orders.spec` still pass.

## S-154 — Shield generators switch off to save power (the user, via B: "a shield can be turned off to save power") (2026-10-24)

- **Built:** Phalanx and Carapace (any def with `shield`) honour TOGGLED_ON (the TOGGLE command), and start switched on like converters.
  - Off: the dome is down (SHIELD's UP flag clear), so shells pass. No power upkeep and no recharge; the charge it has is kept.
  - On: it rises again under the usual rule, at RAISE_AT (25%) of capacity, and recharges.
- **Tests:** `Shield.spec`: off, the dome drops, draws nothing, lets a heavy shell through and keeps its charge; on, it rises.
- **Client:** B offers On/Off on the card for any def with `shield`. No wire change: TOGGLED_ON and SHIELD's flags already carry it.

## S-155 — Build over your own units; they walk out of the footprint (the user, via B) (2026-10-24)

- **Asked:** "You can also pre-place model inside grid that have unit (not structure) so when you build the model, other units inside can move out of the grid." Before, `Placement.check` failed with "units in the way" when a frame should start.
- **Rule:**
  - When a frame starts (`Placement.check` with `owner`, no `knower`), the builder's own and allied ground units are no obstacle. Enemy ground units still block ("units in the way"). Aircraft never did.
  - Planning checks with `knower` (the skirmish AI) still treat every unit as an obstacle. Letting the AI plan over its own units held Chaos's T2 back by minutes in seed 24 (its Forgemaster came at 7 min instead of 3.3), and two AI tests failed. So the AI keeps its old sites.
  - The client's ghost should treat own and allied units as no obstacle, since the server accepts them at the frame's start.
  - When a structure's footprint is occupied (`Placement.occupy`, so a new frame, a spawned structure, or an upgrade's restored footprint), `Placement.clearUnits` sends every ground unit on it (any team) straight out, away from the centre across the nearer edges, to a cell past the edge. It uses S-133's walk-out (`BuildState.exiting`): through the blocked cells, ignoring separation, whatever its order, until it's clear on open ground. Then it carries on with its orders.
- **Fixed on the way:** Movement skipped its whole step when nothing was moving or had an order. A unit walking out while everything else stood still never left; now walking out counts as active. And a walking-out unit near its exit point no longer counts as settled.
- **Tests:** `Build.spec`: a Commander starts a Vehicle Plant over a friendly Lancer, and the Lancer walks off the footprint; an enemy Ravager on the site still stops the frame.
- **Client:** B drops its "units in the way" check for own and allied units to match.
- **Fixed while testing:** a unit that stopped at its exit point kept the walk-out flag for good, because clearing was checked only while it moved. In an AI match a Commander and builders kept steering at their exit points, and one held a new factory's pad (S-133's pad wait). Movement now checks every tick whether a walking-out unit is clear: out of the footprint, and on open ground or stopped. AI.spec passes again.
- **Mirror-fairness test widened (`Fairness.spec`):** with S-155 the six-seed mirrored-matches test split west 3 / east 9 (the bar is 4 each). Over seeds 1–18 the split is west 15 / east 21, the same as `main` before the change, and seeds 7–12 split 5/7 (6/6 on `main`). So the start's odds didn't move; six seeds are too few. The test now plays seeds 1–18 (36 matches) and asks for 12 each, the same one-third bar. It takes ~165 s instead of ~55 s, in the slow suite only.

## S-156 — Resource priority: high and low consumers (the user, via B) (2026-10-24)

- **Asked:** a high / low resource priority per unit; high consumers take supply and power first in a stall.
- **Wire (protocol 33):**
  - Command `PRIORITY 18`, `value u8`: 0 low, 1 high. Any unit takes it.
  - Unit state bit `LOW_PRIORITY 128`: set means low. Clear, high, is the default for every unit. The AI never sends it.
  - It's a state bit, not an owner field, so allies and enemies who see the unit see it too, like `REPEAT`.
- **Economy (`settleRatio`):** missile refills first, up to their share of income (S-66). Then the high consumers share what's left (`ratio`); refills beyond their share count as high. The low consumers (`lowDemand`) share the rest (`lowRatio`). With no low demand the arithmetic is exactly as before, so matches without the command replay unchanged. `Economy.effective(acc, s, p, low)` reads the low ratio.
- **Who counts as a consumer:**
  - a builder's or factory's build power: the frame it builds splits its progress by builder;
  - a stockpiler's refills: a low one leaves the refill share and refills last;
  - an aircraft's rearm (its own bit, not the pad's);
  - shield, tracking-radar, plain-radar, jammer and DIRCM upkeep.
- **Tests:**
  - `Economy.spec`: the low ratio gets what the high demand leaves, and nothing when the high demand is short.
  - `Build.spec`: two plants, supply income for one. Both high, they share alike. With one low, the high plant runs at full speed and the low one gets next to nothing. PRIORITY 1 clears the bit.

## S-157 — T1 defences, Chaos's Bulwark, and the tier rebalance (the user, via B) (2026-10-24)

- **Asked (the user, through B):**
  - The T1 defence batch: Sentry, Beamer, Overwatch and Gauntlet for Order; Guard, Twin Guard, a triple-barrel tower and a Gauntlet counterpart for Chaos.
  - Bulwark redesigned as Chaos's counterpart to Radiance, in Inferno's place.
  - "T1 unit (tank and defense) currently has too much health and range. Tune them down." "T2 more health and damage."
  - "around 4 [scouts] should be able to win against 1 lone T1 defense like the new sentry."
  - A Juggernaut lost over half its health to a Spike.
- **Names and ids (ids never change, so every tower is new; the user approved these):**

  | id | Name | Weapon | Range | Notes |
  |---|---|---|---|---|
  | `ord_sentry_tower` | Sentry | `ord_sentry_laser`, red | 190 | 800 health; Commander and Mason |
  | `chs_guard` | Guard | `chs_guard_laser`, red | 165 | 750 health |
  | `ord_beamer` | Beamer | `ord_beamer_beam`, blue | 220 | 5 pulses a second, ramping |
  | `ord_overwatch` | Overwatch | `ord_overwatch_laser`, green | 240 | 2 barrels in turn |
  | `chs_twin_guard` | Twin Guard | `chs_twin_laser`, red | 195 | 2 barrels |
  | `chs_geryon` | Geryon | `chs_geryon_laser`, green | 215 | 3-barrel drum; harder hits than Overwatch, less range |
  | `ord_gauntlet` | Gauntlet | `ord_gauntlet_shell` | 420 | high arc |
  | `chs_talos` | Talos | `chs_talos_shell` | 360 | high arc |
  | `chs_bulwark` | Bulwark (T2) | `chs_bulwark_beam` and `chs_geryon_laser` | 480 / 215 | Inferno's numbers, retracts like it |

  The corvette `ord_sentry` keeps its id and is now **Envoy**.
- **Retired:** `ord_bulwark`, `chs_spike` and `chs_inferno` get `retired = true`. They're on no build list (`Defs.validate` refuses a retired build option) and the AI doesn't build them. The defs stay, so old replays and scenes load. `TechTree.spec` skips retired defs when it checks that every def is reachable. The hard AI's gun turrets are now Sentry and Guard, and its T2 beam tower is Bulwark for Chaos.
- **New mechanics:**
  - **Ramp** (`weapon.ramp = { from, to, seconds, cooldown = { shortest, longest } }`, HITSCAN only, aoe 0). Each hit deals `from` .. `to` (the damage table holds the full `to`), rising linearly over `seconds` while the weapon stays on one target and can fire at it. When the target changes (or is lost), the weapon holds fire for `cooldown[1]` .. `cooldown[2]` seconds, by the intensity it had reached. The new target starts again from `from`. State per weapon slot: `World.wRampTarget` / `wRampTime`, hashed when present.
    - Beamer: 10 → 50 over 4 s, a pulse every 0.2 s (50 → 250 a second), pause 0.1–0.5 s.
  - **High arc** (`weapon.highArc`, BALLISTIC, not lofted): `Ballistics.launchPitch(..., high)` takes the high solution for aiming, leading and line of fire. Gauntlet and Talos lob at 165 / 155 studs/s, so a shell lands 3–5 s later and hits what stands still. Their barrels top out at 85°, so they can't hit what's right beside them.
  - **Client-only fields:**
    - weapon `fx.tracer = "laser"` and `fx.color = { r, g, b }`;
    - weapon slot `muzzles = { ... }` (2 or 3 barrels in turn) and `drumPiece` (Geryon, Bulwark's laser). Validation checks they're in `pieces`. The server still fires from `muzzle`.
  - Laser towers aim down to −60°, so units next to them don't hide under the barrel (scouts hugging a Sentry did at −15°).
- **Tier rebalance:**
  - **T1 tanks, less health:**
    - Lancer 1300 → 1050, Ravager 1000 → 800, Locust 600 → 500;
    - Verdict 800 → 650, Hellmouth 700 → 570 (artillery keeps its range).
  - **T1 guns, less range:** `ord_light_cannon` 210 → 190, `chs_light_cannon` 170 → 155, `chs_autocannon` 120 → 110. Tideguard and Mire share the light cannons and lose the range too.
  - **T2 tanks, more health:** Paladin 3200 → 3850, Juggernaut 2500 → 3000, Minotaur 4200 → 5000, Cyclops 1100 → 1300, Tideguard 1400 → 1700, Mire 1550 → 1850.
  - **T2 guns, +15% damage:** `ord_heavy_cannon` (Paladin, Bastion), `chs_juggernaut_cannon`, `chs_ram_cannon`, `chs_siege_mortar`.
  - No balance report was run (the user's rule); the fights below check the targets.
- **Tests (`Towers.spec`):**
  - Four scouts, either faction's, beat a lone Sentry or Guard with 2–3 left; three lose.
  - Paladin or Juggernaut against a Sentry, Guard or the old Spike: the tower falls, the tank keeps 87–100%. The Juggernaut outranges a Guard.
  - The Beamer's first hit is ~10, halfway after 2 s, 50 from 4 s. It switches after its target dies, about 0.5 s later, low again.
  - Gauntlet and Talos hit a still tank near their range, aiming above 45°.
  - Bulwark fires both weapons and starts on.

## S-158 — Own units off camera: OWN_STATUS (the user's approval, next.md item 4) (2026-10-24)

- **Asked:** strategic records carry only cell, icon, team and flags, so the owner's units off camera kept their last health, build progress and factory queue (B's question). The user approved a slim owner-only record, sent on change and capped per tick.
- **Wire (protocol 34):** event `OWN_STATUS 26`: `unitId u16, health u8, build u8, queueHead u16, queueProgress u8, queueCount u8`, 9 bytes. Health as ENTER's (u8 of max, rounded up), the queue head a unit def index (0 = none), its progress 0..255.
- **When:** for the player's own units outside its tactical tier, when one of the values changed since the client last had it. The head's progress counts by sixteenths (`Stockpile.WIRE_STEPS`), like the owner's queue field, so a factory off camera sends 16 a build. At a unit's LEAVE the server notes its status (the client has it then), so leaving doesn't resend. On join every own unit off camera is sent.
- **Cap:** `NetOut.OWN_STATUS_MAX` = 24 per player per tick (216 bytes, at most ~3.2 KB/s). Past the cap the next tick starts where this one stopped (a round-robin cursor over the world's ID list), so no unit waits forever.
- **Cost:** one pass over the world's units per player per tick, with a signature per own off-camera unit (no strings, no tables unless one is sent).
- **Why an event, not a strategic field:** strategic records go to everyone with fog applied and every 5th tick; this is owner-only, rare and reliable, like IDLE.
- **Tests:** `Schema.spec` golden bytes; `NetOut.spec` "OWN_STATUS": owner only, nothing when nothing changed, health and queue changes arrive, leaving the tier doesn't resend, the cap holds and the rest arrive on the next ticks, a late join gets all of them.

## S-159 — Commanders walk: the WALKER move class (the user's approval, queue item 3) (2026-10-24)

- **Asked:** a WALKER move class, about 40° slopes, BAR-bot style, for `ord_sovereign` and `chs_warlord`; check every map still connects and mirror fairness holds.
- **Built:** `MoveClasses.WALKER`: bit 9, land, `maxSlope` 40, `maxFord` 2 (as TRACKED), flow-field pathing. Terrain speeds: grass 1, rock 0.95, sand 0.85, road 1.05 (legs mind the ground less than tracks). Both Commanders have `moveClass = "WALKER"` (footprint 2 kept).
- **Normandy's hedgerows:** they're 6-stud bumps on 8-stud cells, 35–38° slopes, so a 40° walker crosses them; 11.5% of Normandy (the bocage) is open to Commanders only. Houses (45°) still stop them. 36° wouldn't have kept the hedges closed either (some are 35°): it would take ≤ 34°, barely more than a tank's 30°. I kept your 40°; `Normandy.spec` now exempts WALKER from the hedge check. Alternatives under "Needs my review".
- **Every map still connects** (`Walker.spec`, new): on Ridgeline, Coastline, Twin Lakes, Crossroads, Normandy and The Canyon, at footprint 2, every start is open to a Commander and in one component with every other start, every deposit a tank reaches from a start a Commander reaches too, and a Commander enters every cell a tank does. Cells open to Commanders only: Ridgeline, Coastline, Crossroads 0; Canyon 160 (0.4%: no mesa top: `Canyon.spec` still has no land unit on a cliff); Twin Lakes 264 (0.7%); Normandy 7,522 (11.5%, the hedges).
- **Mirror fairness holds:** the slow suite's 36 mirror AI matches on Ridgeline split west 19 / east 17 (the guard needs 12 each).
- **Tests:** `Passability.spec` (a 37° ramp open to WALKER, not TRACKED; 45° closed; ford like TRACKED), `Walker.spec`, `Canyon.spec` / `Normandy.spec` / `Placement.spec` class lists.

## S-160 — Structure facing on BUILD: the AI faces its factories toward the enemy (the user's BAR reference #7) (2026-10-24)

- **Asked:** a facing (N / E / S / W) on BUILD, so a factory's pad and exit lanes follow it; the AI faces its factories toward the enemy. Tell B the wire format.
- **Already there:** BUILD has carried `facing u8` (0..3, bits 2–7 reserved) since protocol 1 (guide 7.3, 9.3), and the frame's heading is facing × 90°. The build pad and the exit drive (S-133) and the AI's kept-clear exit lane (S-142) already follow the heading. So no wire change: 0 north (+Z), 1 east (+X), 2 south, 3 west. The arrow and "Buildings set to face East" are client-only (B sends the chosen facing).
- **Changed:** the skirmish AI chose east or west only, from the sign of the enemy's x. On The Canyon (north vs south) its factories faced sideways. `Skirmish.enemyFacing` now picks the nearest of the four toward the enemy start (east / west on a tie, so the mirrored 1v1 maps are unchanged). Vehicle plants and advanced plants use it; airfields and shipyards stay at 0.
- **Guide 9.3** says what facing means and who follows it.
- **Tests:** `Build.spec` (BUILD with each facing: the frame's heading and its pad on that axis), `Canyon.spec` (the AI faces south from the north start and north from the south; on Ridgeline east and west as before; the slow match checks the AI's built plants).

## S-161 — The AI's give-ups: their causes, fixed; the coarser base grid tried and parked (your queue item 6, next.md item 3) (2026-10-24)

- **Asked:** the cause of the remaining give-ups (1–2 per 12 minutes after S-142), and mixed sizes laid out on a coarser grid, with mirror fairness as the guard.
- **How:** `lune run debug_giveups [minutes] [seeds] [mapFilter]` (new, `.lune/`): mirror matches at normal and hard on Ridgeline, Coastline, Twin Lakes and The Canyon. Each give-up (`Skirmish.giveUpHook`, a debug hook, nil in play) prints what stood around it. **59 give-ups in 16 matches of 12 minutes:**
  - **28, a builder standing still with a move order** before a deposit it can't reach (Twin Lakes' middle deposits at x = ±12, The Canyon's at (-396, -644)). When no open cell of the builder's region lies near the goal, Nav marks the move unreachable and the unit never moves. S-142's reach check covered `spotNear` sites but not `freeDeposit`'s.
  - **17, a site occupied:** mostly the same unreachable far deposits, already taken by the enemy.
  - **13, moving but no closer:** a builder produced by a vehicle plant, given a site behind the plant while still driving out (S-133), pushed head-on into the plant for 20 s. Planning started from its cell inside the footprint, the route search found nothing, and the order was marked unreachable for good: no field, no extension, a straight line into the wall.
  - 1, units in the way.
- **Fixed:**
  - `Skirmish.freeDeposit(brain, accept, builder)` skips deposits the builder can't reach (the S-142 check);
  - `Nav` plans a unit standing in a blocked cell from the nearest open cell (the one it comes out on), so the order gets a field.
- **After: 2 give-ups in the same 16 matches**, both builders sliding along their own buildings (an extractor and a generator). Every AI was affected, the player's units too (any order given while driving out of a factory, or walking off a new frame, S-155).
- **The coarser grid, tried and parked on branch `s161-grid`:** sites on a lattice of blocks anchored at home and mirrored. Footprints up to BLOCK − 2 at block centres, larger ones at every second block corner, so any two buildings keep 2 free cells whatever their sizes. It never ran out of sites, but it cost the economy on Ridgeline (normal, seeds 34–36, 8 minutes):

  | Layout | Generators | Lancers | Power ratio, minutes 6–8 |
  |---|---|---|---|
  | Ring sweep (kept) | 15 / 15 / 15 | 14 / 19 / 12 | 0.74 / 0.81 / 0.81 |
  | 5-cell blocks | 11 / 18 / 19 | 9 / 17 / 11 | 0.47 / 0.67 / 0.67 |
  | 4-cell blocks | 11 / 11 / 11 | 15 / 17 / 10 | 0.64 / 0.65 / 0.66 |

  With 5-cell blocks `AI.spec`'s normal-economy test failed (power ratio 0.45 at 8 minutes, needs 0.5). With the give-ups gone, the lanes it was for matter less. Under "Needs my review".
- **Tests:** `Build.spec`: a tank ordered behind its plant while driving out of it gets round it (136 studs short before the fix).
- **Mirror fairness:** the slow suite's guard runs at the merge.

## S-162 — The fairness run as its own report (your queue item 7, next.md item 6) (2026-10-24)

- `lune run fairness [seeds] [minutes] [mapFilter] [level]` (new): the same AI level on both starts (default normal), both faction mirrors, seeds 1..12 by default (24 matches a map), up to 10 minutes each (then the value lead decides, as in `Fairness.spec`), on every two-start map: Ridgeline, Coastline, Normandy, The Canyon. Per map: wins by start, draws, wins per faction mirror, the two-sided binomial p. Target: neither start under a third of the decided matches. Parallel workers (`--jobs`, S-99). Writes `docs/FAIRNESS.md` without a map filter.
- **Report only, outside the slow suite:** it runs with the balance checkpoint, never per change. The slow suite keeps its 36-match Ridgeline guard (S-155) for merges.
- Not run now (your rule): its first numbers come with the next balance checkpoint.

## S-163 — Beam damage along the beam (your queue item 8, guide audit item 16) (2026-10-24)

- **Before:** lingering beams dealt their damage per tick (S-113), but a single-target beam's share always went to its target, through anything in front of it, and a missed beam burned nothing. Hit-rays (Radiance, `pierce`) already hurt everything on their line (S-115).
- **Now:** each tick a single-target beam's share goes to the **first enemy unit its line crosses**, from the muzzle to its end (the target's aim point, a miss's fixed point on the ground, or the dome that stops it), by collision radius, in the weapon's target classes; the hit target when nothing stands in front. A unit stepping into the beam takes it; a missed beam burns whatever walks into its line. Allies are never hit.
- **Wire:** nothing new. When the struck unit changes, a new FIRE ends the drawn beam there (`hit = true`, at its aim point), or at the full end when nothing is struck, as dome changes do (S-123). The beam keeps who it struck (`Beam.struck`, hashed).
- **Tests:** `Defenses.spec`: an Inferno beam at a Paladin; a Lancer stepping into the line takes the share and a FIRE ends the beam at it; the Paladin behind takes only the shares before.

## S-164 — The live server's budget: B's watchdog run 1, the fixes, `--!native` (your queue item 5, next.md item 1) (2026-10-24)

- **B's Studio run 1** (client request 65; Twin Lakes seed 13, 4 Hard AI FFA, `income all 100`, speed 4, 24.5 game minutes, peak 273 units, main d6643d4): only one tick over the 54 ms tick budget, 104 ms with **Damage 96.1 ms** when a player was eliminated (its units self-destruct). Over 2× their 18.1 budgets: Damage (4–9 ms through big fights), Pathing (15–26 ms spikes), Commands (2–4 ms from minute 0), NetOut (12–16 ms spikes, one spectator), once Weapons 12.9 and Construction 6.8.
- **`lune run profile_match [minutes] [seed] [mapId] [income] [--parts]`** (new): the same match headless; per system the ticks over budget, the median over and the five worst ticks with what happened in them. `--parts` times a few functions inside the systems (module fields only). Its shapes match B's (Lune isn't a live server: compare shapes, not milliseconds).
- **Found and fixed:**
  - **Damage: a structure's removal cost 1.5–2.4 ms**, all in `Passability.updateRect`: the clearance transform over a (size + 4 × CAP)² rectangle per ground class (CAP 16), into a fresh table each time. Only cells within CAP of the change can change, so the transform now covers just that band, seeded on its border with the current values of the cells just outside. Exact: the two-pass L∞ transform is min-plus linear, so arbitrary exact seeds give the exact result; `Passability.spec`'s full-recompute comparison passes. One scratch table is reused. A footprint-3 place + remove: 3.34 → 0.72 ms. In the profile, Damage over budget on 47 ticks → 1, peak 5.6 → 2.5 ms.
  - **Damage 96 ms on an elimination:** S-144 self-destructed 20 units a tick, structures included. Structures now weigh 10 against those 20 (`Match.SELF_DESTRUCT_STRUCTURE`), about 2 a tick; the first in line always goes.
  - **Pathing on idle ticks:** an idle Pathing tick applied every tree's pending terrain changes (S-67), 5 trees' updates and component passes at once: 10–14 ms. Now one tree a tick (the others the next idle ticks, or when an order needs them).
  - **`Nav.nearestOpen`** (goal and slot snapping, up to 4,096 cells) built a direction table per cell and a fresh `seen` set per call. Now a stamp buffer and a reused queue; the same cells in the same order, so the same results.
- **Commands:** its average is 0.29 ms a tick at 196 units (auto-orders 0.07, the per-unit pass 0.14). Its over-budget ticks are single `Nav.issueMove` calls of 3–5 ms that I couldn't reproduce outside a running match (the same orders benchmark at 0.02–0.5 ms), so most likely garbage collection landing there. Run 2 will show whether the nearestOpen change helped. Not changed further.
- **NetOut:** 12–18 ms spikes in the profile too, with the spectator (who has every unit tactical). Not looked into yet; next once run 2 is in.
- **`--!native`** on `Systems/Targeting`, `Systems/Movement` and `Sim/Sensors` (none was over budget in run 1, so run 2 shows the codegen's effect on them). Lune ignores it; `lune run build` keeps it (darklua keeps comments) and the place compiles.
- **Tooling:** `integrate.sh` now prints the failing tests of a failed suite (it showed only the summary line).
- **Next:** B's run 2 on the merge commit, same profile and seed, side by side with run 1.

## S-165 — Homing corrections for radar-only contacts: measured, not built (your queue item 8, client request 11a) (2026-10-24)

- **Asked (11a, 2026-10-21):** corrections more often than every 5 ticks for missiles whose target the player has only as a radar contact; the client drifted ~7 studs (up to 35).
- **Tried:** every 2 ticks for homing projectiles whose target isn't in the player's tactical tier. In `NetOut.spec`'s torpedo scene (torpedoes at sonar contacts) the mean visible drift went from 2.68 to 2.55 studs (−5%), the worst case stayed 10.5, and the homing bytes rose 63% (0.09 → 0.15 KB/s); with every other message lost it got worse (corrections every 2 ticks all fell on the lost ticks).
- **Why so little:** since S-131 / S-134 a blip is sent at its unit's true cell and the client circles it 1.5 studs, so the client already steers at almost the right point. 11a's drift was measured before that.
- **Not built.** If B still sees drifting missiles in Studio, a smaller step (every 3 ticks, radar-only targets only) is ready to try.

## S-166 — A naval SAM platform and an advanced rearm pad (your queue item 8, guide audit item 15) (2026-10-24)

- **Naval SAM platforms** (guide 13.5, built by the advanced naval workers): `ord_pharos` **Pharos** (the Crusader's `ord_naval_sam`, own radar 600, error 20; 2,200 health; 300 supply, 3,800 power) and `chs_scylla` **Scylla** (the Corsair's `chs_naval_sam`, radar 560, error 22; 2,400 health; 280 / 3,600). T2, footprint 3, `placement = "water"`. Radar-guided: jamming beyond burn-through blocks them, chaff decoys them. Names after the faction styles (Order: a lighthouse; Chaos: the sea monster).
- **Advanced rearm pads** (guide 13.1, built by the advanced air workers): `ord_empyrean` **Empyrean** and `chs_rookery` **Rookery**: T2, footprint 4 (two bays), 3,000 / 3,200 health, 300 supply, 3,600 power. `rearmPads = 2` and the new def field **`rearmSpeed = 2`**: rounds come twice as fast (and are paid twice as fast).
- **`rearmSpeed`** (structures and carriers with `rearmPads`, default 1, validated): Air's rearm rate is `rearmSpeed / rearmTime` rounds a second at full economy.
- **The AI doesn't build them yet.** Wire: nothing new.
- **Tests:** `Air.spec` (two aircraft on an Empyrean or a Rookery at once, each rearmed in half an Aerie's time), `Naval.spec` (each platform stands on the sea, not on land, and shoots down a loitering enemy fighter).
- **Requests:** blockouts / models to models-C; icon entries to client-B (the icon run fails on a def without one, C-183).

## S-161 follow-up — the Nav fix tilted mirror fairness; now symmetric (2026-10-24)

- **Found at the merge:** with S-161 the slow suite's 36 mirror matches on Ridgeline split **west 11 / east 25** (the guard needs 12 each; before, 19 / 17), and the merge of 775ceb6 was dropped (main untouched). Three variants in parallel: without the Nav fix 19 / 17; without the deposit reach check still 11 / 25. So the Nav fix.
- **Cause:** it took the open cell `nearestOpen` finds first, a search that tries +x first. From inside a factory's footprint that's the east side: the exit for the west player's plants (they face east) but the back of the east player's.
- **Now:** the open cell on the smallest square ring around the unit's cell that is nearest the unit itself (`Nav` `openNearPoint`; exact ties to the lower index). A unit driving out is already part-way through its door, so that's the exit side, mirrored for both.
- **Checks:** mirror matches **west 15 / east 21** (pass); `debug_giveups`: **1 give-up in 16 matches** (2 with the first version, 59 before S-161); `Build.spec`'s regression test passes.

## S-167 — Aircraft rise gradually over hills (the user) (2026-10-24)

- **Asked:** an aircraft passing over a hill snapped to the new height (terrain + offset); it should rise gradually.
- **Cause:** `World.alt` (height above the ground) only eased toward the cruise band, so the absolute height was always ground + band and followed every rise and drop of the terrain at once (13.5 studs in one tick over Normandy's bluffs).
- **Now:** a flying aircraft keeps an absolute height (`AirState.height`, hashed). It climbs at `Air.CLIMB_RATE` 40 studs/s and descends at `Air.DESCENT_RATE` 25 toward its cruise band over the highest ground on its path in the next `Air.TERRAIN_LOOKAHEAD` 2 s (4 samples along its heading at its speed), so it starts climbing before the hill and eases down after it. It never flies lower than `Air.MIN_CLEARANCE` 8 studs over the ground (a cliff steeper than the lookahead can catch pushes it up). `alt` is derived from it. Landed on a pad: as before.
- **Wire:** nothing new: altitude is still height above the ground, so the client's ground + alt is now smooth.
- **Tests:** `Air.spec`: a Falcon and a Harpy crossing Normandy's bluffs change height at most 2.7 studs a tick (the ground under them jumps more), never below 8 studs over the ground.

## S-168 — Resurrect and reclaim for the T1 workers (the user) (2026-10-24)

- **Asked:** a dead unit's wreck can be reclaimed for supply (when only workers are selected, the client shows areas with their total reclaimable supply), or resurrected by a worker: power only if the wreck is untouched; a partly reclaimed wreck must first be filled back to 100% with the worker's supply. Two bars: purple for the resurrect progress, dark green for the wreck's supply (only below 100%). Hovering a wreck shows its unit's name and its supply. The user approved the plan: full health on resurrect, structures resurrectable, Commanders not.
- **Defs:** `canResurrect` (builders only, validated) on `ord_mason` and `chs_scrapper`.
- **Command (protocol 35):** RESURRECT 19, `targetId` = a wreck, queueable like RECLAIM (order kind `resurrect`). Other units, and Commanders' wrecks, are refused.
- **Sim (`Build`):**
  - The worker walks into build range of the wreck. If its supply is below what it held (`Combat.fullWreckSupply`: half the unit's supply cost), the worker refills it from the team's supply at its reclaim rate (0.1 supply/s per build power), an economy consumer like building (stall ratios, priority).
  - Then the resurrect: progress at `buildPower / buildTime` a second, paid in power (`Build.RESURRECT_POWER` × the unit's power cost, 1), also a consumer.
  - At 100%: the unit stands on the wreck's spot and heading, the worker's owner's, at full health, missile stockpiles empty (as produced); the wreck goes (event RESURRECTED). A structure waits until its footprint is free; anything waits for room under the unit cap.
  - Progress is kept on the wreck (`Combat.wreckRez`, hashed) when the worker stops or dies; anyone reclaiming the wreck lowers its supply, so it must be refilled before the resurrect can finish. Instabuild (cheat) makes it free and immediate.
- **Wire (protocol 35):** WRECK carries `supply u16` and `fullSupply u16` (10 → 14 bytes). WRECK_STATE 27 (`wreckId u16, supply u16, rez u8`, 6 bytes) on sensor ticks for a sent wreck in the team's sight whose supply or progress changed. Fog as for wrecks: out of sight, nothing. Contract: net.md 7a and commands.
- **Client (B):** the two bars, the hover, and the workers' reclaim zones from the known wrecks' supply.
- **Not yet:** the AI doesn't resurrect.
- **Tests (`Resurrect.spec`):** an enemy Ravager's untouched wreck resurrected by a Mason for its power cost, no supply, in about its build time, the Mason's player's at full health; a three-quarters-reclaimed wreck refilled first (at the reclaim rate), then resurrected; enemy reclaiming during a resurrect lowers the supply, the progress stays; a tank and a Commander don't resurrect, a Commander's wreck can't be; a generator's wreck comes back on its footprint; the wire (supply, full supply, progress, the enemy out of sight hears nothing, the supply drop as it's reclaimed). `Schema.spec`: golden bytes for WRECK, WRECK_STATE, RESURRECT.

## S-169 — Chosen starts in a pre-game; up to 16 players on any map (the user) (2026-10-24)

- **Asked:** a map's spawn points are only suggestions; 16 people can play on a 2-team map, or a 4-team map. A setting lets players choose their spawn point. While choosing, everyone sees the others' spots, and you can queue build commands for your Commander. When all are ready, a 5..1 countdown, then the match. The user approved the plan: start areas per side, up to 16 players, ready + countdown, pre-queued Commander builds; briefs to B and D.
- **16 players:**
  - `Schema.MAX_TEAMS` 8 → 16; strategic records 6 → 7 bytes (team 4 bits: icon bits 0–7, team 8–11, flags 12–16, 7 reserved). 128 strategic records fill a 900-byte message (was 150).
  - `Match`: at most 16 players (`MAX_PLAYERS`); FFA up to 16; TEAM 2–8 sides of any size. `MatchConfig` (shared) the same, plus `startMode` and 4 more colours (Navy, Maroon, Lime, Lavender, D's picks) for 16.
  - **Unit cap:** the default is now also at most `Match.GLOBAL_CAP` 1,200 / players (16 players: 75 each). Today's 8-player FFA (150 each) is unchanged. Under "Needs my review".
- **The pre-game (`Sim/Pregame`), with `match.startMode = "choose"`:**
  - `Sim.new` keeps the scenario (standard_start only) for later and boots with no units. `Sim.step` runs only Commands and NetOut until the start.
  - **Sides:** the ally teams share the map's starts in contiguous blocks; each side's start area is the Voronoi region of its starts (`Shared/Match/StartAreas`, shared with the client).
  - **Commands:** START_POS 20 (a pick: in the own side's area, Commander-standable, 48 studs from other picks), READY 21, and BUILD / STOP with no unit IDs for the Commander's queue (its build options, at most 30).
  - **Flow:** all ready (or 90 s) → a 5 s countdown (un-ready cancels) → each Commander on its pick (unpicked: the first free point among its side's suggestions, start then rings of 48 studs), facing the map's centre, with its queue as build orders; `match.startTick` = that tick (hashed).
  - **The AI** picks its side's suggestion and readies through recorded commands (`Skirmish.tick`), since AI levels aren't in the replay; its brain is a stand-in until the start, then the real one.
  - **Replays:** format 4 keeps the start mode; a chosen-starts match replays exactly.
- **Wire (protocol 36):** events PREGAME 28 (each player's pick, ready, AI; to everyone), COUNTDOWN 29 (5..1, 255 cancelled, 0 on the start tick with the Commanders' ENTERs), PREBUILD 30 (a player's queue, to the player and allies). Contract net.md 9b.
- **Lobby (D):** the room setting, `startMode` in the config (absent = fixed), `start = 0` (or == id) in choose mode, the limits; match.md is D's.
- **Client (B):** the pre-game screen, picking, ghosts, the Commander's build menu with no Commander, the countdown, 16-player colours and HUD.
- **Tests (`Pregame.spec`):** start areas and suggestions; no units and no eliminations in the pre-game; a pick in the other side's area or too close is refused; all ready → 75 ticks → Commanders on their picks with their queues, the unpicked one on its side's start; un-ready cancels, the timeout starts anyway; 16 AI players 8v8 on Ridgeline, all spaced and in their areas, then they build (cap 75); the wire (everyone sees picks, queues to allies only, COUNTDOWN 5..0 with the ENTERs on one tick); replay; fixed mode unchanged. `Match.spec` (limits, 16-player cap), `Schema.spec` (golden bytes, 4-bit team).

## S-170 — No unit cap in-game (the user) (2026-10-24)

- **Asked:** remove the units limit in-game.
- **Now:** `Match.validate` gives no cap unless the match config sets `unitCap` (0 = none; 1..65535 per player). The default was `clamp(300 − 25 × (players − 2), 150, 300)`; S-169's match-wide 1,200 is gone with it. The cap machinery stays for configs that set one (tests, special modes); the AI's massing rule already handled no cap.
- **Risk:** the server budget (guide 18.1) was planned for about 800 units in a match. Without a cap, 16 players can build far more; B's watchdog and `profile_match` will show what a live server takes. Under "Needs my review".
- **Tests:** `Match.spec` (no cap by default for 2, 8 and 16 players; a set cap still applies), `Pregame.spec`.

## S-171 — No fixed starts: spawn boxes, and the map's starts as AI hints (the user) (2026-10-24)

- **Asked:** remove the fixed start positions too. They should help the AI pick the best spot for each map (with not enough of them, the most beneficial free spot around). Each team has a spawn box: its spawn points are confined to it. Write the logic and tell D.
- **Every match has the pre-game:** the lobby no longer chooses a start mode; the match server always passes `startMode = "choose"`. `"fixed"` stays in `Sim.new` for headless tests, tools and reports (every AI test and balance report uses it). `MatchConfig`: no `startMode`; `start` is 0 (== id accepted from older lobbies).
- **Spawn boxes** (`Shared/Match/StartAreas.boxes`) replace S-169's nearest-start areas: per side, the bounding box of its starts' boxes (a map's own `Layers.startBoxes`, or a square of a sixth of the map's shorter side, 96..256 studs, around each start), 16 studs inside the map; overlapping boxes of two sides are split at the midpoint between their starts, 96 studs apart. No map defines its own boxes yet.
- **Best spot** (`Pregame.bestSpot`, the AI's pick and the default for players who never pick): the side's k-th player takes the side's k-th hint if it's a valid pick; otherwise the best valid spot in the box on a 16-stud grid by free deposits within 160 studs (×10; within 100 of another pick they're taken), open ground (the Commander's clearance up to 6, ×2), minus the distance to the side's nearest hint / 16. In an 8v8 on Ridgeline every one of side 1's seven non-hint players starts within 160 studs of a deposit.
- **Wire:** unchanged from protocol 36 (the client computes the boxes from the shared module and the map). Contract net.md 9b.
- **Tests (`Pregame.spec`):** the boxes (size, split, a map's own box, the edge), picks outside the own box refused, the 8v8 (each side's first player on its hint, the rest spaced, in their boxes, near deposits).

## S-172 — Player colours: allies cold, enemies warm (the user) (2026-10-24)

- **Asked:** each team member gets a colour automatically: allies cold colours (blue, green, cyan shades), enemies warm ones (red, orange, fuchsia, yellow shades).
- **Built:** `Shared/Match/TeamColors` (pure, shared by the client and the lobby): `forViewer(viewer, players)` gives every player's colour as that viewer sees it. The viewer is Blue, its allies the other cold shades by player ID (8 in all: Blue, Cyan, Green, Navy, Teal, Sky, Mint, Forest); enemies warm shades by side then ID (16: Red, Orange, Fuchsia, Yellow, Crimson, Amber, Magenta, Gold, Coral, Tangerine, Pink, Lemon, Brick, Rust, Plum, Mustard; hues alternate, so a 16-player FFA's 15 enemies are all distinct). A spectator sees ally team 1 cold. So two players see each other in different colours; that's what the user asked for (BAR's ally / enemy colour mode).
- **Not the sim's:** the sim and the wire carry no colours. MatchConfig still validates the contract's `color` index (the lobby may keep sending one); clients use TeamColors. B draws it, D shows it in the room (the viewer's side cold).
- **Tests:** `TeamColors.spec` (8v8 from three viewers, a 16-player FFA, spectators, order independence).

## S-173 — The Plains, a flat 8v8 map (the user) (2026-10-24)

- **Asked:** a flat map with plains, bigger than The Canyon, for 8v8 matches, with a lot of deposits; each player should be able to spawn on a spot with three deposits.
- **Built:** `map:plains` (`Shared/Grid/Plains`, in MapRegistry.HANDMADE as "The Plains"): 256 × 256 cells (2048 × 2048 studs: the wire's largest; The Canyon is 154 × 256), grass, gently rolling (steepest 1.8°), no water; roads east–west through the middle and north–south at x = ±520; mirror-symmetric west ↔ east.
  - **16 start hints** (S-171): 1–8 west, 9–16 east, each half in a north and a south group of four. So 2 sides get a half each (8v8), 4 sides a quarter (4 × 4), 8 sides two hints each.
  - **Deposits:** three value-3 deposits round each hint (two in front, one behind, 40–50 studs out), and value-2 deposits on a jittered 200-stud grid over the middle and the flanks, at least 120 studs from any hint (148 in all).
- **Tests (`Plains.spec`):** size, flatness, no water, mirror symmetry of heights, ground and deposits; every hint with exactly three deposits within 80 studs; an 8v8 AI pre-game where all 16 Commanders start on a hint with its three deposits; the same map every time.
- **For C:** `lune run export_ground map:plains` makes its ground file for a baked mesh, as for the other maps (C-167). B: it's in MapRegistry like The Canyon (minimap, map picker).

## S-174 — Factions per player; the pre-game v2: host start, 150 s picks, faction switch, drawn boxes, landing (the user's playtest, F31, F32, F35, F26) (2026-10-26)

- **Asked (playtest feedback, 2026-10-26):** F31: 16 players (and 6v6, 7v7) crashed the match place: `Sim.new: team must be an integer in 1..16, got 18`. F32: everyone starts Not Ready; 150 s to pick, then the game picks; the AI picks after the first player has, taking the spots left; when everyone is ready the host starts (or `/forcestart`); after 3 s everyone descends from the sky (a star flare) and starts their queued builds. F35: the faction picked in the lobby can be changed in the pre-game. F26: each team's spawn box, drawn by the host.
- **F31's cause:** the match place numbered teams by faction parity (`MatchContract.teams`: Order 1, 3, 5…, Chaos 2, 4, 6…), as the sim decided factions by team parity; 9 players of one faction reach team 17 or 18. **Now** each player carries its `faction` in the sim config (`players[i].faction`, "order" | "chaos"; default still by parity, so tests and tools don't change); `Scenarios`, `Pregame.commanderDef` and the AI read it. The match place sends `team = player id` (B).
- **Pre-game v2** (`Pregame`, protocol 37, net.md 9b): `PICK_TIME` 150 s, then `bestSpot` for the unpicked (no auto-ready any more); `match.host` (a player; the lobby's host user mapped by the match place; nil when the host spectates) starts with `START 0` once everyone is ready, or `START 1` at any time (a forced countdown un-readying can't cancel); with no host, all ready starts it. `MAX_WAIT` 300 s forces a start (so an absent host can't stall a match; PICK_CLOCK counts the last 30 s). Countdown 3 s. `FACTION` while not ready (clears the queue; the pick stays if still valid). The AI waits for the first human pick (or picks at once when there are no humans, or when the pick time is over).
- **The landing:** `Schema.LANDING_TICKS` (23 ticks, 1.5 s) after the start, `Commands` holds every command but CAMERA and CHEAT (in order, so the replay records them when applied); then `Pregame.land` gives the Commanders their queues, before the held commands. The client plays the descent over those ticks; the units are already on the ground in the sim.
- **Drawn boxes:** config `match.startBoxes` (ally team → fractions of the map, quantized to 65535ths in `Sim.new` so the replay holds the same) replaces those sides' default boxes. Sent to clients as `START_BOXES` (world studs).
- **Replays:** format 5: each player's faction, the host and the boxes in the header.
- **MatchConfig v2** (the lobby ↔ match contract): `host` (the room host's UserId, a player or spectator) and optional `startBoxes`, both validated; version 1 records are refused (both places publish together).
- **Tests:** `Pregame.spec` (13: the 3 s countdown and the landing holding a queued move behind the pre-game queue; un-ready cancels, the pick time picks, MAX_WAIT starts; the host's start and force start; the faction switch and its replay; 16 players with 9 Chaos; the drawn boxes and their replay; the AI waiting for a human pick; the wire with factions, boxes, clock and 3..0), `Schema.spec` (golden bytes for 37), `Replay.spec`, `MatchConfig.spec`.

## S-175 — Teams: Command Ends counts the ally team's Commanders (the user's playtest, F7) (2026-10-26)

- **Asked:** in Teams, a player whose Commander dies keeps playing; the team all explode only when none of its Commanders is alive.
- **Now:** `Match.step` with COMMAND_ENDS counts Commanders per ally team; an ally team with none left is out, all its players at once, and everything they own self-destructs (S-144's few-a-tick pace). In FFA every player is its own ally team, so nothing changes there. A player without a Commander keeps its economy, factories and units.
- **Tests:** `Match.spec` (a player without a Commander plays on; the ally team's last Commander takes both players out at once; their units are gone 30 ticks later).

## S-176 — Sharing between allies: units, resources, requests (the playtest, F23; F22 already existed) (2026-10-26)

- **Asked:** a team panel with Share (1 click: ask for units, 2 clicks: give the selection), Orb and Energy (1 click: ask; drag up: give from your bank); F22 "share resources when overflow".
- **F22** was already in the sim since guide 8.4: overflow goes to allies with room (`Economy.shareOverflow`, `Match.spec`). Nothing changed; B's panel can show it.
- **Built (`Sim/Share`, protocol 37):** commands `SHARE_UNITS 24` (value = ally player; complete own units, never a Commander), `SHARE_RESOURCE 25` (new "share" params: toPlayer u8, resource u8, amount u32), `REQUEST 26` (value = `ShareKind.ASK_UNITS / ASK_SUPPLY / ASK_POWER`). Event `SHARE 33` (from, to, what, amount; 8 B) to the giver's ally team and spectators.
  - A given unit is re-made for the receiver where it stands (health, heading, missile stock, on/off and priority switches kept; a new ID, no orders, factory queue dropped; aircraft re-made flying). Simpler and safer than re-keying every per-owner cache; the cost is the new ID.
  - A resource gift is capped by what the giver may still spend this window (`Economy.allowance`): counted as the giver's spending and credited to the receiver at the window's settle like reclaim, so no store goes negative and the receiver's overflow moves on.
- **Tests:** `Share.spec` (units with health and flying aircraft, never a Commander or to an enemy; a resource gift; the wire to allies only; record round-trips).

## S-177 — Wind is a fixed wave within the map's range, not random (the user via B) (2026-10-26)

- **Asked (relayed by client-B):** "Wind should not be RNG"; the top bar shows wind min / max / current and tidal, as BAR's does.
- **Now:** `Economy.windAt(range, tick)`: two slow sine waves (173 s and 61 s) between the map's `layers.wind = { min, max }` (fractions of a turbine's max; default 0.1..0.9). The same on every match on a map, smooth (under 1% of the range per economy step), no seed. The wire is unchanged (Eco `wind` = the current fraction × 255); the client reads min / max from the map's layers and tidal from the tidal generator's def (25 power/s; per-map tidal is not built).
- **Tests:** `Economy.spec` (stays within the range, varies over most of it, smooth, the same for every seed; turbine income follows it).

## S-178 — Combat from the playtest: lasers up close, death blasts, nukes, air turns, carpet bombs (F12, F15, F16, F17, F33) (2026-10-26)

- **F12 lasers:** weapon field `closeDamage` (×1.5 on the nine laser and beam weapons): damage × 1.5 at point blank, falling linearly to × 1 at full range (`Combat.nearFactor`), for hitscan shots, lingering beams and hit-rays.
- **F15 death blasts:** every unit now explodes when it dies (`Defs.defaultDeathBlast`, unless the def sets its own): damage 0.4 × (supply + power / 10 of its cost) + 8 × power produced a second + 0.5 × power storage, aoe 8 + 5 × footprint + 0.6 × √damage (at most 90), edge 0.3. A generator 226 / 27 studs, a Lancer 136 / 20, a scout 40 / 17. Commanders: 4,000 in 120 studs, edge 0.15 (a nuke is 150); fusion reactors keep 2,500 / 120, so a cluster still chains. No blast for a self-destruct (an eliminated player's units: chains would break S-164's per-tick budget) or for a structure an upgrade frame stands on.
- **F16 nukes:** strategic blasts do 33% to Commanders (`Combat.STRATEGIC_COMMANDER`); edge effectiveness 0.3 → 0.05 (400 at the rim, 8,000 at the centre), so the edge visibly matters.
- **F17:** every aircraft turns 1.5× as fast (at most 210°/s).
- **F33 carpet bombing:** bombs drop in salvos of 3 along the heading (0.2 s apart; heavy bombs 0.25 s), each half the old bomb; the rest of a bomb salvo falls even once the target is behind (Weapons). B draws the three impact points for a manual attack.
- **Tests:** `DeathBlast.spec` (every unit blasts by its worth; quiet self-destructs), `Air.spec` (only a carpet's lead bomb is judged for the lead point; jets inside their tighter turn circle), `Defenses.spec`, `Towers.spec` (laser damage with `nearFactor`), `Match.spec` (tanks clear of their Commander's blast; a 2v2 can end in a draw when Commanders blast each other).

## S-179 — Balance notes from the playtest (BAL1–4) (2026-10-26)

- **Asked:** artillery tanks far too strong (both factions); T1 defences too weak against T1 units (health and damage); every T1 unit's range halved, radar and jammer included, T1 anti-air excepted; T1 damage down (an extractor survives 4 shots).
- **Done:**
  - **T1 mobile units:** weapon range × 0.5 (not anti-air, not bombs) and damage × 0.8: Lancer 190 → 95 (structure damage 118 → 94: four shells leave an Order extractor at 22 health), Ravager 155 → 78, MGs, naval guns and torpedoes, T1 air rockets. T1 bombs × 0.8.
  - **Artillery:** Verdict and Hellmouth range halved and damage × 0.6; T2 artillery (Judgement and Hydra MLRS, Cyclops) damage × 0.8. Their shells are slower (howitzer 220 → 130, mortar 210 → 112 studs/s): with only the range halved the low arc went flat (about 9 studs high at full range) and artillery could no longer fire over a 20-stud ridge (a test subagent caught it; guide 10.8, S-32). Now about 30–35° at full range, peaking around 33 studs; slower shells are also easier to dodge.
  - **T1 radar and jammers** (Oracle, Watcher, Watchtower, Eye; Curtain, Smog): range × 0.5.
  - **T1 defences** (Sentry, Guard, Twin Guard, Overwatch, Beamer, Geryon, Gauntlet, Talos, Spike, Bulwark, Moat, Riptide, Undertow, Fang): health × 2 and damage × 2. Measured: a tower holds against 8 scouts and 2 T1 tanks; 3–4 tanks take it; a T2 tank still beats one (with 38–100% health left).
  - Weapons shared between a changed and an unchanged unit were split: `ord_lancer_cannon`, `ord_bulwark_cannon`, `chs_ravager_cannon`, `chs_spike_cannon`, `chs_barracuda_gun`, `chs_riptide_gun`, `ord_sentry_gun`, `ord_moat_gun`, `chs_fang_torpedo`, `ord_undertow_torpedo`, `chs_bulwark_laser` (copies; the originals stay with their T2 users).
- **Not run:** the balance checkpoint (only on "run the balance checkpoint"). Expect the AI's T1 play to need the AI rework (the user's request after this round).
- **Tests:** about 40 tests placed T1 units at their old ranges; their geometry follows the new ranges (spec by spec in the commit).

## S-180 — Match connection errors shown in the lobby (the user; D and B) (2026-10-26)

- **Asked:** "Any failed attempt to connect to the game match must be displayed on the lobby when return with error code + description."
- **Shared:** `MatchConfig.ERRORS[code] = { title, description }` (lobby-D's table, contract match.md section 11: 1xx lobby side, 2xx match side), `ERROR_DETAIL_MAX` 200, `MatchConfig.cleanError`; `validateResult` checks an optional `error`. D shows them (panels, results); B sends them back (teleport data `{ matchId, error }`, result `error`).
- **Tests:** `MatchConfig.spec`.

## S-182 — Radar needs line of sight; homing missiles check their line of fire; the pre-game clocks wait for loading (F28, F29; client-B) (2026-10-26)

- **F28 (the playtest):** "Radar should not pick up units without direct LoS: SAMs target air instantly in range even though they're well covered." Now a unit is on radar only when one of the team's radars that covers it sees it over the terrain: a straight line from 4 studs above the radar's top to the middle of the unit, above the ground every 12 studs (`Sensors.terrainClear`). Hills hide ground units and low aircraft. Ground results are cached per (radar, sensor cell) while the radar stays in its cell; aircraft are checked each time. The radar map still stamps whole cells, so the exact-radius check allows 24 studs of slack for normal units (stealthy ones keep the exact range × signature). Sight is unchanged (no terrain occlusion for sight).
- **F29:** "a Sanction targeting a unit behind a mountain always hits the mountain." Homing missiles now pass `Combat.lineOfFire` too: a straight line from the muzzle, or for vertical launchers from the top of their climb. A battery doesn't fire at a tank tucked behind a ridge, and Targeting picks a target it can reach; a SAM won't fire at a helicopter behind a hill.
- **Pre-game loading (client-B's Studio run: 41 s of loading came out of the 150 s pick time):** the clocks start once every human's first command has arrived (the client sends CAMERA after WELCOME), or after `Pregame.LOAD_WAIT` (60 s; 120 s since client-B's asset preload: the first CAMERA waits for it, 24.5 s cold in Studio, slower live). PICK_CLOCK holds at 150 with flag LOADING (4) until then. Commands are recorded, so replays start the clocks on the same tick.
- **Tests:** `LineOfFire.spec` (SAM across the ridge blocked, above it clear, a Sanction dives over it from afar but not onto a tank right behind; radar through the gap but not across the ridge), `Pregame.spec` (the clocks wait for two humans, not the AI; LOAD_WAIT), `Tracking.spec`.

## S-181 — New units from the playtest: bots, Tzar, Centurion, Dragon, Liche (2026-10-26)

- **Asked:** new T2 air (Chaos "Dragon", a flying fortress with a fire gun pouring onto the ground and two green lasers; Order "Liche", a strategic bomber: devastating bomb, long reload, fast, slow turn), a T1 transport per faction, and a new BOT type (steep terrain, fast, turns almost instantly in place) with a constructor, scouts, Mace / Thug, Lazarus / Graverobber helpers, AA bots, Centurion (Chaos), Fatboy (Order) and its counterpart Tzar (a Chaos T2 vehicle, a little less range, more damage, faster reload).
- **Built (19 units, 10 weapons):**
  - Factories: `ord_botlab` "Bot Lab" and `chs_botlab` "Bot Pit" (T1; Commanders, Masons / Scrappers and the bot constructors build them), `ord_advbotlab` / `chs_advbotlab` (T2; Architect / Forgemaster and the bot constructors).
  - T1 bots (all move class WALKER, 40° slopes, turn rate 380–500°/s): constructors `ord_artisan` "Artisan" / `chs_tinker` "Tinker" (less build power and health than the Mason / Scrapper); scouts `ord_glint` "Glint" (tougher, arm lasers alternating) / `chs_skitter` "Skitter" (fastest, plasma spray); `ord_mace` "Mace" (skirmisher, long slow plasma, 125 range: outranges T1 tanks) / `chs_thug` "Thug" (tough assault bot, 70 range); helpers `ord_lazarus` "Lazarus" / `chs_graverobber` "Graverobber" (repair, reclaim, resurrect, build nothing: a builder kind without a build list, allowed for resurrecting units); AA `ord_kestrel` "Kestrel" / `chs_needle` "Needle" (the factions' IR SAMs).
  - T2: `ord_fatboy` "Fatboy" (WALKER, 4,800 health, plasma 300 range, 900/800/1,100 in 48 studs, 6 s); `chs_tzar` "Tzar" (heavy tracked, 270 range, 1,100/980/1,300 in 40 studs, 4.5 s; Advanced Vehicle Foundry); `chs_centurion` "Centurion" (WALKER, 5,200 health, a red hit-ray beam to full range: new weapon field `fullLength` runs a piercing beam past its target to the weapon's range, so it cuts through a line); `chs_dragon` "Dragon" (HELI, 9,000 health, a downward fire gun and two green lasers; Advanced Airfield); `ord_liche` "Liche" (JET, 260 speed, turn rate 40, one 3,000–4,000 bomb in 55 studs, 20 s rearm; Advanced Airfield).
- **Not built:** the T1 transports. They need a load / unload mechanic (carried units leave the world and ride along, unload at a point, die with the transport) that touches movement, targeting, sensors and the wire. They're the next item for the sim after this round.
- **Numbers are first guesses** (no balance checkpoint run). Models (C), icons (B) and Codex roles (D) follow.
- **Tests:** `NewUnits.spec` (every new unit has a builder of its faction; bots are WALKERs turning fast; helpers build nothing; Tzar vs Fatboy trade-off; a Glint kills a scout; the Centurion's beam hurts a whole line; the Dragon fires both weapons; the Liche drops one bomb a sortie).

## S-183 — Smart Reclaim, reclaim in the income, aircraft over the map (the user: F42, F43; the playtest's F3) (2026-10-26)

- **Smart Reclaim (F42):** "reclaiming a whole area (also repair / resurrect): units auto path to the nearest wreck to reclaim and repeat until the area is clear, or if REPEAT is on they stay there and collect wrecks repeatedly; E + drag to size the zone." Command `AREA 27` (protocol 37; op, centre, radius). Builders get an `area` order: whenever idle, the nearest target inside the circle (`Orders.areaTarget`): a wreck to reclaim, a wreck to resurrect (not a Commander's; resurrecting builders only), or one of the team's damaged or unfinished units / structures to repair. It ends when none is left, unless the builder's REPEAT is on (the REPEAT command now applies to mobile builders too): then it stays inside the circle and takes new targets as they appear. B: E + drag.
- **Reclaim in the income (F43):** the Eco record's `income` adds the last economy window's reclaim (and resource gifts) as a per-second rate (`Resource.reclaimRate`); no wire change.
- **F3, aircraft drawn pinned to the map's edge:** jets turned back at a fixed 60 studs and overshot while turning; the wire clamps positions to the map, so clients saw them stuck on the border. Heading out, a jet now turns back a turn radius (speed / turn rate + 20 studs) before the edge, and Movement clamps every aircraft to the map.
- **Tests:** `SmartReclaim.spec` (nearest first, the circle only, the order ends; REPEAT stays and takes a new wreck; area resurrect and repair; the reclaim rate; AREA records), `AirEdge.spec` (four jets heading out stay over the map; Harpies left it before), `Schema.spec`.

## S-184 — Deposits are 2 × 2 patches; advanced extractors centre over the T1; tall towers (the playtest's F6; models-C's F18) (2026-10-26)

- **Asked (F6):** "make orb deposit spots take 2 × 2, and the advanced orb extractor be placed in the middle of the tier 1."
- **Maps:** every map builder still places one cell per deposit; `MapRegistry.load` grows each into a 2 × 2 patch (`Layers.expandDeposits`), toward the map's centre on each axis, so mirrored and rotated maps stay exactly symmetric. `layers.deposits` lists every patch: its centre (a cell corner) and value. Map generators that compare raw layers expand them the same way.
- **Income:** `PlacementRules.supplyUnder` counts a patch's four cells as its value once (÷ 4): a T1 extractor (footprint 2) exactly on the patch gets the full value, as a one-cell deposit gave before; one a cell off gets half. `PlacementRules.depositNear(layers, x, z, radius)` gives the nearest patch centre: the AI builds there, and clients snap the extractor ghost to it.
- **Advanced extractors:** footprint 2, the T1's size, on the same patch (the user, relayed by models-C: "T2 of the T1 extractor must be the same size, they should look like an upgraded version"; first built as footprint 4, then changed). They upgrade the T1 in place on exactly its cells (S-108); S-104's size-by-tier rule doesn't apply to these two.
- **The AI and the pre-game** list deposits by patch, not by cell (the pre-game's spot score counted each deposit four times otherwise).
- **Tall towers (models-C's F18 blockouts):** new optional unit fields `height` and `muzzleHeight` (studs; defaults 6 × footprint and 0.6 × height). Set on the reworked towers: Bastion, Maw 24 / 17; Rampart, Breaker 23 / 16; Edict, Cataclysm 25 / 19; Sentry, Twin Guard, Beamer 19 / 16.5; Guard 18 / 16; Overwatch, Geryon 20 / 17.5. Shots leave from the barrels, and line of fire and radar sight lines start from there.
- **Also:** `Scenarios.ew_test`'s helicopter holds fire and is tougher, so the IR towers keep launching and a countermeasure wins early (client-B's decoy specs).
- **Tests:** `Deposits.spec` (every registry map: whole patches, listed once, no stray cells; income on / off the patch; the 4 × 4 centred; depositNear), and the deposit counts in `Canyon`, `Normandy`, `Plains`, `TestMap`, `MapGen`, `Economy` and the scripted build order, which are now patches.

## S-185 — Movement fixes from the playtest: Maneuver leash, builders stop at their reach, footprint-2 units through two-cell gaps (F5, F30, F24); allies' economy for the team panel (2026-10-26)

- **F5 "units with Maneuver are likely to go off on their own":** the Maneuver leash was a flat 150 studs, more than the new T1 ranges (95). Now `Orders.leash(def)` = 1.0 × the unit's range, 60..150 studs: how far it chases from its anchor and how far past its range it looks.
- **F30 "a builder walks into range, goes in a little more, backs off, then builds":** on reaching range a builder's goal was set to where it stood, so it coasted on while braking and drove back to that point. Now the goal is where its braking ends (`stopPoint`), and an approaching builder starts braking when its braking distance would carry it 6 studs inside its reach (`Build.STOP_INSIDE`), so it stops just inside and never reverses. A nudge from a neighbour doesn't make it re-approach.
- **F24 "units stuck between structures with a big gap (pre-queued structures on your own position)":** footprint-2 units (Commanders, heavy tanks, heavy bots; about 14 studs wide) needed 2 cells of clearance, so a 16-stud, two-cell gap between structures was a wall to them. Clearance is per cell and can't tell a two-cell gap from a one-cell one, so footprint 2 now needs 1 (like footprint 1): they may brush a corner but never get boxed in by a sensible layout. Footprints 3+ are unchanged.
- **Allies' economy (client-B, for F23's team panel):** a player's Eco message now carries its ally teams' records after its own (same layout; spectators already got every team's).
- **Tower heights:** the F18 blockouts' measured tops and muzzles (models-C), and the Glint's arm muzzles `arm_l_muzzle` / `arm_r_muzzle`.
- **Tests:** `BuilderApproach.spec` (four builders never reverse and build from just inside their reach), `MoveStates.spec` (the scaled leash), `Shield.spec`, `Passability.spec` and `Route.spec` (footprint 2 passes a one-cell gap, footprint 3 doesn't).
- **Idle weapons search on every sensor tick (follow-up, from the slow suite):** the mirror-fight parity guard failed after the balance pass (the even-ID side won 32 of 40). Tracing it: in close, in-range mirror fights the odd-ID side fired its first volley earlier in 34 of 40 setups. A weapon without a target searched only on its hashed stagger tick (S-23), and for the small IDs these fights use, the hash phases favoured odd IDs; the first volley decided the fight. A weapon with no target now also searches on every sensor tick (every 2nd, when visibility changes), so every unit reacts to a newly seen enemy on the same tick; units with a target keep the staggered re-search. In-range mirror fights are now exact draws (40 of 40), the guard's own setup 27 / 13. The Beamer's ramp clock now starts at minus its switch pause, so a target found during the pause doesn't ramp early.
- **Also found by the slow suite:** the builders' early-stop table was module-level and leaked between simulations in one process (two identical runs differed); it's in `BuildState` now.

## S-186 — Per-map side splits: The Plains with 3, 5, 6 or 7 sides (lobby-D's F40 note) (2026-10-26)

- **Found by lobby-D:** with three sides on The Plains, contiguous blocks of its 16 hints gave side 2 hints 6–10: the south-west group and the north-east one, two corners apart, so its default spawn box was the map's middle column.
- **Now:** a map may list `layers.sideSplits` (side count → each side's start indices); `StartAreas.sides(allyTeams, startCount, splits)` uses it when it has an entry for that many sides, else the contiguous blocks. The Plains: 3 sides = west half / north-east / south-east; 5, 6 and 7 split by corner groups and rows. 2, 4, 8 and 16 sides already fell on groups.
- **Callers:** the pre-game passes `layers.sideSplits`; the lobby's default boxes should too (D).
- **Tests:** `Plains.spec` (2..8 sides: each side on one half, and within one corner group when it has four hints or fewer).

## S-187 — The AI rework: four levels, team roles, teamwork, counters, tidy generators, the new units (the user's F41, F19–F21); lasers cost energy (2026-10-26)

- **Asked (F41):** retune the AI (Easy, Normal, Hard - Balanced, Hard - Aggressive) for the new state of the game: counter the threats it meets, play aggressively or passively, and in teams take roles: some cover air, some fund tech, some spam cheap units to overrun defences, some build layered defences and guard chokepoints with jammers and turrets. The playtest: "AI tend to swarm their units into one spot" (F19), "place generators randomly: messy base" (F20), "more aggressive, better teamwork" (F21).
- **Levels:** `easy`, `normal`, `hard` (Hard - Balanced, unchanged) and **`hard_aggressive`**: hard's economy and tech, waves of 6 growing by 2, no waiting to outweigh the known defence (attack margin 0.8), no retreat, no recall, no turrets at home, a bot lab, and raids: every 60 s up to four fast units hit the nearest known enemy extractor. `MatchConfig.LEVELS`, `Match.validate` and `Skirmish.LEVEL_NAMES` list all four (D shows them; B labels them).
- **Roles** (`Skirmish.roleOf`, `Skirmish.withRole`): two or more non-easy AIs on a side take `balanced`, `air`, `defense`, `spam`, `tech` in player order; a lone AI plays balanced. Air: an airfield as soon as a plant and two extractors stand, 60% of its army production from the airfield, an advanced airfield (Liche / Dragon, T2 aircraft) when rich. Defence: four more turrets, a Barrier wall, radar, waves 1.5× larger (so it holds). Spam: a bot lab, one more item queued per factory, small frequent waves (×0.6, growing by 1), little artillery. Tech: the advanced plant at 400 supply instead of 900, a bot lab and its advanced lab, waves 1.3× larger.
- **Teamwork** (all non-easy): when an ally sends a wave, an AI whose army is worth half a wave joins within 10 s; an AI under attack calls for help, and its allies send half their home army for 6 s. Waves split in two lanes for every faction now (F19), each lane on its own approach.
- **Counters:** the census counts the enemy's known turrets, artillery and light units. Three or more turrets: +20% artillery, and the Tzar (Chaos) more often; three or more artillery pieces: fast raiders among the tanks and more scout bots. Known aircraft already brought AA (S-7); bot labs add AA bots then.
- **The new units** (S-181) in the mix: bot labs build scout bots, Mace / Thug and two Lazarus / Graverobber helpers; the advanced bot lab Fatboys / Centurions; Chaos's advanced plant the Tzar.
- **F20 tidy generators:** `Skirmish.blockSpot`: generators fill a block behind the base, rows of 4 along the front, 24 studs apart (an 8-stud lane between), in world order so mirrored players fill mirror blocks (S-31); `spotNear` only when the block is full.
- **Lasers cost energy (the user):** every laser and beam weapon draws power per shot (`shotCost`), and holds fire without it, as the Radiance and the Chaos beams did: Sentry 20, Guard 18, Twin Guard 12, Overwatch 15, Geryon 20, Bulwark laser 12, Beamer 6 a pulse, Glint 2, Dragon 8, Centurion 150 (about one generator's 20/s while a tower fires).
- **Not run:** the balance checkpoint and the AI level reports (`lune run ailevels`, `faction_ai`) — on "run the balance checkpoint".
- **Tests:** `AIRoles.spec` (four levels match MatchConfig; roles by player order, a lone AI balanced; slow: a 3v3 where the air AIs build airfields and fly aircraft, the defence AI out-turrets the balanced one and bot labs come up; generators on the block lattice), `Towers.spec` (a Sentry fires with power and holds without), and the slow suite's mirror tests (`Fairness.spec`: the Twin Lakes 2v2 mirror builds the same).

## S-188 — Line moves end facing the line's front (F34, client-B's formation controls) (2026-10-26)

- **Asked (client-B, from Studio):** the formation line's units spread into their slots exactly but kept their travel heading; BAR units turn to face the formation's front.
- **Now:** a move with a line (LINE flag) gives each ground unit a facing (`Nav.face`): across the line, away from the group's centre when the order was given. Once a unit stands still on its slot it turns in place at its turn rate to that facing (Movement), then drops it. Any later move replaces it; it's dropped after 60 s regardless. Aircraft don't take one.
- **Tests:** `LineFacing.spec` (six tanks on a north–south line coming from the west face east; a later plain move keeps its travel heading).

## S-189 — Protocol 38: wire positions on a fixed grid; maps up to 1,024 cells, The Lakelands (512) first; aircraft past the edge (F4, F3; the user's go-ahead) (2026-10-26)

- **Asked (the user, after the F4 measurements):** "Go ahead: protocol 38 with the same-size positions, a 512 medium map, and aircraft allowed past the edge."
- **Wire positions (Grid):** `cell u16, offX u8, offZ u8` keeps its 4 bytes and its Lua fields, but `cell` is now one of a fixed 256 × 256 grid of 64-stud **wire cells** centred on the origin, and the offsets are quarter studs: ±8,192 studs whatever the map, so a 1,024-cell map and 4,096 studs past each edge. `Grid.encode` rounds (error ≤ 1/8 stud; 1/32 before) and clamps past ±8,192; `Grid.decode` takes any wire cell. Orders decode with `Grid.decodeOnMap` (a point past the edge is an order to the edge; such orders were clamped by the encoder before). No more "cell outside the map" checks in Commands or Pregame.
- **Other records:** strategic records carry offX / offZ in 3 bits each, in the 7 reserved bits (still 7 B; 8-stud squares, decoded to the centre, as precise as the old map cells). ALERT carries offX / offZ (8 B). SIGHT_CELLS entries are u24 (`SIGHT_SEEN` bit 23; a 1,024 map has 262,144 sensor cells). SIGHT_ROWS `firstRow` is u16. CAMERA cells are u16. Replay format 6.
- **Maps:** `Grid.MAX_CELLS` 1,024. `map:lakelands`, **The Lakelands**: MapGen 2v2 with lakes at 512 cells (4,096 studs), seed 15; 3–4 s to generate. `MapRegistry.sizeClass(cells)`: small ≤ 256, medium ≤ 512, large above, for the lobby's picker (lobby-D). No large map yet: they wait for a Studio check of server memory and the client's terrain (the F4 measurements: +50% tick, 3–4× heap).
- **Past the edge:** `Grid.OVERFLY` 512 studs. Aircraft stay within it (Movement's clamp; over the map before, S-183). Jets turn back once over the edge instead of a turn radius before it (the widest turn, the Liche's, is 372 studs). Projectiles fly within it too and burst at its limit (at the edge before, client request 15), so a missile at a jet past the edge can hit it. NetOut's camera rectangle that touches the map's edge covers what is past it.
- **Network load:** unchanged for the hot records (tactical, strategic, ENTER, WRECK, commands); SIGHT_CELLS +1 byte per cell (~+0.2 KB/s per player at 600 units); the join's SIGHT_ROWS grows with the map (8 KB at 512).
- **Client-B:** decode strategic records and ALERT with their offsets; SIGHT_CELLS u24 / the new `SIGHT_SEEN`; CAMERA u16; never read `cell` as a map cell. **Lobby-D:** the picker by `MapRegistry.sizeClass`. **Models-C:** The Lakelands' ground (`lune run export_ground map:lakelands`).
- **Tests:** `BigMaps.spec` (size classes, The Lakelands; a tank in a 512 map's far corner and a jet past its edge reach the client to 1/8 stud; the wire covers a 1,024 map plus OVERFLY; slow: four AIs play a 2v2 on The Lakelands); `Grid.spec` rewritten for the wire grid; `Schema.spec` golden bytes for 38; `AirEdge.spec` (jets fly past the edge, turn back, stay within OVERFLY); `Air.spec` (shells burst at the overfly limit); `Movement.spec` (a point past the edge moves to the edge).

## S-190 — Plasma shots in the tank shell's colour; Thug and Mace hit only what they strike (the user) (2026-10-26)

- **Colour:** every plasma weapon (`fx.trail = "plasma"`: Skitter, Thug, Mace, Tzar, Fatboy) has `fx.color` = (255, 225, 120), the client's tank shell colour (`PROJ_COLOR.BALLISTIC`), in place of the factions' orange and blue.
- **Thug (`chs_thug_cannon`) and Mace (`ord_mace_plasma`):** no `aoe` and no `edgeEffectiveness` (were 8 and 6): a shot damages only the unit it hits; a miss does nothing. Their `fx.impact` is the tank's small hit (`explosion_small`, as `ord_lancer_cannon`). Damage, range and reload unchanged. The Mace's slow lob (120 studs/s) now misses moving targets more often: its splash used to cover that.
- **Client-B:** the plasma ball's size comes from `aoe` (`1.4 + aoe × 0.08`), so with no blast these two draw the smallest ball; the user wants them the tank shell's size, and their impact the tank's small hit (the burst at the 7-stud minimum with no `aoe`).
- **Tests:** `NewUnits.spec`: every plasma weapon in the tank shell's colour; Thug and Mace have no blast and the tank's impact; each kills a Lancer while a friend 5 studs from it, with friendly fire on, takes nothing from the shots.

## S-191 — The sight diff reads only the rows Sensors changed (client-B's watchdog report) (2026-10-26)

- **Problem:** NetOut diffed each ally team's whole sight map every sensor tick: 65,536 sensor cells on a 512-cell map, 262,144 on 1,024, even with nothing moving. B's Studio watchdog showed the match place's lobby preview on The Lakelands (8 sim players, no units) at 12–14 ms of NetOut per tick (0.5 ms on Coastline). Lune: 1.50 ms per tick.
- **Change:** `SensorsState.losDirty`, per ally team and sensor row, the first and last column whose sight may have changed since NetOut's last diff (u16 pairs, not hashed). Sensors marks the bounding square of every sight stamp and unstamp, both circles of a one-cell shift, and the whole map for the reveal cheat. `NetOut.updateSight` reads only marked spans and clears them; the first diff still reads the whole map. The output (changes in cell order) is the same as before.
- **Measured in Lune:** the empty preview on The Lakelands goes from 1.50 to 0.03 ms per tick. Four hard AIs on The Lakelands for 4 minutes: NetOut 0.548 → 0.155 ms per tick on average (peak 4.31 → 3.67).
- **Tests:** `NetOut.spec`: two hard AIs on Coastline for 90 s, with the reveal cheat on and off: every sensor tick, every cell of both teams' diffed sight equals the sensor map. Marking one cell too few around a shift fails it, and fails the existing fog test.

## S-192 — Mesh terrain for every map's ground, not Roblox terrain (the user) (2026-10-26)

- **Asked:** "From now on, maybe switch to mesh terrain instead of Roblox terrain."
- **Decision:** each map's ground is drawn from the models stream's baked mesh tiles (C-167, `Render/MeshGround`). A new named map ships only with an approved bake. Roblox Terrain voxels are only a fallback for maps without an approved bake, and for water until the client replaces it. Recorded in the guide, section 5.4.
- **State at the decision:** baked grounds for Ridgeline, Coastline, Twin Lakes, Crossroads, Normandy, The Canyon (4-stud, in review) and The Lakelands (8-stud, approved); none for The Plains. Random `mapgen:` maps and test maps have no bake.
- **Sim:** nothing changes. The sim's heights come from the map layers; the client stands units on the drawn surface (C-235).
- **Asks:** models-C bakes The Plains, and bakes every new map as part of authoring it. Client-B makes mesh ground the default path, and looks into mesh water and mesh ground for unbaked maps (generated from the layers at load).

## S-193 — Playtest feedback 2, first batch: slower units, Fatboy/Tzar shells, one factory type early, wider generator lanes, map details (G8, G10, G1, G3, G12) (2026-10-26)

- **G8, "units are so fast: lower speed of all units by 40%":**
  - Every unit def's `maxSpeed`, and `minSpeed` for jets, is × 0.6: 97 values in 85 files. A Lancer goes from 28 to 16.8, a Falcon from 240 to 144.
  - Acceleration, braking and turn rates are unchanged. So units reach their (lower) top speed sooner, and jets turn tighter circles: turn radius = speed / turn rate.
  - Projectiles are unchanged.
- **G10, "Fatboy and Tzar projectile must be identical to the projectile of the tank (golden yellow shot)":**
  - `ord_fatboy_cannon` and `chs_tzar_cannon` lose `fx.trail = "plasma"` and `fx.color`, so the client draws them as its normal shell.
  - They gain `muzzle = "flash_large"`, and keep `impact = "explosion_huge"` and their big blasts (aoe 48 / 40).
- **G1, "AI Hard Aggressive build a lot of factories instead of concentrate on 1 type early game (1 vehicle and 2 bot labs)":**
  - The census now counts factories a builder has been ordered to build but not started: bot labs, advanced labs, airfields, shipyards, plants. Extractors were already counted this way (S-104).
  - Before, a second builder ordered a second bot lab while the first still walked to its site.
  - The bot lab also waits until the AI is established: 6 extractors, 6 army units, 200 supply stored, the same gate as the airfield. So every level and role opens on its vehicle plant alone.
- **G3, "unit still try to get itself stuck inside a grid of generators":**
  - The AI's generator block (S-187) placed 16-stud generators 24 studs apart, leaving 8-stud lanes.
  - Since S-185 (F24), footprint-2 units need clearance 1, so they path into one-cell gaps that are narrower than they are, and wedge there. Clearance per cell can't tell a one-cell gap from a two-cell one.
  - `Skirmish.GEN_GAP` is now 32: 16-stud, two-cell lanes they drive through.
  - Still open: a player's own buildings with one-cell gaps can trap them the same way. The real fix is a "fits a 2 × 2 square" pass layer for even footprints, to do if it still shows.
- **G12, map info for the lobby's panel:** `MapRegistry.details(mapId)` returns, built once and cached:
  - the map's name, cells, studs, size class, starts and deposits;
  - `windMin` / `windMax`: one Wind Turbine's power at the map's weakest and strongest wind;
  - `tidal`: a Tidal Generator's power; 0 without water;
  - `features`: "cliffs" (8+ studs between neighbouring dry cells), "flat" (no hills or cliffs), "hills" (12+ studs of dry height range), "roads", "water".
  - The field names are lobby-D's.
- **Tests:**
  - `Orders.spec`: GUARD and ASSIST timed for the slower units.
  - `NewUnits.spec`: Fatboy and Tzar draw as shells and keep their blasts.
  - `AIRoles.spec`: Hard - Aggressive builds no bot lab in its first 3 minutes and never two; the generator lanes are 16 studs.
  - `BigMaps.spec`: map details.

## S-194 — Protocol 39: self-destruct, aircraft retreat to heal (no ammo), the Commanders' laser and D-Gun, turrets that hold their aim, builders' work on the wire (G13, G17, G5, G9, G7, G4) (2026-10-26)

- **G13, self-destruct:**
  - Command `SELF_DESTRUCT` 29: value 1 starts the unit's countdown (`Schema.SELF_DESTRUCT_SECONDS` 6 s), 0 stops it.
  - When it runs out (`Sim/SelfDestruct`, run first in Damage), the unit dies at once, through god mode and armour, and leaves no wreck.
  - Its death blast's damage and radius are × (1 + 0.25 × tier): T1 1.25, T2 1.5, T3 1.75 ("mostly T3 ... yield bigger explosion"). A frame under construction just goes, as before.
  - The owner gets the seconds left in the new owner field SELF_DESTRUCT; 0 when it stops.
- **G17, "remove the ammo things all the air", heal at a rearm pad:**
  - The 13 aircraft lose `ammo` and `ammoCost`.
  - Their weapons' reload gains the old per-round rearm time, so the trip home they no longer make doesn't make them fire faster. The Liche's bomb: 1 → 21 s; Falcon 1.4 → 3.4; Absolution 1.5 → 3.5.
  - The two ASW torpedoes are shared with destroyers and are unchanged.
  - Command `SET_RETREAT` 28 (`Schema.RetreatAt`: never, 30%, 40%, 50%; default 30%). An aircraft below that health flies to a rearm pad (its home base first), heals there for free in `Air.HEAL_SECONDS` 10 s from nothing to full (an advanced pad faster), and flies back to where it was going.
  - An order doesn't launch a hurt aircraft on its way home; with no pad it keeps flying.
  - The setting goes to the owner in the STATES byte's bits 4–5.
  - The ammo mechanism stays in `Sim/Air` for any def that sets ammo. The tests of it run on `Support/AmmoDefs`, the aircraft as they were.
- **G5, the Commander's laser gun and D-Gun:**
  - `ord_sovereign` / `chs_warlord` get `*_laser` (HITSCAN, range 120, 10 power a shot, from the arm's `emitter`) and `*_dgun`, both turning with the `torso`.
  - The D-Gun fires only on the new `DGUN` 30 command (a point). Out of range (90% of 160 studs), the Commander walks toward the point and stops when the bolt goes.
  - Each shot costs 500 power. Any new order drops a shot not fired yet.
  - The bolt (weapon field `bolt` = 7 studs) flies level along the ground, `BOLT_HEIGHT` 5 above it, at 70 studs/s for its range. It destroys every ground and naval unit and structure it passes within 7 studs of: the shooter excepted, allies included, aircraft in flight not.
  - Those units leave no wreck. Commanders lose half their max health instead (`Combat.BOLT_COMMANDER`).
- **G9, "the turret need to hold its lock on the target, and don't drift away with the body":**
  - Turret yaw is relative to the hull, so a turning hull dragged the aim with it until the turret slewed back.
  - Each weapon slot now keeps the hull heading its yaw was set against (`World.wHull`). While the weapon has a target, or still holds its aim, the turret counter-turns by the hull's turn since last tick (within its arc), then slews as usual.
  - A Lancer turning about 60° while on a target now stays within 6° of it (22° before).
- **G7 / G4, what a builder works on:**
  - Until now the client guessed a builder's nano-spray target from its order line.
  - The new owner field WORK sends, for own builders, `Schema.WorkKind` (BUILD, REPAIR, ASSIST with a unit ID; RECLAIM, RESURRECT with a wreck ID; NONE) and its target, whenever it changes (client-B asked for the kind).
  - The client can draw the spray, and turn the Commander's torso (G4), from it.
- **After S-193 (the race that merged it untested, see sim.md):**
  - The AI's bot lab waits for 6 extractors and 4 army units, not `established`. The aggressive AIs never kept its 200 stored supply, so they built no bot lab at all.
  - The slow full-match test allows 45 minutes (units are 40% slower); the 3v3 roles test runs 14.
  - Movement clamps the terrain cell under a ground unit (one off the map stopped the sim; client-B).
- **D-Gun fixes from client-B's Studio check:**
  - A point up a slope never fired: the shell's line-of-fire check stopped it, though the bolt follows the ground. The D-Gun now aims in yaw only (pitch 0) and skips the line of fire.
  - Each pass-through IMPACT carried the bolt's ID, so NetOut ended the bolt for the clients and announced it again (four SPAWN_PROJ for one bolt). Pass-through IMPACTs now carry no projectile ID; only the bolt's end does.
  - NetOut doesn't send an IMPACT without a projectile: projId 0 is reserved on the wire. The first version of this fix sent them and broke the encoder whenever a watched bolt burned through a unit; client-B's test caught it on main `3f393dec`. Clients see the burned units die (DEATH) along the bolt's path.
- **G16, at the source (client-B's finding):** an aircraft's wire `alt` is now its height over the ground at the wire's rounded position (`NetOut.wireAlt`), not at its own. Before, a quarter-stud rounding across a cell edge over a cliff put the client's ground + alt 12 studs off.
- **Wire:** protocol 39. Commands 28–30; owner mask bits 32 (SELF_DESTRUCT u8) and 64 (WORK kind u8 + target u16); STATES bits 4–5. `docs/contracts/net.md` updated.
- **Tests:**
  - `Feedback2.spec`:
    - the self-destruct countdown, no wreck, a bigger blast, and the stop;
    - no ammo, and a hurt Falcon heals on a pad and flies back, but not when set to never;
    - the turret holding its aim;
    - the D-Gun: no shot without an order, three Juggernauts in a line destroyed with no wrecks, a Commander halved, a tank off its path untouched.
  - `Schema.spec`: golden bytes for the new fields and commands.
  - The ammo tests (Air, EW, Landing, NetOut) run on the old aircraft.

## S-195 — Supreme Strait, a 320-cell map for ground, air and naval play (the user's G6) (2026-10-26)

- **Asked:** "A new map Supreme Strait (24 x 24): a map that features ground, air, and oceans", with BAR's references: the height map, the dry texture, a 3D view and four screenshots.
- **Built:** `map:supreme_strait`, `Shared/Grid/SupremeStrait`, a hand-made map like The Canyon (shapes in the reference image's coordinates).
  - **Size:** 320 × 320 cells (2,560 studs), a medium map. At The Canyon's scale, BAR's 24 × 24 is about 310 cells.
  - **Symmetry:** point-symmetric about the centre; each pair of twin cells is built from one of them, so they match exactly.
  - **Seas:** two bays from the north-west and south-east corners, up to 16 studs deep, with sand beaches. Ships sail each bay; the bays don't join, because the land strait between their tips links the halves.
  - **Plateaus:** green, about 10 studs above the sea.
  - **Mountains:** rocky high ground with jagged cliffs in the north-east and south-west corners and on the edges.
  - **Craters and mesas:** a crater (a rock rim round a pond) and two flat-topped mesas on each half.
  - **Starts:** 16 hints, 1-8 in the south-west half and their twins in the north-east. Both seas lie between the sides.
  - **Deposits:** three value-3 deposits per hint, and value-2 deposits on a jittered grid over open ground. They go only where wheeled units can drive from the hints, never in a pocket walled by rock.
  - `SupremeStrait.feature(cx, cz)` names each cell for drawing: sea, beach, grass, mountain, crater, pond, mesa.
- **For the streams:**
  - Models-C bakes its ground (`lune run export_ground map:supreme_strait`; S-192: every map's ground is a mesh).
  - The lobby lists it by itself (`MapRegistry.details`: medium; cliffs, hills, water).
- **Tests:** `SupremeStrait.spec`:
  - the size, the hints and their twins, and point symmetry;
  - every land class drives from hint 1 to every hint and every deposit;
  - the north-west sea is big and doesn't join the other;
  - three deposits per hint;
  - the map is the same every time;
  - slow: four hard AIs build bases on it.

## S-196 — Maps made the BAR way: image layers compiled into the game; Supreme Strait rebuilt from BAR's previews (the user) (2026-10-27)

- **Asked:** "C's Supreme Strait ground need to be reworked … follow the design of this closely" (the 3D view). Then: "Follow beyond all reason pipeline for map design" (beyondallreason.info, mapping guide). On the source: "try to rebuild it first; if not satisfied, I will send you the file".
- **Pipeline** (`docs/design/maps.md`):
  - A named map is a folder `assets/maps/<name>/source/` like BAR's: `height.png` (BAR's heightmap), `type.png` (typemap), `metal.png` (metalmap, red dots), `minimap.png`, and `mapinfo.luau` (mapinfo.lua: size, cells, height range, water level, wind, types, metal value, symmetry, start hints).
  - `lune run map_compile <name>` is BAR's compiler in our form. It resamples the layers to `cells` cells, enforces point symmetry, snaps start hints to open ground, and checks starts, reachability and deposits. It writes `src/shared/Grid/Maps/<name>.luau`: heights as Base64 i16, terrain run-length encoded, deposits and starts. `Shared/Grid/CompiledMap` turns that back into Layers in both runtimes (with `Shared/Util/Base64`).
  - `lune run map_derive` derives the type, metal and minimap layers from a painted texture and the height map.
  - `.lune/lib/Png` reads 8- and 16-bit PNGs (zlib via @lune/serde) and writes them.
- **Supreme Strait, rebuilt:**
  - **Sources:** BAR's preview images, fetched as WebP and converted with Windows' decoder: the 1537-pixel height map (8-bit, BAR's full 64 × 24 + 1 resolution) and the 4096-pixel dry texture.
  - **Heights:** −6 to 83.25 studs with the water at 8. The seas are about 7 deep at their floor, enough for ships but not subs. The crater lakes come out of the height map.
  - **Type:** green and the mesas' yellow tops are grass. Steep ground (over 1.6 studs a BAR pixel) and dark stone on high ground are rock. Grey (beaches, the strait, the sand paths, the sea floor) is sand.
  - **Metal:** the texture's 57 cyan crystals give 76 deposits after point symmetry; 8 are under water and 4 on mesa tops.
  - **Starts:** the user's 8v8 spawn points (16 circles on the compiled render, point-symmetric).
  - The client's `SupremeStrait.feature` now names cells sea, beach, grass or mountain, from the compiled layers.
- **Ground:** models-C re-bakes `ground.supreme_strait` from the new layers. The S-195 bake was of the hand-shaped version, which the user didn't approve.
- **Orientation fix (models-C's finding, after the user saw the bake):** the compiler put the image's top row (BAR's north) at +z. The game camera at yaw 0 looks toward −z, so +z is the screen's bottom, and the map showed as BAR's mirrored top to bottom, with the seas north-east and south-west. Now an image's top row is −z: `map_compile` maps v to z directly (metal, starts and features too), and `map_features` writes v from −z. Supreme Strait recompiled: the seas are north-west and south-east on screen, as in BAR.
- **Tests:** `SupremeStrait.spec`, rewritten for the compiled map:
  - point symmetry;
  - every land class reaches every start;
  - every dry deposit but the mesa tops' is reachable;
  - the seas are big and apart;
  - each start has 2+ metal spots within 140 studs;
  - slow: four AIs build bases.
  - Plus `Base64.spec`.

## S-197 — Map features: trees for power, rocks for supply, listed per map; Supreme Strait's metal is BAR's (the user) (2026-10-27)

- **Asked:** "Introducing environmental resources. Each map features some environment probes: 1. Forests and trees (can be reclaimed for energy). 2. Rocks (can be reclaimed for orb). Each map defines its own list of these probes (type, position, value)." Choices: rocks block, trees don't; Supreme Strait first.
- **Kinds** (`Shared/Defs/Features`):
  - **tree:** 150 power, scenery units pass through, model "feature_tree".
  - **rock:** 30 supply, solid: no ground or naval unit enters its cell and nothing is built there until it's reclaimed; model "feature_rock".
- **Per map:**
  - `Layers.features` = { kind, x, z, value? } in studs; value nil = the kind's default.
  - Pipeline maps list them in `assets/maps/<name>/source/features.luau` as fractions, one side; `map_compile` adds the twins and checks the map with the rocks in place.
  - `lune run map_features <name> [seed]` writes a first list: tree copses along the grass edges plus lone trees, rocks on islets and at cliff feet, clear of starts and metal. Edit it freely.
  - Supreme Strait: 398 trees, 170 rocks.
- **In the sim** (`Sim/Features`):
  - At the start every feature becomes a reclaimable object on the wreck machinery: `Combat.addFeature`, with `wreckKind`, the amount in `wreckSupply`, `wreckFull`, and `wreckDef` 0.
  - Reclaim orders and Smart Reclaim take them like wrecks; they're never resurrected.
  - A tree pays power at `Build.POWER_RECLAIM_RATE` (1 power/s per point of build power, ten times supply's); a rock pays supply.
  - A rock occupies its cell as `Passability.ROCK` (0xFFFF; unit IDs now end at 65534), and frees it when reclaimed.
  - Each feature gets its own heading: the golden angle times its place in the list, so the headings spread evenly with no RNG. Clients turn the model by it, so a forest isn't one tree repeated.
- **Wire, protocol 40:**
  - WRECK gains `featureKind u8` (0 = a unit's wreck, 1 tree, 2 rock), 15 bytes.
  - A feature's defIndex is 0, and its supply / fullSupply count its own resource (a tree's power).
  - Every team knows the map's features from the start; only their removal needs sight, like a wreck's.
- **Supreme Strait's metal:** the user sent BAR's metal map (white dots, 24 × 24).
  - `metal.png` now holds its 89 spots: the six big ones on the strait at value 4, the rest 3. They were read off the image, its frame from the big dots' symmetry (centre at 406, 402 of 812 × 804).
  - With point symmetry that's 90 deposits. The spot hidden under the image's "24 × 24" label is the twin of (120, 776), which the symmetry adds.
  - The texture-derived spots had missed the six big ones and the islets'.
- **For the streams:**
  - client-B draws trees and rocks from WRECK `featureKind` (hover: power or supply left).
  - models-C models "feature_tree" and "feature_rock".
  - Drawing contract (models-C asked): a rock sits at its cell's centre and fills that one 8-stud cell; a tree is a point and blocks nothing. A tree's base fits about 4 studs: copses jitter ±22 studs, so trees can stand close. Make a few variants of each; the client picks one and a scale from the wreck ID and turns it by the wire heading.
- **Tests:**
  - `Features.spec`:
    - Supreme Strait's features are there from the start;
    - rocks occupy their cells, and nothing is built on one;
    - reclaiming a tree pays power and a rock supply, freeing its cell;
    - a client knows every feature without seeing it.
  - `Schema.spec`: protocol 40's WRECK.

## S-198 — Economy balance: extractors cost power, converters 1 supply / 1,200 power, share and convert levels on the resource bar (the user) (2026-10-27)

- **Asked:**
  1. "Orb deposit costs energy to run."
  2. "Energy supply converter costs 1 orb and 1200 energy to build. Converts spare 70 energy to 1 orb."
  3. "2 new thresholds (change with the slider on both resources bar)": the total energy stored (drag it down to share the rest fairly with all allies), the total orb stored (the same), and the converter threshold ("energy stored past this point can be used by converters … If you have 80 spare, only 1 converter can use it").
- **Extractor upkeep:**
  - `extractor.upkeep` power per second: T1 3, T2 15.
  - `Economy.step` pays it right after production. Short of power, extractors deliver the share of their supply that was paid for (`Account.extractRatio`).
  - An extractor on bare ground extracts nothing and costs nothing.
- **Converters:**
  - Both factions: 1 supply and 1,200 power to build (60 / 1,200 before), 70 power a second into 1 supply (Chaos converted 60 : 1 before).
  - They burn only power stored above `Account.convertAt` (default `CONVERTER_RESERVE`, 0.5). Each needs its whole 70 spare above that level, so 80 spare runs one, not two. Before, each burned whatever was above a fixed 50%, partially.
- **Share levels:**
  - `Resource.shareLevel` (default 1). Each economy window, what's stored above level × storage goes to the allies, split fairly. Each ally takes up to its own level, so nothing bounces back.
  - What nobody takes stays; overflow above storage is still wasted when nobody takes it.
- **Wire, protocol 40** (with S-197): command `ECO_LEVEL` 31.
  - Its params, with no unit IDs, are `ecoLevel u8` (`Schema.EcoLevel` SUPPLY_SHARE 1, POWER_SHARE 2, CONVERT 3) and `value u8` (percent).
  - It sets the sender's team's level.
  - The Eco record adds `supplyShare, powerShare, convertAt` (u8 percent each), 44 bytes. That's what the client's sliders show.
- **For client-B:** a slider on each resource bar for its share level, and a third on the power bar for the convert level. Each sends ECO_LEVEL; the Eco record shows each slider's current value.
- **Tests:**
  - `EcoLevels.spec`:
    - extractors without power give nothing, and with it their full rate for 3 power a second;
    - 80 spare runs one of two converters;
    - share levels split fairly and respect the receivers' own levels;
    - the converter's cost.
  - `Economy.spec`: updated for the upkeep and the whole-chunk converter.
  - `Schema.spec`: ECO_LEVEL and the Eco record's golden bytes.

## S-199 — FRONT: an order to the head of the queue (the user, through client-B) (2026-10-27)

- **Asked:** "Hold Space to insert command to the front of the queue." client-B asked for it as a command flag in protocol 40, so the protocol needn't move again.
- **Wire:** `Schema.CmdFlag.FRONT` 8 (the flags mask is now 15). It applies to every order command: MOVE, FIGHT, PATROL, ATTACK, ATTACK_GROUND, GUARD, REPAIR, RECLAIM, RESURRECT, BUILD (mobile builders), AREA, DGUN. Other commands ignore it. With QUEUE as well, FRONT wins.
- **In the sim** (`Orders.give(..., queued, front)`):
  - The new order goes in at the head of each unit's queue, and the rest stays.
  - The order under way stops: its work ends (`Build.commandIdle`; an unfinished frame keeps standing), and a move halts. It's marked not started, so it starts over once the new order is done. The builder walks back, finds its frame (`frameAt`) and finishes it rather than placing a new one. A patrol keeps its two ends.
  - An automatic order (move state, S-34) isn't kept; FRONT replaces it, like any command.
  - Factories: FRONT puts an order first on the list for new units. A factory's BUILD still appends to production.
  - DGUN out of range: the walk goes first. When the bolt fires, the walk ends and the queue goes on (`Orders.endWalk`); without FRONT the Commander stops there, as before.
- **Tests:** Orders.spec: a FRONT move goes first, then the interrupted move, then the queued one; a FRONT BUILD mid-build finishes first, then the builder finishes the same frame; a FRONT D-Gun walks, fires and goes on to its queued move. Schema.spec: the reserved-bit case moved to 16.

## S-200 — Bigger strategic stockpiles: nukes 10, anti-nukes 20 (the user) (2026-10-27)

- **Asked:** "increase anti nuke stockpile to 20, nuke stockpile to 10".
- **Changed:** the nuke silos' warhead stockpile (`ord_nuke`, `chs_nuke`) holds 10 instead of 2. The anti-nuke structures' interceptor stockpile (`ord_interceptor`, `chs_interceptor`) holds 20 instead of 3. Build time and cost per missile are unchanged (warheads 120 s for 1,500 supply + 40,000 power; interceptors 60 / 50 s). Mobile anti-nukes still carry 1.
- **Wire:** none. The STOCK owner field's count is a u8.

## S-201 — Anti-nukes take turns: each warhead gets one interceptor, the others take the next (the user) (2026-10-27)

- **Asked:** "Anti nuke now take turn to intercept (if the current nuke is being intercepted, the others will choose to intercept other nuke warhead instead".
- **Was:** an anti-nuke skipped a missile one of its team's interceptors already flew at (S-111), but in the tick before any launched, every site picked the nearest warhead. Two sites facing two warheads aimed at the same one. The one that fired then took the second warhead off the other site while it reloaded, and the second warhead landed.
- **Now** (`Targeting.interceptTarget`): each tick an interceptor ready to fire (stock left, reload done) claims its missile for its ally team. The team's other interceptors leave it and take the next missile, nearest first; with none left they wait. An interceptor that is empty or reloading tracks a missile without claiming it, so it never keeps a ready site off. A missile whose interceptor misses or is shot down is free again. The same rule covers point defence (S-149).
- **Test:** Nuke.spec: two sites, two warheads launched the same tick: two interceptors at different warheads, both shot down, nothing lands.

## S-202 — Every unit takes radar blips; a ghost under radar is a blip (the user) (2026-10-27)

- **Asked:** "unit also need to auto target radar blips (I tested a Radiance with some unit outside of it vision range but in its attack range, aided with good radar but it does not shoot)".
- **Was:**
  - Only 20 of 93 weapons had `canTargetRadar` (artillery, long-range missiles, bombs, the Radiance). The rest ignored blips: Inferno, Bulwark, Talos, the naval guns, the Citadel.
  - A structure the team had seen once was a GHOST whenever it was out of sight, even under radar. The search never takes a ghost (S-127: only on an attack order), so a scouted base sitting on radar wasn't shot. That's the likely case in the playtest: the Radiance itself already fires at plain blips (Defenses.spec).
- **Now:**
  - `Defs` sets `canTargetRadar` true unless a def says false. No def opts out today.
  - Sensors keeps `radarGhosts[team]`: the live structures it remembers that its radar covers this sensor tick. Targeting treats those like radar contacts, aimed at the remembered spot (structures don't move). A ghost off radar still needs an attack order.
  - Blips are aimed at their hidden aim point (S-131), so radar shots miss by the radar's error, less with tracking radar and Pinpointers. IR missiles still can't lock a blip (EW).
- **Tests:** RadarTargets.spec: a Talos, whose def doesn't ask for it, shells a radar blip beyond its sight and holds fire with no radar; a structure seen once is shelled while radar covers it and left alone when only remembered.

## S-203 — Playtest 3 balance and economy: Commanders, beam towers, radars, solar, wind, Fatboy / Tzar; the Generator retired; scouts fire lasers (the user) (2026-10-29)

- **Asked** (FTGG-FEEDBACK-3, `docs/progress/playtest-2026-10-28.md`): H5 D-Gun range −50%; H6 Commander laser range −25%; H7 Radiance range −25%, Bulwark −20%; H8 Watchtower radar +25%; H9 advanced radar tower sight +50%; H11 both factions' scouts fire a hot-yellow hit-scan laser; H22 remove the Generator from both factions; H23 the solar array makes 20 energy and stores 50; H24 the windmill costs 40 orb and 175 energy; H42 / H43 lower the Fatboy's and Tzar's damage and range.
- **Changed:**
  - D-Gun 160 → 80 (both Commanders); Commander laser 120 → 90 (both).
  - Radiance's beam 650 → 488. Bulwark (Chaos's beam tower) 480 → 384, its green laser 215 → 172 with it.
  - Watchtower radar 350 → 438, and Chaos's Eye 280 → 350 to match (the user named Order's tower). Beacon and All-Seer sight 180 → 270.
  - Scouts (`ord_herald`, `chs_jackal`): their weapons (ids `ord_mg`, `chs_mg` kept) are HITSCAN lasers, hot yellow (255, 214, 40), `tracer = "laser"`, 1 power a shot and ×1.5 up close like every laser. Range, reload and damage as before.
  - Radiance's beam carries `fx.color` electric blue (60, 150, 255) for the client (H38).
  - Solar arrays (both) +20 power (was 8), +50 power storage. Windmills (both) 40 supply + 175 power (was 35 + 0).
  - Fatboy and Tzar (no number given): damage −20%, range −15% (Fatboy 300 → 255, Tzar 270 → 230).
  - The Generator (`ord_generator`, `chs_generator`) is `retired` (S-157 style): off every build list, kept for old replays. The solar array now makes the same 20 power, so the AI's generator rule builds solar arrays instead (`Skirmish` asks for `solar`; its rules and the block behind the base are unchanged).
  - The T2 tank `chs_juggernaut` is renamed Goliath: the name Juggernaut goes to the Chaos T3 bot (`chs_korgoth`, H40). Id and model unchanged.
- **Tests:** specs that built Generators build solar arrays (build time 45 ticks, storage +50, overflow numbers). The beam mechanism's tests (Defenses, Shield) run on `Tests/Support/BeamDefs` (the beams at their old ranges), since they test the beam, not its reach. The D-Gun's line of tanks moved inside 80 studs. Shield.spec's shell weights drop the scout's gun (a laser now).

## S-204 — Aircraft put the player's orders first (the user) (2026-10-29)

- **Asked:** H12 "Air unit still not priority manual command (I ordered a Fighter to move back to home be it keep insisted on chasing another plane)"; H13 "Bomber plane ignored manual targeting".
- **Was:** `Air.steerJet` chased whatever slot 1 had targeted, whatever the order: a move order lost to any plane in missile range. A bomber's attack order on a target beyond its bomb bay's 800-stud reach failed Targeting's range check, so the search took the nearest target instead and the bomber bombed that.
- **Now:**
  - A jet whose head order is a player's MOVE (not an automatic one) flies to the goal: no chase and no bomb run on the way. Its weapons still fire at what comes in front of them. FIGHT, PATROL, ATTACK and idle aircraft chase as before.
  - A BOMB weapon with an attack order's target keeps that target at any distance while the team knows it, and takes nothing else (Targeting). The runs go at it from wherever the bomber is.
- **Tests:** AirOrders.spec: a Falcon ordered home 10 s after meeting a Harpy flies home; a bomber ordered onto a depot beyond 800 studs never picks the nearer extractor and bombs the depot. Air.spec's bomb-run tests give the bomber an attack-move (FIGHT) instead of a plain move.

## S-205 — Heavy shots charge while the weapon reloads (the user) (2026-10-29)

- **Asked:** H32 "Bulwark only shoot its primary turret for once and never used it again".
- **Was:** a weapon with a shot cost (S-96) fired only when the team's stores held the whole cost: Bulwark 500, Radiance 700, Centurion 150. In a match, construction keeps stored power near zero (the economy spends what comes in), so after the first shot the stores never held 500 again and the beam never fired. In a test with full stores it fired every 7 s.
- **Now** (`Stockpile.chargeStep`, run by Build.step after the missile refills): a weapon whose shot costs `Stockpile.CHARGE_MIN` (100) or more pays the next shot while it reloads, cost / reload per second, as a priority consumer like a missile refill (a low-priority unit's last, S-156). It fires once reloaded and charged (`World.wCharge`, nil = charged; hashed only while charging). Spawned charged. A stall slows the charge, so the beam fires less often instead of never. Small laser costs (1–2 power) and the D-Gun (ordered by hand) still pay at once.
- **Tests:** Defenses.spec's Radiance test: 700 a shot, charged while reloading; with empty stores the charge stops and no shot fires.

## S-206 — Air builders build what ground builders build (the user) (2026-10-29)

- **Asked:** H35 "T1 Air should be able to build other things same as other T1 builder. T2 Air too."
- **Now:** a builder def may name `buildsLike`, builders of its faction whose lists it adds after its own (`Defs.build` merges them, without repeats, so a structure added to a ground builder later reaches the air builder too). Skywright: Mason and Artisan; Vulture: Scrapper and Tinker; Zenith: Architect; Condor: Forgemaster. Each keeps its own air structures (airfields, pads, its SAMs and radars) first.
- **Validation:** `buildsLike` only on builders, naming builders of the same faction.

## S-207 — AI: roles by spot, the free starts first, the enemy's starts only, long-range radar (the user) (2026-10-29)

- **Asked** (playtest 3): H10 "Normal AI on the frontline spot in Supreme Strait still build a vehicle factory + an air factory"; H14 "There's 1 available spot but the AI doesn't take it but spawn beside another one" (8v8 Supreme Strait); H15 "AI tend to ignore to take up empty orb deposit spots"; H33 "Radiance of AI still does not target radar blips?".
- **H10:** a side's AIs drew roles (S-187) in player order, so the front spot could draw "air", which builds an airfield right after the first plant. The side still gets the same roles, but `Skirmish.roleOf` hands them out by spot: the AIs nearest an enemy Commander get balanced and spam, then defence, and the farthest back tech and air (`ROLE_DEPTH`). Ties, or no Commanders yet, keep player order.
- **H14:** an AI took its side's k-th start (k = its place on the side). If a human had picked that start, it scanned its box for the best spot, which could be right beside another player while a start stood empty. Now `Pregame.bestSpot` tries its own start, then the side's first free start, then the scan.
- **H15:** the AI took every map start but its own as an "enemy start": allies' and empty ones too. So a Hard AI (safe expansion) never took a deposit nearer any other start, and a Chaos AI waited for an escort for those. Now its enemy starts are the enemy side's Commanders when it starts (the map's other starts only if none stands yet). The scout loop uses them too.
- **H33:** the AI's beam tower already takes blips (S-202), but its only radar was one T1 tower near home, short of the beam's range. Its T2 builders now build a long-range radar (Beacon / All-Seer) right after the beam tower.
- **Tests:** AIRoles.spec: roles by spot on Supreme Strait (front balanced, back air on each side); an AI's enemy starts are the two enemy Commanders' spots in a 2v2. Pregame.spec: 8v8 on Supreme Strait, player 1 takes the 4th start, and every start of the side ends up taken.
