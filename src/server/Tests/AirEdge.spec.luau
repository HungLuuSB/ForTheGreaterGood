--!strict
-- The playtest's F3: jets turned back at a fixed 60 studs and overshot
-- the map's edge while turning, so clients drew them pinned to it (the
-- wire stopped at the edge). S-183 kept them over the map; since protocol
-- 38 (S-189) the wire carries them past it, so they turn back once over the
-- edge and swing out at most Air.OVERFLY.
local Air = require("../Sim/Air")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("jets fly past the edge, turn back and stay within Air.OVERFLY", function()
		for _, id in { "ord_falcon", "chs_harpy", "ord_liche", "ord_absolution" } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local g = (sim.map :: any).grid
			local half = g.sizeX / 2
			local jet = Spawn.unit(sim, id, 1, half - 150, 0, math.pi / 2) -- heading east, toward the edge
			local worst, back = -math.huge, false
			for _ = 1, 15 * 30 do
				Sim.step(sim)
				local out = math.max(math.abs(w.posX[jet]), math.abs(w.posZ[jet]))
				worst = math.max(worst, out)
				back = back or (worst > half and out < half - 50)
			end
			t.expect(worst > half, `{id}: flew past the edge ({worst} of {half})`)
			t.expect(worst <= half + Air.OVERFLY - 100, `{id}: within the overfly margin ({worst - half} studs out)`)
			t.expect(back, `{id}: and came back over the map`)
		end
	end)
end
