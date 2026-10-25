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

PlacementRules.DEPOSIT_CELLS = 4 -- a deposit is a 2 × 2 patch (S-184)

-- Supply under a footprint of `size` cells snapped at (x, z): the sum of its
-- cells' deposits (S-104), per patch (S-184: a patch's four cells count
-- as its value once, so an extractor exactly on it, or an advanced one
-- centred over it, gets the full value; one half off it, half).
function PlacementRules.supplyUnder(layers: Layers.Layers, size: number, x: number, z: number): number
	local g = layers.grid
	local x0, z0 = PlacementRules.snap(g, size, x, z)
	local sum = 0
	for cz = z0, z0 + size - 1 do
		for cx = x0, x0 + size - 1 do
			if g:inBounds(cx, cz) then
				sum += Layers.getSupply(layers, g:index(cx, cz))
			end
		end
	end
	return sum / PlacementRules.DEPOSIT_CELLS
end

-- The deposit patch nearest (x, z) within `radius` studs: its centre and
-- value, or nil (S-184; build ghosts and the AI snap extractors to it).
function PlacementRules.depositNear(layers: Layers.Layers, x: number, z: number, radius: number): (number?, number?, number?)
	local best, bestD = nil, radius * radius
	for _, d in layers.deposits or {} do
		local dd = (d[1] - x) ^ 2 + (d[2] - z) ^ 2
		if dd <= bestD then
			best, bestD = d, dd
		end
	end
	if best == nil then
		return nil, nil, nil
	end
	return best[1], best[2], best[3]
end

return PlacementRules
