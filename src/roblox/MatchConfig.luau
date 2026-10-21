--!strict
-- What the Studio playtest runs (C-9). Until a lobby exists, the server
-- hosts one fixed match and Roblox players take the human slots in join
-- order. Pick a profile with ACTIVE, in this file: an edit made in Studio
-- isn't seen by Rojo and silently survives until this file changes.
--
-- `spawns` (optional) adds units after the scenario at every match start:
--   { def, player, x, z, heading?, count?, dx?, dz?, health? }
-- `count` units from (x, z), each `dx`, `dz` studs from the last (default
-- one unit); heading in radians (0 faces +z, pi / 2 faces +x). `health`
-- multiplies the units' starting health (test runs only; bars show full
-- until they drop below their normal maximum). `moveTo = { x, z }` gives
-- them a move order there as the match starts (their player's order).
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
