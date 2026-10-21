local process = require("@lune/process")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local level = process.args[1] or "hard"
local minutes = tonumber(process.args[2]) or 20
local seeds = tonumber(process.args[3]) or 3
local aligned = process.args[4] == "aligned"
local function value(sim, owner)
	local v = 0
	for _, id in sim.world.ids do
		if sim.world.owner[id] == owner then
			local c = sim.defs.unitByIndex[sim.world.defIndex[id]].cost
			v += (c.supply + c.power / 10) * sim.world.buildProgress[id]
		end
	end
	return v
end
local west, east = 0, 0
for seed = 7, 6 + seeds do
	local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
	local sim = Sim.new({ seed = seed, players = players, mapId = "map:twin_lakes", scenario = "standard_start",
		match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = level, [2] = level, [3] = level, [4] = level } } })
	local brains = Skirmish.forMatch(sim)
	if aligned then
		for _, b in brains do b.thinkOffset = if b.player == 1 or b.player == 3 then 0 else b.cfg.think // 2 end
	end
	local trace = {}
	for t = 1, minutes * 900 do
		for _, b in brains do Skirmish.tick(b) end
		Sim.step(sim)
		if t % 2700 == 0 then
			table.insert(trace, string.format("%dm %d/%d|%d/%d", t // 900, value(sim, 1), value(sim, 3), value(sim, 2), value(sim, 4)))
		end
		if sim.match.over then break end
	end
	local w = if sim.match.over then sim.match.winner elseif value(sim, 1) + value(sim, 2) > value(sim, 3) + value(sim, 4) then 1 else 2
	if w == 1 then west += 1 elseif w == 2 then east += 1 end
	print(string.format("seed %d: winner %s at %.1f min%s; values P1/P3|P2/P4: %s", seed, if w == 1 then "west" else "east", sim.tick / 900, if sim.match.over then "" else " (on value)", table.concat(trace, "  ")))
end
print(string.format("%s mirror%s: west %d, east %d", level, if aligned then " (aligned offsets)" else "", west, east))
