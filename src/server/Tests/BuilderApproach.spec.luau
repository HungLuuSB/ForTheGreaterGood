--!strict
-- Builders walking to work (S-185, the playtest's F30: a builder drove into
-- range, on past it, then backed off before building). Now it brakes so it
-- stops just inside its reach, never reverses, and holds that spot.
local Build = require("../Sim/Build")
local Orders = require("../Sim/Orders")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("the nano-spray target goes on the wire only once the builder is in reach (S-208, H1)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local b = Spawn.unit(sim, "ord_mason", 1, -300, 0, math.pi / 2)
		local frame = Spawn.unit(sim, "ord_solar", 1, 0, 0)
		World.setBuildProgress(w, frame, 0.2)
		Orders.give(sim, { b }, { kind = "repair", target = frame, gen = w.gen[frame] }, false)
		local early, reached = 0, nil
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			if (sim.build.target[b] or 0) ~= 0 and not Build.inReach(sim, b) then
				early += 1 -- assigned, still walking
			elseif Build.inReach(sim, b) and reached == nil then
				reached = math.sqrt(w.posX[b] ^ 2 + w.posZ[b] ^ 2)
			end
		end
		t.expect(early > 0, `the job is assigned while it walks ({early} ticks), but not in reach`)
		t.expect(reached ~= nil and (reached :: number) <= (sim.defs.units.ord_mason.buildRange :: number) + 8 + 1e-6, `in reach at {reached}`)
	end)

	t.test("a builder walks to its site, stops inside its reach without reversing, and builds", function()
		for _, who in { "ord_mason", "chs_scrapper", "ord_sovereign", "ord_artisan" } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local b = Spawn.unit(sim, who, 1, -200, 0, math.pi / 2)
			local gen = sim.defs.units[string.sub(who, 1, 4) .. "solar"] -- (the generator until S-203)
			Orders.give(sim, { b }, { kind = "build", x = 0, z = 0, defIndex = gen.index, facing = 0 }, false)
			local last, reversed, started = math.huge, 0, nil
			for _ = 1, 15 * 20 do
				local acc = sim.eco.accounts[1]
				acc.supply.stored, acc.power.stored = acc.supply.storage, acc.power.storage
				Sim.step(sim)
				local d = math.sqrt(w.posX[b] ^ 2 + w.posZ[b] ^ 2)
				if d > last + 0.05 then
					reversed += 1
				end
				last = d
				if started == nil and (sim.build.target[b] or 0) ~= 0 then
					started = d
				end
			end
			local reach = (sim.defs.units[who].buildRange :: number) + gen.footprint * 4
			t.equal(reversed, 0, `{who} never backs off`)
			t.expect(started ~= nil and (started :: number) <= reach and (started :: number) >= reach - 12, `{who} builds from just inside its reach ({started} of {reach})`)
		end
	end)
end
