local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
local Sensors = require("../../src/server/Sim/Sensors")
local Orders = require("../../src/server/Sim/Orders")
local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 3 } }, mapId = "flat:96" })
local w = sim.world
local lancer = Spawn.unit(sim, "ord_lancer", 1, -200, 0, math.pi / 2)
Spawn.unit(sim, "ord_watchtower", 1, -50, 120, 0)
local enemy = Spawn.unit(sim, "chs_ravager", 2, 100, 0, -math.pi / 2)
World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
for i = 1, 40 do
	Sim.step(sim)
	if i % 10 == 0 then
		print(i, "level", Sensors.level(sim, w.ally[lancer], enemy), "ms", w.moveState[lancer], "fs", w.fireState[lancer], "queue", sim.orders.queue[lancer] and #sim.orders.queue[lancer], "anchor", sim.orders.anchorX[lancer], "pos", w.posX[lancer], "target", w.wTarget[lancer * 8], "goal", w.goalX[lancer])
	end
end
print("def", sim.defs.unitByIndex[w.defIndex[lancer]].domain, sim.defs.unitByIndex[w.defIndex[lancer]].buildPower, sim.defs.unitByIndex[w.defIndex[lancer]].maxRange)
