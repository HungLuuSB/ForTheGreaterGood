--!strict
-- The skirmish AI's military (S-222, after BAR's CircuitAI): the threat
-- map, targets a wave outweighs, waves sized to the strongest enemy group,
-- damaged units repaired at a Construction Turret.
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Spawn = require("../Sim/Spawn")
local ThreatMap = require("../Sim/AI/ThreatMap")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function start(seed: number): Sim.Sim
	return Sim.new({
		seed = seed,
		players = PLAYERS,
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
end

-- A unit that holds its fire (so the test's setup stays as it is).
local function spawn(sim: Sim.Sim, defId: string, owner: number, x: number, z: number): number
	local id = Spawn.unit(sim, defId, owner, x, z, 0)
	World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
	return id
end

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

return function(t: RunAll.Context)
	t.test("the threat map: known armed enemies by their reach, the enemy army by where it stands (S-222)", function()
		local sim = start(51)
		local brain = Skirmish.new(sim, 1, "hard")
		local ally = brain.ally
		local mx, mz = (brain.homeX + brain.enemyX) / 2, (brain.homeZ + brain.enemyZ) / 2
		local guard = sim.defs.units.chs_guard
		local reach = ThreatMap.surfaceRange(sim.defs, guard)
		t.expect(reach > 0, "the turret reaches ground targets")
		spawn(sim, "chs_guard", 2, mx, mz)
		spawn(sim, "ord_lancer", 1, mx - brain.toward * 120, mz) -- sees it
		steps(sim, 10)
		local tm = ThreatMap.build(sim, ally)
		local v = ThreatMap.value(guard)
		t.equal(ThreatMap.at(tm, mx, mz), v, "on the turret")
		t.equal(ThreatMap.at(tm, mx + reach - ThreatMap.CELL, mz), v, "inside its reach")
		t.equal(ThreatMap.at(tm, mx + reach + ThreatMap.PAD + ThreatMap.CELL * 1.5, mz), 0, "beyond it")
		t.equal((ThreatMap.strongestGroup(tm)), 0, "a turret is no army")
		-- three Ravagers by the turret, seen; one far off, not
		local rav = sim.defs.units.chs_ravager
		for i = 1, 3 do
			spawn(sim, "chs_ravager", 2, mx + brain.toward * 40, mz + (i - 2) * 20)
		end
		spawn(sim, "chs_ravager", 2, brain.enemyX, brain.enemyZ + 200)
		steps(sim, 10)
		tm = ThreatMap.build(sim, ally)
		local gv, gx, gz = ThreatMap.strongestGroup(tm)
		t.equal(gv, 3 * ThreatMap.value(rav), "the group seen")
		t.expect(math.abs(gx - mx) <= 2 * ThreatMap.CELL and math.abs(gz - mz) <= 2 * ThreatMap.CELL, "where it stands")
		t.expect(ThreatMap.at(tm, mx, mz) >= v + 3 * ThreatMap.value(rav), "their guns add to the turret's")
		t.equal(ThreatMap.of(sim, ally), ThreatMap.of(sim, ally), "built once a tick")
	end)

	t.test("a wave goes for a target it outweighs, skipping a stronger one (S-222)", function()
		local sim = start(52)
		local brain = Skirmish.new(sim, 1, "hard")
		local dx, dz = brain.enemyX - brain.homeX, brain.enemyZ - brain.homeZ
		-- a guarded solar array at a third of the way, a bare one at two thirds
		local ax, az = brain.homeX + dx / 3, brain.homeZ + dz / 3
		local bx, bz = brain.homeX + dx * 2 / 3, brain.homeZ + dz * 2 / 3
		spawn(sim, "chs_solar", 2, ax, az)
		spawn(sim, "chs_guard", 2, ax + 30, az)
		spawn(sim, "chs_guard", 2, ax - 30, az)
		spawn(sim, "chs_solar", 2, bx, bz)
		spawn(sim, "ord_lancer", 1, ax, az + 100)
		spawn(sim, "ord_lancer", 1, bx, bz + 100)
		steps(sim, 10)
		local tm = ThreatMap.build(sim, brain.ally)
		local guards = 2 * ThreatMap.value(sim.defs.units.chs_guard)
		t.expect(ThreatMap.at(tm, ax, az) >= guards, "the near one is guarded")
		t.equal(ThreatMap.at(tm, bx, bz), 0, "the far one isn't")
		local px, pz = Skirmish.pickTarget(brain, tm, guards / 2)
		t.expect(px and pz and (px - bx) ^ 2 + (pz - bz) ^ 2 < 50 ^ 2, "a weak wave goes for the bare one")
		px, pz = Skirmish.pickTarget(brain, tm, guards * 2)
		t.expect(px and pz and (px - ax) ^ 2 + (pz - az) ^ 2 < 50 ^ 2, "a strong one for the nearer")
	end)

	t.test("a wave gathers until it outweighs the strongest enemy group it saw (S-222)", function()
		local function trial(group: number): Skirmish.Brain
			local sim = start(53)
			local brain = Skirmish.new(sim, 1, "normal")
			local rx = brain.homeX + brain.toward * brain.rallyDist
			for i = 1, 8 do
				spawn(sim, "ord_lancer", 1, rx, brain.homeZ + (i - 4.5) * 14)
			end
			brain.enemyGroup, brain.enemyGroupAt = group, 0
			for _ = 1, Skirmish.WAVE_ALIGN + 30 do
				Skirmish.tick(brain)
				Sim.step(sim)
			end
			return brain
		end
		local free = trial(0)
		t.equal(free.waves, 1, "no known group: the wave leaves")
		local army = 8 * Skirmish.value(free.sim.defs.units.ord_lancer)
		t.equal(trial(army * 3).waves, 0, "a group three times its size: it gathers")
	end)

	t.test("a damaged unit pulls back to a Construction Turret, is repaired and rejoins (S-222)", function()
		local sim = start(54)
		local w = sim.world
		local brain = Skirmish.new(sim, 1, "normal")
		local nano = Spawn.unit(sim, "ord_nano", 1, brain.homeX - brain.toward * 40, brain.homeZ + 60, 0)
		local x = brain.homeX + brain.toward * 400
		local id = spawn(sim, "ord_lancer", 1, x, brain.homeZ)
		local max = sim.defs.units.ord_lancer.health
		World.setHealth(w, id, max * 0.3)
		brain.attacking[id] = true
		local pulled, healed = false, false
		for _ = 1, 120 * 15 do
			Skirmish.tick(brain)
			Sim.step(sim)
			pulled = pulled or brain.repairing[id] ~= nil
			if pulled and brain.repairing[id] == nil then
				healed = true
				break
			end
		end
		t.expect(w.slot[nano] ~= nil, "the turret stands")
		t.equal(brain.repairs, 1, "pulled back once")
		t.expect(pulled and healed, "repaired and back with the army")
		t.expect(w.health[id] >= max * Skirmish.REJOIN_HEALTH, `healed ({w.health[id]} of {max})`)
		t.equal(brain.attacking[id], nil, "not sent back into the old wave")
	end)
end
