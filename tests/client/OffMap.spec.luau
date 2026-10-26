--!strict
-- Missiles past the map's edge (C-46, S-33; S-189): since protocol 38 a
-- shot may fly up to Grid.OVERFLY past the edge, and the server bursts one
-- that reaches that margin there (an IMPACT on it), so a missile never flies
-- on further, and the client draws the burst where the server says.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")
local Grid = require("@shared/Grid/Grid")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("missiles that reach the overfly margin burst on it, drawn there", function()
		-- the old sam layout that made missiles overshoot the east edge
		local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
		local f = Spawn.unit(sim, "ord_falcon", 1, -540, 0, math.pi / 2)
		ServerWorld.setHealth(sim.world, f, sim.world.health[f] * 50)
		for i = 0, 1 do
			Spawn.unit(sim, "chs_thorn", 2, 340 + i * 160, -120, 0)
			Spawn.unit(sim, "chs_thorn", 2, 340 + i * 160, 120, 0)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.MOVE, { f }, 420, 0)))
		local fx = Effects.new()
		local half = g.sizeX / 2 + Grid.OVERFLY
		local seen: { [any]: boolean } = {}
		local edgeBursts, outBursts, farOut = 0, 0, 0
		for tick = 1, 15 * 60 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			for _, b in fx.bursts do
				if b.kind == "impact" and not seen[b] then
					seen[b] = true
					local m = math.max(math.abs(b.x), math.abs(b.z))
					if m > half + 0.5 then
						outBursts += 1
					elseif m > half - 0.5 then
						edgeBursts += 1
					end
				end
			end
			for _, p in fx.projectiles do
				local step = math.sqrt(p.vx * p.vx + p.vz * p.vz) * DT
				if math.max(math.abs(p.x), math.abs(p.z)) > half + step + 1 then
					farOut += 1 -- a drawn missile more than a tick past the edge
				end
			end
		end
		print(string.format("    explosions on the margin %d, past it %d; missile frames more than a tick past it %d", edgeBursts, outBursts, farOut))
		t.equal(outBursts, 0)
		t.equal(farOut, 0)
	end)
end
