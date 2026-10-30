# Lobby decisions (L-)

Decisions of the lobby stream (session D): `src/lobby/**`, `lobby.project.json`, the Studio place "FTGG Lobby", `docs/contracts/match.md`. Progress is in [`../progress/lobby.md`](../progress/lobby.md).

Each entry gives the date, the decision, the alternatives and the reason. Overrule any of them and the code, the contract and this file are updated together.

## Summary

| ID | Decision |
|---|---|
| L-1 | The lobby is its own place, synced from `build/lobby` (darklua-converted, like the main build) by `lune run src/lobby/tools/sync serve` + `rojo serve lobby.project.json` on port 34874 |
| L-2 | Lobby constants in `src/lobby/shared/Config.luau`; the match place setting there (L-14) |
| L-3 | Rooms are pure Luau (`Rooms.luau`), server-owned, on one lobby server each (listed on all of them, L-15); members vs seats; host migration in join order |
| L-4 | Match config v1 and results record v1 in MemoryStore, found by the match server through its PrivateServerId; only the match ID travels in the teleport |
| L-5 | Map previews: one byte per pixel from the map's layers, built on the server, colored on the client |
| L-6 | Studio stand-ins for MemoryStore, TeleportService, DataStore and TextService, and an in-process stand-in match server |
| L-7 | Lobby specs in `src/lobby/tests`, run with `lune run src/lobby/tools/test` on the shared runner |
| L-8 | Profiles in DataStore `FtggProfiles`, written by lobby servers only, idempotent by match ID |
| L-9 | Room chat through one TextChatService channel per room |
| L-10 | The lobby UI follows BAR's lobby (top tabs, battle room in three columns) in the client's UI kit; green to go, red to leave |
| L-11 | Replays and Settings pages: Replays listed only; Settings saved on the profile (L-16) |
| L-12 | The menu background is a live scene of the game's own unit models with a mouse parallax camera |
| L-13 | Loading screens show layered key art from the models stream with mouse parallax (`docs/contracts/key-art.md`) |
| L-14 | The match place comes from one setting, `Config.MATCH_PLACE_ID`; 0 finds it at server start (the experience's other place) |
| L-15 | Rooms are listed across lobby servers through a MemoryStore sorted map; joining one elsewhere is a teleport to that server, then the usual join |
| L-16 | The lobby settings (UI scale, background scene, parallax) are saved on the profile |
| L-17 | Invite a friend: a Roblox game invite whose launch data is the room code |
| L-18 | A Units tab: the unit encyclopedia by role with counterparts, a 3D showroom with places, and the article from the defs |

## L-1 (2026-10-23): a separate lobby place, its own converted tree

- **Decision:** the lobby is a separate place ("FTGG Lobby"). `lobby.project.json` maps a converted tree under `build/lobby/src`: `src/shared` (ReplicatedStorage.Shared), `src/lobby/shared` (ReplicatedStorage.LobbyShared), `src/lobby/server` (ServerScriptService.Lobby), `src/lobby/client` (StarterPlayerScripts.Lobby), and read-only copies of the client's `UI/Kit`, `Core/Chart` and `Render/MeshModels` (ReplicatedStorage.ClientKit) plus `place/MeshMaterials.model.json`. `src/lobby/tools/sync.luau` builds it (`build`: place file + `check_build`) or keeps it in sync (`serve`), never touching `build/serve` or `build/ci`. Rojo serves it on port 34874 so it can run next to the main game's sync.
- **Alternatives:** lobby screens inside the match place (one place, no teleports: but matches need their own servers anyway, and the guide says reserved servers); serving the sources directly (Roblox can't resolve `@shared`).
- **Why:** the user asked for a separate place; the conversion keeps the repo's require style (D84) and the main build untouched.
- **Requires:** `@shared/...` across roots, `@client/...` for the read-only client modules (darklua `sources`, and `src/lobby` has no `.luaurc` of its own yet), relative within `src/lobby`.

## L-2 (2026-10-23): one constants module

`Config.luau` holds the lobby's limits, labels, timeouts, store names and the match place setting `MATCH_PLACE_ID` (L-14; it was the main game's 89435699207932 until 2026-10-24). Both places must be in one experience. Since S-145 the contract's version, enums, team limits and palette come from `@shared/Match/MatchConfig` and are re-exported here.

## L-3 (2026-10-23): rooms

- **Decision:** a room has members (humans in join order) and seats (`slots`: humans who play and AI). A member without a seat spectates. New members sit while the map has free starts (and FFA has fewer than 8), else spectate. The host changes settings, AI and starts; players set their own faction, team and color; colors are unique. Host changes to the map, mode, win rule or options unready everyone. A leaving host passes the room to the first member here (then the first away). Rooms live on one lobby server; the browser lists every lobby server's rooms (L-15): public to all, friends-only to the host's friends, private never (join by the 5-character code).
- **Phases:** `setup` → `starting` (reserving, nothing changes, Leave refused) → `match` (members away keep their seats) → `setup` with the results.
- **Alternatives:** BAR's fixed slot list with open slots (the old dev lobby): more clicks; a cross-server room list through MemoryStore: added on 2026-10-24 (L-15).
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

Replays lists your recent matches; "Watch" stays off until the match place can play a saved replay on a reserved server (contract "reserved for a later version"). Settings holds the lobby's own: interface scale, the background scene and its parallax, saved on the profile since 2026-10-24 (L-16). Keys, graphics and sound stay in the match's settings.

## L-12 (2026-10-23): the battle in the background

- **Decision:** the menu's background is a live scene: Order Paladins, Lancers and a Seraph SAM against Chaos Ravagers, a Minotaur and a Hydra MLRS, Harpies making passes, all from the game's own approved meshes (the client's `MeshModels`, read-only), in team colors, under evening light (Atmosphere, bloom, sun rays, a color grade, light depth of field). Turrets turn to targets, guns fire shells that burst near them, the MLRS fires arcing salvos, the SAM's missiles chase the Harpies and sometimes bring one down. Nothing is simulated. The camera drifts slowly and eases toward the mouse (parallax). A model that isn't ready in 20 s gets a box stand-in. Settings can turn the scene or the parallax off.
- **Alternatives:** a pre-rendered image (an upload, and static); the real sim running a match (needs the server sim and the renderer in the lobby place).
- **Why:** the user's request ("rendered in-game model like TANK, SAM fighting with lighting, move a little with the mouse").

## L-13 (2026-10-23): layered key art with parallax for the loading screens

- **Decision:** the user's call. models-C renders key art (tanks, aircraft, ships on the far side, SAM missiles, ground explosions, realistic light, a sci-fi edge) as 4 layers from one camera (`sky`, `far`, `mid`, `near`, each with a depth). The loading screens shift each layer with the mouse in proportion to its depth, plus an idle drift. Layers are 2048 × 1152 in 2 × 2 tiles of 1024 × 576, because Roblox shrinks images above 1024 px. The tiles are listed in the mesh manifest's `keyArt` table (C's generated file); "review" art shows only in Studio. The viewer is client-B's `src/client/UI/KeyArt.luau` (C-176, started as a copy of the lobby's), used read-only by the lobby like the UI kit, so both loading screens run the same code. Without approved art the lobby keeps the live battle behind the loading screen.
- **Smoothness (2026-10-24):** the layers move by fractions of the screen (UDim2 offsets are whole pixels), the tiles draw at sub-pixel positions, and the lobby pauses its 3D battle while art covers the screen (`Scene.setCovered`). Measured in Studio: 39 → 60 fps, the near layer moving every frame instead of every third.
- **Alternatives:** a single flat image (no depth); the live 3D scene on the match side too (the match place loads its own assets while that screen shows, so a picture is lighter).
- **Why:** the user asked for stunning key art that keeps the parallax feel of the menu.

## L-14 (2026-10-24): the match place from one setting

- **Decision:** the user's call for the live playtest in a new experience, "FTGG Playtest" (the lobby as its start place, the match place added as its second place). `Config.MATCH_PLACE_ID` is the only place setting. Its default `0` means "find it": at server start `server/Places.luau` lists the experience's places (`AssetService:GetGamePlacesAsync`, retried) and takes the only one that isn't this place, or the one whose name contains "match"; it logs `[Lobby] match place <id> (...)`. A non-zero setting wins. Starting a match without a match place fails with the reason in the room. The lobby place ID is never configured: `game.PlaceId`, carried in the config's `lobby.placeId` for the return.
- **Alternatives:** a hard-coded ID per experience (a lobby rebuild and republish after the match place is published, and an easy mix-up between experiences); an attribute set on the place in Studio (Rojo-managed instances, easy to lose).
- **Why:** the same lobby build works in any experience whose other place is the match place, so publishing needs no code change.

## L-15 (2026-10-24): rooms across lobby servers

- **Decision:** the user approved it (queue item 1). Each lobby server writes one entry, keyed by its JobId, to the MemoryStore sorted map `FtggRooms` (TTL 60 s): its rooms with privacy, password, host and phase, and its player count. It rewrites the entry when its rooms change (at most every 3 s) and at least every 15 s, and reads the whole map every 10 s (`server/Lobbies.luau`, pure part `shared/Listing.luau`). The browser lists the other servers' public rooms, and friends-only ones to the host's friends, tagged "[other server]"; private rooms are listed for their codes only. The top bar's "players online" counts every lobby server. Joining a room elsewhere (click or code) is a hop: this server checks phase, room, friendship and password; writes `hop/<userId>` (the room and password, 300 s) to `FtggMatch`; and teleports the player to that server (`TeleportOptions.ServerInstanceId`), showing the loading screen. The room's server reads the key on arrival and joins them through `Rooms.join`. A failed teleport (a full server) brings a toast. Room codes are unique across the listed servers.
- **Studio stand-in:** an in-memory sorted map and a stand-in peer server (`StandInPeer`) with four rooms at fixed codes (PEERT Teams, PEERL password "peer", PEERP private, PEERM in a match). A hop to one moves that room into this server and runs the real arrival. `StandInFail = "hop"` stages a failed move.
- **Alternatives:** one HashMap key per room (more requests per read); a cross-server MessagingService feed (no state for a server that just started); joining a remote room without a teleport (not possible: room members must be on its server to start together).
- **Why:** friends on different lobby servers could only meet through a code that worked on one server; budget: a few requests per server per minute against MemoryStore's per-experience limit.

## L-16 (2026-10-24): lobby settings on the profile

Since 2026-10-24 the page is client-B's settings body (`Kit.options`, C-202), as in the match: search, a section tree, sub-section headers, hover help; the camera switch sits under the battle scene switch and dims with it.

The user approved it (queue item 2). The profile record gets `settings = { uiScale, scene, parallax }` (`Profile.cleanSettings` checks each field: scale 0.75-1.25 in 0.05 steps, booleans; older records get the defaults). The Settings page applies the saved values when the profile arrives and sends `{ op = "settings" }` after each change (the slider once it rests); the server writes the latest values in one UpdateAsync 3 s later. Alternative: client-side storage (none that persists across devices on Roblox).

## L-17 (2026-10-24): invite a friend

The user approved it (queue item 5). "Invite" in the room calls `SocialService:PromptGameInvite` with launch data `room=<code>` (`Listing.launchData`). A player who joins with that launch data goes to the room after the match-return and hop checks: on this server with `Rooms.join`, on another with a hop; a room with a password asks for it. The launch data is only a code (anyone can make a link with launch data), so every rule of a normal join applies. In Studio the attribute `StandInLaunch` on ServerScriptService.Lobby stands in for the launch data. Alternative: following the inviter (lands on their server, not in their room).

## L-18 (2026-10-24): the Units tab (unit encyclopedia)

- **Decision:** the user's request ("a wikipedia tab for units"), plan approved with the 3D showroom. A **Units** tab between Multiplayer and Replays:
  - **List (left):** Order or Chaos, search (names and roles), All / Units / Structures, tier; units grouped by section (command and workers, ground, air, naval, defences, sensors and EW, strategic, economy, factories) and role, with their strategic icons (client-B's `UI/IconAtlas`, read-only).
  - **Showroom (middle):** the unit's real model (client-B's `Render/Models`: the BAR mesh when approved, else the blockout; `MeshModels` starts every approved model when the tab first opens and the shown unit jumps the queue) on a place: Pad, Field, Water (terrain water, ships at their waterline, submarines lower), Shore (amphibious units at the waterline on a beach) or Sky (a runway far below; aircraft hover and bob). Auto picks the place from client-B's `Core/PortraitStage`, as the build menu's portraits do (structures on the field). Later (2026-10-26, the user): an Underwater place (deep water over a seabed, the camera under the surface; Auto picks it for submarines and amphibious units), water transparency 0.05, and models stand on each place's floor dressing instead of sinking into it. Options: the turntable, Dusk (the menu's light) or Day, the colour (faction or any of the 12 lobby colours), and Compare (the unit and its counterparts side by side). Drag turns, the wheel zooms. The places are built once, far from the menu's battle; while the tab is open the battle leaves the world (`Scene.setAway`) and the camera is the showroom's.
  - **Article (right):** name, faction, role, tier, description; the counterpart (links) with how they differ (health, damage per second, range, speed, sight and value, 5% or more, green when better); the in-game values (cost, value, build work and seconds at its first builder, health and armor, movement, sensors, stealth, firepower, countermeasures, ammo, build power, income, storage, size); each weapon (damage per second against its main class, range, reload, volley, damage per armor class, targets, guidance, lock, splash, stock); what it builds and what builds it (links).
- **Data:** `src/lobby/shared/Codex.luau`. The defs have no role, so the roles are a table after guide section 13 (with the economy, factories and the units added since); a role holds each faction's units (none for a faction-only role, two for Chaos's heavy laser towers). A def no role lists shows under "Other"; defs nothing builds (retired: Inferno, Spike, the old Bulwark) don't show. The numbers use the unit panel's rule (client-B's `Core/UnitStats`: damage × shots ÷ reload against the weapon's main class), computed here because UnitStats needs the match's client world. `Codex.spec` checks the roles against the real defs.
- **Read-only client modules added to `lobby.project.json`:** `Render/Models`, `Render/BlockoutBuilder`, `Core/PortraitStage`, `UI/IconAtlas` (with the kit's rule: client-B keeps their API stable).
- **Alternatives:** a flat ViewportFrame preview (no terrain water, no shadows, the lobby's lighting doesn't reach it); a `role` field on the defs (sim-A's files; the lobby's table works now and the spec catches drift).

## L-19 (2026-10-26): automatic player colours in the room

- **Decision:** sim-A's request after the beta publish (S-172, the user's rule: colours are automatic). The room has no colour picker. Every seat shows `TeamColors.forViewer` from the viewer's seat: you Blue, allies cold, enemies warm; a spectator sees the lowest ally team as cold. The IDs passed to `forViewer` are the config's player IDs (`MatchConfig.seats`, the order `MatchConfig.build` sends), so a player's colour in the room is the one the match shows them. The results panel does the same with the players' list order.
- **The colour index stays in the contract:** each seat still gets a unique palette index (validated by the shared check), so the config keeps its shape and older match servers still accept it.
- **Alternatives:** keep the picker as a preference (the match would ignore it, which misleads); send the viewer's colours from the server (each viewer needs its own, and the client already has everything `forViewer` needs).

## L-20 (2026-10-26): spawn boxes edited by the host (F26)

- **Decision:** the user's playtest feedback F26 and sim-A's spec. In Teams, the room's map shows one box per team; the host drags a side to resize it or the inside to move it, and sides snap to the map's edge (within 3%). Boxes are fractions of the map, `{ x0, z0, x1, z1 }`, with f = (coord - origin) / size. The room keeps the host's edits by room team (`settings.boxes`, string keys, so views and remotes carry them). A new map or mode clears them, and "Reset boxes" does too. A team without seats keeps its edit but isn't shown or sent.
- **Defaults:** `StartAreas.boxes` for the room's sides (its seated teams, ascending, numbered like the config's ally teams), from the map's bounds, start hints and own boxes, which the server reads from the layers and sends with the previews. So an untouched room shows the boxes the match would use.
- **Contract:** `startBoxes` by ally team, every side's box once any was edited (the others are the defaults), else absent; `host` (F32). Both are in match.md v2 (sim-A's S-174).
- **Alternatives:** a larger editor dialog (the room's map is about 230 px on a small screen, but dragging on it worked in Studio); boxes in free for all (16 boxes on one map; FFA keeps the match's defaults).

## L-21 (2026-10-26): match errors with codes (F38)

- **Decision:** the user's rule that every failed attempt to reach a match shows on the lobby with a code and a description. One numbered list: 1xx for the lobby's side, 2xx for the match server's, with a title and a one-line description each, and an optional free-text detail (200 characters). The table is in contract section 11 and `src/lobby/shared/MatchErrors.luau`, and a spec keeps the two equal. sim-A moves it to `@shared/Match/MatchConfig` for both places.
- **Transport:** the match server sends 2xx in the return teleport data (`error`) and, for a match that failed as a whole, in the result's `error`. The lobby cleans both (listed codes only), shows a whole-match error once with the results, and the rest in a panel.
- **Delivery:** pending errors travel in the player's view (`errors`, three at most) until the player dismisses them (`dismissError`). A push sent at arrival could arrive before the client listens.
- **Alternatives:** toasts (gone in 5 s, no room for a code and a description); the room's notice alone (only for players in a room, and not per player).

## L-22 (2026-10-26): the Units showroom animates, fires and goes full screen

- **Decision:** the user's ideas for the Units tab: unique unit animations, a weapon preview against dummy targets, and a full-screen view.
- **Animation:** client-B's own piece scheduler and scripts (`Core/PieceAnim`, `Core/PieceScripts`, `Ambient`), not a lobby copy. Every animation the match has shows the same here, and new piece scripts come for free.
- **Weapon preview:** the showroom plays the match's effects (`Render/Effects` draws `Core/Effects` records), not the match's network path. `Effects.update` needs a world of replicated units and events, so the showroom makes the records itself: tracers and bursts as `Effects` makes them, projectiles stepped with `Shared/Combat/Ballistics` at the sim's 15 Hz.
  - **Distances:** targets stand at 15% of the weapon's range (22 to 40 studs), so the shot fits on screen. Shells keep the arc of 70% of the real range and fly slower.
  - **Not shown:** anti-missile and strategic weapons; nothing would show them faithfully at this scale.
- **Full view** hides the lobby's own panels and its top bar; the stage takes the page, so drags anywhere turn the camera.
- **Cost:** 25 more of client-B's modules are mounted read-only, the same rule as the kit: B keeps their APIs stable, and the lobby's build check fails when one changes its requires.
- **Alternatives:** running a small sim in the lobby (the whole sim on the client for a preview), or the lobby's own simple effects (looks that drift from the match).

## L-23 (2026-10-26): a loading screen on joining the lobby

- **Decision:** the user asked for the lobby to load its assets the way a match does. On joining, a full-screen loading screen in the match start's look (key art, a tip, the olive bar) stays until the lobby has cached what it draws. Weights follow the match's `Render/Preload`: connected 0.10, the map list 0.10, every approved unit mesh built 0.55 (`MeshModels.start` with all defs), textures 0.25 (`PreloadAsync` on MeshMaterials, the Vfx templates and the icon sheets). Then it fades out.
- **Why:** the showroom and the battle behind no longer pop in from blockouts to meshes, and Units opens instantly.
- **Escape hatch:** a mesh that fails counts as done. After 12 s a Continue button lets the player in without waiting (a slow asset download shouldn't keep anyone out).
- **Measured in Studio:** 138 meshes and the textures in about 25 s.

## L-24 (2026-10-26): the Units article's numbers in BAR's wiki look

- **Decision:** the user's reference (BAR's unit wiki). The unit's stats stay on top, the weapons below:
  - **Cost** and **General stats** are bar rows: an uppercase label, an icon cell and a dark bar filled to the value's share of the game's biggest (`Codex.maxima`), with the number in the middle. Cost has supply, power and build time. General stats has health, speed, sight, radar, DPS, range, build power, stockpile and ammo, each only when the unit has it.
  - **Details** keeps the rows that aren't amounts: value, build, armor, movement, other sensors, stealth, countermeasures, income, storage, size.
  - **Weapons** are cards: a coloured tile by kind, the name in capitals, the kind and a stock round's power cost. Then one row per figure: the number in red, what it is, and a word for how it reads (reload "slow", alpha "very heavy", aoe "large", range "very long": `Codex.word`). Last, a sentence on what it does and the damage per hit. The header folds the rows.
- **Bars on a square-root scale:** linear against the biggest value (the strategic structures) would leave most units' bars a sliver.
- **Icons are text glyphs** that Roblox's fallback fonts draw, checked in Studio; several, such as ✹ ➚ ↻ ◷ ⌖ ➤, show as empty boxes and are avoided. No image uploads needed.

## L-25 (2026-10-26): a room holds 16 people, AIs included; only authority changes it (G11)

- **Decision:** the user, from playtest 2. The create dialog's "Players and spectators" slider is gone, and every room holds `Config.DEFAULT_PLAYERS` = 16 people, AIs included (`Rooms.headcount`: members plus AI seats). Join, Add AI and the browser's "full" all count both. The skirmish room uses the same cap (it was 2, which an AI would now fill).
- **Authority:** only someone with authority sets another cap: the experience's owner (rank `Config.ADMIN_RANK` = 254 and up for a group's experience), the user IDs in `Config.ADMINS`, and anyone in Studio (`server/Authority`). The view's `me.authority` shows them the slider, and the server ignores a cap sent by anyone else.

## L-26 (2026-10-26): a map panel instead of the Map dropdown; no start markers (G12)

- **Decision:** the user, from playtest 2. The room's Map row opens a panel: the maps grouped small to large, a big preview, and an information column (size and cells, starts and how many teams, then wind, tides and terrain features from the map's `info` once sim-A's MapRegistry sends them). The host chooses there; everyone else can look.
- **No suggested landing points:** the room's map and the Skirmish preview drop the numbered start markers. Players pick their start in the match (S-171).

## L-27 (2026-10-29): the user's answers on cheats, forced start, spectators, key art, lobby size

- **Cheats:** agreed as built. The host may turn them on in any room; such matches are listed on the profile and don't count; the match server enforces the allow-list (C-119).
- **Forced start:** the host's force start goes straight to the countdown, and at the start whoever hasn't picked a spot gets the best free one. The match's pre-game already does exactly this (`Pregame`, S-174: START 1 is a 3 s countdown that un-readying can't cancel; `start` gives every unpicked player `Pregame.bestSpot`). The lobby's forced start skips only the room's ready check; the match's pick time still runs. The user confirmed this on 2026-10-30: the lobby's forced start doesn't skip the pick time.
- **Spectators:** they join and watch, nothing more for now. The match place gives them no seat and the full view (C-79).
- **Key art:** at random on each loading screen, never the one shown last time (`Overlays/Loading`); the joining screen already picks at random (`UI/KeyArt`).
- **Lobby max players (a place setting, the user's):** recommended 50, was 20. Rooms hold 16 people, AIs included (L-25), and a room on another lobby server is joined by moving to that server (L-15), which fails while it is full. At 20, one full room leaves room for 4 more players, so joining a busy room often fails. At 50 a server holds a few full rooms plus browsers. A lobby server's load is small: room logic and chat; the 3D background runs on each player's machine. 2 stays only for the playtest's Part A, so four testers spread over two servers.
