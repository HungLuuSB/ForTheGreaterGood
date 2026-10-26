--!strict
-- Deposits are 2 × 2 patches (S-184, the playtest's F6): every map's
-- deposits grow into patches that keep the map's symmetry; a T1 extractor
-- exactly on a patch earns its full value, half off it half; the advanced
-- extractor is the T1's size, on the same patch (the user).
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	t.test("every registry map: each deposit a whole 2 × 2 patch of one value, listed once, mirrored like the map", function()
		local names = {}
		for name in MapRegistry.HANDMADE do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local layers = MapRegistry.load("map:" .. name) :: Layers.Layers
			local g = layers.grid
			local cells = 0
			for i = 0, g.cellCount - 1 do
				if Layers.getSupply(layers, i) > 0 then
					cells += 1
				end
			end
			local deposits = layers.deposits :: { { number } }
			t.expect(#deposits > 0, `{name}: deposits`)
			local whole = 0
			for _, d in deposits do
				local x0, z0 = g:cellAt(d[1] - 4, d[2] - 4)
				local all = true
				for dz = 0, 1 do
					for dx = 0, 1 do
						all = all and Layers.getSupply(layers, g:index(x0 + dx, z0 + dz)) == d[3]
					end
				end
				whole += if all then 1 else 0
			end
			t.equal(whole, #deposits, `{name}: every patch whole`)
			t.equal(cells, 4 * #deposits, `{name}: no stray deposit cells`)
		end
	end)

	t.test("income: on the patch the full value, half off it half; the advanced extractor the T1's size", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64" })
		local layers = (sim.map :: any).layers :: Layers.Layers
		local d = (layers.deposits :: { { number } })[1]
		t.equal(PlacementRules.supplyUnder(layers, 2, d[1], d[2]), d[3], "exactly on it: its value")
		t.equal(PlacementRules.supplyUnder(layers, 2, d[1] + 8, d[2]), d[3] / 2, "a cell off: half")
		t.equal(PlacementRules.supplyUnder(layers, 4, d[1], d[2]), d[3], "a 4 × 4 centred on it: its value once")
		local px, pz = PlacementRules.depositNear(layers, d[1] + 5, d[2] - 3, 16)
		t.deepEqual({ px, pz }, { d[1], d[2] }, "depositNear snaps to the patch centre")
		local t1 = Spawn.unit(sim, "ord_extractor", 1, d[1], d[2])
		t.equal(sim.world.posX[t1], d[1], "the T1 sits on the patch centre")
		t.equal(sim.defs.units.ord_advextractor.footprint, 2, "the advanced extractor is the T1's size (the user)")
	end)
end
