--!strict
-- Map grid geometry (guide 5.1, 5.3): 8-stud cells, up to 256 × 256, map
-- centered on the world origin.
--
-- Cells are addressed by (cx, cz), both 0-based, or by index = cz * cellsX + cx
-- (0-based; fits u16 for the largest map). Wire positions are cell index +
-- offX/offZ in 1/256 of a cell (1/32 stud):
--   worldX = (cx + offX / 256) * 8 + originX

local Grid = {}
Grid.__index = Grid

Grid.CELL_SIZE = 8
Grid.SENSOR_CELL_SIZE = 16 -- 2 × 2 grid cells (guide 11.2)
Grid.MAX_CELLS = 256 -- per side
Grid.OFFSET_STEPS = 256 -- u8 offset resolution per cell

local CELL = Grid.CELL_SIZE
local SENSOR = Grid.SENSOR_CELL_SIZE
local STEPS = Grid.OFFSET_STEPS
local floor = math.floor

type GridData = {
	cellsX: number,
	cellsZ: number,
	cellCount: number,
	originX: number, -- world X of the map's min corner
	originZ: number,
	sizeX: number, -- studs
	sizeZ: number,
	sensorX: number, -- sensor cells per side
	sensorZ: number,
}
export type Grid = typeof(setmetatable({} :: GridData, Grid))

function Grid.new(cellsX: number, cellsZ: number): Grid
	for _, n in { cellsX, cellsZ } do
		if type(n) ~= "number" or n ~= floor(n) or n < 1 or n > Grid.MAX_CELLS then
			error(`Grid.new: cells per side must be an integer in 1..{Grid.MAX_CELLS}, got {n}`, 2)
		end
	end
	local sizeX, sizeZ = cellsX * CELL, cellsZ * CELL
	return setmetatable({
		cellsX = cellsX,
		cellsZ = cellsZ,
		cellCount = cellsX * cellsZ,
		originX = -sizeX / 2,
		originZ = -sizeZ / 2,
		sizeX = sizeX,
		sizeZ = sizeZ,
		sensorX = math.ceil(cellsX / 2),
		sensorZ = math.ceil(cellsZ / 2),
	}, Grid)
end

function Grid.index(self: Grid, cx: number, cz: number): number
	return cz * self.cellsX + cx
end

function Grid.coords(self: Grid, index: number): (number, number)
	local cz = index // self.cellsX
	return index - cz * self.cellsX, cz
end

function Grid.inBounds(self: Grid, cx: number, cz: number): boolean
	return cx >= 0 and cz >= 0 and cx < self.cellsX and cz < self.cellsZ
end

-- Cell containing world point (x, z). May be out of bounds; check inBounds.
function Grid.cellAt(self: Grid, x: number, z: number): (number, number)
	return floor((x - self.originX) / CELL), floor((z - self.originZ) / CELL)
end

-- World position of a cell's center.
function Grid.cellCenter(self: Grid, cx: number, cz: number): (number, number)
	return (cx + 0.5) * CELL + self.originX, (cz + 0.5) * CELL + self.originZ
end

-- Quantizes one axis: grid units u (cells, fractional) → cell, offset.
-- Points outside the map clamp to its edge.
local function quantize(u: number, cells: number): (number, number)
	local c = floor(u)
	if c < 0 then
		return 0, 0
	elseif c >= cells then
		return cells - 1, STEPS - 1
	end
	local off = floor((u - c) * STEPS)
	if off > STEPS - 1 then
		off = STEPS - 1
	end
	return c, off
end

-- World position → wire position (cell index u16, offX u8, offZ u8).
-- Error is under 1/32 stud inside the map; positions outside clamp to the edge.
function Grid.encode(self: Grid, x: number, z: number): (number, number, number)
	local cx, offX = quantize((x - self.originX) / CELL, self.cellsX)
	local cz, offZ = quantize((z - self.originZ) / CELL, self.cellsZ)
	return cz * self.cellsX + cx, offX, offZ
end

-- Wire position → world position. Errors on a cell index outside the map.
function Grid.decode(self: Grid, cell: number, offX: number, offZ: number): (number, number)
	if cell < 0 or cell >= self.cellCount or cell ~= floor(cell) then
		error(`Grid.decode: cell {cell} outside a {self.cellsX}x{self.cellsZ} map`, 2)
	end
	local cz = cell // self.cellsX
	local cx = cell - cz * self.cellsX
	return (cx + offX / STEPS) * CELL + self.originX, (cz + offZ / STEPS) * CELL + self.originZ
end

-- Sensor cell (16 studs) containing world point (x, z), clamped to the map.
function Grid.sensorCellAt(self: Grid, x: number, z: number): (number, number)
	local sx = floor((x - self.originX) / SENSOR)
	local sz = floor((z - self.originZ) / SENSOR)
	return math.clamp(sx, 0, self.sensorX - 1), math.clamp(sz, 0, self.sensorZ - 1)
end

return Grid
