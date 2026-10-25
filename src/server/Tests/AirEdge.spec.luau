--!strict
-- The playtest's F3 (S-183): jets turned back at a fixed 60 studs and
-- overshot the map's edge while turning, so clients drew them pinned to it.
-- Heading out, a jet now turns back a turn radius earlier and stays over
-- the map.
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("jets flying at the edge never leave the map", function()
		for _, id in { "ord_falcon", "chs_harpy", "ord_liche", "ord_absolution" } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local g = (sim.map :: any).grid
			local half = g.sizeX / 2
			local jet = Spawn.unit(sim, id, 1, half - 150, 0, math.pi / 2) -- heading east, toward the edge
			local worst = -math.huge
			for _ = 1, 15 * 30 do
				Sim.step(sim)
				worst = math.max(worst, math.abs(w.posX[jet]), math.abs(w.posZ[jet]))
			end
			t.expect(worst <= half, `{id}: stays over the map (at most {worst} of {half} studs out)`)
		end
	end)
end
