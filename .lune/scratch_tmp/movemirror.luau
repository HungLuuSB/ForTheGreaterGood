local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Packer = require("../../src/shared/Net/Packer")
local Schema = require("../../src/shared/Net/Schema")
local process = require("@lune/process")
local mapId = process.args[1] or "map:ridgeline"
local unit = process.args[2] or "ord_mason"
local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } }, mapId = mapId })
local g = sim.map.grid
local w = sim.world
local mid = g.originX + g.cellsX * 8 / 2
local half = g.cellsX * 8 / 2
local function submit(player, cmd)
	local wr = Packer.Writer.new(); Schema.encodeCommand(wr, cmd); assert(Sim.submit(sim, player, wr:finish()))
end
-- pairs of trips (west unit, mirrored east unit) from a grid of starts to a grid of goals
local trips = {}
local k = 0
for _, sx in { -0.8, -0.5, -0.2 } do
	for _, sz in { -0.6, 0, 0.6 } do
		for _, gx in { -0.6, -0.1, 0.3 } do
			for _, gz in { -0.7, 0.1, 0.7 } do
				k += 1
				if k % 3 == 0 then table.insert(trips, { sx * half + mid, sz * half, gx * half + mid, gz * half }) end
			end
		end
	end
end
local westFaster, eastFaster, equal, diffSum = 0, 0, 0, 0
for _, tr in trips do
	local s2 = Sim.new({ seed = 1, players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } }, mapId = mapId })
	sim = s2; w = s2.world
	local a = Spawn.unit(sim, unit, 1, tr[1], tr[2], 0)
	local b = Spawn.unit(sim, unit, 2, 2 * mid - tr[1], tr[2], 0)
	local ca, oxa, oza = g:encode(tr[3], tr[4])
	local cb, oxb, ozb = g:encode(2 * mid - tr[3], tr[4])
	submit(1, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { a }, cell = ca, offX = oxa, offZ = oza })
	submit(2, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { b }, cell = cb, offX = oxb, offZ = ozb })
	local ta, tb
	for _ = 1, 3000 do
		Sim.step(sim)
		if not ta and w.orderId[a] == 0 then ta = sim.tick end
		if not tb and w.orderId[b] == 0 then tb = sim.tick end
		if ta and tb then break end
	end
	ta, tb = ta or 3000, tb or 3000
	if ta < tb then westFaster += 1 elseif tb < ta then eastFaster += 1 else equal += 1 end
	diffSum += tb - ta
end
print(string.format("%s %s: %d trips, west faster %d, east faster %d, equal %d, mean (east - west) %.1f ticks", mapId, unit, #trips, westFaster, eastFaster, equal, diffSum / #trips))
