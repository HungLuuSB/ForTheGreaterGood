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
