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

-- Starts a job. The goal must be inside the corridor.
function FlowField.newJob(tree: Quadtree.Tree, corridor: Route.Corridor, goalCell: number, keepCost: boolean?): Job
	if not Route.inCorridor(corridor, goalCell) then
		error(`FlowField.newJob: goal cell {goalCell} is outside the corridor`, 2)
	end
	local grid = tree.grid
	local n = grid.cellCount
	local dir = buffer.create(n)
	buffer.fill(dir, 0, FlowField.NONE)
	local cost = table.create(n, INF)
	cost[goalCell + 1] = 0
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
		entryCell = { goalCell },
		entryCost = { 0 },
		entryNext = { 0 },
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
		while spent < remaining do
			-- next entry: the current bucket's head, else the next non-empty bucket
			local e = bucketHead[job.bucket] or 0
			while e == 0 and job.bucket < job.maxBucket do
				job.bucket += 1
				e = bucketHead[job.bucket] or 0
			end
			if e == 0 then
				break -- queue empty
			end
			bucketHead[job.bucket] = entryNext[e]
			local cell, c = entryCell[e], entryCost[e]
			if c > cost[cell + 1] then
				continue -- stale entry; costs no work
			end
			spent += 1
			local cz = cell // w
			local cx = cell - cz * w
			for d = 0, 7 do
				local nx, nz = cx + DX[d + 1], cz + DZ[d + 1]
				if nx < 0 or nz < 0 or nx >= w or nz >= h then
					continue
				end
				local nc = nz * w + nx
				if readu8(mask, nc) == 0 then
					continue
				end
				local step = 1
				if d % 2 == 1 then
					-- diagonal: both cells it squeezes between must be open
					if readu8(mask, cz * w + nx) == 0 or readu8(mask, nz * w + cx) == 0 then
						continue
					end
					step = SQRT2
				end
				if stepCost then
					step *= (readf32(stepCost, cell * 4) + readf32(stepCost, nc * 4)) * 0.5
				end
				local nv = c + step
				if nv < cost[nc + 1] then
					cost[nc + 1] = nv
					local b = floor(nv)
					local ne = job.entryCount + 1
					job.entryCount = ne
					entryCell[ne] = nc
					entryCost[ne] = nv
					entryNext[ne] = bucketHead[b] or 0
					bucketHead[b] = ne
					if b > job.maxBucket then
						job.maxBucket = b
					end
				end
			end
		end
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
				for d = 0, 7 do
					local nx, nz = x + DX[d + 1], z + DZ[d + 1]
					if nx < 0 or nz < 0 or nx >= w or nz >= h then
						continue
					end
					if d % 2 == 1 and (readu8(mask, z * w + nx) == 0 or readu8(mask, nz * w + x) == 0) then
						continue
					end
					local nv = cost[nz * w + nx + 1]
					if nv < bestCost then
						best, bestCost = d, nv
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
