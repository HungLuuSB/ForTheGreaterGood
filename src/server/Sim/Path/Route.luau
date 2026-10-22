--!strict
-- Coarse route over quadtree leaves and the corridor around it
-- (guide 6.3 steps 1–2).
--
-- A* runs over open leaves. A leaf's position is its center, except the start
-- and goal leaves, which use the start and goal cells. Edge cost is the
-- Euclidean distance between positions; the heuristic is the straight line to
-- the goal cell, so it is admissible and consistent. Ties break on f, then h,
-- then leaf ID, so the route is deterministic.

local Heap = require("./Heap")
local Quadtree = require("./Quadtree")

local Work = require("../Work")

local Route = {}

export type Corridor = {
	mask: buffer, -- u8 per cell: 1 = inside the corridor
	cellCount: number,
	minX: number, -- bounding box, cells, inclusive
	minZ: number,
	maxX: number,
	maxZ: number,
}

export type Failure = "start_blocked" | "goal_blocked" | "unreachable"

-- Leaf IDs from the start cell's leaf to the goal cell's leaf, or nil and a
-- reason. Cells are 0-based indices.
function Route.find(tree: Quadtree.Tree, startCell: number, goalCell: number): ({ number }?, Failure?)
	local startLeaf = Quadtree.leafAt(tree, startCell)
	local goalLeaf = Quadtree.leafAt(tree, goalCell)
	if not tree.leafOpen[startLeaf] then
		return nil, "start_blocked"
	end
	if not tree.leafOpen[goalLeaf] then
		return nil, "goal_blocked"
	end
	if tree.leafComponent[startLeaf] ~= tree.leafComponent[goalLeaf] then
		return nil, "unreachable"
	end
	if startLeaf == goalLeaf then
		return { startLeaf }, nil
	end

	local grid = tree.grid
	local sx, sz = grid:coords(startCell)
	local gx, gz = grid:coords(goalCell)
	sx += 0.5
	sz += 0.5
	gx += 0.5
	gz += 0.5

	local function position(id: number): (number, number)
		if id == startLeaf then
			return sx, sz
		elseif id == goalLeaf then
			return gx, gz
		end
		return Quadtree.leafCenter(tree, id)
	end

	local g: { [number]: number } = { [startLeaf] = 0 }
	local cameFrom: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local heap = Heap.new()
	local hs = math.sqrt((gx - sx) ^ 2 + (gz - sz) ^ 2)
	Heap.push(heap, startLeaf, hs, hs)

	while not Heap.isEmpty(heap) do
		local cur = Heap.pop(heap)
		if closed[cur] then
			continue -- stale heap entry
		end
		if cur == goalLeaf then
			local route = { cur }
			while cameFrom[cur] do
				cur = cameFrom[cur]
				table.insert(route, cur)
			end
			-- reverse into start → goal order
			local n = #route
			for i = 1, n // 2 do
				route[i], route[n - i + 1] = route[n - i + 1], route[i]
			end
			return route, nil
		end
		closed[cur] = true
		local cx, cz = position(cur)
		local gCur = g[cur]
		for _, nb in tree.neighbors[cur] do
			if closed[nb] then
				continue
			end
			local nx, nz = position(nb)
			local tentative = gCur + math.sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)
			local known = g[nb]
			if known == nil or tentative < known then
				g[nb] = tentative
				cameFrom[nb] = cur
				local hn = math.sqrt((gx - nx) ^ 2 + (gz - nz) ^ 2)
				Heap.push(heap, nb, tentative + hn, hn)
			end
		end
	end
	return nil, "unreachable" -- unreachable despite the component check: shouldn't happen
end

-- Leaves on shortest leaf paths from every start cell to the goal cell, for
-- one shared field serving a whole group (guide 6.3: "all units in one move
-- order share one field"). One Dijkstra over the leaf graph from the goal
-- leaf, stopped once every reachable start leaf is settled.
--
-- Resumable so the Pathing system can slice it by work units: newSearch,
-- then runSearch(budget) until it returns true, then searchResult. One work
-- unit per leaf popped and per neighbor edge examined.
export type Search = {
	tree: Quadtree.Tree,
	startCells: { number },
	goalLeaf: number,
	wanted: { [number]: boolean },
	wantedCount: number,
	anyWanted: boolean,
	unreachable: { number },
	dist: { [number]: number },
	parent: { [number]: number },
	settled: { [number]: boolean },
	touched: { number }, -- leaves whose dist / settled were set (reset on release, S-60)
	arraySize: number, -- the leaf count dist / settled were made for
	heap: Heap.Heap,
	done: boolean,
	workDone: number,
}

-- Finished searches give back their per-leaf arrays (S-60): reset on exactly
-- the leaves they touched, so a reused pair is as good as new and routes
-- come out the same; it saves ~0.6 MB of allocation per search on a big map.
local POOL_MAX = 4
local arrayPool: { { dist: { number }, settled: { boolean }, n: number } } = {}

local function takeArrays(n: number): ({ number }, { boolean })
	for i = #arrayPool, 1, -1 do
		local a = arrayPool[i]
		if a.n == n then
			table.remove(arrayPool, i)
			return a.dist, a.settled
		end
	end
	return table.create(n, math.huge), table.create(n, false)
end

-- Gives a search's arrays back for the next one; the search must not be
-- used again.
function Route.releaseSearch(s: Search)
	if #arrayPool >= POOL_MAX or s.dist == nil then
		return
	end
	local dist, settled = s.dist, s.settled
	for _, leaf in s.touched do
		dist[leaf] = math.huge
		settled[leaf] = false
	end
	table.insert(arrayPool, { dist = dist, settled = settled, n = s.arraySize })
	s.dist, s.settled = nil :: any, nil :: any
end

function Route.newSearch(tree: Quadtree.Tree, startCells: { number }, goalCell: number): Search
	local goalLeaf = Quadtree.leafAt(tree, goalCell)
	local dist, settled = takeArrays(tree.leafCount)
	local s: Search = {
		tree = tree,
		startCells = startCells,
		goalLeaf = goalLeaf,
		wanted = {},
		wantedCount = 0,
		anyWanted = false,
		unreachable = {},
		-- per-leaf arrays sized to the tree (array part, no rehashing as the
		-- search grows; pooled; S-60): math.huge = not reached, false = not settled
		dist = dist,
		parent = {},
		settled = settled,
		touched = { goalLeaf },
		arraySize = tree.leafCount,
		heap = Heap.new(),
		done = false,
		workDone = 0,
	}
	s.dist[goalLeaf] = 0
	if not tree.leafOpen[goalLeaf] then
		s.unreachable = table.clone(startCells)
		s.done = true
		return s
	end
	local goalComp = tree.leafComponent[goalLeaf]
	for _, cell in startCells do
		local leaf = Quadtree.leafAt(tree, cell)
		if not tree.leafOpen[leaf] or tree.leafComponent[leaf] ~= goalComp then
			table.insert(s.unreachable, cell)
		elseif not s.wanted[leaf] then
			s.wanted[leaf] = true
			s.wantedCount += 1
		end
	end
	s.anyWanted = s.wantedCount > 0
	if not s.anyWanted then
		s.done = true -- no start cell can reach the goal
		return s
	end
	Heap.push(s.heap, goalLeaf, 0, 0)
	return s
end

-- Advances the search by about `budget` work units; true when finished.
function Route.runSearch(s: Search, budget: number): boolean
	local tree = s.tree
	local heap, dist, parent, settled, wanted, touched = s.heap, s.dist, s.parent, s.settled, s.wanted, s.touched
	local spent = 0
	-- leaf centres inline (Quadtree.leafCenter: corner + size / 2, the same
	-- arithmetic), the hot loop of big orders on fragmented maps (S-60)
	local leafX, leafZ, leafSize, neighbors = tree.leafX, tree.leafZ, tree.leafSize, tree.neighbors
	local sqrt = math.sqrt
	while not s.done and spent < budget do
		if Heap.isEmpty(heap) or s.wantedCount == 0 then
			s.done = true
			break
		end
		local cur, d = Heap.pop(heap)
		spent += 1
		if settled[cur] then
			continue
		end
		settled[cur] = true
		if wanted[cur] then
			s.wantedCount -= 1
		end
		local half = leafSize[cur] / 2
		local cx, cz = leafX[cur] + half, leafZ[cur] + half
		for _, nb in neighbors[cur] do
			spent += 1
			if not settled[nb] then
				local nhalf = leafSize[nb] / 2
				local nx, nz = leafX[nb] + nhalf, leafZ[nb] + nhalf
				local nd = d + sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)
				local old = dist[nb]
				if nd < old then
					if old == math.huge then
						touched[#touched + 1] = nb
					end
					dist[nb] = nd
					parent[nb] = cur
					Heap.push(heap, nb, nd, 0)
				end
			end
		end
	end
	if not s.done and (Heap.isEmpty(heap) or s.wantedCount == 0) then
		s.done = true
	end
	s.workDone += spent
	Work.counts.routeWork += spent -- (S-99)
	return s.done
end

-- The finished search's leaf list (no duplicates, deterministic order) and
-- the start cells that can't reach the goal. Empty list = goal blocked or
-- unreachable.
function Route.searchResult(s: Search): ({ number }, { number })
	if not s.anyWanted then
		return {}, s.unreachable
	end
	-- Walk each start leaf back to the goal, in start order.
	local leaves: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, cell in s.startCells do
		local leaf = Quadtree.leafAt(s.tree, cell)
		if s.wanted[leaf] then
			local cur: number? = leaf
			while cur ~= nil and not seen[cur] do
				seen[cur] = true
				table.insert(leaves, cur)
				cur = s.parent[cur]
			end
		end
	end
	if not seen[s.goalLeaf] then
		table.insert(leaves, s.goalLeaf)
	end
	return leaves, s.unreachable
end

-- The whole search in one call.
function Route.findMany(tree: Quadtree.Tree, startCells: { number }, goalCell: number): ({ number }, { number })
	local s = Route.newSearch(tree, startCells, goalCell)
	Route.runSearch(s, math.huge)
	return Route.searchResult(s)
end

-- Corridor = cells of the route's leaves plus every open leaf adjacent to
-- them (the guide's "one neighbor ring as padding").
function Route.corridor(tree: Quadtree.Tree, route: { number }): Corridor
	local grid = tree.grid
	local w, h = grid.cellsX, grid.cellsZ
	local mask = buffer.create(grid.cellCount)
	local included: { [number]: boolean } = {}
	local order: { number } = {}
	local function include(id: number)
		if not included[id] then
			included[id] = true
			table.insert(order, id)
		end
	end
	for _, id in route do
		include(id)
		for _, nb in tree.neighbors[id] do
			include(nb)
		end
	end

	local count = 0
	local minX, minZ, maxX, maxZ = w, h, -1, -1
	for _, id in order do
		local x0, z0, size = tree.leafX[id], tree.leafZ[id], tree.leafSize[id]
		local x1, z1 = math.min(x0 + size, w) - 1, math.min(z0 + size, h) - 1
		for cz = z0, z1 do
			for cx = x0, x1 do
				buffer.writeu8(mask, cz * w + cx, 1)
			end
		end
		count += (x1 - x0 + 1) * (z1 - z0 + 1)
		minX, minZ = math.min(minX, x0), math.min(minZ, z0)
		maxX, maxZ = math.max(maxX, x1), math.max(maxZ, z1)
	end
	return { mask = mask, cellCount = count, minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ }
end

-- Union of two corridors over the same map (new mask; inputs unchanged).
-- With the grid `width`, only the two corridors' bounding box is scanned
-- (S-5); without it, the whole mask.
function Route.mergeCorridors(a: Corridor, b: Corridor, width: number?): Corridor
	local n = buffer.len(a.mask)
	local mask = buffer.create(n)
	local count = 0
	local readu8, writeu8 = buffer.readu8, buffer.writeu8
	if width then
		local am, bm = a.mask, b.mask
		for cz = math.min(a.minZ, b.minZ), math.max(a.maxZ, b.maxZ) do
			local row = cz * width
			for cx = math.min(a.minX, b.minX), math.max(a.maxX, b.maxX) do
				local i = row + cx
				if readu8(am, i) == 1 or readu8(bm, i) == 1 then
					writeu8(mask, i, 1)
					count += 1
				end
			end
		end
	else
		for i = 0, n - 1 do
			if readu8(a.mask, i) == 1 or readu8(b.mask, i) == 1 then
				writeu8(mask, i, 1)
				count += 1
			end
		end
	end
	return {
		mask = mask,
		cellCount = count,
		minX = math.min(a.minX, b.minX),
		minZ = math.min(a.minZ, b.minZ),
		maxX = math.max(a.maxX, b.maxX),
		maxZ = math.max(a.maxZ, b.maxZ),
	}
end

function Route.inCorridor(corridor: Corridor, cell: number): boolean
	return buffer.readu8(corridor.mask, cell) == 1
end

return Route
