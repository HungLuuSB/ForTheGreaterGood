--!strict
-- Builders walking to work (S-185, the playtest's F30: a builder drove into
-- range, on past it, then backed off before building). Now it brakes so it
-- stops just inside its reach, never reverses, and holds that spot.
local Orders = require("../Sim/Orders")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("a builder walks to its site, stops inside its reach without reversing, and builds", function()
		for _, who in { "ord_mason", "chs_scrapper", "ord_sovereign", "ord_artisan" } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local b = Spawn.unit(sim, who, 1, -200, 0, math.pi / 2)
			local gen = sim.defs.units[string.sub(who, 1, 4) .. "generator"]
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
