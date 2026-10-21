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
					t.equal(Terrain.kind(layers, x, z, level), if Terrain.kind(layers, x, z, level) == "rock" then "rock" else "sand", "sea bed is sand (or rock where steep)")
				end
			end
		end
		t.expect(wet > 1000 and below == wet, `{wet} water cells, all with the ground under the surface`)
		t.equal(Terrain.waterLevel(assert(MapRegistry.load("map:ridgeline"))), nil, "a dry map has no water level")
	end)

	t.test("ground kinds: grass at the starts, rock on the ridges, sand on the shore", function()
		local layers = assert(MapRegistry.load("map:coastline"))
		local g = layers.grid
		local level = Terrain.waterLevel(layers)
		local counts = { grass = 0, rock = 0, sand = 0 }
		for cz = 0, g.cellsZ - 1 do
			for cx = 0, g.cellsX - 1 do
				local x, z = g:cellCenter(cx, cz)
				local k = Terrain.kind(layers, x, z, level)
				counts[k] += 1
			end
		end
		for _, s in layers.starts do
			t.equal(Terrain.kind(layers, s[1], s[2], level), "grass", "a start is on grass")
		end
		print(string.format("    coastline cells: %d grass, %d rock, %d sand", counts.grass, counts.rock, counts.sand))
		t.expect(counts.rock > 0 and counts.sand > 0 and counts.grass > counts.rock, "all three kinds, mostly grass")
	end)
end
