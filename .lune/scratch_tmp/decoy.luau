local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
local Packer = require("../../src/shared/Net/Packer")
local Schema = require("../../src/shared/Net/Schema")
local NetOut = require("../../src/server/Sim/NetOut")
local Client = require("../../src/server/Tests/Support/Client")
local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
local w, c = sim.world, sim.combat
local tgt = Spawn.unit(sim, "ord_falcon", 1, -540, 0, math.pi / 2)
World.setHealth(w, tgt, 1e9)
for _, p in { { 340, -120 }, { 500, -120 }, { 340, 120 }, { 500, 120 } } do Spawn.unit(sim, "chs_thorn", 2, p[1], p[2], 0) end
local wr = Packer.Writer.new()
local cell, ox, oz = sim.map.grid:encode(420, 0)
Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tgt }, cell = cell, offX = ox, offZ = oz })
Sim.submit(sim, 1, wr:finish())
local watch = {}
local spec = NetOut.addSpectator(sim)
local view = Client.new(sim.map.grid)
for _ = 1, 1200 do
	Sim.step(sim)
	Client.receive(view, sim.net.spectators[spec].outbox)
	for _, e in c.events do
		if e.kind == "DECOYED" then
			watch[e.other] = true
			local d = c.pDecoy[e.other]
			if false then print("decoyed", e.other, "tick", sim.tick, "dist", math.floor(math.sqrt((c.px[e.other]-w.posX[tgt])^2+(c.pz[e.other]-w.posZ[tgt])^2)), "decoy", d and d[4]) end
		end
	end
	for p in watch do
		if c.projSlot[p] then
			local d = c.pDecoy[p]
			local cp = view.projectiles[p]
			local dd = cp and math.sqrt((cp.x-c.px[p])^2+(cp.y-c.py[p])^2+(cp.z-c.pz[p])^2) or 0
			if dd > 5 then print("  ", p, sim.tick, d and d[4] or "-", math.floor(c.px[p]), math.floor(c.py[p]), math.floor(c.pz[p]), d and string.format("pt %d %d %d", d[1], d[2], d[3]) or "", cp and string.format("client %.1f %.1f %.1f dec %s tgt %d", cp.x, cp.y, cp.z, tostring(cp.decoy and cp.decoy[4]), cp.target) or "none", dd) end
		else watch[p] = nil end
	end
end
