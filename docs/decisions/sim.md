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
