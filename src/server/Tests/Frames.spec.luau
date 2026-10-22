--!strict
-- Units under construction (S-87, the user): a frame does nothing until it
-- is complete (no aiming, targeting or firing; sensors, factories, economy
-- and shields already waited), and destroyed it leaves no wreck and sets off
-- no death blast.
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Combat = require("../Sim/Combat/Combat")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

-- Shots the unit fired over `ticks` (projectiles and hitscan).
local function shots(sim: Sim.Sim, id: number, ticks: number): number
	local n = 0
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") and e.unit == id then
				n += 1
			end
		end
	end
	return n
end

-- Kills `id` with one queued blow and steps once; returns its DEATH event and
-- whether a BLAST followed.
local function kill(sim: Sim.Sim, id: number): (any, boolean)
	Combat.queueDamage(sim.combat, id, 1e6, 0)
	Sim.step(sim)
	local death, blast = nil, false
	for _, e in sim.combat.events do
		if e.kind == "DEATH" and e.unit == id then
			death = e
		elseif e.kind == "BLAST" and e.unit == id then
			blast = true
		end
	end
	return death, blast
end

return function(t: RunAll.Context)
	t.test("a half-built turret neither aims nor fires; complete, it does", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local turret = Spawn.unit(sim, "ord_bulwark", 1, 0, 0)
		World.setBuildProgress(w, turret, 0.5)
		local tank = Spawn.unit(sim, "chs_ravager", 2, 0, 80, math.pi)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setHealth(w, tank, 1e6)
		t.equal(shots(sim, turret, 150), 0, "no shot in 10 s from a frame")
		t.equal(w.wTarget[World.slotKey(turret, 1)], 0, "no target")
		World.setBuildProgress(w, turret, 1)
		t.expect(shots(sim, turret, 150) > 0, "complete, it fires at the tank")
	end)

	t.test("a destroyed frame leaves no wreck; a complete unit does", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local frame = Spawn.unit(sim, "ord_bulwark", 1, 0, 0)
		World.setBuildProgress(w, frame, 0.6)
		local whole = Spawn.unit(sim, "ord_bulwark", 1, 60, 0)
		-- killed with little overkill: a complete unit would leave a wreck
		World.setHealth(w, frame, 10)
		World.setHealth(w, whole, 10)
		Combat.queueDamage(sim.combat, frame, 20, 0)
		Combat.queueDamage(sim.combat, whole, 20, 0)
		Sim.step(sim)
		local wrecks: { [number]: number } = {}
		for _, e in sim.combat.events do
			if e.kind == "DEATH" then
				wrecks[e.unit] = e.other
			end
		end
		t.equal(wrecks[frame], 0, "the frame: gone, no wreck")
		t.expect((wrecks[whole] or 0) ~= 0, "the complete turret: a wreck")
	end)

	t.test("a destroyed reactor frame sets off no death blast; a complete reactor does", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local frame = Spawn.unit(sim, "ord_fusion", 1, 0, 0)
		World.setBuildProgress(w, frame, 0.9)
		local _, blast = kill(sim, frame)
		t.equal(blast, false, "no blast from a frame")
		local reactor = Spawn.unit(sim, "ord_fusion", 1, 0, 0)
		local _, blast2 = kill(sim, reactor)
		t.equal(blast2, true, "a complete reactor blows")
	end)
end
