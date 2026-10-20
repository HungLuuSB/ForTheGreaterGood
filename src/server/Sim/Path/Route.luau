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
-- Returns the leaf list (no duplicates, deterministic order) and the start
-- cells that can't reach the goal. Empty list = goal blocked or unreachable.
function Route.findMany(tree: Quadtree.Tree, startCells: { number }, goalCell: number): ({ number }, { number })
	local goalLeaf = Quadtree.leafAt(tree, goalCell)
	local unreachable: { number } = {}
	if not tree.leafOpen[goalLeaf] then
		return {}, table.clone(startCells)
	end
	local goalComp = tree.leafComponent[goalLeaf]

	-- Start leaves still to settle.
	local wanted: { [number]: boolean } = {}
	local wantedCount = 0
	for _, cell in startCells do
		local leaf = Quadtree.leafAt(tree, cell)
		if not tree.leafOpen[leaf] or tree.leafComponent[leaf] ~= goalComp then
			table.insert(unreachable, cell)
		elseif not wanted[leaf] then
			wanted[leaf] = true
			wantedCount += 1
		end
	end
	if wantedCount == 0 then
		return {}, unreachable -- no start cell can reach the goal
	end

	local dist: { [number]: number } = { [goalLeaf] = 0 }
	local parent: { [number]: number } = {}
	local settled: { [number]: boolean } = {}
	local heap = Heap.new()
	Heap.push(heap, goalLeaf, 0, 0)
	while not Heap.isEmpty(heap) and wantedCount > 0 do
		local cur, d = Heap.pop(heap)
		if settled[cur] then
			continue
		end
		settled[cur] = true
		if wanted[cur] then
			wantedCount -= 1
		end
		local cx, cz = Quadtree.leafCenter(tree, cur)
		for _, nb in tree.neighbors[cur] do
			if not settled[nb] then
				local nx, nz = Quadtree.leafCenter(tree, nb)
				local nd = d + math.sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)
				if dist[nb] == nil or nd < dist[nb] then
					dist[nb] = nd
					parent[nb] = cur
					Heap.push(heap, nb, nd, 0)
				end
			end
		end
	end

	-- Walk each start leaf back to the goal, in start order.
	local leaves: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, cell in startCells do
		local leaf = Quadtree.leafAt(tree, cell)
		if wanted[leaf] then
			local cur: number? = leaf
			while cur ~= nil and not seen[cur] do
				seen[cur] = true
				table.insert(leaves, cur)
				cur = parent[cur]
			end
		end
	end
	if not seen[goalLeaf] then
		table.insert(leaves, goalLeaf)
	end
	return leaves, unreachable
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
function Route.mergeCorridors(a: Corridor, b: Corridor): Corridor
	local n = buffer.len(a.mask)
	local mask = buffer.create(n)
	local count = 0
	for i = 0, n - 1 do
		if buffer.readu8(a.mask, i) == 1 or buffer.readu8(b.mask, i) == 1 then
			buffer.writeu8(mask, i, 1)
			count += 1
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
