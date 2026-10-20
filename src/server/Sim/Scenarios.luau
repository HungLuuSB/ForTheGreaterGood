--!strict
-- Match start setups, by name. The scenario name is stored in the replay
-- header, so a replay rebuilds the same starting world. Setups may use only
-- sim.rng for randomness and must visit players in sim.playerOrder.

local Nav = require("./Nav")
local Types = require("./Types")
local World = require("./World")

local Scenarios: { [string]: (Types.Sim) -> () } = {}

-- No units. Used by tests that build their own world.
Scenarios.empty = function(_sim: Types.Sim) end

-- Ten tanks per player scattered over a 512 × 512 stud area: Order for odd
-- teams, Chaos for even teams. Headless test setup until real starts exist.
Scenarios.skirmish_test = function(sim: Types.Sim)
	local defs = sim.defs
	for _, playerId in sim.playerOrder do
		local player = sim.players[playerId]
		local def = if player.team % 2 == 1 then defs.units.ord_lancer else defs.units.chs_ravager
		for _ = 1, 10 do
			World.spawn(sim.world, sim.tick, {
				defIndex = def.index,
				team = player.team,
				owner = player.id,
				x = sim.rng:nextNumber(-256, 256),
				z = sim.rng:nextNumber(-256, 256),
				heading = sim.rng:nextNumber(0, 2 * math.pi),
				health = def.health,
			})
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
	local def = sim.defs.units.ord_lancer
	local profile = nav.profiles[def.index]
	local g = nav.grid
	local owner = sim.playerOrder[1]
	local team = sim.players[owner].team
	local spacing = 12
	local placed = 0
	local x = g.originX + 24
	while placed < 50 and x < g.originX + g.sizeX / 3 do
		for row = 0, 9 do
			-- rows alternate outward from the middle: 0, +1, -1, +2, -2, ...
			local offset = if row % 2 == 0 then row // 2 else -(row // 2 + 1)
			local z = offset * spacing
			if placed < 50 and math.abs(z) < g.sizeZ / 2 - 16 and Nav.fits(nav, profile, x, z) then
				World.spawn(sim.world, sim.tick, {
					defIndex = def.index,
					team = team,
					owner = owner,
					x = x,
					z = z,
					heading = math.pi / 2, -- facing +X
					health = def.health,
				})
				placed += 1
			end
		end
		x += spacing
	end
end

return Scenarios
