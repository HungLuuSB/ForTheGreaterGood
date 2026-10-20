--!strict
-- Slope, passMask and per-move-class clearance layers (guide 5.2, 6.1, 6.2),
-- derived from the height and water layers.
--
--   slope      u8 per cell: steepest climb to a 4-neighbor, 0..255 → 0..90°
--   passMask   u16 per cell: bit MoveClasses[mc].bit set if mc may enter
--   clearance  u8 per cell per move class: Chebyshev distance to the nearest
--              cell that class can't enter (outside the map counts as
--              blocked): 0 = blocked, 1 = passable but touching a blocked
--              cell or the map edge, and so on. Capped at CLEARANCE_CAP (16).
--   occupancy  u16 per cell: the structure standing there (0 = none);
--              occupied cells are blocked for every non-air class.
--
-- A unit with footprint F (an F × F cell square) can stand on a cell when
-- clearance >= floor(F / 2) + 1, i.e. the (2r + 1)² square around it is free
-- for r = floor(F / 2). Even footprints are treated like the next odd one.

local Grid = require("./Grid")
local Layers = require("./Layers")
local MoveClasses = require("../Defs/MoveClasses")

local Passability = {}

local readu8, writeu8 = buffer.readu8, buffer.writeu8
local readu16, writeu16 = buffer.readu16, buffer.writeu16
local readi16 = buffer.readi16
local band = bit32.band
local atan = math.atan
local deg = math.deg

local HEIGHT_STEP = Layers.HEIGHT_STEP
local CELL = Grid.CELL_SIZE
local SLOPE_SCALE = 255 / 90

export type PassMap = {
	grid: Grid.Grid,
	layers: Layers.Layers,
	slope: buffer, -- u8 per cell
	passMask: buffer, -- u16 per cell
	clearance: { [string]: buffer }, -- u8 per cell, by move class ID (capped)
	occupancy: buffer, -- u16 per cell: structure ID, 0 = free (guide 5.2)
}

-- Clearance values are capped: no footprint needs more, and the cap bounds
-- how far a local change can reach (exact local updates).
Passability.CLEARANCE_CAP = 16
local CAP = Passability.CLEARANCE_CAP

-- Move classes in bit order, so iteration is deterministic.
local CLASS_ORDER: { MoveClasses.MoveClass } = {}
for _, mc in MoveClasses do
	table.insert(CLASS_ORDER, mc)
end
table.sort(CLASS_ORDER, function(a, b)
	return a.bit < b.bit
end)
Passability.CLASS_ORDER = table.freeze(CLASS_ORDER)

-- Smallest clearance a footprint-F unit needs.
function Passability.requiredClearance(footprint: number): number
	return footprint // 2 + 1
end

-- u8 slope ↔ degrees.
function Passability.slopeToDegrees(u: number): number
	return u / SLOPE_SCALE
end

local function degreesToSlope(d: number): number
	return math.min(math.floor(d * SLOPE_SCALE + 0.5), 255)
end
Passability.degreesToSlope = degreesToSlope

local function computeSlope(grid: Grid.Grid, layers: Layers.Layers): buffer
	local w, h = grid.cellsX, grid.cellsZ
	local heights = layers.height
	local slope = buffer.create(grid.cellCount)
	for cz = 0, h - 1 do
		for cx = 0, w - 1 do
			local i = cz * w + cx
			local hc = readi16(heights, i * 2)
			local maxDiff = 0
			if cx > 0 then
				maxDiff = math.max(maxDiff, math.abs(readi16(heights, (i - 1) * 2) - hc))
			end
			if cx < w - 1 then
				maxDiff = math.max(maxDiff, math.abs(readi16(heights, (i + 1) * 2) - hc))
			end
			if cz > 0 then
				maxDiff = math.max(maxDiff, math.abs(readi16(heights, (i - w) * 2) - hc))
			end
			if cz < h - 1 then
				maxDiff = math.max(maxDiff, math.abs(readi16(heights, (i + w) * 2) - hc))
			end
			writeu8(slope, i, degreesToSlope(deg(atan(maxDiff * HEIGHT_STEP / CELL))))
		end
	end
	return slope
end

-- Can move class `mc` enter a cell with this slope (u8) and water depth (studs)?
local function canEnter(mc: MoveClasses.MoveClass, slopeU8: number, water: number): boolean
	local surface = mc.surface
	local slopeOk = mc.maxSlope == nil or slopeU8 <= degreesToSlope(mc.maxSlope)
	if surface == "land" then
		return slopeOk and water <= (mc.maxFord or 0)
	elseif surface == "water" then
		return water >= (mc.minDepth or 0)
	elseif surface == "hover" then
		return water > 0 or slopeOk -- the water surface is flat
	elseif surface == "amphib" then
		return slopeOk -- drives along the sea floor
	end
	return true -- air
end

-- Exact Chebyshev distance transform (two-pass chamfer with unit weights)
-- over the rectangle [rx0, rx1] × [rz0, rz1] (inclusive cells). Cells outside
-- the map count as blocked (0); cells inside the map but outside the
-- rectangle count as free. Writes min(distance, CLEARANCE_CAP) into `out` for
-- the cells of [wx0, wx1] × [wz0, wz1].
--
-- A cell's capped clearance depends only on blocked cells within CAP of it,
-- so recomputing a rectangle that extends 2 × CAP beyond a change and writing
-- back the inner CAP band is exact (Passability.updateRect).
local function transform(
	grid: Grid.Grid,
	passMask: buffer,
	bitValue: number,
	out: buffer,
	rx0: number,
	rz0: number,
	rx1: number,
	rz1: number,
	wx0: number,
	wz0: number,
	wx1: number,
	wz1: number
)
	local mapW, mapH = grid.cellsX, grid.cellsZ
	local w, h = rx1 - rx0 + 1, rz1 - rz0 + 1
	local BIG = 1000000
	-- d covers the rectangle plus a one-cell border holding the outside
	-- values (0 beyond the map edge, BIG inside the map), so the passes need
	-- no bounds checks. Padded stride: pw = w + 2.
	local pw, ph = w + 2, h + 2
	local d = table.create(pw * ph, 0)
	for pz = 0, ph - 1 do
		local mz = rz0 + pz - 1
		for px = 0, pw - 1 do
			local mx = rx0 + px - 1
			local v
			if mx < 0 or mz < 0 or mx >= mapW or mz >= mapH then
				v = 0 -- outside the map: blocked
			elseif px == 0 or pz == 0 or px == pw - 1 or pz == ph - 1 then
				v = BIG -- inside the map, outside the rectangle: free
			else
				v = if band(readu16(passMask, (mz * mapW + mx) * 2), bitValue) ~= 0 then BIG else 0
			end
			d[pz * pw + px + 1] = v
		end
	end
	local min = math.min
	for pz = 1, h do
		for px = 1, w do
			local i = pz * pw + px + 1
			local v = d[i]
			if v > 0 then
				d[i] = min(v, d[i - 1] + 1, d[i - pw] + 1, d[i - pw - 1] + 1, d[i - pw + 1] + 1)
			end
		end
	end
	for pz = h, 1, -1 do
		for px = w, 1, -1 do
			local i = pz * pw + px + 1
			local v = d[i]
			if v > 0 then
				d[i] = min(v, d[i + 1] + 1, d[i + pw] + 1, d[i + pw + 1] + 1, d[i + pw - 1] + 1)
			end
		end
	end
	for z = wz0, wz1 do
		for x = wx0, wx1 do
			writeu8(out, z * mapW + x, min(d[(z - rz0 + 1) * pw + (x - rx0 + 1) + 1], CAP))
		end
	end
end

-- passMask bits for one cell from terrain and occupancy.
local function cellMask(slopeU8: number, water: number, occupied: boolean): number
	local mask = 0
	for _, mc in CLASS_ORDER do
		if (not occupied or mc.surface == "air") and canEnter(mc, slopeU8, water) then
			mask += 2 ^ mc.bit
		end
	end
	return mask
end

-- Derives slope, passMask and clearance for every move class. Pure function
-- of the layers; run once at map load. Structures change it locally through
-- setOccupied / clearOccupied.
function Passability.build(layers: Layers.Layers): PassMap
	local grid = layers.grid
	local n = grid.cellCount
	local slope = computeSlope(grid, layers)
	local passMask = buffer.create(n * 2)
	for i = 0, n - 1 do
		writeu16(passMask, i * 2, cellMask(readu8(slope, i), Layers.getWater(layers, i), false))
	end
	local clearance = {}
	local mx, mz = grid.cellsX - 1, grid.cellsZ - 1
	for _, mc in CLASS_ORDER do
		local out = buffer.create(n)
		transform(grid, passMask, 2 ^ mc.bit, out, 0, 0, mx, mz, 0, 0, mx, mz)
		clearance[mc.id] = out
	end
	return {
		grid = grid,
		layers = layers,
		slope = slope,
		passMask = passMask,
		clearance = clearance,
		occupancy = buffer.create(n * 2),
	}
end

-- Recomputes passMask for the cells of a rectangle (from terrain and
-- occupancy), then every class's clearance around it, exactly.
function Passability.updateRect(pm: PassMap, x0: number, z0: number, x1: number, z1: number)
	local grid = pm.grid
	local mapW, mapH = grid.cellsX, grid.cellsZ
	x0, z0 = math.max(x0, 0), math.max(z0, 0)
	x1, z1 = math.min(x1, mapW - 1), math.min(z1, mapH - 1)
	for z = z0, z1 do
		for x = x0, x1 do
			local i = z * mapW + x
			local occupied = buffer.readu16(pm.occupancy, i * 2) ~= 0
			writeu16(pm.passMask, i * 2, cellMask(readu8(pm.slope, i), Layers.getWater(pm.layers, i), occupied))
		end
	end
	local rx0, rz0 = math.max(x0 - 2 * CAP, 0), math.max(z0 - 2 * CAP, 0)
	local rx1, rz1 = math.min(x1 + 2 * CAP, mapW - 1), math.min(z1 + 2 * CAP, mapH - 1)
	local wx0, wz0 = math.max(x0 - CAP, 0), math.max(z0 - CAP, 0)
	local wx1, wz1 = math.min(x1 + CAP, mapW - 1), math.min(z1 + CAP, mapH - 1)
	for _, mc in CLASS_ORDER do
		transform(grid, pm.passMask, 2 ^ mc.bit, pm.clearance[mc.id], rx0, rz0, rx1, rz1, wx0, wz0, wx1, wz1)
	end
end

-- Marks a size × size block of cells (min corner x0, z0) as occupied by
-- structure `id` (blocked for every non-air class) and updates clearance.
function Passability.setOccupied(pm: PassMap, x0: number, z0: number, size: number, id: number)
	local g = pm.grid
	for z = z0, z0 + size - 1 do
		for x = x0, x0 + size - 1 do
			if g:inBounds(x, z) then
				buffer.writeu16(pm.occupancy, (z * g.cellsX + x) * 2, id)
			end
		end
	end
	Passability.updateRect(pm, x0, z0, x0 + size - 1, z0 + size - 1)
end

-- Frees the cells of a block that structure `id` occupies (cells another
-- structure owns are left alone) and restores terrain passability.
function Passability.clearOccupied(pm: PassMap, x0: number, z0: number, size: number, id: number)
	local g = pm.grid
	for z = z0, z0 + size - 1 do
		for x = x0, x0 + size - 1 do
			if g:inBounds(x, z) and buffer.readu16(pm.occupancy, (z * g.cellsX + x) * 2) == id then
				buffer.writeu16(pm.occupancy, (z * g.cellsX + x) * 2, 0)
			end
		end
	end
	Passability.updateRect(pm, x0, z0, x0 + size - 1, z0 + size - 1)
end

function Passability.occupant(pm: PassMap, index: number): number
	return buffer.readu16(pm.occupancy, index * 2)
end

function Passability.slopeDegrees(pm: PassMap, index: number): number
	return readu8(pm.slope, index) / SLOPE_SCALE
end

function Passability.canEnter(pm: PassMap, moveClass: string, index: number): boolean
	return band(readu16(pm.passMask, index * 2), 2 ^ MoveClasses[moveClass].bit) ~= 0
end

function Passability.clearance(pm: PassMap, moveClass: string, index: number): number
	return readu8(pm.clearance[moveClass], index)
end

-- Can a unit of this move class and footprint stand on the cell?
function Passability.fits(pm: PassMap, moveClass: string, footprint: number, index: number): boolean
	return readu8(pm.clearance[moveClass], index) >= footprint // 2 + 1
end

return Passability
