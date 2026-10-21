--!strict
-- The next missile's build progress (protocol 17, S-49, C-59): an own
-- silo rebuilding a nuke shows the server's progress, grown between
-- records at the full rate and capped at the next sixteenth.

local Commands = require("../../src/client/Core/Commands")
local Bars = require("../../src/client/Core/Bars")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local SimWorld = require("../../src/server/Sim/World")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("a rebuilding silo's next pip follows the server's progress", function()
		local sim = Sim.new({ seed = 9, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:256", scenario = "empty" })
		-- the `nuke` profile's economy: a nuke rebuilds at the full rate
		for i = 0, 4 do
			Spawn.unit(sim, "ord_fusion", 1, -980, -640 + i * 48, 0)
		end
		for i = 0, 11 do
			Spawn.unit(sim, "ord_converter", 1, -840 + (i // 4) * 16, 380 + (i % 4) * 16, 0)
		end
		local silo = Spawn.unit(sim, "ord_reckoning", 1, -900, 0, 0)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.ATTACK_GROUND, { silo }, 500, 500)))
		local key = SimWorld.slotKey(silo, 1)
		local worst, frames, records, lastSent = 0, 0, 0, nil
		local barFrames = 0
		for tick = 1, 15 * 60 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			World.settle(world, tick)
			local u = world.units[silo]
			local server = sim.world.wStockProgress[key] or 0
			local shown = if u then World.stockProgressOf(world, u, tick) else nil
			if shown and server > 0 then
				frames += 1
				worst = math.max(worst, math.abs(shown - server))
				local p = (u :: any).stockProgress[1]
				if p[2] ~= lastSent then
					records += 1
					lastSent = p[2]
				end
				for _, b in Bars.list(world, {}) do
					if b.id == silo and b.stockProgress == shown then
						barFrames += 1
					end
				end
			end
		end
		print(string.format("    60 s of a nuke rebuild: %d frames, %d progress records, client vs server worst %.3f (a sixteenth is %.3f)", frames, records, worst, 1 / 16))
		t.expect(frames > 800, "the client saw the rebuild's progress")
		t.expect(worst < 0.01, `at the full rate it is the server's progress (worst {worst})`)
		t.equal(barFrames, frames) -- the silo's bar carries it
	end)
end
