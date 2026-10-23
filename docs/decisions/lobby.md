# Lobby decisions (L-)

Decisions of the lobby stream (session D): `src/lobby/**`, `lobby.project.json`, the Studio place "FTGG Lobby", `docs/contracts/match.md`. Progress is in [`../progress/lobby.md`](../progress/lobby.md).

Each entry gives the date, the decision, the alternatives and the reason. Overrule any of them and the code, the contract and this file are updated together.

## Summary

| ID | Decision |
|---|---|
| L-1 | The lobby is its own place, synced from `build/lobby` (darklua-converted, like the main build) by `lune run src/lobby/tools/sync serve` + `rojo serve lobby.project.json` on port 34874 |
| L-2 | Lobby constants in `src/lobby/shared/Config.luau`; the match place ID there |
| L-3 | Rooms are pure Luau (`Rooms.luau`), server-owned, per lobby server; members vs seats; host migration in join order |
| L-4 | Match config v1 and results record v1 in MemoryStore, found by the match server through its PrivateServerId; only the match ID travels in the teleport |
| L-5 | Map previews: one byte per pixel from the map's layers, built on the server, colored on the client |
| L-6 | Studio stand-ins for MemoryStore, TeleportService, DataStore and TextService, and an in-process stand-in match server |
| L-7 | Lobby specs in `src/lobby/tests`, run with `lune run src/lobby/tools/test` on the shared runner |
| L-8 | Profiles in DataStore `FtggProfiles`, written by lobby servers only, idempotent by match ID |
| L-9 | Room chat through one TextChatService channel per room |
| L-10 | The lobby UI follows BAR's lobby (top tabs, battle room in three columns) in the client's UI kit; green to go, red to leave |
| L-11 | Replays and Settings pages: listed and local for now |
| L-12 | The menu background is a live scene of the game's own unit models with a mouse parallax camera |

## L-1 (2026-10-23): a separate lobby place, its own converted tree

- **Decision:** the lobby is a separate place ("FTGG Lobby"). `lobby.project.json` maps a converted tree under `build/lobby/src`: `src/shared` (ReplicatedStorage.Shared), `src/lobby/shared` (ReplicatedStorage.LobbyShared), `src/lobby/server` (ServerScriptService.Lobby), `src/lobby/client` (StarterPlayerScripts.Lobby), and read-only copies of the client's `UI/Kit`, `Core/Chart` and `Render/MeshModels` (ReplicatedStorage.ClientKit) plus `place/MeshMaterials.model.json`. `src/lobby/tools/sync.luau` builds it (`build`: place file + `check_build`) or keeps it in sync (`serve`), never touching `build/serve` or `build/ci`. Rojo serves it on port 34874 so it can run next to the main game's sync.
- **Alternatives:** lobby screens inside the match place (one place, no teleports: but matches need their own servers anyway, and the guide says reserved servers); serving the sources directly (Roblox can't resolve `@shared`).
- **Why:** the user asked for a separate place; the conversion keeps the repo's require style (D84) and the main build untouched.
- **Requires:** `@shared/...` across roots, `@client/...` for the read-only client modules (darklua `sources`, and `src/lobby` has no `.luaurc` of its own yet), relative within `src/lobby`.

## L-2 (2026-10-23): one constants module

`Config.luau` holds the enums, limits, palette, timeouts, store names and `MATCH_PLACE_ID = 89435699207932` (the FTGG main game, as the user named it). Both places must be in one experience.

## L-3 (2026-10-23): rooms

- **Decision:** a room has members (humans in join order) and seats (`slots`: humans who play and AI). A member without a seat spectates. New members sit while the map has free starts (and FFA has fewer than 8), else spectate. The host changes settings, AI and starts; players set their own faction, team and color; colors are unique. Host changes to the map, mode, win rule or options unready everyone. A leaving host passes the room to the first member here (then the first away). Rooms live on one lobby server; the browser lists that server's rooms: public to all, friends-only to the host's friends, private never (join by the 5-character code).
- **Phases:** `setup` → `starting` (reserving, nothing changes, Leave refused) → `match` (members away keep their seats) → `setup` with the results.
- **Alternatives:** BAR's fixed slot list with open slots (the old dev lobby): more clicks; a cross-server room list through MemoryStore: needs a published place to test and joining a room on another server means teleporting there. Left for later (Needs my review).
- **Why:** BAR's model (players and spectators, teams with Add bot / Join), all checked server-side (guide 19); pure Luau so Lune tests it.

## L-4 (2026-10-23): match config and results through MemoryStore

- **Decision:** `docs/contracts/match.md` v1. The lobby writes `config/<matchId>` and `server/<privateServerId>` (plus lobby-only `access`, `room`, `player` keys) to MemoryStore HashMap `FtggMatch`; the match server finds its match from `game.PrivateServerId` (client-B's suggestion); teleport data carries only `{ matchId }`, a hint the lobby cross-checks against its own `player/<userId>` key and the config's player list. Results come back in `result/<matchId>`. Sim player order equals start order (TEAM: ally teams grouped), so version 1 needs no start-position change in the sim (`start == id`).
- **Alternatives:** teleport data (passes through clients: tamperable); keyed by match ID only (the match server would have to trust the teleport data to find it); a start pick on the match side (sim request 64): the lobby assigns starts instead.
- **Why:** never trust client data (user's rule, guide 19); MemoryStore is the cross-server channel with expiry.

## L-5 (2026-10-23): map previews

The server loads each map's layers once (MapRegistry, ~1.3 s for all six in Lune) and builds a 128-pixel preview: class (grass, rock, sand, road, water, deposit) × 32 shades of height or depth, one byte per pixel, plus the starts. Clients color it into an EditableImage and mark the starts in the color of who starts there. Alternatives: uploaded screenshots per map (assets to keep in step), a client-side MapGen run (slow on low-end devices).

## L-6 (2026-10-23): Studio stand-ins

- **Decision:** every Roblox service Studio can't use for this is behind an interface with a real and a Studio implementation: MatchStore (MemoryStore / in-memory with TTLs), Teleport (TeleportService / stand-in), ProfileStore (DataStore / in-memory), Social (TextService filter / pass-through; friendships live in both). In Studio the stand-in Teleport hands players to `StandInMatch`, which plays the match server's part of the contract in-process: finds its match through `server/<id>`, validates, heartbeats, writes a seeded made-up result after 20 s (or at once with "End match now"), and sends players back through the same arrival code a real return uses. "Server dies" and "Leave early" test the timeout and early-return paths; `StandInFail` on ServerScriptService.Lobby (`reserve`, `teleport`, `player`) stages failures. Studio uses shorter polling (1 s) and arrival timeout (15 s).
- **Why:** the user's rule; the start and return code is the same in both, only the services differ. What needs a published test is listed in the contract (section 10).

## L-7 (2026-10-23): lobby specs

Specs in `src/lobby/tests/*.spec.luau` (not synced), run by `lune run src/lobby/tools/test [filter]` with the shared `src/server/Tests/RunAll` (read-only). They cover the pure modules: Rooms, MatchConfig, Profile, MapPreview (on the real maps).

## L-8 (2026-10-23): profiles

DataStore `FtggProfiles`, key `p/<userId>`, written only by lobby servers through UpdateAsync with the user's ID for data requests. Writes queue per server, wait for UpdateAsync budget (up to 60 s), retry 5 times with backoff. Adding a match is idempotent by match ID; the history keeps 50; cheat and spectated matches are listed, not counted; abandoned matches count separately. Players who come back later get their entry from `player/<userId>` on join.

## L-9 (2026-10-23): room chat

One `TextChannel` per room under `TextChatService.LobbyRooms`, holding exactly the room's members (AddUserAsync on join, the TextSource destroyed on leave). Roblox filters and delivers; the room panel shows it. Alternative: our own remote with TextService filtering (more code, same result).

## L-10 (2026-10-23): BAR's lobby layout in the game's kit

The user's references (BAR's battle room, scenario page, landing page, loading screen). Top bar with Home, Skirmish, Multiplayer, Replays, Profile and Settings; the battle room in three columns (seats, chat, map + rules + actions); skirmish as map cards with a detail panel; the loading screen as the battle behind, a tip and a long bar. Everything uses the client's `UI/Kit` read-only, so the lobby matches the game. Green buttons go (Start, Ready, Launch, Quick play), red ones leave, amber is the kit's primary (forced start, Ready up).

## L-11 (2026-10-23): Replays and Settings

Replays lists your recent matches; "Watch" stays off until the match place can play a saved replay on a reserved server (contract "reserved for a later version"). Settings holds the lobby's own: interface scale, the background scene and its parallax, for the session. Keys, graphics and sound stay in the match's settings.

## L-12 (2026-10-23): the battle in the background

- **Decision:** the menu's background is a live scene: Order Paladins, Lancers and a Seraph SAM against Chaos Ravagers, a Minotaur and a Hydra MLRS, Harpies making passes, all from the game's own approved meshes (the client's `MeshModels`, read-only), in team colors, under evening light (Atmosphere, bloom, sun rays, a color grade, light depth of field). Turrets turn to targets, guns fire shells that burst near them, the MLRS fires arcing salvos, the SAM's missiles chase the Harpies and sometimes bring one down. Nothing is simulated. The camera drifts slowly and eases toward the mouse (parallax). A model that isn't ready in 20 s gets a box stand-in. Settings can turn the scene or the parallax off.
- **Alternatives:** a pre-rendered image (an upload, and static); the real sim running a match (needs the server sim and the renderer in the lobby place).
- **Why:** the user's request ("rendered in-game model like TANK, SAM fighting with lighting, move a little with the mouse").
