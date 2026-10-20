--!strict
local Passability = require("@shared/Grid/Passability")
local Prng = require("@shared/Util/Prng")
local TestMap = require("@shared/Grid/TestMap")
local Heap = require("../Sim/Path/Heap")
local Quadtree = require("../Sim/Path/Quadtree")
local Route = require("../Sim/Path/Route")
local RunAll = require("./RunAll")

-- Flat land; `water(cx, cz)` > 0 makes a cell impassable for land units.
local function flatWith(cellsX: number, cellsZ: number, water: ((number, number) -> number)?): Passability.PassMap
	return Passability.build(TestMap.build(cellsX, cellsZ, function(cx, cz)
		return 10, if water then water(cx, cz) else 0
	end))
end

-- 32 × 32 map with a water wall at cx = 16, open only at cz >= 28.
local function wallMap(gapWidth: number?): Passability.PassMap
	local gap = gapWidth or 4
	return flatWith(32, 32, function(cx, cz)
		return if cx == 16 and cz < 32 - gap then 10 else 0
	end)
end

-- 4-connected flood fill over cells where `ok(cell)` holds.
local function reachable(tree: Quadtree.Tree, from: number, ok: (number) -> boolean): { [number]: boolean }
	local g = tree.grid
	local seen = { [from] = true }
	local queue, head = { from }, 1
	while queue[head] do
		local c = queue[head]
		head += 1
		local cx, cz = g:coords(c)
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = cx + d[1], cz + d[2]
			if g:inBounds(nx, nz) then
				local n = g:index(nx, nz)
				if not seen[n] and ok(n) then
					seen[n] = true
					table.insert(queue, n)
				end
			end
		end
	end
	return seen
end

return function(t: RunAll.Context)
	t.test("heap pops in (k1, k2, id) order", function()
		local heap = Heap.new()
		local rng = Prng.new(8)
		local entries = {}
		for i = 1, 500 do
			local e = { i, rng:nextInteger(0, 20), rng:nextInteger(0, 3) }
			table.insert(entries, e)
			Heap.push(heap, e[1], e[2], e[3])
		end
		table.sort(entries, function(a, b)
			if a[2] ~= b[2] then
				return a[2] < b[2]
			end
			if a[3] ~= b[3] then
				return a[3] < b[3]
			end
			return a[1] < b[1]
		end)
		for _, e in entries do
			local id, k1 = Heap.pop(heap)
			t.equal(id, e[1])
			t.equal(k1, e[2])
		end
		t.expect(Heap.isEmpty(heap), "heap should be empty")
		Heap.clear(heap)
		Heap.push(heap, 7, 1, 1)
		t.equal((Heap.pop(heap)), 7, "reusable after clear")
	end)

	t.test("open terrain collapses into few leaves", function()
		local full = Quadtree.build(flatWith(256, 256), "TRACKED", 1)
		t.equal(full.leafCount, 1)
		t.equal(full.openLeafCount, 1)
		t.equal(full.componentCount, 1)
		-- Non-power-of-two sides decompose into power-of-two squares along the
		-- edges (200 = 128 + 64 + 8): still a tiny fraction of 24,000 cells.
		local odd = Quadtree.build(flatWith(200, 120), "TRACKED", 1)
		t.expect(odd.openLeafCount <= 64, `200x120 open map used {odd.openLeafCount} open leaves`)
		t.equal(odd.componentCount, 1)
		-- Hilly terrain with lakes: leaves stay well under 1/4 of the cells.
		local hills = Quadtree.build(Passability.build(TestMap.generate({ seed = 9, cellsX = 128 })), "TRACKED", 1)
		t.expect(hills.leafCount * 4 < 128 * 128, `generated map used {hills.leafCount} leaves`)
	end)

	t.test("leaves partition the map; components match cell connectivity", function()
		local pm = Passability.build(TestMap.generate({ seed = 21, cellsX = 64 }))
		for _, need in { 1, 2 } do
			local tree = Quadtree.build(pm, "TRACKED", need)
			local g = tree.grid
			local function passable(c: number): boolean
				return Passability.clearance(pm, "TRACKED", c) >= need
			end
			for c = 0, g.cellCount - 1 do
				local leaf = Quadtree.leafAt(tree, c)
				local cx, cz = g:coords(c)
				local x0, z0, size = tree.leafX[leaf], tree.leafZ[leaf], tree.leafSize[leaf]
				t.expect(cx >= x0 and cz >= z0 and cx < x0 + size and cz < z0 + size, `cell {c} outside its leaf`)
				t.equal(tree.leafOpen[leaf], passable(c), `leaf openness at cell {c}`)
			end
			-- Neighbor lists are symmetric.
			for id = 1, tree.leafCount do
				for _, nb in tree.neighbors[id] do
					t.expect(table.find(tree.neighbors[nb], id) ~= nil, `neighbors {id} -> {nb} not symmetric`)
				end
			end
			-- Same component <=> 4-connected through passable cells.
			local done: { [number]: boolean } = {}
			for c = 0, g.cellCount - 1 do
				if passable(c) and not done[c] then
					local region = reachable(tree, c, passable)
					local comp = Quadtree.component(tree, c)
					for other in region do
						done[other] = true
						t.equal(Quadtree.component(tree, other), comp, "connected cells share a component")
					end
				end
			end
		end
	end)

	t.test("route goes around an obstacle through the gap", function()
		local tree = Quadtree.build(wallMap(), "TRACKED", 1)
		local g = tree.grid
		local start, goal = g:index(2, 2), g:index(30, 2)
		local route, failure = Route.find(tree, start, goal)
		t.equal(failure, nil)
		assert(route)
		t.equal(route[1], Quadtree.leafAt(tree, start))
		t.equal(route[#route], Quadtree.leafAt(tree, goal))
		for i = 1, #route - 1 do
			t.expect(tree.leafOpen[route[i]], "route leaves are open")
			t.expect(table.find(tree.neighbors[route[i]], route[i + 1]) ~= nil, "consecutive route leaves touch")
		end

		local corridor = Route.corridor(tree, route)
		t.expect(Route.inCorridor(corridor, start) and Route.inCorridor(corridor, goal), "corridor holds both ends")
		local inside = 0
		for c = 0, g.cellCount - 1 do
			if Route.inCorridor(corridor, c) then
				inside += 1
				t.expect(Quadtree.isOpen(tree, c), `corridor cell {c} is blocked`)
				local cx, cz = g:coords(c)
				t.expect(cx >= corridor.minX and cx <= corridor.maxX and cz >= corridor.minZ and cz <= corridor.maxZ, "bounding box")
			end
		end
		t.equal(inside, corridor.cellCount)
		local within = reachable(tree, start, function(c)
			return Route.inCorridor(corridor, c)
		end)
		t.expect(within[goal], "the goal is reachable without leaving the corridor")
		local usesGap = false
		for cz = 28, 31 do
			usesGap = usesGap or Route.inCorridor(corridor, g:index(16, cz))
		end
		t.expect(usesGap, "the corridor passes through the gap")
	end)

	t.test("no route to unreachable or blocked cells", function()
		-- A ring of water around (8..11, 8..11) makes an island.
		local pm = flatWith(24, 24, function(cx, cz)
			local onRing = (cx == 6 or cx == 13) and cz >= 6 and cz <= 13 or (cz == 6 or cz == 13) and cx >= 6 and cx <= 13
			return if onRing then 10 else 0
		end)
		local tree = Quadtree.build(pm, "TRACKED", 1)
		local g = tree.grid
		local route, failure = Route.find(tree, g:index(1, 1), g:index(9, 9))
		t.equal(route, nil)
		t.equal(failure, "unreachable")
		_, failure = Route.find(tree, g:index(1, 1), g:index(6, 9))
		t.equal(failure, "goal_blocked")
		_, failure = Route.find(tree, g:index(13, 13), g:index(1, 1))
		t.equal(failure, "start_blocked")
	end)

	t.test("a 1-cell gap passes footprint 1 but not footprint 2", function()
		local pm = wallMap(1) -- the gap is the single cell (16, 31) on the map edge
		local gapPm = flatWith(32, 32, function(cx, cz)
			return if cx == 16 and cz ~= 20 then 10 else 0
		end)
		for _, case in { { pm, "edge gap" }, { gapPm, "interior gap" } } do
			local small = Quadtree.build(case[1], "TRACKED", Passability.requiredClearance(1))
			local big = Quadtree.build(case[1], "TRACKED", Passability.requiredClearance(2))
			local g = small.grid
			local start, goal = g:index(5, 10), g:index(26, 10)
			t.expect(Route.find(small, start, goal) ~= nil, `footprint 1 through the {case[2]}`)
			local route, failure = Route.find(big, start, goal)
			t.equal(route, nil, `footprint 2 must not pass the {case[2]}`)
			t.equal(failure, "unreachable")
		end
	end)

	t.test("routes within one leaf and determinism", function()
		local tree = Quadtree.build(flatWith(64, 64), "TRACKED", 1)
		local g = tree.grid
		local route = Route.find(tree, g:index(1, 1), g:index(60, 60))
		t.deepEqual(route, { 1 })

		local pm = Passability.build(TestMap.generate({ seed = 5, cellsX = 128 }))
		local a = Quadtree.build(pm, "TRACKED", 1)
		local b = Quadtree.build(pm, "TRACKED", 1)
		t.equal(a.leafCount, b.leafCount)
		-- Pick two open cells in the same component, far apart.
		local first, last
		for c = 0, a.grid.cellCount - 1 do
			if Quadtree.isOpen(a, c) then
				first = first or c
				if Quadtree.component(a, c) == Quadtree.component(a, first) then
					last = c
				end
			end
		end
		local ra = Route.find(a, first, last)
		local rb = Route.find(b, first, last)
		t.expect(ra ~= nil, "route on the generated map")
		t.deepEqual(ra, rb)
	end)
end
