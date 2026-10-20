--!strict
-- Slope, passMask and per-move-class clearance layers (guide 5.2, 6.1, 6.2),
-- derived from the height and water layers.
--
--   slope      u8 per cell: steepest climb to a 4-neighbor, 0..255 → 0..90°
--   passMask   u16 per cell: bit MoveClasses[mc].bit set if mc may enter
--   clearance  u8 per cell per move class: Chebyshev distance to the nearest
--              cell that class can't enter (outside the map counts as
--              blocked): 0 = blocked, 1 = passable but touching a blocked
--              cell or the map edge, and so on. Capped at 255.
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
	clearance: { [string]: buffer }, -- u8 per cell, by move class ID
}

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

-- Exact Chebyshev distance transform (two-pass chamfer with unit weights).
-- Cells outside the map count as blocked at distance 0.
local function computeClearance(grid: Grid.Grid, passMask: buffer, bitValue: number): buffer
	local w, h = grid.cellsX, grid.cellsZ
	local n = grid.cellCount
	local d = table.create(n, 0)
	local BIG = 255

	for i = 0, n - 1 do
		d[i + 1] = if band(readu16(passMask, i * 2), bitValue) ~= 0 then BIG else 0
	end

	-- Forward pass: left, up-left, up, up-right (outside = 0).
	for cz = 0, h - 1 do
		for cx = 0, w - 1 do
			local i = cz * w + cx + 1
			local v = d[i]
			if v > 0 then
				local left = if cx > 0 then d[i - 1] else 0
				local up = if cz > 0 then d[i - w] else 0
				local upLeft = if cx > 0 and cz > 0 then d[i - w - 1] else 0
				local upRight = if cx < w - 1 and cz > 0 then d[i - w + 1] else 0
				v = math.min(v, left + 1, up + 1, upLeft + 1, upRight + 1)
				d[i] = v
			end
		end
	end
	-- Backward pass: right, down-right, down, down-left.
	for cz = h - 1, 0, -1 do
		for cx = w - 1, 0, -1 do
			local i = cz * w + cx + 1
			local v = d[i]
			if v > 0 then
				local right = if cx < w - 1 then d[i + 1] else 0
				local down = if cz < h - 1 then d[i + w] else 0
				local downRight = if cx < w - 1 and cz < h - 1 then d[i + w + 1] else 0
				local downLeft = if cx > 0 and cz < h - 1 then d[i + w - 1] else 0
				v = math.min(v, right + 1, down + 1, downRight + 1, downLeft + 1)
				d[i] = v
			end
		end
	end

	local out = buffer.create(n)
	for i = 0, n - 1 do
		writeu8(out, i, d[i + 1])
	end
	return out
end

-- Derives slope, passMask and clearance for every move class. Pure function
-- of the layers; run once at map load (and locally when structures change).
function Passability.build(layers: Layers.Layers): PassMap
	local grid = layers.grid
	local n = grid.cellCount
	local slope = computeSlope(grid, layers)
	local passMask = buffer.create(n * 2)
	for i = 0, n - 1 do
		local s = readu8(slope, i)
		local water = Layers.getWater(layers, i)
		local mask = 0
		for _, mc in CLASS_ORDER do
			if canEnter(mc, s, water) then
				mask += 2 ^ mc.bit
			end
		end
		writeu16(passMask, i * 2, mask)
	end
	local clearance = {}
	for _, mc in CLASS_ORDER do
		clearance[mc.id] = computeClearance(grid, passMask, 2 ^ mc.bit)
	end
	return { grid = grid, layers = layers, slope = slope, passMask = passMask, clearance = clearance }
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
