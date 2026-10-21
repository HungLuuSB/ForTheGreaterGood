--!strict
-- What the Studio playtest runs (C-9). Until a lobby exists, the server
-- hosts one fixed match and Roblox players take the human slots in join
-- order. Pick a profile with ACTIVE, in this file: an edit made in Studio
-- isn't seen by Rojo and silently survives until this file changes.

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

local ACTIVE = "duel"

return table.freeze(PROFILES[ACTIVE])
