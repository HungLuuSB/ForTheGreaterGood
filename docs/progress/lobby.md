# Lobby progress

Progress of the lobby stream (session D): the lobby place "FTGG Lobby" (`src/lobby/**`, `lobby.project.json`, Rojo port 34874) and the lobby ↔ match contract (`docs/contracts/match.md`). Branch `m-lobby`, worktree `FTGG-lobby`. This stream never edits `src/client`, `src/server` or `src/shared`; it asks under "Requests" below. Decisions: `L-1`, `L-2`, ... in [`../decisions/lobby.md`](../decisions/lobby.md).

## Summary (2026-10-26: maps by size, F4)

- Merged sim-A's `592af90a` (S-189: maps bigger than 256 cells, `MapRegistry.sizeClass`, The Lakelands at 512 cells, protocol 38).
- **Size classes:** the server reads each map's class from its grid (small ≤ 256 cells a side, medium ≤ 512, large above) and sends it, with the cell count, in the map list, smallest first.
- **Skirmish** groups its cards under "Small maps" and "Medium maps" (and "Large maps" once there are any), each card tagged with its size.
- **The room's Map dropdown** lists them in that order with the size in each label ("The Lakelands (4) · Medium").
- New Rooms spec: the pickers' sizes are MapRegistry's classes, smallest first.
- **Studio:** the Skirmish groups and The Lakelands' details, 512 × 512 cells and 4 starts (`lobby_skirmish_sizes`); a room on The Lakelands (`lobby_room_lakelands`). The lobby's map loop now takes a few seconds longer (The Lakelands loads in 3 to 4 s).
- Lobby specs 65 / 65; the build check passes.

## Summary (2026-10-26: anti-air with the game's missiles)

- **The user:** anti-air missiles must use the game's missile system (vertical launch), and the target must be far away so the missile shows in action.
- **Missiles fly the game's guidance** (`Shared/Combat/Guidance`, as the server's Projectiles):
  - **Vertical launchers** (radar SAMs, missile batteries) fire straight up, climb their `climbHeight`, pitch over (`Guidance.vertical`), then navigate by proportional navigation. Their turret stays at rest (S-42).
  - **Other missiles** leave along the launcher's aim and navigate (`Guidance.pn`), against the drone's real velocity.
  - **Hits** are judged on each tick's path: a 9-stud fuse for the drone.
- **The drone** flies far out, a fifth of the weapon's range (70 to 220 studs), 25 to 60 studs up, making passes across the view. It is three times bigger, with a blinking red beacon. The haze thins while the range is up.
- **The camera** frames a box round the unit, its targets and the top of the climb (1.8 × climbHeight, which the pitch-over overshoots).
- Fire now stays on across page changes, as the switch shows.
- **Studio:** Seraph: the missile climbs to about 190 studs over the launcher, pitches over and bursts on the drone 230 studs out (`lobby_range_seraph_pitchover`, `lobby_range_seraph_intercept`). Halo: the IR missile flies straight out to the drone 80 studs away.
- Lobby specs 64 / 64; the build check passes.
- Ready to merge: `8bb573b7` (anti-air with the game's missile guidance, far drone; touches only `src/lobby` and the lobby progress)

## Summary (2026-10-26: the Units showroom comes alive, L-22)

The user's three ideas for the Units tab:
- **Unit animations.** The match's piece scheduler (`Core/PieceAnim`) runs each shown unit's own piece script and the ambient pieces (`Ambient`), as if powered and producing. Radars and dishes sweep, rotors and drills turn, gantries run, aircraft fly, deployable units are deployed. Joints move through `Motor6D.Transform` as in a match; models keep their template's anchoring (the base) instead of every part.
- **Weapon preview: Fire.** A switch at the end of the place row.
  - **Targets**, one per kind the weapons take: a board on the ground (a barge on water), a drone circling for anti-air, a hulk under the water for anti-submarine weapons. They stand closer than the real range (15% of it, 22 to 40 studs); the camera frames the unit and its targets. Each target flashes on a hit.
  - **Firing:** each weapon aims (its piece script turns the turret and barrel) and fires at its reload (at most 4 s), salvos included. The shots are the match's own effect records (`Core/Effects`: shells, missiles, tracers, beams, lasers, bursts), drawn by `Render/Effects`.
  - **Shots:** shells keep their real arc shape (the pitch at 70% of the weapon's range, launched slower to land on the nearer target), missiles steer at their turn rate, bombs fall, torpedoes run at depth.
  - **Not shown:** anti-missile and strategic weapons. The switch reads "Fire (no weapon)" then; `Codex.rangeTarget` decides, and a Codex spec checks every weapon.
- **Full view:** a button (or H) hides the list, the article, the toolbar and the top bar; the unit fills the screen, and "Show panels (H)" or H brings them back.
- **Read-only client modules added to `lobby.project.json`:** 25 of client-B's: Core Deaths, Effects, GroundMeshes, Interp, Nanoframe, PieceAnim, PieceMotion, Terrain, World and PieceScripts; Render BeamShots, Crater, Effects, Ground, Lasers, MeshGround, Terrain and Vfx. The build check fails if their requires change.
- **Studio** (`debug_out/screens/`):
  - `lobby_anim_watchtower`: the radar sweeps, about 60° a second.
  - `lobby_range_paladin_hit`: the shell bursts on the board.
  - `lobby_range_halo_drone`: the missile hits the drone.
  - `lobby_range_radiance_beam`, `lobby_range_bulwark`: beam and laser.
  - `lobby_range_sub_target`: the torpedo runs at depth into the hulk.
  - Bombs from the Absolution land on the board 145 studs below.
  - `lobby_units_full_view`: H brings the panels back.
  - No errors.
- Lobby specs 64 / 64; the build check passes (564 scripts, 938 requires).
- Ready to merge: `dbf1c000` (Units showroom animations, firing range, full view; `lobby.project.json` mounts 25 more client modules read-only; touches only `src/lobby`, `lobby.project.json` and the lobby docs)

## Summary (2026-10-26: four AI levels and team roles, F41)

- Merged sim-A's `8713c298` (S-187): `LEVELS` = easy, normal, hard, hard_aggressive. Names: Easy, Normal, **Hard - Balanced** (the id stays `hard`), **Hard - Aggressive**.
- **Pickers** (the room's AI editor, Skirmish) show the four as Easy · Normal · Hard · Bal. · Hard · Agg., to fit four in a row; seat chips and everything else use the full names. In the match an AI is named "AI 1 (hard aggressive)".
- **Role badges:** two or more non-easy AIs on one side split the work. The AI chips show each one's role (Balanced, Air, Defense, Spam, Tech) with the sim's rule (`MatchConfig.aiRoles`; `AiLevels.spec` checks it against `Skirmish.roleOf` on the same match and keeps `Config.AI_ROLES` equal to `Skirmish.ROLES`).
- Studio (`debug_out/screens/`): `lobby_room_ai_roles` (team 2: Balanced, Air, Defense, the easy AI without a badge), `lobby_room_ai_levels` (the AI editor), `lobby_skirmish_ai_levels`.
- Lobby specs 63 / 63; the build check passes.
- Ready to merge: `51243401` (four AI levels and role badges; includes the merge of sim-A's `8713c298`; touches only `src/lobby` and the lobby progress)

## Summary (2026-10-26: The Plains' side splits, S-186)

- Merged sim-A's `9583455e`: maps may carry `layers.sideSplits`, and `StartAreas.sides` takes it as a third argument.
- The room's default spawn boxes pass the map's splits. The server sends them with the map's shape as a list (`SpawnBoxes.splitList`: a table keyed by side counts has gaps, which a remote can drop), and `SpawnBoxes.defaults` rebuilds them.
- With 3 sides on The Plains: side 1 is the west strip, sides 2 and 3 the two eastern corners. No box spans the map's middle any more (`lobby_room_plains_3_sides`).
- Ready to merge: `b18634b3` (default boxes follow the map's side splits; includes the merge of sim-A's `9583455e`; touches only `src/lobby` and the lobby progress)
- New spec: The Plains' 3-side defaults keep side 1 west and sides 2 and 3 east, apart. Lobby specs 61 / 61; the build check passes.

## Summary (2026-10-26: tracks on the ground; the Underwater place)

- **Tracks clipping into the ground (the user):** units stood at the place's level, under thin floor dressing on top of it:
  - **The menu's battle:** the sand band, 0.15 studs. Units now stand on its top (`FIELD_TOP`).
  - **The Units showroom:** the pad's disc and marks (0.11) and the field's dirt patch (0.12). Models now stand on each place's `FLOOR`.
  - **Measured in Studio:** every unit's lowest point is exactly on the surface, sinking into nothing (`lobby_units_field_tank`).
- **Submarines and amphibious units underwater (the user):** a new **Underwater** place in the showroom.
  - Deep water over a sandy seabed with rocks and weed.
  - Submarines float mid-water, amphibious units drive on the seabed, and ships show their hulls from below.
  - The camera stays under the surface and may look up at it. "Auto" picks it for submarines and amphibious units; Shore is still available.
  - A cool sea tint while underwater; leaving restores the menu's light.
  - Water transparency 0.05 (the user's value), set by the showroom's water.
  - Studio: `lobby_units_underwater_sub` (Silence), `lobby_units_underwater_amphib` (Tideguard).
- Lobby specs 60 / 60; the build check passes.
- Ready to merge: `782092e` (tracks on the ground, the Underwater showroom place; touches only `src/lobby` and the lobby docs)

## Summary (2026-10-26: Codex roles for the bots, S-181)

- Merged sim-A's `2b3ca0e` (the bot roster). Codex roles for the 19 new units:
  - **Command and workers:** Bot constructor (Artisan / Tinker); Field engineer for repair, resurrect and reclaim (Lazarus / Graverobber).
  - **Ground, bots:** Scout bot (Glint / Skitter); Light combat bot (Mace / Thug); AA bot (Kestrel / Needle); Heavy plasma (Fatboy / Tzar, the tank counterpart); Heavy laser bot (Chaos: Centurion).
  - **Air:** Heavy bomber (Order: Liche); Flying fortress (Chaos: Dragon).
  - **Factories:** Bot lab (Bot Lab / Bot Pit); Advanced bot lab.
- Lobby specs 60 / 60 (the Codex spec lists every buildable unit's role); the build check passes. Studio: Fatboy's article with Tzar as its counterpart and the comparison (`lobby_units_fatboy`).
- Ready to merge: `f8e3cbb` (Codex roles for the bots; includes the merge of sim-A's `2b3ca0e`; touches only `src/lobby` and the lobby progress)
- **Not the lobby's:** the bots have no list icons (B) and no models yet (C), so the showroom shows the placeholder box.

## Summary (2026-10-26: the shared error list)

- Merged sim-A's `ed06b01`: `MatchConfig.ERRORS`, `ERROR_DETAIL_MAX` and `cleanError`, and `validateResult` accepting `error`. It also brings the new unit defs; the Codex spec still passes.
- `MatchErrors` now reads the shared list and cleaning, and keeps only the lobby's teleport mapping and one-line form. The contract's note says where the table lives; `MatchErrors.spec` compares the contract with the shared table.
- B's match side (`2b1fde9`) sends the 2xx codes in the return teleport data and the result's `error`. 206 has no path yet, and a player with no readable config is still kicked, with the code in the kick message.
- Lobby specs 60 / 60; the build check passes; Studio: a staged reserve failure shows Error 103 from the shared table.
- Ready to merge: `10f7b77` (the lobby reads `MatchConfig.ERRORS`; includes the merge of sim-A's `ed06b01`; touches only `src/lobby`, the lobby docs and `docs/contracts/match.md`)
- **Next (F41):** four AI levels in the pickers once sim-A sends the level IDs.

## Summary (2026-10-26: match errors with codes, F38)

- **The user's rule:** "any failed attempt to connect to the game match must be displayed on the lobby when return with error code + description". One numbered list (`MatchErrors`, contract section 11, L-21):
  - **1xx, the lobby's side:** no match place, a bad setup, no server, the match store, room changed, nobody to send, teleport failures by TeleportResult, the match server going silent (120), rejoin with the match gone.
  - **2xx, the match server's side:** no or bad setup, version mismatches, not listed, full, already over, players didn't arrive, everyone left, a server error, unnamed.
- **Shown:** a panel the player dismisses: "Couldn't reach the match", the code, title, description and detail.
  - **Start failures:** every room member present gets it, and the room's notice carries the code.
  - **A player's own failed teleport:** after the retries, for that player.
  - **Rejoin:** its errors too.
  - **A player sent back with `error` in the teleport data:** shown on arrival.
  - **A match that failed as a whole:** the result's `error` shows in the results panel instead, once.
  - Errors wait in the player's view until dismissed, so one raised during arrival isn't lost.
- **Studio:** the stand-in match refuses with codes (201, 202, 203, 205), and `StandInFail = "match:<code>"` stages any 2xx. Checked (`debug_out/screens/`): `lobby_error_103_start` (reserve failed), `lobby_error_206_sent_back`, `lobby_error_120_results` (the lobby's heartbeat timeout), `lobby_error_209_results` (shown once, with the results), `lobby_error_114_teleport` (a player's teleport, after the retries).
- **Specs** (`MatchErrors.spec`, 5 tests): the list, the contract's table equal to the code's, cleaning, the teleport mapping, results carrying the error. Lobby specs 60 / 60; the build check passes.
- Ready to merge: `a8eb423` (match errors with codes, F38; touches only `src/lobby`, the lobby docs and `docs/contracts/match.md`)
- **For B and sim-A:** the match place reports 2xx in the return teleport data and the result's `error`; sim-A moves the list to `MatchConfig.ERRORS`, then the lobby reads it from there.

## Summary (2026-10-26: the host back from a match)

- **The user's bug:** after a match, the host came back to a lobby and couldn't control the room, so they made a new one. Two causes, both fixed:
  1. **A room rebuilt on another lobby server** (the room's server had closed, for example when everyone left it for the match) went to whoever was back first. `Rooms.fromMatch` (moved out of `Directory.recreate`) now gives it to the config's `host` (v2) when they're a member; without one (v1), still the first back.
  2. **A host removed after the grace** (not back within `AWAY_GRACE` of the result) was attached to the room on return without being a member, so every request failed with "You're not in this room". `Rooms.welcomeBack` makes them a member again (a spectator; their seat went) and gives the match's host the room back.
- **Spec:** back from a match as host, on a rebuilt room (the other player back first) and on the same server after the grace. Host rights, setup, a host-only setting, and Start's check pass again; a v1 config without `host` still goes to the first one back.
- **Studio** (same server): Lobby → stand-in match → back as host; changing the win rule and the real Start button worked, and a second match launched (`lobby_host_back_from_match`).
- **By design, not changed:** a host back early while others still play sees the room "In match" (Rejoin) until that match ends.
- Lobby specs 55 / 55; the build check passes.
- Ready to merge: `0ed1299` (the host keeps the room after a match; touches only `src/lobby` and the lobby progress)

## Summary (2026-10-26: beta feedback F25, F31, F32, F35)

From the user's playtest feedback (`FTGG-FEEDBACK.txt`; sim-A's plan in `docs/progress/playtest-2026-10-26.md`):
- **F25 (an AI added to team 7 landed on team 2):** a new AI always sat on team 1 or 2, and the room moved it with a second request 0.3 s later, aimed at "the last seat"; if the view hadn't arrived, that moved a different AI or none. `addAi` and `play` now take the team in the same request (checked against the map's sides). Specs: back-to-back requests to teams 7, 2, 7, 8; team 9 and team 5 on a four-start map refused; a spectator joins team 3 in one request. Studio: five requests sent back to back and two quick clicks on Team 3's Add AI all land on their teams (`lobby_room_ai_teams_f25`).
- **F31 (the 16-player crash):** the match place numbered teams by faction parity (B fixes it). The room already seats 16 in any mix; a new spec builds 16 seats, 9 Chaos and 7 Order, 8 against 8 and free for all on The Plains, and checks the start rules and the shared config check.
- **F32:** the config carries `host` (the room host's UserId), seated or not. Contract row added.
- **F35:** your seat editor says the faction is a first choice that can change in the match (`lobby_room_faction_note_f35`).
- **Tests:** lobby specs 50 / 50; the build check passes.
- Ready to merge: `7e667f4` (F25 AI team in one request, F31 spec, F32 `host` in the config, F35 faction note; touches only `src/lobby`, the lobby docs and `docs/contracts/match.md`)
- **F26: spawn boxes edited by the host.** In Teams, the room's map shows every team's box in its colour as you see it. The defaults are the match's own: `StartAreas.boxes` for the room's sides, from each map's bounds, start hints and boxes, which the server now sends with the previews. The host drags a side to resize or the inside to move; sides within 3% of the map's edge snap to it, the smallest box is 4% of the map, and the box is sent when the drag ends. "Reset boxes" (beside the map, host only, once a box was edited) brings back the defaults. A new map or mode resets them too. The config's `startBoxes` carries every side's box by ally team once one was edited, and is omitted otherwise (`SpawnBoxes`, L-20).
  - **Specs** (`SpawnBoxes.spec`, 4 tests): cleaning and snapping; the defaults equal `StartAreas` on The Plains for 2 to 8 sides; only the host edits, Teams only, seated teams only, resets on map and mode changes; the config's boxes by ally team, an emptied team's edit left out.
  - **Studio** (`debug_out/screens/`): `lobby_room_spawn_boxes` (three teams' defaults), `lobby_room_spawn_boxes_dragged` (team 1's east side dragged, its west side snapped; team 3 moved down and snapped to the corner), `lobby_room_spawn_boxes_reset_button`, `lobby_room_spawn_boxes_after_reset`. A forced start with edited boxes passed the shared check and launched.
  - **Note for sim-A:** with 3 sides on The Plains, side 2 gets starts 6-10, which lie in two corners. Its default box spans the map's middle column (`lobby_room_spawn_boxes`).
- **Contract v2:** merged sim-A's `72fb087` (CONFIG_VERSION 2, `host`, `startBoxes`). The lobby specs follow the shared version and check that v2 refuses a host outside the match and boxes for a missing side. A forced start with an edited box passed the check in Studio. Lobby specs 54 / 54; the build check passes.
- Ready to merge: `99c27ae` (F26 spawn boxes, `9a57381`, plus the merge of sim-A's `72fb087` and the v2 specs; must land with `72fb087`; touches only `src/lobby`, the lobby docs and `docs/contracts/match.md`)

## Summary (2026-10-26: automatic colours, S-172)

- **sim-A's request:** after the beta publish, the room still had the colour picker. Players' colours are now automatic in the lobby too:
  - **Room:** the seat editor's colour grid is gone. Every seat's swatch (seat chips, the "You" row) comes from `TeamColors.forViewer` from your seat: you Blue, your allies cold, enemies warm; spectators see the lowest ally team as the cold side.
  - **Same IDs as the match:** `MatchConfig.seats(room)` is the config's player order (each seat's player ID and ally team), split out of `MatchConfig.build`. `MatchConfig.colors(room, viewer)` calls `forViewer` with those IDs and the viewer's own ID (0 for a spectator), as sim-A asked and as B does in the match.
  - **Results panel:** colours from your view, using the players' place in the list as their ID.
  - **Contract:** `color` is still sent: a unique palette index, validated, unused. Still version 1.
  - **The Plains** was already in the map picker (the server lists every hand-made map: "The Plains (16)").
- **Checked:** lobby specs 48 / 48 (one new: seat colours from each viewer, the same as `forViewer` on the built config); the lobby build check passes. In Studio on the published lobby place ("FTGG Testplace"), a Teams room on The Plains (`debug_out/screens/`):
  - `lobby_room_auto_colours`: you Blue, your AI ally Cyan; team 2 Red, Orange, Fuchsia; team 3 Yellow;
  - `lobby_room_seat_no_picker`, `lobby_room_ai_no_picker`: the seat editors without the colour grid, shorter to fit;
  - `lobby_room_spectator_colours`: as a spectator, team 1 Blue, team 2 Red and Orange.
- Smart App Control blocked `lune.exe` and `rojo.exe` on the morning of 2026-10-26 (unsigned); the user turned it off.
- Ready to merge: `192cab0` (automatic player colours in the room and results from your view, S-172; no colour picker; `MatchConfig.seats` / `MatchConfig.colors`; L-19; touches only `src/lobby`, the lobby docs and `docs/contracts/match.md` (the `color` row: still sent, unused); still version 1)

## Summary (2026-10-24, the beta merge: new start rules and limits)

- **sim-A's beta merge failed 3 lobby specs** after S-169 / S-171 raised the shared limits. Fixed on `m-lobby` with sim-A's `c06d3ca` merged in:
  - **Room rules:** Teams 2 up to min(8, the map's starts) sides of any size, at most 16 players; free for all one player per start, up to 16. The map's starts cap the sides, not the players: 4 against 4 on a two-start map is allowed.
  - **Config:** every player's `start` is `0` (picked in the match's pre-game, S-171).
  - **Room UI:** the seat editor lists only the teams the map allows, and its colour grid has a third row for the 16 colours. The room's map markers no longer take player colours, since starts are hints.
  - **Contract:** `docs/contracts/match.md` updated (start 0, the limits); still version 1.
- **Checked in Studio:** The Plains (16 starts) is in the map list; a 4-against-4 Teams room on it, the seat editor with 8 teams and 16 colours (`lobby_room_plains_seat.jpg`), and a forced start whose config passed the shared check and launched.
- **Not done yet (after the beta):** the automatic colours in the room (`TeamColors.forViewer`) and removing the colour picker (done 2026-10-26, above); The Plains' skirmish note.
- **Tests:** lobby specs 47 / 47; the lobby build check passes.
- Ready to merge: `63ca504` (rooms to the new limits, start 0 for every player, seat editor for 8 teams and 16 colours, specs and contract; includes sim-A's `c06d3ca`; touches only `src/lobby`, the lobby docs and `docs/contracts/match.md`)

## Summary (2026-10-24, Settings on client-B's components; publishing)

- **The Settings page uses client-B's settings body** (`Kit.options`, C-202): search, section tree, amber sub-section headers, hover help, children dimmed under a switched-off parent. Interface (scale; a pointer to the match's Settings) and Background (battle scene, camera follows the mouse). Still saved on the profile (L-16). Checked in Studio (`lobby_settings_options.jpg`, `lobby_settings_background.jpg`).
- **Main merged** (`f508bfa`, main `1536c94`). The kit now needs client-B's `Core/OptionTree`, mounted read-only like the rest. Four new defs got roles in the Units tab: naval SAM platform (Pharos / Scylla), advanced rearm pad (Empyrean / Rookery).
- **Found while publishing: EditableImage must be allowed** for the experience (Game Settings → Security). Without it a published place lets EditableImage be created but refuses the write: client-B's `Kit.panel` then stops the whole lobby client, and the map previews stay empty. You enabled it for FTGG Playtest; it's in the beta guide (step 5) now. The lobby's map previews now fall back to the map's name; I asked client-B to guard the kit the same way (B-8).
- **Top bar:** the tabs are narrower, so "Settings" no longer runs into the player count on a 1548-pixel-wide window (`lobby_topbar_skirmish.jpg`). The room under client-B's new look: `lobby_room_newkit.jpg`.
- **Published so far (by you):** the lobby is the start place of experience 10772730291 (place 109045403486391, "FTGG Testplace"), with "FTGG Match" (123800718230540) added. The lobby there was published before this summary's changes and before the Units tab's latest fixes: publish it again once the match place is in.
- **Tests:** lobby specs 47 / 47; the lobby build check passes.
- Ready to merge: `d1c6758` (rooms across lobby servers, invites, lobby settings on the profile, the match place from one setting, the reference UI changes, the Units tab, the Settings page on `Kit.options`, the playtest checklist; L-14..L-18; touches only `src/lobby`, `lobby.project.json`, the lobby docs and `docs/contracts/match.md` (lobby-only keys and the place setting; the match server's side unchanged, still version 1); includes merges of main up to `1536c94`)

## Summary (2026-10-24, the Units tab)

- **A unit encyclopedia, the new "Units" tab (L-18):**
  - **List:** both factions' units and structures by role, with icons, search, and Units / Structures and tier filters.
  - **Showroom:** a 3D showroom of the real models on Pad, Field, Water, Shore or Sky ("Auto" picks by the unit), with turntable, Day/Dusk, colours, and Compare (counterparts side by side).
  - **Article:** description, counterpart with the differences, in-game values, weapons, and what it builds and what builds it.
- **Data:** `src/lobby/shared/Codex.luau` (roles after guide section 13; retired defs hidden); `Codex.spec` checks it against the real defs.
- **Checked in Studio** ("FTGG Lobby", after Rojo was restarted for the new mounts):
  - every place: Paladin on the pad, Dominion on the water, Tideguard on the shore, Falcon in the sky, Bastion on the field;
  - Compare with one counterpart (Paladin vs Juggernaut) and with two (Overwatch vs Twin Guard and Geryon);
  - Day light, a colour swatch, the weapons and "Built by" sections;
  - leaving the tab brings the battle and its dusk light back.
- **Fixed in Studio:** infobox rows that grew without end and then didn't wrap (now sized from the wrapped text); the build line's wording; the hint off the stage; aircraft centred; wider framing; the pad's lamps out of the camera's way.
- **Screenshots** (`debug_out/screens/`): `lobby_units_pad`, `lobby_units_compare`, `lobby_units_day_colour`, `lobby_units_field_compare`, `lobby_units_article_weapons`, `lobby_home_after_units`. The place shots `lobby_units_water`, `lobby_units_sky`, `lobby_units_shore` and `lobby_units_field` are from before the text fixes.
- **Tests:** `lune run src/lobby/tools/test`: 47 tests in 6 specs pass; the lobby build check passes.

## Summary (2026-10-24, live playtest prep, rooms across servers, invites, saved settings)

- **The lobby is ready to publish** for the "FTGG Playtest" experience: specs and build pass, and everything below was checked in Studio ("FTGG Lobby", stand-ins). The click-by-click checklist and the 30-minute test plan are under "Live playtest" below. I haven't published anything.
- **One place setting (L-14):** `MATCH_PLACE_ID` in `src/lobby/shared/Config.luau` replaces the hard-coded 89435699207932. It is `0`, which means the lobby finds the match place when a server starts: the experience's other place. So publishing needs no code change. The lobby's own place ID isn't configured anywhere (`game.PlaceId`).
- **Rooms across lobby servers (L-15):** each lobby server lists its rooms in a shared MemoryStore list. The browser shows the other servers' rooms tagged "[other server]", says "N rooms on M lobby servers", and the top bar counts players on every server. Joining one (click or code) moves you to that server behind the loading screen ("Moving to the room's lobby server...") and into the room. A full server gives a toast. Studio has a stand-in second server with four rooms (codes PEERT, PEERL with password "peer", PEERP private, PEERM in a match).
- **Lobby settings saved on the profile (L-16):** UI scale, background scene and parallax follow you to any server.
- **Invite a friend (L-17):** "Invite" in the room opens Roblox's invite prompt. The invite carries the room code, and a friend who joins through it lands in the room (on any lobby server; a password room asks for the password).
- **Closer to your references 1-2:**
  - the room's settings are BAR rows: a darker label cell joined to a value cell, with a chevron on choices;
  - Friendly fire and Cheats are real switches (square knob, green on, red off), shown read-only to guests;
  - Skirmish map cards are greyscale, in colour when hovered or chosen;
  - the room header says "In match · running for N min" while a match runs (the browser too);
  - the map preview fills the room's right column above the rules (much bigger at 1080p; in Studio's short viewport the rows were made more compact to give it room).
- **B's kit:** the lobby now uses `Kit.button`'s go / stop fills and `Kit.input` (C-174). B's new Settings components aren't on main yet: I'll switch the Settings page when B says they are.
- **Key art:** the loading screen takes the next approved art each time. Art 3 "Converging" and art 2 "Volley" both show (screenshots below). Art 1 "Commander's stand" shows by itself once models-C lists it in the manifest.
- **Fixed on the way:**
  - the seat editor's colour grid sat outside its dialog;
  - a room drawn before the map list arrived kept "Loading map...";
  - "Leave early" (Studio stand-in) was hard to read over bright key art;
  - views stopped entirely if the room list published before the server was ready (found in Studio, fixed before anything shipped).
- **Screenshots** (`debug_out/screens/`):
  - `lobby_browser_servers.jpg`: rooms from two lobby servers;
  - `lobby_room_after_hop.jpg`: a room joined on the other server;
  - `lobby_invite_arrival.jpg`: an invite's launch data landing in a private room;
  - `lobby_room_host.jpg`, `lobby_room_dropdown.jpg`, `lobby_room_toggle.jpg`: host rows, an open list, a switch flipped off;
  - `lobby_room_in_match.jpg`: the "running for" header;
  - `lobby_skirmish_grey.jpg`, `lobby_seat_editor.jpg`, `lobby_settings.jpg`;
  - `lobby_loading_converging.jpg`, `lobby_loading_volley.jpg`.
- **Tests:** `lune run src/lobby/tools/test`: 41 tests in 5 specs pass (new: `Listing.spec` with 7, settings in `Profile.spec`). The lobby build check passes.

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

## Beta: publishing both places (guide for you)

**The experience** (created 2026-10-24, owned by your account): id 10772730291.
- Start place: the lobby, Studio window "FTGG Testplace", place 109045403486391.
- Second place: "FTGG Match", place 123800718230540.

Both places exist; steps 1–4 bring them up to date, step 5 checks the settings, steps 6–7 prove it works before your friends join.

### 1. Wait for the green light

1. sim-A finishes the merge chain into `main`: my lobby (`c64caa7`), sim-A's start rules (`458b2d0`), and client-B's and models-C's queued work. sim-A sends you the final `main` commit.
2. I merge that `main` into `m-lobby`, run the lobby specs, check the lobby in Studio, and tell you "lobby ready to publish". The lobby carries its own copy of the shared code (defs, maps, the config check), so it must hold the same `main` as the match place.
3. client-B (or sim-A) tells you the match game is synced to that same commit (step 3).

### 2. Publish the lobby

1. In Studio, open the lobby: the window "FTGG Testplace" (File → Open from Roblox → FTGG Playtest, if it's closed).
2. Live sync running: in two terminals in `C:\Workspace\Projects\FTGG-lobby`:
   - `lune run src/lobby/tools/sync serve`
   - `rojo serve lobby.project.json` (port 34874)
3. Rojo plugin in that window: port **34874** → **Connect**. Tell me, and I check that the synced code is the right version.
4. No playtest running (Stop).
5. **File → Publish to Roblox** (the window is already linked to place 109045403486391, so not "Publish As").

### 3. Sync the match game to the same `main`

The match place is the main game's place file (its maps, terrain and models live in the file) with `main`'s code synced in.

- **Easiest:** ask client-B: "sync the match game window to main `<commit>` for the beta publish". B runs its usual sync and tells you when Studio shows that commit.
- **If B isn't around,** ask sim-A to do the same from the integration worktree (`FTGG-integration`, on `main`). Don't run git or the sync there yourself: sim-A merges in that worktree, and a sync running during a merge would break it.
- **Check before publishing:** the Rojo plugin in the match game's window says connected, and the window's Output shows no red errors after a quick Play / Stop.

### 4. Publish the match place

1. In the match game's window: **File → Save to File As…** "FTGG Match beta.rbxl". Studio continues in this copy, so your dev place 89435699207932 stays linked to the old experience.
2. **File → Publish to Roblox As…** → experience **FTGG Playtest** → place **FTGG Match** → **Overwrite**.
3. Next time (a later fix): open "FTGG Match beta.rbxl", sync, **File → Publish to Roblox**.

### 5. Settings (Studio, File → Game Settings, in either place's window; Save)

1. **Places** tab:
   - **⋯** on FTGG Match → **Configure Place** → Max players **16**.
   - **⋯** on FTGG Testplace → **Configure Place** → Max players **20**. Use **2** only for Part A of the test plan below (two lobby servers with four testers); a plain friends' playtest can stay at 20.
2. **Permissions** tab: Playability **Private**. Collaborators: add each friend's Roblox username with **Play**. You stay the owner.
3. **Security** tab: EditableImage allowed (done 2026-10-24; without it the menus can't draw).
4. If Roblox asks for the maturity questionnaire, fill it in.
5. Creator Dashboard (create.roblox.com → Creations → FTGG Playtest → Places): FTGG Testplace is the start place, FTGG Match is the second.

### 6. Fresh servers

Servers started before a publish keep the old code. Before anyone joins: Creator Dashboard → FTGG Playtest → **⋯** → **Shut down all servers** (or "Restart servers for updates").

### 7. Smoke test alone (5 minutes, before your friends)

1. Join from the Roblox app or website (Play on FTGG Playtest), not from Studio.
2. The lobby loads: the battle behind the menu, "1 player online", no "STUDIO STAND-INS" tag.
3. **F9 → Server**, filter `[Lobby]`. Look for `match place 123800718230540 (the experience's other place "FTGG Match")`, then `room list: memorystore`.
4. Home → **Quick play**. The loading screen with key art, then the match place. The match plays: the pre-game where you pick your start, then the match against the AI.
5. Finish it (or leave the match and rejoin the experience). You come back to the lobby, in your room with the results, and the match is on your Profile.
6. If any step fails: screenshot F9 (Server and Client tabs) and send it to me; don't invite anyone yet.

### 8. The 30-minute test plan (4 testers)

**Reading the logs:** in the game press **F9 → Server**, type `[Lobby]` (in the match: `[Match]`) in the filter. Only A sees the Server tab.

**Part A: two lobby servers (0-9 min, lobby max players 2)**

| Time | Who does what | Watch |
|---|---|---|
| 0-2 | **A1.** Join in this order: A, B (wait until B is in), C, D. | A and B share one lobby server (S1), C and D another (S2). Top bar: "4 players online" for everyone. A's log: `match place <id> (the experience's other place "FTGG Match")`, `room list: memorystore`. |
| 2-4 | **A2.** A: Multiplayer → Create room "Cross A", public. C and D open Multiplayer. C clicks "Cross A". | Within ~15 s C and D see "Cross A [other server]" and "1 room on 2 lobby servers". C's move fails because S1 is full: a short loading screen, then the toast "Couldn't move you to Cross A's lobby server (...)". C stays usable on S2. |
| 4-6 | **A3.** B closes Roblox. C clicks "Cross A" again. | Loading screen "Moving to the room's lobby server...", then C is in Cross A with A. A's log: `C joined room XXXXX from server ...`. |
| 6-8 | **A4.** D (alone on S2) creates a **private** room "Cross D" and reads its code aloud. A: Leave, type the code in "Room code", **Join by code**. | The private room never shows in anyone's browser. A moves to S2 and lands in Cross D. |
| 8-9 | **A5.** A sets FTGG Testplace's Max players to **20** (step 5.1). Everyone closes Roblox. | Empty servers close; the next ones are 20-player servers. |

**Part B: matches (9-28 min, lobby 20, match 16)**

| Time | Who does what | Watch |
|---|---|---|
| 9-12 | **B1.** A joins and creates public room "Playtest": Teams, Twin Lakes. A clicks **Invite** and invites D (D is not in the game). B and C join the experience and click "Playtest". D accepts the invite. Everyone types one line in room chat. B opens Settings: Interface scale 1.10, "Camera follows the mouse" off. | D lands straight in Playtest (A's log: `D came from an invite to room XXXXX`). The browser says "this lobby server". Everyone sees all four chat lines. |
| 12-18 | **B2. Match 1.** A and B on Team 1; C on Team 2, A adds a Normal AI to Team 2. D clicks **Leave** and stays in the lobby (keeps this lobby server alive). A turns **Cheats on**. Everyone Ready, A Start. At ~2 min C closes Roblox, rejoins the experience, clicks **Rejoin match**. A ends the match with the cheat command line (destroy Team 2's Commander), or you play it out. | Key art loading screen, then A, B and C arrive in the match together. D's browser: "Playtest · In match · N min". C lands back in the room with "Rejoin match" and returns to the same seat. After the results' "Return to lobby", A, B and C are back on D's lobby server, in Playtest with the results. Profile: the match listed as cheats (not counted). |
| 18-26 | **B3. Match 2, abandoned.** D joins Playtest. Cheats off. A+B against C+D. Start. After ~1 min **all four close Roblox**. Wait a minute, then all rejoin the experience. | All four arrive in the match. On return everyone is in Playtest on a new lobby server (A's log: `room XXXXX rebuilt for match ...`). The room shows "In match" until about 2-3 min after the match server stopped, then results "abandoned"; the profile counts it as abandoned. |
| 26-28 | **B4.** B opens Settings; everyone opens Profile. | B's scale 1.10 and parallax off came back on the new server. Both matches in everyone's history. |

Not stageable on purpose: one player's teleport refused by Roblox (contract 10.4) and DataStore budget pressure (10.7). Note it if either happens.

### 9. What to send me afterwards

- **Server logs:** screenshots of A's F9 → Server, filtered `[Lobby]`, after A3, A4, B1, B2 (the return) and B3 (the rebuild and "abandoned"); and filtered `[Match]` on the match server at each start.
- **Room state:** screenshots of the Playtest room after each match (the results panel and the room behind it), and of C's and D's browser during A2.
- **Anything odd:** the toast text, who saw it, and the clock time, so I can find it in the logs.
- **Profiles (optional):** Creator Dashboard → FTGG Playtest → Data Stores → `FtggProfiles`, key `p/<B's user ID>`: a screenshot of its `settings` and `history`.

## Needs my review

1. **Done (2026-10-24): rooms across lobby servers** (L-15). Needs the live test (Part A above).
2. **Guide 16.3 says "map vote".** Your design has the host pick the map (BAR). I followed your design; the guide is the sim stream's file, so I asked sim-A to update it (request A-3).
3. **Cheats:** the host can turn them on in any room. Matches with cheats are listed on the profile but don't count. The match server still enforces the allow-list (C-119). OK?
4. **Forced start** skips only the ready check; every other rule holds.
5. **Spectators** are members without a seat (when the map's starts are full, or by choice). They're in the config and may watch the match; client-B needs to support it (request B-1).
6. **Start positions:** the lobby orders players so the sim's player ID is the start index (Teams: ally teams together). So sim request 64 (chosen starts) isn't needed for version 1. BAR's start boxes or chosen starts could come later.
7. **Players beyond 16:** the room cap is 16 humans (players and spectators); FFA seats up to 8, Teams 4 × 4.
8. **Done (2026-10-24): lobby settings saved on the profile** (L-16).
12. **Key art order:** I read "show key arts 1 and 3" as: every approved art comes round, one per loading screen in turn (2 "Volley" included). Say if the lobby should show only 1 and 3 and leave Volley to the match's loading screen.
13. **Lobby max players:** 2 for Part A of the playtest only, so four testers fill two lobby servers; 20 afterwards.
9. **Done (2026-10-23): the config validator is in `src/shared`** (`@shared/Match/MatchConfig`, S-145; the lobby uses it since its merge of main). sim-A moves validate / validateResult and their constants to `src/shared/Match/MatchConfig.luau` (from m-lobby 287b99e). Then the lobby and client-B drop their copies. `build` and `summary` stay in `src/lobby`.
11. **Decided (2026-10-23): layered key art with parallax** from models-C for both loading screens (L-13, `docs/contracts/key-art.md`). Uploads still need your approval.
10. **Merge check:** `integrate.sh` doesn't run the lobby's 32 specs. sim-A agreed to add `lune run src/lobby/tools/test` (a failure blocks the push) once its running merges finish; until then I run them before every "Ready to merge" line.

## Requests

### For sim-A (sim session)

- **A-1. Done (sim-A S-143):** confirmed, `standard_start` seats player i on start i (IDs must be contiguous from 1, which MatchConfig guarantees); request 64 closed against L-4. **Match config → Sim (contract section 3).** Nothing new is needed from `Sim.new` for version 1: player ID = start index, factions by team parity as `src/roblox/Lobby.config` does. Please confirm, and resolve your request 64 (chosen starts) against L-4: the lobby assigns starts by player order.
- **A-2. Done (S-145, main d095edd); the lobby uses `@shared/Match/MatchConfig`.** **A shared validator (optional).** If the match server should run `MatchConfig.validate` without copying it, it could move to `src/shared/Match/` (yours). Say if you want it.
- **A-3. Done (sim-A, m-sim-2 2e9b5c7).** **Guide 16.3** ("map vote, mode, teams, faction pick"): the user's design is a BAR battle room where the host picks the map; reserved servers via TeleportService; the flow in `docs/contracts/match.md`. Please update the guide.

### For client-B (client session, match place)

**B-1..B-4 done by client-B (C-173 / C-174):** the match server side with a copy of the validator, the BAR-style loading screen (real caching progress), "Return to lobby" with the 30 s countdown, and `Kit.button` go / stop fills plus `Kit.input`. Since 2026-10-24 the lobby uses the kit's go / stop buttons and `Kit.input` (its own copies are gone).

- **B-7. Done (C-202, 2026-10-24):** the lobby's Settings page is built on `Kit.options`.
- **B-8. Done by client-B (C-214, e7c577c; on main with sim-A's next merge):** create, write and content now share one pcall in `editable()`, and `Kit.chart` is guarded the same way. **Guard `Kit` `editable()`:** `WritePixelsBuffer` and `Content.fromObject` are outside its pcall. In a published place without the EditableImage setting the write throws and the first `Kit.panel` stops the client script. Inside the pcall, a missing setting would only lose the stripes and shadow. Their question (every human out while AI teams fight on) is answered in the contract: `"finished"` with no `winner`, a loss for the humans.

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

  Each art is 4 depth layers in 2 × 2 tiles of 1024 × 576. Once you approve the uploads, they go in the manifest's `keyArt`. The lobby's loading screen shows them as soon as they're listed. **Status 2026-10-24:** 2 "Volley" and 3 "Converging" are listed and show in the lobby; 1 "Commander's stand" waits for its upload and manifest entry.

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
| Match place from one setting (L-14) | done, checked in Studio (stand-in) |
| Rooms across lobby servers (L-15) | done, checked in Studio with the stand-in peer server; live test in the playtest plan |
| Lobby settings on the profile (L-16) | done, checked in Studio (stand-in store) |
| Invite a friend (L-17) | done; the prompt opens in Studio, the arrival checked with `StandInLaunch` |
| References 1-2: rows, switches, grey cards, "running for", bigger map | done, checked in Studio |
| Kit buttons and input (C-174) | done; B's Settings components: waiting (B-7) |
| Published test ("FTGG Playtest", the checklist above) | ready to publish; waiting for you |
| Units tab: encyclopedia, showroom, article (L-18) | done, checked in Studio |

## How to continue

- Specs: `lune run src/lobby/tools/test`. Offline build and check: `lune run src/lobby/tools/sync build` (only `build/lobby`).
- Server: `src/lobby/server/Main.server.luau` (requests and views), `Launcher` (start), `Returns` (poll, results, arrivals), `StandInMatch` (Studio), `Services/*` (real vs stand-in).
- Client: `src/lobby/client/Main.client.luau` (shell), `Pages/*`, `Overlays/*`, `Scene.luau` (background).
- Server, new: `Places` (the match place, L-14), `Lobbies` (rooms across servers, hops), `StandInPeer` (Studio's second server), `Services/RoomIndex` (the `FtggRooms` list); shared `Listing` (its pure part).
- Studio test hooks on `game.ServerScriptService.Lobby`: `StandInFail` = `"reserve"` | `"teleport"` | `"player"` | `"hop"` in a playtest's server; `StandInLaunch` = `"room=PEERP"` (set in Edit before Play) for an invite's launch data.
