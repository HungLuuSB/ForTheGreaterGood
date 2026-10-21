local process = require("@lune/process")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local mapId = process.args[1] or "map:coastline"
local l1, l2 = process.args[2] or "normal", process.args[3] or "easy"
local minutes = tonumber(process.args[4]) or 20
local teams = process.args[5] == "chaos" and { 2, 4 } or { 1, 3 }
local sim = Sim.new({ seed = 7, players = { { id = 1, team = teams[1], allyTeam = 1 }, { id = 2, team = teams[2], allyTeam = 2 } }, mapId = mapId, scenario = "standard_start",
	match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = l1, [2] = l2 } } })
local brains = Skirmish.forMatch(sim)
local w = sim.world
local kills = { 0, 0 }
for t = 1, minutes * 900 do
	for _, b in brains do Skirmish.tick(b) end
	Sim.step(sim)
	for _, e in sim.combat.events do
		if e.kind == "DEATH" then
			local victimOwner = 0
			-- dead unit already removed; credit by the wreck or skip
			kills[1] += 0
		end
	end
	if t % 900 == 0 then
		local parts = {}
		for p = 1, 2 do
			local n, army, sx, sz, structures = 0, 0, 0, 0, 0
			for _, id in w.ids do
				if w.owner[id] == p then
					n += 1
					local d = sim.defs.unitByIndex[w.defIndex[id]]
					if d.moveClass == nil then
						structures += 1
					elseif not d.builder and #d.weapons > 0 then
						army += 1; sx += w.posX[id]; sz += w.posZ[id]
					end
				end
			end
			table.insert(parts, string.format("P%d %s: units %d (structures %d, army %d at %d,%d) supply %d", p, brains[p].cfg.name or "", n, structures, army, army > 0 and sx // army or 0, army > 0 and sz // army or 0, sim.eco.accounts[sim.players[p].team].supply.stored))
		end
		print(string.format("%2dm kills %d | %s", t // 900, sim.combat.stats.kills, table.concat(parts, " | ")))
		if t == 900 * 10 then
			local n = 0
			for id in brains[2].attacking do
				if w.slot[id] and n < 8 then
					n += 1
					local q = sim.orders.queue[id]
					local h = q and q[1]
					local tg = w.wTarget[id * 8]
					print(string.format("   unit %d %s at %d,%d order %s hold %s target %s %s speed %.1f", id, sim.defs.unitByIndex[w.defIndex[id]].id, w.posX[id], w.posZ[id], h and h.kind or "-", tostring(sim.orders.hold[id]), tostring(tg), tg ~= 0 and w.slot[tg] and string.format("%s at %d,%d", sim.defs.unitByIndex[w.defIndex[tg]].id, w.posX[tg], w.posZ[tg]) or "", w.speed[id]))
				end
			end
		end
		for p = 1, 2 do
			local b = brains[p]
			local tx, tz, ax, az = Skirmish.knownTargets(b)
			local nw = 0
			for _ in b.attacking do nw += 1 end
			print(string.format("     P%d threat %s target %s waves %d waveSize %d attacking %d home %d,%d enemy %d,%d", p, tx and string.format("%d,%d", tx, tz) or "-", ax and string.format("%d,%d", ax, az) or "-", b.waves, b.waveSize, nw, b.homeX, b.homeZ, b.enemyX, b.enemyZ))
		end
	end
	if sim.match.over then print("over, winner", sim.match.winner) break end
end
