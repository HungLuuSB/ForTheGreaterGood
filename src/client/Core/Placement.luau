--!strict
-- Client-side placement check for the build ghost (guide 9.3, 15.6): the
-- server's rules (src/server/Sim/Placement.luau) applied to what this client
-- knows. Snapping and terrain are exact (same layers, same slope); occupancy
-- and units in the way use known units only, as the server's planning check
-- (D101) does. The server re-checks when the builder starts the frame.
-- Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Placement = {}

-- copies of the server's values (Sim/Placement.luau; request 4)
Placement.LAND_MAX_SLOPE = 30 -- degrees
Placement.WATER_MIN_DEPTH = 6 -- studs
Placement.RADIUS_PER_FOOTPRINT = 8 * 0.45 -- unit collision radius per footprint cell

export type Result = {
	ok: boolean,
	reason: string?, -- "out of bounds" | "terrain" | "occupied" | "no deposit" | "units in the way"
	x0: number, -- min-corner cell
	z0: number,
	x: number, -- snapped center (studs)
	z: number,
	replaces: number, -- extractor upgrade: the extractor it replaces, else 0
}

-- Min-corner cell of a size-F footprint whose center is nearest (x, z), and
-- the snapped center: odd footprints center on a cell, even on a corner.
function Placement.snap(grid: Grid.Grid, size: number, x: number, z: number): (number, number, number, number)
	local fx = (x - grid.originX) / Grid.CELL_SIZE - size / 2
	local fz = (z - grid.originZ) / Grid.CELL_SIZE - size / 2
	local x0, z0 = math.floor(fx + 0.5), math.floor(fz + 0.5)
	return x0, z0, (x0 + size / 2) * Grid.CELL_SIZE + grid.originX, (z0 + size / 2) * Grid.CELL_SIZE + grid.originZ
end

-- The client's passability map for its world (built once per map).
local passCache: { [any]: Passability.PassMap } = setmetatable({}, { __mode = "k" }) :: any

local function passMap(world: World.World): Passability.PassMap?
	local layers = world.layers
	if layers == nil then
		return nil
	end
	local pm = passCache[layers]
	if pm == nil then
		pm = Passability.build(layers)
		passCache[layers] = pm
	end
	return pm
end

-- Known structures' footprints: (x0, z0, size, id, def?) per structure.
local function structures(world: World.World): { { any } }
	local out = {}
	for id, u in world.units do
		local def = World.def(world, u)
		if def and def.domain == "structure" then
			local x0, z0 = Placement.snap(world.grid, def.footprint, u.x, u.z)
			table.insert(out, { x0, z0, def.footprint, id, def })
		elseif def == nil and u.flags and bit32.band(u.flags, Schema.StrategicFlag.GHOST) ~= 0 then
			-- a ghost (strategic record): its cell only, its size is unknown
			local cx, cz = world.grid:cellAt(u.x, u.z)
			table.insert(out, { cx, cz, 1, id, nil })
		end
	end
	return out
end

function Placement.check(world: World.World, def: any, x: number, z: number): Result
	local g = world.grid
	local size = def.footprint
	local x0, z0, cx, cz = Placement.snap(g, size, x, z)
	local function fail(reason: string): Result
		return { ok = false, reason = reason, x0 = x0, z0 = z0, x = cx, z = cz, replaces = 0 }
	end
	local layers = world.layers
	local pm = passMap(world)
	if layers == nil or pm == nil then
		return fail("out of bounds")
	end
	-- occupant per covered cell, from the known structures
	local occupant: { [number]: { any } } = {}
	for _, s in structures(world) do
		local sx0, sz0, ssize = s[1], s[2], s[3]
		if sx0 < x0 + size and x0 < sx0 + ssize and sz0 < z0 + size and z0 < sz0 + ssize then
			for cz2 = math.max(sz0, z0), math.min(sz0 + ssize, z0 + size) - 1 do
				for cx2 = math.max(sx0, x0), math.min(sx0 + ssize, x0 + size) - 1 do
					occupant[cz2 * g.cellsX + cx2] = s
				end
			end
		end
	end
	-- cell by cell, in the server's order: bounds, occupant, terrain
	local placement = def.placement or "land"
	local replaces = 0
	for cellZ = z0, z0 + size - 1 do
		for cellX = x0, x0 + size - 1 do
			if not g:inBounds(cellX, cellZ) then
				return fail("out of bounds")
			end
			local i = g:index(cellX, cellZ)
			local s = occupant[i]
			if s then
				local id, sdef = s[4], s[5]
				local u = world.units[id]
				local upgrade = def.extractor ~= nil
					and sdef ~= nil
					and sdef.extractor ~= nil
					and sdef.extractor.rate < def.extractor.rate
					and u.team == world.me.team
					and (u.build or 0) >= 1
					and (replaces == 0 or replaces == id)
				if not upgrade then
					return fail("occupied")
				end
				replaces = id
			end
			local water = Layers.getWater(layers, i)
			local land = water <= 0 and Passability.slopeDegrees(pm, i) <= Placement.LAND_MAX_SLOPE
			local sea = water >= Placement.WATER_MIN_DEPTH
			local ok = if placement == "land" then land elseif placement == "water" then sea else (land or sea)
			if not ok then
				return fail("terrain")
			end
		end
	end
	if def.extractor then
		local gx, gz = g:cellAt(cx, cz)
		if Layers.getSupply(layers, g:index(gx, gz)) == 0 then
			return fail("no deposit")
		end
	end
	local minX, minZ = x0 * Grid.CELL_SIZE + g.originX, z0 * Grid.CELL_SIZE + g.originZ
	local maxX, maxZ = minX + size * Grid.CELL_SIZE, minZ + size * Grid.CELL_SIZE
	for id, u in world.units do
		local udef = World.def(world, u)
		if udef and udef.domain ~= "air" and udef.domain ~= "structure" and id ~= replaces then
			local r = udef.footprint * Placement.RADIUS_PER_FOOTPRINT
			local px, pz = u.rx or u.x, u.rz or u.z
			if px + r > minX and px - r < maxX and pz + r > minZ and pz - r < maxZ then
				return fail("units in the way")
			end
		end
	end
	return { ok = true, reason = nil, x0 = x0, z0 = z0, x = cx, z = cz, replaces = replaces }
end

-- Centers for a row of `def` dragged from (x1, z1) to (x2, z2): one per
-- footprint along the drag, snapped (guide 15.6 "drag for rows").
function Placement.row(world: World.World, def: any, x1: number, z1: number, x2: number, z2: number): { { number } }
	local step = def.footprint * Grid.CELL_SIZE
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.floor(len / step) + 1
	local out = {}
	local seen: { [string]: boolean } = {}
	for i = 0, n - 1 do
		local t = if n == 1 then 0 else i / (n - 1)
		local _, _, cx, cz = Placement.snap(world.grid, def.footprint, x1 + dx * t, z1 + dz * t)
		local key = `{cx},{cz}`
		if not seen[key] then
			seen[key] = true
			table.insert(out, { cx, cz })
		end
	end
	return out
end

return Placement
