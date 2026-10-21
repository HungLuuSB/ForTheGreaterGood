--!strict
-- Passability quadtree for one (move class, clearance requirement) pair
-- (guide 6.3 step 1). Leaves are square regions that are entirely passable
-- ("open") or entirely blocked. Open terrain collapses into a few big leaves,
-- which keeps the coarse A* small.
--
-- The root is the next power of two covering the map; cells outside the map
-- count as blocked. A node splits until it is uniform. Uniformity is checked
-- in O(1) with a summed-area table of passable cells.
--
-- Open leaves are linked to the open leaves sharing an edge with them
-- (4-connectivity; corner-only contact is not a connection, matching flow
-- fields that never cut corners). Each open leaf also gets a connected-
-- component ID, so unreachable goals are rejected without a search.
--
-- Quadtree.update brings a tree up to date after passability changed in a
-- rectangle (a structure placed or removed) without a full rebuild
-- (DECISIONS D86). The leaf set, adjacency and components equal a full
-- rebuild's; leaf IDs may differ (reused or appended), deterministically.

local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")

local readu8 = buffer.readu8
local readu32, writeu32 = buffer.readu32, buffer.writeu32

local Quadtree = {}

export type Tree = {
	grid: Grid.Grid,
	moveClass: string,
	need: number, -- minimum clearance
	stepCost: buffer?, -- flow-field step-cost multipliers by terrain (f32 per cell, >= 1; Shared/Grid/Terrain, S-37); nil = all 1
	rootSize: number,
	-- leaves, 1-based IDs
	leafCount: number,
	leafX: { number }, -- min corner, cells
	leafZ: { number },
	leafSize: { number },
	leafOpen: { boolean },
	leafComponent: { number }, -- 0 for blocked leaves
	neighbors: { { number } }, -- open leaves only; ascending IDs
	cellLeaf: buffer, -- u32 per cell: leaf ID
	openLeafCount: number,
	componentCount: number,
	freeIds: { number }, -- IDs of removed leaves (leafSize 0), ascending; reused first
}

-- Appends the open leaves sharing an edge with leaf `id` to `out` (each
-- once: `stamp[n] = id` marks the ones already added).
local function scanNeighbors(tree: Tree, id: number, stamp: { [number]: number }, out: { number })
	local w, h = tree.grid.cellsX, tree.grid.cellsZ
	local x, z, size = tree.leafX[id], tree.leafZ[id], tree.leafSize[id]
	local cellLeaf, leafOpen = tree.cellLeaf, tree.leafOpen
	local function consider(cx: number, cz: number)
		if cx < 0 or cz < 0 or cx >= w or cz >= h then
			return
		end
		local n = readu32(cellLeaf, (cz * w + cx) * 4)
		if leafOpen[n] and stamp[n] ~= id then
			stamp[n] = id
			table.insert(out, n)
		end
	end
	for i = 0, size - 1 do
		consider(x + i, z - 1)
		consider(x + i, z + size)
		consider(x - 1, z + i)
		consider(x + size, z + i)
	end
end

-- Connected components over open leaves (BFS in ID order).
local function computeComponents(tree: Tree)
	local comps = tree.leafComponent
	for id = 1, tree.leafCount do
		comps[id] = 0
	end
	local comp = 0
	local queue: { number } = {}
	for id = 1, tree.leafCount do
		if tree.leafOpen[id] and comps[id] == 0 then
			comp += 1
			comps[id] = comp
			table.clear(queue)
			queue[1] = id
			local head = 1
			while queue[head] do
				local cur = queue[head]
				head += 1
				for _, n in tree.neighbors[cur] do
					if comps[n] == 0 then
						comps[n] = comp
						table.insert(queue, n)
					end
				end
			end
		end
	end
	tree.componentCount = comp
end

local function nextPow2(n: number): number
	local p = 1
	while p < n do
		p *= 2
	end
	return p
end

-- Builds the tree for units of `moveClass` needing clearance >= need
-- (Passability.requiredClearance(footprint)).
function Quadtree.build(pm: Passability.PassMap, moveClass: string, need: number): Tree
	local grid = pm.grid
	local w, h = grid.cellsX, grid.cellsZ
	local clearance = pm.clearance[moveClass]
	if clearance == nil then
		error(`Quadtree.build: unknown move class "{moveClass}"`, 2)
	end

	-- Summed-area table: sat[z * (w + 1) + x + 1] = passable cells in [0, x) × [0, z).
	local stride = w + 1
	local sat = table.create(stride * (h + 1), 0)
	for z = 1, h do
		local rowSum = 0
		for x = 1, w do
			if readu8(clearance, (z - 1) * w + (x - 1)) >= need then
				rowSum += 1
			end
			sat[z * stride + x + 1] = sat[(z - 1) * stride + x + 1] + rowSum
		end
	end
	local function openCount(x0: number, z0: number, x1: number, z1: number): number -- [x0, x1) × [z0, z1)
		return sat[z1 * stride + x1 + 1] - sat[z0 * stride + x1 + 1] - sat[z1 * stride + x0 + 1] + sat[z0 * stride + x0 + 1]
	end

	local tree: Tree = {
		grid = grid,
		moveClass = moveClass,
		need = need,
		rootSize = nextPow2(math.max(w, h)),
		leafCount = 0,
		leafX = {},
		leafZ = {},
		leafSize = {},
		leafOpen = {},
		leafComponent = {},
		neighbors = {},
		cellLeaf = buffer.create(grid.cellCount * 4),
		openLeafCount = 0,
		componentCount = 0,
		freeIds = {},
	}

	local function addLeaf(x: number, z: number, size: number, open: boolean)
		local id = tree.leafCount + 1
		tree.leafCount = id
		tree.leafX[id] = x
		tree.leafZ[id] = z
		tree.leafSize[id] = size
		tree.leafOpen[id] = open
		tree.leafComponent[id] = 0
		tree.neighbors[id] = {}
		if open then
			tree.openLeafCount += 1
		end
		for cz = z, math.min(z + size, h) - 1 do
			for cx = x, math.min(x + size, w) - 1 do
				writeu32(tree.cellLeaf, (cz * w + cx) * 4, id)
			end
		end
	end

	-- Depth-first, children in fixed order (NW, NE, SW, SE): leaf IDs are deterministic.
	local function visit(x: number, z: number, size: number)
		if x >= w or z >= h then
			return -- entirely outside the map
		end
		local x1, z1 = math.min(x + size, w), math.min(z + size, h)
		local inside = (x1 - x) * (z1 - z)
		local open = openCount(x, z, x1, z1)
		if open == 0 then
			addLeaf(x, z, size, false)
		elseif open == inside and inside == size * size then
			addLeaf(x, z, size, true)
		else
			local half = size // 2
			visit(x, z, half)
			visit(x + half, z, half)
			visit(x, z + half, half)
			visit(x + half, z + half, half)
		end
	end
	visit(0, 0, tree.rootSize)

	-- Edge-sharing open neighbors of each open leaf.
	local stamp = table.create(tree.leafCount, 0)
	for id = 1, tree.leafCount do
		if tree.leafOpen[id] then
			scanNeighbors(tree, id, stamp, tree.neighbors[id])
			table.sort(tree.neighbors[id])
		end
	end
	computeComponents(tree)
	return tree
end

local OUTSIDE, BLOCKED, OPEN, SPLIT, KEPT_SPLIT = 0, 1, 2, 3, 4

-- Updates `tree` after clearance changed inside the inclusive cell rectangle
-- [x0, x1] × [z0, z1] (callers pad it by the clearance cap). Returns true if
-- the tree changed.
--   1. Cells whose open/blocked state flipped; none → nothing to do.
--   2. Re-decide nodes top-down, descending only into nodes that touch the
--      flipped cells. Other nodes take their state from the old tree in O(1)
--      (inside an old leaf: that leaf's state; else an unchanged subtree).
--      A node is a blocked leaf if all its inside children are blocked
--      leaves, an open leaf if all four are open leaves, else split: the
--      same rule as Quadtree.build, so merges and splits match a rebuild.
--   3. Leaves that differ from the old ones replace the old leaves they
--      cover. IDs: removed and free IDs ascending, then new ones.
--   4. Neighbor lists of the new leaves and of the old leaves around them
--      are patched; components are recomputed.
-- `deferComponents`: leave the components to a later
-- Quadtree.computeComponents (several updates in a row, Nav's lazy flush, S-67).
function Quadtree.update(tree: Tree, pm: Passability.PassMap, x0: number, z0: number, x1: number, z1: number, deferComponents: boolean?): boolean
	local w, h = tree.grid.cellsX, tree.grid.cellsZ
	local clearance = pm.clearance[tree.moveClass]
	local need = tree.need
	local cellLeaf = tree.cellLeaf
	x0, z0 = math.max(x0, 0), math.max(z0, 0)
	x1, z1 = math.min(x1, w - 1), math.min(z1, h - 1)

	-- 1. bounding box of flipped cells
	local fx0, fz0, fx1, fz1 = w, h, -1, -1
	for z = z0, z1 do
		for x = x0, x1 do
			local c = z * w + x
			if (readu8(clearance, c) >= need) ~= tree.leafOpen[readu32(cellLeaf, c * 4)] then
				fx0, fz0 = math.min(fx0, x), math.min(fz0, z)
				fx1, fz1 = math.max(fx1, x), math.max(fz1, z)
			end
		end
	end
	if fx1 < 0 then
		return false
	end

	-- 2. decide nodes; leaves that differ from the old tree are collected
	local newX, newZ, newSize, newOpen = {}, {}, {}, {}
	local function emit(x: number, z: number, size: number, status: number, keep: number)
		if (status == OPEN or status == BLOCKED) and keep == 0 then
			table.insert(newX, x)
			table.insert(newZ, z)
			table.insert(newSize, size)
			table.insert(newOpen, status == OPEN)
		end
	end
	-- the old leaf that is exactly this node with this state, or 0
	local function same(x: number, z: number, size: number, status: number): number
		local id = readu32(cellLeaf, (z * w + x) * 4)
		if tree.leafSize[id] == size and tree.leafOpen[id] == (status == OPEN) then
			return id
		end
		return 0
	end
	local function decide(x: number, z: number, size: number): (number, number)
		if x >= w or z >= h then
			return OUTSIDE, 0
		end
		if x > fx1 or z > fz1 or x + size - 1 < fx0 or z + size - 1 < fz0 then
			local id = readu32(cellLeaf, (z * w + x) * 4)
			local leafSize = tree.leafSize[id]
			if leafSize < size then
				return KEPT_SPLIT, 0
			end
			local status = if tree.leafOpen[id] then OPEN else BLOCKED
			return status, if leafSize == size then id else 0
		end
		if size == 1 then
			local status = if readu8(clearance, z * w + x) >= need then OPEN else BLOCKED
			return status, same(x, z, 1, status)
		end
		local half = size // 2
		local s1, k1 = decide(x, z, half)
		local s2, k2 = decide(x + half, z, half)
		local s3, k3 = decide(x, z + half, half)
		local s4, k4 = decide(x + half, z + half, half)
		if s1 == OPEN and s2 == OPEN and s3 == OPEN and s4 == OPEN then
			return OPEN, same(x, z, size, OPEN)
		end
		local function blockedOrOut(st: number): boolean
			return st == BLOCKED or st == OUTSIDE
		end
		if blockedOrOut(s1) and blockedOrOut(s2) and blockedOrOut(s3) and blockedOrOut(s4) then
			return BLOCKED, same(x, z, size, BLOCKED)
		end
		emit(x, z, half, s1, k1)
		emit(x + half, z, half, s2, k2)
		emit(x, z + half, half, s3, k3)
		emit(x + half, z + half, half, s4, k4)
		return SPLIT, 0
	end
	local rootStatus, rootKeep = decide(0, 0, tree.rootSize)
	emit(0, 0, tree.rootSize, rootStatus, rootKeep)

	-- 3. old leaves covered by new ones are removed
	local removed: { [number]: boolean } = {}
	local removedList: { number } = {}
	local available: { number } = table.clone(tree.freeIds)
	for i = 1, #newX do
		local lx, lz, size = newX[i], newZ[i], newSize[i]
		for cz = lz, math.min(lz + size, h) - 1 do
			for cx = lx, math.min(lx + size, w) - 1 do
				local old = readu32(cellLeaf, (cz * w + cx) * 4)
				if not removed[old] then
					removed[old] = true
					table.insert(removedList, old)
					table.insert(available, old)
				end
			end
		end
	end
	table.sort(available)
	table.sort(removedList)
	for _, id in removedList do
		if tree.leafOpen[id] then
			tree.openLeafCount -= 1
			for _, n in tree.neighbors[id] do
				if not removed[n] then
					local list = tree.neighbors[n]
					local k = table.find(list, id)
					if k then
						table.remove(list, k)
					end
				end
			end
		end
		tree.neighbors[id] = {}
		tree.leafOpen[id] = false
		tree.leafSize[id] = 0
		tree.leafComponent[id] = 0
	end
	local isNew: { [number]: boolean } = {}
	local newIds: { number } = {}
	local nextAvail = 1
	for i = 1, #newX do
		local id = available[nextAvail]
		if id then
			nextAvail += 1
		else
			id = tree.leafCount + 1
			tree.leafCount = id
		end
		isNew[id] = true
		newIds[i] = id
		local lx, lz, size, open = newX[i], newZ[i], newSize[i], newOpen[i]
		tree.leafX[id], tree.leafZ[id], tree.leafSize[id], tree.leafOpen[id] = lx, lz, size, open
		tree.leafComponent[id] = 0
		tree.neighbors[id] = {}
		if open then
			tree.openLeafCount += 1
		end
		for cz = lz, math.min(lz + size, h) - 1 do
			for cx = lx, math.min(lx + size, w) - 1 do
				writeu32(cellLeaf, (cz * w + cx) * 4, id)
			end
		end
	end
	tree.freeIds = table.move(available, nextAvail, #available, 1, {})

	-- 4. neighbors and components
	local stamp: { [number]: number } = {}
	local touched: { [number]: boolean } = {} -- surviving leaves whose neighbor lists grew
	local touchedList: { number } = {}
	for _, id in newIds do
		if tree.leafOpen[id] then
			local list = tree.neighbors[id]
			scanNeighbors(tree, id, stamp, list)
			table.sort(list)
			for _, n in list do
				if not isNew[n] then
					table.insert(tree.neighbors[n], id)
					if not touched[n] then
						touched[n] = true
						table.insert(touchedList, n)
					end
				end
			end
		end
	end
	for _, n in touchedList do
		table.sort(tree.neighbors[n])
	end
	if not deferComponents then
		computeComponents(tree)
	end
	return true
end

Quadtree.computeComponents = computeComponents

function Quadtree.leafAt(tree: Tree, cell: number): number
	return readu32(tree.cellLeaf, cell * 4)
end

function Quadtree.isOpen(tree: Tree, cell: number): boolean
	return tree.leafOpen[readu32(tree.cellLeaf, cell * 4)]
end

-- Component of the cell's leaf; 0 if blocked.
function Quadtree.component(tree: Tree, cell: number): number
	return tree.leafComponent[readu32(tree.cellLeaf, cell * 4)]
end

-- Leaf center in cell units (continuous: a 1-cell leaf at (3, 4) → 3.5, 4.5).
function Quadtree.leafCenter(tree: Tree, id: number): (number, number)
	local half = tree.leafSize[id] / 2
	return tree.leafX[id] + half, tree.leafZ[id] + half
end

return Quadtree
