--!strict
-- Match start setups, by name. The scenario name is stored in the replay
-- header, so a replay rebuilds the same starting world. Setups may use only
-- sim.rng for randomness and must visit players in sim.playerOrder.

local Nav = require("./Nav")
local Spawn = require("./Spawn")
local Types = require("./Types")

local Scenarios: { [string]: (Types.Sim) -> () } = {}

-- No units. Used by tests that build their own world.
Scenarios.empty = function(_sim: Types.Sim) end

-- Ten tanks per player scattered over a 512 × 512 stud area, of the
-- player's faction (S-174; by default Order for odd teams, Chaos for even). Headless test setup until real starts exist.
Scenarios.skirmish_test = function(sim: Types.Sim)
	local defs = sim.defs
	for _, playerId in sim.playerOrder do
		local player = sim.players[playerId]
		local defId = if player.faction == "order" then "ord_lancer" else "chs_ravager"
		for _ = 1, 10 do
			local x = sim.rng:nextNumber(-256, 256)
			local z = sim.rng:nextNumber(-256, 256)
			Spawn.unit(sim, defId, player.id, x, z, sim.rng:nextNumber(0, 2 * math.pi))
		end
	end
end

-- 50 Lancers for the first player, in a block (columns of up to 10) near the
-- west edge of the map
-- (spots on terrain they can't stand on are skipped). Needs a map.
Scenarios.march_test = function(sim: Types.Sim)
	local nav = sim.nav
	if nav == nil then
		error("Scenarios.march_test: needs a map (mapId)", 0)
	end
	local profile = nav.profiles[sim.defs.units.ord_lancer.index]
	local g = nav.grid
	local owner = sim.playerOrder[1]
	local spacing = 12
	local placed = 0
	local x = g.originX + 24
	while placed < 50 and x < g.originX + g.sizeX / 3 do
		for row = 0, 9 do
			-- rows alternate outward from the middle: 0, +1, -1, +2, -2, ...
			local offset = if row % 2 == 0 then row // 2 else -(row // 2 + 1)
			local z = offset * spacing
			if placed < 50 and math.abs(z) < g.sizeZ / 2 - 16 and Nav.fits(nav, profile, x, z) then
				Spawn.unit(sim, "ord_lancer", owner, x, z, math.pi / 2) -- facing +X
				placed += 1
			end
		end
		x += spacing
	end
end

-- Ten Lancers (first player) and ten Ravagers (second player) facing each
-- other 140 studs apart in two rows of five, all within both guns' range.
Scenarios.duel_test = function(sim: Types.Sim)
	local order = sim.playerOrder
	if #order < 2 then
		error("Scenarios.duel_test: needs two players", 0)
	end
	for i = 0, 9 do
		local row, col = i // 5, i % 5
		Spawn.unit(sim, "ord_lancer", order[1], -70 - row * 10, (col - 2) * 12, math.pi / 2)
		Spawn.unit(sim, "chs_ravager", order[2], 70 + row * 10, (col - 2) * 12, -math.pi / 2)
	end
end

-- Match start (guide 16.3): each player's Command Vehicle at its map start
-- position (player order), of the player's faction (S-174), facing the map
-- center. Needs a map with start positions.
-- With chosen starts (the pre-game, S-169) each Commander stands on its
-- player's pick (`sim.startPositions`), facing the map's centre.
Scenarios.standard_start = function(sim: Types.Sim)
	local map = sim.map
	local chosen = sim.startPositions
	if map == nil or (chosen == nil and #map.layers.starts < #sim.playerOrder) then
		error("Scenarios.standard_start: needs a map with a start per player", 0)
	end
	for i, playerId in sim.playerOrder do
		local player = sim.players[playerId]
		local defId = if player.faction == "order" then "ord_sovereign" else "chs_warlord"
		if chosen then
			local p = chosen[playerId]
			local g = map.grid
			local cx, cz = g.originX + g.cellsX * 4, g.originZ + g.cellsZ * 4 -- the map's centre
			Spawn.unit(sim, defId, playerId, p[1], p[2], math.atan2(cx - p[1], cz - p[2]))
		else
			local start = map.layers.starts[i]
			local heading = if start[1] < 0 then math.pi / 2 else -math.pi / 2
			Spawn.unit(sim, defId, playerId, start[1], start[2], heading)
		end
	end
end

-- Electronic warfare (guide 11.5–11.6): an Order radar SAM site with a
-- spotter facing a Chaos helicopter under a mobile jammer, and an Order
-- helicopter with DIRCM inside a ring of four Chaos IR SAM sites.
Scenarios.ew_test = function(sim: Types.Sim)
	local order = sim.playerOrder
	if #order < 2 then
		error("Scenarios.ew_test: needs two players", 0)
	end
	local a, b = order[1], order[2]
	Spawn.unit(sim, "ord_aegis", a, -450, 0)
	Spawn.unit(sim, "ord_lancer", a, 100, 150, math.pi)
	Spawn.unit(sim, "ord_generator", a, -450, 200)
	Spawn.unit(sim, "ord_guardian", a, -250, -250)
	Spawn.unit(sim, "chs_wasp", b, 100, 0)
	Spawn.unit(sim, "chs_shroud", b, 120, -40)
	for i = 0, 3 do
		local angle = i * math.pi / 2
		Spawn.unit(sim, "chs_thorn", b, -250 + 150 * math.sin(angle), -250 + 150 * math.cos(angle))
	end
end

-- Match rules (guide 16): each player gets a Command Vehicle and tanks.
-- Ally team 1 (the lowest) starts west with three tanks per player; every
-- other ally team starts east with one, so ally team 1 wins a straight fight.
Scenarios.match_test = function(sim: Types.Sim)
	local first = sim.allyTeams[1]
	local slot: { [number]: number } = {}
	for _, pid in sim.playerOrder do
		local ally = sim.players[pid].allyTeam :: number
		slot[ally] = (slot[ally] or 0) + 1
		local west = ally == first
		local x = if west then -160 else 160
		local z = (slot[ally] - 1) * 120 - 60
		local facing = if west then math.pi / 2 else -math.pi / 2
		Spawn.unit(sim, if west then "ord_sovereign" else "chs_warlord", pid, x + (if west then -40 else 40), z, facing)
		for k = 1, if west then 3 else 1 do
			Spawn.unit(sim, if west then "ord_lancer" else "chs_ravager", pid, x, z + (k - 2) * 16, facing)
		end
	end
end

return Scenarios
