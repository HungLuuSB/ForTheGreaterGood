--!strict
-- Missiles past the map's edge (C-46): positions on the wire are clamped to
-- the map, so a correction for a missile that overshot the edge says "at
-- the edge". The client keeps its own prediction on that axis instead of
-- pulling the missile back.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("a missile past the map's edge stays where the server has it, not on the edge", function()
		-- the sam scene before its fix: the Falcon circles past the east edge
		local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
		local f = Spawn.unit(sim, "ord_falcon", 1, -540, 0, math.pi / 2)
		ServerWorld.setHealth(sim.world, f, sim.world.health[f] * 50)
		for i = 0, 1 do
			Spawn.unit(sim, "chs_thorn", 2, 340 + i * 160, -120, 0)
			Spawn.unit(sim, "chs_thorn", 2, 340 + i * 160, 120, 0)
		end
		for _, x in { -450, 450 } do
			for _, z in { -450, 450 } do
				Spawn.unit(sim, "ord_beacon", 1, x, z, 0) -- the sam scene's radars
			end
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.MOVE, { f }, 420, 0)))
		local fx = Effects.new()
		local half = g.sizeX / 2
		local outside, worstOut, onEdge, inside, worstIn = 0, 0, 0, 0, 0
		local seenBursts, edgeBursts, outBursts = {}, 0, 0
		for tick = 1, 15 * 60 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			for _, b in fx.bursts do
				if b.kind == "impact" and not seenBursts[b] then
					seenBursts[b] = true
					local m = math.max(math.abs(b.x), math.abs(b.z))
					if math.abs(m - half) < 0.1 then
						edgeBursts += 1
					elseif m > half then
						outBursts += 1
					end
				end
			end
			local c = sim.combat
			for id, p in fx.projectiles do
				if p.weapon.type == "HOMING" and c.projSlot[id] then
					local sx, sz = c.px[id], c.pz[id]
					local gap = math.sqrt((p.x - sx) ^ 2 + (p.z - sz) ^ 2)
					if math.max(math.abs(sx), math.abs(sz)) > half + 2 then
						outside += 1
						worstOut = math.max(worstOut, gap)
						if math.abs(math.abs(p.x) - half) < 0.1 or math.abs(math.abs(p.z) - half) < 0.1 then
							onEdge += 1
						end
					else
						inside += 1
						worstIn = math.max(worstIn, gap)
					end
				end
			end
		end
		print(string.format("    %d missile ticks past the edge (worst %.2f studs from the server, %d drawn on the edge), %d inside (worst %.2f); explosions past the edge %d, on it %d", outside, worstOut, onEdge, inside, worstIn, outBursts, edgeBursts))
		t.expect(outBursts > 0 and edgeBursts == 0, "missiles that end past the edge explode there, not on the edge")
		t.expect(outside > 20, "missiles flew past the edge")
		t.expect(onEdge == 0, "none was pulled back onto the edge")
		t.expect(worstOut < 2, `past the edge the client stays with the server ({worstOut} studs)`)
	end)

	t.test("unclamp keeps only an axis that sits on the clamp with the prediction beyond it", function()
		local world = World.new((Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:16", scenario = "empty" })).defs)
		local g = world.grid
		local edge = g.originX + g.sizeX - 8 / 256
		local p = { x = edge + 30, z = 5 } :: any
		local x, z = Effects.unclamp(world, p, edge, 5)
		t.equal(x, edge + 30)
		t.equal(z, 5)
		-- inside the map, or the prediction on the map side: the record wins
		p.x = edge - 3
		x = Effects.unclamp(world, p, edge, 5)
		t.equal(x, edge)
		p.x, p.z = 0, g.originZ - 12
		x, z = Effects.unclamp(world, p, 10, g.originZ)
		t.equal(x, 10)
		t.equal(z, g.originZ - 12)
	end)
end
