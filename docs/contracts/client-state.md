# Contract: client state for UI (first draft)

Owner: client stream. Readers: a future UI session (resource bar, build menu, command card, unit panel, minimap, alerts; guide 15.7). Status: **draft**, filled in as the client foundation lands (tasks 4–9). Network details are in `docs/contracts/net.md` (sim stream).

The UI reads one state table and calls one actions table. It never touches RemoteEvents, never edits the state, and never reads `workspace.Units` models for game data.

```lua
local Client = require(PlayerScripts.Client.Api)   -- { state = ..., actions = ..., changed = ... }
```

## 1. Read: `Client.state`

Plain tables, updated by the client each frame (positions) or when packets arrive (the rest). Treat them as read-only; copy what you keep.

| Field | Type | Meaning |
|---|---|---|
| `player` | `{ id, team, allyTeam }` | the local player's sim IDs |
| `tick` | number | latest server tick received |
| `units` | `{ [id]: UnitView }` | every unit the player knows (both tiers) |
| `selection` | `{ id }` | selected own units, in selection order |
| `groups` | `{ [1..9]: { id } }` | control groups |
| `camera` | `{ x, z, zoom, strategic: bool, rect = { minX, minZ, maxX, maxZ } }` | focus point (studs), zoom level, icon view on, visible cell rectangle |
| `hover` | `{ unit: id?, x, z }?` | what the mouse is over (ground point in studs) |
| `placement` | `{ defId, x, z, facing, valid, reason? }?` | active build ghost, nil when not placing |
| `economy` | `{ supply = Res, power = Res }` | **placeholder** until the sim sends the Eco channel (request in `docs/progress/client.md`) |
| `alerts` | `{ { kind, x, z, time } }` | recent alerts, newest last |

`UnitView`:

| Field | Type | Notes |
|---|---|---|
| `id` | number | sim unit ID (IDs are reused; the client drops a view on DEATH / LEAVE) |
| `defId` | string? | nil for unidentified radar blips |
| `team` | number | 1..8 |
| `relation` | `"own" \| "ally" \| "enemy"` | |
| `tier` | `"tactical" \| "strategic"` | tactical = full detail, model shown |
| `detection` | `"visible" \| "radar" \| "sonar" \| "ghost"` | own and ally units are `"visible"` |
| `x, y, z` | numbers | interpolated draw position (studs) |
| `heading` | number | radians, sim convention (`rig.md` 2) |
| `health` | number? | 0..1, tactical only |
| `build` | number? | 0..1 while under construction |
| `moving`, `landed`, `submerged`, `toggledOn` | booleans | from the state bits |
| `weapons` | `{ { yaw, pitch, state } }?` | tactical only; state = `"idle" \| "aiming" \| "ready" \| "restoring"` |

`Res` = `{ stored, storage, income, demand, ratio }` (ratio < 1 = stalling).

## 2. Listen: `Client.changed`

Signals with `:Connect(fn)`; each fires at most once per frame.

| Signal | Argument |
|---|---|
| `selection` | the new selection list |
| `units` | `{ added = { id }, removed = { id } }` |
| `economy` | `state.economy` |
| `placement` | `state.placement` or nil |
| `alert` | the new alert |

## 3. Trigger: `Client.actions`

Each action validates locally, then builds the Schema command and sends it on the Cmd channel. They return `ok, reason?`.

| Action | Effect |
|---|---|
| `select(ids, mode?)` | mode `"replace"` (default), `"add"`, `"toggle"`; own units only |
| `selectType(defId, onScreenOnly?)` | |
| `setGroup(n)`, `recallGroup(n)` | control groups 1..9 |
| `order(kind, target, queue?)` | kind = `"move" \| "fight" \| "attack" \| "attackGround" \| "patrol" \| "guard" \| "repair" \| "reclaim"`; target = `{ x, z }` or a unit ID |
| `smartOrder(x, z, unitId?, queue?)` | the right-click rule (guide 15.6) |
| `lineMove(x1, z1, x2, z2, queue?)` | |
| `stop()` | |
| `setFireState(n)`, `setMoveState(n)`, `toggle(on)` | Schema `FireState` / `MoveState` values |
| `beginPlacement(defId)`, `rotatePlacement()`, `cancelPlacement()` | build ghost; the click that places comes from input |
| `queueBuild(factoryId, defId, count)` | BUILD sent to the factory (the sim queues units, guide 9.2); removing from a queue needs a new command later |
| `focusCamera(x, z)` | minimap click |

## 4. Rules

- Read positions from `state.units`, not from models: models exist only for tactical units.
- Don't keep references to `UnitView` tables across frames for identity: compare IDs.
- Never send commands for units outside `selection` or not `relation == "own"`; the server rejects them anyway.
- Placeholder parts (economy, factory queues) are marked in this file and change when the sim provides the data.
