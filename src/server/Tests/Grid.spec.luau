--!strict
local Grid = require("@shared/Grid/Grid")
local Prng = require("@shared/Util/Prng")
local RunAll = require("./RunAll")

local PRECISION = 1 / 32 -- one offset step: 8 studs / 256

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
		t.equal(Grid.new(256, 256).cellCount - 1, 65535, "largest cell index fits u16")
		t.equal(Grid.new(3, 3).sensorX, 2, "odd sizes round sensor cells up")
		for _, bad in { 0, 257, 1.5, -4 } do
			t.throws(function()
				Grid.new(bad, 16)
			end, "integer in 1..256")
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

	t.test("encode/decode round-trips within 1/32 stud (random)", function()
		local rng = Prng.new(5)
		for _, size in { { 256, 256 }, { 128, 96 }, { 7, 13 } } do
			local g = Grid.new(size[1], size[2])
			for _ = 1, 5000 do
				local x = rng:nextNumber(g.originX, g.originX + g.sizeX)
				local z = rng:nextNumber(g.originZ, g.originZ + g.sizeZ)
				local cell, offX, offZ = g:encode(x, z)
				t.expect(cell >= 0 and cell < g.cellCount, "cell in range")
				t.expect(offX >= 0 and offX <= 255 and offZ >= 0 and offZ <= 255, "offsets fit u8")
				local dx, dz = g:decode(cell, offX, offZ)
				t.expect(x - dx >= 0 and x - dx < PRECISION, `x error {x - dx} at {x}`)
				t.expect(z - dz >= 0 and z - dz < PRECISION, `z error {z - dz} at {z}`)
				local cx, cz = g:cellAt(x, z)
				t.equal(cell, g:index(cx, cz), "encoded cell matches cellAt")
			end
		end
	end)

	t.test("encode is exact on offset steps", function()
		local g = Grid.new(16, 16)
		for _, off in { 0, 1, 128, 255 } do
			local x = g.originX + 3 * 8 + off / 32
			local cell, offX, offZ = g:encode(x, g.originZ)
			t.deepEqual({ cell, offX, offZ }, { g:index(3, 0), off, 0 })
			local dx = g:decode(cell, offX, offZ)
			t.equal(dx, x)
		end
	end)

	t.test("positions outside the map clamp to its edge", function()
		local g = Grid.new(16, 16)
		t.deepEqual({ g:encode(-1000, -1000) }, { 0, 0, 0 })
		t.deepEqual({ g:encode(1000, 1000) }, { g.cellCount - 1, 255, 255 })
		-- The far edge itself is outside the last cell: it clamps 1/32 stud inside.
		local cell, offX, offZ = g:encode(64, 64)
		local x, z = g:decode(cell, offX, offZ)
		t.equal(64 - x, PRECISION)
		t.equal(64 - z, PRECISION)
	end)

	t.test("decode rejects cells outside the map", function()
		local g = Grid.new(16, 16)
		t.throws(function()
			g:decode(256, 0, 0)
		end, "outside a 16x16 map")
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
