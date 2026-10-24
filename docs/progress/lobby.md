# Lobby progress

Progress of the lobby stream (session D): the lobby place "FTGG Lobby" (`src/lobby/**`, `lobby.project.json`, Rojo port 34874) and the lobby ↔ match contract (`docs/contracts/match.md`). Branch `m-lobby`, worktree `FTGG-lobby`. This stream never edits `src/client`, `src/server` or `src/shared`; it asks under "Requests" below. Decisions: `L-1`, `L-2`, ... in [`../decisions/lobby.md`](../decisions/lobby.md).

## Summary (2026-10-23, first lobby: rooms, start and return, profile)

- **The lobby place works end to end in Studio.** Make a room, set it up, start, play the (stand-in) match, come back to the room with the results, and see it on your profile.
- **Rooms (BAR battle room):** create a room (name, public / friends / private, optional password, 2-16 players), browse with search and filters, join by click or by code, leave, kick, host migration, room chat. The host picks the map (with a preview), mode, win rule, friendly fire and cheats, and adds AI with level and faction. Players pick faction, team and color and ready up. The host starts when all are ready, or forces it after a confirmation.
- **Start and return:** the server checks the room again, reserves a match server, writes the match config to MemoryStore, and teleports everyone together. Only the match ID travels with the teleport. Failures bring everyone back to the room with the reason. Coming back puts you in the same room, rebuilt if that server is gone. The room shows "in match" while it runs.
- **Studio can't teleport,** so a stand-in match server runs the match's side of the contract in-process. Its loading screen has buttons to end the match, "kill" the server, or leave early. All three paths were checked in Studio, plus staged reserve and teleport failures.
- **Main menu:** Home (Quick play), Skirmish (map cards and Launch), Multiplayer (rooms), Replays, Profile, Settings, laid out after your BAR references. The background is a live battle of the game's own tank, SAM, MLRS and aircraft models, with a mouse parallax camera.
- **Checked in Studio through the UI:** Home, the room browser, Create room, the battle room (Teams on Twin Lakes with 3 AI), room chat, Start, the stand-in match screen, the results panel, and the profile. Screenshots: `debug_out/screens/lobby_*.jpg`.
- **Re-checked after Rojo reconnected:** the background uses the game's real unit meshes (all 11, no box stand-ins), brighter and closer (`lobby_home.jpg`). The four fixes work: Skirmish scrolls with Launch pinned and segmented options, the results panel fits, the pages hide behind the loading screen (`lobby_loading.jpg`), and the browser order is right. A two-player free for all is called "1v1".
- **Contract:** `docs/contracts/match.md` v1 (config schema, MemoryStore keys, results record, timeouts, rejoin, profiles), filed below for sim-A and client-B.
- **Tests:** `lune run src/lobby/tools/test`: 32 tests in 4 specs pass. The lobby build check passes (`lune run src/lobby/tools/sync build`).
- **No Discord post:** the notify tool isn't in main (sim-A removed it at your request).
- Ready to merge: `18d894a` (lobby server, shared logic, specs, tooling; touches only `src/lobby`, `lobby.project.json`)
- Ready to merge: `bdb507b` (loading text readable over key art; includes merges of main with Volley)
- Ready to merge: `0e9644c` (top bar clear of Roblox's own buttons)
- Ready to merge: `d9c51c0` (no 3D rendering while key art covers the screen, as C-184)
- Ready to merge: `78c2c4d` (pause the 3D battle behind opaque key art)
- Ready to merge: `27b4ce0` (one key-art viewer: client-B's `UI/KeyArt` mounted read-only; includes a merge of main)
- Ready to merge: `84dc557` (background with the real meshes, brighter and closer; 1v1 naming; segmented skirmish options; checked in Studio)
- Ready to merge: `673427d` (the lobby uses `@shared/Match/MatchConfig`; includes a merge of main)
- Ready to merge: `22f73db` (layered key art with parallax for the loading screens, L-13, `docs/contracts/key-art.md`)
- Ready to merge: `287b99e` (match contract: a finished result may have no winner when every human is out; validator, specs, results panel)
- Ready to merge: `fb34ced` (lobby UI, background scene, `docs/contracts/match.md`, lobby decisions and progress; nothing outside `src/lobby`, `lobby.project.json` and the lobby docs)

## Connecting Studio

In "FTGG Lobby" only, from the repo root:

1. `lune run src/lobby/tools/sync serve` (keeps `build/lobby` converted)
2. `rojo serve lobby.project.json` (port 34874)
3. Rojo plugin: port **34874**, Connect.

Restart both after editing `lobby.project.json`; then reconnect the plugin.

## What needs a published test

Studio can't reserve or teleport, and MemoryStore and DataStore need a published place. The list is in `docs/contracts/match.md` section 10. In short:
1. Publish "FTGG Lobby" as the **start place** of the same experience as the match place (89435699207932). I haven't published anything.
2. The match place must implement its side of the contract (request 1 for client-B) before a real match can run.
3. Then check: group teleport in and out, the same lobby server on return (and a rebuilt room when it's gone), one player's failed teleport, rejoin, a match server shut down mid-match, profile writes, the name filter, friends-only rooms, and room chat with two real accounts.

## Needs my review

1. **Rooms are per lobby server.** Players on another lobby server don't see your room; friends join through the room code only if they're on the same server. A cross-server browser (rooms listed in MemoryStore, joining = teleporting to that server) is possible but needs a published place to test. Want it next?
2. **Guide 16.3 says "map vote".** Your design has the host pick the map (BAR). I followed your design; the guide is the sim stream's file, so I asked sim-A to update it (request A-3).
3. **Cheats:** the host can turn them on in any room. Matches with cheats are listed on the profile but don't count. The match server still enforces the allow-list (C-119). OK?
4. **Forced start** skips only the ready check; every other rule holds.
5. **Spectators** are members without a seat (when the map's starts are full, or by choice). They're in the config and may watch the match; client-B needs to support it (request B-1).
6. **Start positions:** the lobby orders players so the sim's player ID is the start index (Teams: ally teams together). So sim request 64 (chosen starts) isn't needed for version 1. BAR's start boxes or chosen starts could come later.
7. **Players beyond 16:** the room cap is 16 humans (players and spectators); FFA seats up to 8, Teams 4 × 4.
8. **Lobby settings** (UI scale, background scene, parallax) last for the session only. Should they be saved on the profile?
9. **Done (2026-10-23): the config validator is in `src/shared`** (`@shared/Match/MatchConfig`, S-145; the lobby uses it since its merge of main). sim-A moves validate / validateResult and their constants to `src/shared/Match/MatchConfig.luau` (from m-lobby 287b99e). Then the lobby and client-B drop their copies. `build` and `summary` stay in `src/lobby`.
11. **Decided (2026-10-23): layered key art with parallax** from models-C for both loading screens (L-13, `docs/contracts/key-art.md`). Uploads still need your approval.
10. **Merge check:** `integrate.sh` doesn't run the lobby's 32 specs. sim-A agreed to add `lune run src/lobby/tools/test` (a failure blocks the push) once its running merges finish; until then I run them before every "Ready to merge" line.

## Requests

### For sim-A (sim session)

- **A-1. Done (sim-A S-143):** confirmed, `standard_start` seats player i on start i (IDs must be contiguous from 1, which MatchConfig guarantees); request 64 closed against L-4. **Match config → Sim (contract section 3).** Nothing new is needed from `Sim.new` for version 1: player ID = start index, factions by team parity as `src/roblox/Lobby.config` does. Please confirm, and resolve your request 64 (chosen starts) against L-4: the lobby assigns starts by player order.
- **A-2. Done (S-145, main d095edd); the lobby uses `@shared/Match/MatchConfig`.** **A shared validator (optional).** If the match server should run `MatchConfig.validate` without copying it, it could move to `src/shared/Match/` (yours). Say if you want it.
- **A-3. Done (sim-A, m-sim-2 2e9b5c7).** **Guide 16.3** ("map vote, mode, teams, faction pick"): the user's design is a BAR battle room where the host picks the map; reserved servers via TeleportService; the flow in `docs/contracts/match.md`. Please update the guide.

### For client-B (client session, match place)

**B-1..B-4 done by client-B (C-173 / C-174 on m-client-foundation):** the match server side with a copy of the validator, the BAR-style loading screen (real caching progress), "Return to lobby" with the 30 s countdown, and `Kit.button` go / stop fills plus `Kit.input`. I'll switch the lobby to the kit's versions once they're on main. Their question (every human out while AI teams fight on) is answered in the contract: `"finished"` with no `winner`, a loss for the humans.

- **B-1. The match server's side of `docs/contracts/match.md`** (in `src/roblox`):
  - On start, read `server/<game.PrivateServerId>` → `config/<matchId>` from MemoryStore HashMap `FtggMatch`, validate (section 3), refuse otherwise (section 9). Teleport data is only a cross-check.
  - Admit only listed users; seat them by `players[i].user`; spectators get the spectator stream.
  - Heartbeat `alive/<matchId>` every 30 s.
  - At the end, write `result/<matchId>` (section 5), then teleport everyone back to the lobby place with `ServerInstanceId = config.lobby.jobId` and teleport data `{ matchId }`.
  - Rejoin = join; player colors from the palette; the dev lobby (`src/roblox/Lobby.luau`) stays the Studio fallback.
- **B-2. Loading screen** while players arrive (your plan), in the style of the user's reference (BAR: full-screen art, a tip line, a long olive progress bar). The lobby's own pre-teleport screen uses the same layout, so the hand-off looks continuous.
- **B-3. "Return to lobby"** on the results panel with a 30 s auto-return countdown; the server does the teleport (section 6).
- **B-4. Kit additions** (I use the kit read-only): a text input (`Kit.input`, the lobby has its own in `src/lobby/client/Ui.luau`), and a `fill` option on `Kit.button` for green / red action buttons.
- **B-5. (later) Replays from the lobby:** a `kind = "replay"` match config for a reserved server that plays a saved replay (contract "reserved for a later version").

- **B-6. Done (C-184, ddc588f).** **Key-art viewer stutter (2026-10-24, the user approved):** UDim2 offsets are whole pixels, so `UI/KeyArt` moved its layers in 1 px jumps. Move them by scale instead (fractional), give tiles a 1 px overlap and a 0.001° rotation (sub-pixel drawing). Tested live: smooth, 60 fps.

### For models-C (models session)

- **C-1. Key art with parallax layers (2026-10-23, the user):** 3 key arts per `docs/contracts/key-art.md`:
  1. "Commander's stand", a dusk land battle with ships on the far sea: **approved by you, rendered (m-models 37cfb7a), waiting for your upload approval**;
  2. a SAM site under air attack, at dusk (your style guide);
  3. a beach assault.

  Each art is 4 depth layers in 2 × 2 tiles of 1024 × 576. Once you approve the uploads, they go in the manifest's `keyArt`. The lobby's loading screen shows them as soon as they're listed.

## Plan and status

| Step | Status |
|---|---|
| `lobby.project.json`, sync and build tooling (L-1) | done |
| Rooms and room setup, server-checked (L-3), chat (L-9) | done, checked in Studio |
| Start and return with Studio stand-ins (L-4, L-6), failure paths | done, checked in Studio |
| Profile and history (L-8) | done, checked in Studio (stand-in store) |
| Main menu, skirmish, browser, battle room, loading and results screens (L-10, L-11) | done, checked in Studio |
| Background battle scene with parallax (L-12) | done, checked in Studio with the real meshes |
| Contract v1 and requests | done |
| Key-art contract and parallax viewer on the loading screen (L-13) | done; one viewer (client-B's `UI/KeyArt`, read-only). Art 2 "Volley" on main and checked in Studio through Quick play: smooth (60 fps), the battle paused behind it (`lobby_loading_volley.jpg`) |
| Published test (needs the user to publish, and B-1) | waiting |

## How to continue

- Specs: `lune run src/lobby/tools/test`. Offline build and check: `lune run src/lobby/tools/sync build` (only `build/lobby`).
- Server: `src/lobby/server/Main.server.luau` (requests and views), `Launcher` (start), `Returns` (poll, results, arrivals), `StandInMatch` (Studio), `Services/*` (real vs stand-in).
- Client: `src/lobby/client/Main.client.luau` (shell), `Pages/*`, `Overlays/*`, `Scene.luau` (background).
- Studio test hooks: `game.ServerScriptService.Lobby:SetAttribute("StandInFail", "reserve" | "teleport" | "player")` in a playtest's server.
