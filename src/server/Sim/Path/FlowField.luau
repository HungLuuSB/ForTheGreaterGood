--!strict
-- Flow fields inside a corridor (guide 6.3 step 3, 6.4).
--
-- 1. Integration: Dijkstra from the goal over corridor cells, 8-connected.
--    Straight steps cost 1, diagonal steps √2, times the mean of the two
--    cells' terrain multipliers (tree.stepCost, each >= 1; S-37). Diagonals
--    never cut corners: both orthogonal cells they
--    pass between must be in the corridor.
--    The queue is a bucket queue (Dial's algorithm): bucket b holds cells
--    with cost in [b, b + 1). Every step costs at least 1, so a cell in the
--    current bucket can't be improved by another cell of the same bucket:
--    costs are exactly Dijkstra's, with O(1) queue operations. (Terrain
--    modifiers must keep the minimum step cost >= the bucket width.)
-- 2. Directions: each corridor cell points to its cheapest neighbor (u8,
--    0..7 counter-clockwise from +X; 255 = none). The goal cell and cells
--    the goal can't reach have 255.
--
-- Work is time-sliced in deterministic work units, not milliseconds: one
-- unit per settled cell and one per directed cell. A job resumes where it
-- stopped, so the result never depends on how it was sliced, and the tick a
-- field completes on never depends on CPU speed (replays stay exact).

local Quadtree = require("./Quadtree")
local Route = require("./Route")

local readu8, writeu8 = buffer.readu8, buffer.writeu8
local SQRT2 = math.sqrt(2)
local INF = math.huge

local FlowField = {}

FlowField.NONE = 255

-- Direction d moves by (DX[d + 1], DZ[d + 1]) cells. Even directions are
-- straight, odd ones diagonal.
FlowField.DX = table.freeze({ 1, 1, 0, -1, -1, -1, 0, 1 })
FlowField.DZ = table.freeze({ 0, 1, 1, 1, 0, -1, -1, -1 })
local DX, DZ = FlowField.DX, FlowField.DZ

export type Field = {
	moveClass: string,
	need: number,
	goalCell: number,
	cellsX: number,
	cellsZ: number,
	dir: buffer, -- u8 per cell
	corridor: Route.Corridor,
	cost: { number }?, -- integration values (1-based by cell + 1), only if kept
}

export type Job = {
	field: Field,
	phase: "integrate" | "direct" | "done",
	cost: { number },
	-- bucket queue: entries linked per bucket (LIFO), buckets visited in order
	bucketHead: { [number]: number }, -- bucket → first entry (0 = empty)
	entryCell: { number },
	entryCost: { number },
	entryNext: { number },
	entryCount: number,
	bucket: number, -- current bucket
	maxBucket: number,
	scanZ: number, -- direction pass position within the corridor bbox
	scanX: number,
	keepCost: boolean,
	workDone: number, -- total work units spent
	stepCost: buffer?, -- the tree's terrain multipliers (S-37)
}

-- Finished jobs give back their scratch (S-60, the Normandy profile): the
-- per-cell cost table (a whole map's worth, ~1 MB on a 256-cell map) and the
-- bucket-queue arrays. Released cost tables are reset to INF on exactly the
-- cells the job wrote (every one of them is in its entry list), so a reused
-- table is indistinguishable from a new one and fields come out the same.
local POOL_MAX = 4
local scratchPool: { { cost: { number }, n: number, entryCell: { number }, entryCost: { number }, entryNext: { number } } } = {}

local function takeScratch(n: number): ({ number }, { number }, { number }, { number })
	for i = #scratchPool, 1, -1 do
		local s = scratchPool[i]
		if s.n == n then
			table.remove(scratchPool, i)
			return s.cost, s.entryCell, s.entryCost, s.entryNext
		end
	end
	return table.create(n, INF), {}, {}, {}
end

-- Gives a finished job's scratch back for the next job (no-op for jobs that
-- keep their cost table or aren't done). Call once the field is stored.
function FlowField.release(job: Job)
	if job.keepCost or job.phase ~= "done" or #scratchPool >= POOL_MAX then
		return
	end
	local cost, entryCell = job.cost, job.entryCell
	for e = 1, job.entryCount do
		cost[entryCell[e] + 1] = INF
	end
	table.insert(scratchPool, { cost = cost, n = job.field.cellsX * job.field.cellsZ, entryCell = entryCell, entryCost = job.entryCost, entryNext = job.entryNext })
	job.cost = {} -- the job no longer owns it
end

-- Starts a job. The goal must be inside the corridor.
function FlowField.newJob(tree: Quadtree.Tree, corridor: Route.Corridor, goalCell: number, keepCost: boolean?): Job
	if not Route.inCorridor(corridor, goalCell) then
		error(`FlowField.newJob: goal cell {goalCell} is outside the corridor`, 2)
	end
	local grid = tree.grid
	local n = grid.cellCount
	local dir = buffer.create(n)
	buffer.fill(dir, 0, FlowField.NONE)
	local cost, entryCell, entryCost, entryNext = takeScratch(n)
	cost[goalCell + 1] = 0
	entryCell[1], entryCost[1], entryNext[1] = goalCell, 0, 0
	return {
		field = {
			moveClass = tree.moveClass,
			need = tree.need,
			goalCell = goalCell,
			cellsX = grid.cellsX,
			cellsZ = grid.cellsZ,
			dir = dir,
			corridor = corridor,
			cost = nil,
		},
		phase = "integrate",
		cost = cost,
		bucketHead = { [0] = 1 },
		entryCell = entryCell,
		entryCost = entryCost,
		entryNext = entryNext,
		entryCount = 1,
		bucket = 0,
		maxBucket = 0,
		scanZ = corridor.minZ,
		scanX = corridor.minX,
		keepCost = keepCost == true,
		workDone = 0,
		stepCost = tree.stepCost,
	}
end

-- Runs up to `budget` work units (nil = to completion). Returns true when the
-- field is finished.
function FlowField.run(job: Job, budget: number?): boolean
	local remaining = budget or INF
	local field = job.field
	local w, h = field.cellsX, field.cellsZ
	local mask = field.corridor.mask
	local cost = job.cost
	local spent = 0
	local stepCost = job.stepCost
	local readf32 = buffer.readf32

	if job.phase == "integrate" then
		local bucketHead, entryCell, entryCost, entryNext = job.bucketHead, job.entryCell, job.entryCost, job.entryNext
		local floor = math.floor
		-- the job's queue counters live in locals while it runs (S-60: the
		-- Normandy profile); written back below
		local bucket, maxBucket, entryCount = job.bucket, job.maxBucket, job.entryCount
		-- the cell being expanded: its cost and terrain multiplier
		local cur, curStep = 0, 0
		local function relax(nc: number, base: number)
			local step = base
			if stepCost then
				step *= (curStep + readf32(stepCost, nc * 4)) * 0.5
			end
			local nv = cur + step
			if nv < cost[nc + 1] then
				cost[nc + 1] = nv
				local b = floor(nv)
				entryCount += 1
				entryCell[entryCount] = nc
				entryCost[entryCount] = nv
				entryNext[entryCount] = bucketHead[b] or 0
				bucketHead[b] = entryCount
				if b > maxBucket then
					maxBucket = b
				end
			end
		end
		while spent < remaining do
			-- next entry: the current bucket's head, else the next non-empty bucket
			local e = bucketHead[bucket] or 0
			while e == 0 and bucket < maxBucket do
				bucket += 1
				e = bucketHead[bucket] or 0
			end
			if e == 0 then
				break -- queue empty
			end
			bucketHead[bucket] = entryNext[e]
			local cell, c = entryCell[e], entryCost[e]
			if c > cost[cell + 1] then
				continue -- stale entry; costs no work
			end
			spent += 1
			local cz = cell // w
			local cx = cell - cz * w
			cur, curStep = c, if stepCost then readf32(stepCost, cell * 4) else 0
			-- the 8 neighbors in DX / DZ order (E, NE, N, NW, W, SW, S, SE),
			-- unrolled (S-60); a diagonal also needs both cells it squeezes
			-- between open
			local e = cx + 1 < w and readu8(mask, cell + 1) ~= 0
			local n = cz + 1 < h and readu8(mask, cell + w) ~= 0
			local west = cx > 0 and readu8(mask, cell - 1) ~= 0
			local s = cz > 0 and readu8(mask, cell - w) ~= 0
			if e then
				relax(cell + 1, 1)
			end
			if e and n and readu8(mask, cell + w + 1) ~= 0 then
				relax(cell + w + 1, SQRT2)
			end
			if n then
				relax(cell + w, 1)
			end
			if west and n and readu8(mask, cell + w - 1) ~= 0 then
				relax(cell + w - 1, SQRT2)
			end
			if west then
				relax(cell - 1, 1)
			end
			if west and s and readu8(mask, cell - w - 1) ~= 0 then
				relax(cell - w - 1, SQRT2)
			end
			if s then
				relax(cell - w, 1)
			end
			if e and s and readu8(mask, cell - w + 1) ~= 0 then
				relax(cell - w + 1, SQRT2)
			end
		end
		job.bucket, job.maxBucket, job.entryCount = bucket, maxBucket, entryCount
		local head = job.bucketHead[job.bucket] or 0
		if head == 0 and job.bucket >= job.maxBucket then
			job.phase = "direct"
		end
	end

	if job.phase == "direct" then
		local corridor = field.corridor
		local dir = field.dir
		local goal = field.goalCell
		local z, x = job.scanZ, job.scanX
		while spent < remaining and z <= corridor.maxZ do
			local cell = z * w + x
			if readu8(mask, cell) == 1 and cell ~= goal and cost[cell + 1] < INF then
				spent += 1
				local best, bestCost = FlowField.NONE, cost[cell + 1]
				-- the 8 neighbors in DX / DZ order, unrolled (S-60); a diagonal
				-- needs both cells it squeezes between open. First strictly
				-- lower cost wins, as before.
				local inE, inN, inW, inS = x + 1 < w, z + 1 < h, x > 0, z > 0
				local e = inE and readu8(mask, cell + 1) ~= 0
				local n = inN and readu8(mask, cell + w) ~= 0
				local west = inW and readu8(mask, cell - 1) ~= 0
				local s = inS and readu8(mask, cell - w) ~= 0
				local v
				if inE then
					v = cost[cell + 2]
					if v < bestCost then
						best, bestCost = 0, v
					end
				end
				if e and n then
					v = cost[cell + w + 2]
					if v < bestCost then
						best, bestCost = 1, v
					end
				end
				if inN then
					v = cost[cell + w + 1]
					if v < bestCost then
						best, bestCost = 2, v
					end
				end
				if west and n then
					v = cost[cell + w]
					if v < bestCost then
						best, bestCost = 3, v
					end
				end
				if inW then
					v = cost[cell]
					if v < bestCost then
						best, bestCost = 4, v
					end
				end
				if west and s then
					v = cost[cell - w]
					if v < bestCost then
						best, bestCost = 5, v
					end
				end
				if inS then
					v = cost[cell - w + 1]
					if v < bestCost then
						best, bestCost = 6, v
					end
				end
				if e and s then
					v = cost[cell - w + 2]
					if v < bestCost then
						best, bestCost = 7, v
					end
				end
				writeu8(dir, cell, best)
			end
			x += 1
			if x > corridor.maxX then
				x = corridor.minX
				z += 1
			end
		end
		job.scanZ, job.scanX = z, x
		if z > corridor.maxZ then
			job.phase = "done"
			if job.keepCost then
				field.cost = cost
			end
		end
	end

	job.workDone += spent
	return job.phase == "done"
end

function FlowField.isDone(job: Job): boolean
	return job.phase == "done"
end

-- One-shot build.
function FlowField.build(tree: Quadtree.Tree, corridor: Route.Corridor, goalCell: number, keepCost: boolean?): Field
	local job = FlowField.newJob(tree, corridor, goalCell, keepCost)
	FlowField.run(job)
	return job.field
end

-- Direction byte for a cell (0..7, or NONE).
function FlowField.direction(field: Field, cell: number): number
	return readu8(field.dir, cell)
end

-- Does following this field from `cell` lead to the goal?
function FlowField.covers(field: Field, cell: number): boolean
	return cell == field.goalCell or readu8(field.dir, cell) ~= FlowField.NONE
end

-- Unit vector for a direction byte (diagonals normalized).
local INV_SQRT2 = 1 / SQRT2
function FlowField.vector(d: number): (number, number)
	local s = if d % 2 == 1 then INV_SQRT2 else 1
	return DX[d + 1] * s, DZ[d + 1] * s
end

return FlowField
