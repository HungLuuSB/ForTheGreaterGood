# Network contract: what the client receives

**Status: ready** (sim stream, 2026-10-26). Everything here is `Schema.PROTOCOL_VERSION` **40**, as built and tested (protocol 40, S-197 / S-198: WRECK `featureKind` for map trees and rocks, the ECO_LEVEL command and the Eco record's share and convert levels; protocol 39, S-194: commands SET_RETREAT, SELF_DESTRUCT, DGUN and the owner fields' retreat bits, SELF_DESTRUCT and WORK; protocol 38, S-189: wire positions on a fixed grid, section 3), including the join / reconnect snapshot and the economy channel (section 10, S-2), the REPEAT command (S-13), and the team's sight map and wrecks (section 7a, S-26).

Owner: sim stream (`src/shared/Net`, `src/server/Sim/NetOut.luau`). The client stream builds `NetIn` against this file.
- **Source of truth for byte layouts:** `src/shared/Net/Schema.luau`. `Tests/Schema.spec.luau` pins golden bytes to the protocol version.
- **Reference receiver:** `src/server/Tests/Support/Client.luau`. It is a headless client that rebuilds a player's view from the real outbox and is checked by `NetOut.spec`, `Export.spec` and the viewer. When this file and that code disagree, the code is right and this file has a bug.
- Guide sections: 7 (networking), 11 (sensors), 15 (client).

---

## 1. Transport

| Channel | Direction | Roblox remote | Reliable | Content |
|---|---|---|---|---|
| `Cmd` | C → S | RemoteEvent | yes | Commands (move, build, camera, ...) |
| `Tactical` | S → C | UnreliableRemoteEvent | no | Positions of moving units in the tactical tier |
| `State` | S → C | RemoteEvent | yes | Changed health / state bits / aim / weapon states / build progress |
| `Strategic` | S → C | UnreliableRemoteEvent | no | Every known non-tactical unit, every 5th tick |
| `Events` | S → C | RemoteEvent | yes | ENTER / LEAVE / DEATH, combat events, sight and wrecks (7a) |
| `Projectiles` | S → C | UnreliableRemoteEvent | no | Homing-projectile corrections; shells in a shield dome's field (S-79) |
| `Eco` | S → C | RemoteEvent | yes | Own team's economy; a spectator's: every team's (section 10) |
| `Snapshot` | both | RemoteEvent | yes | Join handshake (section 10) |

Names and reliability: `Schema.Channel`.

- The server produces, per player and per tick, an **outbox**: channel → list of `buffer` messages (`sim.net.players[p].outbox`, filled by `NetOut.step` at the end of every tick).
- The Roblox server glue fires one remote call per message, in this channel order: Snapshot, Events, Tactical, State, Projectiles, Strategic, Eco. The client must apply a WELCOME before the rest of that tick's messages.
- A message is at most **900 bytes** (`Packer.MAX_MESSAGE_BYTES`). It is a run of records of one type after a **tick header**; records are never split across messages. Read a message with `Packer.readAll(msg, Schema.decode<Kind>, Schema.decodeTickHeader)`.

## 2. Wire rules

- Little endian. Unit, projectile, def and weapon IDs are 1-based **u16**; 0 is reserved ("none") where a field allows it, and rejected elsewhere.
- **Tick header:** `tick u16` = sim tick mod 65,536. It wraps every ~72.8 min. Compare with `Shared/Net/Tick` (`Tick.isNewer`, `Tick.diff`, `Tick.unwrap`), never with `<`.
- Decoders reject unknown enum values, reserved bits and truncated input with a `Schema:` error. Wrap every decode of a message in `pcall` and drop the whole message on error.
- Unreliable channels may lose or reorder messages. For each unit (or projectile), apply a Tactical, Strategic or Projectiles record only if its message tick is newer than the last one applied to it.

## 3. Units, IDs and quantization

| Quantity | Wire | Decode |
|---|---|---|
| Unit ID | u16 | Unique among live units, ghosts and the reuse window: an ID is reused only 10 s after its unit died, and never while any team still remembers it as a ghost. The server tracks generations internally (D109); the wire never needs them. |
| Position (units) | `cell u16, offX u8, offZ u8` | Since protocol 38 (S-189) a **wire position**, the same for every map: `cell` is one of 256 × 256 wire cells of 64 studs centred on the origin, the offsets quarter studs: `x = ((cell % 256) × 256 + offX) / 4 − 8192`, z with `cell // 256` and offZ. Use `Grid:decode(cell, offX, offZ)` / `Grid:encode(x, z)`; never treat `cell` as a map cell. Positions can lie past the map's edge (aircraft and shots, up to `Grid.OVERFLY` 512 studs). Before 38: the map cell index and 1/32-stud offsets. |
| Strategic position | `cell u16` + `offX`, `offZ` 3 bits each | The wire cell and its offsets' top 3 bits: an 8-stud square. The decoder gives offX / offZ at the square's centre: `Grid:decode(r.cell, r.offX, r.offZ)` (protocol 38; before: a map cell, drawn at `Grid:decode(cell, 128, 128)`). |
| Projectile / event position | `cell u16, offX u8, offZ u8, y i16` | x, z as above; `y = i16 / 8` studs (`Schema.Y_SCALE`). |
| Velocity | `vx, vy, vz i16` | studs per second = `i16 / 8`. |
| Heading | u8 | `heading × 360 / 256` degrees, 0 = +Z, counter-clockwise (radians: `× 2π / 256`). |
| Altitude | u8 | Studs above the ground, rounded. Only aircraft send it. |
| Health | u8 | `ceil(health / maxHealth × 255)`; 0 only when dead. |
| Build progress | u8 | `floor(progress × 255)`; 255 = complete. |
| Turret yaw / pitch | u8 | Radians in [−π, π] → `round((a + π) / 2π × 255)`; yaw is relative to the hull. |
| Def index | u16 | `defs.unitByIndex[i]` (1-based, `Defs.load()` order, identical on both sides; the defs hash proves it). |
| Weapon index | u16 | `defs.weaponByIndex[i]`. |
| Icon | 8 bits (protocol 19) | 0 = unknown (radar / sonar blip). Else the unit's **def index** (Defs: sorted by ID, from 1): every unit type has its own icon (S-58, client request 35). `Shared/Net/Icons.byDef`, which the server uses too. `def.icon` stays the family name (`Icons.names` lists them) for the shape; the def gives the unique glyph. |
| Team | 4 bits (strategic; 3 before protocol 36) / u8 (ENTER) | 1..16 (S-169; 1..8 before). Ally teams come from the match config. |

**Unit `state` bits** (u16, `Schema.UnitState` in Shared; the sim's `World.State` is the same table): `MOVING 1` (since S-33: ground and naval units with a movement order or speed, aircraft unless landed, loitering included; it changes in a State record like any bit), `TOGGLED_ON 2` (radar / jammer / converter switched on; a beam tower deployed: clear = retracted into its shell, S-96), `SUBMERGED 4`, `LANDED 8`, `REPEAT 16` (factory repeat on, protocol 7), `DEPLOYED 32` and `DEPLOYING 64` (protocol 22, S-64: a deployable unit, the Warden, unpacked, or unpacking / packing; 4 s each way, the progress isn't sent), `LOW_PRIORITY 128` (protocol 33, S-156: resource priority low; clear = high, the default), `CLOAKED 256` (protocol 46, S-228: cloaked; enemies see it at most as a radar contact, so only its own side gets the bit: draw it translucent), `PARALYZED 512` (protocol 46, S-229: stunned by EMP; neither moves, fires nor builds: a crackle on it). Other bits are reserved (0).

**Weapon states** (2 bits per slot in a u16; slot 1 = bits 0–1; `Schema.weaponStateAt`):
- `IDLE 0`: no target;
- `AIMING 1`: target, reloading or turning;
- `READY 2`: target, reloaded;
- `RESTORING 3`: not sent yet.

A unit has at most 8 weapon slots, in `def.weapons` order.

## 4. What a player knows (fog first)

Everything sent to player P is filtered by P's **ally team's** knowledge (`Sensors`), never by the camera. The camera only chooses the level of detail.

| Level | Meaning | On the wire |
|---|---|---|
| own / allied | the ally team's units | full |
| VISIBLE | in sight (LOS, or air sight for aircraft) | full |
| GHOST | a structure seen earlier, now out of sight (alive or not: the team can't tell) | strategic record, real icon, GHOST flag, last known cell |
| RADAR | radar contact | strategic record, **wobbled** cell, icon 0 (only its domain is known: air / surface / submerged) |
| RADAR + TRACKED | radar contact inside the team's fire-control radar (D104) | as RADAR, small wobble, **real icon**, TRACKED flag |
| SONAR | sonar contact | strategic record, wobbled cell, icon 0 |
| HIDDEN | — | nothing, ever |

The client never receives a hidden unit, a radar contact's true position, or a hidden shooter's ID.

## 5. Tiers, ENTER / LEAVE, Tactical, State

The camera is sent by the client as a `CAMERA` command (map-cell rectangle `minX, minZ, maxX, maxZ`, u16 each since protocol 38, u8 before; at most ~5 per second; guide 15.5). A rectangle touching the map's edge also covers everything past that edge (aircraft over it, S-189).
- **No camera** means no tactical tier: everything arrives as strategic records.
- **Tactical tier:** own / allied or VISIBLE units inside the camera rectangle. A unit enters within **+2 cells** of it and leaves beyond **+5 cells** (hysteresis).

Per tick, for each player, in this order (the Events message carries them in this order too):

1. **DEATH** for tactical units that died (the unit is removed: play the death effect; `wreckId` 0 = no wreck; aircraft shot down in flight never leave one, S-38). Since protocol 10 the wreck itself arrives as a WRECK record in the same batch (section 7a): draw wrecks from WRECK / WRECK_GONE, and use `wreckId` only to link the death animation to it.
2. **LEAVE** for tactical units removed without a death (reclaimed, cancelled frame, ID gone) or no longer tactical (left the camera area, out of sight). The client keeps the unit as *strategic* until the next strategic snapshot refreshes or drops it.
3. **ENTER** for units that just joined the tactical tier. It carries the full state (`defIndex`, team, position, heading, altitude, health, build, state bits). It is the only way a unit becomes tactical. Spawn or reuse a model.
4. Combat events (section 7), after the ENTERs: a FIRE's shooter is always already known.

Then:
- **Tactical** (unreliable): `unitId, cell, offX, offZ, heading, flags (bit0 = has altitude), [alt]`, 8 or 9 B. Sent only for tactical units that moved, turned or changed altitude this tick, and never in the same tick as their ENTER. No record means it didn't move: keep the last value.
- **State** (reliable): `unitId, mask` plus only the changed fields.
  - Mask bits: health 1, state 2, aim 4, weapon 8, build 16, targets 32 (protocol 8), stock 64 (protocol 15), owner 128 (protocol 20).
  - Aim: `slotMask u8` (bit i−1 = slot i), then `yaw u8, pitch u8` per set bit in slot order.
  - A change of state bits or turret aim sends the state, the aim of every slot and the weapon field together.
  - Aim rest and restore (S-20): a unit enters with its weapons at their turret's rest pose (`restYaw`, `restPitch`); after losing a target a weapon holds its aim `restoreDelay` seconds, then turns back to rest. `Shared/Combat/Aim.update` is the server's exact per-tick step, so a client can animate between aim updates with the same results.
  - **Targets** (S-16, own units only): `slotMask u8`, then `targetId u16` per set bit (0 = no target). Sent to the unit's owner whenever a weapon's target changes (every slot), and with the ENTER tick when it has any target; the ID is always a unit (or remembered structure) the team knows. Other players never get it. Exact from the tick Targeting picks the target, before the turret has turned.
  - **Owner** (S-61, own units only; protocol 20): `ownerMask u8` (QUEUE 1, STATES 2, AMMO 4, CHARGES 8, PRODUCING 16, SELF_DESTRUCT 32, WORK 64), then the fields it sets, after `stock`, in that order:
    - QUEUE (factories): `count u8` (0..50), `progress u8` (the head item, 0..255 of 1), then `defIndex u16` per queued item, the head first. Sent when the queue changes or the head's progress crosses a sixteenth.
    - STATES (mobile units and armed structures): one byte, fire state in bits 0–1 (`Schema.FireState`), move state in bits 2–3 (`Schema.MoveState`), and since protocol 39 an aircraft's retreat setting in bits 4–5 (`Schema.RetreatAt`: 0 never, 1 / 2 / 3 below 30 / 40 / 50% health; S-194). Bits 6–7 are reserved. Sent when any of them changes.
    - AMMO (aircraft with an `ammo` count): `rounds u8`, `max u8`. Sent when the rounds change.
    - CHARGES 8 (units with flares or chaff; protocol 21, S-63): `flares u8`, `chaff u8`, the charges left (0 for a kind the def lacks). Sent when either changes. DIRCM has no charges.
    - PRODUCING 16 (**allied** players' factories, not the owner's; protocol 27, S-103, client request 45): `defIndex u16` (the item in production; 0 = idle), `progress u8` (0..255 of 1). Sent with the ENTER and when the item or its progress (by sixteenths) changes. It is the only owner field allies get; the owner has QUEUE.
    - SELF_DESTRUCT 32 (protocol 39, S-194): `seconds u8`, the whole seconds left of the unit's self-destruct countdown (`Schema.SELF_DESTRUCT_SECONDS` 6 at the start); 0 = the countdown was stopped. Sent when it starts, each second, and when it stops.
    - WORK 64 (builders; protocol 39, S-194): `kind u8, target u16`, what its nano spray is on, as the server builds. `kind` is `Schema.WorkKind`: NONE 0 (target 0), BUILD 1, REPAIR 2, ASSIST 3 (a factory's production) with a unit ID, RECLAIM 4, RESURRECT 5 with a wreck ID; RECLAIM_UNIT 6 (protocol 42, S-218) with a live enemy unit's ID, which a construction turret takes apart. Sent when it changes; with the ENTER only when not NONE. Draw the spray from this, not from the order line.
    - CARGO 128 (transports; protocol 43, S-219): `count u8` (0..8), then `id u16` per unit on board, in loading order. Sent when it changes; with the ENTER only when not empty. The units on board are not in the view (each had a LEAVE).
    - Each is also sent with the ENTER tick. Other players and spectators never get them.
  - **Stock** (S-47, own units only; protocol 15, progress since 17): `slotMask u8`, then `count u8, progress u8` per set bit: missiles in stock of each weapon slot that has a stockpile (`weapons[i].stockCapacity` in the defs; slots without one are never set), and the next missile's build progress (0..255 of one missile; 0 when full). Sent to the unit's owner whenever a count changes or a progress crosses a sixteenth (`Stockpile.WIRE_STEPS`; every stockpile slot together), and with the ENTER tick always. Between records the progress grows by at most 1/16 (it stalls with the economy), so a client may animate it at `1 / buildTime` per second and stop at the next sixteenth. Other players and spectators never get it. Comes after `targets` in the record.

A Tactical or State record always refers to a unit the client got an ENTER for. If not, the client is out of sync: drop the record (the reference client asserts).

## 6. Strategic

- Every 5th tick (3 Hz) the server sends a full **snapshot** of every known unit that is not tactical for this player. That includes own units outside the camera and ghosts of structures that died unseen.
- Record: `unitId u16, cell u16, icon 8 bits | team 4 bits (team − 1) | flags 5 bits | offX 3 bits | offZ 3 bits | 1 reserved bit (0)`, 7 B (protocol 38, S-189: the position is a wire cell plus the offsets' top 3 bits, section 3; protocol 36, S-169: teams 1..16; bits LSB-first: icon 0–7, team 8–11, flags 12–16, offX 17–19, offZ 20–22; before 38 the 7 bits after the flags were reserved and `cell` a map cell; before 36: 6 B with team 8–10, flags 11–15).
- Flags:
  - `RADAR_ONLY 1`, `SONAR_ONLY 2`, `UNDER_ATTACK 4` (since protocol 23, S-68: own and allied units an enemy hit in the last 3 s), `GHOST 8`, `TRACKED 16`;
  - all 5 flag bits are in use.
- **Header (protocol 41, S-212):** `tick u16 | part u8 | parts u8`, 4 B. A snapshot can span several messages with the same tick; `part` numbers them from 0 and `parts` (1..255) says how many there are. Read with `Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeStrategicHeader)`, which returns `{ tick, part, parts }` as the header.
- A message whose tick differs from the last strategic tick **starts a new snapshot**: apply its records as they come (update or add units). Only once **every part** of that tick has arrived, drop the non-tactical units missing from all of them. The channel is unreliable: with a part lost, keep the units that weren't in the parts you got until a complete snapshot leaves them out. Before 41 the header was the tick alone and the client dropped every non-tactical unit at a new tick, so a lost part made its units blink out (client-B's H36).
- An empty snapshot still sends one message holding only the header (part 0 of 1), so the client can drop units that disappeared.
- Positions of radar and sonar contacts are wobbled server-side (they move smoothly, re-aimed every 30 ticks); never treat them as exact.

## 7. Combat events (Events channel)

All of a tick's events are one reliable batch. Records start with `kind u8`; sizes include it. Shooters are sent only where P's ally team may know (D99). **Projectiles and shots are shown in P's camera area whatever the team sees (S-43, client request 21):** they carry no shooter, so a hidden shooter stays hidden; only normal sight reveals it.

| Kind | Layout | When P gets it |
|---|---|---|
| `FIRE 4` | `shooterId u16, slot u8 (bits 0–3 slot 1..8, bit 4 hit), end pos`, 10 B | Hitscan / beam shots of units in P's tactical tier. Draw a tracer from the shooter's muzzle to the end point (the target's hull centre on a hit, the ground on a miss). No target ID. |
| `SHOT 13` | `hit u8 (0 / 1), start pos, end pos, weaponDefIndex u16`, 16 B (protocol 14; the weapon since 28, S-118, client request 52; 0 = unknown) | A hitscan / beam shot whose shooter P doesn't have (not in its tactical tier), when either end is in the camera area (+2 cells). Draw it from the start (the muzzle) to the end, as its weapon is drawn: a BEAM held for its `beamDuration`, deflected on a dome, etc. No shooter or target ID. |
| `SPAWN_PROJ 5` | `projId u16, weaponIndex u16, pos, vel, targetId u16`, 19 B | A projectile the client doesn't have yet, once it is in the camera area (+2 cells), seen or not (S-43): at launch, or when it flies into the camera area. `targetId` is the homing target if P's team knows that unit, else 0. |
| `IMPACT 6` | `projId u16, pos`, 9 B | For projectiles the client has, or any impact in the camera area. Explosion effect; drop the projectile. Projectiles that reach the end of their life also send one (no damage). A strategic missile's IMPACT is its detonation (`aoe` 150). |
| `INTERCEPTOR 14` | as SPAWN_PROJ, 19 B (protocol 16) | SPAWN_PROJ of a missile fired at a strategic missile (S-48). `targetId` is the **projectile ID** of the strategic missile it chases (always one the client has: see below), not a unit. Steer it with `Guidance.vertical` / `pn` against that projectile's predicted position and velocity (vy included). Its IMPACT is the interceptor's burst. |
| `LAUNCH_WARNING 15` | `projId u16, pos`, 9 B (protocol 16) | A strategic missile (`weapon.strategic`) was launched from `pos` (the silo). **Every player** gets it, camera or not, in the launch tick. **Strategic missiles are sent to every player wherever they fly:** its SPAWN_STRATEGIC arrives in the same tick. |
| `ALERT 18` | `alert u8, cell u16, offX u8, offZ u8, defIndex u16` (0 = none), 8 B (protocol 23, S-68; the offsets since protocol 38: a wire position, section 3) | To the player it concerns (Sim/Alerts): UNIT_ATTACKED 1 / STRUCTURE_ATTACKED 2 (one per 400-stud zone per 20 s), UNIT_LOST 3 / STRUCTURE_LOST 4 (one per zone per 5 s), BUILD_DONE 5 (each factory unit and finished frame), STALL_SUPPLY 6 / STALL_POWER 7 (the team's ratio dropped below 1; once per 30 s each; cell 0), NUKE_LAUNCH 8 (every player, at the silo), COMMANDER_ATTACKED 9 (one per 10 s). `cell, offX, offZ` is where it happened. |
| `SPAWN_STRATEGIC 17` | SPAWN_PROJ's fields (`targetId` 0), then `goal pos`, 25 B (protocol 18) | A strategic missile the client doesn't have yet, to **every player** wherever it is (S-48): at launch, or on joining mid-flight. `goal` is the spot it flies to. Step it every tick with `Lofted.step(x, y, z, vx, vy, vz, gx, gy, gz, gy + weapon.apex, weapon.gravity, rad(weapon.turnRate) / 15, Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z)), 1/15)` (`Shared/Combat/Lofted`, S-51): straight up to `climbHeight`, the pitch-over, the arc. The phase comes from its state, so a copy first seen mid-flight steps the same (a client copy stays within 0.15 studs of the server's over a whole flight). Its IMPACT is the detonation, ~12.7 s after launch. |
| `SHIELD 19` | `unitId u16, charge u8, flags u8`, 5 B (protocol 24, S-79) | A shield dome generator in P's tactical tier: right after its ENTER, then whenever its charge (0..255 of the def's `shield.capacity`) moved 4 or its flags changed. Flags (`Schema.ShieldFlag`): UP 1 (the dome stands; without it the dome is down until 25%), RECHARGING 2 (below capacity and powered). The radius is the def's `shield.radius`. Generators enter and leave the tactical tier with margins grown by their dome's radius (in cells), so P has the dome wherever it shows. |
| `SHIELD_FIELD 21` | `projId u16, pos (the dome's centre: the generator's base), radius u16 (studs), force u8 (0..255 of full), phase u8 (1 braking, 2 repelled)`, 13 B (protocol 24, S-79) | **Not sent since S-93** (every projectile is destroyed at the surface: SHIELD_HIT with ABSORBED), but still decoded; it returns if the field does. A projectile P has came into an enemy dome's field this tick, or is in one when its SPAWN_PROJ is sent (then right after it). Step it with `ShieldField.step(x, y, z, vx, vy, vz, weapon.gravity, cx, cy, cz, radius, force / 255, ShieldField.mass(weapon), phase, 1/15)` (`Shared/Combat/ShieldField`) instead of `Ballistics.step` until the returned phase is DONE (3); then fly on plainly. Projectiles corrections cover shells in a field every 5 ticks, on their turn or breach, and as they leave it. |
| `SHIELD_HIT 20` | `unitId u16 (the generator; 0 = one P doesn't have), projId u16 (0 = a hitscan shot, protocol 26), pos (the point on the dome), mass u8, flags u8`, 13 B (protocol 24, S-79) | For projectiles P has, or anywhere in the camera area: a shell turned back by a dome's field (the hit; a missile loses its lock); with flag `SHIELD_BREACH` 1, one that broke through; with flag `SHIELD_ABSORBED` 2 (protocol 25, S-85), a light shell (mass under `ShieldField.ABSORB_MASS`, 0.5) destroyed where it crossed the dome's surface: drop it, no burst; no IMPACT follows. `mass` / `Schema.SHIELD_MASS_SCALE` (31) is the shell's mass (1 = a 150-damage shell, 0.2..8). A turned shell stays live and bursts with its own IMPACT where it lands. |
| `DOME 23` | `unitId u16 (the generator), pos (the dome's centre), radius u16 (studs), charge u8, flags u8 (ShieldFlag)`, 13 B (protocol 29, S-122, client request 55) | A shield dome whose circle touches P's camera area (+2 cells) while P doesn't have its generator, whatever P's team sees (as BAR draws shields). Sent when it enters that area and when its charge (by `NetOut.SHIELD_STEP`) or flags change. It doesn't reveal the generator's type. Draw the dome from it. When the generator enters P's tactical tier, its ENTER and SHIELD records take over, after a DOME_GONE. |
| `DOME_GONE 24` | `unitId u16`, 3 B (protocol 29) | That dome left P's camera area, its generator died, or P now has the generator. |
| `IDLE 25` | `unitId u16, idle u8 (0 / 1)`, 4 B (protocol 31, S-136, client request 62) | Owner only, on camera or not: one of P's finished builders or factories (units with `buildOptions`) became idle (1) or busy (0). A builder is idle with no order of its own (automatic reactions don't count) and no build, assist, repair or reclaim work; a factory with an empty queue. Checked every `NetOut.IDLE_EVERY` (5) ticks. Units never reported are busy. On join / reconnect every idle one is sent. A dead unit's report lapses: drop it with the unit. |
| `OWN_STATUS 26` | `unitId u16, health u8, build u8, queueHead u16, queueProgress u8, queueCount u8`, 9 B (protocol 34, S-158, next.md item 4) | Owner only: one of P's own units **outside its tactical tier** whose health (u8 of max, as ENTER), build progress (u8), factory queue head (unit def index, 0 = none or empty), the head's progress (0..255; sent when it moves a sixteenth) or queue length changed since the client last had it. The client has a unit's status as of its LEAVE, so leaving the tier sends nothing by itself. At most `NetOut.OWN_STATUS_MAX` (24) per tick; the rest follow on the next ticks in turn. On join / reconnect every own unit off camera is sent (over a few ticks). It can arrive before the unit's first strategic record: keep it by unit ID and apply it when the unit is known; drop it with the unit. Tactical units never get one (ENTER / State carry the same). |
| `INTERCEPTED 16` | `projId u16, pos`, 9 B (protocol 16) | A strategic missile was destroyed in flight at `pos`: a small burst, **no detonation**; drop the projectile. Sent instead of its IMPACT. |
| `DECOYED 7` | `projId u16, pos, vel, decoy pos, decoyTicks u8, countermeasure u8`, 23 B (countermeasure: 1 flares, 2 chaff, 3 DIRCM, `Schema.Countermeasure`; protocol 13) | For projectiles the client has: a countermeasure seduced it. Snap to `pos`/`vel`, clear its target, and for the next `decoyTicks` ticks steer toward the decoy point with `Guidance.decoy` (stop early when it returns false), then fly straight (protocol 11, S-28). |
| `LOST_LOCK 8` | `projId u16, pos, vel`, 15 B | Same, but the missile flies on unguided. A RADAR-guided missile (S-146) then corkscrews and sinks: the event carries its state after the server's first lost step (k = 0), so on each later tick step its velocity with `Guidance.lost(vx, vy, vz, k, projId, 1 / 15)` before the ballistic step, with k = 1, 2, 3... (the ticks since the event). Others fly straight. |
| `DEATH 3` | `unitId u16, severity u8, wreckId u16`, 6 B | Tactical units (section 5). |
| `ENTER 1` / `LEAVE 2` | 16 B / 3 B | Section 5. |

| `WRECK 9` | `wreckId u16, defIndex u16, cell u16, offX u8, offZ u8, heading u8, supply u16, fullSupply u16, featureKind u8, heap u8`, 16 B (supply fields since protocol 35, S-168; featureKind 40, S-197; heap 45, S-227) | Section 7a. |
| `WRECK_GONE 10` | `wreckId u16`, 3 B | Section 7a. |
| `WRECK_STATE 27` | `wreckId u16, supply u16, rez u8, heap u8`, 7 B (protocol 35, S-168; heap 45, S-227) | Section 7a. |
| `WRECK_HIT 36` | `wreckId u16`, 3 B (protocol 45, S-227) | Section 7a. |
| `PREGAME 28` | `player u8, flags u8 (PICKED 1, READY 2, AI 4, CHAOS 8, HOST 16), cell u16, offX u8, offZ u8`, 7 B (protocol 36, S-169; CHAOS and HOST protocol 37) | Section 9b. |
| `COUNTDOWN 29` | `seconds u8`, 2 B | Section 9b. |
| `PREBUILD 30` | `player u8, count u8, count × (defIndex u16, cell u16, offX u8, offZ u8, facing u8)`, 3 + 7 × count B | Section 9b. |
| `PICK_CLOCK 31` | `seconds u8, flags u8 (ALL_READY 1, MAX_WAIT 2, LOADING 4)`, 3 B (protocol 37, S-174) | Section 9b. |
| `START_BOXES 32` | `count u8, count × (allyTeam u8, x0 i16, z0 i16, x1 i16, z1 i16)`, 2 + 9 × count B | Section 9b. |
| `SHARE 33` | `from u8, to u8 (0 = a request), what u8 (ShareKind: UNITS 1, SUPPLY 2, POWER 3, ASK_UNITS 4, ASK_SUPPLY 5, ASK_POWER 6), amount u32`, 8 B (protocol 37, S-176) | A gift or a request for help, to the giver's ally team and spectators. Commands: `SHARE_UNITS 24` (unit IDs, value = the ally player; complete own units, not Commanders: re-made for the ally with new IDs), `SHARE_RESOURCE 25` (params `toPlayer u8, resource u8 (SUPPLY / POWER), amount u32`, no unit IDs; capped by what the giver can spend this window), `REQUEST 26` (value = ASK_*; no unit IDs). |
| `SIGHT_ROWS 11` | `firstRow u8, rowCount u8, rowBytes u8, bits`, 4 + rowCount × rowBytes B | Section 7a. |
| `SIGHT_CELLS 12` | `count u8, cell u16 × count`, 2 + 2 × count B | Section 7a. |

`pos` = `cell u16, offX u8, offZ u8, y i16` (6 B); `vel` = `vx, vy, vz i16` (6 B). Sizes per kind: `Schema.EVENT_BYTES` (fixed kinds), `Schema.eventBytes(e)` (all).

**Client projectiles** (guide 15.3):
- From SPAWN_PROJ, step each projectile yourself every tick with the server's math:
  - homing weapons (`weapon.turnRate`) whose target the client knows first steer (S-27, **`Shared/Combat/Guidance`**): `HOMING` missiles with `Guidance.pn(x, y, z, vx, vy, vz, tx, ty, tz, tvx, 0, tvz, rad(turnRate) / 15, 1/15)` (proportional navigation), `TORPEDO` with `Guidance.lead(x, y, z, vx, vy, vz, tx, ty, tz, tvx, tvz, rad(turnRate) / 15)`. `t` is the target's position **at the start of the tick** (where the client had it before this tick's records) and `tv` its velocity: `Guidance.velocity(heading, speed)` on the server; the reference client estimates it from its last two Tactical records (0 when a tick brings none);
  - then `Ballistics.step(x, y, z, vx, vy, vz, weapon.gravity or 0, 1/15)` (**`Shared/Combat/Ballistics`**).
  - A guided missile whose target leaves its seeker cone gets LOST_LOCK and flies on unguided (S-27); the client gets the event.
  - A RADAR-guided missile whose target is gone (killed, lock broken, decoy spent) spirals: LOST_LOCK, then `Guidance.lost` each tick (S-146). If the target died during the launch phase (a vertical launch before it pitched over, or the first 8 ticks of other launches), there is no event: it flies to the target's last known aim point and bursts there; homing corrections carry that path.
  - Vertical launches (`weapon.launch == "vertical"`: the radar SAMs, S-42) spawn pointing straight up from a launcher whose turret stays at rest. Step them with `Guidance.vertical(x, y, z, vx, vy, vz, tx, ty, tz, tvx, 0, tvz, rad(turnRate) / 15, 1/15, turned, climbLeft)`, which returns the velocity and the new `turned`: keep it per missile, false at SPAWN_PROJ (a missile that comes into view already turned over flips to true on its first step with the target near its nose).
  - The boost climb (S-44): `climbLeft = Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z))`, the weapon's `climbHeight` (100 studs on both radar SAMs) minus the missile's height above the ground under it. Use `Layers.heightAt` (Shared, cell-based: the cell's height, the server's `Combat.groundHeight`), not a smoothed ground, or the hand-over tick differs. While the missile still flies exactly straight up (vx = vz = 0, which the wire keeps exact) and `climbLeft > 0`, it doesn't steer; nothing about its age is needed.
  - A decoyed missile (DECOYED) follows its decoy point: `Guidance.decoy(x, y, z, vx, vy, vz, dx, dy, dz, rad(turnRate) / 15, Guidance.seekerAngle(weapon))` each tick while ticks remain and it returns true (S-28). The reference client matches the server's path to under a stud this way (`Guidance.spec`).
- Unguided projectiles then match the server exactly; homing ones are approximate.
- Drop a projectile on IMPACT. A projectile that leaves the map bursts on its edge with an IMPACT there (S-33). As a fallback, drop it at its time to live: `2 × range / projectileSpeed + 1` s (bombs 8 s), plus a tick.
- Projectile IDs are reused. A SPAWN_PROJ for an ID the client still has replaces it.

## 7a. Sight map and wrecks (Events channel, protocol 10, S-26; client requests 9 and 10)

**Sight.** The client's fog is the ally team's sight, exactly: sensor cells (16 studs, 2 × 2 grid cells; `grid.sensorX × grid.sensorZ`, index `z × sensorX + x`, `Grid:sensorCellAt(x, z)`) that any unit of the ally team (own or allied) has in LOS. Air sight (against aircraft only) is not part of it.
- `SIGHT_ROWS` (`firstRow u16` since protocol 38, u8 before; `rowCount u8, rowBytes u8`, the bits): rows `firstRow .. firstRow + rowCount − 1` of the map as a bitset, `rowBytes = ceil(sensorX / 8)` bytes per row; cell x of a row is bit `x % 8` of byte `x // 8`; 1 = in sight. Sent after a WELCOME (the whole map, in records of at most 640 bytes of bits), and instead of SIGHT_CELLS when a tick's changes are larger.
- `SIGHT_CELLS`: up to 255 cells that changed since the last sight record, each a u24 (low u16 then high u8; u16 before protocol 38): `cell index | 0x800000` (`Schema.SIGHT_SEEN`, bit 23; bit 15 before 38) when it is now in sight, the bare index when it no longer is. Apply them in order.
- Sent on sensor ticks (every 2nd tick, `NetOut.SIGHT_EVERY`) when something changed. The client's map then equals `Sensors` LOS at the end of every sensor tick (tested on every one).
- Spectators get no sight records: they have no fog.

**Wrecks.** Known per ally team, like structure ghosts:
- `WRECK` when the team first has the wreck's spot in sight (in the same tick as the DEATH that made it, if the team saw it), on the whole map, not only the camera area (wrecks are on the minimap). `heading` is the dead unit's (u8 like ENTER); `defIndex` is the unit it was (the wreck model comes from its def).
- `WRECK_GONE` when the team sees the spot without the wreck (reclaimed). A wreck removed out of the team's sight stays on the client's map until then.
- After a WELCOME, a WRECK for every wreck the team knows. Spectators get every wreck at once and see it go at once.
- **Supply and resurrect (protocol 35, S-168):** WRECK carries `supply` (whole units left in the wreck when sent) and `fullSupply` (what it held when the unit died: `Combat.WRECK_SUPPLY_FRACTION` 0.5 × the def's supply cost). `WRECK_STATE` follows on sensor ticks (every 2nd tick) for a wreck the client has, while its spot is in the team's sight, when its `supply` or its resurrect progress `rez` (0..255) changed since the last sent; a WRECK whose `rez` isn't 0 is followed by one at once. Out of sight the client keeps the last values. The values to show: a dark-green bar `supply / fullSupply` (below 1 only), a purple bar `rez / 255` (above 0 only); a hover can name the wreck (its `defIndex`) and its `supply`; the reclaimable supply of an area is the sum of the known wrecks' `supply`.
- **Wrecks wear down (protocol 45, S-227):** a unit's wreck has health, 0.54 × its unit's max health, and what it holds follows it: `health fraction = supply / fullSupply`. Blasts damage it (splash, or a shell that lands on it), and reclaim takes health with the supply. Below 40% (`supply < 0.4 × fullSupply`) it's a **scrap heap**: `heap = 1` in WRECK and WRECK_STATE. A heap can't be resurrected (the server refuses RESURRECT on it and stops one under way) and never turns back into a wreck. At 0 the wreck is gone (WRECK_GONE once the team sees the spot). `WRECK_HIT` goes to a player who has the wreck, while its spot is in the team's sight, in the tick a blast hits it: sparks there. Its lower `supply` follows in WRECK_STATE on the next sensor tick. Map features (`featureKind` 1, 2) never take damage and are never heaps.
- Wreck IDs are the server's (1-based, never reused within a match); RECLAIM commands target them.

**Cost** (`lune run stress`, 800 units, two players): sight ~0.3–0.4 KB/s and wrecks ~0.12 KB/s per player in a large battle (events 0.72 → 1.22 KB/s, total 15.4 KB/s of 35); a join adds the whole map once (2 KB on a 256-cell map, 8 KB on 512, 33 KB on 1,024) plus 14 B per known wreck.

## 8. Homing corrections (Projectiles channel, D102)

- Record: `projId u16, pos, vel`, 14 B, after the tick header.
- Sent for each homing projectile the client has while it is in P's view (camera + 5 cells; sight doesn't matter since S-43): about 3 Hz (every 5 ticks, staggered by ID), plus once on the tick it comes back into view.
- **Client:**
  - snap the prediction to `pos`/`vel` and keep drawing where it was;
  - blend the drawn offset to 0 over 5 ticks;
  - snap outright when the error is above 60 studs (it was out of view).
- Lost corrections only mean a longer blend. Ignore corrections for unknown IDs.
- Measured worst visible drift with corrections: 30 studs for torpedoes and 67 for air-to-air missiles (D102).

## 9. Client → server: commands (Cmd channel)

- Layout: guide 7.3 and `Schema.encodeCommand`: `cmdType u8, flags u8, count u16, unitIds u16 × count, params`.
- Types: MOVE 1, FIGHT 2, ATTACK 3, ATTACK_GROUND 4, PATROL 5, GUARD 6, STOP 7, BUILD 8, REPAIR 9, RECLAIM 10 (targetId: a wreck), SET_FIRE_STATE 11, SET_MOVE_STATE 12, TOGGLE 13, CAMERA 14, REPEAT 15 (`value u8`: 0 off, 1 on; protocol 7), CANCEL 16 (`value u8` 0..50; protocol 12): on an unfinished frame it cancels it (gone, no wreck; the frame's progress × cost is refunded); on a factory it drops queue item `value` (1-based; 0 = all), refunding the progress on the item in production (S-35). An unfinished factory takes BUILD queue items too and starts on them when finished (S-138); while its queue isn't empty, CANCEL drops queue items (0 = all) and leaves the frame, so a CANCEL 0 on an empty queue removes the frame. PRIORITY 18 (`value u8`: 0 low, 1 high; protocol 33, S-156) sets or clears the unit's `LOW_PRIORITY` bit, on any unit. It matters for consumers: builders and factories (their build power), stockpilers (missile refills), aircraft rearming, and shield / radar / jammer / DIRCM upkeep. In a stall the low ones share only what the high ones leave. RESURRECT 19 (`targetId u16`: a wreck; protocol 35, S-168): units whose def has `canResurrect` (the T1 workers `ord_mason`, `chs_scrapper`) walk into build range, refill the wreck with team supply at their reclaim rate if it was partly reclaimed, then resurrect it at their build power against the unit's build time, paid in power (the unit's power cost); the unit then stands where the wreck lay, the worker's owner's, at full health (an enemy's wreck too; a structure once its footprint is free; within the unit cap). Never a Commander's wreck. Other units ignore it. Resurrect progress stays on the wreck when the worker stops; reclaiming a wreck lowers its supply, and it must be refilled before the resurrect can finish.
- LOAD 32 (`targetId u16`; protocol 43, S-219): transports among the units fly to the target, an allied finished ground unit that fits (`docs/design/transports.md`), and pick it up in 1 s; units told to LOAD one of the sender's own transports board it (the transport picks each up, queued). UNLOAD 33 (pos; protocol 43): the sender's transports fly to the point and set their cargo down one unit a second on open ground around it. A carried unit takes no commands.
- Flags: bit0 queue (shift), bit1 line formation, bit2 GROUP (ctrl; protocol 31, S-137): on MOVE, FIGHT and PATROL, every ground unit of the selection moves no faster than its slowest ground unit's top speed, so the group keeps together (BAR's ctrl-move); aircraft fly as usual. Other commands ignore it. bit3 FRONT (space; protocol 40, S-199): on orders (MOVE, FIGHT, PATROL, ATTACK, ATTACK_GROUND, GUARD, REPAIR, RECLAIM, RESURRECT, mobile builders' BUILD, AREA, DGUN), the order goes in at the head of each unit's queue; the order under way stops and starts again after it (a frame keeps standing, the builder comes back to it), then the rest of the queue. It wins over QUEUE. On a factory, an order goes first on its list for new units; a factory's BUILD still appends to production. A FRONT DGUN out of range walks in, fires, then goes on with the queue.
- At most 200 unit IDs per command.
- The server applies a command to the sender's own live units only and ignores the rest. Commands are validated server-side (guide 19); a rejected command just has no effect.
- **All commands are effective** (S-4). With the queue flag, an order is appended to each unit's queue; without it, it replaces the queue:
  - MOVE;
  - FIGHT: attack-move: advances while no enemy is within weapon range, stops and fires while one is, then goes on (S-14);
  - PATROL: back and forth between the unit's start and the point, forever;
  - ATTACK: force-fire a unit the sender's team knows, even on hold fire; it chases into range. A target the team doesn't know is ignored;
  - GUARD: follow an allied unit (builders assist a frame or factory);
  - ATTACK_GROUND: bombers make runs on the spot; a silo fires once; units with ballistic weapons (artillery, tanks, gun turrets and emplacements; S-68) drive into range and shell it with those weapons, whatever their fire state, until another order. Missile-only units ignore it;
  - REPAIR: assist a frame or a factory's production, or heal a damaged allied unit, for free;
  - RECLAIM;
  - BUILD: mobile builders. A factory queues the unit.
- **STOP** clears the queue.
- **Factories:** MOVE, FIGHT, PATROL, GUARD, REPAIR and ATTACK given to a factory go on its **order list** (S-95, client request 44): the queue flag appends, a plain order replaces the list, STOP clears it. Each unit it produces rolls out of the exit, then takes a copy of the list, in order. (Before S-95: MOVE / FIGHT / PATROL set one rally point.) **REPEAT** on a factory sets **repeat** on or off: a finished item goes back to the end of the queue; the factory's `REPEAT` state bit shows it. Other units ignore REPEAT. **TOGGLE** only switches `TOGGLED_ON` (radar, jammer, converters, beam towers: off retracts them, S-96), on any unit (S-13; in protocol 6, TOGGLE on a factory meant repeat).
- Order queues aren't replicated yet. The client draws queued paths from what it sent (guide 15.6).
- **Formation goals** (S-12): the server splits a move's units into groups by move class and clearance (aircraft form one group) and places each group with `Shared/Grid/Formation`: `spacing(maxRadius)` with radius = footprint × `PlacementRules.RADIUS_PER_FOOTPRINT`, `layout` (a line from the first point to the second, or a spiral around the point; aircraft always take the spiral around the center), `deepestFirst`, then `assign`. A client that runs the same steps on the positions it knows gets the server's goals on open ground; near blocked cells the server also drops or snaps slots, which a client can't see exactly.

## 9a. Cheat commands (protocol 27, S-102)

Test and cheat commands are **ordinary commands**: sent on the Cmd channel, queued, recorded in the replay and applied in order, so replays repeat them exactly. The sim applies them only when the match allows cheats; otherwise each is answered `CHEATS_OFF` and does nothing.

- **Enabling:** match option `cheats = true` (`MatchState.Config`), or `Sim.new{ cheats = true }` without match rules (sandboxes, Studio scenes). `Sim.new{ offline = true }` (offline / Studio) additionally allows SPEED. Who may cheat is the Roblox entry's decision (host only, the allow list, never in public matchmaking): it drops CHEAT records from anyone else before `Sim.submit`.
- **Text:** `Shared/Net/CheatText`:
  - `parse(text, defs, selectedIds)` returns `(Schema.Command?, err?)`. It accepts a leading `/` or `/cheat` and the forms below.
  - `describe(event)` turns a CHEAT_RESULT into a chat line.
- **Record:** `cmdType 17 (CHEAT), flags 0, count u16 (0..200), unitIds, op u8, arg u8, team u8, defIndex u16, amount u32, x i16, z i16, radius u16`.
  - `team` 0 means the sender's team. `x` and `z` are world studs, rounded.
  - Only KILL SELECTED uses the unit IDs.

| Text | op (`Schema.CheatOp`) | Fields | Effect |
|---|---|---|---|
| `give <unitId> [count] [team] at <x,z>` | GIVE 1 | defIndex, amount = count (1..100), team, x, z | Finished units in a square formation around the point, owned by the sender (or the lowest player ID on `team`). Structures snap to the grid; a spot where placement fails (off the map, occupied, wrong terrain, no deposit) is skipped, as is a cell a mobile unit can't enter. No unit cap. Answer: count = placed, total = asked; NO_ROOM when none fit. |
| `res <supply\|power\|all> <amount\|max> [team]` | RES 2 | arg = `CheatResource` (1 supply, 2 power, 3 all), amount (≤ 10,000,000; `CHEAT_MAX` 0xFFFFFFFF = fill) | Sets the team's stored amount. Storage is raised to fit; the raise lasts. Answer: count = new stored (capped at 65535 on the wire). |
| `income <supply\|power\|all> <amount> [team]` | INCOME 3 | arg, amount per second | A flat bonus per second; 0 clears it. |
| `instabuild on\|off` | INSTABUILD 4 | arg 1 / 0 | Every frame and factory item (every team's) finishes on its next build step, free. Builders still walk to the site. |
| `reveal on\|off [team]` | REVEAL 5 | arg, team | Full sight, air sight, sonar and radar everywhere for the team's ally team: every enemy is VISIBLE and the sight map (SIGHT_ROWS / SIGHT_CELLS) covers the map. |
| `god on\|off` | GOD 6 | arg | The sender's units take no damage. KILL still works on them. |
| `kill selected` / `kill <team>` / `kill at <x,z> <radius>` | KILL 7 | arg = `CheatKill` (1 SELECTED: the unit IDs, any owner; 2 TEAM; 3 AREA: x, z, radius) | Self-destruct on this tick's Damage step: no wrecks. Answer: count = units killed. |
| `speed <0.25-8>` | SPEED 8 | amount = speed × 100 (25..800) | Only with `offline`, else NOT_OFFLINE. The sim stores it in `sim.cheats.speed` and doesn't read it: the tick driver runs at that speed. |
| `ai <team> pause\|resume` | AI 9 | arg 1 pause / 0 resume, team | Every AI player on the team skips its turns (`Skirmish.tick`). NO_AI when the team has none. |

- **Answer:** event `CHEAT_RESULT 22` (Events channel, owner only, the tick the command applied): `op u8, result u8, count u16, total u16`, 7 B.
  - `Schema.CheatResult`: OK 0, CHEATS_OFF 1, BAD_ARGS 2, NO_TEAM 3, NO_ROOM 4, NOT_OFFLINE 5, NO_AI 6, NO_MAP 7.
- **Flags:** the first cheat that applies marks the match:
  - `sim.cheats.used`;
  - the replay header's `cheated` (replay format 3: a `cheats u8` byte, bit 0 allowed, bit 1 used, bit 2 offline);
  - `Stats.series(sim).cheated`;
  - `Stats.report(sim)[pid].cheats`: the cheats each player applied.

  The results screen and replay list can show "cheats used" from these.

## 9b. The pre-game: chosen starts (protocol 36, S-169, S-171; protocol 37, S-174)

**Every match from the lobby starts with a pre-game** (S-171, the user: there are no fixed starts). The match server passes `startMode = "choose"` to `Sim.new` (`"fixed"`, start i on the map's start i, is left only for headless tests and tools). The sim boots with no units; only commands and the wire run (ticks advance). Everything here is ordinary recorded commands and events.

- **Sides and hints:** the ally teams, ascending, share the map's start positions in contiguous blocks (`Shared/Match/StartAreas.sides(allyTeams, #starts)`: with A sides and S starts, side k gets starts ⌊(k−1)·S/A⌋+1 .. ⌊k·S/A⌋; never more sides than starts). Those starts are **hints**: the AI takes them first (below).
- **Spawn boxes:** each side picks inside its **spawn box**. By default `StartAreas.boxes(sides, starts, StartAreas.bounds(grid), layers.startBoxes)`: the bounding box of its starts' boxes (the map's own `startBoxes`, or a square of `StartAreas.boxHalf` around each start: a sixth of the map's shorter side, 96..256 studs), kept 16 studs inside the map; two sides' boxes that would overlap are split at the midpoint between their starts, 96 studs apart. Since protocol 37 the host may draw them in the lobby (config `startBoxes`, fractions of the map from its low-X / low-Z corner; S-174): those replace the defaults. **Draw the boxes from `START_BOXES`**, which the server sends once after a join during the pre-game (world studs, rounded outward).
- **Commands** (no unit IDs):
  - `START_POS 20` (pos params: `cell, offX, offZ`): the sender's Commander starts there. Accepted when inside the sender's side's spawn box, on ground the Commander can stand on, and at least `StartAreas.SPACING` (48) studs from every other player's pick; refused silently otherwise (the PREGAME event shows what holds). A new one replaces the old.
  - `READY 21` (`value u8`: 1 ready, 0 not).
  - `FACTION 22` (`value u8`: 0 Order, 1 Chaos; protocol 37): while the sender isn't ready. It clears the sender's PREBUILD list (the other Commander's build options); the pick stays if the other Commander can stand there.
  - `START 23` (`value u8`: 0 start, 1 force; protocol 37): from the match's host only (PREGAME flag HOST). 0 starts the countdown when everyone is ready (PICK_CLOCK flag ALL_READY); 1 (`/forcestart`) starts it whoever is ready, and nobody can cancel it.
  - `BUILD` with **no unit IDs**: a build for the sender's future Commander (one of its build options; anywhere on the map); with the QUEUE flag appended, else the list is replaced. At most `Schema.PREBUILD_MAX` (30). `STOP` with no unit IDs clears it.
  - CAMERA and CHEAT work as usual; anything else is ignored until the match starts.
- **Events:**
  - `PREGAME` for every player, to everyone, when its pick, ready, AI, faction (CHAOS set = Chaos, else Order) or host flag changes (and after a join): `cell/offX/offZ` = the pick when PICKED is set.
  - `PICK_CLOCK`, to everyone, when it changes (about once a second): the pick time left (150..0; at 0 everyone without a pick got one), flag ALL_READY when every player is ready; with flag MAX_WAIT, `seconds` counts down instead to the forced start (the last 30 s before `Pregame.MAX_WAIT`, 300 s). With flag LOADING the clocks haven't started: they start once every human player's first command has arrived (the client's CAMERA after WELCOME), or after `Pregame.LOAD_WAIT` (120 s); `seconds` holds at 150 until then.
  - `START_BOXES`, to everyone, once after a join while the pre-game lasts: every side's box.
  - `PREBUILD` for the receiver and its allies (spectators: everyone), when the list changes (and after a join): the full list in order; `count` 0 = none.
  - `COUNTDOWN`: 3, 2, 1 while it runs (one each second; 5..1 before protocol 37), 255 when it's cancelled, **0 on the tick the match starts**, in the same outbox as the Commanders' ENTERs (and their first State records).
- **Flow (protocol 37, S-174):** everyone starts not ready. After `Pregame.PICK_TIME` (150 s) every player without a pick gets `Pregame.bestSpot`; they still ready themselves. With a host (config `match.host`, a player), the host starts once everyone is ready, or forces a start at any time; with no host (it spectates, or headless) the countdown starts by itself when everyone is ready. `Pregame.MAX_WAIT` (300 s) after the pre-game began a forced countdown starts anyway. A normal countdown (3 s) is cancelled by any un-ready; a forced one isn't. When it ends the Commanders appear on the picks and the match starts on that tick (`match.startTick`). **The landing:** for `Schema.LANDING_TICKS` (23 ticks, 1.5 s) after that, the sim holds every command except CAMERA and CHEAT (they apply after it, in order); then each Commander takes its PREBUILD list as its build orders. Play the descent (the star flare) over those ticks.
- **The AI, and players who never pick** (`Pregame.bestSpot`): the k-th player of a side (by player ID) takes the side's k-th hint when it's a valid pick; past the hints, or with the hint taken, the best valid spot in the box on a 16-stud grid: free deposits within 160 studs (deposits within 100 of another pick are taken) × 10 + open ground (the Commander's clearance, up to 6) × 2 − the distance to the side's nearest hint / 16. The AI picks once the first human has picked (or at once when every player is an AI; protocol 37), taking the spots left, and readies at once, through these commands.

## 10. Join and reconnect (S-2)

A reconnect is a join. The **Snapshot** channel carries a short handshake, then the normal channels deliver the state. Records start with `kind u8`.

| Kind | Direction | Layout | Meaning |
|---|---|---|---|
| `HELLO 1` | C → S | `protocol u16, defsHash u32`, 7 B | First message after connecting. |
| `REJECT 2` | S → C | `protocol u16, defsHash u32, reason u8`, 8 B | The server's versions; `reason` 1 = protocol, 2 = defs. Show "update your client" and stop. Nothing else is sent. |
| `WELCOME 3` | S → C | `tick u32, player u8, team u8, allyTeam u8, mapIdLength u8, mapId bytes, teamCount u8, allyTeam u8 × teamCount` (the list since protocol 30, S-129), 10 B + map ID + teams | The full sim tick (to unwrap wire ticks), who you are, the map to load, and every team's ally team (team 1 first; 0 = a team not in the match): units of teams in your ally team are friends. |

After WELCOME, the server resets the player's replication state, so the very next outbox is a complete picture:
- a **full strategic snapshot**, not waiting for the 5-tick cadence;
- **ENTER** for every tactical unit, if a camera is set; a reconnect keeps the last camera, a first join has none until the client sends `CAMERA`;
- **SPAWN_PROJ** for projectiles in view;
- an **Eco** record;
- **SIGHT_ROWS** of the whole map and a **WRECK** for every wreck the team knows (protocol 10).

The client drops everything it had before WELCOME.

Server side: `NetOut.hello(sim, msg)` returns nil (accept) or the REJECT message; malformed input errors, so `pcall` it. `NetOut.join(sim, player, clearCamera?)` queues the WELCOME. Test (`NetOut.spec`): a client that joins at tick 300 has, five ticks later, exactly the view of a client connected from the start: units, tiers, positions, icons and flags, unguided projectiles and the economy.

**Eco channel** (reliable): after the tick header, one record per team: a player gets only its own team's, a spectator every team's, in team order (protocol 9, S-21). Sent on economy ticks (every 5th tick) when any of them changed, and after WELCOME.

```
team u8             1..16 (protocol 9; 1..8 before 36)
per resource, supply then power:
  stored u32        whole units (floor)
  storage u32       whole units
  income u32        tenths of a unit per second
  demand u32        tenths of a unit per second (power: construction plus extractor upkeep and converters' burn, S-215)
  ratio u8          stall ratio, floor(ratio × 255)
wind u8             current wind, 0..255 of a turbine's maximum
radarError u16      the team's radar accuracy, tenths of a stud (0 = no radar):
                    a radar-fired weapon aims at a point circling a contact
                    at this distance (guide 11.4), Pinpointers included
trackError u16      the same for tracked contacts (0 = no fire-control radar)
precision u8        Pinpointer precision, floor(p × 255)  (protocol 32, S-147)
                    (trackError is 0 only while no fire-control radar has any
                    power; in a partial stall it still tracks, within its shrunk
                    reach: it applies to the contacts flagged TRACKED)
                    = 41 B
```

## 10a. Spectators and player replays (S-18)

- **Spectator:** `NetOut.addSpectator(sim)` adds a viewer that sees every unit (no fog, no ghosts), with a camera on the whole map: every unit is in its tactical tier, and it gets every combat event and homing correction. Its stream starts with a WELCOME whose `player`, `team` and `allyTeam` are **0** (no protocol change: 0 was never a valid player). It gets every team's Eco record (S-21) and no weapon targets (those are the owner's).
- **Player replay files** (`Shared/Net/PlayerReplay`, guide 17.1): the stream one viewer got (a player, or a spectator), message by message. A client plays it back through its normal receive code, never re-simulating, so it survives balance patches and platform differences; it needs the protocol version and defs hash it was recorded with (both in the header).
  - Layout: `"FTGP"`, format u8 (1), protocol u16, defsHash u32, mapId (u8 length + bytes), viewer u8 (0 = spectator), players (count u8, then id, team, allyTeam u8 each), firstTick u32, lastTick u32, then frames: tick delta (varint), message count (varint), and per message channel u8 (1-based in `PlayerReplay.CHANNELS`, the same order as `NetState.CHANNELS`), length (varint), bytes. Ticks without messages have no frame.
  - API: `PlayerReplay.new(header, firstTick)`, `record(replay, tick, outbox)` after every sim tick, `serialize` / `parse`, and `play(replay, deliver)`, which calls `deliver(tick, outbox)` for every tick (empty outboxes between frames), exactly what a live client receives.
  - Size: a spectator of a 4-minute AI match on `skirmish:192` is ~54 KB per game minute, a player ~33 KB (raw; compression is left to whoever stores the file). The 40-minute soak's spectator replay is in `docs/progress/sim.md`.
  - Tested (`PlayerReplay.spec`): playing back the spectator's and player 1's recordings rebuilds the live client's view exactly at every checkpoint (units, tiers, positions, health, state, targets, projectiles, economy).

## 11. Bandwidth (headless stress test, per player)

- 800 units: about 23 KB/s total (tactical 6.2, strategic 7.4, state 7.5, events 1.8), within the guide 7.6 budget of 35.
- Homing corrections: about 45 B/s per homing projectile in view.

## Changes

| Protocol | Change |
|---|---|
| 2 | ENTER / LEAVE / DEATH events |
| 3 | FIRE, SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK (D99) |
| 4 | Projectiles channel: homing corrections (D102) |
| 5 | Strategic TRACKED flag (D104) |
| 6 | Snapshot handshake (HELLO / REJECT / WELCOME), Eco channel (S-2) |
| 7 | REPEAT command (15) and `REPEAT` unit state bit (16); TOGGLE no longer sets repeat on factories (S-13) |
| 8 | State `targets` field (mask bit 32): own units' weapon targets (S-16, client request 6) |
| 9 | Eco records start with `team u8` (36 B); spectators get every team's (S-21) |
| 10 | Events WRECK 9, WRECK_GONE 10, SIGHT_ROWS 11, SIGHT_CELLS 12: the team's wrecks and sight map (S-26, client requests 9 and 10) |
| 34 | Event `OWN_STATUS 26`: own units off camera, health / build / queue head on change, capped per tick (S-158) |
| 44 | S-220 (client request 40, the user): events TRANSPORT 34 (`unitId u16` transport, `targetId u16` unit, `defIndex u16`, `action u8` = `Schema.TransportAction` PICKUP 1 / DROP 2 / CANCEL 3, `ticks u8`, `cell u16, offX u8, offZ u8`: the pick-up point or the set-down spot, 0 for CANCEL; 13 B) as each pick-up or set-down starts or stops, and CARRY 35 (`unitId u16`, `defIndex u16` of the unit on board, 0 = empty, `team u8`; 6 B) with the transport's ENTER and when it changes; both to every player with the transport tactical. Both transport tiers carry one unit |
| 46 | S-228, S-229 (the BAR roster's batch 1): unit state bits CLOAKED 256 and PARALYZED 512; no record changes |
| 45 | S-227 (the user): wrecks wear down to scrap heaps. WRECK gains `heap u8` (16 B), WRECK_STATE gains `heap u8` (7 B), new event WRECK_HIT 36 (`wreckId u16`, 3 B) |
| 43 | S-219 (transports, `docs/design/transports.md`): commands LOAD 32 (`targetId`: transports pick that allied unit up; units told to LOAD one of the sender's transports board it) and UNLOAD 33 (`pos`: the cargo is set down around the point, one unit a second); owner field CARGO 128 (`count u8`, then `u16` per unit on board; OWNER_MASK_ALL is 255). A carried unit leaves every player's view (a LEAVE, its owner's too) and comes back with an ENTER when set down; when a loaded transport dies, its cargo dies with it (no wrecks) |
| 42 | S-218: WORK kind RECLAIM_UNIT 6, a live enemy unit's ID: a construction turret takes it apart (it then dies with no wreck) |
| 41 | S-212: Strategic messages' header is `tick u16, part u8, parts u8` (section 6): drop missing units only once every part of a tick's snapshot arrived |
| 40 | S-197: WRECK gains `featureKind u8` (0 = a unit's wreck, 1 tree, 2 rock; `Shared/Defs/Features`), 15 B; a feature's defIndex is 0 and its supply / fullSupply count its resource (a tree's power); every team gets the map's features from the start. S-198: command ECO_LEVEL 31 (params `ecoLevel u8` = `Schema.EcoLevel` SUPPLY_SHARE 1 / POWER_SHARE 2 / CONVERT 3, `value u8` percent; no unit IDs): the sender's team's resource-bar slider; the Eco record gains `supplyShare, powerShare, convertAt` (u8 percent), 44 B. S-199: command flag `FRONT 8` (space: the order first in the queue) |
| 39 | S-194 (the playtest's feedback 2): commands SET_RETREAT 28 (value `Schema.RetreatAt` 0..3: aircraft fly to a rearm pad to heal below 30 / 40 / 50% health, or never; default 30%), SELF_DESTRUCT 29 (value 1 starts a 6 s countdown, 0 stops it), DGUN 30 (pos: Commanders fire their D-Gun at the point, walking into range first); STATES byte bits 4–5 the retreat setting; owner fields SELF_DESTRUCT 32 and WORK 64 (`kind u8, target u16`). Aircraft carry no ammo (AMMO is no longer sent by any def) |
| 37 | Pre-game v2 (section 9b, S-174): commands FACTION 22, START 23; PREGAME flags CHAOS 8, HOST 16; events PICK_CLOCK 31, START_BOXES 32; a 3 s countdown, then the landing (`Schema.LANDING_TICKS`). Sharing (S-176): commands SHARE_UNITS 24, SHARE_RESOURCE 25, REQUEST 26; event SHARE 33. Smart Reclaim (S-183): command AREA 27 (params `op u8 (AreaOp RECLAIM 1, REPAIR 2, RESURRECT 3), cell u16, offX u8, offZ u8, radius u16` studs 1..1024, builders' unit IDs); REPEAT now also on mobile builders (an area order stays) |
| 36 | Up to 16 teams: strategic records 7 B (team 4 bits); commands START_POS 20, READY 21, and BUILD / STOP with no unit IDs in the pre-game; events PREGAME 28, COUNTDOWN 29, PREBUILD 30 (section 9b, S-169); every match has the pre-game, spawn boxes (S-171) |
| 35 | Command RESURRECT 19; WRECK carries `supply`, `fullSupply` (14 B); event WRECK_STATE 27 (S-168) |
| 33 | Command PRIORITY 18 and unit state bit LOW_PRIORITY 128: resource priority (S-156) |
| 32 | Eco records end with the team's radar accuracy: `radarError u16, trackError u16, precision u8` (S-147) |
| 31 | Event `IDLE 25` (own idle builders and factories, S-136); command flag `GROUP 4` (S-137) |
| 30 | WELCOME ends with every team's ally team (`teamCount u8, allyTeam u8 × teamCount`): allies on the client (S-129) |
| 29 | Events DOME 23 and DOME_GONE 24: shield domes regardless of vision (S-122, client request 55) |
| 28 | SHOT carries `weaponDefIndex u16` (16 B): a hidden shooter's beam is drawn as a beam (S-118, client request 52) |
| 27 | CHEAT command 17 and event CHEAT_RESULT 22: cheat / test commands (section 9a, S-102); State owner field PRODUCING 16: allied factories' item and progress (S-103, client request 45) |
| 26 | SHIELD_HIT projId 0: a hitscan shot stopped at a dome's surface (S-89) |
| 25 | SHIELD_HIT flag SHIELD_ABSORBED 2: a light shell destroyed at a dome's surface (S-85) |
| 24 | Events SHIELD 19, SHIELD_HIT 20, SHIELD_FIELD 21: shield domes; corrections for shells in a field (S-79, client request 40) |
| 23 | Event ALERT 18 and the strategic UNDER_ATTACK flag (S-68, client request 39) |
| 22 | Unit state bits DEPLOYED 32, DEPLOYING 64 (the Warden, S-64) |
| 21 | State `owner` field CHARGES (bit 8): own units' flares and chaff left (S-63, client request 37) |
| 20 | State `owner` field (mask bit 128): own units' factory queue, fire / move state, aircraft ammo (S-61, client request 36) |
| 19 | Strategic icon is 8 bits, the unit's def index: one icon per unit type; flags 5 bits (S-58, client request 35) |
| 18 | Event SPAWN_STRATEGIC 17: a strategic missile with its goal; nukes boost, pitch over, then fly the lofted arc (`Shared/Combat/Lofted`; S-51, client request 28) |
| 17 | State `stock` entries gain `progress u8`: the next missile's build progress (S-49, client request 27b) |
| 16 | Events INTERCEPTOR 14, LAUNCH_WARNING 15, INTERCEPTED 16; strategic missiles go to every player (S-48, client request 26) |
| 15 | State `stock` field (mask bit 64): own units' missile stock per stockpile slot (S-47, client request 25) |
| 14 | SHOT 13: a hidden shooter's hitscan shot with both ends; projectiles and homing corrections in the camera area whatever the team sees (S-43, client request 21) |
| 13 | DECOYED ends with `countermeasure u8`: what defeated the missile (S-38, client request 18) |
| 12 | CANCEL command 16 (S-35) |
| 11 | DECOYED adds the decoy point (pos) and `decoyTicks u8` (22 B): decoyed missiles bend toward the flares or chaff instead of turning 60° in one tick (S-28, client request 13d) |
