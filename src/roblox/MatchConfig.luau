--!strict
-- What the Studio playtest runs (C-9). Until a lobby exists, the server
-- hosts one fixed match and Roblox players take the human slots in join
-- order. Pick a profile with ACTIVE, in this file: an edit made in Studio
-- isn't seen by Rojo and silently survives until this file changes.
--
-- `spawns` (optional) adds units after the scenario at every match start:
--   { def, player, x, z, heading?, count?, dx?, dz?, health? }
-- `count` units from (x, z), each `dx`, `dz` studs from the last (default
-- one unit); with `cols`, a formation: rows of `cols` units, each row
-- `rowDx`, `rowDz` studs from the last. Heading in radians (0 faces +z,
-- pi / 2 faces +x). `health`
-- multiplies the units' starting health (test runs only; bars show full
-- until they drop below their normal maximum). `moveTo = { x, z }` gives
-- them a move order there as the match starts (their player's order);
-- `fireAt = { x, z }` an attack-ground order there (how a nuke silo fires).
-- `weaponOverrides` (optional, tests only, C-60): { [weaponId] = { reload?,
-- stockpile = { buildTime?, cost? }, intercepts = { chance? } } }, numbers
-- no client simulates, changed for this server only.
-- `startResources = { supply, power }` (optional): what every team has
-- stored at match start (default 1,000 each; capped by its storage).
-- `speed` (optional, default 1): the sim speed the match starts at (C-35);
-- in a playtest - / = change it and P pauses.

local PROFILES = {
	-- 10 Lancers (you) vs 10 Ravagers (bot), in gun range from the start
	duel = {
		seed = 7,
		mapId = "flat:48",
		scenario = "duel_test",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		-- Placeholder bot: every 10 s it orders its units to the midpoint
		-- between the two sides.
		demoOrders = true,
		-- Start a new match (next seed) this long after one side is gone.
		restartAfter = 6, -- seconds
	},
	-- your Command Vehicle on a start map with deposits: for trying the build ghost (B)
	build = {
		seed = 2,
		mapId = "start:48",
		scenario = "standard_start",
		players = { { id = 1, team = 1 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
	},
	-- a procedural map with hills, ridges and a sea (S-15), for the terrain
	-- (C-28): your Command Vehicle and three Lancers against a Warlord and a Ravager
	terrain = {
		seed = 3,
		mapId = "map:coastline",
		scenario = "match_test",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = true,
		restartAfter = nil,
	},
	-- electronic warfare (guide 11.5–11.6): an Order radar SAM site, a spotter
	-- and a helicopter with DIRCM against a Chaos helicopter under a jammer and
	-- four IR SAM sites (air rendering, C-31)
	ew = {
		seed = 1,
		mapId = "flat:128",
		scenario = "ew_test",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
	},
	-- Juggernaut fight: your 4 Juggernauts (west, facing east) against 8
	-- Lancers 280 studs away; the bot drives them in, so the arms rise as the
	-- Lancers come into range (C-30, C-33)
	juggernaut = {
		seed = 21,
		mapId = "flat:64",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = true,
		restartAfter = 8,
		spawns = {
			{ def = "chs_juggernaut", player = 1, x = -140, z = -30, heading = math.pi / 2, count = 4, dz = 20 },
			{ def = "ord_lancer", player = 2, x = 140, z = -70, heading = -math.pi / 2, count = 8, dz = 20 },
		},
	},
	-- air fight: your 3 Archon fighters and 3 Guardian helicopters against 3
	-- Manticore fighters and 3 Wasp helicopters (C-31)
	air = {
		speed = 0.25, -- flight paths are easier to follow slowed down (the user's rule for these test scenes)
		seed = 22,
		mapId = "flat:128",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = true,
		restartAfter = 8,
		spawns = {
			{ def = "ord_archon", player = 1, x = -300, z = -80, heading = math.pi / 2, count = 3, dz = 80 },
			{ def = "ord_guardian", player = 1, x = -250, z = -40, heading = math.pi / 2, count = 3, dz = 40 },
			{ def = "chs_manticore", player = 2, x = 300, z = -80, heading = -math.pi / 2, count = 3, dz = 80 },
			{ def = "chs_wasp", player = 2, x = 250, z = -40, heading = -math.pi / 2, count = 3, dz = 40 },
		},
	},
	-- naval fight on the sea map (land in the west quarter): your Dominion
	-- cruiser, Crusader destroyer and Silence submarine against a Kraken
	-- cruiser, a Corsair destroyer and a Lamprey submarine (C-31)
	naval = {
		speed = 0.25, -- flight paths are easier to follow slowed down (the user's rule for these test scenes)
		seed = 23,
		mapId = "sea:64",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = true,
		restartAfter = 8,
		spawns = {
			{ def = "ord_dominion", player = 1, x = -60, z = -30, heading = math.pi / 2 },
			{ def = "ord_crusader", player = 1, x = -60, z = 40, heading = math.pi / 2 },
			{ def = "ord_silence", player = 1, x = -40, z = 70, heading = math.pi / 2 },
			{ def = "chs_kraken", player = 2, x = 170, z = -30, heading = -math.pi / 2 },
			{ def = "chs_corsair", player = 2, x = 170, z = 40, heading = -math.pi / 2 },
			{ def = "chs_lamprey", player = 2, x = 130, z = 70, heading = -math.pi / 2 },
		},
	},
	-- radar and fog on Coastline: your watchtower (radar 650) and 2 Lancers in
	-- the west, 4 Ravagers and a generator in the middle, on radar but out of
	-- sight; the bot stays put, so they stay radar contacts (C-32)
	radar = {
		seed = 24,
		mapId = "map:coastline",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
		spawns = {
			{ def = "ord_watchtower", player = 1, x = -420, z = -60 },
			{ def = "ord_lancer", player = 1, x = -380, z = -70, heading = math.pi / 2, count = 2, dz = 20 },
			{ def = "chs_ravager", player = 2, x = 100, z = -90, heading = -math.pi / 2, count = 4, dz = 20 },
			{ def = "chs_generator", player = 2, x = 140, z = 60 },
		},
	},
	-- SAM test: 4 Thorn IR SAM sites on the east side of a long map (2048
	-- studs, the largest); your Falcon (5x health) starts far west, out of
	-- their reach, and flies ~1,500 studs in to circle at x = 600, just short
	-- of them (its 220-stud circle stays inside the map); your 4 long-range
	-- radars cover the map.
	-- For watching missile flight paths and the sensor view (N, C-39) with
	-- its seeker cones (C-42). The Thorns launch
	-- along their turret's aim until the sim adds vertical launch (request 12).
	sam = {
		speed = 0.25, -- flight paths are easier to follow slowed down (the user's rule for these test scenes)
		seed = 25,
		mapId = "flat:256",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
		spawns = {
			{ def = "ord_beacon", player = 1, x = -600, z = -600, count = 2, dx = 1200 },
			{ def = "ord_beacon", player = 1, x = -600, z = 600, count = 2, dx = 1200 },
			{ def = "ord_falcon", player = 1, x = -950, z = 0, heading = math.pi / 2, health = 5, moveTo = { 600, 0 } },
			{ def = "chs_thorn", player = 2, x = 640, z = -120, count = 2, dx = 160 },
			{ def = "chs_thorn", player = 2, x = 640, z = 120, count = 2, dx = 160 },
		},
	},
	-- Air raid on a SAM belt (the user, 2026-10-21): your 2 Falcon jets, 2
	-- Archon fighters and 3 Guardian helicopters start far west
	-- on the largest map and fly east into 5 Chaos SAM systems: 3 Thorn IR
	-- sites in front (range 280) and 2 Wyvern radar SAM sites behind them
	-- (range 560), so flares, chaff and DIRCM all come up. The jets head
	-- for x = 600 through the belt, the helicopters stop short at x = 250;
	-- your 4 long-range radars cover the map, and a fusion reactor powers
	-- them and the aircraft's DIRCM jammers. Normal health: a unit above its
	-- normal maximum shows a full bar until it drops below it.
	airsam = {
		speed = 0.25, -- flight paths are easier to follow slowed down (the user's rule for these test scenes)
		seed = 31,
		mapId = "flat:256",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
		spawns = {
			{ def = "ord_beacon", player = 1, x = -600, z = -600, count = 2, dz = 1200 },
			{ def = "ord_beacon", player = 1, x = 200, z = -700, count = 2, dz = 1400 },
			{ def = "ord_fusion", player = 1, x = -950, z = 650 }, -- power for the radars and the aircraft's DIRCM (115/s)
			{ def = "ord_falcon", player = 1, x = -950, z = -120, heading = math.pi / 2, count = 2, dz = 80, moveTo = { 600, -60 } },
			{ def = "ord_archon", player = 1, x = -950, z = 120, heading = math.pi / 2, count = 2, dz = 80, moveTo = { 600, 160 } },
			{ def = "ord_guardian", player = 1, x = -900, z = -40, heading = math.pi / 2, count = 3, dz = 40, moveTo = { 250, 0 } },
			{ def = "chs_thorn", player = 2, x = 450, z = -220, count = 3, dz = 220 },
			{ def = "chs_wyvern", player = 2, x = 720, z = -150, count = 2, dz = 300 },
		},
	},
	-- Nukes and interception (S-48, C-57): the Chaos Ragnarok silo in the
	-- east launches at your base as the match starts; your 2 Aegis radar
	-- SAMs try to shoot it down (each interceptor has a 50% chance). Your
	-- own Reckoning silo in the west has 2 nukes: select it, press A and
	-- left-click the ground (or a unit) to launch one at the Chaos base,
	-- which 2 Wyvern radar SAMs defend. Lancers stand in both target areas
	-- to show the blast. Your economy funds the stockpiles: 5 fusion
	-- reactors (1,250 power/s) and 12 supply converters (12 supply/s from
	-- spare power; the flat map has no deposits) rebuild a nuke in its full
	-- 120 s, back to back, with power left for the Aegis' interceptors.
	-- For testing (the user, 2026-10-21) nukes cost 1 supply and 1 power,
	-- build in 10 s, and a silo can launch again 2 s after a launch (reload
	-- 10 s in the defs). Radar SAM interceptors kill with chance 0.2 (the
	-- defs' since S-50).
	nuke = {
		speed = 0.25, -- flight paths are easier to follow slowed down (the user's rule for these test scenes)
		seed = 41,
		mapId = "flat:256",
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
		spawns = {
			{ def = "ord_beacon", player = 1, x = -600, z = -600, count = 2, dx = 1200 },
			{ def = "ord_beacon", player = 1, x = -600, z = 600, count = 2, dx = 1200 },
			{ def = "ord_fusion", player = 1, x = -950, z = 650 },
			{ def = "ord_fusion", player = 1, x = -980, z = -640, count = 4, dz = 48 },
			{ def = "ord_converter", player = 1, x = -840, z = 380, count = 4, dz = 16 },
			{ def = "ord_converter", player = 1, x = -824, z = 380, count = 4, dz = 16 },
			{ def = "ord_converter", player = 1, x = -808, z = 380, count = 4, dz = 16 },
			{ def = "ord_reckoning", player = 1, x = -900, z = 0 },
			{ def = "ord_aegis", player = 1, x = -650, z = -150, count = 2, dz = 300 },
			{ def = "ord_lancer", player = 1, x = -500, z = -60, count = 4, dz = 40, heading = math.pi / 2 },
			{ def = "chs_ragnarok", player = 2, x = 900, z = 0, fireAt = { -520, 0 } },
			{ def = "chs_wyvern", player = 2, x = 650, z = -150, count = 2, dz = 300 },
			{ def = "chs_ravager", player = 2, x = 500, z = -60, count = 4, dz = 40, heading = -math.pi / 2 },
		},
		weaponOverrides = {
			ord_nuke = { reload = 2, stockpile = { buildTime = 10, cost = { supply = 1, power = 1 } } },
			chs_nuke = { reload = 2, stockpile = { buildTime = 10, cost = { supply = 1, power = 1 } } },
		},
	},
	-- Large-scale battle (the user, 2026-10-21): an Order and a Chaos army
	-- of every land and air type (no naval, submarines, amphibious tanks,
	-- anti-sub helicopters or command vehicles), in formation, with no
	-- orders. Order holds the north (beachhead), Chaos the south. Each side:
	-- 76 land units (tanks in front, mobile IR SAMs and scouts with them,
	-- artillery, mobile radar SAMs, radars and jammers behind), 29
	-- aircraft, 4 IR SAM sites near the battlefield, and in the safe rear 3
	-- radar SAM sites, 2 long-range radars, 16 fusion reactors (4,000
	-- power/s), 50 converters (50 supply/s from spare power), 10 depots
	-- (11,000 supply storage), a nuke silo (2 in stock) and 5 constructors;
	-- stores start full (`startResources`).
	-- Laid out for `map:normandy` (request 31: sea z > 760, beach and the
	-- Order rear z 640-760, bluffs with draws, bocage battlefield, a river
	-- at z -380, the Chaos rear south of it); on flat:256 until it lands.
	normandy = {
		seed = 44,
		mapId = "flat:256",
		startResources = { supply = 10000, power = 20000 },
		scenario = "empty",
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
		spawns = {
			-- Order (player 1): rear on the beach
			{ def = "ord_fusion", player = 1, x = -980, z = 700, count = 16, cols = 8, dx = 50, rowDz = 40 },
			{ def = "ord_converter", player = 1, x = 480, z = 664, count = 50, cols = 10, dx = 16, rowDz = 16 },
			{ def = "ord_depot", player = 1, x = -560, z = 740, count = 10, dx = 30 },
			{ def = "ord_reckoning", player = 1, x = 0, z = 715 },
			{ def = "ord_aegis", player = 1, x = -470, z = 690 },
			{ def = "ord_aegis", player = 1, x = 250, z = 700 },
			{ def = "ord_aegis", player = 1, x = 900, z = 700 },
			{ def = "ord_beacon", player = 1, x = -200, z = 720 },
			{ def = "ord_beacon", player = 1, x = 400, z = 720 },
			{ def = "ord_mason", player = 1, x = -300, z = 680, count = 3, dx = 20, heading = math.pi },
			{ def = "ord_architect", player = 1, x = 140, z = 680, count = 2, dx = 20, heading = math.pi },
			-- Order: IR SAM sites near the battlefield
			{ def = "ord_vigil", player = 1, x = -650, z = 380, count = 4, dx = 430 },
			-- Order army, facing south
			{ def = "ord_herald", player = 1, x = -500, z = 250, count = 6, dx = 200, heading = math.pi },
			{ def = "ord_lancer", player = 1, x = -700, z = 300, count = 12, cols = 6, dx = 24, rowDz = 24, heading = math.pi },
			{ def = "ord_lancer", player = 1, x = 560, z = 300, count = 12, cols = 6, dx = 24, rowDz = 24, heading = math.pi },
			{ def = "ord_paladin", player = 1, x = -100, z = 300, count = 16, cols = 8, dx = 28, rowDz = 28, heading = math.pi },
			{ def = "ord_halo", player = 1, x = -450, z = 350, count = 6, dx = 180, heading = math.pi },
			{ def = "ord_judgement", player = 1, x = -360, z = 440, count = 8, cols = 4, dx = 30, rowDz = 30, heading = math.pi },
			{ def = "ord_verdict", player = 1, x = 260, z = 440, count = 8, cols = 4, dx = 30, rowDz = 30, heading = math.pi },
			{ def = "ord_seraph", player = 1, x = -40, z = 470, count = 2, dx = 80, heading = math.pi },
			{ def = "ord_oracle", player = 1, x = -600, z = 470, count = 2, dx = 1200, heading = math.pi },
			{ def = "ord_arbiter", player = 1, x = -150, z = 500, count = 2, dx = 300, heading = math.pi },
			{ def = "ord_veil", player = 1, x = -300, z = 400, count = 2, dx = 600, heading = math.pi },
			-- Order air, over the bluffs
			{ def = "ord_falcon", player = 1, x = -500, z = 580, count = 8, cols = 4, dx = 30, rowDz = 30, heading = math.pi },
			{ def = "ord_archon", player = 1, x = 380, z = 580, count = 6, cols = 3, dx = 30, rowDz = 30, heading = math.pi },
			{ def = "ord_guardian", player = 1, x = -120, z = 560, count = 8, cols = 4, dx = 26, rowDz = 26, heading = math.pi },
			{ def = "ord_absolution", player = 1, x = -800, z = 600, count = 4, dx = 40, heading = math.pi },
			{ def = "ord_phantom", player = 1, x = 750, z = 600, count = 2, dx = 50, heading = math.pi },
			{ def = "ord_archangel", player = 1, x = 0, z = 620, heading = math.pi },
			-- Chaos (player 2): rear south of the river
			{ def = "chs_fusion", player = 2, x = -980, z = -800, count = 16, cols = 8, dx = 50, rowDz = -40 },
			{ def = "chs_converter", player = 2, x = 480, z = -760, count = 50, cols = 10, dx = 16, rowDz = -16 },
			{ def = "chs_depot", player = 2, x = -560, z = -840, count = 10, dx = 30 },
			{ def = "chs_ragnarok", player = 2, x = 0, z = -800 },
			{ def = "chs_wyvern", player = 2, x = -400, z = -760 },
			{ def = "chs_wyvern", player = 2, x = 250, z = -760 },
			{ def = "chs_wyvern", player = 2, x = 900, z = -760 },
			{ def = "chs_allseer", player = 2, x = -200, z = -820 },
			{ def = "chs_allseer", player = 2, x = 400, z = -820 },
			{ def = "chs_scrapper", player = 2, x = -300, z = -740, count = 3, dx = 20 },
			{ def = "chs_forgemaster", player = 2, x = 140, z = -740, count = 2, dx = 20 },
			-- Chaos: IR SAM sites near the battlefield
			{ def = "chs_thorn", player = 2, x = -650, z = -320, count = 4, dx = 430 },
			-- Chaos army, facing north
			{ def = "chs_jackal", player = 2, x = -500, z = -180, count = 6, dx = 200 },
			{ def = "chs_ravager", player = 2, x = -700, z = -230, count = 12, cols = 6, dx = 24, rowDz = -24 },
			{ def = "chs_ravager", player = 2, x = 560, z = -230, count = 12, cols = 6, dx = 24, rowDz = -24 },
			{ def = "chs_juggernaut", player = 2, x = -100, z = -230, count = 16, cols = 8, dx = 28, rowDz = -28 },
			{ def = "chs_hornet", player = 2, x = -450, z = -270, count = 6, dx = 180 },
			{ def = "chs_hydra", player = 2, x = -360, z = -300, count = 8, cols = 4, dx = 30, rowDz = -30 },
			{ def = "chs_hellmouth", player = 2, x = 260, z = -300, count = 8, cols = 4, dx = 30, rowDz = -30 },
			{ def = "chs_gorgon", player = 2, x = -40, z = -330, count = 2, dx = 80 },
			{ def = "chs_watcher", player = 2, x = -600, z = -340, count = 2, dx = 1200 },
			{ def = "chs_stalker", player = 2, x = -150, z = -350, count = 2, dx = 300 },
			{ def = "chs_shroud", player = 2, x = -300, z = -280, count = 2, dx = 600 },
			-- Chaos air, south of the river
			{ def = "chs_harpy", player = 2, x = -500, z = -520, count = 8, cols = 4, dx = 30, rowDz = -30 },
			{ def = "chs_manticore", player = 2, x = 380, z = -520, count = 6, cols = 3, dx = 30, rowDz = -30 },
			{ def = "chs_wasp", player = 2, x = -120, z = -500, count = 8, cols = 4, dx = 26, rowDz = -26 },
			{ def = "chs_plague", player = 2, x = -800, z = -560, count = 4, dx = 40 },
			{ def = "chs_behemoth", player = 2, x = 750, z = -560, count = 2, dx = 50 },
			{ def = "chs_banshee", player = 2, x = 0, z = -600 },
		},
	},
	-- 50 Lancers, no enemy: for trying selection and orders
	march = {
		seed = 1,
		mapId = "flat:48",
		scenario = "march_test",
		players = { { id = 1, team = 1 } },
		humanSlots = { 1 },
		demoOrders = false,
		restartAfter = nil,
	},
}

local ACTIVE = "terrain"

return table.freeze(PROFILES[ACTIVE])
