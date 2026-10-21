local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 3 } }, mapId = "flat:96" })
local w = sim.world
local lancer = Spawn.unit(sim, "ord_lancer", 1, -200, 0, math.pi / 2)
local scout = Spawn.unit(sim, "ord_herald", 1, 40, 90, 0)
World.setFireState(w, scout, World.FireState.HOLD_FIRE); World.setMoveState(w, scout, 0)
local enemy = Spawn.unit(sim, "chs_ravager", 2, 100, 0, -math.pi / 2)
World.setFireState(w, enemy, World.FireState.HOLD_FIRE); World.setMoveState(w, enemy, 0); World.setHealth(w, enemy, 2000)
for i = 1, 200 do
	Sim.step(sim)
	if i % 5 == 0 then
		local q = sim.orders.queue[lancer]
		print(i, string.format("x %.1f speed %.1f", w.posX[lancer] + 200, w.speed[lancer]), "order", q and q[1] and q[1].kind, "auto", q and q[1] and q[1].auto, "hold", sim.orders.hold[lancer], "target", w.wTarget[lancer * 8], "blocked", w.wBlocked[lancer * 8], "scoutX", w.posX[scout])
	end
end
