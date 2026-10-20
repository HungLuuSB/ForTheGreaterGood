--!strict
-- Per-cell map data layers (guide 5.2), each a flat buffer indexed by the
-- 0-based cell index. Heights and water depths are i16 in 0.25-stud steps
-- (range ±8191.75 studs).
--
-- More layers (slope, passMask, clearance...) are added by the passability
-- builder; this module owns only the terrain inputs.

local Grid = require("./Grid")

local Layers = {}

Layers.HEIGHT_STEP = 0.25
local STEP = Layers.HEIGHT_STEP
local MIN_RAW, MAX_RAW = -32768, 32767

local readi16 = buffer.readi16
local writei16 = buffer.writei16

export type Layers = {
	grid: Grid.Grid,
	height: buffer, -- i16 × cellCount
	waterDepth: buffer, -- i16 × cellCount; 0 = dry land
	supply: buffer, -- u8 × cellCount: supply deposit value, 0 = none (guide 5.2)
	starts: { { number } }, -- start positions {x, z} in world studs, player order
}

function Layers.new(grid: Grid.Grid): Layers
	return {
		grid = grid,
		height = buffer.create(grid.cellCount * 2),
		waterDepth = buffer.create(grid.cellCount * 2),
		supply = buffer.create(grid.cellCount),
		starts = {},
	}
end

local function toRaw(studs: number): number
	return math.clamp(math.floor(studs / STEP + 0.5), MIN_RAW, MAX_RAW)
end

function Layers.getHeight(layers: Layers, index: number): number
	return readi16(layers.height, index * 2) * STEP
end

-- Rounds to the nearest 0.25 stud; clamps to the i16 range.
function Layers.setHeight(layers: Layers, index: number, studs: number)
	writei16(layers.height, index * 2, toRaw(studs))
end

function Layers.getWater(layers: Layers, index: number): number
	return readi16(layers.waterDepth, index * 2) * STEP
end

-- Rounds to the nearest 0.25 stud; negative depths become 0.
function Layers.setWater(layers: Layers, index: number, studs: number)
	writei16(layers.waterDepth, index * 2, toRaw(math.max(studs, 0)))
end

function Layers.getSupply(layers: Layers, index: number): number
	return buffer.readu8(layers.supply, index)
end

-- Deposit value 0..255 (0 removes the deposit).
function Layers.setSupply(layers: Layers, index: number, value: number)
	buffer.writeu8(layers.supply, index, math.clamp(math.floor(value), 0, 255))
end

return Layers
