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

local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")

local readu8 = buffer.readu8
local readu32, writeu32 = buffer.readu32, buffer.writeu32

local Quadtree = {}

export type Tree = {
	grid: Grid.Grid,
	moveClass: string,
	need: number, -- minimum clearance
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
}

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
		if not tree.leafOpen[id] then
			continue
		end
		local x, z, size = tree.leafX[id], tree.leafZ[id], tree.leafSize[id]
		local list = tree.neighbors[id]
		local function consider(cx: number, cz: number)
			if cx < 0 or cz < 0 or cx >= w or cz >= h then
				return
			end
			local n = readu32(tree.cellLeaf, (cz * w + cx) * 4)
			if tree.leafOpen[n] and stamp[n] ~= id then
				stamp[n] = id
				table.insert(list, n)
			end
		end
		for i = 0, size - 1 do
			consider(x + i, z - 1)
			consider(x + i, z + size)
			consider(x - 1, z + i)
			consider(x + size, z + i)
		end
		table.sort(list)
	end

	-- Connected components over open leaves (BFS in ID order).
	local comp = 0
	for id = 1, tree.leafCount do
		if tree.leafOpen[id] and tree.leafComponent[id] == 0 then
			comp += 1
			tree.leafComponent[id] = comp
			local queue, head = { id }, 1
			while queue[head] do
				local cur = queue[head]
				head += 1
				for _, n in tree.neighbors[cur] do
					if tree.leafComponent[n] == 0 then
						tree.leafComponent[n] = comp
						table.insert(queue, n)
					end
				end
			end
		end
	end
	tree.componentCount = comp

	return tree
end

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
