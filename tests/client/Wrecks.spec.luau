--!strict
-- Wrecks from the wire (WRECK / WRECK_GONE, protocol 10, C-65): a wreck the
-- team sees appears in the client's world with its def and spot, also for a
-- player who joins after it was left, and goes when it is reclaimed. The
-- DEATH that left it marks it as placed by the death animation.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local Combat = require("../../src/server/Sim/Combat/Combat")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local CT = Schema.CmdType

local function reclaim(mason: number, wreck: number): buffer
	local w = Packer.Writer.new(64)
	Schema.encodeCommand(w, { cmdType = CT.RECLAIM, flags = 0, unitIds = { mason }, targetId = wreck })
	return w:finish()
end

return function(t: any)
	t.test("wrecks appear from WRECK and go when reclaimed", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local victim = Spawn.unit(sim, "chs_ravager", 2, 40, 0, 0)
		local mason = Spawn.unit(sim, "ord_mason", 1, -20, 0, 0) -- sees the victim's spot
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			end
		end
		step(3)
		sim.world.health[victim] = 1
		Combat.queueDamage(sim.combat, victim, 100, 0) -- low overkill: leaves a wreck
		step(4)
		local wreck = sim.combat.wreckIds[1]
		t.expect(wreck ~= nil, "the server left a wreck")
		local rec = world.wrecks[wreck]
		t.expect(rec ~= nil, "the client has it")
		if rec then
			t.equal(rec.defIndex, sim.defs.units.chs_ravager.index)
			t.expect(math.abs(rec.x - sim.combat.wreckX[wreck]) < 0.1 and math.abs(rec.z - sim.combat.wreckZ[wreck]) < 0.1, "at its spot")
		end
		t.expect(world.deathWrecks[wreck] ~= nil, "its DEATH marks it as the death animation's")
		t.expect(table.find(world.wreckAdded, wreck) ~= nil, "queued for the renderer")

		-- reclaimed: WRECK_GONE removes it
		assert(Sim.submit(sim, 1, reclaim(mason, wreck)))
		local gone = false
		for _ = 1, 600 do
			step(1)
			if world.wrecks[wreck] == nil then
				gone = true
				break
			end
		end
		t.expect(sim.combat.wreckX[wreck] == nil, "the server reclaimed it")
		t.expect(gone, "the client dropped it")
		t.expect(table.find(world.wreckGone, wreck) ~= nil, "queued for the renderer to remove")
	end)

	t.test("a client that joins after the death gets the wreck, with no DEATH of its own", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local victim = Spawn.unit(sim, "chs_ravager", 2, 40, 0, 0)
		Spawn.unit(sim, "ord_mason", 1, -20, 0, 0)
		for _ = 1, 3 do
			Sim.step(sim)
		end
		sim.world.health[victim] = 1
		Combat.queueDamage(sim.combat, victim, 100, 0)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		local wreck = sim.combat.wreckIds[1]
		t.expect(wreck ~= nil, "the server left a wreck before anyone joined")
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		for tick = 1, 4 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		end
		t.expect(world.wrecks[wreck] ~= nil, "the joining client has the wreck")
		t.expect(world.deathWrecks[wreck] == nil, "no DEATH of its own: the renderer places it from the record")
	end)
end
