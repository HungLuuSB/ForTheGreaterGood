--!strict
-- What the Studio playtest runs (C-9). Until the join handshake (protocol 6)
-- and lobby exist, the server hosts one fixed match and Roblox players take
-- the human slots in join order.

return table.freeze({
	seed = 7,
	mapId = "flat:48",
	scenario = "duel_test", -- 10 Lancers (player 1) vs 10 Ravagers (player 2)
	players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
	humanSlots = { 1 }, -- sim players controlled by Roblox players, in join order
	-- Placeholder until client commands exist (client task 5): at the start
	-- the server orders every unit to drive at the enemy side.
	demoOrders = true,
	-- Start a new match (next seed) this long after one side has no units left.
	restartAfter = 6, -- seconds
})
