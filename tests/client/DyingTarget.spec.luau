--!strict
-- A missile's target that dies (C-50): the DEATH record arrives ~2 ticks
-- before the render clock reaches the hit, so the client must keep the dying
-- unit as the missile's target until then. Before, the missile lost it
-- ("IR no lock"), flew straight past the jet, and only then the explosion
-- and the death played.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")

local DT = 1 / 15
local LAG = 2

return function(t: any)
	t.test("a missile keeps its dying target until its hit is drawn", function()
		local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		for i = 0, 3 do
			local f = Spawn.unit(sim, "ord_falcon", 1, -60, -60 + i * 40, math.pi / 2)
			ServerWorld.setHealth(sim.world, f, 20) -- one hit kills
			Spawn.unit(sim, "chs_thorn", 2, -100 + (i % 2) * 200, -100 + (i // 2) * 200, 0)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local fx = Effects.new()
		local killers: { [number]: boolean } = {} -- projectile IDs whose IMPACT killed a jet
		local lost, chased, kills = 0, 0, 0
		for tick = 1, 15 * 25 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "DEATH" then
					kills += 1
				end
			end
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" then
					killers[e.other] = nil -- a new projectile under a reused ID
				end
				if e.kind == "IMPACT" and e.unit ~= 0 and sim.world.health[e.unit] == nil then
					killers[e.other] = true
				end
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local rt = tick - LAG
			World.settle(world, rt)
			Effects.update(fx, world, rt, rt * DT, 0, 0)
			table.clear(world.died)
			for id, p in fx.projectiles do
				-- the killing missile, still drawn on its way in: the server has removed
				-- it (a projectile with its ID still alive there is a later, reused one)
				if p.weapon.type == "HOMING" and p.target ~= 0 and killers[id] and sim.combat.projSlot[id] == nil then
					chased += 1
					if World.unitOrDying(world, p.target) == nil then
						lost += 1 -- drawn as "no lock" while the server's missile is still on its way in
					end
				end
			end
		end
		print(string.format("    %d jets killed; %d frames of killing missiles chasing, %d with the target gone", kills, chased, lost))
		t.expect(kills >= 2 and chased > 0, "missiles killed jets")
		t.equal(lost, 0)
	end)
end
