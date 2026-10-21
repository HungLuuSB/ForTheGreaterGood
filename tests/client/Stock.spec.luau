--!strict
-- SAM missile stockpiles on the client (protocol 15, S-47, C-56): an own
-- site's stock follows the server's shot by shot and refill by refill, its
-- bar stays up while it isn't full, and an enemy site's stock never reaches
-- the client.

local Bars = require("../../src/client/Core/Bars")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local ServerWorld = require("../../src/server/Sim/World")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

return function(t: any)
	t.test("own SAM stock follows the server; enemy stock stays unknown", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		local w = sim.world
		local mine = Spawn.unit(sim, "ord_vigil", 1, 0, 0, 0) -- Order's IR SAM site, ours
		local theirs = Spawn.unit(sim, "chs_thorn", 2, 0, 200, 0)
		for i = 0, 2 do
			local f = Spawn.unit(sim, "chs_harpy", 2, -60 + i * 60, -120, math.pi / 2) -- enemy jets over our site
			ServerWorld.setHealth(w, f, w.health[f] * 20)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local key = ServerWorld.slotKey(mine, 1)
		local capacity = sim.defs.unitByIndex[w.defIndex[mine]].weapons[1].stockCapacity :: number
		local lowest, mismatches, refills, barShownWhileLow, lowFrames = math.huge, 0, 0, 0, 0
		local last
		for tick = 1, 15 * 60 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local u = world.units[mine]
			local count, cap = World.stockOf(world, u)
			if count ~= w.wStock[key] then
				mismatches += 1
			end
			if count then
				lowest = math.min(lowest, count)
				if last and count > last then
					refills += 1
				end
				last = count
				if count < (cap :: number) then
					lowFrames += 1
					for _, b in Bars.list(world, {}) do
						if b.id == mine and b.stock == count and b.stockMax == cap then
							barShownWhileLow += 1
						end
					end
				end
			end
			local e = world.units[theirs]
			if e then
				t.expect(e.stock == nil, "an enemy site's stock never reaches us")
			end
		end
		print(string.format("    capacity %d: stock went down to %d, %d refills; %d ticks off the server's count", capacity, lowest, refills, mismatches))
		t.expect(lowest < capacity, "our site fired and spent missiles")
		t.expect(refills > 0, "and refilled")
		t.equal(mismatches, 0)
		t.equal(barShownWhileLow, lowFrames) -- a site that isn't full keeps its bar up
	end)
end
