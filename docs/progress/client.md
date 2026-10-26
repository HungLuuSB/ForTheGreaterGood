# Client progress

Progress of the client stream: `src/client`, `src/shared/Defs/Blockouts/`, Studio-only place content and `docs/contracts/`. Branch `m-client-foundation`, worktree `FTGG-client`. This stream is the only one using the Studio connection. The headless simulation (`src/server`, the rest of `src/shared`, `.lune/`) is the sim stream's area; see [`sim.md`](sim.md).

Decisions: `C-1`, `C-2`, ... in [`../decisions/client.md`](../decisions/client.md).

## Summary (2026-10-26, pre-game and automatic colours)

- **Units on The Lakelands' baked ground (C-235):** that map's ground is drawn more coarsely than the simulation's heights, which left units up to 2 studs sunk into or floating above the grass at the foot of a cliff. They now stand on exactly what's drawn.
- Ready to merge: `78734742` (C-235; main 08c20e4b and 679a89a7 merged in: approved meshes, the Lakelands ground; test_client 316 / 316, test 573 / 573, build passed. Studio: Lancers at the ridge's foot on the drawn ground, debug_out/screens/2026-10-26-lakelands-ridge-foot.jpg)
- Ready to merge: `c5e996c5` (main e43b5726 merged in: models-C's Lakelands ground, still in review; test_client 315 / 315, test 573 / 573, build passed)
- **Death explosions from models-C (F27):** units now go up in C's death template (`ReplicatedStorage.Vfx.Death`): a fire burst with a ring on the ground. The client already played the template whenever the place had one, so no client code changed.
- Ready to merge: `ed345a93` (main 778851e1 merged in: models-C's Vfx.Death, meshes, wrecks; test_client 315 / 315, test 573 / 573, build passed. Studio, The Plains: 4 deaths played the Death template 4 times, screenshot debug_out/screens/2026-10-26-vfx-death.jpg)
- Ready to merge: `2b62f0d0` (main 9d7da230 merged in: S-191, D's map picker and firing range; test_client 315 / 315, test 573 / 573, build passed. Studio: The Lakelands' empty preview at 0.23 ms per tick, was 6.60, with only the join tick over budget)
- **Bigger maps (C-233, protocol 38):** the client reads the new wire positions. The Lakelands (512 cells) plays in Studio. Aircraft that swing past the map's edge are drawn there, and the minimap keeps them on its edge.
- **Plasma like tank shells (C-234, S-190):** the Thug's and Mace's plasma is as thick as a tank shell and bursts like its small hit.
- Ready to merge: `c6e78e52` (main's 592af90a (S-189) and m-sim-2's 16b5cb75 (S-190) merged in; C-233, C-234; test_client 315 / 315, test 572 / 572, build passed)
- **Death blasts (C-232, F15):** every unit explodes when it dies, sized by its blast; Commanders and fusion reactors go up in a fireball and smoke column like a smaller nuke (no crater).
- Ready to merge: `1bc6b6a7` (C-232 with its spec fix; supersedes the 01895765 line, whose Splash.spec still expected the old blast: test_client 315 / 315, build passed)
- **The bots walk (C-231):** the new bots step on their legs like the Commanders (Fatboy short heavy steps, Centurion long strides, Skitter scuttling on four legs), and the Dragon's fans turn. All client specs pass again.
- Ready to merge: `39f70870` (C-231 with m-models 4f6f268f; test_client 315 / 315, build passed)
- **Everything loads first (C-230):** in a lobby match every model and texture loads during the loading screen (twice as fast as before: 24.5 s in Studio), and the pick clock only starts once you're loaded. The loading screen's text has dark outlines so it reads over the art.
- Ready to merge: `8fd37e1d` (C-230; src/client; test_client 313 of 314, Nanoframe passes once models-C's 6c93cc9e is in; build passed)
- Ready to merge: `e6121b44` (LOAD_HOLD 115 s to match the sim's LOAD_WAIT 120; build passed)
- **More from the playtest (C-229):** right-drag a line and every selected unit's spot shows along it before you let go (F34; Ctrl keeps them together). AI levels read Hard - Balanced and Hard - Aggressive; lasers show their power per shot.
- Ready to merge: `5f0fabdf` (C-229 with m-sim-2 8713c298; test_client 313 of 314, Nanoframe waiting on models-C; build passed)
- **Tower lasers reworked (C-228), after your look:** they end on the target's surface facing the tower (not its turret top, not inside it), the wider beams are a bright wavering core in a soft fading glow instead of a solid rod, and a flash with a soft halo covers the muzzle. The camera turns all the way round now.
- Ready to merge: `cc254306` (C-228; src/client; test_client 312 of 313, Nanoframe waiting on models-C; build passed)
- **Small playtest items (C-227):** Ctrl + wheel turns the camera (F2); a building's rotation stays for the next ones (F14); stockpiles show their count as a number with a bar for the one being made (F10); Sentry and Overwatch lasers (both factions) are wider (F11).
- Ready to merge: `7547c68f` (C-227; src/client and a spec; test_client 312 of 313, Nanoframe waiting on models-C; build passed)
- **Team panel (C-226, F23):** bottom right, every player by team with a supply bar over a power bar (hover them for the numbers); on an ally: Units (click asks for units, double-click gives your selection), ■ / ϟ (click asks, drag up gives from your bank); gifts and requests show above it. **Smart Reclaim (F42):** in reclaim / repair / resurrect mode, drag a circle and the workers clear everything in it. Deposits are 2 × 2 patches and extractors snap to them; the pre-game says "Waiting for players to load".
- Ready to merge: `5748408d` (C-223..C-226 with m-sim-2 676ddca merged; test_client 311 of 312: Nanoframe's pads for the new labs wait on models-C registering the S-181 blockouts after S-181 reaches main; test 561, build passed)
- **Wind and tidal in the top bar (C-224):** a wind box after your sketch (the current in the middle over a see-through fan turning with the wind, min top right, max bottom right) and TIDAL.
- **Bomb carpets (C-225):** in attack mode, selected bombers show a blast ring where each of their three bombs will land.
- **sim phase 2 merged (C-223):** the new bot and air units have icons (borrowing the closest existing ones for now), plasma shots glow in their colour, the Dragon breathes a fire stream, and the Centurion's beam runs to its full range. Two scenes wait on sim-A (decoys) and the new labs' build pads on models-C.
- **Playtest phase 1 (C-222):** the unit panel shows what a unit makes in green and what it uses in red, per resource ("■ +1.0 −26", "ϟ +20 −51"), not 0/0 (F9). A builder's queued builds survive the camera being away, so its spray goes to the structure it's really building (F13). Aircraft: they're never drawn outside the map; ones that overshoot while turning stick to the edge because the server clamps their position there, so sim-A is keeping them inside (F3).
- **The camera opens on your Commander** at the start of every match, fixed starts included.
- Ready to merge: `dfcf7c8` (camera on the Commander at the start; src/client; test_client 308, build passed)
- Ready to merge: `c5ddf27` (C-222; src/client and a spec; test_client 308, build passed)
- **Pick your start (C-218), after your BAR screenshot:** every lobby match opens with the pre-game. Your area is filled green on the ground, the enemies' red; click inside yours to place your Commander (its model stands there with your name). A big Ready button on the right, the host's Start under it (lit when everyone is ready), the pick clock (150 s); the victory condition and "Pick a start spot within the green area, and click the Ready button." low on the screen; "Pick your faction" at the bottom with both Commanders. Start counts down 3 s, then the Commanders drop from the sky in a star flare and land 1.5 s later. `/forcestart` lets the host start at any time. Built on sim-A's protocol 37 (merged 72fb087), which also fixes the "team ... got 18" seat crash.
- **Automatic colours (C-217):** you are Blue, your allies cold colours, enemies warm ones, the same as the lobby.
- **Build menu on the unit panel (C-219)** instead of hanging under the minimap on tall screens; **Commander name labels (C-220)** over every Commander in game.
- Checked in Studio on FTGG Match (Coastline vs a Normal AI): picking, faction switch, Ready, Start, countdown, the landing flare, /forcestart, the build menu, the name labels.
- Ready to merge: `a0e3bad` (C-217..C-220 with m-sim-2 72fb087 merged; test_client 306, test 539, build passed)
- **Match failures reach the lobby (C-221, F38):** whenever the match server sends someone back (a refused setup, not in the match, a stale game version, the match already over, nobody arrived, a server error), the return carries D's error code and detail, and so does the result record, so the lobby can show it. Tried in Studio with the lobby-style test match: codes 203, 204, 205 and 208 go back with the right detail. Also fixed: the loading screen's call to stop drawing the world threw an error at the start and end of loading.
- Ready to merge: `9340b6b` (C-221 Studio check, MatchLoading fix, contract profile v2; test_client 307, build passed)
- Ready to merge: `2b1fde9` (C-221; src/roblox and a spec; test_client 307, test 539, build passed)

## Summary (2026-10-24, playtest logging, BAR settings, HUD, watchdog run, facing arrow, bars under units)

- **Live playtest logging (C-201):** the match place prints a `[Match]` line at each step of lobby → match → lobby: the config read (match id, map, mode, room, one line per seat), each player admitted or refused (with user id) and leaving, the start (who hadn't loaded), a heartbeat every 30 s, the result and when the store accepted it, and each teleport back (target, started or failed, fallback, retries). Failed store reads and writes warn per attempt and once more when they give up. The watchdog's WARN / INFO lines stay on.
- **Settings in BAR's layout (C-202):** a search box across the top, Unfold all and Advanced switches, a sidebar with each section's sub-sections and the amber bar on the one in view, amber section headers with an underline, fold arrows with indented child rows (dimmed while their parent is off), right-aligned dark dropdowns, square-knob sliders and toggles, and the hovered option's help in the footer. The pieces are in the Kit (`Kit.options`, `Kit.search`, `Kit.header`, `Kit.fold`, `Kit.treeNav`, `Kit.helpFooter`) for the lobby. Screenshots: `debug_out/screens/c202_settings_*.jpg`.
- **HUD after reference 3 (C-203):** build categories Economy / Combat / Utility / Build in tabs under the grid, each with its colour and key; Z X C V open them while a builder is selected (Patrol, Cancel, camera-right and range rings give way then; all four are rebindable); tile costs at the bottom right, the type icon bottom left; short coloured underlines on state buttons ("Repeat On / Off"); the unit's name in yellow-green; a flat "Keys · Settings (O)" text menu top right. Screenshots: `debug_out/screens/c203_hud_*.jpg`.
- Ready to merge: `feee077` (main d6643d4 merged into the client; test_client 285, test 495, build passed)
- Ready to merge: `8c74610` (C-201: [Match] playtest logging; src/roblox)
- Ready to merge: `3265b0b` (C-202 settings rebuild + Studio fixes 3234fff, C-203 HUD; src/client and client specs; test_client 290, build passed)
- **Watchdog run 1 for sim-A (C-204, request 65):** four Hard AI on Twin Lakes for 24 game minutes (peak 273 units): one tick over budget (Damage 96 ms when a player's army self-destructed), Pathing spikes 15–26 ms, Commands 2–4 ms over its 1 ms. The table is in request 65; raw lines in `debug_out/watchdog_2026-10-24.txt`. A new `watchdog` test profile runs it again after A's fixes. sim-A will also make radar terrain-cut (request 66) for reference 6.
- **Own units off camera stay live (C-205, S-158):** health, build bars and factory queues keep moving when the camera is elsewhere.
- **Factory facing (C-206, reference 7):** the placement ghost of a factory shows a green arrow on its exit side, and R shows "Buildings set to face East" over it; the ghost now turns the same way the built factory will (it was flipped for South and North). Screenshots: `debug_out/screens/c206_*.jpg`.
- **Health bars under the unit (C-208, your request):** `debug_out/screens/c208_health_bars_under.jpg`.
- **State buttons show every state (C-210, your request):** three segments under Fire / Move state (red, yellow, green), two under Repeat, On / Off and priority (red left, green right); the current one lit. `debug_out/screens/c210_state_segments_x2.jpg`.
- **The Canyon's mesh ground (C-209, models-C's 08b9889):** wired and checked in Studio: it builds in ~10 s and is sharp right after a minimap jump; clicks over mesas now land on the ground. Its textures draw flat white in the match place, so models-C is looking at them before your review. Side-by-side shots: `debug_out/screens/c209_canyon_*.jpg` (voxel vs mesh, close and after a jump).
- Ready to merge: `94be98c` (m-models 08b9889 merged in 13b9a3c; C-209, C-210; test_client 295, build passed)
- **Radar coverage (C-207, reference 6):** while you place a radar, select one, or press N, your radar coverage shows as a translucent green fill with softer lighter rings, under the fog and on the minimap. It follows the server's circles until sim-A makes radar terrain-shaped (request 66). Screenshots: `debug_out/screens/c207_radar_fill_minimap.jpg`, `c207_radar_fill_placing.jpg`.
- **Canyon textures fixed by the Studio restart** (models-C's diagnosis): the mesh ground is textured and sharp after a jump (`c209_canyon_mesh_close.jpg`, `c209_canyon_mesh_after_jump.jpg`). Still to fix: in unexplored areas the fog blanket sits flat over the mesa tops at the sim's blocky height, showing as grey squares above the rounded baked mesas.
- Ready to merge: `84ef26e` (main 1b8da68 merged in a439502: S-158..S-160; C-207; test_client 298, build passed)
- **Sonar pings and jammer shimmer (C-211):** your sonar units and buildings send a cyan ring out across the water every 3 s; jammers (yours and enemies' in sight) wear a shimmering dome with a thin purple ring at their reach. `debug_out/screens/c211_sonar_ping_jammer.jpg`.
- Ready to merge: `fe5325a` (C-211; test 506, test_client 300, build passed)
- **Changed after your look (C-212):** the radar fill is switched off for now, and jammers show only the purple ring at their reach (the shimmering dome is off). Both can come back with a switch.
- **New units' icons (C-212):** Pharos and Scylla use the Radar SAM Site icon, Empyrean and Rookery the Rearm Pad icon, until you design their own.
- **Watchdog runs 2–3 for sim-A (request 65):** sim-A's fix removed the 96 ms Damage spike (now 5.7 ms at worst); no tick went over budget in the same 24 minutes. Commands and the Pathing spikes are unchanged. Run 2 was spoiled by other work on the machine, so I ran a clean run 3.
- **Five more maps' mesh ground (models-C's eb9f88d) merged** (Coastline, Ridgeline, Twin Lakes, Crossroads, Normandy; all at review, off unless switched on in Studio). Not checked in Studio yet.
- Ready to merge: `52103cd` (main 3471b0f merged in ba7e932: S-161..S-166; C-212; m-models eb9f88d merged in 3d80b8c; test 511, test_client 300, build passed)
- Ready to merge: `5ffed26` (main 1536c94 merged; only sim.md changed; with C-212 the icon specs pass: test_client 300, build passed)
- **Fog over the Canyon's mesas fixed (C-213):** the mesas are now fogged like the ground around them (the rock details on top used to poke through, leaving grey squares). `debug_out/screens/c213_canyon_fog_before.jpg` / `c213_canyon_fog_over_mesas.jpg`. A thin skirt still drapes off the mesa edges: the fog can't be finer than about 32 studs there.
- **Kit crash fix for D (C-214):** a published experience without EditableImage allowed no longer crashes at the first panel; it just loses the stripes, shadow and charts.
- Ready to merge: `e7c577c` (C-213, C-214; test_client 300, build passed)
- **Resurrect and reclaim (C-216, sim-A's S-168):** wrecks show a dark-green bar for supply left (when partly reclaimed) and a purple bar while being resurrected; hover a wreck for "<unit> wreck · supply"; T1 workers get a Resurrect button (key D); with only workers selected, nearby wrecks show as green zones with "+N supply". Checked in Studio, a Lancer resurrected end to end. `debug_out/screens/c216_*.jpg`.
- Ready to merge: `1e3361e` (C-216 with main 3e06cf2 merged in 7a9708b; test_client 303, build passed)
- **16 players' colours (C-215 groundwork):** until the palette grows to 16 (sim-A, with lobby-D's four colours), teams 13–16 draw as lighter twins of 1–4 instead of grey.
- Ready to merge: `8a32e77` (C-215 groundwork: Render/TeamColors only; build passed)
- Ready to merge: `99ee814` (C-214 follow-up: the vignette and the fog blanket survive an experience without EditableImage too; test_client 300, build passed)
- Ready to merge: `196d8a7` (main f04d534 merged in 3d5fbf4, protocol 34; C-204 watchdog profile and speed fix (src/roblox), C-205, C-206, C-208; test 496, test_client 295, build passed)

## Summary (2026-10-24, point defence; new icon sheet)

- **Bulwark's laser muzzles stay put on death (C-200):** muzzles named like `laser_muzzle1` count as attachments, so a destroyed tower never flings them.
- Ready to merge: `10eb034` (C-200; src/client and a spec; main merged in at debda1b, test 495, test_client 285, build passed)
- **Laser looks (C-199):** lasers follow your references: a thick white-to-colour bolt tapering to the target with a muzzle flare and a glowing orb (Overwatch, Geryon and the other laser towers in their colours); the Beamer a thin flickering thread with a cone of light where it lands.
- Ready to merge: `583fb90` (C-199; src/client only)
- **Priority, new icons, tower visuals (C-196..C-198):** a High / Low priority button on units that use resources; your draft 5 icon sheet with the new towers' own icons; red, green and blue lasers, the Beamer's growing beam, barrels firing in turn and Geryon's turning drum.
- Ready to merge: `6eb8b11` (C-196 e7d8400, C-197 082a892, C-198; src/client, the icon sheet and asset id)
- **Build over your own units; new defences have icons (C-195):** placing over your own or allied units is allowed (they walk out); shields' On / Off works on the card; the new T1 defences use existing icon tiles until they get their own.
- Ready to merge: `09df50f` (C-195; carries sim-A's d41074e, S-152..S-157, so the new defs land with their icon entries; test 495, test_client 280, build passed)
- **Command line (C-194):** Tab completes and cycles choices (reveal on / off, kill selected / a team ...); /give takes aliases like ord_shield or chs_ir-sam.
- Ready to merge: `a04dd51` (C-194: Tab cycling, unit aliases; src/client)
- **Commands and order lines (C-193):** each unit offers only commands that do something (no Stop on a generator; shields get On / Off); a box with a builder in it selects only builders; a turret takes no move; order lines (assist, build, factory orders) stay until done; builders spray what they build; the shield bar sits over the generator.
- Ready to merge: `1699a9e` (C-193: command audit, box filter, lasting order lines, nano spray; src/client)
- **Units on their terrain (C-192):** portraits show each unit on ground, water, a shore or above ground; in the world, water buildings and amphibious units float, and far-off aircraft stay in the air.
- Ready to merge: `17bd157` (C-192: units on their terrain, portraits and world; src/client)
- **Selection tiles (C-191):** with several units selected, each type's tile shows the unit itself, its icon bottom right and the count top left.
- Ready to merge: `41fd948` (C-191: multi-select tiles; src/client)
- **Smoother shield hits (C-190):** the hit patch crossfades between its frames instead of stepping; a faster patch is asked of models-C.
- Ready to merge: `e06e139` (C-190: hit patch crossfade; src/client)
- **No honeycomb on the shield (C-189):** the dome shows hex cells only where a shot hits.
- Ready to merge: `f0f231f` (C-189: no idle honeycomb on v4 shields; src/client)
- **New shield look in the game (C-187):** your approved v4 from models-C: a ForceField dome in the faction's colour (Order cyan, Chaos amber) that forms from the top down and drains back up, a channel with packets, streaks, energy waves and glowing hit patches. It replaces the old look and C-186. About 0.27 ms a frame per dome. Screenshots: `debug_out/screens/c187_shield_*.jpg`.
- Ready to merge: `5dd4a94` (C-187: shield energy v4, C-186 taken out; src/client, place/MeshMaterials; main 5950103 merged in; also carries the C-186 hold note)
- Ready to merge: `84771a6` (C-186: shield column and dome waves; src/client, place/MeshMaterials; main bd87d26 merged in)
- **Shield hits explode (C-185):** shells and rockets destroyed on a dome now explode on the honeycomb with their own impact effect. `debug_out/screens/c185_shield_absorb_bursts.jpg`.
- Ready to merge: `369ea62` (C-185: absorbed projectiles burst on the dome; src/client)
- **Smooth key art (C-184):** the loading screens' parallax no longer stutters, and the match no longer draws the world behind its loading screen.
- Ready to merge: `ddc588f` (C-184: KeyArt sub-pixel parallax, 3D paused while loading; src/client)
- **New icon sheet (C-183):** your draft 4 is uploaded (asset 83784263765889) and live. Every unit's icon comes from the sheet's own lists; anti-nukes, point defences, shields, flak, missile batteries and the decoy drone have their own tiles now. A second sheet starts automatically once the first is full. Screenshots: `debug_out/screens/c183_strategic_*.jpg`.
- Ready to merge: `02e1493` (C-183: icon sheet draft 4, multi-sheet atlas, new asset id, Studio "hold" debug query; src/client, src/roblox, tools/icons, assets, docs/art)
- **Point defence (C-182, S-149):** interceptors from the Sanctum, Basilisk, Shepherd and Griffin chase rockets and missiles on screen; a shot-down rocket ends in a small puff. Stopgap icons until your draft 4 sheet.
- Ready to merge: `f5696da` (C-182: point defence on the client, stopgap icons; main c1bbe23 merged in; fixes main's 2 icon specs)

## Summary (2026-10-23, lost missiles fall; radar accuracy shown)

- **SAMs no longer fly into the sky when their target dies (C-181, S-146):** a radar missile that loses its target now spirals and falls on your screen, on the same path the server uses.
- **Radar accuracy in the sensor view (N):** a circle round each radar blip shows how far radar-fired shots miss (amber; smaller and green when a fire-control radar tracks it), with a readout under the resource bar, e.g. "Radar accuracy ±7.7 studs · tracked ±2.6 · Pinpointers 40%". Screenshots: `debug_out/screens/c181_*.jpg`.
- Ready to merge: `589e168` (C-181: lost radar missiles, radar accuracy view; main 276158f merged in; test_client 258, test 481, build passed)
- Ready to merge: `11d9adf` (C-181 follow-up: the readout greys "tracked" while nothing is tracked)

## Summary (2026-10-23, the match side of the lobby flow)

- **The match place now runs a lobby match end to end (C-173, D's contract):**
  - it reads the room's settings that D's lobby stores and admits only the listed players;
  - it shows a BAR-style loading screen until every client has cached the map, the models and the textures;
  - it plays, writes the results record for the lobby, and shows "Return to lobby" with a 30 s countdown before sending everyone back.
  - Checked in Studio with a stand-in store. The real teleports and storage need a published test.
- **Player colours** now come from the lobby's 12-colour palette.
- **Kit additions for D (C-174):** green / red action buttons and a text input.
- Ready to merge: `c821622` (C-173, C-174: match side of docs/contracts/match.md; src/roblox and src/client)
- Ready to merge: `3cb87aa` (C-175: humans out while AI fight on = finished, no winner; D's decision)
- Ready to merge: `ae721bf` (C-176: loading screen key art, a copy of the lobby's KeyArt viewer)
- Ready to merge: `9a9ae06` (C-177: fix a client freeze from crane / gantry loops far from the camera)
- Ready to merge: `3fd6f06` (C-178: MatchContract and TeamColors use @shared/Match/MatchConfig)
- **One key art viewer (C-179):** the lobby place now mounts `UI/KeyArt` read-only, as it does the Kit; keep its API stable.
- Ready to merge: `50e2138` (C-179: KeyArt header, the lobby mounts it read-only; comment only)
- **No more animation freezes (C-180):** your playtest log still showed the freeze, most likely from a match started before C-177. The animation scheduler now holds any loop that waits on pieces that have already arrived, so a script like that can't freeze the client again.
- Ready to merge: `cf35347` (C-180: PieceAnim spin guard; src/client and tests/client)

## Summary (2026-10-23, new T1 models in; the Commander stops spinning)

- **The approved T1 structure models are merged here** (models-C's batch), so a playtest draws them. All 31 built with no failure in Studio.
- **Your Commander no longer rotates (C-172):** my animation pass was spinning the mech's torso and head like a radar. It now moves only the parts it knows.
- Ready to merge: `f220783` (C-172: Ambient only animates known pieces; contains the m-models 671732b merge)

## Summary (2026-10-23, queue in a frame, Ctrl moves, server idle counts)

- **You can queue units in a factory that's still being built** (sim-A's S-138): pick from the build menu with the frame selected, and production starts the moment it's finished.
- **Ctrl + right click (or a line drag, or Move / Fight / Patrol) keeps the group together** at its slowest unit's speed (C-169, sim-A's S-137).
- **Idle counts now come from the server (C-158 on S-136):** every idle builder and factory counts, also off camera, and **I** jumps to one anywhere.
- **Recharge bar (C-170):** your Radiance, Inferno and every other weapon reloading 4 s or more show a thin pale-blue bar under the health bar, filling until the next shot is ready.
- Ready to merge: `96392ac` (C-169: Ctrl moves send GROUP; idle counts from IDLE events; frame queue specs)
- Ready to merge: `8321418` (C-170: recharge bar for long-reload weapons)
- Ready to merge: `c1300b4` (C-171: Watchdog wired into the live server, S-140)

## Summary (2026-10-23, factory progress bar)

- **A producing factory shows an amber progress bar under its health bar (C-168),** always, for your factories and your allies'. It fills smoothly with the unit being built.
- Ready to merge: `c1a45ea` (C-168: factory production bar; client only)

## Summary (2026-10-23, mesh ground on the way)

- **The ground is moving off Roblox terrain (C-167):** the named maps will use mesh tiles that models-C bakes from the game's own height data (requested). They stay sharp at any distance, so a minimap jump lands crisp. Terrain keeps only the water.
  - Building the ground in game wasn't possible: Roblox's budget for such meshes runs out after a few thousand points, and The Canyon needs about 160,000.
  - The client loader, the export tool (`lune run export_ground`) and the contract are done. Until C's tiles arrive, every map keeps the voxel terrain.
  - The Canyon comes first, for you to compare in Studio.
- Ready to merge: `3fbca98` (C-167: export_ground tool, map-ground contract, mesh ground loader; client and .lune only)

## Summary (2026-10-23, assist, minimap drag, build grid, no overlapping plans)

- **Assist (C-163):** right-click your own factory with builders selected and they help its production; right-click your own frame and they build it; right-click your own builder and they follow its lead, helping whatever it builds. With only builders selected, the Guard button reads "Assist".
- **Minimap (C-164):** drag on it to move the camera; your view now shows as the real trapezoid on the ground.
- **Build grid (C-166):** while placing, the build cells round the ghost show on the ground (Settings > Interface > Build grid).
- **No overlapping plans (C-165):** a new building can't be placed over one you've already queued, rows and extractor drags included.
- **The coarse-then-sharp terrain after a long jump** is Roblox's terrain level of detail. Pointing the camera's focus at the ground (C-162) didn't change it; options are under "Needs my review".
- **Queue in a factory under construction:** needs the server (sim request 63, sent). The client side is already in place.
- Ready to merge: `5a70dc2` (C-162..C-166; client only)

## Summary (2026-10-23, nothing pops when the camera moves)

- **Your units and buildings stay drawn when the camera leaves (C-161):** no more re-rendering when you pan away and back; the same models carry on. A selected Mason far away keeps its unit panel, build menu and command card, so you can keep queueing builds for it. Checked in Studio.
- Off camera, a unit's health and a far building's progress show their last values until you look again (the server sends little there).
- Ready to merge: `9e8e8c2` (C-161: units stay drawn and selectable off camera; client only)

## Summary (2026-10-23, your queue while away)

Queue status, item by item (details below and in the decisions log):
- **0. "Needs my review" cleaned up:** everything you approved up to C-130 is gone; only open questions are left.
- **1. Beam shots from C's assets:** already done before the queue (C-133..C-144; the beam entry is approved). Skipped.
- **2. Animation pass (C-156):** done. Radars, sonar drums and drills turn while powered, wheels roll while moving, gantries run while producing, windmills turn, tracks judder. Not done: a sonar "ping" and jammer shimmer, which would be new effects rather than pieces.
- **3. Selection panel like BAR (C-157):** done. Click a tile to keep that type, Shift-click to drop it, Ctrl-click for every one of that type on screen.
- **4. Idle indicators (C-158):** done, as a client-side guess. sim-A has already made the server's IDLE events (S-136, request 62); I switch to them once they're on main.
- **5. Group speed (Ctrl-move) (C-169):** done. Ctrl + right click, a line drag, Move / Fight / Patrol, or a minimap right click keeps the group at its slowest unit's speed.
- **6. Rebindable keys (C-159):** done. Settings > Keys, click and press, red clash warnings, saved for your account. Camera turn-right moved from E to C.
- **7. Commander walk on the v3 mechs (C-160):** done. It works as is, checked in Studio with a new preview switch.

## Summary (2026-10-23, the Canyon by day, blips circling, units leave from the pad)

- **The Canyon is playable and looks like a desert in daylight (C-153, C-155):** pale sand floor and red rock mesas and cliffs, under a mid-afternoon sun with blowing sand. It's in the skirmish lobby's map list, and the `canyon` test profile starts both Commanders there.
- **Each map now has its own lighting and time of day (C-155):** the Canyon is the first. The others stay on the moonlit night. Settings > Atmosphere defaults to "Map's own" and can still override it.
- **Radar blips circle about 1.5 studs round their spot, as in BAR (C-154).** The server's circle (S-131) didn't reach the client, so the client draws it. Measured in Studio.
- **Finished units appear on the build pad (S-133, merged here from sim-A's branch for your playtest):** the server's pad spot equals the client's drawn frame (64, 47.4 on a vehicle plant).
- **Animated pieces (C-156):** radars and drills turn while powered, wheels roll while moving, factory gantries run while producing, windmills turn.
- Ready to merge: `e299b43` (C-153..C-155: Canyon look and lobby entry, client blip orbit, per-map looks)
- Ready to merge: `65673ae` (C-156: animated pieces run by state)
- **Selection panel like BAR (C-157):** with several units selected, click a type tile to keep it, Shift-click to drop it, Ctrl-click for every one of that type on screen.
- **Idle indicators (C-158):** idle builder and factory counts beside the resource bar, **I** jumps to the next idle builder (the camera follows), an IDLE tag over each. For now only what's in view counts: sim request 62 asks the server for a proper idle signal.
- Ready to merge: `946b6a7` (C-157, C-158: selection tiles, idle indicators)
- **Rebindable keys (C-159):** Settings > Keys has a button per action: click, press the new key. Two actions on one key show a red warning on both. Saved for your account (the session only in Studio). Camera turn-right moved from E to C, because E is also reclaim.
- Ready to merge: `0db7a34` (C-159: rebindable keys; adds the Keybinds remote in src/roblox)
- **The Commander mechs v3 walk (C-160):** the walk works on models-C's v3 meshes as they are; checked in Studio with the new preview switch (`FtggClientDebug:Invoke("reviewmesh", "ord_sovereign")`). They show in normal games once you approve them.
- Ready to merge: `eb4ad8b` (C-160: review-mesh preview switch; v3 walk checked)

## Summary (2026-10-23, factories show what they build)

- **You can now watch a factory build (C-152):** the unit in production stands on the factory's pad as a translucent team-coloured hologram. It fills in from the bottom up behind a glowing line, with nano spray from the factory's emitters. The spray stops when the economy stalls. This works for your factories and your allies'. Checked in Studio on a vehicle plant and an airfield.
- **Coming:** finished units start on the pad and drive out, instead of appearing a cell outside the factory (sim request 61).
- Ready to merge: `12ff8b5` (C-152: factory production frames; client only, no protocol change)

## Summary (2026-10-23, radar blips circle their unit)

- **Radar blips orbit the real unit now,** like BAR (sim-A's S-130 with the client's glide). In the radar scene a blip swept a full turn in about 6 s, 13–17 studs out, and the real position never reaches the client. Guide 11.4 is updated.

## Summary (2026-10-23, allies, assist and ghosts merged)

- **Merged sim-A's S-127 / S-128 / S-129:**
  - units no longer fire on their own at remembered buildings (only on your order);
  - builders assist another builder's work with Guard;
  - the client knows every team's alliance, so right-clicking an ally's unit guards it (or assists its builder) instead of attacking it.
  - An end-to-end test checks the ally list arriving and right-click using it.
- **Radar blips circle their unit** (S-130, merged and checked in Studio).
- **Coming:** a much smaller circle, ~1.5 studs as in BAR (sim request 60). Radar shots keep missing by the radar error, through a hidden aim point the client never receives.

## Summary (2026-10-23, smooth radar blips)
- **BAR-style circling blips:** at your choice, the server's wobble will become a slow orbit around the real unit (sim request 59), so blips circle it while the real position stays secret. Targeting still uses the wobbled point.

- **Radar blips glide now (C-151)** instead of jumping to each new wobbled spot: the ground discs, icons and minimap dots all ease toward each new reading. A contact that reappears far away still snaps. Checked in the radar scene.

## Summary (2026-10-23, builders assist builders)

- **Builders assist other builders (sim-A's S-128, merging):** give a builder Guard (G, or the card's Guard button) on another builder, and it helps build whatever that one builds, following it in between. Right-clicking your own builder does the same. Nothing changed on the client; it already sends that order.
- **Allies (C-150):** once sim-A's S-129 is merged, right-clicking an ally's unit guards it (or assists its builder) instead of attacking it. Until then, use G.

## Summary (2026-10-23, manual targets fixed; crash fixed; ghosts)

- **Merged sim-A's S-124 / S-125 / S-126.**
  - **Manual targets** now stick while the unit lives, even unseen: point weapons keep firing at its last known spot while it's in range.
  - When the target dies, the unit goes straight back to auto-targeting.
  - I re-ran my test: the towers burned through two domes to kill the ordered tank, and there's no crash any more (S-126 fixed a crash on beams at a dead building's ghost).
- **Coming (S-127, from you):** units won't auto-fire at remembered buildings any more, only when you order it. Right-click or Attack on a remembered building already works on the client (C-149, spec added).

## Summary (2026-10-23, beams stop at the next dome; manual target issues)

- **S-123 merged and checked:** two Radiances on a tank behind two overlapping domes. When the front dome drops, the beams stop at the second dome's surface instead of going through, with their glancing legs (`debug_out/screens/two_domes_beam.jpg`). The case of a dome rising across a beam was tested by sim-A; I didn't stage it in Studio.
- **Manual targeting (sim request 57):** two problems, both sim side:
  - an ordered target is dropped for a dome generator after a couple of blocked shots, while it still lives;
  - your note: when the chosen unit dies, it should go back to auto-targeting.
- **Mech meshes v2** (heroic, ~10 studs) are on m-models at review, next to merge.

## Summary (2026-10-23, domes without vision live; bigger mechs)

- **Shield domes without vision (C-145 + sim-A's S-122): live and checked in Studio.** An enemy Carapace out of your sight shows its dome, honeycomb shell and core, with no unit revealed (`debug_out/screens/unseen_dome.jpg`).
- **Mech Commanders:** models-C rebuilt them as ~10-stud heroic mechs (blockouts for now). The walk cycle follows their new stride (C-148). Not re-checked in Studio.
- **Beams vs overlapping domes:** sim-A built request 56 (S-123), integrating. The client is ready.

## Summary (2026-10-23, beams and overlapping domes)

- **Your screenshot (two overlapping domes):** the beam went through dome #2 when #1 collapsed, and through #1 when it came back up. The sim checks a beam's path against domes only at certain moments, not continuously, so it's with sim-A as **request 56**: re-check every dome each tick, and cut the beam at the first one in its way.
- **Client (C-147):** when a beam's end moves onto another dome, its glancing leg and honeycomb pulses move with it. Unseen domes count too.

## Summary (2026-10-23, the Commanders walk; Needs my review)

- **Mech Commanders (C-146):** the Sovereign and Warlord walk: legs in models-C's stride, alternating every 0.3 s, arms swinging, the torso twisting and the pelvis bobbing. They ease back to rest when they stop (`debug_out/screens/mech_walk.jpg`).
- **Needs my review:** models-C's mech meshes are at "review", so the game draws the mech blockouts. Approve them through models-C to see the meshes.
- **Domes without vision (C-145):** the client side is ready and waits for sim-A's S-122 on main.

## Summary (2026-10-23, S-120 / S-121 merged: beams go through fallen domes)

- **Merged sim-A's S-120 / S-121 and checked in Studio:** a Radiance ordered onto an enemy Carapace takes the order (towers now accept attack orders). Its beam ends on the dome, and once the dome collapses (~2.5 s in) the same beam moves on to the generator. It repeats when the dome rises again (`debug_out/screens/beam_through_dome.jpg`).
- **Domes visible without vision (as in BAR):** asked sim-A (**request 55**). Today the server only sends a dome for a generator you can see. The client will draw domes from the new records.
- Your shield_beams edit (fewer Radiances) is kept; it's your local MatchConfig, uncommitted.

## Summary (2026-10-23, S-119 merged)

- **Merged sim-A's S-119.** Beam and hitscan weapons follow attack-ground orders: in shield_beams the Radiances now fire at your dome's middle, and their beams end on its surface. A turret's barrel holds on its beam while it burns, and turrets show their aim as soon as a unit comes into view. Checked in Studio.
- **Still integrating (sim-A, S-120 / S-121):** manual targets win whatever the fire state; structures take ATTACK orders (the cause of your Radiance ignoring the Phalanx: towers never received the order); a beam goes on through a dome that drops under it (the client side is ready, C-144).
- **Next from models-C:** the Commanders become walking mechs. The blockouts are on m-models; the client will need a walk cycle for their legs once the meshes come.

## Summary (2026-10-23, beam through a fallen dome; thinner rings)

- **Thinner rings** flow down the dome (C-144).
- **Honeycomb hit patches stay as in C-142.** The wide rim of tiny cells is reverted at your word, and it was too heavy for the frame rate anyway.
- **A dome dropping under a beam:** the client is ready to carry the beam on to its target (C-144). sim-A is building the sim side (request 54), together with your Radiance picking a tank over the Phalanx you ordered.
- **Manual targets win whatever the fire state:** sim-A built it as S-120. It lands with their next merge, after S-119.

## Summary (2026-10-23, faster detailed models, hidden beams)

- **Detailed models (C-143):** all 74 types in a big match are ready in about 15 s, against more than a minute before (models-C's new meshes have many more pieces, which were built one at a time). The area the server fills with full models also runs ahead of the camera when you pan.
- **Hidden beam towers:** their shots now draw as full beams with no vision, as in BAR (sim-A's S-118 merged). Checked in shield_beams without /reveal (`debug_out/screens/hidden_beams.jpg`).
- **Also merged:** sim-A's S-117 (beams drain shields a lot: your dome dropped to 0% under three Radiances and an Inferno).
- **Coming from sim-A (S-119):** attack-ground for beam and hitscan weapons; turrets hold their aim while a beam burns; and a server fix for turrets not showing their aim on units entering your view (the likely cause of "the gun never aims at a unit that doesn't move").
- **Manual targeting priority:** asked sim-A to re-check S-115 against your expectation.

## Summary (2026-10-23, outer rings, C's effects in Studio, turret aim)

- **Shield hits (C-142):** 8 to 11 rings (217 to 397 cells), the outer ones smaller still. Not checked in Studio yet: you were in a playtest. It shows in your next one.
- **models-C's beam effect and honeycomb shell now show in Studio without commands.** Live games still wait for your approval.
- **Turret aim:** the client draws the server's aim exactly. My headless tests didn't reproduce turrets going back to rest during a reload, so it's with sim-A (**request 53**), together with your point that beam and hitscan weapons need attack-ground orders (today they ignore them and pick their own targets).
- **Hidden Radiances' shots drawn as projectiles:** that's request 52 (a SHOT carries no weapon yet). Built by sim-A as S-118; I'll draw them as full beams once it's on main.

## Summary (2026-10-23, more rings in shield hits)

- **Shield hits (C-141):** more rings, getting smaller toward the edge: 6 to 9 rings (127 to 271 cells). The edge cells are a third the size of the centre one and packed tight, and the inward wave is a little quicker. Screenshot: `debug_out/screens/shield_rings_more.jpg` (shield_beams, 0.5×).

## Summary (2026-10-23, shield vs Radiances scenario)

- **New test profile `shield_beams` (C-140):** your Phalanx dome against three Radiances (east, west, south) and an Inferno (south-east), every beam aimed at the dome so it glances off, plus Juggernauts and Ravagers shelling it. Your units are tough so it lasts. Set `ACTIVE = "shield_beams"` (your local MatchConfig already is).
- **Play it with `/reveal on` for now:** a beam from an enemy you can't see reaches the client as a plain shot with no weapon, so it draws as a quick tracer. Sim request 52 asks for the weapon on those shots.
- **Your earlier question:** your own dome's hit patches show without /reveal (204 cells lit with the shooter unseen). It was the scattered shell (`shellanyway`) and these hidden-shooter beams that looked tied to /reveal.
- **Screenshot:** `debug_out/screens/shield_beams_scene.jpg`.

## Summary (2026-10-23, beams pulse on shields; bigger patches)

- **A beam held on a shield (C-139)** lights its honeycomb again every 0.2 s for as long as it burns.
- **Bigger hit patches:** 4.8-stud cells, 5 to 7 rings (91 to 127 to 169 cells), about three times the diameter of the patches before C-136.
- **Shields vs beams (sim request 51, built as S-117, merging):** a Radiance beam drains 250 charge over its 3 s (42% of a Phalanx, 62% of a Carapace), an Inferno about 142. Capacities are unchanged.

## Summary (2026-10-23, shield shell, beams glancing off shields; Needs my review)

- **Beams glance off shields: done and checked in Studio.** A Radiance firing at an enemy dome stops at its surface, a short leg glances off downward into the ground, the dome takes the hit, and the units inside are untouched (`debug_out/screens/beam_deflect_side.jpg`).
- **Honeycomb shell (C-138):** models-C's shell is on every dome as scattered hex patches, strongest on top and fading toward the base, with its opacity following the shield's charge (`shield_shell_top.jpg`, `shield_shell_beam.jpg`).
- **Beam shot:** stays on for the shot's full duration (Radiance 3 s, Inferno 1.5 s) with a hot spot at the impact, per your note to models-C.
- **Needs my review:** the shell and the beam shot are both at "review". Preview them in a playtest with `ReplicatedStorage.FtggClientDebug:Invoke("shellanyway", true)` and `Invoke("beamsanyway", true)`. Approve them through models-C and they show everywhere.

## Summary (2026-10-23, sim S-104..S-116 merged into the client)

- **Main merged:** sim-A's S-104..S-116, with bigger structures, extractor upgrades kept running under the frame, anti-nukes, beams that last and pierce and stop at domes, manual targets, and the AI fixes. All 8 client specs it broke are fixed (C-137).
- **New units** get stopgap icons until the icon catalogue has them: the Sanction and Scourge missile batteries, the Wraith decoy bomber, and the four anti-nukes.
- **Extractor ghost:** an extractor works any deposit under its footprint, the sim's rule.
- **Now testable in Studio:** beams glancing off shields (C-129), the full 3 s Radiance beam, and anti-nukes intercepting.

## Summary (2026-10-23, bigger shield hit patches)

- **Shield hits (C-136):** each hit covers about twice the diameter: 3.2-stud cells, 4 to 6 rings (61 to 127 cells). Start a new playtest to see it.

## Summary (2026-10-23, beam update from models-C; slowed test)

- **Beam shot (C-135):** models-C's update is merged and used: a point at the target, nothing wider than the emitter ball at the muzzle, a smaller impact flare, and a flickering star on the ball while firing. The shot also slows with the game speed now.
- **0.25× test:** running in Studio (`shield_one` + a Radiance + Juggernauts, with C's beam previewed). `debug_out/screens/shield_slow_honeycomb.jpg` shows a hit's patch at that speed.

## Summary (2026-10-23, shield cells only cave in)

- **Shield hits (C-134):** the cells now only move inward. They're pushed in, deepest at the centre, then ease back to the surface. C-132's bounce took them past the surface, outward, which is what you saw.

## Summary (2026-10-23, C's beam shot wired; Needs my review)

- **Merged m-models** (animated pieces on 44 meshes, rebuilt wrecks, lighter deposits, the beam shot effect). test_client stays green and the materials file was regenerated.
- **Beam shot (C-133):** models-C's effect (a white core, a wide coloured glow, jittering filaments, a charge flash, an impact flare and a scorch mark) now draws the Radiance and Inferno shots. My adjustments for your notes:
  - it lasts the shot's full duration (Radiance 3 s, Inferno 1.5 s), held, then narrowing away over the last second;
  - it narrows to **a point at the target end**, and the filaments meet there instead of fanning out. models-C is updating their recommended widths for the same thing.
- **Needs my review:** it's at "review", so in a normal game you still see the placeholder ray. To preview it, run `ReplicatedStorage.FtggClientDebug:Invoke("beamsanyway", true)` in a playtest. Approve it and models-C flips the status, then it shows everywhere.
- **Shield hits (C-132), now seen in Studio:** a honeycomb patch on the dome where shots land (`debug_out/screens/shield_cavein.jpg`).
- **Honeycomb shell over the dome:** asked models-C for the asset (fading out toward the base); I'll scale it with the shield's capacity.
- **Screenshot:** `debug_out/screens/beam_shot_c.jpg` (both beams, the rig driven directly; the towers' own targets were out of sight in that scene).

## Summary (2026-10-23, shield hits cave in)

- **Shield hits (C-132),** after your second look at the GIF (its 2nd and 3rd shots):
  - **the wave runs inward:** the outer ring lights first, each ring in after it, the centre last and hottest;
  - **cells grow toward the centre:** small at the rim, bigger inside (1.3× at the centre, 0.75× at the rim), with the inner rings spread slightly wider;
  - **the patch caves in like a bowl,** deepest at the centre, then springs back past flat once (a small bounce), as if the dome bends in to repel the shot.
- **Not checked in Studio yet:** you were in a playtest (`shield_one`), so I didn't touch it. The specs cover the timing, sizes and bounce. Start a new playtest to see it.

## Summary (2026-10-23, shield hits like BAR's plasma deflector)

- **Shield hits (C-131),** after your BAR GIF:
  - the ripple is gone;
  - a hit now lights a patch of fine **outlined** honeycomb cells on the dome: 2.6-stud cells whose edges touch, 3 to 5 rings depending on the shot (37 to 91 cells);
  - the cells are white-hot at the centre and fade outward, still curved with the dome. Each hit sends its wave through the patch as before.
- **Screenshots:** `debug_out/screens/shield_honeycomb_1.jpg`, `shield_honeycomb_2.jpg` (the shield scene under fire, from outside).

## Summary (2026-10-23, big-map fog fixed)

- **Fog on big maps (C-130):**
  - the cause, confirmed in the Studio log: "Failed to create empty EditableMesh ... memory budget limits". Normandy needed 16 fog chunks, and the device budget, shared with the shield effect, charts and vignette, ran out partway.
  - the fix: the fog's vertices now spread out on bigger maps, so every map needs at most 4 chunks, as Coastline always did.
  - Normandy now builds 4 of 4 and is dark everywhere it should be. From game height it looks the same.
- **Screenshot:** `debug_out/screens/fog_normandy.jpg`.

## Summary (2026-10-23, beams glance off shields)

- **Deflection (C-129), from your sketch:** a beam that ends on a shield dome's surface is drawn as two legs: up to the dome, then a shorter one mirrored off the surface and angled down into the ground nearby, fading with the beam.
- It shows up once sim-A stops beams at domes (**sim request 50**). Today beams still pass through, so there was nothing to screenshot yet.
- **sim-A built request 49 (S-115, merging):**
  - Radiance pierces: every enemy on its fixed 3 s line takes damage;
  - manual targets stay until STOP, a new attack order or the target's death; the unit fights on its own while the target is out of range.

## Summary (2026-10-23, Radiance's ray)

- **Radiance (C-128):** a bluer beam, held about 3 s, its last second narrowing to nothing. Inferno stays orange and holds 1.5 s. Once sim-A's `beamDuration` is in main, the client draws exactly the sim's duration.
- **Sim work (requests 47 and 49) with sim-A:**
  - Radiance targets radar blips and can miss them without Pinpointers (S-113, merging);
  - a hit-ray damaging every enemy on the line, for 3 s (request 49);
  - manual targets override (request 49).
- **Beam VFX:** models-C builds them, at your request; mine is a placeholder ray until then.
- **Screenshot:** `debug_out/screens/beam_radiance.jpg`.

## Summary (2026-10-23, beam towers apart)

- **Inferno's beam stays orange:** I made it green (C-127), then put it back at your word.
- The rest of your note (Radiance targets radar blips and can miss them without a Pinpointer, a lingering high-damage beam; Inferno shorter and weaker) is sim work: **sim request 47** is with sim-A. Once they name the beam's duration, I'll hold the drawn beam that long.
- A note on C-126: its first suite run had 1 failure that didn't come back in 3 reruns (213/213 each). It ran while you were playtesting; I couldn't see which spec it was.

## Summary (2026-10-23, cheat line arrow keys)

- **Cheat command line (C-126):** while suggestions show, Up / Down move through them, and Tab or Enter takes the highlighted one; with none showing they walk the history as before. Not checked in Studio (you were in a playtest); the camera already ignores the arrow keys while you type.
- **Camera:** unchanged by your choice: middle-drag (and the arrow keys when not typing).

## Summary (2026-10-23, C's deposit models in; Needs my review)

- **Merged m-models** (models-C's deposits, interceptor missiles, effect textures, animated blockout pieces, S-104-scaled and anti-nuke blockouts). test_client stays green and the materials file has the three deposit variants.
- **Deposit models, at review:** with them switched on (`Invoke("depositsanyway", true)`), every deposit is one of C's three variants at its own turn, a dark scraped patch with pale rocks.
  - Grass blades covered the low rocks, so deposit cells are now bare ground in the terrain.
  - The patch is tinted with the real colour of the terrain around it.
  - They read quite dark at night. **Needs my review:** approve them (C flips the status and they replace the plain patch everywhere) or ask C for lighter patches.
- **Screenshot:** `debug_out/screens/deposit_models.jpg`.

## Summary (2026-10-23, HUD layout, developer mode, unit panel)

- **HUD (C-124):**
  - Settings (O) is in the top right corner.
  - The Follow (T) button is gone. T still follows the selection, but only in **developer mode**, a new toggle in Settings > Interface (on by default in Studio, off in a live game).
  - The F3 debug readout is in the bottom right.
  - Settings > Keys lists T and F3 under "Developer mode".
- **Unit panel (C-125):**
  - the portrait is the unit's model at an angle with its type icon bottom right, like the build menu's tiles;
  - under the health bar, instead of HP numbers, it shows what the unit adds to or takes from the economy right now: supply in white, power in yellow ("+5", "−10").
  - The wire has no per-unit flow, so the client works it out from the defs and what it sees: an extractor's deposits, generators, wind, converters, radar upkeep, and a factory or builder at work (the item's cost at its buildpower, slowed by a stall). Own units only.
- **Screenshots:** `debug_out/screens/unitpanel_plant.jpg` (Settings top right, F3 bottom right, a plant building Lancers: −6.7 / −67), `unitpanel_fusion.jpg` (+250 power).

## Summary (2026-10-23, deposits without the yellow squares)

- **Deposits (C-123):** the neon squares are gone. Each deposit is now a dark, subtle patch of scraped ground with a few stones, tinted from the terrain under it, with no glow.
  - C's deposit models (`fx.deposit`, 3 variants) replace the patch automatically once you approve them. Each deposit gets its own variant and turn, and C's ground patch is tinted to the terrain. models-C is building them today.
  - A structure built on a deposit hides it; it comes back when the structure is gone.
- **Overlay, only when it helps (BAR's metal view):**
  - while you place an extractor, free deposits get a soft ring with the yield your extractor would take ("+2.0");
  - deposits other players hold get a dim marker, and your own show nothing;
  - **F4** shows the same overlay any time, with each deposit's value. It's listed in Settings > Keys, with the extractor drag.
- **Minimap:** small neutral rings for deposits, filled with the holder's team colour when taken (yours in your colour).
- **Screenshots:** `debug_out/screens/deposit_normal.jpg` (patches, a deposit hidden under your extractor, minimap rings, one filled), `deposit_overlay.jpg` (placing an extractor), `deposit_f4.jpg` (F4).

## Summary (2026-10-23, minimap icons; anti-nukes coming)

- **Minimap icons (C-122):** units on the minimap now show their type icon instead of a dot, the same icons as the zoomed-out view, about 11 px.
  - Ghosts are faint, the selection is lightened and drawn on top, and units under attack blink red.
  - Radar blips with no known type stay dots.
- **Screenshot:** `debug_out/screens/minimap_icons.jpg` (shield scene, enemies shown with /reveal).
- **Sim request 46 is built (S-111, merging):**
  - radar SAMs shoot only aircraft and one-shot every T1 aircraft;
  - new anti-nukes: Providence / Cerberus (structures, 3 interceptors, 18 s / 15 s between shots) and Custodian / Chimera (mobile, 1 interceptor, only while stopped);
  - each intercepts any enemy nuke aimed inside its cover, with a certain hit, so two nukes on one spot get one through.
  - I'll do their client side (icons, cover ring, stock and shot delay, blockouts from models-C) once it's in main.

## Summary (2026-10-23, extractor upgrades in place)

- **Upgrading extractors (C-121).** A T2 builder can now build an advanced extractor on top of your own T1:
  - **Placing:** while you place an Advanced Extractor, every T1 extractor it can upgrade gets a pulsing green disc. The ghost snaps onto a T1 near the cursor and draws over it.
  - **Shift-drag:** with an extractor ghost, a drag is now a circle (as in BAR's area extractor), not a row. It queues an extractor on every free deposit and every T1 it upgrades inside the circle, nearest the builder first.
  - **"Upgrade" on the command card:** T2 builders only. Drag a circle to queue an upgrade on every own T1 inside it, nearest first, or click an extractor to upgrade just that one.
  - **Build menu:** the tile has a green "▲ UPGRADE" badge, and the tooltip says "Upgrades a T1 extractor in place".
- **sim-A's S-108 is coming with S-104** and changes the rules. The client already follows it, falling back to today's rule until it merges:
  - upgrades are listed per def (`upgradesFrom`), and only your own extractors qualify;
  - the T1 keeps producing under the frame and leaves only when the T2 finishes;
  - the T1 is 2×2 and the T2 3×3, so the build goes on the deposit cell.
  - The nanoframe (next task) will draw over the T1.
- **Two fixes found while testing:**
  - The build ghost of a blockout model left all its parts but the base far away (they're anchored, not welded); the ghost now moves the whole model.
  - Queued builds on a spot where a T1 stood dropped off the waypoint display at once.
- **Sim request 46** (your SAM and anti-nuke message) is filed with sim-A.
- **Screenshots:** `debug_out/screens/upgrade_targets.jpg` (discs, badge, Upgrade button), `upgrade_ghost.jpg`, `upgrade_area.jpg` (the Upgrade circle), `upgrade_started.jpg`, `upgrade_drag.jpg` (an extractor Shift-drag).

## Summary (2026-10-23, cheats work)

- **The cheat commands are live (C-120)**, now that sim-A's S-102 is in main. Tested in Studio:
  - `/give Lancer 3` places 3 Lancers at the cursor (the log shows "→ give ord_lancer 3 at 43,24");
  - `/res all max`, `/god on`, `/reveal on`, `/kill selected`, `/kill 2`, `/speed 2` (the game really runs at 2×) and `/speed 1` all work;
  - mistakes say why in red ("unknown unit", "speed must be 0.25..8", "no AI on that team").
- **Results:** green when a command worked, red when it didn't.
- **"Cheats used":** the statistics Overview says "CHEATS USED (name ×n)" next to the match length, and a saved replay's name ends in "· cheats used".
- **Log:** on a short window it shows only the newest lines that fit, so it never covers the resource bar.
- **Screenshots:** `debug_out/screens/cheats_results.jpg`, `cheats_autocomplete.jpg`, `cheats_kill_speed.jpg`, `cheats_stats.jpg` (the stats panel shown with sample results, since a test profile never ends).

## Summary (2026-10-23, cheat command line; shield hits)

- **Cheat command line (C-119), BAR's /cheat:**
  - Press Enter or "/" and type. Suggestions appear as you type: commands, then units by id or display name ("/give lanc" offers the Lancer). Tab takes the first.
  - "/help" lists every command with an example. Results print in a log above the bar.
  - "at" defaults to the cursor, and Ctrl+Shift+G repeats the last /give at the cursor.
- **Until sim-A's S-102 is in main, the bar is a stub** that says what it would send. sim-A built the commands themselves (S-102: give, res, income, instabuild, reveal, god, kill, speed, ai), and they're integrating now. I'll hook them up next.
- **Who may cheat:**
  - only players on the allow list (`src/roblox/CheatConfig.luau`: your UserId);
  - only in Studio, or in a match where the host turned on the new lobby toggle "Cheats" (off by default);
  - anyone else's cheat commands are dropped on the server before the sim sees them.
- **/cheat on|off** flips that lobby toggle (host only). sim-A has asked you whether it should also work mid-match.
- **"Cheats used" on results and replays** comes with S-102's flags.
- **Shield hits:** dimmer ripples, bigger hex patches (C-117), and each hit now sends a visible wave through its patch instead of freezing it lit (C-118).
- **Screenshots:** `debug_out/screens/cheats_*.jpg`, `shield_hex_*.jpg`.

## Summary (2026-10-23, T2 beam towers in game)

- **Beam towers (S-96 + C-112):** Radiance (Order) and Inferno (Chaos), Pulsar-style.
  - **The beam:** a bright held line from the barrel to the target, ice-white for Order and hot orange for Chaos, fading over half a second, with a charge flash at the barrel and a heavy impact.
  - **On / Off:** the command card shows a real On / Off for them. Off retracts the tower: the turret sinks into its shell, the barrel folds and the lids close. It can't fire and takes a quarter of the damage (sim). On raises it again.
  - **Commands:** a beam tower shows Fire state, On / Off, Stop and Attack.
  - Each shot costs 700 power from your stores.
- **Flak towers** (Lumen, Hailstorm) work as normal defenses.
- **Icons:** all four use existing icon tiles for now (beam towers: Heavy Turret; flak towers: IR SAM Site). No icon re-import needed.
- **Models:** the towers draw as models-C's blockouts (C-113), and retract with closing lids; BAR meshes come next.
- **Screenshots:** `debug_out/screens/beam_radiance.jpg`, `beam_tower_on.jpg`, `beam_tower_off.jpg`.

## Summary (2026-10-23, per-unit commands, factory orders, top strip)

- **Each unit gets its own commands (C-109):** the command card shows only what the selection can do, and shrinks to fit.
  - defenses: stop, attack, fire state (plus on / off once request 43's towers exist);
  - builders: movement, stop, repair, reclaim (E, then click a wreck), guard to assist;
  - silos: stop (the launch) and attack (a manual launch);
  - tanks, aircraft and ships: movement, attack, fire and move state;
  - factories: repeat, cancel, and Move / Fight / Patrol / Guard as orders for the units they build;
  - a mixed selection gets the union.
- **Factory orders for new units:** the sim keeps one rally point today, so I asked sim-A for a full order queue per factory (request 44: pre-move, then guard or patrol). The client already offers the orders on factories and keeps drawing them until replaced.
- **Roblox top bar gone where Roblox allows it:**
  - chat, player list, backpack and health are off;
  - the resource bars and debug overlay moved up into the top strip;
  - Settings sits in the upper-left corner (Resign will join it).
  - **Not removable:** Roblox's own menu button keeps the first ~164 × 58 pixels of the top left (measured: `GuiService.TopbarInset`), even with the top bar disabled, so the minimap starts right under it instead of at the very top.
- **Minimap:** smaller, 220 pixels (was 280); the build menu follows it up.
- **Missile meshes:** `lune run mesh_materials` now also covers C's effect meshes (missiles, shield emitter) for when they're approved.
- **Screenshots:** `debug_out/screens/hud_topstrip.jpg`, `minimap_220.jpg`.

## Summary (2026-10-23, build menu portraits, turn fix, shield and defense requests)

- **Build menu, BAR style (C-107):** each tile shows the unit's model at a three-quarter angle (the BAR mesh, or its blockout until the mesh loads), its type icon at the bottom right, and its cost stacked at the bottom left (supply white, power yellow). Four larger tiles per row.
- **Hover a tile** to see its name, description, cost and build time at the selected builder's power ("51s at 100 buildpower"), health, weapons (DPS, range, reload) and speed / sight.
- **"Off" on factories:** only converters use the on/off switch, so every factory showed "Off" in red. Units that can't switch now show a neutral grey "On / Off".
- **Turrets turning the long way:** the client drew turret turns straight from one angle to the next. Aims crossing ±180° (170° to −170°) swung 340°. Turns now take the short way. The server's aim already did; the client also extrapolated a turning hull the long way across ±180°, now fixed too.
- **Sent to sim-A (requests 42, 43):**
  - **Shield, made simple:** destroy every projectile on contact.
  - **Build speed:** a Lancer takes 51 s at the vehicle plant; asked to roughly halve T1 build times or double the plants' power.
  - **T2 defenses** (you corrected T3 to T2): a Pulsar-style beam tower per faction (long-range precise beam, heavy hit, big power cost per shot; switched off it retracts into an armored shell), then more T2 defenses.
- **Sent to models-C (request 2):** the beam tower meshes. C proposed pieces with the retract pose and queued them after the T1 aircraft.
- **When those land, client side:** the beam effect (your reference: a thin bright line from the barrel), the retract pose, the on/off button.
- **Screenshots:** `debug_out/screens/buildmenu_tooltip.jpg`, `buildmenu_structures.jpg`.

## Summary (2026-10-23, your C-103..105 review follow-ups)

- **Your review (2026-10-23):** C-103, C-104 and C-105 approved.
- **Modal panels (C-106):**
  - settings, lobby and statistics are 95% opaque with a dark scrim over the game;
  - they sit above every HUD screen, the F3 overlay included, so nothing draws through;
  - clicking the scrim closes the settings.
- **Panels fill their space:**
  - statistics is a 3 × 2 grid of charts that fills the panel: Economy (supply and power produced, used, stored), Combat (damage dealt and taken, units killed, built, lost and alive);
  - the settings and lobby panels size to their content (Graphics is no longer a full panel with three rows).
- **Graphics settings:** "Detailed models" On/Off (Off draws blockouts and loads nothing), "Glow" Off/Low/High, "Headlights" On/Off. The detailed-models request wasn't anywhere in the repo, so it's new here.
- **Model loading:** types drawn on screen load first, then every type in the match, then your faction, then the rest. Measured on the `fog` profile: the Order vehicle plant ready at 2.5 s and the Mason, Herald and Lancer by 5.3 s (they were 16–19 s, alphabetical behind Chaos). The whole set still takes about 18 s, in the background.
- **Glow against team color (your second message):** with C's clash table, an Order unit on cyan (team 7) and a Chaos unit on orange (team 6) show their running and power glow white; head and weapon glow stay. Checked in a match.
- **Factory pulse capped at 3** (was 4): at 3.9 the Order vehicle plant's door bloomed into a white block. At 3 it's still bright. Screenshot pair below. You confirmed 3 (2026-10-23).
- **Statistics data from the sim:** sim-A delivered request 41 (S-88, `Stats.series`), so my stopgap sampler is gone and "Damage · Taken" now has data.
- **Screenshots:** `debug_out/screens/uikit2_*.jpg`.

## Summary (2026-10-23, UI kit, settings, statistics, lobby)

- **UI kit (C-105):** one theme module, `UI/Kit`, used by every panel.
  - **Look:** dark translucent panels (85%), a thin light border, a soft shadow and a faint diagonal stripe. The stripe and shadow are our own, drawn in-game, with no textures or icons copied.
  - **Text:** light-grey in Montserrat (Roblox's built-in geometric sans, the closest to the reference), one warm amber accent, rounded corners, a type and spacing scale.
  - **Components:** panel with title and sidebar nav (highlighted pill), toggle (green on, red off), slider with value, dropdown, segmented buttons, filter chips with team swatches, thin scrollbar, table, line chart.
- **Settings** rebuilt on it: sidebar Camera, Graphics, Interface, Audio (nothing yet: the game has no sound), Keys. Real sliders and toggles replace the +/- steppers; keys are a clean two-column table. Same settings and saving.
- **Statistics panel** replaces the results screen:
  - sidebar Overview, Economy, Combat, Units;
  - chips All, You, Team 1, Team 2 with team swatches;
  - small line charts over match time: supply and power produced, used and stored; units built and lost; damage dealt; units killed;
  - Overview is the styled scoreboard under VICTORY / DEFEAT.
- **Statistics data:** the sim keeps no samples over time, so the Roblox server samples its report every 10 s for now. I filed sim request 41 for real samples with damage taken; until then that chart says it's waiting.
- **Charts:** at most 120 points per line, drawn into one EditableImage per chart (measured against pooled Frames below), one chart per frame, and the panel is built once. Opening it doesn't hitch.
- **Lobby** rebuilt on the kit. The unit panel, command card, build menu and resource bar take the kit's colors, font and borders.
- **Your 7 new reference images** (lobby, scenarios, in-game HUD, two settings panels, radar range, factory facing): written up in `docs/ui/references.md` with a "still to do" list for later UI work.
- **Screenshots:** `debug_out/screens/uikit_*.jpg` (settings, statistics, lobby), at the Studio viewport (1548 × 601: Studio can't be set to 1080p from here) and at UI scale 1.2. Panels shrink to fit the screen and scroll.

## Summary (2026-10-23, glow pass and BAR models in game)

- **BAR models now draw in the game (C-103):** the client builds every approved model from C's mesh manifest at start: 19 models, about 21 s in the background, with blockouts standing in until each one is ready. Oracle, Watcher and the Order vehicle plant are still "review" in the manifest, so they stay blockouts.
- **Full materials:** game scripts can't set a SurfaceAppearance's maps or emissive mask (Roblox's Plugin capability). Rojo can, so a generated `place/MeshMaterials.model.json` holds one appearance per model plus the glow mask, and the client clones them. That gives full PBR, team paint and real emission.
- **Your glow pass:**
  - **Power:** structures dim on an energy stall (rest × ratio, floor 0.3).
  - **Factories** pulse 1.5–4 once a second while producing (measured: 1.51 → 3.99).
  - **Weapons** flash to 6 per shot and settle over 0.3 s (measured peak 6.0).
  - **Unfinished units** stay dark.
  - **Headlights:** shadowless SpotLights on the 12 nearest on-screen vehicles (the quality's light budget) at close zoom or in the night and dusk atmospheres.
- **Measured with 200 units** (100 Lancers against 100 Ravagers): 146 glowing models drawn, 615 glow parts, the glow driver 0.19 ms a frame (worst 0.76), 21 writes a frame, 60 fps held.
- **Screenshots:** `debug_out/screens/glowfx_*.jpg` (vehicles, headlights, factory, stall full and low, fight, 200 units).
- **Not done:** builders brightening while they build. The client doesn't know when a builder is building (no field on the wire).
- **Shield hits fixed (C-104):** one shell looked like 5–6 hitting at once. Each shell lights the dome exactly once (measured), but its 7 hex plates were all near full white and bloomed into separate blobs. Now the centre plate is bright and each ring out is 30% as opaque and greyer, so a hit reads as one impact (`shieldhit_before.jpg` / `shieldhit_after.jpg`).
- **Next:** your UI kit, settings, statistics and lobby task: done as C-105, summary above.

## Summary (2026-10-23, environment and colour grade)

- **Colour grade (C-102, your "most impressive part"):** a moonlit teal grade, deeper blacks and brighter whites, with a soft vignette framing the view.
  - It eases off as you zoom out, so the strategic view stays readable.
  - Big blasts near the camera (a nuke, a large unit's death) warm and brighten the whole picture for a moment. Impacts never flash, so a busy fight doesn't flicker.
- **Night sky:** stars, a moon and a faint blue glow on the horizon, instead of the place's day skybox.
- **Map edge:** the bright blue void past the border is now dark ground fading into the haze, at every zoom.
- **Terrain colours:** cooler, duller greens and rocks that the grade turns moonlit.
- **Ambient particles:** dust motes drift in the moonlight and a faint low mist hangs near the ground, at close zoom only and off at Low quality.
- **Fog of war is grey now (your call):** never-seen ground is a flat grey haze, explored ground a lighter grey wash. The near-black fog hid the ghost structures; they now read clearly as see-through blue-grey copies.
- **Fixed:** the settings menu's fifth atmosphere button (Dusk) was cut off. The buttons are narrower, and "Battlefield haze" is now "Battle haze".
- **Screenshots:** `debug_out/screens/environment_*.jpg`: 35°, 55°, 80°, strategic zoom, the sky, ghosts, a night battle, and a before/after pair.
- **Next:** your glow pass. C's glow assets are now in main (M-22).

## Summary (2026-10-23, night lighting)

- **Your review of C-100 (2026-10-23):** you tested the fog blanket, "Look good", and it is the default fog of war. Removed from "Needs my review".

- **Night by default (C-101):** you said the maps have no sun, so the default atmosphere is now a moonlit night: midnight sky, no sun rays, cool neutral light bright enough to read every unit, soft shadows.
- **Less "plastic":** the sky reflections on terrain, units and the fog blanket are cut to 15% (EnvironmentSpecularScale 0.15), and the light is softer and duller. The shell over steep rocks still shows but is far calmer.
- **Fog of war under night light:** "explored" is lighter (grey 40 at 40%, was 30 at 52%), otherwise it looked like never seen. All three states read apart, close and at strategic zoom.
- **Glows stand out:** bloom picks up shells, fire, and the shield dome.
- **Choice kept:** the settings menu still offers Current (the place as saved), Clear day, Battlefield haze and Dusk.
- **Screenshots:** `debug_out/screens/lighting_*.jpg`: 35°, 55°, 80°, strategic zoom, a before/after pair (the place's day lighting vs night) and a shield battle at night.
- **One thing for you:** set Lighting → Technology to **Realistic** in the place, if it isn't already (Roblox merged Future into Realistic). Scripts can't read or change it, and Realistic gives the soft shadows and the glow lights their best look.
- **Not started:** your glow pass still waits for C's glow assets.

## Summary (2026-10-23, fog of war blanket)

- **Fog of war, BAR style (C-100):** normal lighting everywhere; what your team can't see is darkened by a "fog blanket" draped over the terrain. Visible ground is clear, explored ground desaturated grey (about 40% darker), never-seen ground about 70% darker. Edges are soft, and pixels fade over 0.3 s.
- **Built on one image per map:** a pixel per grid cell, written live from the team's sight on the wire. The minimap shows the same image.
- **Old fog removed:** the point-light fog and its plates are gone, with no fog lights and no lighting changes. The settings menu's "Fog lights" is now "Fog of war" (on by default).
- **Roblox limits:** checked and worked round, details below.
  - Editable images and meshes work in published games with the Mesh / Image APIs setting on (you turned it on).
  - A SurfaceAppearance can't be fed from a game script, so the image is the mesh's own texture, with the part 2% transparent so its alpha blends.
  - The device's editable-mesh memory budget forced a vertex every 16 studs: 4 meshes for a 128-cell map.
- **Cost:**
  - at rest: 0.013 ms per update;
  - a big battle (5% of the map's sight changing every update): about 1.5 ms per update in Lune;
  - the worst case, the whole map flipping every update: 15.5 ms per update in Studio, 4.9 ms in Lune.
  - Updates run at most 15 times a second, and a per-update pixel cap spreads huge changes over several updates.
- **Screenshots:** `debug_out/screens/fogblanket_*.jpg` on ridgeline: 35°, 55°, 80°, strategic zoom, and a before/after pair.
- **Not started:** your glow pass waits for C's glow assets; realistic lighting is next, as you asked.

## Summary (2026-10-23, shield domes)

- **Shield mechanic:** decided with you and handed to sim-A to build (request 40). The decisions:
  - shield generator structure only;
  - Order and Chaos both get one, Chaos's dome smaller;
  - bounced shells stay live;
  - full force from 50% charge;
  - collapse at 0%, rise at 25%.
- **Client side:**
  - **Prototype (C-87 to C-89):** the repulsor field, hexagon hits, plasma core and capacity bar, the `shield` test profile.
  - **`Render/ShieldFx` (C-90):** your interface (`new`, `deploy`, `setStrength`, `hit`, `collapse`, `destroy`), with the deploy, up, hit, low and collapse states.
  - **Performance rules:** fixed pools, one render loop, off-screen skip, strategic detail.
  - **Placement:** generators sit upright on the terrain.
- **Measured** (table under C-90 below): 20 shields on screen cost 1.9 ms a frame of render-loop CPU at close zoom, 0.34 ms at strategic zoom, 0.07 ms off screen.
- **Waiting on:**
  - sim-A: request 40, the shield on the wire;
  - session C: the shield assets (`docs/contracts/fx.md`, `assets/fx/shield/roblox_assets.json`).

## Summary (overnight run, 2026-10-22 → 23)

**Your list is done.** Server alerts landed overnight (C-85); you imported the draft 3 sheet and ran the 2-client test the next morning (C-86). Each item is committed, pushed and marked "Ready to merge" below. sim-A has already integrated C-75 to C-80 into main (`a21d325`).

| # | What | Decision | Proof |
|---|---|---|---|
| 1 | Current work: request 36 used (server queues, fire / move states, ammo); icon sheet draft 3 built | C-75, C-74 | `OwnerFields.spec` (client = server every tick); sheet `assets/icons/ftgg-icons.png` |
| 2 | Unit stats in the unit panel, enemies by hover, knowledge rules | C-76 | `UnitStats.spec` (Lancer vs armored), `c76_*.jpg` |
| 3 | Two humans: lobby seats, host, factions, rejoin into the seat; `duo` profile | C-77 | `TwoPlayers.spec` (two client stacks: join, fog, commands, combat, win), `c77_*.jpg`; your 2-client Studio test (C-86): both seated, host-only lobby, a match on crossroads, `c86_duo_player*.jpg` |
| 4 | Robustness: late join, rejoin, restart; the stale selection after a restart fixed | C-78 | `Robustness.spec`, `c78_rejoined.jpg` |
| 5 | Spectators (no seat → watch everything) and the replay viewer (save, watch, pause, 0.25–8×, seek, exit) | C-79 | `Replay.spec` (every seek = the live view), `c79_*.jpg` |
| 6 | Lobby choices (faction, AI level per seat, named maps) and results with the sim's statistics | C-77, C-80 | `Lobby.spec`, `c77_results_stats.jpg` |
| 7 | Settings menu (O): camera, graphics quality, fog lights, atmosphere, UI scale, keys | C-81 | `Settings.spec`, `c81_*.jpg` |
| 8 | Server alerts (request 39 landed overnight), under-attack blinking | C-85 | `Ui.spec`, `c85_server_alerts.jpg` |
| 9 | Nuke crater (Terrain, put back on a new match), water splashes | C-82 | `Splash.spec`, `c82_nuke_crater.jpg`, `c82_crater_close.jpg` |
| 10 | Atmosphere presets as options (Current stays the default) | C-83 | table with GPU / CPU cost and `c83_atmosphere_*.jpg` |
| + | Requests 37, 38 used (live flares / chaff; sim statistics), S-62 Pinpointer weights followed | C-80 | `OwnerFields.spec`, `c80_charges.jpg` |
| + | Warden deploy and Minotaur ram animations (S-64); their icons fall back to the Main Battle Tank | C-84, C-74 | `Deploy.spec`; no Studio image until the models stream's blockouts land |
| + | Sound plan with candidate audio IDs, nothing inserted | — | `docs/SOUND_PLAN.md` |

**Tests at the end:** `lune run test_client`: 43 specs, 143 passed, 0 failed. `lune run test` (sim): 53 specs, 355 passed. `lune run build`: 415 scripts compile, every require resolves.

**What I need from you:**
1. ~~Import the draft 3 sheet~~ (done: `87919807696998`, C-86).
2. Add catalogue entries for the Warden, Minotaur, Locust, Cyclops, Barrier and Citadel to the icon HTML (drawn with stopgap icons until then), and look again at the gun turret vs floating turret pair (C-86).
3. ~~Run the 2-client test~~ (done, C-86).
4. Review the "Needs my review" list: settings defaults, UI placement, atmosphere options, sound picks.

## Summary (night run, 2026-10-21)

**All nine queued tasks are done, committed, pushed and in the merge queue below.** Tasks 1–5 were verified in Studio playtests; Studio then closed its place (the instance reports "Place is not open"), so tasks 6–9 are verified headless only: Lune specs against the real sim, plus headless renders of the real client's view (C-15). Nothing was done to repair Studio.

| Task | What | Commit | Verified |
|---|---|---|---|
| 1 | Rojo live sync (`lune run serve` + `rojo serve serve.project.json`), in-Studio test entry | `f815a5d`, `7bbaa7b`, `89e7db1` | Studio: 34 specs, 253 passed |
| 2 | Contracts `rig.md`, `client-state.md` | `a96cca2` | — |
| 3 | Blockout generator; Lancer and Ravager; generic blockouts for all 123 defs | `2062b10` | Lune + Studio (Edit) |
| 4 | Client foundation: client World, NetIn, interpolation, model pool, RTS camera, minimal server entry | `df29a2d` | Studio playtest: tanks drive and fight from the real sim |
| 5 | Selection, control groups, smart right-click, Shift queue, line move; protocol 6 join | `f52bf53` | Studio playtest with real mouse / keyboard input |
| 6 | Build placement ghost: snapping, validity tint, rows | `47aaa63` | Lune (client check = server check on 750 spots) + headless render |
| 7 | Combat effects with guide 15.3's caps | `afe8aea` | Lune (shells within 0.5 studs of the server) + headless render |
| 8 | Strategic zoom icons | `b8405ff` | Lune + headless render |
| 9 | Placeholder minimap and resource bar | `508b215` | Lune + headless image (GUI not rendered) |

**Tests:** `lune run test_client`: **7 specs, 31 passed, 0 failed**. `lune run test` (sim): 36 specs, 270 passed. `lune run build`: 304 scripts compile, every require resolves.

**Images** (`debug_out/screens/`, gitignored): `task4_brawl_topdown.png`, `task5_selection_orders_topdown.png` (from live playtest dumps); `task6_build_ghost_valid.png`, `task6_build_ghost_invalid.png`, `task7_combat_effects_headless.png`, `task8_strategic_icons_headless.png`, `task9_minimap_resourcebar_headless.png` (headless). Studio's own `screen_capture` only ever showed the GUI over a black 3D view (`task4_studio_capture_black3d.jpg`), so no true screenshot exists yet.

**When Studio is back (first thing to do):** play the `duel`, `march` and `build` profiles in `src/roblox/MatchConfig.luau` (`ACTIVE`) and check what the headless runs can't: the build ghost's Instances and keys (B, R, Esc), particles and effect frame cost (guide 18.2), the icon layer and the zoom switch, the minimap and resource bar layout and clicks; then take real screenshots.

**Needs your review:** camera feel, controls, visual style, UI layout, effects look, strategic zoom (section below).

**Requests for the sim session:** 5 open (section at the end): bomber `bay` pieces; formation slots, placement rules and icon numbering in Shared (the client copies them, tested equal or close). Request 2 (unit state bits) was done by S-6.

## Merge queue

- Ready to merge: `a2371cd` (CLAUDE.md: Studio is available to the client session only; the sim stays headless and is tested with `lune run test`).
- Ready to merge: `f815a5d` (task 1: Rojo live sync and the in-Studio test entry; touches `CLAUDE.md`, both project files and the skill).
- Ready to merge: `7bbaa7b` (separate `build/serve` and `build/ci` folders, `lune run serve`; touches `.lune/`, `CLAUDE.md`, the project files and the skill; C-3).
- Ready to merge: `89e7db1` (Studio check of the serve sync; polling notes in `CLAUDE.md` and the skill).
- Ready to merge: `a96cca2` (task 2: `docs/contracts/rig.md`, `docs/contracts/client-state.md`; C-4..C-6).
- Ready to merge: `2062b10` (task 3: blockout data and generator, `lune run test_client`; adds a line to `CLAUDE.md`).
- Ready to merge: `df29a2d` (task 4: client foundation and minimal server entry; touches `CLAUDE.md`, `STUDIO_HANDOFF.md`, new `.lune/render_view.luau`).
- Ready to merge: `f52bf53` (task 5: selection, orders, protocol 6 join; touches `CLAUDE.md`, new `.lune/render_scene.luau` (replaces `render_view`)).
- Ready to merge: `47aaa63` (task 6: build ghost; adds `.lune/client_demo.luau`, a line in `CLAUDE.md`).
- Ready to merge: `afe8aea` (task 7: combat effects with caps; `.lune/client_demo.luau` and `render_scene.luau` updated).
- Ready to merge: `b8405ff` (task 8: strategic zoom icons; `.lune/client_demo.luau` and `render_scene.luau` updated).
- Ready to merge: `508b215` (task 9: placeholder minimap and resource bar; touches `STUDIO_HANDOFF.md`, `CLAUDE.md`).
- Ready to merge: `002cc39` (night run summary at the top of `docs/progress/client.md`).
- Ready to merge: `90c387d` (client uses Shared PlacementRules and Net/Icons).
- Ready to merge: `5563c15` (step 2: readable shells, effect diagnostics (C-18)).
- Ready to merge: `6cff90b` (line-move goals from Shared Formation).
- Ready to merge: `142b5c6` (step 3 and 5: range rings, target line, BAR controls; `.lune/render_scene.luau` draws ring arcs).
- Ready to merge: `3e2066b` (step 4: tasks 6-9 re-verified in Studio; Esc removed).
- Ready to merge: `b207ca1` (extractor placement on deposits (C-22)).
- Ready to merge: `486fc51` (queued builds (C-23); request 7: build ranges).
- Ready to merge: `2fa0039` (Health and build bars (C-24)).
- Ready to merge: `9abe9b0` (Exact target line from S-16 (C-25)).
- Ready to merge: `f5740e0` (Explosion delay after a hit (C-26)).
- Ready to merge: `a602502` (Shells from the barrel tip (C-27)).
- Ready to merge: `9254e74` (Task 1: terrain from the map layers (C-28)).
- Ready to merge: `f95efcc` (Smooth range rings (C-29)).
- Ready to merge: `49e983c` (Task 2: piece scripts and the Juggernaut (C-30)).
- Ready to merge: `e125dee` (Task 3: air and naval rendering (C-31)).
- Ready to merge: `dfdd0e7` (merge of `main` into this branch: resolves the `docs/progress/client.md` conflict with f5b8093 by keeping request 6 done and requests 7 and 8; test_client, test and build pass).
- Ready to merge: `4a98d03` (Task 4: fog of war in 3D (C-32)).
- Ready to merge: `9c6d2d1` (Juggernaut follows the server arm timing (C-33)).
- Ready to merge: `cc217a1` (merge of `main` with S-19 and S-20 into this branch; clean, test_client, test and build pass).
- Ready to merge: `6093f19` (Task 5: deaths and wrecks (C-34)).
- Ready to merge: `db75cf4` (Own team's Eco record (protocol 9)).
- Ready to merge: `b2d2095` (merge of `main` with S-21, protocol 9, into this branch; clean, test_client, test and build pass).
- Ready to merge: `ec6488d` (Playtest profiles (juggernaut, air, naval, radar)).
- Ready to merge: `7f38c53` (global sim speed for debugging, C-35; C-26 timing fix).
- Ready to merge: `89740cf` (smooth missile paths, C-36).
- Ready to merge: `6161783` (SAM test scene, slowed flight tests, fog darkening off, C-37).
- Ready to merge: `5d6c9e9` (curved missile paths, aircraft markers, clicking models, C-38).
- Ready to merge: `1b2866a` (merge of `main` with S-23, S-24 and the C-36, C-37 integrations; test_client 78, test 299, build passed).
- Ready to merge: `4a014e9` (missile sensor view, C-39).
- Ready to merge: `3671f2b` (recognizable missiles: model, smoke trail, exhaust glow, C-40).
- Ready to merge: `d8f67eb` (request 13 for the sim session: IR SAM misses; docs only).
- Ready to merge: `272b106` (merge of `main` with S-25 and the C-38 integration; test_client 81, test 299, build passed).
- Ready to merge: `486d468` (SAM scene reworked: bigger map, Thorns east, one Falcon flying in).
- Ready to merge: `b3c1d19` (range rings of known enemy defenses, C-41; request 13c).
- Ready to merge: `849486c` (merge of `main` with the final AI level report; test_client 82, test 299, build passed).
- Ready to merge: `f9cc4ed` (seeker cone in the missile sensor view, C-42).
- Ready to merge: `7c2180c` (SAM scene: the Falcon circles at x = 300).
- Ready to merge: `64472f6` (camera follow, C-43).
- Ready to merge: `d44e70c` (request 13d for the sim session: gradual decoy turn; docs only).
- Ready to merge: `7a7e2bd` (merge of `main` with S-26, S-27, S-28, protocol 11; with `8ca419a` test_client 85, test 304, build passed).
- Ready to merge: `8ca419a` (client missiles steer with the shared guidance, C-44; take it with `7a7e2bd`, or the client lags the server's guidance).
- Ready to merge: `4346a86` (move lines last until the unit arrives, C-45).
- Ready to merge: `2d244af` (missiles past the map's edge, C-46).
- Ready to merge: `d39ec8e` (SAM scene on flat:256).
- Ready to merge: `58187a7` (log C-45, C-46; requests 14-16 for the sim session).
- Ready to merge: `927a141` (detailed combat effects with ReplicatedStorage.Vfx templates, C-47).
- Ready to merge: `a8d794e` (merge of `main` with S-29..S-32) with `a9ef27b` (spec threshold); test_client 92, test 313, build passed.
- Ready to merge: `91a79a1` (aircraft crash, countermeasures by equipment, C-48; requests 17-19).
- Ready to merge: `37c6142` (airsam test profile: planes and helicopters against 5 SAMs).
- Ready to merge: `1ae6176` (health bars change on the hit's tick, C-49; airsam at normal health).
- Ready to merge: `073d5e7` (missiles keep their dying target until the hit is drawn, C-50).
- Ready to merge: `b66ff70` (merge of `main` with S-33..S-40, protocol 13) with `d69e3f8` (client follows requests 14-19, C-51); test_client 97, test 325, build passed.
- Ready to merge: `5c92bb0` (crashes leave their smoke, radar SAM missiles drawn big, C-52; request 20).
- Ready to merge: `d39244e` (merge of `main` with S-41, S-42) with `54f1532` (vertical-launch steering, C-53); test_client 98, test 326, build passed.
- Ready to merge: `ad0c3b1` (request 21 for the sim session: projectiles visible regardless of sight; docs only).
- Ready to merge: `6cafe85` (merge of `main` with S-43, protocol 14) with `9698380` (SHOT tracers, C-54); test_client 99, test 327, build passed.
- Ready to merge: `95ff932` `8b54138` (merge of `main` with S-44, S-45; the climb mirrored, C-55); test_client 99, test 327, build passed.
- Ready to merge: `186af86` `042e4c4` (merge of `main` with S-46; request 24 marked done); test_client 99, test 327, build passed.
- Ready to merge: `b031b63` `0728784` (merge of `main` with S-47, protocol 15; SAM stock pips, C-56); test_client 100, test 334, build passed.
- Ready to merge: `5d8a153` `d1ec2d3` (merge of `main` with S-48, protocol 16; nukes, interceptors, launch warning, A attack order, C-57; models request 1); test_client 102, test 339, build passed.
- Ready to merge: `209312d` `b408822` (nuke profile: Order economy to refill the stockpiles; C-57 queue line); test_client 102, test 339, build passed.
- Ready to merge: `4e991cb` (attack-mode arc preview, radar tracks on nukes, C-58; request 27 for the sim); test_client 103, test 339, build passed.
- Ready to merge: `a619e7d` `15cb953` (merge of `main` with S-49, protocol 17; building pip C-59, test weapon overrides C-60; request 28 for the sim); test_client 104, test 339, build passed.
- Ready to merge: `78d61cb` (request 29 for the sim: interception chance 0.2; docs only).
- Ready to merge: `b0a0293` (one launch notice, C-61); test_client 104, build passed.
- Ready to merge: `8f9e3e9` `2af545f` (merge of `main` with S-50; the nuke profile's interception override dropped, request 29 marked done); test_client 104, test 339, build passed.
- Ready to merge: `40656ab` `4446fed` (merge of `main` with S-51, protocol 18; nukes climb then turn, C-62; request 30 for the sim); test_client 104, test 340, build passed.
- Ready to merge: `48af47e` `99e8a8f` (merge of `main` with S-52; request 30 marked done); test_client 104, test 340, build passed.
- Ready to merge: `cfa1424` (reload test override, nuke profile launches every 2 s); test_client 104, build passed.
- Ready to merge: `82d0e5f` (large-scale battle profile `normandy`, formation spawns; request 31 for the sim); build passed.
- Ready to merge: `242cecc` (normandy: stronger economy, startResources); build passed.
- Ready to merge: `537ee67` `cafdbaa` `57ea548` (merges of `main` with S-53..S-55; radar rings always on, C-63; normandy on map:normandy; requests 31, 32 done, 33 sent); test_client 105, test 345, build passed.
- Ready to merge: `db5d469` (radar rings always on top, C-64); test_client 105, build passed.
- Ready to merge: `02237c5` `27eef6e` (merge of `main` with S-56; request 33 done, SAM scene specs); test_client 105, test 345, build passed.
- Ready to merge: `1f3d216` (fog from the server's sight, wrecks from WRECK records, C-65; requests 34, 35 for the sim); test_client 108, test 345, build passed.
- Ready to merge: `68b0641` `33a0b04` (merge of `main` with S-58, protocol 19; terrain from the sim's terrain layer and Normandy features, C-66); test_client 108, test 345, build passed.
- Ready to merge: `23adb8d` (a unique icon per unit type, C-67); test_client 108, build passed.
- Ready to merge: `7ed355e` (playable placeholder UI, C-68; request 36 for the sim); test_client 112, test 345, build passed.
- Ready to merge: `2e8d261` (camera pitch, C-69); test_client 112, build passed.
- Ready to merge: `4240ff8` (match flow: lobby, match against the AI, results, C-70); test_client 115, build passed.
- Ready to merge: `d76abd2` `3708a23` (merge of `main` with S-57, S-59; BAR-style layout and icon glyphs, C-71); test_client 115, test 349, build passed.
- Ready to merge: `d05f3c6` (radar precision from Pinpointers, C-72); test_client 116, build passed.
- Ready to merge: `12354ba` ("Accuracy 50%" wording, C-72); build passed.
- Ready to merge: `420adba` (icon layer writes only what changed, C-73); test_client 116, build passed.
- Ready to merge: `926e4a9` (the user's icon set on one sprite sheet, drawn in the game, C-74; includes the icon HTML commits `44dc172`, `a0e43e1`); test_client 119, test 350, build passed.
- Ready to merge: `994ba89` (factory queues, fire / move states and ammo from the server, request 36, C-75); test_client 122, test 350, build passed.
- Ready to merge: `8abbf6d` (unit stats in the unit panel, C-76; also the draft 3 icon commits `226ed70`, `c9ff356`, the sheet not yet re-imported); test_client 127, test 350, build passed.
- Ready to merge: `315ec04` (lobby seats for several humans, results with statistics, C-77; the 2-client Studio test not run); test_client 130, test 350, build passed.
- Ready to merge: `3101bcf` (rejoin, late join, restart: a new WELCOME clears the client's references, C-78); test_client 133, build passed.
- Ready to merge: `390df33` (spectators and the replay viewer, C-79); test_client 136, build passed.
- Ready to merge: `5aa4552` (requests 37 and 38 used, the faction pass followed, C-80; includes the merge of main at 1cbfb0d); test_client 137, test 355, build passed.
- Ready to merge: `8ce4923` (settings menu, C-81); test_client 140, build passed.
- Ready to merge: `cb7098f` (stable icon layout, S-64 units drawn as the Main Battle Tank, C-74 follow-up; includes the merge of main at a21d325); test_client 140, build passed.
- Ready to merge: `9fac768` (nuke craters and water splashes, C-82); test_client 141, build passed.
- Ready to merge: `c5888f5` (atmosphere presets as options, C-83); test_client 141, build passed.
- Ready to merge: `2d98701` (Warden and Minotaur piece scripts, deploy phases, C-84); test_client 143, build passed.
- Ready to merge: `6ea62c3` (alerts from the server, S-69 to S-73 followed, C-85; includes the merge of main at f487eea); test_client 144, build passed.
- Ready to merge: `a994ce5` (draft 3 icons wired in, S-75 units with stopgap icons, no build-menu error for units missing from the sheet, C-86); test_client 145, test 386, build passed.
- Ready to merge: `0a83686` (shield dome prototype, client only, C-87); test_client 156, test 386, build passed.
- Ready to merge: `0f8c297` (shield idle hexes keep clear of hit patches; hexagon mesh checked, C-88); test_client 157, test 386, build passed.
- Ready to merge: `e066303` (shield test scenario, neutral dome fading with charge, radius 120, C-89); test_client 157, test 386, build passed.
- Ready to merge: `7e2c5d7` (ShieldFx shield dome renderer, review generators, request 40, C-90); test_client 163, test 386, build passed.
- Ready to merge: `ff3e146` (shield domes from the server, protocol 24, real Phalanx in the shield profile, C-91); test_client 165, test 399, build passed.
- Ready to merge: `57a7610` (shield profile checked at 50x, docs only); test_client 165, test 399, build passed.
- Ready to merge: `f5774f4` (ShieldFx on C's shield assets, beam from the generator, shield debug counts, S-82 checked, C-94); test_client 165, test 400, build passed.
- Ready to merge: `f390838` (shield field inside the dome checked, docs only); test_client 165, test 400, build passed.
- Ready to merge: `eae1f16` (shield hits on entry, white-grey hexagons, thin rings from RingThin, C-95); test_client 165, test 400, build passed. RingThin's ID is on m-models (models-C), used by its asset ID.
- Ready to merge: `c4b6c67` (shield ripple on its first frame, shield_one profile, C-96); test_client 165, test 400, build passed.
- Ready to merge: `a1b6c7d` (force plumes on shells in a shield field, absorbed shells dropped (protocol 25), C-97); test_client 167, test 401, build passed.
- Ready to merge: `4f9fe7c` (shells in a shield field burn: bow shock and trail, C-98); test_client 167, test 401, build passed.
- Ready to merge: `92be867` (shield hits on the crossing frame, absorbed shells end mid-tick, unfinished units see-through, minimap 10 Hz, server build debug query, C-99); test_client 169, test 404, build passed.
- Ready to merge: `693a3b7` (fog of war blanket, point-light fog removed, fog profile, C-100); test_client 171, test 404, build passed.
- Ready to merge: `92b9a43` (night lighting by default, low specular, lighter explored fog, C-101); test_client 171, test 404, build passed.
- Ready to merge: `e8f5ce9` (docs only: Realistic lighting technology instead of Future; C-100 approved by the user).
- Ready to merge: `d4ab33b` (environment and colour grade: night sky, map-edge ground, ambient particles, zoom-eased grade with blast flash and vignette, grey fog, C-102); test_client 176, test 404, build passed.
- Ready to merge: `bdc88e8` (BAR models built from the mesh manifest with Rojo-written materials, glow driver and headlights, C-103; includes m-models `44880cc`; touches CLAUDE.md and the three project files, new `place/`); test_client 187, test 404, build passed.
- Ready to merge: `51e4d07` (one shield hit reads as one impact: faint outer hex rings, C-104); test_client 187, build passed.
- Ready to merge: `18195e5` (UI kit; settings, statistics panel and lobby rebuilt on it; server stat samples; sim request 41, C-105; touches src/roblox Main.server and Lobby); test_client 191, test 404, build passed.
- Ready to merge: `b5b5d48` (review follow-ups: modal panels, fitted layouts, graphics options, model load order, glow vs team color, pulse 3, Stats.series, C-106 `767ae09`; merged with main at protocol 26, includes m-models `0af6ed7`); test_client 192, test 407, build passed.
- Ready to merge: `ad2f474` (build menu portraits and stats tooltip, On / Off, short-way turns, sim requests 42-43, models request 2, C-107); test_client 193, test 407, build passed.
- Ready to merge: `bb644b9` (per-unit command sets, factory orders kept, Roblox top bar cleared and HUD in the top strip, sim request 44, C-109; also C-108 `0cfa7d0`: minimap 220, fx materials, includes m-models `764874b`); test_client 195, test 407, build passed.
- Ready to merge: `ecd03d2` (main with S-93 / S-94 merged; shield wire spec for heavy shells, C-110); test_client 194 (one unidentified failure in one of four runs, not repeated), test 409, build passed.
- Ready to merge: `01a59d5` (main with S-95 merged; factories offer Attack; FactoryOrders.spec, C-111); test_client 195, test 410, build passed.
- Ready to merge: `2a7b73f` (beam drawing, retract piece script and On / Off, stopgap icons for S-96 towers; fixes main's 2 icon specs; C-112); test_client 196, test 414, build passed.
- Ready to merge: `b915691` (S-96 tower blockouts merged from m-models `aafbf19`; retract checked, C-113; docs only besides the merge); test 414, build passed; test_client 196 (the intermittent failure was Ranges.spec's timing check under load, fixed in the next commit).
- Ready to merge: `ed5681f` (Ranges.spec timing check robust to machine load); test_client 196, test 414, build passed.
- Ready to merge: `96973a5` (S-96 tower meshes merged from m-models `1efc5e9`, `1429976`; retracted glow dims, C-114); test_client 197, test 414, build passed.
- Ready to merge: `1d738c9` (wreck meshes built and placed, wreck_<id> appearances, includes m-models `6b94586`, C-115); test_client 197, test 414, build passed.
- Ready to merge: `f6e9cea` (shield ripples from fixed-size emitters, C-116); test_client 198, test 414, build passed.
- Ready to merge: `a19380c` (dimmer ripples, bigger hex patches, C-117); test_client 198, test 414, build passed.
- Ready to merge: `7ac3622` (hex patches animate: waves per hit, glassy plates, C-118); test_client 199, test 414, build passed.
- Ready to merge: `bbaafa6` (cheat command line, gate, lobby Cheats toggle; stub until S-102; touches src/roblox Main.server, Lobby, new CheatConfig; C-119); test_client 202, test 419, build passed.

## Tasks

1. Studio sync (`STUDIO_HANDOFF.md` step 1) and an in-Studio test entry for `RunAll`. **Done 2026-10-21**, see below.
2. Contracts: `docs/contracts/rig.md`, `docs/contracts/client-state.md`. **Done 2026-10-21** (C-4, C-5, C-6).
3. Blockout generator (guide 20.2), `ord_lancer` and `chs_ravager` first. **Done 2026-10-21**: data in `src/shared/Defs/Blockouts/` (`Blockout`, `Registry`, `ord_lancer`, `chs_ravager`), builder `src/client/Render/BlockoutBuilder` + `Models` (C-6, C-8). `lune run test_client`: 5 tests pass, every def gets a valid blockout. In Studio (Edit): Lancer and Ravager build with 13 parts and 2 Motor6Ds each; turret, barrel and muzzle land exactly at their blockout positions (joint rest error 0). Screenshot pending: Studio's viewport renders black (window minimized or session locked?), retried in task 4.
4. Client foundation (guide 15): world table from NetIn, interpolation, model pool, RTS camera. **Done 2026-10-21**, see below.
5. Selection (box select, control groups) and commands (smart right-click, shift-queue, line move). **Done 2026-10-21**, see below.
6. Build placement ghost with snapping and validity tint. **Done 2026-10-21** (no Studio playtest: Studio was away), see below.
7. Combat visual effects from network events, with the caps from guide 15.3. **Done 2026-10-21** (no Studio playtest: Studio was away), see below.
8. Strategic zoom icons (15.4). **Done 2026-10-21** (no Studio playtest: Studio was away), see below.
9. A minimal minimap and resource bar, marked placeholder UI. **Done 2026-10-21** (no Studio playtest: Studio was away), see below.

## Task 1: Studio sync and in-Studio tests

- **Sync:** `lune run build` once, then three watchers in the repo root: `rojo sourcemap default.project.json -o sourcemap.json --watch`, `darklua process src build/src --watch`, `rojo serve build.project.json`; connect the Rojo plugin. Studio has 263 scripts (178 Shared, 43 Sim, 41 Tests, 1 Entry), the same as the offline build. No string requires left (two in comments).
- **Test entry:** `src/roblox/RunTests.luau` → `ServerScriptService.Entry.RunTests` (C-1, C-2). From `execute_luau` (Edit): `.start(filter?)`, then poll `.status()`.
- **Result in Studio:** 34 specs, 253 passed, 0 failed (31.8 s and 33.2 s; Lune 17.6 s). No warnings from our code in Output (the Defs loader is quiet).
- **Gotcha (fixed in the follow-up, C-3):** darklua's watcher deleted the output when a source file was replaced by rename (Claude's Edit/Write tools do this) and didn't write it back.

### Follow-up: separate serve and CI folders (C-3)

Rojo's serve crashed (`change_processor.rs` line 179, "The system cannot find the path specified") after `lune run build` wiped `build/src`, the folder it was serving (I ran the build while the sync was up).

- Live sync: `lune run serve` (new `.lune/serve.luau`) keeps `build/serve/src` converted; `rojo serve serve.project.json` serves it. Two terminals instead of three: the script replaces both `darklua --watch` and `rojo sourcemap --watch`. It only writes files and removes the output file of a deleted source; it never deletes a directory.
- Offline build: `lune run build` now wipes and rebuilds only `build/ci/` (`build.project.json`, `build/ci/place.rbxl`; `check_build`'s default follows).
- Tested with the watcher running: add, in-place edit, save by rename (shell and Claude's Edit tool), delete; each synced, no directory removed. `lune run build` alongside left `build/serve` untouched (19 directories before and after). Both trees check clean: 263 scripts, 787 requires.
- Verified in Studio (2026-10-21) with `lune run serve` + `rojo serve serve.project.json`: 263 scripts, no duplicate trees; a probe module added, edited (arrived in 1.3 s, its `@shared` require resolved) and deleted, each reaching Studio. Tests: **34 specs, 253 passed, 0 failed (32.6 s)**. A poll that waits inside `execute_luau` (20 s) was dropped; plain polls work, and one can be dropped while a long test runs.
- Touches `.lune/` (`build.luau`, `check_build.luau`, new `serve.luau`), the sim stream's area, at the user's request. Session A: `lune run build` output moved to `build/ci/`.
- **Not done (handoff step 2, left for later):** the cross-runtime hash check (D51), Script Analysis pass, and the `wait_for_child` question for client requires.

## Task 4: client foundation

- **Server** (`src/roblox`, C-9): `Main.server` runs the real Sim (duel_test on `flat:48`) at 15 Hz and sends NetOut's outboxes over `ReplicatedStorage.Remotes`; `MatchConfig` holds the match. Sim step in Studio: avg 0.14-0.40 ms, peak under 1 ms with 20 tanks.
- **Client, pure** (`src/client/Core`, Lune-tested): `World` (known units, both tiers, snapshot buffers, queues for the renderer), `NetIn` (decodes every channel; drops malformed, reordered and out-of-sync records), `Interp` (render clock 2 ticks behind, lerp, 1-tick extrapolation only while MOVING), `Commands` (CAMERA, point orders).
- **Client, Roblox**: `Main.client` (wiring, version check), `Render/Ground` (map layers as 64-stud checkered tiles), `Render/ModelPool` (pool per def, team colors), `Render/UnitRenderer` (one `BulkMoveTo` per frame, turret / barrel `Motor6D.Transform` from replicated aim), `Camera` (RTS camera, CAMERA command at most 5/s), `Debug/Hud` (F3).
- **Tests:** `lune run test_client`: 11 pass. `ClientWorld.spec` runs the real sim for 300 ticks and checks the client world against the reference receiver and the sim (positions within 1/32 stud), aim and READY states, dropping of reordered and malformed messages, interpolation and the render clock.
- **Playtest (Studio, 2026-10-21):** blockout Lancers and Ravagers drive at each other and fight from the real simulation. Client at tick 112: 11 tactical units, 11 models, render 2.0 ticks behind, 0 dropped; the sides lose tanks until one is gone, then the match restarts. Proof: `debug_out/screens/task4_brawl_topdown.png` (top-down render of the live client's parts, C-10). Studio's own capture shows only the GUI over a black 3D view (`task4_studio_capture_black3d.jpg`).
- **Found on the way:** edge scrolling dragged the camera to a map corner in Studio (mouse resting on the window edge): it's off in Studio, on in live games. Tanks that drive past each other beyond sight range vanish from the client: that's fog of war working, not a bug.

## Task 5: selection and orders

- **Protocol 6 adopted first** (C-12): HELLO / WELCOME join on the Snapshot channel, REJECT handling, Eco records; the server entry re-joins players on a match restart. `ClientWorld.spec` gained a late-join test (a client joining at tick 60 rebuilds the same view) and a REJECT test.
- **Pure** (`src/client/Core`, Lune-tested): `Selection` (box, click pick, same type on screen, groups, pruning), `Orders` (smart right-click, line slots as the server assigns them, chunks of 200), `Waypoints` (what each unit was sent, for the lines), `Signal`; `src/client/Api.luau` is the UI surface from `docs/contracts/client-state.md`.
- **Roblox:** `Input/Controls` (mouse and keys, C-13), `Render/Overlay` (selection rings, order lines and dots colored by kind, right-drag preview, order flashes).
- **Tests:** `lune run test_client`: 19 pass. `Orders.spec` against the real sim: box select takes own units only; add / toggle / groups / pruning on death; right-click on an enemy queues an ATTACK on the server, on an own unit GUARD, on the ground MOVE; three Shift-queued moves end at the last point; a line move ends with every unit within 4 studs of its drawn slot; 450 units split into 3 commands.
- **Studio playtest (march profile, real mouse and keyboard input through the MCP tools):** a left-drag box selected 10 Lancers (10 rings); right-click moved them; Shift+right-click queued a second point and all 10 ended there; Ctrl+1 saved them; clicking empty ground cleared the selection; a second box took the other 40; a right-drag line move spread them along x = -20 from z -70 to 69. Image: `debug_out/screens/task5_selection_orders_topdown.png` (from the last scene dump, C-10).
- **Studio went away** at the end of task 5: the instance now reports "Place is not open". Not repaired (your rules). Later tasks continue with Lune-tested logic and are checked in Studio when it's back.

## Task 6: build placement ghost

- **Pure** (Lune-tested): `Core/Placement` (snap, the server's placement rules on client knowledge, rows; C-14); `Api` gained `state.placement` and `beginPlacement`, `rotatePlacement`, `cancelPlacement`, `updatePlacement`, `place`, `placeRow` (BUILD to the selected builders that have the structure in `buildOptions`); `Orders` encodes BUILD; order lines show BUILD in yellow.
- **Roblox:** `Render/PlacementGhost` (translucent model copy over a footprint plate, Highlight tint green / red), `Input/Controls` (B = next build option of the selected builder, placeholder for the build menu; left click places, Shift queues and keeps placing, left drag places a row, R rotates, right click / Esc cancels), the F3 readout shows the ghost's state and reason.
- **Tests:** `lune run test_client`: 22 pass. `Placement.spec`: the client check agrees with the server's planning check on 750 random spots, reason included; placing sends one BUILD and the frame appears at the ghost's snapped spot with construction started; extractors need a deposit, invalid spots send nothing, Shift keeps placing, a Shift-dragged row of solars queues after the extractor.
- **Proof (headless, C-15):** `debug_out/screens/task6_build_ghost_valid.png` (green ghost, a generator frame, a queued row of solar frames) and `task6_build_ghost_invalid.png` (red over the Command Vehicle: units in the way), from `lune run client_demo build`.
- **Not verified in Studio:** the ghost's Instances, Highlight tint and the B / R / Esc keys. `MatchConfig` has a `build` profile (Command Vehicle on `start:48`) for that playtest.

## Task 7: combat effects

- **Pure** (Lune-tested): `Core/Effects` (C-16): projectiles from SPAWN_PROJ stepped with the shared Ballistics, IMPACT / DECOYED / LOST_LOCK / homing corrections, FIRE tracers from the drawn muzzle, death bursts sized by footprint and severity, all on the render clock; caps 150 / 60 / 100 by importance. Death records now carry their tick.
- **Roblox:** `Render/Effects` (pooled projectile parts moved with one `BulkMoveTo`, tracers, flashes, particle bursts with `Emit`); `Render/UnitRenderer` keeps a dead unit's model until its death plays; `Debug/SceneDump` includes effects (`E` records over the units).
- **Tests:** `lune run test_client`: 25 pass. `Effects.spec`: client shells within 0.5 studs of the server's for 240 ticks, IMPACT ends them; events and deaths wait for the render clock; caps hold with near effects kept.
- **Proof (headless, C-15):** `debug_out/screens/task7_combat_effects_headless.png` (`lune run client_demo combat`): shells in flight between the lines, impact bursts on the Lancers, turrets on target.
- **Not verified in Studio:** the Instances, particles and frame cost of the effects (guide 18.2: 2 ms).

## Task 8: strategic zoom icons

- **Pure** (Lune-tested): `Core/Icons` (C-17): the server's icon numbering, one shape family per role, blips / tracked contacts / ghosts, sizes, draws per frame with the selection on top, the zoom switch with hysteresis.
- **Roblox:** `Render/IconLayer` (pooled screen-space frames, a triangle glyph for aircraft), `ModelPool.setVisible` hides all models at strategic zoom, `UnitRenderer` keeps computing positions while hidden.
- **Tests:** `lune run test_client`: 29 pass. `Icons.spec`: numbering equals `NetOut.iconIndex`, every def has a family, strategic records map to the right family (seen, radar blip, tracked, ghost), all 20 units of a live duel get an icon.
- **Proof (headless, C-15):** `debug_out/screens/task8_strategic_icons_headless.png` (`lune run client_demo icons`, EW scenario): own structures framed, the selected units edged white, the enemy helicopter a triangle, its jammer vehicle a square, four SAM sites remembered as ghosts.
- **Not verified in Studio:** the GUI layer, the triangle glyph in Arial, and the zoom switch feel.

## Task 9: placeholder minimap and resource bar

- **Pure** (Lune-tested): `Core/Minimap`: map and minimap coordinates, terrain tiles (4 x 4 cells, merged along rows; water, height, deposits), unit dots (unit, structure, blip, ghost, selected), the camera box, resource-bar lines (stored / storage, +income, -demand, `STALL n%` when the stall ratio drops below 1).
- **Roblox:** `UI/Minimap` (bottom left, 200 px, labelled "PLACEHOLDER MINIMAP"; dots refresh at 3 Hz; left click moves the camera, right click orders the selection, Shift queues), `UI/ResourceBar` (top center, labelled "PLACEHOLDER RESOURCE BAR"; fills turn red in a stall). Both use only the client API (C-5). The F3 readout moved below the Roblox top bar.
- **Tests:** `lune run test_client`: 31 pass. `Minimap.spec`: coordinates round-trip, tiles cover a generated map exactly once (lakes shown), dots and camera box from a live match, a full bar at the start and a `STALL` line once three factories drain the economy.
- **Proof (headless, C-15):** `debug_out/screens/task9_minimap_resourcebar_headless.png` (`lune run client_demo minimap`): supply 392 / 1.0k (+1.0 -25.7), power 231 / 1.0k (+20.0 -51.4) while three factories go up; the minimap shows the deposits, the selected Command Vehicle, its frames and the camera box. The GUI (text, layout) needs a Studio playtest.

## 2026-10-22: shared modules and projectiles

- **Screenshot check (C-10):** `screen_capture` in Edit mode is still black (only Studio's view cube draws), although the place has daylight, a sky and the baseplate in front of the camera. Proof stays on scene dumps rendered with `lune run render_scene`.
- **Shared modules:** line-move goals and waypoint reach use `Shared/Grid/Formation` (S-12). The client uses `Shared/Grid/PlacementRules` (S-9) and `Shared/Net/Icons` (S-10); its copies are gone; the agreement tests still pass (`90c387d`). Formation slots stay a copy until the sim marks them ready.
- **Projectiles (C-18):** cause 1, a stale `MatchConfig` in Studio (`build` instead of `duel`: no enemy, no shots; re-synced by a real edit). Duel diagnostics: 92 SPAWN_PROJ / 92 IMPACT received and applied in 8 s, no FIRE (both tank guns are ballistic), up to 15 shell parts and 20 flashes at once; shells were 0.45 x 0.45 x 1.1 studs for 0.05–0.13 s (cause 2: too small for the RTS camera). Now Neon shells with a short Trail, bigger muzzle flashes and impacts. Mid-fight frame: `debug_out/screens/step2_shells_midfight.png` (scene dump of the live playtest).

## 2026-10-22: range rings, target line, BAR controls

- **Range rings (C-19):** `Core/Ranges` (union of same-kind circles as arcs, polylines on the terrain) and `Render/RangeOverlay` (pooled segments, rebuilt on change at most 4 Hz, V toggles, on by default; the build ghost of a turret or SAM shows its rings too). `Ranges.spec`: overlapping circles give one closed outline with no interior arcs, separate ones stay whole, nested and identical ones vanish, kinds don't merge. Studio, 50 Lancers selected: one merged red weapon outline and one white sight outline (`debug_out/screens/step3_ranges_50_selected.png`); cost in C-19 (0.024 ms per frame when nothing changes, rebuilds 3–5 ms at most 4 Hz while moving).
- **Target line (C-20):** one unit selected → red line to its target and a red ring on it (`debug_out/screens/step3_target_line_and_rings.png`, live duel). The target is guessed from the turret aim (99.6 % equal to the server's in `Targets.spec`) until request 6 puts it on the wire.
- **Controls (C-21):** arrows / edge scroll (live) / middle-drag pan, S stop, V rings; WASD free. Studio: S stopped 50 moving Lancers and cleared their lines without moving the camera; V hid and restored the rings (a first version didn't clear them: fixed).
- **Your fog question:** units drawn as models are always VISIBLE to your ally team; radar-only contacts only ever arrive as blips (`Fog.spec`: 596 radar-blip unit-ticks without a def, 0 of 416 enemy model unit-ticks not VISIBLE on the server). In the duel all Ravagers are inside the Lancers' white sight ring (200 studs), so full models are right; that profile has no radar.

## 2026-10-22: tasks 6–9 re-verified in Studio (step 4)

All with real mouse and keyboard input through the MCP tools.
- **Effects (task 7):** duel, 8 s of fight (83 shells, up to 15 drawn at once, 20 flashes, 92 particle bursts): effects 0.135 ms per frame on average, 0.47 ms worst (guide 18.2 budget 2 ms); whole client 0.29 ms average, 1.0 ms worst.
- **Icons and zoom switch (task 8):** seven wheel notches out to 585 studs: models hidden, 20 square icons for the 20 tanks; three notches back in (385): models back, icons gone.
- **Minimap and resource bar (task 9):** a left click at minimap (0.8, 0.2) moved the camera to exactly (115.2, -115.2); a right click with five Lancers selected ordered them to (-38, 0); the bar shows the live Eco values ("Supply 966 / 1.0k +1.0 -0.0", "Power 1.1k / 1.1k +40.0 -0.0" after a generator went up).
- **Build ghost (task 6):** click the Command Vehicle, B: extractor ghost tinted red ("no deposit"); B nine more times: Bulwark ghost, "ok", with its sight and weapon rings; R turned it to -90°; right click cancelled without moving the builder; B, B, click: a generator frame rose at the ghost's snapped spot and placing ended. **Fixed:** Esc didn't cancel. Roblox reserves it for its menu (it opened); right click is the cancel now (C-21).

## 2026-10-22: extractors on deposits (C-22)

- **Your report:** extractors couldn't be placed on the golden spots. Cause: the gold you saw was the minimap's 4 x 4-cell tile (32 studs) around each one-cell deposit; nothing marked the exact 8-stud cell in 3D, and the server (correctly) needs the extractor's center on it.
- **Fix:** gold plates on the deposit cells in 3D, cell-sized squares on the minimap, and the extractor ghost snaps onto a deposit within 12 studs. Tested against the server for every deposit; in Studio an off-center aim snapped, the extractor was built, supply income +1.0 → +3.0.

## 2026-10-22: queued builds and build range (C-23)

- **Line to the rest of the queue vanished:** the 2 s idle rule wiped a builder's queue while it stood still building. Now a queued build is done when its frame starts; builders with a build next aren't idle-cleared while a frame goes up (20 s fallback otherwise). Tested against the server's queue in Lune; in Studio the line stayed through all three queued generators.
- **Queued structures** show as translucent models over a yellow footprint until their frame starts (`debug_out/screens/queued_builds_and_line.png`). Factory unit queues have no map spot: not drawn.
- **Build range:** `buildRange` is in the unit defs (sim's files): request 7 asks for about 70 % (80 → 56, 64 → 45, 48 → 34).

## 2026-10-21: health and build bars (C-24)

- **Bars** over selected, damaged and unfinished units (own and enemy): health (green → yellow → red) and, while a frame is going up, a light-blue build bar under it; one bar once finished. `Bars.spec` checks it against the real sim, including a frame under fire whose health drops while its progress doesn't.
- **Studio:** two bars on a factory frame, health tracking progress; a 35 % hit lowered health only; finished with one bar (`debug_out/screens/health_bars.jpg`). 0.019 ms per frame. `FtggDebug:Invoke("damage", id, amount)` added for this (Studio only).

## 2026-10-21: exact target line (C-25)

- The target line now uses the server's targets (S-16) for your own units instead of guessing from the turret: equal to the server's on every tick of the duel in `Targets.spec`. Allies' units (no targets on the wire) keep the guess.

## 2026-10-21: explosion delay after a hit (C-26)

- **Your duel note:** a delay between the shot hitting and the explosion. Cause: during the tick a shell hit in, it was drawn on to the server's end-of-tick spot (up to ~23 studs past the tank) and burst only when that tick ended (33 ms later on average, 67 ms at worst). Now it bursts the frame its drawn path reaches the hit point (within 8 ms in `Effects.spec`); checked live in the Studio duel.

## 2026-10-21: shells from the barrel tip (C-27)

- **Your note:** shells spawned far from the barrels. They appeared a tick's travel (~23 studs) out, measured from the hull center: the server sends a shell after its first step and launches from the unit's center. Now each shell starts a tick earlier at the server's launch point, drawn from the shooter's barrel tip, and joins the server's path within 3 ticks. Tested in `Effects.spec`; Studio duel: 101 of 101 shells left a barrel tip (`debug_out/screens/shells_from_barrels.jpg`).

## 2026-10-21: task 1, terrain from the map layers (C-28)

- The client builds Roblox Terrain from the map's height and water layers: smooth slopes between cells, rock on steep ridges, sand on shores, water up to its surface. Units, rings, bars and effects use the same surface. The sim's procedural maps draw as they are (tried on `map:coastline`, MatchConfig profile `terrain`, now the ACTIVE one).
- Terrain vs parts measured in Studio: terrain builds in ~1.3 s (0.5 s CPU, spread over frames) and draws cheaper (GPU 2.7 vs 3.4 ms) with no instances; parts build in 0.08 s but need 8,980 parts and look stepped. Terrain is the default (`debug_out/screens/terrain_coastline.jpg`; parts: `terrain_coastline_parts.jpg`).
- Units stand on the drawn terrain within 0.02 stud; deposits stay visible (gold plates over the ground); the place's own Terrain stays empty (the client's terrain isn't saved).
- Not done: units don't tilt with the slope (they stay upright).
- **Next, task 4 (fog of war), the user's idea (2026-10-21):** light points in the grid cells that brighten what you see and darken the rest, with the Lighting adjusted to match.

## 2026-10-21: smooth range rings (C-29)

- **Your note:** the rings should update faster and smoothly. They now follow their units every frame (the merged outline is still recomputed 4 times a second). Costs about 1.3 ms more per frame while 50 selected units move, nothing when they stand still (`debug_out/screens/rings_follow.jpg`).
- **Later (your note):** order lines and other markers drawn on top of the terrain instead of being hidden by hills. Planned for a later pass: draw them as always-on-top adornments.

## 2026-10-21: task 2, piece animation (C-30)

- **Piece scripts** (guide 14): `Turn`, `Move`, `WaitForTurn`, `WaitForMove`, `Sleep`, `StartThread`, `Signal` / `SetSignalMask`, hooks from the replicated aim, weapon state, MOVING bit and shots, LOD near / mid / far. Every unit's turret and barrel now run through it (default script, with recoil).
- **Juggernaut:** hand-made blockout with a turning torso and two gun arms; its script raises the arms to aim, recoils them in turn, and lowers them 3 s after it stops aiming (`debug_out/screens/juggernaut_arms_down.jpg`, `juggernaut_arms_up.jpg`).
- **Cost:** 64 animated units in a fight, 0.13 ms per frame (`juggernaut_50.jpg`).
- **Not exact yet:** the server has no rest pose or restore delay, so the Juggernaut can fire before its arms are fully up (request 8 makes the client follow the server exactly).
- Studio-only helpers: `FtggDebug:Invoke("spawn", defId, player, x, z, heading, count, spacing)` on the server; `FtggClientDebug:Invoke("camera", x, z, distance)` and `Invoke("anim")` on the client.

## 2026-10-21: task 3, air and naval rendering (C-31)

- **Aircraft** fly at their replicated altitude; jets bank into turns, helicopters tilt and spin their rotors (wound down when landed) (`debug_out/screens/air_helicopters.jpg`, `air_jet_bank.jpg`).
- **Ships** sit in the water; **own submarines** are drawn just under the surface; **enemy submarines** appear only as sonar contacts, a hollow ring icon (`naval_ship_sub_sonar.jpg`).
- Playtested with the new `ew` MatchConfig profile (the sim's `ew_test`; its helicopters are shot down within ~30 s, so extra aircraft were spawned) and on Coastline's sea with spawned ships and submarines. MatchConfig is back on `terrain`.

## 2026-10-21: task 4, fog of war in 3D (C-32)

- **Light fog (your idea, as in Astra Force's write-up):** the scene is darkened and a point light per 32-stud cell lights what your units see, fading in and out (`debug_out/screens/fog_lights.jpg`).
- **The write-up's limit, measured:** Roblox stops rendering point lights a few hundred studs from the camera: lit at 320 studs of zoom, gone at 470 (`fog_lights_culled_470.jpg`). Our tactical zoom goes to 480, so beyond 330 the fog switches to dark plates over unseen ground with normal lighting (`fog_overlay_far.jpg`).
- **Radar contacts** pulse on the ground in the dark (`fog_radar_contact.jpg`); **ghost structures** stay drawn where last seen, faintly glowing (`fog_ghost.jpg`).
- The client works out what your team sees exactly like the server (tested cell for cell). Cost: 0.02 ms per frame for the fog code; GPU +1.6 ms with the light fog; 60 fps.
- **Known gaps:** units never seen in the camera use a typical sight range for their icon, and allies' units don't count yet (request 9).

## 2026-10-21: task 5, deaths and wrecks (C-34)

- **Deaths by severity:** a death that leaves a wreck shakes briefly and becomes a charred wreck of the unit (`debug_out/screens/deaths_wrecks.jpg`); a big overkill flings the turret and other pieces up and away under the explosion and leaves nothing (`deaths_fling.jpg`). Same rule as the server for when a wreck exists.
- **Gap:** the client only learns of wrecks from deaths it saw, and never of a wreck being reclaimed, so wrecks stay until the match restarts (request 10).

## 2026-10-21: global sim speed (C-35)

- In a Studio playtest: `-` slower, `=` faster (0.1×, 0.25×, 0.5×, 1×, 2×, 4×), `P` pause / resume; the F3 readout shows the speed. A profile can start at another speed with `speed = 0.25` in `MatchConfig`. Everything simulated slows together; camera and UI stay real-time; a pause freezes the picture exactly (`debug_out/screens/sim_speed_quarter.jpg`).
- Also fixed: a just-launched shell on a short shot could burst up to 0.9 tick late (C-26 timing with the C-27 barrel-tip offset).

## 2026-10-21: smooth missile paths (C-36)

- **Your note:** missiles bounced and zig-zagged. Causes: the client steered at the target's newest position without the server's lead, and every server correction (every 5 ticks) or decoy turned or moved the drawn missile at once. Now it steers like the server and eases from the old course to the new one. Worst jump in a frame: 27.7 studs before, 2.5 after (Lune), 5.3 in Studio.
- **Still:** missiles chasing a target you only see on radar drift between corrections (the client doesn't know where the target really is); request 11.

## 2026-10-21: SAM test scene, slowed flight tests, fog off (C-37)

- `ACTIVE = "sam"`: your radars cover the map, 4 Falcons (5× health) circle over 4 enemy IR SAM sites that keep firing (`debug_out/screens/sam_profile.jpg`). Missiles launch along the launcher's aim until the sim adds vertical launch (request 12).
- `sam`, `air` and `naval` start at 0.25× speed (`-` / `=` / `P` still change it).
- The fog-of-war darkening is off for now (`FogOfWar.ENABLED`); radar contacts and ghosts still show.

## 2026-10-21: curved missile paths, aircraft markers, clicking models (C-38)

- **Missile zig-zag:** missiles were drawn straight within each tick and turned at its end (up to 10.7° corners every tick), and frequently corrected missiles trailed an old course. They now follow a smooth curve through each tick and converge after corrections. At 0.25× in Studio: worst 2.2° of turn in a frame.
- **Aircraft icon, health bar, selection ring and lines** now sit at the aircraft, not at twice its altitude or on the ground under it (`debug_out/screens/air_select_ring_bar.jpg`).
- **Clicking a unit's model** selects it (right-click targets it), wherever it is drawn.

## 2026-10-21: missile sensor view (C-39)

- **N** shows what each homing missile is doing: its predicted path for the next second (green = it will hit, orange = it will miss), the point it steers at (yellow), its target's centre (red), the fuse zone around the target, the predicted closest approach (magenta), and a label with guidance, lock, target, distance, time to go and predicted miss vs fuse. Corrections and decoys flash as short fading lines (`debug_out/screens/c39_missile_view_sam.jpg`).
- Predictions run the client's copy of the server's guidance with the target flown straight on, so they are close for a second or so and spread when the target turns.

## 2026-10-21: recognizable missiles (C-40)

- Missiles are now small models (body, nose, fins) with a flickering exhaust glow, a short flame and a grey smoke trail that widens behind them and fades after the missile is gone. IR missiles have a dark seeker nose, radar missiles a white radome; radar SAM missiles are bigger with thicker, longer smoke (`debug_out/screens/c40_missile_model_closeup.jpg`, `c40_missile_smoke_launch.jpg`).

## 2026-10-21: SAM scene reworked

- `sam` is now on a bigger map (`flat:160`): the 4 Thorns stand on the east side, and one Falcon (5× health) starts on the west side out of their range and flies over them (spawn entries take `moveTo`). Your radars still cover the map (`debug_out/screens/sam_east_falcon_inbound.jpg`).
- Later the same day: the Falcon now flies to x = 300 instead of 420 and circles there, just west of the Thorns and inside the map (at 420 its circle ran past the east edge). Studio: it circles between x ≈ 110 and 500 (`debug_out/screens/sam_falcon_circles_300.jpg`).

## 2026-10-21: enemy defense ranges (C-41)

- Enemy defenses you have seen (or can identify on radar) show their weapon range: dark red for ground weapons, violet for anti-air. Seen-before ones keep the ring as ghosts. Factories don't get one, and unknown radar blips don't either (their type isn't known). V hides all rings (`debug_out/screens/c41_enemy_sam_rings.jpg`).

## 2026-10-21: seeker cones (C-42)

- The missile sensor view (N) now draws each guided missile's seeker cone out to its lock range: cyan while its target is inside the cone, red when it is outside (IR 60°, radar 70° off the nose; command-guided missiles have none). The label adds the target's angle off the nose, e.g. "34° / 60° off". In the `sam` scene most locked missiles turn out to have their target behind them after a miss, which is request 13c (`debug_out/screens/c42_seeker_cone.jpg`).

## 2026-10-21: camera follow (C-43)

- **T** (or the "Follow (T)" button next to the minimap) makes the camera follow the first selected unit, or with nothing selected the missile nearest the middle of the screen; press again to stop. Aircraft and missiles stay in the middle of the screen at their altitude, the camera never ends up below a climbing missile, and it may follow a missile up to 400 studs past the map's edge. Panning stops it, zooming doesn't; when the target dies or the missile ends, the camera stays there (`debug_out/screens/c43_follow_falcon.jpg`, `c43_follow_missile.jpg`).

## 2026-10-21: protocol 11, move lines, missiles past the edge, a longer SAM map (C-44 – C-46)

- Merged `main` with the sim's new missile guidance (S-27: proportional navigation, seeker cones), decoy bend (S-28) and sight / wreck records (S-26). The client's missiles now steer with the same shared code, so the drawn missiles stay within a few hundredths of a stud of the server's (C-44); in the `sam` scene Thorns now hit 90% of the time (`debug_out/screens/c44_pn_missiles_long_map.jpg`). Fog and wrecks don't use the new records yet.
- **Move lines** no longer vanish after 2 s: the server never sets the MOVING bit, so the client now tells from position updates whether a unit is moving; an aircraft's line lasts until it reaches its circle (C-45, `debug_out/screens/c45_falcon_move_line.jpg`). Asked the sim to set the bit (request 14).
- **Missiles past the map's edge** explode where they are instead of on the edge (C-46). Positions past the edge can't be sent yet (request 15).
- **`sam` scene** is now on the largest map (2048 studs): the Falcon starts far west and flies ~1,500 studs in. A longer Thorn range and bigger blast are request 16 (weapon defs are the sim's).

## 2026-10-21: detailed combat effects (C-47)

- **Explosions** now have a fireball, sparks, smoke, and on the ground a dust ring and a scorch mark; their size follows the weapon's blast radius, so the bigger Thorn blast (request 16) will show bigger. **Gunshots** flash at the muzzle with a puff of smoke, tracers fly as glowing streaks and spark on hits. **Missiles** leave in a launch cloud, trail billowing smoke, and decoyed ones show falling flares (`debug_out/screens/c47_*.jpg`).
- Effects slow down and freeze with the sim speed, so paused playtests can be inspected.
- **Your own effects:** save an effect as `ReplicatedStorage.Vfx.Impact` (or `Death`, `MuzzleFlash`, `Hit`, `Launch`, `Decoy`, `Flare`, `Chaff`) and it replaces the built-in one, e.g. one made with VFX Studio. Give each ParticleEmitter an `EmitCount` attribute (optional `EmitDelay`); C-47 lists the rest.

## 2026-10-21: aircraft crash, countermeasures, merge of S-29..S-32 (C-48)

- **Aircraft fall out of the sky** when they die in the air: jets dive and roll, helicopters spin down, burning and trailing smoke, and explode where they hit the ground; they leave no wreck (`debug_out/screens/c48_jet_falling.jpg`, `c48_crash_explosion.jpg`). Asked the sim not to make air wrecks at all (request 19).
- **Countermeasures follow what the aircraft carries:** a jammer laser for aircraft with DIRCM only (Falcon, Archon, Guardian), flares dropped from the aircraft for those with flares (Wasp, Manticore), chaff against radar missiles (`c48_dircm_laser.jpg`). Request 18 asks for the exact one on the wire.
- **Deaths and effects** now slow down and pause with the sim speed.
- **Moving an aircraft to a point inside its circle** still doesn't work: the server counts it as arrived and circles from where the jet is. That is request 17 (high priority); the client's line will follow the fix.

## 2026-10-21: air raid on a SAM belt (`airsam` profile)

- New test profile `airsam` (set `ACTIVE = "airsam"` in `src/roblox/MatchConfig.luau`): on the largest map (2048 studs, 0.25x), your 2 Falcon jets, 2 Archon fighters and 3 Guardian helicopters (3x health) start far west and fly east into 5 Chaos SAM systems: 3 Thorn IR sites in front, 2 Wyvern long-range radar SAM sites behind. 4 radars cover the map and a fusion reactor powers them and the aircraft's DIRCM jammers (without it power stalls at once and DIRCM never recharges). Studio: SAMs launch at the jets and helicopters across the belt, missiles get jammed (DIRCM) and aircraft go down (`debug_out/screens/airsam_engagement.jpg`, `airsam_dircm_jam.jpg`).

## 2026-10-21: health bars and hits (C-49)

- **Health drops with the hit now:** bars used to drop about 2 ticks before the missile or shell that caused it was drawn arriving (half a second at 0.25x); they now change on the hit's tick.
- **"The plane takes no damage":** it did, but `airsam` gave the aircraft 3x health and the wire can't show health above a unit's normal maximum, so bars stayed full until two-thirds of it was gone. `airsam` now uses normal health; the `sam` profile's Falcon still has 5x.
- A message asking sim-A to do requests 17 and 18 expired undelivered (that session holds cross-session messages); they stand in the request list below.

## 2026-10-21: missiles on dying aircraft (C-50)

- **"IR no lock" just before a kill:** the client learned of the aircraft's death about 2 ticks before it drew the missile arriving, removed the aircraft, and the missile lost its target and flew past; then the explosion and the death played. The dying aircraft now stays the missile's target until its death is drawn, so the missile flies into it and explodes there.
- **Missile damage varies on purpose:** SAM missiles burst next to the target, and the damage falls off with how close they got (a Thorn missile: 200 at the hull, 100 at 5 studs). Jammed or decoyed missiles do nothing.

## 2026-10-21: requests 14-19 done by the sim; client follows (C-51)

- Merged `main` with the sim's answers to requests 14-19 (S-33, S-38), move states, cancel, carriers, terrain types and amphibious units (S-34..S-40), protocol 13.
- **Moving a jet to a nearby point works now:** the server flies it to the point (or, for a point inside its turn circle, to its closest approach) and then circles it; the move line goes exactly then (`debug_out/screens/c51_jet_move_line.jpg`).
- **Flares, chaff or DIRCM** are now the one the server says won, not a guess.
- **Thorn SAMs** reach 420 studs with a 12-stud blast; the rings, seeker cones and explosions follow the new numbers.
- Missiles that reach the map's edge now burst there on the server, so the client's edge workaround (C-46) is gone.
- Not used yet: terrain types (ground colour by sand / rock / road), the CANCEL command, carriers, move-state buttons, the sight and wreck records.

## 2026-10-21: crashes leave their smoke, big radar SAM missiles (C-52)

- **Crashed aircraft** no longer vanish the moment they hit the ground: they explode and keep falling through it out of sight for 3 seconds, so their smoke trail fades in the air instead of disappearing with them (`debug_out/screens/c52_crash_smoke_stays.jpg`).
- **Radar SAM missiles** (Wyvern, Gorgon, Aegis, Seraph) are drawn about 2.3x the size of IR ones, with a heavier, longer plume, and their explosions are drawn 1.8x bigger (`c52_radar_sam_missile.jpg`).
- **Vertical launch for radar SAMs** and a bigger radar SAM blast radius are server changes: request 20 for the sim session.

## 2026-10-21: vertical-launch radar SAMs (C-53)

- Merged `main` with the sim's vertical-launch radar SAMs (S-42): Wyvern, Gorgon, Aegis and Seraph missiles now leave straight up, pitch over onto their target and dive in, with a 20-stud blast. The client steers its copies the same way, so they stay within a few hundredths of a stud of the server's (`debug_out/screens/c53_vertical_launch.jpg`).
- You only see a launch if your side can see the launcher: the server sends a missile once it's in your sight. In `airsam` the aircraft see the Wyverns only when they get close.

## 2026-10-21: projectiles without line of sight (C-54)

- Merged `main` with request 21 (S-43, protocol 14): every missile and shell in your camera area is now shown, even from a launcher you can't see, and the launcher stays hidden; a vertical-launch SAM's missile is seen leaving the ground (`debug_out/screens/c54_unseen_launch.jpg`).
- Gun shots from a hidden shooter are drawn as a tracer from where the shot started, with no muzzle flash and without revealing the shooter.

## 2026-10-21: longer climb and 3x range for radar SAMs (C-55)

- Radar SAM missiles now climb straight up about 100 studs before they pitch over (`climbHeight` in `chs_radar_sam.luau` / `ord_radar_sam.luau`, tunable like `reload`); the client follows the same rule (`debug_out/screens/c55_vertical_climb.jpg`).
- Radar SAMs reach 3x as far (Wyvern / Gorgon 1680, Aegis / Seraph 1800) with their radars to match; the range rings follow. In `airsam` the Wyverns can now reach your aircraft almost from where they start.

## 2026-10-21: SAM missile stockpiles (C-56)

- SAM sites and mobile SAMs now hold a stock of missiles (Thorn / Vigil 8, Hornet / Halo 4, Wyvern / Aegis 6, Gorgon / Seraph 3) and rebuild it one missile at a time for supply and power (IR 6 s, 15 + 300; radar 12 s, 40 + 900). An empty site holds its fire.
- Your own SAMs show their stock as a row of pips above the health bar (lit = in stock), and a site that isn't full keeps its bar up while it refills (`debug_out/screens/c56_sam_stock_pips.jpg`). You never see an enemy site's stock.

## 2026-10-21: nukes and interception (C-57)

- Nuke silos (Order Reckoning, Chaos Ragnarok) and radar SAM interception from the sim (S-48) are now drawn: a big missile on a high arc, Aegis / Wyvern interceptors flying at it, a burst in the air when one gets it, and a mushroom cloud with a shockwave and a screen flash when it lands.
- Every player gets a warning while a nuke flies: a blinking "NUCLEAR LAUNCH DETECTED - impact in N s" banner, a red ring at the launch site and a pulsing red ring of the blast where it will land.
- New key A (BAR's attack): select units, press A, left-click an enemy or the ground; Shift keeps attacking, right click cancels. With a silo selected that launches a nuke there.
- New test profile `nuke`: the Chaos silo fires at your base when the match starts and your 2 Aegis try to stop it; your silo has 2 nukes for the Chaos base, which 2 Wyverns defend (`debug_out/screens/c57_chase.jpg`, `c57_warning.jpg`). Both nukes were intercepted in my Studio run, so the detonation itself is only checked in Lune so far.
- The `nuke` profile now has an economy to refill the stockpiles (the user): 5 fusion reactors and 12 supply converters (the flat map has no deposits), 12 supply/s and 1,250 power/s. Measured headless: the silo rebuilds a nuke in its full 120 s, twice back to back; 8 converters fall to 135 s on the second.

## 2026-10-21: nuke arc preview, radar tracks (C-58)

- In attack mode (A) with a silo selected, the cursor now shows the nuke's flight arc from the silo, its blast ring and "impact in 12.7 s - 2 in stock" (`debug_out/screens/c58_attack_preview.jpg`). An order on an empty silo says "empty: fires when built": the order waits and the nuke launches as soon as it's built.
- The flight path is a physics arc (gravity), not a Bezier curve; it climbs 800 studs, off the top of the screen. The height is the sim's: asked sim-A to bring it down to 300 with the same 13 s flight (request 27a).
- The silo didn't stop building: headless it fires and rebuilds every 120 s, but at sim speed 0.25 that's 8 real minutes and the pips only show whole nukes. Asked sim-A to send the build progress so the pips can fill as it builds (request 27b).
- The sensor view (N) now shows radars tracking a nuke: lines from every radar SAM site that has it, "NUKE  RADAR TRACK x2", time to impact and interceptors up; interceptors show locked on it. The warning banner adds "2 radars tracking" (`c58_radar_tracks.jpg`).

## 2026-10-21: building pip, test overrides (C-59, C-60)

- Your silo's (and SAM sites') next pip now fills up as the missile is built, from the sim's new progress (S-49) (`debug_out/screens/c59_stock_progress_pip.jpg`). Nukes also fly lower now (300 studs up, same 13 s), so they stay on screen.
- For testing, the `nuke` profile makes nukes cost 1 supply and 1 power, build in 10 s, and lets a silo launch again 2 s after a launch (10 s in the defs). A silo fires with 1 nuke in stock; it was the 10 s reload, ending together with the 10 s rebuild, that made it look like it needed 2. Radar SAM interceptors kill only 20% of the time: first as a test override, now the real number (S-50). These are test overrides for this profile only (`weaponOverrides` in MatchConfig); the real numbers are the sim's.

## 2026-10-21: one launch notice (C-61)

- The warning banner now just says "NUCLEAR LAUNCH DETECTED", whatever the number of nukes in the air; the impact time and radar tracks are in the sensor view (N).

## 2026-10-21: nukes climb, then turn (C-62)

- Nukes now leave the silo straight up, climb about 120 studs, then turn over onto their arc toward the target (S-51) (`debug_out/screens/c62_nuke_boost_turn.jpg`). The attack-mode preview draws that same path, and the landing ring follows it.

## 2026-10-21: large-scale battle profile `normandy`

- New test profile `normandy`: 150 units a side in formation with no orders. Each army has every land and air type (no naval, submarines, amphibious tanks, anti-sub helicopters or command vehicles). IR SAM sites stand near the battlefield; in the safe rear there are radar SAM sites, long-range radars, 10 fusion reactors, 30 converters, depots, a nuke silo and constructors. Order holds the north, Chaos the south (`debug_out/screens/normandy_order_lines.jpg`).
- Spawns can now be laid out as formations (`cols`, `rowDx`, `rowDz` in MatchConfig).
- A stronger economy after the user's playtest ("resources declined very fast"). Each side now has 16 fusion reactors, 50 converters and 10 depots, and starts with full stores (`startResources`: 10,000 supply, 20,000 power). Order had stalled because its power stayed at the converters' 50% reserve and supply fell to 8 within a minute. Now Order's supply keeps rising by about 10/s on top of ~33/s of SAM refills, and Chaos fills its 11,000 storage.
- It runs on `flat:256` until sim-A's Normandy map lands (request 31). Headless: about 2 ms a tick on average, 7.5 ms at worst, over 4 minutes.

## 2026-10-21: radar rings always on; normandy on its map

- Your radar towers and unarmed radar units (mobile radars, AWACS) now always show their green radar ring, selected or not (C-63). It is drawn always on top, so hills and hedgerows don't hide it, and it stays a bold 6 px line at any zoom (C-64, `debug_out/screens/c64_radar_rings_on_top.jpg`).
- The `normandy` battle is on sim-A's `map:normandy` now (S-53, S-54), laid out west (Order) to east (Chaos): each army in its staging field in front of its river, IR SAM sites at the edge of the bocage, aircraft, radar SAMs, radars, economy and silo behind the river. All 392 units stand on open ground (checked cell by cell), ticks average 2.5 ms (worst 17.5 ms) and both sides keep full supply (`debug_out/screens/normandy_map_order_side.jpg`).
- SAM ranges cut twice on the user's word (S-55, S-56): IR SAMs now reach 206 (Thorn) / 147 (Vigil), radar SAMs 945 (Wyvern) / 1013 (Aegis). Two client specs' SAM scenes adjusted: the Thorns stand under the jets' loiter circle, and the floors for prediction count and boundary bend account for ~6-tick flights.

## 2026-10-23: cheat command line, permission gate, lobby Cheats toggle; stub until S-102 (C-119)

- **Asked:** an in-game command line for testing (BAR's /cheat): TextChatService commands; give / res / income / instabuild / reveal / god / kill / speed / ai as the sim defines them; "at" = the cursor; ids or names with suggestions; /help; results in chat. Allowed only in Studio, or when the host enabled "Cheats" in the lobby AND the UserId is allow-listed; never in public matchmaking; "cheats used" on results and replays; Ctrl+Shift+G repeats the last give; a stub until the sim side merges.
- **The commands are the sim's** (S-102, net.md "Cheat commands"): a CHEAT command on the Cmd channel, recorded in the replay. `Shared/Net/CheatText` parses chat text into it, and a CHEAT_RESULT event answers (`CheatText.describe`).
- **`Core/CheatInput`** (pure, `CheatInput.spec` 3):
  - the command list with usages and examples;
  - suggestions: command names, then after "give" units whose id or display name starts with (or contains) the typed text, case-insensitive;
  - `prepare`: drops "/" and "/cheat", turns a display name into its id, and adds " at x,z" (the cursor's ground point) to a give without one;
  - /help's lines.
- **`UI/CheatConsole`:**
  - a UI-kit bar at the bottom centre, opened with Enter or "/";
  - suggestions above it (Tab or a click takes one), Up / Down history, Escape closes;
  - a log of up to 16 lines on a faint backing, kept above the suggestions and fading after 12 s;
  - Ctrl+Shift+G repeats the last give at the cursor.
  - Roblox's chat window is off (C-109), so this is the command line; the same commands are also registered as TextChatService commands for when chat is on.
  - Enter is also taken from a focus loss while Return is down (Studio's input tool drops the TextBox's enterPressed).
  - The debug hook `Invoke("cheatline", text)` enters a line.
- **Gate** (`src/roblox/Main.server`, new `src/roblox/CheatConfig`):
  - a Cmd payload whose byte 0 is CHEAT (17) is dropped unless the player's UserId is in `CheatConfig.allow` (the user's, 11846985184) and the game is in Studio or the lobby's `cheats` is on;
  - lobby matches pass `match.cheats` (the toggle, or always in Studio); test profiles start with `cheats` and `offline` in Studio;
  - sim-A confirmed the byte-0 rule.
- **Lobby:** a host-only "Cheats" toggle (off by default; `Lobby.cheats`, `op = "set", key = "cheats"`). "/cheat on|off" sets it.
- **Until S-102 is in main:** the bar answers "stub: would send …". Next: `CheatText.parse`, the Cmd channel, the CHEAT_RESULT lines, the speed driver and "cheats used" on results.
- **Screenshots** (`debug_out/screens/`): `cheats_console.jpg` (three entered lines, "LANCER" turned into ord_lancer and the cursor's "at 47,104" added; "/give rad" suggesting the Radiance), `cheats_commands.jpg` (the command list), `cheats_help.jpg`.

## 2026-10-23: hex patches animate: a wave per hit, glassy plates (C-118)

- **Your notes:** the bigger patches change but look static, solid, not smooth.
- **Cause 1:** a hit within 6 studs of a young patch merged into it by restarting its clock, so the patch snapped back to full heat. Under steady fire it sat lit and never animated. Hits after 0.25 s also stacked a second grid on the same spot.
- **Cause 2:** under the night bloom, lit Neon plates at 95% opacity saturated to one white block.
- **Fix** (`Core/Shield`, `Render/ShieldFx`):
  - each patch keeps a wave per hit (up to 4); a merging hit adds a wave instead of restarting it;
  - a plate shows the brightest of its waves (`Shield.plateLook`), and each wave runs out from the centre ring by ring;
  - rings now light 0.07 s apart (was 0.045), so the spread shows;
  - patches merge while they glow (`MERGE_AGE` 0.65), so the grids don't stack;
  - plates peak at 60% opacity (`ShieldFx.PLATE_OPACITY`), glassy with the falloff visible.
  - `Shield.spec`: the wave reaches ring 2 later than the centre, and a new hit keeps the old wave and relights the centre.
- **Screenshot:** `debug_out/screens/shield_hex_waves.jpg`.

## 2026-10-23: dimmer ripples, bigger hex patches (C-117)

- **Your notes:** the ripple is too bright (light emission?), and the hex shield should be bigger or have more hexes.
- **Ripple** (`Render/ShieldFx`): LightEmission 1 → 0.3, so it no longer glares white under the night bloom; it starts 30% transparent (was opaque).
- **Hexes** (`Core/Shield`):
  - plates 2.4 → 4.5 studs across (gap 0.4);
  - every hit lights at least 2 rings (19 plates; 37 for a heavy shell);
  - each ring out is 45% as opaque as the one inside (was 30%, so the second ring shows);
  - the shared plate pool grows to 240.
  - `Shield.spec`: the centre still outshines ring 1 (below half).
- **Screenshot:** `debug_out/screens/shield_hex_bigger.jpg`.

## 2026-10-23: a heavy hit no longer enlarges every ripple on the dome (C-116)

- **Your find:** with small ripples on the dome, one large shell turned them all big at once: the "burst" of shield effects.
- **Cause:** each dome had one ripple ParticleEmitter. Every hit set its `Size` for that shell, then emitted one particle. A ParticleEmitter's `Size` applies to the particles it already emitted, so one heavy hit resized every live ripple.
- **Fix:**
  - each dome now has one emitter per size in `ShieldLook.RIPPLE_SCALES` (0.6, 0.85, 1.2, 1.7 × `RIPPLE_SIZE` × R), each sized once;
  - a hit emits from the nearest one (`ShieldLook.rippleBucket`, by √intensity); nothing is resized after creation;
  - `ShieldLook.spec` covers the choice.
- **Studio** (`shield` profile): over 245 mixed hits in 15 s the four emitters kept their sizes (18 / 25.5 / 36 / 51 studs), and big and small ripples show side by side (`debug_out/screens/shield_ripples_mixed.jpg`).

## 2026-10-23: wreck meshes (models-C) built and placed; wreck appearances (C-115)

- **Merged** models-C's `6b94586`: a `wreck` per approved manifest entry (its own meshes, centers, sizes and maps; the live entry's rig; no glow, no team pieces).
- **Materials:** `lune run mesh_materials` writes a `wreck_<id>` SurfaceAppearance per wreck (22), as C asked; `MeshMaterials.spec` checks them.
- **`Render/MeshModels.wreck(def)`:**
  - builds the wreck on first ask in the background: the live rig's joints, the wreck's meshes and the cloned `wreck_<id>` appearance;
  - returns nil until it's ready, and only for an approved wreck (`wreck.status == "approved"`; C keeps them review until you look).
  - `Invoke("wrecksanyway", true)` uses review wrecks too, for review screenshots.
- **`Render/Deaths`:** a dying unit leaves the meshed wreck when there is one, with the same knocked-askew joints and no charring or CorrodedMetal; otherwise the darkened model as before.
- **Studio** (`shield` profile, review wrecks on):
  - the first Ravager and Lancer deaths left darkened copies while the wrecks built;
  - the next ones left C's meshed wrecks with their materials (`debug_out/screens/wrecks_meshed.jpg`).
  - They read very dark under the night preset (their maps are charred).
- **Found on the way:** the debug kill with a million damage is overkill, and those deaths fling the hull and leave no wreck. Kill with just over full health to see wrecks.
- **Your call:** approve the wreck meshes (models-C sets `status = "approved"` on each `wreck`), and whether they're too dark at night.

## 2026-10-23: S-96 tower meshes merged (review); a retracted tower's glow dims (C-114)

- **Meshes:** models-C's BAR meshes for the beam towers (`1efc5e9`) and flak towers (`1429976`) are merged from m-models. They're "review" in the manifest, so the towers keep their blockouts in game until you approve them; `MeshMaterials` was already current. The lids `shellL` / `shellR` are pieces under `shell`, which `Render/MeshModels` rigs like any other piece, so C-112's retract script drives them on the meshes too.
- **Glow on retract** (models-C's suggestion): `Core/Glow` takes `retracted` (a `def.retract` tower with TOGGLED_ON clear). Power drops to its floor (0.3) and weapon goes dark; running stays on. `Glow.spec` covers it.
- **Your call:** approve the four tower meshes (Radiance, Inferno, Lumen, Hailstorm) for them to draw in game.

## 2026-10-23: S-96 tower blockouts merged; retract checked on them (C-113)

- **Blockouts:** models-C's blockouts for `ord_radiance`, `chs_inferno`, `ord_lumen` and `chs_hailstorm` are merged from m-models `aafbf19`. The towers draw as their blockouts instead of generic boxes.
- **Retract in Studio** (`shield` profile, all four spawned):
  - switched off, both beam towers sink the turret, fold the barrel and close the lids flush with the collar;
  - switched on, they rise and reopen (turret back at 5.0 / 4.5 studs);
  - the Inferno's `tankL` above the lids is a fixed part of its base.
- **Screenshots:** `debug_out/screens/beam_towers_deployed.jpg`, `beam_towers_retracted.jpg`.
- **No code change:** C-112's piece script fits the blockouts' pivots as they are.

## 2026-10-23: beam towers drawn, retract on / off, icons for S-96's towers (C-112)

- **S-96 (sim-A, request 43, first part):**
  - beam towers `ord_radiance` / `chs_inferno`: BEAM weapons, 700 power a shot, visible targets only; `retract = { armor = 4 }`, TOGGLED_ON clear = retracted;
  - flak towers `ord_lumen` / `chs_hailstorm`.
- **Beam drawing** (`Core/Effects`, `Render/Effects`):
  - a FIRE from a BEAM weapon becomes a tracer with `beam` = the shooter's faction, held `BEAM_SECONDS` (0.45);
  - drawn as the whole line at once, a Neon core 0.9 studs thick thinning to 0.27 and fading, in the faction's weapon glow tint (Order 200, 240, 255; Chaos 255, 170, 70);
  - with a launch-size charge flash at the barrel and an impact burst at a hit.
- **Retract** (`Core/PieceAnim` calls `Retract(u, retracted, instant)` for `def.retract` units on the TOGGLED_ON bit; `PieceScripts/BeamTower` for both):
  - the turret faces front and sinks (7.6 / 7.4 studs, models-C's `retracted` pose), the barrel folds −90°, and the lids `shellL` / `shellR` close ∓90° when the model has them, over 1.5 s;
  - no aiming while retracted;
  - `PieceAnim.spec`: retract and rise.
- **On / Off:** `Core/CommandSet` and the command card treat `def.retract` as switchable (green On, red Off); `CommandSet.spec` covers the Radiance.
- **Icons** (`tools/icons/render.mjs` STOPGAP): Radiance and Inferno as "Heavy Turret", Lumen and Hailstorm as "IR SAM Site". The sheet image is unchanged (asset 87919807696998), and `IconAtlas` was regenerated: 139 of 139 defs mapped.
- **Studio** (`shield` profile, a Radiance at (60, −150) and an Inferno on the enemy side):
  - the Radiance's ice-white beam reached an enemy with an impact (`beam_radiance.jpg`);
  - its card shows Fire at will / On / Stop / Attack (`beam_tower_on.jpg`);
  - Off went red and the turret block sank into the shell on the placeholder model (`beam_tower_off.jpg`).

## 2026-10-23: factory order lists in game (S-95 merged; C-111)

- **sim-A did request 44 (S-95):** MOVE, FIGHT, PATROL, GUARD, REPAIR and ATTACK on a factory go on its order list (shift appends, a plain order replaces, STOP clears). Each unit it builds rolls out, then takes a copy in order. Main is merged into this branch (with C-107..C-109, models' BAR pairs 5–9 and the missiles).
- **Client:** factories now offer Attack too (`Core/CommandSet`, spec updated). Their drawn orders already stay until replaced (C-109).
- **`FactoryOrders.spec`:** a move, then a shift-queued patrol, sent to a vehicle plant the way the client sends them (`Orders.encode`). The Lancer it builds carries the move, then the patrol.
- **Studio** (`shield` profile): the plant got a move to (84, −108) and a queued patrol. The new Lancer rolled out and drove to the move point, then started its patrol and held at the first enemies in range, firing at the attackers (a patrol is an attack-move) (`debug_out/screens/factory_orders.jpg`).

## 2026-10-23: shields destroy every shell, in game (S-93 merged; C-110)

- **Your report:** shields still diverted shots. S-93 (every projectile destroyed at an up dome's surface) was on sim-A's branch, not yet in main. It's now merged (main `ead4014`, with S-94: T1 factories at 200 build power, a Lancer in 25.5 s) and merged into this branch.
- **Client:** no change needed; an absorbed SHIELD_HIT already ends the shell at the surface (C-99) and lights the dome there.
  - `ShieldWire.spec`: the two field tests (shells braked and turned inside the dome) are replaced by one for heavy shells: Ravager shells are destroyed exactly at the surface (within 0.5 stud, measured from the dome's real centre at the generator's base), with no turn, breach or field-entry hits and none drawn inside.
- **Studio,** `shield` profile, 30 s of every attacker type: 663 SHIELD_HIT, all absorbed; no field entries, no breaches, nothing turned back (`debug_out/screens/shield_absorb_all.jpg`).

## 2026-10-23: per-unit command sets; factory orders; Roblox top bar cleared (C-109)

- **Asked:** each unit its own commands (defense on / off and stop; builders move, stop, repair, assist; silos stop the launch and attack manually; air its own); queued orders for units new from factories; remove Roblox's top bar, minimap and resource bars up there, settings and resign in the upper-left corner.
- **Command sets** (`Core/CommandSet`, pure, `CommandSet.spec` 2):
  - every type: stop;
  - armed: attack and fire state (silos, whose weapons are all stockpiled launchers: attack only);
  - mobile: move, fight, patrol, guard, and move state when armed;
  - builders that aren't factories: repair and reclaim;
  - factories: repeat, cancel, and move / fight / patrol / guard;
  - switchable (converters, or a def with `toggle`): on / off;
  - the alert jump always.
  - `UI/CommandCard` shows the selection's union in card order and resizes. Repair (target an own unit) and reclaim (the known wreck nearest the click, within 24 studs) are new command modes in `Api.commandAt`; E starts reclaim, with hints and the keys table updated.
  - Checked in Studio: Mason stop / move / patrol / fight / guard / repair / reclaim; vehicle plant repeat / cancel / stop / move / patrol / fight / guard; shield generator and fusion stop only; Oracle movement only.
- **Factory orders:** `Core/Waypoints` keeps a factory's orders (they don't expire on idle). The sim uses only the last move-like one as its rally point; sim request 44 asks for the full list copied to each new unit.
- **Top bar:**
  - `Main` turns off Roblox's core UI and asks `SetCore("TopbarEnabled", false)`;
  - the resource bars (y 6), the alert feed (y 52) and the debug overlay (y 6) draw from the top of the window (IgnoreGuiInset);
  - the Settings button sits in the top strip right after Roblox's corner, following `GuiService.TopbarInset` (measured 164 × 58 at the top left, unchanged with the top bar disabled: Roblox keeps its menu button);
  - the minimap stays just under that corner.
- **Screenshot:** `debug_out/screens/hud_topstrip.jpg` (Mason selected: its 8 commands; resource bars and debug overlay at the top; Settings top left).

## 2026-10-23: smaller minimap; effect meshes in the materials file (C-108)

- **Minimap:** 280 → 220 pixels (the user: smaller). The build menu now starts under it (`MinimapUI.SIZE`), so both tile rows fit above the unit panel on short screens. Screenshot `debug_out/screens/minimap_220.jpg`.
- **Effect meshes** (models-C's request): `lune run mesh_materials` also writes a SurfaceAppearance per `Meshes.fx` entry, named `fx_<id>`: the six missiles and the shield emitter, merged from m-models `764874b`. `MeshMaterials.spec` checks them.

## 2026-10-23: build menu portraits and tooltip; On / Off; short-way turns; shield and T2 defense requests (C-107)

- **Your notes** (after a shield test):
  - shield simple (destroy on contact);
  - build speed too slow, and factories say OFF;
  - units sometimes rotate the long way;
  - build menu BAR style (model preview at an angle plus icon), stats on hover;
  - more T2 defenses like the Pulsar (corrected from T3).
- **Build menu** (`UI/BuildMenu`, `UI/Portrait`):
  - **Tiles:** 66 px, 4 per row. Each holds a ViewportFrame with the unit's model template (`Render/Models`: the mesh when ready, else the blockout), team-colored, the camera at a three-quarter view from the front right and above, framed to the model's bounds. Portraits rebuild only when the def, the team or the template changes (a mesh replacing its stand-in).
  - **On each tile:** the type glyph (18 px) at the bottom right; supply (white) and power (yellow) stacked at the bottom left; the hotkey top left; the queued count top right. The name moved to the tooltip.
  - **Tooltip** (its own screen at DisplayOrder 30, over the unit panel and command card, kept on screen): the name in yellow-green as in BAR's unit panel, the description, cost with build time at the selected builders' highest build power, health, and `UnitStats.lines` (new `UnitStats.ofDef`: a type's sheet with no live state).
  - **Height:** the menu fits between the minimap and the unit panel (top-bar inset included) and scrolls when short.
- **On / Off** (`UI/CommandCard`): the sim's TOGGLED_ON is used by converters only, so other selections show "On / Off" with a grey bar instead of a red "Off".
- **Short-way turns:**
  - `Core/PieceAnim.setGoal` turns from the current angle by the wrapped difference;
  - `Core/Interp` extrapolates heading by the wrapped step;
  - `PieceAnim.spec`: 170° → −170° at 20°/s takes 1 s and ends at −170°;
  - the server's `Shared/Combat/Aim` already wrapped. A hull that turns the long way would be the sim's movement; not seen in testing.
- **Requests:** sim 42 (shield destroys every projectile on contact; T1 build speed) and 43 (T2 defenses: Pulsar-style beam tower with an off / retract state, then more); models 2 (the tower meshes; C's proposed pieces: `base`, `turret` sinking y −2.4 when retracted, `barrel`, `muzzle`, client-only shell lids `shellL` / `shellR`).
- **Screenshots** (`debug_out/screens/`, `fog` profile): `buildmenu_tooltip.jpg` (vehicle plant menu, Lancer tooltip), `buildmenu_structures.jpg` (Masons' Economy tab).

## 2026-10-23: review follow-ups: modal panels, fitted layouts, graphics options, model loading order, glow against team color (C-106)

- **Asked** (your review of C-103..105, approved): modal panels; fill the space; graphics options for detailed models, glow and headlights; load on-screen and own-faction models first. Then: white glow where a team color clashes, and the factory pulse capped at about 3.
- **Modal** (`UI/Kit`):
  - panels are 95% opaque (`panelTransparency` 0.05);
  - every panel has a scrim (black at 55%, `Active` so clicks stop there) under it;
  - the settings gui is at DisplayOrder 110 and the lobby / statistics gui at 100, above every HUD screen (5–40) and the debug HUD;
  - a click on the settings scrim closes it.
- **Fitted layouts:**
  - `Kit.panel`'s `setHeight(h)` sizes a panel to its content, never above the screen;
  - settings fit the selected page (at least the sidebar's height) and refit when it changes;
  - the lobby fits its rows;
  - statistics: a 3 × 2 `UIGridLayout` in scale units fills the panel (1180 × 660, shrinks to fit); Economy's six charts, and Combat with damage dealt / taken, units killed / built / lost / alive (alive = 1 + built − lost);
  - `Kit.chart` fills its cell and draws at the plot's real pixel size, redrawing when it changes size.
- **Graphics settings** (`Core/Settings`: `detailedModels`, `glow` `off`/`low`/`high`, `headlights`; `Settings.spec`):
  - **Detailed models:** `Models.setDetailed` clears the templates; the pool drops its copies and every drawn unit is drawn again. Off draws blockouts and starts no mesh loading.
  - **Glow** (`Core/Glow`, `Glow.spec`): off = dark; low = the resting glow and the stall dimming; high = also the factory pulse and the weapon flash.
  - **Headlights:** on/off for the SpotLights.
  - Checked in Studio: toggling Detailed models swapped units to blockouts and back, with no errors.
- **Model loading order** (`Render/MeshModels.want`, `Main.wantMeshes`):
  - loading starts when the first units arrive (2 s after joining at the latest);
  - each job's priority is the highest it was given: 3 drawn on screen, 2 in the match (strategic records by their icon, S-58), 1 the player's faction; ties go alphabetically; refreshed twice a second while jobs wait;
  - **Measured** on the `fog` profile: `ord_vehplant` 2.5 s, `ord_mason` 3.6, `ord_herald` 4.5, `ord_lancer` 5.3 (before: 16–19 s, behind every Chaos model); the full set 18.2 s.
- **Glow against team color** (C's table in docs/contracts/fx.md):
  - `Core/Glow.clashes(faction, team, channel)`: Order on team 7 (cyan) and Chaos on team 6 (orange) turn `running` and `power` white (235, 240, 245); head and weapon stay; yellow on Chaos stays (C: borderline, no switch);
  - applied by `ModelPool.acquire` with the team color, from each glow part's own tint otherwise;
  - checked in a `fog` match with teams 7 and 6: Order Lancers and plant white, Chaos Ravagers on team 6 white, a Chaos Ravager on team 7 amber (`uikit2_glow_clash.jpg`).
- **Factory pulse** `PULSE_HIGH` 4 → 3:
  - `uikit2_plant_pulse4_before.jpg` (3.93) is a flat white block under the night bloom;
  - `uikit2_plant_pulse3.jpg` (3.0) is still bright;
  - `uikit2_plant_stalled.jpg`: the same plant on an energy stall at the 0.3 floor.
- **Statistics data:** `src/roblox/StatSeries` and its test are removed; the results carry `Stats.series(sim)` (S-88), with damage taken.
- **Screenshots** (`debug_out/screens/uikit2_*.jpg`): settings Graphics (modal, fitted), lobby (modal, fitted), statistics Economy and Combat (3 × 2) at UI scale 1 and 1.2, the clash and pulse shots above.

## 2026-10-23: UI kit; settings, statistics and lobby rebuilt on it (C-105)

- **Asked:** a UI kit in the BAR statistics panel's style (style only), then settings, a statistics panel and the lobby rebuilt on it, then the stats and selection panels.
- **`UI/Kit`** (one theme module):
  - **Colors:** panel (20, 22, 27) at 15% transparency; border white at 86%; text (226, 229, 235), dim and faint greys; accent amber (238, 186, 92); green on, red off; a dark amber for chosen HUD buttons.
  - **Font:** Montserrat (`rbxasset://fonts/families/Montserrat.json`), the closest built-in to the reference's geometric sans; Builder Sans was the other option.
  - **Type scale** 26 / 16 / 14 / 12, **spacing scale** 4 / 8 / 12 / 16 / 24, **corners** 10 (panels) and 6 (controls).
  - **Stripe and shadow:** a 16 px tile and a 64 px 9-slice soft shadow, drawn once into EditableImages (no asset).
  - **Components:** `panel` (title, optional sidebar with a highlighted pill; shrinks to fit the screen at the UI scale), `section`, `row`, `toggle`, `slider`, `button`, `segmented`, `dropdown` (a drawn chevron: Montserrat has no arrow glyph), `chip`, `scroll` (4 px bar), `table`, `chart`.
  - `skin(gui)` gives older HUD screens the kit's font, borders and corners, including elements added later.
- **Settings** (`UI/SettingsMenu`): built once.
  - **Camera:** pan speed and zoom step sliders, edge scroll toggle.
  - **Graphics:** quality segmented, with what it caps; fog of war toggle; atmosphere dropdown.
  - **Interface:** UI scale slider.
  - **Audio:** says there's no sound yet.
  - **Keys:** a two-column table per group.
  - Same `Core/Settings` state and `apply`; settings last for the session.
- **Statistics** (`UI/Statistics`), the results screen:
  - **Overview:** the title (VICTORY, DEFEAT, ELIMINATED or MATCH OVER), the match length, the scoreboard (team swatch, faction, team, end, built / lost / killed, supply and power gathered / spent, damage), replay buttons, back to lobby.
  - **Economy, Combat, Units:** charts of the server's samples in team colors, filtered by the chips.
  - Damage taken shows "comes with sim request 41".
- **Data:**
  - `src/roblox/StatSeries` samples `Stats.report` and the team accounts' stored amounts every 150 ticks; past 120 samples it halves and doubles the interval.
  - `Main.server` sends them with the results (`finishMatch`), and the results carry each player's `team` for colors.
  - The Studio debug `FtggDebug:Invoke("results")` ends a lobby match now.
- **Charts** (`Core/Chart`, pure): LTTB downsampling to at most 120 points, nice axis tops (1 / 2 / 5 × 10^n), short labels (1.5k, 3M), and an anti-aliased rasterizer into an RGBA buffer.
- **Frames vs EditableImage, measured** (one chart: 4 lines × 120 points):
  - **EditableImage:** 4.6 ms per redraw (raster and upload), one instance, about 100 KB of image memory, nothing after it's drawn.
  - **Frames:** 476 rotated Frames per chart (5,712 for a 12-chart page), 8.5 ms to create, 0.57 ms to move them.
  - Their standing cost while shown couldn't be isolated: Studio was pinned at 65 ms a frame by the 4× sim.
  - **Chosen: EditableImage.** No standing instances, anti-aliased lines, and a redraw only on new results or a filter change, one chart a frame (12 charts in about 12 frames, under 5 ms each).
- **Lobby** (`UI/Lobby`) rebuilt on a kit panel:
  - map dropdown; mode and win segmented; friendly fire toggle;
  - per seat: faction, AI level / open and team segmented, × to remove;
  - Add AI, Add seat, Start (amber).
- **HUD:** `UnitPanel`, `CommandCard`, `BuildMenu` and `ResourceBar` use the kit's panel, control and selected colors, and `Kit.skin`.
- **Specs:** `Statistics.spec` (4): sampling and halving, downsampling keeps the ends and a spike, axis numbers, the rasterizer.
- **Screenshots:** `debug_out/screens/uikit_*.jpg`, at Studio's viewport of 1548 × 601. A 1080p viewport can't be set from the tools here.

## 2026-10-23: one shield hit reads as one impact (C-104)

- **Your report:** the shield's touch effect looked like 5–6 shots happening at the same time.
- **Measured** (`shield_one`: one Ravager against a Phalanx):
  - 23 shells fired, 23 SHIELD_FIELD, 22 SHIELD_HIT, 22 domes lit: each shell lights the dome once;
  - the lights came one every 1.4 s, the Ravager's reload, so they aren't bunched either.
- **The cause was the look:**
  - a hit lights a patch of 7 hexagon plates (the centre and one ring);
  - the ring's plates were almost as opaque and white as the centre (×0.82 heat, full opacity);
  - under the night bloom each Neon plate bloomed into its own white blob, so one shell read as a cluster of shots (`shieldhit_close_before.jpg`).
- **Fix** (`Core/Shield.plateAt`):
  - each ring out is `RING_ALPHA` (0.3) as opaque as the one inside it;
  - its heat falls 40% a ring (floor 20%), so it reads grey;
  - the centre stays white-hot. `Shield.spec` checks the centre outshines ring 1.
- **Screenshots:** `shieldhit_before.jpg` / `shieldhit_after.jpg` (play distance) and `shieldhit_close_before.jpg` / `shieldhit_close_after.jpg`.
- **Not changed:** the ripple: C's texture has three rings by design.

## 2026-10-23: glow pass; BAR models built from the mesh manifest (C-103)

- **Asked:** after C's glow pass (M-22), drive the glow states: power dims on an energy stall, factories pulse while producing, weapons flash per shot; optional SpotLights at close zoom or night, capped at the 12 nearest on screen, no shadows; measure with 200 units; `glowfx_*.jpg`.
- **Models first:**
  - The game place had no `ReplicatedStorage.Models`, so every unit was a blockout. C won't edit the game place and sent a mesh manifest instead (`@shared/Defs/Meshes/Registry`, M-23, merged from m-models).
  - `Render/MeshModels` builds each "approved" entry once at start: `CreateMeshPartAsync` per piece and glow part, 4 models at a time; Motor6Ds at the pivots, muzzles, `TeamColor` on team pieces; glow parts welded, albedo = tint, tagged `Glow` with their attributes.
  - `Render/Models` prefers a place model, then the mesh model, then the blockout. While a mesh builds, its blockout stands in and isn't kept as the template; when the mesh is ready the pool drops the old copies and the drawn units are drawn again (`UnitRenderer.reshow`).
  - Measured: 19 models in about 21 s, none failed.
- **The Plugin wall:**
  - A game script can't set `SurfaceAppearance` maps or `EmissiveMaskContent`, nor `MeshPart.RenderFidelity` ("lacking capability Plugin"). Studio's own tool can, which is why a first test looked fine.
  - Without the mask, `EmissiveStrength` shows nothing: tested at 20, no change.
  - Fix: `place/MeshMaterials.model.json` (generated by `lune run mesh_materials` from the manifest, `Core/MeshMaterials`), mapped by the three project files to `ReplicatedStorage.MeshMaterials`: a SurfaceAppearance per model (color, normal, roughness and metalness maps, Overlay) and "Glow" (the shared white mask).
  - Rojo writes those properties; the client clones them (cloning carries them). `RenderFidelity.Precise` goes in through `CreateMeshPartAsync`'s options.
  - The file lives outside `src` because darklua turns a JSON file into a Lua module. Without the folder, a piece falls back to its color map as the MeshPart's `TextureContent`, and glow parts don't emit.
- **Glow driver** (`Core/Glow`, pure, `Glow.spec` 5; `Render/Glow`):
  - Glow parts are collected once when a model is drawn; `EmissiveStrength` is written only on a change of 0.02 or more.
  - **States:**
    - power = rest × the team's power stall ratio (floor 0.3), or the 1 Hz pulse 1.5–4 while a factory's queue isn't empty (also scaled by the ratio; out of step by unit);
    - weapon = 6 on a shot (`fx.shots`), easing back to rest over 0.3 s;
    - running and head stay at rest;
    - everything is 0 while the unit is being built.
  - Enemy structures assume no stall (the client only knows its own economy).
  - **Headlights:** a pool of SpotLights (Front, 55°, range 36, brightness 2.5, warm white, no shadows) in Attachments on the chosen vehicles' roots, at their head glow parts, aimed along the heading. Every 0.25 s they go to the nearest on-screen vehicles, capped by the quality's light budget (12 at High), within 220 studs of camera distance or always in the night and dusk atmospheres; off at strategic zoom.
  - **Debug:** `Invoke("glow")` stats, `Invoke("glowratio", r)` fakes a stall, `Invoke("meshes")` build stats and capabilities.
- **Measured** (Studio, `fog` profile on ridgeline, test units spawned):
  - factory pulse 1.51 → 3.99 at 1 Hz, one write a frame;
  - Lancer weapon glow peak 6.0;
  - stall at ratio 0.12: power parts at the 0.3 floor, clearly dimmer;
  - 200 units: 146 glowing models, 615 parts, driver 0.19 ms average (0.76 worst), 21 writes a frame, frame 16.7 ms average (18.3 worst).
- **Not done:** builders brightening while building (no "building" field on the wire; a sim request if wanted). C's "review" models (Oracle, Watcher, Order vehicle plant) stay blockouts until approved in the manifest.
- **Seen:** at close zoom the C-102 mist reads as separate grey puffs; to tune with your review.
- **Screenshots** (`debug_out/screens/`):
  - `glowfx_vehicles.jpg`: both factions' vehicles, running strips and headlights;
  - `glowfx_headlights.jpg`: the earlier TextureContent build, before the materials;
  - `glowfx_factory.jpg`: the Chaos vehicle plant producing;
  - `glowfx_stall_full.jpg` and `glowfx_stall_low.jpg`: generators and solars at full power and at a 0.12 stall;
  - `glowfx_fight.jpg`;
  - `glowfx_200.jpg`.
- **CLAUDE.md:** the `place/` folder and `lune run mesh_materials`.

## 2026-10-23: environment and colour grade (C-102)

- **Asked:** map edge, night sky, terrain colours and ambient particles; then, mid-task, "pay attention to the ColorCorrection, this should be the most impressive part", and "leave the map grey" so the ghost structures can be seen.
- **Colour grade** (`Core/Grade`, pure; `Render/Grade`):
  - **Night grade:** brightness 0.05, contrast 0.32, saturation −0.02, tint (196, 218, 255): moonlight teal with deep blacks.
    - The tint darkens the picture and the brightness gives it back.
    - Three grades were compared side by side in Studio. C-101's grade was flat; a middle step was still too green.
  - **Zoom easing:** the full grade within 150 studs of camera distance, eased (smoothstep) to the strategic grade by 800. There, contrast and saturation keep 55%, the tint goes halfway back to white, and the vignette keeps 60%.
  - **Blast flash:**
    - Every Vfx effect is reported (`Vfx.onSpawn`). Nukes add a flash level of 1; deaths at scale 1.5 and up add 0.35 × size, falling off to nothing 1.2 camera distances from the focus. Impacts never flash.
    - The level is capped at 1 and falls to 1/e in 0.3 s. At level 1 it adds brightness +0.14, contrast +0.06, saturation +0.12 and a warm tint (255, 222, 186).
    - Measured: three Juggernauts killed by the camera took brightness from 0.05 to 0.09 with a warm tint, gone in about 0.6 s.
  - **Vignette:** a 256 × 256 EditableImage drawn once, on a full-screen ImageLabel under every other UI (DisplayOrder −10). Its strength comes from the preset (night 0.55, dusk 0.35, haze 0.3, none for Current and Clear day). Without editable memory there is simply no vignette.
  - **Tonemapper:** Roblox has a ColorGradingEffect, but its only setting is the tonemapper (Default or Retro), so the grade is all ColorCorrection.
- **Night sky** (the `night` preset's `sky`): the six skybox faces set to empty (Roblox's procedural sky, which follows the clock), 3,000 stars, moon size 14. Captured from the place, so Current puts the day skybox back.
- **Terrain colours** (the preset's `ground`): Grass (72, 90, 66), LeafyGrass, Rock, Ground, Sand, Asphalt, Mud, WoodPlanks and water, cooler and duller. Captured from the place and put back by the other presets.
- **Map edge** (`Core/Environment`, pure; `Render/Environment`):
  - Dark Ground slabs (30, 32, 36) 6,000 studs round the map, their top 0.5 studs under the lowest edge surface.
  - Parts are at most 2,048 studs a side, so the ring is 49 tiles (a first try with single huge parts was silently clamped and left gaps).
  - The slabs are not queryable, so clicks go through, and cast no shadows.
- **Ambient particles:** one invisible box (220 × 30 × 220) follows the camera focus within 320 studs of camera distance, with the built-in smoke texture (no asset):
  - dust: 40 per second, 6–10 s, 0.6 studs, a light breeze;
  - mist: 3 per second, 16–24 s, 30–55 studs, 92% transparent.
  - Off at Low quality.
- **Fog of war grey:** explored grey 80 at 38%, never seen grey 56 at 70%, tint (1, 1.02, 1.08).
  - Never-seen ground reads as a flat haze, and explored ground still shows its terrain.
  - The ghosts (C-32: blue-grey copies at 70% transparency) stand out against it. Checked with a Chaos vehicle plant and airfield spotted by a Herald that was then killed.
- **Settings menu:** five atmosphere buttons at 80 px (Dusk was clipped at 104); "Battlefield haze" is shown as "Battle haze".
- **Cost:**
  - CPU: a few property writes a frame, skipped when nothing changed; 60 fps in the playtest.
  - Memory: 256 KB of editable image; 49 static parts; at most about 400 dust and 60 mist particles at close zoom.
- **Specs:** `Environment.spec` (5): the skirt's tiles exactly cover the ring within the part size; the skirt sits under the lowest edge, water included; zoom easing; flashes (impacts and small deaths don't, out of view doesn't, cap, decay); the vignette is clear in the middle.
- **Screenshots** (`debug_out/screens/`, `fog` profile on ridgeline unless noted):
  - `environment_35.jpg`, `environment_55.jpg`, `environment_80.jpg`, `environment_strategic.jpg`;
  - `environment_sky.jpg` (low camera: stars, horizon glow, dust);
  - `environment_ghosts.jpg` (two ghost structures in grey fog);
  - `environment_battle.jpg` (the `shield` profile's fight);
  - `environment_before.jpg` (C-101) and `environment_after.jpg`, the same view.

## 2026-10-23: night lighting by default (C-101)

- **Why:** you said the maps have no sun ("we play in dark environment/time"), and asked for realistic lighting with no brightness and shadow control, to calm the "plastic wrapping" look of the fog blanket.
- **The `night` preset** (`Render/Atmosphere`, first in the list and the default in `Core/Settings`), tuned in Studio on ridgeline:
  - **Sky:** ClockTime 0 (midnight), sun rays off.
  - **Light:** Brightness 2.5, ambient (112, 118, 132), outdoor ambient (140, 146, 162), exposure +1.1, so units read clearly. Shadow softness 0.6.
  - **Sheen:** environment specular 0.15 (was 1) and diffuse 0.6. This removes most of the glossy sky reflection that made the blanket and rocks look wrapped in plastic.
  - **Air:** Atmosphere density 0.2, offset 0.15, haze 0.6, a dark blue-grey colour. First tried at 0.3 and haze 1, but that washed the map flat at strategic zoom.
  - **Bloom:** intensity 0.8, size 26, threshold 1.2, so shells, fire and shield effects glow.
  - **Colour:** contrast +0.1, saturation −0.18, a faint cool tint.
- **Presets** gain two optional fields, `specular` and `diffuse` (EnvironmentSpecularScale and EnvironmentDiffuseScale), captured with the place's own values so Current restores them.
- **Fog blanket:** the explored look is now grey 40 at alpha 0.4 (was 30 at 0.52). Under the night light, explored and never-seen ground looked alike.
- **Settings:** the default atmosphere is `night`. A player who saved another preset keeps it. `Settings.spec` updated.
- **Lighting.Technology** can't be read or set by a script (RobloxScript capability), so the place keeps its own. Realistic is recommended (Roblox's unified technology, which replaced Future).
- **Screenshots** (`debug_out/screens/`, `fog` profile on ridgeline):
  - `lighting_35.jpg`, `lighting_55.jpg`, `lighting_80.jpg`, `lighting_strategic.jpg`;
  - `lighting_before.jpg` (the place's day lighting) and `lighting_after.jpg` (night), the same view;
  - `lighting_shield.jpg`: the `shield` profile's battle at night.
- **Seen in the console:** `rbxassetid://203785492 failed due to: Asset type does not match requested type`. It isn't in this repo, so it's place content (probably the Sky); not new.

## 2026-10-23: fog of war blanket (C-100)

- **Why (your brief):** the point-light fog read as night with flashlights. It made bright blotches where circles overlapped, was capped by the light limit (470-stud culling) and didn't match the sim's cell vision. It's replaced by a BAR-style blanket: normal light everywhere, and what you can't see darkened.
- **States:**
  - **visible:** clear;
  - **explored:** a cool grey layer at 52%, so desaturated and about 40% darker;
  - **never seen:** near black at 74%, about 70% darker.
  - Ghosts of structures show as before: they stand above the blanket.
  - Each pixel's look blends its four nearest sight cells, for soft edges about a sight cell wide, and fades to a new look over 0.3 s.
- **Pieces:**
  - `Core/FogBlanket` (pure, `FogBlanket.spec`, 3 tests): states, the explored memory, blending, fades, the changed rectangle, and the real sim's sight driving it (a scout clears ground and leaves it explored).
  - `Render/FogBlanket`:
    - one EditableImage (128 × 128 for current maps, 64 KB) and 4 EditableMesh chunks draped over the terrain;
    - a vertex every 16 studs, 1 stud above the highest ground within 8 studs, so ridges stay under it;
    - vision read and only the changed rectangle uploaded, at most 15 times a second.
  - The minimap has a Fog layer showing the same image, over the terrain and under the unit dots.
- **Removed:**
  - `Render/FogOfWar` (point lights, ColorCorrection, plates) and `Core/Fog`;
  - their plate and light test (the ghost and contact tests stay in `FogOfWar.spec`);
  - the "Fog lights" setting, now "Fog of war", on by default; it only turns the shading off, and hidden units stay hidden.
  - Lights are now only for glow effects.
- **Roblox rules found on the way:**
  - EditableImage and EditableMesh work in published games with the experience's Mesh / Image APIs setting on. Images are up to 1024 × 1024, meshes up to 20,000 triangles, and each device has an editable-memory budget.
  - A SurfaceAppearance in transparency mode shows the image with alpha, but a game script can't set its ColorMapContent (it needs Plugin capability). A Texture on the mesh projected wrongly.
  - What works: the MeshPart's own TextureContent by UVs, with the part at Transparency 0.02. At 0 it shows the part's colour under clear pixels.
  - A MeshPart made from an EditableMesh keeps the mesh's own origin, so the vertices are in world space and the part sits at (0, 0, 0).
  - The mesh can't be freed while it's shown: destroying the EditableMesh empties the MeshPart.
  - The Studio client's editable-mesh budget ran out after about 7,600 vertices at a vertex per 8 studs. At one per 16 studs a 128-cell map is 4,356 vertices in 4 chunks, and fits.
  - Roblox samples this texture without smoothing, so the soft edges are blended in the image itself.
- **Measured** (Studio playtest, `fog` profile, ridgeline):
  - At rest: 0.013 ms per update (worst 0.31).
  - Stress, `Invoke("fogstress")`: every sight cell on the map flips every update, the whole image rewritten and uploaded each time, worse than any battle. Average 15.5 ms per update, worst 17.6, at 15 updates a second.
  - In Lune, the core alone per update: whole map flipping 4.9 ms (worst 7.1); a quarter of the map 3.0 ms; a big battle with 5% of the map's cells changing 1.45 ms (worst 2.7).
  - A per-update cap of 3,000 pixels spreads larger changes over the next updates.
  - Building the blanket: 0.4–1.1 s at match start in its own thread.
  - **Memory:** the image 64 KB, CPU-side buffers about 400 KB, the meshes 4 × 1,089 vertices. The client's total in Studio didn't move measurably (2,343 → 2,351 MB during the stress, Studio noise).
- **Screenshots** (`debug_out/screens/`, `fog` profile on ridgeline: your base south-west, a scout driven east along the south edge, the north never seen):
  - `fogblanket_35.jpg`, `fogblanket_55.jpg`, `fogblanket_80.jpg`, `fogblanket_strategic.jpg`;
  - before/after, the same view without and with the blanket: `fogblanket_before.jpg`, `fogblanket_after.jpg`.
  - All three states show: clear round the units, grey along the scout's path, dark to the north.
- **Known:**
  - On steep rock formations the blanket floats as a visible shell over the peaks. It's a 16-stud drape over sharp terrain, and it's lit like a surface: your "plastic wrapping".
  - Neon (unlit) looked worse, with a white glow on the rocks. Matte Fabric removes the sun glints.
  - The lighting pass you asked for next (no brightness, shadow control) should calm the rest, and you said the maps may have no sun at all.
- **Debug:** `Invoke("fogshow", on)`, `Invoke("fogstress", seconds)`, `Invoke("fogpattern")` (a test image), `Invoke("fog")` stats.
- **New `fog` profile** on ridgeline.

## 2026-10-23: shield hits on the crossing frame; destroyed shells gone at once; unfinished units see-through; minimap 10 Hz (C-99)

- **Reflect effect still late (found the cause):** SHIELD_FIELD is due on the tick a shell crosses. The client applied it only at that tick's end, so for a whole tick the shell flew on plainly, unbraked and a tick deep into the dome (about 13 studs for a Ravager shell), before its hit showed and the field took hold.
  - Now, during the tick before, the client steps the shell through the field from the tick's start, as the server does, and shows the hit on the frame its drawn path crosses the surface.
  - `ShieldWire.spec` renders in quarter-tick frames like the game: the shell is within 6 studs of the surface when its hit shows. It was 12.6 studs off before the fix; checked by turning the fix off.
- **Destroyed shells travelling on (S-85 rounds):** the absorbed SHIELD_HIT now ends the shell where its drawn path meets the dome, like an IMPACT, instead of at the tick's end. Spec: never drawn more than 4 studs inside.
- **Shield effects follow the sim speed:** the ripple and plates pause and slow with the shells, which helps to see them at 0.1x.
- **Units under construction (your rule):** drawn semi-transparent until complete, then solid.
  - Studio: a Bulwark see-through with its build bar, solid at 1800/1800 when done (`debug_out/screens/c99_bulwark_building.jpg`, `c99_bulwark_done.jpg`).
  - The rest is the server's and is in main (S-87): no firing or other function while unfinished, and no wreck when destroyed.
- **Minimap:** unit dots refresh 10 times a second, up from 3. The guide says the strategic rate (guide 15.8), and the strategic records themselves still come at 2–4 Hz.
- **Shield 20x (your call):** done by sim-A (S-86): Phalanx 600 at 30/s, Carapace 400 at 24/s. Unfinished units are inert and leave no wreck (S-87), and enemies get build progress too, so their frames are drawn see-through as well.
- **Studio:** `c99_shield_entry.jpg` (shield profile, 0.1x, frozen on the hit's frame): the ripple and hexagon at the point where the shell is crossing the surface.
- **Debug:** a server query `FtggDebug:Invoke("build", builderId, defId, x, z)`.
- **Not done yet:** your glow pass (emissive states, lights, 200-unit cost). It waits for C's glow assets to merge (`docs/contracts/fx.md` has no glow section yet).

## 2026-10-23: shells burn in the field like a meteor (C-98)

- **Your drawing:** a curved front ahead of the shell, like atmospheric entry. This replaces C-97's plume, which stretched ahead of the shell.
  - **Bow shock:** C's dome mesh flattened into a glowing cap, curved round the shell's nose on the side the field pushes from.
  - **Burning trail:** streams back from the shell along the force.
  - Both grow with the force, and with the shell's weight.
- **Colour:** white-hot with a little orange (burning); you chose to keep it. The hexagons stay white and grey.
- **Pool:** the same fixed pool of 32, made once C's dome mesh has loaded.
- **Screenshot:** `debug_out/screens/c98_shield_bow_shock.jpg`: `shield_one`, frozen with a Ravager shell braking, side on. The shock front is on its nose, the trail behind it, and its entry hexagons on the right.

## 2026-10-23: force plumes on shells in the dome; light shells absorbed (C-97, S-84, S-85)

- **Force plume (your request):** a shell inside the dome shows the force on it, a glowing plume on the side the field pushes from, flowing into the shell.
  - The force is the field step's change of velocity over a tick, minus the weapon's own gravity (`ShieldLook.force`, `ShieldLook.spec`). So it follows the shot and the dome's centre: braking against the shot, steering and the push out.
  - The plume is 2–14 studs long by strength, and wider for heavier shells.
  - A fixed pool of 32 beams, made on first use.
  - `debug_out/screens/c97_shield_force_plume.jpg`: `shield_one` at 0.1× speed, frozen with a Ravager shell braking. Its entry hexagons are on the right, and its plume stretches ahead of it toward the centre.
- **S-84 (sim-A):** inside the field shells feel an extra 60 studs/s² of gravity on top of their own, so turned shells arc down at the dome's edge. Nothing to change on the client: it steps them with the shared field.
- **S-85 (sim-A, protocol 25):** shells under mass 0.5 (75 damage: machine guns, the Locust autocannon, Hydra and Judgement rockets) are destroyed where they cross the surface. SHIELD_HIT carries the new ABSORBED flag.
  - The client drops the shell with no burst and lights the dome at the crossing.
  - `ShieldWire.spec`: a Locust's rounds are destroyed at the surface, none is drawn inside, and nothing bursts inside.
- **Debug:** `Invoke("camera", x, z, distance, pitch, yaw)` now takes a yaw.

## 2026-10-23: the shield ripple shows on its first frame; a one-attacker test profile (C-96)

- **You still saw the ripple late.** The entry effect did fire on the crossing tick: in Studio it lit for 197 of 197 shells. But a Ravager shell turns only about 1.5 ticks (0.1 s) after it enters, and C's ripple grew from size 0, so it was barely visible until around the turn.
  - **Fix:** the ripple now starts at a third of its size and fully opaque on its first frame, then spreads and fades.
  - **Checked** in `shield_one` at 0.1× speed, freezing sim and effects on the frame the entry fires: the white hexagon and the ripple rings sit at the surface with the shell just crossing it (`debug_out/screens/c96_shield_entry_frozen.jpg`).
- **`shield_one` profile (your idea):** one Phalanx, its fusion plant, a builder in the dome's core as the target, one Ravager to the north. Change the Ravager's def to try other shells.
- **A shell that never showed entering** (one destroyed on contact, or a missed SHIELD_FIELD) now lights the dome at its SHIELD_HIT. That's ready for your next rule.
- **Sent to sim-A** (field rules, theirs to build):
  - extra downward force on shells inside the dome, like gravity;
  - light shots destroyed instantly on contact, heavy ones on the current mechanic. I suggested a cut near mass 0.5 (75 damage): the Locust autocannon and Hydra rockets destroyed, cannon shells turned.
- **Debug:** `Invoke("shielddomes")` now reports entries, domes lit, and the average ticks from entry to turn.

## 2026-10-23: shield hits on entry, white-grey hexagons, thin rings (C-95)

- **Band depth:** you kept the band at 0.4R. sim-A has closed the review item.
- **Hit shows at once:** the hit effect was late because the server's SHIELD_HIT comes at the turn, 16–30 studs inside the dome after braking. The client now lights C's ripple and the hexagon plates the moment a shell crosses the surface: SHIELD_FIELD goes out on that tick, and the point is the shell's position projected onto the dome. The turn adds nothing more; a breach still flashes. No wire change, and sim-A has noted it in S-83.
  - `ShieldWire.spec`: every turned shell first lit the dome on entry, on the surface, ticks before its turn.
- **Hexagons white and grey (your call):** white at their hottest, fading to grey; no red or orange (`Shield.color`, `Shield.spec`).
- **Thin rings:** the flowing rings use models-C's RingThin (`111379471786973`; tube 0.2% of the radius, about 0.24 studs on a 120-stud dome) instead of adornments. C's Ring stays as the foot ring.
- **Studio, shield profile:** 149 turns and 0 breaches in 8 s, dome at 100%, and the meshes loaded (dome, foot, thin rings). Screenshots:
  - `debug_out/screens/c95_shield_entry_close.jpg`: at 0.25× speed, the grey-white hexagons and ripple where shells crossed, the shells already inside;
  - `c95_shield_thin_rings.jpg`: the whole dome with the thin rings.

## 2026-10-23: the shield field inside the dome checked (S-83)

- You asked for shells to pass through the surface and be slowed and turned inside the dome, not stopped outside it. sim-A moved the field band into the outer 40% of the dome (S-83): the core is 72 studs on the Phalanx and 48 on the Carapace. No client change: the client steps shells with the shared field, and hits stay on the surface where the ripple is drawn.
- **Lune:** `ShieldWire.spec` passes unchanged. With the same setup, Ravager shells go about 16 studs inside the dome before turning, and the heavier Juggernaut shells about 30, out of a 48-stud band.
- **Studio, shield profile, 12 s:** 230 shells crossed the surface, 219 turned back, 0 broke through, and the dome held at 100% (`debug_out/screens/c95_shield_inner.jpg`). At 0.1x sim speed the shells show inside the foot ring, slowing there (`c95_shield_inner_slow.jpg`).
- **For your review (from sim-A):**
  - **Head-on at full charge:** the Phalanx stops everything except the Citadel round. The Carapace's 32-stud band also lets the siege mortar through. A band of 0.5R would stop both on the Phalanx and leave only the Citadel round on the Carapace.
  - **Units in the band** can be hit by shells still slowing down there.

## 2026-10-23: C's shield assets in ShieldFx; S-82's field checked (C-94)

- **C's shield FX** (models request, `docs/contracts/fx.md`, `assets/fx/shield/roblox_assets.json`) replaces the placeholders:
  - the Dome hemisphere mesh, so it no longer sinks into the ground as a full ball;
  - C's Ring as the bright ring at the dome's foot;
  - the beam texture, rising from the generator's own `beam` attachment (the Phalanx and Carapace blockouts);
  - the swirl decal turning at the top;
  - the speck and ripple textures (a hit is one ripple particle lying flat on the dome).
- **Generator core:** it now glows green → orange → red with the charge, with no placeholder ball.
- **Meshes:** built from their IDs at runtime, once, in their own thread (I don't touch FTGG Art). Domes wait for them.
- **Your rules over the contract:** the dome stays neutral white, its opacity follows charge, and it isn't ForceField. Everything is tinted white, not team colour.
- **Flowing rings:** they stay thin adornments. C's Ring scales its tube with the ring, a 2.4-stud ribbon on a 120-stud dome. I've asked models-C for a thinner one.
- **S-82** (the field after your drawing) plus sim-A's stalling fix (28bc934), shield profile, 12 s: 271 of 288 shells turned back, 0 broke through, the dome stayed at 100%.
  - Before the fix, about half the shells stalled in the field. I sent sim-A a reproduction from `ShieldWire.spec`, now in sim-A's `Shield.spec` too.
  - In sim-A's measurements, off-centre shots now carry on round the dome: 51° at half the radius off-centre, 14° near the edge. Head-on shots come back at 180°.
- **Screenshots:** `debug_out/screens/c94_shield_assets.jpg` (the scenario), `c94_shield_assets_side.jpg` (generator, beam, swirl, rings).
- **Debug:** `Invoke("shielddomes")` now also counts hits and keeps the last breaches (mass, position) for sim-A.

## 2026-10-23: shield profile checked at 50x strength (S-80, S-81)

- After merging S-80 (your 10x, and the near-mirror bounce: PUSH 2800, TANGENT_DRAG 0.3) and S-81 (your 50x: Phalanx 1500 charge at 75/s, Carapace 1000 at 60/s; the power draw is still 40 / 25 per second, sim-A's call), I ran the `shield` profile in Studio. Under the full barrage the Phalanx dome stayed at 100% for all 12 s measured. 167 of 171 shells that entered its field turned back and 4 broke through. Turned shells fly back out and land in front of the attackers, live (`debug_out/screens/c92_shield_x50.jpg`).
- No client change: the client reads the radius from the def and the charge from SHIELD, and steps shells with the shared field.
- sim-A's note that main's client tests failed on the Phalanx and Carapace icons was already fixed by C-91 (both borrow the Jammer Tower icon). With main merged: test_client 46 specs, 165 passed.

## 2026-10-23: shield domes from the server (protocol 24, S-79, request 40) (C-91)

- **You couldn't see a shield in the shield scenario:** the profile only spawned units, and until S-79 the sim had no shield. I first added a client-only stand-in. While it was in review, sim-A shipped the real thing (S-79: `ord_phalanx`, `chs_carapace`, `Shared/Combat/ShieldField`, events SHIELD, SHIELD_FIELD, SHIELD_HIT), so the stand-in went and the client now draws the server's shields:
  - **SHIELD:** `world.shields[generatorId] = { charge 0..1, flags }`, dropped on LEAVE, DEATH and WELCOME.
  - **SHIELD_FIELD:** the shell steps with `ShieldField.step` instead of the plain ballistic step until its phase is DONE, both per tick and drawn between ticks (`Core/Effects`).
  - **SHIELD_HIT:** a turned missile loses its target, and the hit goes to `fx.shieldHits`.
  - **`Render/ShieldDomes`:** a ShieldFx dome on every generator the client has, round its base, with radius from the def. Strength is the server's charge. It collapses when UP clears, deploys when UP returns, and comes into view already standing without a deploy animation. Hits light the dome they name, or the nearest dome round the point if the generator is hidden.
- **Lune** (`ShieldWire.spec`, real sim and client stack):
  - the client's charge and UP flag follow the server's, collapse included;
  - shells in the field are stepped like the server's (worst 0.07 studs off over 43 shell-ticks);
  - 9 Ravager shells turned back on a full dome, no breach, each hit on the dome surface.
- **`shield` profile:** a real Phalanx on the spot (radius 120, 50× health), a fusion plant powering it, the vehicle plant moved north of it.
- **Studio:**
  - The dome stands on the Phalanx. In 15 s, 72 shells entered its field and 63 turned back, and the turned shells land back outside, live (`debug_out/screens/c91_shield_scenario.jpg`).
  - **Still too weak at today's numbers:** the barrage drains the server's capacity of 30 within a second of each rise. Your 10× is with sim-A (below).
- **Fixed:** two domes appeared on one generator. The first ShieldFx built its hexagon mesh with `CreateMeshPartAsync`, which yields, and the next frame made a second dome. `new()` now never yields: the plate pool builds in its own thread, and the capacity bar's PlayerGui is looked up, not waited for.
- **Icons:** `ord_phalanx` and `chs_carapace` borrow the Jammer Tower icon until the catalogue lists them. The sheet is byte-identical, so no re-import is needed.
- **Sent to sim-A** (the numbers are theirs):
  - **Your "boost 10x":** capacity ×10 with the same refill time, so Phalanx 30 → 300 and recharge 1.5 → 15; Carapace 20 → 200 and 1.2 → 12.
  - **Your "the deceleration is so weak, it reflected 0 shots":** that was my stand-in, which couldn't move shells; the server's field (braking doubled in S-79) turns them back.
  - **Your new deflection rule:** a head-on shot goes straight back, and a glancing one bounces off at an angle. I measured the shared field:
    - head-on shells go straight back;
    - glancing shells are diverted the right way, but leave much steeper than a mirror bounce (30° → 20°, 50° → 29°, 70° → 36°), because the field's sideways drag (TANGENT_DRAG 1.5) takes most of their sideways speed;
    - suggested 0.2–0.3 or none.
- **Debug:** `Invoke("shielddomes")` returns the client's domes and SHIELD records.

## 2026-10-23: ShieldFx — the shield dome renderer (C-90)

- **`Render/ShieldFx`**, your interface: `ShieldFx.new(emitterAttachmentOrPosition, radius, teamColor)`, then `:deploy()`, `:setStrength(0..1)`, `:hit(worldPos, intensity)`, `:collapse()`, `:destroy()`. `Core/ShieldLook` (pure, `ShieldLook.spec`, 6 tests) holds:
  - the timings, deploy and collapse phases;
  - ring positions on the curve (r = R·sin θ, y = R·cos θ);
  - the low-strength flicker and ring flow;
  - the opacity rule, the strategic-detail hysteresis and the off-screen test.
- **Look:**
  - **Dome:** a neutral white dome with a bright edge (your rule: no team colour), opacity following strength, invisible at 0% and full from 50%.
  - **Rings:** 9 thin rings flowing from the top down the dome.
  - **Beam and vortex:** a curved beam from the emitter to the top, a vortex at the top (sparkles turning on a disc plus 3 glowing arcs), floating specks inside, a slow pulse.
  - **Core and bar:** the plasma core (green → orange → red) and the capacity bar above the dome.
  - The "ForceField material" in the brief read grey with no edge in the earlier tests (C-87), so the dome is a tinted ball with a camera-facing edge ring.
- **States:**
  - **Deploy:** the beam reaches the top in 0.4 s, then the dome grows in 0.6 s (ease-out) with a ring flash on the ground.
  - **Up:** the rings flow, the vortex turns, specks drift.
  - **Hit:** a ripple ring spreading from the impact on the dome, red-hot hexagon plates, a brightness pulse.
  - **Low (<30%):** the flicker gets faster and deeper, and the rings dim and slow.
  - **Collapse:** it flickers, the dome shrinks, then the beam retracts. Deploying again works.
- **Performance** (your hard rules):
  - **Fixed pools:** every instance is made in `new()` and only moved or hidden afterwards. That's 9 rings, 4 ripples and 3 vortex arcs per shield, and 160 hexagon plates shared by all shields.
  - **One render loop:** a single RenderStepped loop updates every shield and skips those off screen.
  - **Strategic detail** (beyond 480 studs from the camera): only the dome and its edge.
  - Client-side only.
- **Placeholders:** Studio textures and parts. C's shield assets replace them when they merge (`docs/contracts/fx.md`, `assets/fx/shield/roblox_assets.json`; neither exists yet).
- **Review content** in the place: `ReplicatedStorage.ShieldFxReview`.
  - Two placeholder shield generators: Order, radius 120, a clean stepped plinth with four pylons; Chaos, radius 80, a rusty slab with scrap spikes and a cage.
  - Each has an `Emitter` attachment and `Radius` and `Offset` attributes. It lives in ReplicatedStorage so a playtest's terrain doesn't swallow it.
  - **Not built, by your answers:** the Warden's small dome (shield generators only), and radius 48 for the generator (you set 120 earlier). Both are easy to add.
- **Debug calls** (Studio playtest), `FtggClientDebug:Invoke("shieldfx", op, ...)`:
  - `review` places the generators round the camera's focus, each with its dome;
  - `spawn`; `bench` (n, radius) puts a grid round the focus;
  - `deploy`, `collapse`, `hit` (intensity), `strength` (f), `drain` (to, seconds);
  - `slow` (time scale, for screenshots), `stats`, `clear`.
  - `Invoke("camera", x, z, distance, pitch)` places the camera.
  - `Invoke("shield")` still runs the mechanic demo, now on this dome (`Render/ShieldDemo`).
- **Fixed after your question:** the Order generator lay on its side and sank into the grass. The model's pivot came from its base cylinder, which is turned 90°, and placement used the sim's ground height rather than the rendered terrain. The models now pivot upright at their bottom centre, and placement raycasts the terrain (`shieldfx_generator.jpg`).
- **Screenshots** (`debug_out/screens/`, the `shield` profile, both generators, hits running):
  - camera angles at 220 studs: `shieldfx_35.jpg`, `shieldfx_55.jpg`, `shieldfx_80.jpg`;
  - deploy: `shieldfx_deploy_beam.jpg`, `shieldfx_deploy_grow.jpg`;
  - other states: `shieldfx_low.jpg` (15%), `shieldfx_collapse.jpg`;
  - the 20-shield test: `shieldfx_20_close.jpg`, `shieldfx_20_strategic.jpg`.
- **Measured** in a Studio playtest, `shield` profile, radius-24 domes in a grid, deployed and settled, averaged over 2.5–3 s. "Loop" is ShieldFx's own render-loop CPU per frame; render CPU and GPU are Roblox's `Stats` frame times, which are noisy in Studio and include the whole scene.

| Shields | Zoom | Loop ms (avg / max) | Render CPU ms | Render GPU ms |
|---|---|---|---|---|
| 0 | close (220 studs, 55°) | 0.04 | 6.8 | 4.0 |
| 1 | close | 0.12 / 0.21 | 6.2 | 3.6 |
| 5 | close | 0.53 / 0.72 | 7.1 | 3.9 |
| 20 | close | 1.87 / 2.32 | 9.8 | 5.6 |
| 0 | strategic (600 studs) | — | 7.0 | 4.6 |
| 1 | strategic | 0.10 / 0.33 | 10.2 (noise) | 3.8 |
| 5 | strategic | 0.13 / 0.28 | 5.3 | 0.5 |
| 20 | strategic | 0.34 (without the bars) | 5.2 | 2.8 |
| 20 | off screen | 0.07 (20 skipped) | — | — |

  - The first strategic 20-shield run cost 0.72 ms. Hiding the capacity bars at strategic detail brought it to 0.34 ms.
  - At close zoom the loop costs about 0.09 ms per shield. Most of that is the rings and the edge.
  - Final numbers need a live device; Studio adds its own overhead.

## 2026-10-23: shield test scenario; a neutral, bigger dome that fades with its charge (C-89)

- **`shield` profile** (set `ACTIVE = "shield"`), the test ground for when the sim has the Phalanx:
  - **Defended spot:** a 120-stud dome position on (0, -150) on flat land. Under it, Order units that don't shoot back, at 50× health so the test lasts: a vehicle plant at the centre (for the Cyclops), a radar and three builders near the north edge.
  - **Attackers:** from the north, all outside the dome and its field, every shell weight:
    - Locust autocannons (lightest);
    - Ravager and Juggernaut shells, aimed at the edge units so they cross the dome;
    - Hellmouth mortars and Hydra rockets on attack-ground at the centre;
    - Cyclops siege mortars (heaviest, structures only, spotted by a Watcher).
  - **Checked in Studio:** 21 units spawn, every row fires, and the server's "under attack" alerts come in. The sim still has no shield, so the shells hit for real.
- **Dome look (your call):** neutral white-grey, no team colour. Rim, field, idle hexes and sparkles are all white.
  - **Opacity follows the charge:** invisible at 0%, full from 50% up. The rim fades on a squared curve because white Neon blooms.
  - Hits stay red-hot; the core and bar still run green → orange → red.
- **Size (your call):** the demo dome is now 120 studs radius, twice the Phalanx design's 60 (`ShieldFx.DEMO_RADIUS`). Idle hexes and sparkles scale with the size.
- **Screenshots** (`debug_out/screens/`): `c89_shield_scenario.jpg` (the attack rows firing at the dome), `c89_shield_full.jpg` (100%), `c89_shield_30.jpg` (30%, fainter).

## 2026-10-23: shield hexagons as one mesh (C-88)

- You turned on EditableMesh, so the plates now use the hexagon prism: one MeshPart each, clean edges, no star seams. That's a third of the parts the three-rectangle fallback needed (`debug_out/screens/c88_shield_hex_mesh.jpg`, normandy). No warning or error in the console.
- Idle team-coloured flickers no longer draw over a live hit patch. A flicker won't start next to one, and a new hit clears the flickers around it (`Shield.spec`, 12 tests).

## 2026-10-23: shield dome prototype, client only (C-87)

You asked for a client-only prototype of the plasma deflector, with no sim change. `Core/Shield` holds the logic (`Shield.spec`, 11 tests) and `Render/ShieldFx` draws it. `FtggClientDebug:Invoke("shield", seconds?)` starts a test dome under the camera with fake fire heavier than its recharge, so it runs down, collapses and rises again.

- **Dome, in team colour:**
  - a tinted field ball;
  - a bright rim on the sphere's outline as the camera sees it: 64 thin Neon segments, recomputed each frame, so terrain and units in front still hide it;
  - plasma sparkles on its surface;
  - faint team-coloured hexagons flickering at random spots.
  - The rim dims with the field's force and flickers below full force.
  - The ForceField material (it read grey) and Highlight (its outline vanished on a transparent ball, and only 31 can show at once) were tried and dropped.
- **Plasma core and capacity bar:**
  - The core and its halo are green at full charge, orange as it drops, red near empty.
  - The capacity bar sits above the dome's outline, in screen space, with a mark at 25%. A BillboardGui wouldn't render in the playtest.
- **Collapse and rise:**
  - At 0% the dome collapses: it flashes, shrinks and fades, and the core sputters. Shells then pass through, and the bar reads "Shield down · x% / 25%".
  - At 25% it rises again, growing out of the core.
- **Repulsor field** (your rules):
  - In a 50-stud band outside the dome, an inbound shell slows down until it stops, which is the hit, then the field throws it back out, speeding up.
  - Force is full at 50% charge and above, and scales with charge below that. It's divided by mass^0.6, so heavier shells take longer to stop.
  - Measured at full force: mass 0.5 takes 0.17 s, mass 1 takes 0.22 s, mass 4 takes 0.40 s. At 35% charge a mass-4 shell breaks through, at 20% a mass-2.5 one. They get inside still slowed, and light shells are still turned back.
  - Each shell turned back costs 0.04 charge per unit of mass. Recharge is a flat 0.05/s in the prototype; the real dome would draw power for it.
- **Hit:** hexagon plates wrap the dome round the hit point, 7, 19 or 37 by strength.
  - They go white hot, then yellow, orange and red, ripple outward ring by ring, and fade in about 0.65 s.
  - The centre dents in and springs back, with sparks and a light flash.
  - Hits within 6 studs of a young patch merge into one hotter patch.
  - Caps: 6 patches per dome, 400 lit plates.
- **Studio (normandy, playtest)**, in `debug_out/screens/`:
  - `c87_shield_full.jpg`: 100%, green core, team rim, idle hexes, a red-hot hit, shells in flight.
  - `c87_shield_low_breach.jpg`: 26%, orange core and bar, a heavy shell through by the core, a light one turned back.
  - `c87_shield_collapsed.jpg`: the dome down, the core sputtering, "Shield down · 5% / 25%", a shell passing through.
  - `c87_shield_rising.jpg`: the dome growing back from the core at 25%.
  - `c87_shield_hex_merge.jpg`: a close-up of the hexagons and a merged burst (the earlier ForceField look).
  - No script errors.
  - The last tweak, a dimmer rim at low force, isn't in these shots.
- **Hexagon shape:** three rectangles 60° apart, because EditableMesh is off in this experience's Security settings. They show faint star seams up close.

## 2026-10-23: draft 3 icons wired in; your 2-client test; S-75 units drawn (C-86)

- The draft 3 sheet is wired in (`tools/icons/assets.json`: `87919807696998`). Rebuilding it gives the same PNG byte for byte, so the import matches the atlas.
- Main brought four new units (S-75). The sheet has no tiles for them yet, so they use existing icons until the catalogue lists them: Locust as Light Tank, Cyclops as Artillery, Barrier as Storage, Citadel as Heavy Turret. The renderer reports each one on every run.
- **Your 2-client test** found a bug: every frame, Player 2's build menu errored at `Icons:95` on the Locust, which wasn't on the sheet, and left a blank "Label" button. Fixed two ways: the stopgap icon, and `Icons.ofDef` now gives a def with no tile its domain's plain frame instead of erroring (`IconAtlas.spec`). Apart from that, the test worked. The server seated both players and refused Player 2's lobby change ("only the host"). The match started on crossroads with both players building, and neither client logged a script error (`debug_out/screens/c86_duo_player1.jpg`, `c86_duo_player2.jpg`). The asset error `rbxassetid://203785492` in the log doesn't come from this repo.
- **Icon pairs at real size** (cut from the imported sheet, tinted as ImageColor3 does, 22 px × tier scale, grass and sand; `debug_out/icons/pairs-real.png`, `pairs-4x.png`):
  - fixed: bomber vs strategic bomber (one chevron vs two, dots and size), MBT vs MLRS (shell vs rocket fan), airfield vs rearm pad (triangle vs H), fighter vs air superiority;
  - **still hard:** gun turret vs floating turret, the same shield and shell, where the floating turret's waves blur into a smudge at 22 px, worst in red on sand.
  - The Studio check in normandy waits until your 2-client test is over: I didn't stop it.
- S-77 (replay format 2) and the Citadel's second slot need no client change: `parse` reads both formats, and the default aim turns each slot's `turretPiece`.

## 2026-10-23: alerts from the server, S-69 to S-73 followed (C-85)

- Alerts now come from the server (request 39, S-68, protocol 23): unit or structure under attack, Command Vehicle under attack, unit or structure lost, construction complete, supply or power stall, nuclear launch, each with the unit's name, rate-limited by the server. The client's own guesses are gone. Own and allied units the server marks under attack blink red on the minimap and as strategic icons. `Ui.spec` runs a real fight, loss, stall and build through the server's alerts; `debug_out/screens/c85_server_alerts.jpg`.
- S-70: a Fusion Reactor's death draws a blast as wide as its damage (`Splash.spec`). S-72: radar power drain shows as upkeep in the unit stats. S-73: "Friendly fire" On / Off in the lobby (on by default). S-69: ground attack already went out for any selection, so artillery, tanks and turrets can now shell a spot with no client change; MLRS salvos draw rocket by rocket.

## 2026-10-22: sound plan

- `docs/SOUND_PLAN.md`: the sounds the game needs and candidate Roblox audio IDs from Studio's Creator Store search, nothing inserted. ProSoundEffects (Roblox-licensed) where it has a fit; several community uploads are ripped from other games and marked "don't use".

## 2026-10-22: Warden and Minotaur animations (C-84)

- S-64's faction units animate: the Warden swings its spades down, squats onto them and levels its gun over the 4 s it unpacks (when it stands still), and reverses while it packs before driving off, gun locked forward; the Minotaur's ram strikes forward on its demolition charge (weapon slot 2) and draws back slowly. Piece scripts `Core/PieceScripts/ord_warden`, `chs_minotaur`, with a new `Deploy(u, phase)` hook driven by the DEPLOYED / DEPLOYING bits (protocol 22). `tests/client/Deploy.spec` runs a real Warden through unpacking, deployed, packing and packed. The blockouts are the models stream's (request 3: Warden `spades`, Minotaur `ram`); until they land both draw as the generic placeholder, so there is no Studio screenshot yet. Barrier walls and the Citadel aren't in the sim yet.

## 2026-10-22: atmosphere presets (C-83)

- Four lighting presets, chosen in the settings menu (O, "Atmosphere"); Current stays the default. Same fight in the normandy battle, same camera, 4 s each in Studio (60 fps cap, so the frame is 16.7 ms in all four; GPU and CPU are Roblox's render frame times):

| Preset | Look | GPU | CPU | Screenshot |
|---|---|---|---|---|
| Current | the place as saved (Roblox's default sky, Atmosphere 0.3, Bloom) | 4.26 ms | 6.46 ms | `debug_out/screens/c83_atmosphere_current.jpg` |
| Clear day | thinner, bluer air, a touch more colour and contrast, softer bloom | 4.80 ms | 7.12 ms | `c83_atmosphere_clear.jpg` |
| Battlefield haze | thick warm-grey air, muted colours, sun rays through it | 4.76 ms | 6.24 ms | `c83_atmosphere_haze.jpg` |
| Dusk | a low warm sun (17:12), orange horizon, stronger bloom and rays | 4.91 ms | 6.14 ms | `c83_atmosphere_dusk.jpg` |

  The presets cost about 0.5 ms of GPU (the colour correction pass and the denser air); the CPU differences are the fight's own variation. Lighting technology (Future) can't be set from a script, so it isn't part of the presets.

## 2026-10-22: nuke crater, water splashes (C-82)

- A nuke that bursts near the ground now digs a crater in the Terrain instead of leaving the 240-stud dark scorch decal (your idea): a shallow bowl (radius 0.45× the blast, depth 7% of that, at most 6 studs) with a scorched basalt floor, a ring of mud around it and an uneven earth rim. It is visual only and kept shallow, since units still drive at the sim's height. Each crater's area is copied first and put back on the next WELCOME (checked in Studio: 1,727 basalt voxels, then 0 after a new WELCOME). `debug_out/screens/c82_nuke_crater.jpg` (as it forms, under the mushroom cloud), `c82_crater_close.jpg` (one dug directly, close up).
- Shells, bombs and torpedoes that land in open water splash: a white column that falls back, spray, mist and a foam ring on the surface, instead of fire, dust and a scorch mark; a hit on a ship (a hull under the point) still explodes. `tests/client/Splash.spec` (in a corvette fight 3 of 30 impacts splash, the hits explode; on land none do). In Studio the splash is too brief to catch in a screenshot (`c82_naval_hit.jpg` shows a hit on a ship).

## 2026-10-22: icons for S-64's new units (C-74 follow-up)

- The Warden and the Minotaur (S-64) have no entry in your icon set yet: they draw as the Main Battle Tank (T2 vehicle) until the catalogue has them, and `render.mjs` reports it on every run. The sheet's layout is now stable: tiles keep their spots when units or entries are added, so the uploaded sheet stays right until the next import (the rebuilt sheet is byte-identical).

## 2026-10-22: settings menu (C-81)

- O (or "Settings" above the follow button) opens a settings panel: camera pan speed, zoom step and edge scroll; graphics quality Low / Medium / High (caps on explosions, tracers, projectiles, lights and copies of one effect, and the distance of full piece animation) and fog lights on / off; UI scale (0.7 to 1.5, the UI panels only: overlays at world positions keep screen pixels); and the key bindings reference. Values apply live; they last for the session. High is today's look; fog lights default off (your earlier call). `tests/client/Settings.spec`; screenshots `debug_out/screens/c81_settings.jpg`, `c81_settings_low_scale12.jpg`.

## 2026-10-22: requests 37 and 38 used, faction pass followed (C-80)

- Countermeasure charges (request 37, S-63, protocol 21): the unit panel shows own units' flares and chaff left from the server ("Flares 6/6 · Chaff 6/6", `debug_out/screens/c80_charges.jpg`); other players' units keep "max". `OwnerFields.spec` checks the client's counts against the server's.
- Match statistics (request 38, S-63): the results come from the sim's `Stats.report`: units built / lost / killed, supply and power gathered / spent, damage dealt. My server-side `MatchStats` (C-77) is removed.
- Faction pass (S-62): radar precision weighs each Pinpointer (`Pinpoint.weight`: 5 Witnesses or 7 Augurs for full). Specs that hard-coded unit numbers now read them from the defs (a Lancer now does 141 per 1.75 s = 80.6 DPS against armored). Two Studio-scene bounds moved with the new numbers (SAM prediction median at the Thorn's 165 studs; Wyvern pitch-overs when targets die early), and a Moving spec bug surfaced: it encoded the move with the client's placeholder grid before the WELCOME (fixed: the map's grid).

## 2026-10-22: spectators and the replay viewer (C-79)

- Spectators: a Roblox player without a seat (a full lobby, or a profile with no free slot) watches as a spectator on sim-A's spectator stream (S-18): every unit, no fog, a "SPECTATING" banner; re-added at every new match. New profile `spectate` (the duel, both sides played by the placeholder bot) shows it in a solo playtest (`debug_out/screens/c79_spectator.jpg`).
- Replays: in a lobby match the server records each human's stream as a PlayerReplay (sim-A's format; 32 MB cap for all recordings together). The results screen has Save replay (kept for this server session; on a live server also a DataStore copy), Watch replay and the saved ones. Watching streams the file to the client in 200 KB chunks; it plays through the same NetIn path as the live stream with a bar at the bottom: play / pause, slower / faster (0.25× to 8×), time, a seek bar (click anywhere; back starts over from the first tick, which is fast), Exit (back to the live match with a new HELLO). Orders are not sent while a replay plays.
- Verified: `tests/client/Replay.spec` (playback, pause, 4×, seeks forward and back, and the file round trip all give exactly the live client's view at the same tick; a spectator sees every unit as player 0; 20 s of a 2-AI match is 8.6 KB). In Studio: a 31 s match, Save (2.9 KB), Watch, 4×, seek forward, pause, seek back, Exit back to the results, no errors (`c79_results_replay.jpg`, `c79_replay.jpg`, `c79_replay_seek_back.jpg`). The DataStore copy is skipped in Studio (it needs API access; a live server tries it).

## 2026-10-22: rejoin, late join, restart (C-78)

- `tests/client/Robustness.spec` checks the client against the server's own view in three cases: a client joining a running match (every unit the server shows it, nothing else, health within the wire's step, the sight map whole), a dropped client replaced by a fresh one that joins as the same player (the same, with no CAMERA sent again: the server keeps it), and a match restart on a new sim and map with the same client (the new map, team and units, none of the old).
- Fixed: after a restart or rejoin, unit IDs start over, and the old selection, control groups, waypoints and command mode pointed at other units (the restart test caught the selection keeping ID 1, the new match's Command Vehicle). The client API now clears them on every new WELCOME.
- In Studio: the running client sent HELLO again, as a reconnecting client does; the server re-joined it as sim player 1 and the client rebuilt its view (196 units, no errors; `debug_out/screens/c78_rejoined.jpg`). The restart path ran in Studio with C-77 (lobby → match → results → lobby, no errors). A real disconnect can't be made in a solo Studio test.

## 2026-10-22: two humans, lobby seats, results with statistics (C-77)

- Two humans can play one match: the lobby has seats (a human, an AI with Easy / Normal / Hard, or open for a human to join), each with a faction and, in Teams, an ally team; the first human hosts (map, mode, win rule, seats, start), every human picks their own faction; open seats nobody took drop out at the start. A human who leaves mid-match keeps the seat and rejoins into it; in the lobby the seat opens (the host passes to the next human). Results come when the match is over or every human is out, and show victory or defeat for each viewer, plus a table per player: end, units built / lost, supply and power gathered / spent, damage taken (`src/roblox/MatchStats`, counted by the server each tick; damage dealt and kills wait for request 38). New profile `duo`: the lobby with two open seats.
- Verified in Lune with two full client stacks on one match (`tests/client/TwoPlayers.spec`): both join as their own player, each sees only its own units through the fog with its own sight map, neither can select or (with a forged command) move the other's units, they meet and fight, both see the deaths, and annihilation ends it for the survivor. Lobby seats, the host's rights, two humans with an AI, and the statistics in `tests/client/Lobby.spec`.
- In Studio (one client, profile `duo`): the lobby with seats, seat 2 set to a Hard AI, a match, defeat with the statistics table, back to the lobby with the seats kept; no errors (`debug_out/screens/c77_lobby_seats.jpg`, `c77_results_stats.jpg`). **Not done: the 2-client Studio test.** Studio's "Clients and Servers" test can't be started from my Studio tools (they only start a solo playtest); to run it: set `ACTIVE = "duo"`, Test tab, Clients and Servers, 2 players, Start; the first client hosts.

## 2026-10-22: unit stats in the unit panel (C-76)

- One selected unit (or a hovered one: an enemy always, an own one when nothing is selected) shows its stats, BAR style, from `Core/UnitStats`: per weapon DPS against its main target class (named), range, reload, spread, damage per shot, and for missiles guidance, lock range, stockpile and refill time; speed, sight, air sight, radar, sonar, jammer and tracking radius; cost, build power and build options; income, upkeep, conversion, extraction or storage; health, build progress, the server's fire / move state, ammo and countermeasures. Enemies: full stats only in sight or tracked; a ghost its type's stats without health; a radar or sonar contact its domain only. `tests/client/UnitStats.spec` (a Lancer does 75 DPS against armored). Screenshots: `debug_out/screens/c76_falcon_stats.jpg`, `c76_factory_queue.jpg`, `c76_hover.jpg`. The panel is 460 px wide now (the build grid shows 2 rows, the command card moved right).
- Countermeasure charges show the def's maximum ("Chaff max 2"): live charges aren't on the wire (request 37).

## 2026-10-22: request 36 used (C-75)

- Factory queues, fire / move states and ammo now come from the server (S-61, protocol 20): the unit panel's queue line, the build grid's queued counts and right-click cancel read the server's queue; the command card's fire and move state buttons show the server's state for the selection; aircraft show their real ammo. The client's own guesses (`Core/FactoryQueue`, the last state sent) are removed. `tests/client/OwnerFields.spec`: the client's queue equals the server's on every tick of 1,350 (head progress within 1/16), fire / move states after each command, and ammo.

## 2026-10-22: the user's icon set (C-74)

- Your icon set (draft 2) is in the game (C-74): one sprite sheet (asset 96380571554418), team-tinted, drawn by the strategic icon layer, the build grid and the unit panel; ghosts at 45%, radar and sonar contacts as dashed frames. All 127 unit types map to your catalogue; `node tools/icons/render.mjs` rebuilds the sheet from the HTML. Readability at real size (22 px) in the normandy battle, on grass and sand: `debug_out/screens/c74_icons_grass.jpg`, `c74_icons_sand.jpg`, `c74_icons_real_size.jpg` (every icon, both teams, with ghosts), `c74_icons_ui.jpg`. Hard to tell apart: Bomber vs Strategic Bomber, Main Battle Tank vs MLRS, Airfield vs Rearm Pad, Gun Turret vs Floating Turret; close but readable: Fighter vs Air Superiority and the IR vs radar SAMs; T1 vs T2 dots are about 2 px.

## 2026-10-22: overnight run

- Fog and wrecks from the server (C-65): the client now uses the server's exact team sight, allies included (it used to work it out from its own units). Wrecks appear for anything the team knows of, also after joining, and disappear when reclaimed (`debug_out/screens/c65_wrecks.jpg`).
- Client performance in the normandy battle (C-73): 60 fps at normal and full zoom in Studio; the client's own frame work is 1-2 ms. The biggest cost, the icon layer at full zoom, dropped 60% (1.67 → 0.66 ms) by only writing what changed.
- Pinpointers (S-59, C-72): radars, radar SAMs and Pinpointers show the team's radar precision in the unit panel as "Accuracy 50%" (`debug_out/screens/c72_radar_precision.jpg`).
- BAR-style UI (C-71, the user's reference screenshot): minimap top left, the build grid under it, unit info bottom left, the command card next to it with colored state bars, BAR's resource bar; unit icons are now BAR-like glyphs (shape, role mark, tier pips) instead of letter codes (`debug_out/screens/c71_bar_layout.jpg`). BAR's real icons are CC BY-NC-ND, so they can't be used in a Roblox game; see the question in the summary.
- Match flow (C-70): new profile `skirmish` starts in a lobby (map, mode, win rule, faction, AI slots Easy / Normal / Hard), then a match from the map's starts against the AI, a results screen (victory, defeat, or eliminated while the AIs fight on) and back to the lobby (`debug_out/screens/c70_lobby.jpg`, `c70_results.jpg`).
- Camera pitch (C-69): Alt + scroll tilts the camera between 35° and 80°. At low pitch the area the server sends in full detail stops at about 1.8 camera distances, so it never reaches the horizon (farther units show as icons). At 35° in the battle: 8.4 KB/s received (8.5 at 55°), 1.7 ms of client frame work (`debug_out/screens/c69_pitch35.jpg`, `c69_pitch80.jpg`).
- Playable placeholder UI (C-68): a build menu by category tabs (B, then 1..0), a command card (move M, fight F, attack A, patrol Z, guard G, stop S, fire state L, move state K, repeat Y, on/off U, cancel X), a unit panel (health, weapons, stockpiles, build progress, factory queue) and alerts (under attack, structure lost, power stall, nuke launch) with minimap pings and J to jump to the last one (`debug_out/screens/c68_build_menu.jpg`, `c68_factory_queue.jpg`, `c68_alerts.jpg`). Factory queues, fire / move states and ammo aren't on the wire yet (request 36): the queue shown is what the client queued.
- Every unit type has its own icon (C-67): its family shape with a unique two-letter code from its name (Ln Lancer, Pa Paladin, Rc Reckoning...), now that the server sends each unit's type in strategic records (S-58) (`debug_out/screens/c67_unique_icons.jpg`).
- Terrain from the sim's terrain layer (C-66): sand, rock and roads are drawn where the sim has them, so what looks like sand slows units. On Normandy: leafy hedgerows, asphalt roads, plank bridges, and brick houses with slate roofs in the villages (`debug_out/screens/c66_village.jpg`, `c66_bridge.jpg`). Also merged S-58 (protocol 19: unique icon numbers per unit type).

## Needs my review

Cleaned up on 2026-10-23: you approved the current values of everything listed up to C-130 (shield hit look, wrecks, towers, beam timing, command sets, build menu, UI kit, glow, environment, lighting, settings, hotkeys, camera, effects). Those entries are gone. What's left are real open questions.

- **Models still at "review"** (the game draws the blockout or placeholder until models-C flips them; preview with `FtggClientDebug:Invoke("shellanyway", true)` and so on):
  - the shield shell's honeycomb bands (C-138);
  - the Commander mechs v3 (`ord_sovereign`, `chs_warlord`; M-33, on main);
  - the extractors at footprint 2 (and their wrecks);
  - on m-models, not merged here yet: the T1 structure redesigns, pairs 2–7 (generators, solar, wind, depots, Bulwark / Spike, vehicle plants).
- **Sound IDs:** `docs/SOUND_PLAN.md` lists candidate Creator Store audio for every sound. Nothing is inserted until you pick.
- **Camera turn keys (C-159):** turn right moved from E to C, since E is also BAR's reclaim. Rebind it in Settings > Keys if you prefer something else.
- **Terrain sharpening after a long camera jump (C-162):** Roblox's voxel terrain draws a far area coarse and sharpens it over a few seconds; scripts can't control it. Your call:
  - leave it;
  - glide the camera on long jumps instead of teleporting (it softens the pop but doesn't remove it);
  - replace the voxel terrain with our own mesh ground at full detail everywhere (a bigger job, and a different look to tune).
- **Lighting technology:** set `Lighting.Technology` to Realistic in the place (a place setting scripts can't change).
- **New since C-130, for a look in your playtest:**
  - the unit in production on the factory pad (C-152): hologram, build line, nano spray;
  - The Canyon's desert colours and daylight (C-153, C-155): `debug_out/screens/c155_canyon_day_*.jpg`;
  - radar blips circling 1.5 studs out (C-154).
  - the radar accuracy circles and readout in the sensor view (C-181): colours, the readout's place under the resource bar. A tracked contact's circle (±2.6 studs) sits inside its blip disc.

## Requests for the models session

3. **Baked map ground (2026-10-23, the user; C-167, `docs/contracts/map-ground.md`):** mesh tiles of each named map's ground from `lune run export_ground` (the Canyon first, status review), ground textures for desert, redrock, grass, rock, sand, road, leafy and ground, and rock detail (Canyon mesa rims, cliff terraces, boulders; then Normandy's bluffs). Uploads need the user's approval.

2. **T2 defense meshes (2026-10-23, the user asked; sim request 43 brings the defs):**
   - a Pulsar-style beam tower per faction, with a tall emitter barrel, glowing charge rails on the base (`power` glow), and a **retract pose**: an armored shell the turret sinks into when switched off (a piece the client moves down, e.g. `turret` dropping into `base`, plus shell plates);
   - then the other T2 defenses as the sim defines them;
   - BAR style, as for the T1 pairs, with glow parts and the manifest.

1. **Silo blockouts (C-57, 2026-10-21):** `ord_reckoning` (Order, "Reckoning") and `chs_ragnarok` (Chaos, "Ragnarok"), the T3 nuke silos from S-48, have no blockouts yet, so the generator draws them as plain boxes. Footprint 3 (24 × 24 studs); pieces `base`, `hatch` (opens for the launch; a lid or two doors on top) and `muzzle` (where the nuke leaves, inside the hatch, pointing up). Faction styles as usual. Medium priority.

## Requests for the sim session

66. **Open (2026-10-24, the user's reference 6, C-207): terrain-cut radar.** The user wants radar coverage drawn like BAR's: a green fill **cut by terrain** (line-of-sight shaped). Our `Sensors` stamps radar as a plain circle, so a client-side cut would show coverage the server doesn't apply. Is a terrain-occluded radar map (per emitter, from its height over the ground heights, like BAR's radar LOS) something you'd add to `Sensors`, with a shared pure function (e.g. `Shared/Sensors/RadarLos.cells(layers, x, z, height, radius)`) so the client draws exactly the server's cells? Until then the client draws the circle the sim uses (C-207) and swaps in the shared function when it lands. If you'd rather keep radar circular, say so and I'll tell the user.
65. **Runs 1–3 done (2026-10-24, your request, next.md item 1): Studio watchdog runs.** Raw lines: `debug_out/watchdog_2026-10-24.txt` in FTGG-client (gitignored; ask and I'll paste any part).
    - **Setup:** MatchConfig profile `watchdog` (C-204, on m-client-foundation 6352d16): map:twin_lakes seed 13, 4 Hard AI FFA, Command Ends, `income all 100` each, `speed 4`; I watched as a spectator. Studio Play (client and server in one process, so the server shares the CPU with rendering). Server code at main d6643d4. Ticks 0–22,030 (24.5 game minutes); 85 units at minute 2, 195 at 4, peak **273 at minute 7**, 236–245 at minutes 11–14, then 140–190 after the drop at tick 13,442 (most likely a player eliminated).
    - **Every tick stayed under the 54 ms tick budget except one** (104.2 ms, below). Mean tick 1.1 ms (min 1) → 6–10 ms (min 7–14, 210–245 units) → 5–7 ms late. Ticks over some system's budget: 0.6–7.3 % per minute (worst minute 11, 7.3 %).
    - **Per system** (flagged = WARN lines naming it over 2× its budget; lead = it was the worst system on the line):

      | System (budget ms) | Flagged / lead | Median when flagged | Peak ms | Peak at | Units then |
      |---|---|---|---|---|---|
      | **Damage (2)** | 104 / 103 | 6.3 | **96.1** (tick total 104.2) | tick 13,442 (min 14.9) | 236 → 151 (likely an elimination: its units self-destruct, S-144) |
      | Damage (2), next worst | | | 24.1 | 10,991 (12.2) | 236 |
      | **Pathing (8)** | 24 / 21 | 18.2 | 26.4 (tick 43.9) | 7,596 (8.4) | 223 |
      | **Commands (1)** | 290 / 284 | 2.6 | 7.2 | 2,097 (2.3) | 68 |
      | NetOut (6) | 2 / 2 | 16.4 | 16.4 (tick 35.7, with Movement 11.1 of 10) | 3,983 (4.4) | 218 |
      | NetOut (6) | | | 14.1 | 1,584 (1.8) | 85 |
      | Weapons (5) | 1 / 1 | | 12.9 | 3,242 (3.6) | 140 |
      | Construction (1.5) | 6 / 3 | 4.1 | 6.8 | 8,160 (9.1) | 209 |
      | Sensors (5), Targeting (8), Movement (10), Economy (1) | 0 | | 3.4 / 5.2 / 11.1 / 0.1 | | |

    - **Reading:** Commands is over its 1 ms on most WARN lines from minute 0 (2–4 ms with 4 AI submitting: the AI's command load, not players'); Damage runs 4–9 ms through every big fight from minute 4 and spikes to 96 ms when a player's army self-destructs; Pathing spikes 15–26 ms every few hundred ticks (flow-field builds for new goals?); NetOut 2–6 ms routinely, 12–16 ms spikes (one spectator, so a 4-player server would pay more).
    - **Run 2 / run 3 (2026-10-24, server at main 3471b0f, S-164 and `--!native`):** same profile and seed; the AI now plays a different game (S-160..S-162), peaking at 311 units against 273. Run 2 is discarded: from tick ~6,000 to ~20,000 the machine also ran Lune tests, builds and an m-models sync, and every system took one-off 25–95 ms spikes in turn. Run 3 ran with nothing else from me. Summary file: `debug_out/watchdog_2026-10-24_runs2-3.txt`.

      | Ticks 0–22,100 | Run 1 (d6643d4) | Run 3 (3471b0f) |
      |---|---|---|
      | Ticks over 54 ms | 1 (104.2 ms) | **0** (worst 44.5) |
      | Mean tick per minute | 1.1 → 10.0 ms | 1.3 → 9.9 ms |
      | Damage (2): flagged / median / peak | 104 / 6.3 / **96.1** | **5 / 5.4 / 5.7** |
      | Pathing (8) | 24 / 18.2 / 26.4 | 59 / 18.6 / 29.0 |
      | Commands (1) | 290 / 2.6 / 7.2 | 426 / 2.6 / 10.6 |
      | NetOut (6) | 2 / 16.4 / 16.4 | 6 / 12.6 / 19.2 |
      | Construction (1.5) | 6 / 4.1 / 6.8 | 2 / 3.4 / 9.0 |
      | Weapons (5) | 1 / 12.9 | 0 |
      | Movement (10) | 0 (11.1 once) | 1 / 24.0 |

    - **Reading:** Damage is fixed (an eliminated player's army no longer stalls a tick). Commands is unchanged: 2–3 ms on most ticks with 4 AI. The Pathing spikes are unchanged in size and more frequent, with bigger armies in this game. Run 3 went on to tick 83,344 (92 game minutes, the idle machine kept up with speed 4); between ticks 70,000 and 81,000, one-off spikes hit every system in turn (NetOut up to 92.6, Sensors 57, Pathing 54), the same pattern as run 2's contamination, likely other sessions' Lune runs. A Studio Play measurement shares the CPU with whatever else the machine runs.
63. **Done (S-138; checked through the real path, FrameQueue.spec).** (2026-10-23, the user: "Add the ability to queue inside the factory while it being built"): accept a factory's queue (and CANCEL / REPEAT) while it's still a frame, start producing when it's finished, and send the QUEUE owner field for the frame. The client already offers the build menu on an unfinished factory.
62. **Done (S-136; used by C-158 / C-169).** (2026-10-23, the user's queue item 4): **An idle signal for own units.** Owner-only and sent on change, covering units outside the camera (owner fields ride only tactical records, and the strategic flags are full): which of the player's builders have no orders and no build / assist / repair / reclaim / guard / patrol work, and which factories have an empty queue. The client guesses from what it sees until then (C-158).
61. **Done on m-sim-2 (S-133, 04c70db; not on main yet, merged into this branch for the user's playtest):** the pad position matches the client's frame (vehicle plant: 64, 47.4). (2026-10-23, the user: "why the spawn point of the unit when finished building was too far off? It starts where its built"):** **Produced units start on the build pad.**
    - The finished unit spawns at the factory's `buildpad` (from the blockout's attachments, model space, rotated with the facing) with the factory's heading. Today it's halfSize + one cell out, then EXIT_ROLL: ~12 studs past the pad on a vehicle plant.
    - It then drives out along the heading through the factory's own footprint, then takes the rally order.
    - The client draws the frame there already (C-152).
    - Your call how it leaves the impassable footprint: a scripted roll or own-team yard cells.
60. **Done (S-131, main 0a34204; drawn by the client, C-154):** strategic records carry only the cell, so S-131's 1.5-stud server orbit can't show. The client circles each blip 1.5 studs round its spot instead. I suggested sim-A drop the drawn offset and keep only the hidden aim point. (2026-10-23, the user: "that radius is huge, in BAR, just 1-2 studs"): **Small blip orbit, hidden aim error.** S-130's orbit radius (= radar error, 13–45 studs) is far bigger than BAR's. At the user's choice:
    - The drawn blip orbits ~1.5 studs around the real unit (same ~6 s turn, own phase and direction per contact).
    - The radar error stays as now, but only in the server's aiming: weapons firing at a radar contact aim at a hidden offset point (radius = radar error, or the Pinpointer's tracking error), so radar shots still miss as before. The client never learns that point.
    - This relaxes guide 11.4's "never the true position" for display: the sent position is within ~2 studs of the true one. The user accepted that. Please update 11.4 with it.
    - No client change needed: C-151's glide already draws it.
59. **Done (S-130, main 57299f7; checked in Studio: a blip sweeps a full turn in ~6 s at radius 13–17).** **Radar blips circle around the real unit (the user, as in BAR):** the wobble offset follows a slow orbit (radius = radar error) instead of moving between random points, so the true position still never goes on the wire (the user chose this over sending true positions, which guide 11.4 forbids). Guide 11.4 to be updated with it. The client already glides (C-151).

58. **Fixed (S-126, on main b7f0f09; verified headless, 70 s with no crash):** the crash was a beam fired at a dead structure's ghost (Radiance may target ghosts, D101 / S-113); hitscanHits indexed the gone unit. Now a shot at a gone target is a miss at the believed spot. Regression test added.

57. **On main (S-125, 6c68d4c; behaviour verified headless, but see 58): cause was a lost spotter (an unseen manual target counted as out of range). Now point-capable weapons keep firing at its last known spot while it lives and that spot is in range (beyond range: own picks); on its death the weapons search the same tick.** **Manual targets:** dropped for a dome generator after a couple of dome-blocked shots while the ordered unit still lives (headless repro sent); and when the chosen unit dies, back to auto-targeting at once (the user).

56. **Done (S-123, main 3860e72; checked in Studio).** **Beams vs overlapping domes (the user's screenshot):** a burning beam must re-check its line against every up dome each tick. When #1 collapses, it stops at #2 behind it instead of going through; when a dome rises across it, it's cut there. A new FIRE / SHOT whenever the end changes; the client follows (C-144, C-147).

55. **Done (S-122, on main f3334c7; client C-145; checked in Studio).** **Shield domes render regardless of vision (the user, as in BAR):** send dome state (centre, radius, charge, flags) for enemy domes touching the camera area, whatever the team sees, without revealing the generator; the client draws domes from it.

54. **Done (S-120 / S-121, on main 4356074; checked in Studio): structures take ATTACK (manual target, any fire state); a dome dropping under a beam sends a new FIRE / SHOT to the target; the client continues the beam (C-144).** **An ordered target must stick (a Radiance ordered onto a Phalanx picked a tank), and a beam must go on through a dome that drops under it.** Proposed wire: a new FIRE / SHOT on the drop tick; the client continues the burning beam (C-144, ready). Manual-target priority over fire state is S-120.

53. **Built (S-119, merging): attack-ground for BEAM / HITSCAN; aim held while a beam burns; NetOut sends aim on ENTER.** **Attack-ground for BEAM / HITSCAN; turret aim during a beam (the user):**
    - Beams and hitscan should fire at an ordered point; pierce damages anyone crossing.
    - Cause of the "turret doesn't aim at its target" report (beam towers in shield_beams): the attack-ground order is ignored, the tower tracks a Mason wandering inside the dome (~15° of swing), and its fixed 3 s beam no longer lines up with the barrel.
    - Also asked: hold the aim on the fired line while a beam burns.

52. **Built (S-118, protocol 28, merging): SHOT carries weaponDefIndex; the client to draw hidden beams as full beams.** **SHOT should say it's a beam:** a hidden shooter's beam arrives as SHOT (both ends, no weapon), so the client draws a plain tracer: no held beam, glancing leg or shield pulses. Asked for the weapon's def index on SHOT (protocol bump).

51. **Built (S-117, merging): a beam stopped by a dome drains it over its duration (best damage / 150 × 12.5: Radiance 250, Inferno ~142). The user: shields were far too strong against beams.**

50. **Built (S-116, merging): beams end at the first up enemy dome (FIRE hit = false on its surface, absorbed SHIELD_HIT); Radiance's pierce stops there; the client's glancing leg (C-129) shows once merged.** **Shield domes deflect beams (the user's sketch):** a beam meeting an active enemy dome ends at the contact (FIRE end point, hit = false); pierce damage stops there; the dome takes a SHIELD_HIT. The client draws the glancing leg (C-129, ready).

49. **Built (S-115, merging): Radiance beamDuration 3, pierce along its fixed line; manual targets kept until STOP, a new ATTACK or the target's death.** **Radiance a hit-ray; manual targets override (the user):**
    - Radiance `beamDuration` 3.0; during the beam, damage goes to every enemy the beam's line crosses (a miss on a blip still hurts what's on the line). An amendment to S-113.
    - An attack order on a unit beats the unit's own target choice. Out of range, the unit picks its own targets; back in range, it returns to the manual target. STOP clears it.

48. **Built (S-114, S-116, merging): two Furnaces then extractors first; an enemy structure contests a deposit only within its weapon range + 40 (a hold-fire Bulwark by the base froze the Chaos AI's expansion).** **The skirmish AI builds too many Furnaces (the user):** hard or normal AI puts up many `chs_generator`s instead of extractors on free deposits. Sim-A to check the Chaos AI's economy choice. Nothing on the client.

47. **Built (S-113, merging): beamDuration (Radiance 2.5, then 3 in S-115; Inferno 1.5, range 480), Radiance targets radar blips.** **Beam towers apart (the user):** Radiance can target radar blips, may miss them without a Pinpointer (S-59 precision), and its beam lingers longer for high damage. Inferno has a smaller range and a weaker beam. Client side: hold the beam for the sim's duration field once named (0.45 s today). Inferno's beam stays orange (the user changed their mind on green).

46. **Built (S-111, merging): radar SAMs air only (AIR 1,150 / 1,100); anti-nukes `ord_providence` / `chs_cerberus` and mobile `ord_custodian` / `chs_chimera`, INTERCEPTOR / INTERCEPTED, stock in STOCK; client side to do.** **Radar SAMs stop intercepting nukes; a new anti-nuke "umbrella" unit (the user):**
    - **Radar SAMs** (`ord_radar_sam`, `chs_radar_sam`): drop `intercepts`, air only; damage retuned so a T2 radar SAM one-shots T1 air.
    - **Anti-nuke:** intercepts any enemy strategic missile whose target point is inside its cover range, with a certain hit and a delay after each shot, so several nukes on one spot overwhelm it. Tier, cost, range, delay and names are sim-A's call (Order and Chaos versions).
    - Client side once it lands: blockouts, icons, interceptor visuals, a cover-range ring.

44. **Done and used (S-95; C-111).** **Orders for the units a factory builds, as a queue (2026-10-23, the user):** "queue up command for newly built unit from factories like pre-move to this location, guard something, patrol."
    - Today a MOVE / FIGHT / PATROL given to a factory sets one rally point (Orders.give; PATROL becomes fight).
    - **Please keep the factory's whole order list instead,** as for a unit: MOVE, FIGHT, PATROL, GUARD (a unit), REPAIR, ATTACK. Shift appends, a plain order replaces, STOP clears it.
    - Each unit the factory produces rolls out of the exit, then takes a copy of the list, so a pre-move then a patrol, or a move then guard a commander, works.
    - The client already offers Move, Fight, Patrol and Guard on factories and keeps drawing the factory's orders until they're replaced or stopped (C-109). Nothing new is needed on the wire.

43. **First part done and used (S-96; C-112): beam towers `ord_radiance` / `chs_inferno`, flak towers `ord_lumen` / `chs_hailstorm`.** **More T2 defenses, a Pulsar-style beam tower first (2026-10-23, the user asked with BAR's Pulsar as the reference; the user corrected T3 to T2):** today the defenses above T1 are thin (Order's Citadel is T3).
    - **A long-range beam tower per faction, T2** (as BAR's Pulsar):
      - a precise ground-to-ground beam (`type = "BEAM"`) with very long range (Pulsar: 1400 against Citadel-class ranges here), a very heavy hit and a long reload (Pulsar: 10,800 damage every 9.9 s, small area);
      - a big **power cost per shot** (Pulsar: 1500), so the economy matters;
      - **"Turn it OFF to retract into its armored shell":** off (TOGGLED_ON clear) it can't fire but takes far less damage (about 4× effective HP). This gives the on/off button a use beyond converters;
      - high enough to fire over other defenses;
      - poor against radar contacts (a precision weapon: the Pinpointer accuracy from S-59 applies).
    - **More T2 defenses** for both factions, e.g. a heavy laser or plasma turret, a long-range AA site, a T2 artillery emplacement. Names in the faction styles (Order Latin / virtue / heraldic; Chaos myth beasts / ruin).
    - **Builders:** the T2 builders' buildOptions.
    - **Client side:** I'll draw the beam (the user's reference: a thin bright line with a glow from the barrel to the target, held for the shot), the retract pose in the piece script, and the on/off button. The models stream needs the meshes (models request 2).

42. **Done and used (S-93, S-94; C-110).** **Shield: destroy every projectile on contact; faster unit production (2026-10-23, the user):**
    - **Shield, made simple:** "destroy projectile on contact, that will ease thing out." Every projectile that reaches an up enemy dome is destroyed at the surface (SHIELD_HIT ABSORBED, as the light shells already are, S-85), whatever its mass: no braking field, no turning back, no breach.
      - Keep the charge drain per hit (by mass) and the collapse at 0% / rise at 25%.
      - The client already draws an absorbed hit at the surface; it will drop the field's bow-shock look once you confirm.
      - Please keep the hitscan / beam stop from S-89.
    - **Build speed:** "build speed for a single unit take too much time." A Lancer is 5,100 build time at the vehicle plant's 100 build power: **51 s each**, longer on a stall.
      - BAR's T1 tanks take about 25–30 s at a plant. Halving T1 build times, or doubling the T1 plants' build power, would match.
      - Your call which, with the balance report.

41. **Done and used (S-88, `Stats.series`; C-106).** **Match statistics over time (2026-10-23, the user asked, C-105):** the statistics panel charts each player's numbers over match time.
    - **Please keep, in `Sim/Stats`, a sample every 150 ticks (10 s)** per player:
      - supply and power gathered, spent and stored (the team account's);
      - units built, lost and killed;
      - damage dealt and **damage taken** (new: health removed from this player's units by enemies, capped like damage dealt).
    - Keep at most 120 samples per line: past that, drop every other sample and double the interval.
    - Expose them with `Stats.report` or a `Stats.series(sim)`, in the shape `src/roblox/StatSeries.luau` uses (`t` in seconds; `players[tostring(pid)][field]` arrays).
    - **Meanwhile** `src/roblox/StatSeries` samples `Stats.report` on the Roblox server. That's fine for live matches, but replays and headless runs don't have it, and it can't give damage taken. The client switches to the sim's series when it's there.

40. **Done and used (S-79, protocol 24; C-91).** **Shield generators on the wire (2026-10-23, the user asked; the client draws them with `Render/ShieldFx`, C-90):**
    - **Mechanic** (the user's rules):
      - A shield generator structure (no vehicle shield). Order's dome is bigger than Chaos's; the client prototype uses radius 120 (Order) and 80 (Chaos), placeholders.
      - Charge draws power to recharge.
      - Inside a field band outside the dome, an inbound shell slows to a stop and is thrown back out. Heavier shells take longer to stop.
      - Full force at ≥50% charge, scaling down below that, so big shells break through, slowed.
      - The dome collapses at 0% and rises again at 25%.
      - Bounced shells stay **live**: they explode where they land.
      - The client's placeholder numbers are in `src/client/Core/Shield.luau`. Since C-91 the shield is 10x stronger (the user): 0.004 charge per unit of shell weight turned back, 0.002 per breach, recharge 5%/s.
    - **Per shield, on the generator's record**, for everyone who can see it (enemies included, since the dome is visible):
      - radius;
      - strength fraction (u8 is enough);
      - state: up, down (collapsed) or recharging (rising).
      - It changes rarely, so it suits a State record or the strategic flags.
    - **Hit events:** the world position of each shell turned back or broken through, plus intensity (the shell's mass or damage) and whether it broke through. The client lights the hit ripple and hex patch there.
    - Bounced shells already arrive as projectiles, so they need nothing new.

39. **Done and used (S-68, protocol 23; C-85).** **The ALERT event and the strategic UNDER_ATTACK flag (2026-10-22, the user asked):** owner-only alerts (attacked, lost, built, stalls, nuke, commander attacked) rate-limited on the server, and the flag on units hit in the last ~3 s. Sent to sim-A directly.

37. **Done and used (S-63, protocol 21; C-80): the unit panel shows own flares and chaff left.** **Live countermeasure charges for own units (C-76, 2026-10-22):** the unit panel shows ammo from S-61 but flares / chaff only as the def's maximum. Suggested: a 4th OwnerField bit, CHARGES 8: `flares u8, chaff u8` (charges left), on change and with the ENTER, for units with `countermeasures`. Low priority. Sent to sim-A directly.
38. **Done and used (S-63, Sim/Stats; C-80): the results screen shows them.** **Match statistics per player (2026-10-22, the user asked):** for the results screen: units built, lost and killed, supply / power gathered and spent, damage dealt per player, counted by the sim (e.g. `Sim/Stats`), read by the Roblox server at match end; no wire change. Medium priority. Sent to sim-A directly.

36. **Done and used (S-61, protocol 20; C-75): the unit panel shows the server's factory queue, the command card the server's fire and move states, aircraft their real ammo; `Core/FactoryQueue` and the last-sent states are gone.** **Factory queues, fire / move states and ammo on the wire (C-68, 2026-10-22):** the playable UI's unit panel and command card need them; today the client shows what it queued itself (`Core/FactoryQueue`) and the last state it sent, and no ammo. Suggested: own factories' queue (def indices, at most ~20, and the progress of the first) in State records when it changes; own units' fire state and move state (2 bits each, in the state field or a new one); aircraft ammo (rounds left / max) for own units. Owner only, like STOCK. Medium priority.

35. **Done (S-58, protocol 19): the strategic icon is the def index; `def.icon` stays the family.** **A unique strategic icon per unit type (the user, 2026-10-22, overnight list):** "Every type of unit need to have its own unique icon." The wire's icon number comes from Shared/Net/Icons, which numbers icon *names*; 126 unit defs share 50 names (worker x10, radar x6 ...). Asked: an icon number unique per unit def (e.g. defs in sorted order, fits a u8), keeping `def.icon` as the shape family; ghosts and contacts keep their rules. The client then draws a unique glyph per def. Sent to sim-A directly.

34. **Done (S-59): Witness / Augur Pinpointers (T2, built by the Architect / Forgemaster); precision min(n, 6) / 6 cuts wobble and tracking error to 10% and radar-only lock loss to 0; the client shows it since C-72. Mobile radars already existed (Oracle, Watcher; Arbiter, Stalker for fire control).** **Radar vehicles and a pinpointer (the user, 2026-10-22, overnight list):** "Add radar vehicles, radar enhance facility (pinpointer) that increase the team's accuracy, build around 6 and maximum accuracy achieved -> less to no wobble radar blip, radar missile will be able to hit more precisely (long range radar will likely to lose lock or miss without pinpointer enhancements)." Asked: check the mobile radars (Oracle, Watcher) and add any missing; a Pinpointer structure per faction whose count (full at ~6) cuts radar contacts' wobble and radar-guided weapons' tracking error; radar missiles lose lock / miss more without them; the team's precision on the wire for the UI. Sent to sim-A directly.

33. **Done (S-56): IR SAM range / lockRange Thorn 206, Vigil 147; radar SAM Wyvern 945, Aegis 1013; sensors follow. sim-A's note for the user: a nuke is now inside a radar site's reach for only ~6 s of its 12.7 s flight, so at chance 0.2 two sites often let it through.** **SAM ranges again: IR -30%, radar -25% from S-55 (the user, 2026-10-21):** "Drop the IR range 30% more, the SAM 25% more." chs_ir_sam 294 -> 206, ord_ir_sam 210 -> 147; chs_radar_sam 1260 -> 945, ord_radar_sam 1350 -> 1013; sensors by the same factors. Sent to sim-A directly.

32. **Done (S-55): IR SAM range / lockRange -30% (Thorn 294, Vigil 210), radar SAM -25% (Wyvern 1260, Aegis 1350); airSight and the SAM sites' own radars follow.** **Shorter SAM ranges (the user, 2026-10-21):** "the anti air should not cover this large range... reduce the SAM IR by 30%, the SAM radar by 25%". Sent to sim-A directly.

31. **Done (S-53, S-54): `map:normandy`, re-oriented west against east at the user's word (coast and bluffs a shared north flank; rivers at x = +-660 with three bridges; staging |x| 420-640; bocage with hedgerows and two villages); the `normandy` profile is laid out on it.** **A Normandy map, `map:normandy` (the user, 2026-10-21):** "a large map, maybe make a map like Normandy". 256 x 256 cells around 0,0. Zones the `normandy` profile is laid out on: sea at z > 760 (scenery only); beach z 640-760 (sand, the Order rear); bluffs z 560-640 up to a plateau at ~34, with draws at x = -560, 0, 560; a bocage plateau z -360 to 560 with hedgerows and gaps, open staging fields at z 280-540 (Order) and z -340 to -200 (Chaos), and villages at (-300, 150) and (400, -100) with roads; a river at z ~ -380 with bridges at x = -500, 100, 650; open fields south of it (the Chaos rear). No deposits. Sent to sim-A directly.

30. **Done (S-52): Wyvern / Aegis radar SAMs hold 15 and rebuild one every 6 s; cost per missile, Gorgon / Seraph (3) and IR SAMs unchanged. Past 10 missiles the client draws the stock as one filling bar instead of pips.** **Radar SAM stock 15, faster refill (the user, 2026-10-21):** "tell A to increase the SAM stock to 15, lower its recharge time too." Read as the radar SAM sites that intercept nukes: Wyvern (`chs_radar_sam`) and Aegis (`ord_radar_sam`), stockpile capacity 6 → 15; no refill number was given, suggested buildTime 12 → 6 s per missile. Cost per missile, the mobile radar SAMs (Gorgon / Seraph, 3) and the IR SAMs are the sim's call. Nothing changes on the client (it reads the defs). Sent to sim-A directly.

29. **Done (S-50): `intercepts = { chance = 0.2 }` on both radar SAMs; the `nuke` profile's override dropped.** **Radar SAM interception chance 0.5 → 0.2 (the user, 2026-10-21):** "Make 0.2 the real interception chance." `chs_radar_sam` and `ord_radar_sam`: `intercepts = { chance = 0.2 }` (guide 10.9 and the S-48 numbers with it). The user tried it in the `nuke` profile through C-60's test override; once the defs say 0.2 the client drops that override. Nothing else changes on the client (it never reads the chance). High priority (the user asked).

28. **Done (S-51, protocol 18): SPAWN_STRATEGIC with the goal; Shared/Combat/Lofted (boost to climbHeight 120, pitch-over at 90°/s, arc to apex 300 above the goal, 12.7 s); the client flies, previews and predicts with it since C-62.** **Nukes launch vertically, then turn onto their arc (the user, 2026-10-21):** "Can we make the nuke go vertical to a height then turn toward its destination?" Today a nuke leaves the silo already on its parabola (Weapons.fire's lofted branch: up at sqrt(2 g apex), across at dist / t). Suggested (numbers yours):
    - A boost phase like the radar SAMs' (S-42 / S-44): straight up from the silo to `climbHeight` (e.g. 120 studs above the launcher), then a pitch-over at `turnRate` (e.g. 90°/s, about a second) toward the lofted velocity that, from where the missile is, peaks at `apex` (300 above the launcher) and lands on the aimed spot; then unpowered ballistic flight as now. Re-solving that velocity at the end of the turn keeps the landing exact. The flight can stay near 12.7 s so interceptors keep their window.
    - As a shared function (e.g. in `Shared/Combat/Ballistics` or `Guidance`), so the client steps it the same way: its drawn flight and interceptor steering, the attack-mode arc preview (C-58) and the landing prediction under the warning (C-57) all mirror the server. The client needs the phase: derivable from the state if the rule only uses the position, height above the launch point and velocity (the client has the SPAWN_PROJ point), or on the wire.
    - The guide (10.9) and contract need it. Medium priority; the user asked.

27. **Done (S-49, protocol 17): apex 300 / gravity 15 (same 12.7 s); STOCK carries the next missile's progress; the client fills the next pip since C-59.** **Lower nuke apex; stockpile build progress on the wire (the user, 2026-10-21):**
    - (a) "limit its height so that the missile does not shoot over the screen height." At the camera's 55° pitch and 70° field of view a point above the view's focus stays on screen up to ~0.6 × the camera distance: ~290 studs at 480 (the last zoom before the icon view). `ord_nuke` / `chs_nuke` climb to `apex` 800 above the launch. Suggested: `apex` 300 with `gravity` 15, which keeps the flight time at 12.7 s (it only depends on apex / gravity: 2 × sqrt(2 × apex / gravity)), so interceptors keep the same window; the vertical launch speed drops from 253 to 95 studs/s. Numbers are yours; guide 10.9 needs them. The client reads both from the def (flight, arc preview, landing prediction), nothing to change on this side.
    - (b) The user fired 3 nukes in the `nuke` profile and thought the silo had stopped building more. Headless it hasn't (6 launches, each rebuilt in 120 s with the profile's economy), but at sim speed 0.25 one rebuild is 8 real minutes and STOCK only carries whole missiles, so the pips sit still the whole time. Suggested: the build progress of the next missile per stockpile slot with STOCK (e.g. a u8, 0–255 of `wStockProgress`, sent when it changes by a step, owner only, like STOCK; protocol 17), so the client can fill the next pip as it builds. Medium priority.

26. **Done (S-48, protocol 16): Reckoning / Ragnarok silos, `ord_nuke` / `chs_nuke` (strategic, manual fire, stockpile 2), radar SAMs intercept (chance 0.5), INTERCEPTOR / LAUNCH_WARNING / INTERCEPTED; the client draws them and fires silos with A since C-57.** **Nuke silo and radar SAM interception (the user, 2026-10-21; new design, not in the guide):** "apart from air, it needs to shoot down ICBMs or nukes from the enemy launched into its radar range." The user chose: a T3 nuke silo per faction that builds nukes into a stockpile, and the radar SAM sites themselves as the interceptors. Suggested (numbers are yours to balance):
    - **Silo:** one T3 structure per faction (names in the faction styles, e.g. Order "Judgement", Chaos "Ragnarok"; your call), built by the advanced builders. It builds one nuke at a time into a stockpile (capacity 1–2, ~120 s and very expensive, e.g. 1,500 supply + 40,000 power, drained like construction and slowed by stalls) and fires only on a manual ground-target order (never automatically), anywhere on the map.
    - **Nuke:** a slow ballistic missile on a high arc (apex several hundred studs; ~150–200 studs/s, so defenses get time), a huge blast (aoe ~150, `edgeEffectiveness` ~0.3) that damages everything in it, own units included (BAR). A new weapon type or a flag (e.g. `strategic = true`) so other systems can tell it apart.
    - **Interception:** radar SAM weapons (`chs_radar_sam`, `ord_radar_sam`) get e.g. `intercepts = true`: an enemy strategic missile inside the site's radar range (and detected by the team: strategic missiles could count as radar-visible) is a target, preferred over aircraft. The site fires interceptors from its stockpile (request 25) at it; each has a hit chance (sim Prng, e.g. 0.5) or a proximity fuse against the missile's path, so one site can be overwhelmed by several nukes or an empty stockpile. A destroyed nuke doesn't detonate (a small burst only).
    - **Wire:** an interceptor's target is a projectile, not a unit (SPAWN_PROJ needs a target projectile ID or a flag); a nuke launch is worth an event every player gets (a warning; BAR announces it). The client draws whatever the contract says: on my side the nuke's plume, flash, shockwave and cloud, a launch warning, interceptors flying at the missile, and the silo's fire order and stockpile in the UI.
    - The guide needs it: weapon schema (4.3), economy drain (8), targeting projectiles (10), guidance (11.5), roster (13.5, a T3 row), and contract section 7.

25. **Done (S-47, protocol 15): weapon field `stockpile`, own units' STOCK in State records; the client shows it since C-56. Naval SAMs have no stockpile yet (a question for the user).** **Missile stockpiles for SAM sites (the user, 2026-10-21; new design, not in the guide):** "SAM systems should have a stockpile and spend resources to fill it up." Today SAMs fire forever at their reload rate; only aircraft have ammo. The user chose: all SAM sites and mobile SAMs, refilled automatically, BAR style. Suggested:
    - A weapon field, e.g. `stockpile = { capacity, buildTime, cost = { supply, power } }`: Thorn and Vigil 8, Wyvern and Aegis 6, Hornet 4, Gorgon and Seraph 3. Build times e.g. IR 6 s and radar 12 s per missile; costs e.g. IR 15 supply + 300 power, radar 40 + 900. The reload between shots stays as it is.
    - A site builds one missile at a time while below capacity, draining supply and power like construction (slower when the team stalls). A shot needs a missile in stock. Built sites start empty and fill up; scenario spawns could start full.
    - Wire: the owner's units carry their stock (e.g. a `stock u8` in State records, own units only, like `targets`) so the client can show it; protocol bump.
    - Client (mine, once it's on the wire): the stock count on the unit panel and bars.
    - Guide: weapon schema (4.3) and economy drain (8).

24. **Done (S-46): `ord_archon` radarSignature 0.6. In `airsam` a Wyvern can lock an Archon from 992 studs (tick 40); its first radar shot at one still comes at tick 62, the Wyverns' first reload (4 s) after their opening shots at a Falcon and a Guardian.** **Archon radar signature 0.35 → 0.6 (the user, 2026-10-21):** with the radar SAMs at 3× range (S-45), Wyverns in `airsam` fire at Falcons and Guardians from ~1,600 studs but at Archons only from 552 (detection 1800 × 0.35 = 630, lock 1680 × 0.35 ≈ 590), about where the Thorns already reach, so radar and IR SAMs open up on them together. At 0.6 a Wyvern locks an Archon at ~1,000. `ord_phantom` (0.2) unchanged. The user will test it. Sent to sim-A directly.

23. **Done (S-45): radar SAM range / lockRange 1680 (Chaos) and 1800 (Order), their radars ×3; the client reads it from the defs.** **Radar SAM range ×3 (the user, 2026-10-21):** "increase the long range RADAR to x3 its current range". Weapons: `chs_radar_sam` range / lockRange 560 → 1680, `ord_radar_sam` 600 → 1800; their own radars ×3 so they can lock that far: `chs_wyvern` 600 → 1800, `chs_gorgon` 480 → 1440, `ord_aegis` 650 → 1950, `ord_seraph` 520 → 1560. projectileSpeed and balance are the sim's call (a full-range shot at 360 studs/s flies ~4.7 s). The client reads it all from the defs. Sent to sim-A directly.

22. **Done (S-44): weapon field `climbHeight` (100 on both radar SAMs); the client mirrors the climb since C-55.** **Vertical launches climb longer before pitching over (the user, 2026-10-21):** "I need the missile to launch vertically a little more time, it turns over too soon." `Guidance.vertical` turns toward the target from the first tick at 3× turnRate, so a Wyvern missile is near level after ~1/3 s. Suggested: a weapon field `climbHeight` (studs above the ground; ~100 on `chs_radar_sam` and `ord_radar_sam`, tunable like `reload`) below which the missile flies straight up, then the pitch-over as now. Derivable from the missile's position (with a ground height both sides compute the same) rather than its age, since a client can receive a missile mid-flight; or put the remaining boost ticks on SPAWN_PROJ and corrections. Sent to sim-A directly (both sessions in bypass).

21. **Done (S-43, protocol 14): projectiles go to every player whose camera area has them; a hidden shooter's gun shot arrives as SHOT (both ends, no shooter); cloak rule in guide 11.4. The client draws SHOT since C-54.** **Projectiles visible regardless of sight, without revealing the shooter (the user, 2026-10-21; high priority):** "Only render the projectile, not revealing the shooters; if the shooter is cloaked and they decide to shoot, they switch out of cloak mode and reveal themselves." Today SPAWN_PROJ, homing corrections and IMPACT reach a player only in its ally team's sight (D99, contract section 7), so missiles from a site you can't see appear mid-flight and vertical launches (S-42) are never seen leaving. Please:
    - **Projectiles:** send SPAWN_PROJ (at launch), homing corrections and IMPACT for every projectile in the player's camera area (+ the usual margin), whatever the ally team sees. These records carry no shooter, so the shooter stays hidden; it is revealed only by the normal sight rules. Keep the camera-area limit (bandwidth), and keep `targetId` as now (0 when the team doesn't know the target).
    - **Gun shots (FIRE):** a hitscan / beam shot from a shooter the player doesn't have carries `shooterId`, which would reveal it. For those, send the start point instead (e.g. `shooterId` 0 and a start `pos`, or a FIRE variant with both ends); the client draws the tracer from it. Shots of known shooters stay as they are.
    - **Cloak (for when it is built; the guide lists a `cloaked` state bit only):** a cloaked unit that fires drops its cloak and is revealed by normal sight, so firing never stays hidden; record that in the guide's cloak section.
    - This changes the guide's fog rule (section 2, rule 6, and D99): projectiles in the camera area are exempt; please update the guide and contract section 7 with it.
    The client needs nothing for projectiles (it draws them from SPAWN_PROJ alone); it will draw tracers from the FIRE start point once the format is set.

20. **Done (S-42): radar SAM weapons have `launch = "vertical"` and `aoe` 20; the client steers them with `Guidance.vertical` since C-53.** **Radar SAMs vertical-launch, and carry heavy warheads (the user, 2026-10-21; high priority):** "SAM system with RADAR should be the long range that cover large area, it does not need to turn its turret because they launch vertically like the IRIS-T SLM launching. Missile for RADAR SAM must be way bigger than IR (they carry a lot of TNT in real life)." This makes request 12 concrete:
    - **Vertical launch** for the radar SAM weapons (`chs_radar_sam`: Wyvern, Gorgon; `ord_radar_sam`: Aegis, Seraph): e.g. a weapon field `launch = "vertical"`. Weapons fires as soon as a target is in range and locked, with no turret aim (no yaw / pitch wait, no tolerance check; the turret can stay at rest); the missile spawns at the launcher pointing straight up at its speed (or a short boost), and Projectiles steers it over toward the target at its `turnRate` (PN once it points roughly at the target, or from the start), so it climbs, pitches over and dives in. IR sites (Thorn, Vigil) keep their trainable launchers. The client needs nothing: it draws missiles from SPAWN_PROJ and steers them with `Shared/Combat/Guidance` (C-44).
    - **Heavy warhead:** `chs_radar_sam` has `aoe` 8, now smaller than the IR Thorn's 12 (request 16), so its blast and explosions are the smaller ones. Suggest radar SAM `aoe` ~20 (both factions; `edgeEffectiveness` as is), keeping damage 400. The client already draws radar SAM missiles 2.3× the IR ones and scales `..._large` impact effects 1.8× (C-52); the explosion grows with `aoe` on its own.

19. **Done (S-38): aircraft shot down in flight leave no wreck (DEATH `wreckId` 0).** **No wrecks for aircraft (C-48, the user, 2026-10-21):** "HELI/AIR death should be: they fall off the sky, crash onto the ground and their wreck explode, so air won't leave wreck." `Damage` makes a wreck for any unit dying at severity ≤ `WRECK_MAX_SEVERITY`, aircraft included, at the spot under the aircraft. The client now plays the fall and the crash explosion itself and draws no wreck for aircraft (C-48), but the server's wreck still exists (reclaimable, and WRECK records will put it on the client's map once the client reads them). Please skip `Combat.addWreck` for units of the air domain that die airborne (a landed aircraft may keep one). Medium priority.

18. **Done (S-38, protocol 13): DECOYED ends with `countermeasure`; the client draws the one it names since C-51.** **Which countermeasure seduced a missile (C-48, 2026-10-21):** DECOYED doesn't say whether flares, DIRCM or chaff won, so the client guesses from the target's equipment and EW's order (radar → chaff; IR → DIRCM if it has no flares, else flares). An aircraft with both DIRCM and flares (none today, but the defs allow it) would be drawn wrong half the time. A `cm u8` in DECOYED (1 flares, 2 chaff, 3 DIRCM), e.g. in the top bits of `decoyTicks` (15 fits in 4 bits), would make it exact; a protocol bump. Low priority.

17. **Done (S-38): jets fly to the goal and arrive within `Air.ARRIVE_RADIUS` (40) or at the closest approach; the client's move line follows since C-51.** **A jet ordered to a point inside its loiter radius never goes there (the user, 2026-10-21):** "when you click move on air plane, if the move is inside the white range, it will disappear shortly after and the plane move following its current facing direction, not the pre-defined position." In `Air.steerJet` an order whose goal is within `Air.LOITER_RADIUS` (220 studs) of the jet counts as arrived at once (`Nav.clearOrder`), and the jet starts circling the goal at 220 studs, from wherever it is: it never flies to the point, and a close order looks like nothing happened. Suggest: a new move flies to the goal until it passes within a small arrival radius (e.g. 40 studs, or the closest approach once past it), then loiters around it; the loiter stays at 220 (wider than the turn circle). The client's move line uses the arrival radius (C-45 mirrors `LOITER_RADIUS` today), so please name it (e.g. `Air.ARRIVE_RADIUS`) and the client will follow. High priority (the user asked).

16. **Done (S-33): `chs_ir_sam` range / lockRange 420, aoe 12, projectileSpeed 500; Thorn airSight 420.** **Thorn SAM: longer range, bigger blast (the user, 2026-10-21):** "increase SAM range and the IR missile explosion" (blast radius, with a matching effect on the client). `chs_ir_sam` today: `range` / `lockRange` 280, `aoe` 5 (also its proximity fuse), `terminalRange` 30. Suggest `range` and `lockRange` 420 (1.5×) and `aoe` 12 (keep `edgeEffectiveness` 0.5, or add a separate `fuseRange` if 12 should not change the fuse), maybe `projectileSpeed` up so a 420-stud shot isn't slower to arrive than today's (420 → ~500 studs/s); `chs_thorn`'s turret and targeting follow `range`. The client reads all of these from the def (rings, seeker cone length, explosion size), so nothing changes on this side. The `sam` test scene is now 2048 studs long (`flat:256`), the Thorns at x 640–800, the Falcon circling at x = 600. Unit and weapon defs are yours; high priority (the user asked).

15. **Partly done (S-33): projectiles burst on the map's edge (C-46's workaround removed in C-51); aircraft still turn back at 60 studs and may be drawn on the edge for a moment, which the client accepts for now.** **Positions past the map's edge (C-46, 2026-10-21):** wire positions are clamped to the map (`Grid.encode`), so anything past the edge reaches the client on it. Jets turn back at `Air.EDGE_MARGIN` (60 studs) but their turn carries them up to ~14 studs out (a Falcon at moveTo 420 on `flat:160`: 10 ticks out, worst 14 studs), and missiles that miss fly hundreds of studs out and self-destruct there. The client now keeps its own prediction for a projectile record on the clamp (C-46), but a unit past the edge is drawn on it and a missile chasing it steers at the clamped point. Either keep aircraft inside (turn back earlier, by about the turn radius at speed, speed / turnRate in rad/s: 260 / 1.31 ≈ 200 studs for a Falcon), or let positions past the edge on the wire (a signed offset, protocol bump). Low to medium priority.

14. **Done (S-33): the server sets MOVING; the client also keeps its position-based fallback (C-45).** **The MOVING state bit is never set (C-45, 2026-10-21):** `Schema.UnitState.MOVING` (1) is in the schema and the contract, but nothing in `src/server` writes it, so every unit looks idle on the client. Its move lines vanished 2 s after an order (the user saw it on an airplane), piece scripts never got StartMoving, and Interp never extrapolated. The client now works it out from position records (C-45), which is late by up to 2 ticks and can't tell a stop from a lost record. Please set MOVING while a unit has a movement goal or nonzero speed (aircraft: while flying, loitering included; landed: off) and clear it when it stops; it rides on the State record's dirty bit. Medium priority.

13. **Done (S-27, S-28; reported in docs/progress/sim.md); the client steers with `Shared/Combat/Guidance` since the 7a7e2bd merge (C-44).** **IR SAMs miss most crossing shots (C-39, 2026-10-21):** in the `sam` scene (4 Thorns, `chs_ir_sam`, against 4 circling Falcons) only 57 of 183 missiles hit over 2 minutes (31 %; 5 decoyed, the rest missed); hits come almost only head-on or tail-on. The missile sensor view (N, C-39) shows why: crossing shots pass 5–9 studs from the hull against a 5-stud fuse. Two causes: (a) guidance is lead pursuit with a straight-line target prediction (Projectiles: aim at where the target would be after the straight-line time to go, at `turnRate` 160°/s); against a turning jet the lead is wrong and the missile ends in a tail chase or overshoots; (b) the proximity fuse is `aoe` (5 studs from the hull), which is small next to a missile's 28-stud step per tick. Suggestions: proportional navigation (commanded turn = N × closing speed × line-of-sight rate, N ≈ 3–4, capped by `turnRate`), which handles turning targets without predicting them; and a separate fuse radius for SAMs (e.g. `fuseRange = 10`) instead of reusing `aoe`, keeping the damage falloff on `aoe`. (c) No seeker field of view: a missile that misses keeps its lock, overshoots and turns back for another pass (160°/s, a full loop in ~2.3 s) until its fuel runs out; the user saw one "lose lock, fly off and come round again" at the Falcon. Suggest a seeker cone per guided weapon (e.g. `seekerAngle = 60`° off the nose for IR, wider for radar): in the midcourse check, a target outside it breaks the lock (LOST_LOCK, the missile flies on and self-destructs at its lifetime), and nothing re-acquires. (d) **Decoyed missiles "fling to a side, then continue"** (the user, 2026-10-21): on a successful flare / chaff roll the terminal check in `EW.guide` turns the velocity by `EW.DECOY_TURN` (±60°) in one tick and clears the target, so Projectiles never steers it again; a missile at 420 studs/s visibly kinks sideways (the client eases the kink over its 5-tick blend, C-36, and is otherwise in sync, so this is the server's path, not drawing). Suggest a gradual turn toward a decoy point instead: on DECOYED keep steering for a short time (e.g. `DECOY_SECONDS = 1`) at the weapon's `turnRate` toward a fixed point where the flare or chaff was dropped, behind and below the target (e.g. the target's position minus ~1 s of its velocity, 10–20 studs lower for flares; chaff could drift with the wind side, using the same ±side roll), then fly straight to the end of its lifetime as today. Seen from above, the missile then bends off the jet's tail toward the falling flare and goes on, like a real seeker seduced by a flare. The DECOYED event could carry that point (or the client derives it from the target's state at the event tick) so the client steers it like the server instead of easing a correction; until then corrections cover it. Your call on the weapon model (guide 10.4, 11.5) and on request 11c's G limit with it. The client mirrors the guidance in `Core/Effects` (`aimFrom`, `predict`) and would follow a change (better, request 11b: a shared aim function). Medium priority; the user asked.

12. **Superseded by request 20 (radar SAMs).** **Vertical-launch SAM, IRIS-T SLM style (the user, 2026-10-21):** "the enemy will have 4 SAM systems that launch missiles vertical ... to test missile flight path". Missiles leave the launcher straight up, then pitch over toward the target (at their turnRate, or after a short boost), so the launcher needs no turret aim. E.g. a weapon field `launch = "vertical"` (Weapons spawns at pitch 90°, ready to fire as soon as the target is in range and locked; Projectiles steers from there), and a Chaos (or Order) VLS SAM site using it; the client draws it with no change (it steers like the server, C-36, once request 11b shares the aim code; until then corrections cover it). The `sam` test profile would switch its Thorns to that unit. Medium priority.

11. **(b) done (S-27: `Guidance.pn` / `lead`, used by the client since C-44); (c) answered (turnRate is the G limit at constant speed); (a) open.** **Homing missiles on the wire (C-36, 2026-10-21):** (a) homing corrections more often than every 5 ticks (`NetOut.HOMING_SYNC_EVERY`), e.g. every 2, or every tick for missiles whose target the player only has as a radar contact: the client can't steer those like the server and drifts ~7 studs (up to 35) between corrections; a correction is ~14 bytes, a few dozen missiles at most. (b) The server's homing aim (`Combat.aimPoint` with `UNIT_HEIGHT`, `DRAFT`, `SUB_DEPTH`, and the lead in Projectiles) as a shared function, so the client calls it instead of mirroring it. (c) The user asked whether missiles should have a G limit: today a missile turns at most `turnRate` degrees per second; a G limit (turn rate = G × gravity / speed) would make fast missiles turn wider. Your call (weapon model, guide 10.4). Medium priority.

10. **Done (S-26, protocol 10; reported in docs/progress/sim.md); the client doesn't read WRECK / WRECK_GONE yet.** **Wrecks on the wire (task 5, 2026-10-21):** a wreck reaches the client only as `wreckId` in a DEATH of its tactical tier. It never hears of wrecks made outside that tier or before it joined, and never of a wreck being reclaimed (so drawn wrecks stay until the match restarts, C-34). Wreck records would fix both: e.g. WRECK `wreckId u16, cell, offX, offZ, heading u8, defIndex u16` when a wreck enters the camera area (and on join), WRECK_GONE `wreckId` when it is reclaimed or leaves; a reclaim's progress could show as a shrinking wreck later. Low to medium priority.

9. **Done (S-26, protocol 10; reported in docs/progress/sim.md); the client doesn't read SIGHT_ROWS / SIGHT_CELLS yet.** **The team's sight map on the wire (task 4, 2026-10-21):** the client rebuilds its team's sight from its own units (C-32: exact while it knows their defs), but own units never seen in the camera arrive as strategic records with only an icon (their sight range is a guess), and allied players' units can't be counted (the wire doesn't say who is allied). Sending the ally team's `los` map would make the fog exact and cover allies: e.g. on the Strategic channel at sensor rate, the sensor cells that turned seen / unseen since the last send (u16 cell indices; a few dozen per update while armies move; a full bitset on join: 64 × 64 cells = 512 bytes on a 128-cell map). Alternatively own units' strategic records could carry their def index. Medium priority.

8. **Done (S-20; reported in docs/progress/sim.md); the client follows it since C-33.** **Juggernaut arm timing on the server (the user, task 2, 2026-10-21):** "raises its arms to aim, fires, and lowers them after a delay, matching the server's aim timing". Today the heavy cannon rests at pitch 0 and reaches its firing pitch almost at once, so no arm raise exists in gameplay. Please give the Juggernaut's weapon (its own weapon def, or the heavy cannon if `chs_maw` may share it) a rest pose and a hold: `turret.restPitch = -65` (arms down; `minPitch` down to -65 so it can rest there), a `pitchRate` that makes the raise cost real time (e.g. 80°/s: ~0.85 s from rest to level), and `turret.restoreDelay = 3`: after losing its target the weapon keeps its aim for that long before turning back to rest. Weapons then rest at `restPitch` instead of 0. Also add `armL`, `armR` to `chs_juggernaut.pieces` (guide 14.2: piece names come from the def; the client lists them as visual pieces until then). The client script already reads `restPitch` / `restoreDelay` and switches to the server's rates when they exist (C-30). Medium priority.

7. **Done (S-19; reported in docs/progress/sim.md):** 56, 45 and 34; nothing to change on the client. **Shorter build ranges (the user, 2026-10-22):** "the build range of the unit is so far, reduce to around 70%". Today `buildRange` is 80 (`ord_sovereign`, `chs_warlord`), 64 (the constructors: `ord_mason`, `ord_architect`, `ord_harbormaster`, `ord_tidewright`, `chs_scrapper`, `chs_forgemaster`, `chs_reaver`, `chs_wrecker`) and 48 (aircraft builders: `ord_skywright`, `ord_zenith`, `chs_condor`, `chs_vulture`). About 70 %: 56, 45 and 34. Unit defs are yours; the client reads `buildRange` from the defs, so nothing changes on this side. High priority (the user asked).
6. **Done (S-16, protocol 8; marked by the sim session); the client uses it since C-25.** State records carry `targets` (mask bit 32) for the owner's units; contract section 6. **Own units' weapon target on the wire:** the target line (C-20) guesses the target from the turret aim (99.6 % right in the duel). A `target u16` per weapon slot in State records for the player's own units (the target is always a unit the team knows) would make it exact, including before the turret has turned. A protocol bump; medium priority (the user asked for the line).

1. **Done (S-3, S-11; marked by the sim session).** Bombs have no turret, so the bombers no longer name `turretPiece`; the muzzle is their only weapon piece, and `Defs` rejects turret pieces on turretless weapons. **Bomber weapon pieces:** `chs_behemoth`, `chs_plague` and `ord_absolution` name `turretPiece = "bay"`, which isn't in their `pieces`. Either add `bay` to `pieces` or drop `turretPiece`; and maybe have `Defs.validate` check that weapon pieces exist. The client works around it (muzzle on the hull).
2. **Done (S-6), thanks.** **Unit state bits in shared:** `World.State` (MOVING, TOGGLED_ON, SUBMERGED, LANDED) is in `src/server`, which clients can't require. Please mirror it in Schema (e.g. `Schema.UnitState`) so the client decodes ENTER/State `state` without a copy. (net.md lists the values; the client copies them in `Core/World`.)
5. **Done (S-10), client switched 2026-10-22.** **Icon numbering in shared:** `NetOut.iconIndex` is copied in `Core/Icons` (tested equal). A shared function would keep one copy. Low priority.
4. **Done (S-9), client switched 2026-10-22.** **Placement rules in shared:** the client copies `Placement.snap` and the constants `LAND_MAX_SLOPE`, `WATER_MIN_DEPTH`, `RADIUS_PER_FOOTPRINT` (C-14). A shared pure `snap` + terrain check would keep them in one place. Low priority.
3. **Done (S-12; marked by the sim session).** `Shared/Grid/Formation` (`layout`, `deepestFirst`, `assign`, `SLOT_SPACING`); `Formation.spec` checks a client prediction equals the server's goals. **Formation slots in shared:** the client mirrors `Nav.slotsFor` / `Nav.assignSlots` and the constants `SLOT_SPACING`, `RADIUS_PER_FOOTPRINT` to draw where line-moved units go (C-11). A pure function in `src/shared` (layout + greedy assignment, without the open-ground filter) would let both sides use one copy. Low priority.
- Ready to merge: `5021d5f` (cheat commands live on S-102: results in the log, /speed drives the tick loop, "cheats used" on statistics and replay names; touches src/roblox Main.server; C-120); test_client 203, test 430, build passed.
- Ready to merge: `4305d94` (extractor upgrades in place on S-108's rule with the D92 fallback: target discs, snap, extractor drags as areas, Upgrade extractors command, UPGRADE badge; ghost PivotTo and build waypoints fixes; touches src/roblox Main.server (Studio debug query "deposits"); C-121); test_client 207, test 430, build passed.
- Ready to merge: `c74da88` (minimap unit icons, C-122); test_client 207, test 430, build passed.
- Ready to merge: `22f0286` (deposits: dark patch / C's fx.deposit variants, hidden under structures, placement and F4 overlay, minimap rings; C-123); test_client 209, test 430, build passed.
- Ready to merge: `7928550` (Settings top right, Follow button removed with T in developer mode, F3 bottom right; unit panel model portrait, type icon and +/- supply and power flow; C-124, C-125); test_client 213, test 430, build passed.
- Ready to merge: `e943f2f` (merge of m-models eb8a768 with the materials regenerated; deposit cells bare ground, terrain-colored patch tint; C-123 follow-up); test_client 213, test 430, build passed.
- Ready to merge: `646d404` (cheat line arrow keys cycle suggestions, C-126); test_client 213, build passed (client UI only).
- Ready to merge: `0d6ca37` (Inferno beam green, C-127); test_client 213, build passed (client render only).
- Ready to merge: `a6bff45` (Inferno beam back to orange, C-127; supersedes 0d6ca37's colour); render constant only.
- Ready to merge: `3f2d1ea` (Radiance ray bluer, 3 s, narrowing fade; beamSeconds reads S-113's beamDuration; C-128); test_client 214, build passed (client render only).
- Ready to merge: `5890cad` (beam deflection off shield domes, drawn; active once sim request 50 lands; C-129); test_client 215, build passed (client render only).
- Ready to merge: `6bb8932` (big-map fog: at most 4 chunks, C-130); test_client 215, build passed (client render only).
- Ready to merge: `0971cf3` (shield hits: no ripple, outlined honeycomb cells, C-131); test_client 214, build passed (client render only).
- Ready to merge: `391ff62` (shield hits cave in: inward wave, bigger centre cells, bowl dent with bounce; C-132); test_client 214, build passed (client render only; not checked in Studio, the user was playtesting).
- Ready to merge: `ccd9985` (m-models merge cf2e795 + materials 0285a54; C's beam shot wired, review-gated; C-133); test_client 214, build passed.
- Ready to merge: `1c9b92f` (shield cells inward only, C-134); test_client 214, build passed (client render only).
- Ready to merge: `33087cd` (m-models merge 2cbfb90; beam shot follows C's values and game speed; C-135); test_client 214, build passed.
- Ready to merge: `23df21b` (larger shield hit patches, C-136); test_client 214, build passed (client render only).
- Ready to merge: `1000f8b` (main 522ca80 merged in 9ce4c94, m-models 252d63a; 8 client specs fixed, stopgap icons, supplyUnder ghost; C-137); test_client 214, test 445, build passed.
- Ready to merge: `13f7561` (m-models merges ce25ddd + 786d85c; honeycomb shell, beam held for beamDuration; C-138); test_client 214, build passed.
- Ready to merge: `25b6d3f` (beam pulses on shields, bigger hit patches; C-139); test_client 214, build passed (client render only).
- Ready to merge: `6d0e0df` (shield_beams test profile, C-140; MatchConfig profile hunk only, ACTIVE untouched); build passed.
- Ready to merge: `b8cc921` (more, smaller rings in shield hits, C-141); test_client 214, build passed (client render only).
- Ready to merge: `4b58c31` (more outer rings, review effects on in Studio; C-142); test_client 214, build passed (client render only).
- Ready to merge: `511ab10` (with 58d5579 and the main merge 46d094c: fast mesh builds, camera lead, SHOT beams; C-143); test_client 214, test 446, build passed.
- Ready to merge: `5db24f6` (beam continuation for request 54, thinner flowing rings; C-144); test_client 215, build passed (client only).
- Ready to merge: `318555d` (main 062ba5f merged into the client: S-119); test_client 215, test 449, build passed.
- Ready to merge: `aaa1538` (m-models merge 021c8c7: sparser honeycomb shell texture, mech Commander blockouts; materials regenerated); test_client 215, build passed.
- Ready to merge: `861edf9` (main 4356074 merged into the client: S-120, S-121); test_client 215, test 450, build passed.
- Ready to merge: `8145721` (mech Commander walk cycle, C-146; with the m-models merge of 2b4dc5b and C-145's dome prep 58f2e4c / c7b1493); test_client 215, build passed.
- Ready to merge: `3986c2a` (glance follows a moved beam end, C-147); test_client 215, build passed (client only).
- Ready to merge: `ed3303e` (main f3334c7 merged in 9e18206, m-models 2e5a42b; mech stride, domes without vision verified; C-148); test_client 215, test 451, build passed.
- Ready to merge: `7c8566b` (main 3860e72 merged into the client: S-123); test_client 215, build passed.
- Ready to merge: `26e92d3` (m-models 44101bf: heroic mech Commander meshes, at review); test_client 215, build passed.
- Ready to merge: `a6942aa` (main b7f0f09 merged in 8f553c1 with S-124..S-126; ghost-attack spec, C-149); test_client 216, build passed.
- Ready to merge: `29a4d48` (ally relation and smart orders, C-150; inert until S-129); test_client 217, build passed (client only).
- Ready to merge: `8d672dd` (smooth radar blips, C-151); test_client 218, build passed (client only).
- Ready to merge: `3a06cb7` (main e13d850 merged in e5672df: S-127..S-129; ally end-to-end spec); test_client 219, test 457, build passed.
- Ready to merge: `ace2e89` (m-models e7f4570: Commander mechs v3 at review; team pieces cover every part; materials up to date); test_client 219, build passed.
- Ready to merge: `1f948db` (main 57299f7 merged into the client: S-130); test_client 219, build passed.
