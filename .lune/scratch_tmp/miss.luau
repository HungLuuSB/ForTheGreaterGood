local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
local Combat = require("../../src/server/Sim/Combat/Combat")
local Packer = require("../../src/shared/Net/Packer")
local Schema = require("../../src/shared/Net/Schema")
local function submit(sim, player, cmd)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end
local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
local w = sim.world
local c = sim.combat
local tgt = Spawn.unit(sim, "ord_falcon", 1, -540, 0, math.pi / 2)
World.setHealth(w, tgt, 1e9)
for _, p in { { 340, -120 }, { 500, -120 }, { 340, 120 }, { 500, 120 } } do
	Spawn.unit(sim, "chs_thorn", 2, p[1], p[2], 0)
end
local cell, ox, oz = sim.map.grid:encode(420, 0)
submit(sim, 1, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tgt }, cell = cell, offX = ox, offZ = oz })
local best, life, bestTick = {}, {}, {}
local hist = {}
local prev = {}
local pt = { 0, 0, 0 }
print("falcon speed", w.speed[tgt])
for _ = 1, 900 do
	Sim.step(sim)
	local tx, ty, tz = Combat.aimPoint(c, w, tgt)
	for _, p in c.proj do
		local q = prev[p]
		local d = math.huge
		if q then
			for k = 0, 20 do
				local f = k / 20
				local mx, my, mz = q[1] + (c.px[p] - q[1]) * f, q[2] + (c.py[p] - q[2]) * f, q[3] + (c.pz[p] - q[3]) * f
				local ax, ay, az = pt[1] + (tx - pt[1]) * f, pt[2] + (ty - pt[2]) * f, pt[3] + (tz - pt[3]) * f
				d = math.min(d, math.sqrt((mx - ax) ^ 2 + (my - ay) ^ 2 + (mz - az) ^ 2))
			end
		end
		if best[p] == nil or d < best[p] then best[p] = d end
		prev[p] = { c.px[p], c.py[p], c.pz[p] }
	end
	pt = { tx, ty, tz }
	for _, e in c.events do
		if e.kind == "IMPACT" and best[e.other] then
			local b = math.floor(best[e.other] / 2) * 2
			local key = (if e.unit == tgt then "hit " else "miss ") .. b
			hist[key] = (hist[key] or 0) + 1
			if e.unit ~= tgt and #hist < 0 then end
			best[e.other] = nil; prev[e.other] = nil
		end
	end
	if sim.tick % 150 == 0 then print("tick", sim.tick, "falcon", math.floor(w.posX[tgt]), math.floor(w.posZ[tgt]), "alt", w.alt[tgt], "speed", w.speed[tgt]) end
end
local keys = {}
for k in hist do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do print(k, hist[k]) end
