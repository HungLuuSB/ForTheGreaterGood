# Network contract: what the client receives

**Status: ready** (sim stream, 2026-10-21). Everything here is `Schema.PROTOCOL_VERSION` **15**, as built and tested, including the join / reconnect snapshot and the economy channel (section 10, S-2), the REPEAT command (S-13), and the team's sight map and wrecks (section 7a, S-26).

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
| `Projectiles` | S → C | UnreliableRemoteEvent | no | Homing-projectile corrections |
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
| Position (units) | `cell u16, offX u8, offZ u8` | `cell = cz × cellsX + cx`; `x = (cx + offX / 256) × 8 + originX`, same for z. Use `Grid:decode(cell, offX, offZ)` with the map's grid (from the map ID). |
| Strategic position | `cell u16` | Cell only. Draw at the cell center (`Grid:decode(cell, 128, 128)`). |
| Projectile / event position | `cell u16, offX u8, offZ u8, y i16` | x, z as above; `y = i16 / 8` studs (`Schema.Y_SCALE`). |
| Velocity | `vx, vy, vz i16` | studs per second = `i16 / 8`. |
| Heading | u8 | `heading × 360 / 256` degrees, 0 = +Z, counter-clockwise (radians: `× 2π / 256`). |
| Altitude | u8 | Studs above the ground, rounded. Only aircraft send it. |
| Health | u8 | `ceil(health / maxHealth × 255)`; 0 only when dead. |
| Build progress | u8 | `floor(progress × 255)`; 255 = complete. |
| Turret yaw / pitch | u8 | Radians in [−π, π] → `round((a + π) / 2π × 255)`; yaw is relative to the hull. |
| Def index | u16 | `defs.unitByIndex[i]` (1-based, `Defs.load()` order, identical on both sides; the defs hash proves it). |
| Weapon index | u16 | `defs.weaponByIndex[i]`. |
| Icon | 6 bits | 0 = unknown (radar / sonar blip). Else the position (1-based) of the def's `icon` name in the **sorted list of distinct icon names** over all unit defs, capped at 63: `Shared/Net/Icons` (`Icons.byDef`, `Icons.names`), which the server uses too. |
| Team | 3 bits (strategic) / u8 (ENTER) | 1..8. Ally teams come from the match config. |

**Unit `state` bits** (u16, `Schema.UnitState` in Shared; the sim's `World.State` is the same table): `MOVING 1` (since S-33: ground and naval units with a movement order or speed, aircraft unless landed, loitering included; it changes in a State record like any bit), `TOGGLED_ON 2` (radar / jammer switched on), `SUBMERGED 4`, `LANDED 8`, `REPEAT 16` (factory repeat on, protocol 7). Other bits are reserved (0).

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

The camera is sent by the client as a `CAMERA` command (cell rectangle `minX, minZ, maxX, maxZ`, u8 each; at most ~5 per second; guide 15.5).
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
  - Mask bits: health 1, state 2, aim 4, weapon 8, build 16, targets 32 (protocol 8), stock 64 (protocol 15).
  - Aim: `slotMask u8` (bit i−1 = slot i), then `yaw u8, pitch u8` per set bit in slot order.
  - A change of state bits or turret aim sends the state, the aim of every slot and the weapon field together.
  - Aim rest and restore (S-20): a unit enters with its weapons at their turret's rest pose (`restYaw`, `restPitch`); after losing a target a weapon holds its aim `restoreDelay` seconds, then turns back to rest. `Shared/Combat/Aim.update` is the server's exact per-tick step, so a client can animate between aim updates with the same results.
  - **Targets** (S-16, own units only): `slotMask u8`, then `targetId u16` per set bit (0 = no target). Sent to the unit's owner whenever a weapon's target changes (every slot), and with the ENTER tick when it has any target; the ID is always a unit (or remembered structure) the team knows. Other players never get it. Exact from the tick Targeting picks the target, before the turret has turned.
  - **Stock** (S-47, own units only; protocol 15): `slotMask u8`, then `count u8` per set bit: missiles in stock of each weapon slot that has a stockpile (`weapons[i].stockCapacity` in the defs; slots without one are never set). Sent to the unit's owner whenever any of its counts changes (every stockpile slot), and with the ENTER tick always. Other players and spectators never get it. Comes after `targets` in the record.

A Tactical or State record always refers to a unit the client got an ENTER for. If not, the client is out of sync: drop the record (the reference client asserts).

## 6. Strategic

- Every 5th tick (3 Hz) the server sends a full **snapshot** of every known unit that is not tactical for this player. That includes own units outside the camera and ghosts of structures that died unseen.
- Record: `unitId u16, cell u16, icon 6 bits | team 3 bits (team − 1) | flags 7 bits`, 6 B.
- Flags:
  - `RADAR_ONLY 1`, `SONAR_ONLY 2`, `UNDER_ATTACK 4` (reserved, not sent yet), `GHOST 8`, `TRACKED 16`;
  - bits 5–6 reserved.
- A message whose tick differs from the last strategic tick **starts a new snapshot**: drop every non-tactical unit, then add the records. A snapshot can span several messages with the same tick.
- An empty snapshot still sends one message holding only the tick header, so the client can drop units that disappeared.
- Positions of radar and sonar contacts are wobbled server-side (they move smoothly, re-aimed every 30 ticks); never treat them as exact.

## 7. Combat events (Events channel)

All of a tick's events are one reliable batch. Records start with `kind u8`; sizes include it. Shooters are sent only where P's ally team may know (D99). **Projectiles and shots are shown in P's camera area whatever the team sees (S-43, client request 21):** they carry no shooter, so a hidden shooter stays hidden; only normal sight reveals it.

| Kind | Layout | When P gets it |
|---|---|---|
| `FIRE 4` | `shooterId u16, slot u8 (bits 0–3 slot 1..8, bit 4 hit), end pos`, 10 B | Hitscan / beam shots of units in P's tactical tier. Draw a tracer from the shooter's muzzle to the end point (the target's hull centre on a hit, the ground on a miss). No target ID. |
| `SHOT 13` | `hit u8 (0 / 1), start pos, end pos`, 14 B (protocol 14) | A hitscan / beam shot whose shooter P doesn't have (not in its tactical tier), when either end is in the camera area (+2 cells). Draw a tracer from the start (the muzzle) to the end. No shooter or target ID. |
| `SPAWN_PROJ 5` | `projId u16, weaponIndex u16, pos, vel, targetId u16`, 19 B | A projectile the client doesn't have yet, once it is in the camera area (+2 cells), seen or not (S-43): at launch, or when it flies into the camera area. `targetId` is the homing target if P's team knows that unit, else 0. |
| `IMPACT 6` | `projId u16, pos`, 9 B | For projectiles the client has, or any impact in the camera area. Explosion effect; drop the projectile. Projectiles that reach the end of their life also send one (no damage). |
| `DECOYED 7` | `projId u16, pos, vel, decoy pos, decoyTicks u8, countermeasure u8`, 23 B (countermeasure: 1 flares, 2 chaff, 3 DIRCM, `Schema.Countermeasure`; protocol 13) | For projectiles the client has: a countermeasure seduced it. Snap to `pos`/`vel`, clear its target, and for the next `decoyTicks` ticks steer toward the decoy point with `Guidance.decoy` (stop early when it returns false), then fly straight (protocol 11, S-28). |
| `LOST_LOCK 8` | `projId u16, pos, vel`, 15 B | Same, but the missile flies on unguided. |
| `DEATH 3` | `unitId u16, severity u8, wreckId u16`, 6 B | Tactical units (section 5). |
| `ENTER 1` / `LEAVE 2` | 16 B / 3 B | Section 5. |

| `WRECK 9` | `wreckId u16, defIndex u16, cell u16, offX u8, offZ u8, heading u8`, 10 B | Section 7a. |
| `WRECK_GONE 10` | `wreckId u16`, 3 B | Section 7a. |
| `SIGHT_ROWS 11` | `firstRow u8, rowCount u8, rowBytes u8, bits`, 4 + rowCount × rowBytes B | Section 7a. |
| `SIGHT_CELLS 12` | `count u8, cell u16 × count`, 2 + 2 × count B | Section 7a. |

`pos` = `cell u16, offX u8, offZ u8, y i16` (6 B); `vel` = `vx, vy, vz i16` (6 B). Sizes per kind: `Schema.EVENT_BYTES` (fixed kinds), `Schema.eventBytes(e)` (all).

**Client projectiles** (guide 15.3):
- From SPAWN_PROJ, step each projectile yourself every tick with the server's math:
  - homing weapons (`weapon.turnRate`) whose target the client knows first steer (S-27, **`Shared/Combat/Guidance`**): `HOMING` missiles with `Guidance.pn(x, y, z, vx, vy, vz, tx, ty, tz, tvx, 0, tvz, rad(turnRate) / 15, 1/15)` (proportional navigation), `TORPEDO` with `Guidance.lead(x, y, z, vx, vy, vz, tx, ty, tz, tvx, tvz, rad(turnRate) / 15)`. `t` is the target's position **at the start of the tick** (where the client had it before this tick's records) and `tv` its velocity: `Guidance.velocity(heading, speed)` on the server; the reference client estimates it from its last two Tactical records (0 when a tick brings none);
  - then `Ballistics.step(x, y, z, vx, vy, vz, weapon.gravity or 0, 1/15)` (**`Shared/Combat/Ballistics`**).
  - A guided missile whose target leaves its seeker cone gets LOST_LOCK and flies on unguided (S-27); the client gets the event.
  - Vertical launches (`weapon.launch == "vertical"`: the radar SAMs, S-42) spawn pointing straight up from a launcher whose turret stays at rest. Step them with `Guidance.vertical(x, y, z, vx, vy, vz, tx, ty, tz, tvx, 0, tvz, rad(turnRate) / 15, 1/15, turned, climbLeft)`, which returns the velocity and the new `turned`: keep it per missile, false at SPAWN_PROJ (a missile that comes into view already turned over flips to true on its first step with the target near its nose).
  - The boost climb (S-44): `climbLeft = Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z))`, the weapon's `climbHeight` (100 studs on both radar SAMs) minus the missile's height above the ground under it. Use `Layers.heightAt` (Shared, cell-based: the cell's height, the server's `Combat.groundHeight`), not a smoothed ground, or the hand-over tick differs. While the missile still flies exactly straight up (vx = vz = 0, which the wire keeps exact) and `climbLeft > 0`, it doesn't steer; nothing about its age is needed.
  - A decoyed missile (DECOYED) follows its decoy point: `Guidance.decoy(x, y, z, vx, vy, vz, dx, dy, dz, rad(turnRate) / 15, Guidance.seekerAngle(weapon))` each tick while ticks remain and it returns true (S-28). The reference client matches the server's path to under a stud this way (`Guidance.spec`).
- Unguided projectiles then match the server exactly; homing ones are approximate.
- Drop a projectile on IMPACT. A projectile that leaves the map bursts on its edge with an IMPACT there (S-33). As a fallback, drop it at its time to live: `2 × range / projectileSpeed + 1` s (bombs 8 s), plus a tick.
- Projectile IDs are reused. A SPAWN_PROJ for an ID the client still has replaces it.

## 7a. Sight map and wrecks (Events channel, protocol 10, S-26; client requests 9 and 10)

**Sight.** The client's fog is the ally team's sight, exactly: sensor cells (16 studs, 2 × 2 grid cells; `grid.sensorX × grid.sensorZ`, index `z × sensorX + x`, `Grid:sensorCellAt(x, z)`) that any unit of the ally team (own or allied) has in LOS. Air sight (against aircraft only) is not part of it.
- `SIGHT_ROWS`: rows `firstRow .. firstRow + rowCount − 1` of the map as a bitset, `rowBytes = ceil(sensorX / 8)` bytes per row; cell x of a row is bit `x % 8` of byte `x // 8`; 1 = in sight. Sent after a WELCOME (the whole map, in records of at most 640 bytes of bits), and instead of SIGHT_CELLS when a tick's changes are larger.
- `SIGHT_CELLS`: up to 255 cells that changed since the last sight record, each `cell index | 0x8000` (`Schema.SIGHT_SEEN`) when it is now in sight, the bare index when it no longer is. Apply them in order.
- Sent on sensor ticks (every 2nd tick, `NetOut.SIGHT_EVERY`) when something changed. The client's map then equals `Sensors` LOS at the end of every sensor tick (tested on every one).
- Spectators get no sight records: they have no fog.

**Wrecks.** Known per ally team, like structure ghosts:
- `WRECK` when the team first has the wreck's spot in sight (in the same tick as the DEATH that made it, if the team saw it), on the whole map, not only the camera area (wrecks are on the minimap). `heading` is the dead unit's (u8 like ENTER); `defIndex` is the unit it was (the wreck model comes from its def).
- `WRECK_GONE` when the team sees the spot without the wreck (reclaimed). A wreck removed out of the team's sight stays on the client's map until then.
- After a WELCOME, a WRECK for every wreck the team knows. Spectators get every wreck at once and see it go at once.
- Wreck IDs are the server's (1-based, never reused within a match); RECLAIM commands target them.

**Cost** (`lune run stress`, 800 units, two players): sight ~0.3–0.4 KB/s and wrecks ~0.12 KB/s per player in a large battle (events 0.72 → 1.22 KB/s, total 15.4 KB/s of 35); a join adds the whole map once (2 KB on a 256-cell map) plus 10 B per known wreck.

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
- Types: MOVE 1, FIGHT 2, ATTACK 3, ATTACK_GROUND 4, PATROL 5, GUARD 6, STOP 7, BUILD 8, REPAIR 9, RECLAIM 10, SET_FIRE_STATE 11, SET_MOVE_STATE 12, TOGGLE 13, CAMERA 14, REPEAT 15 (`value u8`: 0 off, 1 on; protocol 7), CANCEL 16 (`value u8` 0..50; protocol 12): on an unfinished frame it cancels it (gone, no wreck; the frame's progress × cost is refunded); on a factory it drops queue item `value` (1-based; 0 = all), refunding the progress on the item in production (S-35).
- Flags: bit0 queue (shift), bit1 line formation.
- At most 200 unit IDs per command.
- The server applies a command to the sender's own live units only and ignores the rest. Commands are validated server-side (guide 19); a rejected command just has no effect.
- **All commands are effective** (S-4). With the queue flag, an order is appended to each unit's queue; without it, it replaces the queue:
  - MOVE;
  - FIGHT: attack-move: advances while no enemy is within weapon range, stops and fires while one is, then goes on (S-14);
  - PATROL: back and forth between the unit's start and the point, forever;
  - ATTACK: force-fire a unit the sender's team knows, even on hold fire; it chases into range. A target the team doesn't know is ignored;
  - GUARD: follow an allied unit (builders assist a frame or factory);
  - ATTACK_GROUND: bombers;
  - REPAIR: assist a frame or a factory's production, or heal a damaged allied unit, for free;
  - RECLAIM;
  - BUILD: mobile builders. A factory queues the unit.
- **STOP** clears the queue.
- **Factories:** MOVE / FIGHT / PATROL given to a factory set its **rally point** (produced units roll out of the exit, then take the rally order). **REPEAT** on a factory sets **repeat** on or off: a finished item goes back to the end of the queue; the factory's `REPEAT` state bit shows it. Other units ignore REPEAT. **TOGGLE** only switches `TOGGLED_ON` (radar, jammer, converters), on any unit (S-13; in protocol 6, TOGGLE on a factory meant repeat).
- Order queues aren't replicated yet. The client draws queued paths from what it sent (guide 15.6).
- **Formation goals** (S-12): the server splits a move's units into groups by move class and clearance (aircraft form one group) and places each group with `Shared/Grid/Formation`: `spacing(maxRadius)` with radius = footprint × `PlacementRules.RADIUS_PER_FOOTPRINT`, `layout` (a line from the first point to the second, or a spiral around the point; aircraft always take the spiral around the center), `deepestFirst`, then `assign`. A client that runs the same steps on the positions it knows gets the server's goals on open ground; near blocked cells the server also drops or snaps slots, which a client can't see exactly.

## 10. Join and reconnect (S-2)

A reconnect is a join. The **Snapshot** channel carries a short handshake, then the normal channels deliver the state. Records start with `kind u8`.

| Kind | Direction | Layout | Meaning |
|---|---|---|---|
| `HELLO 1` | C → S | `protocol u16, defsHash u32`, 7 B | First message after connecting. |
| `REJECT 2` | S → C | `protocol u16, defsHash u32, reason u8`, 8 B | The server's versions; `reason` 1 = protocol, 2 = defs. Show "update your client" and stop. Nothing else is sent. |
| `WELCOME 3` | S → C | `tick u32, player u8, team u8, allyTeam u8, mapIdLength u8, mapId bytes`, 9 B + map ID | The full sim tick (to unwrap wire ticks), who you are, and the map to load. |

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
team u8             1..8 (protocol 9)
per resource, supply then power:
  stored u32        whole units (floor)
  storage u32       whole units
  income u32        tenths of a unit per second
  demand u32        tenths of a unit per second
  ratio u8          stall ratio, floor(ratio × 255)
wind u8             current wind, 0..255 of a turbine's maximum
                    = 36 B
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
| 15 | State `stock` field (mask bit 64): own units' missile stock per stockpile slot (S-47, client request 25) |
| 14 | SHOT 13: a hidden shooter's hitscan shot with both ends; projectiles and homing corrections in the camera area whatever the team sees (S-43, client request 21) |
| 13 | DECOYED ends with `countermeasure u8`: what defeated the missile (S-38, client request 18) |
| 12 | CANCEL command 16 (S-35) |
| 11 | DECOYED adds the decoy point (pos) and `decoyTicks u8` (22 B): decoyed missiles bend toward the flares or chaff instead of turning 60° in one tick (S-28, client request 13d) |
