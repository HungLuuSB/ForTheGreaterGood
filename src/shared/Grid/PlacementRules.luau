--!strict
-- Placement rules both sides need (S-9, client request): the footprint
-- snap, the terrain rule and the unit collision radius per footprint cell.
-- The sim's Placement, Nav and Combat use these; clients draw the build
-- ghost with the same functions, so the ghost's tint matches the server.

local Grid = require("./Grid")
local Layers = require("./Layers")
local Passability = require("./Passability")

local PlacementRules = {}

PlacementRules.LAND_MAX_SLOPE = 30 -- degrees
PlacementRules.WATER_MIN_DEPTH = 6 -- studs (as deep as ships need)
PlacementRules.RADIUS_PER_FOOTPRINT = 8 * 0.45 -- collision radius per footprint cell (studs)

-- Min-corner cell of a size-F footprint whose center is nearest (x, z), and
-- the snapped world center.
function PlacementRules.snap(grid: Grid.Grid, size: number, x: number, z: number): (number, number, number, number)
	local fx = (x - grid.originX) / Grid.CELL_SIZE - size / 2
	local fz = (z - grid.originZ) / Grid.CELL_SIZE - size / 2
	local x0, z0 = math.floor(fx + 0.5), math.floor(fz + 0.5)
	return x0, z0, (x0 + size / 2) * Grid.CELL_SIZE + grid.originX, (z0 + size / 2) * Grid.CELL_SIZE + grid.originZ
end

local maxSlope = Passability.degreesToSlope(PlacementRules.LAND_MAX_SLOPE)

-- Does cell `i`'s terrain allow a structure with this `placement` ("land",
-- "water", or anything else = either)? Occupants and units are checked
-- separately (the server's Placement.check).
function PlacementRules.terrainOk(pm: Passability.PassMap, i: number, placement: string): boolean
	local water = Layers.getWater(pm.layers, i)
	local land = water <= 0 and buffer.readu8(pm.slope, i) <= maxSlope
	local sea = water >= PlacementRules.WATER_MIN_DEPTH
	return if placement == "land" then land elseif placement == "water" then sea else (land or sea)
end

return PlacementRules
