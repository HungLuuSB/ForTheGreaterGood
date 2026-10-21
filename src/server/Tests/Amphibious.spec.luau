--!strict
-- Amphibious and hover details (guide 6.1, 12.3; S-39). "beach:96": land at
-- height 10 west of x = 0, sloping 1.5 studs per cell into the sea east of
-- it, 30 studs deep from x = 160 (water surface at 10).
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function move(sim: Sim.Sim, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, 1, wr:finish()))
end

return function(t: RunAll.Context)
	t.test("an amphibious tank submerges in deep water: hidden from eyes, guns quiet, back up on land", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "beach:96" })
		local w = sim.world
		local amphib = Spawn.unit(sim, "ord_tideguard", 1, -100, 0, math.pi / 2)
		World.setMoveState(w, amphib, World.MoveState.HOLD_POSITION)
		-- an enemy tank on the shore that watches the water (no sonar), within
		-- the amphibious tank's gun range of where it will stop
		local watcher = Spawn.unit(sim, "chs_ravager", 2, -60, 0, math.pi / 2)
		World.setFireState(w, watcher, World.FireState.HOLD_FIRE)
		World.setMoveState(w, watcher, World.MoveState.HOLD_POSITION)
		World.setHealth(w, watcher, 1e9)
		local SUB = World.State.SUBMERGED
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(bit32.band(w.state[amphib], SUB), 0, "on land it isn't submerged")
		t.equal(Sensors.level(sim, 2, amphib), Sensors.Level.VISIBLE, "and the enemy sees it")
		move(sim, { amphib }, 100, 0) -- into the sea: 18 studs deep there, 160 studs from the enemy
		local under = false
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			if bit32.band(w.state[amphib], SUB) ~= 0 and w.orderId[amphib] == 0 then
				under = true
				break
			end
		end
		t.expect(under, "in deep water it is submerged")
		Sim.step(sim)
		Sim.step(sim)
		t.equal(Sensors.level(sim, 2, amphib), Sensors.Level.HIDDEN, "the enemy without sonar loses it")
		-- its gun doesn't fire from under water, though the enemy is in range
		local range = sim.defs.unitByIndex[w.defIndex[amphib]].maxRange
		t.expect(math.abs(w.posX[amphib] - w.posX[watcher]) < range, `the enemy is in range ({w.posX[amphib] - w.posX[watcher]} of {range})`)
		local shots = 0
		for _ = 1, 90 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.unit == amphib and (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") then
					shots += 1
				end
			end
		end
		t.equal(shots, 0, "no shots while submerged")
		move(sim, { amphib }, -60, -40)
		local surfaced = false
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			if bit32.band(w.state[amphib], SUB) == 0 then
				surfaced = true
				break
			end
		end
		t.expect(surfaced, "back in the shallows it surfaces")
	end)

	t.test("a hover unit over water sits on the surface for aiming and hits", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "sea:128" })
		local w, c = sim.world, sim.combat
		local id = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local p = c.profiles[w.defIndex[id]]
		local _, groundY = Combat.aimPoint(c, w, id)
		t.expect(math.abs(groundY - (Combat.groundHeight(c, 0, 0) + p.height / 2)) < 1e-6, "a ground unit's aim point is on the sea floor")
		p.hover = true -- no hover unit in the roster yet: try the rule on this profile
		local _, hoverY = Combat.aimPoint(c, w, id)
		t.expect(math.abs(hoverY - (Combat.surfaceHeight(c, 0, 0) + p.height / 2)) < 1e-6, `a hover unit's is on the surface ({hoverY})`)
		local _, knownY = Combat.knownAimPoint(c, w, 0, nil, 0, 0)
		t.equal(knownY, Combat.groundHeight(c, 0, 0), "attack-ground still aims at the ground")
		p.hover = false
	end)
end
