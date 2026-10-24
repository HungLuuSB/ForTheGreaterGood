--!strict
-- The team's radar coverage as a map layer (C-207, BAR reference 6): one
-- value per grid cell, 0 outside, FILL inside, RING on the lighter rings
-- (each radar's own, every RING_STEP studs from it, and the coverage's
-- outer edge: an edge deep inside another radar isn't drawn). Circles are
-- the sim's: Sensors stamps a radar's radius as a plain circle (terrain
-- occlusion is coming from sim-A, request 66: then the cells come from its
-- shared function), so the layer shows what the server counts as covered.
-- Core/FogBlanket composites it under the fog, so the minimap shows the
-- same. Shown while placing a radar structure (its range included), while
-- a selected own unit has radar, or in the sensor view. Pure Luau (C-7).

local World = require("./World")

local RadarFill = {}

RadarFill.FILL = 1
RadarFill.RING = 2
RadarFill.RING_STEP = 160 -- studs between the inner rings
RadarFill.RING_WIDTH = 8 -- studs: a ring is this wide (a grid cell)

export type Circle = { x: number, z: number, r: number }
export type Layer = { width: number, depth: number, cells: buffer, key: string, version: number }

function RadarFill.new(width: number, depth: number): Layer
	return { width = width, depth = depth, cells = buffer.create(width * depth), key = "", version = 0 }
end

-- A key that changes when the circles do (rounded to `step` studs).
function RadarFill.key(circles: { Circle }, step: number): string
	local parts = {}
	for _, c in circles do
		table.insert(parts, `{math.floor(c.x / step + 0.5)},{math.floor(c.z / step + 0.5)},{c.r}`)
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

-- Fills the layer for `circles` on a grid of `cell`-stud cells whose corner
-- is (originX, originZ). Returns true when it changed (a new key).
function RadarFill.build(layer: Layer, circles: { Circle }, originX: number, originZ: number, cell: number): boolean
	local key = RadarFill.key(circles, cell)
	if key == layer.key then
		return false
	end
	layer.key = key
	layer.version += 1
	local cells, w, d = layer.cells, layer.width, layer.depth
	buffer.fill(cells, 0, 0)
	local half, band = RadarFill.RING_WIDTH / 2, RadarFill.RING_WIDTH
	local function each(c: Circle, fn: (i: number, dist: number) -> ())
		local x0 = math.max(0, math.floor((c.x - c.r - originX) / cell))
		local x1 = math.min(w - 1, math.floor((c.x + c.r - originX) / cell))
		local z0 = math.max(0, math.floor((c.z - c.r - originZ) / cell))
		local z1 = math.min(d - 1, math.floor((c.z + c.r - originZ) / cell))
		for pz = z0, z1 do
			local dz = originZ + (pz + 0.5) * cell - c.z
			for px = x0, x1 do
				local dx = originX + (px + 0.5) * cell - c.x
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist <= c.r then
					fn(pz * w + px, dist)
				end
			end
		end
	end
	-- deep inside some radar (past its edge band): another radar's edge
	-- there isn't drawn, so overlapping radars show one outline
	local deep = buffer.create(w * d)
	for _, c in circles do
		each(c, function(i, dist)
			if c.r - dist >= band then
				buffer.writeu8(deep, i, 1)
			end
		end)
	end
	for _, c in circles do
		each(c, function(i, dist)
			local ring
			if c.r - dist < band then
				ring = buffer.readu8(deep, i) == 0 -- the coverage's outer edge
			else
				local m = dist % RadarFill.RING_STEP
				ring = dist > half and (m < half or RadarFill.RING_STEP - m < half) -- this radar's inner rings
			end
			if ring then
				buffer.writeu8(cells, i, RadarFill.RING)
			elseif buffer.readu8(cells, i) == 0 then
				buffer.writeu8(cells, i, RadarFill.FILL)
			end
		end)
	end
	return true
end

-- A def's radar radius in studs (0: none).
local function radarOf(def: any): number
	return if def and def.sensors and def.sensors.radar then def.sensors.radar else 0
end

-- The circles to draw now, or nil (layer hidden): every finished own radar
-- emitter (structures and units), plus the placement ghost's when it is a
-- radar. Shown while `placement` is a radar structure, while any of
-- `selection` is an own unit with radar, or with `sensorView` on.
function RadarFill.circles(world: World.World, placement: { defIndex: number, x: number, z: number }?, selection: { number }, sensorView: boolean): { Circle }?
	local ghost = if placement then world.defs.unitByIndex[placement.defIndex] else nil
	local show = sensorView or radarOf(ghost) > 0
	if not show then
		for _, id in selection do
			local u = world.units[id]
			if u and u.team == world.me.team and radarOf(World.def(world, u)) > 0 then
				show = true
				break
			end
		end
	end
	if not show then
		return nil
	end
	local out: { Circle } = {}
	local ids = {}
	for id, u in world.units do
		if u.team == world.me.team and (u.build == nil or u.build >= 0.999) and radarOf(World.def(world, u)) > 0 then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		local u = world.units[id]
		table.insert(out, { x = u.rx or u.x, z = u.rz or u.z, r = radarOf(World.def(world, u)) })
	end
	if placement and radarOf(ghost) > 0 then
		table.insert(out, { x = placement.x, z = placement.z, r = radarOf(ghost) })
	end
	return out
end

function RadarFill.at(layer: Layer, px: number, pz: number): number
	if px < 0 or pz < 0 or px >= layer.width or pz >= layer.depth then
		return 0
	end
	return buffer.readu8(layer.cells, pz * layer.width + px)
end

return RadarFill
