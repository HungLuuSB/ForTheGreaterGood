--!strict
-- Map grid geometry (guide 5.1, 5.3): 8-stud cells, up to 1,024 × 1,024
-- (S-189), map centered on the world origin.
--
-- Cells are addressed by (cx, cz), both 0-based, or by index = cz * cellsX + cx
-- (0-based).
--
-- Wire positions (protocol 38, S-189) don't depend on the map: a fixed
-- 256 × 256 grid of 64-stud wire cells centred on the world origin, so
-- ±8,192 studs (a 1,024-cell map and 4,096 studs past each edge), and
-- offX / offZ in 1/256 of a wire cell (a quarter stud):
--   worldX = ((wireCell % 256) * 256 + offX) / 4 - 8192
-- Same 4 bytes as the map-cell positions before protocol 38.

local Grid = {}
Grid.__index = Grid

Grid.CELL_SIZE = 8
Grid.SENSOR_CELL_SIZE = 16 -- 2 × 2 grid cells (guide 11.2)
Grid.MAX_CELLS = 1024 -- per side (S-189: 256 before protocol 38)
Grid.OFFSET_STEPS = 256 -- u8 offset resolution per wire cell
Grid.WIRE_CELL = 64 -- studs per wire cell (S-189)
Grid.WIRE_CELLS = 256 -- wire cells per side
Grid.WIRE_EXTENT = Grid.WIRE_CELL * Grid.WIRE_CELLS / 2 -- 8,192 studs: the wire reaches ±this far
Grid.OVERFLY = 512 -- studs past the map's edge aircraft and shots may go (S-189; inside the wire's reach for every map)

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

-- Wire positions (S-189): quarter studs from -WIRE_EXTENT, one axis.
local WIRE_CELLS = Grid.WIRE_CELLS
local EXTENT = Grid.WIRE_EXTENT
local PER_STUD = STEPS / Grid.WIRE_CELL -- 4 steps per stud
local WIRE_MAX = WIRE_CELLS * STEPS - 1
local function wireAxis(v: number): number
	return math.clamp(floor((v + EXTENT) * PER_STUD + 0.5), 0, WIRE_MAX)
end

-- World position → wire position (wire cell u16, offX u8, offZ u8). The
-- same for every map (S-189): error under 1/8 stud within ±WIRE_EXTENT;
-- positions past it clamp to its edge.
function Grid.encode(_self: Grid, x: number, z: number): (number, number, number)
	local qx, qz = wireAxis(x), wireAxis(z)
	return (qz // STEPS) * WIRE_CELLS + qx // STEPS, qx % STEPS, qz % STEPS
end

-- Wire position → world position (anywhere in ±WIRE_EXTENT, on the map or
-- not: decodeOnMap for orders). Errors on a malformed wire cell.
function Grid.decode(_self: Grid, cell: number, offX: number, offZ: number): (number, number)
	if cell < 0 or cell > WIRE_CELLS * WIRE_CELLS - 1 or cell ~= floor(cell) then
		error(`Grid.decode: wire cell {cell} outside 0..{WIRE_CELLS * WIRE_CELLS - 1}`, 2)
	end
	local tz = cell // WIRE_CELLS
	local tx = cell - tz * WIRE_CELLS
	return (tx * STEPS + offX) / PER_STUD - EXTENT, (tz * STEPS + offZ) / PER_STUD - EXTENT
end

-- (x, z) clamped onto the map (an eighth of a stud inside its far edge).
function Grid.clampToMap(self: Grid, x: number, z: number): (number, number)
	return math.clamp(x, self.originX, self.originX + self.sizeX - 0.125), math.clamp(z, self.originZ, self.originZ + self.sizeZ - 0.125)
end

-- Wire position → world position on the map: an order's point past the
-- edge (the wire carries those since S-189) moves onto the edge, as the
-- map-cell positions before protocol 38 clamped it.
function Grid.decodeOnMap(self: Grid, cell: number, offX: number, offZ: number): (number, number)
	local x, z = self:decode(cell, offX, offZ)
	return self:clampToMap(x, z)
end

-- Sensor cell (16 studs) containing world point (x, z), clamped to the map.
function Grid.sensorCellAt(self: Grid, x: number, z: number): (number, number)
	local sx = floor((x - self.originX) / SENSOR)
	local sz = floor((z - self.originZ) / SENSOR)
	return math.clamp(sx, 0, self.sensorX - 1), math.clamp(sz, 0, self.sensorZ - 1)
end

return Grid
