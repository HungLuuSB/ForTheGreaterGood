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
