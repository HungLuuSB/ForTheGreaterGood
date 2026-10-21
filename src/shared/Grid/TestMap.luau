--!strict
-- Procedural test maps (height + water layers) for headless tests and
-- benchmarks. Real maps are baked in Studio (guide 5.4, M1+); these stand in
-- until then.
--
-- Deterministic: the same options always give byte-identical layers.

local Grid = require("./Grid")
local Layers = require("./Layers")
local Prng = require("../Util/Prng")

local TestMap = {}

export type Options = {
	seed: number,
	cellsX: number?, -- default 128
	cellsZ: number?, -- default cellsX
	amplitude: number?, -- studs from lowest to highest point, default 48
	seaLevel: number?, -- water surface height in studs, default 35% of amplitude
}

-- Value-noise octaves: lattice spacing in cells and weight (weights sum to 1).
local OCTAVES = {
	{ spacing = 32, weight = 0.6 },
	{ spacing = 8, weight = 0.3 },
	{ spacing = 4, weight = 0.1 },
}

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

type Lattice = { values: { number }, width: number, spacing: number }

local function makeLattice(rng: Prng.Prng, cellsX: number, cellsZ: number, spacing: number): Lattice
	local width = cellsX // spacing + 2
	local depth = cellsZ // spacing + 2
	local values = table.create(width * depth)
	for i = 1, width * depth do
		values[i] = rng:nextNumber()
	end
	return { values = values, width = width, spacing = spacing }
end

-- Smooth noise in [0, 1] at cell (cx, cz).
local function sample(l: Lattice, cx: number, cz: number): number
	local u, v = cx / l.spacing, cz / l.spacing
	local x0, z0 = math.floor(u), math.floor(v)
	local tx, tz = smoothstep(u - x0), smoothstep(v - z0)
	local vals, w = l.values, l.width
	local i = z0 * w + x0 + 1
	local a, b = vals[i], vals[i + 1]
	local c, d = vals[i + w], vals[i + w + 1]
	local top = a + (b - a) * tx
	local bottom = c + (d - c) * tx
	return top + (bottom - top) * tz
end

-- Builds layers from a function returning (height, waterDepth) per cell.
-- Handy for hand-made test maps with known expected values.
function TestMap.build(cellsX: number, cellsZ: number, cell: (cx: number, cz: number) -> (number, number?, number?)): Layers.Layers
	local grid = Grid.new(cellsX, cellsZ)
	local layers = Layers.new(grid)
	for cz = 0, cellsZ - 1 do
		for cx = 0, cellsX - 1 do
			local h, water, terrain = cell(cx, cz)
			local index = grid:index(cx, cz)
			Layers.setHeight(layers, index, h)
			Layers.setWater(layers, index, water or 0)
			if terrain then
				Layers.setTerrain(layers, index, terrain) -- default grass (S-37)
			end
		end
	end
	return layers
end

-- Rolling hills with lakes and sea below seaLevel.
function TestMap.generate(options: Options): Layers.Layers
	local cellsX = options.cellsX or 128
	local cellsZ = options.cellsZ or cellsX
	local amplitude = options.amplitude or 48
	local seaLevel = options.seaLevel or amplitude * 0.35
	local rng = Prng.new(options.seed)

	local lattices = {}
	for i, octave in OCTAVES do
		lattices[i] = makeLattice(rng, cellsX, cellsZ, octave.spacing)
	end

	return TestMap.build(cellsX, cellsZ, function(cx, cz)
		local n = 0
		for i, octave in OCTAVES do
			n += octave.weight * sample(lattices[i], cx, cz)
		end
		local h = n * amplitude
		if h < seaLevel then
			return h, seaLevel - h
		end
		return h, 0
	end)
end

return TestMap
