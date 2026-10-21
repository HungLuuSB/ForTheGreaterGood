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
local w, c = sim.world, sim.combat
local tgt = Spawn.unit(sim, "ord_guardian", 1, -540, 0, math.pi / 2)
World.setHealth(w, tgt, 1e9)
for _, p in { { 340, -120 }, { 500, -120 }, { 340, 120 }, { 500, 120 } } do
	Spawn.unit(sim, "chs_thorn", 2, p[1], p[2], 0)
end
local cell, ox, oz = sim.map.grid:encode(200, 0)
submit(sim, 1, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tgt }, cell = cell, offX = ox, offZ = oz })
local born, decoy = {}, {}
local track = {}
for _ = 1, 260 do
	Sim.step(sim)
	for _, p in c.proj do
		track[p] = track[p] or {}
		table.insert(track[p], string.format("(%.0f,%.0f,%.0f v %.0f,%.0f,%.0f tgt %d)", c.px[p], c.py[p], c.pz[p], c.pvx[p], c.pvy[p], c.pvz[p], c.pTarget[p]))
	end
	for _, e in c.events do
		if e.kind == "SPAWN_PROJ" then born[e.other] = sim.tick
		elseif e.kind == "DECOYED" then decoy[e.other] = true
		elseif e.kind == "IMPACT" and born[e.other] and e.unit ~= tgt and not decoy[e.other] then
			local tx, ty, tz = Combat.aimPoint(c, w, tgt)
			print(table.concat(track[e.other] or {}, " "))
			local hx, hy, hz = Combat.aimPoint(c, w, tgt)
			print("heli", hx, hy, hz, "ground", Combat.groundHeight(c, e.x, e.z))
			print(string.format("miss at tick %d, life %d, y %.1f, dist to heli %.1f, heli speed %.1f alt %.1f", sim.tick, sim.tick - born[e.other], e.y, math.sqrt((e.x - tx) ^ 2 + (e.y - ty) ^ 2 + (e.z - tz) ^ 2), w.speed[tgt], w.alt[tgt]))
		end
		if e.kind == "IMPACT" then born[e.other] = nil; decoy[e.other] = nil; track[e.other] = nil end
	end
end
