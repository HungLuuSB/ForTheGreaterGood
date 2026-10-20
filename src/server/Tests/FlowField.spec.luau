--!strict
local Passability = require("@shared/Grid/Passability")
local TestMap = require("@shared/Grid/TestMap")
local FieldCache = require("../Sim/Path/FieldCache")
local FlowField = require("../Sim/Path/FlowField")
local Quadtree = require("../Sim/Path/Quadtree")
local Route = require("../Sim/Path/Route")
local Maps = require("./Support/Maps")
local RunAll = require("./RunAll")

local DX, DZ = FlowField.DX, FlowField.DZ

-- Follows the field from `cell`; checks each step stays in the corridor and
-- never cuts a corner. Returns the number of steps to the goal, or errors.
local function follow(field: FlowField.Field, cell: number): number
	local w = field.cellsX
	local mask = field.corridor.mask
	local steps = 0
	while cell ~= field.goalCell do
		local d = FlowField.direction(field, cell)
		if d == FlowField.NONE then
			error(`cell {cell} has no direction`, 0)
		end
		local cz = cell // w
		local cx = cell - cz * w
		local nx, nz = cx + DX[d + 1], cz + DZ[d + 1]
		if d % 2 == 1 and (buffer.readu8(mask, cz * w + nx) == 0 or buffer.readu8(mask, nz * w + cx) == 0) then
			error(`corner cut at ({cx}, {cz})`, 0)
		end
		cell = nz * w + nx
		if buffer.readu8(mask, cell) == 0 then
			error(`left the corridor at ({nx}, {nz})`, 0)
		end
		steps += 1
		if steps > field.cellsX * field.cellsZ then
			error("loop in the field", 0)
		end
	end
	return steps
end

local function checkAllReachGoal(t: RunAll.Context, field: FlowField.Field, label: string)
	local covered = 0
	for cell = 0, field.cellsX * field.cellsZ - 1 do
		if Route.inCorridor(field.corridor, cell) then
			local ok, err = pcall(follow, field, cell)
			t.expect(ok, `{label}: {err}`)
			covered += 1
		else
			t.equal(FlowField.direction(field, cell), FlowField.NONE, `{label}: cell {cell} outside the corridor has a direction`)
		end
	end
	t.expect(covered > 0, "corridor is not empty")
end

return function(t: RunAll.Context)
	t.test("every corridor cell reaches the goal (wall map)", function()
		local pm = Maps.flatWith(48, 32, function(cx, cz)
			return if cx == 24 and cz < 26 then 10 else 0
		end)
		local g = pm.grid
		local field = Maps.field(pm, "TRACKED", 1, g:index(2, 2), g:index(45, 3))
		checkAllReachGoal(t, field, "wall map")
		t.equal(FlowField.direction(field, field.goalCell), FlowField.NONE, "the goal has no direction")
		t.expect(FlowField.covers(field, field.goalCell), "covers() includes the goal")
	end)

	t.test("every corridor cell reaches the goal (maze and generated terrain)", function()
		local maze = Maps.maze(64, 32, 8)
		local g = maze.grid
		checkAllReachGoal(t, Maps.field(maze, "TRACKED", 1, g:index(1, 16), g:index(62, 16)), "maze")

		local hills = Passability.build(TestMap.generate({ seed = 5, cellsX = 96 }))
		local tree = Quadtree.build(hills, "TRACKED", 1)
		local first, last
		for c = 0, tree.grid.cellCount - 1 do
			if Quadtree.isOpen(tree, c) then
				first = first or c
				if Quadtree.component(tree, c) == Quadtree.component(tree, first) then
					last = c
				end
			end
		end
		checkAllReachGoal(t, Maps.field(hills, "TRACKED", 1, first, last), "generated")
	end)

	t.test("integration cost on open ground is the octile distance", function()
		local pm = Maps.flatWith(16, 16)
		local g = pm.grid
		local goal = g:index(8, 8)
		local field = Maps.field(pm, "TRACKED", 1, g:index(0, 0), goal, true)
		local cost = field.cost :: { number }
		for cz = 0, 15 do
			for cx = 0, 15 do
				local dx, dz = math.abs(cx - 8), math.abs(cz - 8)
				local octile = math.max(dx, dz) - math.min(dx, dz) + math.sqrt(2) * math.min(dx, dz)
				t.expect(math.abs(cost[g:index(cx, cz) + 1] - octile) < 1e-9, `cost at ({cx}, {cz})`)
			end
		end
		-- Straight line along a row: steps = distance.
		t.equal(follow(field, g:index(0, 8)), 8)
		-- Diagonal approach: 8 diagonal steps from (0, 0).
		t.equal(follow(field, g:index(0, 0)), 8)
	end)

	t.test("diagonals never squeeze between two blocked cells", function()
		-- Water at (5, 4) and (4, 5): a diagonal from (4, 4) to (5, 5) would cut both corners.
		local pm = Maps.flatWith(10, 10, function(cx, cz)
			return if (cx == 5 and cz == 4) or (cx == 4 and cz == 5) then 10 else 0
		end)
		local g = pm.grid
		local field = Maps.field(pm, "TRACKED", 1, g:index(4, 4), g:index(5, 5))
		local d = FlowField.direction(field, g:index(4, 4))
		t.expect(d ~= 1, "(4, 4) must not point diagonally through the gap")
		checkAllReachGoal(t, field, "pinch")
	end)

	t.test("a time-sliced job equals the one-shot result", function()
		local pm = Maps.maze(64, 48, 8)
		local g = pm.grid
		local tree = Quadtree.build(pm, "TRACKED", 1)
		local start, goal = g:index(1, 1), g:index(62, 46)
		local route = Route.find(tree, start, goal) :: { number }
		local corridor = Route.corridor(tree, route)
		local oneShot = FlowField.build(tree, corridor, goal)
		for _, budget in { 1, 7, 64, 1000 } do
			local job = FlowField.newJob(tree, corridor, goal)
			local calls = 0
			while not FlowField.run(job, budget) do
				calls += 1
				t.expect(calls < 1000000, "job never finished")
			end
			t.equal(buffer.tostring(job.field.dir), buffer.tostring(oneShot.dir), `budget {budget}`)
			if budget < 100 then
				t.expect(calls > 10, `budget {budget} should take many calls, took {calls}`)
			end
			t.expect(job.workDone <= 2 * corridor.cellCount, "work units are bounded by twice the corridor size")
		end
	end)

	t.test("newJob rejects a goal outside the corridor", function()
		local pm = Maps.flatWith(8, 8)
		local tree = Quadtree.build(pm, "TRACKED", 1)
		local corridor = Route.corridor(tree, { 1 })
		corridor.mask = buffer.create(64) -- empty corridor
		t.throws(function()
			FlowField.newJob(tree, corridor, 0)
		end, "outside the corridor")
	end)

	t.test("vectors are unit length and point along the direction", function()
		for d = 0, 7 do
			local x, z = FlowField.vector(d)
			t.expect(math.abs(math.sqrt(x * x + z * z) - 1) < 1e-12, `length for {d}`)
			t.equal(math.sign(x), DX[d + 1])
			t.equal(math.sign(z), DZ[d + 1])
		end
	end)

	t.test("field cache: hits, LRU eviction, invalidation", function()
		local cache = FieldCache.new(3)
		local pm = Maps.flatWith(8, 8)
		local g = pm.grid
		local function field(goal: number): FlowField.Field
			return (Maps.field(pm, "TRACKED", 1, g:index(0, 0), goal))
		end
		local ka, kb, kc, kd = FieldCache.key("TRACKED", 1, 10), FieldCache.key("TRACKED", 1, 11), FieldCache.key("TRACKED", 1, 12), FieldCache.key("TRACKED", 2, 10)
		t.notEqual(ka, kd, "need is part of the key")
		t.equal(FieldCache.get(cache, ka), nil)
		FieldCache.put(cache, ka, field(10))
		FieldCache.put(cache, kb, field(11))
		FieldCache.put(cache, kc, field(12))
		t.expect(FieldCache.get(cache, ka) ~= nil, "a is cached")
		local evicted = FieldCache.put(cache, kd, field(10))
		t.equal(evicted, kb, "b was least recently used")
		t.equal(FieldCache.get(cache, kb), nil)
		t.equal(FieldCache.size(cache), 3)
		t.equal(cache.hits, 1)
		t.equal(cache.misses, 2)
		t.equal(cache.evictions, 1)
		-- Replacing an existing key doesn't evict.
		t.equal(FieldCache.put(cache, ka, field(10)), nil)
		-- Every field here covers the whole 8 × 8 map (one leaf), so any cell drops all of them.
		t.equal(FieldCache.invalidateCell(cache, g:index(3, 3)), 3)
		t.equal(FieldCache.size(cache), 0)
	end)
end
