--!strict
-- Coarse 64-stud bucket grid of live units (guide 10.2), rebuilt when
-- positions change. Queries filter by team: "enemies of team T near (x, z)"
-- is the per-team contact grid. Until Sensors exist (M4) every enemy counts
-- as known (DECISIONS D43); the visibility check slots into `query`.
--
-- Linked lists in reused arrays: no allocation per rebuild once warm.

local Grid = require("@shared/Grid/Grid")
local World = require("../World")

local ContactGrid = {}

ContactGrid.BUCKET = 64

export type ContactGrid = {
	originX: number,
	originZ: number,
	width: number, -- buckets per side
	depth: number,
	head: { [number]: number }, -- bucket → first unit ID
	nextUnit: { [number]: number }, -- unit ID → next unit ID in its bucket (0 = end)
	used: { number }, -- buckets with a head, to clear
}

-- Without a map the grid covers ±2048 studs (the largest map size).
function ContactGrid.new(grid: Grid.Grid?): ContactGrid
	local originX = if grid then grid.originX else -2048
	local originZ = if grid then grid.originZ else -2048
	local sizeX = if grid then grid.sizeX else 4096
	local sizeZ = if grid then grid.sizeZ else 4096
	return {
		originX = originX,
		originZ = originZ,
		width = math.ceil(sizeX / ContactGrid.BUCKET),
		depth = math.ceil(sizeZ / ContactGrid.BUCKET),
		head = {},
		nextUnit = {},
		used = {},
	}
end

local function bucketOf(g: ContactGrid, x: number, z: number): (number, number)
	local bx = math.clamp(math.floor((x - g.originX) / ContactGrid.BUCKET), 0, g.width - 1)
	local bz = math.clamp(math.floor((z - g.originZ) / ContactGrid.BUCKET), 0, g.depth - 1)
	return bx, bz
end

function ContactGrid.rebuild(g: ContactGrid, w: World.World)
	local head, used = g.head, g.used
	for i = #used, 1, -1 do
		head[used[i]] = nil
		used[i] = nil
	end
	-- Insert in reverse ids order so each bucket lists units in ids order.
	local ids = w.ids
	for k = #ids, 1, -1 do
		local id = ids[k]
		local bx, bz = bucketOf(g, w.posX[id], w.posZ[id])
		local b = bz * g.width + bx
		local first = head[b]
		if first == nil then
			table.insert(used, b)
			g.nextUnit[id] = 0
		else
			g.nextUnit[id] = first
		end
		head[b] = id
	end
end

-- Writes into `out` the IDs of units whose center is within `radius` of
-- (x, z) and whose ally team is not `excludeAlly` (0 = keep every team). Returns
-- the count. Order is deterministic (buckets row by row, ids order within a
-- bucket). Callers add unit radii to `radius` when they need surface contact.
function ContactGrid.query(
	g: ContactGrid,
	w: World.World,
	x: number,
	z: number,
	radius: number,
	excludeAlly: number,
	out: { number }
): number
	local n = 0
	local x0, z0 = bucketOf(g, x - radius, z - radius)
	local x1, z1 = bucketOf(g, x + radius, z + radius)
	local r2 = radius * radius
	local head, nextUnit, ally, posX, posZ = g.head, g.nextUnit, w.ally, w.posX, w.posZ
	for bz = z0, z1 do
		for bx = x0, x1 do
			local id = head[bz * g.width + bx]
			while id ~= nil and id ~= 0 do
				if ally[id] ~= excludeAlly then
					local dx, dz = posX[id] - x, posZ[id] - z
					if dx * dx + dz * dz <= r2 then
						n += 1
						out[n] = id
					end
				end
				id = nextUnit[id]
			end
		end
	end
	return n
end

return ContactGrid
