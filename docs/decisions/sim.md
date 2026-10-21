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
