--!strict
local Hash = require("@shared/Util/Hash")
local Layers = require("@shared/Grid/Layers")
local TestMap = require("@shared/Grid/TestMap")
local RunAll = require("./RunAll")

local function layerHash(layers: Layers.Layers): number
	return Hash.string(Hash.fnv1a(buffer.tostring(layers.height)), buffer.tostring(layers.waterDepth))
end

return function(t: RunAll.Context)
	t.test("layers quantize to 0.25 stud and clamp to i16", function()
		local layers = TestMap.build(2, 1, function()
			return 0
		end)
		Layers.setHeight(layers, 0, 10.1)
		t.equal(Layers.getHeight(layers, 0), 10)
		Layers.setHeight(layers, 0, 10.13)
		t.equal(Layers.getHeight(layers, 0), 10.25)
		Layers.setHeight(layers, 1, -3.5)
		t.equal(Layers.getHeight(layers, 1), -3.5)
		Layers.setHeight(layers, 1, 1e9)
		t.equal(Layers.getHeight(layers, 1), 32767 * 0.25)
		Layers.setWater(layers, 0, -5)
		t.equal(Layers.getWater(layers, 0), 0, "negative water depth becomes 0")
	end)

	t.test("build fills every cell from the callback", function()
		local layers = TestMap.build(4, 3, function(cx, cz)
			return cx + cz * 10, if cx == 0 then 2 else nil
		end)
		local g = layers.grid
		t.equal(Layers.getHeight(layers, g:index(3, 2)), 23)
		t.equal(Layers.getWater(layers, g:index(0, 1)), 2)
		t.equal(Layers.getWater(layers, g:index(1, 1)), 0)
	end)

	t.test("generate is deterministic per seed", function()
		local a = TestMap.generate({ seed = 42, cellsX = 64 })
		local b = TestMap.generate({ seed = 42, cellsX = 64 })
		local c = TestMap.generate({ seed = 43, cellsX = 64 })
		t.equal(layerHash(a), layerHash(b), "same seed, same layers")
		t.notEqual(layerHash(a), layerHash(c), "different seed, different layers")
	end)

	t.test("generated terrain stays in range with consistent water", function()
		local amplitude, seaLevel = 48, 16.8
		local layers = TestMap.generate({ seed = 7, cellsX = 128, cellsZ = 96, amplitude = amplitude, seaLevel = seaLevel })
		local g = layers.grid
		t.equal(g.cellsX, 128)
		t.equal(g.cellsZ, 96)
		local wet = 0
		for i = 0, g.cellCount - 1 do
			local h, w = Layers.getHeight(layers, i), Layers.getWater(layers, i)
			t.expect(h >= 0 and h <= amplitude, `height {h} out of range`)
			if w > 0 then
				wet += 1
				t.expect(h <= seaLevel, `water over land at {h}`)
				t.expect(math.abs(h + w - seaLevel) <= 0.25, `surface {h + w} is not at sea level`)
			else
				t.expect(h >= seaLevel - 0.25, `dry cell below sea level: {h}`)
			end
		end
		t.expect(wet > 0 and wet < g.cellCount, `map should have land and water, wet = {wet}`)
	end)

	t.test("full-size map generates", function()
		local layers = TestMap.generate({ seed = 1, cellsX = 256 })
		t.equal(layers.grid.cellCount, 65536)
		t.equal(buffer.len(layers.height), 65536 * 2)
	end)
end
