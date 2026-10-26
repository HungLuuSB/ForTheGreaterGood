--!strict
-- Line moves (S-188, F34): the units spread into their slots along the line,
-- then turn in place to face its front (across the line, away from where
-- the group came from), as BAR units do.
local Orders = require("../Sim/Orders")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	t.test("six tanks on a north–south line, coming from the west, end up facing east", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128" })
		local w = sim.world
		local ids = {}
		for i = 1, 6 do
			table.insert(ids, Spawn.unit(sim, "ord_lancer", 1, -200, (i - 3.5) * 14, 0)) -- heading north
		end
		Orders.give(sim, ids, { kind = "move", x = 0, z = -60, lx = 0, lz = 60 }, false)
		for _ = 1, 15 * 30 do
			Sim.step(sim)
		end
		for _, id in ids do
			t.expect(math.abs(w.posX[id]) < 12, `on the line ({w.posX[id]})`)
			local h = (w.heading[id] + math.pi) % (2 * math.pi) - math.pi
			t.expect(math.abs(h - math.pi / 2) < 0.05, `facing east ({math.deg(h)}°)`)
		end
		-- a plain move afterwards keeps its travel heading: no facing left over
		Orders.give(sim, { ids[1] }, { kind = "move", x = 0, z = 200 }, false)
		for _ = 1, 15 * 20 do
			Sim.step(sim)
		end
		local h = (w.heading[ids[1]] + math.pi) % (2 * math.pi) - math.pi
		t.expect(math.abs(h - math.pi / 2) > 0.2, "a plain move keeps its travel heading")
	end)
end
