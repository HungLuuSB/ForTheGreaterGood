--!strict
-- A hidden shooter's gun shot (protocol 14, S-43, C-54): the client gets a
-- SHOT with both ends and no shooter, and draws a tracer from the start point
-- to the end point, with no muzzle flash and without learning the shooter.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local Combat = require("../../src/server/Sim/Combat/Combat")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")

local DT = 1 / 15

return function(t: any)
	t.test("a hidden gunner's shot is drawn from its start point, the gunner stays unknown", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64" })
		local w, c = sim.world, sim.combat
		local victim = Spawn.unit(sim, "ord_lancer", 1, -100, 0, 0)
		local gunner = Spawn.unit(sim, "chs_jackal", 2, 200, 150, 0) -- far outside Order's sight
		for _, id in { victim, gunner } do
			ServerWorld.setFireState(w, id, ServerWorld.FireState.HOLD_FIRE)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 63, 63)))
		for tick = 1, 4 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		end
		-- the gunner's shot, as Weapons records it
		Combat.addEvent(c, { kind = "FIRE", tick = sim.tick, unit = gunner, other = victim, slot = 1, hit = true, x = -100, y = 13, z = 0, sx = 200, sy = 14, sz = 150 })
		NetOut.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, 5 * DT)
		local fx = Effects.new()
		Effects.update(fx, world, sim.tick, 5 * DT, 0, 0)
		t.expect(world.units[gunner] == nil, "the client doesn't know the gunner")
		t.equal(#fx.tracers, 1)
		local tr = fx.tracers[1]
		if tr then
			t.expect(math.abs(tr.x0 - 200) < 0.1 and math.abs(tr.z0 - 150) < 0.1 and math.abs(tr.y0 - 14) < 0.1, "from the start point")
			t.expect(math.abs(tr.x1 + 100) < 0.1 and math.abs(tr.z1) < 0.1, "to the end point")
			t.equal(tr.hit, true)
		end
		local flashes = 0
		for _, b in fx.bursts do
			if b.kind == "muzzle" then
				flashes += 1
			end
		end
		t.equal(flashes, 0) -- no muzzle flash where a hidden gunner stands
		t.equal(fx.applied.SHOT, 1)
	end)
end
