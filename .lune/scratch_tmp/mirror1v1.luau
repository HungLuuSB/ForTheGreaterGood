local process = require("@lune/process")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local Schema = require("../../src/shared/Net/Schema")
local level = process.args[1] or "normal"
local seeds = tonumber(process.args[2]) or 6
local minutes = tonumber(process.args[3]) or 10
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
for seed = 1, seeds do
	for _, teams in { { 1, 3 }, { 2, 4 } } do
		local sim = Sim.new({ seed = seed, players = { { id = 1, team = teams[1], allyTeam = 1 }, { id = 2, team = teams[2], allyTeam = 2 } }, mapId = "map:ridgeline", scenario = "standard_start",
			match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = level, [2] = level } } })
		local brains = Skirmish.forMatch(sim)
		local g = sim.map.grid
		local midX = g.originX + g.cellsX * 8 / 2
		local orders = { {}, {} }
		local trace = {}
		for t = 1, minutes * 900 do
			for _, b in brains do Skirmish.tick(b) end
			for _, q in sim.queue do
				local cmd = q.cmd
				if cmd.cmdType == Schema.CmdType.BUILD and (cmd.cell or 0) ~= 0 then
					local x, z = g:decode(cmd.cell, cmd.offX, cmd.offZ)
					if q.player == 2 then x = 2 * midX - x end
					table.insert(orders[q.player], string.format("%s@%d,%d", sim.defs.unitByIndex[cmd.defIndex].id, math.floor(x / 8 + 0.5), math.floor(z / 8 + 0.5)))
				end
			end
			Sim.step(sim)
			if t % 1800 == 0 then table.insert(trace, string.format("%dm %d/%d", t // 900, value(sim, 1), value(sim, 2))) end
			if sim.match.over then break end
		end
		local same = 0
		while same < math.min(#orders[1], #orders[2]) and orders[1][same + 1] == orders[2][same + 1] do same += 1 end
		local w = if sim.match.over then sim.match.winner elseif value(sim, 1) > value(sim, 2) then 1 else 2
		if w == 1 then west += 1 else east += 1 end
		print(string.format("seed %d %s: %s at %.1f; same first %d structures (%s | %s); %s", seed, teams[1] == 1 and "Order" or "Chaos", w == 1 and "west" or "east", sim.tick / 900, same, orders[1][same + 1] or "-", orders[2][same + 1] or "-", table.concat(trace, " ")))
	end
end
print(level, "west", west, "east", east)
