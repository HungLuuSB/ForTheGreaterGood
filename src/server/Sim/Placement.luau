--!strict
-- Structure footprints on the grid (guide 9.3): snapping, placement checks,
-- and occupying / releasing cells (which updates passability and Nav).
--
-- A footprint of size F covers F × F cells. Odd footprints are centered on a
-- cell; even ones on a cell corner. Facing doesn't change square footprints
-- (non-square footprints would swap their sides at 90°/270°, guide 9.3).

local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Passability = require("@shared/Grid/Passability")
local Lifecycle = require("./Lifecycle")
local Nav = require("./Nav")
local Types = require("./Types")

local Placement = {}

Placement.LAND_MAX_SLOPE = 30 -- degrees
Placement.WATER_MIN_DEPTH = 6 -- studs (as deep as ships need)

-- Min-corner cell of a size-F footprint whose center is nearest (x, z), and
-- the snapped world center.
function Placement.snap(grid: Grid.Grid, size: number, x: number, z: number): (number, number, number, number)
	local fx = (x - grid.originX) / Grid.CELL_SIZE - size / 2
	local fz = (z - grid.originZ) / Grid.CELL_SIZE - size / 2
	local x0, z0 = math.floor(fx + 0.5), math.floor(fz + 0.5)
	return x0, z0, (x0 + size / 2) * Grid.CELL_SIZE + grid.originX, (z0 + size / 2) * Grid.CELL_SIZE + grid.originZ
end

-- Can `def` be placed centered near (x, z)? Returns ok, a reason when not,
-- and the snapped min corner and center.
function Placement.check(sim: Types.Sim, def: Defs.UnitDef, x: number, z: number): (boolean, string?, number, number, number, number)
	local pm = sim.map
	if pm == nil then
		return false, "no map", 0, 0, x, z
	end
	local g = pm.grid
	local size = def.footprint
	local x0, z0, cx, cz = Placement.snap(g, size, x, z)
	local layers = pm.layers
	local placement = def.placement or "land"
	local maxSlope = Passability.degreesToSlope(Placement.LAND_MAX_SLOPE)
	for cellZ = z0, z0 + size - 1 do
		for cellX = x0, x0 + size - 1 do
			if not g:inBounds(cellX, cellZ) then
				return false, "out of bounds", x0, z0, cx, cz
			end
			local i = g:index(cellX, cellZ)
			if Passability.occupant(pm, i) ~= 0 then
				return false, "occupied", x0, z0, cx, cz
			end
			local water = Layers.getWater(layers, i)
			local land = water <= 0 and buffer.readu8(pm.slope, i) <= maxSlope
			local sea = water >= Placement.WATER_MIN_DEPTH
			local ok = if placement == "land" then land elseif placement == "water" then sea else (land or sea)
			if not ok then
				return false, "terrain", x0, z0, cx, cz
			end
		end
	end
	if def.extractor then
		local gx, gz = g:cellAt(cx, cz)
		if Layers.getSupply(layers, g:index(gx, gz)) == 0 then
			return false, "no deposit", x0, z0, cx, cz
		end
	end
	-- no ground unit may stand on the footprint
	local w = sim.world
	local minX, minZ = x0 * Grid.CELL_SIZE + g.originX, z0 * Grid.CELL_SIZE + g.originZ
	local maxX, maxZ = minX + size * Grid.CELL_SIZE, minZ + size * Grid.CELL_SIZE
	for _, id in w.ids do
		local udef = sim.defs.unitByIndex[w.defIndex[id]]
		if udef.domain ~= "air" then
			local r = sim.combat.profiles[w.defIndex[id]].radius
			local px, pz = w.posX[id], w.posZ[id]
			if px + r > minX and px - r < maxX and pz + r > minZ and pz - r < maxZ then
				return false, "units in the way", x0, z0, cx, cz
			end
		end
	end
	return true, nil, x0, z0, cx, cz
end

local function footprintRect(sim: Types.Sim, id: number): (number, number, number)
	local pm = sim.map :: Passability.PassMap
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	local x0, z0 = Placement.snap(pm.grid, def.footprint, sim.world.posX[id], sim.world.posZ[id])
	return x0, z0, def.footprint
end

-- Marks structure `id`'s footprint as occupied (blocking ground movement).
function Placement.occupy(sim: Types.Sim, id: number)
	local pm = sim.map
	if pm == nil then
		return
	end
	local x0, z0, size = footprintRect(sim, id)
	Passability.setOccupied(pm, x0, z0, size, id)
	if sim.nav then
		Nav.terrainChanged(sim.nav, x0, z0, x0 + size - 1, z0 + size - 1)
	end
end

-- Frees structure `id`'s footprint (destroyed, reclaimed or cancelled).
function Placement.release(sim: Types.Sim, id: number)
	local pm = sim.map
	if pm == nil then
		return
	end
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	if def.domain ~= "structure" then
		return
	end
	local x0, z0, size = footprintRect(sim, id)
	Passability.clearOccupied(pm, x0, z0, size, id)
	if sim.nav then
		Nav.terrainChanged(sim.nav, x0, z0, x0 + size - 1, z0 + size - 1)
	end
end

table.insert(Lifecycle.removalHooks, Placement.release)

return Placement
