--!strict
-- The drawn ground (C-28) on the procedural maps (S-15): exact at cell
-- centers, no jumps between cells, flat under deposits and at the starts,
-- water flat at the map's level, and ground kinds where they belong.

local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Terrain = require("../../src/client/Core/Terrain")

local MAPS = { "map:ridgeline", "map:coastline", "map:twin_lakes", "map:crossroads" }

return function(t: any)
	for _, id in MAPS do
		t.test(`{id}: the surface matches the layers and is continuous`, function()
			local layers = assert(MapRegistry.load(id))
			local g = layers.grid
			local worstCenter, worstSeam, worstDeposit = 0, 0, 0
			for cz = 0, g.cellsZ - 1 do
				for cx = 0, g.cellsX - 1 do
					local i = cz * g.cellsX + cx
					local x, z = g:cellCenter(cx, cz)
					local h = Layers.getHeight(layers, i)
					worstCenter = math.max(worstCenter, math.abs(Terrain.groundY(layers, x, z) - h))
					-- across the cell's east and north seams: no step
					local ex, nz = g.originX + (cx + 1) * 8, g.originZ + (cz + 1) * 8
					worstSeam = math.max(worstSeam, math.abs(Terrain.groundY(layers, ex - 1e-6, z) - Terrain.groundY(layers, ex + 1e-6, z)))
					worstSeam = math.max(worstSeam, math.abs(Terrain.groundY(layers, x, nz - 1e-6) - Terrain.groundY(layers, x, nz + 1e-6)))
					if Layers.getSupply(layers, i) > 0 then
						-- the deposit plate (Render/Ground) floats DEPOSIT_LIFT above the
						-- cell's height: the drawn ground must stay under it
						for _, o in { { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 }, { 0, 0 } } do
							worstDeposit = math.max(worstDeposit, math.abs(Terrain.groundY(layers, x + o[1], z + o[2]) - h))
						end
					end
				end
			end
			t.expect(worstCenter < 1e-9, `exact at cell centers (worst {worstCenter})`)
			t.expect(worstSeam < 1e-3, `no step between cells (worst {worstSeam})`)
			t.expect(worstDeposit < Terrain.DEPOSIT_LIFT, `within {Terrain.DEPOSIT_LIFT} stud of flat under every deposit (worst {worstDeposit})`)
			for _, s in layers.starts do
				local cx, cz = g:cellAt(s[1], s[2])
				local h = Layers.getHeight(layers, cz * g.cellsX + cx)
				for _, o in { { -24, 0 }, { 24, 0 }, { 0, -24 }, { 0, 24 } } do
					t.expect(math.abs(Terrain.groundY(layers, s[1] + o[1], s[2] + o[2]) - h) < 1e-9, "flat around the start")
				end
			end
		end)
	end

	t.test("water is flat at the map's level and floating things sit on it", function()
		local layers = assert(MapRegistry.load("map:coastline"))
		local g = layers.grid
		local level = Terrain.waterLevel(layers)
		t.expect(level ~= nil, "the coastline map has a sea")
		local wet, below = 0, 0
		for cz = 0, g.cellsZ - 1 do
			for cx = 0, g.cellsX - 1 do
				local x, z = g:cellCenter(cx, cz)
				local w = Terrain.waterY(layers, x, z)
				if w then
					wet += 1
					t.expect(w == level, "one water level")
					t.expect(Terrain.surfaceY(layers, x, z) == level, "floats on the water")
					if Terrain.groundY(layers, x, z) < level then
						below += 1
					end
				end
			end
		end
		t.expect(wet > 1000 and below == wet, `{wet} water cells, all with the ground under the surface`)
		t.equal(Terrain.waterLevel(assert(MapRegistry.load("map:ridgeline"))), nil, "a dry map has no water level")
	end)

	t.test("ground kinds are the sim's terrain types; Normandy's features give its materials (C-66)", function()
		local Layers = require("@shared/Grid/Layers")
		local Normandy = require("@shared/Grid/Normandy")
		local layers = assert(MapRegistry.load("map:normandy"))
		local g = layers.grid
		local names = { [Layers.Terrain.GRASS] = "grass", [Layers.Terrain.ROCK] = "rock", [Layers.Terrain.SAND] = "sand", [Layers.Terrain.ROAD] = "road" }
		local counts: { [string]: number } = {}
		local mats: { [string]: { [string]: boolean } } = {}
		local wrong = 0
		for cz = 0, g.cellsZ - 1 do
			for cx = 0, g.cellsX - 1 do
				local x, z = g:cellCenter(cx, cz)
				local k = Terrain.kind(layers, x, z)
				if k ~= names[Layers.getTerrain(layers, g:index(cx, cz))] then
					wrong += 1
				end
				counts[k] = (counts[k] or 0) + 1
				local f = Normandy.feature(cx, cz)
				mats[f] = mats[f] or {}
				mats[f][Terrain.material(layers, x, z, Normandy.feature)] = true
			end
		end
		print(string.format("    normandy cells: %d grass, %d rock, %d sand, %d road", counts.grass or 0, counts.rock or 0, counts.sand or 0, counts.road or 0))
		t.equal(wrong, 0)
		t.expect((counts.road or 0) > 0 and (counts.sand or 0) > 0 and (counts.rock or 0) > 0, "all four types on Normandy")
		t.expect(mats.hedge and mats.hedge.leafy, "hedgerows are leafy")
		t.expect(mats.road and mats.road.road, "roads are road")
		t.expect(mats.bridge and mats.bridge.bridge, "bridges are planks")
		t.expect(mats.beach and mats.beach.sand, "the beach is sand")
		t.expect(mats.house and mats.house.ground, "house cells are ground under their parts")
		-- without features the material is the terrain type
		local x, z = g:cellCenter(10, 10)
		t.equal(Terrain.material(layers, x, z), Terrain.kind(layers, x, z))
	end)
end
