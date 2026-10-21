local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
local sim = Sim.new({ seed = 7, players = players, mapId = "map:twin_lakes", scenario = "standard_start",
	match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = "hard", [2] = "hard", [3] = "hard", [4] = "hard" } } })
local brains = Skirmish.forMatch(sim)
local g = sim.map.grid
local mid = g.originX + g.cellsX * 8 / 2
local w = sim.world
local seen = {}
for _ = 1, 1000 do
	for _, b in brains do Skirmish.tick(b) end
	Sim.step(sim)
	for _, e in sim.combat.events do
		if e.kind == "PRODUCED" or e.kind == "BUILD_DONE" then
			local id = e.unit
			local o = w.owner[id]
			if o then
				local x = w.posX[id]
				if o >= 3 then x = 2 * mid - x end
				print(string.format("t%d %s P%d %s at %.2f,%.2f heading %.3f", sim.tick, e.kind, o, sim.defs.unitByIndex[w.defIndex[id]].id, x, w.posZ[id], o >= 3 and (-w.heading[id]) % (2 * math.pi) or w.heading[id]))
			end
		end
	end
end
