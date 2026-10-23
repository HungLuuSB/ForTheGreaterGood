--!strict
local Layers = require("@shared/Grid/Layers")
local MoveClasses = require("@shared/Defs/MoveClasses")
local Passability = require("@shared/Grid/Passability")
local TestMap = require("@shared/Grid/TestMap")
local RunAll = require("./RunAll")

local CLASSES = { "WHEELED", "TRACKED", "HEAVY_TRACKED", "HOVER", "AMPHIB", "SHIP", "SUB", "HELI", "JET" }

-- Land at height 10 everywhere; `water(cx, cz)` gives depths (0 = dry).
local function flatWith(cellsX: number, cellsZ: number, water: (number, number) -> number): Passability.PassMap
	return Passability.build(TestMap.build(cellsX, cellsZ, function(cx, cz)
		return 10, water(cx, cz)
	end))
end

local function enterable(pm: Passability.PassMap, index: number): { [string]: boolean }
	local out = {}
	for _, mc in CLASSES do
		out[mc] = Passability.canEnter(pm, mc, index)
	end
	return out
end

return function(t: RunAll.Context)
	t.test("move class bits are unique and fit a u16", function()
		local seen = {}
		for _, mc in CLASSES do
			local b = MoveClasses[mc].bit
			t.expect(b >= 0 and b < 16 and not seen[b], `bad bit for {mc}`)
			seen[b] = true
		end
		t.equal(#Passability.CLASS_ORDER, #CLASSES)
	end)

	t.test("required clearance by footprint", function()
		t.equal(Passability.requiredClearance(1), 1)
		t.equal(Passability.requiredClearance(2), 2)
		t.equal(Passability.requiredClearance(3), 2)
		t.equal(Passability.requiredClearance(4), 3)
	end)

	t.test("slope is the steepest climb to a 4-neighbor", function()
		-- Heights 0, 8, 8, 8: 45° between cells 0 and 1, flat after.
		local pm = Passability.build(TestMap.build(4, 1, function(cx)
			return if cx == 0 then 0 else 8
		end))
		t.equal(buffer.readu8(pm.slope, 0), 128) -- round(45 * 255 / 90)
		t.equal(buffer.readu8(pm.slope, 1), 128)
		t.equal(buffer.readu8(pm.slope, 2), 0)
		t.equal(buffer.readu8(pm.slope, 3), 0)
		t.expect(math.abs(Passability.slopeDegrees(pm, 0) - 45) < 0.2, "u8 → degrees")
	end)

	t.test("water depth decides ships, subs and fording", function()
		-- One row of cells with depths 0, 1, 2, 3, 6, 11.75, 12, 20.
		local depths = { 0, 1, 2, 3, 6, 11.75, 12, 20 }
		local pm = flatWith(#depths, 1, function(cx)
			return depths[cx + 1]
		end)
		local expected = {
			-- depth: WHEELED TRACKED HEAVY HOVER AMPHIB SHIP SUB HELI JET
			{ true, true, true, true, true, false, false, true, true }, -- 0
			{ true, true, true, true, true, false, false, true, true }, -- 1 (ford ≤ 1)
			{ false, true, true, true, true, false, false, true, true }, -- 2 (ford ≤ 2)
			{ false, false, false, true, true, false, false, true, true }, -- 3
			{ false, false, false, true, true, true, false, true, true }, -- 6 (ship ≥ 6)
			{ false, false, false, true, true, true, false, true, true }, -- 11.75
			{ false, false, false, true, true, true, true, true, true }, -- 12 (sub ≥ 12)
			{ false, false, false, true, true, true, true, true, true }, -- 20
		}
		for i, row in expected do
			local want = {}
			for j, mc in CLASSES do
				want[mc] = row[j]
			end
			t.deepEqual(enterable(pm, i - 1), want, `depth {depths[i]}`)
		end
	end)

	t.test("steep slopes block by move class (HEAVY_TRACKED at 26.5°)", function()
		-- A ramp rising 4 studs per 8-stud cell: atan(0.5) = 26.57°.
		local pm = Passability.build(TestMap.build(6, 1, function(cx)
			return cx * 4
		end))
		local i = 2
		t.expect(math.abs(Passability.slopeDegrees(pm, i) - 26.5) < 0.3, "ramp slope")
		t.expect(not Passability.canEnter(pm, "WHEELED", i), "WHEELED max 20°")
		t.expect(not Passability.canEnter(pm, "HEAVY_TRACKED", i), "HEAVY_TRACKED max 25°")
		t.expect(not Passability.canEnter(pm, "HOVER", i), "HOVER max 18° on land")
		t.expect(Passability.canEnter(pm, "TRACKED", i), "TRACKED max 30°")
		t.expect(Passability.canEnter(pm, "AMPHIB", i), "AMPHIB max 30°")
		t.expect(Passability.canEnter(pm, "HELI", i), "air ignores slope")

		-- A 2-stud step per cell (14°) is fine for every land class.
		local gentle = Passability.build(TestMap.build(6, 1, function(cx)
			return cx * 2
		end))
		for _, mc in { "WHEELED", "TRACKED", "HEAVY_TRACKED", "HOVER", "AMPHIB" } do
			t.expect(Passability.canEnter(gentle, mc, 2), `{mc} on a 14° slope`)
		end
	end)

	t.test("clearance is the Chebyshev distance to blocked cells and the edge", function()
		-- 9 × 7 flat land with a single deep-water cell at (3, 3).
		local pm = flatWith(9, 7, function(cx, cz)
			return if cx == 3 and cz == 3 then 10 else 0
		end)
		local g = pm.grid
		for cz = 0, 6 do
			for cx = 0, 8 do
				local toPond = math.max(math.abs(cx - 3), math.abs(cz - 3))
				local toEdge = math.min(cx + 1, cz + 1, 9 - cx, 7 - cz)
				local want = math.min(toPond, toEdge)
				t.equal(Passability.clearance(pm, "TRACKED", g:index(cx, cz)), want, `TRACKED at ({cx}, {cz})`)
			end
		end
		-- For ships the pond is the only passable cell; it touches land on all sides.
		t.equal(Passability.clearance(pm, "SHIP", g:index(3, 3)), 1)
		t.equal(Passability.clearance(pm, "SHIP", g:index(0, 0)), 0)
	end)

	t.test("footprint-2 units are rejected in 1-cell gaps", function()
		-- 11 × 9 land split by a water wall at cx = 5, with a 1-cell gap at
		-- cz = 2 and a 3-cell gap at cz = 5..7.
		local pm = flatWith(11, 9, function(cx, cz)
			if cx ~= 5 then
				return 0
			end
			if cz == 2 or (cz >= 5 and cz <= 7) then
				return 0
			end
			return 10
		end)
		local g = pm.grid
		local narrow = g:index(5, 2)
		t.expect(Passability.fits(pm, "TRACKED", 1, narrow), "footprint 1 fits the 1-cell gap")
		t.expect(not Passability.fits(pm, "TRACKED", 2, narrow), "footprint 2 must not fit the 1-cell gap")
		local wide = g:index(5, 6)
		t.expect(Passability.fits(pm, "TRACKED", 2, wide), "footprint 2 fits the middle of the 3-cell gap")
		t.expect(Passability.fits(pm, "TRACKED", 3, wide), "footprint 3 fits the middle of the 3-cell gap")
		t.expect(not Passability.fits(pm, "TRACKED", 4, wide), "footprint 4 is too big")
		t.expect(not Passability.fits(pm, "TRACKED", 1, g:index(5, 0)), "the wall itself is blocked")
	end)

	t.test("generated map layers obey the move class rules", function()
		local layers = TestMap.generate({ seed = 11, cellsX = 96 })
		local pm = Passability.build(layers)
		local g = pm.grid
		local shipCells, landCells = 0, 0
		for i = 0, g.cellCount - 1 do
			local water = Layers.getWater(layers, i)
			local slope = Passability.slopeDegrees(pm, i)
			local ship = Passability.canEnter(pm, "SHIP", i)
			t.equal(ship, water >= 6, `SHIP at cell {i}`)
			t.equal(Passability.canEnter(pm, "SUB", i), water >= 12, `SUB at cell {i}`)
			if Passability.canEnter(pm, "HEAVY_TRACKED", i) then
				t.expect(water <= 2 and slope <= 25.2, `HEAVY_TRACKED on water {water}, slope {slope}`)
				landCells += 1
			end
			if ship then
				shipCells += 1
			end
			for _, mc in CLASSES do
				local c = Passability.clearance(pm, mc, i)
				t.equal(c == 0, not Passability.canEnter(pm, mc, i), `{mc} clearance 0 iff blocked`)
			end
		end
		t.expect(shipCells > 0 and landCells > 0, "test map should have both sea and land")
	end)

	t.test("occupying a block updates clearance exactly like a full recompute (S-144)", function()
		local Prng = require("@shared/Util/Prng")
		local layers = TestMap.generate({ seed = 7, cellsX = 96 })
		local pm = Passability.build(layers)
		local g = pm.grid
		local rng = Prng.new(3)
		for n = 1, 40 do
			local size = rng:nextInteger(1, 4)
			-- some blocks hang over the map's edge
			local x0, z0 = rng:nextInteger(-2, g.cellsX - 2), rng:nextInteger(-2, g.cellsZ - 2)
			Passability.setOccupied(pm, x0, z0, size, n)
		end
		local fast: { [string]: string } = {}
		for _, mc in CLASSES do
			fast[mc] = buffer.tostring(pm.clearance[mc])
		end
		Passability.recomputeClearance(pm) -- the full, exact recompute
		for _, mc in CLASSES do
			t.expect(buffer.tostring(pm.clearance[mc]) == fast[mc], `{mc} clearance equals the full recompute after placing`)
		end
		-- and removing half of them again (the transform path, skipping unchanged classes)
		for n = 1, 40, 2 do
			for i = 0, g.cellCount - 1 do
				if Passability.occupant(pm, i) == n then
					local x, z = i % g.cellsX, i // g.cellsX
					Passability.clearOccupied(pm, x, z, 1, n)
				end
			end
		end
		for _, mc in CLASSES do
			fast[mc] = buffer.tostring(pm.clearance[mc])
		end
		Passability.recomputeClearance(pm)
		for _, mc in CLASSES do
			t.expect(buffer.tostring(pm.clearance[mc]) == fast[mc], `{mc} clearance equals the full recompute after removing`)
		end
	end)

	t.test("clearance changes by at most 1 between neighbors", function()
		local pm = Passability.build(TestMap.generate({ seed = 3, cellsX = 64 }))
		local g = pm.grid
		for cz = 0, g.cellsZ - 1 do
			for cx = 0, g.cellsX - 2 do
				local a = Passability.clearance(pm, "TRACKED", g:index(cx, cz))
				local b = Passability.clearance(pm, "TRACKED", g:index(cx + 1, cz))
				t.expect(math.abs(a - b) <= 1, `jump at ({cx}, {cz})`)
			end
		end
	end)
end
