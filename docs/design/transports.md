# Transports (proposal, waiting for the user's OK)

Short design for air transports (playtest 3's open item), on BAR's model. Nothing is built until the user approves it; the decisions marked **(you pick)** are open.

## Units

| Tier | Order | Chaos | Capacity | Built at |
|---|---|---|---|---|
| T1 | Air transport (name TBD) | Air transport (name TBD) | 1 unit of footprint 1–2 | Airfield / Aerodrome |
| T2 | Heavy air transport (name TBD) | Heavy air transport (name TBD) | 4 slots: footprint 1 = 1 slot, footprint 2 = 2 slots, footprint 3 = 4 slots | Advanced Airfield / Aerodrome |

- **Unarmed.** Light armor. Each new id goes to B (icon), C (model), D (Codex) and E (2D art), as usual.
- **Speed:** slower while loaded: 1 − 0.1 × slots used (T2 full: 60%).

## Which units fit

- Ground units only: vehicles, bots and amphibious units, on land or in shallow water (not submerged).
- Never structures, aircraft, ships or T3 walkers.
- **Commanders (you pick):**
  - Yes, as in BAR. A T1 transport can carry one, which allows a "Commander drop".
  - Or no, which is safer for Command Ends.

## Load

- `LOAD` targets one unit or an area. The transport flies to each unit in turn, hovers over it, and picks it up in about 1 s.
- Only its own team's units. Allies too **(you pick)**.
- A picked-up unit:
  - drops its orders;
  - is hidden on the map and can't be seen, targeted or hit;
  - doesn't fire, build or use its sensors;
  - keeps its health, ammo and stockpile.
- A unit can also be told to board: right-click a transport.

## Unload

- `UNLOAD` at a point or an area. The transport flies there and lands the units one by one, about 1 s each.
- Each unit is set down on the nearest open cell its move class can stand on, spread by its footprint.
- If there's no room, the transport waits and reports "can't unload here".
- Units come out idle. A queued order after the unload (move, fight) goes to them.

## Death of a loaded transport

- **(you pick):**
  - **a)** As in BAR: every unit on board dies with it, without wrecks.
  - **b)** Passengers drop where it crashes and take 50% of their max health as fall damage, so light units usually die and heavy ones survive.
- Self-destructing a loaded transport kills its passengers, under a or b.

## Sim, network and AI

- **Sim:**
  - World: `cargo[id]`, the list of carried units, and `carrier[id]`, the transport a unit rides in.
  - Carried units stay in the world, but Movement, Combat, Sensors and the quadtree skip them.
  - Hashed and replayed.
- **Protocol (+1):**
  - Commands: `LOAD` and `UNLOAD`.
  - Unit state: a `CARRIED` bit.
  - The transport's own-status record carries its cargo, so the client can show the passengers' icons on it.
- **AI:** none at first. Later, Hard could ferry builders to far deposits.
- **Tests:**
  - Load and unload round trip.
  - Capacity by footprint.
  - Which units fit.
  - Death under the picked rule.
  - A carried unit can't be targeted.
  - Replay.
