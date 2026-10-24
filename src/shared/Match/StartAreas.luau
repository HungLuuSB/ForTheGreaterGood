--!strict
-- Spawn boxes and start hints (S-169, S-171, the user: there are no fixed
-- starts; a map's start positions are hints the AI uses to pick good spots,
-- and each side's players start inside that side's spawn box). Shared by
-- the sim, which checks every pick, and the client, which draws the boxes.
-- Pure Luau.
--
--   * Sides: the match's ally teams, ascending, share out the map's starts
--     (the hints) in contiguous blocks: with A sides and S starts, side k
--     gets starts floor((k-1)·S/A)+1 .. floor(k·S/A). Never more sides than
--     starts.
--   * Spawn boxes: each start has a box, the map's own (`Layers.startBoxes`,
--     { x0, z0, x1, z1 } per start) or, without one, a square of BOX_HALF
--     (a sixth of the map's shorter side, 96..256 studs) around it. A
--     side's box is the bounding box of its starts' boxes, kept EDGE studs
--     inside the map. Two sides' boxes that overlap are split at the
--     midpoint between their starts' centres, along the axis they're
--     farther apart on, GAP studs apart.
--   * Picks keep SPACING studs from every other player's pick.

local StartAreas = {}

StartAreas.SPACING = 48 -- studs between two players' starts
StartAreas.EDGE = 16 -- studs a box keeps from the map's edge
StartAreas.GAP = 96 -- studs between two sides' boxes split apart

export type Box = { number } -- { x0, z0, x1, z1 }, world studs, x0 <= x1, z0 <= z1
export type Sides = {
	allies: { number }, -- the sides (ally teams), ascending
	startsOf: { [number]: { number } }, -- ally team → its start indices (1-based, ascending)
	sideOfStart: { [number]: number }, -- start index → its ally team
}

-- Shares `startCount` starts among `allyTeams` (any order; duplicates ignored).
-- Errors when there are more sides than starts.
function StartAreas.sides(allyTeams: { number }, startCount: number): Sides
	local allies: { number } = {}
	for _, a in allyTeams do
		if table.find(allies, a) == nil then
			table.insert(allies, a)
		end
	end
	table.sort(allies)
	local n = #allies
	if n == 0 or n > startCount then
		error(`StartAreas.sides: {n} sides for {startCount} starts`, 2)
	end
	local startsOf: { [number]: { number } } = {}
	local sideOfStart: { [number]: number } = {}
	for k, a in allies do
		local first, last = (k - 1) * startCount // n + 1, k * startCount // n
		local list = {}
		for i = first, last do
			table.insert(list, i)
			sideOfStart[i] = a
		end
		startsOf[a] = list
	end
	return { allies = allies, startsOf = startsOf, sideOfStart = sideOfStart }
end

-- Half the side of a derived start box on a map of `width` × `depth` studs.
function StartAreas.boxHalf(width: number, depth: number): number
	return math.clamp(math.min(width, depth) / 6, 96, 256)
end

local function centre(starts: { { number } }, list: { number }): (number, number)
	local x, z = 0, 0
	for _, i in list do
		x += starts[i][1]
		z += starts[i][2]
	end
	return x / #list, z / #list
end

-- Every side's spawn box. `bounds` is the map's { x0, z0, x1, z1 };
-- `startBoxes` the map's own boxes per start (optional).
function StartAreas.boxes(sides: Sides, starts: { { number } }, bounds: Box, startBoxes: { Box }?): { [number]: Box }
	local half = StartAreas.boxHalf(bounds[3] - bounds[1], bounds[4] - bounds[2])
	local out: { [number]: Box } = {}
	for _, a in sides.allies do
		local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
		for _, i in sides.startsOf[a] do
			local b = if startBoxes and startBoxes[i] then startBoxes[i] else { starts[i][1] - half, starts[i][2] - half, starts[i][1] + half, starts[i][2] + half }
			x0, z0 = math.min(x0, b[1]), math.min(z0, b[2])
			x1, z1 = math.max(x1, b[3]), math.max(z1, b[4])
		end
		local e = StartAreas.EDGE
		out[a] = { math.max(x0, bounds[1] + e), math.max(z0, bounds[2] + e), math.min(x1, bounds[3] - e), math.min(z1, bounds[4] - e) }
	end
	-- split overlapping boxes between their sides' starts
	for p = 1, #sides.allies do
		for q = p + 1, #sides.allies do
			local a, b = sides.allies[p], sides.allies[q]
			local ba, bb = out[a], out[b]
			if ba[1] < bb[3] and bb[1] < ba[3] and ba[2] < bb[4] and bb[2] < ba[4] then
				local ax, az = centre(starts, sides.startsOf[a])
				local bx, bz = centre(starts, sides.startsOf[b])
				local alongX = math.abs(bx - ax) >= math.abs(bz - az)
				local lo, hi = if alongX then 1 else 2, if alongX then 3 else 4
				local ca, cb = if alongX then ax else az, if alongX then bx else bz
				local mid = (ca + cb) / 2
				local first, second = if ca <= cb then ba else bb, if ca <= cb then bb else ba
				first[hi] = math.min(first[hi], mid - StartAreas.GAP / 2)
				second[lo] = math.max(second[lo], mid + StartAreas.GAP / 2)
			end
		end
	end
	return out
end

function StartAreas.inBox(box: Box, x: number, z: number): boolean
	return x >= box[1] and x <= box[3] and z >= box[2] and z <= box[4]
end

-- The map's bounds { x0, z0, x1, z1 } from its grid.
function StartAreas.bounds(grid: any): Box
	return { grid.originX, grid.originZ, grid.originX + grid.cellsX * 8, grid.originZ + grid.cellsZ * 8 }
end

-- Does (x, z) keep SPACING from every pick in `picks` (player → { x, z }),
-- `self` aside?
function StartAreas.spaced(picks: { [number]: { number } }, self: number, x: number, z: number): boolean
	for pid, p in picks do
		if pid ~= self and (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < StartAreas.SPACING ^ 2 then
			return false
		end
	end
	return true
end

return table.freeze(StartAreas)
