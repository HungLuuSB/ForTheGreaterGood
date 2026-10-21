local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local Schema = require("../../src/shared/Net/Schema")
local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } }, mapId = "map:ridgeline", scenario = "standard_start",
	match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = "normal", [2] = "normal" } } })
local brains = Skirmish.forMatch(sim)
local w = sim.world
local rows = { {}, {} }
for _ = 1, 1500 do
	for _, b in brains do
		if (sim.tick - b.thinkOffset) % b.cfg.think == 0 then
			local a = sim.eco.accounts[b.team]
			local plants, frames, busy = 0, 0, 0
			for _, id in w.ids do
				if w.owner[id] == b.player then
					local d = sim.defs.unitByIndex[w.defIndex[id]]
					if d.id == "ord_vehplant" then if w.buildProgress[id] >= 1 then plants += 1 else frames += 1 end end
				end
			end
			table.insert(rows[b.player], string.format("t%d plants %d frames %d p.income %.0f ratio %.2f stored %.0f s.stored %.0f shortAt %d", sim.tick, plants, frames, a.power.income, a.power.ratio, a.power.stored, a.supply.stored, b.powerShortAt == -math.huge and -1 or b.powerShortAt))
		end
		Skirmish.tick(b)
	end
	for _, q in sim.queue do
		if q.cmd.cmdType == Schema.CmdType.BUILD and (q.cmd.cell or 0) ~= 0 then
			table.insert(rows[q.player], string.format("   -> BUILD %s", sim.defs.unitByIndex[q.cmd.defIndex].id))
		end
	end
	Sim.step(sim)
end
for i = 1, 60 do
	if rows[1][i] or rows[2][i] then
		print(string.format("%-90s | %s", rows[1][i] or "", rows[2][i] or ""))
	end
end
