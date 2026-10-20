--!strict
-- Map IDs → terrain layers. The ID is stored in the replay header, so a
-- replay rebuilds exactly the same map.
--
--   "none"              no map (the sim runs without terrain or movement)
--   "flat:<cells>"      flat land, cells × cells
--   "gen:<seed>:<cells>" TestMap.generate hills and lakes
--   "wall:<cells>"      flat land split by a north–south water wall (3 cells
--                       thick) with one 6-cell gap near the north end
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
	local seed, size = string.match(mapId, "^gen:(%d+):(%d+)$")
	if seed then
		return TestMap.generate({ seed = tonumber(seed) :: number, cellsX = tonumber(size) :: number })
	end
	error(`MapRegistry.load: unknown map id "{mapId}"`, 2)
end

return MapRegistry
