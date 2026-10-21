local process = require("@lune/process")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local Schema = require("../../src/shared/Net/Schema")
local level = process.args[1] or "hard"
local seed = tonumber(process.args[2]) or 7
local minutes = tonumber(process.args[3]) or 6
local levels = { level, level, level, level }
if process.args[4] then levels = { process.args[4], process.args[4], level, level } end -- west, east
local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
local sim = Sim.new({ seed = seed, players = players, mapId = "map:twin_lakes", scenario = "standard_start",
	match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = levels[1], [2] = levels[2], [3] = levels[3], [4] = levels[4] } } })
local brains = Skirmish.forMatch(sim)
local g = sim.map.grid
local cx = g.originX + g.cellsX * 8 / 2
local log = { {}, {}, {}, {} }
for _ = 1, minutes * 900 do
	for _, b in brains do Skirmish.tick(b) end
	for _, q in sim.queue do
		local c = q.cmd
		if c.cmdType == Schema.CmdType.BUILD then
			local d = sim.defs.unitByIndex[c.defIndex].id
			local s
			if c.cell and c.cell ~= 0 then
				local x, z = g:decode(c.cell, c.offX, c.offZ)
				if q.player >= 3 then x = 2 * cx - x end
				s = string.format("%s@%d,%d", d, math.floor(x / 8 + 0.5), math.floor(z / 8 + 0.5))
			else
				s = d
			end
			table.insert(log[q.player], { tick = sim.tick, s = s })
		end
	end
	Sim.step(sim)
	if sim.match.over then break end
end
for _, pair in { { 1, 3 }, { 2, 4 } } do
	local a, b = log[pair[1]], log[pair[2]]
	local n = math.min(#a, #b)
	local first = nil
	for i = 1, n do
		if a[i].s ~= b[i].s then first = i break end
	end
	print(string.format("players %d / %d: %d / %d build orders; first difference at #%s", pair[1], pair[2], #a, #b, tostring(first)))
	if first then
		for i = 1, math.min(n, first + 2) do
			print(string.format("  #%d  t%d %-34s | t%d %s", i, a[i].tick, a[i].s, b[i].tick, b[i].s))
		end
	end
end
print("winner", sim.match.winner, "tick", sim.tick)
