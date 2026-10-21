local Combat = require("../../src/server/Sim/Combat/Combat")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
for _, avoid in { true, false } do
	Combat.AVOID_OVERKILL = avoid
	local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 3 } }, mapId = "flat:96" })
	local w, c = sim.world, sim.combat
	local guns = {}
	for i = 1, 6 do table.insert(guns, Spawn.unit(sim, "ord_verdict", 1, -200, (i - 3.5) * 24, math.pi / 2)) end
	local sp = Spawn.unit(sim, "ord_lancer", 1, 60, 0, math.pi / 2); World.setFireState(w, sp, World.FireState.HOLD_FIRE)
	local ts = {}
	for i = 1, 6 do local t = Spawn.unit(sim, "chs_ravager", 2, 150, (i - 3.5) * 36, -math.pi / 2); World.setFireState(w, t, World.FireState.HOLD_FIRE); World.setHealth(w, t, 250); table.insert(ts, t) end
	print("avoid", avoid)
	for _ = 1, 200 do
		Sim.step(sim)
		for _, e in c.events do
			if e.kind == "SPAWN_PROJ" then print(sim.tick, "fire", e.unit, "->", c.pAim[e.other])
			elseif e.kind == "IMPACT" then print(sim.tick, "impact", e.unit)
			elseif e.kind == "DEATH" then print(sim.tick, "DEATH", e.unit) end
		end
	end
end
