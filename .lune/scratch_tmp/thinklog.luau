local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
local sim = Sim.new({ seed = 7, players = players, mapId = "map:twin_lakes", scenario = "standard_start",
	match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = "hard", [2] = "hard", [3] = "hard", [4] = "hard" } } })
local brains = Skirmish.forMatch(sim)
local rows = { [1] = {}, [3] = {} }
for _ = 1, 900 do
	for _, b in brains do
		if (b.player == 1 or b.player == 3) and (sim.tick - b.thinkOffset) % b.cfg.think == 0 and sim.tick >= 700 then
			local a = sim.eco.accounts[b.team]
			table.insert(rows[b.player], string.format("t%d ratio %.3f income %.0f stored %.0f demand %.1f", sim.tick, a.power.ratio, a.power.income, a.power.stored, a.power.demand))
		end
		Skirmish.tick(b)
	end
	Sim.step(sim)
end
for i = 1, math.min(#rows[1], 14) do
	print(string.format("%-62s | %s", rows[1][i], rows[3][i] or ""))
end
