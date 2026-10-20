--!strict
-- Map IDs → terrain layers. The ID is stored in the replay header, so a
-- replay rebuilds exactly the same map.
--
--   "none"              no map (the sim runs without terrain or movement)
--   "flat:<cells>"      flat land, cells × cells
--   "gen:<seed>:<cells>" TestMap.generate hills and lakes
--   "wall:<cells>"      flat land split by a north–south water wall (3 cells
--                       thick) with one 6-cell gap near the north end
--   "start:<cells>"     flat land with two starts (west, east), four supply
--                       deposits (value 4) around each start, two in the middle
--   "skirmish:<cells>"  "start" plus expansions for the skirmish AI: two
--                       pairs of deposits (value 3) per side, mirrored, and a
--                       rich pair (value 6) in the middle
--   "sea:<cells>"       land on the west quarter (height 10), deep sea elsewhere
--                       (sea floor -10, surface at 10: 20 studs of water)
--
-- Baked Studio maps (guide 5.4) will be added as "baked:<name>".

local Layers = require("./Layers")
local TestMap = require("./TestMap")

local MapRegistry = {}

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
	local seed, size = string.match(mapId, "^gen:(%d+):(%d+)$")
	if seed then
		return TestMap.generate({ seed = tonumber(seed) :: number, cellsX = tonumber(size) :: number })
	end
	error(`MapRegistry.load: unknown map id "{mapId}"`, 2)
end

return MapRegistry
