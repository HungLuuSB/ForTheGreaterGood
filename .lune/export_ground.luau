--!strict
-- Exports a map's drawn ground for the models stream to bake into mesh
-- tiles (C-167, docs/contracts/map-ground.md): the same surface the client
-- draws units on (Core/Terrain.groundY), sampled every STEP studs, the
-- ground type of every cell (Core/Terrain.material: the map's features
-- where it has them), the hand-made map's feature names, water, deposits
-- and starts.
--   lune run export_ground [mapId | all] [outDir]
-- mapId as in MapRegistry ("map:canyon"); "all" (the default) exports every
-- named and hand-made map. Writes <outDir>/<name>/ground.json (default
-- outDir: assets/maps).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Canyon = require("../src/shared/Grid/Canyon")
local Layers = require("../src/shared/Grid/Layers")
local MapRegistry = require("../src/shared/Grid/MapRegistry")
local Normandy = require("../src/shared/Grid/Normandy")
local Terrain = require("../src/client/Core/Terrain")

local STEP = 4 -- studs between height samples (half a cell)
local FEATURES: { [string]: (number, number) -> string } = {
	["map:normandy"] = Normandy.feature,
	["map:canyon"] = Canyon.feature,
}

local function round(v: number, places: number): number
	local m = 10 ^ places
	return math.floor(v * m + 0.5) / m
end

local function export(mapId: string, outDir: string)
	local layers = assert(MapRegistry.load(mapId), `unknown map {mapId}`) :: Layers.Layers
	local g = layers.grid
	local feature = FEATURES[mapId]
	local name = string.match(mapId, "^map:(.+)$") or mapId
	-- heights: a vertex every STEP studs from the map's corner, x fastest
	local nx, nz = math.floor(g.sizeX / STEP) + 1, math.floor(g.sizeZ / STEP) + 1
	local heights = table.create(nx * nz)
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			table.insert(heights, round(Terrain.groundY(layers, g.originX + i * STEP, g.originZ + j * STEP), 3))
		end
	end
	-- per cell: ground type, feature, water depth; palettes keep it small
	local palette, paletteIndex = {}, {}
	local featurePalette, featureIndex = {}, {}
	local function code(list: { string }, index: { [string]: number }, value: string): number
		local c = index[value]
		if c == nil then
			table.insert(list, value)
			c = #list - 1
			index[value] = c
		end
		return c
	end
	local materials, features, water = table.create(g.cellCount), table.create(g.cellCount), table.create(g.cellCount)
	local deposits = {}
	local waterLevel = Terrain.waterLevel(layers)
	for cz = 0, g.cellsZ - 1 do
		for cx = 0, g.cellsX - 1 do
			local x, z = g:cellCenter(cx, cz)
			local i = g:index(cx, cz)
			table.insert(materials, code(palette, paletteIndex, Terrain.material(layers, x, z, feature)))
			table.insert(features, code(featurePalette, featureIndex, if feature then feature(cx, cz) else ""))
			table.insert(water, round(Layers.getWater(layers, i), 2))
			local s = Layers.getSupply(layers, i)
			if s > 0 then
				table.insert(deposits, { cx, cz, s })
			end
		end
	end
	local starts = {}
	for _, s in layers.starts or {} do
		table.insert(starts, { s.x, s.z })
	end
	local doc = {
		format = "ftgg-ground/1",
		mapId = mapId,
		origin = { g.originX, g.originZ },
		size = { g.sizeX, g.sizeZ },
		cells = { g.cellsX, g.cellsZ },
		cellSize = g.sizeX / g.cellsX,
		step = STEP,
		vertices = { nx, nz },
		heights = heights,
		materialPalette = palette,
		materials = materials,
		featurePalette = featurePalette,
		features = features,
		waterLevel = waterLevel,
		water = water,
		deposits = deposits,
		starts = starts,
	}
	local dir = `{outDir}/{name}`
	fs.writeDir(dir)
	local path = `{dir}/ground.json`
	fs.writeFile(path, serde.encode("json", doc))
	print(string.format("%s: %d × %d vertices, %d × %d cells, %d ground types, %d deposits → %s", mapId, nx, nz, g.cellsX, g.cellsZ, #palette, #deposits, path))
end

local which = process.args[1] or "all"
local outDir = process.args[2] or "assets/maps"
if which == "all" then
	local ids = {}
	for name in MapRegistry.NAMED do
		table.insert(ids, "map:" .. name)
	end
	for name in MapRegistry.HANDMADE do
		table.insert(ids, "map:" .. name)
	end
	table.sort(ids)
	for _, id in ids do
		export(id, outDir)
	end
else
	export(which, outDir)
end
