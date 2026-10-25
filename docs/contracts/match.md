# Contract: lobby ↔ match server

Owner: lobby stream (session D). Readers and writers: the lobby place (`src/lobby`), the match place's server entry (`src/roblox`, client stream B), the simulation's match config (`Sim.new`, sim stream A). Decisions: L-4, L-6, L-8 in [`../decisions/lobby.md`](../decisions/lobby.md). Guide 16.3 (match flow), 7.5 (join, reconnect), 19 (never trust the client).

**Version 1.** Every record below carries `version = 1`. A reader that gets another version refuses the record (section 9).

## 1. Places and the flow

| Place | Role |
|---|---|
| **FTGG Lobby** (the experience's **start place**) | rooms, room setup, start, return, profiles |
| **Match place** (the FTGG main game, as the experience's second place) | runs one match per reserved server |

Both places **must be in the same experience**: reserved servers, MemoryStore and DataStores are per experience. The first live experience is **"FTGG Playtest"** (the user's account). The lobby finds the match place from one setting, `Config.MATCH_PLACE_ID` in `src/lobby/shared/Config.luau`: `0` (the default) looks it up at server start as the experience's only other place, or the one whose name contains "match" (L-14). The lobby's own place ID is never configured: it is `game.PlaceId`, and the config's `lobby.placeId` carries it for the return trip.

1. The host starts a room. The lobby server checks everything (`Rooms.checkStart`), reserves a server of the match place (`TeleportService:ReserveServer`), writes the match config and its lookup keys to MemoryStore (section 4), and teleports the room's players together with `TeleportOptions.ReservedServerAccessCode`. **Only the match ID travels in the teleport data**: `{ matchId = "<guid>" }`.
2. The match server finds its match from its own `game.PrivateServerId` (never from teleport data), admits only the listed users, plays, and keeps a heartbeat.
3. At the end it writes the results record, then teleports everyone back to the lobby place, to the lobby server they came from when it can.
4. The lobby puts them back in their room (rebuilt from the records if that server is gone), shows the results and adds the match to each player's profile.

## 2. Who writes what

| Record | Written by | Read by |
|---|---|---|
| `config/<matchId>`, `server/<privateServerId>`, `access/<matchId>`, `room/<matchId>`, `player/<userId>` | lobby | match server (`config`, `server`), lobby (all) |
| `alive/<matchId>` | match server | lobby |
| `result/<matchId>` | match server (or the lobby, only to mark a dead match `abandoned`, section 6) | lobby |
| Profile `p/<userId>` (DataStore) | lobby only | lobby |

## 3. Match config (`config/<matchId>`)

Built by `src/lobby/shared/MatchConfig.luau` (`MatchConfig.build`). The shapes, limits, palette and checks live in **`@shared/Match/MatchConfig`** (`validate`, `validateResult`, `users`; S-145). The lobby and the match place both use it, so they can't disagree.

| Field | Type | Meaning |
|---|---|---|
| `version` | number | `1` |
| `matchId` | string | a GUID; also the key |
| `createdAt` | number | `os.time()` when written |
| `seed` | integer 1..2^31−1 | the sim seed |
| `mapId` | string | a MapRegistry ID (`map:<name>` today) |
| `mode` | `"FFA"` \| `"TEAM"` | guide 16.1 |
| `win` | `"COMMAND_ENDS"` \| `"ANNIHILATION"` | guide 16.2 |
| `friendlyFire` | boolean | S-73 |
| `cheats` | boolean | the host's toggle; cheat commands still need the CheatConfig allow-list (C-119). Matches with cheats don't count on profiles |
| `startBoxes` | `{ [allyTeam]: { x0, z0, x1, z1 } }`? | the host's spawn boxes (F26, 2026-10-26): fractions of the map, 0..1, x0 < x1, z0 < z1, f = (coord - origin) / size (x0 / z0 the low-X / low-Z edge). Every side's box once the host moved or resized any (the others are the defaults: `StartAreas.boxes` for the match's sides, as fractions); absent when untouched (the match uses its own). Teams only; the match place passes it as the Sim config's `match.startBoxes` |
| `host` | number | the room host's UserId (F32, 2026-10-26). The match place maps it to a player ID, or to none when the host spectates (then the match starts once everyone is ready) |
| `players` | array | one per seat, in sim player order (below) |
| `spectators` | array of `{ user, name }` | members who watch |
| `lobby` | `{ placeId, jobId, roomId, roomName }` | where the room lives (for the return trip) |

Each `players[i]`:

| Field | Type | Meaning |
|---|---|---|
| `id` | integer | sim player ID, `== i` |
| `start` | integer | **`0`: picked in the match's pre-game** (S-171, 2026-10-24: no fixed starts; the map's starts are only hints for the AI). `== id` is still accepted from lobbies published before and means the same |
| `faction` | `"order"` \| `"chaos"` | |
| `allyTeam` | integer 1..n | FFA: `== id`. TEAM: 1..number of ally teams, numbered in team order |
| `color` | integer 1..#COLORS | index into the palette below; unique per match. Validated but unused since S-172: the match and the lobby colour players by `TeamColors.forViewer` with `id` |
| `user` | number? | a human's UserId (absent for an AI) |
| `name` | string | display name; `"AI 1 (normal)"` for an AI |
| `ai` | `"easy"` \| `"normal"` \| `"hard"`? | present only for an AI |

Player order: FFA keeps the room's seat order. TEAM puts ally teams together (team 1's players first, then team 2's...). Limits (S-169, S-171): at most 16 players, at least one human; FFA up to min(16, the map's starts); TEAM 2 to min(8, the map's starts) ally teams of any size. Every player keeps their own sim player (economy, units); factions by parity as below.

**To the sim config** (what `src/roblox/Lobby.config` does today): `players[i] → { id = i, team = <faction parity: Order odd, Chaos even, as Lobby.config>, allyTeam }`, `match = { mode, win, friendlyFire, cheats, ai = { [id] = level } }`, `scenario = "standard_start"`.

**Palette** (`COLORS` in `@shared/Match/MatchConfig`, RGB): 1 Blue 64,132,230 · 2 Red 222,70,62 · 3 Green 82,186,92 · 4 Yellow 236,200,64 · 5 Purple 156,92,214 · 6 Orange 238,132,46 · 7 Cyan 60,200,210 · 8 Pink 232,110,180 · 9 White 226,229,235 · 10 Olive 140,150,70 · 11 Brown 150,100,62 · 12 Teal 40,130,120.

## 4. Where it's stored

MemoryStore **HashMap `FtggMatch`** (values are JSON tables; each under 32 KB):

| Key | Value | TTL |
|---|---|---|
| `config/<matchId>` | the config (section 3) | 6 h |
| `server/<privateServerId>` | the matchId (string) | 6 h |
| `access/<matchId>` | `{ accessCode, privateServerId }`; lobby-only (rejoin) | 6 h |
| `room/<matchId>` | `{ privacy, password?, maxPlayers }`; lobby-only (rebuilding the room) | 6 h |
| `player/<userId>` | the matchId the user was last sent to | 6 h |
| `alive/<matchId>` | `{ at = os.time(), players = n }` | 120 s, refreshed every 30 s |
| `result/<matchId>` | the results record (section 5) | 3 days |

Lobby-only records (the match server never reads them):

| Where | Key | Value | TTL |
|---|---|---|---|
| HashMap `FtggMatch` | `hop/<userId>` | `{ roomId, password?, from }`: the room a player is moving to on another lobby server (L-15) | 300 s, removed on arrival |
| **SortedMap `FtggRooms`** | `<lobby JobId>` | that lobby server's rooms (`src/lobby/shared/Listing.luau`), rewritten on change and every 15 s | 60 s |

**The match server finds its match:** `server/<game.PrivateServerId>` → matchId → `config/<matchId>`. No key, or a config that fails validation: refuse (section 9). The teleport data's `matchId` must equal it; if not, trust the store and log it. Never read anything else from teleport data or from clients.

## 5. Results record (`result/<matchId>`)

Written once by the match server when the match ends for the humans (the sim's `match.over`, or every human out or gone).

| Field | Type | Meaning |
|---|---|---|
| `version` | number | `1` |
| `matchId` | string | |
| `outcome` | `"finished"` \| `"draw"` \| `"abandoned"` | `abandoned`: no result (every human left, the server is shutting down, or the config was refused) |
| `winner` | integer? | the winning ally team, `"finished"` only. Absent when every human is out while AI teams still fight (FFA): the match is over for the humans, and each player's `won` is false (the humans lost) |
| `seconds` | number | match length |
| `endedAt` | number | `os.time()` |
| `cheatsUsed` | boolean | any cheat command applied (`sim.cheats.used`) |
| `reason` | string? | optional, for `abandoned` |
| `error` | `{ code, detail? }`? | why the match failed as a whole (section 11): 2xx from the match server (a refused config, nobody arrived, everyone left, a server error), or 120 written by a lobby that stopped hearing from it. Optional; the lobby shows it with the results |
| `players` | array | `players[i]` for config `players[i]`: `{ id, won, outAt?, stats? }` |

Which outcome (client-B's `MatchContract.outcomeOf`): the sim's end gives `"finished"` + `winner`, or `"draw"` (no ally team left). Before that, every human gone from the server gives `"abandoned"`; one ally team standing gives `"finished"` + that team; every human out while AI teams still fight gives `"finished"` with no `winner` (a loss for the humans, not a draw).

`outAt` is seconds into the match when eliminated. `stats` is a flat table of numbers, the sim's `Stats.report` names: `unitsBuilt`, `unitsLost`, `unitsKilled`, `damageDealt`, `damageTaken`, `supplyGathered`, `powerGathered`, `supplySpent`, `powerSpent`. No time series (size); the match's own results screen keeps those. Checked by `validateResult` in `@shared/Match/MatchConfig`.

## 6. Lifetimes and timeouts

| What | Rule |
|---|---|
| Heartbeat | the match server sets `alive/<matchId>` within 30 s of starting and every 30 s after (TTL 120 s) |
| Lobby polling | every 15 s while the room is "in match": `result/<matchId>`, then `alive/<matchId>` |
| Never started | no heartbeat 120 s after the teleport: the lobby writes `result` `{ outcome = "abandoned", by = "lobby" }` if none exists, and the room returns to setup |
| Server died | the heartbeat expires (120 s): same as above |
| Waiting for players | the match server waits up to 90 s for the listed humans after the first arrives, then starts; an absent human's seat plays nobody until they rejoin (section 7) |
| Unlisted users | kicked with a message (not in `players` or `spectators`) |
| Return | after the result: `TeleportService:TeleportAsync(lobby place, players, options)` with `options.ServerInstanceId = config.lobby.jobId` and teleport data `{ matchId }`. If that fails (the lobby server is full or gone), retry without `ServerInstanceId`: any lobby server rebuilds the room from `config` and `room`. Players may leave earlier with "Return to lobby"; auto-return 30 s after the results screen |
| After the return | the room stays with the results; members not back within 180 s of the result leave it |

## 7. Rejoin

- A player who drops out of a match and rejoins the game lands in the lobby (the start place). The lobby reads `player/<userId>`; while the match runs, their room shows **Rejoin**, which teleports them with `access/<matchId>`'s access code.
- The match server treats a listed user arriving again as a reconnect (guide 7.5: reconnect = join): same seat, same team. Spectators too.
- A player whose teleport into the match fails is retried alone up to 3 times, then gets their seat back in the lobby with the reason and can use Rejoin.
- Once `result/<matchId>` exists the match is closed: no more rejoins; the match server shuts down when the last player leaves.
- A player who comes back long after (more than 180 s after the result) gets the history entry but no room.

## 8. Profiles (DataStore `FtggProfiles`, key `p/<userId>`)

Lobby servers are the only writers (UpdateAsync, retried with backoff, waiting for request budget; adding a match is idempotent by match ID). The match server never writes profiles. Record (`src/lobby/shared/Profile.luau`): `version, created, played, wins, losses, draws, abandoned, factions = { order, chaos }, history = [ { matchId, at, mapId, mapName, mode, result, seconds, faction?, players, ai, cheats } ]` (newest first, 50 at most). Cheat and spectated matches are listed, not counted.

**Reserved for a later version:** `kind = "replay"` configs (a reserved server of the match place playing a saved replay for the lobby's Replays page).

## 9. Refusals

The match server refuses a match whose config is missing, fails validation or has another `version`: it writes `result/<matchId>` with `outcome = "abandoned"`, `reason` and `error` (201, 202 or 203, section 11), then sends everyone back with the same `error` in their teleport data. The lobby shows it.

## 10. What only a published test can check

Studio can't reserve or teleport, and MemoryStore / DataStore need a published place, so the lobby uses stand-ins there (L-6): an in-memory store, an in-memory profile store, and an in-process stand-in match server that plays sections 4-6 (it finds its match through `server/<id>`, heartbeats, writes a result and sends players back). A published test must check:

1. `ReserveServer` and `TeleportAsync` into the match place, a group of 2+ players arriving together.
2. The match server reading `server/<PrivateServerId>` and `config/<matchId>` from the real MemoryStore.
3. The return trip to the same lobby server (`ServerInstanceId`), and to another one when it's gone (room rebuilt).
4. `TeleportInitFailed` for one player (e.g. a blocked account) and the retry.
5. Rejoin after a disconnect, through `access/<matchId>`.
6. A match server shut down mid-match (heartbeat expiry, abandoned).
7. Profile writes in the live DataStore, under budget pressure.
8. The room name filter (TextService) and friends-only rooms (`IsFriendsWith`) with real accounts.
9. Room chat (TextChatService channels) between two real clients.
10. Rooms across lobby servers (L-15): the `FtggRooms` list, a move to a room on another lobby server (`TeleportAsync` with `ServerInstanceId`), a move refused because that server is full.
11. Game invites (L-17): `SocialService:PromptGameInvite` with launch data `room=<code>`, and the invited friend landing in the room.
12. Lobby settings saved on the profile (L-16) and back on the next visit.

The ordered plan for a 4-tester session is in [`../progress/lobby.md`](../progress/lobby.md), "Live playtest".

## 11. Errors (F38, 2026-10-26)

The user's rule: "any failed attempt to connect to the game match must be displayed on the lobby when return with error code + description". Every failure has a number. The lobby shows it in a panel the player dismisses, with the code, a title, the description and the detail. That happens when the lobby itself fails to start or send them (1xx), or when they come back from a match server that couldn't take them or failed (2xx).

**Shape:** `{ code: number, detail: string? }`. `detail` is free text for the curious, up to 200 characters (an engine message, the validator's reason). The lobby drops unknown codes and cuts long details.

**How 2xx reach the lobby:**
- **One player sent back** (they weren't listed, the server was full, the game versions differ): teleport data `{ matchId, error = { code, detail? } }` on their return teleport.
- **The whole match failed** (a refused config, players didn't arrive, everyone left, a server error): the result record's `error` (section 5), and the same `error` in every returning player's teleport data. The lobby shows it once, with the results.

| Code | Title | Description |
|---|---|---|
| **1xx** | **lobby side** | |
| 101 | No match place | The lobby couldn't find the game's match place. |
| 102 | Bad match setup | The lobby built a match setup that failed its own check. (detail: the validator's reason) |
| 103 | No match server | Roblox didn't give the lobby a server for the match. (detail: the ReserveServer error) |
| 104 | Match store unavailable | The lobby couldn't save the match setup (MemoryStore). |
| 105 | Room changed | The room changed while the match was starting. |
| 106 | Nobody to send | None of the room's players were on this lobby server. |
| 110 | Teleport failed | Roblox couldn't send the players to the match server. (TeleportAsync threw, or TeleportResult `Failure`) |
| 111 | Match server not found | The teleport couldn't find the match server. (`GameNotFound`) |
| 112 | Match server closed | The match server shut down before you arrived. (`GameEnded`) |
| 113 | Match server full | The match server had no room for you. (`GameFull`) |
| 114 | Teleport not allowed | Roblox refused the teleport to the match. (`Unauthorized`) |
| 115 | Too many teleports | Roblox is limiting teleports right now. (`Flooded`) |
| 116 | Already teleporting | Another teleport was still in progress. (`IsTeleporting`) |
| 120 | Match server stopped answering | The match server stopped reporting, so the match was ended. (the lobby's heartbeat timeout) |
| 121 | Match not found | The running match's details have expired; it can't be rejoined. |
| **2xx** | **match side** | |
| 201 | No match setup | The match server found no setup for itself. (no `server/<id>` or `config/<id>`) |
| 202 | Bad match setup | The match server refused the lobby's match setup. (detail: the validator's reason) |
| 203 | Version mismatch | The lobby and the match place are on different versions. (config `version`) |
| 204 | Game version mismatch | Your game client and the match server are on different versions. (protocol or defs REJECT) |
| 205 | Not in this match | You aren't one of this match's players or spectators. |
| 206 | Match full | The match had no free seat for you. |
| 207 | Match already over | The match ended before you arrived. |
| 208 | Players didn't arrive | Not everyone reached the match in time, so it didn't start. (the start timeout) |
| 209 | Everyone left | Every player left, so the match was abandoned. |
| 210 | Match server error | The match server hit an error and ended the match. (detail: the error) |
| 299 | Match server problem | The match server sent you back for a reason it didn't name. |

The table lives in code as `src/lobby/shared/MatchErrors.luau`, until sim-A moves it to `@shared/Match/MatchConfig` (`ERRORS`) for both places.

## Changes

- 2026-10-23: version 1 (L-4).
- 2026-10-23: the checks moved to `@shared/Match/MatchConfig` (sim-A, S-145, the user's choice); the lobby and client-B dropped their copies.
- 2026-10-24 (later): `start` is `0` for every player (S-171: the match opens with a pre-game where players pick their start; `== id` still accepted from older lobbies); the new limits (16 players; FFA up to the map's starts; TEAM 2-8 sides of any size, up to the map's starts). The colour index is still sent and validated; the match colours players itself (S-172). Still version 1.
- 2026-10-26: **version 2** (sim-A's S-174): `host` (required: the room host's UserId, a player or a spectator) and `startBoxes` (optional, F26). The lobby sends `host` always and `startBoxes` once the host edited a box.
- 2026-10-24: the match place comes from `Config.MATCH_PLACE_ID` (0: found at server start) instead of the hard-coded main game ID, for the "FTGG Playtest" experience (L-14); lobby-only records `hop/<userId>` and the `FtggRooms` sorted map (L-15). The match server's side is unchanged; still version 1.
- 2026-10-23: `winner` may be absent on `"finished"` (every human out, AI still fighting), at client-B's question; still version 1 (nothing published yet).
