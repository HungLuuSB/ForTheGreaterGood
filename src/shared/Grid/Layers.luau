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
	terrain: buffer, -- u8 × cellCount: Layers.Terrain type (guide 5.2 terrainType, S-37)
	starts: { { number } }, -- start positions {x, z} in world studs, player order
	startBoxes: { { number } }?, -- per start, its spawn box { x0, z0, x1, z1 } (studs); nil = derived (Shared/Match/StartAreas, S-171)
	sideSplits: { [number]: { { number } } }?, -- side count → each side's start indices, where contiguous blocks would split a side across the map (S-186)
	deposits: { { number } }?, -- every deposit's 2 × 2 patch: { x, z (its centre, a cell corner), value } (S-184; Layers.expandDeposits)
	wind: { number }?, -- { min, max }: the map's wind range, fractions of a turbine's max (0..1); nil = the default 0.1..0.9 (S-177)
}

function Layers.new(grid: Grid.Grid): Layers
	return {
		grid = grid,
		height = buffer.create(grid.cellCount * 2),
		waterDepth = buffer.create(grid.cellCount * 2),
		supply = buffer.create(grid.cellCount),
		terrain = buffer.create(grid.cellCount), -- all grass
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

-- Ground height at world (x, z): the height of the cell it falls in, cells
-- outside the map clamped to the edge. The server's Combat.groundHeight and
-- the vertical-launch climb (Guidance.climbLeft, S-44) use it, so a client
-- calling it gets the same number.
function Layers.heightAt(layers: Layers, x: number, z: number): number
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	return Layers.getHeight(layers, cz * g.cellsX + cx)
end

-- Terrain types (guide 5.2 `terrainType`; speed factors in Shared/Grid/Terrain).
Layers.Terrain = table.freeze({ GRASS = 0, ROCK = 1, SAND = 2, ROAD = 3 })

function Layers.getTerrain(layers: Layers, index: number): number
	return buffer.readu8(layers.terrain, index)
end

function Layers.setTerrain(layers: Layers, index: number, terrainType: number)
	buffer.writeu8(layers.terrain, index, terrainType)
end

-- Deposits are 2 × 2 cell patches (S-184, the user's playtest F6). Map
-- builders place one cell per deposit; this grows each into its patch,
-- toward the map's centre on each axis, so mirrored and rotated maps stay
-- symmetric, and lists the patches (`layers.deposits`: centre x, z on the
-- shared cell corner, and the value). A cell next to another deposit is
-- left alone. MapRegistry.load runs it once per map.
function Layers.expandDeposits(layers: Layers)
	local g = layers.grid
	local midX, midZ = (g.cellsX - 1) / 2, (g.cellsZ - 1) / 2
	local seeds = {}
	for i = 0, g.cellCount - 1 do
		local v = Layers.getSupply(layers, i)
		if v > 0 then
			table.insert(seeds, { i, v })
		end
	end
	local patches = {}
	for _, seed in seeds do
		local cx, cz = g:coords(seed[1])
		local dx = if cx < midX then 1 elseif cx > midX then -1 else 1
		local dz = if cz < midZ then 1 elseif cz > midZ then -1 else 1
		for _, d in { { dx, 0 }, { 0, dz }, { dx, dz } } do
			local nx, nz = cx + d[1], cz + d[2]
			if g:inBounds(nx, nz) and Layers.getSupply(layers, g:index(nx, nz)) == 0 then
				Layers.setSupply(layers, g:index(nx, nz), seed[2])
			end
		end
		local x0, z0 = math.min(cx, cx + dx), math.min(cz, cz + dz)
		local x, z = g:cellCenter(x0, z0)
		table.insert(patches, { x + 4, z + 4, seed[2] }) -- (half a cell: the shared corner)
	end
	layers.deposits = patches
end

return Layers
