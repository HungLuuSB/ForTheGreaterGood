local process = require("@lune/process")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local aligned = process.args[1] == "aligned"
local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
local sim = Sim.new({ seed = 7, players = players, mapId = "map:twin_lakes", scenario = "standard_start",
	match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = "hard", [2] = "hard", [3] = "hard", [4] = "hard" } } })
local brains = Skirmish.forMatch(sim)
if aligned then for _, b in brains do b.thinkOffset = if b.player == 1 or b.player == 3 then 0 else b.cfg.think // 2 end end
local function defs(owner)
	local per = {}
	for _, id in sim.world.ids do
		if sim.world.owner[id] == owner then
			local d = sim.defs.unitByIndex[sim.world.defIndex[id]].id
			per[d] = (per[d] or 0) + sim.world.buildProgress[id]
		end
	end
	return per
end
for t = 1, 2700 do
	for _, b in brains do Skirmish.tick(b) end
	Sim.step(sim)
	if t % 450 == 0 then
		local a, b = defs(1), defs(3)
		local keys = {}
		for k in a do keys[k] = true end
		for k in b do keys[k] = true end
		local parts = {}
		for k in keys do
			if math.abs((a[k] or 0) - (b[k] or 0)) > 0.01 then table.insert(parts, string.format("%s %.2f/%.2f", k, a[k] or 0, b[k] or 0)) end
		end
		table.sort(parts)
		local ea, eb = sim.eco.accounts[1], sim.eco.accounts[3]
		print(string.format("t%d P1/P3 differ: %s | supply %.0f/%.0f power %.0f/%.0f, income s %.1f/%.1f p %.1f/%.1f", t, table.concat(parts, ", "), ea.supply.stored, eb.supply.stored, ea.power.stored, eb.power.stored, ea.supply.income, eb.supply.income, ea.power.income, eb.power.income))
	end
end
