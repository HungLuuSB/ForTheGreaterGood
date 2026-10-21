local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
local Packer = require("../../src/shared/Net/Packer")
local Schema = require("../../src/shared/Net/Schema")
local process = require("@lune/process")

local function submit(sim, player, cmd)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function run(targetDef, seed, ticks, goal)
	local sim = Sim.new({ seed = seed, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
	local w = sim.world
	local tgt = Spawn.unit(sim, targetDef, 1, -540, 0, math.pi / 2)
	World.setHealth(w, tgt, 1e9)
	for _, p in { { 340, -120 }, { 500, -120 }, { 340, 120 }, { 500, 120 } } do
		Spawn.unit(sim, "chs_thorn", 2, p[1], p[2], 0)
	end
	local g = sim.map.grid
	local cell, ox, oz = g:encode(goal[1], goal[2])
	submit(sim, 1, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tgt }, cell = cell, offX = ox, offZ = oz })
	local launched, hits, decoyed, lost, expired = 0, 0, 0, 0, 0
	local mine = {}
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "SPAWN_PROJ" and sim.combat.pTeam[e.other] == 2 then
				launched += 1
				mine[e.other] = true
			elseif e.kind == "IMPACT" and mine[e.other] then
				mine[e.other] = nil
				if e.unit == tgt then hits += 1 else expired += 1 end
			elseif e.kind == "DECOYED" and mine[e.other] then decoyed += 1
			elseif e.kind == "LOST_LOCK" and mine[e.other] then lost += 1 end
		end
	end
	return launched, hits, decoyed, lost, expired
end
local ticks = tonumber(process.args[1]) or 1800
for _, case in { { "ord_falcon", { 420, 0 } }, { "ord_guardian", { 420, 0 } }, { "ord_guardian", { 200, 0 } } } do
	local L, H, D, Lo, E = 0, 0, 0, 0, 0
	for seed = 1, 3 do
		local l, h, d, lo, e = run(case[1], seed, ticks, case[2])
		L += l; H += h; D += d; Lo += lo; E += e
	end
	print(string.format("%-13s goal %4d,%d: launched %d, hits %d (%.0f%%), decoyed %d, lost lock %d, missed/expired %d", case[1], case[2][1], case[2][2], L, H, H / math.max(L, 1) * 100, D, Lo, E))
end
