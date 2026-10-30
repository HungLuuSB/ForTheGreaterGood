# Transports (S-219, approved by the user 2026-10-30)

Air transports on BAR's model. The user's answers: Commanders and units can be carried; the light transport carries light units (Commanders included); most heavier units use the T2 transport; if a transport dies, the units it carries die with it.

## Units

| Tier | Order | Chaos | Carries | Built at |
|---|---|---|---|---|
| T1 | Courier (`ord_courier`) | Buzzard (`chs_buzzard`) | One light unit: tier 1 or a Commander, footprint up to 2 | Airfield |
| T2 | Ark (`ord_ark`) | Charon (`chs_charon`) | Up to 4 units of tier up to 2 and footprint up to 3, by slots: footprint 1 = 1 slot, 2 = 2, 3 = 4 (4 slots) | Advanced Airfield |

- Helicopters (`HELI`), unarmed. Names are placeholders the user can change.
- The def field is `transport = { slots, maxUnits, maxTier, maxFootprint }` (`Shared/Defs/Defs`). Commanders are tier 0.
- **Speed:** a loaded transport flies at `1 − 0.1 × slots used` of its top speed (an Ark full: 60%).

## Who fits (`Transport.canCarry`)

- Allied ground units only (`domain = "ground"`: vehicles, bots, amphibious units), finished.
- Never structures, aircraft, ships, T3, other transports, shield carriers, a deployed or deploying Warden, or a submerged unit.

## Load

- `LOAD` with a target unit: each transport flies over it, hovers within 10 studs plus the unit's radius, and picks it up in 1 s (`Transport.LOAD_TICKS` = 15). The unit stops when the pick-up starts.
- Units told to `LOAD` one of the sender's transports board it: the transport picks them up one by one, after its other orders.
- A carried unit is **parked** (`World.park`): it stays alive but leaves `world.ids`, so it doesn't move, fire, build, see, get seen or get hit. Its orders and work are dropped. It keeps its health, ammo and stockpile.
- A carried unit takes no orders.

## Unload

- `UNLOAD` at a point: the transport flies there (within 12 studs) and hovers. It sets one unit down each second on the nearest open ground its move class can stand on, with no structure on it, searching in rings out from where it hovers.
- With no room, it waits there.
- Units come out idle where they were set down.

## Death of a loaded transport

- Every unit on board dies with it, with no wrecks and no death blasts (the user's choice: as in BAR). A carried Commander dies too, which ends its player under Command Ends.
- The same when the transport self-destructs.

## Network (protocol 43)

- Commands: `LOAD` 32 (`targetId`) and `UNLOAD` 33 (`pos`).
- Owner field `CARGO` 128 on the transport's own-status record: `count u8`, then a `u16` unit ID per unit on board, in loading order. It is sent when the cargo changes, and with the ENTER when not empty.
- A carried unit leaves every player's view, its owner's too: a `LEAVE`. Setting it down brings an `ENTER`.

## AI

- None for now. Later, Hard could ferry builders to far deposits.

## Tests (`Transport.spec`)

- Load and unload round trip.
- Who fits, slots and capacity.
- Boarding, and a carried unit taking no orders.
- Death on board.
- Determinism.
- The wire: LEAVE, CARGO, ENTER.
