--!strict
local Grid = require("@shared/Grid/Grid")
local Prng = require("@shared/Util/Prng")
local RunAll = require("./RunAll")

local STEP = 1 / 4 -- one wire offset step: 64 studs / 256 (S-189)

return function(t: RunAll.Context)
	t.test("new validates sizes and centers the map on the origin", function()
		local g = Grid.new(128, 64)
		t.equal(g.cellCount, 128 * 64)
		t.equal(g.sizeX, 1024)
		t.equal(g.sizeZ, 512)
		t.equal(g.originX, -512)
		t.equal(g.originZ, -256)
		t.equal(g.sensorX, 64)
		t.equal(g.sensorZ, 32)
		t.equal(Grid.new(1024, 1024).sizeX, 8192, "1,024-cell maps (S-189)")
		t.equal(Grid.new(3, 3).sensorX, 2, "odd sizes round sensor cells up")
		for _, bad in { 0, 1025, 1.5, -4 } do
			t.throws(function()
				Grid.new(bad, 16)
			end, "integer in 1..1024")
		end
	end)

	t.test("index and coords round-trip", function()
		local g = Grid.new(256, 200)
		for _, c in { { 0, 0 }, { 255, 0 }, { 0, 199 }, { 255, 199 }, { 17, 93 } } do
			local i = g:index(c[1], c[2])
			local cx, cz = g:coords(i)
			t.deepEqual({ cx, cz }, c)
		end
		t.equal(g:index(255, 199), g.cellCount - 1)
		t.expect(g:inBounds(0, 0) and g:inBounds(255, 199), "corners in bounds")
		t.expect(not g:inBounds(-1, 0) and not g:inBounds(256, 0) and not g:inBounds(0, 200), "outside is out of bounds")
	end)

	t.test("cellAt follows cell boundaries", function()
		local g = Grid.new(16, 16) -- origin -64
		t.deepEqual({ g:cellAt(-64, -64) }, { 0, 0 })
		t.deepEqual({ g:cellAt(-56, -64) }, { 1, 0 }, "a cell edge belongs to the next cell")
		t.deepEqual({ g:cellAt(-56.001, -64) }, { 0, 0 })
		t.deepEqual({ g:cellAt(0, 0) }, { 8, 8 })
		t.deepEqual({ g:cellAt(63.99, 63.99) }, { 15, 15 })
		t.deepEqual({ g:cellAt(-65, 64) }, { -1, 16 }, "outside points give out-of-bounds cells")
		t.deepEqual({ g:cellCenter(0, 0) }, { -60, -60 })
	end)

	t.test("encode/decode round-trips within 1/8 stud, on and off the map (random, S-189)", function()
		local rng = Prng.new(5)
		for _, size in { { 1024, 1024 }, { 512, 512 }, { 128, 96 }, { 7, 13 } } do
			local g = Grid.new(size[1], size[2])
			for _ = 1, 5000 do
				-- the map and Grid.OVERFLY around it
				local x = rng:nextNumber(g.originX - Grid.OVERFLY, g.originX + g.sizeX + Grid.OVERFLY)
				local z = rng:nextNumber(g.originZ - Grid.OVERFLY, g.originZ + g.sizeZ + Grid.OVERFLY)
				local cell, offX, offZ = g:encode(x, z)
				t.expect(cell >= 0 and cell <= 65535, "wire cell fits u16")
				t.expect(offX >= 0 and offX <= 255 and offZ >= 0 and offZ <= 255, "offsets fit u8")
				local dx, dz = g:decode(cell, offX, offZ)
				t.expect(math.abs(x - dx) <= STEP / 2, `x error {x - dx} at {x}`)
				t.expect(math.abs(z - dz) <= STEP / 2, `z error {z - dz} at {z}`)
			end
		end
	end)

	t.test("the wire grid is the same for every map: 64-stud cells from -8192 (S-189)", function()
		local small, large = Grid.new(16, 16), Grid.new(1024, 1024)
		for _, p in { { 0, 0 }, { -100.25, 37.5 }, { 4000, -4000 } } do
			t.deepEqual({ small:encode(p[1], p[2]) }, { large:encode(p[1], p[2]) }, "map-independent")
		end
		t.deepEqual({ small:encode(-8192, -8192) }, { 0, 0, 0 }, "the wire's corner")
		t.deepEqual({ small:encode(0, 0) }, { 128 * 256 + 128, 0, 0 }, "the origin: wire cell (128, 128)")
		for _, off in { 0, 1, 128, 255 } do
			local x = 3 * 64 + off / 4 -- wire cell 131, offset off
			local cell, offX, offZ = small:encode(x, 0)
			t.deepEqual({ cell, offX, offZ }, { 128 * 256 + 131, off, 0 }, "exact on offset steps")
			t.equal((small:decode(cell, offX, offZ)), x)
		end
	end)

	t.test("positions past the wire's reach clamp to it; decodeOnMap clamps onto the map", function()
		local g = Grid.new(16, 16)
		t.deepEqual({ g:encode(-1e5, -1e5) }, { 0, 0, 0 })
		t.deepEqual({ g:encode(1e5, 1e5) }, { 65535, 255, 255 })
		local x, z = g:decode(65535, 255, 255)
		t.equal(x, Grid.WIRE_EXTENT - STEP)
		t.equal(z, Grid.WIRE_EXTENT - STEP)
		-- past the map's edge: decode keeps it, decodeOnMap moves it onto the map
		local cell, offX, offZ = g:encode(300, -200)
		t.deepEqual({ g:decode(cell, offX, offZ) }, { 300, -200 })
		t.deepEqual({ g:decodeOnMap(cell, offX, offZ) }, { 64 - 0.125, -64 })
	end)

	t.test("decode rejects malformed wire cells", function()
		local g = Grid.new(16, 16)
		t.throws(function()
			g:decode(65536, 0, 0)
		end, "outside 0..65535")
		t.throws(function()
			g:decode(-1, 0, 0)
		end, "outside")
	end)

	t.test("sensor cells are 16 studs and clamp to the map", function()
		local g = Grid.new(16, 16)
		t.deepEqual({ g:sensorCellAt(-64, -64) }, { 0, 0 })
		t.deepEqual({ g:sensorCellAt(-48.5, -47.5) }, { 0, 1 })
		t.deepEqual({ g:sensorCellAt(63.9, 0) }, { 7, 4 })
		t.deepEqual({ g:sensorCellAt(500, -500) }, { 7, 0 })
	end)
end
