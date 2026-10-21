--!strict
-- Map IDs → terrain layers. The ID is stored in the replay header, so a
-- replay rebuilds exactly the same map.
--
--   "none"              no map (the sim runs without terrain or movement)
--   "flat:<cells>"      flat land, cells × cells
--   "gen:<seed>:<cells>" TestMap.generate hills and lakes
--   "wall:<cells>"      flat land split by a north–south water wall (3 cells
--                       thick) with one 6-cell gap near the north end
--   "ridge:<cells>"     flat land split by a north–south ridge (3 cells thick,
--                       20 studs above the land) with one 6-cell gap near the north end
--                       (line-of-fire tests, S-32)
--   "beach:<cells>"     land (height 10) in the west half sloping gently
--                       (about 10°) into a sea 30 studs deep in the east
--                       (water surface at 10; amphibious tests, S-39)
--   "terrain:<cells>"   flat land: grass in the west half, sand in the east
--                       half, a road along the middle row (terrain tests, S-37)
--   "start:<cells>"     flat land with two starts (west, east), four supply
--                       deposits (value 4) around each start, two in the middle
--   "skirmish:<cells>"  "start" plus expansions for the skirmish AI: two
--                       pairs of deposits (value 3) per side, mirrored, and a
--                       rich pair (value 6) in the middle
--   "sea:<cells>"       land on the west quarter (height 10), deep sea elsewhere
--                       (sea floor -10, surface at 10: 20 studs of water)
--   "mapgen:<layout>:<seed>:<cells>[:<water>[:<symmetry>]]"
--                       a MapGen skirmish map (guide 5.5, S-15): layout 1v1,
--                       2v2 or ffa4; water none (default), lakes or sea
--   "map:<name>"        a named MapGen map (MapRegistry.NAMED below)
--
-- Baked Studio maps (guide 5.4) will be added as "baked:<name>".

local Layers = require("./Layers")
local MapGen = require("./MapGen")
local TestMap = require("./TestMap")

local MapRegistry = {}

-- Named skirmish maps (S-15): MapGen options plus a display name. Starts
-- are in player order; on 2v2 maps players 1-2 and 3-4 are the teams.
export type Named = { name: string, options: MapGen.Options }
MapRegistry.NAMED = table.freeze({
	ridgeline = { name = "Ridgeline", options = { seed = 11, cells = 128, layout = "1v1", symmetry = "mirror", water = "none" } },
	coastline = { name = "Coastline", options = { seed = 12, cells = 128, layout = "1v1", symmetry = "mirror", water = "sea" } },
	twin_lakes = { name = "Twin Lakes", options = { seed = 13, cells = 192, layout = "2v2", water = "lakes" } },
	crossroads = { name = "Crossroads", options = { seed = 14, cells = 192, layout = "ffa4", water = "sea" } },
} :: { [string]: Named })

-- MapGen options for a "map:" or "mapgen:" ID, nil for other IDs.
function MapRegistry.genOptions(mapId: string): MapGen.Options?
	local name = string.match(mapId, "^map:([%w_]+)$")
	if name then
		local named = MapRegistry.NAMED[name]
		if named == nil then
			error(`MapRegistry: unknown named map "{name}"`, 2)
		end
		return named.options
	end
	local rest = string.match(mapId, "^mapgen:(.+)$")
	if rest then
		local parts = string.split(rest, ":")
		local seed, cells = tonumber(parts[2]), tonumber(parts[3])
		if #parts < 3 or seed == nil or cells == nil then
			error(`MapRegistry: malformed map id "{mapId}"`, 2)
		end
		return { layout = parts[1] :: any, seed = seed, cells = cells, water = parts[4] :: any, symmetry = parts[5] :: any }
	end
	return nil
end

-- Info (layout, symmetry, water, players, mode tags) of a generated map.
function MapRegistry.info(mapId: string): MapGen.Info?
	local options = MapRegistry.genOptions(mapId)
	if options == nil then
		return nil
	end
	local _, info = MapGen.generate(options)
	return info
end

-- Layers for a map ID, nil for "none". Errors on an unknown or malformed ID.
function MapRegistry.load(mapId: string): Layers.Layers?
	if mapId == "none" then
		return nil
	end
	local cells = string.match(mapId, "^flat:(%d+)$")
	if cells then
		local n = tonumber(cells) :: number
		return TestMap.build(n, n, function()
			return 10, 0
		end)
	end
	local wallCells = string.match(mapId, "^wall:(%d+)$")
	if wallCells then
		local n = tonumber(wallCells) :: number
		local mid = n // 2
		return TestMap.build(n, n, function(cx, cz)
			local inWall = cx >= mid - 1 and cx <= mid + 1
			local inGap = cz >= 4 and cz < 10
			return 10, if inWall and not inGap then 10 else 0
		end)
	end
	local ridgeCells = string.match(mapId, "^ridge:(%d+)$")
	if ridgeCells then
		local n = tonumber(ridgeCells) :: number
		local mid = n // 2
		return TestMap.build(n, n, function(cx, cz)
			local inRidge = cx >= mid - 1 and cx <= mid + 1 and not (cz >= 4 and cz < 10)
			return if inRidge then 30 else 10, 0
		end)
	end
	local beachCells = string.match(mapId, "^beach:(%d+)$")
	if beachCells then
		local n = tonumber(beachCells) :: number
		return TestMap.build(n, n, function(cx)
			local h = math.max(-20, 10 - math.max(0, cx - n // 2) * 1.5)
			return h, math.max(0, 10 - h)
		end)
	end
	local terrainCells = string.match(mapId, "^terrain:(%d+)$")
	if terrainCells then
		local n = tonumber(terrainCells) :: number
		local T = Layers.Terrain
		return TestMap.build(n, n, function(cx, cz)
			return 10, 0, if cz == n // 2 then T.ROAD elseif cx >= n // 2 then T.SAND else T.GRASS
		end)
	end
	local startCells = string.match(mapId, "^start:(%d+)$")
	if startCells then
		local n = tonumber(startCells) :: number
		local layers = TestMap.build(n, n, function()
			return 10, 0
		end)
		local g = layers.grid
		local mid = n // 2
		local west, east = math.floor(n * 0.15), n - 1 - math.floor(n * 0.15)
		for _, sx in { west, east } do
			table.insert(layers.starts, { g:cellCenter(sx, mid) })
			for _, d in { { 4, 4 }, { 4, -4 }, { -4, 4 }, { -4, -4 } } do
				Layers.setSupply(layers, g:index(sx + d[1], mid + d[2]), 4)
			end
		end
		Layers.setSupply(layers, g:index(mid - 1, mid - 6), 4)
		Layers.setSupply(layers, g:index(mid, mid + 6), 4)
		return layers
	end
	local skirmishCells = string.match(mapId, "^skirmish:(%d+)$")
	if skirmishCells then
		local n = tonumber(skirmishCells) :: number
		local layers = MapRegistry.load(`start:{n}`) :: Layers.Layers
		local g = layers.grid
		local mid = n // 2
		for _, side in { -1, 1 } do
			local ex = mid + side * math.floor(n * 0.2)
			for _, dz in { -1, 1 } do
				local ez = mid + dz * math.floor(n * 0.25)
				Layers.setSupply(layers, g:index(ex, ez), 3)
				Layers.setSupply(layers, g:index(ex + side * 3, ez), 3)
			end
		end
		Layers.setSupply(layers, g:index(mid - 1, mid - 6), 6)
		Layers.setSupply(layers, g:index(mid, mid + 6), 6)
		return layers
	end
	local seaCells = string.match(mapId, "^sea:(%d+)$")
	if seaCells then
		local n = tonumber(seaCells) :: number
		return TestMap.build(n, n, function(cx)
			if cx < n // 4 then
				return 10, 0
			end
			return -10, 20
		end)
	end
	local options = MapRegistry.genOptions(mapId)
	if options then
		return (MapGen.generate(options))
	end
	local seed, size = string.match(mapId, "^gen:(%d+):(%d+)$")
	if seed then
		return TestMap.generate({ seed = tonumber(seed) :: number, cellsX = tonumber(size) :: number })
	end
	error(`MapRegistry.load: unknown map id "{mapId}"`, 2)
end

return MapRegistry
