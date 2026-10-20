--!strict
-- Match start setups, by name. The scenario name is stored in the replay
-- header, so a replay rebuilds the same starting world. Setups may use only
-- sim.rng for randomness and must visit players in sim.playerOrder.

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

return Scenarios
